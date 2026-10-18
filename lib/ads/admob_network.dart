import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ads.dart';

/// Google AdMob behind [AdNetwork]. Mechanics only: consent, loading,
/// showing and reporting. Every "should an ad appear" rule is in [Ads].
///
/// Start-up order: the UMP consent form (shown only where the law requires
/// it, e.g. EEA/UK) runs first; the SDK starts and ads load only once
/// `canRequestAds` is true.
class AdMobNetwork implements AdNetwork {
  AdMobNetwork({AdUnitIds? ids}) : ids = ids ?? AdUnitIds.current;

  final AdUnitIds ids;

  /// Wait this long before retrying a failed load, so a no-fill account is
  /// never hammered with requests.
  static const _retryDelay = Duration(seconds: 60);

  final _sdkReady = ValueNotifier(false);
  final _rewardedReady = ValueNotifier(false);
  final _privacyRequired = ValueNotifier(false);

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  Future<void>? _init;

  @override
  bool get enabled => true;

  @override
  ValueListenable<bool> get rewardedReady => _rewardedReady;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _privacyRequired;

  @override
  Future<void> init() => _init ??= _initOnce();

  Future<void> _initOnce() async {
    // Consent given in an earlier session lets ads start straight away.
    if (await _canRequestAds()) unawaited(_startSdk());
    await _gatherConsent();
    await _refreshPrivacyRequirement();
    if (await _canRequestAds()) await _startSdk();
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) debugPrint('[ads] consent form: ${error.message}');
        if (!done.isCompleted) done.complete();
      }),
      (error) {
        debugPrint('[ads] consent update failed: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  Future<bool> _canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshPrivacyRequirement() async {
    try {
      _privacyRequired.value =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {}
  }

  Future<void> _startSdk() async {
    if (_sdkReady.value) return;
    await MobileAds.instance.initialize();
    _sdkReady.value = true;
    _loadInterstitial();
    _loadRewarded();
  }

  void _loadInterstitial() {
    if (_loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: ids.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          debugPrint('[ads] interstitial load failed: ${error.message}');
          Timer(_retryDelay, _loadInterstitial);
        },
      ),
    );
  }

  void _loadRewarded() {
    if (_loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: ids.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
          _rewardedReady.value = true;
        },
        onAdFailedToLoad: (error) {
          _loadingRewarded = false;
          debugPrint('[ads] rewarded load failed: ${error.message}');
          Timer(_retryDelay, _loadRewarded);
        },
      ),
    );
  }

  @override
  Widget banner(AdPlacement placement) => ValueListenableBuilder<bool>(
    valueListenable: _sdkReady,
    builder: (context, ready, _) =>
        ready ? _AdMobBanner(key: ValueKey(placement), unitId: ids.banner) : const SizedBox.shrink(),
  );

  @override
  Future<bool> showInterstitial(BuildContext context, AdPlacement placement) async {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    final closed = Completer<bool>();
    var showed = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => showed = true,
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!closed.isCompleted) closed.complete(showed);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        debugPrint('[ads] interstitial show failed: ${error.message}');
        a.dispose();
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    await ad.show();
    final result = await closed.future;
    _loadInterstitial();
    return result;
  }

  @override
  Future<RewardOutcome> showRewarded(BuildContext context, AdPlacement placement) async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return const NoFill();
    }
    _rewarded = null;
    _rewardedReady.value = false;
    final closed = Completer<RewardOutcome>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!closed.isCompleted) closed.complete(earned ? const Rewarded() : const Dismissed());
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        debugPrint('[ads] rewarded show failed: ${error.message}');
        a.dispose();
        if (!closed.isCompleted) closed.complete(const NoFill());
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    final outcome = await closed.future;
    _loadRewarded();
    return outcome;
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('[ads] privacy options: ${error.message}');
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await _refreshPrivacyRequirement();
    if (await _canRequestAds()) await _startSdk();
  }
}

/// One 320x50 banner. Created when the slot appears and disposed when it
/// goes (Torch tab, glow, dialogs), so it never refreshes while hidden.
class _AdMobBanner extends StatefulWidget {
  const _AdMobBanner({super.key, required this.unitId});
  final String unitId;

  @override
  State<_AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<_AdMobBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: widget.unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[ads] banner load failed: ${error.message}');
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        key: const Key('admob-banner'),
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
