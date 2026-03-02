// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'location_lookup.dart';

Future<LocationLookupResult> detectCurrentLocation() async {
  final position = await _getCurrentPosition();
  final coords = position.coords;
  final lat = coords?.latitude;
  final lon = coords?.longitude;
  if (lat == null || lon == null) {
    throw StateError('Device location coordinates are unavailable.');
  }

  final url =
      'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en';

  final raw = await html.HttpRequest.getString(url);
  final map = jsonDecode(raw) as Map<String, dynamic>;

  final city = (map['city'] ?? map['locality'] ?? '').toString().trim();
  final subdivision =
      (map['principalSubdivisionCode'] ?? map['principalSubdivision'] ?? '')
          .toString()
          .trim();
  final state = _toUsStateCode(subdivision);
  final zip = (map['postcode'] ?? '').toString().trim();

  final out = LocationLookupResult(city: city, state: state, zip: zip);
  if (!out.hasAny) {
    throw StateError('No location details available for this device position.');
  }
  return out;
}

Future<html.Geoposition> _getCurrentPosition() async {
  try {
    return await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 12),
      maximumAge: const Duration(minutes: 2),
    );
  } catch (_) {
    throw StateError('Location permission denied or unavailable.');
  }
}

String _toUsStateCode(String value) {
  final v = value.trim();
  if (v.isEmpty) return '';
  if (v.contains('-')) {
    final part = v.split('-').last.trim();
    if (part.length == 2) return part.toUpperCase();
  }
  if (v.length == 2) return v.toUpperCase();
  return v.toUpperCase();
}
