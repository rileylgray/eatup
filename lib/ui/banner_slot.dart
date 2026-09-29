import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ads/ad_manager.dart';

/// The one banner in the app: an anchored adaptive banner pinned to the top,
/// far from the thumb that throws, so it never catches an accidental tap.
///
/// It lives above every panel, so it stays visible (and viewable) whether the
/// player is on the menu, in a throw or in the store.
class BannerSlot extends StatefulWidget {
  const BannerSlot({super.key});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    AdManager.instance.started.addListener(_load);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.sizeOf(context).width.truncate();
    if (w != _width) {
      _width = w;
      _load();
    }
  }

  Future<void> _load() async {
    final width = _width;
    if (width == null || !AdManager.instance.adsStarted) return;
    _retry?.cancel();
    final old = _ad;
    final ad = await AdManager.instance.createBanner(
      width: width,
      onLoaded: () {
        if (!mounted) return;
        setState(() => _loaded = true);
      },
      onFailed: () {
        if (!mounted) return;
        setState(() {
          _ad = null;
          _loaded = false;
        });
        _retry = Timer(const Duration(seconds: 45), _load);
      },
    );
    if (!mounted) {
      ad?.dispose();
      return;
    }
    setState(() {
      _ad = ad;
      _loaded = false;
    });
    old?.dispose();
    await ad?.load();
  }

  @override
  void dispose() {
    AdManager.instance.started.removeListener(_load);
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final height = ad != null && _loaded ? ad.size.height.toDouble() : 0.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: height,
      width: double.infinity,
      color: const Color(0x66000000),
      alignment: Alignment.center,
      child: ad != null && _loaded
          ? SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            )
          : null,
    );
  }
}
