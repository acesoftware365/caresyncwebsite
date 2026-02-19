import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daycare_public.dart';
import '../../../services/location_text.dart';

class DaycareSearchFilters {
  DaycareSearchFilters({
    this.name = '',
    this.city = '',
    this.state = '',
    this.language = '',
    this.license = '',
    this.minCapacity,
  });

  final String name;
  final String city;
  final String state;
  final String language;
  final String license;
  final int? minCapacity;
}

class DaycareDirectoryService {
  DaycareDirectoryService(this.db);
  final FirebaseFirestore db;

  Future<List<DaycarePublic>> search(DaycareSearchFilters f) async {
    final snap = await _baseQuery(f).get();
    return _toFilteredSorted(snap, f);
  }

  Future<List<DaycarePublic>> featured({int limit = 8}) async {
    final snap = await db.collection('tenants').where('websiteReady', isEqualTo: true).limit(limit).get();
    return _toSorted(snap.docs.map((d) => DaycarePublic.fromTenantDoc(d.id, d.data())).toList());
  }

  Stream<List<DaycarePublic>> watchSearch(DaycareSearchFilters f) {
    return _baseQuery(f).snapshots().map((snap) => _toFilteredSorted(snap, f));
  }

  Stream<List<DaycarePublic>> watchFeatured({int limit = 8}) {
    return db
        .collection('tenants')
        .where('websiteReady', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snap) => _toSorted(snap.docs.map((d) => DaycarePublic.fromTenantDoc(d.id, d.data())).toList()));
  }

  Query<Map<String, dynamic>> _baseQuery(DaycareSearchFilters f) {
    Query<Map<String, dynamic>> q = db.collection('tenants').where('websiteReady', isEqualTo: true);
    // Keep the base query broad and apply normalized location filters client-side
    // so the search works even if stored city/state casing is inconsistent.
    return q.limit(80);
  }

  List<DaycarePublic> _toFilteredSorted(
    QuerySnapshot<Map<String, dynamic>> snap,
    DaycareSearchFilters f,
  ) {
    final items = snap.docs.map((d) => DaycarePublic.fromTenantDoc(d.id, d.data())).toList();
    final nameQ = f.name.trim().toLowerCase();
    final langQ = f.language.trim().toLowerCase();
    final licQ = f.license.trim().toLowerCase();
    final minCap = f.minCapacity;
    final cityQ = normalizeCity(f.city);
    final stateQ = normalizeStateCode(f.state);

    var out = items;
    if (cityQ.isNotEmpty) out = out.where((x) => normalizeCity(x.city) == cityQ).toList();
    if (stateQ.isNotEmpty) out = out.where((x) => normalizeStateCode(x.state) == stateQ).toList();
    if (nameQ.isNotEmpty) out = out.where((x) => x.name.toLowerCase().contains(nameQ)).toList();
    if (langQ.isNotEmpty) out = out.where((x) => x.languages.any((l) => l.toLowerCase().contains(langQ))).toList();
    if (licQ.isNotEmpty) out = out.where((x) => x.licenseNumber.toLowerCase().contains(licQ)).toList();
    if (minCap != null && minCap > 0) out = out.where((x) => x.capacity >= minCap).toList();

    return _toSorted(out);
  }

  List<DaycarePublic> _toSorted(List<DaycarePublic> items) {
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }
}
