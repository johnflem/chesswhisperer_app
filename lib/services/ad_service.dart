import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _adsRemoved = false;

  // Test Ad Unit ID - replace with your real ID before publishing
  static const String _adUnitId = 'ca-app-pub-3940256099942544/1033173712';

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    await _checkAdRemovalStatus();
    if (!_adsRemoved) {
      _loadInterstitialAd();
    }
  }

  Future<void> _checkAdRemovalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool('ads_removed') ?? false;
  }

  Future<void> removeAds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ads_removed', true);
    _adsRemoved = true;
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  bool get adsRemoved => _adsRemoved;

  void _loadInterstitialAd() {
    if (_adsRemoved) return;

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd(); // Load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd(); // Load next ad
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isAdLoaded = false;
          // Try loading again after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            _loadInterstitialAd();
          });
        },
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (_adsRemoved) return;

    if (_isAdLoaded && _interstitialAd != null) {
      await _interstitialAd!.show();
      _isAdLoaded = false;
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}
