import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../analytics.dart';
import '../live_config.dart';
import '../sound.dart';
import 'ad_ids.dart';
import 'consent_manager.dart';

/// Decides when an interstitial may interrupt. Kept free of the ad SDK so the
/// rules can be unit tested.
///
/// The rules protect retention first: a brand-new player sees no interstitial
/// until they are hooked, and after that one can only appear at a natural
/// break (leaving a results card), no more than once per [minGap].
class InterstitialPacer {
  InterstitialPacer({
    DateTime Function()? clock,
    this.graceRounds = 2,
    this.roundsBetween = 1,
    this.minGap = const Duration(seconds: 90),
    this.sessionWarmup = const Duration(seconds: 60),
  }) : _clock = clock ?? DateTime.now {
    _sessionStart = _clock();
  }

  factory InterstitialPacer.live() {
    final c = LiveConfig.instance;
    return InterstitialPacer(
      graceRounds: c.interstitialGraceRounds,
      roundsBetween: c.interstitialRoundsBetween,
      minGap: c.interstitialMinGap,
      sessionWarmup: c.interstitialWarmup,
    );
  }

  final DateTime Function() _clock;
  late final DateTime _sessionStart;
  DateTime? _lastFullScreen;
  int _roundsSinceAd = 0;

  /// Lifetime rounds before the first interstitial ever.
  final int graceRounds;
  final int roundsBetween;
  final Duration minGap;
  final Duration sessionWarmup;

  void onRound() => _roundsSinceAd++;

  /// Any full-screen ad (a rewarded one too) resets the clock.
  void onFullScreenShown() {
    _lastFullScreen = _clock();
    _roundsSinceAd = 0;
  }

  bool shouldShow({required int lifetimeRounds}) {
    final now = _clock();
    if (lifetimeRounds < graceRounds) return false;
    if (_roundsSinceAd < roundsBetween) return false;
    if (now.difference(_sessionStart) < sessionWarmup) return false;
    final last = _lastFullScreen;
    if (last != null && now.difference(last) < minGap) return false;
    return true;
  }
}

/// Banner, interstitial and rewarded ads. Every load waits on consent, and
/// every failed load retries with backoff so a slot is rarely empty.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  late final InterstitialPacer pacer = InterstitialPacer.live();

  bool _started = false;
  bool get adsStarted => _started;

  /// Flips true once the SDK is up, so banner slots built earlier can load.
  final ValueNotifier<bool> started = ValueNotifier(false);

  /// Set by the Remove Ads purchase: no banners, no interstitials. Rewarded
  /// videos stay, because the player chooses those.
  final ValueNotifier<bool> adsRemoved = ValueNotifier(false);

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _interstitialFails = 0;
  int _rewardedFails = 0;
  bool _showingFullScreen = false;

  /// Notifies listeners when a rewarded ad becomes (un)available, so reward
  /// buttons can show their state.
  final ValueNotifier<bool> rewardedReady = ValueNotifier(false);

  Future<void> startIfAllowed() async {
    if (_started) return;
    if (!ConsentManager().canRequestAds) {
      debugPrint('Ads not started: no consent yet');
      return;
    }
    _started = true;
    try {
      await MobileAds.instance.initialize();
      started.value = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      _started = false;
      debugPrint('MobileAds init failed: $e');
    }
  }

  void removeAds() {
    if (adsRemoved.value) return;
    adsRemoved.value = true;
    _interstitial?.dispose();
    _interstitial = null;
  }

  Duration _backoff(int fails) => Duration(seconds: min(300, 15 * (1 << min(fails, 5))));

  // Interstitial --------------------------------------------------------------

  void _loadInterstitial() {
    if (!_started || _interstitial != null || adsRemoved.value) return;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialFails = 0;
          _interstitial = ad;
        },
        onAdFailedToLoad: (e) {
          _interstitialFails++;
          Future.delayed(_backoff(_interstitialFails), _loadInterstitial);
        },
      ),
    );
  }

  /// Shows an interstitial if the pacer allows it and one is loaded.
  /// Completes once the player is back in the game.
  Future<bool> maybeShowInterstitial({required int lifetimeRounds}) async {
    final ad = _interstitial;
    if (ad == null || _showingFullScreen || adsRemoved.value) return false;
    if (!pacer.shouldShow(lifetimeRounds: lifetimeRounds)) return false;

    _interstitial = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        pacer.onFullScreenShown();
        Sound.instance.suspend();
        Analytics.instance.event('ad_interstitial_shown');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _afterFullScreen();
        _loadInterstitial();
        if (!done.isCompleted) done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _afterFullScreen();
        _loadInterstitial();
        if (!done.isCompleted) done.complete(false);
      },
    );
    _showingFullScreen = true;
    await ad.show();
    return done.future;
  }

  void _afterFullScreen() {
    _showingFullScreen = false;
    Sound.instance.unsuspend();
  }

  // Rewarded ------------------------------------------------------------------

  void _loadRewarded() {
    if (!_started || _rewarded != null) return;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedFails = 0;
          _rewarded = ad;
          rewardedReady.value = true;
        },
        onAdFailedToLoad: (e) {
          _rewardedFails++;
          rewardedReady.value = false;
          Future.delayed(_backoff(_rewardedFails), _loadRewarded);
        },
      ),
    );
  }

  /// Shows a rewarded video. Completes with true only if the player earned
  /// the reward. [placement] is logged so the best-earning offers are visible.
  Future<bool> showRewarded(String placement) async {
    final ad = _rewarded;
    if (ad == null || _showingFullScreen) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    rewardedReady.value = false;

    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        pacer.onFullScreenShown();
        Sound.instance.suspend();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _afterFullScreen();
        _loadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _afterFullScreen();
        _loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    _showingFullScreen = true;
    await ad.show(
      onUserEarnedReward: (_, _) {
        earned = true;
        Analytics.instance.event('reward_earned', {'placement': placement});
      },
    );
    return done.future;
  }

  // Banner --------------------------------------------------------------------

  /// An anchored adaptive banner sized for [width] logical px, or null when
  /// ads can't run (no consent, removed, or the size query failed).
  Future<BannerAd?> createBanner({
    required int width,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    if (!_started || adsRemoved.value) return null;
    // The standard anchored size (~50-60dp): the "large" one eats too much of
    // the playfield.
    // ignore: deprecated_member_use
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null) return null;
    return BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          onFailed();
        },
      ),
    );
  }
}
