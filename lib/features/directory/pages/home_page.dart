import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/location_text.dart';
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

  final quickCity = TextEditingController();
  String quickState = 'CT';

  @override
  void initState() {
    super.initState();
    svc = DaycareDirectoryService(FirebaseFirestore.instance);
  }

  @override
  void dispose() {
    quickCity.dispose();
    super.dispose();
  }

  void _goSearch({String? state, String? city}) {
    final qp = <String, String>{};
    final st = normalizeStateCode(state ?? quickState);
    if (st.isNotEmpty) qp['state'] = st;
    final c = normalizeCity(city ?? quickCity.text);
    if (c.isNotEmpty) qp['city'] = c;
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
                    colors: [Color(0xFFFFE7EF), Color(0xFFFFF3F8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
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
                  ],
                ),
              ),
              _Hero(
                cityCtrl: quickCity,
                state2: quickState,
                onStateChanged: (v) => setState(() => quickState = v),
                onSearch: () => _goSearch(),
              ),
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
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No featured daycares yet.'),
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 640 ? 2 : 1);
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
                        itemBuilder: (_, i) {
                          final x = items[i];
                          return FeaturedTile(
                            item: x,
                            onTap: () => context.go('/daycare/${x.effectiveSlug}'),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 22),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined),
                      Text('Only daycares with websites ready are listed.'),
                      SizedBox(width: 12),
                      Icon(Icons.palette_outlined),
                      Text('Clean, family-friendly browsing experience.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.cityCtrl,
    required this.state2,
    required this.onStateChanged,
    required this.onSearch,
  });

  final TextEditingController cityCtrl;
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
            const Text('Search by city/state, language, license, and capacity.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 280,
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
                FilledButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
