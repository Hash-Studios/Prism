import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/auth/userModel.dart';

const String defaultProfilePhotoUrl =
    'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4';

const String currentAppVersion = '2.6.9';
const String currentAppVersionCode = '75';
const String defaultObsoleteAppVersion = '2.6.0';

const String defaultBannerText = 'Join our Telegram';
const String defaultBannerUrl = 'https://t.me/PrismWallpapers';
const bool defaultBannerTextOn = true;

const bool defaultAiEnabled = true;
const int defaultAiRolloutPercent = 100;
const bool defaultAiSubmitEnabled = true;
const bool defaultAiVariationsEnabled = true;
const bool defaultUseRcPaywalls = true;

const List<String> defaultTopTitleText = <String>['TOP-RATED', 'BEST OF COMMUNITY', 'FAN-FAVOURITE', 'TRENDING'];

const List<String> defaultPremiumCollections = <String>['space', 'abstract', 'flat', 'mesh gradients', 'fluids'];

const List<String> defaultVerifiedUsers = <String>['akshaymaurya3006@gmail.com', 'maurya.abhay30@gmail.com'];

const String defaultTopImageLink =
    'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4';

PrismUsersV2 createGuestPrismUser() {
  final now = DateTime.now().toUtc().toIso8601String();
  return PrismUsersV2(
    name: '',
    bio: '',
    createdAt: now,
    email: '',
    username: '',
    followers: <dynamic>[],
    following: <dynamic>[],
    id: '',
    lastLoginAt: now,
    links: <String, dynamic>{},
    premium: false,
    subscriptionTier: 'free',
    loggedIn: false,
    profilePhoto: defaultProfilePhotoUrl,
    badges: <Badge>[],
    coins: 0,
    subPrisms: <dynamic>[],
    transactions: <PrismTransaction>[],
    coverPhoto: '',
    uploadsWeekStart: '',
    uploadsThisWeek: 0,
  );
}

bool parseRemoteBool(String raw, {required bool fallback}) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'true') {
    return true;
  }
  if (normalized == 'false') {
    return false;
  }
  return fallback;
}
