import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/location_text.dart';
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
  final licenseCtrl = TextEditingController();
  final languageCtrl = TextEditingController();
  final capacityCtrl = TextEditingController();

  String state2 = 'CT';

  @override
  void initState() {
    super.initState();
    svc = DaycareDirectoryService(FirebaseFirestore.instance);

    nameCtrl.text = widget.query['name'] ?? '';
    cityCtrl.text = normalizeCity(widget.query['city'] ?? '');
    state2 = normalizeStateCode(widget.query['state'] ?? 'CT');
    licenseCtrl.text = widget.query['license'] ?? '';
    languageCtrl.text = widget.query['language'] ?? '';
    capacityCtrl.text = widget.query['capacity'] ?? '';

    _runSearch();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    cityCtrl.dispose();
    licenseCtrl.dispose();
    languageCtrl.dispose();
    capacityCtrl.dispose();
    super.dispose();
  }

  void _runSearch() {
    final minCap = int.tryParse(capacityCtrl.text.trim());
    final filters = DaycareSearchFilters(
      name: nameCtrl.text,
      city: cityCtrl.text,
      state: state2,
      language: languageCtrl.text,
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
    final state = normalizeStateCode(state2);
    if (state.isNotEmpty) qp['state'] = state;
    if (languageCtrl.text.trim().isNotEmpty) qp['language'] = languageCtrl.text.trim();
    if (licenseCtrl.text.trim().isNotEmpty) qp['license'] = licenseCtrl.text.trim();
    if (capacityCtrl.text.trim().isNotEmpty) qp['capacity'] = capacityCtrl.text.trim();
    context.go(Uri(path: '/search', queryParameters: qp).toString());
  }

  @override
  Widget build(BuildContext context) {
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFEDF3), Color(0xFFFFF8FB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(
                  'Use filters to quickly find the best daycare fit for your family.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _FiltersCard(
                nameCtrl: nameCtrl,
                cityCtrl: cityCtrl,
                state2: state2,
                onStateChanged: (v) => setState(() => state2 = v),
                languageCtrl: languageCtrl,
                licenseCtrl: licenseCtrl,
                capacityCtrl: capacityCtrl,
                onSearch: () {
                  _applyToUrl();
                  _runSearch();
                },
                onClear: () {
                  nameCtrl.clear();
                  cityCtrl.clear();
                  licenseCtrl.clear();
                  languageCtrl.clear();
                  capacityCtrl.clear();
                  setState(() => state2 = 'CT');
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
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No results found. Try different filters.'),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${items.length} results', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      ...items.map((x) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DaycareCard(
                              item: x,
                              onTap: () => context.go('/daycare/${x.effectiveSlug}'),
                            ),
                          )),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.nameCtrl,
    required this.cityCtrl,
    required this.state2,
    required this.onStateChanged,
    required this.languageCtrl,
    required this.licenseCtrl,
    required this.capacityCtrl,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController nameCtrl;
  final TextEditingController cityCtrl;
  final String state2;
  final ValueChanged<String> onStateChanged;
  final TextEditingController languageCtrl;
  final TextEditingController licenseCtrl;
  final TextEditingController capacityCtrl;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    initialValue: state2,
                    decoration: const InputDecoration(labelText: 'State'),
                    items: const [
                      DropdownMenuItem(value: 'CT', child: Text('CT')),
                      DropdownMenuItem(value: 'NY', child: Text('NY')),
                      DropdownMenuItem(value: 'NJ', child: Text('NJ')),
                      DropdownMenuItem(value: 'MA', child: Text('MA')),
                      DropdownMenuItem(value: 'PA', child: Text('PA')),
                      DropdownMenuItem(value: 'RI', child: Text('RI')),
                      DropdownMenuItem(value: 'VT', child: Text('VT')),
                      DropdownMenuItem(value: 'NH', child: Text('NH')),
                    ],
                    onChanged: (v) => onStateChanged((v ?? 'CT').toUpperCase()),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: languageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      hintText: 'Spanish, English...',
                      prefixIcon: Icon(Icons.language_outlined),
                    ),
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
                ),
                const SizedBox(width: 10),
                OutlinedButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
