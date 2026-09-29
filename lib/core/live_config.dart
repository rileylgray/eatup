import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Knobs that can be retuned for everyone without an app update, via Firebase
/// Remote Config. Every value has a shipped default, so the game runs the same
/// offline or with Firebase not configured.
///
/// Add a knob: a default in [_defaults] and a getter below. Then set it (per
/// country, per A/B group...) in the Firebase console.
class LiveConfig {
  LiveConfig._();
  static final LiveConfig instance = LiveConfig._();

  static const Map<String, Object> _defaults = {
    'round_seconds': 100,
    'interstitial_grace_rounds': 2,
    'interstitial_rounds_between': 1,
    'interstitial_min_gap_s': 90,
    'interstitial_warmup_s': 60,
    'free_coins_amount': 100,
    'free_coins_cooldown_min': 5,
    'wheel_free_hours': 6,
    'wheel_ad_spins': 3,
    'revive_enabled': true,
  };

  FirebaseRemoteConfig? _rc;

  Future<void> attach() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(fetchTimeout: const Duration(seconds: 8), minimumFetchInterval: const Duration(hours: 1)),
      );
      await rc.setDefaults(_defaults);
      _rc = rc;
      // Values fetched now apply from the next launch, so a round never
      // changes rules halfway (and startup never waits on the network).
      rc.fetch().catchError((Object e) => debugPrint('Remote config fetch failed: $e'));
      await rc.activate();
    } catch (e) {
      debugPrint('Remote config unavailable: $e');
    }
  }

  int _int(String key) {
    try {
      final rc = _rc;
      if (rc != null) return rc.getInt(key);
    } catch (_) {}
    return _defaults[key]! as int;
  }

  bool _bool(String key) {
    try {
      final rc = _rc;
      if (rc != null) return rc.getBool(key);
    } catch (_) {}
    return _defaults[key]! as bool;
  }

  double get roundSeconds => _int('round_seconds').clamp(45, 300).toDouble();
  int get interstitialGraceRounds => _int('interstitial_grace_rounds');
  int get interstitialRoundsBetween => _int('interstitial_rounds_between');
  Duration get interstitialMinGap => Duration(seconds: _int('interstitial_min_gap_s'));
  Duration get interstitialWarmup => Duration(seconds: _int('interstitial_warmup_s'));
  int get freeCoinsAmount => _int('free_coins_amount');
  Duration get freeCoinsCooldown => Duration(minutes: _int('free_coins_cooldown_min'));
  Duration get wheelFreeEvery => Duration(hours: _int('wheel_free_hours'));
  int get wheelAdSpins => _int('wheel_ad_spins');
  bool get reviveEnabled => _bool('revive_enabled');
}
