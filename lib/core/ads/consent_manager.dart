import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Handles the Google UMP (User Messaging Platform) consent flow, plus the iOS
/// App Tracking Transparency prompt.
///
/// In the EEA, UK and Switzerland, AdMob requires a TCF-registered CMP to have
/// collected a consent choice before ads are requested. An ad request sent
/// before that choice carries no TC string, which Google's Policy center flags
/// as "Consent requirement: No CMP" and which throttles serving in those
/// regions.
///
/// The message itself is configured in the AdMob console under
/// Privacy & messaging → European regulations, and must be *published* and
/// applied to this app. This class only asks the SDK to fetch and show whatever
/// is configured there.
///
/// The contract with [AdManager] is [canRequestAds]: it stays false until the
/// SDK confirms ads may be requested, and no ad is ever loaded while it is
/// false. That is deliberately fail-closed — a startup with no network yields
/// no ads rather than a TC-string-less ad request.
class ConsentManager {
  ConsentManager._internal();

  static final ConsentManager _instance = ConsentManager._internal();
  factory ConsentManager() => _instance;

  bool _canRequestAds = false;
  Future<void>? _inFlight;

  /// Whether the SDK has confirmed ads may be requested. Always false until
  /// [gather] has completed a consent info update at least once.
  bool get canRequestAds => _canRequestAds;

  bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Requests the latest consent info and shows the consent form if the user's
  /// region requires one and they haven't answered yet.
  ///
  /// Awaited before ads are initialized so the very first ad request already
  /// carries the right consent signals. Never throws.
  ///
  /// Safe to call again after a failure: unlike a one-shot latch, this retries,
  /// so a user who launched offline can still reach the form later.
  Future<void> gather() {
    // On unsupported platforms ads are never requested anyway, so leaving
    // _canRequestAds false costs nothing.
    if (!_supported || _canRequestAds) return Future<void>.value();
    return _inFlight ??= _gather().whenComplete(() => _inFlight = null);
  }

  Future<void> _gather() async {
    try {
      await _requestConsentInfoUpdate();
      // Runs whatever the console serves; a no-op when consent isn't required
      // or was already collected.
      await _loadAndShowFormIfRequired();
    } catch (e) {
      debugPrint('Consent gathering failed: $e');
    }

    await _requestTrackingAuthorization();

    // Asked even when the steps above failed: the UMP SDK persists a previous
    // session's choice, so a user who already consented isn't punished for a
    // transient error here.
    await _refreshCanRequestAds();
  }

  /// Shows the iOS App Tracking Transparency prompt, once, on first launch.
  ///
  /// Unlike the UMP form this is not region-gated — it goes to every iOS user.
  /// Without it iOS hands back an all-zero advertising identifier, so ad
  /// requests are personalized in name only and sell at non-personalized rates.
  ///
  /// Ordering matters twice over: Apple wants it after the UMP form, and it can
  /// only appear with the app actually in the foreground, hence the short delay.
  /// Never throws — a refused or failed prompt just means less ad targeting.
  Future<void> _requestTrackingAuthorization() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      // Anything else means the user already answered; asking again is a no-op
      // that Apple would rather we skip.
      if (status != TrackingStatus.notDetermined) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (e) {
      debugPrint('ATT prompt failed: $e');
    }
  }

  /// Shows the privacy options form so a user can change their choice. Backs
  /// the "Ad privacy choices" row in settings, which Google requires to be
  /// reachable whenever a message with privacy options is configured.
  ///
  /// Returns true if the form was shown without error.
  Future<bool> showPrivacyOptions() async {
    if (!_supported) return false;

    try {
      FormError? formError;
      await ConsentForm.showPrivacyOptionsForm((error) => formError = error);

      if (formError != null) {
        debugPrint('Privacy options form failed: ${formError!.errorCode} ${formError!.message}');
        return false;
      }

      // The user may have just granted consent, so ads can potentially start.
      await _refreshCanRequestAds();
      return true;
    } catch (e) {
      debugPrint('Privacy options form failed: $e');
      return false;
    }
  }

  /// True when this user must be offered a privacy options entry point, so the
  /// settings row can stay hidden for the (many) users outside a consent region.
  Future<bool> hasPrivacyOptions() async {
    if (!_supported) return false;
    try {
      final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('Privacy options requirement check failed: $e');
      return false;
    }
  }

  Future<void> _refreshCanRequestAds() async {
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      debugPrint('Consent resolved: canRequestAds=$_canRequestAds');
    } catch (e) {
      debugPrint('canRequestAds check failed: $e');
      _canRequestAds = false;
    }
  }

  /// Wraps the SDK's callback-style update in a Future.
  Future<void> _requestConsentInfoUpdate() {
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        debugPrint('Consent info update failed: ${error.errorCode} ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint('Consent info update timed out'),
    );
  }

  /// Loads and shows the consent form when the SDK says one is required.
  ///
  /// Intentionally not time-limited: this completes only once the form is
  /// dismissed, because starting ads while the form is still on screen is
  /// exactly what produces ad requests with no TC string.
  Future<void> _loadAndShowFormIfRequired() async {
    FormError? formError;
    await ConsentForm.loadAndShowConsentFormIfRequired((error) => formError = error);

    if (formError != null) {
      debugPrint('Consent form failed: ${formError!.errorCode} ${formError!.message}');
    }
  }
}
