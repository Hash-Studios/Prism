import 'package:Prism/auth/badgeModel.dart';
import 'package:Prism/auth/transactionModel.dart';
import 'package:Prism/auth/userModel.dart';

const String defaultProfilePhotoUrl =
    'https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2Fpost%20bg.png?alt=media&token=d708b5e3-a7ee-421b-beae-3b10946678c4';

const String currentAppVersion = '3.0.8';
const String currentAppVersionCode = '332';
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
  {"name":"Space","query":"space","imageUrl":"https://images.pexels.com/photos/586059/pexels-photo-586059.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Scenery","query":"scenery landscape","imageUrl":"https://images.pexels.com/photos/572897/pexels-photo-572897.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Vehicles","query":"cars vehicles","imageUrl":"https://images.pexels.com/photos/358070/pexels-photo-358070.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Animals","query":"animals wildlife","imageUrl":"https://images.pexels.com/photos/247502/pexels-photo-247502.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Fantasy","query":"fantasy","imageUrl":"https://images.pexels.com/photos/3075993/pexels-photo-3075993.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Anime","query":"anime","imageUrl":"https://images.pexels.com/photos/998641/pexels-photo-998641.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["wallhaven"]},
  {"name":"Nature","query":"nature","imageUrl":"https://images.pexels.com/photos/3244513/pexels-photo-3244513.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Aesthetic","query":"aesthetic","imageUrl":"https://images.pexels.com/photos/1458457/pexels-photo-1458457.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Abstract","query":"abstract","imageUrl":"https://images.pexels.com/photos/7130560/pexels-photo-7130560.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Aerial","query":"aerial photography","imageUrl":"https://images.pexels.com/photos/1004409/pexels-photo-1004409.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Artistic","query":"art painting","imageUrl":"https://images.pexels.com/photos/1269968/pexels-photo-1269968.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Gradients","query":"colorful gradient","imageUrl":"https://images.pexels.com/photos/7415261/pexels-photo-7415261.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Clouds","query":"sky clouds","imageUrl":"https://images.pexels.com/photos/844297/pexels-photo-844297.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Textures","query":"texture","imageUrl":"https://images.pexels.com/photos/129731/pexels-photo-129731.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Flowers","query":"flowers","imageUrl":"https://images.pexels.com/photos/931177/pexels-photo-931177.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"City","query":"city urban skyline","imageUrl":"https://images.pexels.com/photos/466685/pexels-photo-466685.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Birds","query":"birds","imageUrl":"https://images.pexels.com/photos/326900/pexels-photo-326900.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Warriors","query":"warrior fighter","imageUrl":"https://images.pexels.com/photos/3657154/pexels-photo-3657154.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Illustration","query":"illustration art","imageUrl":"https://images.pexels.com/photos/1633798/pexels-photo-1633798.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Architecture","query":"architecture buildings","imageUrl":"https://images.pexels.com/photos/323780/pexels-photo-323780.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Portraits","query":"portrait","imageUrl":"https://images.pexels.com/photos/1516680/pexels-photo-1516680.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels"]},
  {"name":"Under the Sea","query":"underwater ocean","imageUrl":"https://images.pexels.com/photos/10017673/pexels-photo-10017673.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Quotes","query":"typography quotes","imageUrl":"https://images.pexels.com/photos/6980830/pexels-photo-6980830.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels"]},
  {"name":"Robots","query":"robot technology","imageUrl":"https://images.pexels.com/photos/3861969/pexels-photo-3861969.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Spiritual","query":"spiritual meditation","imageUrl":"https://images.pexels.com/photos/3560044/pexels-photo-3560044.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"3D Renders","query":"3d render art","imageUrl":"https://images.pexels.com/photos/3165335/pexels-photo-3165335.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Fashion","query":"fashion style","imageUrl":"https://images.pexels.com/photos/1536619/pexels-photo-1536619.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Kawaii","query":"cute kawaii","imageUrl":"https://images.pexels.com/photos/1643457/pexels-photo-1643457.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["wallhaven"]},
  {"name":"Sports","query":"sports","imageUrl":"https://images.pexels.com/photos/34563722/pexels-photo-34563722.png?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Comic","query":"comic superhero","imageUrl":"https://images.pexels.com/photos/7809122/pexels-photo-7809122.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["wallhaven"]},
  {"name":"Tech","query":"technology circuit","imageUrl":"https://images.pexels.com/photos/2582937/pexels-photo-2582937.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]},
  {"name":"Gaming","query":"gaming setup","imageUrl":"https://images.pexels.com/photos/3165335/pexels-photo-3165335.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["wallhaven"]},
  {"name":"Food","query":"food photography","imageUrl":"https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels"]},
  {"name":"Music","query":"music vinyl","imageUrl":"https://images.pexels.com/photos/167636/pexels-photo-167636.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940","sources":["pexels","wallhaven"]}
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
