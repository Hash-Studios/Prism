import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/auth/userModel.dart';
import 'package:Prism/data/ads/adHelper.dart';
import 'package:Prism/main.dart' as main;

GoogleAuth gAuth = GoogleAuth();
PrismUsers prismUser = main.prefs.get(
  'prismUser',
  defaultValue: PrismUsers.initial(
    createdAt: DateTime.now().toIso8601String(),
    lastLogin: DateTime.now(),
    links: {},
    followers: [],
    following: [],
  ),
) as PrismUsers;
String currentAppVersion = '2.6.5';
String obsoleteAppVersion = '2.6.0';
String currentAppVersionCode = '64';
bool updateChecked = false;
bool updateAvailable = false;
Map versionInfo = {};
AdHelper adHelper = AdHelper();
bool updateAlerted = false;
bool hasNotch = false;
double? notchSize;
bool tooltipShown = false;
bool followersTab = true;

List topTitleText = [
  "TOP-RATED",
  "BEST OF COMMUNITY",
  "FAN-FAVOURITE",
  "TRENDING",
];

List premiumCollections = [
  "space",
  "abstract",
  "flat",
  "mesh gradients",
  "fluids",
];

String topImageLink =
    'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4';

List verifiedUsers = [
  "akshaymaurya3006@gmail.com",
  "maurya.abhay30@gmail.com",
];

String bannerText = "Join our Telegram";

String bannerURL = "https://t.me/PrismWallpapers";

String bannerTextOn = "true";

bool isPremiumWall(List premiumCollections, List wallCollections) {
  bool result = false;
  wallCollections.forEach((element) {
    if (premiumCollections.contains(element)) {
      result = true;
    } else {}
  });
  return result;
}
