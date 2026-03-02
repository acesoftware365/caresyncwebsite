import 'location_lookup_stub.dart'
    if (dart.library.html) 'location_lookup_web.dart' as impl;

class LocationLookupResult {
  const LocationLookupResult({
    required this.city,
    required this.state,
    required this.zip,
  });

  final String city;
  final String state;
  final String zip;

  bool get hasAny => city.isNotEmpty || state.isNotEmpty || zip.isNotEmpty;
}

Future<LocationLookupResult> detectCurrentLocation() {
  return impl.detectCurrentLocation();
}
