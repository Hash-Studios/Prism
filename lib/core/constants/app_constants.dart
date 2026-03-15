import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/auth/userModel.dart';

const String defaultProfilePhotoUrl =
    'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4';

const String currentAppVersion = '3.0.3';
const String currentAppVersionCode = '317';
const String defaultObsoleteAppVersion = '2.6.0';

const String defaultBannerText = 'Join our Telegram';
const String defaultBannerUrl = 'https://t.me/PrismWallpapers';
const bool defaultBannerTextOn = true;

const bool defaultAiEnabled = true;
const int defaultAiRolloutPercent = 100;
const bool defaultAiSubmitEnabled = true;
const bool defaultAiVariationsEnabled = true;
const bool defaultUseRcPaywalls = true;

const bool defaultOnboardingV2Enabled = true;
const List<Map<String, dynamic>> defaultOnboardingStarterPack = <Map<String, dynamic>>[];

const String personalizedInterestsRemoteConfigKey = 'personalized_interests_v1';
const String personalizedInterestsLocalCacheKey = 'personalized_interests_catalog_v1';
const String personalizedFeedMixLocalKey = 'personalized_feed_mix';
const String defaultPersonalizedInterestsJson = '''
[
  {"name":"Minimal","query":"minimal","imageUrl":"https://images.pexels.com/photos/2662792/pexels-photo-2662792.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels"]},
  {"name":"Moody","query":"moody","imageUrl":"https://images.pexels.com/photos/3408744/pexels-photo-3408744.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Retro","query":"retro","imageUrl":"https://images.pexels.com/photos/1633798/pexels-photo-1633798.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["wallhaven","pexels"]},
  {"name":"Cyberpunk","query":"cyberpunk","imageUrl":"https://images.pexels.com/photos/3165335/pexels-photo-3165335.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["wallhaven"]},
  {"name":"Nature","query":"nature","imageUrl":"https://images.pexels.com/photos/40896/larch-conifer-cone-branch-tree-40896.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Architecture","query":"architecture","imageUrl":"https://images.pexels.com/photos/323780/pexels-photo-323780.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Cars","query":"cars","imageUrl":"https://images.pexels.com/photos/358070/pexels-photo-358070.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["wallhaven","pexels"]},
  {"name":"Anime","query":"anime","imageUrl":"https://images.pexels.com/photos/998641/pexels-photo-998641.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["wallhaven"]},
  {"name":"Space","query":"space","imageUrl":"https://images.pexels.com/photos/586059/pexels-photo-586059.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["wallhaven","pexels"]},
  {"name":"Portrait","query":"portrait","imageUrl":"https://images.pexels.com/photos/1516680/pexels-photo-1516680.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels"]},
  {"name":"Abstract","query":"abstract","imageUrl":"https://images.pexels.com/photos/7130560/pexels-photo-7130560.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Textures","query":"textures","imageUrl":"https://images.pexels.com/photos/129731/pexels-photo-129731.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]}
]''';

const List<String> defaultTopTitleText = <String>['TOP-RATED', 'BEST OF COMMUNITY', 'FAN-FAVOURITE', 'TRENDING'];

const List<String> defaultPremiumCollections = <String>['space', 'abstract', 'flat', 'mesh gradients', 'fluids'];

const List<String> defaultVerifiedUsers = <String>['akshaymaurya3006@gmail.com', 'maurya.abhay30@gmail.com'];

const Set<String> adminEmails = <String>{'akshaymaurya3006@gmail.com', 'maurya.abhay30@gmail.com'};

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
    followers: const <String>[],
    following: const <String>[],
    id: '',
    lastLoginAt: now,
    links: const <String, String>{},
    premium: false,
    loggedIn: false,
    profilePhoto: defaultProfilePhotoUrl,
    badges: <Badge>[],
    coins: 0,
    subPrisms: const <String>[],
    transactions: <PrismTransaction>[],
    coverPhoto: '',
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
