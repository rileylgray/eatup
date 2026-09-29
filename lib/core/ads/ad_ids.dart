import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob ad unit ids.
///
/// Debug builds always use Google's public TEST units: serving real ads to
/// yourself while developing risks the AdMob account being flagged.
///
/// TODO(release): create the EatUp app and its three units per platform in
/// the AdMob console and paste the ids below (and the app ids into
/// AndroidManifest.xml and Info.plist). Until then release builds fall back
/// to the test units too, so nothing breaks, but nothing earns either.
class AdIds {
  static String get banner => _pick(
    androidTest: 'ca-app-pub-3940256099942544/9214589741',
    android: '',
    iosTest: 'ca-app-pub-3940256099942544/2435281174',
    ios: '',
  );

  static String get interstitial => _pick(
    androidTest: 'ca-app-pub-3940256099942544/1033173712',
    android: '',
    iosTest: 'ca-app-pub-3940256099942544/4411468910',
    ios: '',
  );

  static String get rewarded => _pick(
    androidTest: 'ca-app-pub-3940256099942544/5224354917',
    android: '',
    iosTest: 'ca-app-pub-3940256099942544/1712485313',
    ios: '',
  );

  static String _pick({
    required String androidTest,
    required String android,
    required String iosTest,
    required String ios,
  }) {
    if (Platform.isAndroid) return kReleaseMode && android.isNotEmpty ? android : androidTest;
    return kReleaseMode && ios.isNotEmpty ? ios : iosTest;
  }
}
