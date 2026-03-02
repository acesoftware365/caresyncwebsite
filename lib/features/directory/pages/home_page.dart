import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../../services/location_text.dart';
import '../../../services/analytics/analytics_event_logger.dart';
import '../constants/search_options.dart';
import '../models/daycare_public.dart';
import '../services/daycare_directory_service.dart';
import '../widgets/daycare_cards.dart';

class DirectoryHomePage extends StatefulWidget {
  const DirectoryHomePage({super.key});

  @override
  State<DirectoryHomePage> createState() => _DirectoryHomePageState();
}

class _DirectoryHomePageState extends State<DirectoryHomePage> {
  late final DaycareDirectoryService svc;

  final quickName = TextEditingController();
  final quickCity = TextEditingController();
  final quickZip = TextEditingController();
  String quickLanguage = '';
  String quickState = '';

  @override
  void initState() {
    super.initState();
    svc = DaycareDirectoryService(FirebaseFirestore.instance);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsEventLogger.log(
        eventType: 'page_view_home',
        pageType: 'home',
      );
    });
  }

  @override
  void dispose() {
    quickName.dispose();
    quickCity.dispose();
    quickZip.dispose();
    super.dispose();
  }

  void _goSearch({
    String? name,
    String? state,
    String? city,
    String? zip,
    String? language,
  }) {
    final qp = <String, String>{};
    final n = (name ?? quickName.text).trim();
    if (n.isNotEmpty) qp['name'] = n;
    final st = normalizeStateCode(state ?? quickState);
    if (st.isNotEmpty) qp['state'] = st;
    final c = normalizeCity(city ?? quickCity.text);
    if (c.isNotEmpty) qp['city'] = c;
    final z = (zip ?? quickZip.text).trim();
    if (z.isNotEmpty) qp['zip'] = z;
    final l = (language ?? quickLanguage).trim();
    if (l.isNotEmpty) qp['language'] = l;
    AnalyticsEventLogger.log(
      eventType: 'click_home_search',
      pageType: 'home',
      data: {
        'name': n,
        'state': st,
        'city': c,
        'zip': z,
        'language': l,
      },
    );
    context.go(Uri(path: '/search', queryParameters: qp).toString());
  }

  @override
  Widget build(BuildContext context) {
    final cfgStream = FirebaseFirestore.instance
        .doc('system/daycarefinder_config')
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: cfgStream,
      builder: (context, snap) {
        final data = snap.data?.data() ?? <String, dynamic>{};
        final config = _FinderConfig.fromMap(data);
        final palette = _finderPalettes[config.palette] ?? _finderPalettes['blush']!;
        final promos = config.promos.where((e) => e.enabled).toList();

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        palette.sixty,
                        Color.lerp(palette.sixty, palette.thirty, 0.55)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: palette.thirty.withAlpha(170)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final compact = c.maxWidth < 760;
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(210),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.family_restroom_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Discover trusted daycare programs near you.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonalIcon(
                                onPressed: () {
                                  AnalyticsEventLogger.log(
                                    eventType: 'click_share_home_button',
                                    pageType: 'home',
                                  );
                                  _openShareOptionsSheet(
                                    context,
                                    url: 'https://daycarefinder.web.app',
                                    title: 'DaycareFinder',
                                  );
                                },
                                icon: const Icon(Icons.link_rounded, size: 18),
                                label: const Text('Share Home'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white.withAlpha(210),
                                  foregroundColor: palette.accent,
                                  side: BorderSide(
                                    color: palette.accent.withAlpha(90),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(210),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.family_restroom_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Discover trusted daycare programs near you.',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              AnalyticsEventLogger.log(
                                eventType: 'click_share_home_button',
                                pageType: 'home',
                              );
                              _openShareOptionsSheet(
                                context,
                                url: 'https://daycarefinder.web.app',
                                title: 'DaycareFinder',
                              );
                            },
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: const Text('Share Home'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withAlpha(210),
                              foregroundColor: palette.accent,
                              side: BorderSide(
                                color: palette.accent.withAlpha(90),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _Hero(
                  palette: palette,
                  nameCtrl: quickName,
                  cityCtrl: quickCity,
                  zipCtrl: quickZip,
                  language: quickLanguage,
                  onLanguageChanged: (v) => setState(() => quickLanguage = v),
                  state2: quickState,
                  onStateChanged: (v) => setState(() => quickState = v),
                  onSearch: () => _goSearch(),
                ),
                if (promos.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _PromoSection(
                    promos: promos,
                    rotationSeconds: config.promoRotationSeconds,
                    onOpenUrl: _openExternalUrl,
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text('Featured Daycares', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    TextButton(onPressed: () => context.go('/search'), child: const Text('View all')),
                  ],
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<DaycarePublic>>(
                  stream: svc.watchFeatured(limit: 3),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final items = snap.data ?? [];
                    if (items.isEmpty) {
                      return Card(
                        color: palette.sixty.withAlpha(190),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No featured daycares yet.'),
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, c) {
                        final isMobile = c.maxWidth < 640;

                        Widget buildFeaturedTile(DaycarePublic x) {
                          return FeaturedTile(
                            item: x,
                            onTap: () {
                              AnalyticsEventLogger.log(
                                eventType: 'click_featured_daycare',
                                pageType: 'home',
                                tenantId: x.tenantId,
                                slug: x.effectiveSlug,
                                data: {'name': x.name},
                              );
                              context.go('/daycare/${x.effectiveSlug}');
                            },
                          );
                        }

                        if (isMobile) {
                          final cardWidth = c.maxWidth.clamp(220.0, 280.0).toDouble();
                          return SizedBox(
                            height: 230,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              separatorBuilder: (_, index) => const SizedBox(width: 12),
                              itemBuilder: (_, i) => SizedBox(
                                width: cardWidth,
                                child: buildFeaturedTile(items[i]),
                              ),
                            ),
                          );
                        }

                        final cols = c.maxWidth > 900 ? 4 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.35,
                          ),
                          itemBuilder: (_, i) => buildFeaturedTile(items[i]),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 22),
                Card(
                  color: palette.sixty.withAlpha(190),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: palette.accent.withAlpha(220),
                        ),
                        const Text('Only daycares with websites ready are listed.'),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.palette_outlined,
                          color: palette.accent.withAlpha(220),
                        ),
                        const Text('Clean, family-friendly browsing experience.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openExternalUrl(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return;
    final normalized = value.startsWith('http://') || value.startsWith('https://')
        ? value
        : 'https://$value';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  Future<void> _openShareOptionsSheet(
    BuildContext context, {
    required String url,
    required String title,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    final text = Uri.encodeComponent('Check this out: $cleanUrl');
    final smsBody = Uri.encodeComponent('Check this out: $cleanUrl');
    final emailSubject = Uri.encodeComponent('Shared from DaycareFinder');
    final emailBody = Uri.encodeComponent('Take a look:\n$cleanUrl');

    Future<void> launchOrCopy(Uri uri) async {
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok) {
        await Clipboard.setData(ClipboardData(text: cleanUrl));
        if (!mounted) return;
        ScaffoldMessenger.of(
          this.context,
        ).showSnackBar(SnackBar(content: Text('Link copied: $cleanUrl')));
      }
    }

    if (!context.mounted) return;
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
              ),
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('WhatsApp'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  AnalyticsEventLogger.log(
                    eventType: 'share_home_whatsapp',
                    pageType: 'home',
                    data: {'url': cleanUrl},
                  );
                  await launchOrCopy(Uri.parse('https://wa.me/?text=$text'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: const Text('Text Message'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  AnalyticsEventLogger.log(
                    eventType: 'share_home_sms',
                    pageType: 'home',
                    data: {'url': cleanUrl},
                  );
                  await launchOrCopy(Uri.parse('sms:?body=$smsBody'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  AnalyticsEventLogger.log(
                    eventType: 'share_home_email',
                    pageType: 'home',
                    data: {'url': cleanUrl},
                  );
                  await launchOrCopy(
                    Uri.parse('mailto:?subject=$emailSubject&body=$emailBody'),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy Link'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  AnalyticsEventLogger.log(
                    eventType: 'share_home_copy',
                    pageType: 'home',
                    data: {'url': cleanUrl},
                  );
                  await Clipboard.setData(ClipboardData(text: cleanUrl));
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(SnackBar(content: Text('Link copied: $cleanUrl')));
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.palette,
    required this.nameCtrl,
    required this.cityCtrl,
    required this.zipCtrl,
    required this.language,
    required this.onLanguageChanged,
    required this.state2,
    required this.onStateChanged,
    required this.onSearch,
  });

  final _FinderPalette palette;
  final TextEditingController nameCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController zipCtrl;
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final String state2;
  final ValueChanged<String> onStateChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Find the perfect daycare', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Search by name, zip code, city/state, and language.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.sixty.withAlpha(210),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.thirty.withAlpha(210)),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final desktop = c.maxWidth >= 1020;
                  final tablet = c.maxWidth >= 760 && c.maxWidth < 1020;

                  if (desktop) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: _SearchNameField(nameCtrl: nameCtrl)),
                        const SizedBox(width: 10),
                        Expanded(flex: 3, child: _SearchCityField(cityCtrl: cityCtrl)),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: _SearchZipField(zipCtrl: zipCtrl)),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 105,
                          child: _StateField(
                            state2: state2,
                            onStateChanged: onStateChanged,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _LanguageField(
                            value: language,
                            onChanged: onLanguageChanged,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _SearchCtaButton(
                          onSearch: onSearch,
                          palette: palette,
                        ),
                      ],
                    );
                  }

                  if (tablet) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(flex: 3, child: _SearchNameField(nameCtrl: nameCtrl)),
                            const SizedBox(width: 10),
                            Expanded(flex: 3, child: _SearchCityField(cityCtrl: cityCtrl)),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: _SearchZipField(zipCtrl: zipCtrl)),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 105,
                              child: _StateField(
                                state2: state2,
                                onStateChanged: onStateChanged,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _LanguageField(
                                value: language,
                                onChanged: onLanguageChanged,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _SearchCtaButton(
                              onSearch: onSearch,
                              palette: palette,
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _SearchNameField(nameCtrl: nameCtrl),
                      const SizedBox(height: 10),
                      _SearchCityField(cityCtrl: cityCtrl),
                      const SizedBox(height: 10),
                      _SearchZipField(zipCtrl: zipCtrl),
                      const SizedBox(height: 10),
                      _StateField(state2: state2, onStateChanged: onStateChanged),
                      const SizedBox(height: 10),
                      _LanguageField(
                        value: language,
                        onChanged: onLanguageChanged,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Search'),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.accent,
                            foregroundColor: _bestTextOn(palette.accent),
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCtaButton extends StatelessWidget {
  const _SearchCtaButton({required this.onSearch, required this.palette});
  final VoidCallback onSearch;
  final _FinderPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      child: FilledButton.icon(
        onPressed: onSearch,
        icon: const Icon(Icons.search),
        label: const Text('Search'),
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: _bestTextOn(palette.accent),
          minimumSize: const Size.fromHeight(46),
        ),
      ),
    );
  }
}

class _SearchNameField extends StatelessWidget {
  const _SearchNameField({required this.nameCtrl});
  final TextEditingController nameCtrl;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: nameCtrl,
      decoration: _searchInputDecoration(
        labelText: 'Daycare Name',
        icon: Icons.badge_outlined,
      ),
    );
  }
}

class _SearchCityField extends StatelessWidget {
  const _SearchCityField({required this.cityCtrl});
  final TextEditingController cityCtrl;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: cityCtrl,
      decoration: _searchInputDecoration(
        labelText: 'City',
        icon: Icons.location_city_outlined,
      ),
    );
  }
}

class _SearchZipField extends StatelessWidget {
  const _SearchZipField({required this.zipCtrl});
  final TextEditingController zipCtrl;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: zipCtrl,
      keyboardType: TextInputType.number,
      decoration: _searchInputDecoration(
        labelText: 'ZIP Code',
        icon: Icons.pin_drop_outlined,
      ),
    );
  }
}

class _StateField extends StatelessWidget {
  const _StateField({required this.state2, required this.onStateChanged});
  final String state2;
  final ValueChanged<String> onStateChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: state2,
      decoration: _searchInputDecoration(labelText: 'State'),
      items: [
        const DropdownMenuItem(value: '', child: Text('Any State')),
        ...usStateCodes
            .map((code) => DropdownMenuItem(value: code, child: Text(code))),
      ],
      onChanged: (v) => onStateChanged((v ?? '').toUpperCase()),
    );
  }
}

class _LanguageField extends StatelessWidget {
  const _LanguageField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _searchInputDecoration(
        labelText: 'Language',
        icon: Icons.language_outlined,
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Any Language')),
        ...directoryLanguages
            .map((lang) => DropdownMenuItem(value: lang, child: Text(lang))),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}

InputDecoration _searchInputDecoration({
  required String labelText,
  IconData? icon,
}) {
  return InputDecoration(
    labelText: labelText,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    prefixIcon: icon == null ? null : Icon(icon, size: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );
}

class _PromoSection extends StatelessWidget {
  const _PromoSection({
    required this.promos,
    required this.rotationSeconds,
    required this.onOpenUrl,
  });

  final List<_PromoItem> promos;
  final int rotationSeconds;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final small = promos.where((p) => p.size == 'small').toList();
    final large = promos.where((p) => p.size == 'large').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Highlights', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (large.isNotEmpty) ...[
          Text(
            'Large Carousel',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          _PromoCarousel(
            promos: large,
            rotationSeconds: rotationSeconds,
            large: true,
            onOpenUrl: onOpenUrl,
          ),
          const SizedBox(height: 12),
        ],
        if (small.isNotEmpty) ...[
          Text(
            'Highlights',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          _PromoSmallGrid(
            promos: small,
            onOpenUrl: onOpenUrl,
          ),
        ],
      ],
    );
  }
}

class _PromoSmallGrid extends StatelessWidget {
  const _PromoSmallGrid({
    required this.promos,
    required this.onOpenUrl,
  });

  final List<_PromoItem> promos;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 980
            ? 3
            : (constraints.maxWidth >= 620 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: promos.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.02,
          ),
          itemBuilder: (context, i) {
            final p = promos[i];
            return _PromoCardTile(
              promo: p,
              large: false,
              onOpenUrl: onOpenUrl,
            );
          },
        );
      },
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel({
    required this.promos,
    required this.rotationSeconds,
    required this.large,
    required this.onOpenUrl,
  });

  final List<_PromoItem> promos;
  final int rotationSeconds;
  final bool large;
  final ValueChanged<String> onOpenUrl;

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _PromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotationSeconds != widget.rotationSeconds ||
        oldWidget.promos.length != widget.promos.length) {
      _timer?.cancel();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (widget.promos.length <= 1) return;
    final secs = widget.rotationSeconds.clamp(1, 120);
    _timer = Timer.periodic(Duration(seconds: secs), (_) {
      if (_userInteracting) return;
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.promos.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  void _setInteraction(bool value) {
    if (_userInteracting == value) return;
    setState(() => _userInteracting = value);
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.large ? 340.0 : 240.0;
    return Column(
      children: [
        MouseRegion(
          onEnter: (_) => _setInteraction(true),
          onExit: (_) => _setInteraction(false),
          child: GestureDetector(
            onPanDown: (_) => _setInteraction(true),
            onPanEnd: (_) => _setInteraction(false),
            onPanCancel: () => _setInteraction(false),
            onTapDown: (_) => _setInteraction(true),
            onTapUp: (_) => _setInteraction(false),
            onTapCancel: () => _setInteraction(false),
            child: SizedBox(
              height: height,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _setInteraction(true);
                  } else if (notification is ScrollEndNotification) {
                    _setInteraction(false);
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.promos.length,
                  onPageChanged: (v) => setState(() => _index = v),
                  itemBuilder: (context, i) {
                    final p = widget.promos[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _PromoCardTile(
                        promo: p,
                        large: widget.large,
                        onOpenUrl: widget.onOpenUrl,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (widget.promos.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: List.generate(widget.promos.length, (i) {
              final active = i == _index;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  _setInteraction(true);
                  _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                  Future<void>.delayed(
                    const Duration(milliseconds: 320),
                    () {
                      if (mounted) _setInteraction(false);
                    },
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PromoCardTile extends StatelessWidget {
  const _PromoCardTile({
    required this.promo,
    required this.large,
    required this.onOpenUrl,
  });

  final _PromoItem promo;
  final bool large;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: promo.imageUrl.trim().isEmpty
                ? Container(
                    color: const Color(0xFFF6F7F8),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.photo_outlined,
                      size: 36,
                      color: _finderPalettes['slate']!.accent.withAlpha(120),
                    ),
                  )
                : Image.network(
                    promo.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF6F7F8),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _finderPalettes['slate']!.accent.withAlpha(120),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.title.isEmpty ? 'Promotion' : promo.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (promo.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    promo.description,
                    maxLines: large ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (promo.youtubeUrl.trim().isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => onOpenUrl(promo.youtubeUrl),
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        label: const Text('YouTube'),
                      ),
                    if (promo.ctaUrl.trim().isNotEmpty)
                      FilledButton(
                        onPressed: () => onOpenUrl(promo.ctaUrl),
                        child: Text(
                          promo.ctaLabel.trim().isEmpty
                              ? 'Learn More'
                              : promo.ctaLabel,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinderConfig {
  _FinderConfig({
    required this.palette,
    required this.promoRotationSeconds,
    required this.promos,
  });

  final String palette;
  final int promoRotationSeconds;
  final List<_PromoItem> promos;

  factory _FinderConfig.fromMap(Map<String, dynamic> data) {
    final palette = (data['palette'] ?? 'blush').toString().trim();
    final rawSeconds = data['promoRotationSeconds'];
    final parsedSeconds = rawSeconds is int
        ? rawSeconds
        : int.tryParse((rawSeconds ?? '').toString());
    final raw = (data['promos'] as List?) ?? const [];
    final promos = raw
        .whereType<Map>()
        .map((e) => _PromoItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return _FinderConfig(
      palette: palette,
      promoRotationSeconds: (parsedSeconds ?? 5).clamp(1, 120),
      promos: promos,
    );
  }
}

class _PromoItem {
  _PromoItem({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.youtubeUrl,
    required this.ctaLabel,
    required this.ctaUrl,
    required this.size,
    required this.enabled,
  });

  final String title;
  final String description;
  final String imageUrl;
  final String youtubeUrl;
  final String ctaLabel;
  final String ctaUrl;
  final String size;
  final bool enabled;

  factory _PromoItem.fromMap(Map<String, dynamic> data) {
    return _PromoItem(
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      youtubeUrl: (data['youtubeUrl'] ?? '').toString(),
      ctaLabel: (data['ctaLabel'] ?? 'Learn More').toString(),
      ctaUrl: (data['ctaUrl'] ?? '').toString(),
      size: (data['size'] ?? 'small').toString() == 'large' ? 'large' : 'small',
      enabled: (data['enabled'] ?? true) == true,
    );
  }
}

class _FinderPalette {
  const _FinderPalette({
    required this.sixty,
    required this.thirty,
    required this.accent,
  });

  final Color sixty;
  final Color thirty;
  final Color accent;
}

const Map<String, _FinderPalette> _finderPalettes = {
  'blush': _FinderPalette(
    sixty: Color(0xFFFFF0F5),
    thirty: Color(0xFFF8C7D8),
    accent: Color(0xFFD94F82),
  ),
  'coastal': _FinderPalette(
    sixty: Color(0xFFEAF4F8),
    thirty: Color(0xFFBBD6E3),
    accent: Color(0xFF1E6F8C),
  ),
  'sunset': _FinderPalette(
    sixty: Color(0xFFF9EFE5),
    thirty: Color(0xFFD9BBA0),
    accent: Color(0xFFB4542D),
  ),
  'garden': _FinderPalette(
    sixty: Color(0xFFEEF5EC),
    thirty: Color(0xFFC4D9B8),
    accent: Color(0xFF3F7F4A),
  ),
  'lavender': _FinderPalette(
    sixty: Color(0xFFF3F0FF),
    thirty: Color(0xFFD7CCFF),
    accent: Color(0xFF6C4BC8),
  ),
  'sunflower': _FinderPalette(
    sixty: Color(0xFFFFF8E8),
    thirty: Color(0xFFFDE2A4),
    accent: Color(0xFFC27A00),
  ),
  'slate': _FinderPalette(
    sixty: Color(0xFFF1F5F9),
    thirty: Color(0xFFCBD5E1),
    accent: Color(0xFF334155),
  ),
  'american_flag': _FinderPalette(
    sixty: Color(0xFFF5F8FF),
    thirty: Color(0xFFE3EAFB),
    accent: Color(0xFFB22234),
  ),
  'christmas': _FinderPalette(
    sixty: Color(0xFFF4FBF5),
    thirty: Color(0xFFD4EED6),
    accent: Color(0xFFC62828),
  ),
  'saint_valentine': _FinderPalette(
    sixty: Color(0xFFFFF1F6),
    thirty: Color(0xFFFBCADD),
    accent: Color(0xFFE11D48),
  ),
  'saint_patrick': _FinderPalette(
    sixty: Color(0xFFF2FAF3),
    thirty: Color(0xFFCBECCF),
    accent: Color(0xFF0F8A3B),
  ),
};

Color _bestTextOn(Color color) {
  return color.computeLuminance() > 0.55 ? Colors.black : Colors.white;
}
