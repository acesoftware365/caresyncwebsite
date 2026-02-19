import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/image_url.dart';
import '../../../services/location_text.dart';
import '../../../services/web_link_opener.dart';
import '../../../widgets/smart_network_image.dart';

class DaycarePublicPage extends StatefulWidget {
  const DaycarePublicPage({super.key, required this.slug});
  final String slug;

  @override
  State<DaycarePublicPage> createState() => _DaycarePublicPageState();
}

class _DaycarePublicPageState extends State<DaycarePublicPage> {
  Future<String?>? tenantIdFuture;

  final _contactFormKey = GlobalKey<FormState>();
  final _contactNameCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactZipCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _contactChildBirthdayCtrl = TextEditingController();
  final _contactMessageCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    tenantIdFuture = _resolveTenantId(widget.slug);
  }

  @override
  void didUpdateWidget(covariant DaycarePublicPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      tenantIdFuture = _resolveTenantId(widget.slug);
    }
  }

  @override
  void dispose() {
    _contactNameCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactZipCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactChildBirthdayCtrl.dispose();
    _contactMessageCtrl.dispose();
    super.dispose();
  }

  Future<String?> _resolveTenantId(String slug) async {
    final db = FirebaseFirestore.instance;
    final s = slug.trim();
    if (s.isEmpty) return null;

    final q1 = await db
        .collection('tenants')
        .where('websiteSlug', isEqualTo: s)
        .where('websiteReady', isEqualTo: true)
        .limit(1)
        .get();
    if (q1.docs.isNotEmpty) return q1.docs.first.id;

    final q2 = await db
        .collection('tenants')
        .where('slug', isEqualTo: s)
        .where('websiteReady', isEqualTo: true)
        .limit(1)
        .get();
    if (q2.docs.isNotEmpty) return q2.docs.first.id;

    final doc = await db.collection('tenants').doc(s).get();
    final data = doc.data();
    if (data == null) return null;
    final ready = (data['websiteReady'] as bool?) ?? false;
    return ready ? doc.id : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: tenantIdFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final tenantId = snap.data;
        if (tenantId == null || tenantId.trim().isEmpty) {
          return const Center(child: Text('Not found / not ready'));
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('tenants')
              .doc(tenantId)
              .snapshots(),
          builder: (context, docSnap) {
            if (docSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = docSnap.data?.data();
            if (data == null ||
                ((data['websiteReady'] as bool?) ?? false) != true) {
              return const Center(child: Text('Not found / not ready'));
            }

            final d = data;
            final name = (d['daycareName'] ?? d['name'] ?? 'Daycare')
                .toString();
            final desc = (d['websiteDescription'] ?? '').toString().trim();
            final email = (d['email'] ?? '').toString().trim();
            final phone = _phoneFromDoc(d);
            final logoUrl = normalizeImageUrl(
              (d['websiteLogoUrl'] ?? '').toString(),
              defaultBucket: 'liisgo-daycare-system.firebasestorage.app',
            );
            final heroUrl = normalizeImageUrl(
              (d['websiteHeroUrl'] ?? '').toString(),
              defaultBucket: 'liisgo-daycare-system.firebasestorage.app',
            );
            final galleryRaw = (d['websiteGalleryUrls'] as List?) ?? const [];
            final galleryUrls = galleryRaw
                .map(
                  (e) => normalizeImageUrl(
                    e.toString(),
                    defaultBucket: 'liisgo-daycare-system.firebasestorage.app',
                  ),
                )
                .where((e) => e.isNotEmpty)
                .toList();

            final photos = <String>[];
            if (heroUrl.isNotEmpty) photos.add(heroUrl);
            for (final g in galleryUrls) {
              if (!photos.contains(g)) photos.add(g);
            }

            final city = normalizeCity((d['addressCity'] ?? '').toString());
            final state = normalizeStateCode(
              (d['addressState'] ?? '').toString(),
            );
            final zip = (d['addressZip'] ?? '').toString().trim();
            final street =
                '${(d['addressHouseNumber'] ?? '').toString()} ${(d['addressStreet'] ?? '').toString()}'
                    .trim();
            final address = [
              street,
              city,
              state,
              zip,
            ].where((e) => e.trim().isNotEmpty).join(', ');

            final license = (d['licenseNumber'] ?? '').toString().trim();
            final capacity = _capacityLabel(d['capacity']);
            final languages = ((d['languages'] as List?) ?? const [])
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .join(', ');
            final hours = (d['hours'] ?? '').toString().trim();
            final providerType =
                (d['providerType'] ?? d['daycareType'] ?? 'Daycare')
                    .toString()
                    .trim();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    _TopHeader(
                      name: name,
                      city: city,
                      state: state,
                      zip: zip,
                      providerType: providerType,
                      capacity: capacity,
                    ),
                    const SizedBox(height: 14),
                    _HeroGallery(
                      photos: photos,
                      onTapPhoto: (index) =>
                          _openGalleryLightbox(photos, index),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 980;
                        final left = _buildMainColumn(
                          context,
                          name: name,
                          desc: desc,
                          logoUrl: logoUrl,
                          providerType: providerType,
                          capacity: capacity,
                          languages: languages,
                        );
                        final right = _buildSideColumn(
                          context,
                          daycareName: name,
                          email: email,
                          phone: phone,
                          address: address,
                          website: _pickWebsite(d),
                          hours: hours,
                          providerType: providerType,
                          license: license,
                          ageLabel: _ageLabel(d),
                        );

                        if (!wide) {
                          return Column(
                            children: [left, const SizedBox(height: 14), right],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: left),
                            const SizedBox(width: 14),
                            Expanded(flex: 4, child: right),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMainColumn(
    BuildContext context, {
    required String name,
    required String desc,
    required String logoUrl,
    required String providerType,
    required String capacity,
    required String languages,
  }) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LogoAvatar(url: logoUrl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Tag(
                                label: providerType.isEmpty
                                    ? 'Daycare'
                                    : providerType,
                              ),
                              if (capacity.isNotEmpty) _Tag(label: capacity),
                              if (languages.isNotEmpty) _Tag(label: languages),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _TabHeader(),
                const SizedBox(height: 14),
                Text(
                  'About $name',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  desc.isEmpty
                      ? 'This daycare has not added a public description yet.'
                      : desc,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Program Snapshot',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _FactsGrid(
                  facts: [
                    _Fact(
                      label: 'Provider Type',
                      value: providerType.isEmpty ? 'Daycare' : providerType,
                    ),
                    _Fact(
                      label: 'Capacity',
                      value: capacity.isEmpty ? 'N/A' : capacity,
                    ),
                    _Fact(
                      label: 'Languages',
                      value: languages.isEmpty ? 'N/A' : languages,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parent Reviews',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'No reviews yet. Be the first family to share feedback.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: null,
                    child: const Text('Reviews Coming Soon'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideColumn(
    BuildContext context, {
    required String daycareName,
    required String email,
    required String phone,
    required String address,
    required String website,
    required String hours,
    required String providerType,
    required String license,
    required String ageLabel,
  }) {
    final addressHref = address.isEmpty
        ? null
        : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    final phoneDigits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final phoneHref = phoneDigits.isEmpty ? null : 'tel:$phoneDigits';
    final emailHref = email.isEmpty
        ? null
        : _buildMailtoUri(
            to: email,
            subject: 'Website inquiry for $daycareName',
            body:
                'Hi $daycareName,\n\nI would like more information about your daycare.\n',
          ).toString();
    final websiteValue = website.trim();
    final websiteHref = websiteValue.isEmpty
        ? null
        : (websiteValue.startsWith('http')
              ? websiteValue
              : 'https://$websiteValue');

    return Column(
      children: [
        Card(
          color: const Color(0xFFE8F6EA),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Openings Available',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
                ),
                SizedBox(height: 6),
                Text(
                  'Please contact us for enrollment details and current availability.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daycareName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (address.isNotEmpty)
                  _ActionRow(
                    icon: Icons.location_on_outlined,
                    text: address,
                    href: addressHref,
                    onTap: () => _openAddress(address),
                  ),
                if (phone.isNotEmpty)
                  _ActionRow(
                    icon: Icons.call_outlined,
                    text: phone,
                    href: phoneHref,
                    onTap: () => _openPhone(phone),
                  ),
                if (email.isNotEmpty)
                  _ActionRow(
                    icon: Icons.mail_outline,
                    text: email,
                    href: emailHref,
                    onTap: () => _openEmail(
                      to: email,
                      subject: 'Website inquiry for $daycareName',
                      body:
                          'Hi $daycareName,\n\nI would like more information about your daycare.\n',
                    ),
                  ),
                if (website.isNotEmpty)
                  _ActionRow(
                    icon: Icons.language,
                    text: 'Visit website',
                    href: websiteHref,
                    onTap: () => _openWebsite(website),
                  ),
                const Divider(height: 22),
                _MiniDetail(
                  title: 'Hours & Availability',
                  value: hours.isEmpty
                      ? 'Please contact for current schedule.'
                      : hours,
                ),
                _MiniDetail(
                  title: 'Ages',
                  value: ageLabel.isEmpty ? 'N/A' : ageLabel,
                ),
                _MiniDetail(
                  title: 'Provider Type',
                  value: providerType.isEmpty ? 'Daycare' : providerType,
                ),
                _MiniDetail(
                  title: 'License Number',
                  value: license.isEmpty ? 'N/A' : license,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          key: const ValueKey('request_form_card'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _contactFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Information',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your family so we can help connect you with the best care options.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Please enter your name'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contactEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Your Email',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (v) {
                      final x = (v ?? '').trim();
                      if (x.isEmpty) return 'Please enter your email';
                      if (!x.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contactZipCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ZIP Code Looking for Care',
                      prefixIcon: Icon(Icons.location_pin),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contactPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _UsPhoneFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Your Phone Number',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      final ok = RegExp(r'^\d{3}-\d{3}-\d{4}$').hasMatch(value);
                      if (!ok) return 'Use format 123-456-7890';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contactChildBirthdayCtrl,
                    keyboardType: TextInputType.datetime,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _UsDateFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: "Child's Birthday (optional)",
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return null;
                      final m = RegExp(
                        r'^(\d{2})/(\d{2})/(\d{4})$',
                      ).firstMatch(value);
                      if (m == null) return 'Use format MM/DD/YYYY';
                      final month = int.parse(m.group(1)!);
                      final day = int.parse(m.group(2)!);
                      final year = int.parse(m.group(3)!);
                      final dt = DateTime.tryParse(
                        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
                      );
                      if (dt == null ||
                          dt.month != month ||
                          dt.day != day ||
                          dt.year != year) {
                        return 'Enter a valid date (MM/DD/YYYY)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contactMessageCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.message_outlined),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Please enter a message'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _sendRequestInformation(
                        daycareName: daycareName,
                        targetEmail: email,
                        address: address,
                      ),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Request Information'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddress(String address) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    await _launchWithFallback(
      uri,
      fallbackText: address,
      errorMessage: 'Could not open maps. Address copied to clipboard.',
    );
  }

  Future<void> _openPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: digits);
    await _launchWithFallback(
      uri,
      fallbackText: phone,
      errorMessage: 'Could not open dialer. Phone copied to clipboard.',
    );
  }

  Future<void> _openWebsite(String website) async {
    final value = website.trim();
    if (value.isEmpty) return;
    final uri = Uri.tryParse(
      value.startsWith('http') ? value : 'https://$value',
    );
    if (uri == null) return;
    await _launchWithFallback(
      uri,
      fallbackText: website,
      errorMessage: 'Could not open website. URL copied to clipboard.',
    );
  }

  Future<void> _openEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    final uri = _buildMailtoUri(to: to, subject: subject, body: body);
    await _launchWithFallback(
      uri,
      fallbackText: to,
      errorMessage: 'Could not open email client. Email copied to clipboard.',
    );
  }

  Uri _buildMailtoUri({
    required String to,
    required String subject,
    required String body,
  }) {
    final encodedSubject = Uri.encodeComponent(subject).replaceAll('+', '%20');
    final encodedBody = Uri.encodeComponent(body).replaceAll('+', '%20');
    return Uri.parse(
      'mailto:${to.trim()}?subject=$encodedSubject&body=$encodedBody',
    );
  }

  Future<void> _launchWithFallback(
    Uri uri, {
    required String errorMessage,
    String? fallbackText,
  }) async {
    final scheme = uri.scheme.toLowerCase();
    bool ok = false;
    final attempts = <_LaunchAttempt>[
      const _LaunchAttempt(mode: LaunchMode.platformDefault),
      const _LaunchAttempt(
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      ),
      const _LaunchAttempt(
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      ),
      const _LaunchAttempt(
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      ),
      const _LaunchAttempt(mode: LaunchMode.externalApplication),
      const _LaunchAttempt(mode: LaunchMode.externalNonBrowserApplication),
    ];
    for (final attempt in attempts) {
      ok = await _tryLaunch(
        uri,
        mode: attempt.mode,
        webOnlyWindowName: attempt.webOnlyWindowName,
      );
      if (ok) break;
    }

    if (ok || !mounted) return;

    if (fallbackText != null && fallbackText.trim().isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: fallbackText));
    }
    if (kIsWeb && (scheme == 'tel' || scheme == 'mailto')) {
      _showNotice('$errorMessage Browser/OS app handler not configured.');
      return;
    }
    _showNotice(errorMessage);
  }

  Future<bool> _tryLaunch(
    Uri uri, {
    required LaunchMode mode,
    String? webOnlyWindowName,
  }) async {
    try {
      return await launchUrl(
        uri,
        mode: mode,
        webOnlyWindowName: webOnlyWindowName,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendRequestInformation({
    required String daycareName,
    required String targetEmail,
    required String address,
  }) async {
    if (!(_contactFormKey.currentState?.validate() ?? false)) {
      _showNotice('Please complete your name and email before sending.');
      return;
    }
    if (targetEmail.trim().isEmpty) {
      _showNotice('This daycare does not have a public email yet.');
      return;
    }

    final senderName = _contactNameCtrl.text.trim();
    final senderEmail = _contactEmailCtrl.text.trim();
    final zip = _contactZipCtrl.text.trim();
    final phone = _contactPhoneCtrl.text.trim();
    final childBirthday = _contactChildBirthdayCtrl.text.trim();
    final message = _contactMessageCtrl.text.trim();

    final body =
        '''
Hi $daycareName,

$message

Family Details:
- Name: $senderName
- Email: $senderEmail
- Phone: ${phone.isEmpty ? 'Not provided' : phone}
- ZIP Code: ${zip.isEmpty ? 'Not provided' : zip}
- Child Birthday: ${childBirthday.isEmpty ? 'Not provided' : childBirthday}
- Address of Interest: ${address.isEmpty ? 'Not provided' : address}

Best regards,
$senderName
''';

    await _openEmail(
      to: targetEmail,
      subject: 'Request information from $senderName',
      body: body,
    );
  }

  Future<void> _openGalleryLightbox(
    List<String> galleryUrls,
    int initialIndex,
  ) async {
    if (galleryUrls.isEmpty) return;
    final controller = PageController(initialPage: initialIndex);
    var current = initialIndex;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(220),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(20),
              backgroundColor: Colors.transparent,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.black,
                      child: Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              controller: controller,
                              itemCount: galleryUrls.length,
                              onPageChanged: (i) =>
                                  setLocalState(() => current = i),
                              itemBuilder: (context, index) {
                                final url = galleryUrls[index];
                                return InteractiveViewer(
                                  minScale: 1,
                                  maxScale: 4,
                                  child: Center(
                                    child: SmartNetworkImage(
                                      urls: candidateImageUrls(url),
                                      fit: BoxFit.contain,
                                      placeholder: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                      fallback: const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            color: const Color(0xCC000000),
                            child: Text(
                              'Photo ${current + 1} of ${galleryUrls.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNotice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _LaunchAttempt {
  const _LaunchAttempt({required this.mode, this.webOnlyWindowName});
  final LaunchMode mode;
  final String? webOnlyWindowName;
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.name,
    required this.city,
    required this.state,
    required this.zip,
    required this.providerType,
    required this.capacity,
  });

  final String name;
  final String city;
  final String state;
  final String zip;
  final String providerType;
  final String capacity;

  @override
  Widget build(BuildContext context) {
    final location = [
      city,
      state,
      zip,
    ].where((e) => e.trim().isNotEmpty).join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F3DF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Verified',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(location, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (providerType.isNotEmpty) _Tag(label: providerType),
                if (capacity.isNotEmpty) _Tag(label: capacity),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({required this.photos, required this.onTapPhoto});

  final List<String> photos;
  final ValueChanged<int> onTapPhoto;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 320,
          child: _imageFallback(
            context,
            icon: Icons.photo_size_select_actual_outlined,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 960;
        if (!wide || photos.length == 1) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 360,
              child: InkWell(
                onTap: () => onTapPhoto(0),
                child: SmartNetworkImage(
                  urls: candidateImageUrls(photos.first),
                  fit: BoxFit.cover,
                  placeholder: _imageLoading(context),
                  fallback: _imageFallback(
                    context,
                    icon: Icons.broken_image_outlined,
                  ),
                ),
              ),
            ),
          );
        }

        final sidePhotos = photos.skip(1).take(4).toList();
        return SizedBox(
          height: 430,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => onTapPhoto(0),
                    child: SmartNetworkImage(
                      urls: candidateImageUrls(photos.first),
                      fit: BoxFit.cover,
                      placeholder: _imageLoading(context),
                      fallback: _imageFallback(
                        context,
                        icon: Icons.broken_image_outlined,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sidePhotos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, i) {
                    final absoluteIndex = i + 1;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => onTapPhoto(absoluteIndex),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            SmartNetworkImage(
                              urls: candidateImageUrls(sidePhotos[i]),
                              fit: BoxFit.cover,
                              placeholder: _imageLoading(context),
                              fallback: _imageFallback(
                                context,
                                icon: Icons.broken_image_outlined,
                              ),
                            ),
                            if (i == sidePhotos.length - 1 && photos.length > 5)
                              Container(
                                color: Colors.black.withAlpha(110),
                                alignment: Alignment.center,
                                child: Text(
                                  '+${photos.length - 5} Photos',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          _TabItem(label: 'Overview', active: true),
          _TabItem(label: 'Programs'),
          _TabItem(label: 'Reviews'),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, this.active = false});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FactsGrid extends StatelessWidget {
  const _FactsGrid({required this.facts});
  final List<_Fact> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 620 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: facts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 3.2,
          ),
          itemBuilder: (context, i) {
            final fact = facts[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    fact.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fact.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Fact {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;
}

class _MiniDetail extends StatelessWidget {
  const _MiniDetail({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.text,
    required this.onTap,
    this.href,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final String? href;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final link = href?.trim();
          if (kIsWeb && link != null && link.isNotEmpty) {
            final opened = openWebLinkSelf(link);
            if (opened) return;
          }
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 68,
        height: 68,
        child: url.isEmpty
            ? _imageFallback(context, icon: Icons.school_rounded)
            : SmartNetworkImage(
                urls: candidateImageUrls(url),
                fit: BoxFit.cover,
                placeholder: _imageLoading(context),
                fallback: _imageFallback(context, icon: Icons.school_rounded),
              ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _UsPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 10 ? digits.substring(0, 10) : digits;
    final b = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i == 3 || i == 6) b.write('-');
      b.write(trimmed[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _UsDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 8 ? digits.substring(0, 8) : digits;
    final b = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(trimmed[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String _phoneFromDoc(Map<String, dynamic> d) {
  final area = (d['phoneAreaCode'] ?? '').toString().trim();
  final number = (d['phoneNumber'] ?? '').toString().trim();
  if (number.isEmpty) return '';
  return area.isEmpty ? number : '($area) $number';
}

String _pickWebsite(Map<String, dynamic> d) {
  final candidates = [d['websiteUrl'], d['website'], d['siteUrl']];
  for (final c in candidates) {
    final value = (c ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _capacityLabel(dynamic raw) {
  if (raw == null) return '';
  if (raw is int) return 'Capacity $raw';
  if (raw is double) return 'Capacity ${raw.toInt()}';
  final value = raw.toString().trim();
  if (value.isEmpty) return '';
  return 'Capacity $value';
}

String _ageLabel(Map<String, dynamic> d) {
  final direct = (d['ageRange'] ?? '').toString().trim();
  if (direct.isNotEmpty) return direct;

  final min = (d['minAge'] ?? '').toString().trim();
  final max = (d['maxAge'] ?? '').toString().trim();
  if (min.isNotEmpty || max.isNotEmpty) {
    return '$min - $max'.trim();
  }
  return '';
}

Widget _imageLoading(BuildContext context) {
  return Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}

Widget _imageFallback(BuildContext context, {required IconData icon}) {
  return Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: Icon(icon),
  );
}
