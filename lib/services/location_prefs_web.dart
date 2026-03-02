// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'location_prefs.dart';

const _kCity = 'df_home_city';
const _kState = 'df_home_state';
const _kZip = 'df_home_zip';

Future<void> saveHomeLocation(SavedHomeLocation value) async {
  final store = html.window.localStorage;
  store[_kCity] = value.city.trim();
  store[_kState] = value.state.trim();
  store[_kZip] = value.zip.trim();
}

Future<SavedHomeLocation?> loadHomeLocation() async {
  final store = html.window.localStorage;
  final city = (store[_kCity] ?? '').trim();
  final state = (store[_kState] ?? '').trim();
  final zip = (store[_kZip] ?? '').trim();
  final out = SavedHomeLocation(city: city, state: state, zip: zip);
  return out.hasAny ? out : null;
}

Future<void> clearHomeLocation() async {
  final store = html.window.localStorage;
  store.remove(_kCity);
  store.remove(_kState);
  store.remove(_kZip);
}
