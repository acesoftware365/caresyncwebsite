import 'location_prefs_stub.dart'
    if (dart.library.html) 'location_prefs_web.dart' as impl;

class SavedHomeLocation {
  const SavedHomeLocation({
    required this.city,
    required this.state,
    required this.zip,
  });

  final String city;
  final String state;
  final String zip;

  bool get hasAny => city.isNotEmpty || state.isNotEmpty || zip.isNotEmpty;
}

Future<void> saveHomeLocation(SavedHomeLocation value) {
  return impl.saveHomeLocation(value);
}

Future<SavedHomeLocation?> loadHomeLocation() {
  return impl.loadHomeLocation();
}

Future<void> clearHomeLocation() {
  return impl.clearHomeLocation();
}
