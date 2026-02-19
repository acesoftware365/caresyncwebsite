// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

bool openWebLinkSelf(String url) {
  try {
    html.window.location.assign(url);
    return true;
  } catch (_) {
    return false;
  }
}
