// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get foldersLibraryEmptyTitle => 'अभी कोई फ़ोल्डर नहीं';

  @override
  String get foldersLibraryEmptyBody => 'किसी वॉलपेपर को फ़ोल्डर में सहेजने के लिए उस पर दिल के निशान को दबाए रखें।';

  @override
  String get foldersLoadAllError => 'आपके फ़ोल्डर लोड नहीं हो सके';

  @override
  String get galleryEmptyBody => 'इन्हें हटा दिया गया है या ये अब सार्वजनिक नहीं हैं।';

  @override
  String get galleryEmptyTitle => 'ये वॉलपेपर अब नहीं हैं';

  @override
  String get galleryScreenTitle => 'आपके लिए वॉलपेपर';

  @override
  String wallpaperFavouriteSearchCountHint(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString पसंदीदा में खोजें',
      one: '1 पसंदीदा में खोजें',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteSortAndFilter => 'क्रमबद्ध और फ़िल्टर करें';

  @override
  String get wallpaperFavouriteSortBy => 'इस क्रम में लगाएँ';

  @override
  String get wallpaperFavouriteFilterSource => 'स्रोत';

  @override
  String get wallpaperHistorySetAgain => 'फिर से लगाएँ';

  @override
  String wallpaperHistoryTileLabel(String current, String target, String time) {
    return '$current$target, $time बजे लगाया गया';
  }

  @override
  String get wallpaperProviderWallhaven => 'Wallhaven';

  @override
  String get economyExportFailedLabel => 'एक्सपोर्ट नहीं हो सका';

  @override
  String get coreSignInCreatorSearchFeature => 'क्रिएटर खोज';

  @override
  String get debugLogExportSubject => 'Prism की डिबग लॉग फ़ाइलें';

  @override
  String get accountAbout => 'परिचय';

  @override
  String get accountAboutPrism => 'Prism के बारे में';

  @override
  String get accountAccount => 'खाता';

  @override
  String get accountAccountDeletionSubscriptionWarning =>
      'खाता हटाने पर आपकी स्टोर सदस्यता रद्द नहीं होती। स्टोर में इसे रद्द करने तक बिलिंग जारी रहेगी।';

  @override
  String get accountAdPrivacyChoices => 'विज्ञापन गोपनीयता विकल्प';

  @override
  String get accountAddProfilePhoto => 'प्रोफ़ाइल फ़ोटो जोड़ें';

  @override
  String get accountAddSocialLink => 'एक सोशल लिंक जोड़ें';

  @override
  String get accountAdmin => 'एडमिन';

  @override
  String get accountAdminModeration => 'एडमिन मॉडरेशन';

  @override
  String accountAndroidSharePitch(String url) {
    return 'Android को फिर से अपने अंदाज़ में ढालने का मज़ा लें! Prism देखें -\n$url';
  }

  @override
  String get accountAnyResolution => 'कोई भी';

  @override
  String get accountAppName => 'Prism वॉलपेपर';

  @override
  String get accountAppearance => 'दिखावट';

  @override
  String get accountApply => 'लागू करें';

  @override
  String get accountAskEveryTime => 'हर बार पूछें';

  @override
  String get accountAudience => 'दर्शक';

  @override
  String get accountAutoRotateWallpapers => 'वॉलपेपर अपने-आप बदलें';

  @override
  String get accountBlock => 'ब्लॉक करें';

  @override
  String get accountBlockActionFailed => 'ब्लॉक किए गए खाते अपडेट नहीं हो सके';

  @override
  String get accountBlockActionPendingSync => 'आपका बदलाव इस डिवाइस पर सेव है और मौका मिलते ही सिंक हो जाएगा।';

  @override
  String get accountBlockConfirmationUserFallback => 'यह उपयोगकर्ता';

  @override
  String accountBlockThisUserTitle(String name) {
    return '$name को ब्लॉक करें?';
  }

  @override
  String get accountBlockUser => 'उपयोगकर्ता को ब्लॉक करें';

  @override
  String accountBlockUserMessage(String name) {
    return 'आप $name को अनफ़ॉलो कर देंगे, फ़ीड में उनके वॉलपेपर नहीं दिखेंगे और उनकी नई पोस्ट की सूचनाएँ नहीं मिलेंगी।';
  }

  @override
  String get accountBlockedAccounts => 'ब्लॉक किए गए खाते';

  @override
  String get accountBlockedAccountsEmptyBody =>
      'ब्लॉक करने पर उनकी पोस्ट आपकी फ़ीड से छिप जाती हैं। फिर भी वे आपकी सार्वजनिक प्रोफ़ाइल और वॉलपेपर देख सकते हैं।';

  @override
  String get accountBlockedAccountsLoadError => 'ब्लॉक किए गए खाते लोड नहीं हो सके';

  @override
  String get accountBlockedListUserFallback => 'ब्लॉक किया गया उपयोगकर्ता';

  @override
  String get accountBlockedProfileBody =>
      'उनके वॉलपेपर आपकी फ़ीड और सूचनाओं से छिपे हैं। आप उन्हें कभी भी अनब्लॉक कर सकते हैं।';

  @override
  String get accountBringBackSubscription => 'पहले की सदस्यता वापस लाएँ';

  @override
  String get accountBrowseByCategory => 'श्रेणी के अनुसार देखें';

  @override
  String get accountBrowseByColour => 'रंग के अनुसार देखें';

  @override
  String get accountBuyPremium => 'Premium खरीदें';

  @override
  String get accountCacheCleared => 'कैश साफ़ किया गया।';

  @override
  String accountCacheClearedBytes(String size) {
    return '$size साफ़ किया गया।';
  }

  @override
  String accountCachedImageSize(String size) {
    return 'कैश की गई इमेज $size';
  }

  @override
  String get accountCancel => 'रद्द करें';

  @override
  String get accountCannotGiftThisAccount => 'आप इस खाते को उपहार नहीं भेज सकते।';

  @override
  String accountCategorySemanticLabel(String name) {
    return 'श्रेणी, $name';
  }

  @override
  String get accountChangeAutomatically => 'अपने-आप बदलें';

  @override
  String get accountChangeCoverPhoto => 'कवर फ़ोटो बदलें';

  @override
  String get accountChangeOrCancelStore => 'स्टोर में बदलें या रद्द करें';

  @override
  String get accountChangePhoto => 'फ़ोटो बदलें';

  @override
  String get accountChangeWallpaperOnTimer => 'टाइमर पर वॉलपेपर बदलें';

  @override
  String get accountCheckConnectionTryAgain => 'कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get accountClear => 'साफ़ करें';

  @override
  String get accountClearAllDownloads => 'सभी डाउनलोड हटाएँ';

  @override
  String get accountClearAllFavouritesQuestion => 'सभी पसंदीदा हटाएँ?';

  @override
  String get accountClearCache => 'कैश साफ़ करें';

  @override
  String get accountClearCacheConfirmMessage => 'कैश की गई इमेज हट जाएँगी। ज़रूरत पड़ने पर वे फिर लोड होंगी।';

  @override
  String accountClearCacheConfirmSizeMessage(String size) {
    return 'कैश की गई $size इमेज हट जाएँगी। ज़रूरत पड़ने पर वे फिर लोड होंगी।';
  }

  @override
  String get accountClearCacheQuestion => 'कैश साफ़ करें?';

  @override
  String get accountClearCacheTitle => 'कैश साफ़ करें';

  @override
  String get accountClearCachedImages => 'डिवाइस पर कैश की गई इमेज हटाएँ';

  @override
  String get accountClearColour => 'रंग साफ़ करें';

  @override
  String get accountClearDepthEffect => 'डेप्थ इफ़ेक्ट साफ़ करें';

  @override
  String get accountClearSpatialScene => 'स्पेशियल साफ़ करें';

  @override
  String get accountClearFavouriteWallpapers => 'पसंदीदा वॉलपेपर हटाएँ';

  @override
  String get accountClearFavourites => 'पसंदीदा हटाएँ';

  @override
  String accountClearFavouritesCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString पसंदीदा वॉलपेपर हटाए जाएँगे',
      one: '1 पसंदीदा वॉलपेपर हटाया जाएगा',
    );
    return 'आपके खाते से $_temp0। इसे वापस नहीं किया जा सकता।';
  }

  @override
  String get accountClearFavouritesMessage =>
      'आपके खाते से सभी पसंदीदा वॉलपेपर हटा दिए जाएँगे। इसे वापस नहीं किया जा सकता।';

  @override
  String get accountClearLearnedTaste => 'सीखी हुई पसंद मिटाएँ';

  @override
  String accountClearLearnedTasteCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString बातें', one: '1 बात');
    return 'Prism, आपके देखे और सेव किए गए कंटेंट से सीखी $_temp0 भूल जाएगा। आपकी फ़ीड फिर से आपकी चुनी हुई रुचियों के आधार पर दिखेगी। इसे वापस नहीं किया जा सकता।';
  }

  @override
  String get accountClearLearnedTasteQuestion => 'सीखी हुई पसंद मिटाएँ?';

  @override
  String get accountClearSearch => 'खोज साफ़ करें';

  @override
  String get accountColour => 'रंग';

  @override
  String accountCommitCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString कमिट',
      one: '1 कमिट',
      zero: 'कोई कमिट नहीं',
    );
    return '$_temp0';
  }

  @override
  String get accountCompleteProfile => 'प्रोफ़ाइल पूरी करें';

  @override
  String get accountCompleteYourProfile => 'अपनी प्रोफ़ाइल पूरी करें';

  @override
  String get accountConnectionTryAgain => 'कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get accountContent => 'कंटेंट';

  @override
  String get accountContributor => 'योगदानकर्ता';

  @override
  String accountContributorCommitCount(String login, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString कमिट',
      one: '1 कमिट',
      zero: 'कोई कमिट नहीं',
    );
    return '$login, $_temp0';
  }

  @override
  String get accountCopy => 'कॉपी करें';

  @override
  String get accountCopyLink => 'लिंक कॉपी करें';

  @override
  String get accountCouldNotBuildReport => 'रिपोर्ट नहीं बन सकी। फिर कोशिश करें।';

  @override
  String get accountCouldNotClearFavourites => 'पसंदीदा वॉलपेपर नहीं हट सके। फिर कोशिश करें।';

  @override
  String get accountCouldNotClearLearnedTaste => 'सीखी हुई पसंद नहीं मिटाई जा सकी। फिर कोशिश करें।';

  @override
  String get accountCouldNotCreateLink => 'लिंक नहीं बनाया जा सका। फिर कोशिश करें।';

  @override
  String get accountCouldNotDeleteDownloads => 'डाउनलोड नहीं हटाए जा सके। फिर कोशिश करें।';

  @override
  String accountCouldNotFollowPerson(String name) {
    return '$name को फ़ॉलो नहीं किया जा सका। फिर कोशिश करें।';
  }

  @override
  String get accountCouldNotLoadFollowers => 'फ़ॉलोअर्स लोड नहीं हो सके';

  @override
  String get accountCouldNotLoadFollowing => 'फ़ॉलो किए गए खाते लोड नहीं हो सके';

  @override
  String get accountCouldNotLoadTeam => 'टीम लोड नहीं हो सकी';

  @override
  String get accountCouldNotLoadThisProfile => 'यह प्रोफ़ाइल लोड नहीं हो सकी';

  @override
  String get accountCouldNotLoadTrending => 'ट्रेंडिंग कंटेंट लोड नहीं हो सका';

  @override
  String get accountCouldNotLoadWallpapers => 'वॉलपेपर लोड नहीं हो सके';

  @override
  String accountCouldNotOpenAddress(String address) {
    return '$address नहीं खुला';
  }

  @override
  String get accountCouldNotOpenLink => 'लिंक नहीं खुला। फिर कोशिश करें।';

  @override
  String get accountCouldNotOpenStore => 'स्टोर नहीं खुला। फिर कोशिश करें।';

  @override
  String get accountCouldNotOpenThisLink => 'यह लिंक नहीं खुला।';

  @override
  String get accountCouldNotRefreshSearch => 'रीफ़्रेश नहीं हो सका। फिर कोशिश करने के लिए नीचे खींचें।';

  @override
  String get accountCouldNotRemoveSavedOffline => 'ऑफ़लाइन सेव किए गए वॉलपेपर नहीं हटे। फिर कोशिश करें।';

  @override
  String get accountCouldNotRestorePurchases => 'खरीदारियाँ वापस नहीं लाई जा सकीं। फिर कोशिश करें।';

  @override
  String get accountCouldNotSearchCreators => 'क्रिएटर खोजे नहीं जा सके';

  @override
  String get accountCouldNotSearchRightNow => 'अभी खोज नहीं हो सकी';

  @override
  String get accountCouldNotSendGift => 'उपहार नहीं भेजा जा सका। फिर कोशिश करें।';

  @override
  String get accountCouldNotShareReport => 'रिपोर्ट साझा नहीं की जा सकी। फिर कोशिश करें।';

  @override
  String accountCouldNotUnfollowPerson(String name) {
    return '$name को अनफ़ॉलो नहीं किया जा सका। फिर कोशिश करें।';
  }

  @override
  String get accountCreatorFallback => 'Prism क्रिएटर';

  @override
  String get accountCreatorSearchEmptyBody => 'वर्तनी जाँचें या कोई दूसरा नाम आज़माएँ।';

  @override
  String get accountCurrentSignedInAccountRequired => 'कृपया वह खाता चुनें जिसमें आपने अभी साइन इन किया है।';

  @override
  String get accountDataSaver => 'डेटा सेवर';

  @override
  String get accountDataSaverDescription =>
      'मोबाइल डेटा बचाता है। वॉलपेपर थंबनेल के रूप में खुलते हैं, फ़ीड पहले से लोड नहीं होती और कैरोसेल अपने-आप नहीं चलते।';

  @override
  String get accountDatabaseUsageStats => 'डेटाबेस उपयोग और आँकड़े';

  @override
  String get accountDebugPanel => 'डीबग पैनल';

  @override
  String get accountDefaultActionForSet => 'सेट करने की डिफ़ॉल्ट कार्रवाई';

  @override
  String get accountDeleteAccount => 'खाता हटाएँ';

  @override
  String get accountDeleteAccountConfirmation =>
      'इससे आपका खाता हमेशा के लिए हट जाएगा, आपका निजी डेटा मिट जाएगा और आप साइन आउट हो जाएँगे।\n\nआपके अपलोड किए गए वॉलपेपर \"हटाया गया खाता\" नाम से दिखते रहेंगे।\n\nयह कार्रवाई वापस नहीं की जा सकती।';

  @override
  String get accountDeleteAccountReauthNote => 'अगले चरण में आप Google या Apple से पुष्टि करेंगे।';

  @override
  String get accountDeleteAll => 'सभी हटाएँ';

  @override
  String get accountDeleteAllDownloadsQuestion => 'सभी डाउनलोड हटाएँ?';

  @override
  String accountDeleteDownloadsCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString डाउनलोड किए गए वॉलपेपर हटाए जाएँगे',
      one: '1 डाउनलोड किया गया वॉलपेपर हटाया जाएगा',
    );
    return 'डाउनलोड से $_temp0। ऑफ़लाइन सेव की गई प्रतियाँ प्रभावित नहीं होंगी। इसे वापस नहीं किया जा सकता।';
  }

  @override
  String get accountDeleteDownloadsMessage =>
      'डाउनलोड किए गए वॉलपेपर डाउनलोड से हट जाएँगे। ऑफ़लाइन सेव की गई प्रतियाँ प्रभावित नहीं होंगी। इसे वापस नहीं किया जा सकता।';

  @override
  String get accountDeleteYourAccountQuestion => 'अपना खाता हटाएँ?';

  @override
  String get accountDeletingYourAccount => 'आपका खाता हटाया जा रहा है';

  @override
  String get accountDepthEffect => 'डेप्थ इफ़ेक्ट';

  @override
  String get accountDepthEffectClockSemanticLabel => 'डेप्थ इफ़ेक्ट, विषय घड़ी के सामने';

  @override
  String get accountSpatialScene => 'स्पेशियल';

  @override
  String get accountSpatialSceneSubtitle => 'स्पष्ट 3D गहराई वाले वॉलपेपर';

  @override
  String get accountSpatialSceneSemanticLabel => 'स्पेशियल, स्पष्ट 3D गहराई वाले वॉलपेपर';

  @override
  String accountDownloadedWallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString डाउनलोड किए हुए वॉलपेपर; ऑफ़लाइन सेव प्रतियाँ बनी रहेंगी',
      one: '1 डाउनलोड किया हुआ वॉलपेपर; ऑफ़लाइन सेव प्रतियाँ बनी रहेंगी',
      zero: 'कोई डाउनलोड किया हुआ वॉलपेपर नहीं; ऑफ़लाइन सेव प्रतियाँ बनी रहेंगी',
    );
    return '$_temp0';
  }

  @override
  String get accountDownloadsDeleted => 'सभी डाउनलोड हटा दिए गए।';

  @override
  String get accountEarnCoins => 'कॉइन कमाएँ';

  @override
  String accountEarnProfileCompletionCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'पूरा करने पर $coinsString कॉइन कमाएँ';
  }

  @override
  String get accountEditCover => 'कवर संपादित करें';

  @override
  String get accountEditProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get accountExportFavourites => 'पसंदीदा एक्सपोर्ट करें';

  @override
  String get accountFavouritesCleared => 'सभी पसंदीदा वॉलपेपर हटा दिए गए।';

  @override
  String get accountFeedback => 'फ़ीडबैक';

  @override
  String get accountFeedbackSubject => 'Prism फ़ीडबैक';

  @override
  String get accountFields => 'फ़ील्ड';

  @override
  String get accountFilters => 'फ़िल्टर';

  @override
  String get accountFindCreators => 'क्रिएटर खोजें';

  @override
  String get accountFinishYourProfile => 'अपनी प्रोफ़ाइल पूरी करें';

  @override
  String get accountFirestoreTelemetry => 'Firestore टेलीमेट्री';

  @override
  String get accountFollow => 'फ़ॉलो करें';

  @override
  String accountFollowPerson(String name) {
    return '$name को फ़ॉलो करें';
  }

  @override
  String accountFollowedPerson(String name) {
    return '$name को फ़ॉलो कर लिया!';
  }

  @override
  String get accountFollowers => 'फ़ॉलोअर्स';

  @override
  String accountFollowersCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ॉलोअर्स',
      one: '1 फ़ॉलोअर',
      zero: 'कोई फ़ॉलोअर नहीं',
    );
    return '$_temp0';
  }

  @override
  String accountFollowersCountLabel(String compactCount) {
    return '$compactCount फ़ॉलोअर्स';
  }

  @override
  String get accountFollowersEmptyMessage => 'इस खाते को फ़ॉलो करने वाले लोग यहाँ दिखेंगे।';

  @override
  String get accountFollowing => 'फ़ॉलोइंग';

  @override
  String accountFollowingCountLabel(String compactCount) {
    return '$compactCount फ़ॉलोइंग';
  }

  @override
  String get accountFollowingEmptyMessage => 'आप जिन खातों को फ़ॉलो करते हैं, वे यहाँ दिखेंगे।';

  @override
  String get accountForgetFeedLearned => 'आपकी फ़ीड ने आपके बारे में जो सीखा है, उसे भूलें';

  @override
  String get accountFromPrism => 'Prism से';

  @override
  String get accountGiftLimitReached => 'अभी उपहार भेजने की सीमा पूरी हो गई है। कल फिर कोशिश करें।';

  @override
  String accountGiftPassMessage(String recipientName, int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$recipientName को कल तक Premium कलेक्शन और Premium वॉलपेपर मिलेंगे। कीमत $priceString कॉइन है।';
  }

  @override
  String get accountGiftPassTitle => '24 घंटे का Pro पास उपहार में दें';

  @override
  String get accountGiftPassTooltip => '24 घंटे का पास उपहार में दें';

  @override
  String get accountGiftsOpenAfterSevenDays => 'खाते के 7 दिन पुराने होने पर उपहार भेजे जा सकते हैं।';

  @override
  String get accountHapticFeedback => 'हैप्टिक फ़ीडबैक';

  @override
  String get accountHelp => 'मदद';

  @override
  String get accountHomeAndLockScreens => 'होम और लॉक स्क्रीन';

  @override
  String get accountHomeScreen => 'होम स्क्रीन';

  @override
  String get accountInviteFriends => 'दोस्तों को आमंत्रित करें';

  @override
  String get accountInviteLinkCouldNotCreate => 'आपका आमंत्रण लिंक नहीं बन सका।';

  @override
  String accountInviteRewardHeadline(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString दें, $coinsString पाएँ';
  }

  @override
  String accountInviteRewardMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'जुड़ने पर आपके दोस्त को $coinsString कॉइन मिलेंगे। आपको भी $coinsString मिलेंगे।';
  }

  @override
  String get accountInviteShareFailed => 'अभी आमंत्रण साझा नहीं किया जा सका।';

  @override
  String accountIosSharePitch(String url) {
    return 'अपने फ़ोन को फिर से अपने अंदाज़ में ढालने का मज़ा लें! Prism देखें -\n$url';
  }

  @override
  String get accountLater => 'बाद में';

  @override
  String get accountLatest => 'नवीनतम';

  @override
  String get accountLearnedTasteCleared => 'सीखी हुई पसंद मिटा दी गई।';

  @override
  String get accountLibrary => 'लाइब्रेरी';

  @override
  String get accountLightDarkAccentColour => 'हल्का, गहरा और एक्सेंट रंग';

  @override
  String get accountLink => 'लिंक';

  @override
  String get accountLinkCopied => 'लिंक कॉपी किया गया';

  @override
  String get accountLinkType => 'लिंक का प्रकार';

  @override
  String get accountLinkTypeBehance => 'Behance';

  @override
  String get accountLinkTypeBioLink => 'bio.link';

  @override
  String get accountLinkTypeBuyMeACoffee => 'Buy Me a Coffee';

  @override
  String get accountLinkTypeCustom => 'कस्टम लिंक';

  @override
  String get accountLinkTypeDeviantArt => 'DeviantArt';

  @override
  String get accountLinkTypeDribbble => 'Dribbble';

  @override
  String get accountLinkTypeEmail => 'ईमेल';

  @override
  String get accountLinkTypeGithub => 'GitHub';

  @override
  String get accountLinkTypeGitlab => 'GitLab';

  @override
  String get accountLinkTypeInstagram => 'Instagram';

  @override
  String get accountLinkTypeLinkedin => 'LinkedIn';

  @override
  String get accountLinkTypeLinktree => 'Linktree';

  @override
  String get accountLinkTypeMedium => 'Medium';

  @override
  String get accountLinkTypePatreon => 'Patreon';

  @override
  String get accountLinkTypePaypal => 'PayPal';

  @override
  String get accountLinkTypeReddit => 'Reddit';

  @override
  String accountLinkTypeSemanticLabel(String name) {
    return 'लिंक का प्रकार, $name';
  }

  @override
  String get accountLinkTypeSpotify => 'Spotify';

  @override
  String get accountLinkTypeTelegram => 'Telegram';

  @override
  String get accountLinkTypeTrello => 'Trello';

  @override
  String get accountLinkTypeTwitch => 'Twitch';

  @override
  String get accountLinkTypeTwitter => 'Twitter';

  @override
  String get accountLinkTypeUnsplash => 'Unsplash';

  @override
  String get accountLinkTypeYoutube => 'YouTube';

  @override
  String get accountLiveWallpapers => 'लाइव वॉलपेपर';

  @override
  String get accountLoadingTeam => 'टीम लोड हो रही है';

  @override
  String get accountLockScreen => 'लॉक स्क्रीन';

  @override
  String get accountLogOut => 'साइन आउट करें';

  @override
  String get accountLogOutOfPrismQuestion => 'Prism से साइन आउट करें?';

  @override
  String get accountLogOutQuestion => 'साइन आउट करें?';

  @override
  String get accountLogoutConfirmation =>
      'साइन आउट करने पर इस डिवाइस का इतिहास और सीखी हुई पसंद मिट जाएगी। पसंदीदा, कॉइन और प्रोफ़ाइल आपके खाते में बने रहेंगे।';

  @override
  String get accountLogoutFailed => 'साइन आउट नहीं हो सका। फिर कोशिश करें।';

  @override
  String get accountLogsNetworkToolsStorage => 'लॉग, नेटवर्क, टूल और स्टोरेज';

  @override
  String get accountMadeWithLoveInIndia => 'Flutter के साथ भारत में ❤ से बनाया गया!';

  @override
  String get accountManageBlockedPeople => 'ब्लॉक किए गए लोगों को प्रबंधित करें';

  @override
  String get accountManageSubscription => 'सब्सक्रिप्शन प्रबंधित करें';

  @override
  String get accountMenu => 'मेन्यू';

  @override
  String get accountMinResolution => 'न्यूनतम रिज़ॉल्यूशन';

  @override
  String get accountMoreLinks => 'और लिंक';

  @override
  String get accountMoreOptions => 'और विकल्प';

  @override
  String get accountMovingGradientsMotionVideo => 'चलते ग्रेडिएंट, मोशन और वीडियो';

  @override
  String get accountMyAccent => 'मेरा ऐक्सेंट';

  @override
  String get accountNoBlockedAccounts => 'कोई ब्लॉक किया हुआ अकाउंट नहीं';

  @override
  String get accountNoContributors => 'अभी दिखाने के लिए कोई योगदानकर्ता नहीं है।';

  @override
  String get accountNoCreatorsFound => 'कोई क्रिएटर नहीं मिला';

  @override
  String get accountNoDownloadsToRemove => 'हटाने के लिए कोई डाउनलोड नहीं है।';

  @override
  String get accountNoFollowersYet => 'अभी कोई फ़ॉलोअर नहीं है';

  @override
  String get accountNoPurchasesToRestore => 'इस अकाउंट के लिए वापस पाने योग्य कोई खरीदारी नहीं है।';

  @override
  String get accountNoResults => 'कोई नतीजा नहीं';

  @override
  String accountNoWallpapersForFilters(String filters) {
    return '$filters के लिए कोई वॉलपेपर नहीं मिला';
  }

  @override
  String accountNoWallpapersForQueryWithFilters(String query) {
    return 'चुने गए फ़िल्टर के साथ $query के लिए कोई वॉलपेपर नहीं मिला।';
  }

  @override
  String get accountNoWallpapersFound => 'कोई वॉलपेपर नहीं मिला';

  @override
  String accountNoWallpapersFoundForQuery(String query) {
    return '$query के लिए कोई वॉलपेपर नहीं मिला';
  }

  @override
  String get accountNoWallpapersYet => 'अभी कोई वॉलपेपर नहीं है';

  @override
  String accountNobodyMatchesUsername(String query) {
    return '\"$query\" से मेल खाने वाला कोई नहीं मिला। कोई दूसरा यूज़रनेम आज़माएँ।';
  }

  @override
  String get accountNotEnoughCoinsEarnInRewards => 'पर्याप्त कॉइन नहीं हैं। इनाम में कॉइन कमाएँ।';

  @override
  String get accountNotFollowingAnyoneYet => 'अभी आप किसी को फ़ॉलो नहीं कर रहे हैं';

  @override
  String get accountNotSynced => 'सिंक नहीं हुआ';

  @override
  String get accountNothingLearnedYet => 'Prism ने अभी तक कुछ नहीं सीखा है।';

  @override
  String get accountNotificationPreferences => 'नोटिफ़िकेशन प्राथमिकताएँ';

  @override
  String get accountNotificationTypes => 'आज का वॉलपेपर, फ़ॉलोअर, पोस्ट और बहुत कुछ';

  @override
  String get accountNotifications => 'नोटिफ़िकेशन';

  @override
  String get accountOpenYourProfile => 'अपनी प्रोफ़ाइल खोलें';

  @override
  String get accountOpeningProfileEditor => 'प्रोफ़ाइल एडिटर खुल रहा है';

  @override
  String get accountOpens => 'खुलता है';

  @override
  String get accountOtherContributors => 'अन्य योगदानकर्ता';

  @override
  String accountPassSentToPerson(String name) {
    return 'पास $name को भेज दिया गया।';
  }

  @override
  String accountPersonAlreadyHasPro(String name) {
    return '$name के पास पहले से Pro है।';
  }

  @override
  String get accountPersonalise => 'अपने अनुसार बनाएँ';

  @override
  String get accountPortraitOnly => 'केवल पोर्ट्रेट';

  @override
  String get accountPremiumBenefitsActive => 'आपको सभी Premium वॉलपेपर, मुफ़्त डाउनलोड और मुफ़्त फ़िल्टर मिलते हैं।';

  @override
  String get accountPremiumBenefitsInactive => 'Premium वॉलपेपर, मुफ़्त डाउनलोड और मुफ़्त फ़िल्टर अनलॉक करें।';

  @override
  String get accountPreview => 'प्रीव्यू';

  @override
  String get accountPrismListPrivacySubtitle => 'Prism आपका डेटा कैसे संभालता है';

  @override
  String get accountPrismPro => 'Prism Pro';

  @override
  String get accountPrivacyAction => 'गोपनीयता';

  @override
  String get accountPrivacyAndData => 'गोपनीयता और डेटा';

  @override
  String get accountPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get accountProBadge => 'Pro';

  @override
  String get accountProWallpaperSemantics => 'Pro वॉलपेपर';

  @override
  String get accountProblemReportSharePrompt => 'कृपया बताएँ कि क्या गड़बड़ी हुई। रिपोर्ट फ़ाइल में विवरण हैं।';

  @override
  String get accountProblemReportShareSubject => 'Prism समस्या रिपोर्ट';

  @override
  String get accountProfile => 'प्रोफ़ाइल';

  @override
  String get accountProfileNotAvailable => 'प्रोफ़ाइल उपलब्ध नहीं है';

  @override
  String get accountProfileNotAvailableBody =>
      'यह यूज़र Prism के नवीनतम वर्ज़न पर सक्रिय नहीं है, इसलिए उनकी प्रोफ़ाइल नहीं दिखाई जा सकती।';

  @override
  String accountProfileNudgeMessage(int percent, int coins) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'आपकी प्रोफ़ाइल $percentString% पूरी है। इसे पूरा करके $coinsString Prism कॉइन कमाएँ।';
  }

  @override
  String accountProfilePercentComplete(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'प्रोफ़ाइल $percentString% पूरी';
  }

  @override
  String accountProfilePersonSemantics(String name, String username) {
    return '$name, @$username';
  }

  @override
  String get accountProfiles => 'प्रोफ़ाइलें';

  @override
  String get accountPurchases => 'खरीदारियाँ';

  @override
  String get accountPurchasesRestored => 'खरीदारियाँ वापस पा ली गईं।';

  @override
  String get accountPurchasesRestoredPending => 'खरीदारियाँ वापस पा ली गईं। Pro अनलॉक होने में एक मिनट लग सकता है।';

  @override
  String get accountQuickTiles => 'क्विक टाइलें';

  @override
  String get accountRateApp => 'रेट करें';

  @override
  String get accountRecentSearches => 'हाल की खोजें';

  @override
  String get accountRelevance => 'प्रासंगिकता';

  @override
  String get accountRemoveAllFavouriteWallpapers => 'सभी पसंदीदा वॉलपेपर हटाएँ';

  @override
  String get accountRemoveCoverPhoto => 'कवर फ़ोटो हटाएँ';

  @override
  String get accountRemoveFilesDownloadsOfflineStay => 'डाउनलोड से फ़ाइलें हटाएँ; ऑफ़लाइन सेव की गई कॉपियाँ बनी रहेंगी';

  @override
  String get accountRemoveLink => 'लिंक हटाएँ';

  @override
  String get accountRemovePhoto => 'फ़ोटो हटाएँ';

  @override
  String get accountRemoveSavedOffline => 'ऑफ़लाइन सेव की गई चीज़ें हटाएँ';

  @override
  String accountRemoveSavedOfflineCountMessage(String size) {
    return 'रखी गई ऑफ़लाइन मूल फ़ाइलों में से $size हटाई जाएँगी। डाउनलोड, ड्राफ़्ट और कैटलॉग डेटा जस का तस रहेगा।';
  }

  @override
  String get accountRemoveSavedOfflineMessage =>
      'इस डिवाइस से रखी गई ऑफ़लाइन मूल फ़ाइलें हटाएँ। डाउनलोड, ड्राफ़्ट और कैटलॉग डेटा जस का तस रहेगा।';

  @override
  String get accountRemoveSavedOfflineQuestion => 'ऑफ़लाइन सेव किए गए वॉलपेपर हटाएँ?';

  @override
  String get accountReportAProblem => 'समस्या की रिपोर्ट करें';

  @override
  String accountReportPreviewNotice(String email) {
    return 'इस रिपोर्ट में आपके ऐप का वर्ज़न, डिवाइस और हाल के लॉग शामिल हैं। इसमें ईमेल पता या साइन-इन टोकन नहीं हैं। इसे पढ़ें, फिर $email के साथ शेयर करें।';
  }

  @override
  String get accountReportProblemSubtitle => 'Prism टीम के साथ अपने ऐप लॉग शेयर करें';

  @override
  String get accountReportUser => 'यूज़र की रिपोर्ट करें';

  @override
  String get accountReset => 'रीसेट करें';

  @override
  String get accountResetFilters => 'फ़िल्टर रीसेट करें';

  @override
  String get accountResolution1080 => '1080p';

  @override
  String get accountResolution1440 => '1440p';

  @override
  String get accountResolution4k => '4K';

  @override
  String get accountRestorePurchases => 'खरीदारियाँ वापस पाएँ';

  @override
  String get accountRestoringPurchases => 'खरीदारियाँ वापस पाई जा रही हैं…';

  @override
  String accountResultsForQuery(String query) {
    return '$query के नतीजे';
  }

  @override
  String get accountRetry => 'फिर कोशिश करें';

  @override
  String get accountReviewOrChangeAdConsent => 'विज्ञापन सहमति देखें या बदलें';

  @override
  String get accountReviewStatus => 'समीक्षा की स्थिति';

  @override
  String get accountReviewSubmittedContent => 'जमा की गई सामग्री की समीक्षा करें';

  @override
  String get accountSaveFavouritesAsFile => 'अपने पसंदीदा वॉलपेपर की कॉपी फ़ाइल के रूप में सेव करें';

  @override
  String get accountSavedOffline => 'ऑफ़लाइन सेव किया गया';

  @override
  String get accountSavedOfflineRemoved => 'ऑफ़लाइन सेव किए गए वॉलपेपर हटा दिए गए।';

  @override
  String accountSavedOfflineStorageUnavailable(int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'स्टोरेज उपलब्ध नहीं · $limitString MiB सीमा';
  }

  @override
  String accountSavedOfflineStorageUsed(String size, int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$size इस्तेमाल हुआ · $limitString MiB सीमा';
  }

  @override
  String get accountSavedOnThisDevice => 'इस डिवाइस पर सेव किया गया';

  @override
  String get accountSearch => 'खोजें';

  @override
  String get accountSearchByUsername => 'यूज़रनेम से खोजें';

  @override
  String get accountSearchCreators => 'क्रिएटर खोजें';

  @override
  String get accountSearchCreatorsByName => 'नाम से क्रिएटर खोजें';

  @override
  String get accountSearchFilters => 'फ़िल्टर';

  @override
  String get accountSearchPrismUsersByName => 'नाम से Prism यूज़र खोजें';

  @override
  String get accountSearchWallpapers => 'वॉलपेपर खोजें';

  @override
  String get accountSeeChangelog => 'बदलावों की सूची देखें';

  @override
  String get accountSendGift => 'उपहार भेजें';

  @override
  String get accountSendProfileLink => 'अपनी Prism प्रोफ़ाइल का लिंक भेजें';

  @override
  String get accountSetUpQuickTiles => 'त्वरित सेटिंग्स टाइलें सेट अप करें';

  @override
  String get accountSetUsername => 'यूज़रनेम सेट करें';

  @override
  String get accountSettings => 'सेटिंग्स';

  @override
  String get accountShare => 'शेयर करें';

  @override
  String get accountShareInvite => 'निमंत्रण शेयर करें';

  @override
  String get accountSharePrism => 'Prism शेयर करें';

  @override
  String get accountSharePrismFriendSubtitle => 'किसी दोस्त को लिंक भेजें';

  @override
  String get accountShareProfile => 'प्रोफ़ाइल शेयर करें';

  @override
  String get accountShareProfileLinkFailed => 'लिंक नहीं बन सका। फिर कोशिश करें।';

  @override
  String get accountShareYourProfile => 'अपनी प्रोफ़ाइल शेयर करें';

  @override
  String get accountShop => 'दुकान';

  @override
  String get accountShowAnimeWallpapers => 'ऐनिमे वॉलपेपर दिखाएँ';

  @override
  String get accountShowSketchyWallpapers => 'स्केची वॉलपेपर दिखाएँ';

  @override
  String get accountSignIn => 'साइन इन करें';

  @override
  String get accountSignInAgainToDelete =>
      'कृपया साइन आउट करके फिर साइन इन करें, उसके बाद अपना अकाउंट हटाने की कोशिश करें।';

  @override
  String get accountSignInBenefits => 'अपने पसंदीदा, कॉइन और प्रोफ़ाइल सुरक्षित रखने के लिए साइन इन करें';

  @override
  String get accountSignInForInviteLink => 'अपना आमंत्रण लिंक पाने के लिए साइन इन करें।';

  @override
  String get accountSignInToPrism => 'Prism में साइन इन करें';

  @override
  String get accountSocialGithub => 'GITHUB';

  @override
  String get accountSocialInstagram => 'INSTAGRAM';

  @override
  String get accountSocialTelegram => 'TELEGRAM';

  @override
  String get accountSocialTwitter => 'TWITTER';

  @override
  String get accountSomethingWentWrongTryAgain => 'कुछ गड़बड़ हुई। फिर कोशिश करें।';

  @override
  String get accountSort => 'क्रमबद्ध करें';

  @override
  String get accountStorage => 'स्टोरेज';

  @override
  String accountStorageSizeBytes(String size) {
    return '$size B';
  }

  @override
  String accountStorageSizeGigabytes(String size) {
    return '$size GB';
  }

  @override
  String accountStorageSizeKilobytes(String size) {
    return '$size KB';
  }

  @override
  String accountStorageSizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String get accountSubjectCanSitInFrontOfClock => 'मुख्य विषय घड़ी के सामने दिखाई दे सकता है';

  @override
  String get accountSubjectInFrontOfClock => 'घड़ी के सामने मुख्य विषय';

  @override
  String get accountTerms => 'शर्तें';

  @override
  String get accountTermsAction => 'शर्तें';

  @override
  String accountTermsAgreementSemanticLabel(String terms, String privacy) {
    return 'जारी रखकर आप $terms और $privacy से सहमत होते हैं';
  }

  @override
  String get accountTermsOfUse => 'उपयोग की शर्तें';

  @override
  String get accountTheTeam => 'टीम';

  @override
  String get accountThemes => 'थीम';

  @override
  String get accountThemesIconsFrames => 'थीम, आइकन, फ़्रेम';

  @override
  String get accountThisUser => 'यह यूज़र';

  @override
  String get accountTop => 'सबसे ऊपर';

  @override
  String get accountTrackSubmittedWallpapers => 'जमा किए गए अपने वॉलपेपर की स्थिति देखें';

  @override
  String get accountTrendingNow => 'अभी ट्रेंडिंग';

  @override
  String get accountTryAgain => 'फिर कोशिश करें';

  @override
  String get accountTryFewerFilters => 'कम फ़िल्टर लगाकर देखें।';

  @override
  String get accountTryShorterOrDifferentWord => 'कोई छोटा या दूसरा शब्द आज़माएँ।';

  @override
  String get accountUnblock => 'अनब्लॉक करें';

  @override
  String get accountUnblockUserMessage => 'उनकी पोस्ट फिर से आपकी फ़ीड में दिखेंगी।';

  @override
  String accountUnblockUserTitle(String name) {
    return '$name को अनब्लॉक करें?';
  }

  @override
  String get accountUnfollow => 'अनफ़ॉलो करें';

  @override
  String accountUnfollowPerson(String name) {
    return '$name को अनफ़ॉलो करें';
  }

  @override
  String accountUnfollowedPerson(String name) {
    return '$name को अनफ़ॉलो कर दिया गया!';
  }

  @override
  String get accountUnlimitedUploadsFilters => 'अनलिमिटेड अपलोड और फ़िल्टर';

  @override
  String get accountUploadFirstWallpaper => 'अपनी गैलरी शुरू करने के लिए पहला वॉलपेपर अपलोड करें।';

  @override
  String get accountUseShortcutsAutomation => 'Shortcuts ऑटोमेशन का इस्तेमाल करें';

  @override
  String accountUserBlocked(String name) {
    return '$name को ब्लॉक कर दिया गया';
  }

  @override
  String get accountUserUnblocked => 'अनब्लॉक कर दिया गया';

  @override
  String accountVersionLabel(String version) {
    return 'वर्ज़न $version';
  }

  @override
  String get accountVibrateOnTapsAndActions => 'टैप और क्रियाओं पर वाइब्रेट करें';

  @override
  String get accountWaitingToSync => 'सिंक होने की प्रतीक्षा में';

  @override
  String get accountWallpaperHistory => 'वॉलपेपर इतिहास';

  @override
  String get accountWallpaperManagerTagline => 'सुविधाओं से भरपूर वॉलपेपर मैनेजर।';

  @override
  String get accountWallpaperSourceNames => 'Prism वॉलपेपर के लिए Wallhaven और Pexels का इस्तेमाल करता है';

  @override
  String get accountWallpaperSources => 'वॉलपेपर स्रोत';

  @override
  String get accountWallpaperSourcesMessage => 'Prism आपको वॉलपेपर देने के लिए इन सेवाओं का इस्तेमाल करता है।';

  @override
  String get accountWallpapersSetBefore => 'पहले सेट किए गए वॉलपेपर';

  @override
  String get accountWhatsNew => 'नया क्या है';

  @override
  String get accountWhatsNewAction => 'नया क्या है';

  @override
  String get accountWriteBio => 'बायो लिखें';

  @override
  String accountYouBlockedUser(String name) {
    return 'आपने $name को ब्लॉक किया';
  }

  @override
  String get accountYourContent => 'आपकी सामग्री';

  @override
  String get accountYourProfile => 'आपकी प्रोफ़ाइल';

  @override
  String get actionCancel => 'रद्द करें';

  @override
  String get actionClose => 'बंद करें';

  @override
  String get actionDone => 'हो गया';

  @override
  String get actionRetry => 'फिर कोशिश करें';

  @override
  String get adminAllCaughtUp => 'सब कुछ देख लिया गया';

  @override
  String get adminAllUsers => 'सभी यूज़र';

  @override
  String get adminAnnouncementInbox => 'घोषणा (इनबॉक्स)';

  @override
  String get adminAnonymous => 'अनाम';

  @override
  String get adminApprovalFailed => 'मंज़ूरी नहीं मिली। अपना कनेक्शन जाँचें, फिर कोशिश करें।';

  @override
  String get adminApprove => 'मंज़ूर करें';

  @override
  String get adminApproved => 'मंज़ूर';

  @override
  String get adminBackToReviewList => 'समीक्षा सूची पर वापस जाएँ';

  @override
  String get adminBatchActionFailed => 'समीक्षा की यह कार्रवाई पूरी नहीं हो सकी। फिर कोशिश करें।';

  @override
  String get adminBatchComplete => 'बैच पूरा हुआ';

  @override
  String get adminBodyLabel => 'मुख्य पाठ';

  @override
  String get adminBodyRequired => 'मुख्य पाठ ज़रूरी है';

  @override
  String get adminBy => 'द्वारा';

  @override
  String get adminByCollection => 'कलेक्शन के अनुसार';

  @override
  String get adminByOperation => 'कार्रवाई के अनुसार';

  @override
  String get adminBySourceTop15 => 'स्रोत के अनुसार (शीर्ष 15)';

  @override
  String get adminCancel => 'रद्द करें';

  @override
  String get adminChangeDepthEffect => 'डेप्थ इफ़ेक्ट बदलें';

  @override
  String get adminCheckConnectionRetry => 'अपना कनेक्शन जाँचें, फिर कोशिश करें।';

  @override
  String get adminClose => 'बंद करें';

  @override
  String adminContentTypeReport(String type) {
    return '$type रिपोर्ट';
  }

  @override
  String get adminCopyAllData => 'सारा डेटा कॉपी करें';

  @override
  String get adminCouldNotLoadWallpaper => 'वॉलपेपर लोड नहीं हो सका';

  @override
  String get adminCreatorWillSeeFeedback => 'क्रिएटर यह प्रतिक्रिया देखेगा।';

  @override
  String get adminDepth => 'गहराई';

  @override
  String adminDepthTier(String tier) {
    return 'गहराई: $tier';
  }

  @override
  String get adminDepthTierAuto => 'अपने-आप';

  @override
  String get adminDepthTierMenu => 'मेन्यू';

  @override
  String get adminDepthTierNone => 'कोई नहीं';

  @override
  String get adminDepthTierNotChecked => 'जाँच नहीं हुई';

  @override
  String get adminDrop => 'ड्रॉप';

  @override
  String get adminEmail => 'ईमेल';

  @override
  String get adminEmailExample => 'user@example.com';

  @override
  String get adminEmailRequired => 'ईमेल ज़रूरी है';

  @override
  String get adminEstimatedDocumentReads => 'दस्तावेज़ पढ़ने का अनुमानित आँकड़ा';

  @override
  String get adminEstimatedDocumentWrites => 'दस्तावेज़ लिखने का अनुमानित आँकड़ा';

  @override
  String adminFactLabel(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminFirestoreTelemetry => 'Firestore टेलीमेट्री';

  @override
  String get adminFollowersScreen => 'फ़ॉलोअर्स स्क्रीन';

  @override
  String get adminFreeUsers => 'मुफ़्त उपयोगकर्ता';

  @override
  String get adminGeneral => 'सामान्य';

  @override
  String get adminImageUrlOptional => 'इमेज URL (वैकल्पिक)';

  @override
  String get adminKeepWallpaper => 'वॉलपेपर रखें';

  @override
  String get adminLast14Days => 'पिछले 14 दिन';

  @override
  String get adminList => 'सूची';

  @override
  String get adminLoadNextBatch => 'अगला बैच लोड करें';

  @override
  String get adminLoadingNotificationCounts => 'सूचनाओं की गिनती लोड हो रही है।';

  @override
  String get adminMarkReviewed => 'समीक्षा की गई चिह्नित करें';

  @override
  String get adminMarkReviewedFailed => 'रिपोर्ट को समीक्षा की गई चिह्नित नहीं कर सके। फिर कोशिश करें।';

  @override
  String get adminMarkedReviewed => 'समीक्षा की गई चिह्नित';

  @override
  String adminModerationDuplicate(int percent) {
    return 'Prism की वॉल जैसा · $percent%';
  }

  @override
  String get adminModerationHint => 'ये सिर्फ़ संकेत हैं। अस्वीकार करने से पहले जाँच लें।';

  @override
  String adminModerationLogo(String logo) {
    return 'लोगो: $logo';
  }

  @override
  String get adminModerationLogos => 'लोगो';

  @override
  String get adminModerationOpenFailed => 'पेज नहीं खुल सका।';

  @override
  String adminModerationOpenPage(String host) {
    return '$host खोलें';
  }

  @override
  String get adminModerationSignals => 'समीक्षा संकेत';

  @override
  String get adminModerationSimilarWall => 'मिलती-जुलती Prism वॉल';

  @override
  String adminModerationSimilarity(int percent) {
    return '$percent% मिलती-जुलती';
  }

  @override
  String adminModerationText(String words) {
    return 'टेक्स्ट: $words';
  }

  @override
  String get adminModerationTextInImage => 'इमेज में टेक्स्ट';

  @override
  String adminModerationUnsafe(String categories) {
    return 'असुरक्षित: $categories';
  }

  @override
  String get adminModerationUnsafeCategories => 'असुरक्षित श्रेणियाँ';

  @override
  String adminModerationWeb(String host) {
    return '$host पर मिली';
  }

  @override
  String adminModerationWebMore(String host, int more) {
    return '$host +$more पर मिली';
  }

  @override
  String get adminModerationWebPages => 'वेब पर मिली';

  @override
  String get adminNewWallpapersPending => 'किसी के वॉलपेपर अपलोड करने पर वे यहाँ दिखेंगे।';

  @override
  String get adminNoNotificationCounts => 'अभी सूचनाओं की कोई गिनती नहीं है।';

  @override
  String get adminNoOpenReports => 'कोई खुली रिपोर्ट नहीं';

  @override
  String get adminNoReasonGiven => 'कोई कारण नहीं दिया गया';

  @override
  String get adminNoTelemetryData => 'कॉपी करने के लिए टेलीमेट्री डेटा नहीं है';

  @override
  String get adminNoTelemetryYet => 'अभी टेलीमेट्री नहीं है';

  @override
  String get adminNoWallpapersPending => 'समीक्षा के लिए कोई वॉलपेपर लंबित नहीं है।';

  @override
  String get adminNothingToReview => 'समीक्षा के लिए कुछ नहीं';

  @override
  String get adminNotificationCountExplanation =>
      'स्वीकृत का मतलब है कि Firebase ने पुश स्वीकार किया। अकाउंट टॉपिक और डिवाइस टोकन पर भेजा गया पुश दो बार गिना जाता है। यह देखे जाने की गिनती नहीं है।';

  @override
  String get adminNotificationCountsLoadError => 'सूचनाओं की गिनती लोड नहीं हो सकी।';

  @override
  String get adminNotificationIrreversible =>
      'यह सूचना इस समूह के सभी लोगों को भेजी जाएगी। इसे वापस नहीं लिया जा सकता।';

  @override
  String get adminNotificationQueueFailed => 'सूचना कतार में नहीं डाली जा सकी। फिर कोशिश करें।';

  @override
  String get adminNotificationQueued => 'सूचना कतार में डाल दी गई। Cloud Function इसे जल्द भेजेगा।';

  @override
  String get adminNotifications => 'सूचनाएँ';

  @override
  String get adminOpenReportsLoadError => 'खुली रिपोर्टें लोड नहीं हो सकीं।';

  @override
  String get adminOpenWallpaper => 'वॉलपेपर खोलें';

  @override
  String adminOperationCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString ऑपरेशन',
      one: '$countString ऑपरेशन',
    );
    return '$_temp0';
  }

  @override
  String get adminPendingWallsLoadError => 'समीक्षा के लिए लंबित वॉलपेपर लोड नहीं हो सके।';

  @override
  String get adminPremiumUsers => 'Premium उपयोगकर्ता';

  @override
  String adminReadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString बार पढ़ा',
      one: '$countString बार पढ़ा',
    );
    return '$_temp0';
  }

  @override
  String get adminReasonBlurry => 'धुँधला';

  @override
  String get adminReasonBlurryBody =>
      'इमेज धुँधली है या बहुत ज़्यादा कंप्रेस की गई है। ज़्यादा साफ़ संस्करण अपलोड करें।';

  @override
  String get adminReasonCopyright => 'कॉपीराइट';

  @override
  String get adminReasonCopyrightBody =>
      'यह इमेज किसी और की बनाई हुई हो सकती है। केवल वही वॉलपेपर अपलोड करें जो आपने बनाए हों या जिनके अधिकार आपके पास हों।';

  @override
  String get adminReasonDuplicate => 'डुप्लिकेट';

  @override
  String get adminReasonDuplicateBody => 'यह वॉलपेपर Prism पर पहले से मौजूद वॉलपेपर की नकल है।';

  @override
  String get adminReasonHint => 'बताएँ कि क्या बदलना है';

  @override
  String get adminReasonLabel => 'कारण';

  @override
  String get adminReasonLowResolution => 'कम रिज़ॉल्यूशन';

  @override
  String get adminReasonLowResolutionBody => 'रिज़ॉल्यूशन बहुत कम है। छोटी तरफ़ कम से कम 1080 px वाली इमेज अपलोड करें।';

  @override
  String get adminReasonNotWallpaper => 'वॉलपेपर नहीं है';

  @override
  String get adminReasonNotWallpaperBody =>
      'यह इमेज फ़ोन वॉलपेपर के लिए ठीक नहीं है। ऐसी पोर्ट्रेट इमेज इस्तेमाल करें जो पूरी स्क्रीन भरे।';

  @override
  String get adminReasonOther => 'अन्य';

  @override
  String get adminReasonWatermark => 'वॉटरमार्क';

  @override
  String get adminReasonWatermarkBody => 'इमेज पर वॉटरमार्क है। बिना वॉटरमार्क वाला संस्करण अपलोड करें।';

  @override
  String get adminRefresh => 'रीफ़्रेश करें';

  @override
  String get adminReject => 'अस्वीकार करें';

  @override
  String get adminRejectReasonRequired => 'इस आइटम को अस्वीकार करने से पहले कारण दर्ज करें।';

  @override
  String get adminRejectSaveFailed => 'यह फ़ैसला सहेजा नहीं जा सका। आपका कारण अभी भी यहाँ है। फिर कोशिश करें।';

  @override
  String get adminRejectWallpaper => 'वॉलपेपर अस्वीकार करें';

  @override
  String get adminRemove => 'हटाएँ';

  @override
  String get adminRemoveWallpaper => 'वॉलपेपर हटाएँ';

  @override
  String get adminRemovedFromNextDrop => 'अगले Drop से हटा दिया गया';

  @override
  String get adminReportDismissFailed => 'रिपोर्ट खारिज नहीं हो सकी। फिर कोशिश करें।';

  @override
  String get adminReportDismissedKept => 'रिपोर्ट खारिज की गई। वॉलपेपर रखा गया।';

  @override
  String get adminReported => 'रिपोर्ट किया गया';

  @override
  String get adminReporter => 'रिपोर्ट करने वाला';

  @override
  String get adminReports => 'रिपोर्टें';

  @override
  String get adminReserve => 'रिज़र्व करें';

  @override
  String get adminReserveForDrop => 'Drop के लिए रिज़र्व करें';

  @override
  String get adminReserveUpdateFailed => 'Drop रिज़र्व अपडेट नहीं हो सका। फिर कोशिश करें।';

  @override
  String get adminReservedForNextDrop => 'अगले Drop के लिए रिज़र्व किया गया';

  @override
  String get adminRetry => 'फिर कोशिश करें';

  @override
  String adminReviewProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString/$totalString';
  }

  @override
  String get adminSendNotification => 'सूचना भेजें';

  @override
  String adminSendToAudience(String audience) {
    return '$audience को भेजें?';
  }

  @override
  String get adminSkip => 'छोड़ें';

  @override
  String get adminSpecificUser => 'खास उपयोगकर्ता (ईमेल)';

  @override
  String get adminSwipeInstructions => 'स्वीकृत करने के लिए दाएँ स्वाइप करें, अस्वीकार करने के लिए बाएँ';

  @override
  String get adminSwipeReview => 'स्वाइप करके समीक्षा करें';

  @override
  String get adminTarget => 'लक्ष्य';

  @override
  String get adminTelemetryCopied => 'क्लिपबोर्ड पर कॉपी किया गया। विश्लेषण के लिए कहीं और पेस्ट करें।';

  @override
  String get adminTelemetryReadError => 'टेलीमेट्री पढ़ी नहीं जा सकी';

  @override
  String get adminTitle => 'एडमिन मॉडरेशन';

  @override
  String get adminTitleLabel => 'शीर्षक';

  @override
  String get adminTitleRequired => 'शीर्षक ज़रूरी है';

  @override
  String get adminTotalEvents => 'कुल इवेंट';

  @override
  String get adminTryAgain => 'फिर कोशिश करें';

  @override
  String get adminUndo => 'पहले जैसा करें';

  @override
  String get adminUndoSuccessful => 'पहले जैसा करना सफल रहा';

  @override
  String get adminUnknown => 'अज्ञात';

  @override
  String get adminUnreserve => 'रिज़र्व रद्द करें';

  @override
  String get adminUntitled => 'बिना शीर्षक';

  @override
  String get adminUploaded => 'अपलोड किया गया';

  @override
  String get adminUseAppForEvents => 'Firestore इवेंट बनाने के लिए ऐप इस्तेमाल करें।';

  @override
  String get adminUserEmail => 'उपयोगकर्ता का ईमेल';

  @override
  String get adminUserReportsShowHere => 'उपयोगकर्ताओं की रिपोर्टें यहाँ दिखेंगी।';

  @override
  String get adminValidEmailRequired => 'मान्य ईमेल दर्ज करें';

  @override
  String get adminView => 'देखें';

  @override
  String get adminViewFullWallpaper => 'पूरा वॉलपेपर देखें';

  @override
  String get adminWallId => 'ID';

  @override
  String get adminWallOfTheDay => 'आज का वॉलपेपर';

  @override
  String get adminWallOrUpload => 'वॉलपेपर या अपलोड';

  @override
  String get adminWallpaperAlreadyGone => 'वॉलपेपर पहले ही हट चुका था। रिपोर्ट बंद की गई।';

  @override
  String get adminWallpaperApproved => 'वॉलपेपर स्वीकृत';

  @override
  String get adminWallpaperFullScreen => 'वॉलपेपर, पूरी स्क्रीन';

  @override
  String get adminWallpaperRejected => 'वॉलपेपर अस्वीकार किया गया';

  @override
  String get adminWallpaperRemoved => 'वॉलपेपर हटाया गया';

  @override
  String get adminWallpaperReport => 'वॉलपेपर की रिपोर्ट';

  @override
  String get adminWallpaperToReview => 'समीक्षा के लिए वॉलपेपर';

  @override
  String adminWallpapersRemaining(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString वॉलपेपर बाकी',
      one: '$countString वॉलपेपर बाकी',
    );
    return '$_temp0';
  }

  @override
  String get adminWalls => 'वॉलपेपर';

  @override
  String adminWriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString बार लिखा',
      one: '$countString बार लिखा',
    );
    return '$_temp0';
  }

  @override
  String get appLinkRetryWhenOnline => 'इंटरनेट कनेक्शन नहीं है। ऑनलाइन होने पर यह लिंक खोलेंगे।';

  @override
  String get appTitle => 'Prism';

  @override
  String get coreBack => 'वापस';

  @override
  String get coreBio => 'बायो';

  @override
  String get coreBlockCreatorAfterReport => 'इस क्रिएटर को भी ब्लॉक करें';

  @override
  String get coreBothScreens => 'दोनों स्क्रीन';

  @override
  String get coreCancel => 'रद्द करें';

  @override
  String get coreCancelSelection => 'चयन रद्द करें';

  @override
  String get coreCancelSignIn => 'अभी नहीं';

  @override
  String get coreCategoryAbstract => 'अमूर्त';

  @override
  String get coreCategoryAerial => 'हवाई दृश्य';

  @override
  String get coreCategoryAesthetic => 'सौंदर्यपरक';

  @override
  String get coreCategoryAiArt => 'AI कला';

  @override
  String get coreCategoryAnimals => 'जानवर';

  @override
  String get coreCategoryAnime => 'एनीमे';

  @override
  String get coreCategoryArchitecture => 'वास्तुकला';

  @override
  String get coreCategoryArtistic => 'कलात्मक';

  @override
  String get coreCategoryBirds => 'पक्षी';

  @override
  String get coreCategoryCars => 'कारें';

  @override
  String get coreCategoryCity => 'शहर';

  @override
  String get coreCategoryClouds => 'बादल';

  @override
  String get coreCategoryComic => 'कॉमिक';

  @override
  String get coreCategoryCyberpunk => 'साइबरपंक';

  @override
  String get coreCategoryDark => 'डार्क';

  @override
  String get coreCategoryDefault => 'श्रेणी';

  @override
  String get coreCategoryFantasy => 'फ़ैंटेसी';

  @override
  String get coreCategoryFashion => 'फ़ैशन';

  @override
  String get coreCategoryFlowers => 'फूल';

  @override
  String get coreCategoryFood => 'खाना';

  @override
  String get coreCategoryForest => 'जंगल';

  @override
  String get coreCategoryGalaxy => 'आकाशगंगा';

  @override
  String get coreCategoryGaming => 'गेमिंग';

  @override
  String get coreCategoryGradient => 'ग्रेडिएंट';

  @override
  String get coreCategoryIllustration => 'चित्रण';

  @override
  String get coreCategoryKawaii => 'कावाई';

  @override
  String get coreCategoryLandscape => 'प्राकृतिक दृश्य';

  @override
  String get coreCategoryMinimal => 'मिनिमल';

  @override
  String get coreCategoryMusic => 'संगीत';

  @override
  String get coreCategoryNature => 'प्रकृति';

  @override
  String get coreCategoryNeon => 'नियॉन';

  @override
  String get coreCategoryOcean => 'महासागर';

  @override
  String get coreCategoryPortraits => 'पोर्ट्रेट';

  @override
  String get coreCategoryQuotes => 'उद्धरण';

  @override
  String get coreCategoryRender3d => '3D रेंडर';

  @override
  String get coreCategoryRobots => 'रोबोट';

  @override
  String get coreCategoryScenery => 'नज़ारे';

  @override
  String get coreCategorySpace => 'अंतरिक्ष';

  @override
  String get coreCategorySpiritual => 'आध्यात्मिक';

  @override
  String get coreCategorySports => 'खेल';

  @override
  String get coreCategoryTech => 'टेक्नोलॉजी';

  @override
  String get coreCategoryTextures => 'बनावट';

  @override
  String get coreCategoryUnderTheSea => 'समुद्र के नीचे';

  @override
  String get coreCategoryVehicles => 'वाहन';

  @override
  String get coreCategoryVintage => 'विंटेज';

  @override
  String get coreCategoryWarriors => 'योद्धा';

  @override
  String get coreChangeWallpaperTarget => 'वॉलपेपर कहाँ सेट होगा, बदलें';

  @override
  String get coreChangelogLatest => 'नवीनतम';

  @override
  String get coreChooseReportReason => 'कारण चुनें';

  @override
  String get coreChooseUsername => 'उपलब्ध उपयोगकर्ता नाम चुनें।';

  @override
  String get coreCoinAiWallpaper => 'AI वॉलपेपर';

  @override
  String get coreCoinAutoRotatePass => 'ऑटो-रोटेट पास, 7 दिन';

  @override
  String get coreCoinBadgeReward => 'बैज इनाम';

  @override
  String coreCoinBalance(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString Prism कॉइन्स';
  }

  @override
  String coreCoinBalanceChange(String balance, String change) {
    return '$balance, $change';
  }

  @override
  String get coreCoinBoost => 'बूस्ट';

  @override
  String get coreCoinCoins => 'कॉइन्स';

  @override
  String get coreCoinCoinsReturned => 'कॉइन्स वापस किए गए';

  @override
  String get coreCoinCollectionPreview => 'कलेक्शन का पूर्वावलोकन, 24 घंटे';

  @override
  String get coreCoinDailyChest => 'रोज़ाना चेस्ट';

  @override
  String get coreCoinDailyStreak => 'रोज़ाना सिलसिला';

  @override
  String coreCoinDailyStreakDay(String day) {
    return 'रोज़ाना सिलसिला, दिन $day';
  }

  @override
  String get coreCoinDay7Chest => 'दिन 7 का चेस्ट';

  @override
  String get coreCoinDrawTicket => 'ड्रॉ टिकट';

  @override
  String get coreCoinDropPack => 'ड्रॉप पैक';

  @override
  String get coreCoinDropWall => 'ड्रॉप वॉलपेपर';

  @override
  String get coreCoinFirstUpload => 'पहला अपलोड';

  @override
  String get coreCoinGiftPass => 'उपहार: 24 घंटे का पास';

  @override
  String get coreCoinInviteReward => 'निमंत्रण का इनाम';

  @override
  String get coreCoinLiveWallpaperStyle => 'लाइव वॉलपेपर स्टाइल';

  @override
  String get coreCoinPremiumFilter => 'Premium फ़िल्टर';

  @override
  String get coreCoinPremiumWallpaper => 'Premium वॉलपेपर';

  @override
  String get coreCoinProDailyBonus => 'Pro का दैनिक बोनस';

  @override
  String get coreCoinProSpin => 'Pro स्पिन';

  @override
  String get coreCoinProStreakBonus => 'Pro स्ट्रीक बोनस';

  @override
  String get coreCoinProfileComplete => 'प्रोफ़ाइल पूरी करें';

  @override
  String get coreCoinQuest => 'मिशन';

  @override
  String coreCoinRefund(String target) {
    return 'रिफ़ंड: $target';
  }

  @override
  String get coreCoinShop => 'दुकान';

  @override
  String get coreCoinSpinWheel => 'चक्र घुमाएँ';

  @override
  String get coreCoinStreakFreeze => 'स्ट्रीक रोकें';

  @override
  String get coreCoinStreakRestore => 'स्ट्रीक बहाल करें';

  @override
  String get coreCoinWallpaperDownload => 'वॉलपेपर डाउनलोड';

  @override
  String get coreCoinWatchedVideo => 'वीडियो देखने पर';

  @override
  String get coreCoinWeekBonus => 'साप्ताहिक बोनस';

  @override
  String get coreColorBlack => 'काला';

  @override
  String get coreColorBlue => 'नीला';

  @override
  String get coreColorBrown => 'भूरा';

  @override
  String get coreColorGreen => 'हरा';

  @override
  String get coreColorGrey => 'धूसर';

  @override
  String get coreColorOrange => 'नारंगी';

  @override
  String get coreColorPink => 'गुलाबी';

  @override
  String get coreColorPurple => 'बैंगनी';

  @override
  String get coreColorRed => 'लाल';

  @override
  String get coreColorTeal => 'नीलहरित';

  @override
  String get coreColorWhite => 'सफ़ेद';

  @override
  String get coreColorYellow => 'पीला';

  @override
  String get coreConfirmWallpaperPreview => 'सिस्टम प्रीव्यू में वॉलपेपर की पुष्टि करें।';

  @override
  String get coreContentNotAvailable => 'यह आइटम अब उपलब्ध नहीं है';

  @override
  String get coreContentReportUser => 'उपयोगकर्ता';

  @override
  String get coreContentReportWallpaper => 'वॉलपेपर';

  @override
  String coreContentReportWhy(String contentType) {
    return 'आप $contentType की रिपोर्ट क्यों कर रहे हैं?';
  }

  @override
  String coreContentReportWhyWithDetails(String contentType, String details) {
    return 'आप $contentType ($details) की रिपोर्ट क्यों कर रहे हैं?';
  }

  @override
  String get coreContinueWithApple => 'Apple से जारी रखें';

  @override
  String get coreContinueWithGoogle => 'Google से जारी रखें';

  @override
  String get coreContributorCouldNotLoad => 'यह प्रोफ़ाइल लोड नहीं हो सकी';

  @override
  String get coreContributorGithub => 'GitHub';

  @override
  String get coreContributorTwitter => 'Twitter';

  @override
  String get coreContributorWebsite => 'वेबसाइट';

  @override
  String get coreCouldNotLoadChangelog => 'बदलावों की सूची लोड नहीं हो सकी';

  @override
  String get coreCouldNotLoadWallpaperForEditing => 'वॉलपेपर संपादन के लिए लोड नहीं हो सका';

  @override
  String get coreCouldNotUpdateFavourites => 'पसंदीदा अपडेट नहीं हो सके। फिर से कोशिश करें।';

  @override
  String get coreCreatorPreviewDescription => 'Prism पर इस क्रिएटर की प्रोफ़ाइल देखें।';

  @override
  String get coreDefaultBanner => 'हमारे Telegram से जुड़ें';

  @override
  String get coreDepthEffectAutoLongTip =>
      'डेप्थ इफ़ेक्ट अपने-आप चालू हो जाता है। iOS 18 या उससे पुराने संस्करण में, घड़ी के नीचे वाली जगह विजेट से खाली रखें।';

  @override
  String get coreDepthEffectAutoTip => 'डेप्थ इफ़ेक्ट अपने-आप चालू हो जाता है।';

  @override
  String get coreDepthEffectBadge => 'डेप्थ';

  @override
  String get coreDepthEffectBadgeSemantic => 'डेप्थ इफ़ेक्ट के साथ काम करता है';

  @override
  String get coreDepthEffectMenuShortTip => '••• पर टैप करें, फिर डेप्थ इफ़ेक्ट चुनें।';

  @override
  String get coreDepthEffectMenuTip => 'लॉक स्क्रीन एडिटर में ••• पर टैप करें, फिर डेप्थ इफ़ेक्ट चुनें।';

  @override
  String get coreSpatialBadge => 'स्पेशियल';

  @override
  String get coreSpatialBadgeSemantic => 'स्पेशियल सीन के रूप में काम करता है';

  @override
  String get coreSpatialSceneTip => 'लॉक स्क्रीन एडिटर में स्पेशियल सीन बटन पर टैप करें।';

  @override
  String get coreDeviceCannotSetScreen => 'यह डिवाइस उस स्क्रीन पर वॉलपेपर नहीं लगा सकता।';

  @override
  String get coreDone => 'हो गया';

  @override
  String coreDown(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString कम';
  }

  @override
  String get coreDownloadNotFinishedCoinsReturned => 'आपका पिछला डाउनलोड पूरा नहीं हुआ। कॉइन वापस कर दिए गए हैं।';

  @override
  String get coreDownloadPrismPreviewDescription => 'खूबसूरत वॉलपेपर देखने के लिए Prism डाउनलोड करें।';

  @override
  String get coreEdit => 'संपादित करें';

  @override
  String get coreEditBioHint => 'लोगों को अपने बारे में बताएँ…';

  @override
  String get coreEditDiscardBody => 'आपके बदलाव सेव नहीं हुए हैं।';

  @override
  String get coreEditDiscardTitle => 'बदलाव छोड़ दें?';

  @override
  String get coreEditEmailInvalid => 'मान्य ईमेल पता दर्ज करें।';

  @override
  String coreEditKindLinkInvalid(String kind) {
    return 'मान्य $kind लिंक दर्ज करें।';
  }

  @override
  String get coreEditLinkInvalid => 'मान्य लिंक दर्ज करें।';

  @override
  String get coreEditProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String coreEditProfileLink(String kind) {
    return '$kind लिंक';
  }

  @override
  String get coreEditRemoveBioTitle => 'बायो हटाएँ?';

  @override
  String get coreEditRemoveConfirm => 'हटाएँ';

  @override
  String coreEditRemoveTitle(String item) {
    return '$item हटाएँ?';
  }

  @override
  String get coreEditUsernameAvailable => 'यह यूज़रनेम उपलब्ध है';

  @override
  String get coreEditUsernameChars => 'सिर्फ़ अक्षर, अंक और अंडरस्कोर इस्तेमाल करें।';

  @override
  String get coreEditUsernameAllCaps => 'कम-से-कम एक छोटा अक्षर इस्तेमाल करें।';

  @override
  String coreEditUsernameMinLength(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'कम-से-कम $lengthString अक्षर इस्तेमाल करें।';
  }

  @override
  String coreEditUsernameRule(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'कम-से-कम $lengthString अक्षर, अंक या अंडरस्कोर (_) इस्तेमाल करें।';
  }

  @override
  String get coreEditUsernameTaken => 'यह यूज़रनेम पहले से लिया जा चुका है।';

  @override
  String get coreEditUsernameTakenSemantic => 'यूज़रनेम पहले से लिया गया है';

  @override
  String get coreFavourite => 'पसंदीदा';

  @override
  String coreFileSizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String get coreGenericSignInError => 'कुछ गड़बड़ हुई। कृपया फिर से कोशिश करें!';

  @override
  String get coreGoHome => 'होम पर जाएँ';

  @override
  String get coreGooglePlayServicesSignInError => 'इस डिवाइस पर Google Play services से साइन इन नहीं हो सकता।';

  @override
  String get coreGoogleSignInNetworkError => 'Google से साइन इन नहीं हुआ। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get coreHomeScreen => 'होम स्क्रीन';

  @override
  String get coreHomeScreenSetupUnavailable => 'होम स्क्रीन सेटअप अब उपलब्ध नहीं हैं।';

  @override
  String get coreInvalidLinkBody => 'आपने जो लिंक खोला है, वह अमान्य है या अब उपलब्ध नहीं है।';

  @override
  String coreInvitedToPrismTitle(String name) {
    return '$name ने आपको Prism पर आमंत्रित किया है';
  }

  @override
  String get coreIosWallpaperGuideBody => 'iOS ऐप्स को वॉलपेपर बदलने नहीं देता। Photos में ये चरण पूरे करें:';

  @override
  String get coreJoinPrismPreviewTitle => 'Prism से जुड़ें';

  @override
  String get coreKeepPrismOpen => 'Prism खुला रखें और फिर कोशिश करें।';

  @override
  String get coreLoading => 'लोड हो रहा है';

  @override
  String get coreLoadingMoreFailed => 'और आइटम लोड नहीं हुए। फिर कोशिश करने के लिए टैप करें';

  @override
  String get coreLoadingWallpaper => 'वॉलपेपर लोड हो रहा है';

  @override
  String get coreLockScreen => 'लॉक स्क्रीन';

  @override
  String get coreMatchAccent => 'ऐक्सेंट से मिलाएँ';

  @override
  String get coreName => 'नाम';

  @override
  String get coreNoWallpaperUrl => 'वॉलपेपर का URL उपलब्ध नहीं है';

  @override
  String get coreNotNow => 'अभी नहीं';

  @override
  String get coreOpenPhotos => 'Photos खोलें';

  @override
  String get coreOpenSettings => 'सेटिंग्स खोलें';

  @override
  String get corePairPickerDownloads => 'डाउनलोड';

  @override
  String get corePairPickerFavourites => 'पसंदीदा';

  @override
  String get corePairPickerHistory => 'इतिहास';

  @override
  String get corePairPickerNoDownloads => 'अभी तक कोई डाउनलोड नहीं।';

  @override
  String get corePairPickerNoFavourites => 'अभी तक कोई पसंदीदा नहीं।';

  @override
  String get corePairPickerNoHistory => 'अभी तक कोई इतिहास नहीं।';

  @override
  String get corePairPickerTitle => 'लॉक स्क्रीन के लिए वॉलपेपर चुनें';

  @override
  String get corePairPickerUseWallpaper => 'लॉक स्क्रीन पर यह वॉलपेपर लगाएँ';

  @override
  String get corePhotosPermissionMessage => 'वॉलपेपर सेव करने के लिए Prism को सेटिंग्स में फ़ोटो जोड़ने की अनुमति दें।';

  @override
  String get corePhotosStepOpen => 'Photos खोलें।';

  @override
  String get corePhotosStepShare => 'शेयर करें पर टैप करें।';

  @override
  String get corePhotosStepUseAsWallpaper => 'वॉलपेपर के रूप में इस्तेमाल करें पर टैप करें।';

  @override
  String corePopupAppVersion(String version) {
    return 'आप संस्करण $version इस्तेमाल कर रहे हैं।';
  }

  @override
  String get corePopupCannotUndo => 'इसे वापस नहीं किया जा सकता।';

  @override
  String get corePopupCoverPhoto => 'कवर फ़ोटो';

  @override
  String get corePopupDiscard => 'छोड़ें';

  @override
  String get corePopupProfilePhoto => 'प्रोफ़ाइल फ़ोटो';

  @override
  String get corePopupWhatsNew => 'नया क्या है';

  @override
  String get corePreviousWallpaperRestored => 'पिछला वॉलपेपर बहाल किया गया';

  @override
  String get coreProfileSaveFailed => 'आपकी प्रोफ़ाइल सेव नहीं हो सकी। कृपया फिर कोशिश करें।';

  @override
  String get coreProfileUpdated => 'प्रोफ़ाइल अपडेट की गई';

  @override
  String coreReferralSaved(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'रेफ़रल सेव हुआ। +$coinsString कॉइन पाने के लिए साइन इन करें।';
  }

  @override
  String coreRelativeTimeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString दिन पहले',
      one: '$countString दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeDaysFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString दिन में',
      one: '$countString दिन में',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString घंटे पहले',
      one: '$countString घंटे पहले',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeHoursFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString घंटे में',
      one: '$countString घंटे में',
    );
    return '$_temp0';
  }

  @override
  String get coreRelativeTimeJustNow => 'अभी-अभी';

  @override
  String coreRelativeTimeMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString मिनट पहले',
      one: '$countString मिनट पहले',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeMinutesFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString मिनट में',
      one: '$countString मिनट में',
    );
    return '$_temp0';
  }

  @override
  String get coreRemoveBio => 'बायो हटाएँ';

  @override
  String get coreReport => 'रिपोर्ट करें';

  @override
  String get coreReportCouldNotSubmit => 'आपकी रिपोर्ट भेजी नहीं जा सकी। कृपया फिर कोशिश करें।';

  @override
  String get coreReportDetailsHint => 'क्या कोई और जानकारी है जो हमें पता होनी चाहिए';

  @override
  String get coreReportDetailsOptional => 'जानकारी (ज़रूरी नहीं)';

  @override
  String get coreReportReasonCopyright => 'कॉपीराइट / स्वामित्व';

  @override
  String get coreReportReasonHarassment => 'उत्पीड़न या नफ़रत';

  @override
  String get coreReportReasonOther => 'अन्य';

  @override
  String get coreReportReasonSexual => 'यौन या वयस्क सामग्री';

  @override
  String get coreReportReasonSpam => 'स्पैम या भ्रामक सामग्री';

  @override
  String get coreReportSent => 'रिपोर्ट भेज दी गई। धन्यवाद।';

  @override
  String get coreRestorePreviousWallpaperFailed => 'पिछला वॉलपेपर बहाल नहीं हो सका। इसे वॉलपेपर इतिहास से फिर लगाएँ।';

  @override
  String get coreRetry => 'फिर कोशिश करें';

  @override
  String get coreRetryImage => 'तस्वीर फिर से लोड करें';

  @override
  String coreRetryOnScreen(String screen) {
    return '$screen पर फिर कोशिश करें';
  }

  @override
  String get coreSaveChanges => 'बदलाव सेव करें';

  @override
  String get coreSeeFullChangelog => 'बदलावों की पूरी सूची देखें';

  @override
  String get coreSeeMore => 'और देखें';

  @override
  String coreSelectCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString चुने गए';
  }

  @override
  String get coreSendReport => 'रिपोर्ट भेजें';

  @override
  String get coreSet => 'लगाएँ';

  @override
  String get coreSetItAsWallpaper => 'इसे अपना वॉलपेपर बनाएँ';

  @override
  String get coreSetWallpaper => 'वॉलपेपर के रूप में लगाएँ';

  @override
  String coreSetWallpaperOn(String screen) {
    return '$screen पर वॉलपेपर लगाएँ';
  }

  @override
  String get coreShare => 'शेयर करें';

  @override
  String coreShareCardClipboard(String link) {
    return '🔥यह देखें ➜ $link';
  }

  @override
  String get coreShareFormatStory => 'स्टोरी';

  @override
  String get coreShareFormatPost => 'पोस्ट';

  @override
  String get coreShareFormatClean => 'सादा';

  @override
  String get coreShareTargetInstagram => 'Instagram';

  @override
  String get coreShareTargetCopyLink => 'लिंक कॉपी करें';

  @override
  String get coreShareTargetSaveImage => 'इमेज सेव करें';

  @override
  String get coreShareTargetMore => 'और';

  @override
  String coreShareCardBy(String creator) {
    return '$creator द्वारा';
  }

  @override
  String get coreShareImageSaved => 'इमेज सेव हो गई';

  @override
  String get coreShareImageFailed => 'इमेज सेव नहीं हो सकी। फिर से कोशिश करें।';

  @override
  String get coreShareInstagramFailed => 'Instagram नहीं खुल सका। फिर से कोशिश करें।';

  @override
  String get coreSharePreviewFailed => 'यह इमेज नहीं बन सकी। इसके बजाय “और” से लिंक शेयर करें।';

  @override
  String get coreShareLinkCopied => 'शेयर करने का लिंक कॉपी हो गया!';

  @override
  String coreShareProfileClipboard(String link) {
    return 'Prism पर मेरी प्रोफ़ाइल देखें ➜ $link';
  }

  @override
  String coreShareWallpaperClipboard(String link) {
    return 'यह देखें ➜ $link';
  }

  @override
  String get coreShareWallpaperGeneric => 'यह बंडल किया हुआ वॉलपेपर Prism ऐप में उपलब्ध है।';

  @override
  String get coreSignInFeatureBody => 'आपका अकाउंट आपके कॉइन, पसंदीदा और अपलोड एक जगह रखता है।';

  @override
  String coreSignInFeatureTitle(String feature) {
    return '$feature का इस्तेमाल करने के लिए साइन इन करें';
  }

  @override
  String get coreSignInPopupBody => 'हर डिवाइस पर अपने पसंदीदा, अपलोड और कॉइन साथ रखें।';

  @override
  String get coreSignInPopupTitle => 'Prism में साइन इन करें';

  @override
  String get coreSignInPromptAction => 'साइन इन करें';

  @override
  String get coreSignInToReportContent => 'कंटेंट की रिपोर्ट करने के लिए साइन इन करें';

  @override
  String get coreSignInToSyncFavourites => 'हर डिवाइस पर अपने पसंदीदा साथ रखने के लिए साइन इन करें';

  @override
  String get coreSigningIn => 'साइन इन हो रहा है';

  @override
  String get coreSomethingWentWrong => 'कुछ गड़बड़ हुई। फिर कोशिश करें।';

  @override
  String coreStreakNext(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'अगला इनाम +$coinsString';
  }

  @override
  String coreStreakSemantics(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$daysString दिन की स्ट्रीक, अगला इनाम $coinsString कॉइन';
  }

  @override
  String get coreCustomAccent => 'कस्टम रंग';

  @override
  String get coreCustomAccentHex => 'हेक्स कोड';

  @override
  String get coreCustomAccentHue => 'रंगत';

  @override
  String get coreCustomAccentSaturation => 'संतृप्ति';

  @override
  String get coreCustomAccentLightness => 'चमक';

  @override
  String get coreCustomAccentInvalidHex => '#E57697 जैसे 6 हेक्स अंक डालें।';

  @override
  String get coreCustomAccentLowContrast => 'यह रंग इस थीम पर साफ़ नहीं दिखता। कोई हल्का या गहरा शेड चुनें।';

  @override
  String get coreCustomAccentApply => 'रंग इस्तेमाल करें';

  @override
  String coreThemeAccentSemanticLabel(int index, int count) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'ऐक्सेंट रंग $countString में से $indexString';
  }

  @override
  String get coreThemeAmoled => 'AMOLED';

  @override
  String get coreThemeCoffee => 'कॉफ़ी';

  @override
  String get coreThemeCottonBlue => 'कॉटन ब्लू';

  @override
  String get coreThemeCustom => 'कस्टम थीम';

  @override
  String get coreThemeDeepOcean => 'गहरा महासागर';

  @override
  String get coreThemeFrostWhite => 'फ्रॉस्ट व्हाइट';

  @override
  String get coreThemeJungle => 'जंगल';

  @override
  String get coreThemeLocked => 'लॉक है';

  @override
  String get coreThemeMaterialDark => 'मटीरियल डार्क';

  @override
  String get coreThemeMaterialYou => 'मटीरियल यू';

  @override
  String get coreThemeOlive => 'ऑलिव';

  @override
  String get coreThemePepper => 'काली मिर्च';

  @override
  String get coreThemeRose => 'गुलाब';

  @override
  String get coreThemeSky => 'आसमान';

  @override
  String get coreThemeSteel => 'स्टील';

  @override
  String get coreThemeSpooky => 'डरावना';

  @override
  String get spookyBannerTitle => 'डरावना थीम आ गई है';

  @override
  String get spookyBannerSubtitle => 'नारंगी, काला और कुछ मकड़ियाँ। मुफ़्त। आज़माने के लिए टैप करें।';

  @override
  String get spookyAnnouncementTitle => 'नया: डरावना थीम 🎃';

  @override
  String get spookyAnnouncementBody => 'नारंगी, काला और कुछ मकड़ियाँ। यह मुफ़्त है। आज़माने के लिए टैप करें।';

  @override
  String get coreThemeDiwali => 'दिवाली';

  @override
  String get diwaliBannerTitle => 'दिवाली थीम आ गई है';

  @override
  String get diwaliBannerSubtitle => 'दीये, आतिशबाज़ी और सोना। मुफ़्त। आज़माने के लिए टैप करें।';

  @override
  String get diwaliAnnouncementTitle => 'नई: दिवाली थीम 🪔';

  @override
  String get diwaliAnnouncementBody => 'दीये, आतिशबाज़ी और सोना। यह मुफ़्त है। आज़माने के लिए टैप करें।';

  @override
  String get coreThisPageDoesNotExist => 'यह पेज मौजूद नहीं है';

  @override
  String get coreTryAgain => 'फिर कोशिश करें';

  @override
  String get coreUndo => 'वापस लें';

  @override
  String coreUp(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString ज़्यादा';
  }

  @override
  String get coreUploadFailureDailyLimit => 'आज की अपलोड सीमा पूरी हो गई। कल फिर कोशिश करें।';

  @override
  String get coreUploadFailureFileType =>
      'यह फ़ाइल प्रकार समर्थित नहीं है। JPG, PNG, WebP या HEIC तस्वीर इस्तेमाल करें।';

  @override
  String get coreUploadFailureGeneric => 'अपलोड पूरा नहीं हुआ। आपकी तस्वीर यहीं है, इसलिए आप फिर कोशिश कर सकते हैं।';

  @override
  String get coreUploadFailureInProgress => 'एक अपलोड पहले से जारी है। थोड़ा इंतज़ार करें, फिर कोशिश करें।';

  @override
  String get coreUploadFailureOversize => 'यह इमेज 15 MB से बड़ी है। छोटी इमेज चुनें।';

  @override
  String get coreUploadFailureSignIn => 'अपलोड करने के लिए फिर से साइन इन करें।';

  @override
  String get coreUploadFailureWeeklyLimit => 'इस हफ़्ते की मुफ़्त अपलोड सीमा पूरी हो गई है।';

  @override
  String get coreUploadSubmittedSuccess => 'आपका वॉलपेपर सबमिट हो गया है और समीक्षा में है।';

  @override
  String get coreUsername => 'यूज़रनेम';

  @override
  String get coreUsernameCheckFailed => 'यूज़रनेम जाँचा नहीं जा सका। फिर कोशिश करें।';

  @override
  String get coreUsernameRequiredToShareProfile => 'अपनी प्रोफ़ाइल साझा करने के लिए यूज़रनेम सेट करें';

  @override
  String get coreWallpaperApplied => 'वॉलपेपर सफलतापूर्वक सेट हो गया!';

  @override
  String get coreWallpaperBothScreens => 'दोनों स्क्रीन';

  @override
  String coreWallpaperBySemanticLabel(String name) {
    return '$name का वॉलपेपर';
  }

  @override
  String get coreWallpaperDownloadedPictures => 'वॉलपेपर Pictures/Prism में डाउनलोड हो गया!';

  @override
  String get coreWallpaperEditApplyColorFailed => 'रंग लागू नहीं हो सका। फिर कोशिश करें।';

  @override
  String get coreWallpaperErrorGeneric => 'वॉलपेपर सेट नहीं हो सका।';

  @override
  String get coreWallpaperErrorImageTooLarge => 'यह इमेज आपके डिवाइस पर सेट करने के लिए बहुत बड़ी है।';

  @override
  String get coreWallpaperErrorInvalidVideo =>
      'इस वीडियो को वॉलपेपर के रूप में नहीं चलाया जा सकता। कोई और क्लिप आज़माएँ।';

  @override
  String get coreWallpaperErrorLiveGeneric => 'लाइव वॉलपेपर सेट नहीं हो सका। फिर कोशिश करें।';

  @override
  String get coreWallpaperErrorMemory => 'पर्याप्त मेमोरी नहीं है। दूसरे ऐप बंद करके फिर कोशिश करें।';

  @override
  String get coreWallpaperErrorNotAllowed => 'आपका डिवाइस या कार्य प्रोफ़ाइल वॉलपेपर बदलने की अनुमति नहीं देता।';

  @override
  String get coreWallpaperErrorPermission => 'Prism को उस फ़ाइल को पढ़ने की अनुमति नहीं है।';

  @override
  String get coreWallpaperErrorReadFile => 'फ़ाइल पढ़ी नहीं जा सकी। फिर कोशिश करें।';

  @override
  String get coreWallpaperErrorSourceTooLarge => 'यह फ़ाइल लाइव वॉलपेपर के लिए बहुत बड़ी है।';

  @override
  String get coreWallpaperErrorStyle => 'यह डिवाइस उस शैली को शुरू नहीं कर सका। कोई और आज़माएँ।';

  @override
  String get coreWallpaperErrorSystemPreview => 'सिस्टम प्रीव्यू नहीं खुल सका।';

  @override
  String get coreWallpaperErrorTextureDimensions => 'यह इमेज लाइव वॉलपेपर के लिए बहुत बड़ी है।';

  @override
  String get coreWallpaperErrorTimeout => 'समय सीमा समाप्त हुई। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get coreWallpaperHomeScreen => 'होम स्क्रीन';

  @override
  String get coreWallpaperHomeSetLockFailed => 'होम स्क्रीन सेट हो गई। लॉक स्क्रीन सेट नहीं हो सकी।';

  @override
  String get coreWallpaperLinkCopyFailed => 'लिंक कॉपी नहीं हो सका। फिर कोशिश करें।';

  @override
  String get coreWallpaperLinkCreateFailed => 'शेयर लिंक नहीं बनाया जा सका। फिर कोशिश करें।';

  @override
  String get coreWallpaperLoadTimedOut =>
      'वॉलपेपर लोड होने में समय सीमा समाप्त हुई। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get coreWallpaperLockScreen => 'लॉक स्क्रीन';

  @override
  String get coreWallpaperOfflineUnavailable =>
      'यह वॉलपेपर इस डिवाइस पर सेव नहीं है। इंटरनेट से कनेक्ट करें और फिर कोशिश करें।';

  @override
  String coreWallpaperPartialSet(String applied, String failed) {
    return '$applied सेट हुआ। $failed विफल हुआ।';
  }

  @override
  String get coreWallpaperPreviewDescription => 'Prism का यह शानदार वॉलपेपर देखें।';

  @override
  String get coreWallpaperPreviewTitle => 'Prism पर वॉलपेपर';

  @override
  String get coreWallpaperSaveFailed => 'वॉलपेपर सेट नहीं हो सका। फिर कोशिश करें।';

  @override
  String get coreWallpaperSavedPhotos => 'Photos में सेव किया गया।';

  @override
  String get coreWallpaperSavedToast => 'आपका विज्ञापन इनाम जोड़ दिया गया।';

  @override
  String coreWallpaperSavedWithTip(String saved, String tip) {
    return '$saved $tip';
  }

  @override
  String get coreWallpaperSemanticLabel => 'वॉलपेपर';

  @override
  String get coreWallpaperSet => 'वॉलपेपर सेट हो गया';

  @override
  String get coreWallpaperShareFailed => 'अभी यह वॉलपेपर साझा नहीं किया जा सका।';

  @override
  String get coreWallpaperShareRetryFailed => 'यह वॉलपेपर साझा नहीं हो सका। फिर कोशिश करें।';

  @override
  String get debugAdminReviewDescription => 'कंटेंट मॉडरेशन और पुश नोटिफ़िकेशन टूल';

  @override
  String get debugAdminShortcuts => 'एडमिन शॉर्टकट';

  @override
  String get debugLiveActivityPreview => 'Live Activity पूर्वावलोकन';

  @override
  String get debugLiveActivityPreviewDescription => 'नमूना AI जनरेशन गतिविधि चलाता है: 8 सेकंड बाद तैयार';

  @override
  String get debugLiveActivityUnavailable => 'Live Activities बंद हैं या समर्थित नहीं हैं';

  @override
  String get debugReviewActivityPreview => 'समीक्षा कतार गतिविधि का पूर्वावलोकन';

  @override
  String get debugReviewActivityPreviewDescription => 'लॉक स्क्रीन पर समीक्षा की प्रतीक्षा कर रहे वॉलपेपर दिखाता है';

  @override
  String get debugAllTags => 'सभी टैग';

  @override
  String get debugAndroidVersion => 'Android संस्करण';

  @override
  String get debugAnimationSpeed => 'ऐनिमेशन की गति';

  @override
  String get debugAppInfo => 'ऐप की जानकारी';

  @override
  String get debugAppName => 'ऐप का नाम';

  @override
  String get debugAppVersion => 'ऐप का संस्करण';

  @override
  String get debugAutoScrollOff => 'ऑटो-स्क्रॉल बंद करें';

  @override
  String get debugAutoScrollOn => 'ऑटो-स्क्रॉल चालू करें';

  @override
  String debugBackendName(String backend) {
    return 'बैकएंड: $backend';
  }

  @override
  String get debugBoard => 'बोर्ड';

  @override
  String get debugBrand => 'ब्रांड';

  @override
  String get debugBuildNumber => 'बिल्ड नंबर';

  @override
  String get debugBuildSignature => 'बिल्ड सिग्नेचर';

  @override
  String get debugCacheCleared => 'ऐप कैश साफ़ किया गया';

  @override
  String get debugCancel => 'रद्द करें';

  @override
  String get debugCheckLogsRetry => 'लॉग देखें, फिर कोशिश करें।';

  @override
  String get debugClear => 'साफ़ करें';

  @override
  String get debugClearAll => 'सब साफ़ करें';

  @override
  String get debugClearAllStorageBody =>
      'इससे स्थानीय रूप से सेव किया गया सारा डेटा हमेशा के लिए मिट जाएगा। ऐप को रीस्टार्ट करने तक उसका व्यवहार अप्रत्याशित हो सकता है।';

  @override
  String get debugClearAllStorageTitle => 'सारा स्टोरेज साफ़ करें?';

  @override
  String get debugClearAppCache => 'ऐप कैश साफ़ करें';

  @override
  String get debugClearAppCacheDescription => 'इमेज, फ़ीड और नोटिफ़िकेशन कैश साफ़ करें';

  @override
  String get debugClearImageCache => 'इमेज कैश साफ़ करें';

  @override
  String get debugClearImageCacheDescription => 'मेमोरी में मौजूद इमेज कैश हटाएँ';

  @override
  String get debugClearLogsBody => 'इससे मेमोरी में रखी गई सभी लॉग एंट्रियाँ हट जाएँगी।';

  @override
  String get debugClearLogsTitle => 'लॉग साफ़ करें?';

  @override
  String get debugClearSearch => 'खोज साफ़ करें';

  @override
  String get debugCodePush => 'कोड पुश';

  @override
  String get debugCoins => 'कॉइन्स';

  @override
  String get debugCopied => 'कॉपी किया गया';

  @override
  String get debugCopiedToClipboard => 'क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get debugCopy => 'कॉपी करें';

  @override
  String get debugCopyDiagnosticReport => 'डायग्नोस्टिक रिपोर्ट कॉपी करें';

  @override
  String get debugCopyFiltered => 'सब कॉपी करें (फ़िल्टर किए गए)';

  @override
  String get debugCopyFullDetail => 'पूरा विवरण कॉपी करें';

  @override
  String debugCopyTitle(String title) {
    return '$title कॉपी करें';
  }

  @override
  String get debugCopyValue => 'वैल्यू कॉपी करें';

  @override
  String debugCouldNotClearCache(String error) {
    return 'ऐप कैश साफ़ नहीं हो सका: $error';
  }

  @override
  String get debugCouldNotSaveValue => 'वैल्यू सेव नहीं हो सकी';

  @override
  String get debugCrashApp => 'ऐप क्रैश करें';

  @override
  String get debugDangerZone => 'ख़तरे वाला क्षेत्र';

  @override
  String get debugDarkCard => 'डार्क कार्ड';

  @override
  String get debugDefaultValue => '(डिफ़ॉल्ट)';

  @override
  String get debugDelete => 'मिटाएँ';

  @override
  String get debugDeleteKey => 'की मिटाएँ';

  @override
  String debugDeleteKeyBody(String key) {
    return 'स्थानीय स्टोरेज से \"$key\" मिटाएँ।';
  }

  @override
  String get debugDeleteKeyTitle => 'की मिटाएँ?';

  @override
  String get debugDevice => 'डिवाइस';

  @override
  String get debugDeviceName => 'डिवाइस';

  @override
  String get debugDevicePixelRatio => 'डिवाइस पिक्सेल अनुपात';

  @override
  String get debugDiagnosticCopied => 'डायग्नोस्टिक रिपोर्ट क्लिपबोर्ड पर कॉपी की गई';

  @override
  String get debugDiagnosticReportHeading => '=== Prism डायग्नोस्टिक रिपोर्ट ===';

  @override
  String get debugEditValue => 'वैल्यू संपादित करें';

  @override
  String get debugEmail => 'ईमेल';

  @override
  String get debugEmptyList => 'खाली सूची';

  @override
  String get debugEnvironment => 'पर्यावरण';

  @override
  String get debugError => 'त्रुटि';

  @override
  String get debugErrorCopied => 'त्रुटि कॉपी की गई';

  @override
  String get debugErrorStreakLost => 'त्रुटि, स्ट्रीक टूट गई';

  @override
  String get debugErrorValue => 'त्रुटि';

  @override
  String get debugExportFile => 'फ़ाइल के रूप में एक्सपोर्ट करें';

  @override
  String get debugFavouriteAdded => 'पसंदीदा में जोड़ा गया';

  @override
  String get debugFilterByTag => 'टैग के अनुसार फ़िल्टर करें';

  @override
  String get debugFilterKeys => 'की फ़िल्टर करें';

  @override
  String get debugFingerprint => 'फ़िंगरप्रिंट';

  @override
  String get debugFirestoreTelemetryDescription => 'Firestore रीड और राइट प्रोफ़ाइलिंग देखें';

  @override
  String get debugFlagsReset => 'डिबग फ़्लैग रीसेट किए गए';

  @override
  String get debugForceCrash => 'ज़बरन क्रैश करें';

  @override
  String get debugForceCrashBody => 'Sentry की त्रुटि रिपोर्टिंग जाँचने के लिए यह एक अपवाद उत्पन्न करता है।';

  @override
  String get debugForceCrashDescription => 'Sentry रिपोर्टिंग जाँचने के लिए एक अपवाद उत्पन्न करें';

  @override
  String get debugForceCrashTitle => 'ज़बरन क्रैश करें?';

  @override
  String debugGeneratedAt(String date) {
    return 'बनाया गया: $date';
  }

  @override
  String get debugHardware => 'हार्डवेयर';

  @override
  String get debugIdentifier => 'पहचानकर्ता';

  @override
  String get debugImageCacheCleared => 'इमेज कैश साफ़ किया गया';

  @override
  String get debugIsAdmin => 'एडमिन है';

  @override
  String get debugIsPremium => 'Premium है';

  @override
  String get debugLevel => 'लेवल';

  @override
  String get debugLightCard => 'लाइट कार्ड';

  @override
  String get debugLoadingSearch => 'लोड हो रहा है, खोजें';

  @override
  String get debugLogDetail => 'लॉग विवरण';

  @override
  String debugLogEntryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString एंट्रियाँ',
      one: '$countString एंट्री',
    );
    return '$_temp0';
  }

  @override
  String get debugLoggedIn => 'साइन इन है';

  @override
  String get debugLoggingAndNetwork => 'लॉगिंग और नेटवर्क';

  @override
  String get debugLogicalSize => 'तार्किक आकार';

  @override
  String get debugLogs => 'लॉग';

  @override
  String get debugLogsAppearHere => 'ऐप चलते समय लॉग की पंक्तियाँ यहाँ दिखेंगी।';

  @override
  String get debugMaintenance => 'रखरखाव';

  @override
  String get debugManufacturer => 'निर्माता';

  @override
  String get debugMascot => 'मैस्कॉट';

  @override
  String get debugMessage => 'मैसेज';

  @override
  String get debugMixpanelEnabled => 'Mixpanel चालू है';

  @override
  String get debugMixpanelTokenPresent => 'Mixpanel टोकन मौजूद है';

  @override
  String get debugModel => 'मॉडल';

  @override
  String get debugMoodCalm => 'शांत';

  @override
  String get debugMoodCelebrate => 'जश्न मनाता हुआ';

  @override
  String get debugMoodCurious => 'जिज्ञासु';

  @override
  String get debugMoodHappy => 'खुश';

  @override
  String get debugMoodLove => 'प्यार';

  @override
  String get debugMoodProud => 'गर्वित';

  @override
  String get debugMoodSad => 'उदास';

  @override
  String get debugMoodSleepy => 'नींद में';

  @override
  String get debugMoodSurprised => 'हैरान';

  @override
  String get debugMoodWorried => 'चिंतित';

  @override
  String get debugName => 'नाम';

  @override
  String get debugNoKeysFound => 'कोई की नहीं मिली';

  @override
  String get debugNoLogs => 'कोई लॉग नहीं';

  @override
  String get debugNoMatchingLogs => 'फ़िल्टर से मेल खाती कोई लॉग पंक्ति नहीं है।';

  @override
  String get debugNotAvailable => 'उपलब्ध नहीं';

  @override
  String get debugNotSignedIn => 'साइन इन नहीं है';

  @override
  String get debugNothingNew => 'कुछ नया नहीं';

  @override
  String get debugOfflineStreakRisk => 'ऑफ़लाइन, स्ट्रीक टूटने का जोखिम';

  @override
  String get debugPackage => 'पैकेज';

  @override
  String get debugPackageName => 'पैकेज का नाम';

  @override
  String get debugPaintBaselines => 'बेसलाइन दिखाएँ';

  @override
  String get debugPaintBaselinesDescription => 'टेक्स्ट बेसलाइन गाइड दिखाएँ';

  @override
  String get debugPaintSize => 'आकार दिखाएँ';

  @override
  String get debugPaintSizeDescription => 'सभी विजेट की लेआउट सीमाएँ दिखाएँ';

  @override
  String get debugPaintSizeWarning => 'आकार, रीपेंट रेनबो और बेसलाइन केवल डिबग और प्रोफ़ाइल बिल्ड में काम करते हैं।';

  @override
  String get debugPerformanceOverlay => 'परफ़ॉर्मेंस ओवरले';

  @override
  String get debugPerformanceOverlayDescription => 'GPU और CPU उपयोग के ग्राफ़';

  @override
  String get debugPersistenceBackend => 'स्थायी स्टोरेज बैकएंड';

  @override
  String get debugPexelsKeyPresent => 'Pexels की मौजूद है';

  @override
  String get debugPhysicalDevice => 'असली डिवाइस है';

  @override
  String get debugPhysicalSize => 'भौतिक आकार';

  @override
  String get debugPlatform => 'प्लैटफ़ॉर्म';

  @override
  String get debugRcApiKeyPresent => 'RC API की मौजूद है';

  @override
  String get debugReduceMotionPose => 'हर मूड की कम गति वाली मुद्रा दिखाएँ';

  @override
  String get debugRefresh => 'रीफ़्रेश करें';

  @override
  String get debugRemoteConfig => 'रिमोट कॉन्फ़िगरेशन';

  @override
  String get debugRemoteConfigUnavailable => 'रिमोट कॉन्फ़िगरेशन उपलब्ध नहीं है';

  @override
  String get debugRendering => 'रेंडरिंग';

  @override
  String get debugRepaintRainbow => 'रीपेंट रेनबो';

  @override
  String get debugRepaintRainbowDescription => 'बार-बार पेंट हुए हिस्सों को बदलते रंगों में हाइलाइट करें';

  @override
  String get debugResetFlags => 'सभी डिबग फ़्लैग रीसेट करें';

  @override
  String get debugResetFlagsDescription => 'सभी टॉगल को डिफ़ॉल्ट वैल्यू पर लौटाएँ';

  @override
  String get debugSave => 'सेव करें';

  @override
  String get debugSaveValueAsText => 'सेव करने पर वैल्यू टेक्स्ट के रूप में लिखी जाएगी।';

  @override
  String get debugScreen => 'स्क्रीन';

  @override
  String get debugSdkInt => 'SDK पूर्णांक';

  @override
  String get debugSearchLogs => 'लॉग खोजें';

  @override
  String get debugSemanticsDebugger => 'सेमांटिक्स डीबगर';

  @override
  String get debugSemanticsDebuggerDescription => 'ऐक्सेसिबिलिटी ट्री के लेबल ओवरले में दिखाएँ';

  @override
  String get debugSentryDsnPresent => 'Sentry DSN मौजूद है';

  @override
  String get debugSentryEnabled => 'Sentry चालू है';

  @override
  String get debugSentryEnv => 'Sentry परिवेश';

  @override
  String get debugSequence => 'क्रम';

  @override
  String get debugShorebirdPatch => 'Shorebird पैच';

  @override
  String get debugShowLogToasts => 'लॉग टोस्ट दिखाएँ';

  @override
  String get debugShowLogToastsDescription => 'लॉग एंट्रियाँ कुछ पल के लिए ओवरले टोस्ट के रूप में दिखाएँ';

  @override
  String get debugSimulateNoInternet => 'इंटरनेट न होने का सिमुलेशन करें';

  @override
  String get debugSimulateNoInternetDescription => 'कनेक्टिविटी जाँच को ऑफ़लाइन स्थिति दिखाने के लिए बदलें';

  @override
  String get debugSpeed => 'गति';

  @override
  String get debugStackTrace => 'स्टैक ट्रेस';

  @override
  String get debugStackTraceCopied => 'स्टैक ट्रेस कॉपी किया गया';

  @override
  String get debugStagingPatches => 'स्टेजिंग पैच प्राप्त करें';

  @override
  String get debugStagingPatchesDescription =>
      'स्थिर चैनल की जगह Shorebird स्टेजिंग चैनल जाँचें। पैच लागू करने के लिए रीस्टार्ट करें।';

  @override
  String get debugStillPoses => 'स्थिर मुद्राएँ';

  @override
  String get debugStorage => 'स्टोरेज';

  @override
  String get debugStorageCleared => 'सारा स्टोरेज साफ़ कर दिया गया';

  @override
  String debugStorageKeyCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString कुंजियाँ',
      one: '$countString कुंजी',
    );
    return '$_temp0';
  }

  @override
  String get debugStorageNotInitialized => 'स्टोरेज शुरू नहीं हुआ है';

  @override
  String get debugStorageReadError => 'स्टोरेज पढ़ा नहीं जा सका';

  @override
  String get debugStreakCoinsPurchase => 'स्ट्रीक, कॉइन्स, खरीदारी';

  @override
  String get debugStreakKeptToday => 'आज की स्ट्रीक बनी रही';

  @override
  String get debugSubscriptionTier => 'सब्सक्रिप्शन स्तर';

  @override
  String get debugSystemName => 'सिस्टम का नाम';

  @override
  String get debugSystemVersion => 'सिस्टम संस्करण';

  @override
  String get debugTime => 'समय';

  @override
  String get debugTitle => 'डिबग';

  @override
  String get debugTools => 'टूल';

  @override
  String debugTypeName(String type) {
    return 'प्रकार: $type';
  }

  @override
  String get debugUser => 'उपयोगकर्ता';

  @override
  String get debugUserId => 'उपयोगकर्ता ID';

  @override
  String get debugUsername => 'यूज़रनेम';

  @override
  String get debugValue => 'मान';

  @override
  String get debugVersion => 'संस्करण';

  @override
  String get debugWallpaperSetSaved => 'वॉलपेपर लगाया या सेव किया';

  @override
  String get debugWotdNotification => 'आज का वॉलपेपर, नोटिफ़िकेशन';

  @override
  String get deepLinkInputChooseImage => 'तस्वीर चुनें';

  @override
  String get deepLinkInputChooseImageDescription => 'जारी रखने के लिए अपनी गैलरी से तस्वीर चुनें।';

  @override
  String get deepLinkInputClockPreviewTitle => 'घड़ी का प्रीव्यू';

  @override
  String get deepLinkInputEditTitle => 'वॉलपेपर संपादित करें';

  @override
  String get deepLinkInputFiltersTitle => 'वॉलपेपर फ़िल्टर';

  @override
  String get deepLinkInputGalleryError => 'गैलरी नहीं खुल सकी। कृपया फिर कोशिश करें।';

  @override
  String get deepLinkInputLiveTitle => 'लाइव वॉलपेपर';

  @override
  String get deepLinkInputPhotoPreviewTitle => 'तस्वीर का प्रीव्यू';

  @override
  String get deepLinkInputPositionTitle => 'वॉलपेपर की स्थिति तय करें';

  @override
  String get deepLinkInputUploadTitle => 'वॉलपेपर अपलोड करें';

  @override
  String get deepLinkInputWallpaperPreviewTitle => 'वॉलपेपर का प्रीव्यू';

  @override
  String get economyActivity => 'गतिविधि';

  @override
  String get economyActivityEmptyMessage => 'अपने पहले कॉइन्स कमाने के लिए वीडियो देखें या अपनी स्ट्रीक बनाए रखें।';

  @override
  String get economyActivityLoadFailed => 'गतिविधि लोड नहीं हो सकी।';

  @override
  String get economyAdCreditFailure => 'अभी कॉइन्स जोड़ना संभव नहीं है।';

  @override
  String get economyAdDailyLimit => 'आज की सीमा पूरी हो गई। कल फिर आएँ।';

  @override
  String get economyAdNotCompleted => 'विज्ञापन पूरा नहीं हुआ।';

  @override
  String get economyAdOffline => 'आप ऑफ़लाइन हैं। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String economyAdRewardDetails(int first, int reward, int maximum) {
    final intl.NumberFormat firstNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String firstString = firstNumberFormat.format(first);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'आज का पहला विज्ञापन +$firstString, फिर +$rewardString देगा। दिन में अधिकतम $maximumString।';
  }

  @override
  String get economyAdRewardPending => 'हम अभी आपके इनाम की पुष्टि नहीं कर सके। ऑनलाइन आने पर कॉइन्स मिल जाएँगे।';

  @override
  String get economyAdUnavailable => 'अभी कोई विज्ञापन उपलब्ध नहीं है। बाद में फिर कोशिश करें।';

  @override
  String get economyAddPhotoBio => 'तस्वीर और परिचय जोड़ें';

  @override
  String get economyAddedToBalance => 'आपके बैलेंस में जोड़ा गया';

  @override
  String get economyAddedToCollection => 'आपके कलेक्शन में जोड़ा गया';

  @override
  String get economyAddedToXp => 'आपके XP में जोड़ा गया';

  @override
  String get economyAdsOffPrivacy => 'विज्ञापन बंद हैं। इसे सेटिंग > प्राइवेसी में बदलें।';

  @override
  String get economyAiBusyRefunded => 'AI अभी बहुत व्यस्त है। बाद में फिर कोशिश करें। आपके कॉइन्स लौटा दिए गए हैं।';

  @override
  String get economyAiChargeUnconfirmed => 'चार्ज की पुष्टि नहीं हो सकी। काटे गए कॉइन्स वापस कर दिए जाएँगे।';

  @override
  String get economyAiCheckStatus => 'स्थिति जाँचें';

  @override
  String economyAiCoinsNeeded(int cost, int balance) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'आपको $costString कॉइन्स चाहिए। आपके पास $balanceString हैं।';
  }

  @override
  String get economyAiConnectToGenerate => 'कनेक्शन नहीं है। इंटरनेट से जुड़ें, फिर कोशिश करें।';

  @override
  String get economyAiCouldNotConfirmSubmission =>
      'सबमिशन की पुष्टि नहीं हो सकी। फिर कोशिश करने से पहले समीक्षा स्थिति देखें।';

  @override
  String get economyAiCropMayDiffer => 'आपके डिवाइस पर क्रॉप थोड़ा अलग हो सकता है।';

  @override
  String get aiLiveActivityGenerating => 'आपका वॉलपेपर बनाया जा रहा है';

  @override
  String get aiLiveActivityReady => 'आपका वॉलपेपर तैयार है';

  @override
  String get aiLiveActivityFailed => 'बनाया नहीं जा सका';

  @override
  String get aiLiveActivityStale => 'अभी भी इस पर काम हो रहा है';

  @override
  String get aiLiveActivityOpen => 'Prism में खोलें';

  @override
  String get economyAiDailyLimit => 'आज की AI सीमा पूरी हो गई।';

  @override
  String get economyAiDescribeChanges => 'बताएँ कि क्या बदलना है, जैसे रंग, मूड या बारीकियाँ।';

  @override
  String get economyAiDescribeScene => 'बनाने के लिए किसी दृश्य का वर्णन करें।';

  @override
  String get economyAiDownloadFailed => 'डाउनलोड नहीं हो सका! कृपया फिर कोशिश करें।';

  @override
  String economyAiFailureWithRefund(String message, String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'refunded': ' कॉइन्स वापस कर दिए गए।',
      'pending': ' रिफ़ंड लंबित है।',
      'other': ' रिफ़ंड पूरा नहीं हो सका।',
    });
    return '$message$_temp0';
  }

  @override
  String get economyAiGenerate => 'बनाएँ';

  @override
  String get economyAiGenerateAnother => 'एक और बनाएँ';

  @override
  String get economyAiGenerateFailed => 'अभी बनाया नहीं जा सका। फिर कोशिश करें।';

  @override
  String get economyAiGenerateGenericFailure => 'कुछ गड़बड़ हुई। फिर कोशिश करें।';

  @override
  String get economyAiGeneratedWallpaper => 'AI से बना वॉलपेपर';

  @override
  String economyAiGenerationFrom(String date) {
    return '$date का जनरेशन';
  }

  @override
  String get economyAiGenerationRollingOut =>
      'AI जनरेशन अभी धीरे-धीरे उपलब्ध कराया जा रहा है। कृपया जल्द फिर कोशिश करें।';

  @override
  String get economyAiGenerationTime => 'इसमें लगभग 20 सेकंड लगते हैं';

  @override
  String get economyAiHistoryEmpty =>
      'आपका बनाया हर वॉलपेपर यहाँ दिखेगा, ताकि आप तुलना कर सकें या पुराने वॉलपेपर पर लौट सकें।';

  @override
  String get economyAiHistoryFailed => 'इतिहास लोड नहीं हो सका। रीफ़्रेश करने के लिए नीचे खींचें।';

  @override
  String get economyAiMatchingScreenSize => 'आपकी स्क्रीन के आकार से मेल बिठा रहे हैं…';

  @override
  String get economyAiApplyingStyle => 'आपकी शैली लागू कर रहे हैं…';

  @override
  String get economyAiFinalizingWallpaper => 'आपके वॉलपेपर को अंतिम रूप दे रहे हैं…';

  @override
  String get economyAiRemixHint => 'गहरा आसमान, गर्म रंग, किनारे थोड़े नरम…';

  @override
  String economyAiNeedCoinsToGenerate(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'बनाने के लिए $costString कॉइन्स चाहिए।';
  }

  @override
  String economyNeedMoreCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'अभी $countString कॉइन और चाहिए।',
      one: 'अभी $countString कॉइन और चाहिए।',
    );
    return '$_temp0';
  }

  @override
  String get economyAiNoConnection => 'कनेक्शन नहीं है। अपना नेटवर्क जाँचें और फिर कोशिश करें।';

  @override
  String get economyAiNoConnectionRetry => 'कनेक्शन नहीं है। फिर कोशिश करें।';

  @override
  String get economyAiOfflineHistory =>
      'आप ऑफ़लाइन हैं या नेटवर्क में समस्या आई। वापस ऑनलाइन होने पर रीफ़्रेश करने के लिए नीचे खींचें।';

  @override
  String get economyAiOfflineSavedHistory => 'आप ऑफ़लाइन हैं। सेव किया हुआ इतिहास अब भी उपलब्ध है।';

  @override
  String get economyAiPaymentCheckFailed => 'भुगतान की जाँच नहीं हो सकी। आपके कॉइन्स लौटा दिए जाएँगे।';

  @override
  String get economyAiPreparingShare => 'शेयर करने की तैयारी हो रही है';

  @override
  String get economyAiPromptBlocked => 'यह विवरण स्वीकार्य नहीं है।';

  @override
  String economyAiPromptTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'विवरण बहुत लंबा है (अधिकतम $maximumString अक्षर)।';
  }

  @override
  String get economyAiQuality => 'गुणवत्ता';

  @override
  String get economyAiQualityBalanced => 'संतुलित';

  @override
  String get economyAiQualityFast => 'तेज़';

  @override
  String get economyAiQualityHigh => 'उच्च गुणवत्ता';

  @override
  String economyAiQualitySemantics(String quality, int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '$quality, $costString कॉइन्स';
  }

  @override
  String get economyAiRecent => 'हाल के';

  @override
  String get economyAiRefineExplanation =>
      'बताएँ कि क्या बदलना चाहिए। इससे उसी विवरण और नए सीड से एक नया वॉलपेपर बनेगा, जो काफ़ी अलग दिख सकता है।';

  @override
  String get economyAiResultBlocked => 'नतीजा रोक दिया गया। कोई और विवरण आज़माएँ।';

  @override
  String economyAiRolloutBody(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'अब तक $percentString% अकाउंट्स के लिए उपलब्ध है। जल्द फिर कोशिश करें।';
  }

  @override
  String get economyAiRolloutTitle => 'AI वॉलपेपर धीरे-धीरे उपलब्ध हो रहा है';

  @override
  String get economyAiSave => 'सेव करें';

  @override
  String get economyAiSaveFailed => 'फ़ाइल सेव नहीं हो सकी। फिर कोशिश करें।';

  @override
  String get economyAiSceneIdea => 'दृश्य का विचार';

  @override
  String get economyAiSceneIdeaMessage => 'इस दृश्य को अपने विवरण में इस्तेमाल करें (बदल सकते हैं)';

  @override
  String get economyAiSetAsWallpaper => 'वॉलपेपर के रूप में लगाएँ';

  @override
  String get economyAiShare => 'शेयर करें';

  @override
  String get economyAiShareFailed => 'शेयर नहीं हो सका। कृपया फिर कोशिश करें।';

  @override
  String get economyAiShareReviewNotice =>
      'Prism पर दिखने से पहले मॉडरेटर सबमिशन की समीक्षा करते हैं। केवल वही काम शेयर करें जिसके अधिकार आपके पास हैं।';

  @override
  String get economyAiShareWithCommunity => 'कम्युनिटी के साथ शेयर करें?';

  @override
  String get economyAiShuffle => 'बदलें';

  @override
  String get economyAiShuffleMessage => 'उदाहरण के लिए कोई नया विवरण दिखाएँ';

  @override
  String get economyAiStillWorking => 'आपकी पिछली तस्वीर पर अभी काम चल रहा है।';

  @override
  String get economyAiStyle => 'स्टाइल';

  @override
  String get economyAiStyleAbstract => 'एब्स्ट्रैक्ट';

  @override
  String get economyAiStyleAnime => 'ऐनिमे';

  @override
  String get economyAiStyleCyberpunk => 'साइबरपंक';

  @override
  String get economyAiStyleMeshGradient => 'मेश ग्रेडिएंट';

  @override
  String get economyAiStyleMinimal => 'मिनिमल';

  @override
  String get economyAiStyleNature => 'प्रकृति';

  @override
  String economyAiStyleSemantics(String style) {
    return 'स्टाइल: $style';
  }

  @override
  String get economyAiStyleWatercolor => 'वॉटरकलर';

  @override
  String get economyAiStyleSpace => 'अंतरिक्ष';

  @override
  String get economyAiStyleSynthwave => 'सिंथवेव';

  @override
  String get economyAiStylePixelArt => 'पिक्सेल आर्ट';

  @override
  String get economyAiStyleRender3d => '3D रेंडर';

  @override
  String get economyAiStyleOilPainting => 'ऑयल पेंटिंग';

  @override
  String get economyAiStyleUkiyoE => 'उकियो-ए';

  @override
  String get economyAiSubmissionUnconfirmed => 'सबमिशन की स्थिति की पुष्टि नहीं हुई। फिर कोशिश करने से पहले जाँचें।';

  @override
  String get economyAiSubmitDisabled => 'AI सबमिशन अभी बंद है।';

  @override
  String get economyAiSubmitFailed => 'सबमिट नहीं हो सका। कृपया फिर कोशिश करें।';

  @override
  String get economyAiSubmitForReview => 'कम्युनिटी समीक्षा के लिए सबमिट करें';

  @override
  String get economyAiSubmitStatusUnconfirmed =>
      'सबमिशन की स्थिति की पुष्टि नहीं हुई। फिर कोशिश करने से पहले समीक्षा स्थिति देखें।';

  @override
  String get economyAiSubmittedForReview => 'समीक्षा के लिए सबमिट किया गया।';

  @override
  String get economyAiTryAgain => 'फिर कोशिश करें';

  @override
  String get economyAiTryAnother => 'दूसरा आज़माएँ';

  @override
  String get economyAiTryAnotherVersion => 'दूसरा संस्करण आज़माएँ';

  @override
  String get economyAiUnavailableBody => 'हमने इसे थोड़ी देर के लिए बंद किया है। जल्द फिर देखें।';

  @override
  String get economyAiUnavailableTitle => 'AI वॉलपेपर अभी उपलब्ध नहीं है';

  @override
  String economyAiVariationTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'विवरण बहुत लंबा है (अधिकतम $maximumString अक्षर)।';
  }

  @override
  String get economyAiVariationUnavailable => 'अभी दूसरा आज़माना उपलब्ध नहीं है।';

  @override
  String get economyAiWallpaper => 'AI वॉलपेपर';

  @override
  String get economyAiWatermarkNote => 'मुफ़्त तस्वीरों पर Prism का वॉटरमार्क होता है। Pro से यह हट जाता है।';

  @override
  String get economyAllRankRewardsCollected => 'रैंक के सभी इनाम ले लिए गए';

  @override
  String get economyAllSpinsUsed => 'सभी स्पिन इस्तेमाल हो गए';

  @override
  String get economyBackTomorrow => 'कल फिर आएँ';

  @override
  String get economyBadge => 'बैज';

  @override
  String get economyBadgeAiArtist => 'AI कलाकार';

  @override
  String get economyBadgeAiArtistDescription => '10 AI वॉलपेपर बनाएँ';

  @override
  String get economyBadgeArtCurator => 'कला क्यूरेटर';

  @override
  String get economyBadgeArtCuratorDescription => '50 वॉलपेपर पसंदीदा बनाएँ';

  @override
  String get economyBadgeCollector => 'कलेक्टर';

  @override
  String get economyBadgeCollectorDescription => '10 वॉलपेपर पसंदीदा बनाएँ';

  @override
  String get economyBadgeCreator => 'क्रिएटर';

  @override
  String get economyBadgeCreatorDescription => 'एक वॉलपेपर मंज़ूर करवाएँ';

  @override
  String get economyBadgeDescription => 'Prism में एक बैज';

  @override
  String get economyBadgeEarned => 'बैज मिला';

  @override
  String economyBadgeEarnedCount(int count, int total) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString में से $countString मिले';
  }

  @override
  String economyBadgeName(String name) {
    return '$name बैज';
  }

  @override
  String get economyBadgePrismVeteran => 'Prism के अनुभवी';

  @override
  String get economyBadgePrismVeteranDescription => 'Prism को 30 दिन इस्तेमाल करें और 7 दिन की स्ट्रीक बनाएँ';

  @override
  String get economyBadgeProfileComplete => 'पूरा प्रोफ़ाइल';

  @override
  String get economyBadgeProfileCompleteDescription => 'तस्वीर, यूज़रनेम, परिचय और लिंक जोड़ें';

  @override
  String economyBadgeSemantics(String name, String status, String description) {
    return '$name, $status। $description';
  }

  @override
  String get economyBadgeSocialButterfly => 'मिलनसार';

  @override
  String get economyBadgeSocialButterflyDescription => '10 क्रिएटर्स को फ़ॉलो करें';

  @override
  String get economyBadgeStatusEarned => 'मिला हुआ';

  @override
  String get economyBadgeStatusLocked => 'लॉक है';

  @override
  String get economyBadgeStreakMaster => 'स्ट्रीक मास्टर';

  @override
  String get economyBadgeStreakMasterDescription => '28 दिन की स्ट्रीक बनाएँ';

  @override
  String get economyBadgeWeekWarrior => 'सप्ताह के योद्धा';

  @override
  String get economyBadgeWeekWarriorDescription => '7 दिन की स्ट्रीक बनाएँ';

  @override
  String get economyBadges => 'बैज';

  @override
  String economyBalanceSemantics(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString Prism कॉइन्स';
  }

  @override
  String economyBestStreak(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString दिन की स्ट्रीक',
      one: '$countString दिन की स्ट्रीक',
    );
    return 'सबसे अच्छी $_temp0';
  }

  @override
  String get economyBoost => 'बूस्ट';

  @override
  String economyBoostInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'अपने मंज़ूर किए गए वॉलपेपर में से एक को ट्रेंडिंग में सबसे ऊपर दिखाएँ। बूस्ट के लिए $amountString कॉइन्स लगते हैं। अपना वॉलपेपर खोलें और बूस्ट पर टैप करें।';
  }

  @override
  String get economyBuildStreakDaily => 'स्ट्रीक बनाने के लिए हर दिन Prism खोलें।';

  @override
  String get economyBuy => 'खरीदें';

  @override
  String get economyBuyPremium => 'Premium खरीदें';

  @override
  String get economyCancel => 'रद्द करें';

  @override
  String get economyChestBonusDone => 'बोनस क्वेस्ट पूरी: आपके कॉइन्स दोगुने हो गए।';

  @override
  String get economyChestBonusToDouble => 'अपने कॉइन्स दोगुने करने के लिए पहले आज की बोनस क्वेस्ट पूरी करें।';

  @override
  String economyChestBoosterSemantics(String title, String caption) {
    return '$title। $caption';
  }

  @override
  String economyChestCoinsPrize(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString कॉइन्स',
      one: '$coinsString कॉइन',
    );
    return '$_temp0';
  }

  @override
  String get economyChestDoFirst => 'अपना चेस्ट दोगुना करने के लिए यह पहले करें';

  @override
  String get economyChestDoubled => 'चेस्ट दोगुना हुआ';

  @override
  String get economyChestDoubledByBonus => ' आपकी बोनस क्वेस्ट से दोगुना हुआ।';

  @override
  String get economyChestFreeToday => 'आज मुफ़्त';

  @override
  String economyChestNeedCoins(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'चेस्ट की कीमत $priceString कॉइन्स है। आपके पास $balanceString हैं। और कमाने के लिए वीडियो देखें।';
  }

  @override
  String economyChestNewCosmetic(String kind, String name) {
    return 'एक नया $kind: $name';
  }

  @override
  String economyChestNewKind(String kind) {
    return 'नया $kind';
  }

  @override
  String get economyChestOpenFailed => 'Prism से कनेक्ट नहीं हो सका। फिर कोशिश करें।';

  @override
  String economyChestOpenFor(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString और क्वेस्ट',
      one: '$countString और क्वेस्ट',
    );
    return 'इसे $priceString कॉइन्स में खोलें, या मुफ़्त खोलने के लिए $_temp0 पूरी करें।';
  }

  @override
  String get economyChestOpened => 'खोल दिया गया';

  @override
  String get economyChestOpenedDoubledTomorrow => 'खोल दिया और दोगुना किया। नया कल मिलेगा।';

  @override
  String economyChestOpenedReset(String time) {
    return 'खोल दिया। $time में नया चेस्ट मिलेगा।';
  }

  @override
  String get economyChestOpenedTomorrow => 'खोल दिया। नया कल मिलेगा।';

  @override
  String get economyChestOwnCosmeticCoins => 'आपके पास सभी कॉस्मेटिक आइटम हैं, इसलिए इसके बदले कॉइन्स मिलेंगे';

  @override
  String get economyChestOwnEveryCosmetic => 'आपके पास सभी कॉस्मेटिक आइटम हैं';

  @override
  String get economyChestPriceChanged => 'कीमत बदल गई है। जाँचें और फिर खोलें।';

  @override
  String economyChestPriceFreeAfter(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString और क्वेस्ट',
      one: '$countString और क्वेस्ट',
    );
    return '$priceString कॉइन्स, या $_temp0 के बाद मुफ़्त';
  }

  @override
  String economyChestPrizeSemantics(String tier, String prize, String doubled, int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(doubled, {'true': ' आपकी बोनस क्वेस्ट से दोगुना हुआ।', 'other': ''});
    String _temp1 = intl.Intl.pluralLogic(
      xp,
      locale: localeName,
      other: ' और $xpString XP।',
      one: ' और $xpString XP।',
      zero: '',
    );
    return '$tier। आपको $prize मिला।$_temp0$_temp1';
  }

  @override
  String get economyChestQuestsFree => 'आपकी क्वेस्ट से आज यह मुफ़्त हो गया।';

  @override
  String get economyChestReady => 'खोलने के लिए तैयार';

  @override
  String economyChestReadyPaid(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'खोलने के लिए तैयार। $totalString में से $doneString क्वेस्ट पूरी';
  }

  @override
  String economyChestResetHours(int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$hoursStringघं';
  }

  @override
  String economyChestResetHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$hoursStringघं $minutesStringमि';
  }

  @override
  String economyChestResetMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$minutesStringमि';
  }

  @override
  String get economyChestTierCommon => 'सामान्य';

  @override
  String get economyChestTierEpic => 'एपिक';

  @override
  String get economyChestTierLegendary => 'लीजेंडरी';

  @override
  String get economyChestTierRare => 'रेयर';

  @override
  String economyChestXpLine(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'इसे खोलने पर $xpString XP मिलेंगे।';
  }

  @override
  String get economyClaimedTodayDay7Chest => 'आज का काम पूरा हुआ। 7वें दिन का चेस्ट पाने के लिए कल लौटें।';

  @override
  String economyClaimedTodayReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'आज का काम पूरा हुआ। +$coinsString कॉइन्स पाने के लिए कल लौटें।';
  }

  @override
  String get economyClosePreview => 'प्रीव्यू बंद करें';

  @override
  String economyCoinActivitySemantics(String label, String date, String amount, int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'कॉइन्स', one: 'कॉइन');
    return '$label, $date, $amount $_temp0';
  }

  @override
  String economyCoinBalance(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'बैलेंस $balanceString';
  }

  @override
  String economyCoinGateRefundUnconfirmed(String action) {
    return '$action। आपके रिफ़ंड की पुष्टि नहीं हो सकी।';
  }

  @override
  String economyCoinGateRefunded(String action, int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString कॉइन लौटाए गए।',
      one: '$coinsString कॉइन लौटाया गया।',
    );
    return '$action। $_temp0';
  }

  @override
  String get economyCoinHistoryEarned => 'कमाए';

  @override
  String get economyCoinHistoryEmpty => 'अभी तक कोई कॉइन गतिविधि नहीं।';

  @override
  String get economyCoinHistoryLoadFailed => 'आपकी कॉइन हिस्ट्री लोड नहीं हो सकी।';

  @override
  String get economyCoinHistoryNoLoadedRows => 'अब तक लोड की गई पंक्तियों में कुछ नहीं है।';

  @override
  String get economyCoinHistoryNothingHere => 'अभी यहाँ कुछ नहीं है।';

  @override
  String get economyCoinHistoryRefunds => 'रिफ़ंड';

  @override
  String economyCoinHistoryRowSemantics(
    String label,
    String hasDescription,
    String description,
    String date,
    String amount,
    int coins,
    String balance,
  ) {
    String _temp0 = intl.Intl.selectLogic(hasDescription, {'true': ', $description', 'other': ''});
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'कॉइन', one: 'कॉइन');
    return '$label$_temp0, $date, $amount $_temp1, $balance';
  }

  @override
  String get economyCoinHistorySpent => 'खर्च किए';

  @override
  String get economyCoinHistoryTitle => 'कॉइन हिस्ट्री';

  @override
  String get economyCoinSpendFailed => 'अभी कॉइन का लेन-देन नहीं हो सका।';

  @override
  String economyCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString कॉइन',
      one: '$countString कॉइन',
    );
    return '$_temp0';
  }

  @override
  String get economyCoinsAreYoursToSpend => 'कॉइन खर्च करने के लिए आपके हैं';

  @override
  String economyCoinsEarned(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString कॉइन',
      one: '$countString कॉइन',
    );
    return '+$_temp0';
  }

  @override
  String economyCoinsRange(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '+$minimumString से +$maximumString';
  }

  @override
  String get economyCoinsSpendingDetails =>
      'कॉइन से वॉलपेपर, टूल और दुकान की चीज़ें खरीदी जा सकती हैं। XP आपकी प्रगति है, खर्च करने लायक बैलेंस नहीं। कॉइन खर्च करने से आपका XP कभी कम नहीं होता।';

  @override
  String get economyCoinsWhatYouCanDo => 'इनसे आप क्या कर सकते हैं';

  @override
  String get economyCoinsWord => 'कॉइन';

  @override
  String economyCollectionItemSemantics(String category, String status, String caption) {
    return '$category, $status। $caption';
  }

  @override
  String economyCollectionKeepStreakMessage(int days, int coins, String hasCoins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.selectLogic(hasCoins, {
      'true': ', या इसे अभी अनलॉक करने के लिए $coinsString कॉइन इस्तेमाल करें',
      'other': '',
    });
    return 'इस वॉलपेपर को अनलॉक करने के लिए $daysString दिन की स्ट्रीक जारी रखें$_temp0।';
  }

  @override
  String get economyCollectionLoadFailed => 'यह कलेक्शन लोड नहीं हो सका';

  @override
  String economyCollectionNeedCoinsMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'इस वॉलपेपर को अनलॉक करने के लिए आपको $coinsString कॉइन चाहिए।';
  }

  @override
  String get economyCollectionRequirementsUnmet => 'यह वॉलपेपर अभी उपलब्ध नहीं है।';

  @override
  String get economyCollectionStillLocked => 'अभी लॉक है';

  @override
  String economyCollectionUnlockedAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return '$daysString दिन की स्ट्रीक पर अनलॉक हुआ';
  }

  @override
  String get economyCollectionUnlockedWithCoins => 'कॉइन से अनलॉक किया गया';

  @override
  String economyCollectionUnlocksAtCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString कॉइन में अनलॉक होगा';
  }

  @override
  String economyCollectionUnlocksAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return '$daysString दिन की स्ट्रीक पर अनलॉक होगा';
  }

  @override
  String get economyCompleteProfile => 'अपनी प्रोफ़ाइल पूरी करें';

  @override
  String get economyCosmetic => 'कॉस्मेटिक';

  @override
  String get economyCosmeticAppIcon => 'ऐप आइकन';

  @override
  String get economyCosmeticFrame => 'फ़्रेम';

  @override
  String get economyCosmeticNameGlow => 'नाम की चमक';

  @override
  String get economyCosmeticTheme => 'थीम';

  @override
  String economyCountdownDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$daysString दिन $hoursString घंटे';
  }

  @override
  String economyCountdownHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$hoursString घंटे $minutesString मिनट';
  }

  @override
  String economyCountdownMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$minutesString मिनट';
  }

  @override
  String get economyCreatorApprovedWalls => 'स्वीकृत वॉलपेपर';

  @override
  String get economyCreatorIntro =>
      'आपके वॉलपेपर स्वीकृत होने और नए सदस्य उन्हें पसंदीदा बनाने पर XP कमाएँ। आपकी पहली योग्य पोस्ट के बाद प्रगति दिखने लगेगी।';

  @override
  String economyCreatorMilestoneProgress(String label, int current, int target) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$label: $currentString / $targetString';
  }

  @override
  String economyCreatorMilestoneSemantics(String label) {
    return '$label उपलब्धि';
  }

  @override
  String get economyCreatorMilestones => 'क्रिएटर उपलब्धियाँ';

  @override
  String economyCreatorMilestonesComplete(String label) {
    return '$label की उपलब्धियाँ पूरी हुईं';
  }

  @override
  String economyCreatorNewMembersThisWeek(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'इस हफ़्ते $countString नए सदस्यों ने आपके वॉलपेपर पसंदीदा बनाए';
  }

  @override
  String economyCreatorNextMilestone(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'अगली उपलब्धि: +$xpString XP';
  }

  @override
  String economyCreatorProgressSemantics(int current, int target) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$currentString में से $targetString';
  }

  @override
  String get economyCreatorQualifyingMembers => 'योग्य सदस्य';

  @override
  String get economyCreatorRefresh => 'प्रगति रीफ़्रेश करें';

  @override
  String get economyCreatorRefreshing => 'क्रिएटर की प्रगति रीफ़्रेश हो रही है…';

  @override
  String get economyCreatorRules =>
      'स्वीकृत वॉलपेपर आपके अपने योग्य अपलोड होने चाहिए। Prism मूल अपलोड की पुष्टि न कर पाए तो पुराने अपलोड अयोग्य हो सकते हैं। आपके सभी योग्य कामों में हर दूसरा सदस्य केवल एक बार गिना जाएगा, उसकी पहली योग्य पसंद पर। उसे साइन इन होना चाहिए, ईमेल सत्यापित होना चाहिए और उसका अकाउंट कम-से-कम सात दिन पुराना होना चाहिए। आपकी अपनी पसंदें नहीं गिनी जातीं। ये कुल पुराने रिकॉर्ड हैं, आपके मौजूदा दर्शक नहीं। पसंद हटाने से XP वापस नहीं जाता। क्रिएटर उपलब्धियों पर अतिरिक्त XP मिलता है। सप्ताह UTC में सोमवार से रविवार तक चलता है; देर से हुई गतिविधि अगले सप्ताह में दिख सकती है।';

  @override
  String get economyCreatorSavedRefresh => 'प्रगति सेव हो गई। अपडेट करने के लिए रीफ़्रेश करें।';

  @override
  String get economyCreatorSavedUnavailable => 'प्रगति सेव हो गई। रीफ़्रेश करना उपलब्ध नहीं है।';

  @override
  String economyCreatorThisWeekSummary(int walls, int xp) {
    final intl.NumberFormat wallsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String wallsString = wallsNumberFormat.format(walls);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$wallsString योग्य वॉलपेपर स्वीकृत · $xpString उपलब्धि XP';
  }

  @override
  String economyCreatorTrackingSince(String date) {
    return '$date UTC से ट्रैक हो रहा है';
  }

  @override
  String get economyCreatorUnavailable => 'क्रिएटर की प्रगति उपलब्ध नहीं है।';

  @override
  String economyCreatorWeekRange(String start, String end) {
    return '$start – $end UTC';
  }

  @override
  String economyCreatorWeekSummary(int walls, int members, int xp) {
    final intl.NumberFormat wallsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String wallsString = wallsNumberFormat.format(walls);
    final intl.NumberFormat membersNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String membersString = membersNumberFormat.format(members);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$wallsString योग्य वॉलपेपर स्वीकृत · $membersString नए योग्य सदस्य · $xpString उपलब्धि XP';
  }

  @override
  String get economyCreatorWhatCounts => 'क्या गिना जाता है और हिस्ट्री';

  @override
  String get economyDailyChest => 'दैनिक चेस्ट';

  @override
  String economyDailyChestSemantics(String state, String caption, String hasXp, String xpLine) {
    String _temp0 = intl.Intl.selectLogic(hasXp, {'true': '। $xpLine', 'other': ''});
    return 'दैनिक चेस्ट, $state। $caption$_temp0';
  }

  @override
  String get economyDailyChestTitle => 'दैनिक चेस्ट';

  @override
  String get economyDailyQuests => 'दैनिक क्वेस्ट';

  @override
  String get economyDailyStreak => 'दैनिक स्ट्रीक';

  @override
  String get economyDay7Chest => 'सातवें दिन का चेस्ट';

  @override
  String economyDayLabel(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'दिन $dayString';
  }

  @override
  String economyDayStreakMilestone(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return '$daysString दिन की स्ट्रीक!';
  }

  @override
  String economyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'दिन', one: 'दिन');
    return '$_temp0';
  }

  @override
  String economyDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString दिन पहले',
      one: '$countString दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String get economyDownload => 'डाउनलोड';

  @override
  String get economyDownloadAccountChanged => 'अकाउंट बदल गया। कृपया फिर से सेव करें।';

  @override
  String get economyDownloadAgain => 'फिर से डाउनलोड करें';

  @override
  String economyDownloadAgainCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'फिर से डाउनलोड करें (-$costString कॉइन)';
  }

  @override
  String get economyDownloadAlreadyInDownloads => 'पहले से डाउनलोड में है';

  @override
  String economyDownloadCoinsNeeded(int missing, int reward, String watch, String adState) {
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(watch, {'true': ' हर विज्ञापन से $rewardString मिलते हैं।', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(adState, {
      'disabled': ' विज्ञापन बंद हैं। इसे सेटिंग > गोपनीयता में बदलें।',
      'limit': ' आज की सीमा पूरी हुई। कल फिर कोशिश करें।',
      'other': '',
    });
    return 'इस वॉलपेपर को सेव करने के लिए आपको $missingString और कॉइन चाहिए।$_temp0$_temp1';
  }

  @override
  String economyDownloadCost(String label, int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '$label · $costString';
  }

  @override
  String economyDownloadCostSemantics(String label, int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '$label। इसकी कीमत $costString कॉइन है';
  }

  @override
  String get economyDownloadFailedLabel => 'डाउनलोड विफल';

  @override
  String economyDownloadFreeDownloadsLeftSemantics(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString मुफ़्त डाउनलोड बाकी',
      one: '$countString मुफ़्त डाउनलोड बाकी',
    );
    return '$label। मुफ़्त, $_temp0';
  }

  @override
  String economyDownloadFreeFor(String label) {
    return '$label · मुफ़्त';
  }

  @override
  String economyDownloadFreeLeftFor(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label · मुफ़्त · $countString बाकी';
  }

  @override
  String economyDownloadFreeOwnedSemantics(String label) {
    return '$label। मुफ़्त, यह वॉलपेपर आपका है';
  }

  @override
  String economyDownloadFreeWithPassSemantics(String label) {
    return '$label। आपके पास से मुफ़्त';
  }

  @override
  String get economyDownloadFreeWithPro => 'Pro के साथ मुफ़्त';

  @override
  String economyDownloadFreeWithProSemantics(String label) {
    return '$label। Pro के साथ मुफ़्त';
  }

  @override
  String get economyDownloadLinkUnavailable => 'डाउनलोड लिंक उपलब्ध नहीं है।';

  @override
  String get economyDownloadProGuestMessage => 'कॉइन से यह वॉलपेपर सेव करने के लिए साइन इन करें, या Prism Pro लें।';

  @override
  String get economyDownloadSaveLocalCopy => 'लोकल कॉपी सेव करें';

  @override
  String get economyDownloadSaved => 'सेव हो गया';

  @override
  String get economyDownloadSavedBefore => 'आपने यह वॉलपेपर पहले सेव किया है।';

  @override
  String get economyDownloadSavedInDownloads => 'सेव हो गया। पहले से डाउनलोड में है';

  @override
  String get economyDownloadThisWallpaper => 'यह वॉलपेपर डाउनलोड करें';

  @override
  String get economyDownloadWaitForCurrent => 'डाउनलोड पूरा होने तक इंतज़ार करें!';

  @override
  String get economyDownloadWatchAdMessage => 'यह वॉलपेपर डाउनलोड करने के लिए छोटा वीडियो विज्ञापन देखें।';

  @override
  String get economyDownloadWatchAdPrivacyMessage =>
      'यह वॉलपेपर डाउनलोड करने के लिए छोटा वीडियो विज्ञापन देखें। विज्ञापन बंद हैं। इसे सेटिंग > गोपनीयता में बदलें।';

  @override
  String get economyDownloads => 'डाउनलोड';

  @override
  String economyDownloadsInfo(int amount, int freeCount, String hasFree) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat freeCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String freeCountString = freeCountNumberFormat.format(freeCount);

    String _temp0 = intl.Intl.selectLogic(hasFree, {
      'true': ' आपके पहले $freeCountString डाउनलोड मुफ़्त हैं।',
      'other': '',
    });
    return 'हर वॉलपेपर डाउनलोड करने में $amountString कॉइन लगते हैं।$_temp0 Pro में डाउनलोड मुफ़्त हैं।';
  }

  @override
  String economyDrawAllTicketsHeld(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'इस हफ़्ते के सभी $maximumString टिकट आपके पास हैं।';
  }

  @override
  String economyDrawBuyTicket(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'टिकट खरीदें · $priceString';
  }

  @override
  String get economyDrawClosed => 'यह ड्रॉ बंद है। अगला सोमवार को खुलेगा।';

  @override
  String economyDrawClosesIn(String time) {
    return '$time में बंद होगा';
  }

  @override
  String get economyDrawLastWinner => 'पिछले विजेता';

  @override
  String get economyDrawLoadFailed => 'ड्रॉ लोड नहीं हो सका';

  @override
  String get economyDrawNotEnoughCoins => 'टिकट के लिए पर्याप्त कॉइन नहीं हैं।';

  @override
  String get economyDrawNotOpen => 'ड्रॉ अभी खुला नहीं है।';

  @override
  String get economyDrawOfficialRules => 'आधिकारिक नियम';

  @override
  String economyDrawPrizeDescription(int months) {
    final intl.NumberFormat monthsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$monthsString महीनों का',
      one: '$monthsString महीने का',
    );
    return '$_temp0 Pro + Prism फ़्रेम';
  }

  @override
  String get economyDrawProNotEligible => 'Pro सदस्य पात्र नहीं हैं।';

  @override
  String get economyDrawPurchaseFailed => 'टिकट नहीं खरीदा जा सका। फिर कोशिश करें।';

  @override
  String get economyDrawThisWeeksPrize => 'इस हफ़्ते का इनाम';

  @override
  String economyDrawTicketBought(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'टिकट खरीद लिया। आपके पास $maximumString में से $ticketsString हैं।';
  }

  @override
  String economyDrawTicketCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'टिकट की कीमत $priceString कॉइन है';
  }

  @override
  String economyDrawTicketsAndPeople(int tickets, int people) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat peopleNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String peopleString = peopleNumberFormat.format(people);

    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$peopleString लोगों',
      one: '$peopleString व्यक्ति',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tickets,
      locale: localeName,
      other: '$ticketsString टिकट',
      one: '$ticketsString टिकट',
    );
    return '$_temp0 के $_temp1';
  }

  @override
  String get economyDrawTitle => 'Prism Draw';

  @override
  String economyDrawYourChance(int mine, int pot) {
    final intl.NumberFormat mineNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String mineString = mineNumberFormat.format(mine);
    final intl.NumberFormat potNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String potString = potNumberFormat.format(pot);

    return 'आपकी संभावना: $mineString/$potString';
  }

  @override
  String economyDrawYourTickets(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'आपके टिकट: $maximumString में से $ticketsString';
  }

  @override
  String get economyDropAlreadyUnlocked => 'यह आपके पास पहले से है।';

  @override
  String economyDropByCreator(String creator) {
    return '$creator द्वारा';
  }

  @override
  String economyDropCardSemantics(String time, int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'साप्ताहिक Drop, $time, कुल $totalString में से $unlockedString जमा';
  }

  @override
  String economyDropCarouselDetail(int count, String time) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString वॉल',
      one: '$countString वॉल',
    );
    return '$_temp0 · $time';
  }

  @override
  String economyDropCarouselSemantics(String title, String detail, String lastCall) {
    String _temp0 = intl.Intl.selectLogic(lastCall, {'true': ', आख़िरी मौका', 'other': ''});
    return 'साप्ताहिक Drop, $title, $detail$_temp0';
  }

  @override
  String economyDropCollected(int owned, int total) {
    final intl.NumberFormat ownedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ownedString = ownedNumberFormat.format(owned);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString में से $ownedString जमा';
  }

  @override
  String economyDropDates(String start, String end) {
    return '$start से $end';
  }

  @override
  String get economyDropEnded => 'समाप्त';

  @override
  String get economyDropEndedHeadline => 'यह Drop समाप्त हो गया';

  @override
  String economyDropEndsInDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$daysString दिन', one: '$daysString दिन');
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString घंटे',
      one: '$hoursString घंटे',
    );
    return '$_temp0 $_temp1 में समाप्त होगा';
  }

  @override
  String economyDropEndsInHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString घंटे',
      one: '$hoursString घंटे',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutesString मिनट',
      one: '$minutesString मिनट',
    );
    return '$_temp0 $_temp1 में समाप्त होगा';
  }

  @override
  String economyDropEndsInMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$minutesString मिनट में समाप्त होगा';
  }

  @override
  String get economyDropGone => 'यह Drop अब उपलब्ध नहीं है';

  @override
  String get economyDropLastCallLabel => 'आख़िरी मौका';

  @override
  String get economyDropLoadFailed => 'Drop लोड नहीं हो सका';

  @override
  String get economyDropLocked => 'लॉक है';

  @override
  String get economyDropMissed => 'छूट गया';

  @override
  String get economyDropOver => 'यह Drop समाप्त हो चुका है।';

  @override
  String get economyDropPastDrops => 'पिछले Drops';

  @override
  String economyDropPosition(int index, int total) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString में से $indexString';
  }

  @override
  String get economyDropPreviewTitle => 'Drop का प्रीव्यू';

  @override
  String get economyDropRename => 'Drop का नाम बदलें';

  @override
  String get economyDropRenameFailed => 'Drop का नाम नहीं बदला जा सका। फिर कोशिश करें।';

  @override
  String get economyDropRenameHint => 'Drop का नाम';

  @override
  String get economyDropRenamed => 'Drop का नाम बदल दिया गया';

  @override
  String economyDropSave(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString कॉइन बचाएं';
  }

  @override
  String economyDropStats(String walls, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString कलेक्टर',
      one: '$countString कलेक्टर',
    );
    return '$walls · $_temp0';
  }

  @override
  String get economyDropTitle => 'Drop';

  @override
  String economyDropUnlockAll(int count, int price) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'सभी $countString को $priceString में अनलॉक करें';
  }

  @override
  String get economyDropUnlockFailed => 'अनलॉक नहीं हो सका। फिर कोशिश करें।';

  @override
  String economyDropUnlockFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$priceString में अनलॉक करें';
  }

  @override
  String economyDropUnlockWall(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'इस वॉल को $priceString में अनलॉक करें';
  }

  @override
  String get economyDropUnlocked => 'अनलॉक हुआ';

  @override
  String economyDropUnlockedCount(int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString में से $unlockedString अनलॉक';
  }

  @override
  String economyDropUnlockedCountToast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString वॉलपेपर अनलॉक हुए',
      one: 'वॉलपेपर अनलॉक हुआ',
    );
    return '$_temp0';
  }

  @override
  String get economyDropUnlockedWall => 'अनलॉक किया गया वॉलपेपर';

  @override
  String economyDropUnlockedWallBy(String creator) {
    return '$creator का वॉलपेपर अनलॉक किया';
  }

  @override
  String economyDropWallBySemantics(String state, String serial, String creator) {
    return '$creator का $state वॉलपेपर, क्रमांक $serial';
  }

  @override
  String economyDropWallCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString वॉलपेपर',
      one: '$countString वॉलपेपर',
    );
    return '$_temp0';
  }

  @override
  String economyDropWallSemantics(String state, String serial) {
    return '$state वॉलपेपर, क्रमांक $serial';
  }

  @override
  String get economyDropWallpaperUnavailable => 'यह वॉलपेपर उपलब्ध नहीं है';

  @override
  String economyDropWeekOf(String date) {
    return '$date का सप्ताह';
  }

  @override
  String get economyDropYourVault => 'आपकी तिजोरी';

  @override
  String get economyDrops => 'Drops';

  @override
  String get economyEarnCoins => 'कॉइन कमाएँ';

  @override
  String get economyEarnXpAsYouGo => 'खेलते-खेलते XP कमाएँ';

  @override
  String economyEarnedAtRank(String rank) {
    return '$rank रैंक पर कमाया';
  }

  @override
  String get economyEquipped => 'लागू किया';

  @override
  String get economyEveryChestPays => 'हर चेस्ट में कुछ न कुछ मिलता है।';

  @override
  String get economyEverySpinPays => 'हर स्पिन में कुछ न कुछ मिलता है।';

  @override
  String economyFallbackCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'सब अपने पास होने पर $countString कॉइन मिलेंगे';
  }

  @override
  String economyFinishDay7Chest(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '$minimumString से $maximumString कॉइन वाला चेस्ट पाने के लिए सातवाँ दिन पूरा करें';
  }

  @override
  String get economyFinishStreakWeek => 'स्ट्रीक के सात दिन पूरे करें।';

  @override
  String economyFirstDownloadsFree(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'पहले $countString मुफ़्त';
  }

  @override
  String get economyFirstUpload => 'पहला अपलोड';

  @override
  String get economyFreeDailySpin => 'मुफ़्त दैनिक स्पिन';

  @override
  String economyFreeDownloadsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString मुफ़्त डाउनलोड बाकी';
  }

  @override
  String get economyFreeSpin => 'मुफ़्त स्पिन';

  @override
  String economyFreeSpinReady(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '। आज $countString सशुल्क स्पिन बाकी।',
      one: '। आज $countString सशुल्क स्पिन बाकी।',
      zero: '',
    );
    return 'मुफ़्त स्पिन तैयार$_temp0';
  }

  @override
  String get economyFreezeAdded => 'स्ट्रीक फ़्रीज़ जोड़ दिया गया।';

  @override
  String economyFreezeAlreadyAtLimit(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़्रीज़',
      one: '$countString फ़्रीज़',
    );
    return 'आपके पास $_temp0 पहले से हैं।';
  }

  @override
  String economyFreezeBalanceAfter(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'इसके बाद बैलेंस: $balanceString';
  }

  @override
  String economyFreezeBuyConfirm(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '$costString कॉइन में स्ट्रीक फ़्रीज़ खरीदें?';
  }

  @override
  String get economyFreezeBuyFailed => 'फ़्रीज़ नहीं खरीदा जा सका। फिर कोशिश करें।';

  @override
  String economyFreezeCount(int held, int total) {
    final intl.NumberFormat heldNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String heldString = heldNumberFormat.format(held);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString में से $heldString';
  }

  @override
  String get economyFreezeDescription => 'एक दिन छूटने पर आपकी स्ट्रीक बचाता है। यह अपने-आप लागू होता है।';

  @override
  String get economyFreezeFull => 'पूरा';

  @override
  String economyFreezeGetOne(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'एक लें · $costString';
  }

  @override
  String get economyFreezeHeld => 'फ़्रीज़ आपके पास है';

  @override
  String economyFreezeNeedCoins(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'आपको $costString कॉइन चाहिए।';
  }

  @override
  String get economyFreezeSlotEmpty => 'फ़्रीज़ स्लॉट खाली है';

  @override
  String get economyFreezeUnavailable => 'अभी स्ट्रीक फ़्रीज़ उपलब्ध नहीं है। बाद में फिर कोशिश करें।';

  @override
  String get economyFreshLeaderboardDetails =>
      'लीडरबोर्ड साप्ताहिक XP पर आधारित है, जो हर सोमवार 00:00 UTC पर रीसेट होता है। आपका कुल XP, रैंक और कमाए गए कॉस्मेटिक्स बने रहते हैं।';

  @override
  String get economyFreshLeaderboardWeekly => 'हर हफ़्ते नया लीडरबोर्ड';

  @override
  String get economyGetCoins => 'कॉइन पाएँ';

  @override
  String economyGetCoinsChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'कॉइन पाएँ। चेस्ट की कीमत $priceString कॉइन है';
  }

  @override
  String economyGetCoinsForSpin(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'कॉइन पाएँ। एक स्पिन की कीमत $priceString कॉइन है';
  }

  @override
  String get economyGetFreezeNextTime => 'अगली बार के लिए फ़्रीज़ पाएँ';

  @override
  String get economyGetPro => 'Pro लें';

  @override
  String get economyGiftPass => 'पास उपहार में दें';

  @override
  String economyGiftPassInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'दोस्त को $amountString कॉइन में 24 घंटे के लिए Pro कंटेंट दें। उनकी प्रोफ़ाइल खोलें और 24 घंटे का पास दें पर टैप करें।';
  }

  @override
  String get economyGotIt => 'समझ गया';

  @override
  String economyHighestRankReached(String rank) {
    return 'आपकी सर्वोच्च रैंक: $rank';
  }

  @override
  String get economyHighestRankReachedShort => 'सर्वोच्च रैंक हासिल';

  @override
  String get economyHomeScreen => 'होम स्क्रीन';

  @override
  String get economyInviteFriend => 'दोस्त को आमंत्रित करें';

  @override
  String get economyJackpotAddedToBalance => 'जैकपॉट! आपके बैलेंस में जोड़ दिया गया';

  @override
  String get economyKeepStreakToday => 'अपनी स्ट्रीक बनाए रखने के लिए आज Prism खोलें।';

  @override
  String get economyLastWeek => 'पिछला हफ़्ता';

  @override
  String economyLeaderboardEntrySemantics(int position, String name, String isMe, int xp, String hasRank, String rank) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(isMe, {'true': ', आप', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(hasRank, {'true': ', कुल $rank रैंक', 'other': ''});
    return '$positionString, $name$_temp0, इस हफ़्ते $xpString XP$_temp1';
  }

  @override
  String get economyLeaderboardFollowTip =>
      'आपका स्कोर शामिल है। साप्ताहिक XP की तुलना करने के लिए क्रिएटर्स को फ़ॉलो करें।';

  @override
  String get economyLeaderboardFollowToSee => 'उन्हें यहाँ देखने के लिए क्रिएटर्स को फ़ॉलो करें।';

  @override
  String get economyLeaderboardFollowing => 'फ़ॉलो कर रहे हैं';

  @override
  String get economyLeaderboardFriendsCaption => 'आप और वे लोग जिन्हें आप फ़ॉलो करते हैं · रीफ़्रेश करने के लिए खींचें';

  @override
  String get economyLeaderboardFriendsDetails =>
      'इसमें आपका स्कोर और आपके फ़ॉलो किए गए अधिकतम शुरुआती 90 खाते शामिल हैं। हटाए गए खाते शामिल नहीं हैं; खाते की न्यूनतम उम्र की कोई शर्त नहीं है। इस टैब को पहली बार खोलने पर स्कोर लोड होते हैं। रीफ़्रेश करने के लिए खींचें। आपका स्कोर आपके हाल ही में सिंक किए गए XP पर आधारित है।';

  @override
  String get economyLeaderboardGlobal => 'वैश्विक';

  @override
  String get economyLeaderboardGlobalCaption => 'शीर्ष 50 · लगभग हर 3 घंटे में अपडेट';

  @override
  String get economyLeaderboardGlobalDetails =>
      'साप्ताहिक XP के आधार पर अधिकतम 50 खाते दिखाता है। खाते कम-से-कम 7 दिन पुराने होने चाहिए; हटाए गए खाते शामिल नहीं हैं। स्नैपशॉट लगभग हर 3 घंटे में अपडेट होता है, इसलिए नया XP दिखने में समय लग सकता है। रीफ़्रेश करने के लिए खींचें और नवीनतम स्नैपशॉट लोड करें।';

  @override
  String get economyLeaderboardHowScoringWorks => 'लीडरबोर्ड स्कोरिंग कैसे काम करती है';

  @override
  String get economyLeaderboardLoadFailed => 'लीडरबोर्ड लोड नहीं हो सका';

  @override
  String get economyLeaderboardNoRankings => 'अभी कोई रैंकिंग नहीं';

  @override
  String get economyLeaderboardOffline => 'ऑफ़लाइन होने पर सेव किए गए स्कोर दिख सकते हैं।';

  @override
  String get economyLeaderboardRankedByXp => 'इस हफ़्ते कमाए गए XP के आधार पर रैंकिंग';

  @override
  String economyLeaderboardReset(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$daysString दिन', one: '$daysString दिन');
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString घंटे',
      one: '$hoursString घंटा',
    );
    return 'सोमवार 00:00 UTC पर रीसेट · $_temp0 $_temp1 बाकी';
  }

  @override
  String get economyLeaderboardScoringIntro =>
      'स्थान इस हफ़्ते कमाए गए XP के आधार पर तय होते हैं। रजत जैसे रैंक लेबल कुल XP पर आधारित हैं। साप्ताहिक XP सोमवार 00:00 UTC पर रीसेट होता है; कुल XP और रैंक बनी रहती है।';

  @override
  String get economyLeaderboardTitle => 'लीडरबोर्ड';

  @override
  String get economyLifetimePermanentDetails =>
      'कुल XP आपकी रैंक तय करता है और कभी रीसेट नहीं होता। रैंक के कॉस्मेटिक आइटम अपने-आप आपकी इन्वेंट्री में आते हैं, इनमें कोई कॉइन नहीं लगता और ये हमेशा आपके रहते हैं। दुकान में तय करें कि इन्हें कब इस्तेमाल करना है।';

  @override
  String get economyLifetimePermanentRewards => 'कुल प्रगति, स्थायी इनाम';

  @override
  String economyLifetimeXp(String xp) {
    return 'कुल $xp XP';
  }

  @override
  String get economyLifetimeXpNeverResets => 'कुल XP कभी रीसेट नहीं होता।';

  @override
  String get economyLoadingVideo => 'वीडियो लोड हो रहा है';

  @override
  String get economyLockScreen => 'लॉक स्क्रीन';

  @override
  String get economyMystery => 'रहस्यमय';

  @override
  String get economyMysteryCosmetic => 'रहस्यमय कॉस्मेटिक आइटम';

  @override
  String get economyNewBadge => 'नया बैज';

  @override
  String economyNewCosmetic(String kind, String name) {
    return 'नया $kind: $name';
  }

  @override
  String get economyNewUnknownCosmetic => 'नया कॉस्मेटिक आइटम';

  @override
  String get economyNextDropMonday => 'अगला Drop सोमवार को आएगा।';

  @override
  String economyNextReward(String reward) {
    return 'अगला इनाम: $reward';
  }

  @override
  String get economyNice => 'बढ़िया';

  @override
  String get economyNoDropNow => 'अभी कोई Drop नहीं';

  @override
  String get economyNoSpinsLeft => 'आज कोई स्पिन बाकी नहीं।';

  @override
  String get economyNotEnoughCoins => 'कॉइन कम हैं';

  @override
  String get economyNotNow => 'अभी नहीं';

  @override
  String economyOddsTierSemantics(String tier, String odds) {
    return '$tier, $odds';
  }

  @override
  String get economyOddsTitle => 'जीतने की संभावना';

  @override
  String get economyOnceADay => 'दिन में एक बार';

  @override
  String get economyOpen => 'खोलें';

  @override
  String economyOpenChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'चेस्ट खोलें, $priceString कॉइन';
  }

  @override
  String get economyOpenChestFree => 'चेस्ट खोलें, मुफ़्त';

  @override
  String get economyOpenChestLoading => 'चेस्ट खुल रहा है। लोड हो रहा है';

  @override
  String get economyOpenDaily => 'हर दिन Prism खोलें।';

  @override
  String economyOpenDailyPro(String multiplier) {
    return 'हर दिन Prism खोलें। Pro पर x$multiplier कमाएँ।';
  }

  @override
  String get economyOpenFree => 'मुफ़्त खोलें';

  @override
  String get economyOpenShop => 'दुकान खोलें';

  @override
  String get economyOpening => 'खुल रहा है';

  @override
  String get economyOwned => 'आपका है';

  @override
  String get economyPremiumCollection => 'Premium कलेक्शन';

  @override
  String economyPriceCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString कॉइन';
  }

  @override
  String economyPriceCoinsForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$hoursString घंटे के लिए $amountString कॉइन';
  }

  @override
  String economyPriceCoinsPerWall(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'हर वॉलपेपर के लिए $amountString';
  }

  @override
  String economyPriceCoinsPerWallSemantics(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'हर वॉलपेपर के लिए $amountString कॉइन';
  }

  @override
  String economyPriceCoinsWithNote(int amount, String note, String hasNote) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(hasNote, {'true': ', $note', 'other': ''});
    return '$amountString कॉइन$_temp0';
  }

  @override
  String economyPriceForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$hoursString घंटे के लिए $amountString';
  }

  @override
  String economyPriceFrom(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString से';
  }

  @override
  String economyPriceFromCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString कॉइन से';
  }

  @override
  String get economyPrizeWheel => 'इनाम का पहिया';

  @override
  String get economyPro => 'Pro';

  @override
  String get economyProDailyFreeSpin => 'Pro सदस्यों को हर दिन एक मुफ़्त स्पिन मिलता है';

  @override
  String get economyProDownloadsFilters => 'Pro के साथ डाउनलोड और फ़िल्टर मुफ़्त हैं।';

  @override
  String get economyProPrice => 'Pro की कीमत';

  @override
  String get economyProWallpaper => 'Pro वॉलपेपर';

  @override
  String get economyQuestBrowse10 => '10 वॉलपेपर देखें';

  @override
  String get economyQuestColourSearch => 'रंग के आधार पर खोजें';

  @override
  String economyQuestDoneMessage(int coins, int xp) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.pluralLogic(xp, locale: localeName, other: ' · +$xpString XP', zero: '');
    String _temp1 = intl.Intl.pluralLogic(xp, locale: localeName, other: ' · +$xpString XP', zero: '');
    String _temp2 = intl.Intl.pluralLogic(xp, locale: localeName, other: 'मिशन पूरा: +$xpString XP', zero: 'मिशन पूरा');
    String _temp3 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'मिशन पूरा: +$coinsString कॉइन$_temp0',
      one: 'मिशन पूरा: +$coinsString कॉइन$_temp1',
      zero: '$_temp2',
    );
    return '$_temp3';
  }

  @override
  String get economyQuestDownload2 => '2 वॉलपेपर डाउनलोड करें';

  @override
  String get economyQuestFav3 => '3 वॉलपेपर पसंदीदा में जोड़ें';

  @override
  String economyQuestNewIn(String time) {
    return '$time में नया';
  }

  @override
  String get economyQuestProSpin => 'अपना मुफ़्त स्पिन लें';

  @override
  String get economyQuestSetWall => 'वॉलपेपर सेट करें या सेव करें';

  @override
  String get economyQuestShareWall => 'वॉलपेपर शेयर करें';

  @override
  String economyQuestTileSemantics(
    String title,
    String isDone,
    int progress,
    int target,
    int coins,
    int xp,
    String hasCoins,
    String hasXp,
    String isWeekly,
    String endsIn,
    String hasEnds,
  ) {
    final intl.NumberFormat progressNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String progressString = progressNumberFormat.format(progress);
    final intl.NumberFormat targetNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(isDone, {'true': 'पूरा', 'other': '$targetString में से $progressString'});
    String _temp1 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString कॉइन',
      one: '$coinsString कॉइन',
    );
    String _temp2 = intl.Intl.selectLogic(hasCoins, {'true': '. इनाम: $_temp1', 'other': ''});
    String _temp3 = intl.Intl.selectLogic(hasXp, {'true': '. इनाम: $xpString XP', 'other': ''});
    String _temp4 = intl.Intl.selectLogic(hasEnds, {'true': ', $endsIn में समाप्त', 'other': ''});
    String _temp5 = intl.Intl.selectLogic(isWeekly, {'true': '. साप्ताहिक मिशन$_temp4', 'other': ''});
    return '$title, $_temp0$_temp2$_temp3$_temp5';
  }

  @override
  String get economyQuestTrending => 'देखें क्या ट्रेंड कर रहा है';

  @override
  String get economyQuestUnknown => 'कोई मिशन पूरा करें';

  @override
  String get economyQuestWatchAd => 'वीडियो देखें';

  @override
  String get economyQuestWeeklySet5 => '5 वॉलपेपर सेव करें या सेट करें';

  @override
  String get economyQuestWotd => 'आज का वॉलपेपर खोलें';

  @override
  String get economyRankBronze => 'कांस्य';

  @override
  String get economyRankGold => 'स्वर्ण';

  @override
  String get economyRankGrowsWithXp => 'कुल XP के साथ आपकी रैंक बढ़ती है।';

  @override
  String economyRankInfoSemantics(String rank) {
    return '$rank रैंक। XP और रैंक के इनाम कैसे काम करते हैं';
  }

  @override
  String get economyRankPrism => 'Prism';

  @override
  String economyRankProgressSemantics(String rank) {
    return '$rank रैंक की प्रगति';
  }

  @override
  String economyRankRewardAtRank(String rank, String xp) {
    return '$rank पर अपने-आप मिलेगा · $xp XP';
  }

  @override
  String economyRankRewardMilestone(String rank, String xp, String reward) {
    return '$rank · $xp XP\n$reward';
  }

  @override
  String get economyRankRewardSyncing => 'आपकी इन्वेंट्री में सिंक हो रहा है। यह हमेशा आपका रहेगा।';

  @override
  String get economyRankRewardsHelp => 'XP और रैंक के इनाम कैसे काम करते हैं';

  @override
  String get economyRankSilver => 'रजत';

  @override
  String economyRankTag(String rank) {
    return '$rank रैंक';
  }

  @override
  String get economyRankUnknown => 'रैंक';

  @override
  String economyReferralBothGet(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString कॉइन',
      one: '$coinsString कॉइन',
    );
    return 'आप दोनों को $_temp0 मिलेंगे';
  }

  @override
  String get economyRestore => 'बहाल करें';

  @override
  String economyRestoreStreak(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'अपनी $daysString-दिन की स्ट्रीक बहाल करें · $coinsString कॉइन';
  }

  @override
  String economyRewardEarned(String reward) {
    return '$reward हासिल किया';
  }

  @override
  String get economyRewardsTitle => 'इनाम';

  @override
  String get economySameActivitySameXp => 'एक ही गतिविधि से हमेशा उतना ही XP मिलता है';

  @override
  String get economySameActivityXpDetails =>
      'विज्ञापन, Pro स्पिन, Pro के दैनिक बोनस, रेफ़रल और रिफ़ंड से XP नहीं मिलता। Pro और कॉइन मल्टीप्लायर से XP नहीं बढ़ता। कॉइन के इनाम अलग रहते हैं।';

  @override
  String get economySeeAll => 'सभी देखें';

  @override
  String get economySeeBadges => 'बैज देखें';

  @override
  String get economySeeItInShop => 'इसे दुकान में देखें';

  @override
  String get economySeeOdds => 'जीतने की संभावना देखें';

  @override
  String get economySeePro => 'Pro देखें';

  @override
  String get economySeeRewards => 'इनाम देखें';

  @override
  String get economyShareWallpaper => 'वॉलपेपर शेयर करें';

  @override
  String get economyShopAlreadyOwned => 'यह पहले से आपका है';

  @override
  String get economyShopAurora => 'ऑरोरा';

  @override
  String economyShopBuyFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$priceString में खरीदें';
  }

  @override
  String get economyShopChangeIconFailed => 'आइकन बदला नहीं जा सका';

  @override
  String economyShopCoinsShort(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'आपको $countString और कॉइन चाहिए।';
  }

  @override
  String get economyShopCottonBlue => 'कॉटन ब्लू';

  @override
  String get economyShopDeepOcean => 'गहरा समंदर';

  @override
  String get economyShopDefaultIcon => 'डिफ़ॉल्ट';

  @override
  String get economyShopEarnXp => 'XP कमाएँ';

  @override
  String economyShopEarnedAtLifetimeXp(String rank) {
    return 'कुल XP से $rank रैंक पर हासिल किया।';
  }

  @override
  String get economyShopEmber => 'अंगारा';

  @override
  String get economyShopEquip => 'लगाएँ';

  @override
  String get economyShopEquipFailed => 'यह बदला नहीं जा सका। फिर कोशिश करें।';

  @override
  String economyShopEquipped(String name) {
    return '$name लगा दिया';
  }

  @override
  String get economyShopFounders => 'फ़ाउंडर्स';

  @override
  String get economyShopFrames => 'फ़्रेम';

  @override
  String get economyShopGlass => 'ग्लास';

  @override
  String get economyShopGlowPreviewName => 'चमक';

  @override
  String get economyShopGlows => 'चमक';

  @override
  String get economyShopGold => 'स्वर्ण';

  @override
  String economyShopIconEnabled(String name) {
    return '$name आइकन चालू है';
  }

  @override
  String get economyShopIcons => 'आइकन';

  @override
  String economyShopItemSemantics(String name, String status) {
    return '$name, $status';
  }

  @override
  String get economyShopJungle => 'जंगल';

  @override
  String get economyShopMono => 'मोनो';

  @override
  String get economyShopNeedMoreCoins => 'इसके लिए आपको और कॉइन चाहिए';

  @override
  String get economyShopNoir => 'नोयर';

  @override
  String get economyShopOcean => 'समंदर';

  @override
  String get economyShopOlive => 'ऑलिव';

  @override
  String get economyShopPepper => 'काली मिर्च';

  @override
  String get economyShopPrism => 'Prism';

  @override
  String get economyShopProOnly => 'यह आइटम सिर्फ़ Pro सदस्यों के लिए है';

  @override
  String get economyShopPurchaseFailed => 'यह खरीदा नहीं जा सका। फिर कोशिश करें।';

  @override
  String economyShopPurchased(String name) {
    return '$name अब आपका है';
  }

  @override
  String economyShopRankLocked(String rank) {
    return 'इसे अनलॉक करने के लिए $rank रैंक हासिल करें';
  }

  @override
  String get economyShopRankReachedSyncing => 'रैंक हासिल हुई। आपका इनाम सिंक हो रहा है।';

  @override
  String economyShopRankRewardSynced(String name) {
    return '$name रैंक का इनाम सिंक हो गया';
  }

  @override
  String economyShopReachRankToBuy(String rank) {
    return 'इसे खरीदने के लिए $rank रैंक हासिल करें।';
  }

  @override
  String get economyShopRing => 'रिंग';

  @override
  String get economyShopRose => 'गुलाब';

  @override
  String economyShopSaleUntil(String date) {
    return 'सीमित ऑफ़र। $date तक बिक्री पर।';
  }

  @override
  String get economyShopSky => 'आसमान';

  @override
  String get economyShopSoldOut => 'यह सीमित आइटम बिक चुका है';

  @override
  String get economyShopSteel => 'स्टील';

  @override
  String get economyShopSunset => 'सूर्यास्त';

  @override
  String get economyShopSyncReward => 'इनाम सिंक करें';

  @override
  String get economyShopThemes => 'थीम';

  @override
  String get economyShopTitle => 'दुकान';

  @override
  String get economyShopUnequip => 'हटाएँ';

  @override
  String economyShopUnequipped(String name) {
    return '$name हटा दिया';
  }

  @override
  String get economyShopUseIcon => 'आइकन इस्तेमाल करें';

  @override
  String get economyShopUseTheme => 'थीम इस्तेमाल करें';

  @override
  String get economyShopWearingNeedsPro => 'इसे पहनने के लिए Pro चाहिए।';

  @override
  String get economyShowMore => 'और दिखाएँ';

  @override
  String get economySignIn => 'साइन इन करें';

  @override
  String get economySoldOut => 'बिक चुका है';

  @override
  String get economySoon => 'जल्द';

  @override
  String economySpendItemSemantics(String label, String price) {
    return '$label, $price';
  }

  @override
  String get economySpin => 'स्पिन करें';

  @override
  String get economySpinAgain => 'फिर से स्पिन करें';

  @override
  String get economySpinAgainFree => 'फिर से स्पिन करें, मुफ़्त स्पिन';

  @override
  String economySpinAgainPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'फिर से स्पिन करें, $priceString कॉइन';
  }

  @override
  String economySpinCardCaption(int price, int maximum) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'हर स्पिन के लिए $priceString कॉइन। $maximumString कॉइन तक या कोई कॉस्मेटिक आइटम जीतें';
  }

  @override
  String economySpinCosts(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'एक स्पिन के लिए $priceString कॉइन लगते हैं';
  }

  @override
  String get economySpinFree => 'स्पिन करें, मुफ़्त स्पिन';

  @override
  String economySpinPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'स्पिन करें, $priceString कॉइन';
  }

  @override
  String get economySpinPriceChanged => 'कीमत बदल गई है। इसे जाँचें और फिर स्पिन करें।';

  @override
  String economySpinShortBalanceMessage(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'एक स्पिन के लिए $priceString कॉइन लगते हैं। आपके पास $balanceString हैं। और कमाने के लिए वीडियो देखें।';
  }

  @override
  String get economySpinTheWheel => 'पहिया घुमाएँ';

  @override
  String economySpinWheelCardSemantics(String caption) {
    return 'पहिया घुमाएँ। $caption';
  }

  @override
  String get economySpinning => 'स्पिन हो रहा है';

  @override
  String economySpinsLeftToday(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString स्पिन',
      one: '$countString स्पिन',
    );
    return 'आज $_temp0 बाकी';
  }

  @override
  String get economyStreak => 'स्ट्रीक';

  @override
  String economyStreakChestReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString दिन 7 का चेस्ट';
  }

  @override
  String get economyStreakCollection => 'स्ट्रीक कलेक्शन';

  @override
  String get economyStreakCollectionDescription => 'अपनी स्ट्रीक बनाए रखकर या कॉइन इस्तेमाल करके वॉलपेपर अनलॉक करें।';

  @override
  String economyStreakCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString दिन की स्ट्रीक',
      one: '$countString दिन की स्ट्रीक',
    );
    return '$_temp0';
  }

  @override
  String economyStreakCycleSemantics(int day, String showReward, int reward, String state) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(showReward, {'true': ', साथ में $rewardString कॉइन', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(state, {'done': ', पूरा', 'today': ', आज', 'other': ''});
    return 'दिन $dayString$_temp0$_temp1';
  }

  @override
  String economyStreakDailyReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'आज +$coinsString';
  }

  @override
  String economyStreakDayNumber(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'आपकी स्ट्रीक का दिन $dayString';
  }

  @override
  String get economyStreakFreeze => 'स्ट्रीक फ़्रीज़';

  @override
  String economyStreakFreezeSaved(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'फ़्रीज़ से आपकी $daysString-दिन की स्ट्रीक बच गई';
  }

  @override
  String economyStreakFreezesLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़्रीज़ बाकी',
      one: '$countString फ़्रीज़ बाकी',
    );
    return '$_temp0';
  }

  @override
  String economyStreakProReward(int coins, String multiplier) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString x$multiplier Pro';
  }

  @override
  String get economyStreakRescueCooldown => 'आप हर 30 दिन में एक स्ट्रीक बहाल कर सकते हैं।';

  @override
  String get economyStreakRescueExpired => 'इस स्ट्रीक को बहाल करने के 48 घंटे बीत चुके हैं।';

  @override
  String get economyStreakRescueFailed => 'आपकी स्ट्रीक बहाल नहीं हो सकी। फिर कोशिश करें।';

  @override
  String get economyStreakRescueUnavailable => 'अभी यह स्ट्रीक बहाल नहीं की जा सकती।';

  @override
  String get economyStreakReset => 'आपकी स्ट्रीक रीसेट हो गई';

  @override
  String economyStreakResetMessage(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'आपकी स्ट्रीक $daysString दिनों की थी। आज फिर शुरू करें, +$coinsString कॉइन पाएँ।';
  }

  @override
  String economyStreakRestoreShort(int balance, int cost) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'आपके पास $balanceString हैं। आपको $costString चाहिए।';
  }

  @override
  String get economyStreakRestored => 'आपकी स्ट्रीक वापस आ गई';

  @override
  String economyStreakRestoredCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'अब आपकी स्ट्रीक फिर से $countString दिनों की है।';
  }

  @override
  String get economyToday => 'आज';

  @override
  String get economyUnknownCosmetic => 'कॉस्मेटिक';

  @override
  String economyUntil(String date) {
    return '$date तक';
  }

  @override
  String economyUpToCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+$countString तक';
  }

  @override
  String get economyUpgradeToPro => 'Pro में अपग्रेड करें';

  @override
  String economyUseReward(String reward) {
    return '$reward इस्तेमाल करें';
  }

  @override
  String get economyUseYourCoins => 'अपने कॉइन इस्तेमाल करें';

  @override
  String get economyWatchAd => 'विज्ञापन देखें';

  @override
  String get economyWatchVideo => 'वीडियो देखें';

  @override
  String economyWatchVideoRewardAdsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString विज्ञापन',
      one: '$countString विज्ञापन',
    );
    return 'वीडियो देखें · आज $_temp0 बाकी';
  }

  @override
  String economyWatchVideoRewardCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'वीडियो देखें (+$coinsString)';
  }

  @override
  String get economyWeekComplete => 'हफ़्ता पूरा हुआ!';

  @override
  String get economyWeekly => 'साप्ताहिक';

  @override
  String get economyWeeklyDraw => 'साप्ताहिक ड्रॉ';

  @override
  String get economyWeeklyDrop => 'साप्ताहिक Drop';

  @override
  String economyWeeklyEndsIn(String time) {
    return 'साप्ताहिक · $time';
  }

  @override
  String get economyWeeklyXpFriendsEveryone => 'साप्ताहिक XP, दोस्त और सभी';

  @override
  String economyWonCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString कॉइन',
      one: '$coinsString कॉइन',
    );
    return 'आपने $_temp0 जीते';
  }

  @override
  String economyWonCosmetic(String kind, String name) {
    return 'आपने नया $kind जीता: $name';
  }

  @override
  String get economyWonUnknownCosmetic => 'आपने एक कॉस्मेटिक जीता';

  @override
  String economyWonXp(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'आपने $xpString XP जीते';
  }

  @override
  String economyXp(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString XP';
  }

  @override
  String economyXpActivityDetails(
    int dailyStreak,
    int streakWeek,
    int questChest,
    int upload,
    int profile,
    int dailyQuest,
    int weeklyQuest,
  ) {
    final intl.NumberFormat dailyStreakNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dailyStreakString = dailyStreakNumberFormat.format(dailyStreak);
    final intl.NumberFormat streakWeekNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String streakWeekString = streakWeekNumberFormat.format(streakWeek);
    final intl.NumberFormat questChestNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String questChestString = questChestNumberFormat.format(questChest);
    final intl.NumberFormat uploadNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String uploadString = uploadNumberFormat.format(upload);
    final intl.NumberFormat profileNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String profileString = profileNumberFormat.format(profile);
    final intl.NumberFormat dailyQuestNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dailyQuestString = dailyQuestNumberFormat.format(dailyQuest);
    final intl.NumberFormat weeklyQuestNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String weeklyQuestString = weeklyQuestNumberFormat.format(weeklyQuest);

    return 'रोज़ की स्ट्रीक से $dailyStreakString XP मिलते हैं, और सात दिनों का चक्र पूरा करने पर $streakWeekString XP अतिरिक्त मिलते हैं। क्वेस्ट चेस्ट से $questChestString XP मिलते हैं। आपका पहला मान्य अपलोड $uploadString XP देता है; प्रोफ़ाइल पूरी करने पर $profileString XP मिलते हैं। हर रोज़ की क्वेस्ट से $dailyQuestString XP और साप्ताहिक क्वेस्ट से $weeklyQuestString XP मिलते हैं। कुछ बैज और क्रिएटर उपलब्धियों से भी XP मिलते हैं।';
  }

  @override
  String economyXpAwarded(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '+$xpString XP';
  }

  @override
  String get economyXpRanksRewards => 'XP, रैंक और इनाम';

  @override
  String economyXpToRank(String xp, String rank) {
    return '$rank तक पहुँचने के लिए $xp XP';
  }

  @override
  String get economyXpUnit => 'XP';

  @override
  String get economyYesterday => 'कल';

  @override
  String economyYouHaveCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'आपके पास $countString कॉइन हैं';
  }

  @override
  String get economyYourXp => 'आपके XP';

  @override
  String get errorGeneric => 'कुछ गड़बड़ हुई। कृपया फिर कोशिश करें।';

  @override
  String get errorNetwork => 'अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get navigationBackOnline => 'फिर से ऑनलाइन';

  @override
  String get navigationNoInternetConnection => 'इंटरनेट कनेक्शन नहीं है';

  @override
  String get navigationScrollToTop => 'सबसे ऊपर जाएँ';

  @override
  String get notifActivateToCollapse => 'समेटने के लिए सक्रिय करें।';

  @override
  String get notifActivateToExpand => 'खोलने के लिए सक्रिय करें।';

  @override
  String get notifChannelDownloads => 'डाउनलोड';

  @override
  String get notifChannelDownloadsDescription => 'वॉलपेपर डाउनलोड की प्रगति के बारे में सूचनाएँ पाएँ।';

  @override
  String get notifChannelDraw => 'Prism ड्रॉ';

  @override
  String get notifChannelDrawDescription => 'ड्रॉ के नतीजे और इनाम।';

  @override
  String get notifChannelDrops => 'साप्ताहिक Drops';

  @override
  String get notifChannelDropsDescription => 'नया Drop उपलब्ध होने पर और उसके खत्म होने से पहले।';

  @override
  String get notifChannelFollowers => 'फ़ॉलोअर';

  @override
  String get notifChannelFollowersDescription => 'नए फ़ॉलोअर की सूचनाएँ पाएँ।';

  @override
  String get notifChannelGifts => 'उपहार';

  @override
  String get notifChannelGiftsDescription => 'किसी दोस्त ने आपको Pro पास भेजा।';

  @override
  String get notifChannelGroup => 'सूचनाएँ';

  @override
  String get notifChannelGroupDescription => 'Prism की सभी सूचनाएँ';

  @override
  String get notifChannelModeration => 'मॉडरेशन';

  @override
  String get notifChannelModerationDescription => 'Prism एडमिन के लिए रिपोर्ट और समीक्षा अनुरोध।';

  @override
  String get notifChannelPosts => 'पोस्ट';

  @override
  String get notifChannelPostsDescription => 'आप जिन कलाकारों को फ़ॉलो करते हैं, उनकी पोस्ट की सूचनाएँ पाएँ।';

  @override
  String get notifChannelRecommendations => 'सुझाव';

  @override
  String get notifChannelRecommendationsDescription => 'Prism की ओर से सुझावों की सूचनाएँ पाएँ।';

  @override
  String get notifChannelStreaks => 'स्ट्रीक रिमाइंडर';

  @override
  String get notifChannelStreaksDescription => 'लॉगिन स्ट्रीक बनाए रखने के लिए रात 8 बजे का रिमाइंडर।';

  @override
  String get notifChannelWotd => 'दिन की वॉलपेपर';

  @override
  String get notifChannelWotdDescription => 'हर दिन सुबह 9 बजे खास वॉलपेपर की सूचना।';

  @override
  String get notifClearDeviceMessage => 'इससे वे इस डिवाइस से हट जाएँगी।';

  @override
  String get notifClearInbox => 'इनबॉक्स खाली करें';

  @override
  String get notifClearInboxAction => 'इनबॉक्स खाली करें';

  @override
  String notifClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString सूचनाएँ हटाएँ?';
  }

  @override
  String get notifClearOneTitle => 'यह सूचना हटाएँ?';

  @override
  String get notifCollapsed => 'समेटा गया';

  @override
  String notifDownloadedTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString वॉलपेपर डाउनलोड हुए।',
      one: '$countString वॉलपेपर डाउनलोड हुआ।',
    );
    return '$_temp0';
  }

  @override
  String get notifDownloadingWallpaper => 'वॉलपेपर डाउनलोड हो रहा है';

  @override
  String get notifEmptyBody => 'नए फ़ॉलोअर, मंज़ूरियाँ और दिन की वॉलपेपर यहाँ दिखेंगे।';

  @override
  String get notifEmptyTitle => 'कोई सूचना नहीं';

  @override
  String get notifExpanded => 'खोला गया';

  @override
  String get notifGenericTitle => 'सूचना';

  @override
  String notifGroupAndMore(String message, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString और।',
      one: '$otherCountString और।',
    );
    return '$message और $_temp0';
  }

  @override
  String notifGroupApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'मंज़ूरियाँ', one: 'मंज़ूरी');
    return '$_temp0';
  }

  @override
  String notifGroupCountAction(int count, String label, String action) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString $label · $action';
  }

  @override
  String notifGroupCreatorSummary(String name, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString अन्य क्रिएटर',
      one: '$otherCountString अन्य क्रिएटर',
    );
    return '$name और $_temp0 की ओर से।';
  }

  @override
  String notifGroupDailyPicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'रोज़ की पसंद', one: 'रोज़ की पसंद');
    return '$_temp0';
  }

  @override
  String get notifGroupDayRows => 'हर पंक्ति अलग दिन दिखाती है; समय दाईं ओर हैं।';

  @override
  String notifGroupFollowerSummary(String name, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString अन्य लोगों',
      one: '$otherCountString अन्य व्यक्ति',
    );
    return '$name और $_temp0 ने आपको फ़ॉलो किया।';
  }

  @override
  String notifGroupFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'नए फ़ॉलोअर', one: 'नया फ़ॉलोअर');
    return '$_temp0';
  }

  @override
  String get notifGroupHide => 'छिपाएँ';

  @override
  String notifGroupNotifications(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'सूचनाएँ', one: 'सूचना');
    return '$_temp0';
  }

  @override
  String notifGroupNotificationsRemoved(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString सूचनाएँ हटाई गईं',
      one: '$countString सूचना हटाई गई',
    );
    return '$_temp0';
  }

  @override
  String notifGroupSameMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'एक ही संदेश $countString बार भेजा गया। कब भेजा गया, यह देखने के लिए समय की तुलना करें।';
  }

  @override
  String notifGroupSemantics(String title, String summary, String expandedState, String unreadStatus, String action) {
    return '$title। $summary। $expandedState। $unreadStatus $action';
  }

  @override
  String get notifGroupSeveralCreators => 'कई क्रिएटर। हर वॉलपेपर देखने के लिए खोलें।';

  @override
  String get notifGroupShowAll => 'सभी दिखाएँ';

  @override
  String notifGroupSummaryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इस समूह में $countString सूचनाएँ हैं।',
      one: 'इस समूह में $countString सूचना है।',
    );
    return '$_temp0';
  }

  @override
  String notifGroupWallLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'वॉलपेपर प्रकाशित हुए',
      one: 'वॉलपेपर प्रकाशित हुआ',
    );
    return '$_temp0';
  }

  @override
  String get notifHasUnread => 'बिना पढ़ी सूचना है।';

  @override
  String get notifInboxCleared => 'इनबॉक्स खाली किया गया';

  @override
  String get notifLoadErrorTitle => 'आपकी सूचनाएँ लोड नहीं हो सकीं';

  @override
  String get notifMarkAllRead => 'सभी को पढ़ा हुआ मानें';

  @override
  String get notifOfflineSaved => 'नई सूचनाएँ लोड नहीं हो सकीं। नीचे दिख रही सूचनाएँ इस डिवाइस पर सेव हैं।';

  @override
  String get notifOpenSettings => 'सेटिंग खोलें';

  @override
  String get notifPermissionOff => 'सूचनाएँ बंद हैं। पहले सिस्टम सेटिंग में इन्हें चालू करें।';

  @override
  String get notifPermissionOffForApp => 'Prism की सूचनाएँ बंद हैं।';

  @override
  String get notifPreferences => 'सूचना प्राथमिकताएँ';

  @override
  String get notifPushDrawWinnerBody => 'एक महीने का Pro और Prism फ़्रेम आपके हैं।';

  @override
  String get notifPushDrawWinnerTitle => 'आपने Prism ड्रॉ जीता';

  @override
  String notifPushDropLastCallBody(String dropTitle, int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString घंटों',
      one: '$hoursString घंटे',
    );
    return '$dropTitle $_temp0 में खत्म होगा। फिर ये वॉलपेपर एक महीने के लिए गायब हो जाएँगे।';
  }

  @override
  String get notifPushDropLastCallTitle => 'इस हफ़्ते के Drop का आख़िरी मौका';

  @override
  String notifPushDropLiveBody(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इस हफ़्ते के लिए सिर्फ़ $countString वॉलपेपर। जाने से पहले उनका प्रीव्यू देखें।',
      one: 'इस हफ़्ते के लिए सिर्फ़ $countString वॉलपेपर। जाने से पहले उसका प्रीव्यू देखें।',
    );
    return '$_temp0';
  }

  @override
  String get notifPushDropLiveTitle => 'नया Drop उपलब्ध है';

  @override
  String notifPushFollowDigestTitleOne(String artistName) {
    return '$artistName ने एक नया वॉलपेपर पोस्ट किया';
  }

  @override
  String notifPushFollowDigestTitleSolo(String artistName, int wallCount) {
    return '$artistName ने $wallCount नए वॉलपेपर पोस्ट किए';
  }

  @override
  String notifPushFollowDigestTitlePair(String artistName, String secondArtistName, int wallCount) {
    return '$artistName और $secondArtistName ने $wallCount नए वॉलपेपर पोस्ट किए';
  }

  @override
  String notifPushFollowDigestTitleGroup(String artistName, int otherCount, int wallCount) {
    return '$artistName और $otherCount अन्य ने $wallCount नए वॉलपेपर पोस्ट किए';
  }

  @override
  String get notifPushFollowDigestBodyUntitled => 'सभी देखने के लिए टैप करें।';

  @override
  String get notifPushGiftReceivedBody => 'Premium कलेक्शन और वॉलपेपर कल तक आपके लिए उपलब्ध हैं।';

  @override
  String notifPushGiftReceivedTitle(String senderName) {
    return '$senderName ने आपको 24 घंटे का Pro पास भेजा';
  }

  @override
  String notifPushNewContentReportBody(String contentType, String reason, String targetId) {
    return '$contentType · $reason · दस्तावेज़ $targetId';
  }

  @override
  String get notifPushNewContentReportTitle => 'नई कंटेंट रिपोर्ट';

  @override
  String notifPushNewFollowerBody(String followerName) {
    return '$followerName अब आपको फ़ॉलो करते हैं।';
  }

  @override
  String get notifPushNewFollowerTitle => 'आपका नया फ़ॉलोअर है! 🎉';

  @override
  String notifPushReportReviewBody(String contentType, String reason) {
    return '$contentType · $reason · 12 घंटे से अधिक समय से खुली है';
  }

  @override
  String get notifPushReportReviewTitle => 'रिपोर्ट समीक्षा के इंतज़ार में';

  @override
  String get notifPushStreakReminderBody => 'अपनी लॉगिन स्ट्रीक बनाए रखने के लिए अभी Prism खोलें 🔥';

  @override
  String get notifPushStreakReminderTitle => 'आपकी स्ट्रीक टूटने वाली है!';

  @override
  String notifPushWallApprovedAdminBody(String wallTitle, String artistName) {
    return '$artistName का \"$wallTitle\" अब लाइव है।';
  }

  @override
  String get notifPushWallApprovedAdminTitle => 'वॉलपेपर मंज़ूर ✅';

  @override
  String notifPushWallApprovedArtistBody(String wallTitle) {
    return '\"$wallTitle\" मंज़ूर हो गया है और अब सभी को दिख रहा है।';
  }

  @override
  String get notifPushWallApprovedArtistBodyUntitled => 'आपका वॉलपेपर मंज़ूर हो गया है और अब सभी को दिख रहा है।';

  @override
  String get notifPushWallApprovedArtistTitle => 'आपका वॉलपेपर लाइव है! 🎉';

  @override
  String notifPushWallLiveFollowersBody(String wallTitle) {
    return '\"$wallTitle\" अब Prism पर लाइव है।';
  }

  @override
  String notifPushWallLiveFollowersTitle(String artistName) {
    return '$artistName का नया वॉलपेपर';
  }

  @override
  String notifPushWallSubmittedBody(String artistName, String artistEmail) {
    return '$artistName ($artistEmail) की नई पोस्ट समीक्षा के लिए भेजी गई है।';
  }

  @override
  String get notifPushWallSubmittedTitle => 'समीक्षा के लिए नया Premium वॉलपेपर! 🎉';

  @override
  String get notifPushWinBack14Body => 'देखें कि क्रिएटर ने पिछले दो हफ़्तों में क्या जोड़ा है।';

  @override
  String get notifPushWinBack14Title => 'नए वॉलपेपर आपका इंतज़ार कर रहे हैं';

  @override
  String get notifPushWinBack30Body => 'ऐसा वॉलपेपर बनाएँ जो बिल्कुल आपके जैसा लगे।';

  @override
  String get notifPushWinBack30Title => 'आजमाने के लिए नई AI शैलियाँ';

  @override
  String get notifPushWinBack60Body => 'आपका अगला पसंदीदा वॉलपेपर बस एक टैप दूर है।';

  @override
  String get notifPushWinBack60Title => 'Prism को आपकी याद आ रही है';

  @override
  String get notifPushWinBack7Body => 'आपकी गैरमौजूदगी में नए वॉलपेपर आए हैं।';

  @override
  String get notifPushWinBack7Title => 'आपकी फ़ीड में नए वॉलपेपर हैं';

  @override
  String notifPushWotdAudienceBody(String wallTitle) {
    return '$wallTitle';
  }

  @override
  String get notifPushWotdAudienceBodyUntitled => 'आज का वॉलपेपर देखने के लिए Prism खोलें।';

  @override
  String get notifPushWotdAudienceTitle => 'आज का वॉलपेपर आ गया है';

  @override
  String get notifPushWotdCreatorBody => 'Prism ने आज सभी के लिए आपका वॉलपेपर चुना है। इसे साझा करने के लिए धन्यवाद।';

  @override
  String get notifPushWotdCreatorTitle => 'आपका वॉलपेपर आज का वॉलपेपर है';

  @override
  String get notifRead => 'पहले से पढ़ी गई';

  @override
  String get notifRemoved => 'सूचना हटाई गई';

  @override
  String get notifReportUnknownContentType => 'कंटेंट';

  @override
  String notifSemanticsRow(String message, String time, String readStatus) {
    return '$message। $time। $readStatus';
  }

  @override
  String get notifSettingDrops => 'साप्ताहिक Drops';

  @override
  String get notifSettingDropsDescription => 'नया Drop उपलब्ध होने पर और उसके खत्म होने से पहले अलर्ट पाएँ।';

  @override
  String get notifSettingFollowers => 'फ़ॉलोअर';

  @override
  String get notifSettingFollowersDescription => 'कोई नया व्यक्ति आपको फ़ॉलो करे, तो अलर्ट पाएँ।';

  @override
  String get notifSettingPosts => 'पोस्ट';

  @override
  String get notifSettingPostsDescription => 'आप जिन क्रिएटर को फ़ॉलो करते हैं, उनके नए काम साझा करने पर अलर्ट पाएँ।';

  @override
  String get notifSettingRecommendations => 'सुझाव';

  @override
  String get notifSettingRecommendationsDescription => 'Prism से सुझाव, खबरें और वॉलपेपर की पसंद।';

  @override
  String get notifSettingStreaks => 'स्ट्रीक रिमाइंडर';

  @override
  String get notifSettingStreaksDescription => 'लॉगिन स्ट्रीक टूटने वाली हो, तो रात 8 बजे के आसपास याद दिलाएँ।';

  @override
  String get notifSettingWotd => 'दिन की वॉलपेपर';

  @override
  String get notifSettingWotdDescription => 'हर दिन एक चुना हुआ वॉलपेपर।';

  @override
  String get notifSignInToChange => 'यह सेटिंग बदलने के लिए साइन इन करें।';

  @override
  String get notifSignInToTurnOn => 'चालू करने के लिए साइन इन करें';

  @override
  String get notifTapToOpenPrism => 'Prism खोलने के लिए टैप करें।';

  @override
  String get notifTitle => 'सूचनाएँ';

  @override
  String get notifToday => 'आज';

  @override
  String get notifUndo => 'पहले जैसा करें';

  @override
  String get notifUnread => 'अभी तक नहीं पढ़ी गई';

  @override
  String get notifYesterday => 'कल';

  @override
  String notifYesterdayAt(String time) {
    return 'कल, $time';
  }

  @override
  String get onboardingAiGenerateError => 'कुछ गड़बड़ हुई।\nफिर कोशिश करने के लिए जनरेट करें पर टैप करें।';

  @override
  String get onboardingAiGeneratePrompt => 'अपना अनोखा वॉलपेपर बनाने के लिए\nजनरेट करें पर टैप करें';

  @override
  String get onboardingAiGenerating => 'आपका वॉलपेपर बनाया जा रहा है…';

  @override
  String get onboardingBrowseGuest => 'बिना अकाउंट के ब्राउज़ करें';

  @override
  String get onboardingCategoriesUnavailable => 'कैटेगरी लोड नहीं हो सकीं, आप यह चरण छोड़ सकते हैं';

  @override
  String get onboardingContinue => 'जारी रखें';

  @override
  String get onboardingContinueApple => 'Apple के साथ जारी रखें';

  @override
  String get onboardingContinueGoogle => 'Google के साथ जारी रखें';

  @override
  String onboardingContinueSelected(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'जारी रखें ($countString चुने गए)';
  }

  @override
  String get onboardingCouldNotLogOut => 'लॉग आउट नहीं हो सका। कृपया फिर कोशिश करें।';

  @override
  String get onboardingCreatorsUnavailable => 'क्रिएटर लोड नहीं हो सके, आप यह चरण छोड़ सकते हैं';

  @override
  String get onboardingFirstAiWallpaper => 'AI से बनाया गया आपका पहला वॉलपेपर';

  @override
  String get onboardingFirstWallpaperSaveFailed => 'आपका वॉलपेपर सेव नहीं हो सका। फिर कोशिश करें या छोड़ दें।';

  @override
  String get onboardingFirstWallpaperSavedPhotos => 'फ़ोटो में सेव हो गया!';

  @override
  String get onboardingFirstWallpaperSet => 'वॉलपेपर सेट हो गया!';

  @override
  String get onboardingFirstWallpaperSetFailed => 'वॉलपेपर सेट नहीं हो सका। फिर कोशिश करें या छोड़ दें।';

  @override
  String get onboardingFirstWallpaperSetHome => 'होम स्क्रीन पर वॉलपेपर सेट हो गया।';

  @override
  String get onboardingFirstWallpaperSetHomeLock => 'होम और लॉक स्क्रीन पर वॉलपेपर सेट हो गया।';

  @override
  String get onboardingFirstWallpaperSetLock => 'लॉक स्क्रीन पर वॉलपेपर सेट हो गया।';

  @override
  String get onboardingFollow => 'फ़ॉलो करें';

  @override
  String onboardingFollowCreatorMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'हम आपको इन $countString क्रिएटर को फ़ॉलो करने का सुझाव दे रहे हैं';
  }

  @override
  String onboardingFollowerCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ॉलोअर',
      one: '$countString फ़ॉलोअर',
    );
    return '$_temp0';
  }

  @override
  String get onboardingFollowing => 'फ़ॉलो कर रहे हैं';

  @override
  String get onboardingGenerateFailure => 'कुछ गड़बड़ हुई — फिर कोशिश करने के लिए जनरेट करें पर टैप करें';

  @override
  String get onboardingGenerateSuccess => 'अच्छा लग रहा है! आपका वॉलपेपर खोल रहे हैं';

  @override
  String get onboardingGenerateWallpaper => 'मेरा वॉलपेपर जनरेट करें';

  @override
  String get onboardingHeadlineCreators => 'अपने जैसे लोगों को खोजें';

  @override
  String get onboardingHeadlineCustomize => 'इसे अपना बनाएँ';

  @override
  String get onboardingHeadlineGenerate => 'अपना\nपहला वॉलपेपर बनाएँ';

  @override
  String get onboardingHeadlineInterests => 'अपना अंदाज़ चुनें';

  @override
  String get onboardingLoadCategoriesFailed => 'कैटेगरी लोड नहीं हो सकीं।';

  @override
  String get onboardingLoadCreatorsFailed => 'क्रिएटर लोड नहीं हो सके।';

  @override
  String get onboardingPro => 'Pro';

  @override
  String get onboardingProFree => '  →  आपके लिए मुफ़्त';

  @override
  String get onboardingRecoveryCreatorsFailed =>
      'क्रिएटर लोड नहीं हो सके। अपना कनेक्शन जाँचें और फिर से लोड करें पर टैप करें।';

  @override
  String get onboardingRecoveryFollowFailed => 'इन क्रिएटर को फ़ॉलो नहीं किया जा सका। फिर कोशिश करें।';

  @override
  String get onboardingRecoveryFollowFailedHelper =>
      'इन क्रिएटर को फ़ॉलो नहीं किया जा सका। अपना कनेक्शन जाँचें और फिर कोशिश करें';

  @override
  String get onboardingRecoveryReload => 'फिर से लोड करें';

  @override
  String get onboardingRecoveryRetry => 'फिर कोशिश करें';

  @override
  String get onboardingRecoverySaveInterestsFailed => 'आपकी पसंद सेव नहीं हो सकी। फिर कोशिश करें।';

  @override
  String get onboardingRecoverySaveInterestsFailedHelper =>
      'आपकी पसंद सेव नहीं हो सकी। अपना कनेक्शन जाँचें और फिर कोशिश करें';

  @override
  String get onboardingRecoverySessionExpired => 'आपका सेशन समाप्त हो गया है। कृपया फिर से साइन इन करें।';

  @override
  String get onboardingRecoverySessionExpiredHelper =>
      'आपका सेशन समाप्त हो गया है। जारी रखने के लिए फिर से साइन इन करें';

  @override
  String get onboardingRecoverySetupFailed => 'सेटअप पूरा नहीं हो सका। फिर कोशिश करें।';

  @override
  String get onboardingRecoverySetupFailedHelper => 'सेटअप पूरा नहीं हो सका। अपना कनेक्शन जाँचें और फिर कोशिश करें';

  @override
  String get onboardingRecoverySignIn => 'फिर से साइन इन करें';

  @override
  String get onboardingReloadLower => 'फिर से लोड करें';

  @override
  String get onboardingSavePhotos => 'फ़ोटो में सेव करें';

  @override
  String onboardingSelectInterestMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'अपनी फ़ीड को आपके मुताबिक बनाने के लिए कम-से-कम $countString कैटेगरी चुनें';
  }

  @override
  String get onboardingSetWallpaper => 'वॉलपेपर के रूप में सेट करें';

  @override
  String get onboardingSignInAgainLower => 'फिर से साइन इन करें';

  @override
  String get onboardingSkip => 'छोड़ें';

  @override
  String get onboardingSkipLower => 'छोड़ें';

  @override
  String get onboardingTermsRequired => 'कृपया पहले नियमों और गोपनीयता नीति से सहमत हों।';

  @override
  String get onboardingTryAgainLower => 'फिर कोशिश करें';

  @override
  String onboardingWallpaperForInterest(String category) {
    return 'आपकी $category में रुचि के आधार पर हमने यह वॉलपेपर चुना है';
  }

  @override
  String get onboardingWallpaperJustForYou => 'हमने यह वॉलपेपर सिर्फ़ आपके लिए चुना है';

  @override
  String get onboardingWelcomeDescription => 'शीर्ष कलाकारों के लाखों Premium वॉलपेपर।';

  @override
  String get onboardingWelcomeHeadline => 'आपकी स्क्रीन, नए अंदाज़ में।';

  @override
  String get premiumPageExplorePlans => 'Prism Premium प्लान देखें।';

  @override
  String get premiumPagePlansUnavailable => 'अभी प्लान उपलब्ध नहीं हैं। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get premiumPageTitle => 'Prism Premium';

  @override
  String get premiumPageTryAgain => 'फिर कोशिश करें';

  @override
  String get premiumPageViewPlans => 'प्लान देखें';

  @override
  String get premiumGuestStorePurchaseActive =>
      'स्टोर से की गई आपकी खरीद इस डिवाइस पर सक्रिय है। खाते से जुड़ी Pro सुविधाओं का उपयोग करने के लिए साइन इन करें।';

  @override
  String get premiumPurchasePending => 'आपकी खरीद दर्ज हो गई है। Pro अनलॉक होने में एक मिनट लग सकता है।';

  @override
  String get premiumPurchaseUnconfirmed =>
      'आपकी खरीद की पुष्टि नहीं हो सकी। सेटिंग्स में ‘खरीदारियाँ वापस पाएँ’ आज़माएँ।';

  @override
  String get updatesRestartToFinish => 'अपडेट पूरा करने के लिए Prism बंद करके फिर से खोलें।';

  @override
  String get updatesStoreUpdateAvailable => 'Prism का नया संस्करण उपलब्ध है।';

  @override
  String get wallpaperAccentColor => 'ऐक्सेंट रंग';

  @override
  String get wallpaperAccentColorsOriginal => 'वॉलपेपर के मूल रंग';

  @override
  String get wallpaperResetOriginal => 'मूल पर रीसेट करें';

  @override
  String get wallpaperAccentResetHint => 'मूल पर रीसेट सहित कार्रवाइयों के लिए दबाकर रखें';

  @override
  String get wallpaperAll => 'सभी';

  @override
  String get wallpaperApplyTo => 'यहाँ लागू करें';

  @override
  String get wallpaperAutoRotateAndroidOnly => 'ऑटो-रोटेशन केवल Android पर उपलब्ध है।';

  @override
  String get wallpaperAutoRotateApplyTo => 'यहाँ लागू करें';

  @override
  String get wallpaperAutoRotateBatterySteps =>
      'सेटिंग्स खोलें, फिर ऐप्स > Prism > बैटरी पर जाएँ। बैटरी उपयोग पर प्रतिबंध न लगाएँ।';

  @override
  String get wallpaperAutoRotateBatteryTip =>
      'अगर वॉलपेपर बदलना बंद हो जाएँ, तो Prism के बैटरी उपयोग पर प्रतिबंध न लगाएँ। सेटिंग्स खोलें, फिर ऐप्स > Prism > बैटरी पर जाएँ।';

  @override
  String get wallpaperAutoRotateBothScreens => 'दोनों';

  @override
  String get wallpaperAutoRotateChangeError => 'वॉलपेपर नहीं बदल सका।';

  @override
  String get wallpaperAutoRotateChangeLabel => 'बदलें';

  @override
  String get wallpaperAutoRotateChargingDescription => 'चार्जर से जुड़े होने पर बदलें, हर अंतराल में अधिकतम एक बार';

  @override
  String get wallpaperAutoRotateChargingOnly => 'केवल चार्ज होते समय';

  @override
  String get wallpaperAutoRotateCopySteps => 'निर्देश कॉपी करें';

  @override
  String get wallpaperAutoRotateCouldNotStart => 'शुरू नहीं हो सका। फिर कोशिश करें।';

  @override
  String wallpaperAutoRotateDownloadedCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: 'वॉलपेपर', one: 'वॉलपेपर');
    return '$totalString में से $cachedString डाउनलोड हुए $_temp0';
  }

  @override
  String wallpaperAutoRotateEnabledUntil(String date) {
    return 'पास $date तक सक्रिय है';
  }

  @override
  String get wallpaperAutoRotateGotIt => 'समझ गया';

  @override
  String get wallpaperAutoRotateHomeScreen => 'होम स्क्रीन';

  @override
  String get wallpaperAutoRotateInterval12Hours => 'हर 12 घंटे';

  @override
  String get wallpaperAutoRotateInterval15 => 'हर 15 मिनट (बैटरी पर अधिक असर)';

  @override
  String get wallpaperAutoRotateInterval30 => 'हर 30 मिनट';

  @override
  String get wallpaperAutoRotateInterval3Days => 'हर 3 दिन';

  @override
  String get wallpaperAutoRotateInterval3Hours => 'हर 3 घंटे';

  @override
  String get wallpaperAutoRotateInterval6Hours => 'हर 6 घंटे';

  @override
  String get wallpaperAutoRotateIntervalDay => 'हर दिन';

  @override
  String get wallpaperAutoRotateIntervalHour => 'हर घंटे';

  @override
  String get wallpaperAutoRotateIntervalWeek => 'हर हफ़्ते';

  @override
  String get wallpaperAutoRotateKeepRunning => 'इसे चालू रखें';

  @override
  String get wallpaperAutoRotateLoadError => 'ऑटो-रोटेशन सेटिंग्स लोड नहीं हो सकीं।';

  @override
  String get wallpaperAutoRotateLoadingWalls => 'वॉलपेपर लोड हो रहे हैं';

  @override
  String get wallpaperAutoRotateLockScreen => 'लॉक स्क्रीन';

  @override
  String wallpaperAutoRotateMix(int count, String source) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString वॉलपेपर',
      one: '$countString वॉलपेपर',
    );
    return 'मिक्स में $source के $_temp0';
  }

  @override
  String wallpaperAutoRotateMixCapped(int count, String source) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString वॉलपेपर',
      one: '$countString वॉलपेपर',
    );
    return 'मिक्स में $source के $_temp0। पहले 100 इस्तेमाल होंगे।';
  }

  @override
  String wallpaperAutoRotateNextChange(String time) {
    return 'अगला बदलाव लगभग $time पर';
  }

  @override
  String wallpaperAutoRotateNounCategory(String category) {
    return '$category';
  }

  @override
  String get wallpaperAutoRotateNounDownloads => 'डाउनलोड';

  @override
  String get wallpaperAutoRotateNounFavourites => 'पसंदीदा';

  @override
  String get wallpaperAutoRotateNounHistory => 'आपका इतिहास';

  @override
  String get wallpaperAutoRotateNounWotd => 'आज के वॉलपेपर की पसंद';

  @override
  String get wallpaperAutoRotateOff => 'बंद';

  @override
  String get wallpaperAutoRotateOffEnded => 'आपका Prism Pro प्लान या पास खत्म होने के कारण ऑटो-रोटेशन बंद है।';

  @override
  String get wallpaperAutoRotateOpenDownloads => 'डाउनलोड खोलें';

  @override
  String get wallpaperAutoRotateOpenFavourites => 'पसंदीदा खोलें';

  @override
  String get wallpaperAutoRotatePassEnabled => 'ऑटो-रोटेशन 7 दिनों के लिए चालू है।';

  @override
  String wallpaperAutoRotatePassPurchase(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '7-दिन का पास · $coinsString Prism Coins';
  }

  @override
  String get wallpaperAutoRotatePickCategory => 'श्रेणी चुनें';

  @override
  String wallpaperAutoRotatePreparing(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString वॉलपेपर',
      one: '$countString वॉलपेपर',
    );
    return 'तैयारी हो रही है: $_temp0';
  }

  @override
  String get wallpaperAutoRotateProBody => 'Prism Coins से इसे 7 दिनों के लिए आज़माएँ, या Prism Pro लें।';

  @override
  String get wallpaperAutoRotateProTitle => 'ऑटो-रोटेशन Prism Pro की सुविधा है।';

  @override
  String wallpaperAutoRotateReadyCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: 'वॉलपेपर तैयार', one: 'वॉलपेपर तैयार');
    return '$totalString में से $cachedString $_temp0';
  }

  @override
  String get wallpaperAutoRotateScheduled => 'शेड्यूल किया गया';

  @override
  String get wallpaperAutoRotateShuffle => 'यादृच्छिक क्रम';

  @override
  String get wallpaperAutoRotateShuffleDescription => 'एक के बाद एक के बजाय बेतरतीब क्रम';

  @override
  String get wallpaperAutoRotateSourceCategory => 'श्रेणी';

  @override
  String get wallpaperAutoRotateSourceDownloads => 'डाउनलोड';

  @override
  String get wallpaperAutoRotateSourceFavourites => 'पसंदीदा';

  @override
  String get wallpaperAutoRotateSourceHistory => 'इतिहास';

  @override
  String get wallpaperAutoRotateSourceLabel => 'स्रोत';

  @override
  String get wallpaperAutoRotateSourceLoadError => 'वॉलपेपर लोड नहीं हो सके। अपना कनेक्शन जाँचें।';

  @override
  String get wallpaperAutoRotateSourceWotd => 'आज का वॉलपेपर';

  @override
  String get wallpaperAutoRotateStartError => 'वॉलपेपर रोटेशन शुरू नहीं हो सका।';

  @override
  String get wallpaperAutoRotateStarting => 'शुरू हो रहा है';

  @override
  String get wallpaperAutoRotateStatusLabel => 'स्थिति';

  @override
  String get wallpaperAutoRotateStepsCopied => 'निर्देश कॉपी हो गए।';

  @override
  String get wallpaperAutoRotateStopError => 'वॉलपेपर रोटेशन बंद नहीं हो सका।';

  @override
  String get wallpaperAutoRotateTitle => 'ऑटो-रोटेशन';

  @override
  String get wallpaperAutoRotateTooFewCategory => 'इस श्रेणी में 2 से कम वॉलपेपर हैं। दूसरी श्रेणी चुनें।';

  @override
  String get wallpaperAutoRotateTooFewDownloads => 'रोटेशन के लिए कम से कम 2 वॉलपेपर डाउनलोड करें।';

  @override
  String get wallpaperAutoRotateTooFewFavourites => 'रोटेशन के लिए कम से कम 2 वॉलपेपर पसंदीदा में जोड़ें।';

  @override
  String get wallpaperAutoRotateTooFewHistory => 'रोटेशन के लिए Prism से कम से कम 2 वॉलपेपर सेट करें।';

  @override
  String get wallpaperAutoRotateTooFewWotd => 'अभी तक पिछली पसंद पर्याप्त नहीं हैं।';

  @override
  String get wallpaperAutoRotateUnlockError => 'ऑटो-रोटेशन अनलॉक नहीं हो सका। फिर कोशिश करें।';

  @override
  String get wallpaperAutoRotateUpdateError => 'ऑटो-रोटेशन अपडेट नहीं हो सका।';

  @override
  String get wallpaperBack => 'वापस';

  @override
  String get wallpaperBlockCreator => 'क्रिएटर को ब्लॉक करें';

  @override
  String get wallpaperBlockCreatorNotFound => 'यह क्रिएटर नहीं मिला। फिर कोशिश करें।';

  @override
  String get wallpaperBoostAlready => 'पहले से बूस्ट किया गया है।';

  @override
  String wallpaperBoostAlreadyUntil(String time) {
    return 'पहले से $time तक बूस्ट किया गया है।';
  }

  @override
  String wallpaperBoostConfirmButton(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString Prism Coins में बूस्ट करें';
  }

  @override
  String wallpaperBoostConfirmMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'इस वॉलपेपर को 24 घंटे के लिए होम कैरोसेल और ट्रेंडिंग में सबसे ऊपर दिखाएँ। कीमत: $coinsString Prism Coins।';
  }

  @override
  String wallpaperBoostDurationAndCost(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '24 घंटे तक सबसे ऊपर · $coinsString Prism Coins';
  }

  @override
  String get wallpaperBoostFailed => 'यह वॉलपेपर बूस्ट नहीं हो सका। फिर कोशिश करें।';

  @override
  String get wallpaperBoostOnlyApproved => 'केवल आपके अपलोड किए और मंज़ूर हुए वॉलपेपर बूस्ट किए जा सकते हैं।';

  @override
  String get wallpaperBoostSlotsTaken => 'सभी बूस्ट स्लॉट भरे हैं। बाद में फिर कोशिश करें।';

  @override
  String wallpaperBoostSlotsTakenUntil(String time) {
    return 'सभी बूस्ट स्लॉट भरे हैं। अगला स्लॉट $time पर खाली होगा।';
  }

  @override
  String get wallpaperBoostTitle => 'ट्रेंडिंग में बूस्ट करें';

  @override
  String get wallpaperBoostedSuccess => 'बूस्ट हो गया। यह होम और ट्रेंडिंग में दिख रहा है।';

  @override
  String get wallpaperBoostedTag => 'बूस्ट किया गया';

  @override
  String wallpaperBoostedUntil(String time) {
    return '$time तक बूस्ट किया गया';
  }

  @override
  String get wallpaperBrowseWallpapers => 'वॉलपेपर ब्राउज़ करें';

  @override
  String wallpaperByCreator(String name) {
    return '$name का वॉलपेपर';
  }

  @override
  String get wallpaperByPrismCreator => 'Prism क्रिएटर का वॉलपेपर';

  @override
  String get wallpaperCategories => 'श्रेणियाँ';

  @override
  String get wallpaperCategory => 'श्रेणी';

  @override
  String get wallpaperCategoryFeedEmptyBody => 'नए वॉलपेपर अक्सर आते हैं। थोड़ी देर बाद फिर देखें।';

  @override
  String get wallpaperCategoryFeedEmptyTitle => 'यहाँ अभी कोई वॉलपेपर नहीं है';

  @override
  String wallpaperCategoryNamed(String name) {
    return 'श्रेणी, $name';
  }

  @override
  String get wallpaperChangeNow => 'अभी बदलें';

  @override
  String get wallpaperCheckBackSoon => 'थोड़ी देर बाद फिर देखें।';

  @override
  String get wallpaperCheckBackTomorrow => 'कल फिर देखें।';

  @override
  String get wallpaperCheckConnection => 'अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get wallpaperClear => 'साफ़ करें';

  @override
  String get wallpaperClearFilters => 'फ़िल्टर हटाएँ';

  @override
  String get wallpaperClearHistoryAction => 'इतिहास साफ़ करें';

  @override
  String get wallpaperClearHistoryBody => 'इससे आपके सेट किए वॉलपेपरों की सूची हट जाएगी। वॉलपेपर वैसे ही रहेंगे।';

  @override
  String get wallpaperClearHistoryTitle => 'इतिहास साफ़ करें?';

  @override
  String get wallpaperClearSearch => 'खोज मिटाएँ';

  @override
  String get wallpaperClosePreview => 'पूर्वावलोकन बंद करें';

  @override
  String get wallpaperCollapseDetails => 'वॉलपेपर की जानकारी समेटें';

  @override
  String get wallpaperCollection => 'कलेक्शन';

  @override
  String get wallpaperCollectionLoadError => 'यह कलेक्शन लोड नहीं हो सका';

  @override
  String wallpaperCollectionNamed(String name) {
    return 'कलेक्शन, $name';
  }

  @override
  String wallpaperCollectionPreviewUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '24 घंटे का पूर्वावलोकन अनलॉक हुआ (-$coinsString Prism Coins)।';
  }

  @override
  String get wallpaperCollectionRefreshError => 'रीफ़्रेश नहीं हो सका। फिर कोशिश करने के लिए नीचे खींचें।';

  @override
  String get wallpaperCollectionsEmptyBody => 'रीफ़्रेश करने के लिए नीचे खींचें, या थोड़ी देर बाद फिर देखें।';

  @override
  String get wallpaperCollectionsEmptyTitle => 'अभी कोई कलेक्शन नहीं है';

  @override
  String get wallpaperCopyAccentHexHint => 'हेक्स रंग कॉपी करने के लिए देर तक दबाएँ';

  @override
  String wallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString वॉलपेपर',
      one: '1 वॉलपेपर',
      zero: 'कोई वॉलपेपर नहीं',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDelete => 'हटाएँ';

  @override
  String get wallpaperDeleteManyDownloadsBody =>
      'ये इस डिवाइस से हट जाएँगे। आप इन्हें बाद में फिर डाउनलोड कर सकते हैं।';

  @override
  String wallpaperDeleteManyDownloadsTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString डाउनलोड हटाएँ?';
  }

  @override
  String get wallpaperDeleteOneDownloadBody => 'यह इस डिवाइस से हट जाएगा। आप इसे बाद में फिर डाउनलोड कर सकते हैं।';

  @override
  String get wallpaperDeleteOneDownloadTitle => 'यह डाउनलोड हटाएँ?';

  @override
  String get wallpaperDepthEditorSubtitle => 'लॉक स्क्रीन एडिटर में ••• पर टैप करें, फिर डेप्थ इफ़ेक्ट चुनें।';

  @override
  String get wallpaperDepthEffect => 'डेप्थ इफ़ेक्ट';

  @override
  String get wallpaperDepthSubjectSubtitle => 'आपका विषय घड़ी के सामने दिखाई देता है।';

  @override
  String get wallpaperSpatialScene => 'स्पेशियल सीन';

  @override
  String get wallpaperSpatialGreatSubtitle => 'साफ़ गहराई। एक मज़बूत 3D लॉक स्क्रीन बनाती है।';

  @override
  String get wallpaperSpatialOkSubtitle => 'थोड़ी गहराई। 3D इफ़ेक्ट हल्का है।';

  @override
  String get wallpaperSpatialGuideTitle => 'इसे स्पेशियल सीन के रूप में सेट करें';

  @override
  String get wallpaperSpatialGuideBody => 'iOS 26 वाले iPhone 12 या उसके बाद के मॉडल पर:';

  @override
  String get wallpaperSpatialStepSave => 'इस वॉलपेपर को फ़ोटो में सेव करें।';

  @override
  String get wallpaperSpatialStepPick =>
      'लॉक स्क्रीन पर, स्क्रीन को स्पर्श करके रखें। जोड़ें बटन पर टैप करें, फ़ोटो पर टैप करें, फिर फ़ोटो चुनें।';

  @override
  String get wallpaperSpatialStepButton =>
      '3D इफ़ेक्ट चालू करने के लिए स्पेशियल सीन बटन पर टैप करें, फिर जोड़ें पर टैप करें।';

  @override
  String get wallpaperSpatialPreviewLabel => '3D';

  @override
  String get wallpaperSpatialPreviewOn => '3D में प्रीव्यू देखें';

  @override
  String get wallpaperSpatialPreviewOff => '3D प्रीव्यू बंद करें';

  @override
  String get wallpaperSpatialDragHint => 'झुकाने के लिए खींचें';

  @override
  String get wallpaperDetailColorCodeCopied => 'रंग कोड क्लिपबोर्ड पर कॉपी हुआ';

  @override
  String get wallpaperDetailNotFound => 'वॉलपेपर नहीं मिला';

  @override
  String get wallpaperDiscard => 'खारिज करें';

  @override
  String get wallpaperDismiss => 'बंद करें';

  @override
  String get wallpaperDownload => 'डाउनलोड';

  @override
  String wallpaperDownloadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString डाउनलोड',
      one: '$countString डाउनलोड',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadSortName => 'नाम';

  @override
  String get wallpaperDownloadSortNewest => 'सबसे नया';

  @override
  String get wallpaperDownloadSortOldest => 'सबसे पुराना';

  @override
  String get wallpaperDownloadWallpaper => 'वॉलपेपर डाउनलोड करें';

  @override
  String get wallpaperDownloadedWallpaper => 'डाउनलोड किया गया वॉलपेपर';

  @override
  String get wallpaperDownloadedWallpaperUnavailable => 'डाउनलोड किया गया वॉलपेपर उपलब्ध नहीं है';

  @override
  String wallpaperDownloadsDeleteError(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString डाउनलोड नहीं हट सके।',
      one: '$countString डाउनलोड नहीं हट सका।',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadsEmptyBody => 'आपके डाउनलोड किए वॉलपेपर यहाँ रखे जाते हैं।';

  @override
  String get wallpaperDownloadsEmptyTitle => 'अभी कोई डाउनलोड नहीं है';

  @override
  String get wallpaperDownloadsLoadError => 'आपके डाउनलोड लोड नहीं हो सके';

  @override
  String get wallpaperDownloadsLoadHelp => 'स्टोरेज की अनुमति जाँचें और फिर कोशिश करें।';

  @override
  String get wallpaperDownloadsRefreshError => 'डाउनलोड रीफ़्रेश नहीं हो सके। फिर कोशिश करें।';

  @override
  String get wallpaperDownloadsShareError => 'शेयर नहीं हो सका। फिर कोशिश करें।';

  @override
  String get wallpaperDownloadsTitle => 'डाउनलोड';

  @override
  String get wallpaperEdit => 'बदलें';

  @override
  String get wallpaperEditTitle => 'वॉलपेपर बदलें';

  @override
  String get wallpaperExpandDetails => 'वॉलपेपर की जानकारी फैलाएँ';

  @override
  String get wallpaperFavourite => 'पसंदीदा में जोड़ें';

  @override
  String get wallpaperFavouriteAddedToast => 'पसंदीदा में जोड़ दिया गया।';

  @override
  String get wallpaperFavouriteClearAccountMessage => 'इससे वे आपके अकाउंट से हट जाएँगे।';

  @override
  String get wallpaperFavouriteClearAll => 'सभी पसंदीदा हटाएँ';

  @override
  String get wallpaperFavouriteClearDeviceMessage => 'इससे वे इस डिवाइस से हट जाएँगे।';

  @override
  String get wallpaperFavouriteClearError => 'पसंदीदा साफ़ नहीं हो सके। फिर कोशिश करें।';

  @override
  String wallpaperFavouriteClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString पसंदीदा हटाएँ?';
  }

  @override
  String get wallpaperFavouriteClearOneTitle => '1 पसंदीदा हटाएँ?';

  @override
  String wallpaperFavouriteClearedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString पसंदीदा हटाए गए',
      one: '$countString पसंदीदा हटाया गया',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteClearedOne => '1 पसंदीदा हटाया गया';

  @override
  String wallpaperFavouriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString पसंदीदा',
      one: '$countString पसंदीदा',
      zero: 'कोई पसंदीदा नहीं',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteEmptyBody => 'वॉलपेपर को यहाँ रखने के लिए उसके दिल वाले आइकन पर टैप करें।';

  @override
  String get wallpaperFavouriteEmptyTitle => 'अभी कोई पसंदीदा नहीं है';

  @override
  String get wallpaperFavouriteExport => 'पसंदीदा एक्सपोर्ट करें';

  @override
  String get wallpaperFavouriteExportEmpty => 'एक्सपोर्ट करने के लिए अभी कोई पसंदीदा नहीं है।';

  @override
  String get wallpaperFavouriteExportError => 'पसंदीदा एक्सपोर्ट नहीं हो सके। फिर कोशिश करें।';

  @override
  String get wallpaperFavouriteGuestPrompt => 'हर डिवाइस पर इन्हें रखने के लिए साइन इन करें';

  @override
  String get wallpaperFavouriteLoadError => 'आपके पसंदीदा लोड नहीं हो सके';

  @override
  String get wallpaperFavouriteMoreActions => 'पसंदीदा के और विकल्प';

  @override
  String get wallpaperFavouriteNoMatch => 'कोई मेल खाता पसंदीदा नहीं';

  @override
  String get wallpaperFavouriteNotSynced => 'सिंक नहीं हुआ';

  @override
  String get wallpaperFavouriteRefreshFallback => 'पसंदीदा रीफ़्रेश नहीं हो सके। आपकी सेव की हुई सूची दिखाई जा रही है।';

  @override
  String get wallpaperFavouriteRemove => 'हटाएँ';

  @override
  String get wallpaperFavouriteRemoveAction => 'पसंदीदा से हटाएँ';

  @override
  String get wallpaperFavouriteRemoveError => 'पसंदीदा हटाए नहीं जा सके। फिर कोशिश करें।';

  @override
  String wallpaperFavouriteRemovedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString पसंदीदा हटाए गए',
      one: '$countString पसंदीदा हटाया गया',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteRemovedOne => 'पसंदीदा से हटाया गया';

  @override
  String get wallpaperFavouriteRemovedToast => 'पसंदीदा से हटाया गया।';

  @override
  String get wallpaperFavouriteRestoreError => 'पसंदीदा वापस नहीं लाए जा सके।';

  @override
  String get wallpaperFavouriteSearchHint => 'क्रिएटर या श्रेणी से खोजें';

  @override
  String get wallpaperFavouriteSetUsesFirst => 'सेट करने पर आपके चुने हुए पहले वॉलपेपर का इस्तेमाल होगा';

  @override
  String get wallpaperFavouriteShareError => 'शेयर नहीं हो सका। फिर कोशिश करें।';

  @override
  String get wallpaperFavouriteSortOldest => 'सबसे पुराना';

  @override
  String get wallpaperFavouriteSortRecentlyAdded => 'हाल ही में जोड़ा गया';

  @override
  String get wallpaperFavouriteSortSource => 'स्रोत';

  @override
  String get wallpaperFavouriteStatus => 'आपके पसंदीदा में';

  @override
  String get wallpaperFavouriteTryDifferent => 'दूसरी खोज या स्रोत आज़माएँ।';

  @override
  String get wallpaperFavouriteUnavailableLegacy =>
      'यह पसंदीदा पुराने वर्शन का है और खुल नहीं सकता। हटाने के लिए देर तक दबाएँ।';

  @override
  String get wallpaperFavouriteWaitingSync => 'सिंक होने की प्रतीक्षा में';

  @override
  String get wallpaperFavouritesTitle => 'पसंदीदा';

  @override
  String get wallpaperFeedAnnouncement => 'घोषणा';

  @override
  String get wallpaperFeedCaughtUpBody => 'रीफ़्रेश करने के लिए नीचे खींचें। नई पसंद यहाँ दिखेंगी।';

  @override
  String get wallpaperFeedCaughtUpTitle => 'आप सब देख चुके हैं';

  @override
  String get wallpaperFeedClearHistoryError => 'इतिहास साफ़ नहीं हो सका। फिर कोशिश करें।';

  @override
  String get wallpaperFeedDiscovery => 'खोज';

  @override
  String get wallpaperFeedEmptyBody =>
      'क्रिएटर फ़ॉलो करें या अपनी रुचियाँ चुनें, ताकि हम आपको आपकी पसंद के वॉलपेपर दिखा सकें।';

  @override
  String get wallpaperFeedEmptyTitle => 'अपनी फ़ीड को अपनी पसंद का बनाएँ';

  @override
  String get wallpaperFeedFollowingEmptyTitle => 'क्रिएटर फ़ॉलो करें और उनके नए वॉलपेपर यहाँ देखें';

  @override
  String get wallpaperFeedFollowingLoadError => 'आपकी फ़ॉलोइंग फ़ीड लोड नहीं हो सकी';

  @override
  String get wallpaperFeedLatestLoadError => 'नवीनतम वॉलपेपर लोड नहीं हो सके';

  @override
  String get wallpaperFeedLearnedFromYou => 'आपसे सीखा गया';

  @override
  String get wallpaperFeedLearningEmpty => 'अपनी फ़ीड को सिखाने के लिए वॉलपेपर खोलें, सेव करें और लगाएँ।';

  @override
  String get wallpaperFeedLearningHistoryCleared => 'सीखने का इतिहास मिटा दिया गया';

  @override
  String get wallpaperFeedLoadError => 'आपकी फ़ीड लोड नहीं हो सकी';

  @override
  String get wallpaperFeedLoadMoreError => 'और लोड नहीं हो सका। फिर कोशिश करें';

  @override
  String get wallpaperFeedMixAdventurous => 'कुछ नया आज़माएँ';

  @override
  String get wallpaperFeedMixAdventurousDescription => 'आपकी पसंद से हटकर और वॉलपेपर दिखाएँ।';

  @override
  String get wallpaperFeedMixBalanced => 'संतुलित';

  @override
  String get wallpaperFeedMixBalancedDescription => 'आपकी पसंद के साथ कुछ नए विकल्प।';

  @override
  String get wallpaperFeedMixFamiliar => 'जाना-पहचाना';

  @override
  String get wallpaperFeedMixFamiliarDescription => 'ज़्यादातर वही जो आपको पहले से पसंद हैं।';

  @override
  String wallpaperFeedPickAtLeast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'कम से कम $countString चुनें';
  }

  @override
  String wallpaperFeedPickedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString चुने गए';
  }

  @override
  String get wallpaperFeedPopularEmptyTitle => 'अभी कोई लोकप्रिय वॉलपेपर नहीं';

  @override
  String get wallpaperFeedPopularLoadError => 'लोकप्रिय वॉलपेपर लोड नहीं हो सके';

  @override
  String get wallpaperFeedPullToRefresh => 'रीफ़्रेश करने के लिए नीचे खींचें।';

  @override
  String get wallpaperFeedRefreshError => 'आपकी फ़ीड रीफ़्रेश नहीं हो सकी।';

  @override
  String get wallpaperFeedSaveError => 'फ़ीड सेटिंग सेव नहीं हो सकी। फिर कोशिश करें।';

  @override
  String get wallpaperFeedSettingsHint => 'फ़ीड सेटिंग खोलने के लिए दो बार टैप करें';

  @override
  String get wallpaperFeedStartingPoints => 'शुरुआत के लिए सुझाव';

  @override
  String get wallpaperFeedTabFollowing => 'फ़ॉलो कर रहे हैं';

  @override
  String get wallpaperFeedTabForYou => 'आपके लिए';

  @override
  String get wallpaperFeedTabLatest => 'नवीनतम';

  @override
  String get wallpaperFeedTabPopular => 'लोकप्रिय';

  @override
  String get wallpaperFeedTabTrending => 'ट्रेंडिंग';

  @override
  String get wallpaperFeedTuneDescription => 'Prism आपके खोले, सेव किए और लगाए गए वॉलपेपर से सीखता है।';

  @override
  String get wallpaperFeedTuneTitle => 'अपनी फ़ीड को बेहतर बनाएँ';

  @override
  String get wallpaperFeedUpdating => 'अपडेट हो रहा है';

  @override
  String get wallpaperFeedWallsLoadError => 'वॉलपेपर लोड नहीं हो सके';

  @override
  String get wallpaperFewerLikeThisConfirmation => 'अब आपको इस तरह के कम वॉलपेपर दिखेंगे।';

  @override
  String get wallpaperFewerLikeThisUndo => 'पहले जैसा करें';

  @override
  String get wallpaperFileMovedOrDeleted => 'हो सकता है फ़ाइल कहीं और ले जाई गई हो या मिटा दी गई हो।';

  @override
  String wallpaperFilterApplyCost(int coins, int missing) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'यह फ़िल्टर लगाने में $coinsString कॉइन लगेंगे। आपके पास $missingString कॉइन कम हैं।';
  }

  @override
  String get wallpaperFilterBlur => 'धुंधलापन';

  @override
  String get wallpaperFilterBrightness => 'चमक';

  @override
  String get wallpaperFilterEffectEdge => 'किनारे';

  @override
  String get wallpaperFilterEffectEmboss => 'उभरा हुआ';

  @override
  String get wallpaperFilterEffectHighPass => 'हाई पास';

  @override
  String get wallpaperFilterEffectSharpen => 'शार्प करें';

  @override
  String get wallpaperFilterHoldToCompare => 'तुलना करने के लिए दबाकर रखें';

  @override
  String get wallpaperFilterHue => 'रंगत';

  @override
  String get wallpaperFilterLightness => 'हल्कापन';

  @override
  String get wallpaperFilterLightnessUnavailable => 'इस डिवाइस पर हल्केपन का विकल्प उपलब्ध नहीं है।';

  @override
  String get wallpaperFilterNeedCoins => 'प्रीमियम फ़िल्टर के लिए कॉइन चाहिए';

  @override
  String get wallpaperFilterOriginal => 'मूल';

  @override
  String get wallpaperFilterSaturation => 'रंग की गहराई';

  @override
  String get wallpaperFilterSaveError => 'वॉलपेपर सेव नहीं हो सका। कृपया फिर कोशिश करें!';

  @override
  String get wallpaperFilterTabAdjustments => 'समायोजन';

  @override
  String get wallpaperFilterTabFilters => 'फ़िल्टर';

  @override
  String wallpaperFilterUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'इस एडिट के लिए प्रीमियम फ़िल्टर अनलॉक किया गया (-$coinsString कॉइन)।';
  }

  @override
  String get wallpaperFitBlur => 'धुंधले बैकग्राउंड के साथ फ़िट करें';

  @override
  String get wallpaperFitColour => 'रंग के साथ फ़िट करें';

  @override
  String get wallpaperFitFill => 'भरें';

  @override
  String get wallpaperGenericError => 'कुछ गड़बड़ हुई!';

  @override
  String get wallpaperGoBack => 'वापस जाएँ';

  @override
  String get wallpaperGotItFewerLikeThis => 'ठीक है। अब ऐसे कम वॉलपेपर दिखेंगे।';

  @override
  String get wallpaperHidePreviewControls => 'नियंत्रण छिपाएँ';

  @override
  String get wallpaperHistoryBothScreens => 'दोनों स्क्रीन';

  @override
  String get wallpaperHistoryCurrent => 'मौजूदा';

  @override
  String get wallpaperHistoryCurrentPrefix => 'मौजूदा। ';

  @override
  String get wallpaperHistoryEmptyBody => 'आपके लगाए हुए वॉलपेपर यहाँ दिखेंगे, ताकि आप उन्हें फिर से लगा सकें।';

  @override
  String get wallpaperHistoryEmptyTitle => 'अभी कोई वॉलपेपर नहीं';

  @override
  String get wallpaperHistoryRemoveAction => 'इतिहास से हटाएँ';

  @override
  String get wallpaperHomeAppName => 'Prism';

  @override
  String get wallpaperImageSemanticHint =>
      'रंग बदलने के लिए टैप करें। पसंदीदा, शेयर और रीसेट के लिए दबाकर रखें। विवरण के लिए स्क्रॉल करें।';

  @override
  String get wallpaperPreviousInFeed => 'पिछला वॉलपेपर';

  @override
  String get wallpaperNextInFeed => 'अगला वॉलपेपर';

  @override
  String get wallpaperImageSemanticLabel => 'वॉलपेपर';

  @override
  String get wallpaperInsufficientCoins => 'कॉइन कम हैं। इनाम में कॉइन कमाएँ।';

  @override
  String wallpaperInterestLearnedLabel(String label, int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'सीखी गई रुचि: $label, $percentString प्रतिशत';
  }

  @override
  String wallpaperInterestSelectedLabel(String name, String selection) {
    return 'रुचि: $name, $selection';
  }

  @override
  String get wallpaperLandscapeCrop => 'लैंडस्केप वॉलपेपर: किनारे कट जाएँगे';

  @override
  String get wallpaperLibraryCollections => 'कलेक्शन';

  @override
  String get wallpaperLibraryDownloads => 'डाउनलोड';

  @override
  String get wallpaperLibraryFavourites => 'पसंदीदा';

  @override
  String get wallpaperLibraryHistory => 'इतिहास';

  @override
  String get wallpaperLibraryTitle => 'लाइब्रेरी';

  @override
  String get wallpaperLive => 'लाइव';

  @override
  String get wallpaperLiveApplied => 'लाइव वॉलपेपर लगा दिया गया।';

  @override
  String wallpaperLiveApplyPhotoDescription(String style) {
    return '$style का प्रीव्यू';
  }

  @override
  String get wallpaperLiveBatterySaver => 'बैटरी सेवर';

  @override
  String get wallpaperLiveChooseAnotherVideo => 'कोई दूसरा वीडियो चुनें';

  @override
  String get wallpaperLiveChooseVideo => 'वीडियो चुनें';

  @override
  String get wallpaperLiveConfirmPreview => 'सिस्टम प्रीव्यू में पुष्टि करें।';

  @override
  String get wallpaperLiveDeviceUnavailable => 'इस डिवाइस पर उपलब्ध नहीं है';

  @override
  String get wallpaperLiveErrorGeneric => 'लाइव वॉलपेपर नहीं लगाया जा सका। फिर कोशिश करें।';

  @override
  String get wallpaperLiveErrorImageTooLarge => 'यह इमेज लाइव वॉलपेपर के लिए बहुत बड़ी है।';

  @override
  String get wallpaperLiveErrorMemory => 'मेमोरी कम है। दूसरे ऐप बंद करके फिर कोशिश करें।';

  @override
  String get wallpaperLiveErrorNotAllowed => 'आपका डिवाइस या वर्क प्रोफ़ाइल वॉलपेपर बदलने की अनुमति नहीं देता।';

  @override
  String get wallpaperLiveErrorPermission => 'Prism को यह फ़ाइल पढ़ने की अनुमति नहीं है।';

  @override
  String get wallpaperLiveErrorPreview => 'सिस्टम प्रीव्यू नहीं खुल सका।';

  @override
  String get wallpaperLiveErrorReadFile => 'फ़ाइल पढ़ी नहीं जा सकी। फिर कोशिश करें।';

  @override
  String get wallpaperLiveErrorStyle => 'यह डिवाइस वह स्टाइल शुरू नहीं कर सका। कोई और आज़माएँ।';

  @override
  String get wallpaperLiveErrorTimeout => 'समय सीमा समाप्त हो गई। कनेक्शन जाँचकर फिर कोशिश करें।';

  @override
  String get wallpaperLiveErrorTooLarge => 'यह फ़ाइल लाइव वॉलपेपर के लिए बहुत बड़ी है।';

  @override
  String get wallpaperLiveErrorVideo => 'यह वीडियो वॉलपेपर के रूप में नहीं चल सकता। कोई और क्लिप आज़माएँ।';

  @override
  String wallpaperLiveFps(int fps) {
    final intl.NumberFormat fpsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String fpsString = fpsNumberFormat.format(fps);

    return 'हर सेकंड $fpsString फ़्रेम';
  }

  @override
  String wallpaperLiveGradientDescription(String style) {
    return '$style का प्रीव्यू';
  }

  @override
  String wallpaperLiveGradientSwatch(String index, String count) {
    return 'ग्रेडिएंट रंग $index / $count';
  }

  @override
  String get wallpaperLiveKeepPrismOpen => 'Prism खुला रखें और फिर कोशिश करें।';

  @override
  String get wallpaperLiveModeGradients => 'ग्रेडिएंट';

  @override
  String get wallpaperLiveModePhoto => 'लाइव बनाएँ';

  @override
  String get wallpaperLiveModeVideo => 'वीडियो';

  @override
  String get wallpaperLiveNoVideo => 'कोई वीडियो नहीं चुना गया';

  @override
  String get wallpaperLivePreviewInstruction => 'Android प्रीव्यू खोलेगा। वहाँ वॉलपेपर लगाने के लिए टैप करें।';

  @override
  String get wallpaperLiveProStyleRequired => 'यह स्टाइल Prism Pro का हिस्सा है।';

  @override
  String get wallpaperLiveSetAction => 'लाइव वॉलपेपर लगाएँ';

  @override
  String get wallpaperLiveShaderUnsupported => 'यह डिवाइस शेडर वाले लाइव वॉलपेपर नहीं चला सकता। वीडियो आज़माएँ।';

  @override
  String get wallpaperLiveStyleAurora => 'ऑरोरा';

  @override
  String get wallpaperLiveStyleAuroraDescription => 'रंगों की मुलायम लहरें।';

  @override
  String get wallpaperLiveStyleBreathe => 'साँस';

  @override
  String get wallpaperLiveStyleBreatheDescription => 'धीरे-धीरे फैलती और सिमटती लहर।';

  @override
  String get wallpaperLiveStyleDrift => 'बहाव';

  @override
  String get wallpaperLiveStyleDriftDescription => 'धीमा पैन और ज़ूम। होम स्क्रीन पर स्वाइप करने के साथ चलता है।';

  @override
  String get wallpaperLiveStyleMesh => 'मेश';

  @override
  String get wallpaperLiveStyleMeshDescription => 'धीरे-धीरे बदलते मिले-जुले रंग।';

  @override
  String get wallpaperLiveStylePlasma => 'प्लाज़्मा';

  @override
  String get wallpaperLiveStylePlasmaDescription => 'बहते हुए मुलायम रंग।';

  @override
  String get wallpaperLiveStyleRipple => 'लहरें';

  @override
  String get wallpaperLiveStyleRippleDescription => 'आपके छूने से फैलते पानी के छल्ले।';

  @override
  String get wallpaperLiveStyleShimmer => 'झिलमिलाहट';

  @override
  String get wallpaperLiveStyleShimmerDescription => 'रोशनी की एक मुलायम चमक।';

  @override
  String get wallpaperLiveStyleDepth => '3D';

  @override
  String get wallpaperLiveStyleDepthDescription => 'होम स्क्रीन बदलने और फ़ोन झुकाने पर फ़ोटो गहराई में चलती है।';

  @override
  String get wallpaperLiveStyleStarfield => 'तारों भरा आसमान';

  @override
  String get wallpaperLiveStyleStarfieldDescription => 'गहरे काले आसमान पर टिमटिमाते तारे।';

  @override
  String wallpaperLiveStyleUnlocked(String style) {
    return '$style 7 दिनों के लिए अनलॉक है।';
  }

  @override
  String get wallpaperLiveStyleWaves => 'लहरें';

  @override
  String get wallpaperLiveStyleWavesDescription => 'एक के ऊपर एक उठती-गिरती लहरें।';

  @override
  String get wallpaperLiveTextureDownloadFailed => 'वॉलपेपर डाउनलोड नहीं हो सका। कनेक्शन जाँचकर फिर कोशिश करें।';

  @override
  String get wallpaperLiveTexturePrepareFailed => 'वॉलपेपर तैयार नहीं हो सका।';

  @override
  String get wallpaperLiveTextureTooDetailed => 'इस वॉलपेपर में एनिमेशन के लिए बहुत ज़्यादा बारीकियाँ हैं।';

  @override
  String get wallpaperLiveTitle => 'लाइव वॉलपेपर';

  @override
  String get wallpaperLiveUnavailableBody => 'इसके लिए ऐसा Android फ़ोन चाहिए जो OpenGL लाइव वॉलपेपर सपोर्ट करता हो।';

  @override
  String get wallpaperLiveUnavailableTitle => 'लाइव वॉलपेपर उपलब्ध नहीं हैं';

  @override
  String wallpaperLiveUnlockCoins(String coins) {
    return 'अनलॉक करें · $coins कॉइन';
  }

  @override
  String wallpaperLiveUnlockError(String style) {
    return '$style अनलॉक नहीं हो सका। फिर कोशिश करें।';
  }

  @override
  String wallpaperLiveUnlockStyleAction(String style, String coins) {
    return '$style को 7 दिनों के लिए अनलॉक करें · $coins कॉइन';
  }

  @override
  String get wallpaperLiveUnlockStyleBody => 'कॉइन से इसे 7 दिनों के लिए अनलॉक करें या हर स्टाइल के लिए Prism Pro लें।';

  @override
  String wallpaperLiveUnlockStyleTitle(String style) {
    return '$style एक सशुल्क स्टाइल है';
  }

  @override
  String get wallpaperLiveUnsupported => 'यह डिवाइस लाइव वॉलपेपर नहीं दिखा सकता।';

  @override
  String get wallpaperLiveVideoChosen => 'चुना गया वीडियो';

  @override
  String get wallpaperLiveVideoDescription => 'होम स्क्रीन पर बिना आवाज़ चलेगा। अधिकतम 256 MB।';

  @override
  String get wallpaperLiveVideoReadFailed => 'वीडियो पढ़ा नहीं जा सका। इसे फिर से चुनें।';

  @override
  String get wallpaperLiveVideoTooLarge => 'यह वीडियो 256 MB से बड़ा है। छोटी क्लिप चुनें।';

  @override
  String get wallpaperLiveVideoUnsupported => 'यह डिवाइस वीडियो को वॉलपेपर के रूप में नहीं चला सकता।';

  @override
  String get wallpaperLoadingImage => 'इमेज लोड हो रही है';

  @override
  String get wallpaperLoadingWallpaper => 'वॉलपेपर लोड हो रहा है';

  @override
  String get wallpaperLowResolutionScreen => 'आपकी स्क्रीन के लिए रिज़ॉल्यूशन कम है';

  @override
  String get wallpaperMakeItLive => 'लाइव बनाएँ';

  @override
  String get wallpaperMatchSystemColour => 'सिस्टम के रंग से मिलाएँ';

  @override
  String get wallpaperMoreLikeThis => 'ऐसे और देखें';

  @override
  String get wallpaperNavCollections => 'कलेक्शन';

  @override
  String get wallpaperNavHome => 'होम';

  @override
  String get wallpaperNavRewards => 'इनाम';

  @override
  String get wallpaperNavSearch => 'खोजें';

  @override
  String get wallpaperNew => 'नया';

  @override
  String get wallpaperNotNow => 'अभी नहीं';

  @override
  String get wallpaperNotSelected => 'चुना नहीं गया';

  @override
  String get wallpaperNotificationPromptBody =>
      'हर सुबह आपकी पसंद का एक वॉलपेपर और स्ट्रीक की याद दिलाने वाले नोटिफ़िकेशन। कोई स्पैम नहीं।';

  @override
  String get wallpaperNotificationPromptTitle => 'आज का वॉलपेपर पाएँ';

  @override
  String get wallpaperOffline => 'ऑफ़लाइन';

  @override
  String wallpaperOldVersionBody(String version) {
    return 'वर्शन $version अब समर्थित नहीं है। Prism का इस्तेमाल जारी रखने के लिए अपडेट करें।';
  }

  @override
  String get wallpaperOldVersionTitle => 'अपडेट करने का समय';

  @override
  String get wallpaperOnPrism => 'Prism पर वॉलपेपर';

  @override
  String get wallpaperOpenError => 'यह वॉलपेपर लोड नहीं हो सका';

  @override
  String get wallpaperOpenFileError => 'यह वॉलपेपर खुल नहीं सका';

  @override
  String get wallpaperOpenNotifications => 'नोटिफ़िकेशन खोलें';

  @override
  String get wallpaperOtherSource => 'अन्य';

  @override
  String get wallpaperPastPicksEmpty => 'अभी तक कोई पिछला चयन नहीं';

  @override
  String get wallpaperPastPicksLoadError => 'पिछले चयन लोड नहीं हो सके';

  @override
  String get wallpaperPastPicksTitle => 'पिछले चयन';

  @override
  String get wallpaperPlacementDim => 'मंद करें';

  @override
  String get wallpaperPositionApproximate => 'अनुमानित जगह। आपके लॉन्चर में अलग हो सकती है।';

  @override
  String get wallpaperPremium => 'Premium';

  @override
  String get wallpaperPremiumCollection => 'Premium कलेक्शन';

  @override
  String wallpaperPremiumCollectionNamed(String name) {
    return 'Premium कलेक्शन, $name';
  }

  @override
  String get wallpaperPreviewHome => 'होम';

  @override
  String get wallpaperPreviewIconClear => 'पारदर्शी';

  @override
  String get wallpaperPreviewIconDark => 'डार्क';

  @override
  String get wallpaperPreviewIconDefault => 'डिफ़ॉल्ट';

  @override
  String get wallpaperPreviewIconStyle => 'आइकन शैली';

  @override
  String get wallpaperPreviewIconThemed => 'थीम वाले';

  @override
  String get wallpaperPreviewIconTinted => 'टिंटेड';

  @override
  String get wallpaperPreviewLock => 'लॉक';

  @override
  String get wallpaperPreviewOnScreen => 'आपकी स्क्रीन पर पूर्वावलोकन';

  @override
  String get wallpaperPreviewSetBoth => 'दोनों स्क्रीन पर लगाएँ';

  @override
  String get wallpaperPreviewSetHome => 'होम स्क्रीन पर लगाएँ';

  @override
  String get wallpaperPreviewSetLock => 'लॉक स्क्रीन पर लगाएँ';

  @override
  String wallpaperPreviewUnlock24Hours(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '24 घंटे के लिए अनलॉक करें (-$costString)';
  }

  @override
  String wallpaperPreviewUnlockCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'इस Premium कलेक्शन का 24 घंटे प्रीव्यू देखने के लिए $costString कॉइन लगेंगे।';
  }

  @override
  String wallpaperPreviewUnlockCostMissing(int cost, int missing) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return '24 घंटे के प्रीव्यू के लिए $costString कॉइन लगेंगे। आपके पास $missingString कॉइन कम हैं।';
  }

  @override
  String wallpaperPreviewWatchAdUnlock(String adOption) {
    return '$adOption और अनलॉक करें';
  }

  @override
  String get wallpaperProcessing => 'वॉलपेपर पर काम हो रहा है';

  @override
  String get wallpaperProfileOpenError => 'प्रोफ़ाइल नहीं खुल सकी';

  @override
  String get wallpaperQuickAddAction => 'क्विक सेटिंग्स में जोड़ें';

  @override
  String get wallpaperQuickFavouriteDescription =>
      'आपके पसंदीदा वॉलपेपर में से कोई एक बेतरतीब लगाता है। पहले साइन इन करें और कुछ वॉलपेपर पसंदीदा में जोड़ें।';

  @override
  String get wallpaperQuickFavouriteTitle => 'बेतरतीब पसंदीदा टाइल';

  @override
  String get wallpaperQuickHowToTitle => 'टाइल कैसे जोड़ें';

  @override
  String get wallpaperQuickShuffleDescription =>
      'अपनी चुनी हुई कैटेगरी से कोई बेतरतीब वॉलपेपर लगाने के लिए टाइल टैप करें।';

  @override
  String get wallpaperQuickShuffleTitle => 'वॉलपेपर बदलने की टाइल';

  @override
  String get wallpaperQuickStepEdit => 'पेंसिल या एडिट आइकन टैप करें।';

  @override
  String get wallpaperQuickStepFindPrism => 'Prism की टाइलें ढूँढें और उन्हें अपनी सक्रिय टाइलों में खींचें।';

  @override
  String get wallpaperQuickStepShade => 'नोटिफ़िकेशन पैनल को दो बार नीचे खींचें।';

  @override
  String get wallpaperQuickTargetBoth => 'दोनों';

  @override
  String get wallpaperQuickTargetHome => 'होम';

  @override
  String get wallpaperQuickTargetLock => 'लॉक';

  @override
  String get wallpaperQuickTileAddError =>
      'टाइल नहीं जोड़ी जा सकी। इसे त्वरित सेटिंग्स की संपादन स्क्रीन से खुद जोड़ें।';

  @override
  String get wallpaperQuickTileAdded => 'टाइल त्वरित सेटिंग्स में जोड़ दी गई।';

  @override
  String get wallpaperQuickTileAlreadyAdded => 'यह टाइल पहले से त्वरित सेटिंग्स में है।';

  @override
  String get wallpaperQuickTileNotAdded => 'टाइल नहीं जोड़ी गई। आप इसे कभी भी जोड़ सकते हैं।';

  @override
  String get wallpaperQuickTileSaveError => 'क्विक टाइल की सेटिंग सेव नहीं हो सकी';

  @override
  String get wallpaperQuickTilesLoadError => 'आपकी क्विक टाइलें लोड नहीं हो सकीं';

  @override
  String get wallpaperQuickTilesTitle => 'क्विक टाइलें';

  @override
  String get wallpaperQuickWotdDescription =>
      'आज का वॉलपेपर लगाता है। नया वॉलपेपर कैश करने के लिए Prism को रोज़ एक बार खोलें।';

  @override
  String get wallpaperQuickWotdTitle => 'आज के वॉलपेपर की टाइल';

  @override
  String get wallpaperRefresh => 'रीफ़्रेश करें';

  @override
  String get wallpaperRemovedFromHistory => 'इतिहास से हटा दिया गया';

  @override
  String get wallpaperReport => 'रिपोर्ट करें';

  @override
  String get wallpaperReset => 'रीसेट करें';

  @override
  String get wallpaperSave => 'सेव करें';

  @override
  String get wallpaperSaveToPhotos => 'फ़ोटो में सेव करें';

  @override
  String get wallpaperSavedOnDevice => 'इस डिवाइस पर सेव किया गया';

  @override
  String wallpaperSearchTag(String tag) {
    return '$tag खोजें';
  }

  @override
  String get wallpaperSeePrismPro => 'Prism Pro देखें';

  @override
  String get wallpaperSelected => 'चुना गया';

  @override
  String get wallpaperServerUnavailable => 'सर्वर से कनेक्ट नहीं हो सका';

  @override
  String get wallpaperSessionEnded => 'आपका सेशन समाप्त हो गया। फिर से साइन इन करें।';

  @override
  String get wallpaperSet => 'सेट करें';

  @override
  String get wallpaperSetAsWallpaper => 'वॉलपेपर के रूप में सेट करें';

  @override
  String wallpaperSetCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString बार सेट किया',
      one: '$countString बार सेट किया',
    );
    return '$_temp0';
  }

  @override
  String get setScreenTargetHome => 'होम स्क्रीन';

  @override
  String get setScreenTargetLock => 'लॉक स्क्रीन';

  @override
  String get setScreenTargetBoth => 'दोनों';

  @override
  String get setScreenTargetGroup => 'कहाँ लगाना है';

  @override
  String get setScreenRemember => 'यह चुनाव याद रखें';

  @override
  String get setScreenRememberHint => 'अगली बार लगाएँ यह स्क्रीन छोड़ देगा। वापस आने के लिए लगाएँ को दबाकर रखें।';

  @override
  String get setScreenAdjust => 'समायोजित करें';

  @override
  String get setScreenMore => 'और';

  @override
  String get setScreenPairLock => 'लॉक स्क्रीन के लिए कोई और वॉलपेपर लगाएँ';

  @override
  String get setScreenOpenSystemEditor => 'सिस्टम एडिटर खोलें';

  @override
  String get setScreenClose => 'बंद करें';

  @override
  String get wallpaperShare => 'शेयर करें';

  @override
  String get wallpaperShareLink => 'लिंक शेयर करें';

  @override
  String get wallpaperShortcutsAddActionsSteps =>
      '\"Prism वॉलपेपर पाएँ\" ऐक्शन जोड़ें। फिर \"वॉलपेपर सेट करें\" ऐक्शन जोड़ें।';

  @override
  String get wallpaperShortcutsBody =>
      'Shortcuts से किसी समय या ट्रिगर पर वॉलपेपर लगाएँ। चलाने से पहले नीचे दिया स्रोत तैयार करें।';

  @override
  String get wallpaperShortcutsChoosePrismData => 'चुनें कि Prism क्या भेजे';

  @override
  String get wallpaperShortcutsChooseTriggerSteps =>
      'शॉर्टकट संपादक में ज़रूरत हो तो ऑटोमेशन खोलें। ट्रिगर चुनकर सेट करें, जैसे दिन का समय, ऐप खोलना या चार्जर लगाना।';

  @override
  String get wallpaperShortcutsDisableConfirmationSteps =>
      'दिखाए गए चलाने के विकल्प जाँचें और शॉर्टकट या ऑटोमेशन सहेजें। अगर \"चलाने से पहले पूछें\" दिखे, अपने-आप चलाने के लिए उसे बंद करें।';

  @override
  String get wallpaperShortcutsHeadline => 'अपना वॉलपेपर अपने-आप बदलें';

  @override
  String get wallpaperShortcutsOpenAction => 'Shortcuts खोलें';

  @override
  String get wallpaperShortcutsOpenAutomationSteps =>
      'Shortcuts खोलें। अगर ऑटोमेशन टैब है, उस पर और फिर नया ऑटोमेशन पर टैप करें। वरना जोड़ें (+) पर और संपादित करें दिखे तो उस पर टैप करें।';

  @override
  String get wallpaperShortcutsOpenError => 'Shortcuts नहीं खुल सका। ऐप खुद खोलें।';

  @override
  String get wallpaperShortcutsSourceFavourite => 'रैंडम पसंदीदा';

  @override
  String get wallpaperShortcutsSourceFavouriteDescription =>
      'Shortcuts के लिए उपलब्ध कोई रैंडम पसंदीदा। पहले Prism में वॉलपेपर पसंद करें। कुछ संरक्षित वॉलपेपर उपलब्ध नहीं हो सकते। कोई दूसरा पसंदीदा उपलब्ध होने पर पिछला चयन दोहराया नहीं जाता।';

  @override
  String get wallpaperShortcutsSourceWotd => 'आज का वॉलपेपर';

  @override
  String get wallpaperShortcutsSourceWotdDescription =>
      'आज का Prism चयन। पहले Prism में आज का मूल वॉलपेपर डाउनलोड करें। दिन का चयन बदलने पर इस स्रोत को चलाने से पहले नया मूल वॉलपेपर डाउनलोड करें।';

  @override
  String get wallpaperShortcutsSteps => 'कदम';

  @override
  String get wallpaperShortcutsTitle => 'अपने-आप बदलें';

  @override
  String get wallpaperShowLessLikeThis => 'ऐसे कम दिखाएं';

  @override
  String get wallpaperShowPreviewControls => 'नियंत्रण दिखाएँ';

  @override
  String get wallpaperSignIn => 'साइन इन करें';

  @override
  String get wallpaperSignInForPremiumFilters => 'कॉइन से प्रीमियम फ़िल्टर इस्तेमाल करने के लिए साइन इन करें।';

  @override
  String get wallpaperSortDownloads => 'डाउनलोड क्रमबद्ध करें';

  @override
  String get wallpaperStartupFailed => 'Prism शुरू नहीं हो सका';

  @override
  String get wallpaperThemeDarkAccent => 'गहरे रंग का ऐक्सेंट';

  @override
  String get wallpaperThemeDarkThemes => 'गहरी थीम';

  @override
  String get wallpaperUseAsAppAccent => 'ऐप ऐक्सेंट के रूप में इस्तेमाल करें';

  @override
  String get wallpaperAppAccentUpdated => 'ऐप ऐक्सेंट अपडेट हो गया';

  @override
  String get wallpaperThemeLightAccent => 'हल्के रंग का ऐक्सेंट';

  @override
  String get wallpaperThemeLightThemes => 'हल्की थीम';

  @override
  String get wallpaperThemeModeDark => 'गहरा';

  @override
  String get wallpaperThemeModeLight => 'हल्का';

  @override
  String get wallpaperThemeModeSystem => 'सिस्टम (हल्का/गहरा)';

  @override
  String get wallpaperThemePreference => 'थीम की पसंद';

  @override
  String get wallpaperThemePreferenceDescription =>
      'अपनी पसंदीदा थीम चुनें। सिस्टम मोड आपके डिवाइस की सेटिंग के अनुसार हल्की और गहरी थीम के बीच अपने-आप बदलता है।';

  @override
  String get wallpaperThemeTitle => 'थीम';

  @override
  String get wallpaperTitle => 'शीर्षक';

  @override
  String get wallpaperTrendingEmptyTitle => 'अभी कुछ भी ट्रेंड नहीं कर रहा';

  @override
  String get wallpaperTrendingLoadError => 'ट्रेंडिंग वॉलपेपर लोड नहीं हो सके';

  @override
  String get wallpaperTryAgain => 'फिर कोशिश करें';

  @override
  String get wallpaperTurnOff => 'बंद करें';

  @override
  String get wallpaperTurnOnNotifications => 'नोटिफ़िकेशन चालू करें';

  @override
  String get wallpaperUnavailable => 'उपलब्ध नहीं';

  @override
  String get wallpaperUnfavourite => 'पसंदीदा से हटाएं';

  @override
  String get wallpaperUnreadItems => 'बिना पढ़े आइटम हैं';

  @override
  String get wallpaperUpdatePrism => 'Prism अपडेट करें';

  @override
  String get wallpaperUploadAction => 'अपलोड करें';

  @override
  String get wallpaperUploadAddTag => 'टैग जोड़ें';

  @override
  String get wallpaperUploadAddTagHint => 'टैग जोड़ें, फिर हो गया पर टैप करें';

  @override
  String get wallpaperUploadAiSubtitle => 'दृश्य का वर्णन करें और फ़ोन के लिए वॉलपेपर बनाएं';

  @override
  String get wallpaperUploadApprovalInfo =>
      'मंज़ूरी के बाद आपका वॉलपेपर कम्युनिटी में दिखेगा। इसकी स्थिति आपके अपलोड में देखें।';

  @override
  String wallpaperUploadBatchPosition(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString में से वॉलपेपर $positionString';
  }

  @override
  String wallpaperUploadBatchSubmitted(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label। $countString सबमिट किए गए।';
  }

  @override
  String wallpaperUploadBatchSummaryNotSent(String submitted, int notSent) {
    final intl.NumberFormat notSentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String notSentString = notSentNumberFormat.format(notSent);

    return '$submitted। $notSentString नहीं भेजे गए।';
  }

  @override
  String wallpaperUploadBatchSummarySubmitted(int submittedCount, int total) {
    final intl.NumberFormat submittedCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String submittedCountString = submittedCountNumberFormat.format(submittedCount);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString में से $submittedCountString वॉलपेपर सबमिट किए गए';
  }

  @override
  String get wallpaperUploadBrightness => 'चमक';

  @override
  String get wallpaperUploadCheckReviewStatus => 'समीक्षा की स्थिति देखें';

  @override
  String get wallpaperUploadChooseAnotherImage => 'दूसरी तस्वीर चुनें';

  @override
  String get wallpaperUploadContinueDraft => 'सेव किए गए वॉलपेपर का संपादन जारी रखें';

  @override
  String get wallpaperUploadContrast => 'कंट्रास्ट';

  @override
  String get wallpaperUploadCreateTitle => 'बनाएं';

  @override
  String get wallpaperUploadDeleteConfirmTitle => 'यह वॉलपेपर हटाएं?';

  @override
  String get wallpaperUploadDeleteError => 'हटाया नहीं जा सका। फिर कोशिश करें।';

  @override
  String get wallpaperUploadDeletePermissionError =>
      'हटाया नहीं जा सका। उसी खाते से साइन इन करें जिससे अपलोड किया था, फिर कोशिश करें।';

  @override
  String get wallpaperUploadDeleteWallpaper => 'वॉलपेपर हटाएं';

  @override
  String get wallpaperUploadDeleted => 'वॉलपेपर हटा दिया गया।';

  @override
  String get wallpaperUploadDetailsOptional => 'जानकारी (ज़रूरी नहीं)';

  @override
  String get wallpaperUploadDiscardBody => 'अपलोड की गई फ़ाइलें हटा दी जाएंगी। चुनी हुई तस्वीर आपके डिवाइस पर रहेगी।';

  @override
  String get wallpaperUploadDiscardEditsBody => 'आपके बदलाव खो जाएंगे।';

  @override
  String get wallpaperUploadDiscardEditsTitle => 'अपने बदलाव छोड़ें?';

  @override
  String get wallpaperUploadDiscardError => 'यह अपलोड छोड़ा नहीं जा सका। फिर कोशिश करें।';

  @override
  String get wallpaperUploadDiscardTitle => 'यह अपलोड छोड़ें?';

  @override
  String get wallpaperUploadDownloadError => 'डाउनलोड नहीं हो सका। फिर कोशिश करें।';

  @override
  String get wallpaperUploadDownloadStarting => 'डाउनलोड शुरू हो रहा है';

  @override
  String get wallpaperUploadDraftSaveError => 'यह ड्राफ़्ट सेव नहीं हो सका। फिर कोशिश करें।';

  @override
  String wallpaperUploadEditBatch(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString में से वॉलपेपर $positionString संपादित करें';
  }

  @override
  String get wallpaperUploadEditSaveError => 'आपके बदलाव सेव नहीं हो सके। फिर कोशिश करें।';

  @override
  String get wallpaperUploadFileSize => 'आकार';

  @override
  String get wallpaperUploadFilesCheckActive => 'वॉलपेपर और उसका प्रीव्यू अपलोड हो रहा है';

  @override
  String get wallpaperUploadFilesCheckDone => 'वॉलपेपर और प्रीव्यू अपलोड हो गए';

  @override
  String get wallpaperUploadFilesCheckPending => 'वॉलपेपर और उसका प्रीव्यू अपलोड करें';

  @override
  String get wallpaperUploadFilesRemoveError => 'अपलोड की गई फ़ाइलें हटाई नहीं जा सकीं। फिर कोशिश करें।';

  @override
  String get wallpaperUploadFlip => 'पलटें';

  @override
  String wallpaperUploadFreeQuotaMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'मुफ़्त उपयोगकर्ता हर हफ़्ते $countString वॉलपेपर अपलोड कर सकते हैं।';
  }

  @override
  String get wallpaperUploadFromGallery => 'गैलरी से';

  @override
  String get wallpaperUploadFullImageError => 'पूरी तस्वीर लोड नहीं हो सकी।';

  @override
  String get wallpaperUploadInReview => 'समीक्षा जारी है';

  @override
  String get wallpaperUploadKeepDraft => 'ड्राफ़्ट रखें';

  @override
  String get wallpaperUploadLeaveBody =>
      'बाद में जारी रखने के लिए ड्राफ़्ट रखें, या इसे छोड़कर अपलोड की गई फ़ाइलें हटाएं।';

  @override
  String get wallpaperUploadLeaveTitle => 'यह अपलोड छोड़ें?';

  @override
  String wallpaperUploadMaxTagsReached(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'आपने $countString टैग जोड़ दिए';
  }

  @override
  String get wallpaperUploadOriginalContentGuideline =>
      'केवल अपने बनाए हुए, उच्च गुणवत्ता वाले वॉलपेपर अपलोड करें। दूसरे ऐप्स की सामग्री अपलोड न करें।';

  @override
  String get wallpaperUploadPrepareCheckActive => 'आपकी तस्वीर और उसका छोटा प्रीव्यू तैयार हो रहा है';

  @override
  String get wallpaperUploadPrepareCheckDone => 'तस्वीर और प्रीव्यू तैयार हैं';

  @override
  String get wallpaperUploadPrepareCheckPending => 'अपनी तस्वीर और उसका छोटा प्रीव्यू तैयार करें';

  @override
  String get wallpaperUploadPrepareError => 'यह तस्वीर तैयार नहीं हो सकी। फिर कोशिश करें या दूसरी तस्वीर चुनें।';

  @override
  String get wallpaperUploadQualityLandscape =>
      'यह तस्वीर चौड़ी है। फ़ोन के वॉलपेपर पोर्ट्रेट आकार में बेहतर दिखते हैं।';

  @override
  String wallpaperUploadQualityLowResolution(int width, int height, int recommendedShortSide) {
    final intl.NumberFormat widthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String widthString = widthNumberFormat.format(width);
    final intl.NumberFormat recommendedShortSideNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String recommendedShortSideString = recommendedShortSideNumberFormat.format(recommendedShortSide);

    return 'इस तस्वीर का आकार ${widthString}x$height है। फ़ोन पर यह धुंधली दिख सकती है। छोटी तरफ़ $recommendedShortSideString px होना बेहतर है।';
  }

  @override
  String get wallpaperUploadQuotaCleanupFailed =>
      'आपकी अपलोड सीमा पूरी हो गई, लेकिन अपलोड की गई फ़ाइलें हटाई नहीं जा सकीं। उन्हें फिर हटाने के लिए वापस जाएं।';

  @override
  String get wallpaperUploadQuotaReached => 'इस हफ़्ते की मुफ़्त वॉलपेपर अपलोड सीमा पूरी हो गई है।';

  @override
  String wallpaperUploadQuotaRemaining(int remaining, int total) {
    final intl.NumberFormat remainingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'इस हफ़्ते $totalString में से $remainingString मुफ़्त अपलोड बाकी';
  }

  @override
  String get wallpaperUploadRejected => 'अस्वीकृत';

  @override
  String get wallpaperUploadRejectedSectionError => 'आपके अस्वीकृत सबमिशन लोड नहीं हो सके।';

  @override
  String get wallpaperUploadRejectionFallback =>
      'कोई खास वजह नहीं बताई गई। वॉलपेपर की जानकारी देखें, फिर दोबारा अपलोड करें।';

  @override
  String get wallpaperUploadRejectionTitle => 'इसे क्यों अस्वीकार किया गया';

  @override
  String wallpaperUploadRemoveTag(String tag) {
    return '$tag टैग हटाएं';
  }

  @override
  String get wallpaperUploadResetAdjustments => 'समायोजन रीसेट करें';

  @override
  String get wallpaperUploadResolution => 'रिज़ॉल्यूशन';

  @override
  String get wallpaperUploadResumeDraft => 'सेव किया गया अपलोड फिर शुरू करें';

  @override
  String get wallpaperUploadRetrySubmit => 'फिर सबमिट करें';

  @override
  String get wallpaperUploadReviewCheckActive => 'समीक्षा के लिए आपका सबमिशन सेव हो रहा है';

  @override
  String get wallpaperUploadReviewCheckDone => 'समीक्षा के लिए सबमिट किया गया';

  @override
  String get wallpaperUploadReviewCheckPending => 'Prism पर दिखने से पहले मॉडरेटर इसकी समीक्षा करेंगे';

  @override
  String get wallpaperUploadReviewEmptyBody => 'आपके अपलोड किए गए वॉलपेपर की समीक्षा स्थिति यहां दिखेगी।';

  @override
  String get wallpaperUploadReviewEmptyTitle => 'अभी यहां कुछ नहीं है';

  @override
  String get wallpaperUploadReviewLoadError => 'आपके अपलोड लोड नहीं हो सके';

  @override
  String get wallpaperUploadReviewSectionError => 'आपके सबमिशन लोड नहीं हो सके।';

  @override
  String get wallpaperUploadRotateLeft => 'बाएं घुमाएं';

  @override
  String get wallpaperUploadRotateRight => 'दाएं घुमाएं';

  @override
  String get wallpaperUploadSaturation => 'रंगों की गहराई';

  @override
  String get wallpaperUploadSavedToPictures => 'वॉलपेपर Pictures/Prism में सेव किया गया';

  @override
  String get wallpaperUploadSkip => 'यह वॉलपेपर छोड़ें';

  @override
  String get wallpaperUploadStagePrepareFailed => 'तस्वीर तैयार नहीं हो सकी';

  @override
  String get wallpaperUploadStagePreparing => 'वॉलपेपर तैयार हो रहा है';

  @override
  String get wallpaperUploadStageQuotaReached => 'अपलोड सीमा पूरी हो गई';

  @override
  String get wallpaperUploadStageReady => 'सबमिट करने के लिए तैयार';

  @override
  String get wallpaperUploadStageSubmissionFailed => 'सबमिशन पूरा नहीं हो सका';

  @override
  String get wallpaperUploadStageSubmitting => 'वॉलपेपर सबमिट हो रहा है';

  @override
  String get wallpaperUploadStageUploadFailed => 'अपलोड पूरा नहीं हो सका';

  @override
  String get wallpaperUploadStageUploading => 'वॉलपेपर अपलोड हो रहा है';

  @override
  String get wallpaperUploadSubmissionUnconfirmed =>
      'सबमिशन की पुष्टि नहीं हो सकी। फिर कोशिश करने से पहले समीक्षा स्थिति देखें।';

  @override
  String get wallpaperUploadTags => 'टैग';

  @override
  String wallpaperUploadTagsHelp(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'अधिकतम $countString। टैग से लोगों को आपका वॉलपेपर ढूंढने में मदद मिलती है।';
  }

  @override
  String get wallpaperUploadTitle => 'वॉलपेपर अपलोड करें';

  @override
  String get wallpaperUploadTitleHint => 'अपने वॉलपेपर का नाम लिखें';

  @override
  String get wallpaperUploadViewWallpaper => 'वॉलपेपर देखें';

  @override
  String get wallpaperUploadYourUploads => 'आपके अपलोड';

  @override
  String get wallpaperUsePhoneAccent => 'अपने फ़ोन का ऐक्सेंट रंग इस्तेमाल करें';

  @override
  String get wallpaperThemeMaterialYouNote => 'मटीरियल यू आपके वॉलपेपर से रंग लेता है।';

  @override
  String wallpaperViewCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString बार देखा गया',
      one: '$countString बार देखा गया',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperViewCountUnavailable => 'देखे जाने की गिनती उपलब्ध नहीं';

  @override
  String wallpaperWotdByPhotographer(String name) {
    return 'आज का वॉलपेपर, $name द्वारा';
  }

  @override
  String get economyAiPromptSceneAnime1 => 'धूप वाले रेलवे प्लेटफ़ॉर्म पर सोती बिल्ली';

  @override
  String get economyAiPromptSceneAnime2 => 'धान के खेतों पर उठते गर्मियों के विशाल बादल';

  @override
  String get economyAiPromptSceneAnime3 => 'बारिश वाली गली में चमकता रेमन का ठेला';

  @override
  String get economyAiPromptSceneAnime4 => 'बादलों के सागर के ऊपर पहाड़ी का मंदिर-द्वार';

  @override
  String get economyAiPromptSceneAnime5 => 'गर्मी के मेले में नदी पर आतिशबाज़ी';

  @override
  String get economyAiPromptSceneAnime6 => 'शांत कक्षा में उड़कर आती फूलों की पंखुड़ियाँ';

  @override
  String get economyAiPromptSceneAnime7 => 'शाम को सागर किनारे सड़क पर अकेला बस स्टॉप';

  @override
  String get economyAiPromptSceneAnime8 => 'सोते शहर के ऊपर तैरती आसमानी व्हेल';

  @override
  String get economyAiPromptSceneMinimal1 => 'शांत हल्के पानी पर एक अकेली काग़ज़ की नाव';

  @override
  String get economyAiPromptSceneMinimal2 => 'खाली मैदान के ऊपर रोशनी की एक मेहराब';

  @override
  String get economyAiPromptSceneMinimal3 => 'बर्फ़ीली ढलान पर अकेला पेड़';

  @override
  String get economyAiPromptSceneMinimal4 => 'दानेदार पृष्ठभूमि पर दो कटते हुए गोले';

  @override
  String get economyAiPromptSceneMinimal5 => 'समुद्र और आकाश को बाँटती पतली क्षितिज-रेखा';

  @override
  String get economyAiPromptSceneMinimal6 => 'खाली आकाश से गिरता एक अकेला पंख';

  @override
  String get economyAiPromptSceneMinimal7 => 'हल्की पृष्ठभूमि पर रखे चिकने कंकड़ों का ढेर';

  @override
  String get economyAiPromptSceneMinimal8 => 'मुलायम प्लास्टर की दीवार पर अर्धचंद्र जैसी छाया';

  @override
  String get economyAiPromptSceneCyberpunk1 => 'नियॉन रोशनी में बारिश से भीगा नूडल बार';

  @override
  String get economyAiPromptSceneCyberpunk2 => 'गगनचुंबी मीनारों के बीच दौड़ती हवाई ट्रेन';

  @override
  String get economyAiPromptSceneCyberpunk3 => 'बारिश में छत पर खड़ा अकेला एंड्रॉयड';

  @override
  String get economyAiPromptSceneCyberpunk4 => 'विशाल शहर की ओर जाता चमकता डेटा हाईवे';

  @override
  String get economyAiPromptSceneCyberpunk5 => 'उलझे तारों के नीचे सजा रात का बाज़ार';

  @override
  String get economyAiPromptSceneCyberpunk6 => 'नियॉन गली में खड़ी क्रोम मोटरबाइक';

  @override
  String get economyAiPromptSceneCyberpunk7 => 'शहर की मीनारों के ऊपर उगता होलोग्राम चाँद';

  @override
  String get economyAiPromptSceneCyberpunk8 => 'स्क्रीनों की दीवार को झलकाती पानी भरी सड़क';

  @override
  String get economyAiPromptSceneWatercolor1 => 'सुबह की धुंध में घुलता लैवेंडर का खेत';

  @override
  String get economyAiPromptSceneWatercolor2 => 'शांत बंदरगाह के पास मछुआरों का छोटा गाँव';

  @override
  String get economyAiPromptSceneWatercolor3 => 'देहाती पगडंडी के किनारे झूमते जंगली पोस्त';

  @override
  String get economyAiPromptSceneWatercolor4 => 'हरी नरम पहाड़ियों के ऊपर गर्म हवा का गुब्बारा';

  @override
  String get economyAiPromptSceneWatercolor5 => 'सरकंडों वाले तालाब में खड़ा बगुला';

  @override
  String get economyAiPromptSceneWatercolor6 => 'धुंधले लैंप वाली बारिश में भीगी शहर की सड़क';

  @override
  String get economyAiPromptSceneWatercolor7 => 'खुली खिड़की के पास भाप उड़ाता चाय का प्याला';

  @override
  String get economyAiPromptSceneWatercolor8 => 'जमी टेढ़ी धारा के किनारे बर्फ़ से ढके चीड़';

  @override
  String get economyAiPromptSceneMeshGradient1 => 'एक-दूसरे में घुलते मुलायम रंगों के धब्बे';

  @override
  String get economyAiPromptSceneMeshGradient2 => 'खुद पर मुड़ती रेशमी ग्रेडिएंट लहर';

  @override
  String get economyAiPromptSceneMeshGradient3 => 'मखमली पृष्ठभूमि पर घुलते चमकते गोले';

  @override
  String get economyAiPromptSceneMeshGradient4 => 'ऊपर की ओर फैलता ऑरोरा जैसा ग्रेडिएंट';

  @override
  String get economyAiPromptSceneMeshGradient5 => 'बारीक दानों वाले रंगों के तरल कुंड';

  @override
  String get economyAiPromptSceneMeshGradient6 => 'हल्के नॉइज़ वाला गर्म से ठंडा ग्रेडिएंट';

  @override
  String get economyAiPromptSceneMeshGradient7 => 'एक-दूसरे पर चढ़ी पारदर्शी ग्रेडिएंट पंखुड़ियाँ';

  @override
  String get economyAiPromptSceneMeshGradient8 => 'बहते रंगीन पट्टों वाला धुंधला सूर्यास्त';

  @override
  String get economyAiPromptSceneAbstract1 => 'रोशनी पकड़ते आपस में फँसे काँच के टुकड़े';

  @override
  String get economyAiPromptSceneAbstract2 => 'पानी में तैरते स्याही के बहते बादल';

  @override
  String get economyAiPromptSceneAbstract3 => 'गति में मुड़े रिबनों का सर्पिल';

  @override
  String get economyAiPromptSceneAbstract4 => 'सुनहरी धारियों वाला टूटा संगमरमर';

  @override
  String get economyAiPromptSceneAbstract5 => 'परतों में लहराती भू-आकृति रेखाएँ';

  @override
  String get economyAiPromptSceneAbstract6 => 'लंबी छायाएँ डालते तैरते गोले';

  @override
  String get economyAiPromptSceneAbstract7 => 'भँवर में घूमती धुएँ की लकीरें';

  @override
  String get economyAiPromptSceneAbstract8 => 'लहरों में उठता मुलायम घनों का मैदान';

  @override
  String get economyAiPromptSceneNature1 => 'काई भरी घाटी में गिरता झरना';

  @override
  String get economyAiPromptSceneNature2 => 'विशाल आकाश तले सूरजमुखी का खेत';

  @override
  String get economyAiPromptSceneNature3 => 'नीली बर्फ़ की दरारों वाली जमी झील';

  @override
  String get economyAiPromptSceneNature4 => 'शांत नदी-पथ के किनारे चेरी के पेड़';

  @override
  String get economyAiPromptSceneNature5 => 'ऊपर से दिखती उष्णकटिबंधीय लैगून';

  @override
  String get economyAiPromptSceneNature6 => 'शांत तालाब में झलकते पतझड़ के मेपल';

  @override
  String get economyAiPromptSceneNature7 => 'भोर में ताज़ा बर्फ़ पर अकेली लोमड़ी';

  @override
  String get economyAiPromptSceneNature8 => 'हरे ऊँचे इलाकों पर घिरते तूफ़ानी बादल';

  @override
  String get economyAiPromptSceneSpace1 => 'चाँद के क्षितिज पर उगता छल्लेदार ग्रह';

  @override
  String get economyAiPromptSceneSpace2 => 'गहरे अंतरिक्ष में चमकती सर्पिल आकाशगंगा';

  @override
  String get economyAiPromptSceneSpace3 => 'नीले ग्रह के ऊपर तैरता अंतरिक्ष यात्री';

  @override
  String get economyAiPromptSceneSpace4 => 'खिलते फूल जैसी आकृति वाली नेबुला';

  @override
  String get economyAiPromptSceneSpace5 => 'परग्रही रेगिस्तान पर डूबते दो सूरज';

  @override
  String get economyAiPromptSceneSpace6 => 'गैस जायंट की परिक्रमा करता अंतरिक्ष स्टेशन';

  @override
  String get economyAiPromptSceneSpace7 => 'शांत वेधशाला के ऊपर उल्कापात';

  @override
  String get economyAiPromptSceneSpace8 => 'चमकती हीरे की अँगूठी वाला ग्रहण';

  @override
  String get economyAiPromptSceneSynthwave1 => 'सूर्यास्त की ओर दौड़ती नियॉन ग्रिड वाली सड़क';

  @override
  String get economyAiPromptSceneSynthwave2 => 'धारीदार सूरज के नीचे ताड़ों वाला तट';

  @override
  String get economyAiPromptSceneSynthwave3 => 'अंतहीन हाईवे पर रेट्रो स्पोर्ट्स कार';

  @override
  String get economyAiPromptSceneSynthwave4 => 'मैजेंटा आकाश तले वायरफ़्रेम पहाड़';

  @override
  String get economyAiPromptSceneSynthwave5 => 'चमकते समुद्र में डूबता क्रोम सूरज';

  @override
  String get economyAiPromptSceneSynthwave6 => 'बारिश की रात में चमकता रेट्रो आर्केड';

  @override
  String get economyAiPromptSceneSynthwave7 => 'नियॉन अंतरिक्ष में तैरता कैसेट टेप';

  @override
  String get economyAiPromptSceneSynthwave8 => 'लेज़र क्षितिज के सामने अकेला ताड़ का पेड़';

  @override
  String get economyAiPromptScenePixelArt1 => 'रात में बर्फ़ीले जंगल की आरामदेह झोपड़ी';

  @override
  String get economyAiPromptScenePixelArt2 => 'समुद्र के ऊपर चट्टान पर बना क़िला';

  @override
  String get economyAiPromptScenePixelArt3 => 'चमकती खिड़कियों वाला छोटा सा क़स्बा';

  @override
  String get economyAiPromptScenePixelArt4 => 'बैंगनी परग्रही दुनिया के ऊपर अंतरिक्ष यान';

  @override
  String get economyAiPromptScenePixelArt5 => 'हरी-भरी जंगल घाटी में झरना';

  @override
  String get economyAiPromptScenePixelArt6 => 'पूर्णिमा की रात में मछली पकड़ने का घाट';

  @override
  String get economyAiPromptScenePixelArt7 => 'वसंत में चेरी ब्लॉसम से घिरा मंदिर';

  @override
  String get economyAiPromptScenePixelArt8 => 'सूर्यास्त के समय पुल पार करती ट्रेन';

  @override
  String get economyAiPromptSceneRender3d1 => 'संतुलन में टिकी चमकदार क्ले की आकृतियाँ';

  @override
  String get economyAiPromptSceneRender3d2 => 'पेस्टल मंच पर धुंधले काँच के रिबन';

  @override
  String get economyAiPromptSceneRender3d3 => 'मुलायम बादल पर तैरता छोटा सा द्वीप';

  @override
  String get economyAiPromptSceneRender3d4 => 'मुलायम रोशनी में फूले हुए क्रोम बुलबुले';

  @override
  String get economyAiPromptSceneRender3d5 => 'अकेले कैक्टस वाला छोटा सा रेगिस्तान';

  @override
  String get economyAiPromptSceneRender3d6 => 'घन के भीतर बना आरामदेह कमरे का डायोरमा';

  @override
  String get economyAiPromptSceneRender3d7 => 'शांत पानी के ऊपर तैरती संगमरमर की मेहराबें';

  @override
  String get economyAiPromptSceneRender3d8 => 'गति में जमी कैंडी-रंग की लहरें';

  @override
  String get economyAiPromptSceneOilPainting1 => 'चट्टानी तट से टकराता तूफ़ानी समुद्र';

  @override
  String get economyAiPromptSceneOilPainting2 => 'धूप में नहाया पोस्त का मैदान और फार्महाउस';

  @override
  String get economyAiPromptSceneOilPainting3 => 'नींबुओं और नीले गुलदान की स्टिल लाइफ़';

  @override
  String get economyAiPromptSceneOilPainting4 => 'भोर की धुंध में पुराने जहाज़ों वाला बंदरगाह';

  @override
  String get economyAiPromptSceneOilPainting5 => 'पतझड़ के रंगों से दहकती जंगल की पगडंडी';

  @override
  String get economyAiPromptSceneOilPainting6 => 'पुराने घरों से घिरी चाँदनी में नहाई नहर';

  @override
  String get economyAiPromptSceneOilPainting7 => 'तूफ़ान से पहले लहराता गेहूँ का खेत';

  @override
  String get economyAiPromptSceneOilPainting8 => 'अँधेरी मेज़ पर गिलास में रखा एक गुलाब';

  @override
  String get economyAiPromptSceneUkiyoE1 => 'हल्के चाँद के नीचे मुड़ती विशाल लहर';

  @override
  String get economyAiPromptSceneUkiyoE2 => 'साँझ में बर्फ़ से ढका पैगोडा';

  @override
  String get economyAiPromptSceneUkiyoE3 => 'धुंध भरे पहाड़ के ऊपर उड़ते सारस';

  @override
  String get economyAiPromptSceneUkiyoE4 => 'झरती चेरी पंखुड़ियों के नीचे लकड़ी का पुल';

  @override
  String get economyAiPromptSceneUkiyoE5 => 'उफनते नील-नीले समुद्र में मछली पकड़ने की नावें';

  @override
  String get economyAiPromptSceneUkiyoE6 => 'ज्वालामुखी शिखर के ऊपर लाल सूरज';

  @override
  String get economyAiPromptSceneUkiyoE7 => 'झुके विलो तले मछलियों वाला तालाब';

  @override
  String get economyAiPromptSceneUkiyoE8 => 'शांत नदी किनारे के क़स्बे पर बरसती बारिश';

  @override
  String get economyAiPromptLightingMorningHaze => 'सुबह की हल्की धुंध';

  @override
  String get economyAiPromptLightingGoldenHour => 'सुनहरी शाम की चमक';

  @override
  String get economyAiPromptLightingMoonlight => 'ठंडी चाँदनी';

  @override
  String get economyAiPromptLightingNeonRim => 'नियॉन किनारी रोशनी';

  @override
  String get economyAiPromptLightingBacklight => 'गर्म बैकलाइट';

  @override
  String get economyAiPromptLightingGodRays => 'कोमल सूर्य-किरणें';

  @override
  String get economyAiPromptLightingStudio => 'समान स्टूडियो लाइट';

  @override
  String get economyAiPromptLightingTwilight => 'गहरी नीली साँझ';

  @override
  String get economyAiPromptPaletteTealAmber => 'टील और एम्बर रंग';

  @override
  String get economyAiPromptPaletteIndigoRose => 'नील और गुलाबी रंग';

  @override
  String get economyAiPromptPaletteSageCream => 'सेज हरा और क्रीम';

  @override
  String get economyAiPromptPaletteBlackNeonPink => 'काला और नियॉन गुलाबी';

  @override
  String get economyAiPromptPalettePastelPeach => 'हल्का पेस्टल आड़ू रंग';

  @override
  String get economyAiPromptPaletteEmeraldGold => 'पन्ना हरा और सुनहरा';

  @override
  String get economyAiPromptPaletteOceanBlue => 'सागर-नीले के शेड्स';

  @override
  String get economyAiPromptPaletteCrimsonCharcoal => 'गहरा लाल और कोयला';

  @override
  String get economyAiPromptSuffix => 'मोबाइल पोर्ट्रेट वॉलपेपर, बिना टेक्स्ट';

  @override
  String economyAiPromptComposition(String scene, String lighting, String palette, String suffix) {
    return '$scene, $lighting, $palette। $suffix';
  }

  @override
  String economyAiPromptSceneOnly(String scene, String suffix) {
    return '$scene, $suffix';
  }

  @override
  String get economyAiMadeWithPrism => 'Prism AI से बनाया गया';

  @override
  String get onboardingAiPromptFallback => 'एक सुंदर वॉलपेपर';

  @override
  String get onboardingAiPromptNature1 => 'भोर में हिमनद झील: दर्पण-सा शांत पानी, गुलाबी पर्वत शिखर';

  @override
  String get onboardingAiPromptNature2 => 'काई से ढकी जंगल की धारा, ऊँचे फ़र्न से छनती कोमल रोशनी';

  @override
  String get onboardingAiPromptNature3 => 'शाम के विशाल आकाश तले जंगली फूलों का मैदान, तैरते बादल';

  @override
  String get onboardingAiPromptNature4 => 'साँझ में काली रेत का तट, फ़िरोज़ी लहरें और समुद्री चट्टानें';

  @override
  String get onboardingAiPromptNature5 => 'जमी झील के पास बर्फ़ीले चीड़ वन पर उत्तरी रोशनी';

  @override
  String get onboardingAiPromptAbstract1 => 'कोमल रोशनी में मुड़ते पारदर्शी काँच के रिबन, इंद्रधनुषी किनारे';

  @override
  String get onboardingAiPromptAbstract2 => 'पानी में खिलते स्याही के बादल, गहरे नीले और सुनहरे रंग में';

  @override
  String get onboardingAiPromptAbstract3 => 'गर्म सूर्यास्त रंगों में कागज़ जैसी परतदार लहरें, हल्की छायाएँ';

  @override
  String get onboardingAiPromptAbstract4 => 'गहरे कोयले रंग की पृष्ठभूमि पर सुनहरी धारियों वाला संगमरमर-भँवर';

  @override
  String get onboardingAiPromptAbstract5 => 'खुले शांत आकाश में पेस्टल आसमान झलकाते तैरते क्रोम गोले';

  @override
  String get onboardingAiPromptWatercolor1 => 'सूर्योदय में पेस्टल घरों और नावों वाला वॉटरकलर तटीय गाँव';

  @override
  String get onboardingAiPromptWatercolor2 => 'खुरदरे कागज़ पर गुलाबी और सेज रंग के वॉटरकलर जंगली फूल';

  @override
  String get onboardingAiPromptWatercolor3 => 'छोटे लकड़ी के घाट और दूर पहाड़ियों वाली धुंधली वॉटरकलर झील';

  @override
  String get onboardingAiPromptWatercolor4 => 'बैंगनी बादलों और चमकते चाँद वाला वॉटरकलर रात का आकाश';

  @override
  String get onboardingAiPromptWatercolor5 => 'नारंगी और सुनहरे गर्म रंगों में वॉटरकलर पतझड़ का जंगल';

  @override
  String get onboardingAiPromptMinimal1 => 'शांत समुद्र पर डूबता एक सूरज, सपाट रंग, खुला खाली आकाश';

  @override
  String get onboardingAiPromptMinimal2 => 'हल्के ग्रेडिएंट आकाश तले रेत-रंग की परतदार पहाड़ियाँ';

  @override
  String get onboardingAiPromptMinimal3 => 'बर्फ़ीली पहाड़ी पर एक नंगा पेड़, चारों ओर शांत खाली जगह';

  @override
  String get onboardingAiPromptMinimal4 => 'भोर में शांत झील पर अकेली नाव, सरल आकृतियाँ, कोमल रंग';

  @override
  String get onboardingAiPromptMinimal5 => 'टेराकोटा और क्रीम रंग की कोमल संकेंद्रित मेहराबें, बारीक दाने';

  @override
  String get onboardingAiPromptAnime1 => 'ऐनिमे गर्मी का आकाश: शांत समुद्री रेलवे पर उठते विशाल बादल';

  @override
  String get onboardingAiPromptAnime2 => 'पहाड़ी से दिखता ऐनिमे रात का शहर, गर्म बत्तियाँ, तारों भरा आकाश';

  @override
  String get onboardingAiPromptAnime3 => 'ऐनिमे जंगल का मंदिर, हरी रोशनी में तैरती चमकती आत्माएँ';

  @override
  String get onboardingAiPromptAnime4 => 'साँझ की बारिश वाली ऐनिमे गली, दुकानों की रोशनी, पानी में झलक';

  @override
  String get onboardingAiPromptAnime5 => 'सुनहरी घड़ी में ऐनिमे घास का मैदान, लंबी घास में दौड़ती हवा';

  @override
  String get onboardingAiPromptMeshGradient1 => 'नारंगी, गुलाबी और बैंगनी रंगों का चिकना मेश ग्रेडिएंट, हल्के दाने';

  @override
  String get onboardingAiPromptMeshGradient2 => 'नेवी और टील का गहरा मेश ग्रेडिएंट, चमकता नींबू-हरा हाइलाइट';

  @override
  String get onboardingAiPromptMeshGradient3 => 'आसमानी, लैवेंडर और गर्म क्रीम रंग का कोमल मेश ग्रेडिएंट';

  @override
  String get onboardingAiPromptMeshGradient4 => 'रेशम-सा बहता गहरे लाल और सुनहरे रंग का चटख मेश ग्रेडिएंट';

  @override
  String get onboardingAiPromptMeshGradient5 => 'सेज, पुदीना और हल्की रेत का शांत मेश ग्रेडिएंट, कोमल रोशनी';

  @override
  String get onboardingAiPromptCyberpunk1 => 'बारिश में भीगी साइबरपंक रात की गली, नियॉन प्रतिबिंब और भाप';

  @override
  String get onboardingAiPromptCyberpunk2 => 'छत से दिखता गगनचुंबी नियॉन शहर, पास से गुज़रती उड़ती कारें';

  @override
  String get onboardingAiPromptCyberpunk3 => 'चमकती दुकानों और तैरती लालटेनों वाली शांत साइबरपंक नहर';

  @override
  String get onboardingAiPromptCyberpunk4 => 'भोर का साइबरपंक क्षितिज, गुलाबी-टील धुंध में काँच की मीनारें';

  @override
  String get onboardingAiPromptCyberpunk5 => 'धुंध भरे भविष्यवादी शहर के नियॉन पुल पर अकेली मोटरबाइक';

  @override
  String get onboardingAiPromptSpace1 => 'पथरीले चाँद के ऊपर उगता छल्लेदार गैस जायंट, काले आकाश में तारे';

  @override
  String get onboardingAiPromptSpace2 => 'बैंगनी और टील रंग की रंगीन नेबुला, चमकीले नए तारे';

  @override
  String get onboardingAiPromptSpace3 => 'सामने से दिखती सर्पिल आकाशगंगा, चमकता केंद्र, धूलभरी नीली भुजाएँ';

  @override
  String get onboardingAiPromptSpace4 => 'सूर्योदय में पृथ्वी के ऊपर तैरता अंतरिक्ष यात्री, पतला नीला वायुमंडल';

  @override
  String get onboardingAiPromptSpace5 => 'शांत पर्वतमाला के ऊपर पूर्ण सूर्यग्रहण';

  @override
  String get onboardingAiPromptSynthwave1 => 'धारीदार सूरज और चमकती नियॉन ग्रिड वाला सिंथवेव सूर्यास्त';

  @override
  String get onboardingAiPromptSynthwave2 => 'सुनसान तटीय सड़क पर मैजेंटा सूरज की ओर जाती रेट्रो कार';

  @override
  String get onboardingAiPromptSynthwave3 => 'तारों भरे बैंगनी आकाश तले वायरफ़्रेम पहाड़ और क्रोम सूरज';

  @override
  String get onboardingAiPromptSynthwave4 => 'ताड़ की छायाओं और चमकते गुलाबी क्षितिज वाला सिंथवेव तट';

  @override
  String get onboardingAiPromptSynthwave5 => 'गुलाबी और सियान नियॉन धुंध में रात का रेट्रो शहर क्षितिज';

  @override
  String get onboardingAiPromptPixelArt1 => 'रात में बर्फ़ीले जंगल की पिक्सेल आर्ट झोपड़ी, खिड़कियों में गर्म रोशनी';

  @override
  String get onboardingAiPromptPixelArt2 => 'सूर्यास्त में बंदरगाह की नावों वाला पिक्सेल आर्ट तटीय क़स्बा';

  @override
  String get onboardingAiPromptPixelArt3 => 'बादलों के ऊपर तैरते द्वीप पर पिक्सेल आर्ट क़िला';

  @override
  String get onboardingAiPromptPixelArt4 => 'जुगनुओं वाली शांत झील पर पिक्सेल आर्ट रात का आकाश';

  @override
  String get onboardingAiPromptPixelArt5 => 'छोटे मंदिर तक जाती चेरी ब्लॉसम की पिक्सेल आर्ट पगडंडी';

  @override
  String get onboardingAiPromptRender3d1 => 'कोमल छायाओं वाली पेस्टल क्ले आकृतियों का 3D रेंडर';

  @override
  String get onboardingAiPromptRender3d2 => 'झरने और पेड़ों वाले छोटे तैरते द्वीप का 3D रेंडर';

  @override
  String get onboardingAiPromptRender3d3 => 'स्टूडियो लाइट में नीली-बैंगनी चमकदार काँच की लहरों का 3D रेंडर';

  @override
  String get onboardingAiPromptRender3d4 => 'चमकते घन के भीतर आरामदेह छोटे कमरे का 3D रेंडर';

  @override
  String get onboardingAiPromptRender3d5 => 'शांत गुलाबी समुद्र पर तैरते क्रोम बुलबुलों का 3D रेंडर';

  @override
  String get onboardingAiPromptOilPainting1 => 'नाटकीय आकाश तले छोटे जहाज़ वाले तूफ़ानी समुद्र की ऑयल पेंटिंग';

  @override
  String get onboardingAiPromptOilPainting2 => 'दूर फार्महाउस वाले धूप भरे पोस्त खेत की ऑयल पेंटिंग';

  @override
  String get onboardingAiPromptOilPainting3 => 'भोर की धुंध में पुरानी लकड़ी की नावों वाले बंदरगाह की ऑयल पेंटिंग';

  @override
  String get onboardingAiPromptOilPainting4 => 'गाढ़े, समृद्ध ब्रश स्ट्रोक में पतझड़ की जंगल पगडंडी की ऑयल पेंटिंग';

  @override
  String get onboardingAiPromptOilPainting5 => 'गर्म चमकती खिड़कियों वाले चाँदनी में नहाए नहर-क़स्बे की ऑयल पेंटिंग';

  @override
  String get onboardingAiPromptUkiyoE1 => 'हल्के चाँद तले विशाल लहर, दूर बर्फ़ीला पर्वत, उकियो-ए शैली';

  @override
  String get onboardingAiPromptUkiyoE2 => 'चमकती कागज़ी लालटेनों वाला रात का बर्फ़ीला गाँव, उकियो-ए';

  @override
  String get onboardingAiPromptUkiyoE3 => 'भोर में धुंध भरे पहाड़ों पर उड़ते सारस, उकियो-ए दृश्य';

  @override
  String get onboardingAiPromptUkiyoE4 => 'वसंत के दिन चेरी ब्लॉसम तले लकड़ी का पुल, उकियो-ए';

  @override
  String get onboardingAiPromptUkiyoE5 => 'शांत नील-नीले समुद्र पर लाल सूरज, छोटी नावें, उकियो-ए';

  @override
  String wallpaperWotdByline(String name) {
    return '$name द्वारा';
  }

  @override
  String get wallpaperWotdPastPicks => 'पिछले चुने हुए वॉलपेपर';

  @override
  String wallpaperWotdPickedOn(String wallpaper, String date) {
    return '$wallpaper, $date को चुना गया';
  }

  @override
  String get wallpaperWotdSeePast => 'पिछले चुने गए वॉलपेपर देखें';

  @override
  String get wallpaperWotdTitle => 'आज का वॉलपेपर';

  @override
  String get wallpaperYourProfile => 'आपकी प्रोफ़ाइल';

  @override
  String get widgetsSettingsTitle => 'विजेट';

  @override
  String get widgetsSettingsSubtitle => 'Prism को अपनी होम स्क्रीन और लॉक स्क्रीन पर जोड़ें';

  @override
  String get widgetsGuideTitle => 'Prism विजेट जोड़ें';

  @override
  String get widgetsGuideHomeTab => 'होम स्क्रीन';

  @override
  String get widgetsGuideLockTab => 'लॉक स्क्रीन';

  @override
  String get widgetsGuideHomeStep1 => 'होम स्क्रीन की किसी खाली जगह को तब तक दबाकर रखें जब तक ऐप्स हिलने न लगें।';

  @override
  String get widgetsGuideHomeStep2 => 'संपादित करें पर टैप करें, फिर विजेट जोड़ें पर टैप करें।';

  @override
  String get widgetsGuideHomeStep3 => 'Prism खोजें, एक साइज़ चुनें, फिर विजेट जोड़ें पर टैप करें।';

  @override
  String get widgetsGuideLockStep1 => 'लॉक स्क्रीन को दबाकर रखें, फिर कस्टमाइज़ करें पर टैप करें।';

  @override
  String get widgetsGuideLockStep2 => 'लॉक स्क्रीन पर टैप करें, फिर घड़ी के नीचे विजेट वाली जगह पर टैप करें।';

  @override
  String get widgetsGuideLockStep3 => 'Prism चुनें, फिर जोड़ने के लिए किसी विजेट पर टैप करें।';

  @override
  String get widgetsGuideHomeIllustration => 'होम स्क्रीन पर आज के वॉलपेपर विजेट वाला फ़ोन';

  @override
  String get widgetsGuideLockIllustration => 'लॉक स्क्रीन पर Prism विजेट वाला फ़ोन';

  @override
  String get widgetsGuideDone => 'हो गया';

  @override
  String get widgetsCardTitle => 'आज का वॉलपेपर आपकी होम स्क्रीन पर';

  @override
  String get widgetsCardBody => 'विजेट जोड़ें और हर दिन नया वॉलपेपर देखें।';

  @override
  String get widgetsCardAction => 'तरीका दिखाएँ';

  @override
  String get widgetsCardDismiss => 'हटाएँ';

  @override
  String get foldersTitle => 'फ़ोल्डर';

  @override
  String get foldersSaveToFolder => 'फ़ोल्डर में सहेजें';

  @override
  String get foldersAddToFolder => 'फ़ोल्डर में जोड़ें';

  @override
  String get foldersNewFolder => 'नया फ़ोल्डर';

  @override
  String get foldersNameHint => 'फ़ोल्डर का नाम';

  @override
  String get foldersCreate => 'बनाएँ';

  @override
  String get foldersCreateFolder => 'फ़ोल्डर बनाएँ';

  @override
  String get foldersSuggested => 'सुझाया गया';

  @override
  String get foldersNewTag => 'नया';

  @override
  String foldersItemCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString वॉलपेपर',
      one: '1 वॉलपेपर',
      zero: 'कोई वॉलपेपर नहीं',
    );
    return '$_temp0';
  }

  @override
  String foldersSavedToCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ोल्डरों में सहेजा गया।',
      one: '1 फ़ोल्डर में सहेजा गया।',
    );
    return '$_temp0';
  }

  @override
  String get foldersUpdated => 'फ़ोल्डर अपडेट किए गए।';

  @override
  String get foldersSaveFailed => 'फ़ोल्डरों में सहेजा नहीं जा सका। फिर से कोशिश करें।';

  @override
  String get foldersUpdateFailed => 'फ़ोल्डर अपडेट नहीं हो सका। फिर से कोशिश करें।';

  @override
  String get foldersRename => 'नाम बदलें';

  @override
  String get foldersRenameTitle => 'फ़ोल्डर का नाम बदलें';

  @override
  String get foldersDelete => 'हटाएँ';

  @override
  String foldersDeleteTitle(String name) {
    return '$name हटाएँ?';
  }

  @override
  String get foldersDeleteMessage => 'वॉलपेपर आपके पसंदीदा में रहेंगे।';

  @override
  String get foldersDeleteConfirm => 'फ़ोल्डर हटाएँ';

  @override
  String get foldersDeleted => 'फ़ोल्डर हटा दिया गया।';

  @override
  String get foldersRemoveTitle => 'इस फ़ोल्डर से हटाएँ?';

  @override
  String get foldersRemoveMessage => 'यह आपके पसंदीदा में रहेगा।';

  @override
  String get foldersRemoveConfirm => 'हटाएँ';

  @override
  String get foldersRemoved => 'फ़ोल्डर से हटा दिया गया।';

  @override
  String get foldersEmptyTitle => 'यह फ़ोल्डर खाली है';

  @override
  String get foldersEmptyBody => 'यहाँ सहेजने के लिए किसी वॉलपेपर पर दिल के निशान को दबाए रखें।';

  @override
  String get foldersLoadError => 'यह फ़ोल्डर लोड नहीं हो सका।';

  @override
  String get foldersNotFoundTitle => 'यह फ़ोल्डर उपलब्ध नहीं है';

  @override
  String get foldersNotFoundBody => 'हो सकता है इसे हटा दिया गया हो।';

  @override
  String get foldersSignInFeature => 'फ़ोल्डर';

  @override
  String get foldersMoreOptions => 'और विकल्प';

  @override
  String get foldersSuggestionLockScreen => 'लॉक स्क्रीन';

  @override
  String get foldersSuggestionHomeScreen => 'होम स्क्रीन';

  @override
  String get moodDreamyTitle => 'स्वप्निल';

  @override
  String get moodDreamyBody => 'नरम आसमान और पेस्टल रोशनी।';

  @override
  String get moodDarkQuietTitle => 'गहरा और शांत';

  @override
  String get moodDarkQuietBody => 'कम रोशनी, आँखों के लिए आरामदेह।';

  @override
  String get moodBrightBoldTitle => 'चटक और बोल्ड';

  @override
  String get moodBrightBoldBody => 'स्क्रीन को जगाने वाला भरपूर रंग।';

  @override
  String get moodMinimalTitle => 'मिनिमल';

  @override
  String get moodMinimalBody => 'सरल आकार और खुली जगह।';

  @override
  String get moodSpatialReadyTitle => 'स्पेशियल सीन के लिए तैयार';

  @override
  String get moodSpatialReadyBody => 'स्पेशियल सीन के रूप में खास दिखने के लिए बना।';

  @override
  String get moodDepthReadyTitle => 'डेप्थ इफ़ेक्ट के लिए तैयार';

  @override
  String get moodDepthReadyBody => 'विषय आपकी लॉक स्क्रीन की घड़ी के आगे आ जाता है।';

  @override
  String get moodChipRowLabel => 'मूड';

  @override
  String get moodSeeAll => 'सब देखें';

  @override
  String moodSeeAllHint(String mood) {
    return '$mood के सभी वॉलपेपर खोलता है';
  }

  @override
  String get moodLoadError => 'ये वॉलपेपर लोड नहीं हो सके';

  @override
  String get moodEmptyTitle => 'यहाँ अभी कोई वॉलपेपर नहीं है';

  @override
  String get moodEmptyBody => 'हर दिन नए वॉलपेपर जुड़ते हैं।';

  @override
  String wallpaperHistoryTileSemantic(String current, String target, String date) {
    return '$currentफिर से लगाएँ। $target, $date';
  }

  @override
  String get wallpaperHistoryTitle => 'वॉलपेपर इतिहास';

  @override
  String get wallpaperLibraryHistoryBody => 'आपके लगाए हुए वॉलपेपर, ताकि आप उन्हें फिर से लगा सकें।';

  @override
  String get wallpaperLibraryHistoryTitle => 'वॉलपेपर इतिहास';

  @override
  String get wallpaperLibraryOpenHistory => 'इतिहास खोलें';

  @override
  String get wallpaperRecentlySet => 'हाल ही में सेट किए गए';

  @override
  String get wallpaperSetAgain => 'यह वॉलपेपर फिर से सेट करें';

  @override
  String get wallpaperSort => 'क्रमबद्ध करें';

  @override
  String get tasteQuizTitle => 'जो आपको ज़्यादा पसंद हो, उसे चुनें';

  @override
  String get tasteQuizWildCard => 'वाइल्ड कार्ड';

  @override
  String tasteQuizProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString में से $currentString';
  }

  @override
  String tasteQuizProgressLabel(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'कुल $totalString में से राउंड $currentString';
  }

  @override
  String get tasteQuizSkip => 'छोड़ें';

  @override
  String tasteQuizPickLabel(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'यह वॉलपेपर चुनें, कुल $totalString में से $positionString';
  }

  @override
  String get tasteQuizTuningTitle => 'आपकी फ़ीड सेट हो रही है';

  @override
  String tasteQuizSummaryFull(String tone, String density, String tag) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'गहरा', 'other': 'हल्का'});
    String _temp1 = intl.Intl.selectLogic(density, {'minimal': 'मिनिमल', 'other': 'विस्तृत'});
    return '$_temp0, $_temp1, थोड़ा $tag';
  }

  @override
  String tasteQuizSummaryToneDensity(String tone, String density) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'गहरा', 'other': 'हल्का'});
    String _temp1 = intl.Intl.selectLogic(density, {'minimal': 'मिनिमल', 'other': 'विस्तृत'});
    return '$_temp0 और $_temp1';
  }

  @override
  String tasteQuizSummaryToneTag(String tone, String tag) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'गहरा', 'other': 'हल्का'});
    return '$_temp0, साथ में थोड़ा $tag';
  }

  @override
  String tasteQuizSummaryDensityTag(String density, String tag) {
    String _temp0 = intl.Intl.selectLogic(density, {'minimal': 'मिनिमल', 'other': 'विस्तृत'});
    return '$_temp0, साथ में थोड़ा $tag';
  }

  @override
  String tasteQuizSummaryTone(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'ज़्यादातर गहरे वॉलपेपर', 'other': 'ज़्यादातर हल्के वॉलपेपर'});
    return '$_temp0';
  }

  @override
  String tasteQuizSummaryDensity(String density) {
    String _temp0 = intl.Intl.selectLogic(density, {
      'minimal': 'ज़्यादातर मिनिमल वॉलपेपर',
      'other': 'ज़्यादातर विस्तृत वॉलपेपर',
    });
    return '$_temp0';
  }

  @override
  String tasteQuizSummaryTag(String tag) {
    return 'ज़्यादा $tag वॉलपेपर';
  }

  @override
  String get tasteQuizSummaryReady => 'आपकी फ़ीड तैयार है';

  @override
  String get tasteQuizRetake => 'यह या वह फिर से खेलें';

  @override
  String get tasteQuizRetakeFailed => 'वॉलपेपर लोड नहीं हो सके। अपना कनेक्शन जाँचें और फिर से कोशिश करें।';

  @override
  String get foldersPublic => 'सार्वजनिक';

  @override
  String get foldersMakePublic => 'सार्वजनिक करें';

  @override
  String get foldersMakePrivate => 'निजी करें';

  @override
  String get foldersMakePublicTitle => 'क्या इस फ़ोल्डर को सार्वजनिक करें?';

  @override
  String get foldersMakePublicMessage =>
      'Prism पर कोई भी इसका नाम और वॉलपेपर देख सकेगा, इसे फ़ॉलो कर सकेगा और इसका लिंक खोल सकेगा। आपके शेयर किए गए लिंक का प्रीव्यू बना रहेगा, भले ही आप बाद में इसे प्राइवेट कर दें।';

  @override
  String get foldersMakePrivateTitle => 'क्या इस फ़ोल्डर को निजी करें?';

  @override
  String get foldersMakePrivateMessage =>
      'इसे सिर्फ़ आप देखेंगे। इसका लिंक काम करना बंद कर देगा और इसके फ़ॉलोअर इसे खो देंगे।';

  @override
  String get foldersMadePublic => 'यह फ़ोल्डर अब सार्वजनिक है।';

  @override
  String get foldersMadePrivate => 'यह फ़ोल्डर अब निजी है।';

  @override
  String get foldersPublicNameRefused => 'इस फ़ोल्डर को सार्वजनिक करने के लिए इसका नाम बदलें।';

  @override
  String get foldersHiddenRefused =>
      'रिपोर्ट मिलने के बाद यह फ़ोल्डर छिपा दिया गया था, इसलिए इसे सार्वजनिक नहीं किया जा सकता।';

  @override
  String get foldersLimitRefused => 'आपने आज फ़ोल्डर बहुत बार बदले हैं। कल फिर से कोशिश करें।';

  @override
  String get foldersFollow => 'फ़ॉलो करें';

  @override
  String get foldersFollowing => 'फ़ॉलो कर रहे हैं';

  @override
  String foldersFollowerCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString फ़ॉलोअर',
      one: '1 फ़ॉलोअर',
      zero: 'कोई फ़ॉलोअर नहीं',
    );
    return '$_temp0';
  }

  @override
  String foldersByOwner(String name) {
    return '$name द्वारा';
  }

  @override
  String get foldersShare => 'फ़ोल्डर साझा करें';

  @override
  String get foldersReport => 'फ़ोल्डर की शिकायत करें';

  @override
  String get foldersUnavailableTitle => 'यह फ़ोल्डर निजी है या अब मौजूद नहीं है';

  @override
  String get foldersUnavailableBody => 'मालिक ने इसे निजी किया होगा या हटा दिया होगा।';

  @override
  String get foldersFollowFailed => 'फ़ॉलो अपडेट नहीं हो सका। फिर से कोशिश करें।';

  @override
  String get foldersYouFollow => 'आपके फ़ॉलो किए गए फ़ोल्डर';

  @override
  String get foldersPublicEmptyTitle => 'यहाँ अभी कोई वॉलपेपर नहीं है';

  @override
  String get foldersPublicEmptyBody => 'मालिक वॉलपेपर जोड़ेगा तो नए वॉलपेपर यहाँ दिखेंगे।';

  @override
  String get notifSettingFolders => 'आपके फ़ॉलो किए गए फ़ोल्डर';

  @override
  String get notifSettingFoldersDescription => 'आपके फ़ॉलो किए गए फ़ोल्डरों में नए वॉलपेपर, दिन में एक बार';

  @override
  String notifPushFolderDigestTitleOne(String folderName) {
    return '$folderName में नया';
  }

  @override
  String notifPushFolderDigestTitleMore(String folderName, int count) {
    return '$folderName में नया और $count और';
  }
}
