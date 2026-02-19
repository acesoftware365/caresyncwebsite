import '../../../services/image_url.dart';
import '../../../services/location_text.dart';

class DaycarePublic {
  DaycarePublic({
    required this.tenantId,
    required this.slug,
    required this.websiteSlug,
    required this.name,
    required this.city,
    required this.state,
    required this.addressLine,
    required this.email,
    required this.phone,
    required this.licenseNumber,
    required this.languages,
    required this.capacity,
    required this.logoUrl,
    required this.heroUrl,
    required this.description,
  });

  final String tenantId;
  final String slug;
  final String websiteSlug;

  final String name;
  final String city;
  final String state;
  final String addressLine;

  final String email;
  final String phone;

  final String licenseNumber;
  final List<String> languages;
  final int capacity;

  final String logoUrl;
  final String heroUrl;
  final String description;

  String get effectiveSlug => websiteSlug.isNotEmpty ? websiteSlug : slug;

  factory DaycarePublic.fromTenantDoc(String tenantId, Map<String, dynamic> d) {
    final daycareName = (d['daycareName'] ?? d['name'] ?? '').toString();

    final house = (d['addressHouseNumber'] ?? '').toString().trim();
    final street = (d['addressStreet'] ?? '').toString().trim();
    final city = normalizeCity((d['addressCity'] ?? '').toString());
    final state = normalizeStateCode((d['addressState'] ?? '').toString());
    final zip = (d['addressZip'] ?? '').toString().trim();

    final addressLine = [
      [house, street].where((e) => e.isNotEmpty).join(' ').trim(),
      city,
      state,
      zip,
    ].where((e) => e.isNotEmpty).join(', ');

    final area = (d['phoneAreaCode'] ?? '').toString().trim();
    final num = (d['phoneNumber'] ?? '').toString().trim();
    final phone = num.isEmpty ? '' : (area.isEmpty ? num : '($area) $num');

    final langsRaw = (d['languages'] as List?) ?? const [];
    final languages = langsRaw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();

    int capacity = 0;
    final capRaw = d['capacity'];
    if (capRaw is int) capacity = capRaw;
    if (capRaw is double) capacity = capRaw.toInt();
    if (capRaw is String) capacity = int.tryParse(capRaw) ?? 0;

    return DaycarePublic(
      tenantId: tenantId,
      slug: (d['slug'] ?? tenantId).toString(),
      websiteSlug: (d['websiteSlug'] ?? tenantId).toString(),
      name: daycareName,
      city: city,
      state: state,
      addressLine: addressLine,
      email: (d['email'] ?? '').toString(),
      phone: phone,
      licenseNumber: (d['licenseNumber'] ?? '').toString(),
      languages: languages,
      capacity: capacity,
      logoUrl: normalizeImageUrl(
        (d['websiteLogoUrl'] ?? '').toString(),
        defaultBucket: 'liisgo-daycare-system.firebasestorage.app',
      ),
      heroUrl: normalizeImageUrl(
        (d['websiteHeroUrl'] ?? '').toString(),
        defaultBucket: 'liisgo-daycare-system.firebasestorage.app',
      ),
      description: (d['websiteDescription'] ?? '').toString(),
    );
  }
}
