import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper so a missing Firebase config (or a test) never throws.
class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  FirebaseAnalytics? _fa;

  void attach() {
    try {
      _fa = FirebaseAnalytics.instance;
    } catch (e) {
      debugPrint('Analytics unavailable: $e');
    }
  }

  void event(String name, [Map<String, Object>? params]) {
    final fa = _fa;
    if (fa == null) return;
    fa.logEvent(name: name, parameters: params).catchError((Object e) {
      debugPrint('Analytics event failed: $e');
    });
  }
}
