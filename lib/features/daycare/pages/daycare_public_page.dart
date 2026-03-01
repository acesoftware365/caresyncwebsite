import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/image_url.dart';
import '../../../services/location_text.dart';
import '../../../services/analytics/analytics_event_logger.dart';
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
  String? _lastTrackedTenantId;

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
            final email = ((d['businessEmail'] ?? d['email']) ?? '')
                .toString()
                .trim();
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
            final languages = _joinList(
              _stringListFromDoc(d, listKey: 'languagesList', fallbackKey: 'languages'),
            );
            final availability = _joinList(
              _stringListFromDoc(
                d,
                listKey: 'availabilityList',
                fallbackKey: 'availability',
              ),
            );
            final hours = _hoursFromDoc(d);
            final programsOffered = (d['programsOffered'] ?? '').toString().trim();
            final certifications = (d['certifications'] ?? '').toString().trim();
            final trainings = (d['trainings'] ?? '').toString().trim();
            final ownerName = (d['ownerName'] ?? '').toString().trim();
            final providerType =
                (d['providerType'] ?? d['daycareType'] ?? 'Daycare')
                    .toString()
                    .trim();
            final paletteId = (d['websitePalette'] ?? 'sunset').toString().trim();
            final palette =
                _websitePalettes[paletteId] ?? _websitePalettes.values.first;
            final showAddress = _boolFromDoc(d, 'websiteShowAddress', fallback: true);
            final showEmail = _boolFromDoc(d, 'websiteShowEmail', fallback: true);
            final showPhone = _boolFromDoc(d, 'websiteShowPhone', fallback: true);
            final showOwner = _boolFromDoc(d, 'websiteShowOwner', fallback: true);
            final showHours = _boolFromDoc(d, 'websiteShowHours', fallback: true);
            final showPrograms = _boolFromDoc(
              d,
              'websiteShowPrograms',
              fallback: true,
            );
            final showLanguages = _boolFromDoc(
              d,
              'websiteShowLanguages',
              fallback: true,
            );
            final showCapacity = _boolFromDoc(
              d,
              'websiteShowCapacity',
              fallback: true,
            );
            final showCertifications = _boolFromDoc(
              d,
              'websiteShowCertifications',
              fallback: true,
            );
            final showTrainings = _boolFromDoc(
              d,
              'websiteShowTrainings',
              fallback: true,
            );
            final showParentReviews = _boolFromDoc(
              d,
              'websiteShowParentReviews',
              fallback: true,
            );
            final showShareButton = _boolFromDoc(
              d,
              'websiteShowShareButton',
              fallback: true,
            );
            final instagramUrl = (d['websiteInstagramUrl'] ?? '').toString().trim();
            final tikTokUrl = (d['websiteTikTokUrl'] ?? '').toString().trim();
            final websiteUrl = _pickWebsite(d);
            final daycareSlugRaw = (d['websiteSlug'] ?? d['slug'] ?? widget.slug)
                .toString()
                .trim();
            final daycarePublicUrl = daycareSlugRaw.isEmpty
                ? 'https://daycarefinder.web.app'
                : 'https://daycarefinder.web.app/#/daycare/${Uri.encodeComponent(daycareSlugRaw)}';
            final ownerMessage = _ownerMessageText(
              raw: (d['websiteOwnerMessage'] ?? '').toString().trim(),
              ownerName: ownerName,
              businessName: name,
              showOwner: showOwner,
            );
            if (_lastTrackedTenantId != tenantId) {
              _lastTrackedTenantId = tenantId;
              AnalyticsEventLogger.log(
                eventType: 'page_view_daycare',
                pageType: 'tenant',
                tenantId: tenantId,
                slug: widget.slug,
                data: {
                  'name': name,
                  'city': city,
                  'state': state,
                },
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.sixty.withAlpha(145),
                    border: Border.all(color: palette.thirty.withAlpha(170)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                    _TopHeader(
                      name: name,
                      city: city,
                      state: state,
                      zip: zip,
                      palette: palette,
                      showShareButton: showShareButton,
                      onShareWebsite: () {
                        AnalyticsEventLogger.log(
                          eventType: 'click_share_daycare_button',
                          pageType: 'tenant',
                          tenantId: tenantId,
                          slug: widget.slug,
                        );
                        _openShareOptionsSheet(
                          context,
                          url: daycarePublicUrl,
                          title: name,
                        );
                      },
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
                            programsOffered: programsOffered,
                            certifications: certifications,
                            trainings: trainings,
                            showPrograms: showPrograms,
                            showLanguages: showLanguages,
                            showCapacity: showCapacity,
                            showCertifications: showCertifications,
                            showTrainings: showTrainings,
                            showParentReviews: showParentReviews,
                            ownerMessage: ownerMessage,
                            palette: palette,
                          );
                          final right = _buildSideColumn(
                            context,
                            tenantId: tenantId,
                            daycareName: name,
                            email: email,
                            phone: phone,
                            address: address,
                            website: websiteUrl,
                            instagramUrl: instagramUrl,
                            tikTokUrl: tikTokUrl,
                            ownerName: ownerName,
                            showAddress: showAddress,
                            showEmail: showEmail,
                            showPhone: showPhone,
                            showOwner: showOwner,
                            showHours: showHours,
                            hours: hours,
                            availability: availability,
                            providerType: providerType,
                            license: license,
                            ageLabel: _ageLabel(d, availability: availability),
                            establishedAt: _establishedFromDoc(d),
                            palette: palette,
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
    required String programsOffered,
    required String certifications,
    required String trainings,
    required bool showPrograms,
    required bool showLanguages,
    required bool showCapacity,
    required bool showCertifications,
    required bool showTrainings,
    required bool showParentReviews,
    required String ownerMessage,
    required _WebsitePalette palette,
  }) {
    final facts = <_Fact>[
      _Fact(
        label: 'Provider Type',
        value: providerType.isEmpty ? 'Daycare' : providerType,
      ),
      if (showCapacity)
        _Fact(label: 'Capacity', value: capacity.isEmpty ? 'N/A' : capacity),
      if (showLanguages)
        _Fact(label: 'Languages', value: languages.isEmpty ? 'N/A' : languages),
      if (showPrograms)
        _Fact(
          label: 'Programs',
          value: programsOffered.isEmpty ? 'N/A' : programsOffered,
        ),
      if (showCertifications)
        _Fact(
          label: 'Certifications',
          value: certifications.isEmpty ? 'N/A' : certifications,
        ),
      if (showTrainings)
        _Fact(label: 'Trainings', value: trainings.isEmpty ? 'N/A' : trainings),
    ];

    return Column(
      children: [
        Card(
          color: Colors.white.withAlpha(235),
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
                                palette: palette,
                              ),
                              if (capacity.isNotEmpty)
                                _Tag(label: capacity, palette: palette),
                              if (languages.isNotEmpty)
                                _Tag(label: languages, palette: palette),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _TabHeader(palette: palette),
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
          color: Colors.white.withAlpha(235),
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
                _FactsGrid(facts: facts, palette: palette),
              ],
            ),
          ),
        ),
        if (showParentReviews) ...[
          const SizedBox(height: 14),
          Card(
            color: Colors.white.withAlpha(235),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parent Reviews',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent.withAlpha(210),
                      ),
                      child: const Text('Reviews Coming Soon'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (ownerMessage.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            color: Colors.white.withAlpha(235),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owner Message',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(ownerMessage, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSideColumn(
    BuildContext context, {
    required String tenantId,
    required String daycareName,
    required String email,
    required String phone,
    required String address,
    required String website,
    required String instagramUrl,
    required String tikTokUrl,
    required String ownerName,
    required bool showAddress,
    required bool showEmail,
    required bool showPhone,
    required bool showOwner,
    required bool showHours,
    required String hours,
    required String availability,
    required String providerType,
    required String license,
    required String ageLabel,
    required String establishedAt,
    required _WebsitePalette palette,
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
    final instagramHref = _toWebUrlOrEmpty(instagramUrl);
    final tikTokHref = _toWebUrlOrEmpty(tikTokUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: palette.thirty.withAlpha(90),
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
          color: Colors.white.withAlpha(235),
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
                if (showOwner && ownerName.isNotEmpty)
                  _ActionRow(
                    icon: Icons.person_outline,
                    text: ownerName,
                    onTap: () {},
                  ),
                if (showAddress && address.isNotEmpty)
                  _ActionRow(
                    icon: Icons.location_on_outlined,
                    text: address,
                    href: addressHref,
                    onTap: () => _openAddress(address),
                  ),
                if (website.isNotEmpty)
                  _ActionRow(
                    icon: Icons.language,
                    text: 'Visit website',
                    href: websiteHref,
                    onTap: () => _openWebsite(website),
                  ),
                if (tikTokHref.isNotEmpty)
                  _ActionRow(
                    icon: Icons.music_note_outlined,
                    text: tikTokHref,
                    href: tikTokHref,
                    onTap: () => _openWebsite(tikTokHref),
                  ),
                if (instagramHref.isNotEmpty)
                  _ActionRow(
                    icon: Icons.camera_alt_outlined,
                    text: instagramHref,
                    href: instagramHref,
                    onTap: () => _openWebsite(instagramHref),
                  ),
                if (showPhone && phone.isNotEmpty)
                  _ActionRow(
                    icon: Icons.call_outlined,
                    text: phone,
                    href: phoneHref,
                    onTap: () => _openPhone(phone),
                  ),
                if (showEmail && email.isNotEmpty)
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
                const Divider(height: 22),
                if (showHours)
                  _MiniDetail(
                    title: 'Hours',
                    value: hours.isEmpty
                        ? 'Please contact for current schedule.'
                        : hours,
                  ),
                _MiniDetail(
                  title: 'Ages',
                  value: ageLabel.isEmpty ? 'N/A' : ageLabel,
                ),
                _MiniDetail(
                  title: 'Established',
                  value: establishedAt.isEmpty ? 'N/A' : establishedAt,
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
          color: Colors.white.withAlpha(235),
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
                    decoration: _contactInputDecoration(
                      labelText: 'Your Name',
                      prefixIcon: Icons.person_outline,
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Please enter your name'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contactEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _contactInputDecoration(
                      labelText: 'Your Email',
                      prefixIcon: Icons.alternate_email,
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
                    decoration: _contactInputDecoration(
                      labelText: 'ZIP Code Looking for Care',
                      prefixIcon: Icons.location_pin,
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
                    decoration: _contactInputDecoration(
                      labelText: 'Your Phone Number',
                      prefixIcon: Icons.call_outlined,
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
                    decoration: _contactInputDecoration(
                      labelText: "Child's Birthday (optional)",
                      prefixIcon: Icons.cake_outlined,
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
                    decoration: _contactInputDecoration(
                      labelText: 'Message',
                      alignLabelWithHint: true,
                      prefixIcon: Icons.message_outlined,
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
                        tenantId: tenantId,
                        daycareName: daycareName,
                        targetEmail: email,
                        address: address,
                      ),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Request Information'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent.withAlpha(230),
                        foregroundColor: _bestContrastingText(palette.accent),
                      ),
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
    AnalyticsEventLogger.log(
      eventType: 'click_open_address',
      pageType: 'tenant',
      slug: widget.slug,
      data: {'address': address},
    );
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
    AnalyticsEventLogger.log(
      eventType: 'click_open_phone',
      pageType: 'tenant',
      slug: widget.slug,
      data: {'phone': phone},
    );
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
    AnalyticsEventLogger.log(
      eventType: 'click_open_website',
      pageType: 'tenant',
      slug: widget.slug,
      data: {'website': website},
    );
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
    String? cc,
  }) async {
    final uri = _buildMailtoUri(
      to: to,
      subject: subject,
      body: body,
      cc: cc,
    );
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
    String? cc,
  }) {
    final toValue = to.trim();
    final ccValue = (cc ?? '').trim();
    final encodedSubject = Uri.encodeComponent(subject).replaceAll('+', '%20');
    final encodedBody = Uri.encodeComponent(body).replaceAll('+', '%20');
    final query = <String>[
      if (ccValue.isNotEmpty)
        'cc=${Uri.encodeComponent(ccValue).replaceAll('+', '%20')}',
      'subject=$encodedSubject',
      'body=$encodedBody',
    ].join('&');
    return Uri.parse('mailto:$toValue?$query');
  }

  Future<String> _fetchRequestInfoAdminEmail() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('system')
          .doc('global_config')
          .get();
      final data = snap.data() ?? <String, dynamic>{};
      return ((data['requestInfoAdminEmail'] ?? data['globalLeadEmail']) ?? '')
          .toString()
          .trim();
    } catch (_) {
      return '';
    }
  }

  InputDecoration _contactInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    bool alignLabelWithHint = false,
  }) {
    const borderColor = Color(0xFFB8CBD9);
    return InputDecoration(
      labelText: labelText,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF5B7183)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8AAFC7), width: 1.3),
      ),
      isDense: true,
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
    required String tenantId,
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
    final adminEmail = await _fetchRequestInfoAdminEmail();
    final familyEmailForSubject = senderEmail.isEmpty
        ? 'no-family-email'
        : senderEmail;

    final body =
        '''
Hi $daycareName,

$message

Daycare:
- Name: $daycareName
- Daycare ID: $tenantId

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
      cc: adminEmail,
      subject:
          'Request Information - Daycare: $daycareName - Family Email: $familyEmailForSubject',
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

  Future<void> _openShareOptionsSheet(
    BuildContext context, {
    required String url,
    required String title,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    final text = Uri.encodeComponent('Check this daycare: $cleanUrl');
    final smsBody = Uri.encodeComponent('Check this daycare: $cleanUrl');
    final emailSubject = Uri.encodeComponent('Daycare shared with you');
    final emailBody = Uri.encodeComponent('Take a look at this daycare:\n$cleanUrl');

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text('Share $title'),
                subtitle: const Text('Choose where to share this link'),
              ),
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('WhatsApp'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  AnalyticsEventLogger.log(
                    eventType: 'share_daycare_whatsapp',
                    pageType: 'tenant',
                    slug: widget.slug,
                    data: {'url': cleanUrl},
                  );
                  await _launchWithFallback(
                    Uri.parse('https://wa.me/?text=$text'),
                    fallbackText: cleanUrl,
                    errorMessage: 'Could not open WhatsApp. Link copied instead.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: const Text('Text Message'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  AnalyticsEventLogger.log(
                    eventType: 'share_daycare_sms',
                    pageType: 'tenant',
                    slug: widget.slug,
                    data: {'url': cleanUrl},
                  );
                  await _launchWithFallback(
                    Uri.parse('sms:?body=$smsBody'),
                    fallbackText: cleanUrl,
                    errorMessage: 'Could not open text app. Link copied instead.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  AnalyticsEventLogger.log(
                    eventType: 'share_daycare_email',
                    pageType: 'tenant',
                    slug: widget.slug,
                    data: {'url': cleanUrl},
                  );
                  await _launchWithFallback(
                    Uri.parse('mailto:?subject=$emailSubject&body=$emailBody'),
                    fallbackText: cleanUrl,
                    errorMessage: 'Could not open email. Link copied instead.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy Link'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  AnalyticsEventLogger.log(
                    eventType: 'share_daycare_copy',
                    pageType: 'tenant',
                    slug: widget.slug,
                    data: {'url': cleanUrl},
                  );
                  await Clipboard.setData(ClipboardData(text: cleanUrl));
                  _showNotice('Link copied: $cleanUrl');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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
    required this.palette,
    required this.showShareButton,
    required this.onShareWebsite,
  });

  final String name;
  final String city;
  final String state;
  final String zip;
  final _WebsitePalette palette;
  final bool showShareButton;
  final VoidCallback onShareWebsite;

  @override
  Widget build(BuildContext context) {
    final location = [
      city,
      state,
      zip,
    ].where((e) => e.trim().isNotEmpty).join(', ');
    return Card(
      color: Colors.white.withAlpha(235),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
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
                          color: palette.thirty.withAlpha(120),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Verified',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showShareButton) ...[
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onShareWebsite,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Share Website'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.thirty.withAlpha(120),
                      foregroundColor: palette.accent,
                      side: BorderSide(color: palette.accent.withAlpha(95)),
                    ),
                  ),
                ],
              ],
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(location, style: Theme.of(context).textTheme.bodyMedium),
            ],
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
                flex: 7,
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
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sidePhotos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
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
  const _TabHeader({required this.palette});
  final _WebsitePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: palette.thirty.withAlpha(90),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TabItem(label: 'Overview', active: true, palette: palette),
          _TabItem(label: 'Programs', palette: palette),
          _TabItem(label: 'Reviews', palette: palette),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.palette,
    this.active = false,
  });
  final String label;
  final _WebsitePalette palette;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? palette.accent.withAlpha(70) : Colors.white.withAlpha(95),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? palette.accent : null,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FactsGrid extends StatelessWidget {
  const _FactsGrid({required this.facts, required this.palette});
  final List<_Fact> facts;
  final _WebsitePalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 620 ? 2 : 1;
        final itemAspectRatio = cols == 1 ? 5.2 : 3.2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: facts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: itemAspectRatio,
          ),
          itemBuilder: (context, i) {
            final fact = facts[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: palette.thirty.withAlpha(85),
                border: Border.all(color: palette.thirty.withAlpha(130)),
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
              Icon(icon, size: 18, color: const Color(0xFF4B5563)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF374151)),
                ),
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
  const _Tag({required this.label, required this.palette});
  final String label;
  final _WebsitePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: palette.thirty.withAlpha(65),
        border: Border.all(color: palette.thirty.withAlpha(120)),
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
  final candidates = [
    d['websiteExternalUrl'],
    d['websiteUrl'],
    d['website'],
    d['siteUrl'],
  ];
  for (final c in candidates) {
    final value = (c ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

bool _boolFromDoc(Map<String, dynamic> d, String key, {required bool fallback}) {
  final value = d[key];
  if (value is bool) return value;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true') return true;
    if (v == 'false') return false;
  }
  return fallback;
}

List<String> _stringListFromDoc(
  Map<String, dynamic> d, {
  required String listKey,
  required String fallbackKey,
}) {
  final listRaw = d[listKey];
  if (listRaw is List) {
    final out = _sanitizeList(
      listRaw.map((e) => e.toString()).toList(),
    );
    if (out.isNotEmpty) return out;
  }

  final fallback = d[fallbackKey];
  if (fallback is List) {
    return _sanitizeList(
      fallback.map((e) => e.toString()).toList(),
    );
  }

  return _sanitizeList(
    fallback.toString().split(','),
  );
}

String _joinList(List<String> values) => values.join(', ');

List<String> _sanitizeList(List<String> raw) {
  return raw
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .where((e) {
        final v = e.toLowerCase();
        return v != 'null' && v != 'n/a' && v != 'na';
      })
      .toList();
}

String _hoursFromDoc(Map<String, dynamic> d) {
  final startDay = (d['hoursStartDay'] ?? '').toString().trim();
  final endDay = (d['hoursEndDay'] ?? '').toString().trim();
  final opening = _formatHourToAmPm((d['hoursOpeningHour'] ?? '').toString().trim());
  final closing = _formatHourToAmPm((d['hoursClosingHour'] ?? '').toString().trim());
  final hasRange = startDay.isNotEmpty ||
      endDay.isNotEmpty ||
      opening.isNotEmpty ||
      closing.isNotEmpty;
  if (hasRange) {
    final days = [startDay, endDay].where((e) => e.isNotEmpty).join('-');
    final hours = [opening, closing].where((e) => e.isNotEmpty).join('-');
    return [days, hours].where((e) => e.isNotEmpty).join(' ');
  }
  final operating = (d['operatingHours'] ?? '').toString().trim();
  if (operating.isNotEmpty) return operating;
  return (d['hours'] ?? '').toString().trim();
}

String _formatHourToAmPm(String value) {
  final v = value.trim();
  if (v.isEmpty) return '';

  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v);
  if (match == null) return v;

  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return v;
  }

  final suffix = hour >= 12 ? 'PM' : 'AM';
  final hour12 = (hour % 12 == 0) ? 12 : (hour % 12);
  final mm = minute.toString().padLeft(2, '0');
  return '$hour12:$mm $suffix';
}

String _ownerMessageText({
  required String raw,
  required String ownerName,
  required String businessName,
  required bool showOwner,
}) {
  final source = raw.trim();
  if (source.isEmpty) return '';
  final safeName = showOwner && ownerName.isNotEmpty ? ownerName : businessName;
  var out = source.replaceAll('{{name}}', safeName);
  if (ownerName.isNotEmpty) {
    out = out.replaceAll(ownerName, safeName);
  }
  return out.trim();
}

String _toWebUrlOrEmpty(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  return 'https://$text';
}

String _capacityLabel(dynamic raw) {
  if (raw == null) return '';
  if (raw is int) return 'Capacity $raw';
  if (raw is double) return 'Capacity ${raw.toInt()}';
  final value = raw.toString().trim();
  if (value.isEmpty) return '';
  return 'Capacity $value';
}

String _ageLabel(Map<String, dynamic> d, {String availability = ''}) {
  final availabilityValue = availability.trim();
  if (availabilityValue.isNotEmpty) return availabilityValue;

  final direct = (d['ageRange'] ?? '').toString().trim();
  if (direct.isNotEmpty) return direct;

  final min = (d['minAge'] ?? '').toString().trim();
  final max = (d['maxAge'] ?? '').toString().trim();
  if (min.isNotEmpty || max.isNotEmpty) {
    return '$min - $max'.trim();
  }
  return '';
}

String _establishedFromDoc(Map<String, dynamic> d) {
  final primary = (d['establishedAt'] ?? '').toString().trim();
  if (primary.isNotEmpty) return primary;

  final fallback = (d['established'] ?? d['establishedDate'] ?? '')
      .toString()
      .trim();
  return fallback;
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

Color _bestContrastingText(Color background) {
  return background.computeLuminance() > 0.55 ? Colors.black : Colors.white;
}

class _WebsitePalette {
  const _WebsitePalette({
    required this.sixty,
    required this.thirty,
    required this.accent,
  });

  final Color sixty;
  final Color thirty;
  final Color accent;
}

const Map<String, _WebsitePalette> _websitePalettes = {
  'sunset': _WebsitePalette(
    sixty: Color(0xFFF9EFE5),
    thirty: Color(0xFFD9BBA0),
    accent: Color(0xFFB4542D),
  ),
  'coastal': _WebsitePalette(
    sixty: Color(0xFFEAF4F8),
    thirty: Color(0xFFBBD6E3),
    accent: Color(0xFF1E6F8C),
  ),
  'garden': _WebsitePalette(
    sixty: Color(0xFFEEF5EC),
    thirty: Color(0xFFC4D9B8),
    accent: Color(0xFF3F7F4A),
  ),
  'playful': _WebsitePalette(
    sixty: Color(0xFFFFF7E8),
    thirty: Color(0xFFFEDCA7),
    accent: Color(0xFFE07A15),
  ),
  'pink_blush': _WebsitePalette(
    sixty: Color(0xFFFFF0F5),
    thirty: Color(0xFFF8C7D8),
    accent: Color(0xFFD94F82),
  ),
  'pink_pop': _WebsitePalette(
    sixty: Color(0xFFFFF2FA),
    thirty: Color(0xFFF7B2D9),
    accent: Color(0xFFC21875),
  ),
  'american_flag': _WebsitePalette(
    sixty: Color(0xFFF5F8FF),
    thirty: Color(0xFFE3EAFB),
    accent: Color(0xFFB22234),
  ),
  'christmas': _WebsitePalette(
    sixty: Color(0xFFF4FBF5),
    thirty: Color(0xFFD4EED6),
    accent: Color(0xFFC62828),
  ),
  'saint_valentine': _WebsitePalette(
    sixty: Color(0xFFFFF1F6),
    thirty: Color(0xFFFBCADD),
    accent: Color(0xFFE11D48),
  ),
  'saint_patrick': _WebsitePalette(
    sixty: Color(0xFFF2FAF3),
    thirty: Color(0xFFCBECCF),
    accent: Color(0xFF0F8A3B),
  ),
};
