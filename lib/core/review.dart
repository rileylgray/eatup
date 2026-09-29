import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'analytics.dart';

/// Asks for a store rating at a high point: right after a win or a new best,
/// once the player has some rounds behind them. No pre-question of our own
/// (Play and App Store policy); pacing is the only filter.
class Review {
  Review._();
  static final Review instance = Review._();

  static const String androidPackage = 'completed.realfunrealgames.eatup';

  /// TODO(release): the numeric App Store id, once the app exists in App
  /// Store Connect. Until then Rate Us falls back to the native sheet.
  static const String iosAppStoreId = '';

  static const int _minRounds = 6;
  static const List<int> _gaps = [10, 30];

  bool _askedThisSession = false;

  /// Call after a round was won or set a new best, while the results card
  /// is up (never behind an interstitial, where the sheet goes unseen).
  Future<void> onHighPoint({required int totalRounds}) async {
    if (_askedThisSession) return;
    final prefs = await SharedPreferences.getInstance();
    final asks = prefs.getInt('review_asks') ?? 0;
    if (asks > _gaps.length) return;
    final next = prefs.getInt('review_next_at') ?? _minRounds;
    if (totalRounds < next) return;

    _askedThisSession = true;
    try {
      final r = InAppReview.instance;
      if (!await r.isAvailable()) return;
      await r.requestReview();
      Analytics.instance.event('review_prompt');
      await prefs.setInt('review_asks', asks + 1);
      if (asks < _gaps.length) {
        await prefs.setInt('review_next_at', totalRounds + _gaps[asks]);
      }
    } catch (e) {
      debugPrint('Review request failed: $e');
    }
  }

  /// Settings → Rate us.
  Future<void> openStore() async {
    try {
      if (Platform.isIOS && iosAppStoreId.isEmpty) {
        await InAppReview.instance.requestReview();
        return;
      }
      await InAppReview.instance.openStoreListing(appStoreId: iosAppStoreId);
    } catch (_) {
      final uri = Uri.parse(
        Platform.isIOS
            ? 'https://apps.apple.com/app/id$iosAppStoreId?action=write-review'
            : 'https://play.google.com/store/apps/details?id=$androidPackage',
      );
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }
}
