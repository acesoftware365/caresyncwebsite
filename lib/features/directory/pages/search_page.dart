import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/location_text.dart';
import '../constants/search_options.dart';
import '../models/daycare_public.dart';
import '../services/daycare_directory_service.dart';
import '../widgets/daycare_cards.dart';

class DirectorySearchPage extends StatefulWidget {
  const DirectorySearchPage({super.key, required this.query});
  final Map<String, String> query;

  @override
  State<DirectorySearchPage> createState() => _DirectorySearchPageState();
}

class _DirectorySearchPageState extends State<DirectorySearchPage> {
  late final DaycareDirectoryService svc;
  Stream<List<DaycarePublic>>? resultsStream;

  final nameCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final zipCtrl = TextEditingController();
  final licenseCtrl = TextEditingController();
  final capacityCtrl = TextEditingController();

  String state2 = '';
  String languageValue = '';

  @override
  void initState() {
    super.initState();
    svc = DaycareDirectoryService(FirebaseFirestore.instance);

    nameCtrl.text = widget.query['name'] ?? '';
    cityCtrl.text = normalizeCity(widget.query['city'] ?? '');
    zipCtrl.text = widget.query['zip'] ?? '';
    state2 = normalizeStateCode(widget.query['state'] ?? '');
    licenseCtrl.text = widget.query['license'] ?? '';
    final incomingLanguage = (widget.query['language'] ?? '').trim();
    languageValue = directoryLanguages.contains(incomingLanguage)
        ? incomingLanguage
        : '';
    capacityCtrl.text = widget.query['capacity'] ?? '';

    _runSearch();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    cityCtrl.dispose();
    zipCtrl.dispose();
    licenseCtrl.dispose();
    capacityCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DirectorySearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.toString() == widget.query.toString()) return;

    nameCtrl.text = widget.query['name'] ?? '';
    cityCtrl.text = normalizeCity(widget.query['city'] ?? '');
    zipCtrl.text = widget.query['zip'] ?? '';
    state2 = normalizeStateCode(widget.query['state'] ?? '');
    licenseCtrl.text = widget.query['license'] ?? '';
    final incomingLanguage = (widget.query['language'] ?? '').trim();
    languageValue = directoryLanguages.contains(incomingLanguage)
        ? incomingLanguage
        : '';
    capacityCtrl.text = widget.query['capacity'] ?? '';
    _runSearch();
  }

  void _runSearch() {
    final minCap = int.tryParse(capacityCtrl.text.trim());
    final filters = DaycareSearchFilters(
      name: nameCtrl.text,
      city: cityCtrl.text,
      state: state2,
      zip: zipCtrl.text,
      language: languageValue,
      license: licenseCtrl.text,
      minCapacity: minCap,
    );
    setState(() {
      resultsStream = svc.watchSearch(filters);
    });
  }

  void _applyToUrl() {
    final qp = <String, String>{};
    if (nameCtrl.text.trim().isNotEmpty) qp['name'] = nameCtrl.text.trim();
    final city = normalizeCity(cityCtrl.text);
    if (city.isNotEmpty) qp['city'] = city;
    if (zipCtrl.text.trim().isNotEmpty) qp['zip'] = zipCtrl.text.trim();
    final state = normalizeStateCode(state2);
    if (state.isNotEmpty) qp['state'] = state;
    if (languageValue.trim().isNotEmpty) qp['language'] = languageValue.trim();
    if (licenseCtrl.text.trim().isNotEmpty) {
      qp['license'] = licenseCtrl.text.trim();
    }
    if (capacityCtrl.text.trim().isNotEmpty) {
      qp['capacity'] = capacityCtrl.text.trim();
    }
    context.go(Uri(path: '/search', queryParameters: qp).toString());
  }

  @override
  Widget build(BuildContext context) {
    final cfgStream = FirebaseFirestore.instance
        .doc('system/daycarefinder_config')
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: cfgStream,
      builder: (context, cfgSnap) {
        final paletteId = (cfgSnap.data?.data()?['palette'] ?? 'blush')
            .toString()
            .trim();
        final palette = _finderPalettes[paletteId] ?? _finderPalettes['blush']!;

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
                  child: Text(
                    'Use filters to quickly find the best daycare fit for your family.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _FiltersCard(
                  nameCtrl: nameCtrl,
                  cityCtrl: cityCtrl,
                  zipCtrl: zipCtrl,
                  state2: state2,
                  palette: palette,
                  onStateChanged: (v) => setState(() => state2 = v),
                  languageValue: languageValue,
                  onLanguageChanged: (v) => setState(() => languageValue = v),
                  licenseCtrl: licenseCtrl,
                  capacityCtrl: capacityCtrl,
                  onSearch: () {
                    _applyToUrl();
                    _runSearch();
                  },
                  onClear: () {
                    nameCtrl.clear();
                    cityCtrl.clear();
                    zipCtrl.clear();
                    licenseCtrl.clear();
                    setState(() => languageValue = '');
                    capacityCtrl.clear();
                    setState(() => state2 = '');
                    context.go('/search');
                    _runSearch();
                  },
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<DaycarePublic>>(
                  stream: resultsStream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final items = snap.data ?? const [];
                    if (items.isEmpty) {
                      return Card(
                        color: palette.sixty.withAlpha(185),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No results found. Try different filters.',
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${items.length} results',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        ...items.map(
                          (x) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DaycareCard(
                              item: x,
                              onTap: () =>
                                  context.push('/daycare/${x.effectiveSlug}'),
                            ),
                          ),
                        ),
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
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.nameCtrl,
    required this.cityCtrl,
    required this.zipCtrl,
    required this.state2,
    required this.palette,
    required this.onStateChanged,
    required this.languageValue,
    required this.onLanguageChanged,
    required this.licenseCtrl,
    required this.capacityCtrl,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController nameCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController zipCtrl;
  final String state2;
  final _FinderPalette palette;
  final ValueChanged<String> onStateChanged;
  final String languageValue;
  final ValueChanged<String> onLanguageChanged;
  final TextEditingController licenseCtrl;
  final TextEditingController capacityCtrl;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: palette.sixty.withAlpha(170),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Daycare name',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: zipCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ZIP Code',
                      prefixIcon: Icon(Icons.pin_drop_outlined),
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: state2,
                    decoration: const InputDecoration(labelText: 'State'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Any State'),
                      ),
                      ...usStateCodes.map(
                        (code) =>
                            DropdownMenuItem(value: code, child: Text(code)),
                      ),
                    ],
                    onChanged: (v) => onStateChanged((v ?? '').toUpperCase()),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: languageValue,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      prefixIcon: Icon(Icons.language_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Any Language'),
                      ),
                      ...directoryLanguages.map(
                        (lang) =>
                            DropdownMenuItem(value: lang, child: Text(lang)),
                      ),
                    ],
                    onChanged: (v) => onLanguageChanged(v ?? ''),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: licenseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'License',
                      prefixIcon: Icon(Icons.verified_outlined),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min capacity',
                      prefixIcon: Icon(Icons.groups_2_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: _bestTextOn(palette.accent),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.accent,
                    side: BorderSide(color: palette.thirty.withAlpha(220)),
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
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
