// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get economyAd => 'Ad';

  @override
  String economyWatchAdForCoins(int reward) {
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    return 'Watch ad for $rewardString coins';
  }

  @override
  String economyCoinsMissing(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'You need $countString more coins.';
  }

  @override
  String economyCoinsRemainAfterAd(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'You may still need $countString coins after the ad';
  }

  @override
  String get economyAdAutomaticPurchase =>
      'If your balance after the reward covers the price, this item will be purchased automatically.';

  @override
  String get economyAdVerificationPending =>
      'Your ad reward is awaiting verification. Coins will appear once it is confirmed.';

  @override
  String get foldersLibraryEmptyTitle => 'No folders yet';

  @override
  String get foldersLibraryEmptyBody => 'Hold the heart on a wallpaper to save it to a folder.';

  @override
  String get foldersLoadAllError => 'Could not load your folders';

  @override
  String get galleryEmptyBody => 'They were removed or are no longer public.';

  @override
  String get galleryEmptyTitle => 'These walls are gone';

  @override
  String get galleryScreenTitle => 'Walls for you';

  @override
  String get favouritePin => 'Pin to top';

  @override
  String get favouriteUnpin => 'Unpin';

  @override
  String get favouritePinnedToast => 'Pinned to the top of Favourites';

  @override
  String get favouriteUnpinnedToast => 'Unpinned';

  @override
  String get favouritePinnedBadge => 'Pinned';

  @override
  String favouritePinLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You can pin up to $count favourites. Unpin one to pin this wallpaper.',
    );
    return '$_temp0';
  }

  @override
  String get favouritePinFailed => 'Unable to update the pin. Check your connection and try again.';

  @override
  String wallpaperFavouriteSearchCountHint(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Search $countString favourites',
      one: 'Search 1 favourite',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteSortAndFilter => 'Sort and filter';

  @override
  String get wallpaperFavouriteSortBy => 'Sort by';

  @override
  String get wallpaperFavouriteFilterSource => 'Source';

  @override
  String get wallpaperHistorySetAgain => 'Set again';

  @override
  String wallpaperHistoryTileLabel(String current, String target, String time) {
    return '$current$target, set at $time';
  }

  @override
  String get wallpaperProviderWallhaven => 'Wallhaven';

  @override
  String get duoTitle => 'Duo reveal';

  @override
  String get duoAiFormatLabel => 'Create a Duo reveal';

  @override
  String get duoPresetNotice =>
      'Prism previews the right side when folded. Align the saved original manually and check both views in the system wallpaper preview. This is a Prism preset, not an automatic iOS crop.';

  @override
  String get duoFoldedPromptLabel => 'Folded view';

  @override
  String get duoFoldedPromptExample => 'A sleepy cat beside a window';

  @override
  String get duoRevealedPromptLabel => 'Unfolded reveal';

  @override
  String get duoRevealedPromptExample => 'A tiny spaceship outside the window';

  @override
  String get duoPromptValidation => 'Describe both views using 1 to 160 characters each.';

  @override
  String get duoMoodBody => 'One wallpaper. A wider reveal.';

  @override
  String get duoDeviceName => 'iPhone Duo';

  @override
  String get duoPhoneDevice => 'Phone';

  @override
  String get duoFold => 'Fold';

  @override
  String get duoUnfold => 'Unfold';

  @override
  String get duoFolded => 'Folded';

  @override
  String get duoUnfolded => 'Unfolded';

  @override
  String get duoAndroidCropNotice =>
      'Prism previews the right side when folded. Android may crop it differently. Check the system wallpaper preview before applying.';

  @override
  String get duoGetOnPrism => 'Get it on Prism';

  @override
  String get duoGuideTitle => 'Set up your Duo reveal';

  @override
  String get duoGuideOpen => 'Open the saved original in Photos, tap Share, then Use as Wallpaper.';

  @override
  String get duoGuideAlign => 'Align the full image manually so the folded view shows the right side.';

  @override
  String get duoGuideCheck => 'Check both folded and unfolded views in the system preview, then add the wallpaper.';

  @override
  String get duoWebTitle => 'iPhone Duo wallpapers | Prism';

  @override
  String get duoWebDescription =>
      'One wallpaper, a hidden second scene. Explore original Duo reveal wallpapers in Prism.';

  @override
  String get duoWebHeading => 'One wallpaper. A wider story.';

  @override
  String get duoWebIntro =>
      'A quiet scene when folded. A second story when unfolded. Preview both views of each original wallpaper.';

  @override
  String get duoWebEmpty => 'The first Duo collection is in review.';

  @override
  String get duoWebEmptyBody => 'Explore Prism while each wallpaper is checked in both views.';

  @override
  String get duoWebFolded => 'Folded preview';

  @override
  String get duoWebUnfolded => 'Unfolded original';

  @override
  String get duoWebPresetNotice =>
      'These previews use Prism\'s right-side preset, not an automatic Apple crop. Save the full original, align it manually, and check both folded and unfolded views in the system wallpaper preview.';

  @override
  String get duoWebOpenPrism => 'Open in Prism';

  @override
  String get duoWebExplore => 'Explore Prism';

  @override
  String get duoWebAppStore => 'Download on the App Store';

  @override
  String get duoWebPlayStore => 'Get it on Google Play';

  @override
  String get economyExportFailedLabel => 'Export failed';

  @override
  String get coreSignInCreatorSearchFeature => 'creator search';

  @override
  String get debugLogExportSubject => 'Prism Debug Logs';

  @override
  String get accountAbout => 'About';

  @override
  String get accountAboutPrism => 'About Prism';

  @override
  String get accountAccount => 'Account';

  @override
  String get accountAccountDeletionSubscriptionWarning =>
      'Your store subscription is not cancelled when you delete your account. It keeps billing until you cancel it in the store.';

  @override
  String get accountAdPrivacyChoices => 'Ad privacy choices';

  @override
  String get accountAddProfilePhoto => 'Add profile photo';

  @override
  String get accountAddSocialLink => 'Add one social link';

  @override
  String get accountAdmin => 'Admin';

  @override
  String get accountAdminModeration => 'Admin moderation';

  @override
  String accountAndroidSharePitch(String url) {
    return 'Fall in love with Android customisation again! Check out Prism -\n$url';
  }

  @override
  String get accountAnyResolution => 'Any';

  @override
  String get accountAppName => 'Prism Wallpapers';

  @override
  String get accountAppearance => 'Appearance';

  @override
  String get accountApply => 'Apply';

  @override
  String get accountAskEveryTime => 'Ask every time';

  @override
  String get accountAudience => 'Audience';

  @override
  String get accountAutoRotateWallpapers => 'Auto-rotate wallpapers';

  @override
  String get accountBlock => 'Block';

  @override
  String get accountBlockActionFailed => 'Could not update blocked accounts';

  @override
  String get accountBlockActionPendingSync => 'Your change is saved on this device and will sync when possible.';

  @override
  String get accountBlockConfirmationUserFallback => 'this user';

  @override
  String accountBlockThisUserTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get accountBlockUser => 'Block user';

  @override
  String accountBlockUserMessage(String name) {
    return 'You will unfollow $name, stop seeing their wallpapers in feeds, and no longer get notifications about their new posts.';
  }

  @override
  String get accountBlockedAccounts => 'Blocked accounts';

  @override
  String get accountBlockedAccountsEmptyBody =>
      'Blocking hides their posts from your feed. They may still be able to view your public profile and wallpapers.';

  @override
  String get accountBlockedAccountsLoadError => 'Could not load blocked accounts';

  @override
  String get accountBlockedListUserFallback => 'Blocked user';

  @override
  String get accountBlockedProfileBody =>
      'Their wallpapers are hidden from your feeds and notifications. You can unblock them any time.';

  @override
  String get accountBringBackSubscription => 'Bring back a previous subscription';

  @override
  String get accountBrowseByCategory => 'Browse by category';

  @override
  String get accountBrowseByColour => 'Browse by colour';

  @override
  String get accountBuyPremium => 'Buy premium';

  @override
  String get accountCacheCleared => 'Cache cleared.';

  @override
  String accountCacheClearedBytes(String size) {
    return 'Cleared $size.';
  }

  @override
  String accountCachedImageSize(String size) {
    return '$size of cached images';
  }

  @override
  String get accountCancel => 'Cancel';

  @override
  String get accountCannotGiftThisAccount => 'You can\'t send a gift to this account.';

  @override
  String accountCategorySemanticLabel(String name) {
    return 'Category, $name';
  }

  @override
  String get accountChangeAutomatically => 'Change automatically';

  @override
  String get accountChangeCoverPhoto => 'Change cover photo';

  @override
  String get accountChangeOrCancelStore => 'Change or cancel in the store';

  @override
  String get accountChangePhoto => 'Change photo';

  @override
  String get accountChangeWallpaperOnTimer => 'Change your wallpaper on a timer';

  @override
  String get accountCheckConnectionTryAgain => 'Check your connection and try again.';

  @override
  String get accountClear => 'Clear';

  @override
  String get accountClearAllDownloads => 'Clear all downloads';

  @override
  String get accountClearAllFavouritesQuestion => 'Clear all favourites?';

  @override
  String get accountClearCache => 'Clear cache';

  @override
  String get accountClearCacheConfirmMessage => 'Cached images are removed. They load again when you need them.';

  @override
  String accountClearCacheConfirmSizeMessage(String size) {
    return '$size of cached images are removed. They load again when you need them.';
  }

  @override
  String get accountClearCacheQuestion => 'Clear cache?';

  @override
  String get accountClearCacheTitle => 'Clear cache';

  @override
  String get accountClearCachedImages => 'Clear locally cached images';

  @override
  String get accountClearColour => 'Clear colour';

  @override
  String get accountClearDepthEffect => 'Clear Depth Effect';

  @override
  String get accountClearSpatialScene => 'Clear Spatial';

  @override
  String get accountClearFavouriteWallpapers => 'Clear favourite wallpapers';

  @override
  String get accountClearFavourites => 'Clear favourites';

  @override
  String accountClearFavouritesCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favourite wallpapers are removed',
      one: '1 favourite wallpaper is removed',
    );
    return '$_temp0 from your account. This cannot be undone.';
  }

  @override
  String get accountClearFavouritesMessage =>
      'All your favourite wallpapers are removed from your account. This cannot be undone.';

  @override
  String get accountClearLearnedTaste => 'Clear learned taste';

  @override
  String accountClearLearnedTasteCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'the $countString things',
      one: 'the 1 thing',
    );
    return 'Prism forgets $_temp0 it learned from what you viewed and saved. Your feed uses your chosen interests again. This cannot be undone.';
  }

  @override
  String get accountClearLearnedTasteQuestion => 'Clear learned taste?';

  @override
  String get accountClearSearch => 'Clear search';

  @override
  String get accountColour => 'Colour';

  @override
  String accountCommitCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString commits',
      one: '1 commit',
      zero: 'No commits',
    );
    return '$_temp0';
  }

  @override
  String get accountCompleteProfile => 'Complete profile';

  @override
  String get accountCompleteYourProfile => 'Complete your profile';

  @override
  String get accountConnectionTryAgain => 'Check your connection and try again.';

  @override
  String get accountContent => 'Content';

  @override
  String get accountContributor => 'Contributor';

  @override
  String accountContributorCommitCount(String login, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString commits',
      one: '1 commit',
      zero: 'no commits',
    );
    return '$login, $_temp0';
  }

  @override
  String get accountCopy => 'Copy';

  @override
  String get accountCopyLink => 'Copy link';

  @override
  String get accountCouldNotBuildReport => 'Couldn\'t build the report. Try again.';

  @override
  String get accountCouldNotClearFavourites => 'Couldn\'t clear favourite wallpapers. Try again.';

  @override
  String get accountCouldNotClearLearnedTaste => 'Couldn\'t clear learned taste. Try again.';

  @override
  String get accountCouldNotCreateLink => 'Couldn\'t create the link. Try again.';

  @override
  String get accountCouldNotDeleteDownloads => 'Couldn\'t delete downloads. Try again.';

  @override
  String accountCouldNotFollowPerson(String name) {
    return 'Couldn\'t follow $name. Try again.';
  }

  @override
  String get accountRelationLoadMoreFailed => 'Could not load more. Check your connection.';

  @override
  String get accountRelationLoadingMore => 'Loading more people';

  @override
  String get accountCouldNotLoadFollowers => 'Could not load followers';

  @override
  String get accountCouldNotLoadFollowing => 'Could not load following';

  @override
  String get accountCouldNotLoadTeam => 'Couldn\'t load the team';

  @override
  String get accountCouldNotLoadThisProfile => 'Could not load this profile';

  @override
  String get accountCouldNotLoadTrending => 'Couldn\'t load trending';

  @override
  String get accountCouldNotLoadWallpapers => 'Could not load wallpapers';

  @override
  String accountCouldNotOpenAddress(String address) {
    return 'Couldn\'t open $address';
  }

  @override
  String get accountCouldNotOpenLink => 'Couldn\'t open the link. Try again.';

  @override
  String get accountCouldNotOpenStore => 'Couldn\'t open the store. Try again.';

  @override
  String get accountCouldNotOpenThisLink => 'Couldn\'t open this link.';

  @override
  String get accountCouldNotRefreshSearch => 'Couldn\'t refresh. Pull down to try again.';

  @override
  String get accountCouldNotRemoveSavedOffline => 'Couldn\'t remove saved offline wallpapers. Try again.';

  @override
  String get accountCouldNotRestorePurchases => 'Could not restore purchases. Try again.';

  @override
  String get accountCouldNotSearchCreators => 'Couldn\'t search creators';

  @override
  String get accountCouldNotSearchRightNow => 'Couldn\'t search right now';

  @override
  String get accountCouldNotSendGift => 'Couldn\'t send the gift. Try again.';

  @override
  String get accountCouldNotShareReport => 'Couldn\'t share the report. Try again.';

  @override
  String accountCouldNotUnfollowPerson(String name) {
    return 'Couldn\'t unfollow $name. Try again.';
  }

  @override
  String get accountCreatorFallback => 'Prism creator';

  @override
  String get accountCreatorSearchEmptyBody => 'Check the spelling or try another name.';

  @override
  String get accountCurrentSignedInAccountRequired => 'Please select the account you are currently signed in with.';

  @override
  String get accountDataSaver => 'Data saver';

  @override
  String get accountDataSaverDescription =>
      'Saves mobile data. Wallpapers open as thumbnails, feeds do not load ahead and carousels do not autoplay.';

  @override
  String get accountDatabaseUsageStats => 'Database usage and stats';

  @override
  String get accountDebugPanel => 'Debug panel';

  @override
  String get accountDefaultActionForSet => 'Default action for Set';

  @override
  String get accountDeleteAccount => 'Delete account';

  @override
  String get accountDeleteAccountConfirmation =>
      'This will permanently delete your account, remove your personal data, and sign you out.\n\nYour uploaded wallpapers will remain visible as \"Deleted Account\".\n\nThis action cannot be undone.';

  @override
  String get accountDeleteAccountReauthNote => 'You will confirm with Google or Apple next.';

  @override
  String get accountDeleteAll => 'Delete all';

  @override
  String get accountDeleteAllDownloadsQuestion => 'Delete all downloads?';

  @override
  String accountDeleteDownloadsCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString downloaded wallpapers are deleted',
      one: '1 downloaded wallpaper is deleted',
    );
    return '$_temp0 from Downloads. Saved offline copies are not affected. This cannot be undone.';
  }

  @override
  String get accountDeleteDownloadsMessage =>
      'Downloaded wallpapers are deleted from Downloads. Saved offline copies are not affected. This cannot be undone.';

  @override
  String get accountDeleteYourAccountQuestion => 'Delete your account?';

  @override
  String get accountDeletingYourAccount => 'Deleting your account';

  @override
  String get accountDepthEffect => 'Depth Effect';

  @override
  String get accountDepthEffectClockSemanticLabel => 'Depth Effect, subject in front of the clock';

  @override
  String get accountSpatialScene => 'Spatial';

  @override
  String get accountSpatialSceneSubtitle => 'Walls with clear 3D depth';

  @override
  String get accountSpatialSceneSemanticLabel => 'Spatial, walls with clear 3D depth';

  @override
  String get accountDownloadApk => 'Download APK';

  @override
  String accountDownloadedWallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString downloaded wallpapers; saved offline copies stay',
      one: '1 downloaded wallpaper; saved offline copies stay',
      zero: 'No downloaded wallpapers; saved offline copies stay',
    );
    return '$_temp0';
  }

  @override
  String get accountDownloadsDeleted => 'Deleted all downloads.';

  @override
  String get accountEarnCoins => 'Earn coins';

  @override
  String accountEarnProfileCompletionCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Earn $coinsString coins when you finish';
  }

  @override
  String get accountEditCover => 'Edit cover';

  @override
  String get accountEditProfile => 'Edit profile';

  @override
  String get accountExportFavourites => 'Export favourites';

  @override
  String get accountFavouritesCleared => 'Cleared all favourite wallpapers.';

  @override
  String get accountFeedback => 'Feedback';

  @override
  String get accountFeedbackSubject => 'Prism feedback';

  @override
  String get accountFields => 'Fields';

  @override
  String get accountFindCreators => 'Find creators';

  @override
  String get accountFinishYourProfile => 'Finish your profile';

  @override
  String get accountFirestoreTelemetry => 'Firestore telemetry';

  @override
  String get accountFollow => 'Follow';

  @override
  String accountFollowPerson(String name) {
    return 'Follow $name';
  }

  @override
  String accountFollowedPerson(String name) {
    return 'Followed $name!';
  }

  @override
  String get accountFollowers => 'Followers';

  @override
  String accountFollowersCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString followers',
      one: '1 follower',
      zero: 'No followers',
    );
    return '$_temp0';
  }

  @override
  String accountFollowersCountLabel(String compactCount) {
    return '$compactCount Followers';
  }

  @override
  String get accountFollowersEmptyMessage => 'People who follow this account will show up here.';

  @override
  String get accountFollowing => 'Following';

  @override
  String accountFollowingCountLabel(String compactCount) {
    return '$compactCount Following';
  }

  @override
  String get accountFollowingEmptyMessage => 'Accounts followed from here will show up here.';

  @override
  String get accountForgetFeedLearned => 'Forget what your feed learned from you';

  @override
  String get accountFromPrism => 'From Prism';

  @override
  String get accountGiftLimitReached => 'Gift limit reached for now. Try again tomorrow.';

  @override
  String accountGiftPassMessage(String recipientName, int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$recipientName gets premium collections and premium walls until tomorrow. Costs $priceString coins.';
  }

  @override
  String get accountGiftPassTitle => 'Gift a 24-hour Pro pass';

  @override
  String get accountGiftPassTooltip => 'Gift a 24 h pass';

  @override
  String get accountGiftsOpenAfterSevenDays => 'Gifts open when your account is 7 days old.';

  @override
  String get accountHapticFeedback => 'Haptic feedback';

  @override
  String get accountHelp => 'Help';

  @override
  String get accountHomeAndLockScreens => 'Home and lock screens';

  @override
  String get accountHomeScreen => 'Home screen';

  @override
  String get accountInviteFriends => 'Invite friends';

  @override
  String get accountInviteLinkCouldNotCreate => 'Could not create your invite link.';

  @override
  String accountInviteRewardHeadline(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Give $coinsString, get $coinsString';
  }

  @override
  String accountInviteRewardMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Your friend gets $coinsString coins when they join. You get $coinsString too.';
  }

  @override
  String get accountInviteShareFailed => 'Unable to share invite right now.';

  @override
  String accountIosSharePitch(String url) {
    return 'Fall in love with your phone\'s personalization again! Check out Prism -\n$url';
  }

  @override
  String get accountLater => 'Later';

  @override
  String get accountLatest => 'Latest';

  @override
  String get accountLearnedTasteCleared => 'Learned taste cleared.';

  @override
  String get accountLibrary => 'Library';

  @override
  String get accountLightDarkAccentColour => 'Light, dark and accent colour';

  @override
  String get accountLink => 'Link';

  @override
  String get accountLinkCopied => 'Link copied';

  @override
  String get accountLinkType => 'Link type';

  @override
  String get accountLinkTypeBehance => 'Behance';

  @override
  String get accountLinkTypeBioLink => 'bio.link';

  @override
  String get accountLinkTypeBuyMeACoffee => 'Buy Me a Coffee';

  @override
  String get accountLinkTypeCustom => 'Custom link';

  @override
  String get accountLinkTypeDeviantArt => 'DeviantArt';

  @override
  String get accountLinkTypeDribbble => 'Dribbble';

  @override
  String get accountLinkTypeEmail => 'Email';

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
    return 'Link type, $name';
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
  String get accountLiveWallpapers => 'Live wallpapers';

  @override
  String get accountLoadingTeam => 'Loading the team';

  @override
  String get accountLockScreen => 'Lock screen';

  @override
  String get accountLogOut => 'Log out';

  @override
  String get accountLogOutOfPrismQuestion => 'Log out of Prism?';

  @override
  String get accountLogOutQuestion => 'Log out?';

  @override
  String get accountLogoutConfirmation =>
      'Signing out clears history and learned taste on this device. Favourites, coins and profile stay with your account.';

  @override
  String get accountLogoutFailed => 'Couldn\'t log out. Try again.';

  @override
  String get accountLogsNetworkToolsStorage => 'Logs, network, tools and storage';

  @override
  String get accountMadeWithLoveInIndia => 'Made with ❤ in India with Flutter!';

  @override
  String get accountManageBlockedPeople => 'Manage people you have blocked';

  @override
  String get accountManageSubscription => 'Manage subscription';

  @override
  String get accountMenu => 'Menu';

  @override
  String get accountMinResolution => 'Min resolution';

  @override
  String get accountMoreLinks => 'More links';

  @override
  String get accountMoreOptions => 'More options';

  @override
  String get accountMovingGradientsMotionVideo => 'Moving gradients, motion and video';

  @override
  String get accountMyAccent => 'My accent';

  @override
  String get accountNoBlockedAccounts => 'No blocked accounts';

  @override
  String get accountNoContributors => 'No contributors to show yet.';

  @override
  String get accountNoCreatorsFound => 'No creators found';

  @override
  String get accountNoDownloadsToRemove => 'You have no downloads to remove.';

  @override
  String get accountNoFollowersYet => 'No followers yet';

  @override
  String get accountNoPurchasesToRestore => 'No purchases to restore for this account.';

  @override
  String get accountNoResults => 'No results';

  @override
  String accountNoWallpapersForFilters(String filters) {
    return 'No $filters wallpapers found';
  }

  @override
  String accountNoWallpapersForQueryWithFilters(String query) {
    return 'No wallpapers found for $query with the selected filters.';
  }

  @override
  String get accountNoWallpapersFound => 'No wallpapers found';

  @override
  String accountNoWallpapersFoundForQuery(String query) {
    return 'No wallpapers found for $query';
  }

  @override
  String get accountNoWallpapersYet => 'No wallpapers yet';

  @override
  String accountNobodyMatchesUsername(String query) {
    return 'Nobody matches \"$query\". Try a different username.';
  }

  @override
  String get accountNotEnoughCoinsEarnInRewards => 'Not enough coins. Earn coins in Rewards.';

  @override
  String get accountNotFollowingAnyoneYet => 'Not following anyone yet';

  @override
  String get accountNotSynced => 'Not synced';

  @override
  String get accountNothingLearnedYet => 'Prism has not learned anything yet.';

  @override
  String get accountNotificationPreferences => 'Notification preferences';

  @override
  String get accountNotificationTypes => 'Wall of the Day, followers, posts and more';

  @override
  String get accountNotifications => 'Notifications';

  @override
  String get accountOpenYourProfile => 'Open your profile';

  @override
  String get accountOpeningProfileEditor => 'Opening profile editor';

  @override
  String get accountOpens => 'Opens';

  @override
  String get accountOtherContributors => 'Other Contributors';

  @override
  String accountPassSentToPerson(String name) {
    return 'Pass sent to $name.';
  }

  @override
  String accountPersonAlreadyHasPro(String name) {
    return '$name already has Pro.';
  }

  @override
  String get accountPersonalise => 'Personalise';

  @override
  String get accountPortraitOnly => 'Portrait only';

  @override
  String get accountPremiumBenefitsActive => 'You have every premium wallpaper, free downloads and free filters.';

  @override
  String get accountPremiumBenefitsInactive => 'Unlock premium wallpapers, free downloads and free filters.';

  @override
  String get accountPreview => 'Preview';

  @override
  String get accountPrismListPrivacySubtitle => 'How Prism handles your data';

  @override
  String get accountPrismPro => 'Prism Pro';

  @override
  String get accountPrivacyAction => 'Privacy policy';

  @override
  String get accountPrivacyAndData => 'Privacy and data';

  @override
  String get accountPrivacyPolicy => 'Privacy policy';

  @override
  String get accountProBadge => 'Pro';

  @override
  String get accountProWallpaperSemantics => 'Pro wallpaper';

  @override
  String get accountProblemReportSharePrompt => 'Please describe what went wrong. The report file has the details.';

  @override
  String get accountProblemReportShareSubject => 'Prism problem report';

  @override
  String get accountProfile => 'Profile';

  @override
  String get accountProfileNotAvailable => 'Profile not available';

  @override
  String get accountProfileNotAvailableBody =>
      'This user is inactive on the latest version of Prism, so their profile cannot be shown.';

  @override
  String accountProfileNudgeMessage(int percent, int coins) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Your profile is $percentString% complete. Finish it to earn $coinsString Prism coins.';
  }

  @override
  String accountProfilePercentComplete(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Profile $percentString% complete';
  }

  @override
  String accountProfilePersonSemantics(String name, String username) {
    return '$name, @$username';
  }

  @override
  String get accountProfiles => 'profiles';

  @override
  String get accountPurchases => 'Purchases';

  @override
  String get accountPurchasesRestored => 'Purchases restored.';

  @override
  String get accountPurchasesRestoredPending => 'Purchases restored. Pro can take a minute to unlock.';

  @override
  String get accountQuickTiles => 'Quick tiles';

  @override
  String get accountRateApp => 'Rate';

  @override
  String get accountRecentSearches => 'Recent searches';

  @override
  String get accountRelevance => 'Relevance';

  @override
  String get accountRemoveAllFavouriteWallpapers => 'Remove all favourite wallpapers';

  @override
  String get accountRemoveCoverPhoto => 'Remove cover photo';

  @override
  String get accountRemoveFilesDownloadsOfflineStay => 'Remove files from Downloads; saved offline copies stay';

  @override
  String get accountRemoveLink => 'Remove link';

  @override
  String get accountRemovePhoto => 'Remove photo';

  @override
  String get accountRemoveSavedOffline => 'Remove saved offline';

  @override
  String accountRemoveSavedOfflineCountMessage(String size) {
    return '$size of retained offline originals are removed. Downloads, drafts and catalog data stay untouched.';
  }

  @override
  String get accountRemoveSavedOfflineMessage =>
      'Remove retained offline originals from this device. Downloads, drafts and catalog data stay untouched.';

  @override
  String get accountRemoveSavedOfflineQuestion => 'Remove saved offline wallpapers?';

  @override
  String get accountReportAProblem => 'Report a problem';

  @override
  String get accountReportProblemSubtitle => 'Send a bug report to the Prism team';

  @override
  String get accountReportUser => 'Report user';

  @override
  String get accountResetFilters => 'Reset filters';

  @override
  String get accountResolution1080 => '1080p';

  @override
  String get accountResolution1440 => '1440p';

  @override
  String get accountResolution4k => '4K';

  @override
  String get accountRestorePurchases => 'Restore purchases';

  @override
  String get accountRestoringPurchases => 'Restoring purchases…';

  @override
  String get accountRetry => 'Retry';

  @override
  String get accountReviewOrChangeAdConsent => 'Review or change your ad consent';

  @override
  String get accountReviewStatus => 'Review status';

  @override
  String get accountReviewSubmittedContent => 'Review submitted content';

  @override
  String get accountSaveFavouritesAsFile => 'Save a copy of your favourites as a file';

  @override
  String get accountSavedOffline => 'Saved offline';

  @override
  String get accountSavedOfflineRemoved => 'Saved offline wallpapers removed.';

  @override
  String accountSavedOfflineStorageUnavailable(int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'Storage unavailable · $limitString MiB limit';
  }

  @override
  String accountSavedOfflineStorageUsed(String size, int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$size used · $limitString MiB limit';
  }

  @override
  String get accountSavedOnThisDevice => 'Saved on this device';

  @override
  String get accountSearch => 'Search';

  @override
  String get accountSearchByUsername => 'Search by username';

  @override
  String get accountSearchCreators => 'Search creators';

  @override
  String get accountSearchCreatorsByName => 'Search creators by name';

  @override
  String get accountSearchFilters => 'Filters';

  @override
  String get accountSearchPrismUsersByName => 'Search Prism users by name';

  @override
  String get accountSearchWallpapers => 'Search wallpapers';

  @override
  String get accountSeeChangelog => 'See the changelog';

  @override
  String get accountSendGift => 'Send gift';

  @override
  String get accountSendProfileLink => 'Send a link to your Prism profile';

  @override
  String get accountSetUpQuickTiles => 'Set up your Quick Settings tiles';

  @override
  String get accountSetUsername => 'Set username';

  @override
  String get accountSettings => 'Settings';

  @override
  String get accountShareInvite => 'Share invite';

  @override
  String get accountSharePrism => 'Share Prism';

  @override
  String get accountSharePrismFriendSubtitle => 'Send a link to a friend';

  @override
  String get accountShareProfile => 'Share profile';

  @override
  String get accountShareProfileLinkFailed => 'Couldn\'t create the link. Try again.';

  @override
  String get accountShareYourProfile => 'Share your profile';

  @override
  String get accountShop => 'Shop';

  @override
  String get accountShowAnimeWallpapers => 'Show anime wallpapers';

  @override
  String get accountShowSketchyWallpapers => 'Show sketchy wallpapers';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get accountSignInAgainToDelete => 'Please sign out and sign in again, then try deleting your account.';

  @override
  String get accountSignInBenefits => 'Sign in to keep your favourites, coins and profile';

  @override
  String get accountSignInForInviteLink => 'Sign in to get your invite link.';

  @override
  String get accountSignInToPrism => 'Sign in to Prism';

  @override
  String get accountSocialGithub => 'GitHub';

  @override
  String get accountSocialInstagram => 'Instagram';

  @override
  String get accountSocialTelegram => 'Telegram';

  @override
  String get accountSocialTwitter => 'Twitter';

  @override
  String get accountSomethingWentWrongTryAgain => 'Something went wrong. Try again.';

  @override
  String get accountSort => 'Sort';

  @override
  String get accountStorage => 'Storage';

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
  String get accountSubjectCanSitInFrontOfClock => 'Subject can sit in front of the clock';

  @override
  String get accountSubjectInFrontOfClock => 'Subject in front of the clock';

  @override
  String get accountTerms => 'Terms';

  @override
  String get accountTermsAction => 'Terms of use';

  @override
  String accountTermsAgreementSemanticLabel(String terms, String privacy) {
    return 'By continuing you agree to the $terms and $privacy';
  }

  @override
  String get accountTermsOfUse => 'Terms of use';

  @override
  String get accountTheTeam => 'The Team';

  @override
  String get accountThemes => 'Themes';

  @override
  String get accountThemesIconsFrames => 'Themes, icons, frames';

  @override
  String get accountThisUser => 'this user';

  @override
  String get accountTop => 'Top';

  @override
  String get accountTrackSubmittedWallpapers => 'Track your submitted wallpapers';

  @override
  String get accountTrendingNow => 'Trending now';

  @override
  String get accountTryAgain => 'Try again';

  @override
  String get accountTryFewerFilters => 'Try fewer filters.';

  @override
  String get accountTryShorterOrDifferentWord => 'Try a shorter or a different word.';

  @override
  String get accountUnblock => 'Unblock';

  @override
  String get accountUnblockUserMessage => 'Their posts will appear in your feed again.';

  @override
  String accountUnblockUserTitle(String name) {
    return 'Unblock $name?';
  }

  @override
  String get accountUnfollow => 'Unfollow';

  @override
  String accountUnfollowPerson(String name) {
    return 'Unfollow $name';
  }

  @override
  String accountUnfollowedPerson(String name) {
    return 'Unfollowed $name!';
  }

  @override
  String get accountUnlimitedUploadsFilters => 'Unlimited uploads and filters';

  @override
  String get accountUploadFirstWallpaper => 'Upload your first wallpaper to start your gallery.';

  @override
  String get accountUseShortcutsAutomation => 'Use a Shortcuts automation';

  @override
  String accountUserBlocked(String name) {
    return 'Blocked $name';
  }

  @override
  String get accountUserUnblocked => 'Unblocked';

  @override
  String accountVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get accountVibrateOnTapsAndActions => 'Vibrate on taps and actions';

  @override
  String get accountWaitingToSync => 'Waiting to sync';

  @override
  String get accountWallpaperHistory => 'Wallpaper history';

  @override
  String get accountWallpaperManagerTagline => 'A feature-rich wallpaper manager.';

  @override
  String get accountWallpaperSourceNames => 'Prism uses Wallhaven and Pexels for wallpapers';

  @override
  String get accountWallpaperSources => 'Wallpaper sources';

  @override
  String get accountWallpaperSourcesMessage => 'Prism uses these services to bring you wallpapers.';

  @override
  String get accountWallpapersSetBefore => 'Wallpapers you set before';

  @override
  String get accountWhatsNew => 'What\'s new';

  @override
  String get accountWhatsNewAction => 'What\'s new';

  @override
  String get accountWriteBio => 'Write bio';

  @override
  String accountYouBlockedUser(String name) {
    return 'You blocked $name';
  }

  @override
  String get accountYourContent => 'Your content';

  @override
  String get accountYourProfile => 'your profile';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionDone => 'Done';

  @override
  String get actionRetry => 'Try again';

  @override
  String adminReleaseApproved(String when) {
    return 'Approved. Releases $when';
  }

  @override
  String adminReleaseRequested(String when) {
    return 'Creator release: $when';
  }

  @override
  String get adminAllCaughtUp => 'All caught up';

  @override
  String get adminAllUsers => 'All users';

  @override
  String get adminAnnouncementInbox => 'Announcement (inbox)';

  @override
  String get adminAnonymous => 'Anonymous';

  @override
  String get adminApprovalFailed => 'Approval failed. Check your connection, then try again.';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminApproved => 'Approved';

  @override
  String get adminBackToReviewList => 'Back to the review list';

  @override
  String get adminBatchActionFailed => 'Could not complete this review action. Try again.';

  @override
  String get adminBatchComplete => 'Batch complete';

  @override
  String get adminBodyLabel => 'Body';

  @override
  String get adminBodyRequired => 'Body is required';

  @override
  String get adminBy => 'By';

  @override
  String get adminByCollection => 'By collection';

  @override
  String get adminByOperation => 'By operation';

  @override
  String get adminBySourceTop15 => 'By source (top 15)';

  @override
  String get adminCancel => 'Cancel';

  @override
  String get adminChangeDepthEffect => 'Change Depth Effect';

  @override
  String get adminCheckConnectionRetry => 'Check your connection, then try again.';

  @override
  String get adminClose => 'Close';

  @override
  String adminContentTypeReport(String type) {
    return '$type report';
  }

  @override
  String get adminCopyAllData => 'Copy all data';

  @override
  String get adminCouldNotLoadWallpaper => 'Could not load the wallpaper';

  @override
  String get adminCreatorWillSeeFeedback => 'The creator will see this feedback.';

  @override
  String get adminDepth => 'Depth';

  @override
  String adminDepthTier(String tier) {
    return 'Depth: $tier';
  }

  @override
  String get adminDepthTierAuto => 'Auto';

  @override
  String get adminDepthTierMenu => 'Menu';

  @override
  String get adminDepthTierNone => 'None';

  @override
  String get adminDepthTierNotChecked => 'Not checked';

  @override
  String get adminDrop => 'Drop';

  @override
  String get adminEmail => 'Email';

  @override
  String get adminEmailExample => 'user@example.com';

  @override
  String get adminEmailRequired => 'Email is required';

  @override
  String get adminEstimatedDocumentReads => 'Estimated document reads';

  @override
  String get adminEstimatedDocumentWrites => 'Estimated document writes';

  @override
  String adminFactLabel(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminFirestoreTelemetry => 'Firestore telemetry';

  @override
  String get adminFollowersScreen => 'Followers screen';

  @override
  String get adminFreeUsers => 'Free users';

  @override
  String get adminGeneral => 'General';

  @override
  String get adminImageUrlOptional => 'Image URL (optional)';

  @override
  String get adminKeepWallpaper => 'Keep wallpaper';

  @override
  String get adminLast14Days => 'Last 14 days';

  @override
  String get adminList => 'List';

  @override
  String get adminLoadNextBatch => 'Load next batch';

  @override
  String get adminLoadingNotificationCounts => 'Loading notification counts.';

  @override
  String get adminMarkReviewed => 'Mark reviewed';

  @override
  String get adminMarkReviewedFailed => 'Could not mark the report reviewed. Try again.';

  @override
  String get adminMarkedReviewed => 'Marked reviewed';

  @override
  String adminModerationDuplicate(int percent) {
    return 'Looks like a Prism wall · $percent%';
  }

  @override
  String get adminModerationHint => 'These are hints. Check before you reject.';

  @override
  String adminModerationLogo(String logo) {
    return 'Logo: $logo';
  }

  @override
  String get adminModerationLogos => 'Logos';

  @override
  String get adminModerationOpenFailed => 'Could not open the page.';

  @override
  String adminModerationOpenPage(String host) {
    return 'Open $host';
  }

  @override
  String get adminModerationSignals => 'Review signals';

  @override
  String get adminModerationSimilarWall => 'Similar Prism wall';

  @override
  String adminModerationSimilarity(int percent) {
    return '$percent% similar';
  }

  @override
  String adminModerationText(String words) {
    return 'Text: $words';
  }

  @override
  String get adminModerationTextInImage => 'Text in the image';

  @override
  String adminModerationUnsafe(String categories) {
    return 'Unsafe: $categories';
  }

  @override
  String get adminModerationUnsafeCategories => 'Unsafe categories';

  @override
  String adminModerationWeb(String host) {
    return 'Found on $host';
  }

  @override
  String adminModerationWebMore(String host, int more) {
    return 'Found on $host +$more';
  }

  @override
  String get adminModerationWebPages => 'Found on the web';

  @override
  String get adminNewWallpapersPending => 'New wallpapers show up here when someone uploads one.';

  @override
  String get adminNoNotificationCounts => 'No notification counts yet.';

  @override
  String get adminNoOpenReports => 'No open reports';

  @override
  String get adminNoReasonGiven => 'No reason given';

  @override
  String get adminNoTelemetryData => 'No telemetry data to copy';

  @override
  String get adminNoTelemetryYet => 'No telemetry yet';

  @override
  String get adminNoWallpapersPending => 'No wallpapers pending review.';

  @override
  String get adminNothingToReview => 'Nothing to review';

  @override
  String get adminNotificationCountExplanation =>
      'Accepted means Firebase took the push. A push to the account topic and the device token counts twice. It is not a view.';

  @override
  String get adminNotificationCountsLoadError => 'Could not load notification counts.';

  @override
  String get adminNotificationIrreversible =>
      'This notification goes out to everyone in this group. You cannot take it back.';

  @override
  String get adminNotificationQueueFailed => 'Could not queue the notification. Try again.';

  @override
  String get adminNotificationQueued => 'Notification queued. The Cloud Function will send it shortly.';

  @override
  String get adminNotifications => 'Notifications';

  @override
  String get adminOpenReportsLoadError => 'Could not load open reports.';

  @override
  String get adminOpenWallpaper => 'Open wallpaper';

  @override
  String adminOperationCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString ops', one: '$countString op');
    return '$_temp0';
  }

  @override
  String get adminPendingWallsLoadError => 'Could not load pending wallpapers.';

  @override
  String get adminPremiumUsers => 'Premium users';

  @override
  String adminReadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString reads',
      one: '$countString read',
    );
    return '$_temp0';
  }

  @override
  String get adminReasonBlurry => 'Blurry';

  @override
  String get adminReasonBlurryBody => 'The image is blurry or heavily compressed. Upload a sharper version.';

  @override
  String get adminReasonCopyright => 'Copyright';

  @override
  String get adminReasonCopyrightBody =>
      'This image may be the work of someone else. Upload only wallpapers you made or have the rights to.';

  @override
  String get adminReasonDuplicate => 'Duplicate';

  @override
  String get adminReasonDuplicateBody => 'This wallpaper is a duplicate of one that is already on Prism.';

  @override
  String get adminReasonHint => 'Explain what needs to change';

  @override
  String get adminReasonLabel => 'Reason';

  @override
  String get adminReasonLowResolution => 'Low resolution';

  @override
  String get adminReasonLowResolutionBody =>
      'The resolution is too low. Upload an image with at least 1080 px on the short side.';

  @override
  String get adminReasonNotWallpaper => 'Not a wallpaper';

  @override
  String get adminReasonNotWallpaperBody =>
      'This image does not work as a phone wallpaper. Use a portrait image that fills the screen.';

  @override
  String get adminReasonOther => 'Other';

  @override
  String get adminReasonWatermark => 'Watermark';

  @override
  String get adminReasonWatermarkBody => 'The image has a watermark. Upload a version without it.';

  @override
  String get adminRefresh => 'Refresh';

  @override
  String get adminReject => 'Reject';

  @override
  String get adminRejectReasonRequired => 'Enter a reason before rejecting this item.';

  @override
  String get adminRejectSaveFailed => 'Could not save this decision. Your reason is still here. Try again.';

  @override
  String get adminRejectWallpaper => 'Reject wallpaper';

  @override
  String get adminRemove => 'Remove';

  @override
  String get adminRemoveWallpaper => 'Remove wallpaper';

  @override
  String get adminRemovedFromNextDrop => 'Removed from the next Drop';

  @override
  String get adminReportDismissFailed => 'Could not dismiss the report. Try again.';

  @override
  String get adminReportDismissedKept => 'Report dismissed. Wallpaper kept.';

  @override
  String get adminReported => 'Reported';

  @override
  String get adminReporter => 'Reporter';

  @override
  String get adminReports => 'Reports';

  @override
  String get adminReserve => 'Reserve';

  @override
  String get adminReserveForDrop => 'Reserve for Drop';

  @override
  String get adminReserveUpdateFailed => 'Could not update the Drop reserve. Try again.';

  @override
  String get adminReservedForNextDrop => 'Reserved for the next Drop';

  @override
  String get adminRetry => 'Retry';

  @override
  String adminReviewProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString/$totalString';
  }

  @override
  String get adminSendNotification => 'Send notification';

  @override
  String adminSendToAudience(String audience) {
    return 'Send to $audience?';
  }

  @override
  String get adminSkip => 'Skip';

  @override
  String get adminSpecificUser => 'Specific user (email)';

  @override
  String get adminSwipeInstructions => 'Swipe right to approve, left to reject';

  @override
  String get adminSwipeReview => 'Swipe review';

  @override
  String get adminTarget => 'Target';

  @override
  String get adminTelemetryCopied => 'Copied to clipboard. Paste elsewhere to analyze.';

  @override
  String get adminTelemetryReadError => 'Could not read telemetry';

  @override
  String get adminTitle => 'Admin moderation';

  @override
  String get adminTitleLabel => 'Title';

  @override
  String get adminTitleRequired => 'Title is required';

  @override
  String get adminTotalEvents => 'Total events';

  @override
  String get adminTryAgain => 'Try again';

  @override
  String get adminUndo => 'Undo';

  @override
  String get adminUndoSuccessful => 'Undo successful';

  @override
  String get adminUnknown => 'Unknown';

  @override
  String get adminUnreserve => 'Unreserve';

  @override
  String get adminUntitled => 'Untitled';

  @override
  String get adminUploaded => 'Uploaded';

  @override
  String get adminUseAppForEvents => 'Use the app to generate Firestore events.';

  @override
  String get adminUserEmail => 'User email';

  @override
  String get adminUserReportsShowHere => 'Reports from users show up here.';

  @override
  String get adminValidEmailRequired => 'Enter a valid email';

  @override
  String get adminView => 'View';

  @override
  String get adminViewFullWallpaper => 'View full wallpaper';

  @override
  String get adminWallId => 'ID';

  @override
  String get adminWallOfTheDay => 'Wall of the Day';

  @override
  String get adminWallOrUpload => 'Wall or upload';

  @override
  String get adminWallpaperAlreadyGone => 'Wallpaper was already gone. Report closed.';

  @override
  String get adminWallpaperApproved => 'Wallpaper approved';

  @override
  String get adminWallpaperFullScreen => 'Wallpaper, full screen';

  @override
  String get adminWallpaperRejected => 'Wallpaper rejected';

  @override
  String get adminWallpaperRemoved => 'Wallpaper removed';

  @override
  String get adminWallpaperReport => 'Wallpaper report';

  @override
  String get adminWallpaperToReview => 'Wallpaper to review';

  @override
  String adminWallpapersRemaining(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers remaining',
      one: '$countString wallpaper remaining',
    );
    return '$_temp0';
  }

  @override
  String get adminWalls => 'Walls';

  @override
  String get adminDesktop => 'Desktop';

  @override
  String get adminDesktopEmptyTitle => 'No desktop versions to review';

  @override
  String get adminDesktopEmptyBody => 'Desktop versions that creators submit show here.';

  @override
  String get adminDesktopLoadError => 'Unable to load desktop versions';

  @override
  String get adminDesktopReplaces => 'Replaces the current desktop version';

  @override
  String get adminDesktopUploadSize => 'Upload size';

  @override
  String get adminDesktopApproved => 'Desktop version approved';

  @override
  String get adminDesktopRejected => 'Desktop version rejected';

  @override
  String get adminDesktopRejectTitle => 'Reject desktop version';

  @override
  String get adminDesktopWallUnavailable => 'This wallpaper is no longer approved. Reject this desktop version.';

  @override
  String adminWriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString writes',
      one: '$countString write',
    );
    return '$_temp0';
  }

  @override
  String get appLinkRetryWhenOnline => 'No connection. We will open this link when you are back online.';

  @override
  String get appTitle => 'Prism';

  @override
  String get coreBack => 'Back';

  @override
  String get coreBio => 'Bio';

  @override
  String get coreBlockCreatorAfterReport => 'Also block this creator';

  @override
  String get coreBothScreens => 'both screens';

  @override
  String get coreCancel => 'Cancel';

  @override
  String get coreCancelSelection => 'Cancel selection';

  @override
  String get coreCancelSignIn => 'Not now';

  @override
  String get coreCategoryAbstract => 'Abstract';

  @override
  String get coreCategoryAerial => 'Aerial';

  @override
  String get coreCategoryAesthetic => 'Aesthetic';

  @override
  String get coreCategoryAiArt => 'AI Art';

  @override
  String get coreCategoryAnimals => 'Animals';

  @override
  String get coreCategoryAnime => 'Anime';

  @override
  String get coreCategoryArchitecture => 'Architecture';

  @override
  String get coreCategoryArtistic => 'Artistic';

  @override
  String get coreCategoryBirds => 'Birds';

  @override
  String get coreCategoryCars => 'Cars';

  @override
  String get coreCategoryCity => 'City';

  @override
  String get coreCategoryClouds => 'Clouds';

  @override
  String get coreCategoryComic => 'Comic';

  @override
  String get coreCategoryCyberpunk => 'Cyberpunk';

  @override
  String get coreCategoryDark => 'Dark';

  @override
  String get coreCategoryDefault => 'Category';

  @override
  String get coreCategoryFantasy => 'Fantasy';

  @override
  String get coreCategoryFashion => 'Fashion';

  @override
  String get coreCategoryFlowers => 'Flowers';

  @override
  String get coreCategoryFood => 'Food';

  @override
  String get coreCategoryForest => 'Forest';

  @override
  String get coreCategoryGalaxy => 'Galaxy';

  @override
  String get coreCategoryGaming => 'Gaming';

  @override
  String get coreCategoryPastel => 'Pastel';

  @override
  String get coreCategoryDesktop => 'Desktop';

  @override
  String get coreCategoryGradient => 'Gradient';

  @override
  String get coreCategoryIllustration => 'Illustration';

  @override
  String get coreCategoryKawaii => 'Kawaii';

  @override
  String get coreCategoryLandscape => 'Landscape';

  @override
  String get coreCategoryMinimal => 'Minimal';

  @override
  String get coreCategoryMusic => 'Music';

  @override
  String get coreCategoryNature => 'Nature';

  @override
  String get coreCategoryNeon => 'Neon';

  @override
  String get coreCategoryOcean => 'Ocean';

  @override
  String get coreCategoryPortraits => 'Portraits';

  @override
  String get coreCategoryQuotes => 'Quotes';

  @override
  String get coreCategoryRender3d => '3D Render';

  @override
  String get coreCategoryRobots => 'Robots';

  @override
  String get coreCategoryScenery => 'Scenery';

  @override
  String get coreCategorySpace => 'Space';

  @override
  String get coreCategorySpiritual => 'Spiritual';

  @override
  String get coreCategorySports => 'Sports';

  @override
  String get coreCategoryTech => 'Tech';

  @override
  String get coreCategoryTextures => 'Textures';

  @override
  String get coreCategoryUnderTheSea => 'Under the Sea';

  @override
  String get coreCategoryVehicles => 'Vehicles';

  @override
  String get coreCategoryVintage => 'Vintage';

  @override
  String get coreCategoryWarriors => 'Warriors';

  @override
  String get coreChangeWallpaperTarget => 'Change where wallpaper is set';

  @override
  String get coreChangelogLatest => 'Latest';

  @override
  String get coreChooseReportReason => 'Choose a reason';

  @override
  String get coreChooseUsername => 'Pick an available username.';

  @override
  String get coreCoinAiWallpaper => 'AI wallpaper';

  @override
  String get coreCoinAutoRotatePass => 'Auto-rotate pass, 7 days';

  @override
  String get coreCoinBadgeReward => 'Badge reward';

  @override
  String coreCoinBalance(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString Prism coins';
  }

  @override
  String coreCoinBalanceChange(String balance, String change) {
    return '$balance, $change';
  }

  @override
  String get coreCoinBoost => 'Boost';

  @override
  String get coreCoinCoins => 'Coins';

  @override
  String get coreCoinCoinsReturned => 'Coins returned';

  @override
  String get coreCoinCollectionPreview => 'Collection preview, 24 h';

  @override
  String get coreCoinDailyChest => 'Daily chest';

  @override
  String get coreCoinDailyStreak => 'Daily streak';

  @override
  String coreCoinDailyStreakDay(String day) {
    return 'Daily streak, day $day';
  }

  @override
  String get coreCoinDay7Chest => 'Day 7 chest';

  @override
  String get coreCoinDrawTicket => 'Draw ticket';

  @override
  String get coreCoinDropPack => 'Drop pack';

  @override
  String get coreCoinDropWall => 'Drop wall';

  @override
  String get coreCoinFirstUpload => 'First upload';

  @override
  String get coreCoinGiftPass => 'Gift: 24 h pass';

  @override
  String get coreCoinInviteReward => 'Invite reward';

  @override
  String get coreCoinLiveWallpaperStyle => 'Live wallpaper style';

  @override
  String get coreCoinPremiumFilter => 'Premium filter';

  @override
  String get coreCoinPremiumWallpaper => 'Premium wallpaper';

  @override
  String get coreCoinProDailyBonus => 'Pro daily bonus';

  @override
  String get coreCoinProSpin => 'Pro spin';

  @override
  String get coreCoinProStreakBonus => 'Pro streak bonus';

  @override
  String get coreCoinProfileComplete => 'Profile complete';

  @override
  String get coreCoinQuest => 'Quest';

  @override
  String coreCoinRefund(String target) {
    return 'Refund: $target';
  }

  @override
  String get coreCoinShop => 'Shop';

  @override
  String get coreCoinSpinWheel => 'Spin the wheel';

  @override
  String get coreCoinStreakFreeze => 'Streak freeze';

  @override
  String get coreCoinStreakRestore => 'Streak restore';

  @override
  String get coreCoinWallpaperDownload => 'Wallpaper download';

  @override
  String get coreCoinWatchedVideo => 'Watched a video';

  @override
  String get coreCoinWeekBonus => 'Week bonus';

  @override
  String get coreColorBlack => 'Black';

  @override
  String get coreColorBlue => 'Blue';

  @override
  String get coreColorBrown => 'Brown';

  @override
  String get coreColorGreen => 'Green';

  @override
  String get coreColorGrey => 'Grey';

  @override
  String get coreColorOrange => 'Orange';

  @override
  String get coreColorPink => 'Pink';

  @override
  String get coreColorPurple => 'Purple';

  @override
  String get coreColorRed => 'Red';

  @override
  String get coreColorTeal => 'Teal';

  @override
  String get coreColorWhite => 'White';

  @override
  String get coreColorYellow => 'Yellow';

  @override
  String get coreConfirmWallpaperPreview => 'Confirm the wallpaper in the system preview.';

  @override
  String get coreContentNotAvailable => 'That item is no longer available';

  @override
  String get coreContentReportUser => 'user';

  @override
  String get coreContentReportWallpaper => 'wallpaper';

  @override
  String coreContentReportWhy(String contentType) {
    return 'Why are you reporting this $contentType?';
  }

  @override
  String coreContentReportWhyWithDetails(String contentType, String details) {
    return 'Why are you reporting this $contentType ($details)?';
  }

  @override
  String get coreContinueWithApple => 'Continue with Apple';

  @override
  String get coreContinueWithGoogle => 'Continue with Google';

  @override
  String get coreContributorCouldNotLoad => 'Could not load this profile';

  @override
  String get coreContributorGithub => 'GitHub';

  @override
  String get coreContributorTwitter => 'Twitter';

  @override
  String get coreContributorWebsite => 'Website';

  @override
  String get coreCouldNotLoadChangelog => 'Could not load the changelog';

  @override
  String get coreCouldNotLoadWallpaperForEditing => 'Could not load wallpaper for editing';

  @override
  String get coreCouldNotUpdateFavourites => 'Couldn\'t update favourites. Try again.';

  @override
  String get coreCreatorPreviewDescription => 'Check out this creator profile on Prism.';

  @override
  String get coreDefaultBanner => 'Join our Telegram';

  @override
  String get coreDepthEffectAutoLongTip =>
      'Depth Effect turns on by itself. On iOS 18 or older, keep widgets off the space under the clock.';

  @override
  String get coreDepthEffectAutoTip => 'Depth Effect turns on by itself.';

  @override
  String get coreDepthEffectBadge => 'Depth';

  @override
  String get coreDepthEffectBadgeSemantic => 'Works with Depth Effect';

  @override
  String get coreDepthEffectMenuShortTip => 'Tap ••• then Depth Effect.';

  @override
  String get coreDepthEffectMenuTip => 'In the Lock Screen editor, tap ••• then Depth Effect.';

  @override
  String get coreSpatialBadge => 'Spatial';

  @override
  String get coreSpatialBadgeSemantic => 'Works as a Spatial Scene';

  @override
  String get coreSpatialSceneTip => 'In the Lock Screen editor, tap the Spatial Scene button.';

  @override
  String get coreDeviceCannotSetScreen => 'This device can\'t set that screen.';

  @override
  String get coreDone => 'Done';

  @override
  String coreDown(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'down $coinsString';
  }

  @override
  String get coreDownloadNotFinishedCoinsReturned => 'Your last download did not finish. Coins returned.';

  @override
  String get coreDownloadPrismPreviewDescription => 'Download Prism to discover beautiful wallpapers.';

  @override
  String get coreEdit => 'Edit';

  @override
  String get coreEditBioHint => 'Tell people about yourself…';

  @override
  String get coreEditDiscardBody => 'Your edits have not been saved.';

  @override
  String get coreEditDiscardTitle => 'Discard changes?';

  @override
  String get coreEditEmailInvalid => 'Enter a valid email address.';

  @override
  String coreEditKindLinkInvalid(String kind) {
    return 'Enter a valid $kind link.';
  }

  @override
  String get coreEditLinkInvalid => 'Enter a valid link.';

  @override
  String get coreEditProfile => 'Edit profile';

  @override
  String coreEditProfileLink(String kind) {
    return '$kind link';
  }

  @override
  String get coreEditRemoveBioTitle => 'Remove bio?';

  @override
  String get coreEditRemoveConfirm => 'Remove';

  @override
  String coreEditRemoveTitle(String item) {
    return 'Remove $item?';
  }

  @override
  String get coreEditUsernameAvailable => 'Username available';

  @override
  String get coreEditUsernameChars => 'Use letters, numbers and underscores only.';

  @override
  String get coreEditUsernameAllCaps => 'Use at least one lowercase letter.';

  @override
  String coreEditUsernameMinLength(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Use at least $lengthString characters.';
  }

  @override
  String coreEditUsernameRule(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Use $lengthString or more letters, numbers or underscores (_).';
  }

  @override
  String get coreEditUsernameTaken => 'That username is taken.';

  @override
  String get coreEditUsernameTakenSemantic => 'Username taken';

  @override
  String get coreFavourite => 'Favourite';

  @override
  String coreFileSizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String get coreGenericSignInError => 'Something went wrong, please try again!';

  @override
  String get coreGoHome => 'Go home';

  @override
  String get coreGooglePlayServicesSignInError => 'Google Play services on this device cannot sign in.';

  @override
  String get coreGoogleSignInNetworkError => 'Google sign-in failed. Check your connection and try again.';

  @override
  String get coreHomeScreen => 'home screen';

  @override
  String get coreHomeScreenSetupUnavailable => 'Home screen setups are no longer available.';

  @override
  String get coreInvalidLinkBody => 'The link you opened is invalid or no longer available.';

  @override
  String coreInvitedToPrismTitle(String name) {
    return '$name invited you to Prism';
  }

  @override
  String get coreIosWallpaperGuideBody => 'iOS does not let apps change your wallpaper. Finish in Photos:';

  @override
  String get coreJoinPrismPreviewTitle => 'Join Prism';

  @override
  String get coreKeepPrismOpen => 'Keep Prism open and try again.';

  @override
  String get coreLoading => 'Loading';

  @override
  String get coreLoadingMoreFailed => 'Couldn\'t load more. Tap to retry';

  @override
  String get coreLoadingWallpaper => 'Loading wallpaper';

  @override
  String get coreLockScreen => 'lock screen';

  @override
  String get coreMatchAccent => 'Match accent';

  @override
  String get coreName => 'Name';

  @override
  String get coreNoWallpaperUrl => 'No wallpaper URL available';

  @override
  String get coreNotNow => 'Not now';

  @override
  String get coreOpenPhotos => 'Open Photos';

  @override
  String get coreOpenSettings => 'Open settings';

  @override
  String get corePairPickerDownloads => 'Downloads';

  @override
  String get corePairPickerFavourites => 'Favourites';

  @override
  String get corePairPickerHistory => 'History';

  @override
  String get corePairPickerNoDownloads => 'No downloads yet.';

  @override
  String get corePairPickerNoFavourites => 'No favourites yet.';

  @override
  String get corePairPickerNoHistory => 'No history yet.';

  @override
  String get corePairPickerTitle => 'Pick a lock screen wallpaper';

  @override
  String get corePairPickerUseWallpaper => 'Use this wallpaper for the lock screen';

  @override
  String get corePhotosPermissionMessage => 'Allow Prism to add photos in Settings to save wallpapers.';

  @override
  String get corePhotosStepOpen => 'Open Photos.';

  @override
  String get corePhotosStepShare => 'Tap Share.';

  @override
  String get corePhotosStepUseAsWallpaper => 'Tap Use as Wallpaper.';

  @override
  String corePopupAppVersion(String version) {
    return 'You are on version $version.';
  }

  @override
  String get corePopupCannotUndo => 'This can\'t be undone.';

  @override
  String get corePopupCoverPhoto => 'cover photo';

  @override
  String get corePopupDiscard => 'Discard';

  @override
  String get corePopupProfilePhoto => 'profile photo';

  @override
  String get corePopupWhatsNew => 'What\'s new';

  @override
  String get corePreviousWallpaperRestored => 'Previous wallpaper restored';

  @override
  String get coreProfileSaveFailed => 'Could not save your profile. Please try again.';

  @override
  String get coreProfileUpdated => 'Profile updated';

  @override
  String coreReferralSaved(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Referral saved. Sign in to claim +$coinsString coins.';
  }

  @override
  String coreRelativeTimeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString days ago', one: '1 day ago');
    return '$_temp0';
  }

  @override
  String coreRelativeTimeDaysFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString days', one: '1 day');
    return 'in $_temp0';
  }

  @override
  String coreRelativeTimeHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeHoursFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString hours', one: '1 hour');
    return 'in $_temp0';
  }

  @override
  String get coreRelativeTimeJustNow => 'Just now';

  @override
  String coreRelativeTimeMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeMinutesFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString minutes', one: '1 minute');
    return 'in $_temp0';
  }

  @override
  String get coreRemoveBio => 'Remove bio';

  @override
  String get coreReport => 'Report';

  @override
  String get coreReportCouldNotSubmit => 'Could not submit your report. Please try again.';

  @override
  String get coreReportDetailsHint => 'Anything else we should know';

  @override
  String get coreReportDetailsOptional => 'Details (optional)';

  @override
  String get coreReportReasonCopyright => 'Copyright / ownership';

  @override
  String get coreReportReasonHarassment => 'Harassment or hate';

  @override
  String get coreReportReasonOther => 'Other';

  @override
  String get coreReportReasonSexual => 'Sexual or adult content';

  @override
  String get coreReportReasonSpam => 'Spam or misleading';

  @override
  String get coreReportSent => 'Report sent. Thank you.';

  @override
  String get coreRestorePreviousWallpaperFailed =>
      'Couldn\'t restore the previous wallpaper. Set it again from Wallpaper history.';

  @override
  String get coreRetry => 'Try again';

  @override
  String get coreRetryImage => 'Retry image';

  @override
  String coreRetryOnScreen(String screen) {
    return 'Retry $screen';
  }

  @override
  String get coreSaveChanges => 'Save changes';

  @override
  String get coreSeeFullChangelog => 'See the full changelog';

  @override
  String get coreSeeMore => 'See more';

  @override
  String coreSelectCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString selected';
  }

  @override
  String get coreSendReport => 'Send report';

  @override
  String get coreSet => 'Set';

  @override
  String get coreSetItAsWallpaper => 'Set it as your wallpaper';

  @override
  String get coreSetWallpaper => 'Set as wallpaper';

  @override
  String coreSetWallpaperOn(String screen) {
    return 'Set as wallpaper on $screen';
  }

  @override
  String get coreShare => 'Share';

  @override
  String coreShareCardClipboard(String link) {
    return '🔥Check this out ➜ $link';
  }

  @override
  String get coreShareFormatStory => 'Story';

  @override
  String get coreShareFormatPost => 'Post';

  @override
  String get coreShareFormatClean => 'Clean';

  @override
  String get coreShareTargetInstagram => 'Instagram';

  @override
  String get coreShareTargetCopyLink => 'Copy link';

  @override
  String get coreShareOpenOnComputer => 'Open on computer';

  @override
  String get coreShareOpenOnComputerBody => 'Type this link in a browser on your computer, or scan the code.';

  @override
  String coreShareOpenOnComputerQr(String link) {
    return 'QR code for $link';
  }

  @override
  String get coreShareTargetSaveImage => 'Save image';

  @override
  String get coreShareTargetMore => 'More';

  @override
  String coreShareCardBy(String creator) {
    return 'by $creator';
  }

  @override
  String get coreShareImageSaved => 'Image saved';

  @override
  String get coreShareImageFailed => 'Couldn\'t save the image. Try again.';

  @override
  String get coreShareInstagramFailed => 'Couldn\'t open Instagram. Try again.';

  @override
  String get coreSharePreviewFailed => 'Couldn\'t make this image. More shares the link instead.';

  @override
  String get coreShareLinkCopied => 'Sharing link copied!';

  @override
  String coreShareProfileClipboard(String link) {
    return 'Hey check out my profile on Prism ➜ $link';
  }

  @override
  String coreShareWallpaperClipboard(String link) {
    return 'Hey check this out ➜ $link';
  }

  @override
  String get coreShareWallpaperGeneric => 'This bundled wallpaper is available in the Prism app.';

  @override
  String get coreSignInFeatureBody => 'Your account keeps your coins, favourites and uploads in one place.';

  @override
  String coreSignInFeatureTitle(String feature) {
    return 'Sign in to use $feature';
  }

  @override
  String get coreSignInPopupBody => 'Keep your favourites, uploads and coins on every device.';

  @override
  String get coreSignInPopupTitle => 'Sign in to Prism';

  @override
  String get coreSignInPromptAction => 'Sign in';

  @override
  String get coreSignInToReportContent => 'Sign in to report content';

  @override
  String get coreSignInToSyncFavourites => 'Sign in to keep your favourites on every device';

  @override
  String get coreSigningIn => 'Signing in';

  @override
  String get coreSomethingWentWrong => 'Something went wrong. Try again.';

  @override
  String coreStreakNext(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Next +$coinsString';
  }

  @override
  String coreStreakSemantics(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$daysString day streak, next reward $coinsString coins';
  }

  @override
  String get coreCustomAccent => 'Custom color';

  @override
  String get coreCustomAccentHex => 'Hex code';

  @override
  String get coreCustomAccentHue => 'Hue';

  @override
  String get coreCustomAccentSaturation => 'Saturation';

  @override
  String get coreCustomAccentLightness => 'Lightness';

  @override
  String get coreCustomAccentInvalidHex => 'Enter 6 hex digits, like #E57697.';

  @override
  String get coreCustomAccentLowContrast => 'This color is hard to see on this theme. Pick a lighter or darker shade.';

  @override
  String get coreCustomAccentApply => 'Use color';

  @override
  String coreThemeAccentSemanticLabel(int index, int count) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Accent colour $indexString of $countString';
  }

  @override
  String get coreThemeAmoled => 'AMOLED';

  @override
  String get coreThemeCoffee => 'Coffee';

  @override
  String get coreThemeCottonBlue => 'Cotton Blue';

  @override
  String get coreThemeCustom => 'Custom theme';

  @override
  String get coreThemeDeepOcean => 'Deep Ocean';

  @override
  String get coreThemeFrostWhite => 'Frost White';

  @override
  String get coreThemeJungle => 'Jungle';

  @override
  String get coreThemeLocked => 'Locked';

  @override
  String get coreThemeMaterialDark => 'Material Dark';

  @override
  String get coreThemeMaterialYou => 'Material You';

  @override
  String get coreThemeOlive => 'Olive';

  @override
  String get coreThemePepper => 'Pepper';

  @override
  String get coreThemeRose => 'Rose';

  @override
  String get coreThemeSky => 'Sky';

  @override
  String get coreThemeSteel => 'Steel';

  @override
  String get coreThemeSpooky => 'Spooky';

  @override
  String get spookyBannerTitle => 'The Spooky theme is here';

  @override
  String get spookyBannerSubtitle => 'Orange, black and a few spiders. Free. Tap to try it.';

  @override
  String get spookyAnnouncementTitle => 'New: the Spooky theme 🎃';

  @override
  String get spookyAnnouncementBody => 'Orange, black and a few spiders. It is free. Tap to try it.';

  @override
  String get coreThemeDiwali => 'Diwali';

  @override
  String get diwaliBannerTitle => 'The Diwali theme is here';

  @override
  String get diwaliBannerSubtitle => 'Diyas, fireworks and gold. Free. Tap to try it.';

  @override
  String get diwaliAnnouncementTitle => 'New: the Diwali theme 🪔';

  @override
  String get diwaliAnnouncementBody => 'Diyas, fireworks and gold. It is free. Tap to try it.';

  @override
  String get coreThemeWinter => 'Winter';

  @override
  String get winterBannerTitle => 'The Winter theme is here';

  @override
  String get winterBannerSubtitle => 'Cool blues and soft snow, in light and dark. Free. Tap to try it.';

  @override
  String get winterAnnouncementTitle => 'New: the Winter theme ❄️';

  @override
  String get winterAnnouncementBody => 'Cool blues and soft snow for the holidays. It is free. Tap to try it.';

  @override
  String get winterNewYearGreeting => 'Happy New Year';

  @override
  String get coreThisPageDoesNotExist => 'This page does not exist';

  @override
  String get coreTryAgain => 'Try again';

  @override
  String get coreUndo => 'Undo';

  @override
  String coreUp(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'up $coinsString';
  }

  @override
  String get coreUploadFailureDailyLimit => 'You reached today’s upload limit. Try again tomorrow.';

  @override
  String get coreUploadFailureFileType => 'That file type is not supported. Use a JPG, PNG, WebP or HEIC image.';

  @override
  String get coreUploadFailureGeneric => 'The upload did not finish. Your image is still here, so you can try again.';

  @override
  String get coreUploadFailureInProgress => 'An upload is already in progress. Wait a moment, then try again.';

  @override
  String get coreUploadFailureOversize => 'This image is over 15 MB. Choose a smaller one.';

  @override
  String get coreUploadFailureSignIn => 'Sign in again to upload.';

  @override
  String get coreUploadFailureWeeklyLimit => 'You reached this week’s free upload limit.';

  @override
  String get coreUploadSubmittedSuccess => 'Your wall is submitted and is under review.';

  @override
  String get coreUsername => 'Username';

  @override
  String get coreUsernameCheckFailed => 'Couldn\'t check the username. Try again.';

  @override
  String get coreUsernameRequiredToShareProfile => 'Set a username to share your profile';

  @override
  String get coreWallpaperApplied => 'Wallpaper set successfully!';

  @override
  String get coreWallpaperBothScreens => 'Both screens';

  @override
  String coreWallpaperBySemanticLabel(String name) {
    return 'Wallpaper by $name';
  }

  @override
  String get coreWallpaperDownloadedPictures => 'Wall downloaded in Pictures/Prism!';

  @override
  String get coreWallpaperEditApplyColorFailed => 'Couldn\'t apply the colour. Try again.';

  @override
  String get coreWallpaperErrorGeneric => 'Couldn\'t set the wallpaper.';

  @override
  String get coreWallpaperErrorImageTooLarge => 'This image is too large for your device to set.';

  @override
  String get coreWallpaperErrorInvalidVideo => 'That video cannot be played as a wallpaper. Try another clip.';

  @override
  String get coreWallpaperErrorLiveGeneric => 'Couldn\'t set the live wallpaper. Try again.';

  @override
  String get coreWallpaperErrorMemory => 'Not enough memory. Close other apps and try again.';

  @override
  String get coreWallpaperErrorNotAllowed => 'Your device or work profile does not allow wallpaper changes.';

  @override
  String get coreWallpaperErrorPermission => 'Prism does not have permission to read that file.';

  @override
  String get coreWallpaperErrorReadFile => 'Couldn\'t read the file. Try again.';

  @override
  String get coreWallpaperErrorSourceTooLarge => 'That file is too large for a live wallpaper.';

  @override
  String get coreWallpaperErrorStyle => 'This device could not start that style. Try another one.';

  @override
  String get coreWallpaperErrorSystemPreview => 'Couldn\'t open the system preview.';

  @override
  String get coreWallpaperErrorTextureDimensions => 'That image is too large for a live wallpaper.';

  @override
  String get coreWallpaperStillSetting => 'Still setting your wallpaper. This can take a moment on some phones.';

  @override
  String get coreWallpaperLockFailedUsePhone =>
      'Couldn\'t set the lock screen. Your phone\'s own wallpaper screen can set it.';

  @override
  String get coreWallpaperHomeSetLockFailedUsePhone =>
      'Home screen set. Couldn\'t set the lock screen. Your phone\'s own wallpaper screen can set it.';

  @override
  String get coreWallpaperSetWithPhone => 'Set with phone';

  @override
  String get coreWallpaperErrorTimeout => 'Timed out. Check your connection and try again.';

  @override
  String get coreWallpaperHomeScreen => 'Home screen';

  @override
  String get coreWallpaperHomeSetLockFailed => 'Home screen set. Lock screen failed.';

  @override
  String get coreWallpaperLinkCopyFailed => 'Couldn\'t copy the link. Try again.';

  @override
  String get coreWallpaperLinkCreateFailed => 'Couldn\'t create the share link. Try again.';

  @override
  String get coreWallpaperLoadTimedOut => 'Timed out loading the wallpaper. Check your connection and try again.';

  @override
  String get coreWallpaperLockScreen => 'Lock screen';

  @override
  String get coreWallpaperOfflineUnavailable =>
      'This wallpaper is not saved on this device. Connect to the internet and try again.';

  @override
  String coreWallpaperPartialSet(String applied, String failed) {
    return '$applied set. $failed failed.';
  }

  @override
  String get coreWallpaperPreviewDescription => 'Check out this amazing wallpaper from Prism.';

  @override
  String get coreWallpaperPreviewTitle => 'Wallpaper on Prism';

  @override
  String get coreWallpaperSaveFailed => 'Couldn\'t set the wallpaper. Try again.';

  @override
  String get coreWallpaperSavedPhotos => 'Saved to Photos.';

  @override
  String get coreWallpaperSavedToast => 'Your ad reward was added.';

  @override
  String coreWallpaperSavedWithTip(String saved, String tip) {
    return '$saved $tip';
  }

  @override
  String get coreWallpaperSemanticLabel => 'Wallpaper';

  @override
  String get coreWallpaperSet => 'Wallpaper set';

  @override
  String get coreWallpaperShareFailed => 'Couldn\'t share this wallpaper right now.';

  @override
  String get coreWallpaperShareRetryFailed => 'Couldn\'t share this wallpaper. Try again.';

  @override
  String get debugAdminReviewDescription => 'Content moderation and push notification tool';

  @override
  String get debugAdminShortcuts => 'Admin shortcuts';

  @override
  String get debugLiveActivityPreview => 'Preview Live Activity';

  @override
  String get debugLiveActivityPreviewDescription => 'Runs a sample AI generation activity: ready after 8 seconds';

  @override
  String get debugLiveActivityUnavailable => 'Live Activities are off or not supported';

  @override
  String get debugReviewActivityPreview => 'Preview review queue activity';

  @override
  String get debugReviewActivityPreviewDescription => 'Shows the walls waiting for review on the Lock Screen';

  @override
  String get debugAllTags => 'All tags';

  @override
  String get debugAndroidVersion => 'Android Version';

  @override
  String get debugAnimationSpeed => 'Animation speed';

  @override
  String get debugAppInfo => 'App info';

  @override
  String get debugAppName => 'App Name';

  @override
  String get debugAppVersion => 'App Version';

  @override
  String get debugAutoScrollOff => 'Turn off auto-scroll';

  @override
  String get debugAutoScrollOn => 'Turn on auto-scroll';

  @override
  String debugBackendName(String backend) {
    return 'Backend: $backend';
  }

  @override
  String get debugBoard => 'Board';

  @override
  String get debugBrand => 'Brand';

  @override
  String get debugBuildNumber => 'Build Number';

  @override
  String get debugBuildSignature => 'Build Signature';

  @override
  String get debugCacheCleared => 'App cache cleared';

  @override
  String get debugCancel => 'Cancel';

  @override
  String get debugCheckLogsRetry => 'Check the logs, then try again.';

  @override
  String get debugClear => 'Clear';

  @override
  String get debugClearAll => 'Clear all';

  @override
  String get debugClearAllStorageBody =>
      'This permanently deletes all locally stored data. The app may behave unexpectedly until restarted.';

  @override
  String get debugClearAllStorageTitle => 'Clear all storage?';

  @override
  String get debugClearAppCache => 'Clear app cache';

  @override
  String get debugClearAppCacheDescription => 'Clear images, feed and notification cache';

  @override
  String get debugClearImageCache => 'Clear image cache';

  @override
  String get debugClearImageCacheDescription => 'Evict in-memory image cache';

  @override
  String get debugClearLogsBody => 'This removes every log entry held in memory.';

  @override
  String get debugClearLogsTitle => 'Clear logs?';

  @override
  String get debugClearSearch => 'Clear search';

  @override
  String get debugCodePush => 'Code push';

  @override
  String get debugCoins => 'Coins';

  @override
  String get debugCopied => 'Copied';

  @override
  String get debugCopiedToClipboard => 'Copied to clipboard';

  @override
  String get debugCopy => 'Copy';

  @override
  String get debugCopyDiagnosticReport => 'Copy diagnostic report';

  @override
  String get debugCopyFiltered => 'Copy all (filtered)';

  @override
  String get debugCopyFullDetail => 'Copy full detail';

  @override
  String debugCopyTitle(String title) {
    return 'Copy $title';
  }

  @override
  String get debugCopyValue => 'Copy value';

  @override
  String debugCouldNotClearCache(String error) {
    return 'Could not clear the app cache: $error';
  }

  @override
  String get debugCouldNotSaveValue => 'Could not save the value';

  @override
  String get debugCrashApp => 'Crash the app';

  @override
  String get debugDangerZone => 'Danger zone';

  @override
  String get debugDarkCard => 'Dark card';

  @override
  String get debugDefaultValue => '(default)';

  @override
  String get debugDelete => 'Delete';

  @override
  String get debugDeleteKey => 'Delete key';

  @override
  String debugDeleteKeyBody(String key) {
    return 'Delete \"$key\" from local storage.';
  }

  @override
  String get debugDeleteKeyTitle => 'Delete key?';

  @override
  String get debugDevice => 'Device';

  @override
  String get debugDeviceName => 'Device';

  @override
  String get debugDevicePixelRatio => 'Device Pixel Ratio';

  @override
  String get debugDiagnosticCopied => 'Diagnostic report copied to clipboard';

  @override
  String get debugDiagnosticReportHeading => '=== Prism Debug Diagnostic Report ===';

  @override
  String get debugEditValue => 'Edit value';

  @override
  String get debugEmail => 'Email';

  @override
  String get debugEmptyList => 'Empty list';

  @override
  String get debugEnvironment => 'Environment';

  @override
  String get debugError => 'Error';

  @override
  String get debugErrorCopied => 'Error copied';

  @override
  String get debugErrorStreakLost => 'Error, streak lost';

  @override
  String get debugErrorValue => 'error';

  @override
  String get debugExportFile => 'Export as file';

  @override
  String get debugFavouriteAdded => 'Favourite added';

  @override
  String get debugFilterByTag => 'Filter by tag';

  @override
  String get debugFilterKeys => 'Filter keys';

  @override
  String get debugFingerprint => 'Fingerprint';

  @override
  String get debugFirestoreTelemetryDescription => 'View Firestore read and write profiling';

  @override
  String get debugFlagsReset => 'Debug flags reset';

  @override
  String get debugForceCrash => 'Force crash';

  @override
  String get debugForceCrashBody => 'This throws an exception to check that Sentry reports errors.';

  @override
  String get debugForceCrashDescription => 'Throw an exception to test Sentry reporting';

  @override
  String get debugForceCrashTitle => 'Force crash?';

  @override
  String debugGeneratedAt(String date) {
    return 'Generated: $date';
  }

  @override
  String get debugHardware => 'Hardware';

  @override
  String get debugIdentifier => 'Identifier';

  @override
  String get debugImageCacheCleared => 'Image cache cleared';

  @override
  String get debugIsAdmin => 'Is Admin';

  @override
  String get debugIsPremium => 'Is Premium';

  @override
  String get debugLevel => 'Level';

  @override
  String get debugLightCard => 'Light card';

  @override
  String get debugLoadingSearch => 'Loading, search';

  @override
  String get debugLogDetail => 'Log detail';

  @override
  String debugLogEntryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString entries',
      one: '$countString entry',
    );
    return '$_temp0';
  }

  @override
  String get debugLoggedIn => 'Logged In';

  @override
  String get debugLoggingAndNetwork => 'Logging and network';

  @override
  String get debugLogicalSize => 'Logical Size';

  @override
  String get debugLogs => 'Logs';

  @override
  String get debugLogsAppearHere => 'Log lines show up here as the app runs.';

  @override
  String get debugMaintenance => 'Maintenance';

  @override
  String get debugManufacturer => 'Manufacturer';

  @override
  String get debugMascot => 'Mascot';

  @override
  String get debugMessage => 'Message';

  @override
  String get debugMixpanelEnabled => 'Mixpanel Enabled';

  @override
  String get debugMixpanelTokenPresent => 'Mixpanel Token Present';

  @override
  String get debugModel => 'Model';

  @override
  String get debugMoodCalm => 'Calm';

  @override
  String get debugMoodCelebrate => 'Celebrate';

  @override
  String get debugMoodCurious => 'Curious';

  @override
  String get debugMoodHappy => 'Happy';

  @override
  String get debugMoodLove => 'Love';

  @override
  String get debugMoodProud => 'Proud';

  @override
  String get debugMoodSad => 'Sad';

  @override
  String get debugMoodSleepy => 'Sleepy';

  @override
  String get debugMoodSurprised => 'Surprised';

  @override
  String get debugMoodWorried => 'Worried';

  @override
  String get debugName => 'Name';

  @override
  String get debugNoKeysFound => 'No keys found';

  @override
  String get debugNoLogs => 'No logs';

  @override
  String get debugNoMatchingLogs => 'No log line matches the filters.';

  @override
  String get debugNotAvailable => 'N/A';

  @override
  String get debugNotSignedIn => 'Not signed in';

  @override
  String get debugNothingNew => 'Nothing new';

  @override
  String get debugOfflineStreakRisk => 'Offline, streak at risk';

  @override
  String get debugPackage => 'Package';

  @override
  String get debugPackageName => 'Package Name';

  @override
  String get debugPaintBaselines => 'Paint baselines';

  @override
  String get debugPaintBaselinesDescription => 'Show text baseline guides';

  @override
  String get debugPaintSize => 'Paint size';

  @override
  String get debugPaintSizeDescription => 'Show layout bounds on all widgets';

  @override
  String get debugPaintSizeWarning =>
      'Paint size, repaint rainbow and baselines only work in debug and profile builds.';

  @override
  String get debugPerformanceOverlay => 'Performance overlay';

  @override
  String get debugPerformanceOverlayDescription => 'GPU and CPU usage graphs';

  @override
  String get debugPersistenceBackend => 'Persistence Backend';

  @override
  String get debugPexelsKeyPresent => 'Pexels Key Present';

  @override
  String get debugPhysicalDevice => 'Is Physical Device';

  @override
  String get debugPhysicalSize => 'Physical Size';

  @override
  String get debugPlatform => 'Platform';

  @override
  String get debugRcApiKeyPresent => 'RC API Key Present';

  @override
  String get debugReduceMotionPose => 'Shows the reduce-motion pose of each mood';

  @override
  String get debugRefresh => 'Refresh';

  @override
  String get debugRemoteConfig => 'Remote Config';

  @override
  String get debugRemoteConfigUnavailable => 'Remote Config unavailable';

  @override
  String get debugRendering => 'Rendering';

  @override
  String get debugRepaintRainbow => 'Repaint rainbow';

  @override
  String get debugRepaintRainbowDescription => 'Highlight repainted areas in rotating colors';

  @override
  String get debugResetFlags => 'Reset all debug flags';

  @override
  String get debugResetFlagsDescription => 'Restore all toggles to default values';

  @override
  String get debugSave => 'Save';

  @override
  String get debugSaveValueAsText => 'Saving writes the value as text.';

  @override
  String get debugScreen => 'Screen';

  @override
  String get debugSdkInt => 'SDK Int';

  @override
  String get debugSearchLogs => 'Search logs';

  @override
  String get debugSemanticsDebugger => 'Semantics debugger';

  @override
  String get debugSemanticsDebuggerDescription => 'Overlay accessibility tree labels';

  @override
  String get debugSentryDsnPresent => 'Sentry DSN Present';

  @override
  String get debugSentryEnabled => 'Sentry Enabled';

  @override
  String get debugSentryEnv => 'Sentry Env';

  @override
  String get debugSequence => 'Sequence';

  @override
  String get debugShorebirdPatch => 'Shorebird patch';

  @override
  String get debugShowLogToasts => 'Show log toasts';

  @override
  String get debugShowLogToastsDescription => 'Display log entries as brief overlay toasts';

  @override
  String get debugSimulateNoInternet => 'Simulate no internet';

  @override
  String get debugSimulateNoInternetDescription => 'Overrides connectivity checks to report offline';

  @override
  String get debugSpeed => 'Speed';

  @override
  String get debugStackTrace => 'Stack trace';

  @override
  String get debugStackTraceCopied => 'Stack trace copied';

  @override
  String get debugStagingPatches => 'Get staging patches';

  @override
  String get debugStagingPatchesDescription =>
      'Check the Shorebird staging track instead of stable. Restart to apply a patch.';

  @override
  String get debugStillPoses => 'Still poses';

  @override
  String get debugStorage => 'Storage';

  @override
  String get debugStorageCleared => 'All storage cleared';

  @override
  String debugStorageKeyCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString keys',
      one: '$countString key',
    );
    return '$_temp0';
  }

  @override
  String get debugStorageNotInitialized => 'Storage not initialized';

  @override
  String get debugStorageReadError => 'Could not read storage';

  @override
  String get debugStreakCoinsPurchase => 'Streak, coins, purchase';

  @override
  String get debugStreakKeptToday => 'Streak kept today';

  @override
  String get debugSubscriptionTier => 'Subscription Tier';

  @override
  String get debugSystemName => 'System Name';

  @override
  String get debugSystemVersion => 'System Version';

  @override
  String get debugTime => 'Time';

  @override
  String get debugTitle => 'Debug';

  @override
  String get debugTools => 'Tools';

  @override
  String debugTypeName(String type) {
    return 'Type: $type';
  }

  @override
  String get debugUser => 'User';

  @override
  String get debugUserId => 'User ID';

  @override
  String get debugUsername => 'Username';

  @override
  String get debugValue => 'Value';

  @override
  String get debugVersion => 'Version';

  @override
  String get debugWallpaperSetSaved => 'Wallpaper set or saved';

  @override
  String get debugWotdNotification => 'Wall of the Day, notification';

  @override
  String get deepLinkInputChooseImage => 'Choose image';

  @override
  String get deepLinkInputChooseImageDescription => 'Choose an image from your gallery to continue.';

  @override
  String get deepLinkInputClockPreviewTitle => 'Clock preview';

  @override
  String get deepLinkInputEditTitle => 'Edit a wallpaper';

  @override
  String get deepLinkInputFiltersTitle => 'Wallpaper filters';

  @override
  String get deepLinkInputGalleryError => 'Could not open your gallery. Please try again.';

  @override
  String get deepLinkInputLiveTitle => 'Live wallpaper';

  @override
  String get deepLinkInputLiveDescription => 'Choose a photo from your gallery to make it a live wallpaper.';

  @override
  String get deepLinkInputPhotoPreviewTitle => 'Photo preview';

  @override
  String get deepLinkInputPositionTitle => 'Position a wallpaper';

  @override
  String get deepLinkInputUploadTitle => 'Upload a wallpaper';

  @override
  String get deepLinkInputWallpaperPreviewTitle => 'Wallpaper preview';

  @override
  String get economyActivity => 'Activity';

  @override
  String get economyActivityEmptyMessage => 'Watch a video or keep your streak to earn your first coins.';

  @override
  String get economyActivityLoadFailed => 'Couldn\'t load activity.';

  @override
  String get economyAdCreditFailure => 'Unable to credit coins right now.';

  @override
  String get economyAdDailyLimit => 'Daily limit reached. Back tomorrow.';

  @override
  String get economyAdNotCompleted => 'Ad was not completed.';

  @override
  String get economyAdOffline => 'You are offline. Check your connection and try again.';

  @override
  String economyAdRewardDetails(int first, int reward, int maximum) {
    final intl.NumberFormat firstNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String firstString = firstNumberFormat.format(first);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'First one of the day +$firstString, then +$rewardString. Up to $maximumString a day.';
  }

  @override
  String get economyAdRewardPending =>
      'We could not confirm your reward yet. The coins arrive when you are back online.';

  @override
  String get economyAdUnavailable => 'No ad is available right now. Try again later.';

  @override
  String get economyAddPhotoBio => 'Add a photo and a bio';

  @override
  String get economyAddedToBalance => 'Added to your balance';

  @override
  String get economyAddedToCollection => 'Added to your collection';

  @override
  String get economyAddedToXp => 'Added to your XP';

  @override
  String get economyAdsOffPrivacy => 'Ads are off. Change this in Settings > Privacy.';

  @override
  String get economyAiBusyRefunded => 'AI is very busy right now. Try again later. Your coins were returned.';

  @override
  String get economyAiChargeUnconfirmed => 'Couldn\'t confirm the charge. Any coins taken will be refunded.';

  @override
  String get economyAiCheckStatus => 'Check status';

  @override
  String economyAiCoinsNeeded(int cost, int balance) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'You need $costString coins. You have $balanceString.';
  }

  @override
  String get economyAiConnectToGenerate => 'No connection. Connect to the internet, then try again.';

  @override
  String get economyAiCouldNotConfirmSubmission =>
      'Could not confirm the submission. Check Review Status before trying again.';

  @override
  String get economyAiCropMayDiffer => 'Crop may differ slightly on your device.';

  @override
  String get aiLiveActivityGenerating => 'Creating your wallpaper';

  @override
  String get aiLiveActivityReady => 'Your wallpaper is ready';

  @override
  String get aiLiveActivityFailed => 'Couldn\'t create it';

  @override
  String get aiLiveActivityStale => 'Still working on it';

  @override
  String get aiLiveActivityOpen => 'Open in Prism';

  @override
  String get aiResultApply => 'Apply';

  @override
  String get aiResultEditPrompt => 'Edit prompt';

  @override
  String get aiSessionStripLabel => 'Wallpapers from this session';

  @override
  String aiSessionTake(int index, int count) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Take $indexString of $countString';
  }

  @override
  String get aiFollowUpWatercolour => 'As watercolour';

  @override
  String get aiFollowUpNight => 'Night version';

  @override
  String get aiFollowUpMinimal => 'More minimal';

  @override
  String get aiFollowUpWarmer => 'Warmer';

  @override
  String get aiFollowUpDepth => 'Add depth';

  @override
  String aiFollowUpCostLabel(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Each new take costs $costString coins';
  }

  @override
  String get aiFollowUpConfirmTitle => 'Make a new take?';

  @override
  String aiFollowUpConfirmBody(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'A follow-up makes a new wallpaper from this one. Each one costs $costString coins.';
  }

  @override
  String get aiFollowUpConfirmAction => 'Make it';

  @override
  String get economyAiDailyLimit => 'You reached today\'s AI limit.';

  @override
  String get economyAiDescribeChanges => 'Say what you want different, such as colors, mood or details.';

  @override
  String get economyAiDescribeScene => 'Describe a scene to generate.';

  @override
  String get economyAiDownloadFailed => 'Couldn\'t download! Please retry.';

  @override
  String economyAiFailureWithRefund(String message, String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'refunded': ' Coins refunded.',
      'pending': ' Refund pending.',
      'other': ' Refund could not be completed.',
    });
    return '$message$_temp0';
  }

  @override
  String get economyAiGenerate => 'Generate';

  @override
  String get economyAiGenerateAnother => 'Generate another';

  @override
  String get economyAiGenerateFailed => 'Couldn\'t generate right now. Try again.';

  @override
  String get economyAiGenerateGenericFailure => 'Something went wrong. Try again.';

  @override
  String get economyAiGeneratedWallpaper => 'Generated wallpaper';

  @override
  String economyAiGenerationFrom(String date) {
    return 'Generation from $date';
  }

  @override
  String get economyAiGenerationRollingOut => 'AI generation is currently rolling out. Please try again soon.';

  @override
  String get economyAiGenerationTime => 'This takes about 20 seconds';

  @override
  String get economyAiHistoryEmpty => 'Each wallpaper you generate appears here, so you can compare or switch back.';

  @override
  String get economyAiHistoryFailed => 'Couldn\'t load history. Pull to refresh.';

  @override
  String get economyAiMatchingScreenSize => 'Matching your screen size…';

  @override
  String get economyAiApplyingStyle => 'Applying your style…';

  @override
  String get economyAiFinalizingWallpaper => 'Finalizing your wallpaper…';

  @override
  String get economyAiRemixHint => 'Darker sky, warmer palette, softer edges…';

  @override
  String economyAiNeedCoinsToGenerate(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Need $costString coins to generate.';
  }

  @override
  String economyNeedMoreCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Need $countString more coins.',
      one: 'Need $countString more coin.',
    );
    return '$_temp0';
  }

  @override
  String get economyAiNoConnection => 'No connection. Check your network and try again.';

  @override
  String get economyAiNoConnectionRetry => 'No connection. Try again.';

  @override
  String get economyAiOfflineHistory => 'You\'re offline or the network failed. Pull to refresh when you\'re back.';

  @override
  String get economyAiOfflineSavedHistory => 'You\'re offline. Saved history is still available.';

  @override
  String get economyAiPaymentCheckFailed => 'Payment check failed. Your coins will be returned.';

  @override
  String get economyAiPreparingShare => 'Preparing share';

  @override
  String get economyAiPromptBlocked => 'That prompt is not allowed.';

  @override
  String economyAiPromptTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Description is too long (max $maximumString characters).';
  }

  @override
  String get economyAiQuality => 'Quality';

  @override
  String get economyAiQualityBalanced => 'Balanced';

  @override
  String get economyAiQualityFast => 'Fast';

  @override
  String get economyAiQualityHigh => 'Quality';

  @override
  String economyAiQualitySemantics(String quality, int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '$quality, $costString coins';
  }

  @override
  String get economyAiRecent => 'Recent';

  @override
  String get economyAiRefineExplanation =>
      'Say what should change. This makes a new wallpaper from the same prompt with a new seed, so it can look quite different.';

  @override
  String get economyAiResultBlocked => 'The result was blocked. Try another prompt.';

  @override
  String economyAiRolloutBody(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'It is on for $percentString% of accounts so far. Try again soon.';
  }

  @override
  String get economyAiRolloutTitle => 'AI wallpaper is opening gradually';

  @override
  String get economyAiSave => 'Save';

  @override
  String get economyAiSaveFailed => 'Couldn\'t save that file. Try again.';

  @override
  String get economyAiSceneIdea => 'Scene idea';

  @override
  String get economyAiSceneIdeaMessage => 'Use this scene in your description (editable)';

  @override
  String get economyAiSetAsWallpaper => 'Set as wallpaper';

  @override
  String get economyAiShare => 'Share';

  @override
  String get economyAiShareFailed => 'Could not share. Please try again.';

  @override
  String get economyAiShareReviewNotice =>
      'Moderators review submissions before they appear in Prism. Only share work you have rights to.';

  @override
  String get economyAiShareWithCommunity => 'Share with the community?';

  @override
  String get economyAiShuffle => 'Shuffle';

  @override
  String get economyAiShuffleMessage => 'Shuffle a new example description';

  @override
  String get economyAiStillWorking => 'Still working on your last image.';

  @override
  String get economyAiStyle => 'Style';

  @override
  String get economyAiStyleAbstract => 'Abstract';

  @override
  String get economyAiStyleAnime => 'Anime';

  @override
  String get economyAiStyleCyberpunk => 'Cyberpunk';

  @override
  String get economyAiStyleMeshGradient => 'Mesh Gradient';

  @override
  String get economyAiStyleMinimal => 'Minimal';

  @override
  String get economyAiStyleNature => 'Nature';

  @override
  String economyAiStyleSemantics(String style) {
    return 'Style: $style';
  }

  @override
  String get economyAiStyleSheetTitle => 'Choose a style';

  @override
  String get economyAiStyleSheetSubject => 'Every preview shows the same scene: a lighthouse on a cliff at dusk.';

  @override
  String get economyAiStyleWatercolor => 'Watercolor';

  @override
  String get economyAiStyleSpace => 'Space';

  @override
  String get economyAiStyleSynthwave => 'Synthwave';

  @override
  String get economyAiStylePixelArt => 'Pixel Art';

  @override
  String get economyAiStyleRender3d => '3D Render';

  @override
  String get economyAiStyleOilPainting => 'Oil Painting';

  @override
  String get economyAiStyleUkiyoE => 'Ukiyo-e';

  @override
  String get economyAiSubmissionUnconfirmed => 'Submission status is unconfirmed. Check before retrying.';

  @override
  String get economyAiSubmitDisabled => 'AI submit is currently disabled.';

  @override
  String get economyAiSubmitFailed => 'Submit failed. Please retry.';

  @override
  String get economyAiSubmitForReview => 'Submit for community review';

  @override
  String get economyAiSubmitStatusUnconfirmed =>
      'Submission status is unconfirmed. Check Review Status before trying again.';

  @override
  String get economyAiSubmittedForReview => 'Submitted for review.';

  @override
  String get economyAiTryAgain => 'Try again';

  @override
  String get economyAiTryAnother => 'Try another';

  @override
  String get economyAiTryAnotherVersion => 'Try another version';

  @override
  String get economyAiUnavailableBody => 'We turned it off for a short while. Check back soon.';

  @override
  String get economyAiUnavailableTitle => 'AI wallpaper is off for now';

  @override
  String economyAiVariationTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'That description is too long (max $maximumString characters).';
  }

  @override
  String get economyAiVariationUnavailable => 'Try another is not available right now.';

  @override
  String get economyAiWallpaper => 'AI wallpaper';

  @override
  String get economyAiWatermarkNote => 'Free images carry a Prism watermark. Pro removes it.';

  @override
  String get economyAllRankRewardsCollected => 'All rank rewards collected';

  @override
  String get economyAllSpinsUsed => 'All spins used';

  @override
  String get economyBackTomorrow => 'Back tomorrow';

  @override
  String get economyBadge => 'Badge';

  @override
  String get economyBadgeAiArtist => 'AI Artist';

  @override
  String get economyBadgeAiArtistDescription => 'Generate 10 AI wallpapers';

  @override
  String get economyBadgeArtCurator => 'Art Curator';

  @override
  String get economyBadgeArtCuratorDescription => 'Favourite 50 wallpapers';

  @override
  String get economyBadgeCollector => 'Collector';

  @override
  String get economyBadgeCollectorDescription => 'Favourite 10 wallpapers';

  @override
  String get economyBadgeCreator => 'Creator';

  @override
  String get economyBadgeCreatorDescription => 'Get a wallpaper approved';

  @override
  String get economyBadgeDescription => 'A badge in Prism';

  @override
  String get economyBadgeEarned => 'Badge earned';

  @override
  String economyBadgeEarnedCount(int count, int total) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$countString of $totalString earned';
  }

  @override
  String economyBadgeName(String name) {
    return '$name badge';
  }

  @override
  String get economyBadgePrismVeteran => 'Prism Veteran';

  @override
  String get economyBadgePrismVeteranDescription => 'Use Prism for 30 days and reach a 7 day streak';

  @override
  String get economyBadgeProfileComplete => 'Profile Complete';

  @override
  String get economyBadgeProfileCompleteDescription => 'Add a photo, username, bio and a link';

  @override
  String economyBadgeSemantics(String name, String status, String description) {
    return '$name, $status. $description';
  }

  @override
  String get economyBadgeSocialButterfly => 'Social Butterfly';

  @override
  String get economyBadgeSocialButterflyDescription => 'Follow 10 creators';

  @override
  String get economyBadgeStatusEarned => 'Earned';

  @override
  String get economyBadgeStatusLocked => 'Locked';

  @override
  String get economyBadgeStreakMaster => 'Streak Master';

  @override
  String get economyBadgeStreakMasterDescription => 'Reach a 28 day streak';

  @override
  String get economyBadgeWeekWarrior => 'Week Warrior';

  @override
  String get economyBadgeWeekWarriorDescription => 'Reach a 7 day streak';

  @override
  String get economyBadges => 'Badges';

  @override
  String economyBalanceSemantics(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString Prism coins';
  }

  @override
  String economyBestStreak(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString days', one: '1 day');
    return 'Best $_temp0';
  }

  @override
  String get economyBoost => 'Boost';

  @override
  String economyBoostInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Put one of your approved wallpapers at the front of Trending. A boost costs $amountString coins. Open your wallpaper and tap Boost.';
  }

  @override
  String get economyBuildStreakDaily => 'Open Prism every day to build a streak.';

  @override
  String get economyBuy => 'Buy';

  @override
  String get economyBuyPremium => 'Buy premium';

  @override
  String get economyCancel => 'Cancel';

  @override
  String get economyChestBonusDone => 'Bonus quest done: your coins are doubled.';

  @override
  String get economyChestBonusToDouble => 'Do today\'s bonus quest first to double your coins.';

  @override
  String economyChestBoosterSemantics(String title, String caption) {
    return '$title. $caption';
  }

  @override
  String economyChestCoinsPrize(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString coins', one: '1 coin');
    return '$_temp0';
  }

  @override
  String get economyChestDoFirst => 'Do this first to double your chest';

  @override
  String get economyChestDoubled => 'Chest doubled';

  @override
  String get economyChestDoubledByBonus => ' Doubled by your bonus quest.';

  @override
  String get economyChestFreeToday => 'Free today';

  @override
  String economyChestNeedCoins(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'The chest costs $priceString coins. You have $balanceString. Watch a video to earn more.';
  }

  @override
  String economyChestNewCosmetic(String kind, String name) {
    return 'a new $kind: $name';
  }

  @override
  String economyChestNewKind(String kind) {
    return 'New $kind';
  }

  @override
  String get economyChestOpenFailed => 'Couldn\'t reach Prism. Try again.';

  @override
  String economyChestOpenFor(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString more quests',
      one: '1 more quest',
    );
    return 'Open it for $priceString coins, or finish $_temp0 to open it free.';
  }

  @override
  String get economyChestOpened => 'Opened';

  @override
  String get economyChestOpenedDoubledTomorrow => 'Opened and doubled. A new one tomorrow.';

  @override
  String economyChestOpenedReset(String time) {
    return 'Opened. A new chest in $time.';
  }

  @override
  String get economyChestOpenedTomorrow => 'Opened. A new one tomorrow.';

  @override
  String get economyChestOwnCosmeticCoins => 'You own every cosmetic, so it pays coins';

  @override
  String get economyChestOwnEveryCosmetic => 'You own every cosmetic';

  @override
  String get economyChestPriceChanged => 'The price changed. Check it and open again.';

  @override
  String economyChestPriceFreeAfter(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString more quests',
      one: '1 more quest',
    );
    return '$priceString coins, or free after $_temp0';
  }

  @override
  String economyChestPrizeSemantics(String tier, String prize, String doubled, int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(doubled, {'true': ' Doubled by your bonus quest.', 'other': ''});
    String _temp1 = intl.Intl.pluralLogic(
      xp,
      locale: localeName,
      other: ' Plus $xpString XP.',
      one: ' Plus 1 XP.',
      zero: '',
    );
    return '$tier. You won $prize.$_temp0$_temp1';
  }

  @override
  String get economyChestQuestsFree => 'Your quests made it free today.';

  @override
  String get economyChestReady => 'Ready to open';

  @override
  String economyChestReadyPaid(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Ready to open. $doneString of $totalString quests done';
  }

  @override
  String economyChestResetHours(int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '${hoursString}h';
  }

  @override
  String economyChestResetHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '${hoursString}h ${minutesString}m';
  }

  @override
  String economyChestResetMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '${minutesString}m';
  }

  @override
  String get economyChestTierCommon => 'Common';

  @override
  String get economyChestTierEpic => 'Epic';

  @override
  String get economyChestTierLegendary => 'Legendary';

  @override
  String get economyChestTierRare => 'Rare';

  @override
  String economyChestXpLine(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Opening it gives $xpString XP.';
  }

  @override
  String get economyClaimedTodayDay7Chest => 'Today is done. Come back tomorrow for your day 7 chest.';

  @override
  String economyClaimedTodayReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Today is done. Come back tomorrow for +$coinsString coins.';
  }

  @override
  String get economyClosePreview => 'Close preview';

  @override
  String economyCoinActivitySemantics(String label, String date, String amount, int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'coins', one: 'coin');
    return '$label, $date, $amount $_temp0';
  }

  @override
  String economyCoinBalance(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Balance $balanceString';
  }

  @override
  String economyCoinGateRefundUnconfirmed(String action) {
    return '$action. Your refund could not be confirmed.';
  }

  @override
  String economyCoinGateRefunded(String action, int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString coins refunded.',
      one: '1 coin refunded.',
    );
    return '$action. $_temp0';
  }

  @override
  String get economyCoinHistoryEarned => 'Earned';

  @override
  String get economyCoinHistoryEmpty => 'No coin activity yet.';

  @override
  String get economyCoinHistoryLoadFailed => 'Couldn\'t load your coin history.';

  @override
  String get economyCoinHistoryNoLoadedRows => 'Nothing here in the rows loaded so far.';

  @override
  String get economyCoinHistoryNothingHere => 'Nothing here yet.';

  @override
  String get economyCoinHistoryRefunds => 'Refunds';

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
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'coins', one: 'coin');
    return '$label$_temp0, $date, $amount $_temp1, $balance';
  }

  @override
  String get economyCoinHistorySpent => 'Spent';

  @override
  String get economyCoinHistoryTitle => 'Coin history';

  @override
  String get economyCoinSpendFailed => 'Unable to process coins right now.';

  @override
  String economyCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString coins', one: '1 coin');
    return '$_temp0';
  }

  @override
  String get economyCoinsAreYoursToSpend => 'Coins are yours to spend';

  @override
  String economyCoinsEarned(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString coins', one: '1 coin');
    return '+$_temp0';
  }

  @override
  String economyCoinReward(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '+$countString';
  }

  @override
  String economyCoinsRange(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '+$minimumString to +$maximumString';
  }

  @override
  String get economyCoinsSpendingDetails =>
      'Coins pay for wallpapers, tools and Shop items. XP is progress, not a balance you spend. Spending coins never lowers your XP.';

  @override
  String get economyCoinsWhatYouCanDo => 'What you can do with them';

  @override
  String get economyCoinsWord => 'coins';

  @override
  String economyCollectionItemSemantics(String category, String status, String caption) {
    return '$category, $status. $caption';
  }

  @override
  String economyCollectionKeepStreakMessage(int days, int coins, String hasCoins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.selectLogic(hasCoins, {
      'true': ', or use $coinsString coins to unlock it now',
      'other': '',
    });
    return 'Keep a $daysString day streak to unlock this wallpaper$_temp0.';
  }

  @override
  String get economyCollectionLoadFailed => 'Could not load this collection';

  @override
  String economyCollectionNeedCoinsMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'You need $coinsString coins to unlock this wallpaper.';
  }

  @override
  String get economyCollectionRequirementsUnmet => 'This wallpaper is not available yet.';

  @override
  String get economyCollectionStillLocked => 'Still locked';

  @override
  String economyCollectionUnlockedAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Unlocked at a $daysString day streak';
  }

  @override
  String get economyCollectionUnlockedWithCoins => 'Unlocked with coins';

  @override
  String economyCollectionUnlocksAtCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Unlocks for $coinsString coins';
  }

  @override
  String economyCollectionUnlocksAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Unlocks at a $daysString day streak';
  }

  @override
  String get economyCompleteProfile => 'Complete your profile';

  @override
  String get economyCosmetic => 'cosmetic';

  @override
  String get economyCosmeticAppIcon => 'app icon';

  @override
  String get economyCosmeticFrame => 'frame';

  @override
  String get economyCosmeticNameGlow => 'name glow';

  @override
  String get economyCosmeticTheme => 'theme';

  @override
  String economyCountdownDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '${daysString}d ${hoursString}h';
  }

  @override
  String economyCountdownHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '${hoursString}h ${minutesString}m';
  }

  @override
  String economyCountdownMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '${minutesString}m';
  }

  @override
  String get economyCreatorApprovedWalls => 'Approved wallpapers';

  @override
  String get economyCreatorIntro =>
      'Earn XP when your wallpapers are approved and new members favourite them. Progress appears after your first qualifying contribution.';

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
    return '$label milestone';
  }

  @override
  String get economyCreatorMilestones => 'Creator milestones';

  @override
  String economyCreatorMilestonesComplete(String label) {
    return '$label milestones complete';
  }

  @override
  String economyCreatorNewMembersThisWeek(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString new members favourited your wallpapers this week';
  }

  @override
  String economyCreatorNextMilestone(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Next milestone: +$xpString XP';
  }

  @override
  String economyCreatorProgressSemantics(int current, int target) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$currentString of $targetString';
  }

  @override
  String get economyCreatorQualifyingMembers => 'Qualifying members';

  @override
  String get economyCreatorRefresh => 'Refresh progress';

  @override
  String get economyCreatorRefreshing => 'Refreshing creator progress…';

  @override
  String get economyCreatorRules =>
      'Approved wallpapers must be your own eligible uploads. Older uploads may be ineligible if Prism cannot verify the original upload. Each other member counts once across all your eligible work, on their first qualifying favourite. They must be signed in, have a verified email and an account at least seven days old. Your own favourites do not count. Counts are historical, not your current audience. Removing favourites does not undo XP. Creator milestones earn extra XP. Weeks run Monday to Sunday in UTC; delayed activity can appear in a later week.';

  @override
  String get economyCreatorSavedRefresh => 'Saved progress. Refresh to update.';

  @override
  String get economyCreatorSavedUnavailable => 'Saved progress. Refresh is unavailable.';

  @override
  String economyCreatorThisWeekSummary(int walls, int xp) {
    final intl.NumberFormat wallsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String wallsString = wallsNumberFormat.format(walls);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$wallsString eligible wallpapers approved · $xpString milestone XP';
  }

  @override
  String economyCreatorTrackingSince(String date) {
    return 'Tracking since $date UTC';
  }

  @override
  String get economyCreatorUnavailable => 'Creator progress is unavailable.';

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

    return '$wallsString eligible wallpapers approved · $membersString new qualifying members · $xpString milestone XP';
  }

  @override
  String get economyCreatorWhatCounts => 'What counts & history';

  @override
  String get economyDailyChest => 'Daily chest';

  @override
  String economyDailyChestSemantics(String state, String caption, String hasXp, String xpLine) {
    String _temp0 = intl.Intl.selectLogic(hasXp, {'true': '. $xpLine', 'other': ''});
    return 'Daily chest, $state. $caption$_temp0';
  }

  @override
  String get economyDailyChestTitle => 'Daily chest';

  @override
  String get economyDailyQuests => 'Daily quests';

  @override
  String get economyDailyStreak => 'Daily streak';

  @override
  String get economyDay7Chest => 'Day 7 chest';

  @override
  String economyDayLabel(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Day $dayString';
  }

  @override
  String economyDayStreakMilestone(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return '$daysString-day streak!';
  }

  @override
  String economyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'days', one: 'day');
    return '$_temp0';
  }

  @override
  String economyDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString days ago', one: '1 day ago');
    return '$_temp0';
  }

  @override
  String get economyDownload => 'Download';

  @override
  String get economyDownloadAccountChanged => 'Account changed. Please try saving again.';

  @override
  String get economyDownloadAgain => 'Download again';

  @override
  String economyDownloadAgainCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Download again (-$costString coins)';
  }

  @override
  String get economyDownloadAlreadyInDownloads => 'Already in Downloads';

  @override
  String economyDownloadCoinsNeeded(int missing, int reward, String watch, String adState) {
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(watch, {'true': ' Each ad adds $rewardString.', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(adState, {
      'disabled': ' Ads are off. Change this in Settings > Privacy.',
      'limit': ' Daily limit reached. Back tomorrow.',
      'other': '',
    });
    return 'You need $missingString more coins to save this wallpaper.$_temp0$_temp1';
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

    return '$label. Costs $costString coins';
  }

  @override
  String get economyDownloadFailedLabel => 'Download failed';

  @override
  String economyDownloadFreeDownloadsLeftSemantics(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString free downloads left',
      one: '1 free download left',
    );
    return '$label. Free, $_temp0';
  }

  @override
  String economyDownloadFreeFor(String label) {
    return '$label · Free';
  }

  @override
  String economyDownloadFreeLeftFor(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label · Free · $countString left';
  }

  @override
  String economyDownloadFreeOwnedSemantics(String label) {
    return '$label. Free, you own this wallpaper';
  }

  @override
  String economyDownloadFreeWithPassSemantics(String label) {
    return '$label. Free with your pass';
  }

  @override
  String get economyDownloadFreeWithPro => 'Free with Pro';

  @override
  String economyDownloadFreeWithProSemantics(String label) {
    return '$label. Free with Pro';
  }

  @override
  String get economyDownloadLinkUnavailable => 'No download link available.';

  @override
  String get economyDownloadProGuestMessage => 'Sign in to save this wallpaper with coins, or get Prism Pro.';

  @override
  String get economyDownloadSaveLocalCopy => 'Save local copy';

  @override
  String get economyDownloadSaved => 'Saved';

  @override
  String get economyDownloadSavedBefore => 'You saved this wallpaper before.';

  @override
  String get economyDownloadSavedInDownloads => 'Saved. Already in Downloads';

  @override
  String get economyDownloadThisWallpaper => 'Download this wallpaper';

  @override
  String get economyDownloadWaitForCurrent => 'Wait for download to complete!';

  @override
  String get economyDownloadWatchAdMessage => 'Watch a small video ad to download this wallpaper.';

  @override
  String get economyDownloadWatchAdPrivacyMessage =>
      'Watch a small video ad to download this wallpaper. Ads are off. Change this in Settings > Privacy.';

  @override
  String get economyDownloads => 'Downloads';

  @override
  String economyDownloadsInfo(int amount, int freeCount, String hasFree) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat freeCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String freeCountString = freeCountNumberFormat.format(freeCount);

    String _temp0 = intl.Intl.selectLogic(hasFree, {'true': ' Your first $freeCountString are free.', 'other': ''});
    return 'Each wallpaper download costs $amountString coins.$_temp0 Pro makes downloads free.';
  }

  @override
  String economyDrawAllTicketsHeld(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'You already hold all $maximumString tickets this week.';
  }

  @override
  String economyDrawBuyTicket(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Buy a ticket · $priceString';
  }

  @override
  String get economyDrawClosed => 'This draw is closed. The next one opens Monday.';

  @override
  String economyDrawClosesIn(String time) {
    return 'Closes in $time';
  }

  @override
  String get economyDrawLastWinner => 'Last winner';

  @override
  String get economyDrawLoadFailed => 'Couldn\'t load the Draw';

  @override
  String get economyDrawNotEnoughCoins => 'Not enough coins for a ticket.';

  @override
  String get economyDrawNotOpen => 'The Draw is not open yet.';

  @override
  String get economyDrawOfficialRules => 'Official rules';

  @override
  String economyDrawPrizeDescription(int months) {
    final intl.NumberFormat monthsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(months, locale: localeName, other: '$monthsString months', one: '1 month');
    return '$_temp0 of Pro + the Prism frame';
  }

  @override
  String get economyDrawProNotEligible => 'Pro members are not eligible.';

  @override
  String get economyDrawPurchaseFailed => 'Couldn\'t buy a ticket. Try again.';

  @override
  String get economyDrawThisWeeksPrize => 'THIS WEEK\'S PRIZE';

  @override
  String economyDrawTicketBought(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Ticket bought. You hold $ticketsString of $maximumString.';
  }

  @override
  String economyDrawTicketCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Tickets cost $priceString coins';
  }

  @override
  String economyDrawTicketsAndPeople(int tickets, int people) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat peopleNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String peopleString = peopleNumberFormat.format(people);

    String _temp0 = intl.Intl.pluralLogic(
      tickets,
      locale: localeName,
      other: '$ticketsString tickets',
      one: '1 ticket',
    );
    String _temp1 = intl.Intl.pluralLogic(people, locale: localeName, other: '$peopleString people', one: '1 person');
    return '$_temp0 from $_temp1';
  }

  @override
  String get economyDrawTitle => 'Prism Draw';

  @override
  String economyDrawYourChance(int mine, int pot) {
    final intl.NumberFormat mineNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String mineString = mineNumberFormat.format(mine);
    final intl.NumberFormat potNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String potString = potNumberFormat.format(pot);

    return 'Your chance: $mineString/$potString';
  }

  @override
  String economyDrawYourTickets(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Your tickets: $ticketsString of $maximumString';
  }

  @override
  String get economyDropAlreadyUnlocked => 'You already have this one.';

  @override
  String economyDropByCreator(String creator) {
    return 'by $creator';
  }

  @override
  String economyDropCardSemantics(String time, int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Weekly Drop, $time, $unlockedString of $totalString collected';
  }

  @override
  String economyDropCarouselDetail(int count, String time) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString walls', one: '1 wall');
    return '$_temp0 · $time';
  }

  @override
  String economyDropCarouselSemantics(String title, String detail, String lastCall) {
    String _temp0 = intl.Intl.selectLogic(lastCall, {'true': ', last call', 'other': ''});
    return 'Weekly Drop, $title, $detail$_temp0';
  }

  @override
  String economyDropCollected(int owned, int total) {
    final intl.NumberFormat ownedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ownedString = ownedNumberFormat.format(owned);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$ownedString of $totalString collected';
  }

  @override
  String economyDropDates(String start, String end) {
    return '$start to $end';
  }

  @override
  String get economyDropEnded => 'Ended';

  @override
  String get economyDropEndedHeadline => 'This Drop has ended';

  @override
  String economyDropEndsInDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '${daysString}d', one: '1d');
    String _temp1 = intl.Intl.pluralLogic(hours, locale: localeName, other: '${hoursString}h', one: '1h');
    return 'Ends in $_temp0 $_temp1';
  }

  @override
  String economyDropEndsInHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(hours, locale: localeName, other: '${hoursString}h', one: '1h');
    String _temp1 = intl.Intl.pluralLogic(minutes, locale: localeName, other: '${minutesString}m', one: '1m');
    return 'Ends in $_temp0 $_temp1';
  }

  @override
  String economyDropEndsInMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return 'Ends in ${minutesString}m';
  }

  @override
  String get economyDropGone => 'This Drop is gone';

  @override
  String get economyDropLastCallLabel => 'Last call';

  @override
  String get economyDropLoadFailed => 'Couldn\'t load the Drop';

  @override
  String get economyDropLocked => 'Locked';

  @override
  String get economyDropMissed => 'Missed';

  @override
  String get economyDropOver => 'This Drop is over.';

  @override
  String get economyDropPastDrops => 'Past drops';

  @override
  String economyDropPosition(int index, int total) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$indexString of $totalString';
  }

  @override
  String get economyDropPreviewTitle => 'Drop preview';

  @override
  String get economyDropRename => 'Rename Drop';

  @override
  String get economyDropRenameFailed => 'Couldn\'t rename the Drop. Try again.';

  @override
  String get economyDropRenameHint => 'Drop name';

  @override
  String get economyDropRenamed => 'Drop renamed';

  @override
  String economyDropSave(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Save $coinsString';
  }

  @override
  String economyDropStats(String walls, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString collectors',
      one: '1 collector',
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

    return 'Unlock all $countString for $priceString';
  }

  @override
  String get economyDropUnlockFailed => 'Couldn\'t unlock this. Try again.';

  @override
  String economyDropUnlockFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Unlock for $priceString';
  }

  @override
  String economyDropUnlockWall(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Unlock this wall for $priceString';
  }

  @override
  String get economyDropUnlocked => 'Unlocked';

  @override
  String economyDropUnlockedCount(int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$unlockedString/$totalString unlocked';
  }

  @override
  String economyDropUnlockedCountToast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString walls unlocked',
      one: 'Wall unlocked',
    );
    return '$_temp0';
  }

  @override
  String get economyDropUnlockedWall => 'Unlocked wall';

  @override
  String economyDropUnlockedWallBy(String creator) {
    return 'Unlocked wall by $creator';
  }

  @override
  String economyDropWallBySemantics(String state, String serial, String creator) {
    return '$state wall $serial by $creator';
  }

  @override
  String economyDropWallCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString walls', one: '1 wall');
    return '$_temp0';
  }

  @override
  String economyDropWallSemantics(String state, String serial) {
    return '$state wall $serial';
  }

  @override
  String get economyDropWallpaperUnavailable => 'This wallpaper is unavailable';

  @override
  String economyDropWeekOf(String date) {
    return 'Week of $date';
  }

  @override
  String get economyDropYourVault => 'Your vault';

  @override
  String get economyDrops => 'Drops';

  @override
  String get economyEarnCoins => 'Earn coins';

  @override
  String get economyEarnXpAsYouGo => 'Earn XP as you go';

  @override
  String economyEarnedAtRank(String rank) {
    return 'Earned at $rank';
  }

  @override
  String get economyEquipped => 'Equipped';

  @override
  String get economyEveryChestPays => 'Every chest pays something.';

  @override
  String get economyEverySpinPays => 'Every spin pays something.';

  @override
  String economyFallbackCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Pays $countString coins if you own them all';
  }

  @override
  String economyFinishDay7Chest(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Finish day 7 for a chest of +$minimumString to +$maximumString';
  }

  @override
  String get economyFinishStreakWeek => 'Finish a week of streak days.';

  @override
  String economyFirstDownloadsFree(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'First $countString free';
  }

  @override
  String get economyFirstUpload => 'First upload';

  @override
  String get economyFreeDailySpin => 'Free daily spin';

  @override
  String economyFreeDownloadsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString free left';
  }

  @override
  String get economyFreeSpin => 'Free spin';

  @override
  String economyFreeSpinReady(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '. $countString paid spins left today.',
      one: '. 1 paid spin left today.',
      zero: '',
    );
    return 'Free spin ready$_temp0';
  }

  @override
  String get economyFreezeAdded => 'Streak freeze added.';

  @override
  String economyFreezeAlreadyAtLimit(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString freezes', one: '1 freeze');
    return 'You already hold $_temp0.';
  }

  @override
  String economyFreezeBalanceAfter(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Balance after: $balanceString';
  }

  @override
  String economyFreezeBuyConfirm(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Buy a streak freeze for $costString coins?';
  }

  @override
  String get economyFreezeBuyFailed => 'Could not buy a freeze. Try again.';

  @override
  String economyFreezeCount(int held, int total) {
    final intl.NumberFormat heldNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String heldString = heldNumberFormat.format(held);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$heldString of $totalString';
  }

  @override
  String get economyFreezeDescription => 'Saves your streak if you miss a day. It applies on its own.';

  @override
  String get economyFreezeFull => 'Full';

  @override
  String economyFreezeGetOne(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Get one · $costString';
  }

  @override
  String get economyFreezeHeld => 'Freeze held';

  @override
  String economyFreezeNeedCoins(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'You need $costString coins.';
  }

  @override
  String get economyFreezeSlotEmpty => 'Empty freeze slot';

  @override
  String get economyFreezeUnavailable => 'Streak freeze is not available right now. Try again later.';

  @override
  String get economyFreshLeaderboardDetails =>
      'The leaderboard uses weekly XP, which resets every Monday at 00:00 UTC. Your lifetime XP, rank and earned cosmetics stay.';

  @override
  String get economyFreshLeaderboardWeekly => 'A fresh leaderboard each week';

  @override
  String get economyGetCoins => 'Get coins';

  @override
  String economyGetCoinsChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Get coins. The chest costs $priceString coins';
  }

  @override
  String economyGetCoinsForSpin(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Get coins. A spin costs $priceString coins';
  }

  @override
  String get economyGetFreezeNextTime => 'Get a freeze for next time';

  @override
  String get economyGetPro => 'Get Pro';

  @override
  String get economyGiftPass => 'Gift a pass';

  @override
  String economyGiftPassInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Give a friend 24 hours of Pro content for $amountString coins. Open their profile and tap Gift a 24 h pass.';
  }

  @override
  String get economyGotIt => 'Got it';

  @override
  String economyHighestRankReached(String rank) {
    return 'Highest rank reached: $rank';
  }

  @override
  String get economyHighestRankReachedShort => 'Highest rank reached';

  @override
  String get economyHomeScreen => 'Home screen';

  @override
  String get economyInviteFriend => 'Invite a friend';

  @override
  String get economyJackpotAddedToBalance => 'Jackpot. Added to your balance';

  @override
  String get economyKeepStreakToday => 'Open Prism today to keep your streak.';

  @override
  String get economyLastWeek => 'Last week';

  @override
  String economyLeaderboardEntrySemantics(int position, String name, String isMe, int xp, String hasRank, String rank) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(isMe, {'true': ', you', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(hasRank, {'true': ', $rank lifetime rank', 'other': ''});
    return '$positionString, $name$_temp0, $xpString XP this week$_temp1';
  }

  @override
  String get economyLeaderboardFollowTip => 'Your score is included. Follow creators to compare weekly XP.';

  @override
  String get economyLeaderboardFollowToSee => 'Follow creators to see them here.';

  @override
  String get economyLeaderboardFollowing => 'Following';

  @override
  String get economyLeaderboardFriendsCaption => 'You and people you follow · pull to refresh';

  @override
  String get economyLeaderboardFriendsDetails =>
      'Includes your score and up to the first 90 accounts you follow. Deleted accounts are left out; there is no minimum account age. Scores load when you first open this tab. Pull to refresh. Your score reflects your latest synced XP.';

  @override
  String get economyLeaderboardGlobal => 'Global';

  @override
  String get economyLeaderboardGlobalCaption => 'Top 50 · updated about every 3 hours';

  @override
  String get economyLeaderboardGlobalDetails =>
      'Shows up to 50 accounts by weekly XP. Accounts must be at least 7 days old; deleted accounts are left out. The snapshot updates about every 3 hours, so new XP may take time to appear. Pulling to refresh loads the latest snapshot.';

  @override
  String get economyLeaderboardHowScoringWorks => 'How leaderboard scoring works';

  @override
  String get economyLeaderboardLoadFailed => 'Couldn\'t load the leaderboard';

  @override
  String get economyLeaderboardNoRankings => 'No rankings yet';

  @override
  String get economyLeaderboardOffline => 'If you are offline, saved scores may be shown.';

  @override
  String get economyLeaderboardRankedByXp => 'Ranked by XP earned this week';

  @override
  String economyLeaderboardReset(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '${daysString}d', one: '1d');
    String _temp1 = intl.Intl.pluralLogic(hours, locale: localeName, other: '${hoursString}h', one: '1h');
    return 'Resets in $_temp0 $_temp1';
  }

  @override
  String get economyLeaderboardScoringIntro =>
      'Positions use XP earned this week. Rank labels, such as Silver, use lifetime XP. Weekly XP resets Monday at 00:00 UTC; lifetime XP and rank stay.';

  @override
  String get economyLeaderboardTitle => 'Leaderboard';

  @override
  String get economyLifetimePermanentDetails =>
      'Lifetime XP sets your rank and never resets. Rank cosmetics arrive automatically in your inventory, cost no coins and stay yours. Choose when to equip them in the Shop.';

  @override
  String get economyLifetimePermanentRewards => 'Lifetime progress, permanent rewards';

  @override
  String economyLifetimeXp(String xp) {
    return '$xp lifetime XP';
  }

  @override
  String get economyLifetimeXpNeverResets => 'Lifetime XP never resets.';

  @override
  String get economyLoadingVideo => 'Loading a video';

  @override
  String get economyLockScreen => 'Lock screen';

  @override
  String get economyMystery => 'Mystery';

  @override
  String get economyMysteryCosmetic => 'Mystery cosmetic';

  @override
  String get economyNewBadge => 'New badge';

  @override
  String economyNewCosmetic(String kind, String name) {
    return 'New $kind: $name';
  }

  @override
  String get economyNewUnknownCosmetic => 'New cosmetic';

  @override
  String get economyNextDropMonday => 'The next Drop lands Monday.';

  @override
  String economyNextReward(String reward) {
    return 'Next reward: $reward';
  }

  @override
  String get economyNice => 'Nice';

  @override
  String get economyNoDropNow => 'No Drop right now';

  @override
  String get economyNoSpinsLeft => 'No spins left today.';

  @override
  String get economyNotEnoughCoins => 'Not enough coins';

  @override
  String get economyNotNow => 'Not now';

  @override
  String economyOddsTierSemantics(String tier, String odds) {
    return '$tier, $odds';
  }

  @override
  String get economyOddsTitle => 'The odds';

  @override
  String get economyOnceADay => 'Once a day';

  @override
  String get economyOpen => 'Open';

  @override
  String economyOpenChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Open the chest, $priceString coins';
  }

  @override
  String get economyOpenChestFree => 'Open the chest, free';

  @override
  String get economyOpenChestLoading => 'Open the chest. Loading';

  @override
  String get economyOpenDaily => 'Open Prism every day.';

  @override
  String economyOpenDailyPro(String multiplier) {
    return 'Open Prism every day. Pro earns x$multiplier.';
  }

  @override
  String get economyOpenFree => 'Open free';

  @override
  String get economyOpenShop => 'Open Shop';

  @override
  String get economyOpening => 'Opening';

  @override
  String get economyOwned => 'Owned';

  @override
  String get economyPremiumCollection => 'Premium collection';

  @override
  String economyPriceCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString coins';
  }

  @override
  String economyPriceCoinsForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$amountString coins for $hoursString hours';
  }

  @override
  String economyPriceCoinsPerWall(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString a wall';
  }

  @override
  String economyPriceCoinsPerWallSemantics(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString coins a wall';
  }

  @override
  String economyPriceCoinsWithNote(int amount, String note, String hasNote) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(hasNote, {'true': ', $note', 'other': ''});
    return '$amountString coins$_temp0';
  }

  @override
  String economyPriceForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$amountString for $hoursString h';
  }

  @override
  String economyPriceFrom(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'from $amountString';
  }

  @override
  String economyPriceFromCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'from $amountString coins';
  }

  @override
  String get economyPrizeWheel => 'Prize wheel';

  @override
  String get economyPro => 'Pro';

  @override
  String get economyProDailyFreeSpin => 'Pro members get a free spin every day';

  @override
  String get economyProDownloadsFilters => 'With Pro, downloads and filters are free.';

  @override
  String get economyProPrice => 'Pro price';

  @override
  String get economyProWallpaper => 'Pro wallpaper';

  @override
  String get economyQuestBrowse10 => 'Look at 10 walls';

  @override
  String get economyQuestColourSearch => 'Search by colour';

  @override
  String economyQuestDoneMessage(int coins, int xp) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.pluralLogic(xp, locale: localeName, other: ' · +$xpString XP', zero: '');
    String _temp1 = intl.Intl.pluralLogic(xp, locale: localeName, other: ' · +$xpString XP', zero: '');
    String _temp2 = intl.Intl.pluralLogic(
      xp,
      locale: localeName,
      other: 'Quest done: +$xpString XP',
      zero: 'Quest done',
    );
    String _temp3 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Quest done: +$coinsString coins$_temp0',
      one: 'Quest done: +1 coin$_temp1',
      zero: '$_temp2',
    );
    return '$_temp3';
  }

  @override
  String get economyQuestDownload2 => 'Download 2 walls';

  @override
  String get economyQuestFav3 => 'Favourite 3 walls';

  @override
  String economyQuestNewIn(String time) {
    return 'New in $time';
  }

  @override
  String get economyQuestProSpin => 'Take your free spin';

  @override
  String get economyQuestSetWall => 'Set or save a wallpaper';

  @override
  String get economyQuestShareWall => 'Share a wallpaper';

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

    String _temp0 = intl.Intl.selectLogic(isDone, {'true': 'done', 'other': '$progressString of $targetString'});
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString coins', one: '1 coin');
    String _temp2 = intl.Intl.selectLogic(hasCoins, {'true': '. Earns $_temp1', 'other': ''});
    String _temp3 = intl.Intl.selectLogic(hasXp, {'true': '. Earns $xpString XP', 'other': ''});
    String _temp4 = intl.Intl.selectLogic(hasEnds, {'true': ', ends in $endsIn', 'other': ''});
    String _temp5 = intl.Intl.selectLogic(isWeekly, {'true': '. Weekly quest$_temp4', 'other': ''});
    return '$title, $_temp0$_temp2$_temp3$_temp5';
  }

  @override
  String get economyQuestTrending => 'See what\'s trending';

  @override
  String get economyQuestUnknown => 'Complete a quest';

  @override
  String get economyQuestWatchAd => 'Watch a video';

  @override
  String get economyQuestWeeklySet5 => 'Save or set 5 walls';

  @override
  String get economyQuestWotd => 'Open today\'s Wall of the Day';

  @override
  String get economyRankBronze => 'Bronze';

  @override
  String get economyRankGold => 'Gold';

  @override
  String get economyRankGrowsWithXp => 'Your rank grows with lifetime XP.';

  @override
  String economyRankInfoSemantics(String rank) {
    return '$rank rank. How XP and rank rewards work';
  }

  @override
  String get economyRankPrism => 'Prism';

  @override
  String economyRankProgressSemantics(String rank) {
    return '$rank rank progress';
  }

  @override
  String economyRankRewardAtRank(String rank, String xp) {
    return 'Yours automatically at $rank · $xp XP';
  }

  @override
  String economyRankRewardMilestone(String rank, String xp, String reward) {
    return '$rank · $xp XP\n$reward';
  }

  @override
  String get economyRankRewardSyncing => 'Syncing to your inventory. It is yours to keep.';

  @override
  String get economyRankRewardsHelp => 'How XP and rank rewards work';

  @override
  String get economyRankSilver => 'Silver';

  @override
  String economyRankTag(String rank) {
    return '$rank rank';
  }

  @override
  String get economyRankUnknown => 'Rank';

  @override
  String economyReferralBothGet(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString coins', one: '1 coin');
    return 'You both get $_temp0';
  }

  @override
  String get economyRestore => 'Restore';

  @override
  String economyRestoreStreak(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Restore your $daysString-day streak · $coinsString coins';
  }

  @override
  String economyRewardEarned(String reward) {
    return '$reward earned';
  }

  @override
  String get economyRewardsTitle => 'Rewards';

  @override
  String get economySameActivitySameXp => 'The same activity earns the same XP';

  @override
  String get economySameActivityXpDetails =>
      'Ads, Pro spins, Pro daily bonuses, referrals and refunds earn no XP. Pro and coin multipliers do not increase XP. Coin rewards stay separate.';

  @override
  String get economySeeAll => 'See all';

  @override
  String get economySeeBadges => 'See badges';

  @override
  String get economySeeItInShop => 'See it in the Shop';

  @override
  String get economySeeOdds => 'See the odds';

  @override
  String get economySeePro => 'See Pro';

  @override
  String get economySeeRewards => 'See rewards';

  @override
  String get economyShareWallpaper => 'Share a wallpaper';

  @override
  String get economyShopAlreadyOwned => 'You already own this';

  @override
  String get economyShopAurora => 'Aurora';

  @override
  String economyShopBuyFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Buy for $priceString';
  }

  @override
  String get economyShopChangeIconFailed => 'Could not change the icon';

  @override
  String economyShopCoinsShort(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'You need $countString more coins.';
  }

  @override
  String get economyShopCottonBlue => 'Cotton Blue';

  @override
  String get economyShopDeepOcean => 'Deep Ocean';

  @override
  String get economyShopDefaultIcon => 'Default';

  @override
  String get economyShopEarnXp => 'Earn XP';

  @override
  String economyShopEarnedAtLifetimeXp(String rank) {
    return 'Earned at $rank rank with lifetime XP.';
  }

  @override
  String get economyShopEmber => 'Ember';

  @override
  String get economyShopEquip => 'Equip';

  @override
  String get economyShopEquipFailed => 'Could not change this. Try again.';

  @override
  String economyShopEquipped(String name) {
    return '$name equipped';
  }

  @override
  String get economyShopFounders => 'Founders';

  @override
  String get economyShopFrames => 'Frames';

  @override
  String get economyShopGlass => 'Glass';

  @override
  String get economyShopGlowPreviewName => 'Glint';

  @override
  String get economyShopGlows => 'Glows';

  @override
  String get economyShopGold => 'Gold';

  @override
  String economyShopIconEnabled(String name) {
    return '$name icon is on';
  }

  @override
  String get economyShopIcons => 'Icons';

  @override
  String economyShopItemSemantics(String name, String status) {
    return '$name, $status';
  }

  @override
  String get economyShopJungle => 'Jungle';

  @override
  String get economyShopMono => 'Mono';

  @override
  String get economyShopNeedMoreCoins => 'You need more coins for this';

  @override
  String get economyShopNoir => 'Noir';

  @override
  String get economyShopOcean => 'Ocean';

  @override
  String get economyShopOlive => 'Olive';

  @override
  String get economyShopPepper => 'Pepper';

  @override
  String get economyShopPrism => 'Prism';

  @override
  String get economyShopProOnly => 'This item is for Pro members';

  @override
  String get economyShopPurchaseFailed => 'Could not buy this. Try again.';

  @override
  String economyShopPurchased(String name) {
    return '$name is yours';
  }

  @override
  String economyShopRankLocked(String rank) {
    return 'Reach $rank rank to unlock this';
  }

  @override
  String get economyShopRankReachedSyncing => 'Rank reached. Your reward is syncing.';

  @override
  String economyShopRankRewardSynced(String name) {
    return '$name rank reward synced';
  }

  @override
  String economyShopReachRankToBuy(String rank) {
    return 'Reach $rank rank to buy this.';
  }

  @override
  String get economyShopRing => 'Ring';

  @override
  String get economyShopRose => 'Rose';

  @override
  String economyShopSaleUntil(String date) {
    return 'Limited. On sale until $date.';
  }

  @override
  String get economyShopSky => 'Sky';

  @override
  String get economyShopSoldOut => 'This limited item is sold out';

  @override
  String get economyShopSteel => 'Steel';

  @override
  String get economyShopSunset => 'Sunset';

  @override
  String get economyShopSyncReward => 'Sync reward';

  @override
  String get economyShopThemes => 'Themes';

  @override
  String get economyShopTitle => 'Shop';

  @override
  String get economyShopUnequip => 'Unequip';

  @override
  String economyShopUnequipped(String name) {
    return '$name removed';
  }

  @override
  String get economyShopUseIcon => 'Use icon';

  @override
  String get economyShopUseTheme => 'Use theme';

  @override
  String get economyShopWearingNeedsPro => 'Wearing this needs Pro.';

  @override
  String get economyShowMore => 'Show more';

  @override
  String get economySignIn => 'Sign in';

  @override
  String get economySoldOut => 'Sold out';

  @override
  String get economySoon => 'soon';

  @override
  String economySpendItemSemantics(String label, String price) {
    return '$label, $price';
  }

  @override
  String get economySpin => 'SPIN';

  @override
  String get economySpinAgain => 'Spin again';

  @override
  String get economySpinAgainFree => 'Spin again, free spin';

  @override
  String economySpinAgainPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Spin again, $priceString coins';
  }

  @override
  String economySpinCardCaption(int price, int maximum) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '$priceString coins a spin. Win up to $maximumString coins or a cosmetic';
  }

  @override
  String economySpinCosts(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'A spin costs $priceString coins';
  }

  @override
  String get economySpinFree => 'Spin, free spin';

  @override
  String economySpinPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Spin, $priceString coins';
  }

  @override
  String get economySpinPriceChanged => 'The price changed. Check it and spin again.';

  @override
  String economySpinShortBalanceMessage(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'A spin costs $priceString coins. You have $balanceString. Watch a video to earn more.';
  }

  @override
  String get economySpinTheWheel => 'Spin the wheel';

  @override
  String economySpinWheelCardSemantics(String caption) {
    return 'Spin the wheel. $caption';
  }

  @override
  String get economySpinning => 'Spinning';

  @override
  String economySpinsLeftToday(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString spins', one: '1 spin');
    return '$_temp0 left today.';
  }

  @override
  String get economyStreak => 'STREAK';

  @override
  String economyStreakChestReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString Day 7 chest';
  }

  @override
  String get economyStreakCollection => 'Streak collection';

  @override
  String get economyStreakCollectionDescription => 'Unlock wallpapers by keeping your streak or using coins.';

  @override
  String economyStreakCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString days streak',
      one: '1 day streak',
    );
    return '$_temp0';
  }

  @override
  String economyStreakCycleSemantics(int day, String showReward, int reward, String state) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(showReward, {'true': ', plus $rewardString coins', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(state, {'done': ', done', 'today': ', today', 'other': ''});
    return 'Day $dayString$_temp0$_temp1';
  }

  @override
  String economyStreakDailyReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString today';
  }

  @override
  String economyStreakDayNumber(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Day $dayString of your streak';
  }

  @override
  String get economyStreakFreeze => 'Streak freeze';

  @override
  String economyStreakFreezeSaved(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'A freeze saved your $daysString-day streak';
  }

  @override
  String economyStreakFreezesLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString freezes left',
      one: '1 freeze left',
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
  String get economyStreakRescueCooldown => 'You can restore one streak every 30 days.';

  @override
  String get economyStreakRescueExpired => 'The 48 hours to restore this streak are over.';

  @override
  String get economyStreakRescueFailed => 'Couldn\'t restore your streak. Try again.';

  @override
  String get economyStreakRescueUnavailable => 'This streak can\'t be restored now.';

  @override
  String get economyStreakReset => 'Your streak reset';

  @override
  String economyStreakResetMessage(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'You were on $daysString days. Start again today, +$coinsString coins.';
  }

  @override
  String economyStreakRestoreShort(int balance, int cost) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'You have $balanceString. You need $costString.';
  }

  @override
  String get economyStreakRestored => 'Your streak is back';

  @override
  String economyStreakRestoredCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'You are on $countString days again.';
  }

  @override
  String get economyToday => 'Today';

  @override
  String get economyUnknownCosmetic => 'Cosmetic';

  @override
  String economyUntil(String date) {
    return 'Until $date';
  }

  @override
  String economyUpToCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Up to +$countString';
  }

  @override
  String get economyUpgradeToPro => 'Upgrade to Pro';

  @override
  String economyUseReward(String reward) {
    return 'Use $reward';
  }

  @override
  String get economyUseYourCoins => 'Use your coins';

  @override
  String get economyWatchAd => 'Watch ad';

  @override
  String get economyWatchVideo => 'Watch a video';

  @override
  String economyWatchVideoRewardAdsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString ads', one: '1 ad');
    return 'Watch a video · $_temp0 left today';
  }

  @override
  String economyWatchVideoRewardCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Watch a video (+$coinsString)';
  }

  @override
  String get economyWeekComplete => 'Week complete!';

  @override
  String get economyWeekly => 'Weekly';

  @override
  String get economyWeeklyDraw => 'Weekly draw';

  @override
  String get economyWeeklyDrop => 'Weekly Drop';

  @override
  String economyWeeklyEndsIn(String time) {
    return 'Weekly · $time';
  }

  @override
  String get economyWeeklyXpFriendsEveryone => 'Weekly XP, friends and everyone';

  @override
  String economyWonCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString coins', one: '1 coin');
    return 'You won $_temp0';
  }

  @override
  String economyWonCosmetic(String kind, String name) {
    return 'You won a new $kind: $name';
  }

  @override
  String get economyWonUnknownCosmetic => 'You won a cosmetic';

  @override
  String economyWonXp(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'You won $xpString XP';
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

    return 'Daily streaks earn $dailyStreakString XP, plus $streakWeekString XP for completing a seven-day cycle. Quest chests earn $questChestString XP. Your first valid upload earns $uploadString XP; profile completion earns $profileString XP. Daily quests award $dailyQuestString XP each; the weekly quest awards $weeklyQuestString XP. Some badges and creator milestones also earn XP.';
  }

  @override
  String economyXpAwarded(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '+$xpString XP';
  }

  @override
  String get economyXpRanksRewards => 'XP, ranks & rewards';

  @override
  String economyXpToRank(String xp, String rank) {
    return '$xp XP to $rank';
  }

  @override
  String get economyXpUnit => 'XP';

  @override
  String get economyYesterday => 'Yesterday';

  @override
  String economyYouHaveCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'You have $countString coins';
  }

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork => 'Check your connection and try again.';

  @override
  String get navigationBackOnline => 'Back online';

  @override
  String get navigationNoInternetConnection => 'No internet connection';

  @override
  String get navigationScrollToTop => 'Scroll to top';

  @override
  String get notifActivateToCollapse => 'Activate to collapse.';

  @override
  String get notifActivateToExpand => 'Activate to expand.';

  @override
  String get notifChannelDownloads => 'Downloads';

  @override
  String get notifChannelDownloadsDescription => 'Get notifications for download progress of wallpapers.';

  @override
  String get notifChannelDraw => 'Prism Draw';

  @override
  String get notifChannelDrawDescription => 'Draw results and prizes.';

  @override
  String get notifChannelDrops => 'Weekly Drops';

  @override
  String get notifChannelDropsDescription => 'When a new Drop is live and before it ends.';

  @override
  String get notifChannelFollowers => 'Followers';

  @override
  String get notifChannelFollowersDescription => 'Get notifications for new followers.';

  @override
  String get notifChannelGifts => 'Gifts';

  @override
  String get notifChannelGiftsDescription => 'A friend sent you a Pro pass.';

  @override
  String get notifChannelGroup => 'Notifications';

  @override
  String get notifChannelGroupDescription => 'All Prism Notifications';

  @override
  String get notifChannelModeration => 'Moderation';

  @override
  String get notifChannelModerationDescription => 'Reports and review requests for Prism admins.';

  @override
  String get notifChannelPosts => 'Posts';

  @override
  String get notifChannelPostsDescription => 'Get notifications for posts from artists you follow.';

  @override
  String get notifChannelRecommendations => 'Recommendations';

  @override
  String get notifChannelRecommendationsDescription => 'Get notifications for recommendations from Prism.';

  @override
  String get notifChannelStreaks => 'Streak reminders';

  @override
  String get notifChannelStreaksDescription => '8 PM reminder to keep your login streak alive.';

  @override
  String get notifChannelWotd => 'Wall of the Day';

  @override
  String get notifChannelWotdDescription => 'Daily featured wallpaper notification at 9 AM.';

  @override
  String get notifClearDeviceMessage => 'This removes them from this device.';

  @override
  String get notifClearInbox => 'Clear inbox';

  @override
  String get notifClearInboxAction => 'Clear inbox';

  @override
  String notifClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Clear $countString notifications?';
  }

  @override
  String get notifClearOneTitle => 'Clear this notification?';

  @override
  String get notifCollapsed => 'Collapsed';

  @override
  String notifDownloadedTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString walls downloaded.',
      one: '1 wall downloaded.',
    );
    return '$_temp0';
  }

  @override
  String get notifDownloadingWallpaper => 'Downloading wallpaper';

  @override
  String get notifEmptyBody => 'New followers, approvals and the Wall of the Day show up here.';

  @override
  String get notifEmptyTitle => 'No notifications';

  @override
  String get notifExpanded => 'Expanded';

  @override
  String get notifGenericTitle => 'Notification';

  @override
  String notifGroupApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'approvals', one: 'approval');
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
      other: '$otherCountString other creators.',
      one: '1 other creator.',
    );
    return 'From $name and $_temp0';
  }

  @override
  String notifGroupDailyPicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'daily picks', one: 'daily pick');
    return '$_temp0';
  }

  @override
  String get notifGroupDayRows => 'Each row is a different day; times are on the right.';

  @override
  String notifGroupFollowerSummary(String name, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString others followed you.',
      one: '1 other followed you.',
    );
    return '$name and $_temp0';
  }

  @override
  String notifGroupFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'new followers', one: 'new follower');
    return '$_temp0';
  }

  @override
  String get notifGroupHide => 'Hide';

  @override
  String notifGroupNotifications(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'notifications', one: 'notification');
    return '$_temp0';
  }

  @override
  String notifGroupNotificationsRemoved(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString notifications removed',
      one: '1 notification removed',
    );
    return '$_temp0';
  }

  @override
  String notifGroupSameMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Same message sent $countString times. Compare timestamps to see when.';
  }

  @override
  String notifGroupSemantics(String title, String summary, String expandedState, String unreadStatus, String action) {
    return '$title. $summary. $expandedState. $unreadStatus $action';
  }

  @override
  String get notifGroupSeveralCreators => 'Several creators. Expand to see each wall.';

  @override
  String get notifGroupShowAll => 'Show all';

  @override
  String notifGroupSummaryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString notifications in this group.',
      one: '1 notification in this group.',
    );
    return '$_temp0';
  }

  @override
  String notifGroupWallLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'walls went live', one: 'wall went live');
    return '$_temp0';
  }

  @override
  String get notifHasUnread => 'Has unread.';

  @override
  String get notifInboxCleared => 'Inbox cleared';

  @override
  String get notifLoadErrorTitle => 'We couldn\'t load your notifications';

  @override
  String get notifMarkAllRead => 'Mark all as read';

  @override
  String get notifOfflineSaved => 'Couldn\'t load new notifications. What you see below is saved on this device.';

  @override
  String get notifOpenSettings => 'Open settings';

  @override
  String get notifPermissionOff => 'Notifications are off. Turn them on in system settings first.';

  @override
  String get notifPermissionOffForApp => 'Notifications are off for Prism.';

  @override
  String get notifPreferences => 'Notification preferences';

  @override
  String get notifPushDrawWinnerBody => 'One month of Pro and the Prism frame are yours.';

  @override
  String get notifPushDrawWinnerTitle => 'You won the Prism Draw';

  @override
  String notifPushDropLastCallBody(String dropTitle, int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(hours, locale: localeName, other: '$hoursString hours', one: '1 hour');
    return '$dropTitle ends in $_temp0. Then these walls are gone for a month.';
  }

  @override
  String get notifPushDropLastCallTitle => 'Last call on this week\'s Drop';

  @override
  String notifPushDropLiveBody(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString walls, this week only. Preview them before they are gone.',
      one: '1 wall, this week only. Preview it before it is gone.',
    );
    return '$_temp0';
  }

  @override
  String get notifPushDropLiveTitle => 'A new Drop is live';

  @override
  String notifPushFollowDigestTitleOne(String artistName) {
    return '$artistName posted a new wall';
  }

  @override
  String notifPushFollowDigestTitleSolo(String artistName, int wallCount) {
    return '$artistName posted $wallCount new walls';
  }

  @override
  String notifPushFollowDigestTitlePair(String artistName, String secondArtistName, int wallCount) {
    return '$artistName and $secondArtistName posted $wallCount new walls';
  }

  @override
  String notifPushFollowDigestTitleGroup(String artistName, int otherCount, int wallCount) {
    return '$artistName and $otherCount others posted $wallCount new walls';
  }

  @override
  String get notifPushFollowDigestBodyUntitled => 'Tap to see them all.';

  @override
  String get notifPushGiftReceivedBody => 'Premium collections and premium walls are open until tomorrow.';

  @override
  String notifPushGiftReceivedTitle(String senderName) {
    return '$senderName sent you a 24-hour Pro pass';
  }

  @override
  String notifPushNewContentReportBody(String contentType, String reason, String targetId) {
    return '$contentType · $reason · doc $targetId';
  }

  @override
  String get notifPushNewContentReportTitle => 'New content report';

  @override
  String notifPushNewFollowerBody(String followerName) {
    return '$followerName is now following you.';
  }

  @override
  String get notifPushNewFollowerTitle => 'You have a new follower! 🎉';

  @override
  String notifPushReportReviewBody(String contentType, String reason) {
    return '$contentType · $reason · open for over 12 hours';
  }

  @override
  String get notifPushReportReviewTitle => 'Report waiting for review';

  @override
  String get notifPushStreakReminderBody => 'Open Prism now to keep your login streak alive 🔥';

  @override
  String get notifPushStreakReminderTitle => 'Your streak is about to break!';

  @override
  String notifPushWallApprovedAdminBody(String wallTitle, String artistName) {
    return '\"$wallTitle\" by $artistName is now live.';
  }

  @override
  String get notifPushWallApprovedAdminTitle => 'Wall approved ✅';

  @override
  String notifPushWallApprovedArtistBody(String wallTitle) {
    return '\"$wallTitle\" has been approved and is now visible to everyone.';
  }

  @override
  String get notifPushWallApprovedArtistBodyUntitled =>
      'Your wallpaper has been approved and is now visible to everyone.';

  @override
  String get notifPushWallsReleasedArtistTitle => 'Your wall is live';

  @override
  String get notifPushWallsReleasedArtistTitleMany => 'Your walls are live';

  @override
  String notifPushWallsReleasedArtistBody(String wallTitle) {
    return '\"$wallTitle\" is now public on Prism.';
  }

  @override
  String get notifPushWallsReleasedArtistBodyUntitled => 'Your wall is now public on Prism.';

  @override
  String notifPushWallsReleasedArtistBodyMany(int count) {
    return '$count walls are now public on Prism.';
  }

  @override
  String get notifPushWallApprovedArtistTitle => 'Your wallpaper is live! 🎉';

  @override
  String get notifPushDesktopVersionApprovedTitle => 'Your desktop version is live';

  @override
  String notifPushDesktopVersionApprovedBody(String wallTitle) {
    return '\"$wallTitle\" now has a desktop version.';
  }

  @override
  String get notifPushDesktopVersionApprovedBodyUntitled => 'Your wallpaper now has a desktop version.';

  @override
  String get notifPushDesktopVersionRejectedTitle => 'Desktop version not approved';

  @override
  String notifPushDesktopVersionRejectedBody(String reason) {
    return 'Reason: $reason';
  }

  @override
  String notifPushWallLiveFollowersBody(String wallTitle) {
    return '\"$wallTitle\" is now live on Prism.';
  }

  @override
  String notifPushWallLiveFollowersTitle(String artistName) {
    return 'New wall by $artistName';
  }

  @override
  String notifPushWallSubmittedBody(String artistName, String artistEmail) {
    return 'New post by $artistName ($artistEmail) is up for review.';
  }

  @override
  String get notifPushWallSubmittedTitle => 'New Premium Wall for review! 🎉';

  @override
  String get notifPushWinBack14Body => 'Come see what creators added this fortnight.';

  @override
  String get notifPushWinBack14Title => 'New walls are waiting';

  @override
  String get notifPushWinBack30Body => 'Make a wallpaper that feels like you.';

  @override
  String get notifPushWinBack30Title => 'New AI styles to try';

  @override
  String get notifPushWinBack60Body => 'Your next favourite wall is a tap away.';

  @override
  String get notifPushWinBack60Title => 'Prism misses you';

  @override
  String get notifPushWinBack7Body => 'Fresh wallpapers landed while you were away.';

  @override
  String get notifPushWinBack7Title => 'Your feed has new walls';

  @override
  String notifPushWotdAudienceBody(String wallTitle) {
    return '$wallTitle';
  }

  @override
  String get notifPushWotdAudienceBodyUntitled => 'Open Prism to see today\'s Wall of the Day.';

  @override
  String get notifPushWotdAudienceTitle => 'Today\'s Wall of the Day is here';

  @override
  String get notifPushWotdCreatorBody => 'Prism picked your wallpaper for everyone today. Thank you for sharing it.';

  @override
  String get notifPushWotdCreatorTitle => 'Your wallpaper is the Wall of the Day';

  @override
  String get notifRead => 'Already read';

  @override
  String get notifRemoved => 'Notification removed';

  @override
  String get notifReportUnknownContentType => 'content';

  @override
  String notifSemanticsRow(String message, String time, String readStatus) {
    return '$message. $time. $readStatus';
  }

  @override
  String get notifSettingDrops => 'Weekly Drops';

  @override
  String get notifSettingDropsDescription => 'Alerts when a new Drop is live and before it ends.';

  @override
  String get notifSettingFollowers => 'Followers';

  @override
  String get notifSettingFollowersDescription => 'Alerts when someone new follows you or comments on your walls.';

  @override
  String get notifSettingPosts => 'Posts';

  @override
  String get notifSettingPostsDescription => 'Alerts when creators you follow share new work.';

  @override
  String get notifSettingRecommendations => 'Recommendations';

  @override
  String get notifSettingRecommendationsDescription => 'Tips, news and wallpaper picks from Prism.';

  @override
  String get notifSettingStreaks => 'Streak reminders';

  @override
  String get notifSettingStreaksDescription => 'Evening heads-up around 8 PM if your login streak is about to break.';

  @override
  String get notifSettingWotd => 'Wall of the Day';

  @override
  String get notifSettingWotdDescription => 'A daily wallpaper pick.';

  @override
  String get notifSignInToChange => 'Sign in to change this setting.';

  @override
  String get notifSignInToTurnOn => 'Sign in to turn on';

  @override
  String get notifTapToOpenPrism => 'Tap to open Prism.';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifToday => 'Today';

  @override
  String get notifUndo => 'Undo';

  @override
  String get notifUnread => 'Not read yet';

  @override
  String get notifYesterday => 'Yesterday';

  @override
  String notifYesterdayAt(String time) {
    return 'Yesterday, $time';
  }

  @override
  String get onboardingAiGenerateError => 'something went wrong.\ntap generate to try again.';

  @override
  String get onboardingAiGeneratePrompt => 'tap generate to create\nyour unique wallpaper';

  @override
  String get onboardingAiGenerating => 'crafting your wallpaper…';

  @override
  String get onboardingBrowseGuest => 'Browse without an account';

  @override
  String get onboardingCategoriesUnavailable => 'we could not load categories, you can skip this step';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingContinueApple => 'Continue with Apple';

  @override
  String get onboardingContinueGoogle => 'Continue with Google';

  @override
  String onboardingContinueSelected(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Continue ($countString selected)';
  }

  @override
  String get onboardingCouldNotLogOut => 'Could not log out. Please try again.';

  @override
  String get onboardingCreatorsUnavailable => 'we could not load creators, you can skip this step';

  @override
  String get onboardingFirstAiWallpaper => 'your first wallpaper, generated by AI';

  @override
  String get onboardingFirstWallpaperSaveFailed => 'Couldn\'t save your wallpaper. Try again or skip.';

  @override
  String get onboardingFirstWallpaperSavedPhotos => 'Saved to Photos!';

  @override
  String get onboardingFirstWallpaperSet => 'Wallpaper set!';

  @override
  String get onboardingFirstWallpaperSetFailed => 'Couldn\'t set your wallpaper. Try again or skip.';

  @override
  String get onboardingFirstWallpaperSetHome => 'Wallpaper set on your home screen.';

  @override
  String get onboardingFirstWallpaperSetHomeLock => 'Wallpaper set on your home and lock screens.';

  @override
  String get onboardingFirstWallpaperSetLock => 'Wallpaper set on your lock screen.';

  @override
  String get onboardingFollow => 'follow';

  @override
  String onboardingFollowCreatorMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'we are suggesting you follow these $countString creators';
  }

  @override
  String onboardingFollowerCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString followers',
      one: '$countString follower',
    );
    return '$_temp0';
  }

  @override
  String get onboardingFollowing => 'following';

  @override
  String get onboardingGenerateFailure => 'something went wrong — tap generate to try again';

  @override
  String get onboardingGenerateSuccess => 'looking good! opening your wallpaper';

  @override
  String get onboardingGenerateWallpaper => 'Generate my wallpaper';

  @override
  String get onboardingHeadlineCreators => 'Find your people';

  @override
  String get onboardingHeadlineCustomize => 'Make it yours';

  @override
  String get onboardingHeadlineGenerate => 'Create your\nfirst wallpaper';

  @override
  String get onboardingHeadlineInterests => 'Pick your vibe';

  @override
  String get onboardingLoadCategoriesFailed => 'We could not load categories.';

  @override
  String get onboardingLoadCreatorsFailed => 'We could not load creators.';

  @override
  String get onboardingPro => 'Pro';

  @override
  String get onboardingProFree => '  →  free for you';

  @override
  String get onboardingRecoveryCreatorsFailed => 'Couldn\'t load creators. Check your connection and tap Reload.';

  @override
  String get onboardingRecoveryFollowFailed => 'Couldn\'t follow these creators. Try again.';

  @override
  String get onboardingRecoveryFollowFailedHelper =>
      'couldn\'t follow these creators. check your connection and try again';

  @override
  String get onboardingRecoveryReload => 'Reload';

  @override
  String get onboardingRecoveryRetry => 'Try again';

  @override
  String get onboardingRecoverySaveInterestsFailed => 'Couldn\'t save your picks. Try again.';

  @override
  String get onboardingRecoverySaveInterestsFailedHelper =>
      'couldn\'t save your picks. check your connection and try again';

  @override
  String get onboardingRecoverySessionExpired => 'Your session has expired. Please sign in again.';

  @override
  String get onboardingRecoverySessionExpiredHelper => 'your session has expired. sign in again to continue';

  @override
  String get onboardingRecoverySetupFailed => 'Couldn\'t finish setup. Try again.';

  @override
  String get onboardingRecoverySetupFailedHelper => 'couldn\'t finish setup. check your connection and try again';

  @override
  String get onboardingRecoverySignIn => 'Sign in again';

  @override
  String get onboardingReloadLower => 'Reload';

  @override
  String get onboardingSavePhotos => 'Save to photos';

  @override
  String onboardingSelectInterestMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Select at least $countString categories to personalize your feed';
  }

  @override
  String get onboardingSetWallpaper => 'Set as wallpaper';

  @override
  String get onboardingSignInAgainLower => 'Sign in again';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingSkipLower => 'Skip';

  @override
  String get onboardingTermsRequired => 'Please agree to the Terms and Privacy policy first.';

  @override
  String get onboardingTryAgainLower => 'Try again';

  @override
  String onboardingWallpaperForInterest(String category) {
    return 'we picked this wallpaper based on your interest in $category';
  }

  @override
  String get onboardingWallpaperJustForYou => 'we picked this wallpaper just for you';

  @override
  String get onboardingWelcomeDescription => 'Millions of premium wallpapers from top artists.';

  @override
  String get onboardingWelcomeHeadline => 'Your screen, reimagined.';

  @override
  String get premiumPageExplorePlans => 'Explore Prism Premium plans.';

  @override
  String get premiumPagePlansUnavailable => 'Plans are not available right now. Check your connection and try again.';

  @override
  String get premiumPageTitle => 'Prism Premium';

  @override
  String get premiumPageTryAgain => 'Try again';

  @override
  String get premiumPageViewPlans => 'View plans';

  @override
  String get premiumPageHeadline => 'The whole gallery, unlocked';

  @override
  String get premiumBenefitWalls => 'Every premium collection and wallpaper';

  @override
  String get premiumBenefitFree => 'Free downloads and no ads';

  @override
  String get premiumBenefitSpin => 'A free spin every day';

  @override
  String get premiumBenefitAutomation => 'Auto-rotate and day and night mode';

  @override
  String get premiumBenefitLiveStyles => 'Every live wallpaper style';

  @override
  String get premiumBenefitAiClean => 'AI wallpapers with no watermark, for fewer coins';

  @override
  String get premiumGuestStorePurchaseActive =>
      'Your store purchase is active on this device. Sign in to use account-based Pro features.';

  @override
  String get premiumPurchasePending => 'Your purchase is saved. Pro can take a minute to unlock.';

  @override
  String get premiumPaymentPending => 'Your payment is pending. Pro unlocks when the payment goes through.';

  @override
  String get premiumPurchaseUnconfirmed => 'Could not confirm your purchase. Try Restore purchases in Settings.';

  @override
  String get updatesStoreUpdateAvailable => 'A new version of Prism is available.';

  @override
  String get wallpaperAccentColor => 'Accent color';

  @override
  String get wallpaperAccentColorsOriginal => 'Original wallpaper colors';

  @override
  String get wallpaperResetOriginal => 'Reset to original';

  @override
  String get wallpaperAll => 'All';

  @override
  String get wallpaperApplyTo => 'Apply to';

  @override
  String get wallpaperAutoRotateApplyTo => 'Apply to';

  @override
  String get wallpaperAutoRotateBatterySteps =>
      'Open Settings, then Apps, Prism, Battery. Set battery use to Unrestricted.';

  @override
  String get wallpaperAutoRotateBatteryTip =>
      'If wallpapers stop changing, set battery use for Prism to Unrestricted. Open settings, then Apps, Prism, Battery.';

  @override
  String get wallpaperAutoRotateBothScreens => 'Both';

  @override
  String get wallpaperAutoRotateChangeError => 'Could not change wallpaper.';

  @override
  String get wallpaperAutoRotateChangeLabel => 'Change';

  @override
  String get wallpaperAutoRotateChargingDescription => 'Change when plugged in, at most once per interval';

  @override
  String get wallpaperAutoRotateChargingOnly => 'Only while charging';

  @override
  String get wallpaperAutoRotateCopySteps => 'Copy steps';

  @override
  String get wallpaperAutoRotateCouldNotStart => 'Could not start. Try again.';

  @override
  String wallpaperAutoRotateDownloadedCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: 'wallpapers', one: 'wallpaper');
    return 'Downloaded $cachedString of $totalString $_temp0';
  }

  @override
  String wallpaperAutoRotateEnabledUntil(String date) {
    return 'Pass active until $date';
  }

  @override
  String get wallpaperAutoRotateGotIt => 'Got it';

  @override
  String get wallpaperAutoRotateHomeScreen => 'Home screen';

  @override
  String get wallpaperAutoRotateInterval12Hours => 'Every 12 hours';

  @override
  String get wallpaperAutoRotateInterval15 => 'Every 15 min (battery heavy)';

  @override
  String get wallpaperAutoRotateInterval30 => 'Every 30 min';

  @override
  String get wallpaperAutoRotateInterval3Days => 'Every 3 days';

  @override
  String get wallpaperAutoRotateInterval3Hours => 'Every 3 hours';

  @override
  String get wallpaperAutoRotateInterval6Hours => 'Every 6 hours';

  @override
  String get wallpaperAutoRotateIntervalDay => 'Every day';

  @override
  String get wallpaperAutoRotateIntervalHour => 'Every hour';

  @override
  String get wallpaperAutoRotateIntervalWeek => 'Every week';

  @override
  String get wallpaperAutoRotateKeepRunning => 'Keep it running';

  @override
  String get wallpaperAutoRotateLoadError => 'Could not load auto-rotate settings.';

  @override
  String get wallpaperAutoRotateLoadingWalls => 'Loading wallpapers';

  @override
  String get wallpaperAutoRotateLockScreen => 'Lock screen';

  @override
  String wallpaperAutoRotateMix(int count, String source) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers from $source in the mix',
      one: '1 wallpaper from $source in the mix',
    );
    return '$_temp0';
  }

  @override
  String wallpaperAutoRotateMixCapped(int count, String source) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers from $source in the mix. Using your first 100.',
      one: '1 wallpaper from $source in the mix. Using your first 100.',
    );
    return '$_temp0';
  }

  @override
  String wallpaperAutoRotateNextChange(String time) {
    return 'Next change around $time';
  }

  @override
  String wallpaperAutoRotateNounCategory(String category) {
    return '$category';
  }

  @override
  String get wallpaperAutoRotateNounDownloads => 'downloads';

  @override
  String get wallpaperAutoRotateNounFavourites => 'favourites';

  @override
  String get wallpaperAutoRotateNounHistory => 'your history';

  @override
  String get wallpaperAutoRotateNounWotd => 'Wall of the Day picks';

  @override
  String get wallpaperAutoRotateOff => 'Off';

  @override
  String get wallpaperAutoRotateOffEnded => 'Auto-rotate is off because your Prism Pro plan or pass ended.';

  @override
  String get wallpaperAutoRotateOpenDownloads => 'Open downloads';

  @override
  String get wallpaperAutoRotateOpenFavourites => 'Open favourites';

  @override
  String get wallpaperAutoRotatePassEnabled => 'Auto-rotate is on for 7 days.';

  @override
  String wallpaperAutoRotatePassPurchase(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '7-day pass · $coinsString coins';
  }

  @override
  String get wallpaperAutoRotatePickCategory => 'Pick a category';

  @override
  String wallpaperAutoRotatePreparing(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers',
      one: '1 wallpaper',
    );
    return 'Preparing $_temp0';
  }

  @override
  String get wallpaperAutoRotateProBody => 'Try it for 7 days with coins, or get Prism Pro.';

  @override
  String get wallpaperAutoRotateProTitle => 'Auto-rotate is a Prism Pro feature.';

  @override
  String wallpaperAutoRotateReadyCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: 'wallpapers', one: 'wallpaper');
    return '$cachedString of $totalString $_temp0 ready';
  }

  @override
  String get wallpaperAutoRotateScheduled => 'Scheduled';

  @override
  String get wallpaperAutoRotateShuffle => 'Shuffle';

  @override
  String get wallpaperAutoRotateShuffleDescription => 'Random order instead of one after another';

  @override
  String get wallpaperAutoRotateSourceCategory => 'Category';

  @override
  String get wallpaperAutoRotateSourceDownloads => 'Downloads';

  @override
  String get wallpaperAutoRotateSourceFavourites => 'Favourites';

  @override
  String get wallpaperAutoRotateSourceHistory => 'History';

  @override
  String get wallpaperAutoRotateSourceLabel => 'Source';

  @override
  String get wallpaperAutoRotateSourceLoadError => 'Could not load wallpapers. Check your connection.';

  @override
  String get wallpaperAutoRotateSourceWotd => 'Wall of the Day';

  @override
  String get wallpaperAutoRotateStartError => 'Could not start wallpaper rotation.';

  @override
  String get wallpaperAutoRotateStarting => 'Starting';

  @override
  String get wallpaperAutoRotateStatusLabel => 'Status';

  @override
  String get wallpaperAutoRotateStepsCopied => 'Steps copied.';

  @override
  String get wallpaperAutoRotateStopError => 'Could not stop wallpaper rotation.';

  @override
  String get wallpaperAutoRotateTitle => 'Auto-rotate';

  @override
  String get wallpaperAutoRotateTooFewCategory => 'This category has fewer than 2 wallpapers. Pick another one.';

  @override
  String get wallpaperAutoRotateTooFewDownloads => 'Download at least 2 wallpapers to rotate them.';

  @override
  String get wallpaperAutoRotateTooFewFavourites => 'Favourite at least 2 wallpapers to rotate them.';

  @override
  String get wallpaperAutoRotateTooFewHistory => 'Set at least 2 wallpapers from Prism to rotate them.';

  @override
  String get wallpaperAutoRotateTooFewWotd => 'There are not enough past picks yet.';

  @override
  String get wallpaperAutoRotateUnlockError => 'Couldn\'t unlock auto-rotate. Try again.';

  @override
  String get wallpaperAutoRotateUpdateError => 'Could not update auto-rotate.';

  @override
  String get wallpaperBack => 'Back';

  @override
  String get wallpaperBlockCreator => 'Block creator';

  @override
  String get wallpaperBlockCreatorNotFound => 'Couldn\'t find this creator. Try again.';

  @override
  String get wallpaperBoostAlready => 'Already boosted.';

  @override
  String wallpaperBoostAlreadyUntil(String time) {
    return 'Already boosted until $time.';
  }

  @override
  String wallpaperBoostConfirmButton(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Boost for $coinsString coins';
  }

  @override
  String wallpaperBoostConfirmMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Show this wallpaper in the Home carousel and at the top of Trending for 24 hours for $coinsString coins.';
  }

  @override
  String wallpaperBoostDurationAndCost(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '24 hours at the top · $coinsString coins';
  }

  @override
  String get wallpaperBoostFailed => 'Couldn\'t boost this wallpaper. Try again.';

  @override
  String get wallpaperBoostOnlyApproved => 'Only approved wallpapers you uploaded can be boosted.';

  @override
  String get wallpaperBoostSlotsTaken => 'All boost slots are taken. Try again later.';

  @override
  String wallpaperBoostSlotsTakenUntil(String time) {
    return 'All boost slots are taken. The next one frees up $time.';
  }

  @override
  String get wallpaperBoostTitle => 'Boost to Trending';

  @override
  String get wallpaperBoostedSuccess => 'Boosted. It is live on Home and in Trending.';

  @override
  String get wallpaperBoostedTag => 'Boosted';

  @override
  String wallpaperBoostedUntil(String time) {
    return 'Boosted until $time';
  }

  @override
  String get wallpaperBrowseWallpapers => 'Browse wallpapers';

  @override
  String wallpaperByCreator(String name) {
    return 'Wallpaper by $name';
  }

  @override
  String get wallpaperByPrismCreator => 'Wallpaper by Prism creator';

  @override
  String get wallpaperCategories => 'Categories';

  @override
  String get wallpaperCategory => 'Category';

  @override
  String get wallpaperCategoryFeedEmptyBody => 'New ones land often. Check back soon.';

  @override
  String get wallpaperCategoryFeedEmptyTitle => 'No wallpapers here yet';

  @override
  String wallpaperCategoryNamed(String name) {
    return 'Category, $name';
  }

  @override
  String get wallpaperChangeNow => 'Change now';

  @override
  String get wallpaperCheckBackSoon => 'Check back soon.';

  @override
  String get wallpaperCheckBackTomorrow => 'Check back tomorrow.';

  @override
  String get wallpaperCheckConnection => 'Check your connection and try again.';

  @override
  String get wallpaperClear => 'Clear';

  @override
  String get wallpaperClearFilters => 'Clear filters';

  @override
  String get wallpaperClearHistoryAction => 'Clear history';

  @override
  String get wallpaperClearHistoryBody =>
      'This removes the list of wallpapers you set. Your wallpapers stay as they are.';

  @override
  String get wallpaperClearHistoryTitle => 'Clear history?';

  @override
  String get wallpaperClearSearch => 'Clear search';

  @override
  String get wallpaperClosePreview => 'Close preview';

  @override
  String get wallpaperCollapseDetails => 'Collapse wallpaper details';

  @override
  String get wallpaperCollection => 'Collection';

  @override
  String get wallpaperCollectionLoadError => 'Couldn\'t load this collection';

  @override
  String wallpaperCollectionNamed(String name) {
    return 'Collection, $name';
  }

  @override
  String wallpaperCollectionPreviewUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Preview unlocked for 24 hours (-$coinsString coins).';
  }

  @override
  String get wallpaperCollectionRefreshError => 'Couldn\'t refresh. Pull down to try again.';

  @override
  String get wallpaperCollectionsEmptyBody => 'Pull down to refresh, or check back soon.';

  @override
  String get wallpaperCollectionsEmptyTitle => 'No collections yet';

  @override
  String get wallpaperCopyAccentHexHint => 'Long press to copy hex color';

  @override
  String wallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers',
      one: '1 wallpaper',
      zero: 'No wallpapers',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDelete => 'Delete';

  @override
  String get wallpaperDeleteManyDownloadsBody =>
      'They are removed from this device. You can download them again later.';

  @override
  String wallpaperDeleteManyDownloadsTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Delete $countString downloads?';
  }

  @override
  String get wallpaperDeleteOneDownloadBody => 'It is removed from this device. You can download it again later.';

  @override
  String get wallpaperDeleteOneDownloadTitle => 'Delete this download?';

  @override
  String get wallpaperDepthEditorSubtitle => 'In the Lock Screen editor, tap ••• then Depth Effect.';

  @override
  String get wallpaperDepthEffect => 'Depth Effect';

  @override
  String get wallpaperDepthSubjectSubtitle => 'Your subject sits in front of the clock.';

  @override
  String get wallpaperSpatialScene => 'Spatial Scene';

  @override
  String get wallpaperSpatialGreatSubtitle => 'Clear depth. Makes a strong 3D Lock Screen.';

  @override
  String get wallpaperSpatialOkSubtitle => 'Some depth. The 3D effect is gentle.';

  @override
  String get wallpaperSpatialGuideTitle => 'Set it as a Spatial Scene';

  @override
  String get wallpaperSpatialGuideBody => 'On iPhone 12 or later with iOS 26:';

  @override
  String get wallpaperSpatialStepSave => 'Save this wall to Photos.';

  @override
  String get wallpaperSpatialStepPick =>
      'On the Lock Screen, touch and hold your screen. Tap the Add button, tap Photos, then select the photo.';

  @override
  String get wallpaperSpatialStepButton => 'Tap the Spatial Scene button to turn the 3D effect on, then tap Add.';

  @override
  String get wallpaperSpatialPreviewLabel => '3D';

  @override
  String get wallpaperSpatialPreviewOn => 'Preview in 3D';

  @override
  String get wallpaperSpatialPreviewOff => 'Turn off the 3D preview';

  @override
  String get wallpaperSpatialDragHint => 'Drag to tilt';

  @override
  String get wallpaperDetailColorCodeCopied => 'Color code copied to clipboard';

  @override
  String get wallpaperDetailNotFound => 'Wallpaper not found';

  @override
  String get wallpaperDiscard => 'Discard';

  @override
  String get wallpaperDismiss => 'Dismiss';

  @override
  String get wallpaperDownload => 'Download';

  @override
  String wallpaperDownloadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString downloads',
      one: '1 download',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadSortName => 'Name';

  @override
  String get wallpaperDownloadSortNewest => 'Newest';

  @override
  String get wallpaperDownloadSortOldest => 'Oldest';

  @override
  String get wallpaperDownloadWallpaper => 'Download wallpaper';

  @override
  String get wallpaperDownloadedWallpaper => 'Downloaded wallpaper';

  @override
  String get wallpaperDownloadedWallpaperUnavailable => 'Downloaded wallpaper is unavailable';

  @override
  String wallpaperDownloadsDeleteError(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn\'t delete $countString downloads.',
      one: 'Couldn\'t delete 1 download.',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadsEmptyBody => 'Wallpapers you download are kept here.';

  @override
  String get wallpaperDownloadsEmptyTitle => 'No downloads yet';

  @override
  String get wallpaperDownloadsLoadError => 'Couldn\'t load your downloads';

  @override
  String get wallpaperDownloadsLoadHelp => 'Check your storage access and try again.';

  @override
  String get wallpaperDownloadsRefreshError => 'Couldn\'t refresh downloads. Try again.';

  @override
  String get wallpaperDownloadsShareError => 'Couldn\'t share. Try again.';

  @override
  String get wallpaperDownloadsTitle => 'Downloads';

  @override
  String get wallpaperEdit => 'Edit';

  @override
  String get wallpaperEditTitle => 'Edit wallpaper';

  @override
  String get wallpaperExpandDetails => 'Expand wallpaper details';

  @override
  String get wallpaperFavourite => 'Favourite';

  @override
  String get wallpaperFavouriteAddedToast => 'Added to favourites.';

  @override
  String get wallpaperFavouriteClearAccountMessage => 'This removes them from your account.';

  @override
  String get wallpaperFavouriteClearAll => 'Clear all favourites';

  @override
  String get wallpaperFavouriteClearDeviceMessage => 'This removes them from this device.';

  @override
  String get wallpaperFavouriteClearError => 'Couldn\'t clear favourites. Try again.';

  @override
  String wallpaperFavouriteClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Clear $countString favourites?';
  }

  @override
  String get wallpaperFavouriteClearOneTitle => 'Clear 1 favourite?';

  @override
  String wallpaperFavouriteClearedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favourites',
      one: '1 favourite',
    );
    return 'Cleared $_temp0';
  }

  @override
  String get wallpaperFavouriteClearedOne => 'Cleared 1 favourite';

  @override
  String wallpaperFavouriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favourites',
      one: '1 favourite',
      zero: 'No favourites',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteEmptyBody => 'Tap the heart on a wallpaper to keep it here.';

  @override
  String get wallpaperFavouriteEmptyTitle => 'No favourites yet';

  @override
  String get wallpaperFavouriteExport => 'Export favourites';

  @override
  String get wallpaperFavouriteExportEmpty => 'No favourites to export yet.';

  @override
  String get wallpaperFavouriteExportError => 'Couldn\'t export favourites. Try again.';

  @override
  String get wallpaperFavouriteGuestPrompt => 'Sign in to keep them on every device';

  @override
  String get wallpaperFavouriteLoadError => 'Couldn\'t load your favourites';

  @override
  String get wallpaperFavouriteMoreActions => 'More favourites actions';

  @override
  String get wallpaperFavouriteNoMatch => 'No matching favourites';

  @override
  String get wallpaperFavouriteNotSynced => 'Not synced';

  @override
  String get wallpaperFavouriteRefreshFallback => 'Couldn\'t refresh favourites. Showing your saved list.';

  @override
  String get wallpaperFavouriteRemove => 'Remove';

  @override
  String get wallpaperFavouriteRemoveAction => 'Remove from favourites';

  @override
  String get wallpaperFavouriteRemoveError => 'Couldn\'t remove favourites. Try again.';

  @override
  String wallpaperFavouriteRemovedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favourites',
      one: '1 favourite',
    );
    return 'Removed $_temp0';
  }

  @override
  String get wallpaperFavouriteRemovedOne => 'Removed from favourites';

  @override
  String get wallpaperFavouriteRemovedToast => 'Removed from favourites.';

  @override
  String get wallpaperFavouriteRestoreError => 'Couldn\'t restore favourites.';

  @override
  String get wallpaperFavouriteSearchHint => 'Search by creator or category';

  @override
  String get wallpaperFavouriteSetUsesFirst => 'Set uses the first one you picked';

  @override
  String get wallpaperFavouriteShareError => 'Couldn\'t share. Try again.';

  @override
  String get wallpaperFavouriteSortOldest => 'Oldest';

  @override
  String get wallpaperFavouriteSortRecentlyAdded => 'Recently added';

  @override
  String get wallpaperFavouriteSortSource => 'Source';

  @override
  String get wallpaperFavouriteStatus => 'In your favourites';

  @override
  String get wallpaperFavouriteTryDifferent => 'Try a different search or source.';

  @override
  String get wallpaperFavouriteUnavailableLegacy =>
      'This favourite is from an older version and cannot be opened. Press and hold to remove it.';

  @override
  String get wallpaperFavouriteWaitingSync => 'Waiting to sync';

  @override
  String get wallpaperFavouritesTitle => 'Favourites';

  @override
  String get wallpaperFeedAnnouncement => 'Announcement';

  @override
  String get wallpaperFeedCaughtUpBody => 'Pull down to refresh. New picks will land here.';

  @override
  String get wallpaperFeedCaughtUpTitle => 'You are all caught up';

  @override
  String get wallpaperFeedClearHistoryError => 'Could not clear history. Try again.';

  @override
  String get wallpaperFeedDiscovery => 'Discovery';

  @override
  String get wallpaperFeedEmptyBody => 'Follow creators or choose interests so we can surface more of what you like.';

  @override
  String get wallpaperFeedEmptyTitle => 'Shape this feed';

  @override
  String get wallpaperFeedFollowingEmptyTitle => 'Follow creators to see their new wallpapers here';

  @override
  String get wallpaperFeedFollowingLoadError => 'Couldn\'t load your following feed';

  @override
  String get wallpaperFeedLatestLoadError => 'Couldn\'t load the latest wallpapers';

  @override
  String get wallpaperFeedLearnedFromYou => 'Learned from you';

  @override
  String get wallpaperFeedLearningEmpty => 'Open, save and set walls to teach your feed.';

  @override
  String get wallpaperFeedLearningHistoryCleared => 'Learning history cleared';

  @override
  String get wallpaperFeedLoadError => 'Couldn\'t load your feed';

  @override
  String get wallpaperFeedLoadMoreError => 'Couldn\'t load more. Try again';

  @override
  String get wallpaperFeedMixAdventurous => 'Adventurous';

  @override
  String get wallpaperFeedMixAdventurousDescription => 'More walls from outside your taste.';

  @override
  String get wallpaperFeedMixBalanced => 'Balanced';

  @override
  String get wallpaperFeedMixBalancedDescription => 'Your taste, with a few surprises.';

  @override
  String get wallpaperFeedMixFamiliar => 'Familiar';

  @override
  String get wallpaperFeedMixFamiliarDescription => 'Mostly what you already love.';

  @override
  String wallpaperFeedPickAtLeast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Pick at least $countString';
  }

  @override
  String wallpaperFeedPickedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString picked';
  }

  @override
  String get wallpaperFeedPopularEmptyTitle => 'No popular wallpapers yet';

  @override
  String get wallpaperFeedPopularLoadError => 'Couldn\'t load popular wallpapers';

  @override
  String get wallpaperFeedPullToRefresh => 'Pull down to refresh.';

  @override
  String get wallpaperFeedRefreshError => 'Couldn\'t refresh your feed.';

  @override
  String get wallpaperFeedSaveError => 'Could not save feed settings. Try again.';

  @override
  String get wallpaperFeedSettingsHint => 'Double tap to open feed settings';

  @override
  String get wallpaperFeedStartingPoints => 'Starting points';

  @override
  String get wallpaperFeedTabFollowing => 'Following';

  @override
  String get wallpaperFeedTabForYou => 'For you';

  @override
  String get wallpaperFeedTabLatest => 'Latest';

  @override
  String get wallpaperFeedTabPopular => 'Popular';

  @override
  String get wallpaperFeedTabTrending => 'Trending';

  @override
  String get wallpaperFeedTuneDescription => 'Prism learns from what you open, save and set.';

  @override
  String get wallpaperFeedTuneTitle => 'Tune your feed';

  @override
  String get wallpaperFeedUpdating => 'Updating';

  @override
  String get wallpaperFeedWallsLoadError => 'Couldn\'t load wallpapers';

  @override
  String get wallpaperFewerLikeThisConfirmation => 'You\'ll see fewer wallpapers like this.';

  @override
  String get wallpaperFewerLikeThisUndo => 'Undo';

  @override
  String get wallpaperFileMovedOrDeleted => 'The file may have been moved or deleted.';

  @override
  String wallpaperFilterApplyCost(int coins, int missing) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'Applying this filter costs $coinsString coins. You need $missingString more coins.';
  }

  @override
  String get wallpaperFilterBlur => 'Blur';

  @override
  String get wallpaperFilterBrightness => 'Brightness';

  @override
  String get wallpaperFilterEffectEdge => 'Edge';

  @override
  String get wallpaperFilterEffectEmboss => 'Emboss';

  @override
  String get wallpaperFilterEffectHighPass => 'High Pass';

  @override
  String get wallpaperFilterEffectSharpen => 'Sharpen';

  @override
  String get wallpaperFilterHoldToCompare => 'Hold to compare';

  @override
  String get wallpaperFilterHue => 'Hue';

  @override
  String get wallpaperFilterLightness => 'Lightness';

  @override
  String get wallpaperFilterLightnessUnavailable => 'Lightness is unavailable on this device.';

  @override
  String get wallpaperFilterNeedCoins => 'Need coins for premium filter';

  @override
  String get wallpaperFilterOriginal => 'Original';

  @override
  String get wallpaperFilterSaturation => 'Saturation';

  @override
  String get wallpaperFilterSaveError => 'Couldn\'t save wallpaper. Please retry!';

  @override
  String get wallpaperFilterTabAdjustments => 'Adjust';

  @override
  String get wallpaperFilterTabFilters => 'Filters';

  @override
  String wallpaperFilterUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Premium filter unlocked for this edit (-$coinsString coins).';
  }

  @override
  String get wallpaperFilterTabCrop => 'Crop';

  @override
  String get wallpaperCropPresetFree => 'Free';

  @override
  String get wallpaperCropPresetPhone => 'This phone';

  @override
  String get wallpaperCropPresetPortrait => '9:16';

  @override
  String get wallpaperCropPresetSquare => '1:1';

  @override
  String get wallpaperCropPresetLandscape => '16:9 desktop';

  @override
  String get wallpaperCropPresetOriginal => 'Original';

  @override
  String get wallpaperCropRotate => 'Rotate 90°';

  @override
  String get wallpaperCropReset => 'Reset crop';

  @override
  String get wallpaperCropArea => 'Crop area';

  @override
  String wallpaperCropSize(int width, int height) {
    return '$width × $height px';
  }

  @override
  String get wallpaperCropCornerTopLeft => 'Top-left corner';

  @override
  String get wallpaperCropCornerTopRight => 'Top-right corner';

  @override
  String get wallpaperCropCornerBottomLeft => 'Bottom-left corner';

  @override
  String get wallpaperCropCornerBottomRight => 'Bottom-right corner';

  @override
  String get wallpaperExportTimedOut => 'Saving took too long. Try a smaller crop or fewer filters.';

  @override
  String get wallpaperFitBlur => 'Fit with blur';

  @override
  String get wallpaperFitColour => 'Fit with colour';

  @override
  String get wallpaperFitFill => 'Fill';

  @override
  String get wallpaperGenericError => 'Something went wrong!';

  @override
  String get wallpaperGoBack => 'Go back';

  @override
  String get wallpaperGotItFewerLikeThis => 'Got it. You\'ll see fewer like this.';

  @override
  String get wallpaperHidePreviewControls => 'Hide controls';

  @override
  String get wallpaperHistoryBothScreens => 'Both screens';

  @override
  String get wallpaperHistoryCurrent => 'Current';

  @override
  String get wallpaperHistoryCurrentPrefix => 'Current. ';

  @override
  String get wallpaperHistoryEmptyBody => 'Wallpapers you set will show up here, so you can set them again.';

  @override
  String get wallpaperHistoryEmptyTitle => 'No wallpapers yet';

  @override
  String get wallpaperHistoryRemoveAction => 'Remove from history';

  @override
  String get wallpaperHomeAppName => 'Prism';

  @override
  String get wallpaperImageSemanticHint => 'Hold for favourite, share, and reset actions. Scroll for details.';

  @override
  String get wallpaperPreviousInFeed => 'Previous wallpaper';

  @override
  String get wallpaperNextInFeed => 'Next wallpaper';

  @override
  String get wallpaperImageSemanticLabel => 'Wallpaper';

  @override
  String get wallpaperImmersiveHint => 'Tap to hide controls';

  @override
  String get wallpaperInsufficientCoins => 'Not enough coins. Earn coins in Rewards.';

  @override
  String wallpaperInterestLearnedLabel(String label, int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Learned: $label, $percentString percent';
  }

  @override
  String wallpaperInterestSelectedLabel(String name, String selection) {
    return 'Interest: $name, $selection';
  }

  @override
  String get wallpaperLandscapeCrop => 'Landscape wallpaper: the sides will be cropped';

  @override
  String get wallpaperLibraryCollections => 'Collections';

  @override
  String get wallpaperLibraryDownloads => 'Downloads';

  @override
  String get wallpaperLibraryFavourites => 'Favourites';

  @override
  String get wallpaperLibraryHistory => 'History';

  @override
  String get wallpaperLibraryTitle => 'Library';

  @override
  String get wallpaperLive => 'Live';

  @override
  String get wallpaperLiveApplied => 'Live wallpaper set.';

  @override
  String wallpaperLiveApplyPhotoDescription(String style) {
    return '$style preview';
  }

  @override
  String get wallpaperLiveBatterySaver => 'Battery saver';

  @override
  String get wallpaperLiveChooseAnotherVideo => 'Choose another video';

  @override
  String get wallpaperLiveChooseVideo => 'Choose a video';

  @override
  String get wallpaperLiveConfirmPreview => 'Confirm in the system preview.';

  @override
  String get wallpaperLiveConfirmHome => 'In the preview, tap Set wallpaper, then Home screen.';

  @override
  String get wallpaperLiveConfirmLock => 'In the preview, tap Set wallpaper, then Lock screen.';

  @override
  String get wallpaperLiveConfirmBoth => 'In the preview, tap Set wallpaper, then Home screen and lock screen.';

  @override
  String get wallpaperLiveSameWallBothScreens =>
      'Confirm in the system preview. This phone shows the same live wall on both screens.';

  @override
  String wallpaperLiveScreensResult(String home, String lock) {
    return 'Home screen: $home. Lock screen: $lock.';
  }

  @override
  String get wallpaperLiveScreenOther => 'another wallpaper';

  @override
  String get wallpaperLiveScreenPrismWall => 'a Prism live wall';

  @override
  String get wallpaperLivePickForHome => 'Pick a wall for the Home screen';

  @override
  String get wallpaperLivePickForLock => 'Pick a wall for the Lock screen';

  @override
  String get wallpaperLiveDeviceUnavailable => 'Not available on this device';

  @override
  String get wallpaperLiveErrorGeneric => 'Couldn\'t set the live wallpaper. Try again.';

  @override
  String get wallpaperLiveErrorImageTooLarge => 'That image is too large for a live wallpaper.';

  @override
  String get wallpaperLiveErrorMemory => 'Not enough memory. Close other apps and try again.';

  @override
  String get wallpaperLiveErrorNotAllowed => 'Your device or work profile does not allow wallpaper changes.';

  @override
  String get wallpaperLiveErrorPermission => 'Prism does not have permission to read that file.';

  @override
  String get wallpaperLiveErrorPreview => 'Couldn\'t open the system preview.';

  @override
  String get wallpaperLiveErrorReadFile => 'Couldn\'t read the file. Try again.';

  @override
  String get wallpaperLiveErrorStyle => 'This device could not start that style. Try another one.';

  @override
  String get wallpaperLiveErrorTimeout => 'Timed out. Check your connection and try again.';

  @override
  String get wallpaperLiveErrorTooLarge => 'That file is too large for a live wallpaper.';

  @override
  String get wallpaperLiveErrorVideo => 'That video cannot be played as a wallpaper. Try another clip.';

  @override
  String wallpaperLiveFps(int fps) {
    final intl.NumberFormat fpsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String fpsString = fpsNumberFormat.format(fps);

    return '$fpsString frames per second';
  }

  @override
  String wallpaperLiveGradientDescription(String style) {
    return '$style preview';
  }

  @override
  String wallpaperLiveGradientSwatch(String index, String count) {
    return 'Gradient colour $index of $count';
  }

  @override
  String get wallpaperLiveKeepPrismOpen => 'Keep Prism open and try again.';

  @override
  String get wallpaperLiveModeGradients => 'Gradients';

  @override
  String get wallpaperLiveModePhoto => 'Make it live';

  @override
  String get wallpaperLiveModeVideo => 'Video';

  @override
  String get wallpaperLiveNoVideo => 'No video chosen';

  @override
  String get wallpaperLivePreviewInstruction => 'Android opens a preview. Tap Set wallpaper there.';

  @override
  String get wallpaperLiveProStyleRequired => 'This style is part of Prism Pro.';

  @override
  String get wallpaperLiveSetAction => 'Set live wallpaper';

  @override
  String get wallpaperLiveShaderUnsupported => 'This device cannot run shader live wallpapers. Try Video.';

  @override
  String get wallpaperLiveStyleAurora => 'Aurora';

  @override
  String get wallpaperLiveStyleAuroraDescription => 'Soft ribbons of colour.';

  @override
  String get wallpaperLiveStyleBreathe => 'Breathe';

  @override
  String get wallpaperLiveStyleBreatheDescription => 'A gentle pulse, in and out.';

  @override
  String get wallpaperLiveStyleDrift => 'Drift';

  @override
  String get wallpaperLiveStyleDriftDescription => 'Slow pan and zoom. Follows your home screen swipes.';

  @override
  String get wallpaperLiveStyleMesh => 'Mesh';

  @override
  String get wallpaperLiveStyleMeshDescription => 'Blended colour that slowly shifts.';

  @override
  String get wallpaperLiveStylePlasma => 'Plasma';

  @override
  String get wallpaperLiveStylePlasmaDescription => 'Smooth, flowing colour.';

  @override
  String get wallpaperLiveStyleRipple => 'Ripple';

  @override
  String get wallpaperLiveStyleRippleDescription => 'Water rings that spread from your touch.';

  @override
  String get wallpaperLiveStyleShimmer => 'Shimmer';

  @override
  String get wallpaperLiveStyleShimmerDescription => 'A soft sweep of light.';

  @override
  String get wallpaperLiveStyleDepth => '3D';

  @override
  String get wallpaperLiveStyleDepthDescription =>
      'The photo moves in depth as you swipe your home screens and tilt your phone.';

  @override
  String get wallpaperLiveStyleStarfield => 'Starfield';

  @override
  String get wallpaperLiveStyleStarfieldDescription => 'Twinkling stars on pure black.';

  @override
  String wallpaperLiveStyleUnlocked(String style) {
    return '$style is unlocked for 7 days.';
  }

  @override
  String get wallpaperLiveStyleWaves => 'Waves';

  @override
  String get wallpaperLiveStyleWavesDescription => 'Layered waves that roll.';

  @override
  String get wallpaperLiveTextureDownloadFailed =>
      'Couldn\'t download the wallpaper. Check your connection and try again.';

  @override
  String get wallpaperLiveTexturePrepareFailed => 'Couldn\'t prepare the wallpaper.';

  @override
  String get wallpaperLiveTextureTooDetailed => 'That wallpaper is too detailed to animate.';

  @override
  String get wallpaperLiveTitle => 'Live wallpapers';

  @override
  String get wallpaperLiveUnavailableBody => 'They need an Android phone that supports OpenGL live wallpapers.';

  @override
  String get wallpaperLiveUnavailableTitle => 'Live wallpapers are not available';

  @override
  String wallpaperLiveUnlockCoins(String coins) {
    return 'Unlock · $coins coins';
  }

  @override
  String wallpaperLiveUnlockError(String style) {
    return 'Couldn\'t unlock $style. Try again.';
  }

  @override
  String wallpaperLiveUnlockStyleAction(String style, String coins) {
    return 'Unlock $style for 7 days · $coins coins';
  }

  @override
  String get wallpaperLiveUnlockStyleBody => 'Unlock it for 7 days with coins, or get Prism Pro for every style.';

  @override
  String wallpaperLiveUnlockStyleTitle(String style) {
    return '$style is a paid style';
  }

  @override
  String get wallpaperLiveUnsupported => 'This device cannot show live wallpapers.';

  @override
  String get wallpaperLiveVideoChosen => 'Chosen video';

  @override
  String get wallpaperLiveVideoDescription => 'Plays on your home screen with the sound off. Up to 256 MB.';

  @override
  String get wallpaperLiveVideoReadFailed => 'Couldn\'t read that video. Pick it again.';

  @override
  String get wallpaperLiveVideoTooLarge => 'That video is larger than 256 MB. Pick a shorter clip.';

  @override
  String get wallpaperLiveVideoUnsupported => 'This device cannot play a video as a wallpaper.';

  @override
  String get wallpaperLoadingImage => 'Loading image';

  @override
  String get wallpaperLoadingWallpaper => 'Loading wallpaper';

  @override
  String get wallpaperLowResolutionScreen => 'Low resolution for your screen';

  @override
  String get wallpaperMakeItLive => 'Make it live';

  @override
  String get wallpaperMatchSystemColour => 'Match system colour';

  @override
  String get wallpaperMoreLikeThis => 'More like this';

  @override
  String get wallpaperNavCollections => 'Collections';

  @override
  String get wallpaperNavHome => 'Home';

  @override
  String get wallpaperNavRewards => 'Rewards';

  @override
  String get wallpaperNavSearch => 'Search';

  @override
  String get wallpaperNew => 'New';

  @override
  String get wallpaperNotNow => 'Not now';

  @override
  String get wallpaperNotSelected => 'not selected';

  @override
  String get wallpaperNotificationPromptBody =>
      'One hand-picked wallpaper each morning, plus streak reminders. No spam.';

  @override
  String get wallpaperNotificationPromptTitle => 'Get the Wall of the Day';

  @override
  String get wallpaperOffline => 'Offline';

  @override
  String wallpaperOldVersionBody(String version) {
    return 'Version $version is no longer supported. Update Prism to keep using it.';
  }

  @override
  String get wallpaperOldVersionDownloadLatest => 'Download the latest version';

  @override
  String get wallpaperOldVersionTitle => 'Time to update';

  @override
  String get wallpaperOnPrism => 'Wallpaper on Prism';

  @override
  String get wallpaperOpenError => 'Couldn\'t load this wallpaper';

  @override
  String get wallpaperOpenFileError => 'Couldn\'t open this wallpaper';

  @override
  String get wallpaperOpenNotifications => 'Open notifications';

  @override
  String get wallpaperOtherSource => 'Other';

  @override
  String get wallpaperPastPicksEmpty => 'No past picks yet';

  @override
  String get wallpaperPastPicksLoadError => 'Couldn\'t load past picks';

  @override
  String get wallpaperPastPicksTitle => 'Past picks';

  @override
  String get wallpaperPlacementDim => 'Dim';

  @override
  String get wallpaperPositionApproximate => 'Approximate. Your launcher may differ.';

  @override
  String get wallpaperPremium => 'Premium';

  @override
  String get wallpaperPremiumCollection => 'Premium collection';

  @override
  String wallpaperPremiumCollectionNamed(String name) {
    return 'Premium collection, $name';
  }

  @override
  String get wallpaperPreviewHome => 'Home';

  @override
  String get wallpaperPreviewIconClear => 'Clear';

  @override
  String get wallpaperPreviewIconDark => 'Dark';

  @override
  String get wallpaperPreviewIconDefault => 'Default';

  @override
  String get wallpaperPreviewIconStyle => 'Icon style';

  @override
  String get wallpaperPreviewIconThemed => 'Themed';

  @override
  String get wallpaperPreviewIconTinted => 'Tinted';

  @override
  String get wallpaperPreviewLock => 'Lock';

  @override
  String get wallpaperPreviewOnScreen => 'Preview on your screen';

  @override
  String get wallpaperPreviewSetBoth => 'Set on both screens';

  @override
  String get wallpaperPreviewSetHome => 'Set on home screen';

  @override
  String get wallpaperPreviewSetLock => 'Set on lock screen';

  @override
  String wallpaperPreviewUnlock24Hours(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Unlock for 24 hours (-$costString)';
  }

  @override
  String wallpaperPreviewUnlockCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Preview this premium collection for 24 hours for $costString coins.';
  }

  @override
  String wallpaperPreviewUnlockCostMissing(int cost, int missing) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'A 24 hour preview costs $costString coins. You need $missingString more.';
  }

  @override
  String wallpaperPreviewWatchAdUnlock(String adOption) {
    return '$adOption and unlock';
  }

  @override
  String get wallpaperProcessing => 'Processing wallpaper';

  @override
  String get wallpaperProfileOpenError => 'Could not open profile';

  @override
  String get wallpaperQuickAddAction => 'Add to Quick Settings';

  @override
  String get wallpaperQuickFavouriteDescription =>
      'Applies a random wallpaper from your favourites. Sign in and favourite some wallpapers first.';

  @override
  String get wallpaperQuickFavouriteTitle => 'Random favourite tile';

  @override
  String get wallpaperQuickHowToTitle => 'How to add a tile';

  @override
  String get wallpaperQuickShuffleDescription => 'Tap the tile to apply a random wallpaper from the category you pick.';

  @override
  String get wallpaperQuickShuffleTitle => 'Shuffle wallpaper tile';

  @override
  String get wallpaperQuickStepEdit => 'Tap the pencil or edit icon.';

  @override
  String get wallpaperQuickStepFindPrism => 'Find the Prism tiles and drag them to your active tiles.';

  @override
  String get wallpaperQuickStepShade => 'Pull down the notification shade twice.';

  @override
  String get wallpaperQuickTargetBoth => 'Both';

  @override
  String get wallpaperQuickTargetHome => 'Home';

  @override
  String get wallpaperQuickTargetLock => 'Lock';

  @override
  String get wallpaperQuickTileAddError =>
      'Could not add the tile. Add it by hand from the Quick Settings edit screen.';

  @override
  String get wallpaperQuickTileAdded => 'Tile added to Quick Settings.';

  @override
  String get wallpaperQuickTileAlreadyAdded => 'This tile is already in Quick Settings.';

  @override
  String get wallpaperQuickTileNotAdded => 'Tile not added. You can add it any time.';

  @override
  String get wallpaperQuickTileSaveError => 'Could not save quick tile settings';

  @override
  String get wallpaperQuickTilesLoadError => 'Couldn\'t load your quick tiles';

  @override
  String get wallpaperQuickTilesTitle => 'Quick tiles';

  @override
  String get wallpaperQuickWotdDescription =>
      'Applies today\'s Wall of the Day. Open Prism once a day to cache the latest one.';

  @override
  String get wallpaperQuickWotdTitle => 'Wall of the Day tile';

  @override
  String get wallpaperRefresh => 'Refresh';

  @override
  String get wallpaperRemovedFromHistory => 'Removed from history';

  @override
  String get wallpaperReport => 'Report';

  @override
  String get wallpaperReset => 'Reset';

  @override
  String get wallpaperSave => 'Save';

  @override
  String get wallpaperSaveToPhotos => 'Save to Photos';

  @override
  String get wallpaperSavedOnDevice => 'Saved on this device';

  @override
  String wallpaperSearchTag(String tag) {
    return 'Search $tag';
  }

  @override
  String get wallpaperSeePrismPro => 'See Prism Pro';

  @override
  String get wallpaperSelected => 'selected';

  @override
  String get wallpaperServerUnavailable => 'Can\'t reach the servers';

  @override
  String get wallpaperSessionEnded => 'Your session ended. Sign in again.';

  @override
  String get wallpaperSet => 'Set';

  @override
  String get wallpaperSetAsWallpaper => 'Set as wallpaper';

  @override
  String wallpaperSetCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Set $countString times', one: 'Set once');
    return '$_temp0';
  }

  @override
  String get setScreenTargetHome => 'Home screen';

  @override
  String get setScreenTargetLock => 'Lock screen';

  @override
  String get setScreenTargetBoth => 'Both';

  @override
  String get setScreenTargetGroup => 'Where to set it';

  @override
  String get setScreenRemember => 'Remember this choice';

  @override
  String get setScreenRememberHint => 'Set skips this screen next time. Touch and hold Set to come back.';

  @override
  String get setScreenAdjust => 'Adjust';

  @override
  String get setScreenMore => 'More';

  @override
  String get setScreenPairLock => 'Use another wall for the lock screen';

  @override
  String get setScreenOpenSystemEditor => 'Open system editor';

  @override
  String get setScreenClose => 'Close';

  @override
  String get wallpaperShare => 'Share';

  @override
  String get wallpaperShareLink => 'Share link';

  @override
  String get wallpaperShortcutsChoosePrismData => 'Pick what Prism sends';

  @override
  String get wallpaperShortcutsOpenAction => 'Open Shortcuts';

  @override
  String get wallpaperShortcutsOpenError => 'Could not open Shortcuts. Open the app yourself.';

  @override
  String get wallpaperShortcutsSourceFavourite => 'Random favourite';

  @override
  String get wallpaperShortcutsSourceWotd => 'Wall of the Day';

  @override
  String get wallpaperShortcutsSourceWotdDescription =>
      'Today\'s Prism pick. Download today\'s original in Prism first. When the daily pick changes, download the new original before running this source.';

  @override
  String get wallpaperShortcutsTitle => 'Change automatically';

  @override
  String get wallpaperShowLessLikeThis => 'Show less like this';

  @override
  String get wallpaperShowPreviewControls => 'Show controls';

  @override
  String get wallpaperSignIn => 'Sign in';

  @override
  String get wallpaperSignInForPremiumFilters => 'Sign in to use premium filters with coins.';

  @override
  String get wallpaperSortDownloads => 'Sort downloads';

  @override
  String get wallpaperStartupFailed => 'Prism could not start';

  @override
  String get wallpaperThemeDarkAccent => 'Dark accent colour';

  @override
  String get wallpaperThemeDarkThemes => 'Dark themes';

  @override
  String get wallpaperUseAsAppAccent => 'Use as app accent';

  @override
  String get wallpaperAppAccentUpdated => 'App accent updated';

  @override
  String get wallpaperThemeLightAccent => 'Light accent colour';

  @override
  String get wallpaperThemeLightThemes => 'Light themes';

  @override
  String get wallpaperThemeModeDark => 'Dark';

  @override
  String get wallpaperThemeModeLight => 'Light';

  @override
  String get wallpaperThemeModeSystem => 'System';

  @override
  String get wallpaperThemePreference => 'Theme Preference';

  @override
  String get wallpaperThemePreferenceDescription =>
      'Select your preferred theme mode. System mode automatically switches between light and dark depending on your device mode.';

  @override
  String get wallpaperThemeTitle => 'Themes';

  @override
  String get wallpaperTitle => 'Title';

  @override
  String get wallpaperTrendingEmptyTitle => 'Nothing is trending yet';

  @override
  String get wallpaperTrendingLoadError => 'Couldn\'t load trending wallpapers';

  @override
  String get wallpaperTryAgain => 'Try again';

  @override
  String get wallpaperTurnOff => 'Turn off';

  @override
  String get wallpaperTurnOnNotifications => 'Turn on notifications';

  @override
  String get wallpaperUnavailable => 'Unavailable';

  @override
  String get wallpaperUnfavourite => 'Unfavourite';

  @override
  String get wallpaperUnreadItems => 'Has unread items';

  @override
  String get wallpaperUpdatePrism => 'Update Prism';

  @override
  String get wallpaperUploadAction => 'Upload';

  @override
  String get wallpaperUploadAddTag => 'Add tag';

  @override
  String get wallpaperUploadAddTagHint => 'Add a tag, then tap Done';

  @override
  String get wallpaperUploadAiSubtitle => 'Describe a scene and generate a phone wallpaper';

  @override
  String get wallpaperUploadApprovalInfo =>
      'Your wallpaper appears in the community after approval. Track it in Your uploads.';

  @override
  String wallpaperUploadBatchPosition(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Wallpaper $positionString of $totalString';
  }

  @override
  String wallpaperUploadBatchSubmitted(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label. $countString submitted.';
  }

  @override
  String wallpaperUploadBatchSummaryNotSent(String submitted, int notSent) {
    final intl.NumberFormat notSentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String notSentString = notSentNumberFormat.format(notSent);

    return '$submitted. $notSentString not sent.';
  }

  @override
  String wallpaperUploadBatchSummarySubmitted(int submittedCount, int total) {
    final intl.NumberFormat submittedCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String submittedCountString = submittedCountNumberFormat.format(submittedCount);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$submittedCountString of $totalString wallpapers submitted';
  }

  @override
  String get wallpaperUploadBrightness => 'Brightness';

  @override
  String get wallpaperUploadCheckReviewStatus => 'Check review status';

  @override
  String get wallpaperUploadChooseAnotherImage => 'Choose another image';

  @override
  String get wallpaperUploadContinueDraft => 'Continue editing your saved wallpaper';

  @override
  String get wallpaperUploadContrast => 'Contrast';

  @override
  String get wallpaperUploadCreateTitle => 'Create';

  @override
  String get wallpaperUploadDeleteConfirmTitle => 'Delete this wallpaper?';

  @override
  String get wallpaperUploadDeleteError => 'Couldn\'t delete. Try again.';

  @override
  String get wallpaperUploadDeletePermissionError =>
      'Couldn\'t delete. Sign in with the account you used to upload, then try again.';

  @override
  String get wallpaperUploadDeleteWallpaper => 'Delete wallpaper';

  @override
  String get wallpaperUploadDeleted => 'Wallpaper deleted.';

  @override
  String get wallpaperUploadDetailsOptional => 'Details (optional)';

  @override
  String get wallpaperUploadDiscardBody =>
      'Uploaded files will be removed. Your selected image will stay on your device.';

  @override
  String get wallpaperUploadDiscardEditsBody => 'Your changes will be lost.';

  @override
  String get wallpaperUploadDiscardEditsTitle => 'Discard your edits?';

  @override
  String get wallpaperUploadDiscardError => 'Could not discard this upload. Try again.';

  @override
  String get wallpaperUploadDiscardTitle => 'Discard this upload?';

  @override
  String get wallpaperUploadDownloadError => 'Couldn\'t download. Try again.';

  @override
  String get wallpaperUploadDownloadStarting => 'Starting download';

  @override
  String get wallpaperUploadDraftSaveError => 'Could not save this draft. Try again.';

  @override
  String wallpaperUploadEditBatch(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Edit wallpaper $positionString of $totalString';
  }

  @override
  String get wallpaperUploadEditSaveError => 'Could not save your edits. Try again.';

  @override
  String get wallpaperUploadFileSize => 'Size';

  @override
  String get wallpaperUploadFilesCheckActive => 'Uploading the wallpaper and its preview';

  @override
  String get wallpaperUploadFilesCheckDone => 'Wallpaper and preview uploaded';

  @override
  String get wallpaperUploadFilesCheckPending => 'Upload the wallpaper and its preview';

  @override
  String get wallpaperUploadFilesRemoveError => 'Could not remove uploaded files. Try again.';

  @override
  String get wallpaperUploadFlip => 'Flip';

  @override
  String wallpaperUploadFreeQuotaMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Free users can upload $countString wallpapers per week.';
  }

  @override
  String get wallpaperUploadFromGallery => 'From your gallery';

  @override
  String get wallpaperUploadFullImageError => 'Couldn\'t load the full image.';

  @override
  String get wallpaperUploadInReview => 'In review';

  @override
  String get wallpaperUploadKeepDraft => 'Keep draft';

  @override
  String get wallpaperUploadLeaveBody => 'Keep your draft to resume later, or discard it and remove uploaded files.';

  @override
  String get wallpaperUploadLeaveTitle => 'Leave this upload?';

  @override
  String wallpaperUploadMaxTagsReached(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'You added $countString tags';
  }

  @override
  String get wallpaperUploadOriginalContentGuideline =>
      'Only upload original, high-quality wallpapers. Do not upload content from other apps.';

  @override
  String get wallpaperUploadPrepareCheckActive => 'Preparing your image and a smaller preview';

  @override
  String get wallpaperUploadPrepareCheckDone => 'Image and preview are ready';

  @override
  String get wallpaperUploadPrepareCheckPending => 'Prepare your image and a smaller preview';

  @override
  String get wallpaperUploadPrepareError => 'We could not prepare this image. Try again or choose another image.';

  @override
  String get wallpaperUploadQualityLandscape => 'This image is wide. Phone wallpapers look best in portrait.';

  @override
  String wallpaperUploadQualityLowResolution(int width, int height, int recommendedShortSide) {
    final intl.NumberFormat widthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String widthString = widthNumberFormat.format(width);
    final intl.NumberFormat recommendedShortSideNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String recommendedShortSideString = recommendedShortSideNumberFormat.format(recommendedShortSide);

    return 'This image is ${widthString}x$height. It can look soft on a phone. $recommendedShortSideString px on the short side is best.';
  }

  @override
  String get wallpaperUploadQuotaCleanupFailed =>
      'You reached the upload limit, but we could not remove the uploaded files. Tap Back to try removing them again.';

  @override
  String get wallpaperUploadQuotaReached => 'You have reached this week’s free wallpaper upload limit.';

  @override
  String wallpaperUploadQuotaRemaining(int remaining, int total) {
    final intl.NumberFormat remainingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$remainingString of $totalString free uploads left this week';
  }

  @override
  String get wallpaperUploadRejected => 'Rejected';

  @override
  String get wallpaperUploadRejectedSectionError => 'Couldn\'t load your rejected submissions.';

  @override
  String get wallpaperUploadRejectionFallback =>
      'No specific reason was provided. Check your wallpaper details, then upload it again.';

  @override
  String get wallpaperUploadRejectionTitle => 'Why it was rejected';

  @override
  String wallpaperUploadRemoveTag(String tag) {
    return 'Remove tag $tag';
  }

  @override
  String get wallpaperUploadResetAdjustments => 'Reset adjustments';

  @override
  String get wallpaperUploadResolution => 'Resolution';

  @override
  String get wallpaperUploadResumeDraft => 'Resume saved upload';

  @override
  String get wallpaperUploadRetrySubmit => 'Retry submit';

  @override
  String get wallpaperUploadReviewCheckActive => 'Saving your submission for review';

  @override
  String get wallpaperUploadReviewCheckDone => 'Submitted for review';

  @override
  String get wallpaperUploadReviewCheckPending => 'Moderators review it before it appears in Prism';

  @override
  String get wallpaperUploadReviewEmptyBody => 'Wallpapers you upload show their review status here.';

  @override
  String get wallpaperUploadReviewEmptyTitle => 'Nothing here yet';

  @override
  String get wallpaperUploadReviewLoadError => 'Couldn\'t load your uploads';

  @override
  String get wallpaperUploadReviewSectionError => 'Couldn\'t load your submissions.';

  @override
  String get wallpaperUploadRotateLeft => 'Rotate left';

  @override
  String get wallpaperUploadRotateRight => 'Rotate right';

  @override
  String get wallpaperUploadSaturation => 'Saturation';

  @override
  String get wallpaperUploadSavedToPictures => 'Wallpaper saved to Pictures/Prism';

  @override
  String get wallpaperUploadSkip => 'Skip this wallpaper';

  @override
  String get wallpaperUploadStagePrepareFailed => 'Image could not be prepared';

  @override
  String get wallpaperUploadStagePreparing => 'Preparing wallpaper';

  @override
  String get wallpaperUploadStageQuotaReached => 'Upload limit reached';

  @override
  String get wallpaperUploadStageReady => 'Ready to submit';

  @override
  String get wallpaperUploadStageSubmissionFailed => 'Submission did not finish';

  @override
  String get wallpaperUploadStageSubmitting => 'Submitting wallpaper';

  @override
  String get wallpaperUploadStageUploadFailed => 'Upload did not finish';

  @override
  String get wallpaperUploadStageUploading => 'Uploading wallpaper';

  @override
  String get wallpaperUploadSubmissionUnconfirmed =>
      'We could not confirm the submission. Check your review status before trying again.';

  @override
  String get wallpaperUploadTags => 'Tags';

  @override
  String wallpaperUploadTagsHelp(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Up to $countString. Tags help people find your wallpaper.';
  }

  @override
  String get wallpaperUploadTitle => 'Upload wallpaper';

  @override
  String get wallpaperUploadTitleHint => 'Name your wallpaper';

  @override
  String get wallpaperUploadViewWallpaper => 'View wallpaper';

  @override
  String get wallpaperUploadYourUploads => 'Your uploads';

  @override
  String get wallpaperUsePhoneAccent => 'Use the accent colour of your phone';

  @override
  String get wallpaperThemeMaterialYouNote => 'Material You takes its colours from your wallpaper.';

  @override
  String wallpaperViewCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString views', one: '1 view');
    return '$_temp0';
  }

  @override
  String get wallpaperViewCountUnavailable => 'View count unavailable';

  @override
  String wallpaperWotdByPhotographer(String name) {
    return 'Wall of the day by $name';
  }

  @override
  String get economyAiPromptSceneAnime1 => 'a cat napping on a sunlit train platform';

  @override
  String get economyAiPromptSceneAnime2 => 'towering summer clouds over rice fields';

  @override
  String get economyAiPromptSceneAnime3 => 'a ramen stall glowing on a rainy back street';

  @override
  String get economyAiPromptSceneAnime4 => 'a hilltop shrine gate above a sea of clouds';

  @override
  String get economyAiPromptSceneAnime5 => 'fireworks over a river at a summer festival';

  @override
  String get economyAiPromptSceneAnime6 => 'a quiet classroom with petals drifting in';

  @override
  String get economyAiPromptSceneAnime7 => 'a seaside road with a lone bus stop at dusk';

  @override
  String get economyAiPromptSceneAnime8 => 'a sky whale drifting over a sleepy town';

  @override
  String get economyAiPromptSceneMinimal1 => 'a single paper boat on still pale water';

  @override
  String get economyAiPromptSceneMinimal2 => 'one arch of light over an empty plain';

  @override
  String get economyAiPromptSceneMinimal3 => 'a lone tree on a gentle snowy slope';

  @override
  String get economyAiPromptSceneMinimal4 => 'two overlapping circles on soft grain';

  @override
  String get economyAiPromptSceneMinimal5 => 'a thin horizon line splitting sea and sky';

  @override
  String get economyAiPromptSceneMinimal6 => 'a single feather falling through empty space';

  @override
  String get economyAiPromptSceneMinimal7 => 'stacked smooth pebbles on a pale backdrop';

  @override
  String get economyAiPromptSceneMinimal8 => 'a crescent shadow on a soft plaster wall';

  @override
  String get economyAiPromptSceneCyberpunk1 => 'a rain-soaked noodle bar under neon glow';

  @override
  String get economyAiPromptSceneCyberpunk2 => 'a hover train threading between megatowers';

  @override
  String get economyAiPromptSceneCyberpunk3 => 'a lone android on a rooftop in the rain';

  @override
  String get economyAiPromptSceneCyberpunk4 => 'a glowing data highway into a vast city';

  @override
  String get economyAiPromptSceneCyberpunk5 => 'a night market under a tangle of cables';

  @override
  String get economyAiPromptSceneCyberpunk6 => 'a chrome motorbike parked in a neon alley';

  @override
  String get economyAiPromptSceneCyberpunk7 => 'a hologram moon rising over city towers';

  @override
  String get economyAiPromptSceneCyberpunk8 => 'a flooded street mirroring a wall of screens';

  @override
  String get economyAiPromptSceneWatercolor1 => 'a lavender field fading into morning mist';

  @override
  String get economyAiPromptSceneWatercolor2 => 'a small fishing village by a calm harbor';

  @override
  String get economyAiPromptSceneWatercolor3 => 'wild poppies swaying beside a country lane';

  @override
  String get economyAiPromptSceneWatercolor4 => 'a hot air balloon over soft green hills';

  @override
  String get economyAiPromptSceneWatercolor5 => 'a heron standing in a reed-filled pond';

  @override
  String get economyAiPromptSceneWatercolor6 => 'a rainy city street with blurred lamps';

  @override
  String get economyAiPromptSceneWatercolor7 => 'a teacup steaming beside an open window';

  @override
  String get economyAiPromptSceneWatercolor8 => 'snowy pines along a winding frozen creek';

  @override
  String get economyAiPromptSceneMeshGradient1 => 'soft color blobs melting into each other';

  @override
  String get economyAiPromptSceneMeshGradient2 => 'a silky gradient wave folding on itself';

  @override
  String get economyAiPromptSceneMeshGradient3 => 'glowing orbs blending on a velvet backdrop';

  @override
  String get economyAiPromptSceneMeshGradient4 => 'an aurora-like gradient sweeping upward';

  @override
  String get economyAiPromptSceneMeshGradient5 => 'liquid color pools with a fine grain';

  @override
  String get economyAiPromptSceneMeshGradient6 => 'a warm-to-cool gradient with soft noise';

  @override
  String get economyAiPromptSceneMeshGradient7 => 'overlapping translucent gradient petals';

  @override
  String get economyAiPromptSceneMeshGradient8 => 'a blurred sunset of fluid color bands';

  @override
  String get economyAiPromptSceneAbstract1 => 'interlocking glass shards catching light';

  @override
  String get economyAiPromptSceneAbstract2 => 'flowing ink clouds suspended in water';

  @override
  String get economyAiPromptSceneAbstract3 => 'a spiral of folded ribbons in motion';

  @override
  String get economyAiPromptSceneAbstract4 => 'shattered marble with veins of gold';

  @override
  String get economyAiPromptSceneAbstract5 => 'rippling topographic lines in layers';

  @override
  String get economyAiPromptSceneAbstract6 => 'floating spheres casting long shadows';

  @override
  String get economyAiPromptSceneAbstract7 => 'smoke trails curling into a vortex';

  @override
  String get economyAiPromptSceneAbstract8 => 'a field of soft cubes rising in waves';

  @override
  String get economyAiPromptSceneNature1 => 'a waterfall pouring into a mossy gorge';

  @override
  String get economyAiPromptSceneNature2 => 'a field of sunflowers under a big sky';

  @override
  String get economyAiPromptSceneNature3 => 'a frozen lake with cracks of blue ice';

  @override
  String get economyAiPromptSceneNature4 => 'cherry trees lining a quiet river path';

  @override
  String get economyAiPromptSceneNature5 => 'a tropical lagoon seen from above';

  @override
  String get economyAiPromptSceneNature6 => 'autumn maples reflected in a still pond';

  @override
  String get economyAiPromptSceneNature7 => 'a lone fox in fresh snow at dawn';

  @override
  String get economyAiPromptSceneNature8 => 'storm clouds rolling over green highlands';

  @override
  String get economyAiPromptSceneSpace1 => 'a ringed planet rising over a moon horizon';

  @override
  String get economyAiPromptSceneSpace2 => 'a spiral galaxy glowing in deep space';

  @override
  String get economyAiPromptSceneSpace3 => 'an astronaut floating above a blue planet';

  @override
  String get economyAiPromptSceneSpace4 => 'a nebula shaped like a blooming flower';

  @override
  String get economyAiPromptSceneSpace5 => 'twin suns setting over an alien desert';

  @override
  String get economyAiPromptSceneSpace6 => 'a space station orbiting a gas giant';

  @override
  String get economyAiPromptSceneSpace7 => 'a meteor shower over a quiet observatory';

  @override
  String get economyAiPromptSceneSpace8 => 'an eclipse with a bright diamond ring';

  @override
  String get economyAiPromptSceneSynthwave1 => 'a neon grid road racing toward a sunset';

  @override
  String get economyAiPromptSceneSynthwave2 => 'a palm-lined coast under a striped sun';

  @override
  String get economyAiPromptSceneSynthwave3 => 'a retro sports car on an endless highway';

  @override
  String get economyAiPromptSceneSynthwave4 => 'wireframe mountains under a magenta sky';

  @override
  String get economyAiPromptSceneSynthwave5 => 'a chrome sun sinking into a glowing sea';

  @override
  String get economyAiPromptSceneSynthwave6 => 'a retro arcade glowing on a rainy night';

  @override
  String get economyAiPromptSceneSynthwave7 => 'a cassette tape floating in neon space';

  @override
  String get economyAiPromptSceneSynthwave8 => 'a lone palm tree against a laser horizon';

  @override
  String get economyAiPromptScenePixelArt1 => 'a cozy cabin in a snowy forest at night';

  @override
  String get economyAiPromptScenePixelArt2 => 'a castle on a cliff above the sea';

  @override
  String get economyAiPromptScenePixelArt3 => 'a tiny town with glowing windows';

  @override
  String get economyAiPromptScenePixelArt4 => 'a starship over a purple alien world';

  @override
  String get economyAiPromptScenePixelArt5 => 'a waterfall in a lush jungle valley';

  @override
  String get economyAiPromptScenePixelArt6 => 'a fishing pier under a full moon';

  @override
  String get economyAiPromptScenePixelArt7 => 'a cherry blossom temple in spring';

  @override
  String get economyAiPromptScenePixelArt8 => 'a train crossing a bridge at sunset';

  @override
  String get economyAiPromptSceneRender3d1 => 'glossy clay shapes stacked in balance';

  @override
  String get economyAiPromptSceneRender3d2 => 'frosted glass ribbons on a pastel stage';

  @override
  String get economyAiPromptSceneRender3d3 => 'a tiny island floating on a soft cloud';

  @override
  String get economyAiPromptSceneRender3d4 => 'inflated chrome bubbles in soft light';

  @override
  String get economyAiPromptSceneRender3d5 => 'a miniature desert with a lone cactus';

  @override
  String get economyAiPromptSceneRender3d6 => 'a cozy room diorama inside a cube';

  @override
  String get economyAiPromptSceneRender3d7 => 'floating marble arches over still water';

  @override
  String get economyAiPromptSceneRender3d8 => 'candy-colored waves frozen in motion';

  @override
  String get economyAiPromptSceneOilPainting1 => 'a stormy sea crashing against a rocky shore';

  @override
  String get economyAiPromptSceneOilPainting2 => 'a sunlit poppy meadow with a farmhouse';

  @override
  String get economyAiPromptSceneOilPainting3 => 'a still life of lemons and a blue vase';

  @override
  String get economyAiPromptSceneOilPainting4 => 'a misty harbor at dawn with old ships';

  @override
  String get economyAiPromptSceneOilPainting5 => 'a forest path ablaze with autumn color';

  @override
  String get economyAiPromptSceneOilPainting6 => 'a moonlit canal lined with old houses';

  @override
  String get economyAiPromptSceneOilPainting7 => 'a wheat field rippling before a storm';

  @override
  String get economyAiPromptSceneOilPainting8 => 'a single rose in a glass on a dark table';

  @override
  String get economyAiPromptSceneUkiyoE1 => 'a great wave curling beneath a pale moon';

  @override
  String get economyAiPromptSceneUkiyoE2 => 'a snow-covered pagoda at twilight';

  @override
  String get economyAiPromptSceneUkiyoE3 => 'cranes flying over a misty mountain';

  @override
  String get economyAiPromptSceneUkiyoE4 => 'a wooden bridge under falling cherry petals';

  @override
  String get economyAiPromptSceneUkiyoE5 => 'fishing boats on a rough indigo sea';

  @override
  String get economyAiPromptSceneUkiyoE6 => 'a red sun over a volcanic peak';

  @override
  String get economyAiPromptSceneUkiyoE7 => 'a koi pond beneath weeping willows';

  @override
  String get economyAiPromptSceneUkiyoE8 => 'rain falling over a quiet riverside town';

  @override
  String get economyAiPromptLightingMorningHaze => 'soft morning haze';

  @override
  String get economyAiPromptLightingGoldenHour => 'golden hour glow';

  @override
  String get economyAiPromptLightingMoonlight => 'cool moonlight';

  @override
  String get economyAiPromptLightingNeonRim => 'neon rim light';

  @override
  String get economyAiPromptLightingBacklight => 'warm backlight';

  @override
  String get economyAiPromptLightingGodRays => 'soft god rays';

  @override
  String get economyAiPromptLightingStudio => 'even studio light';

  @override
  String get economyAiPromptLightingTwilight => 'deep blue twilight';

  @override
  String get economyAiPromptPaletteTealAmber => 'teal and amber hues';

  @override
  String get economyAiPromptPaletteIndigoRose => 'indigo and rose hues';

  @override
  String get economyAiPromptPaletteSageCream => 'sage green and cream';

  @override
  String get economyAiPromptPaletteBlackNeonPink => 'black with neon pink';

  @override
  String get economyAiPromptPalettePastelPeach => 'soft pastel peach';

  @override
  String get economyAiPromptPaletteEmeraldGold => 'emerald and gold';

  @override
  String get economyAiPromptPaletteOceanBlue => 'shades of ocean blue';

  @override
  String get economyAiPromptPaletteCrimsonCharcoal => 'crimson and charcoal';

  @override
  String get economyAiPromptSuffix => 'vertical phone wallpaper, no text';

  @override
  String economyAiPromptComposition(String scene, String lighting, String palette, String suffix) {
    return '$scene, $lighting, $palette, $suffix';
  }

  @override
  String economyAiPromptSceneOnly(String scene, String suffix) {
    return '$scene, $suffix';
  }

  @override
  String get economyAiMadeWithPrism => 'Made with Prism AI';

  @override
  String get onboardingAiPromptFallback => 'a beautiful wallpaper';

  @override
  String get onboardingAiPromptNature1 => 'a glacier lake at sunrise with mirror-still water and pink mountain peaks';

  @override
  String get onboardingAiPromptNature2 => 'a moss-covered forest stream with soft light falling through tall ferns';

  @override
  String get onboardingAiPromptNature3 => 'a field of wildflowers under a vast evening sky with drifting clouds';

  @override
  String get onboardingAiPromptNature4 => 'a black sand beach with turquoise waves and sea stacks at dusk';

  @override
  String get onboardingAiPromptNature5 => 'northern lights over a snowy pine forest beside a frozen lake';

  @override
  String get onboardingAiPromptAbstract1 =>
      'translucent glass ribbons twisting through soft light with iridescent edges';

  @override
  String get onboardingAiPromptAbstract2 => 'ink clouds blooming in water in deep blue and gold with rich soft detail';

  @override
  String get onboardingAiPromptAbstract3 => 'layered paper-like waves in warm sunset colors with gentle shadows';

  @override
  String get onboardingAiPromptAbstract4 => 'a sculpted marble swirl with gold veins on a deep charcoal background';

  @override
  String get onboardingAiPromptAbstract5 => 'floating chrome spheres reflecting a pastel sky in calm open space';

  @override
  String get onboardingAiPromptWatercolor1 => 'a watercolor seaside village with pastel houses and boats at sunrise';

  @override
  String get onboardingAiPromptWatercolor2 => 'loose watercolor wildflowers in blush pink and sage on textured paper';

  @override
  String get onboardingAiPromptWatercolor3 => 'a misty watercolor lake with a small wooden dock and distant hills';

  @override
  String get onboardingAiPromptWatercolor4 => 'a watercolor night sky with soft violet clouds and a glowing moon';

  @override
  String get onboardingAiPromptWatercolor5 => 'a watercolor autumn forest in warm washes of orange and gold';

  @override
  String get onboardingAiPromptMinimal1 => 'a single sun setting over a calm sea with flat colors and a wide empty sky';

  @override
  String get onboardingAiPromptMinimal2 => 'soft layered hills in muted sand tones under a pale gradient sky';

  @override
  String get onboardingAiPromptMinimal3 => 'one bare tree on a snowy hill with plenty of quiet empty space';

  @override
  String get onboardingAiPromptMinimal4 => 'a lone sailboat on a still lake at dawn in simple shapes and soft tones';

  @override
  String get onboardingAiPromptMinimal5 => 'gentle concentric arches in terracotta and cream with fine grain';

  @override
  String get onboardingAiPromptAnime1 => 'an anime summer sky with towering clouds over a quiet seaside railway';

  @override
  String get onboardingAiPromptAnime2 => 'an anime night city seen from a hilltop with warm lights and a sky of stars';

  @override
  String get onboardingAiPromptAnime3 => 'an anime forest shrine with glowing spirits drifting in soft green light';

  @override
  String get onboardingAiPromptAnime4 =>
      'an anime rainy street at dusk with glowing shop lights and puddle reflections';

  @override
  String get onboardingAiPromptAnime5 => 'an anime meadow at golden hour with wind sweeping through tall grass';

  @override
  String get onboardingAiPromptMeshGradient1 => 'a smooth mesh gradient of tangerine, pink and violet with soft grain';

  @override
  String get onboardingAiPromptMeshGradient2 => 'a deep mesh gradient of navy and teal with a glowing lime highlight';

  @override
  String get onboardingAiPromptMeshGradient3 => 'a soft mesh gradient of sky blue, lavender and warm cream';

  @override
  String get onboardingAiPromptMeshGradient4 => 'a bold mesh gradient of crimson and gold flowing like silk';

  @override
  String get onboardingAiPromptMeshGradient5 => 'a calm mesh gradient of sage, mint and pale sand with gentle light';

  @override
  String get onboardingAiPromptCyberpunk1 => 'a cyberpunk street at night in the rain with neon reflections and steam';

  @override
  String get onboardingAiPromptCyberpunk2 => 'a towering neon city seen from a rooftop with flying cars streaking past';

  @override
  String get onboardingAiPromptCyberpunk3 => 'a quiet cyberpunk canal lined with glowing shops and floating lanterns';

  @override
  String get onboardingAiPromptCyberpunk4 => 'a cyberpunk skyline at dawn with glass towers in pink and teal haze';

  @override
  String get onboardingAiPromptCyberpunk5 => 'a lone motorbike on a neon bridge over a misty futuristic city';

  @override
  String get onboardingAiPromptSpace1 => 'a ringed gas giant rising over a rocky moon with stars filling the black sky';

  @override
  String get onboardingAiPromptSpace2 => 'a colorful nebula in violet and teal with bright young stars';

  @override
  String get onboardingAiPromptSpace3 => 'a spiral galaxy seen face-on with a glowing core and dusty blue arms';

  @override
  String get onboardingAiPromptSpace4 => 'an astronaut drifting above Earth at sunrise with a thin blue atmosphere';

  @override
  String get onboardingAiPromptSpace5 => 'a total solar eclipse over a silent mountain range';

  @override
  String get onboardingAiPromptSynthwave1 => 'a synthwave sunset with a striped sun over a glowing neon grid';

  @override
  String get onboardingAiPromptSynthwave2 => 'a retro car driving toward a magenta sun on an empty coastal road';

  @override
  String get onboardingAiPromptSynthwave3 => 'wireframe mountains under a starry purple sky with a chrome sun';

  @override
  String get onboardingAiPromptSynthwave4 => 'a synthwave beach with palm silhouettes and a glowing pink horizon';

  @override
  String get onboardingAiPromptSynthwave5 => 'a retro city skyline at night in pink and cyan neon haze';

  @override
  String get onboardingAiPromptPixelArt1 => 'a pixel art cabin in a snowy forest with warm glowing windows at night';

  @override
  String get onboardingAiPromptPixelArt2 => 'a pixel art seaside town at sunset with boats in the harbor';

  @override
  String get onboardingAiPromptPixelArt3 => 'a pixel art castle on a floating island above the clouds';

  @override
  String get onboardingAiPromptPixelArt4 => 'a pixel art night sky over a quiet lake with fireflies';

  @override
  String get onboardingAiPromptPixelArt5 => 'a pixel art cherry blossom path leading to a small temple';

  @override
  String get onboardingAiPromptRender3d1 => 'a 3D render of soft clay shapes in pastel colors with gentle shadows';

  @override
  String get onboardingAiPromptRender3d2 => 'a 3D render of a tiny floating island with a waterfall and trees';

  @override
  String get onboardingAiPromptRender3d3 => 'a 3D render of glossy glass waves in blue and violet under studio light';

  @override
  String get onboardingAiPromptRender3d4 => 'a 3D render of a cozy miniature room inside a glowing cube';

  @override
  String get onboardingAiPromptRender3d5 => 'a 3D render of chrome bubbles floating over a calm pink sea';

  @override
  String get onboardingAiPromptOilPainting1 => 'an oil painting of a stormy sea with a small ship under a dramatic sky';

  @override
  String get onboardingAiPromptOilPainting2 => 'an oil painting of a sunlit poppy field with a distant farmhouse';

  @override
  String get onboardingAiPromptOilPainting3 => 'an oil painting of a misty harbor at dawn with old wooden boats';

  @override
  String get onboardingAiPromptOilPainting4 => 'an oil painting of an autumn forest path in thick, rich brushstrokes';

  @override
  String get onboardingAiPromptOilPainting5 => 'an oil painting of a moonlit canal town with warm glowing windows';

  @override
  String get onboardingAiPromptUkiyoE1 => 'a ukiyo-e great wave under a pale moon with a snowy mountain far away';

  @override
  String get onboardingAiPromptUkiyoE2 => 'a ukiyo-e snowy village at night with glowing paper lanterns';

  @override
  String get onboardingAiPromptUkiyoE3 => 'a ukiyo-e scene of cranes flying over misty mountains at dawn';

  @override
  String get onboardingAiPromptUkiyoE4 => 'a ukiyo-e wooden bridge under cherry blossoms on a spring day';

  @override
  String get onboardingAiPromptUkiyoE5 => 'a ukiyo-e red sun over a calm indigo sea with small fishing boats';

  @override
  String wallpaperWotdByline(String name) {
    return 'by $name';
  }

  @override
  String get wallpaperWotdPastPicks => 'Past picks';

  @override
  String wallpaperWotdPickedOn(String wallpaper, String date) {
    return '$wallpaper, picked $date';
  }

  @override
  String get wallpaperWotdSeePast => 'See past walls of the day';

  @override
  String get wallpaperWotdTitle => 'Wall of the day';

  @override
  String get wallpaperYourProfile => 'Your profile';

  @override
  String get widgetsSettingsTitle => 'Widgets';

  @override
  String get widgetsSettingsSubtitle => 'Add Prism to your Home Screen and Lock Screen';

  @override
  String get widgetsGuideTitle => 'Add Prism widgets';

  @override
  String get widgetsGuideHomeTab => 'Home Screen';

  @override
  String get widgetsGuideLockTab => 'Lock Screen';

  @override
  String get widgetsGuideHomeStep1 => 'Touch and hold an empty area of your Home Screen until the apps jiggle.';

  @override
  String get widgetsGuideHomeStep2 => 'Tap Edit, then tap Add Widget.';

  @override
  String get widgetsGuideHomeStep3 => 'Search for Prism, pick a size, then tap Add Widget.';

  @override
  String get widgetsGuideLockStep1 => 'Touch and hold your Lock Screen, then tap Customize.';

  @override
  String get widgetsGuideLockStep2 => 'Tap Lock Screen, then tap the widget area under the clock.';

  @override
  String get widgetsGuideLockStep3 => 'Pick Prism, then tap a widget to add it.';

  @override
  String get widgetsGuideHomeIllustration => 'A phone with the Wall of the Day widget on the Home Screen';

  @override
  String get widgetsGuideLockIllustration => 'A phone with Prism widgets on the Lock Screen';

  @override
  String get widgetsGuideDone => 'Done';

  @override
  String get widgetsCardTitle => 'Wall of the Day on your Home Screen';

  @override
  String get widgetsCardBody => 'Add the widget and see a new wall every day.';

  @override
  String get widgetsCardAction => 'Show me how';

  @override
  String get widgetsCardDismiss => 'Dismiss';

  @override
  String get foldersTitle => 'Folders';

  @override
  String get foldersSaveToFolder => 'Save to folder';

  @override
  String get foldersAddToFolder => 'Add to folder';

  @override
  String get foldersNewFolder => 'New folder';

  @override
  String get foldersNameHint => 'Folder name';

  @override
  String get foldersCreate => 'Create';

  @override
  String get foldersCreateFolder => 'Create folder';

  @override
  String get foldersSuggested => 'Suggested';

  @override
  String get foldersNewTag => 'New';

  @override
  String foldersItemCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers',
      one: '1 wallpaper',
      zero: 'No wallpapers',
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
      other: 'Saved to $countString folders.',
      one: 'Saved to 1 folder.',
    );
    return '$_temp0';
  }

  @override
  String get foldersUpdated => 'Folders updated.';

  @override
  String get foldersSaveFailed => 'Could not save to folders. Try again.';

  @override
  String get foldersUpdateFailed => 'Could not update the folder. Try again.';

  @override
  String get foldersRename => 'Rename';

  @override
  String get foldersRenameTitle => 'Rename folder';

  @override
  String get foldersDelete => 'Delete';

  @override
  String foldersDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get foldersDeleteMessage => 'The wallpapers stay in your favourites.';

  @override
  String get foldersDeleteConfirm => 'Delete folder';

  @override
  String get foldersDeleted => 'Folder deleted.';

  @override
  String get foldersRemoveTitle => 'Remove from this folder?';

  @override
  String get foldersRemoveMessage => 'It stays in your favourites.';

  @override
  String get foldersRemoveConfirm => 'Remove';

  @override
  String get foldersRemoved => 'Removed from the folder.';

  @override
  String get foldersEmptyTitle => 'This folder is empty';

  @override
  String get foldersEmptyBody => 'Hold the heart on a wallpaper to save it here.';

  @override
  String get foldersLoadError => 'Could not load this folder.';

  @override
  String get foldersNotFoundTitle => 'This folder is not available';

  @override
  String get foldersNotFoundBody => 'It may have been deleted.';

  @override
  String get foldersSignInFeature => 'folders';

  @override
  String get foldersMoreOptions => 'More options';

  @override
  String get foldersSuggestionLockScreen => 'Lock screen';

  @override
  String get foldersSuggestionHomeScreen => 'Home screen';

  @override
  String get moodDreamyTitle => 'Dreamy';

  @override
  String get moodDreamyBody => 'Soft skies and pastel light.';

  @override
  String get moodDarkQuietTitle => 'Dark and quiet';

  @override
  String get moodDarkQuietBody => 'Low light, easy on the eyes.';

  @override
  String get moodBrightBoldTitle => 'Bright and bold';

  @override
  String get moodBrightBoldBody => 'Big colour to wake up your screen.';

  @override
  String get moodMinimalTitle => 'Minimal';

  @override
  String get moodMinimalBody => 'Simple shapes and room to breathe.';

  @override
  String get moodSpatialReadyTitle => 'Spatial ready';

  @override
  String get moodSpatialReadyBody => 'Made to pop as a Spatial Scene.';

  @override
  String get moodDepthReadyTitle => 'Depth ready';

  @override
  String get moodDepthReadyBody => 'The subject steps in front of your clock.';

  @override
  String get moodChipRowLabel => 'Moods';

  @override
  String get moodSeeAll => 'See all';

  @override
  String moodSeeAllHint(String mood) {
    return 'Opens all $mood wallpapers';
  }

  @override
  String get moodLoadError => 'Couldn\'t load these wallpapers';

  @override
  String get moodEmptyTitle => 'No wallpapers here yet';

  @override
  String get moodEmptyBody => 'New wallpapers join every day.';

  @override
  String wallpaperHistoryTileSemantic(String current, String target, String date) {
    return '${current}Set again. $target, $date';
  }

  @override
  String get wallpaperHistoryTitle => 'Wallpaper history';

  @override
  String get wallpaperLibraryHistoryBody => 'The wallpapers you set, so you can set them again.';

  @override
  String get wallpaperLibraryHistoryTitle => 'Wallpaper history';

  @override
  String get wallpaperLibraryOpenHistory => 'Open history';

  @override
  String get wallpaperRecentlySet => 'Recently set';

  @override
  String get wallpaperSetAgain => 'Set this wallpaper again';

  @override
  String get wallpaperSort => 'Sort';

  @override
  String get tasteQuizTitle => 'Pick the one you like more';

  @override
  String get tasteQuizWildCard => 'Wild card';

  @override
  String tasteQuizProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString of $totalString';
  }

  @override
  String tasteQuizProgressLabel(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Round $currentString of $totalString';
  }

  @override
  String get tasteQuizSkip => 'Skip';

  @override
  String tasteQuizPickLabel(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Pick this wallpaper, $positionString of $totalString';
  }

  @override
  String get tasteQuizTuningTitle => 'Tuning your feed';

  @override
  String tasteQuizSummaryFull(String tone, String density, String tag) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Dark', 'other': 'Light'});
    String _temp1 = intl.Intl.selectLogic(density, {'minimal': 'minimal', 'other': 'detailed'});
    return '$_temp0, $_temp1, a bit of $tag';
  }

  @override
  String tasteQuizSummaryToneDensity(String tone, String density) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Dark', 'other': 'Light'});
    String _temp1 = intl.Intl.selectLogic(density, {'minimal': 'minimal', 'other': 'detailed'});
    return '$_temp0 and $_temp1';
  }

  @override
  String tasteQuizSummaryToneTag(String tone, String tag) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Dark', 'other': 'Light'});
    return '$_temp0, with a bit of $tag';
  }

  @override
  String tasteQuizSummaryDensityTag(String density, String tag) {
    String _temp0 = intl.Intl.selectLogic(density, {'minimal': 'Minimal', 'other': 'Detailed'});
    return '$_temp0, with a bit of $tag';
  }

  @override
  String tasteQuizSummaryTone(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Mostly dark walls', 'other': 'Mostly light walls'});
    return '$_temp0';
  }

  @override
  String tasteQuizSummaryDensity(String density) {
    String _temp0 = intl.Intl.selectLogic(density, {
      'minimal': 'Mostly minimal walls',
      'other': 'Mostly detailed walls',
    });
    return '$_temp0';
  }

  @override
  String tasteQuizSummaryTag(String tag) {
    return 'More $tag walls';
  }

  @override
  String get tasteQuizSummaryReady => 'Your feed is ready';

  @override
  String get tasteQuizRetake => 'Retake This or that';

  @override
  String get tasteQuizRetakeFailed => 'Couldn\'t load walls. Check your connection and try again.';

  @override
  String get foldersPublic => 'Public';

  @override
  String get foldersMakePublic => 'Make public';

  @override
  String get foldersMakePrivate => 'Make private';

  @override
  String get foldersSmartNew => 'New smart folder';

  @override
  String get foldersSmartTag => 'Smart';

  @override
  String get foldersSmartIntro => 'Pick rules once. New wallpapers that match go in by themselves.';

  @override
  String get foldersSmartRulesTitle => 'Rules';

  @override
  String get foldersSmartRulesHint => 'A wallpaper must match each kind you pick. Inside one kind, any choice counts.';

  @override
  String get foldersSmartKindMood => 'Mood';

  @override
  String get foldersSmartKindColour => 'Colour';

  @override
  String get foldersSmartKindCategory => 'Category';

  @override
  String get foldersSmartKindFollowed => 'Creators I follow';

  @override
  String get foldersSmartKindCreator => 'Creator';

  @override
  String get foldersSmartKindDesktop => 'Desktop version';

  @override
  String get foldersSmartKindOnly => 'Only';

  @override
  String get foldersSmartNoCreators => 'Follow creators to pick one here.';

  @override
  String foldersSmartKindLimit(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You can use up to $countString kinds of rule.',
      one: 'You can use 1 kind of rule.',
    );
    return '$_temp0';
  }

  @override
  String foldersSmartValueLimit(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You can pick up to $countString choices in one kind.',
      one: 'You can pick 1 choice in one kind.',
    );
    return '$_temp0';
  }

  @override
  String get foldersSmartPreviewTitle => 'Preview';

  @override
  String foldersSmartMatches(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString matches',
      one: '1 match',
      zero: '0 matches',
    );
    return '$_temp0';
  }

  @override
  String foldersSmartMatchesMore(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString+ matches');
    return '$_temp0';
  }

  @override
  String get foldersSmartNoMatchesHint =>
      'No wallpaper matches all these rules yet. Remove a rule to see more, or save the folder and new matches go in when they arrive.';

  @override
  String get foldersSmartPickRule => 'Pick a rule to see the wallpapers that match.';

  @override
  String get foldersSmartPreviewError => 'Could not load the preview.';

  @override
  String get foldersSmartCreate => 'Create smart folder';

  @override
  String get foldersSmartSaveRules => 'Save rules';

  @override
  String get foldersSmartEditRules => 'Edit rules';

  @override
  String foldersSmartCreated(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Smart folder created with $countString wallpapers.',
      one: 'Smart folder created with 1 wallpaper.',
      zero: 'Smart folder created. New matches go in when they arrive.',
    );
    return '$_temp0';
  }

  @override
  String foldersSmartRulesSaved(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rules saved. $countString wallpapers match.',
      one: 'Rules saved. 1 wallpaper matches.',
      zero: 'Rules saved. Nothing matches yet.',
    );
    return '$_temp0';
  }

  @override
  String foldersSmartLimitRefused(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You can have up to $countString smart folders. Delete one to make another.',
    );
    return '$_temp0';
  }

  @override
  String get foldersSmartTooManyChanges => 'Too many changes today. Try again tomorrow.';

  @override
  String get foldersSmartSaveFailed => 'Could not save the smart folder. Check your connection and try again.';

  @override
  String get foldersSmartEmptyTitle => 'Nothing matches yet';

  @override
  String get foldersSmartEmptyBody => 'New wallpapers that match the rules go in by themselves.';

  @override
  String foldersSmartRuleSummary(String kind, String values) {
    return '$kind: $values';
  }

  @override
  String foldersSmartRulesLabel(String rules) {
    return 'Rules: $rules';
  }

  @override
  String get foldersMakePublicTitle => 'Make this folder public?';

  @override
  String get foldersMakePublicMessage =>
      'Anyone on Prism can see its name and wallpapers, follow it and open its link. Links you share keep their preview even if you make it private later.';

  @override
  String get foldersMakePrivateTitle => 'Make this folder private?';

  @override
  String get foldersMakePrivateMessage => 'Only you will see it. Its link stops working and its followers lose it.';

  @override
  String get foldersMadePublic => 'This folder is now public.';

  @override
  String get foldersMadePrivate => 'This folder is now private.';

  @override
  String get foldersPublicNameRefused => 'Rename this folder to make it public.';

  @override
  String get foldersHiddenRefused => 'This folder was hidden after reports, so it cannot be public.';

  @override
  String get foldersLimitRefused => 'You changed folders too many times today. Try again tomorrow.';

  @override
  String get foldersFollow => 'Follow';

  @override
  String get foldersFollowing => 'Following';

  @override
  String foldersFollowerCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString followers',
      one: '1 follower',
      zero: 'No followers',
    );
    return '$_temp0';
  }

  @override
  String foldersByOwner(String name) {
    return 'By $name';
  }

  @override
  String get foldersShare => 'Share folder';

  @override
  String get foldersReport => 'Report folder';

  @override
  String get foldersDiscoverSectionTitle => 'Folders to follow';

  @override
  String get foldersDiscoverTitle => 'Discover folders';

  @override
  String get foldersDiscoverTabTrending => 'Trending';

  @override
  String get foldersDiscoverTabNew => 'New';

  @override
  String get foldersDiscoverTabLikeYourSaves => 'Like your saves';

  @override
  String get foldersDiscoverTrendingEmptyTitle => 'No trending folders yet';

  @override
  String get foldersDiscoverTrendingEmptyBody => 'Folders that people follow and save this week show here.';

  @override
  String get foldersDiscoverNewEmptyTitle => 'No new folders this week';

  @override
  String get foldersDiscoverNewEmptyBody => 'Public folders can show here for a week after they reach 8 wallpapers.';

  @override
  String get foldersDiscoverSavesEmptyTitle => 'Nothing like your saves yet';

  @override
  String get foldersDiscoverSavesEmptyBody =>
      'Save wallpapers you like. Folders with the same moods and categories show here.';

  @override
  String get foldersDiscoverSeeTrending => 'See trending folders';

  @override
  String get foldersDiscoverLoadError => 'Couldn\'t load folders';

  @override
  String get foldersDiscoverSavesError => 'Couldn\'t read your saves';

  @override
  String foldersDiscoverFollowNamed(String name) {
    return 'Follow $name';
  }

  @override
  String foldersDiscoverUnfollowNamed(String name) {
    return 'Unfollow $name';
  }

  @override
  String get adminFolderReport => 'Folder report';

  @override
  String get adminHideFromDiscovery => 'Hide from discovery';

  @override
  String get adminKeepFolder => 'Keep folder';

  @override
  String get adminFolderHiddenFromDiscovery => 'Hidden from discovery. The folder still opens by link.';

  @override
  String get adminFolderKept => 'Folder kept';

  @override
  String get foldersUnavailableTitle => 'This folder is private or no longer exists';

  @override
  String get foldersUnavailableBody => 'The owner may have made it private or deleted it.';

  @override
  String get foldersFollowFailed => 'Could not update the follow. Try again.';

  @override
  String get foldersYouFollow => 'Folders you follow';

  @override
  String get foldersPublicEmptyTitle => 'No wallpapers here yet';

  @override
  String get foldersPublicEmptyBody => 'New wallpapers show here when the owner adds them.';

  @override
  String get notifSettingFolders => 'Folders you follow';

  @override
  String get notifSettingFoldersDescription => 'New wallpapers in folders you follow, once a day';

  @override
  String notifPushFolderDigestTitleOne(String folderName) {
    return 'New in $folderName';
  }

  @override
  String notifPushFolderDigestTitleMore(String folderName, int count) {
    return 'New in $folderName and $count more';
  }

  @override
  String get topicFollow => 'Follow';

  @override
  String get topicFollowing => 'Following';

  @override
  String topicFollowHint(String topic) {
    return 'Follow $topic';
  }

  @override
  String topicUnfollowHint(String topic) {
    return 'Unfollow $topic';
  }

  @override
  String topicFollowedToast(String topic) {
    return 'Following $topic. With topic notifications on, you get at most one push a day about new wallpapers here.';
  }

  @override
  String topicFollowLimit(int max) {
    return 'You can follow up to $max topics. Unfollow one in Settings first.';
  }

  @override
  String get topicFollowFailed => 'Could not update the follow. Check your connection and try again.';

  @override
  String get topicUnfollow => 'Unfollow';

  @override
  String get topicKindCategory => 'Category';

  @override
  String get topicKindMood => 'Mood';

  @override
  String get followingRowTitle => 'Following';

  @override
  String get followingRowLabel => 'Categories and moods you follow';

  @override
  String topicNewWallpapers(String topic) {
    return '$topic, new wallpapers';
  }

  @override
  String get followedTopicsTitle => 'Topics you follow';

  @override
  String followedTopicsCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString topics',
      one: '1 topic',
      zero: 'None yet',
    );
    return '$_temp0';
  }

  @override
  String get followedTopicsEmptyTitle => 'No topics yet';

  @override
  String get followedTopicsEmptyBody =>
      'Open a category or a mood and tap Follow. With topic notifications on, you get at most one push a day about new wallpapers there.';

  @override
  String get notifSettingTopics => 'Topics you follow';

  @override
  String get notifSettingTopicsDescription => 'New wallpapers in categories and moods you follow, once a day';

  @override
  String get layoutHomeHeader => 'Home';

  @override
  String get layoutFollowingRow => 'Show topics you follow';

  @override
  String get layoutFollowingRowFootnote => 'A row at the top of For you. A dot marks a topic with new wallpapers.';

  @override
  String notifPushTopicDigestTitleOne(String topic) {
    return 'A new wall in $topic';
  }

  @override
  String notifPushTopicDigestTitleSolo(int count, String topic) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString new walls in $topic',
      one: 'A new wall in $topic',
    );
    return '$_temp0';
  }

  @override
  String notifPushTopicDigestTitlePair(int count, String topic, String secondTopic) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString new walls in $topic and $secondTopic',
      one: 'A new wall in $topic and $secondTopic',
    );
    return '$_temp0';
  }

  @override
  String notifPushTopicDigestTitleGroup(int count, String topic, int others) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString new walls in $topic and $others other topics',
      one: 'A new wall in $topic and $others other topics',
    );
    return '$_temp0';
  }

  @override
  String get notifPushTopicDigestBodyUntitled => 'Tap to see what\'s new.';

  @override
  String get historySetAndDownloaded => 'Set and downloaded';

  @override
  String get historyDownloaded => 'Downloaded';

  @override
  String get historyRecentlyViewed => 'Recently viewed';

  @override
  String get historySyncedNote => 'Saved to your account, so these come back on a new phone.';

  @override
  String get historySyncedNoteGuest => 'Sign in to keep these on a new phone.';

  @override
  String get historyActionSet => 'Set';

  @override
  String get historyActionDownloaded => 'Downloaded';

  @override
  String historySyncedTileLabel(String action, String time) {
    return '$action at $time';
  }

  @override
  String get historyClearSyncedBody =>
      'This removes the list here and in your account. Your wallpapers and downloads stay as they are.';

  @override
  String get historyClearViewedTitle => 'Clear recently viewed?';

  @override
  String get historyClearViewedBody => 'This removes the wallpapers you opened from this list and from Home.';

  @override
  String get historyClearViewedAction => 'Clear recently viewed';

  @override
  String get historyEmptyBodyAndroid => 'Wallpapers you set or download show up here, so you can find them again.';

  @override
  String get historyEmptyBodyIos => 'Wallpapers you download show up here, so you can find them again.';

  @override
  String get historyViewedEmptyTitle => 'Nothing viewed yet';

  @override
  String get historyViewedEmptyBody => 'Wallpapers you open show up here, so you can find them again.';

  @override
  String get historyViewedOffTitle => 'Viewing history is off';

  @override
  String get historyViewedOffBody => 'Turn on Save viewing history to see the wallpapers you open here.';

  @override
  String get historyViewedOffAction => 'Turn on';

  @override
  String historyViewedTileLabel(String time) {
    return 'Open wallpaper, viewed at $time';
  }

  @override
  String get pickUpTitle => 'Pick up where you left off';

  @override
  String pickUpTileLabel(int index, int count) {
    return 'Open wallpaper $index of $count';
  }

  @override
  String get settingsSaveViewingHistory => 'Save viewing history';

  @override
  String get settingsSaveViewingHistoryBody =>
      'Shows the wallpapers you open in History and on Home. Turning this off clears the list.';

  @override
  String get historyClearFailed => 'Couldn\'t clear history. Check your connection and try again.';

  @override
  String get wallpaperAutoRotateSourceFolder => 'Folder';

  @override
  String wallpaperAutoRotateSourceFolderNamed(String folder) {
    return 'Folder: $folder';
  }

  @override
  String wallpaperAutoRotateNounFolder(String folder) {
    return '$folder';
  }

  @override
  String get wallpaperAutoRotateTooFewFolder =>
      'This folder needs at least 2 wallpapers that can rotate. Prism wallpapers rotate after you download them.';

  @override
  String get wallpaperAutoRotateOpenFolder => 'Open folder';

  @override
  String get wallpaperAutoRotatePickFolder => 'Pick a folder';

  @override
  String get wallpaperAutoRotateNoFolders =>
      'You have no folders yet. Save a wallpaper to a folder, then pick it here.';

  @override
  String wallpaperAutoRotateConfirmFolderTitle(String folder) {
    return 'Rotate $folder?';
  }

  @override
  String get wallpaperAutoRotateConfirmFolderBody =>
      'Your wallpaper changes to one from this folder, on the schedule below.';

  @override
  String get wallpaperAutoRotateConfirmFolderAction => 'Rotate this folder';

  @override
  String wallpaperAutoRotateStoppedFolderDeleted(String folder) {
    return 'Auto-rotate is off because the folder $folder was deleted.';
  }

  @override
  String wallpaperAutoRotateStoppedFolderEmpty(String folder) {
    return 'Auto-rotate is off because the folder $folder has fewer than 2 wallpapers.';
  }

  @override
  String get foldersRotateThisFolder => 'Rotate this folder';

  @override
  String get foldersRotating => 'Rotating';

  @override
  String get foldersRotatingDescription => 'Auto-rotate uses this folder';

  @override
  String get wallpaperAccentResetHint => 'Hold for actions, including Reset to original';

  @override
  String get wallRequestsTitle => 'Wall requests';

  @override
  String get wallRequestsTabTop => 'Top';

  @override
  String get wallRequestsTabNew => 'New';

  @override
  String get wallRequestsTabFilled => 'Filled';

  @override
  String get wallRequestsAsk => 'Request a wall';

  @override
  String get wallRequestsEmptyTopTitle => 'No requests yet';

  @override
  String get wallRequestsEmptyTopBody => 'Ask for the wall you can\'t find. Others can upvote it.';

  @override
  String get wallRequestsEmptyFilledTitle => 'Nothing filled yet';

  @override
  String get wallRequestsEmptyFilledBody => 'Filled requests show up here with the wall that answered them.';

  @override
  String get wallRequestsLoadFailed => 'Couldn\'t load requests';

  @override
  String get wallRequestsRetry => 'Try again';

  @override
  String wallRequestVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: 'No votes',
    );
    return '$_temp0';
  }

  @override
  String get wallRequestUpvote => 'Upvote';

  @override
  String get wallRequestRemoveUpvote => 'Remove upvote';

  @override
  String get wallRequestMine => 'Your request';

  @override
  String get wallRequestSomeone => 'A Prism user';

  @override
  String wallRequestFilledByCreator(String name) {
    return 'Filled by $name';
  }

  @override
  String get wallRequestFilledByStudio => 'Made by Prism Studio';

  @override
  String get wallRequestOpenWall => 'Open the wall';

  @override
  String get wallRequestMoreActions => 'More actions';

  @override
  String get wallRequestReport => 'Report request';

  @override
  String get wallRequestHide => 'Hide request';

  @override
  String get wallRequestUnhide => 'Show request';

  @override
  String get wallRequestHiddenLabel => 'Hidden';

  @override
  String get wallRequestSheetTitle => 'Request a wall';

  @override
  String get wallRequestSheetHint => 'Describe it, like dark minimal mountains';

  @override
  String get wallRequestSheetTags => 'Tags, up to 3';

  @override
  String get wallRequestSheetSubmit => 'Request it';

  @override
  String get wallRequestSignIn => 'Sign in to request walls and upvote them.';

  @override
  String get wallRequestDuplicateTitle => 'Someone asked for this already';

  @override
  String get wallRequestDuplicateBody => 'Upvote it so creators see it sooner.';

  @override
  String get wallRequestUpvoteInstead => 'Upvote this instead';

  @override
  String get wallRequestCreateAnyway => 'Request mine anyway';

  @override
  String get wallRequestDuplicateMine => 'You asked for this already';

  @override
  String get wallRequestDuplicateVoted => 'You upvoted this already';

  @override
  String get wallRequestEditText => 'Edit my request';

  @override
  String get wallRequestCreated => 'Request sent. We\'ll tell you when it\'s filled.';

  @override
  String get wallRequestUpvoted => 'Upvoted. We\'ll tell you when it\'s filled.';

  @override
  String get wallRequestErrorText => 'Use 3 to 80 characters, and keep it friendly.';

  @override
  String get wallRequestErrorLimit => 'You can make 3 requests a day. Try again tomorrow.';

  @override
  String get wallRequestErrorOwn => 'You can\'t upvote your own request.';

  @override
  String get wallRequestErrorClosed => 'This request is already filled.';

  @override
  String get wallRequestErrorGone => 'This request isn\'t available anymore.';

  @override
  String get wallRequestErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get searchRequestPrompt => 'Can\'t find it?';

  @override
  String get searchRequestAction => 'Request it';

  @override
  String get discoverRequestsTitle => 'Wall requests';

  @override
  String get discoverRequestsSubtitle => 'Ask for a wall, or upvote one';

  @override
  String get uploadFillsRequest => 'Fills a request';

  @override
  String get uploadFillsRequestHint => 'Optional. Pick the request this wall answers.';

  @override
  String get uploadFillsRequestClear => 'Remove request';

  @override
  String get requestPickerTitle => 'Which request does it fill?';

  @override
  String get requestPickerSearch => 'Search requests';

  @override
  String get requestPickerEmpty => 'No open requests match';

  @override
  String get notifPushWallRequestFilledTitle => 'Your request is here';

  @override
  String notifPushWallRequestFilledBody(String requestText) {
    return '$requestText';
  }

  @override
  String get wallRequestAgeNow => 'Just now';

  @override
  String wallRequestAgeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count minutes ago', one: '1 minute ago');
    return '$_temp0';
  }

  @override
  String wallRequestAgeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count hours ago', one: '1 hour ago');
    return '$_temp0';
  }

  @override
  String wallRequestAgeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count days ago', one: '1 day ago');
    return '$_temp0';
  }

  @override
  String wallRequestAgeWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count weeks ago', one: '1 week ago');
    return '$_temp0';
  }

  @override
  String get wallRequestErrorAccountAge => 'Your account can request walls and vote once it\'s 10 days old.';

  @override
  String get adminFillsRequest => 'Fills request';

  @override
  String get wallRemixAction => 'Remix';

  @override
  String get wallRemixActionTooltip => 'Remix this wallpaper with AI';

  @override
  String wallRemixingChip(String title, String creator) {
    return 'Remixing $title by $creator';
  }

  @override
  String get wallRemixDropLinkTooltip => 'Remove remix link';

  @override
  String get wallRemixUntitled => 'Untitled';

  @override
  String get wallRemixUnknownCreator => 'a Prism creator';

  @override
  String get wallRemixesTitle => 'Remixes';

  @override
  String wallRemixesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count remixes', one: '1 remix');
    return '$_temp0';
  }

  @override
  String wallRemixOpenRemixLabel(String creator) {
    return 'Open remix by $creator';
  }

  @override
  String wallRemixOfLabel(String title, String creator) {
    return 'Remix of $title by $creator';
  }

  @override
  String get wallRemixOfTooltip => 'Open the original wallpaper';

  @override
  String get economyAiSubmitPromptNotice => 'Anyone can see your prompt and remix this wallpaper.';

  @override
  String get notifPushWallRemixedTitle => 'Your wallpaper was remixed';

  @override
  String notifPushWallRemixedBody(String remixerName, String wallTitle) {
    return '$remixerName remixed $wallTitle.';
  }

  @override
  String notifPushWallRemixedBodyUntitled(String remixerName) {
    return '$remixerName remixed your wallpaper.';
  }

  @override
  String get wallReleaseTitle => 'Release';

  @override
  String get wallReleaseWhenApproved => 'When approved';

  @override
  String get wallReleaseAtTime => 'At a set time';

  @override
  String get wallReleaseWhenApprovedHelp => 'Goes live as soon as a moderator approves it.';

  @override
  String get wallReleaseAtTimeHelp =>
      'Stays hidden after approval until this time. Walls that go live together send your followers one notification.';

  @override
  String wallReleaseDateLabel(String date) {
    return 'Release date: $date';
  }

  @override
  String wallReleaseTimeLabel(String time) {
    return 'Release time: $time';
  }

  @override
  String wallReleaseTimeZone(String zone) {
    return 'Times use your time zone ($zone).';
  }

  @override
  String get wallReleaseTooSoon => 'Choose a time at least 15 minutes from now.';

  @override
  String get wallReleaseTooLate => 'Choose a time within the next 30 days.';

  @override
  String wallReleaseLabel(String when) {
    return 'Releases $when';
  }

  @override
  String get wallMetadataDescription => 'Description';

  @override
  String get wallMetadataEdit => 'Edit details';

  @override
  String get wallResubmitAction => 'Fix and resubmit';

  @override
  String get wallResubmitChooseImage => 'Choose image';

  @override
  String get wallResubmitImageMissing => 'The original image is no longer available. Choose it again to keep editing.';

  @override
  String get wallResubmitImageKept => 'Original image ready';

  @override
  String get wallResubmitTitle => 'Fix your upload';

  @override
  String get wallUploadUseLastDetails => 'Use last details';

  @override
  String get wallUploadLastDetailsUnavailable => 'No previous details on this device.';

  @override
  String get wallUploadWithdraw => 'Withdraw upload';

  @override
  String get wallUploadWithdrawTitle => 'Withdraw this upload?';

  @override
  String get wallUploadWithdrawBody => 'This removes the upload from review and deletes its uploaded files.';

  @override
  String get wallUploadWithdrawn => 'Upload withdrawn';

  @override
  String get wallUploadDeleteHistory => 'Delete from history';

  @override
  String get wallMetadataInvalid => 'Check the text and tags, then try again.';

  @override
  String get wallUploadOwnerChanged => 'Your account changed. Open this upload again.';

  @override
  String get wallResubmitLimit => 'This wallpaper has reached its three linked resubmissions.';

  @override
  String get wallResubmitUnsupported => 'Choose the original image again. AI source details cannot be reused.';

  @override
  String get wallResubmitUnavailable => 'Unable to load this rejected upload. Try again.';

  @override
  String get wallMetadataEditDetails => 'Edit details';

  @override
  String get wallVariantAdd => 'Add a colour variant';

  @override
  String wallVariantUploadContext(String title) {
    return 'Colour variant of $title';
  }

  @override
  String get wallVariantUploadContextUntitled => 'Colour variant of your wallpaper';

  @override
  String get wallVariantUploadHint => 'Use the same size and shape as the original. It joins the set after review.';

  @override
  String get wallVariantUnlinkTooltip => 'Upload as a new wallpaper instead';

  @override
  String wallVariantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count colours');
    return '$_temp0';
  }

  @override
  String wallVariantDotLabel(int index, int count, String colour) {
    return 'Variant $index of $count, $colour';
  }

  @override
  String wallVariantDotLabelPlain(int index, int count) {
    return 'Variant $index of $count';
  }

  @override
  String get wallVariantDotHint => 'Show this colour';

  @override
  String get wallVariantNextHint => 'Show the next colour';

  @override
  String get wallVariantPending => 'Colour variant. It joins the set after review.';

  @override
  String get wallVariantLinked => 'In a set of colour variants';

  @override
  String get wallVariantDroppedTitle => 'Not added as a colour variant';

  @override
  String get wallVariantDroppedNotFound => 'The original wallpaper was removed.';

  @override
  String get wallVariantDroppedNotOwner => 'The original belongs to another creator.';

  @override
  String get wallVariantDroppedNotApproved => 'The original is not approved.';

  @override
  String get wallVariantDroppedFull => 'The set already has 5 colours.';

  @override
  String get wallVariantDroppedAspect => 'It has a different shape from the original.';

  @override
  String get wallMetadataScheduledHelp =>
      'Approved and scheduled. You can change the release time. Other details unlock when the wall goes live.';

  @override
  String get wallMetadataApprovedHelp =>
      'Change the title, description and tags. The image and category stay the same.';

  @override
  String get wallMetadataPendingHelp => 'Update these details before your wallpaper is reviewed.';

  @override
  String get wallMetadataSave => 'Save details';

  @override
  String get wallMetadataSaved => 'Details saved';

  @override
  String get wallMetadataDiscardTitle => 'Discard changes?';

  @override
  String get wallMetadataDiscardBody => 'Your unsaved details will be lost.';

  @override
  String get wallMetadataDiscard => 'Discard changes';

  @override
  String get wallMetadataReload => 'Reload details';

  @override
  String get wallMetadataReloadTitle => 'Reload current details?';

  @override
  String get wallMetadataReloadBody => 'This replaces your unsaved details with the current version.';

  @override
  String get wallMetadataConflict =>
      'These details changed elsewhere. Your edits are still here. Reload the current details before saving.';

  @override
  String get wallMetadataStatusChanged =>
      'This wallpaper is no longer in the same review state. Your edits have not been saved.';

  @override
  String get wallMetadataMissing => 'This wallpaper is no longer available. Your edits have not been saved.';

  @override
  String get wallMetadataDenied => 'You do not have permission to edit this wallpaper.';

  @override
  String get wallMetadataSignedOut => 'Sign in again to edit this wallpaper.';

  @override
  String get wallMetadataDailyLimit => 'You have reached today\'s edit limit. Try again tomorrow.';

  @override
  String get wallMetadataUnavailable => 'Unable to save details. Check your connection and try again.';

  @override
  String get wallMetadataLoadFailed => 'Unable to load details';

  @override
  String get wallMetadataHistory => 'Edit history';

  @override
  String get wallMetadataHistoryEmpty => 'No metadata edits yet';

  @override
  String get wallMetadataHistoryEmptyBody => 'Changes to the approved title, description and tags appear here.';

  @override
  String get wallMetadataHistoryFailed => 'Unable to load edit history';

  @override
  String get wallMetadataBefore => 'Before';

  @override
  String get wallMetadataAfter => 'After';

  @override
  String get wallMetadataRevert => 'Revert edit';

  @override
  String get wallMetadataRevertTitle => 'Revert this edit?';

  @override
  String get wallMetadataRevertBody =>
      'Restore only the previous title, description and tags shown here. The image and review state will not change.';

  @override
  String get wallMetadataReverted => 'Edit reverted';

  @override
  String get wallMetadataLoadMore => 'Load more edits';

  @override
  String get wallMetadataAbsent => 'Not set';

  @override
  String wallMetadataResubmitted(int attempt) {
    return 'Resubmitted · attempt $attempt of 3';
  }

  @override
  String get wallMetadataPreviousReason => 'Previous rejection reason';

  @override
  String get wallMetadataContextUnavailable => 'Resubmission details unavailable';

  @override
  String get reportSheetMessage =>
      'Tell us what went wrong. Prism never adds your email address or sign-in tokens. Check any screenshot before you send it.';

  @override
  String get reportTopicCrashFreeze => 'Crash/freeze';

  @override
  String get reportTopicWallpaperWontSet => 'Wallpaper won\'t set';

  @override
  String get reportTopicLooksBroken => 'Looks broken';

  @override
  String get reportTopicSlow => 'Slow';

  @override
  String get reportTopicOther => 'Other';

  @override
  String get reportNoteHint => 'What happened? What did you expect?';

  @override
  String get reportScreenshotTitle => 'Screenshot';

  @override
  String get reportScreenshotEmpty => 'Show us what you see.';

  @override
  String get reportScreenshotAttached => 'Tap to view. Check it before you send.';

  @override
  String get reportAddScreenshot => 'Add screenshot';

  @override
  String get reportRemoveScreenshot => 'Remove';

  @override
  String get reportViewScreenshot => 'View screenshot';

  @override
  String get reportIncludeDiagnostics => 'Include device info & recent logs';

  @override
  String get reportShowDiagnostics => 'Show what\'s included';

  @override
  String get reportHideDiagnostics => 'Hide details';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportShareAsFile => 'Share as file';

  @override
  String reportSent(String reference) {
    return 'Thanks, report sent. Reference $reference';
  }

  @override
  String get reportCouldNotSend => 'Couldn\'t send';

  @override
  String get reportCouldNotSendBody => 'Check your connection and try again, or share the report as a file.';

  @override
  String get reportShareInstead => 'Share instead';

  @override
  String get reportShakeToReport => 'Shake to report';

  @override
  String get reportShakeToReportSubtitle => 'Shake your phone on any screen to report a problem';

  @override
  String get accountShowAiWallpapers => 'Show AI-generated wallpapers';

  @override
  String get accountShowAiWallpapersSubtitle => 'Turn off to see only human-made walls';

  @override
  String get accountShowAiWallpapersFootnote => 'Hiding AI wallpapers never hides your own uploads or favourites.';

  @override
  String get wallpaperFeedHideAi => 'Hide AI';

  @override
  String get wallpaperAiGenerated => 'AI-generated';

  @override
  String wallpaperAiMadeWith(String model) {
    return 'Made with $model';
  }

  @override
  String get wallpaperAiMadeWithUnknown => 'Made with AI';

  @override
  String get wallpaperAiReportWrongLabel => 'Report wrong label';

  @override
  String get feedNoHumanWalls => 'No human-made walls here yet';

  @override
  String get feedShowAiWalls => 'Show AI walls';

  @override
  String get dailyMomentTitle => 'Daily moment';

  @override
  String get dailyMomentStreakTitle => 'Daily streak';

  @override
  String get dailyMomentChestTitle => 'Daily chest';

  @override
  String get dailyMomentSpinTitle => 'Free spin';

  @override
  String get dailyMomentUnavailable => 'This reward is no longer available today.';

  @override
  String get dailyMomentError => 'Could not load your reward. Try again.';

  @override
  String dailyMomentStreakReceipt(int coins, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins coins earned',
      one: '$coins coin earned',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'streak of $days days',
      one: 'streak of $days day',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get challengeTitle => 'Weekly challenge';

  @override
  String get challengeRules => 'Up to 3 entries, each reviewed before appearing.';

  @override
  String challengeVotingRules(String date) {
    return 'Vote for other creators until $date.';
  }

  @override
  String get challengeUpload => 'Upload an entry';

  @override
  String get challengeAi => 'Create with AI';

  @override
  String get challengeTop => 'Top';

  @override
  String get challengeNew => 'New';

  @override
  String get challengePast => 'Past challenges';

  @override
  String get challengeEmpty => 'Approved entries will appear here.';

  @override
  String get challengeWaiting => 'Voting has closed. We are waiting for entry reviews before choosing a winner.';

  @override
  String get challengeClosed => 'This challenge has ended.';

  @override
  String get challengeScheduled => 'This challenge has not opened yet.';

  @override
  String get challengeNoWinner => 'No winner for this challenge.';

  @override
  String challengeWinner(String name) {
    return 'Winner · $name';
  }

  @override
  String get challengeVote => 'Vote';

  @override
  String get challengeUnvote => 'Remove vote';

  @override
  String challengeVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: '0 votes',
    );
    return '$_temp0';
  }

  @override
  String get dailyMomentCosmetic => 'Cosmetic added to your collection';

  @override
  String dailyMomentReward(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins coins earned',
      one: '$coins coin earned',
    );
    return '$_temp0';
  }

  @override
  String get dailyMomentChestBody => 'Open today’s chest when you’re ready.';

  @override
  String get dailyMomentSpinBody => 'Your free spin is ready.';

  @override
  String dailyMomentBalance(int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coins coins', one: '$coins coin');
    return 'Balance: $_temp0';
  }

  @override
  String get dailyMomentDone => 'Done';

  @override
  String get dailyMomentRetry => 'Try again';

  @override
  String get dailyMomentContinue => 'Continue';

  @override
  String get dailyMomentOpenFree => 'Open free chest';

  @override
  String dailyMomentOpenChest(int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coins coins', one: '$coins coin');
    return 'Open for $_temp0';
  }

  @override
  String get dailyMomentSpinAction => 'Take free spin';

  @override
  String get dailyMomentClose => 'Close daily moment';

  @override
  String get dailyMomentToday => 'Today';

  @override
  String get dailyMomentReady => 'Daily rewards are ready';

  @override
  String get dailyMomentComplete => 'Today is complete';

  @override
  String get dailyMomentResume => 'Continue daily moment';

  @override
  String get dailyMomentMore => 'More';

  @override
  String get dailyMomentQuests => 'Quests';

  @override
  String get dailyMomentChestLeft => 'Daily chest available';

  @override
  String get dailyMomentSpinLeft => 'Free spin available';

  @override
  String get dailyMomentStreakLeft => 'Daily streak available';

  @override
  String get challengeShare => 'Share challenge';

  @override
  String get challengeRemove => 'Remove challenge';

  @override
  String challengeContext(String theme) {
    return 'Challenge · $theme';
  }

  @override
  String get challengeError => 'We could not load this challenge. Try again.';

  @override
  String get challengeVoteError => 'Your vote could not be saved. Try again.';

  @override
  String get challengeSignIn => 'Sign in to enter or vote.';

  @override
  String get challengeLimit => 'You have entered 3 wallpapers in this challenge.';

  @override
  String get challengeRetry => 'Try again';

  @override
  String get challengeOwnEntry => 'You cannot vote for your own entry.';

  @override
  String get challengeDailyLimit => 'Your daily voting limit is reached.';

  @override
  String get challengeMissing => 'This challenge or entry is no longer available.';

  @override
  String get challengeBadge => 'Challenge Winner';

  @override
  String get challengeBadgeDescription => 'Win a weekly challenge';

  @override
  String get challengeWinnerNotificationTitle => 'Your wallpaper won';

  @override
  String challengeWinnerNotificationBody(String theme) {
    return 'Your entry won the weekly challenge: $theme.';
  }

  @override
  String get statsTitle => 'Your stats';

  @override
  String get statsEntry => 'Stats';

  @override
  String get statsViews => 'Views';

  @override
  String get statsSaves => 'Saves';

  @override
  String get statsSets => 'Sets';

  @override
  String get statsDownloads => 'Downloads';

  @override
  String get statsShares => 'Shares';

  @override
  String get statsFolderAdds => 'Folder additions';

  @override
  String get statsRemixes => 'Remixes';

  @override
  String get statsLoading => 'Loading your stats';

  @override
  String get statsError => 'Your stats could not load. Please try again.';

  @override
  String get statsRetry => 'Try again';

  @override
  String get statsEmptyTitle => 'Your first wall starts here';

  @override
  String get statsEmptyBody => 'Upload a wallpaper. Its stats will appear after approval.';

  @override
  String get statsUpload => 'Upload a wallpaper';

  @override
  String get statsWeekNote => 'This week so far compared with last week. Weeks start on Monday, UTC.';

  @override
  String get statsHistoryNote =>
      'Eight weeks, oldest first. A dash means unavailable history. Tracking can begin partway through a week, so recorded weeks may be partial. The current week is incomplete.';

  @override
  String get statsTopWalls => 'Top walls this week';

  @override
  String get statsUntitled => 'Untitled wall';

  @override
  String get statsCountingNote =>
      'Save totals count current favourites; weekly saves count additions. Remix totals count current credited remixes; weekly remixes count first accepted credits. Folder additions are recorded only from the start of tracking.';

  @override
  String get statsUnavailable => 'Unavailable';

  @override
  String get statsWeeklyTitle => 'Your walls this week';

  @override
  String statsWeeklyBody(String week) {
    return 'See how your walls did in $week.';
  }

  @override
  String statsWallValue(String metric, String value) {
    return '$metric: $value this week';
  }

  @override
  String statsComparison(String current, String previous) {
    return '$current this week · $previous last week';
  }

  @override
  String statsTotal(String value) {
    return 'Total: $value';
  }

  @override
  String statsChange(String value) {
    return '$value compared with last week';
  }

  @override
  String statsUpdated(String date) {
    return 'Updated $date UTC';
  }

  @override
  String statsChartWeek(String date, String value) {
    return 'Week of $date: $value';
  }

  @override
  String statsChartSummary(String metric, String summary) {
    return '$metric, eight weeks. $summary';
  }

  @override
  String get shortcutsGuideHeadline => 'A new wallpaper every day';

  @override
  String get shortcutsGuideBody =>
      'Set up Shortcuts once. Each day it sets a wallpaper from your rotation folder. Its 200 newest walls each show once before any repeats.';

  @override
  String get shortcutsSourceRotation => 'Rotation folder';

  @override
  String get shortcutsSourceRotationDescription => 'Shuffles the folder you picked above.';

  @override
  String get shortcutsSourceFolder => 'Folder';

  @override
  String get shortcutsSourceFolderDescription => 'Shuffles a folder that you pick in Shortcuts.';

  @override
  String get shortcutsSourceFavouriteDescription =>
      'Shuffles your favourites. Each one shows once before any repeats. Some protected wallpapers may not be available.';

  @override
  String get shortcutsRotationNone => 'No folder picked';

  @override
  String get shortcutsRotationNoneBody => 'Pick the folder that the shortcut shuffles.';

  @override
  String get shortcutsRotationPick => 'Pick a folder';

  @override
  String get shortcutsRotationChange => 'Change';

  @override
  String get shortcutsRotationStop => 'Stop';

  @override
  String shortcutsStepLabel(int number, String title) {
    return 'Step $number, $title';
  }

  @override
  String get shortcutsStepAddTitle => 'Add the Prism shortcut';

  @override
  String get shortcutsStepAddBody => 'It gets a wall from your rotation folder and sets it as your wallpaper.';

  @override
  String get shortcutsStepAddAction => 'Add the shortcut';

  @override
  String get shortcutsStepAddManualBody => 'Make it in Shortcuts with 2 actions.';

  @override
  String get shortcutsManualNew => 'In Shortcuts, tap + to make a new shortcut.';

  @override
  String get shortcutsManualGet => 'Add \"Get Prism Wallpaper\". Set Source to Rotation folder.';

  @override
  String get shortcutsManualSet => 'Add \"Set Wallpaper Photo\". Tap the arrow on it, then turn off Show Preview.';

  @override
  String shortcutsManualName(String name) {
    return 'Name the shortcut \"$name\".';
  }

  @override
  String get shortcutsStepAutomationTitle => 'Run it every day';

  @override
  String get shortcutsAutomationOpen => 'In Shortcuts, tap Automation, then tap +.';

  @override
  String get shortcutsAutomationTime => 'Tap Time of Day. Pick a time, then choose Daily.';

  @override
  String get shortcutsAutomationRun => 'Choose Run Immediately, then tap Next.';

  @override
  String shortcutsAutomationPick(String name) {
    return 'Pick \"$name\" to run.';
  }

  @override
  String shortcutsAutomationNoTab(String name) {
    return 'No Automation tab? Open \"$name\", tap Edit, then tap Automation.';
  }

  @override
  String get shortcutsStepTestTitle => 'Test it now';

  @override
  String shortcutsStepTestBody(String name) {
    return 'Runs \"$name\" once, so you can see the new wallpaper now.';
  }

  @override
  String get shortcutsStepTestAction => 'Run the shortcut';

  @override
  String get foldersRotateDaily => 'Rotate this folder daily';

  @override
  String get autoRotateIosTitle => 'Change wallpapers with Shortcuts';

  @override
  String get autoRotateIosBody => 'On iPhone, a Shortcuts automation sets a new wallpaper from your folder every day.';

  @override
  String get autoRotateIosAction => 'Set up Shortcuts';

  @override
  String get shortcutsAutomationIos16 => 'On iOS 16 there is no Run Immediately. Turn off Ask Before Running instead.';

  @override
  String get dayNightTitle => 'Day and night';

  @override
  String get dayNightSettingsSubtitle => 'One wall for the day, one for the night';

  @override
  String get dayNightIntro =>
      'Pick a wall for the day and one for the night. Shortcuts switches them at the times you set.';

  @override
  String get dayNightUseAsDay => 'Use as day wall';

  @override
  String get dayNightUseAsNight => 'Use as night wall';

  @override
  String get dayNightUseVariants => 'Use the lightest and darkest variant';

  @override
  String get dayNightDaySetToast => 'Day wall set.';

  @override
  String get dayNightNightSetToast => 'Night wall set.';

  @override
  String get dayNightPairSetToast => 'Day and night walls set.';

  @override
  String get dayNightOpenAction => 'Open';

  @override
  String get dayNightDayLabel => 'Day';

  @override
  String get dayNightNightLabel => 'Night';

  @override
  String get dayNightEmptyDay => 'Hold any wallpaper, then tap Use as day wall.';

  @override
  String get dayNightEmptyNight => 'Hold any wallpaper, then tap Use as night wall.';

  @override
  String get dayNightDayStarts => 'Day starts';

  @override
  String get dayNightNightStarts => 'Night starts';

  @override
  String dayNightFrom(String time) {
    return 'From $time';
  }

  @override
  String dayNightPreviewLabel(String slot, String time) {
    return '$slot wall, from $time';
  }

  @override
  String get dayNightTimesEqual => 'Pick two different times.';

  @override
  String get dayNightSwitch => 'Switch walls at these times';

  @override
  String get dayNightNeedsBoth => 'Pick a day wall and a night wall first.';

  @override
  String get dayNightNeedsDownload => 'Download this wall in Prism first.';

  @override
  String get dayNightOpenWall => 'Open wall';

  @override
  String get dayNightPreparing => 'Saving both walls for offline use';

  @override
  String get dayNightPrepareFailed => 'Could not save the walls for offline use. Check your connection.';

  @override
  String get dayNightTryAgain => 'Try again';

  @override
  String get dayNightProTitle => 'Day and night is a Prism Pro feature.';

  @override
  String get dayNightOffEnded => 'Day and night is off because your Prism Pro plan or pass ended.';

  @override
  String get dayNightSetUpAction => 'Set up in Shortcuts';

  @override
  String get dayNightGuideTitle => 'Switch walls with Shortcuts';

  @override
  String dayNightGuideBody(String dayTime, String nightTime) {
    return 'Make 2 automations in Shortcuts, one for $dayTime and one for $nightTime. Each sets the wall that matches its time.';
  }

  @override
  String get dayNightGuideStepAutomation => 'In Shortcuts, tap Automation, then tap +.';

  @override
  String dayNightGuideStepTime(String time) {
    return 'Tap Time of Day. Choose $time, then Daily.';
  }

  @override
  String get dayNightGuideStepRun => 'Choose Run Immediately, then tap Next.';

  @override
  String get dayNightGuideStepBlank => 'Tap New Blank Automation.';

  @override
  String get dayNightGuideStepGet => 'Add \"Get Prism Wallpaper\". Set Source to Day and night.';

  @override
  String dayNightGuideStepSet(String screens) {
    return 'Add \"Set Wallpaper Photo\". Tap the arrow on it, choose $screens, then turn off Show Preview.';
  }

  @override
  String get dayNightGuideScreensHome => 'Home Screen';

  @override
  String get dayNightGuideScreensLock => 'Lock Screen';

  @override
  String get dayNightGuideScreensBoth => 'Lock Screen and Home Screen';

  @override
  String dayNightGuideStepRepeat(String time) {
    return 'Make a second automation the same way for $time.';
  }

  @override
  String get dayNightGuideSunTitle => 'Sunrise and sunset';

  @override
  String get dayNightGuideSunBody =>
      'Choose Sunrise or Sunset instead of a time. In Get Prism Wallpaper, set Time to Day for sunrise and Night for sunset.';

  @override
  String get dayNightIntroAndroid =>
      'Pick a wall for the day and one for the night. Prism switches them at the times you set.';

  @override
  String dayNightAroundTime(String time) {
    return 'Around $time';
  }

  @override
  String get dayNightAndroidTimingNote => 'Android can switch a few minutes late to save battery.';

  @override
  String get dayNightTurnOffAutoRotateTitle => 'Turn off auto-rotate?';

  @override
  String get dayNightTurnOffAutoRotateAction => 'Turn off auto-rotate';

  @override
  String get dayNightTurnOffDayNightTitle => 'Turn off Day and night?';

  @override
  String get dayNightTurnOffDayNightAction => 'Turn off Day and night';

  @override
  String get dayNightOneModeAtATime =>
      'Auto-rotate and Day and night both change your wallpaper. Only one can be on at a time.';

  @override
  String get tipAction => 'Tip creator';

  @override
  String get tipMenuItem => 'Send a tip';

  @override
  String tipTitle(String name) {
    return 'Tip $name';
  }

  @override
  String tipMessage(String name) {
    return 'Pick an amount. $name gets every coin and sees your name.';
  }

  @override
  String get tipAmountsLabel => 'Tip amount';

  @override
  String tipBalance(int balance) {
    String _temp0 = intl.Intl.pluralLogic(balance, locale: localeName, other: '$balance coins', one: '1 coin');
    return 'Your balance: $_temp0';
  }

  @override
  String tipShortBy(int amount) {
    String _temp0 = intl.Intl.pluralLogic(amount, locale: localeName, other: '$amount more coins', one: '1 more coin');
    return 'You need $_temp0.';
  }

  @override
  String tipSendButton(int amount) {
    return 'Tip $amount coins';
  }

  @override
  String get tipEarnCoins => 'Earn coins';

  @override
  String get tipThanksTitle => 'Thanks for your tip';

  @override
  String tipThanksMessage(String name, int amount) {
    return '$name got your $amount coins.';
  }

  @override
  String get tipDone => 'Done';

  @override
  String get tipNotEnoughCoins => 'You don\'t have enough coins for this tip.';

  @override
  String get tipDailyLimit => 'You\'ve sent all your tips for today. Try again tomorrow.';

  @override
  String tipPairLimit(String name) {
    return 'You already tipped $name today. Try again tomorrow.';
  }

  @override
  String tipCreatorLimit(String name) {
    return '$name can\'t get more tips today. Try again tomorrow.';
  }

  @override
  String get tipSenderTooNew => 'You can send tips 7 days after you join Prism.';

  @override
  String get tipSenderIneligible => 'Sign in with a verified account to send tips.';

  @override
  String tipUnavailable(String name) {
    return 'You can\'t tip $name right now.';
  }

  @override
  String get tipFailed => 'Couldn\'t send the tip. Try again.';

  @override
  String wallTippedBy(int count) {
    return 'Tipped by $count people';
  }

  @override
  String get coreCoinTipSent => 'Tip sent';

  @override
  String get coreCoinTipReceived => 'Tip received';

  @override
  String notifPushTipReceivedTitle(String senderName, String amount, String wallTitle) {
    return '$senderName tipped you $amount coins for $wallTitle';
  }

  @override
  String notifPushTipReceivedTitleUntitled(String senderName, String amount) {
    return '$senderName tipped you $amount coins';
  }

  @override
  String get notifPushTipReceivedBody => 'See your tips in your creator stats.';

  @override
  String notifTipsReceivedTitle(int count) {
    return 'You got $count tips today';
  }

  @override
  String notifTipsReceivedBody(int coins) {
    return '$coins coins in all. See them in your creator stats.';
  }

  @override
  String get statsTips => 'Tips';

  @override
  String statsTipsTotal(int count, int coins) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tips', one: '1 tip');
    return '$_temp0, $coins coins in all';
  }

  @override
  String statsTipsWeek(String date, int count, int coins) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tips', one: '1 tip');
    return 'Week of $date: $_temp0, $coins coins';
  }

  @override
  String statsTipsWall(int count, int coins) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count tips', one: '1 tip');
    return '$_temp0, $coins coins';
  }

  @override
  String get statsTipsEmpty => 'No tips yet. Fans can tip you from your walls and your profile.';

  @override
  String get creatorsToFollow => 'Creators to follow';

  @override
  String get accountBrowseCreators => 'Browse creators';

  @override
  String get creatorsSeeAll => 'See all';

  @override
  String get creatorsTitle => 'Creators';

  @override
  String get creatorsFilterAll => 'All';

  @override
  String get creatorsEmptyTitle => 'No creators here yet';

  @override
  String get creatorsEmptyBody => 'Try another category.';

  @override
  String get creatorsLoadError => 'Couldn\'t load creators';

  @override
  String creatorsOpenProfile(String name) {
    return 'Open $name\'s profile';
  }

  @override
  String creatorsWallBy(String name) {
    return 'Wallpaper by $name';
  }

  @override
  String creatorsFollowedByOne(String first) {
    return 'Followed by $first';
  }

  @override
  String creatorsFollowedByTwo(String first, String second) {
    return 'Followed by $first and $second';
  }

  @override
  String creatorsFollowedByMany(String first, String second, int others) {
    String _temp0 = intl.Intl.pluralLogic(
      others,
      locale: localeName,
      other: '$others others you follow',
      one: '1 other you follow',
    );
    return 'Followed by $first, $second and $_temp0';
  }

  @override
  String creatorsMoreLike(String name) {
    return 'More like $name';
  }

  @override
  String get creatorsSimilarSubtitle => 'Creators with a similar style';

  @override
  String get creatorsShowMeTitle => 'Show me in Creators to follow';

  @override
  String get creatorsShowMeBody => 'Others can find your profile and top wallpapers';

  @override
  String get promoRedeemTitle => 'Redeem a code';

  @override
  String get promoRedeemMessage => 'Enter a code from a Prism post or giveaway.';

  @override
  String get promoRedeemMessageIos => 'Enter a coin code from a Prism post or giveaway.';

  @override
  String get promoCodeFieldLabel => 'Code';

  @override
  String get promoCodeFieldHint => 'For example, 7KQ2 MPXR 4D';

  @override
  String get promoPasteCode => 'Paste code';

  @override
  String get promoRedeemAction => 'Redeem';

  @override
  String get promoRedeeming => 'Redeeming code';

  @override
  String get promoDone => 'Done';

  @override
  String get promoTryAnother => 'Try another code';

  @override
  String promoSuccessCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString coins', one: '1 coin');
    return 'You got $_temp0';
  }

  @override
  String get promoSuccessCoinsMessage => 'They\'re in your balance now.';

  @override
  String promoSuccessPro(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$daysString days', one: '1 day');
    return 'You got $_temp0 of Pro';
  }

  @override
  String promoSuccessProMessage(String date) {
    return 'Your Pro pass now runs until $date.';
  }

  @override
  String get promoErrorInvalid => 'That isn\'t a Prism code. Codes have 10 or more letters and numbers.';

  @override
  String get promoErrorNotFound => 'We can\'t find that code. Check it and try again.';

  @override
  String get promoErrorDisabled => 'This code is turned off.';

  @override
  String get promoErrorExpired => 'This code has expired.';

  @override
  String get promoErrorLimitReached => 'This code has no uses left.';

  @override
  String get promoErrorAlreadyRedeemed => 'You already used this code.';

  @override
  String get promoErrorAccountTooNew => 'Your account is too new for this code.';

  @override
  String get promoErrorNewUsersOnly => 'This code is for new accounts only.';

  @override
  String get promoErrorPremiumNotOnIos => 'Pro codes don\'t work on iPhone or iPad. Use an App Store code instead.';

  @override
  String get promoErrorAlreadyPremium => 'You already have Pro, so this code isn\'t needed.';

  @override
  String get promoErrorRateLimited => 'Too many tries. Wait an hour, then try again.';

  @override
  String get promoErrorBusy => 'Lots of people are redeeming right now. Try again in a moment.';

  @override
  String get promoErrorSignedOut => 'Sign in to redeem a code.';

  @override
  String get promoErrorNetwork => 'Can\'t reach Prism. Check your connection and try again.';

  @override
  String get promoErrorUnknown => 'Something went wrong. Try again.';

  @override
  String get promoSettingsGroup => 'Codes';

  @override
  String get promoSettingsRedeemTitle => 'Redeem a Prism code';

  @override
  String get promoSettingsRedeemSubtitle => 'Coins or Pro days from our posts and giveaways';

  @override
  String get promoSettingsRedeemSubtitleIos => 'Coins from our posts and giveaways';

  @override
  String get promoAppStoreCodeTitle => 'Redeem an App Store code';

  @override
  String get promoAppStoreCodeSubtitle => 'Pro offer codes from Apple';

  @override
  String get promoPlayCodeTitle => 'Redeem a Play code';

  @override
  String get promoPlayCodeSubtitle => 'Pro offer codes from Google Play';

  @override
  String get promoCodesFootnoteIos => 'Prism codes give coins. App Store codes give Pro.';

  @override
  String get promoCodesFootnoteAndroid => 'Prism codes give coins or Pro days. Play codes give Pro.';

  @override
  String get promoStoreCodeFailed => 'Couldn\'t open the code page. Try again.';

  @override
  String get promoRewardsRowTitle => 'Redeem a code';

  @override
  String get promoRewardsRowSubtitle => 'Got a code from a post or giveaway?';

  @override
  String get promoAdminTitle => 'Promo codes';

  @override
  String get promoAdminEntry => 'Promo codes';

  @override
  String get promoAdminCreate => 'Create code';

  @override
  String get promoAdminTypeCoins => 'Coins';

  @override
  String get promoAdminTypePro => 'Pro days';

  @override
  String get promoAdminAmount => 'Amount';

  @override
  String get promoAdminAmountHelpCoins => '1 to 1,000 coins';

  @override
  String get promoAdminAmountHelpPro => '1 to 90 days. Android only.';

  @override
  String get promoAdminMaxRedemptions => 'Max redemptions';

  @override
  String get promoAdminExpiresInDays => 'Expires in (days)';

  @override
  String get promoAdminMinAccountAge => 'Minimum account age (days)';

  @override
  String get promoAdminNewUsersOnly => 'New accounts only';

  @override
  String get promoAdminNewUsersDays => 'Account at most (days old)';

  @override
  String get promoAdminCustomCode => 'Custom code (optional)';

  @override
  String get promoAdminCustomCodeHelp => '10 to 32 letters and numbers, no I, O, 0 or 1. Leave empty to make one.';

  @override
  String get promoAdminLabel => 'Note';

  @override
  String promoAdminCreated(String code) {
    return 'Created $code';
  }

  @override
  String get promoAdminCopied => 'Code copied';

  @override
  String get promoAdminCopy => 'Copy code';

  @override
  String promoAdminRedemptions(int used, int max) {
    return '$used of $max used';
  }

  @override
  String promoAdminExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get promoAdminDisabled => 'Off';

  @override
  String get promoAdminDisable => 'Turn off';

  @override
  String get promoAdminEnable => 'Turn on';

  @override
  String get promoAdminEmpty => 'No codes yet.';

  @override
  String get promoAdminLoadFailed => 'Couldn\'t load codes. Pull to try again.';

  @override
  String promoAdminCreateFailed(String reason) {
    return 'Couldn\'t create the code: $reason';
  }

  @override
  String get desktopVersionChip => 'Desktop version';

  @override
  String get desktopVersionChipSemantic => 'Open the desktop version';

  @override
  String get desktopVersionSheetTitle => 'Desktop version';

  @override
  String desktopVersionSheetBody(int width, int height) {
    return 'The same scene, made wide for a computer screen. $width × $height.';
  }

  @override
  String get desktopVersionPreviewSemantic => 'Desktop version on a computer screen';

  @override
  String get desktopVersionSendToComputer => 'Send to my computer';

  @override
  String desktopVersionShareText(String url) {
    return 'Get this wallpaper for your computer: $url';
  }

  @override
  String get desktopVersionShareSubject => 'Desktop wallpaper from Prism';

  @override
  String get desktopVersionSetOnTablet => 'Set desktop version';

  @override
  String get desktopUploadAdd => 'Add a desktop version';

  @override
  String get desktopUploadReplace => 'Replace desktop version';

  @override
  String get desktopUploadInReview => 'Desktop version in review';

  @override
  String get desktopUploadTitle => 'Add a desktop version';

  @override
  String get desktopUploadReplaceTitle => 'Replace desktop version';

  @override
  String get desktopUploadIntro => 'Add a wide version of this wallpaper for computers. It goes live after review.';

  @override
  String get desktopUploadReplaceNote => 'The current desktop version stays live until the new one is approved.';

  @override
  String get desktopUploadRequirements => 'Use a landscape image in 16:10 or 16:9, at least 1920 px wide.';

  @override
  String get desktopUploadPhoneLabel => 'Phone';

  @override
  String get desktopUploadDesktopLabel => 'Desktop';

  @override
  String get desktopUploadPhoneSemantic => 'Phone wallpaper';

  @override
  String desktopUploadDesktopSemantic(int width, int height) {
    return 'Desktop version, $width × $height';
  }

  @override
  String desktopUploadSize(int width, int height, String ratio) {
    return '$width × $height, $ratio';
  }

  @override
  String get desktopUploadChooseImage => 'Choose image';

  @override
  String get desktopUploadChooseAnother => 'Choose another image';

  @override
  String get desktopUploadSubmit => 'Submit for review';

  @override
  String get desktopUploadSubmitted => 'Desktop version sent for review';

  @override
  String get desktopUploadErrorPortrait => 'Choose a landscape image. It must be wider than it is tall.';

  @override
  String get desktopUploadErrorAspect => 'Choose an image in 16:10 or 16:9. Crop it on your computer, then try again.';

  @override
  String desktopUploadErrorTooSmall(int width) {
    return 'Choose an image at least 1920 px wide. This one is $width px wide.';
  }

  @override
  String get desktopUploadErrorUnreadable => 'Unable to open this image. Choose another one.';

  @override
  String get desktopUploadErrorTooLarge => 'This file is too large. Choose an image under 15 MB.';

  @override
  String get desktopUploadErrorPending => 'A desktop version of this wallpaper is already in review.';

  @override
  String get desktopUploadErrorNotAllowed => 'You can add a desktop version only to your own approved wallpapers.';

  @override
  String get desktopUploadErrorLimit => 'Daily upload limit reached. Try again tomorrow.';

  @override
  String get desktopUploadErrorFailed => 'Unable to submit. Check your connection and try again.';

  @override
  String get desktopVersionSaveOnTablet => 'Save desktop version';

  @override
  String get desktopVersionUnavailable => 'Unable to get the desktop version. Check your connection and try again.';

  @override
  String get layoutTitle => 'Layout';

  @override
  String get layoutRowSubtitle => 'Tabs and wallpaper grid';

  @override
  String get layoutTabsHeader => 'Tabs';

  @override
  String get layoutTabsFootnote => 'Drag to reorder. At least 3 tabs stay in the bar. Hidden tabs are under More.';

  @override
  String get layoutTabAlwaysShown => 'Always in the bar';

  @override
  String get layoutTabUnderMore => 'Under More';

  @override
  String layoutShowTab(String tab) {
    return 'Show $tab';
  }

  @override
  String layoutReorderTab(String tab) {
    return 'Reorder $tab';
  }

  @override
  String get layoutMoveUp => 'Move up';

  @override
  String get layoutMoveDown => 'Move down';

  @override
  String get layoutGridHeader => 'Wallpaper grid';

  @override
  String get layoutDensityCompact => 'Compact';

  @override
  String get layoutDensityComfortable => 'Comfortable';

  @override
  String get layoutDensityLarge => 'Large';

  @override
  String get layoutGridFootnote => 'Applies to every wallpaper grid. Pinch the Home feed to change it.';

  @override
  String get layoutReset => 'Reset layout';

  @override
  String get navMore => 'More';

  @override
  String get navMoreEditTabs => 'Edit tabs';

  @override
  String get layoutControlsHeader => 'Controls';

  @override
  String get layoutOneHanded => 'One-handed controls';

  @override
  String get layoutOneHandedFootnote =>
      'Puts your profile and notifications in the bottom bar, in reach of your thumb.';

  @override
  String get navAccount => 'Profile and notifications';

  @override
  String navUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count unread', one: '1 unread');
    return '$_temp0';
  }

  @override
  String wrappedTitle(String year) {
    return 'Prism Wrapped $year';
  }

  @override
  String get wrappedIntroHeadline => 'Your year in walls';

  @override
  String get wrappedIntroBody => 'A few cards about the walls you loved this year.';

  @override
  String get wrappedSavesLabel => 'Saved';

  @override
  String wrappedSavesBody(int count, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You saved $count walls in $year.',
      one: 'You saved 1 wall in $year.',
    );
    return '$_temp0';
  }

  @override
  String get wrappedColoursLabel => 'Your colours';

  @override
  String wrappedColoursBody(String first, String second, String third) {
    return '$first, $second and $third showed up most in your saves.';
  }

  @override
  String get wrappedCreatorLabel => 'Your top creator';

  @override
  String wrappedCreatorBody(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You saved $count walls by $name.',
      one: 'You saved 1 wall by $name.',
    );
    return '$_temp0';
  }

  @override
  String get wrappedStreakLabel => 'Your longest run';

  @override
  String wrappedStreakBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You checked in $count days in a row.',
      one: 'You checked in 1 day in a row.',
    );
    return '$_temp0';
  }

  @override
  String wrappedDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count days', one: '1 day');
    return '$_temp0';
  }

  @override
  String get wrappedAiLabel => 'Made with AI';

  @override
  String wrappedAiBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You made $count AI walls.',
      one: 'You made 1 AI wall.',
    );
    return '$_temp0';
  }

  @override
  String get wrappedCategoryLabel => 'Your top category';

  @override
  String wrappedCategoryBody(int count, String category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You saved $count walls from $category.',
      one: 'You saved 1 wall from $category.',
    );
    return '$_temp0';
  }

  @override
  String get wrappedFoldersLabel => 'Folders';

  @override
  String wrappedFoldersBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You made $count folders.',
      one: 'You made 1 folder.',
    );
    return '$_temp0';
  }

  @override
  String get wrappedOnScreenLabel => 'On your screen';

  @override
  String wrappedOnScreenBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You set or downloaded this wall $count times.',
      one: 'You set or downloaded this wall 1 time.',
    );
    return '$_temp0';
  }

  @override
  String get wrappedChallengesLabel => 'Weekly challenges';

  @override
  String wrappedChallengesBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You entered $count weekly challenges.',
      one: 'You entered 1 weekly challenge.',
    );
    return '$_temp0';
  }

  @override
  String get wrappedTipsLabel => 'Tips';

  @override
  String wrappedTipsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You sent $count tips to creators.',
      one: 'You sent 1 tip to a creator.',
    );
    return '$_temp0';
  }

  @override
  String wrappedSince(String date) {
    return 'Since $date';
  }

  @override
  String wrappedSummaryHeadline(String year) {
    return 'Your $year in Prism';
  }

  @override
  String get wrappedShare => 'Share';

  @override
  String get wrappedShareCard => 'Share this card';

  @override
  String get wrappedPause => 'Pause';

  @override
  String get wrappedPlay => 'Play';

  @override
  String get wrappedClose => 'Close';

  @override
  String get wrappedNextCard => 'Next card';

  @override
  String get wrappedPreviousCard => 'Previous card';

  @override
  String wrappedCardPosition(int index, int count) {
    return 'Card $index of $count';
  }

  @override
  String wrappedHomeTitle(String year) {
    return 'Your $year in Prism';
  }

  @override
  String get wrappedHomeSubtitle => 'Your year in walls is ready.';

  @override
  String get wrappedNotEligible => 'There is no Wrapped for this account this year.';

  @override
  String get wrappedLoadFailed => 'Unable to load your Wrapped. Check your connection and try again.';

  @override
  String notifPushWrappedReadyTitle(String year) {
    return 'Your $year in Prism is here';
  }

  @override
  String get notifPushWrappedReadyBody => 'See the walls you saved, your colours and your creators.';

  @override
  String get trialTimelineTitle => 'How your free trial works';

  @override
  String get trialTimelineClose => 'Close';

  @override
  String trialTimelinePlanSummary(int days, String price) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$daysString days', one: '1 day');
    return 'Prism Pro yearly. $_temp0 free, then $price a year.';
  }

  @override
  String get trialTimelineToday => 'Today';

  @override
  String get trialTimelineTodayBody => 'You get full access to Prism Pro. You pay nothing today.';

  @override
  String trialTimelineDay(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Day $dayString';
  }

  @override
  String get trialTimelineReminderBody => 'We remind you that your trial ends soon.';

  @override
  String get trialTimelineNoReminderBody => 'No reminder. You turned it off below.';

  @override
  String trialTimelineChargeBody(String price) {
    return 'You pay $price, unless you cancel at least 24 hours before.';
  }

  @override
  String get trialTimelineRemindToggle => 'Remind me 2 days before the trial ends';

  @override
  String trialTimelineRenewalTerms(String price, String store) {
    return 'After the trial, Prism Pro yearly renews at $price a year until you cancel. $store charges your account. To avoid a charge, cancel at least 24 hours before the trial or a renewal ends.';
  }

  @override
  String trialTimelineCancelLink(String store) {
    return 'Cancel any time in $store settings';
  }

  @override
  String get trialTimelineSeeAllPlans => 'See all plans';

  @override
  String trialTimelineStart(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Start $daysString-day free trial';
  }

  @override
  String get trialTimelineStartFailed => 'Could not start the free trial. Try again.';

  @override
  String trialReminderTitle(String date) {
    return 'Your free trial ends on $date';
  }

  @override
  String trialReminderBody(String store) {
    return 'After that, you pay for Prism Pro yearly. To avoid the charge, cancel in $store settings at least 24 hours before.';
  }

  @override
  String get notifChannelSubscription => 'Subscription';

  @override
  String get notifChannelSubscriptionDescription => 'A reminder before your free trial ends';

  @override
  String premiumTrialEnds(String date) {
    return 'Trial, ends $date';
  }

  @override
  String get premiumTrialAutoRenewOff => 'Auto-renew is off. You will not be charged when the trial ends.';

  @override
  String get editorsChoiceTitle => 'Editors\' Choice';

  @override
  String get editorsChoiceRowBody => 'Wallpapers our editors love.';

  @override
  String get editorsChoiceEmptyTitle => 'No picks yet';

  @override
  String get editorsChoiceEmptyBody => 'Check back soon for new picks.';

  @override
  String get editorsChoiceLoadError => 'Couldn\'t load Editors\' Choice';

  @override
  String get editorsChoiceLabelSemantics => 'Picked for Editors\' Choice';

  @override
  String get editorsChoicePick => 'Add to Editors\' Choice';

  @override
  String get editorsChoiceUnpick => 'Remove from Editors\' Choice';

  @override
  String get editorsChoicePicked => 'Added to Editors\' Choice';

  @override
  String get editorsChoiceUnpicked => 'Removed from Editors\' Choice';

  @override
  String get editorsChoiceNotEligible => 'Only approved free wallpapers with a ready original can be picks.';

  @override
  String get adminApproveAndPick => 'Approve and pick';

  @override
  String get adminApprovedPickLater => 'Approved. Add it to Editors\' Choice from its page once its original is ready.';

  @override
  String wallCreditBy(String name) {
    return 'By $name';
  }

  @override
  String wallCreditPhotoBy(String name) {
    return 'Photo by $name';
  }

  @override
  String get wallCreditByHashStudios => 'By Hash Studios';

  @override
  String get wallCreditPrismExclusive => 'Prism exclusive';

  @override
  String get wallCreditOnPexels => 'From Pexels';

  @override
  String get wallCreditOnWallhaven => 'From Wallhaven';

  @override
  String get wallCreditOpenProfileHint => 'Opens the profile';

  @override
  String get wallCreditOpenSourceHint => 'Opens in your browser';

  @override
  String get profileProBadge => 'Pro';

  @override
  String get profileProBadgeSemantics => 'Prism Pro member';

  @override
  String get settingsShowProBadgeTitle => 'Show Pro badge on my profile';

  @override
  String get settingsShowProBadgeBody => 'People who visit your profile see a Pro badge.';

  @override
  String get notifPushEditorsChoiceTitle => 'Your wallpaper is an Editors\' Choice';

  @override
  String notifPushEditorsChoiceBody(String wallTitle) {
    return 'Our editors picked $wallTitle. Everyone can find it on Home.';
  }

  @override
  String get notifPushEditorsChoiceBodyUntitled => 'Our editors picked your wallpaper. Everyone can find it on Home.';

  @override
  String get coreContentReportComment => 'comment';

  @override
  String get coreContentReportWhyFolder => 'Why are you reporting this folder?';

  @override
  String get commentsAction => 'Comments';

  @override
  String commentsCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
      zero: 'No comments',
    );
    return '$_temp0';
  }

  @override
  String get commentsTitle => 'Comments';

  @override
  String get commentsEmptyTitle => 'No comments yet';

  @override
  String get commentsEmptyBody => 'Tell the creator what you like about this wall.';

  @override
  String get commentsLoadFailed => 'Unable to load comments. Check your connection and try again.';

  @override
  String get commentsRetry => 'Try again';

  @override
  String get commentComposerHint => 'Add a comment';

  @override
  String get commentSend => 'Send';

  @override
  String commentCharactersLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters left',
      one: '1 character left',
    );
    return '$_temp0';
  }

  @override
  String commentCharactersOver(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters too many',
      one: '1 character too many',
    );
    return '$_temp0';
  }

  @override
  String get commentSignInToComment => 'Sign in to comment';

  @override
  String get commentCreatorLabel => 'Creator';

  @override
  String get commentAuthorFallback => 'Prism user';

  @override
  String get commentOptionsHint => 'show comment options';

  @override
  String get commentReport => 'Report comment';

  @override
  String commentBlockUser(String name) {
    return 'Block $name';
  }

  @override
  String get commentDelete => 'Delete comment';

  @override
  String get commentDeleteConfirmTitle => 'Delete this comment?';

  @override
  String get commentDeleteConfirmBody => 'It is removed for everyone. You can\'t undo this.';

  @override
  String get commentDeleted => 'Comment deleted';

  @override
  String get commentDeleteFailed => 'Unable to delete the comment. Try again.';

  @override
  String get commentPostFailed => 'Unable to post your comment. Check your connection and try again.';

  @override
  String get commentErrorDisabled => 'Comments are paused right now. Try again later.';

  @override
  String get commentErrorGuest => 'Sign in with a verified account to comment.';

  @override
  String get commentErrorTooNew => 'You can comment 24 hours after you join Prism.';

  @override
  String get commentErrorWallUnavailable => 'This wall isn\'t open for comments right now.';

  @override
  String get commentErrorEmpty => 'Write a comment before you send it.';

  @override
  String get commentErrorTooLong => 'Use 500 characters or fewer.';

  @override
  String get commentErrorHiddenCharacters => 'Remove the hidden or special characters, then send again.';

  @override
  String get commentErrorBlockedWord => 'Reword your comment to keep it friendly, then send again.';

  @override
  String get commentErrorBlocked => 'You can\'t comment on this wall.';

  @override
  String get commentErrorTooFast => 'Wait a few seconds before your next comment.';

  @override
  String get commentErrorDailyLimit => 'You can post 50 comments a day. Try again tomorrow.';

  @override
  String notifPushWallCommentedTitle(String name, String wallTitle) {
    return '$name commented on $wallTitle';
  }

  @override
  String notifPushWallCommentedTitleUntitled(String name) {
    return '$name commented on your wall';
  }

  @override
  String get adminCommentReport => 'Comment report';

  @override
  String get adminKeepComment => 'Keep comment';

  @override
  String get adminCommentKept => 'Report dismissed. The comment is visible.';

  @override
  String get adminCommentRemoved => 'Comment removed';

  @override
  String get adminCommentGone => 'This comment is already gone.';

  @override
  String get adminContentTypeComment => 'Comment';

  @override
  String get livePhotoAction => 'Live Photo';

  @override
  String get livePhotoActionTooltip => 'Save as a Live Photo';

  @override
  String get livePhotoTitle => 'Live Photo';

  @override
  String get livePhotoBody =>
      'Pick how the wall moves. Prism saves a 3-second Live Photo to Photos, ready for your Lock Screen.';

  @override
  String get livePhotoStyleGroup => 'Motion style';

  @override
  String livePhotoPreview(String style) {
    return 'Preview: $style';
  }

  @override
  String livePhotoStyleLocked(String style) {
    return '$style, Pro style';
  }

  @override
  String get livePhotoSave => 'Save Live Photo';

  @override
  String get livePhotoRendering => 'Making your Live Photo';

  @override
  String livePhotoProgress(String percent) {
    return '$percent done';
  }

  @override
  String get livePhotoSaving => 'Saving to Photos';

  @override
  String get livePhotoCancelling => 'Stopping';

  @override
  String get livePhotoRefusedTitle => 'Prism can\'t add to Photos';

  @override
  String get livePhotoRefusedBody =>
      'To save a Live Photo, allow Prism to add photos. In Settings, tap Photos, then Add Photos Only.';

  @override
  String get livePhotoRestrictedBody =>
      'Photos access is blocked on this iPhone, for example by Screen Time. Check Settings, or ask the person who manages this iPhone.';

  @override
  String get livePhotoNotNow => 'Not now';

  @override
  String get livePhotoFailedTitle => 'Unable to make the Live Photo';

  @override
  String get livePhotoFailedSource => 'Unable to load this wall. Check your connection and try again.';

  @override
  String get livePhotoFailedTimeout => 'This took too long. Try again, or pick another style.';

  @override
  String get livePhotoFailedSave => 'Photos did not save the Live Photo. Try again.';

  @override
  String get livePhotoFailedGeneric => 'Unable to render the Live Photo. Try again.';

  @override
  String get livePhotoTryAgain => 'Try again';

  @override
  String get livePhotoGuideTitle => 'Set it as your Lock Screen';

  @override
  String get livePhotoGuideBody =>
      'Your Live Photo is in Photos. iOS does not let apps change your wallpaper, so finish there:';

  @override
  String get livePhotoGuideStep1 => 'Open Photos. The new photo has a LIVE badge.';

  @override
  String get livePhotoGuideStep2 => 'Tap Share, then Use as Wallpaper.';

  @override
  String get livePhotoGuideStep3 => 'Make sure the Live Photo button at the bottom is on, then tap Add.';

  @override
  String get livePhotoGuideNotesTitle => 'Good to know';

  @override
  String get livePhotoGuideNoteWake =>
      'Motion plays on the Lock Screen when you wake your iPhone. The Home Screen shows the still photo.';

  @override
  String get livePhotoGuideNoteLowPower => 'Low Power Mode turns off Lock Screen motion.';

  @override
  String get livePhotoGuideNoteNotAvailable =>
      'If iOS says Motion not available, use it as a still wallpaper or try another style.';

  @override
  String get livePhotoGuideNoteVersion => 'Lock Screen motion needs iOS 17 or later.';

  @override
  String get watchSetCropPreset => 'Watch';

  @override
  String get watchSetRowTitle => 'Watch set';

  @override
  String get watchSetRowSubtitle => 'Phone and watch, one save';

  @override
  String get watchSetRowSubtitleDesktop => 'Phone, watch and desktop, one save';

  @override
  String get watchSetSheetTitle => 'Watch set';

  @override
  String get watchSetSheetMessage => 'Save this wall for your phone and a crop that fits your watch.';

  @override
  String get watchSetSheetMessageDesktop =>
      'Save this wall for your phone, a crop that fits your watch, and the desktop version.';

  @override
  String get watchSetItemPhone => 'Phone';

  @override
  String get watchSetItemWatch => 'Watch';

  @override
  String get watchSetItemDesktop => 'Desktop';

  @override
  String get watchSetItemFullSize => 'Full size';

  @override
  String get watchSetPhonePreviewSemantic => 'Phone wallpaper preview';

  @override
  String watchSetWatchPreviewSemantic(String watch) {
    return 'Watch image preview for $watch';
  }

  @override
  String get watchSetDesktopPreviewSemantic => 'Desktop version preview';

  @override
  String get watchSetSave => 'Save set';

  @override
  String get watchSetAdjustCrop => 'Adjust watch crop';

  @override
  String get watchSetChangeWatch => 'Change watch';

  @override
  String get watchSetHowTo => 'How to use it on your watch';

  @override
  String get watchSetSaved => 'Watch set saved';

  @override
  String get watchSetDesktopNotSaved =>
      'Phone and watch images saved. The desktop version did not save. Try again in a few minutes.';

  @override
  String get watchSetPreviewFailed => 'Could not load the wall. Check your connection and try again.';

  @override
  String get watchSetPickerTitle => 'Which watch do you have?';

  @override
  String get watchSetPickerMessage => 'Prism saves the watch image at your screen size. You can change it later.';

  @override
  String get watchSetPlatformApple => 'Apple Watch';

  @override
  String get watchSetPlatformWearOs => 'Wear OS';

  @override
  String get watchSetPickerHintApple =>
      'To find your model, open the Watch app on your iPhone, then tap General, then About.';

  @override
  String get watchSetPickerHintWearOs =>
      'To find your model, open Settings on your watch, then tap System, then About.';

  @override
  String get watchFormatApple40 => 'Series 4 to 6 and SE, 40 mm';

  @override
  String get watchFormatApple44 => 'Series 4 to 6 and SE, 44 mm';

  @override
  String get watchFormatApple41 => 'Series 7 to 9, 41 mm';

  @override
  String get watchFormatApple45 => 'Series 7 to 9, 45 mm';

  @override
  String get watchFormatApple42 => 'Series 10 to 12, 42 mm';

  @override
  String get watchFormatApple46 => 'Series 10 to 12, 46 mm';

  @override
  String get watchFormatAppleUltra => 'Ultra and Ultra 2';

  @override
  String get watchFormatAppleUltra3 => 'Ultra 3 and Ultra 4';

  @override
  String get watchFormatPixelWatch => 'Pixel Watch';

  @override
  String get watchFormatGalaxySmall => 'Galaxy Watch, 40 mm or Classic';

  @override
  String get watchFormatGalaxyLarge => 'Galaxy Watch, 44 mm or Ultra';

  @override
  String get watchCropTitle => 'Watch crop';

  @override
  String get watchCropHint => 'Drag to move the frame. Pinch or drag a corner to resize it.';

  @override
  String get watchCropReset => 'Reset';

  @override
  String get watchCropDone => 'Use this crop';

  @override
  String get watchGuideTitle => 'Put it on your watch';

  @override
  String get watchGuideBodyIos => 'The set is in Photos, in Recents. Make a Photos watch face from the watch image.';

  @override
  String get watchGuideBodyAndroid =>
      'The set is in Gallery, in Pictures, Prism, Downloads. Add the watch image to a photo watch face.';

  @override
  String get watchGuideShare => 'Share watch image';

  @override
  String get watchGuideIosStep1 => 'Open Photos and tap the watch image.';

  @override
  String get watchGuideIosStep2 => 'Tap Share, swipe up, then tap Create Watch Face.';

  @override
  String get watchGuideIosStep3 => 'Tap Photos Watch Face, then tap Add.';

  @override
  String get watchGuideIosAlternative =>
      'You can also open the Watch app on your iPhone. Tap Face Gallery, tap Photos, then tap Choose Photos.';

  @override
  String get watchGuidePixelTitle => 'Pixel Watch';

  @override
  String get watchGuidePixelStep1 => 'Open the Pixel Watch app. Tap Watch faces, then tap Add new.';

  @override
  String get watchGuidePixelStep2 => 'Tap Photos, then pick the watch image in Google Photos.';

  @override
  String get watchGuidePixelStep3 => 'Tap Add, then tap Save.';

  @override
  String get watchGuideGalaxyTitle => 'Galaxy Watch';

  @override
  String get watchGuideGalaxyStep1 => 'Open the Galaxy Wearable app and tap Watch faces.';

  @override
  String get watchGuideGalaxyStep2 => 'Tap My Photo+, then tap Customize.';

  @override
  String get watchGuideGalaxyStep3 => 'Pick the watch image from Gallery, then tap Save.';

  @override
  String get watchGuideNotesTitle => 'What Prism can\'t do';

  @override
  String get watchGuideNoteNoTransfer => 'Prism can\'t put the image on your watch. Your watch app does that.';

  @override
  String get watchGuideNoteShareSheet =>
      'Create Watch Face is only in the Photos app. Prism can\'t add it to its own share sheet.';

  @override
  String get watchGuideNoteAlbum =>
      'Prism saves to Recents, not to a Prism album. An album needs full access to your photos, and Prism only asks to add photos.';

  @override
  String get watchGuideNoteLayout => 'Each watch face has its own clock and layout, so it can cover part of the image.';

  @override
  String get watchGuideNoteGooglePhotos =>
      'Pixel Watch reads Google Photos. If the image doesn\'t show, back it up to Google Photos first.';

  @override
  String get searchByPhoto => 'Search by photo';

  @override
  String get searchPhotoPrivacy =>
      'Prism reads the photo\'s colours on your phone. To find what\'s in the photo, a small copy goes to Google Cloud Vision. It isn\'t stored.';

  @override
  String get searchPhotoChoose => 'Choose photo';

  @override
  String get searchPhotoChipLabel => 'Your photo';

  @override
  String get searchPhotoClear => 'Clear';

  @override
  String get searchPhotoClearTooltip => 'Clear photo';

  @override
  String searchPhotoMatchesFor(String labels) {
    return 'Matches for $labels';
  }

  @override
  String get searchPhotoColourMatches => 'Matches by colour';

  @override
  String searchPhotoMainColours(String colours) {
    return 'Main colours: $colours';
  }

  @override
  String get searchPhotoSentNote => 'A small copy went to Google Cloud Vision to find what\'s in it. It isn\'t stored.';

  @override
  String get searchPhotoGuestNote => 'Colour matches only. Sign in to match what\'s in the photo too.';

  @override
  String searchPhotoCappedNote(int count) {
    return 'You\'ve used today\'s $count photo searches. Matching by colour until tomorrow.';
  }

  @override
  String get searchPhotoUnavailableNote => 'Couldn\'t read what\'s in the photo. Matching by colour only.';

  @override
  String get searchPhotoNoMatches => 'No walls match this photo';

  @override
  String get searchPhotoNoMatchesBody => 'Try a photo with bolder colours.';

  @override
  String get searchPhotoChooseAnother => 'Choose another photo';

  @override
  String get searchPhotoCouldNotOpen => 'Couldn\'t open that photo. Try another one.';

  @override
  String get searchMoreWallpapers => 'More wallpapers';

  @override
  String get wallpaperPreviewNoEvents => 'No events today';

  @override
  String accountFollowersLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Followers', one: 'Follower');
    return '$_temp0';
  }

  @override
  String profileBadgeCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString badges', one: '1 badge');
    return '$_temp0';
  }

  @override
  String get economyLeaderboardTopThisWeek => 'Top this week';

  @override
  String get foldersSaveAll => 'Save all';

  @override
  String get foldersSaveAllTitle => 'Save all wallpapers';

  @override
  String get foldersSaveAllChecking => 'Checking the wallpapers…';

  @override
  String get foldersSaveAllPlanFailed => 'Could not check the wallpapers. Try again.';

  @override
  String get foldersSaveAllBusy => 'Another folder is saving. Try again when it ends.';

  @override
  String foldersSaveAllRowFree(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers are free',
      one: '1 wallpaper is free',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllRowCoins(int count, int price) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers cost $priceString coins each',
      one: '1 wallpaper costs $priceString coins',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllRowPro(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers need Pro',
      one: '1 wallpaper needs Pro',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllRowSaved(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers are already in Downloads',
      one: '1 wallpaper is already in Downloads',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllRowBlocked(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers are not available to save',
      one: '1 wallpaper is not available to save',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllAffordable(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your coins cover $countString paid wallpapers.',
      one: 'Your coins cover 1 paid wallpaper.',
      zero: 'You do not have enough coins for a paid wallpaper.',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllPhotosAlbum(String name) {
    return 'They go to the “$name” album in Photos and to Downloads.';
  }

  @override
  String foldersSaveAllGalleryAlbum(String name) {
    return 'They go to Pictures/Prism/$name in your gallery and to Downloads.';
  }

  @override
  String get foldersSaveAllLeaveNote =>
      'You can leave this page while it saves. If you close Prism, tap Save all again to finish.';

  @override
  String get foldersSaveAllNothing => 'There is nothing new to save in this folder.';

  @override
  String foldersSaveAllFreeButton(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save the $countString free wallpapers',
      one: 'Save the free wallpaper',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllPaidButton(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Save all I can ($coinsString coins)',
      one: 'Save all I can (1 coin)',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllCountButton(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save $countString wallpapers',
      one: 'Save 1 wallpaper',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Saving $doneString of $totalString';
  }

  @override
  String foldersSaveAllProgressSemantics(int total, int done) {
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String doneString = doneNumberFormat.format(done);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Saving $doneString of $totalString wallpapers',
      one: 'Saving $doneString of 1 wallpaper',
    );
    return '$_temp0';
  }

  @override
  String get foldersSaveAllStopping => 'Stopping…';

  @override
  String get foldersSaveAllCancel => 'Cancel';

  @override
  String get foldersSaveAllCancelHint => 'Stops the wallpapers that have not started. They cost nothing.';

  @override
  String foldersSaveAllSavedTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpapers saved',
      one: '1 wallpaper saved',
      zero: 'No wallpapers saved',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllStoppedTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Stopped. $countString wallpapers saved',
      one: 'Stopped. 1 wallpaper saved',
      zero: 'Stopped. No wallpapers saved',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllSkipped(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString already in Downloads',
      one: '1 already in Downloads',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllFailed(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString failed', one: '1 failed');
    return '$_temp0';
  }

  @override
  String foldersSaveAllNotStarted(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString not started',
      one: '1 not started',
    );
    return '$_temp0';
  }

  @override
  String get foldersSaveAllRetry => 'Retry failed';

  @override
  String get foldersSaveAllDone => 'Done';

  @override
  String foldersSaveAllToast(int count, String name) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $countString wallpapers from $name.',
      one: 'Saved 1 wallpaper from $name.',
      zero: 'No wallpapers saved from $name.',
    );
    return '$_temp0';
  }

  @override
  String foldersSaveAllToastFailed(int failed, int saved, String name) {
    final intl.NumberFormat failedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String failedString = failedNumberFormat.format(failed);
    final intl.NumberFormat savedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String savedString = savedNumberFormat.format(saved);

    String _temp0 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: 'Saved $savedString from $name. $failedString failed. Open the folder to retry.',
      one: 'Saved $savedString from $name. 1 failed. Open the folder to retry.',
    );
    return '$_temp0';
  }

  @override
  String get foldersInvite => 'Invite';

  @override
  String foldersInviteShareText(String name, String link) {
    return 'Add wallpapers with me in $name on Prism: $link';
  }

  @override
  String foldersInvitePreviewTitle(String name) {
    return 'Join $name on Prism';
  }

  @override
  String get foldersInvitePreviewDescription => 'Add and remove wallpapers in this folder together.';

  @override
  String get foldersInviteFailed => 'Could not make an invite link. Try again.';

  @override
  String get foldersInviteFull => 'This folder is full. Remove someone to invite more people.';

  @override
  String get foldersInviteLimit => 'You made too many invites today. Try again tomorrow.';

  @override
  String get foldersPeople => 'People';

  @override
  String foldersPeopleHintOwner(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Invite up to $countString people to add and remove wallpapers. Only you can rename, share or delete this folder.';
  }

  @override
  String get foldersPeopleHintEditor =>
      'You can add and remove wallpapers. Only the owner can rename, share or delete this folder.';

  @override
  String foldersPeopleCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString people', one: '1 person');
    return '$_temp0';
  }

  @override
  String foldersPeopleButtonLabel(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString people in this folder. Show people',
      one: '1 person in this folder. Show people',
    );
    return '$_temp0';
  }

  @override
  String get foldersRoleOwner => 'Owner';

  @override
  String get foldersRoleEditor => 'Can add and remove';

  @override
  String foldersPersonYou(String name) {
    return '$name (you)';
  }

  @override
  String get foldersUnknownPerson => 'Prism user';

  @override
  String get foldersRemovePerson => 'Remove';

  @override
  String foldersRemovePersonTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get foldersRemovePersonMessage =>
      'They can no longer add or remove wallpapers here. The wallpapers they added stay.';

  @override
  String get foldersRemovePersonConfirm => 'Remove person';

  @override
  String foldersPersonRemoved(String name) {
    return 'Removed $name.';
  }

  @override
  String get foldersLeave => 'Leave folder';

  @override
  String foldersLeaveTitle(String name) {
    return 'Leave $name?';
  }

  @override
  String get foldersLeaveMessage => 'You can no longer add or remove wallpapers here. The wallpapers you added stay.';

  @override
  String get foldersLeft => 'You left the folder.';

  @override
  String get foldersPeopleFailed => 'Could not update the people in this folder. Try again.';

  @override
  String get foldersSharedWithYou => 'Shared with you';

  @override
  String get foldersSharedLabel => 'Shared';

  @override
  String foldersAddedBy(String name) {
    return 'Added by $name';
  }

  @override
  String get foldersAddedByYou => 'Added by you';

  @override
  String get foldersRemoveFromFolder => 'Remove from folder';

  @override
  String get foldersDeleteSharedMessage =>
      'The people you invited lose it too. Wallpapers that are in your favourites stay there.';

  @override
  String get foldersJoinTitle => 'Folder invite';

  @override
  String foldersJoinHeadline(String name) {
    return 'Join $name';
  }

  @override
  String foldersJoinInvitedBy(String name) {
    return '$name invited you to add and remove wallpapers in this folder.';
  }

  @override
  String get foldersJoin => 'Join folder';

  @override
  String get foldersJoinSignIn => 'Sign in to join';

  @override
  String get foldersJoinOpen => 'Open folder';

  @override
  String get foldersJoinAlreadyIn => 'You are already in this folder.';

  @override
  String foldersJoined(String name) {
    return 'You joined $name.';
  }

  @override
  String get foldersJoinFailed => 'Could not join this folder. Try again.';

  @override
  String get foldersJoinLoadFailed => 'Could not load this invite.';

  @override
  String get foldersJoinExpiredTitle => 'This invite expired';

  @override
  String get foldersJoinExpiredBody => 'Invites work for 7 days. Ask the owner for a new link.';

  @override
  String get foldersJoinUsedTitle => 'This invite was already used';

  @override
  String get foldersJoinUsedBody => 'Each invite works once. Ask the owner for a new link.';

  @override
  String get foldersJoinFullTitle => 'This folder is full';

  @override
  String get foldersJoinFullBody => 'Ask the owner to remove someone, then open the link again.';

  @override
  String get foldersJoinUnavailableTitle => 'This invite is not available';

  @override
  String get foldersJoinUnavailableBody => 'The folder may have been deleted, or you cannot join it.';

  @override
  String get foldersMakePrivateMessageShared =>
      'Only you and the people you invited will see it. Its link stops working and its followers lose it.';

  @override
  String get gestureHintHoldToSave => 'Hold to save';

  @override
  String get gestureHintSwipeForSimilar => 'Swipe up for similar walls';

  @override
  String get foldersSectionAdd => 'Add section';

  @override
  String get foldersSectionNewTitle => 'New section';

  @override
  String get foldersSectionNameHint => 'For example, Lock screens';

  @override
  String get foldersSectionRenameTitle => 'Rename section';

  @override
  String get foldersSectionDelete => 'Delete section';

  @override
  String foldersSectionDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String foldersSectionDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count wallpapers move to Unsorted.',
      one: 'Its wallpaper moves to Unsorted.',
      zero: 'The section is empty.',
    );
    return '$_temp0';
  }

  @override
  String get foldersSectionUnsorted => 'Unsorted';

  @override
  String get foldersSectionReorder => 'Reorder sections';

  @override
  String foldersSectionDragHandle(String name) {
    return 'Drag to move $name';
  }

  @override
  String foldersSectionWallCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wallpapers',
      one: '1 wallpaper',
      zero: 'No wallpapers',
    );
    return '$_temp0';
  }

  @override
  String foldersSectionHeaderLabel(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wallpapers',
      one: '1 wallpaper',
      zero: 'no wallpapers',
    );
    return '$name, $_temp0';
  }

  @override
  String foldersSectionJumpTo(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wallpapers',
      one: '1 wallpaper',
      zero: 'no wallpapers',
    );
    return 'Go to $name, $_temp0';
  }

  @override
  String foldersSectionOptions(String name) {
    return 'More options for $name';
  }

  @override
  String get foldersSectionSaveAll => 'Save section';

  @override
  String get foldersSectionMoveTo => 'Move to section';

  @override
  String get foldersSectionMoveTitle => 'Move to';

  @override
  String foldersSectionMoved(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moved $count wallpapers to $name.',
      one: 'Moved 1 wallpaper to $name.',
    );
    return '$_temp0';
  }

  @override
  String get foldersSectionSelect => 'Select wallpapers';

  @override
  String foldersSectionSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
      zero: 'Tap wallpapers to select them',
    );
    return '$_temp0';
  }

  @override
  String foldersSectionsFull(int max) {
    return 'A folder can have up to $max sections.';
  }

  @override
  String get foldersSectionEmpty => 'No wallpapers yet.';

  @override
  String get foldersSectionEmptyHint => 'Drag wallpapers onto the section name, or use Move to section.';

  @override
  String get foldersSectionSuggest => 'Suggest sections';

  @override
  String get foldersSuggestTitle => 'Suggested sections';

  @override
  String get foldersSuggestBody => 'Groups of your Unsorted wallpapers. Keep the ones you want.';

  @override
  String get foldersSuggestByMood => 'Mood';

  @override
  String get foldersSuggestByCategory => 'Category';

  @override
  String get foldersSuggestByColour => 'Colour';

  @override
  String foldersSuggestJoins(String count) {
    return '$count. Goes into your section with this name.';
  }

  @override
  String foldersSuggestAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count sections',
      one: 'Add 1 section',
      zero: 'Add sections',
    );
    return '$_temp0';
  }

  @override
  String foldersSuggestSort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sort $count wallpapers',
      one: 'Sort 1 wallpaper',
    );
    return '$_temp0';
  }

  @override
  String foldersSuggestSorted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sorted $count wallpapers.',
      one: 'Sorted 1 wallpaper.',
    );
    return '$_temp0';
  }

  @override
  String get foldersSuggestEmptyTitle => 'No groups to suggest';

  @override
  String get foldersSuggestEmptyBody =>
      'A group needs 2 or more Prism wallpapers in Unsorted with the same mood, category or colour.';

  @override
  String get foldersSuggestError => 'Could not load suggestions';

  @override
  String get photoWallEntryTitle => 'From your photo';

  @override
  String get photoWallEntrySubtitle => 'Fit a photo to your screen, or restyle it';

  @override
  String get photoWallPickPhoto => 'Choose a photo';

  @override
  String get photoWallPickAnother => 'Choose another photo';

  @override
  String get photoWallPrivacyNote =>
      'Your photo goes to our AI provider, fal.ai, and to Google Cloud Vision for this job only. Prism keeps the finished wallpaper, not your photo, and asks fal.ai to delete the photo after the job.';

  @override
  String get photoWallTargetLabel => 'Make it for';

  @override
  String get photoWallTargetPhone => 'Phone';

  @override
  String get photoWallTargetDesktop => 'Desktop version';

  @override
  String get photoWallPlanExtend => 'Extend to fit your screen';

  @override
  String get photoWallPlanExtendDesktop => 'Extend to fit a desktop screen';

  @override
  String get photoWallPlanExtendDetail => 'AI fills in the missing edges around your photo.';

  @override
  String get photoWallPlanUpscale => 'Upscale';

  @override
  String get photoWallPlanUpscaleDetail => 'AI adds detail so the photo stays sharp on your screen.';

  @override
  String get photoWallPlanFits => 'This photo already fits your screen';

  @override
  String get photoWallPlanFitsDesktop => 'This photo already fits a desktop screen';

  @override
  String get photoWallPlanFitsDetail => 'It has the right shape and size. Choose another photo or switch the target.';

  @override
  String photoWallRunExtend(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Extend · $coins coins',
      one: 'Extend · 1 coin',
    );
    return '$_temp0';
  }

  @override
  String photoWallRunUpscale(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Upscale · $coins coins',
      one: 'Upscale · 1 coin',
    );
    return '$_temp0';
  }

  @override
  String get photoWallToolFit => 'Fit to screen';

  @override
  String get photoWallToolRestyle => 'Restyle';

  @override
  String get photoWallStyleTitle => 'Style';

  @override
  String photoWallPlanRestyle(String style) {
    return 'Restyle as $style';
  }

  @override
  String get photoWallPlanRestyleDetail => 'AI redraws your photo in this style. It keeps the layout and the faces.';

  @override
  String photoWallRunRestyle(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Restyle · $coins coins',
      one: 'Restyle · 1 coin',
    );
    return '$_temp0';
  }

  @override
  String get photoWallWorkingRestyle => 'Restyling your photo';

  @override
  String photoWallGetCoins(int coins) {
    return 'Get coins · need $coins';
  }

  @override
  String get photoWallPlaceTitle => 'Place your photo';

  @override
  String get photoWallPlaceHint => 'Drag to move. Pinch to make it smaller.';

  @override
  String get photoWallPlaceReset => 'Reset position';

  @override
  String get photoWallPlaceSemantics => 'Photo position in the frame';

  @override
  String get photoWallPlaceMoveStart => 'Move to start';

  @override
  String get photoWallPlaceMoveCentre => 'Move to centre';

  @override
  String get photoWallPlaceMoveEnd => 'Move to end';

  @override
  String get photoWallWorkingExtend => 'Extending your photo';

  @override
  String get photoWallWorkingUpscale => 'Upscaling your photo';

  @override
  String get photoWallWorkingDetail => 'This usually takes under a minute.';

  @override
  String get photoWallBefore => 'Before';

  @override
  String get photoWallAfter => 'After';

  @override
  String get photoWallCompareSemantics => 'Before and after. Swipe up or down to compare.';

  @override
  String get photoWallSet => 'Set as wallpaper';

  @override
  String get photoWallDownload => 'Download';

  @override
  String get photoWallSaved => 'Saved to your device';

  @override
  String get photoWallStartOver => 'Use another photo';

  @override
  String get photoWallErrorUnsafeInput => 'This photo can\'t be used. Choose another photo.';

  @override
  String get photoWallErrorUnsafeOutput => 'The result was blocked. Try again or choose another photo.';

  @override
  String photoWallErrorLimit(int count) {
    return 'You reached today\'s limit of $count photo wallpapers.';
  }

  @override
  String get photoWallErrorBusy => 'Photo wallpapers are very busy right now. Try again later.';

  @override
  String get photoWallErrorUnreadable => 'This photo can\'t be opened. Choose another photo.';

  @override
  String get photoWallErrorInProgress => 'Still working on your last photo.';

  @override
  String get photoWallErrorGeneric => 'Couldn\'t make the wallpaper. Try again.';

  @override
  String photoWallRefunded(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Your $coins coins were returned.',
      one: 'Your coin was returned.',
    );
    return '$_temp0';
  }

  @override
  String get photoWallRefundPending => 'Your coins will be returned.';

  @override
  String get photoWallTryAgain => 'Try again';

  @override
  String get shareInImageTitle => 'Use this image';

  @override
  String get shareInSet => 'Set as wallpaper';

  @override
  String get shareInSetDetail => 'Crop it, then set it on your screen.';

  @override
  String shareInFit(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Make it fit · $coins coins',
      one: 'Make it fit · 1 coin',
    );
    return '$_temp0';
  }

  @override
  String get shareInFitTitle => 'Make it fit';

  @override
  String get shareInFitDetail => 'AI extends or sharpens it to fit your screen.';

  @override
  String get shareInFitNotNeeded => 'Already fits your screen';

  @override
  String get shareInUpload => 'Upload to Prism';

  @override
  String get shareInUploadDetail => 'Others can see it after a review.';

  @override
  String get shareInSignInDetail => 'Sign in to use this.';

  @override
  String get shareInLooking => 'Finding the image in this link';

  @override
  String get shareInLinkUnusable => 'Prism cannot use this link.';

  @override
  String get shareInLinkUnusableDetail => 'Share an image, or a link to a page with an image.';

  @override
  String get shareInImageUnreadable => 'Prism cannot open this image.';

  @override
  String get shareInImageUnreadableDetail => 'Share it again, or share a different image.';

  @override
  String get shareInPreviewSemantics => 'Shared image';

  @override
  String get hintGotIt => 'Got it';

  @override
  String get hintFolderHold => 'Hold the heart to save this wallpaper to a folder.';

  @override
  String get hintVariantDots => 'Tap a dot to see this wallpaper in another colour.';

  @override
  String get hintPhotoSearch => 'Find wallpapers that match a photo from your gallery.';

  @override
  String get hintFollowCategory => 'Follow this category to see when it gets new wallpapers.';

  @override
  String get hintSmartFolders => 'A smart folder fills itself with wallpapers that match your rules.';

  @override
  String get hintFolderSections => 'Open More options, then Suggest sections, to sort this folder.';

  @override
  String get hintPhotoFit => 'Turn your own photo into a wallpaper that fits your screen.';

  @override
  String get hintLivePhoto => 'Save this wallpaper as a Live Photo for a moving Lock Screen.';

  @override
  String get settingsShowTipsTitle => 'Show tips';

  @override
  String get settingsShowTipsBody => 'Short hints about features you have not used yet.';

  @override
  String get settingsResetTipsTitle => 'Reset tips';

  @override
  String get settingsResetTipsBody => 'Show every tip again.';

  @override
  String get settingsResetTipsDone => 'Tips will show again.';

  @override
  String get readabilityClockChip => 'Clock may be hard to read';

  @override
  String get readabilityIconsChip => 'Icons may be hard to read';

  @override
  String get readabilityChipHint => 'Shows a before and after preview';

  @override
  String get readabilityClockBody =>
      'The clock may be hard to read on this wallpaper. The original wallpaper stays as it is.';

  @override
  String get readabilityIconsBody =>
      'Icons may be hard to read on this wallpaper. The original wallpaper stays as it is.';

  @override
  String get readabilityDimClockTitle => 'Dim behind the clock?';

  @override
  String get readabilityBlurClockTitle => 'Soften behind the clock?';

  @override
  String get readabilityDimIconsTitle => 'Dim behind the icons?';

  @override
  String get readabilityBlurIconsTitle => 'Soften behind the icons?';

  @override
  String get readabilityBefore => 'Before';

  @override
  String get readabilityAfter => 'After';

  @override
  String get readabilityBeforeSemantic => 'Wallpaper without the fix';

  @override
  String get readabilityAfterSemantic => 'Wallpaper with the fix';

  @override
  String get readabilityApply => 'Apply';

  @override
  String get readabilityKeep => 'Keep as is';

  @override
  String get readabilityApplyFailed => 'Couldn\'t apply the fix. Try again.';

  @override
  String get settingsReadabilityTipsTitle => 'Readability tips';

  @override
  String get settingsReadabilityTipsBody => 'Show a tip when the clock or icons may be hard to read on a wallpaper.';

  @override
  String get uploadKindPhoto => 'Photo';

  @override
  String get uploadKindPhotoBody => 'A still image';

  @override
  String get uploadKindLive => 'Live';

  @override
  String get uploadKindLiveBody => 'A looping video, up to 15 seconds';

  @override
  String get liveUploadChecking => 'Checking your video';

  @override
  String liveUploadFacts(String seconds, int width, int height) {
    return '$seconds s · $width × $height';
  }

  @override
  String get liveUploadErrorFormat => 'Use an MP4 video. Prism can\'t read this file.';

  @override
  String get liveUploadErrorCodec => 'This video isn\'t in H.264. Export it as H.264 MP4, then try again.';

  @override
  String get liveUploadErrorTooLong => 'This clip is longer than 15 seconds. Trim it, then try again.';

  @override
  String get liveUploadErrorTooLarge => 'This clip is larger than 20 MB. Use a shorter or smaller clip.';

  @override
  String get liveUploadErrorLandscape => 'Use a portrait clip that is taller than it is wide.';

  @override
  String get liveUploadErrorFrameSize => 'This clip is larger than 1440 × 3200 pixels. Use a smaller clip.';

  @override
  String get liveUploadErrorUnreadable => 'Prism couldn\'t read this video. Try another clip.';

  @override
  String get liveUploadPickAnother => 'Choose another video';

  @override
  String get coreLiveBadge => 'Live';

  @override
  String get coreLiveBadgeSemantic => 'Live wallpaper';

  @override
  String get liveWallPlay => 'Play video';

  @override
  String get liveWallPause => 'Pause video';

  @override
  String get liveWallSetLive => 'Set live wallpaper';

  @override
  String get liveWallPreparing => 'Getting the video';

  @override
  String get liveWallSetFailed => 'Couldn\'t set the live wallpaper. Try again.';

  @override
  String get liveWallIosTitle => 'Use this live wallpaper';

  @override
  String get liveWallIosBody =>
      'iPhone can\'t use a video as a wallpaper. Save the video, or set the poster as a still wallpaper.';

  @override
  String get liveWallSaveVideo => 'Save video';

  @override
  String get liveWallSaveVideoDone => 'Video saved to Photos.';

  @override
  String get liveWallSaveVideoFailed => 'Couldn\'t save the video. Allow Photos access in Settings, then try again.';

  @override
  String get liveWallSetPoster => 'Set poster as wallpaper';

  @override
  String get adminLiveChecking => 'Checking the video';

  @override
  String get adminLiveFailed => 'The video failed the server check';

  @override
  String adminLiveFacts(String seconds) {
    return 'Live · $seconds s';
  }

  @override
  String get searchFilterPrismSection => 'Prism walls';

  @override
  String get searchFilterPrismOnly => 'Prism walls only';

  @override
  String get searchFilterPrismOnlySubtitle => 'Hide Wallhaven and Pexels results';

  @override
  String get searchKindLive => 'Live';

  @override
  String get searchKindDesktop => 'Desktop version';

  @override
  String get searchKindLightDark => 'Light and dark';

  @override
  String get searchFilterClearAll => 'Clear all';

  @override
  String searchFiltersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Filters, $count on',
      one: 'Filters, 1 on',
      zero: 'Filters',
    );
    return '$_temp0';
  }

  @override
  String get searchKindsPrismOnlyNote =>
      'Only Prism walls have these kinds, so Wallhaven and Pexels results are hidden.';

  @override
  String searchRemoveFilter(String filter) {
    return 'Remove $filter';
  }

  @override
  String get discoverLiveWallsTitle => 'Live walls';

  @override
  String get discoverLiveWallsSubtitle => 'Looping videos from Prism creators';
}
