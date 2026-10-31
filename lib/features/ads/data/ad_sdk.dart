import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<InitializationStatus>? _initialization;

Future<InitializationStatus> initializeMobileAds() => _initialization ??= MobileAds.instance.initialize();
