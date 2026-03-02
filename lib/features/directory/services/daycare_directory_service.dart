import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/daycare_public.dart';
import '../../../services/location_text.dart';

class DaycareSearchFilters {
  DaycareSearchFilters({
    this.name = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.language = '',
    this.license = '',
    this.minCapacity,
  });

  final String name;
  final String city;
  final String state;
  final String zip;
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
    final fetchLimit = (limit * 12).clamp(20, 80);
    final snap = await db
        .collection('tenants')
        .where('websiteReady', isEqualTo: true)
        .limit(fetchLimit)
        .get();
    return _toFeaturedRanked(
      snap.docs.map((d) => DaycarePublic.fromTenantDoc(d.id, d.data())).toList(),
      limit,
    );
  }

  Stream<List<DaycarePublic>> watchSearch(DaycareSearchFilters f) {
    return _baseQuery(f).snapshots().map((snap) => _toFilteredSorted(snap, f));
  }

  Stream<List<DaycarePublic>> watchFeatured({int limit = 8}) {
    final fetchLimit = (limit * 12).clamp(20, 80);
    return db
        .collection('tenants')
        .where('websiteReady', isEqualTo: true)
        .limit(fetchLimit)
        .snapshots()
        .map(
          (snap) => _toFeaturedRanked(
            snap.docs.map((d) => DaycarePublic.fromTenantDoc(d.id, d.data())).toList(),
            limit,
          ),
        );
  }

  Query<Map<String, dynamic>> _baseQuery(DaycareSearchFilters f) {
    Query<Map<String, dynamic>> q =
        db.collection('tenants').where('websiteReady', isEqualTo: true);
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
    final cityQ = normalizeCity(f.city).toLowerCase();
    final stateQ = normalizeStateCode(f.state);
    final zipQ = f.zip.trim();

    var out = items.where((x) => x.isActiveStatus).toList();
    if (cityQ.isNotEmpty) {
      out = out
          .where((x) => normalizeCity(x.city).toLowerCase().contains(cityQ))
          .toList();
    }
    if (stateQ.isNotEmpty) {
      out = out.where((x) => normalizeStateCode(x.state) == stateQ).toList();
    }
    if (zipQ.isNotEmpty) out = out.where((x) => x.zip.contains(zipQ)).toList();
    if (nameQ.isNotEmpty) {
      out = out.where((x) => x.name.toLowerCase().contains(nameQ)).toList();
    }
    if (langQ.isNotEmpty) {
      out = out
          .where((x) => x.languages.any((l) => l.toLowerCase().contains(langQ)))
          .toList();
    }
    if (licQ.isNotEmpty) {
      out = out
          .where((x) => x.licenseNumber.toLowerCase().contains(licQ))
          .toList();
    }
    if (minCap != null && minCap > 0) {
      out = out.where((x) => x.capacity >= minCap).toList();
    }

    return _toSorted(out);
  }

  List<DaycarePublic> _toFeaturedRanked(List<DaycarePublic> items, int limit) {
    final eligible = items.where((x) => x.isFeatureEligible).toList();
    eligible.sort((a, b) {
      final scoreDiff = _featuredScore(b).compareTo(_featuredScore(a));
      if (scoreDiff != 0) return scoreDiff;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return eligible.take(limit).toList();
  }

  int _featuredScore(DaycarePublic item) {
    var score = 0;

    switch (item.featurePlan) {
      case 'premium':
        score += 80;
        break;
      case 'plus':
        score += 40;
        break;
      default:
        break;
    }

    if (item.featureDaycare) score += 30;
    if (item.isVerified) score += 20;
    if (item.heroUrl.trim().isNotEmpty) score += 8;
    if (item.description.trim().isNotEmpty) score += 4;
    if (item.languages.isNotEmpty) score += 3;
    if (item.capacity > 0) score += 2;

    return score;
  }

  List<DaycarePublic> _toSorted(List<DaycarePublic> items) {
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }
}
