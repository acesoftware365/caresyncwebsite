import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsEventLogger {
  AnalyticsEventLogger._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final String _sessionId = _buildSessionId();

  static Future<void> log({
    required String eventType,
    required String pageType,
    String? tenantId,
    String? slug,
    Map<String, dynamic>? data,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final payload = <String, dynamic>{
        'eventType': eventType.trim(),
        'pageType': pageType.trim(),
        'tenantId': (tenantId ?? '').trim(),
        'slug': (slug ?? '').trim(),
        'sessionId': _sessionId,
        'dayKey':
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'createdAt': FieldValue.serverTimestamp(),
        'data': _sanitizeData(data ?? const <String, dynamic>{}),
      };
      await _db.collection('analytics_events').add(payload);
    } catch (_) {
      // Intentionally ignore analytics errors to avoid affecting UX.
    }
  }

  static String _buildSessionId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(999999999);
    return 's$now$rand';
  }

  static Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      final value = entry.value;
      if (value == null) continue;
      if (value is num || value is bool || value is String) {
        out[key] = value;
      } else {
        out[key] = value.toString();
      }
    }
    return out;
  }
}
