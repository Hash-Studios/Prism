// GENERATED CODE - DO NOT MODIFY BY HAND
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('hi'),
    Locale('id'),
    Locale('pt'),
    Locale('pt', 'BR'),
  ];

  /// Title of the empty Folders tab in the Library.
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get foldersLibraryEmptyTitle;

  /// Body of the empty Folders tab in the Library. It says how to save a wallpaper to a folder.
  ///
  /// In en, this message translates to:
  /// **'Hold the heart on a wallpaper to save it to a folder.'**
  String get foldersLibraryEmptyBody;

  /// Title shown when the Library cannot load the user's folders.
  ///
  /// In en, this message translates to:
  /// **'Could not load your folders'**
  String get foldersLoadAllError;

  /// No description provided for @galleryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'They were removed or are no longer public.'**
  String get galleryEmptyBody;

  /// No description provided for @galleryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'These walls are gone'**
  String get galleryEmptyTitle;

  /// No description provided for @galleryScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Walls for you'**
  String get galleryScreenTitle;

  /// Hold-menu action on a favourite wallpaper. Keeps it at the top of Favourites.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get favouritePin;

  /// Hold-menu action on a pinned favourite. Returns it to its normal place in Favourites.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get favouriteUnpin;

  /// Confirmation after the user pins a favourite.
  ///
  /// In en, this message translates to:
  /// **'Pinned to the top of Favourites'**
  String get favouritePinnedToast;

  /// Confirmation after the user unpins a favourite.
  ///
  /// In en, this message translates to:
  /// **'Unpinned'**
  String get favouriteUnpinnedToast;

  /// Accessibility label of the small pin badge on a pinned favourite tile.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get favouritePinnedBadge;

  /// Shown when the user tries to pin more favourites than the limit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{You can pin up to {count} favourites. Unpin one to pin this wallpaper.}}'**
  String favouritePinLimit(int count);

  /// Shown when pinning or unpinning a favourite fails.
  ///
  /// In en, this message translates to:
  /// **'Unable to update the pin. Check your connection and try again.'**
  String get favouritePinFailed;

  /// Hint in the favourites search field. It also tells how many favourites there are.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Search 1 favourite} other{Search {count} favourites}}'**
  String wallpaperFavouriteSearchCountHint(int count);

  /// Title of the favourites sort and filter sheet, and the tooltip of its button.
  ///
  /// In en, this message translates to:
  /// **'Sort and filter'**
  String get wallpaperFavouriteSortAndFilter;

  /// Heading above the sort choices in the favourites sort and filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get wallpaperFavouriteSortBy;

  /// Heading above the source filter chips in the favourites sort and filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get wallpaperFavouriteFilterSource;

  /// Tooltip and screen reader label of the button that sets a wallpaper from history again.
  ///
  /// In en, this message translates to:
  /// **'Set again'**
  String get wallpaperHistorySetAgain;

  /// Screen reader label of a wallpaper history tile. current is empty or the Current prefix, target is the screen, time is the time it was set.
  ///
  /// In en, this message translates to:
  /// **'{current}{target}, set at {time}'**
  String wallpaperHistoryTileLabel(String current, String target, String time);

  /// No description provided for @wallpaperProviderWallhaven.
  ///
  /// In en, this message translates to:
  /// **'Wallhaven'**
  String get wallpaperProviderWallhaven;

  /// Failed filter export action inserted before refund status.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get economyExportFailedLabel;

  /// Feature name inserted into the sign-in title for creator search.
  ///
  /// In en, this message translates to:
  /// **'creator search'**
  String get coreSignInCreatorSearchFeature;

  /// Subject of the shared diagnostic log export.
  ///
  /// In en, this message translates to:
  /// **'Prism Debug Logs'**
  String get debugLogExportSubject;

  /// About page title.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get accountAbout;

  /// Settings item for the About page.
  ///
  /// In en, this message translates to:
  /// **'About Prism'**
  String get accountAboutPrism;

  /// Drawer section heading for account actions.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountAccount;

  /// Notice that deleting a Prism account does not cancel the store subscription.
  ///
  /// In en, this message translates to:
  /// **'Your store subscription is not cancelled when you delete your account. It keeps billing until you cancel it in the store.'**
  String get accountAccountDeletionSubscriptionWarning;

  /// Settings item for advertising privacy options.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices'**
  String get accountAdPrivacyChoices;

  /// Profile completeness step for adding a photo.
  ///
  /// In en, this message translates to:
  /// **'Add profile photo'**
  String get accountAddProfilePhoto;

  /// Profile completeness step for adding a social link.
  ///
  /// In en, this message translates to:
  /// **'Add one social link'**
  String get accountAddSocialLink;

  /// Settings group heading for admin tools.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get accountAdmin;

  /// Admin-only moderation settings item.
  ///
  /// In en, this message translates to:
  /// **'Admin moderation'**
  String get accountAdminModeration;

  /// Share message for Prism on Android.
  ///
  /// In en, this message translates to:
  /// **'Fall in love with Android customisation again! Check out Prism -\n{url}'**
  String accountAndroidSharePitch(String url);

  /// No minimum resolution filter option.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get accountAnyResolution;

  /// Prism app name shown on the About page.
  ///
  /// In en, this message translates to:
  /// **'Prism Wallpapers'**
  String get accountAppName;

  /// Settings group heading for appearance options.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountAppearance;

  /// Apply search filters action label.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get accountApply;

  /// Set action option that asks before applying a wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get accountAskEveryTime;

  /// Notification campaign audience section title.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get accountAudience;

  /// Settings item for automatic wallpaper rotation.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate wallpapers'**
  String get accountAutoRotateWallpapers;

  /// Confirmation action label for blocking an account.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get accountBlock;

  /// Error shown when a block action fails.
  ///
  /// In en, this message translates to:
  /// **'Could not update blocked accounts'**
  String get accountBlockActionFailed;

  /// Status shown when a block change is queued for sync.
  ///
  /// In en, this message translates to:
  /// **'Your change is saved on this device and will sync when possible.'**
  String get accountBlockActionPendingSync;

  /// Fallback name used in block confirmation.
  ///
  /// In en, this message translates to:
  /// **'this user'**
  String get accountBlockConfirmationUserFallback;

  /// Confirmation title for blocking an account.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String accountBlockThisUserTitle(String name);

  /// Profile menu block action label.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get accountBlockUser;

  /// Confirmation message for blocking an account.
  ///
  /// In en, this message translates to:
  /// **'You will unfollow {name}, stop seeing their wallpapers in feeds, and no longer get notifications about their new posts.'**
  String accountBlockUserMessage(String name);

  /// Blocked accounts page title.
  ///
  /// In en, this message translates to:
  /// **'Blocked accounts'**
  String get accountBlockedAccounts;

  /// Empty state explanation for the blocked accounts page.
  ///
  /// In en, this message translates to:
  /// **'Blocking hides their posts from your feed. They may still be able to view your public profile and wallpapers.'**
  String get accountBlockedAccountsEmptyBody;

  /// Error title when blocked accounts cannot load.
  ///
  /// In en, this message translates to:
  /// **'Could not load blocked accounts'**
  String get accountBlockedAccountsLoadError;

  /// Fallback name shown for an account without a username.
  ///
  /// In en, this message translates to:
  /// **'Blocked user'**
  String get accountBlockedListUserFallback;

  /// Explanation shown on a profile blocked by the viewer.
  ///
  /// In en, this message translates to:
  /// **'Their wallpapers are hidden from your feeds and notifications. You can unblock them any time.'**
  String get accountBlockedProfileBody;

  /// Subtitle for restoring purchases.
  ///
  /// In en, this message translates to:
  /// **'Bring back a previous subscription'**
  String get accountBringBackSubscription;

  /// Search discovery section heading.
  ///
  /// In en, this message translates to:
  /// **'Browse by category'**
  String get accountBrowseByCategory;

  /// Search discovery section heading.
  ///
  /// In en, this message translates to:
  /// **'Browse by colour'**
  String get accountBrowseByColour;

  /// Settings item for purchasing premium.
  ///
  /// In en, this message translates to:
  /// **'Buy premium'**
  String get accountBuyPremium;

  /// Success message after clearing the image cache.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared.'**
  String get accountCacheCleared;

  /// Success message after clearing the image cache.
  ///
  /// In en, this message translates to:
  /// **'Cleared {size}.'**
  String accountCacheClearedBytes(String size);

  /// Used image cache size value in settings.
  ///
  /// In en, this message translates to:
  /// **'{size} of cached images'**
  String accountCachedImageSize(String size);

  /// Cancel action label.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountCancel;

  /// Message shown when a gift cannot be sent to this account.
  ///
  /// In en, this message translates to:
  /// **'You can\'t send a gift to this account.'**
  String get accountCannotGiftThisAccount;

  /// Accessible label for a wallpaper category.
  ///
  /// In en, this message translates to:
  /// **'Category, {name}'**
  String accountCategorySemanticLabel(String name);

  /// Settings item for automatic wallpaper changes using Shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Change automatically'**
  String get accountChangeAutomatically;

  /// Accessible action label for changing a profile cover photo.
  ///
  /// In en, this message translates to:
  /// **'Change cover photo'**
  String get accountChangeCoverPhoto;

  /// Subtitle for managing a subscription.
  ///
  /// In en, this message translates to:
  /// **'Change or cancel in the store'**
  String get accountChangeOrCancelStore;

  /// Accessible action label for changing a profile photo.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get accountChangePhoto;

  /// Subtitle for automatic wallpaper rotation.
  ///
  /// In en, this message translates to:
  /// **'Change your wallpaper on a timer'**
  String get accountChangeWallpaperOnTimer;

  /// Hint to retry after a connection error.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get accountCheckConnectionTryAgain;

  /// Clear action label.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get accountClear;

  /// Settings action for deleting downloaded wallpaper files.
  ///
  /// In en, this message translates to:
  /// **'Clear all downloads'**
  String get accountClearAllDownloads;

  /// Confirmation title for clearing favourites.
  ///
  /// In en, this message translates to:
  /// **'Clear all favourites?'**
  String get accountClearAllFavouritesQuestion;

  /// Action label for clearing cached images.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get accountClearCache;

  /// Confirmation message when cache size is unknown.
  ///
  /// In en, this message translates to:
  /// **'Cached images are removed. They load again when you need them.'**
  String get accountClearCacheConfirmMessage;

  /// Confirmation message before clearing cached images.
  ///
  /// In en, this message translates to:
  /// **'{size} of cached images are removed. They load again when you need them.'**
  String accountClearCacheConfirmSizeMessage(String size);

  /// Confirmation title for clearing cached images.
  ///
  /// In en, this message translates to:
  /// **'Clear cache?'**
  String get accountClearCacheQuestion;

  /// Settings item for clearing cached images.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get accountClearCacheTitle;

  /// Subtitle for clearing cached images.
  ///
  /// In en, this message translates to:
  /// **'Clear locally cached images'**
  String get accountClearCachedImages;

  /// Tooltip for clearing the colour filter.
  ///
  /// In en, this message translates to:
  /// **'Clear colour'**
  String get accountClearColour;

  /// Tooltip for clearing the Depth Effect filter.
  ///
  /// In en, this message translates to:
  /// **'Clear Depth Effect'**
  String get accountClearDepthEffect;

  /// Spatial Scene text: accountClearSpatialScene.
  ///
  /// In en, this message translates to:
  /// **'Clear Spatial'**
  String get accountClearSpatialScene;

  /// Settings action for clearing all favourites.
  ///
  /// In en, this message translates to:
  /// **'Clear favourite wallpapers'**
  String get accountClearFavouriteWallpapers;

  /// Action label for clearing favourites.
  ///
  /// In en, this message translates to:
  /// **'Clear favourites'**
  String get accountClearFavourites;

  /// Confirmation message before clearing favourites.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 favourite wallpaper is removed} other{{count} favourite wallpapers are removed}} from your account. This cannot be undone.'**
  String accountClearFavouritesCountMessage(int count);

  /// Confirmation message before clearing favourites when count is unknown or zero.
  ///
  /// In en, this message translates to:
  /// **'All your favourite wallpapers are removed from your account. This cannot be undone.'**
  String get accountClearFavouritesMessage;

  /// Settings action for deleting learned taste signals.
  ///
  /// In en, this message translates to:
  /// **'Clear learned taste'**
  String get accountClearLearnedTaste;

  /// Confirmation message before clearing learned taste.
  ///
  /// In en, this message translates to:
  /// **'Prism forgets {count, plural, =1{the 1 thing} other{the {count} things}} it learned from what you viewed and saved. Your feed uses your chosen interests again. This cannot be undone.'**
  String accountClearLearnedTasteCountMessage(int count);

  /// Confirmation title for removing learned taste signals.
  ///
  /// In en, this message translates to:
  /// **'Clear learned taste?'**
  String get accountClearLearnedTasteQuestion;

  /// Tooltip for clearing a search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get accountClearSearch;

  /// Wallpaper search colour filter heading.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get accountColour;

  /// Number of commits for a contributor.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No commits} =1{1 commit} other{{count} commits}}'**
  String accountCommitCount(int count);

  /// Action to open the profile editor from profile completeness UI.
  ///
  /// In en, this message translates to:
  /// **'Complete profile'**
  String get accountCompleteProfile;

  /// Profile completeness card title and action.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get accountCompleteYourProfile;

  /// Retry hint shown when profile content cannot load.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get accountConnectionTryAgain;

  /// Settings group heading for content preferences.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get accountContent;

  /// Fallback label for an unnamed project contributor.
  ///
  /// In en, this message translates to:
  /// **'Contributor'**
  String get accountContributor;

  /// Accessible label for a contributor and their commit count.
  ///
  /// In en, this message translates to:
  /// **'{login}, {count, plural, =0{no commits} =1{1 commit} other{{count} commits}}'**
  String accountContributorCommitCount(String login, int count);

  /// Copy action label.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get accountCopy;

  /// Copy invite link tooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get accountCopyLink;

  /// Error shown when a report preview cannot be built.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t build the report. Try again.'**
  String get accountCouldNotBuildReport;

  /// Error message when clearing favourites fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t clear favourite wallpapers. Try again.'**
  String get accountCouldNotClearFavourites;

  /// Error message when clearing learned taste fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t clear learned taste. Try again.'**
  String get accountCouldNotClearLearnedTaste;

  /// Error shown when creating a profile link fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the link. Try again.'**
  String get accountCouldNotCreateLink;

  /// Error message after deleting downloads fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete downloads. Try again.'**
  String get accountCouldNotDeleteDownloads;

  /// Error toast when following a profile fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t follow {name}. Try again.'**
  String accountCouldNotFollowPerson(String name);

  /// Error title when the followers list cannot load.
  ///
  /// In en, this message translates to:
  /// **'Could not load followers'**
  String get accountCouldNotLoadFollowers;

  /// Error title when the following list cannot load.
  ///
  /// In en, this message translates to:
  /// **'Could not load following'**
  String get accountCouldNotLoadFollowing;

  /// Error title when team contributors cannot load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the team'**
  String get accountCouldNotLoadTeam;

  /// Error title when a public profile cannot load.
  ///
  /// In en, this message translates to:
  /// **'Could not load this profile'**
  String get accountCouldNotLoadThisProfile;

  /// Error title when trending wallpapers fail to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load trending'**
  String get accountCouldNotLoadTrending;

  /// Error title when creator wallpapers cannot load.
  ///
  /// In en, this message translates to:
  /// **'Could not load wallpapers'**
  String get accountCouldNotLoadWallpapers;

  /// Message shown when an About page link cannot open.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {address}'**
  String accountCouldNotOpenAddress(String address);

  /// Error message when a settings link cannot open.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link. Try again.'**
  String get accountCouldNotOpenLink;

  /// Error message when the subscription store cannot open.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the store. Try again.'**
  String get accountCouldNotOpenStore;

  /// Error shown when a profile link cannot open.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this link.'**
  String get accountCouldNotOpenThisLink;

  /// Error message when refreshing wallpaper search fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh. Pull down to try again.'**
  String get accountCouldNotRefreshSearch;

  /// Error message when clearing saved offline wallpapers fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove saved offline wallpapers. Try again.'**
  String get accountCouldNotRemoveSavedOffline;

  /// Error message when restoring purchases fails.
  ///
  /// In en, this message translates to:
  /// **'Could not restore purchases. Try again.'**
  String get accountCouldNotRestorePurchases;

  /// Error title when creator search fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search creators'**
  String get accountCouldNotSearchCreators;

  /// Error title when wallpaper search fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search right now'**
  String get accountCouldNotSearchRightNow;

  /// Error shown when sending a gift fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the gift. Try again.'**
  String get accountCouldNotSendGift;

  /// Error shown when sharing a report fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share the report. Try again.'**
  String get accountCouldNotShareReport;

  /// Error toast when unfollowing a profile fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t unfollow {name}. Try again.'**
  String accountCouldNotUnfollowPerson(String name);

  /// Fallback display name when a creator has no name or username.
  ///
  /// In en, this message translates to:
  /// **'Prism creator'**
  String get accountCreatorFallback;

  /// Empty state explanation when creator search has no results.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling or try another name.'**
  String get accountCreatorSearchEmptyBody;

  /// Error shown when account deletion uses the wrong account.
  ///
  /// In en, this message translates to:
  /// **'Please select the account you are currently signed in with.'**
  String get accountCurrentSignedInAccountRequired;

  /// Settings item for reduced data usage.
  ///
  /// In en, this message translates to:
  /// **'Data saver'**
  String get accountDataSaver;

  /// Explanation of data saver behavior.
  ///
  /// In en, this message translates to:
  /// **'Saves mobile data. Wallpapers open as thumbnails, feeds do not load ahead and carousels do not autoplay.'**
  String get accountDataSaverDescription;

  /// Subtitle for Firestore telemetry.
  ///
  /// In en, this message translates to:
  /// **'Database usage and stats'**
  String get accountDatabaseUsageStats;

  /// Admin settings item for the debug panel.
  ///
  /// In en, this message translates to:
  /// **'Debug panel'**
  String get accountDebugPanel;

  /// Settings control for the default Set action.
  ///
  /// In en, this message translates to:
  /// **'Default action for Set'**
  String get accountDefaultActionForSet;

  /// Action label for deleting an account.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteAccount;

  /// Permanent account deletion confirmation message.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account, remove your personal data, and sign you out.\n\nYour uploaded wallpapers will remain visible as \"Deleted Account\".\n\nThis action cannot be undone.'**
  String get accountDeleteAccountConfirmation;

  /// Notice shown before account deletion reauthentication.
  ///
  /// In en, this message translates to:
  /// **'You will confirm with Google or Apple next.'**
  String get accountDeleteAccountReauthNote;

  /// Action label for deleting all downloads.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get accountDeleteAll;

  /// Confirmation title for deleting downloads.
  ///
  /// In en, this message translates to:
  /// **'Delete all downloads?'**
  String get accountDeleteAllDownloadsQuestion;

  /// Confirmation message before deleting downloads.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 downloaded wallpaper is deleted} other{{count} downloaded wallpapers are deleted}} from Downloads. Saved offline copies are not affected. This cannot be undone.'**
  String accountDeleteDownloadsCountMessage(int count);

  /// Confirmation message before deleting downloads when count is unknown or zero.
  ///
  /// In en, this message translates to:
  /// **'Downloaded wallpapers are deleted from Downloads. Saved offline copies are not affected. This cannot be undone.'**
  String get accountDeleteDownloadsMessage;

  /// Confirmation title for deleting an account.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get accountDeleteYourAccountQuestion;

  /// Progress title while deleting an account.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account'**
  String get accountDeletingYourAccount;

  /// Depth Effect feature label.
  ///
  /// In en, this message translates to:
  /// **'Depth Effect'**
  String get accountDepthEffect;

  /// Accessible description of Depth Effect wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Depth Effect, subject in front of the clock'**
  String get accountDepthEffectClockSemanticLabel;

  /// Spatial Scene text: accountSpatialScene.
  ///
  /// In en, this message translates to:
  /// **'Spatial'**
  String get accountSpatialScene;

  /// Spatial Scene text: accountSpatialSceneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Walls with clear 3D depth'**
  String get accountSpatialSceneSubtitle;

  /// Spatial Scene text: accountSpatialSceneSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Spatial, walls with clear 3D depth'**
  String get accountSpatialSceneSemanticLabel;

  /// Subtitle describing downloaded files and retained offline copies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No downloaded wallpapers; saved offline copies stay} =1{1 downloaded wallpaper; saved offline copies stay} other{{count} downloaded wallpapers; saved offline copies stay}}'**
  String accountDownloadedWallpaperCount(int count);

  /// Success message after deleting downloads.
  ///
  /// In en, this message translates to:
  /// **'Deleted all downloads.'**
  String get accountDownloadsDeleted;

  /// Earn coins action label.
  ///
  /// In en, this message translates to:
  /// **'Earn coins'**
  String get accountEarnCoins;

  /// Reward hint on the profile completeness card.
  ///
  /// In en, this message translates to:
  /// **'Earn {coins} coins when you finish'**
  String accountEarnProfileCompletionCoins(int coins);

  /// Edit cover photo button label.
  ///
  /// In en, this message translates to:
  /// **'Edit cover'**
  String get accountEditCover;

  /// Edit profile action tooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get accountEditProfile;

  /// Settings action for exporting favourite wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Export favourites'**
  String get accountExportFavourites;

  /// Success message after clearing favourite wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Cleared all favourite wallpapers.'**
  String get accountFavouritesCleared;

  /// About page action to send feedback.
  ///
  /// In en, this message translates to:
  /// **'FEEDBACK'**
  String get accountFeedback;

  /// Email subject for feedback sent from the About page.
  ///
  /// In en, this message translates to:
  /// **'Prism feedback'**
  String get accountFeedbackSubject;

  /// Log record fields section heading.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get accountFields;

  /// Wallpaper search filters button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get accountFilters;

  /// Creator search row and page title.
  ///
  /// In en, this message translates to:
  /// **'Find creators'**
  String get accountFindCreators;

  /// Profile completeness prompt title.
  ///
  /// In en, this message translates to:
  /// **'Finish your profile'**
  String get accountFinishYourProfile;

  /// Admin-only Firestore telemetry settings item.
  ///
  /// In en, this message translates to:
  /// **'Firestore telemetry'**
  String get accountFirestoreTelemetry;

  /// Follow action label and tooltip.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get accountFollow;

  /// Accessible follow action label for a profile.
  ///
  /// In en, this message translates to:
  /// **'Follow {name}'**
  String accountFollowPerson(String name);

  /// Success toast after following a profile.
  ///
  /// In en, this message translates to:
  /// **'Followed {name}!'**
  String accountFollowedPerson(String name);

  /// Followers count label on a profile.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get accountFollowers;

  /// Follower count on a creator search result.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No followers} =1{1 follower} other{{count} followers}}'**
  String accountFollowersCount(int count);

  /// Accessible follower statistic for the profile.
  ///
  /// In en, this message translates to:
  /// **'{compactCount} Followers'**
  String accountFollowersCountLabel(String compactCount);

  /// Empty state message for the followers list.
  ///
  /// In en, this message translates to:
  /// **'People who follow this account will show up here.'**
  String get accountFollowersEmptyMessage;

  /// Following count label on a profile.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get accountFollowing;

  /// Accessible follower statistic for accounts the profile follows.
  ///
  /// In en, this message translates to:
  /// **'{compactCount} Following'**
  String accountFollowingCountLabel(String compactCount);

  /// Empty state message for the following list.
  ///
  /// In en, this message translates to:
  /// **'Accounts followed from here will show up here.'**
  String get accountFollowingEmptyMessage;

  /// Subtitle for clearing learned taste.
  ///
  /// In en, this message translates to:
  /// **'Forget what your feed learned from you'**
  String get accountForgetFeedLearned;

  /// Section heading for Prism catalogue results.
  ///
  /// In en, this message translates to:
  /// **'From Prism'**
  String get accountFromPrism;

  /// Message shown when a user reaches the daily gift limit.
  ///
  /// In en, this message translates to:
  /// **'Gift limit reached for now. Try again tomorrow.'**
  String get accountGiftLimitReached;

  /// Gift pass sheet explanation.
  ///
  /// In en, this message translates to:
  /// **'{recipientName} gets premium collections and premium walls until tomorrow. Costs {price} coins.'**
  String accountGiftPassMessage(String recipientName, int price);

  /// Gift pass sheet title.
  ///
  /// In en, this message translates to:
  /// **'Gift a 24-hour Pro pass'**
  String get accountGiftPassTitle;

  /// Tooltip for gifting a Pro pass.
  ///
  /// In en, this message translates to:
  /// **'Gift a 24 h pass'**
  String get accountGiftPassTooltip;

  /// Message shown when an account is too new to send gifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts open when your account is 7 days old.'**
  String get accountGiftsOpenAfterSevenDays;

  /// Settings row for haptic feedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get accountHapticFeedback;

  /// Settings group heading for support and app info.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get accountHelp;

  /// Set action option for applying to both screens.
  ///
  /// In en, this message translates to:
  /// **'Home and lock screens'**
  String get accountHomeAndLockScreens;

  /// Set action option for applying to the home screen.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get accountHomeScreen;

  /// Invite friends page title.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get accountInviteFriends;

  /// Error shown when invite-link generation fails.
  ///
  /// In en, this message translates to:
  /// **'Could not create your invite link.'**
  String get accountInviteLinkCouldNotCreate;

  /// Referral reward headline.
  ///
  /// In en, this message translates to:
  /// **'Give {coins}, get {coins}'**
  String accountInviteRewardHeadline(int coins);

  /// Referral reward explanation.
  ///
  /// In en, this message translates to:
  /// **'Your friend gets {coins} coins when they join. You get {coins} too.'**
  String accountInviteRewardMessage(int coins);

  /// Error shown when the invite share sheet cannot open.
  ///
  /// In en, this message translates to:
  /// **'Unable to share invite right now.'**
  String get accountInviteShareFailed;

  /// Share message for Prism on iOS.
  ///
  /// In en, this message translates to:
  /// **'Fall in love with your phone\'s personalization again! Check out Prism -\n{url}'**
  String accountIosSharePitch(String url);

  /// Dismiss action label for profile completeness prompt.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get accountLater;

  /// Latest sort option.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get accountLatest;

  /// Success message after clearing learned taste.
  ///
  /// In en, this message translates to:
  /// **'Learned taste cleared.'**
  String get accountLearnedTasteCleared;

  /// Drawer menu item for the wallpaper library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get accountLibrary;

  /// Subtitle describing theme choices.
  ///
  /// In en, this message translates to:
  /// **'Light, dark and accent colour'**
  String get accountLightDarkAccentColour;

  /// Link type label.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get accountLink;

  /// Success toast after copying an invite link.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get accountLinkCopied;

  /// Profile link type picker title.
  ///
  /// In en, this message translates to:
  /// **'Link type'**
  String get accountLinkType;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Behance'**
  String get accountLinkTypeBehance;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'bio.link'**
  String get accountLinkTypeBioLink;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Buy Me a Coffee'**
  String get accountLinkTypeBuyMeACoffee;

  /// Profile link type label for a user-supplied URL.
  ///
  /// In en, this message translates to:
  /// **'Custom link'**
  String get accountLinkTypeCustom;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'DeviantArt'**
  String get accountLinkTypeDeviantArt;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Dribbble'**
  String get accountLinkTypeDribbble;

  /// Profile link type label for an email address.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountLinkTypeEmail;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get accountLinkTypeGithub;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'GitLab'**
  String get accountLinkTypeGitlab;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get accountLinkTypeInstagram;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'LinkedIn'**
  String get accountLinkTypeLinkedin;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Linktree'**
  String get accountLinkTypeLinktree;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get accountLinkTypeMedium;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Patreon'**
  String get accountLinkTypePatreon;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'PayPal'**
  String get accountLinkTypePaypal;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Reddit'**
  String get accountLinkTypeReddit;

  /// Accessible label for a profile link type selector.
  ///
  /// In en, this message translates to:
  /// **'Link type, {name}'**
  String accountLinkTypeSemanticLabel(String name);

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Spotify'**
  String get accountLinkTypeSpotify;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get accountLinkTypeTelegram;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Trello'**
  String get accountLinkTypeTrello;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Twitch'**
  String get accountLinkTypeTwitch;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Twitter'**
  String get accountLinkTypeTwitter;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'Unsplash'**
  String get accountLinkTypeUnsplash;

  /// Profile link provider label.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get accountLinkTypeYoutube;

  /// Settings item for live wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Live wallpapers'**
  String get accountLiveWallpapers;

  /// Loading state title while team contributors load.
  ///
  /// In en, this message translates to:
  /// **'Loading the team'**
  String get accountLoadingTeam;

  /// Set action option for applying to the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get accountLockScreen;

  /// Action label for signing out.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get accountLogOut;

  /// Confirmation title for signing out from the profile drawer.
  ///
  /// In en, this message translates to:
  /// **'Log out of Prism?'**
  String get accountLogOutOfPrismQuestion;

  /// Confirmation title for signing out.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get accountLogOutQuestion;

  /// Explanation shown before signing out.
  ///
  /// In en, this message translates to:
  /// **'Signing out clears history and learned taste on this device. Favourites, coins and profile stay with your account.'**
  String get accountLogoutConfirmation;

  /// Error shown when signing out fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t log out. Try again.'**
  String get accountLogoutFailed;

  /// Subtitle for the debug panel settings item.
  ///
  /// In en, this message translates to:
  /// **'Logs, network, tools and storage'**
  String get accountLogsNetworkToolsStorage;

  /// About page footer text.
  ///
  /// In en, this message translates to:
  /// **'Made with ❤ in India with Flutter!'**
  String get accountMadeWithLoveInIndia;

  /// Subtitle for the blocked accounts settings row.
  ///
  /// In en, this message translates to:
  /// **'Manage people you have blocked'**
  String get accountManageBlockedPeople;

  /// Action label for managing a subscription.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get accountManageSubscription;

  /// Profile menu tooltip.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get accountMenu;

  /// Minimum resolution filter heading.
  ///
  /// In en, this message translates to:
  /// **'Min resolution'**
  String get accountMinResolution;

  /// Tooltip for additional profile links.
  ///
  /// In en, this message translates to:
  /// **'More links'**
  String get accountMoreLinks;

  /// Profile options menu tooltip.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get accountMoreOptions;

  /// Subtitle describing live wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Moving gradients, motion and video'**
  String get accountMovingGradientsMotionVideo;

  /// Filter for the user's selected accent colour.
  ///
  /// In en, this message translates to:
  /// **'My accent'**
  String get accountMyAccent;

  /// Empty state title for the blocked accounts page.
  ///
  /// In en, this message translates to:
  /// **'No blocked accounts'**
  String get accountNoBlockedAccounts;

  /// Empty state when no team contributors are available.
  ///
  /// In en, this message translates to:
  /// **'No contributors to show yet.'**
  String get accountNoContributors;

  /// Empty state title when creator search has no results.
  ///
  /// In en, this message translates to:
  /// **'No creators found'**
  String get accountNoCreatorsFound;

  /// Info message when there are no downloads to delete.
  ///
  /// In en, this message translates to:
  /// **'You have no downloads to remove.'**
  String get accountNoDownloadsToRemove;

  /// Empty state title for a profile with no followers.
  ///
  /// In en, this message translates to:
  /// **'No followers yet'**
  String get accountNoFollowersYet;

  /// Message when restore finds no purchases.
  ///
  /// In en, this message translates to:
  /// **'No purchases to restore for this account.'**
  String get accountNoPurchasesToRestore;

  /// Empty state title when a follower or following list has no results.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get accountNoResults;

  /// Empty state naming the active wallpaper filters.
  ///
  /// In en, this message translates to:
  /// **'No {filters} wallpapers found'**
  String accountNoWallpapersForFilters(String filters);

  /// Empty state when a query and filters return no wallpapers.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers found for {query} with the selected filters.'**
  String accountNoWallpapersForQueryWithFilters(String query);

  /// Empty state for wallpaper search.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers found'**
  String get accountNoWallpapersFound;

  /// Empty state for a wallpaper search query.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers found for {query}'**
  String accountNoWallpapersFoundForQuery(String query);

  /// Empty state title when a creator has no wallpapers.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers yet'**
  String get accountNoWallpapersYet;

  /// Empty state text for a username search.
  ///
  /// In en, this message translates to:
  /// **'Nobody matches \"{query}\". Try a different username.'**
  String accountNobodyMatchesUsername(String query);

  /// Gift failure message when the user lacks coins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins. Earn coins in Rewards.'**
  String get accountNotEnoughCoinsEarnInRewards;

  /// Empty state title for a profile that follows no accounts.
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet'**
  String get accountNotFollowingAnyoneYet;

  /// Sync status label for a blocked account.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get accountNotSynced;

  /// Info message when there are no learned taste signals.
  ///
  /// In en, this message translates to:
  /// **'Prism has not learned anything yet.'**
  String get accountNothingLearnedYet;

  /// Settings item for notification preferences.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get accountNotificationPreferences;

  /// Subtitle describing notification categories.
  ///
  /// In en, this message translates to:
  /// **'Wall of the Day, followers, posts and more'**
  String get accountNotificationTypes;

  /// Settings group heading for notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountNotifications;

  /// Accessible label for the signed-in settings account card.
  ///
  /// In en, this message translates to:
  /// **'Open your profile'**
  String get accountOpenYourProfile;

  /// Accessibility announcement when opening the profile editor.
  ///
  /// In en, this message translates to:
  /// **'Opening profile editor'**
  String get accountOpeningProfileEditor;

  /// Notification campaign route section title.
  ///
  /// In en, this message translates to:
  /// **'Opens'**
  String get accountOpens;

  /// About page section heading for contributors.
  ///
  /// In en, this message translates to:
  /// **'Other Contributors'**
  String get accountOtherContributors;

  /// Success toast after gifting a Pro pass.
  ///
  /// In en, this message translates to:
  /// **'Pass sent to {name}.'**
  String accountPassSentToPerson(String name);

  /// Message shown when the recipient already has Pro.
  ///
  /// In en, this message translates to:
  /// **'{name} already has Pro.'**
  String accountPersonAlreadyHasPro(String name);

  /// Settings group heading for personalization options.
  ///
  /// In en, this message translates to:
  /// **'Personalise'**
  String get accountPersonalise;

  /// Portrait-only wallpaper filter label.
  ///
  /// In en, this message translates to:
  /// **'Portrait only'**
  String get accountPortraitOnly;

  /// Premium benefits description for subscribers.
  ///
  /// In en, this message translates to:
  /// **'You have every premium wallpaper, free downloads and free filters.'**
  String get accountPremiumBenefitsActive;

  /// Premium benefits description for non-subscribers.
  ///
  /// In en, this message translates to:
  /// **'Unlock premium wallpapers, free downloads and free filters.'**
  String get accountPremiumBenefitsInactive;

  /// Notification campaign preview section title.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get accountPreview;

  /// Subtitle for the privacy policy link on the About page.
  ///
  /// In en, this message translates to:
  /// **'How Prism handles your data'**
  String get accountPrismListPrivacySubtitle;

  /// Prism Pro drawer heading.
  ///
  /// In en, this message translates to:
  /// **'Prism Pro'**
  String get accountPrismPro;

  /// About page action to view the privacy policy.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get accountPrivacyAction;

  /// Settings group heading for privacy and data controls.
  ///
  /// In en, this message translates to:
  /// **'Privacy and data'**
  String get accountPrivacyAndData;

  /// Privacy policy link label.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get accountPrivacyPolicy;

  /// Premium badge label in settings and profile wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get accountProBadge;

  /// Accessibility label for a premium wallpaper badge.
  ///
  /// In en, this message translates to:
  /// **'Pro wallpaper'**
  String get accountProWallpaperSemantics;

  /// Prompt shown with the problem report attachment.
  ///
  /// In en, this message translates to:
  /// **'Please describe what went wrong. The report file has the details.'**
  String get accountProblemReportSharePrompt;

  /// Subject for the problem report share sheet.
  ///
  /// In en, this message translates to:
  /// **'Prism problem report'**
  String get accountProblemReportShareSubject;

  /// Profile page title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountProfile;

  /// Error title when a public profile is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Profile not available'**
  String get accountProfileNotAvailable;

  /// Empty state explanation when a profile is unavailable.
  ///
  /// In en, this message translates to:
  /// **'This user is inactive on the latest version of Prism, so their profile cannot be shown.'**
  String get accountProfileNotAvailableBody;

  /// Profile completeness prompt message.
  ///
  /// In en, this message translates to:
  /// **'Your profile is {percent}% complete. Finish it to earn {coins} Prism coins.'**
  String accountProfileNudgeMessage(int percent, int coins);

  /// Accessible description of profile completion progress.
  ///
  /// In en, this message translates to:
  /// **'Profile {percent}% complete'**
  String accountProfilePercentComplete(int percent);

  /// Accessible profile row label with a username.
  ///
  /// In en, this message translates to:
  /// **'{name}, @{username}'**
  String accountProfilePersonSemantics(String name, String username);

  /// Sign-in prompt feature name for profiles.
  ///
  /// In en, this message translates to:
  /// **'profiles'**
  String get accountProfiles;

  /// Settings group heading for purchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get accountPurchases;

  /// Success toast after restoring purchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored.'**
  String get accountPurchasesRestored;

  /// Toast after a restore when the store has the purchase but the server has not confirmed Pro yet.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored. Pro can take a minute to unlock.'**
  String get accountPurchasesRestoredPending;

  /// Settings item for Quick Settings tiles.
  ///
  /// In en, this message translates to:
  /// **'Quick tiles'**
  String get accountQuickTiles;

  /// About page action to rate Prism.
  ///
  /// In en, this message translates to:
  /// **'RATE'**
  String get accountRateApp;

  /// Search history section heading.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get accountRecentSearches;

  /// Relevance sort option.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get accountRelevance;

  /// Subtitle for clearing favourite wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Remove all favourite wallpapers'**
  String get accountRemoveAllFavouriteWallpapers;

  /// Cover photo removal tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove cover photo'**
  String get accountRemoveCoverPhoto;

  /// Subtitle for clearing downloads when file count is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Remove files from Downloads; saved offline copies stay'**
  String get accountRemoveFilesDownloadsOfflineStay;

  /// Remove profile link tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get accountRemoveLink;

  /// Button that removes a custom profile photo.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get accountRemovePhoto;

  /// Action label for removing saved offline wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Remove saved offline'**
  String get accountRemoveSavedOffline;

  /// Confirmation message before removing saved offline wallpapers.
  ///
  /// In en, this message translates to:
  /// **'{size} of retained offline originals are removed. Downloads, drafts and catalog data stay untouched.'**
  String accountRemoveSavedOfflineCountMessage(String size);

  /// Confirmation message when retained offline storage size is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Remove retained offline originals from this device. Downloads, drafts and catalog data stay untouched.'**
  String get accountRemoveSavedOfflineMessage;

  /// Confirmation title for removing offline wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Remove saved offline wallpapers?'**
  String get accountRemoveSavedOfflineQuestion;

  /// Title for the report problem sheet and settings row.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get accountReportAProblem;

  /// Subtitle for reporting a problem.
  ///
  /// In en, this message translates to:
  /// **'Send a bug report to the Prism team'**
  String get accountReportProblemSubtitle;

  /// Profile menu report action label.
  ///
  /// In en, this message translates to:
  /// **'Report user'**
  String get accountReportUser;

  /// Reset search filters action label.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get accountReset;

  /// Action label that clears all wallpaper search filters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get accountResetFilters;

  /// 1080p minimum resolution filter option.
  ///
  /// In en, this message translates to:
  /// **'1080p'**
  String get accountResolution1080;

  /// 1440p minimum resolution filter option.
  ///
  /// In en, this message translates to:
  /// **'1440p'**
  String get accountResolution1440;

  /// 4K minimum resolution filter option.
  ///
  /// In en, this message translates to:
  /// **'4K'**
  String get accountResolution4k;

  /// Settings item for restoring purchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get accountRestorePurchases;

  /// Progress toast while restoring purchases.
  ///
  /// In en, this message translates to:
  /// **'Restoring purchases…'**
  String get accountRestoringPurchases;

  /// Label above wallpaper search results.
  ///
  /// In en, this message translates to:
  /// **'Results for {query}'**
  String accountResultsForQuery(String query);

  /// Retry action label.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get accountRetry;

  /// Subtitle for ad privacy choices.
  ///
  /// In en, this message translates to:
  /// **'Review or change your ad consent'**
  String get accountReviewOrChangeAdConsent;

  /// Settings row for checking wallpaper submissions.
  ///
  /// In en, this message translates to:
  /// **'Review status'**
  String get accountReviewStatus;

  /// Subtitle for admin moderation.
  ///
  /// In en, this message translates to:
  /// **'Review submitted content'**
  String get accountReviewSubmittedContent;

  /// Subtitle for exporting favourites.
  ///
  /// In en, this message translates to:
  /// **'Save a copy of your favourites as a file'**
  String get accountSaveFavouritesAsFile;

  /// Settings row for retained offline wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Saved offline'**
  String get accountSavedOffline;

  /// Success message after removing saved offline wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Saved offline wallpapers removed.'**
  String get accountSavedOfflineRemoved;

  /// Settings subtitle when retained offline storage size is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Storage unavailable · {limit} MiB limit'**
  String accountSavedOfflineStorageUnavailable(int limit);

  /// Settings subtitle showing retained offline storage usage.
  ///
  /// In en, this message translates to:
  /// **'{size} used · {limit} MiB limit'**
  String accountSavedOfflineStorageUsed(String size, int limit);

  /// Label for downloaded results saved on this device.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get accountSavedOnThisDevice;

  /// Wallpaper search page title.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get accountSearch;

  /// Hint for searching a profile's followers or following.
  ///
  /// In en, this message translates to:
  /// **'Search by username'**
  String get accountSearchByUsername;

  /// Creator search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search creators'**
  String get accountSearchCreators;

  /// Initial hint on the creator search page.
  ///
  /// In en, this message translates to:
  /// **'Search creators by name'**
  String get accountSearchCreatorsByName;

  /// Wallpaper search filters heading.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get accountSearchFilters;

  /// Subtitle for creator search entry.
  ///
  /// In en, this message translates to:
  /// **'Search Prism users by name'**
  String get accountSearchPrismUsersByName;

  /// Wallpaper search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search wallpapers'**
  String get accountSearchWallpapers;

  /// Subtitle for the changelog menu item.
  ///
  /// In en, this message translates to:
  /// **'See the changelog'**
  String get accountSeeChangelog;

  /// Send gift action label.
  ///
  /// In en, this message translates to:
  /// **'Send gift'**
  String get accountSendGift;

  /// Subtitle for the share profile settings row.
  ///
  /// In en, this message translates to:
  /// **'Send a link to your Prism profile'**
  String get accountSendProfileLink;

  /// Subtitle for the Quick Tiles guide.
  ///
  /// In en, this message translates to:
  /// **'Set up your Quick Settings tiles'**
  String get accountSetUpQuickTiles;

  /// Profile completeness step for setting a username.
  ///
  /// In en, this message translates to:
  /// **'Set username'**
  String get accountSetUsername;

  /// Settings action label.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get accountSettings;

  /// Share invite action label.
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get accountShareInvite;

  /// Menu item for sharing the Prism app.
  ///
  /// In en, this message translates to:
  /// **'Share Prism'**
  String get accountSharePrism;

  /// Subtitle for the share Prism menu item.
  ///
  /// In en, this message translates to:
  /// **'Send a link to a friend'**
  String get accountSharePrismFriendSubtitle;

  /// Drawer menu item for sharing a profile.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get accountShareProfile;

  /// Error shown when sharing a profile link fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the link. Try again.'**
  String get accountShareProfileLinkFailed;

  /// Settings row for sharing a profile link.
  ///
  /// In en, this message translates to:
  /// **'Share your profile'**
  String get accountShareYourProfile;

  /// Settings row for the Prism shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get accountShop;

  /// Content preference for anime wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Show anime wallpapers'**
  String get accountShowAnimeWallpapers;

  /// Content preference for mature wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Show sketchy wallpapers'**
  String get accountShowSketchyWallpapers;

  /// Sign-in action label.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountSignIn;

  /// Error shown when account deletion requires recent authentication.
  ///
  /// In en, this message translates to:
  /// **'Please sign out and sign in again, then try deleting your account.'**
  String get accountSignInAgainToDelete;

  /// Benefits message on the signed-out settings card.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your favourites, coins and profile'**
  String get accountSignInBenefits;

  /// Hint shown when the user must sign in to get an invite link.
  ///
  /// In en, this message translates to:
  /// **'Sign in to get your invite link.'**
  String get accountSignInForInviteLink;

  /// Heading for the signed-out settings account card.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Prism'**
  String get accountSignInToPrism;

  /// About page social link label for GitHub.
  ///
  /// In en, this message translates to:
  /// **'GITHUB'**
  String get accountSocialGithub;

  /// About page social link label for Instagram.
  ///
  /// In en, this message translates to:
  /// **'INSTAGRAM'**
  String get accountSocialInstagram;

  /// About page social link label for Telegram.
  ///
  /// In en, this message translates to:
  /// **'TELEGRAM'**
  String get accountSocialTelegram;

  /// About page social link label for Twitter.
  ///
  /// In en, this message translates to:
  /// **'TWITTER'**
  String get accountSocialTwitter;

  /// Generic error shown when account deletion fails.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get accountSomethingWentWrongTryAgain;

  /// Wallpaper search sort heading.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get accountSort;

  /// Settings group heading for storage management.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get accountStorage;

  /// Localized byte size shown in account storage messages.
  ///
  /// In en, this message translates to:
  /// **'{size} B'**
  String accountStorageSizeBytes(String size);

  /// Localized gigabyte size shown in account storage messages.
  ///
  /// In en, this message translates to:
  /// **'{size} GB'**
  String accountStorageSizeGigabytes(String size);

  /// Localized kilobyte size shown in account storage messages.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String accountStorageSizeKilobytes(String size);

  /// Localized megabyte size shown in account storage messages.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String accountStorageSizeMegabytes(String size);

  /// Description of the Depth Effect filter.
  ///
  /// In en, this message translates to:
  /// **'Subject can sit in front of the clock'**
  String get accountSubjectCanSitInFrontOfClock;

  /// Description of Depth Effect wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Subject in front of the clock'**
  String get accountSubjectInFrontOfClock;

  /// Terms of use link label.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get accountTerms;

  /// About page action to view the terms of use.
  ///
  /// In en, this message translates to:
  /// **'TERMS'**
  String get accountTermsAction;

  /// Accessible onboarding legal agreement label.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to the {terms} and {privacy}'**
  String accountTermsAgreementSemanticLabel(String terms, String privacy);

  /// Terms of use link label.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get accountTermsOfUse;

  /// About page team section heading.
  ///
  /// In en, this message translates to:
  /// **'The Team'**
  String get accountTheTeam;

  /// Settings row for appearance themes.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get accountThemes;

  /// Subtitle for the shop settings row.
  ///
  /// In en, this message translates to:
  /// **'Themes, icons, frames'**
  String get accountThemesIconsFrames;

  /// Fallback name used in follow result messages.
  ///
  /// In en, this message translates to:
  /// **'this user'**
  String get accountThisUser;

  /// Top sort option.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get accountTop;

  /// Subtitle for the review status settings row.
  ///
  /// In en, this message translates to:
  /// **'Track your submitted wallpapers'**
  String get accountTrackSubmittedWallpapers;

  /// Search discovery section heading.
  ///
  /// In en, this message translates to:
  /// **'Trending now'**
  String get accountTrendingNow;

  /// Retry action label.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get accountTryAgain;

  /// Hint when filters return no wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Try fewer filters.'**
  String get accountTryFewerFilters;

  /// Hint when a wallpaper search returns no results.
  ///
  /// In en, this message translates to:
  /// **'Try a shorter or a different word.'**
  String get accountTryShorterOrDifferentWord;

  /// Action label for unblocking an account.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get accountUnblock;

  /// Confirmation message for unblocking an account.
  ///
  /// In en, this message translates to:
  /// **'Their posts will appear in your feed again.'**
  String get accountUnblockUserMessage;

  /// Confirmation title for unblocking an account.
  ///
  /// In en, this message translates to:
  /// **'Unblock {name}?'**
  String accountUnblockUserTitle(String name);

  /// Unfollow action tooltip.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get accountUnfollow;

  /// Accessible unfollow action label for a profile.
  ///
  /// In en, this message translates to:
  /// **'Unfollow {name}'**
  String accountUnfollowPerson(String name);

  /// Success toast after unfollowing a profile.
  ///
  /// In en, this message translates to:
  /// **'Unfollowed {name}!'**
  String accountUnfollowedPerson(String name);

  /// Premium purchase subtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlimited uploads and filters'**
  String get accountUnlimitedUploadsFilters;

  /// Empty state body on the owner's empty wallpaper gallery.
  ///
  /// In en, this message translates to:
  /// **'Upload your first wallpaper to start your gallery.'**
  String get accountUploadFirstWallpaper;

  /// Subtitle for the Shortcuts guide settings row.
  ///
  /// In en, this message translates to:
  /// **'Use a Shortcuts automation'**
  String get accountUseShortcutsAutomation;

  /// Success message after blocking an account.
  ///
  /// In en, this message translates to:
  /// **'Blocked {name}'**
  String accountUserBlocked(String name);

  /// Success message after unblocking an account.
  ///
  /// In en, this message translates to:
  /// **'Unblocked'**
  String get accountUserUnblocked;

  /// Accessible label for the app version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String accountVersionLabel(String version);

  /// Subtitle for haptic feedback setting.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on taps and actions'**
  String get accountVibrateOnTapsAndActions;

  /// Sync status label for a blocked account.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get accountWaitingToSync;

  /// Settings item for wallpaper history.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper history'**
  String get accountWallpaperHistory;

  /// Short About page description of Prism.
  ///
  /// In en, this message translates to:
  /// **'A feature-rich wallpaper manager.'**
  String get accountWallpaperManagerTagline;

  /// About page subtitle naming wallpaper providers.
  ///
  /// In en, this message translates to:
  /// **'Prism uses Wallhaven and Pexels for wallpapers'**
  String get accountWallpaperSourceNames;

  /// About page section title for wallpaper providers.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper sources'**
  String get accountWallpaperSources;

  /// About page explanation of wallpaper providers.
  ///
  /// In en, this message translates to:
  /// **'Prism uses these services to bring you wallpapers.'**
  String get accountWallpaperSourcesMessage;

  /// Subtitle for wallpaper history.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers you set before'**
  String get accountWallpapersSetBefore;

  /// Menu item for the release changelog.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get accountWhatsNew;

  /// About page action to view changes.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S NEW'**
  String get accountWhatsNewAction;

  /// Profile completeness step for writing a bio.
  ///
  /// In en, this message translates to:
  /// **'Write bio'**
  String get accountWriteBio;

  /// Message shown on a profile blocked by the viewer.
  ///
  /// In en, this message translates to:
  /// **'You blocked {name}'**
  String accountYouBlockedUser(String name);

  /// Drawer section heading for the user's content.
  ///
  /// In en, this message translates to:
  /// **'Your content'**
  String get accountYourContent;

  /// Sign-in prompt feature name for the user's profile.
  ///
  /// In en, this message translates to:
  /// **'your profile'**
  String get accountYourProfile;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @adminAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get adminAllCaughtUp;

  /// No description provided for @adminAllUsers.
  ///
  /// In en, this message translates to:
  /// **'All users'**
  String get adminAllUsers;

  /// No description provided for @adminAnnouncementInbox.
  ///
  /// In en, this message translates to:
  /// **'Announcement (inbox)'**
  String get adminAnnouncementInbox;

  /// No description provided for @adminAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get adminAnonymous;

  /// No description provided for @adminApprovalFailed.
  ///
  /// In en, this message translates to:
  /// **'Approval failed. Check your connection, then try again.'**
  String get adminApprovalFailed;

  /// No description provided for @adminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminApprove;

  /// No description provided for @adminApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get adminApproved;

  /// No description provided for @adminBackToReviewList.
  ///
  /// In en, this message translates to:
  /// **'Back to the review list'**
  String get adminBackToReviewList;

  /// No description provided for @adminBatchActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete this review action. Try again.'**
  String get adminBatchActionFailed;

  /// No description provided for @adminBatchComplete.
  ///
  /// In en, this message translates to:
  /// **'Batch complete'**
  String get adminBatchComplete;

  /// No description provided for @adminBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get adminBodyLabel;

  /// No description provided for @adminBodyRequired.
  ///
  /// In en, this message translates to:
  /// **'Body is required'**
  String get adminBodyRequired;

  /// No description provided for @adminBy.
  ///
  /// In en, this message translates to:
  /// **'By'**
  String get adminBy;

  /// No description provided for @adminByCollection.
  ///
  /// In en, this message translates to:
  /// **'By collection'**
  String get adminByCollection;

  /// No description provided for @adminByOperation.
  ///
  /// In en, this message translates to:
  /// **'By operation'**
  String get adminByOperation;

  /// No description provided for @adminBySourceTop15.
  ///
  /// In en, this message translates to:
  /// **'By source (top 15)'**
  String get adminBySourceTop15;

  /// No description provided for @adminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// No description provided for @adminChangeDepthEffect.
  ///
  /// In en, this message translates to:
  /// **'Change Depth Effect'**
  String get adminChangeDepthEffect;

  /// No description provided for @adminCheckConnectionRetry.
  ///
  /// In en, this message translates to:
  /// **'Check your connection, then try again.'**
  String get adminCheckConnectionRetry;

  /// No description provided for @adminClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get adminClose;

  /// No description provided for @adminContentTypeReport.
  ///
  /// In en, this message translates to:
  /// **'{type} report'**
  String adminContentTypeReport(String type);

  /// No description provided for @adminCopyAllData.
  ///
  /// In en, this message translates to:
  /// **'Copy all data'**
  String get adminCopyAllData;

  /// No description provided for @adminCouldNotLoadWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Could not load the wallpaper'**
  String get adminCouldNotLoadWallpaper;

  /// No description provided for @adminCreatorWillSeeFeedback.
  ///
  /// In en, this message translates to:
  /// **'The creator will see this feedback.'**
  String get adminCreatorWillSeeFeedback;

  /// No description provided for @adminDepth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get adminDepth;

  /// No description provided for @adminDepthTier.
  ///
  /// In en, this message translates to:
  /// **'Depth: {tier}'**
  String adminDepthTier(String tier);

  /// Admin label for a wallpaper whose Depth Effect tier is automatic.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get adminDepthTierAuto;

  /// Admin label for a wallpaper whose Depth Effect tier is set from the device menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get adminDepthTierMenu;

  /// Admin label for a wallpaper with no Depth Effect.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get adminDepthTierNone;

  /// Admin label for a wallpaper whose Depth Effect tier has not been checked.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get adminDepthTierNotChecked;

  /// No description provided for @adminDrop.
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get adminDrop;

  /// No description provided for @adminEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get adminEmail;

  /// No description provided for @adminEmailExample.
  ///
  /// In en, this message translates to:
  /// **'user@example.com'**
  String get adminEmailExample;

  /// No description provided for @adminEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get adminEmailRequired;

  /// No description provided for @adminEstimatedDocumentReads.
  ///
  /// In en, this message translates to:
  /// **'Estimated document reads'**
  String get adminEstimatedDocumentReads;

  /// No description provided for @adminEstimatedDocumentWrites.
  ///
  /// In en, this message translates to:
  /// **'Estimated document writes'**
  String get adminEstimatedDocumentWrites;

  /// No description provided for @adminFactLabel.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String adminFactLabel(String label, String value);

  /// No description provided for @adminFirestoreTelemetry.
  ///
  /// In en, this message translates to:
  /// **'Firestore telemetry'**
  String get adminFirestoreTelemetry;

  /// No description provided for @adminFollowersScreen.
  ///
  /// In en, this message translates to:
  /// **'Followers screen'**
  String get adminFollowersScreen;

  /// No description provided for @adminFreeUsers.
  ///
  /// In en, this message translates to:
  /// **'Free users'**
  String get adminFreeUsers;

  /// No description provided for @adminGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get adminGeneral;

  /// No description provided for @adminImageUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'Image URL (optional)'**
  String get adminImageUrlOptional;

  /// No description provided for @adminKeepWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Keep wallpaper'**
  String get adminKeepWallpaper;

  /// No description provided for @adminLast14Days.
  ///
  /// In en, this message translates to:
  /// **'Last 14 days'**
  String get adminLast14Days;

  /// No description provided for @adminList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get adminList;

  /// No description provided for @adminLoadNextBatch.
  ///
  /// In en, this message translates to:
  /// **'Load next batch'**
  String get adminLoadNextBatch;

  /// No description provided for @adminLoadingNotificationCounts.
  ///
  /// In en, this message translates to:
  /// **'Loading notification counts.'**
  String get adminLoadingNotificationCounts;

  /// No description provided for @adminMarkReviewed.
  ///
  /// In en, this message translates to:
  /// **'Mark reviewed'**
  String get adminMarkReviewed;

  /// No description provided for @adminMarkReviewedFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not mark the report reviewed. Try again.'**
  String get adminMarkReviewedFailed;

  /// No description provided for @adminMarkedReviewed.
  ///
  /// In en, this message translates to:
  /// **'Marked reviewed'**
  String get adminMarkedReviewed;

  /// No description provided for @adminModerationDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Looks like a Prism wall · {percent}%'**
  String adminModerationDuplicate(int percent);

  /// No description provided for @adminModerationHint.
  ///
  /// In en, this message translates to:
  /// **'These are hints. Check before you reject.'**
  String get adminModerationHint;

  /// No description provided for @adminModerationLogo.
  ///
  /// In en, this message translates to:
  /// **'Logo: {logo}'**
  String adminModerationLogo(String logo);

  /// No description provided for @adminModerationLogos.
  ///
  /// In en, this message translates to:
  /// **'Logos'**
  String get adminModerationLogos;

  /// No description provided for @adminModerationOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the page.'**
  String get adminModerationOpenFailed;

  /// No description provided for @adminModerationOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Open {host}'**
  String adminModerationOpenPage(String host);

  /// No description provided for @adminModerationSignals.
  ///
  /// In en, this message translates to:
  /// **'Review signals'**
  String get adminModerationSignals;

  /// No description provided for @adminModerationSimilarWall.
  ///
  /// In en, this message translates to:
  /// **'Similar Prism wall'**
  String get adminModerationSimilarWall;

  /// No description provided for @adminModerationSimilarity.
  ///
  /// In en, this message translates to:
  /// **'{percent}% similar'**
  String adminModerationSimilarity(int percent);

  /// No description provided for @adminModerationText.
  ///
  /// In en, this message translates to:
  /// **'Text: {words}'**
  String adminModerationText(String words);

  /// No description provided for @adminModerationTextInImage.
  ///
  /// In en, this message translates to:
  /// **'Text in the image'**
  String get adminModerationTextInImage;

  /// No description provided for @adminModerationUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Unsafe: {categories}'**
  String adminModerationUnsafe(String categories);

  /// No description provided for @adminModerationUnsafeCategories.
  ///
  /// In en, this message translates to:
  /// **'Unsafe categories'**
  String get adminModerationUnsafeCategories;

  /// No description provided for @adminModerationWeb.
  ///
  /// In en, this message translates to:
  /// **'Found on {host}'**
  String adminModerationWeb(String host);

  /// No description provided for @adminModerationWebMore.
  ///
  /// In en, this message translates to:
  /// **'Found on {host} +{more}'**
  String adminModerationWebMore(String host, int more);

  /// No description provided for @adminModerationWebPages.
  ///
  /// In en, this message translates to:
  /// **'Found on the web'**
  String get adminModerationWebPages;

  /// No description provided for @adminNewWallpapersPending.
  ///
  /// In en, this message translates to:
  /// **'New wallpapers show up here when someone uploads one.'**
  String get adminNewWallpapersPending;

  /// No description provided for @adminNoNotificationCounts.
  ///
  /// In en, this message translates to:
  /// **'No notification counts yet.'**
  String get adminNoNotificationCounts;

  /// No description provided for @adminNoOpenReports.
  ///
  /// In en, this message translates to:
  /// **'No open reports'**
  String get adminNoOpenReports;

  /// No description provided for @adminNoReasonGiven.
  ///
  /// In en, this message translates to:
  /// **'No reason given'**
  String get adminNoReasonGiven;

  /// No description provided for @adminNoTelemetryData.
  ///
  /// In en, this message translates to:
  /// **'No telemetry data to copy'**
  String get adminNoTelemetryData;

  /// No description provided for @adminNoTelemetryYet.
  ///
  /// In en, this message translates to:
  /// **'No telemetry yet'**
  String get adminNoTelemetryYet;

  /// No description provided for @adminNoWallpapersPending.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers pending review.'**
  String get adminNoWallpapersPending;

  /// No description provided for @adminNothingToReview.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review'**
  String get adminNothingToReview;

  /// No description provided for @adminNotificationCountExplanation.
  ///
  /// In en, this message translates to:
  /// **'Accepted means Firebase took the push. A push to the account topic and the device token counts twice. It is not a view.'**
  String get adminNotificationCountExplanation;

  /// No description provided for @adminNotificationCountsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load notification counts.'**
  String get adminNotificationCountsLoadError;

  /// No description provided for @adminNotificationIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This notification goes out to everyone in this group. You cannot take it back.'**
  String get adminNotificationIrreversible;

  /// No description provided for @adminNotificationQueueFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not queue the notification. Try again.'**
  String get adminNotificationQueueFailed;

  /// No description provided for @adminNotificationQueued.
  ///
  /// In en, this message translates to:
  /// **'Notification queued. The Cloud Function will send it shortly.'**
  String get adminNotificationQueued;

  /// No description provided for @adminNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get adminNotifications;

  /// No description provided for @adminOpenReportsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load open reports.'**
  String get adminOpenReportsLoadError;

  /// No description provided for @adminOpenWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Open wallpaper'**
  String get adminOpenWallpaper;

  /// No description provided for @adminOperationCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} op} other{{count} ops}}'**
  String adminOperationCount(int count);

  /// No description provided for @adminPendingWallsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load pending wallpapers.'**
  String get adminPendingWallsLoadError;

  /// No description provided for @adminPremiumUsers.
  ///
  /// In en, this message translates to:
  /// **'Premium users'**
  String get adminPremiumUsers;

  /// No description provided for @adminReadCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} read} other{{count} reads}}'**
  String adminReadCount(int count);

  /// No description provided for @adminReasonBlurry.
  ///
  /// In en, this message translates to:
  /// **'Blurry'**
  String get adminReasonBlurry;

  /// No description provided for @adminReasonBlurryBody.
  ///
  /// In en, this message translates to:
  /// **'The image is blurry or heavily compressed. Upload a sharper version.'**
  String get adminReasonBlurryBody;

  /// No description provided for @adminReasonCopyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright'**
  String get adminReasonCopyright;

  /// No description provided for @adminReasonCopyrightBody.
  ///
  /// In en, this message translates to:
  /// **'This image may be the work of someone else. Upload only wallpapers you made or have the rights to.'**
  String get adminReasonCopyrightBody;

  /// No description provided for @adminReasonDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get adminReasonDuplicate;

  /// No description provided for @adminReasonDuplicateBody.
  ///
  /// In en, this message translates to:
  /// **'This wallpaper is a duplicate of one that is already on Prism.'**
  String get adminReasonDuplicateBody;

  /// No description provided for @adminReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Explain what needs to change'**
  String get adminReasonHint;

  /// No description provided for @adminReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get adminReasonLabel;

  /// No description provided for @adminReasonLowResolution.
  ///
  /// In en, this message translates to:
  /// **'Low resolution'**
  String get adminReasonLowResolution;

  /// No description provided for @adminReasonLowResolutionBody.
  ///
  /// In en, this message translates to:
  /// **'The resolution is too low. Upload an image with at least 1080 px on the short side.'**
  String get adminReasonLowResolutionBody;

  /// No description provided for @adminReasonNotWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Not a wallpaper'**
  String get adminReasonNotWallpaper;

  /// No description provided for @adminReasonNotWallpaperBody.
  ///
  /// In en, this message translates to:
  /// **'This image does not work as a phone wallpaper. Use a portrait image that fills the screen.'**
  String get adminReasonNotWallpaperBody;

  /// No description provided for @adminReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get adminReasonOther;

  /// No description provided for @adminReasonWatermark.
  ///
  /// In en, this message translates to:
  /// **'Watermark'**
  String get adminReasonWatermark;

  /// No description provided for @adminReasonWatermarkBody.
  ///
  /// In en, this message translates to:
  /// **'The image has a watermark. Upload a version without it.'**
  String get adminReasonWatermarkBody;

  /// No description provided for @adminRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get adminRefresh;

  /// No description provided for @adminReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminReject;

  /// No description provided for @adminRejectReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a reason before rejecting this item.'**
  String get adminRejectReasonRequired;

  /// No description provided for @adminRejectSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save this decision. Your reason is still here. Try again.'**
  String get adminRejectSaveFailed;

  /// No description provided for @adminRejectWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Reject wallpaper'**
  String get adminRejectWallpaper;

  /// No description provided for @adminRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get adminRemove;

  /// No description provided for @adminRemoveWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Remove wallpaper'**
  String get adminRemoveWallpaper;

  /// No description provided for @adminRemovedFromNextDrop.
  ///
  /// In en, this message translates to:
  /// **'Removed from the next Drop'**
  String get adminRemovedFromNextDrop;

  /// No description provided for @adminReportDismissFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not dismiss the report. Try again.'**
  String get adminReportDismissFailed;

  /// No description provided for @adminReportDismissedKept.
  ///
  /// In en, this message translates to:
  /// **'Report dismissed. Wallpaper kept.'**
  String get adminReportDismissedKept;

  /// No description provided for @adminReported.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get adminReported;

  /// No description provided for @adminReporter.
  ///
  /// In en, this message translates to:
  /// **'Reporter'**
  String get adminReporter;

  /// No description provided for @adminReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminReports;

  /// No description provided for @adminReserve.
  ///
  /// In en, this message translates to:
  /// **'Reserve'**
  String get adminReserve;

  /// No description provided for @adminReserveForDrop.
  ///
  /// In en, this message translates to:
  /// **'Reserve for Drop'**
  String get adminReserveForDrop;

  /// No description provided for @adminReserveUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the Drop reserve. Try again.'**
  String get adminReserveUpdateFailed;

  /// No description provided for @adminReservedForNextDrop.
  ///
  /// In en, this message translates to:
  /// **'Reserved for the next Drop'**
  String get adminReservedForNextDrop;

  /// No description provided for @adminRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminRetry;

  /// No description provided for @adminReviewProgress.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total}'**
  String adminReviewProgress(int current, int total);

  /// No description provided for @adminSendNotification.
  ///
  /// In en, this message translates to:
  /// **'Send notification'**
  String get adminSendNotification;

  /// No description provided for @adminSendToAudience.
  ///
  /// In en, this message translates to:
  /// **'Send to {audience}?'**
  String adminSendToAudience(String audience);

  /// No description provided for @adminSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get adminSkip;

  /// No description provided for @adminSpecificUser.
  ///
  /// In en, this message translates to:
  /// **'Specific user (email)'**
  String get adminSpecificUser;

  /// No description provided for @adminSwipeInstructions.
  ///
  /// In en, this message translates to:
  /// **'Swipe right to approve, left to reject'**
  String get adminSwipeInstructions;

  /// No description provided for @adminSwipeReview.
  ///
  /// In en, this message translates to:
  /// **'Swipe review'**
  String get adminSwipeReview;

  /// No description provided for @adminTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get adminTarget;

  /// No description provided for @adminTelemetryCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard. Paste elsewhere to analyze.'**
  String get adminTelemetryCopied;

  /// No description provided for @adminTelemetryReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read telemetry'**
  String get adminTelemetryReadError;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin moderation'**
  String get adminTitle;

  /// No description provided for @adminTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get adminTitleLabel;

  /// No description provided for @adminTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get adminTitleRequired;

  /// No description provided for @adminTotalEvents.
  ///
  /// In en, this message translates to:
  /// **'Total events'**
  String get adminTotalEvents;

  /// No description provided for @adminTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get adminTryAgain;

  /// No description provided for @adminUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get adminUndo;

  /// No description provided for @adminUndoSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Undo successful'**
  String get adminUndoSuccessful;

  /// No description provided for @adminUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get adminUnknown;

  /// No description provided for @adminUnreserve.
  ///
  /// In en, this message translates to:
  /// **'Unreserve'**
  String get adminUnreserve;

  /// No description provided for @adminUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get adminUntitled;

  /// No description provided for @adminUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get adminUploaded;

  /// No description provided for @adminUseAppForEvents.
  ///
  /// In en, this message translates to:
  /// **'Use the app to generate Firestore events.'**
  String get adminUseAppForEvents;

  /// No description provided for @adminUserEmail.
  ///
  /// In en, this message translates to:
  /// **'User email'**
  String get adminUserEmail;

  /// No description provided for @adminUserReportsShowHere.
  ///
  /// In en, this message translates to:
  /// **'Reports from users show up here.'**
  String get adminUserReportsShowHere;

  /// No description provided for @adminValidEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get adminValidEmailRequired;

  /// No description provided for @adminView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get adminView;

  /// No description provided for @adminViewFullWallpaper.
  ///
  /// In en, this message translates to:
  /// **'View full wallpaper'**
  String get adminViewFullWallpaper;

  /// No description provided for @adminWallId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get adminWallId;

  /// No description provided for @adminWallOfTheDay.
  ///
  /// In en, this message translates to:
  /// **'Wall of the Day'**
  String get adminWallOfTheDay;

  /// No description provided for @adminWallOrUpload.
  ///
  /// In en, this message translates to:
  /// **'Wall or upload'**
  String get adminWallOrUpload;

  /// No description provided for @adminWallpaperAlreadyGone.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper was already gone. Report closed.'**
  String get adminWallpaperAlreadyGone;

  /// No description provided for @adminWallpaperApproved.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper approved'**
  String get adminWallpaperApproved;

  /// No description provided for @adminWallpaperFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper, full screen'**
  String get adminWallpaperFullScreen;

  /// No description provided for @adminWallpaperRejected.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper rejected'**
  String get adminWallpaperRejected;

  /// No description provided for @adminWallpaperRemoved.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper removed'**
  String get adminWallpaperRemoved;

  /// No description provided for @adminWallpaperReport.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper report'**
  String get adminWallpaperReport;

  /// No description provided for @adminWallpaperToReview.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper to review'**
  String get adminWallpaperToReview;

  /// No description provided for @adminWallpapersRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} wallpaper remaining} other{{count} wallpapers remaining}}'**
  String adminWallpapersRemaining(int count);

  /// No description provided for @adminWalls.
  ///
  /// In en, this message translates to:
  /// **'Walls'**
  String get adminWalls;

  /// No description provided for @adminWriteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} write} other{{count} writes}}'**
  String adminWriteCount(int count);

  /// No description provided for @appLinkRetryWhenOnline.
  ///
  /// In en, this message translates to:
  /// **'No connection. We will open this link when you are back online.'**
  String get appLinkRetryWhenOnline;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Prism'**
  String get appTitle;

  /// No description provided for @coreBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get coreBack;

  /// No description provided for @coreBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get coreBio;

  /// No description provided for @coreBlockCreatorAfterReport.
  ///
  /// In en, this message translates to:
  /// **'Also block this creator'**
  String get coreBlockCreatorAfterReport;

  /// No description provided for @coreBothScreens.
  ///
  /// In en, this message translates to:
  /// **'both screens'**
  String get coreBothScreens;

  /// No description provided for @coreCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get coreCancel;

  /// No description provided for @coreCancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get coreCancelSelection;

  /// No description provided for @coreCancelSignIn.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get coreCancelSignIn;

  /// No description provided for @coreCategoryAbstract.
  ///
  /// In en, this message translates to:
  /// **'Abstract'**
  String get coreCategoryAbstract;

  /// No description provided for @coreCategoryAerial.
  ///
  /// In en, this message translates to:
  /// **'Aerial'**
  String get coreCategoryAerial;

  /// No description provided for @coreCategoryAesthetic.
  ///
  /// In en, this message translates to:
  /// **'Aesthetic'**
  String get coreCategoryAesthetic;

  /// No description provided for @coreCategoryAiArt.
  ///
  /// In en, this message translates to:
  /// **'AI Art'**
  String get coreCategoryAiArt;

  /// No description provided for @coreCategoryAnimals.
  ///
  /// In en, this message translates to:
  /// **'Animals'**
  String get coreCategoryAnimals;

  /// No description provided for @coreCategoryAnime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get coreCategoryAnime;

  /// No description provided for @coreCategoryArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get coreCategoryArchitecture;

  /// No description provided for @coreCategoryArtistic.
  ///
  /// In en, this message translates to:
  /// **'Artistic'**
  String get coreCategoryArtistic;

  /// No description provided for @coreCategoryBirds.
  ///
  /// In en, this message translates to:
  /// **'Birds'**
  String get coreCategoryBirds;

  /// No description provided for @coreCategoryCars.
  ///
  /// In en, this message translates to:
  /// **'Cars'**
  String get coreCategoryCars;

  /// No description provided for @coreCategoryCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get coreCategoryCity;

  /// No description provided for @coreCategoryClouds.
  ///
  /// In en, this message translates to:
  /// **'Clouds'**
  String get coreCategoryClouds;

  /// No description provided for @coreCategoryComic.
  ///
  /// In en, this message translates to:
  /// **'Comic'**
  String get coreCategoryComic;

  /// No description provided for @coreCategoryCyberpunk.
  ///
  /// In en, this message translates to:
  /// **'Cyberpunk'**
  String get coreCategoryCyberpunk;

  /// No description provided for @coreCategoryDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get coreCategoryDark;

  /// No description provided for @coreCategoryDefault.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get coreCategoryDefault;

  /// No description provided for @coreCategoryFantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get coreCategoryFantasy;

  /// No description provided for @coreCategoryFashion.
  ///
  /// In en, this message translates to:
  /// **'Fashion'**
  String get coreCategoryFashion;

  /// No description provided for @coreCategoryFlowers.
  ///
  /// In en, this message translates to:
  /// **'Flowers'**
  String get coreCategoryFlowers;

  /// No description provided for @coreCategoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get coreCategoryFood;

  /// No description provided for @coreCategoryForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get coreCategoryForest;

  /// No description provided for @coreCategoryGalaxy.
  ///
  /// In en, this message translates to:
  /// **'Galaxy'**
  String get coreCategoryGalaxy;

  /// No description provided for @coreCategoryGaming.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get coreCategoryGaming;

  /// No description provided for @coreCategoryGradient.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get coreCategoryGradient;

  /// No description provided for @coreCategoryIllustration.
  ///
  /// In en, this message translates to:
  /// **'Illustration'**
  String get coreCategoryIllustration;

  /// No description provided for @coreCategoryKawaii.
  ///
  /// In en, this message translates to:
  /// **'Kawaii'**
  String get coreCategoryKawaii;

  /// No description provided for @coreCategoryLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get coreCategoryLandscape;

  /// No description provided for @coreCategoryMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get coreCategoryMinimal;

  /// No description provided for @coreCategoryMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get coreCategoryMusic;

  /// No description provided for @coreCategoryNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get coreCategoryNature;

  /// No description provided for @coreCategoryNeon.
  ///
  /// In en, this message translates to:
  /// **'Neon'**
  String get coreCategoryNeon;

  /// No description provided for @coreCategoryOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get coreCategoryOcean;

  /// No description provided for @coreCategoryPortraits.
  ///
  /// In en, this message translates to:
  /// **'Portraits'**
  String get coreCategoryPortraits;

  /// No description provided for @coreCategoryQuotes.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get coreCategoryQuotes;

  /// No description provided for @coreCategoryRender3d.
  ///
  /// In en, this message translates to:
  /// **'3D Render'**
  String get coreCategoryRender3d;

  /// No description provided for @coreCategoryRobots.
  ///
  /// In en, this message translates to:
  /// **'Robots'**
  String get coreCategoryRobots;

  /// No description provided for @coreCategoryScenery.
  ///
  /// In en, this message translates to:
  /// **'Scenery'**
  String get coreCategoryScenery;

  /// No description provided for @coreCategorySpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get coreCategorySpace;

  /// No description provided for @coreCategorySpiritual.
  ///
  /// In en, this message translates to:
  /// **'Spiritual'**
  String get coreCategorySpiritual;

  /// No description provided for @coreCategorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get coreCategorySports;

  /// No description provided for @coreCategoryTech.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get coreCategoryTech;

  /// No description provided for @coreCategoryTextures.
  ///
  /// In en, this message translates to:
  /// **'Textures'**
  String get coreCategoryTextures;

  /// No description provided for @coreCategoryUnderTheSea.
  ///
  /// In en, this message translates to:
  /// **'Under the Sea'**
  String get coreCategoryUnderTheSea;

  /// No description provided for @coreCategoryVehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get coreCategoryVehicles;

  /// No description provided for @coreCategoryVintage.
  ///
  /// In en, this message translates to:
  /// **'Vintage'**
  String get coreCategoryVintage;

  /// No description provided for @coreCategoryWarriors.
  ///
  /// In en, this message translates to:
  /// **'Warriors'**
  String get coreCategoryWarriors;

  /// No description provided for @coreChangeWallpaperTarget.
  ///
  /// In en, this message translates to:
  /// **'Change where wallpaper is set'**
  String get coreChangeWallpaperTarget;

  /// No description provided for @coreChangelogLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get coreChangelogLatest;

  /// No description provided for @coreChooseReportReason.
  ///
  /// In en, this message translates to:
  /// **'Choose a reason'**
  String get coreChooseReportReason;

  /// No description provided for @coreChooseUsername.
  ///
  /// In en, this message translates to:
  /// **'Pick an available username.'**
  String get coreChooseUsername;

  /// No description provided for @coreCoinAiWallpaper.
  ///
  /// In en, this message translates to:
  /// **'AI wallpaper'**
  String get coreCoinAiWallpaper;

  /// No description provided for @coreCoinAutoRotatePass.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate pass, 7 days'**
  String get coreCoinAutoRotatePass;

  /// No description provided for @coreCoinBadgeReward.
  ///
  /// In en, this message translates to:
  /// **'Badge reward'**
  String get coreCoinBadgeReward;

  /// Screen reader label for the current coin balance.
  ///
  /// In en, this message translates to:
  /// **'{coins} Prism coins'**
  String coreCoinBalance(int coins);

  /// Screen reader label for a changed coin balance.
  ///
  /// In en, this message translates to:
  /// **'{balance}, {change}'**
  String coreCoinBalanceChange(String balance, String change);

  /// No description provided for @coreCoinBoost.
  ///
  /// In en, this message translates to:
  /// **'Boost'**
  String get coreCoinBoost;

  /// No description provided for @coreCoinCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get coreCoinCoins;

  /// No description provided for @coreCoinCoinsReturned.
  ///
  /// In en, this message translates to:
  /// **'Coins returned'**
  String get coreCoinCoinsReturned;

  /// No description provided for @coreCoinCollectionPreview.
  ///
  /// In en, this message translates to:
  /// **'Collection preview, 24 h'**
  String get coreCoinCollectionPreview;

  /// No description provided for @coreCoinDailyChest.
  ///
  /// In en, this message translates to:
  /// **'Daily chest'**
  String get coreCoinDailyChest;

  /// No description provided for @coreCoinDailyStreak.
  ///
  /// In en, this message translates to:
  /// **'Daily streak'**
  String get coreCoinDailyStreak;

  /// Daily reward row label in coin history.
  ///
  /// In en, this message translates to:
  /// **'Daily streak, day {day}'**
  String coreCoinDailyStreakDay(String day);

  /// No description provided for @coreCoinDay7Chest.
  ///
  /// In en, this message translates to:
  /// **'Day 7 chest'**
  String get coreCoinDay7Chest;

  /// No description provided for @coreCoinDrawTicket.
  ///
  /// In en, this message translates to:
  /// **'Draw ticket'**
  String get coreCoinDrawTicket;

  /// No description provided for @coreCoinDropPack.
  ///
  /// In en, this message translates to:
  /// **'Drop pack'**
  String get coreCoinDropPack;

  /// No description provided for @coreCoinDropWall.
  ///
  /// In en, this message translates to:
  /// **'Drop wall'**
  String get coreCoinDropWall;

  /// No description provided for @coreCoinFirstUpload.
  ///
  /// In en, this message translates to:
  /// **'First upload'**
  String get coreCoinFirstUpload;

  /// No description provided for @coreCoinGiftPass.
  ///
  /// In en, this message translates to:
  /// **'Gift: 24 h pass'**
  String get coreCoinGiftPass;

  /// No description provided for @coreCoinInviteReward.
  ///
  /// In en, this message translates to:
  /// **'Invite reward'**
  String get coreCoinInviteReward;

  /// No description provided for @coreCoinLiveWallpaperStyle.
  ///
  /// In en, this message translates to:
  /// **'Live wallpaper style'**
  String get coreCoinLiveWallpaperStyle;

  /// No description provided for @coreCoinPremiumFilter.
  ///
  /// In en, this message translates to:
  /// **'Premium filter'**
  String get coreCoinPremiumFilter;

  /// No description provided for @coreCoinPremiumWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Premium wallpaper'**
  String get coreCoinPremiumWallpaper;

  /// No description provided for @coreCoinProDailyBonus.
  ///
  /// In en, this message translates to:
  /// **'Pro daily bonus'**
  String get coreCoinProDailyBonus;

  /// No description provided for @coreCoinProSpin.
  ///
  /// In en, this message translates to:
  /// **'Pro spin'**
  String get coreCoinProSpin;

  /// No description provided for @coreCoinProStreakBonus.
  ///
  /// In en, this message translates to:
  /// **'Pro streak bonus'**
  String get coreCoinProStreakBonus;

  /// No description provided for @coreCoinProfileComplete.
  ///
  /// In en, this message translates to:
  /// **'Profile complete'**
  String get coreCoinProfileComplete;

  /// No description provided for @coreCoinQuest.
  ///
  /// In en, this message translates to:
  /// **'Quest'**
  String get coreCoinQuest;

  /// Refund row label in coin history.
  ///
  /// In en, this message translates to:
  /// **'Refund: {target}'**
  String coreCoinRefund(String target);

  /// No description provided for @coreCoinShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get coreCoinShop;

  /// No description provided for @coreCoinSpinWheel.
  ///
  /// In en, this message translates to:
  /// **'Spin the wheel'**
  String get coreCoinSpinWheel;

  /// No description provided for @coreCoinStreakFreeze.
  ///
  /// In en, this message translates to:
  /// **'Streak freeze'**
  String get coreCoinStreakFreeze;

  /// No description provided for @coreCoinStreakRestore.
  ///
  /// In en, this message translates to:
  /// **'Streak restore'**
  String get coreCoinStreakRestore;

  /// No description provided for @coreCoinWallpaperDownload.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper download'**
  String get coreCoinWallpaperDownload;

  /// No description provided for @coreCoinWatchedVideo.
  ///
  /// In en, this message translates to:
  /// **'Watched a video'**
  String get coreCoinWatchedVideo;

  /// No description provided for @coreCoinWeekBonus.
  ///
  /// In en, this message translates to:
  /// **'Week bonus'**
  String get coreCoinWeekBonus;

  /// Localized name for the black search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get coreColorBlack;

  /// Localized name for the blue search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get coreColorBlue;

  /// Localized name for the brown search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get coreColorBrown;

  /// Localized name for the green search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get coreColorGreen;

  /// Localized name for the grey search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get coreColorGrey;

  /// Localized name for the orange search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get coreColorOrange;

  /// Localized name for the pink search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get coreColorPink;

  /// Localized name for the purple search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get coreColorPurple;

  /// Localized name for the red search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get coreColorRed;

  /// Localized name for the teal search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get coreColorTeal;

  /// Localized name for the white search palette colour.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get coreColorWhite;

  /// Localized name for the yellow search palette colour.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get coreColorYellow;

  /// No description provided for @coreConfirmWallpaperPreview.
  ///
  /// In en, this message translates to:
  /// **'Confirm the wallpaper in the system preview.'**
  String get coreConfirmWallpaperPreview;

  /// No description provided for @coreContentNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'That item is no longer available'**
  String get coreContentNotAvailable;

  /// No description provided for @coreContentReportUser.
  ///
  /// In en, this message translates to:
  /// **'user'**
  String get coreContentReportUser;

  /// No description provided for @coreContentReportWallpaper.
  ///
  /// In en, this message translates to:
  /// **'wallpaper'**
  String get coreContentReportWallpaper;

  /// Prompt for the selected report target type.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this {contentType}?'**
  String coreContentReportWhy(String contentType);

  /// Prompt for reporting a target with a title or subtitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this {contentType} ({details})?'**
  String coreContentReportWhyWithDetails(String contentType, String details);

  /// No description provided for @coreContinueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get coreContinueWithApple;

  /// No description provided for @coreContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get coreContinueWithGoogle;

  /// No description provided for @coreContributorCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load this profile'**
  String get coreContributorCouldNotLoad;

  /// No description provided for @coreContributorGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get coreContributorGithub;

  /// No description provided for @coreContributorTwitter.
  ///
  /// In en, this message translates to:
  /// **'Twitter'**
  String get coreContributorTwitter;

  /// No description provided for @coreContributorWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get coreContributorWebsite;

  /// No description provided for @coreCouldNotLoadChangelog.
  ///
  /// In en, this message translates to:
  /// **'Could not load the changelog'**
  String get coreCouldNotLoadChangelog;

  /// No description provided for @coreCouldNotLoadWallpaperForEditing.
  ///
  /// In en, this message translates to:
  /// **'Could not load wallpaper for editing'**
  String get coreCouldNotLoadWallpaperForEditing;

  /// No description provided for @coreCouldNotUpdateFavourites.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update favourites. Try again.'**
  String get coreCouldNotUpdateFavourites;

  /// No description provided for @coreCreatorPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Check out this creator profile on Prism.'**
  String get coreCreatorPreviewDescription;

  /// Default title for the home feed banner when Remote Config has no campaign copy.
  ///
  /// In en, this message translates to:
  /// **'Join our Telegram'**
  String get coreDefaultBanner;

  /// No description provided for @coreDepthEffectAutoLongTip.
  ///
  /// In en, this message translates to:
  /// **'Depth Effect turns on by itself. On iOS 18 or older, keep widgets off the space under the clock.'**
  String get coreDepthEffectAutoLongTip;

  /// No description provided for @coreDepthEffectAutoTip.
  ///
  /// In en, this message translates to:
  /// **'Depth Effect turns on by itself.'**
  String get coreDepthEffectAutoTip;

  /// No description provided for @coreDepthEffectBadge.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get coreDepthEffectBadge;

  /// No description provided for @coreDepthEffectBadgeSemantic.
  ///
  /// In en, this message translates to:
  /// **'Works with Depth Effect'**
  String get coreDepthEffectBadgeSemantic;

  /// No description provided for @coreDepthEffectMenuShortTip.
  ///
  /// In en, this message translates to:
  /// **'Tap ••• then Depth Effect.'**
  String get coreDepthEffectMenuShortTip;

  /// No description provided for @coreDepthEffectMenuTip.
  ///
  /// In en, this message translates to:
  /// **'In the Lock Screen editor, tap ••• then Depth Effect.'**
  String get coreDepthEffectMenuTip;

  /// Spatial Scene text: coreSpatialBadge.
  ///
  /// In en, this message translates to:
  /// **'Spatial'**
  String get coreSpatialBadge;

  /// Spatial Scene text: coreSpatialBadgeSemantic.
  ///
  /// In en, this message translates to:
  /// **'Works as a Spatial Scene'**
  String get coreSpatialBadgeSemantic;

  /// Spatial Scene text: coreSpatialSceneTip.
  ///
  /// In en, this message translates to:
  /// **'In the Lock Screen editor, tap the Spatial Scene button.'**
  String get coreSpatialSceneTip;

  /// No description provided for @coreDeviceCannotSetScreen.
  ///
  /// In en, this message translates to:
  /// **'This device can\'t set that screen.'**
  String get coreDeviceCannotSetScreen;

  /// No description provided for @coreDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get coreDone;

  /// Decrease direction for coin balance accessibility text.
  ///
  /// In en, this message translates to:
  /// **'down {coins}'**
  String coreDown(int coins);

  /// No description provided for @coreDownloadNotFinishedCoinsReturned.
  ///
  /// In en, this message translates to:
  /// **'Your last download did not finish. Coins returned.'**
  String get coreDownloadNotFinishedCoinsReturned;

  /// No description provided for @coreDownloadPrismPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Download Prism to discover beautiful wallpapers.'**
  String get coreDownloadPrismPreviewDescription;

  /// No description provided for @coreEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get coreEdit;

  /// No description provided for @coreEditBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell people about yourself…'**
  String get coreEditBioHint;

  /// No description provided for @coreEditDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits have not been saved.'**
  String get coreEditDiscardBody;

  /// No description provided for @coreEditDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get coreEditDiscardTitle;

  /// No description provided for @coreEditEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get coreEditEmailInvalid;

  /// Validation error for a named profile link.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid {kind} link.'**
  String coreEditKindLinkInvalid(String kind);

  /// No description provided for @coreEditLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid link.'**
  String get coreEditLinkInvalid;

  /// No description provided for @coreEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get coreEditProfile;

  /// Label for a profile link field.
  ///
  /// In en, this message translates to:
  /// **'{kind} link'**
  String coreEditProfileLink(String kind);

  /// No description provided for @coreEditRemoveBioTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove bio?'**
  String get coreEditRemoveBioTitle;

  /// No description provided for @coreEditRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get coreEditRemoveConfirm;

  /// Confirmation title when removing a profile item.
  ///
  /// In en, this message translates to:
  /// **'Remove {item}?'**
  String coreEditRemoveTitle(String item);

  /// No description provided for @coreEditUsernameAvailable.
  ///
  /// In en, this message translates to:
  /// **'Username available'**
  String get coreEditUsernameAvailable;

  /// No description provided for @coreEditUsernameChars.
  ///
  /// In en, this message translates to:
  /// **'Use letters, numbers and underscores only.'**
  String get coreEditUsernameChars;

  /// No description provided for @coreEditUsernameAllCaps.
  ///
  /// In en, this message translates to:
  /// **'Use at least one lowercase letter.'**
  String get coreEditUsernameAllCaps;

  /// Username minimum length validation error.
  ///
  /// In en, this message translates to:
  /// **'Use at least {length} characters.'**
  String coreEditUsernameMinLength(int length);

  /// Username format requirement shown on profile editing.
  ///
  /// In en, this message translates to:
  /// **'Use {length} or more letters, numbers or underscores (_).'**
  String coreEditUsernameRule(int length);

  /// No description provided for @coreEditUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is taken.'**
  String get coreEditUsernameTaken;

  /// No description provided for @coreEditUsernameTakenSemantic.
  ///
  /// In en, this message translates to:
  /// **'Username taken'**
  String get coreEditUsernameTakenSemantic;

  /// No description provided for @coreFavourite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get coreFavourite;

  /// Megabyte file size shown in wallpaper details.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String coreFileSizeMegabytes(String size);

  /// No description provided for @coreGenericSignInError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong, please try again!'**
  String get coreGenericSignInError;

  /// No description provided for @coreGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get coreGoHome;

  /// No description provided for @coreGooglePlayServicesSignInError.
  ///
  /// In en, this message translates to:
  /// **'Google Play services on this device cannot sign in.'**
  String get coreGooglePlayServicesSignInError;

  /// No description provided for @coreGoogleSignInNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Check your connection and try again.'**
  String get coreGoogleSignInNetworkError;

  /// No description provided for @coreHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'home screen'**
  String get coreHomeScreen;

  /// No description provided for @coreHomeScreenSetupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Home screen setups are no longer available.'**
  String get coreHomeScreenSetupUnavailable;

  /// No description provided for @coreInvalidLinkBody.
  ///
  /// In en, this message translates to:
  /// **'The link you opened is invalid or no longer available.'**
  String get coreInvalidLinkBody;

  /// Referral link preview title.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you to Prism'**
  String coreInvitedToPrismTitle(String name);

  /// No description provided for @coreIosWallpaperGuideBody.
  ///
  /// In en, this message translates to:
  /// **'iOS does not let apps change your wallpaper. Finish in Photos:'**
  String get coreIosWallpaperGuideBody;

  /// No description provided for @coreJoinPrismPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Prism'**
  String get coreJoinPrismPreviewTitle;

  /// No description provided for @coreKeepPrismOpen.
  ///
  /// In en, this message translates to:
  /// **'Keep Prism open and try again.'**
  String get coreKeepPrismOpen;

  /// No description provided for @coreLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get coreLoading;

  /// No description provided for @coreLoadingMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more. Tap to retry'**
  String get coreLoadingMoreFailed;

  /// No description provided for @coreLoadingWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Loading wallpaper'**
  String get coreLoadingWallpaper;

  /// No description provided for @coreLockScreen.
  ///
  /// In en, this message translates to:
  /// **'lock screen'**
  String get coreLockScreen;

  /// No description provided for @coreMatchAccent.
  ///
  /// In en, this message translates to:
  /// **'Match accent'**
  String get coreMatchAccent;

  /// No description provided for @coreName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get coreName;

  /// No description provided for @coreNoWallpaperUrl.
  ///
  /// In en, this message translates to:
  /// **'No wallpaper URL available'**
  String get coreNoWallpaperUrl;

  /// No description provided for @coreNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get coreNotNow;

  /// No description provided for @coreOpenPhotos.
  ///
  /// In en, this message translates to:
  /// **'Open Photos'**
  String get coreOpenPhotos;

  /// No description provided for @coreOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get coreOpenSettings;

  /// No description provided for @corePairPickerDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get corePairPickerDownloads;

  /// No description provided for @corePairPickerFavourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get corePairPickerFavourites;

  /// No description provided for @corePairPickerHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get corePairPickerHistory;

  /// No description provided for @corePairPickerNoDownloads.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet.'**
  String get corePairPickerNoDownloads;

  /// No description provided for @corePairPickerNoFavourites.
  ///
  /// In en, this message translates to:
  /// **'No favourites yet.'**
  String get corePairPickerNoFavourites;

  /// No description provided for @corePairPickerNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet.'**
  String get corePairPickerNoHistory;

  /// No description provided for @corePairPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a lock screen wallpaper'**
  String get corePairPickerTitle;

  /// No description provided for @corePairPickerUseWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Use this wallpaper for the lock screen'**
  String get corePairPickerUseWallpaper;

  /// No description provided for @corePhotosPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow Prism to add photos in Settings to save wallpapers.'**
  String get corePhotosPermissionMessage;

  /// No description provided for @corePhotosStepOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Photos.'**
  String get corePhotosStepOpen;

  /// No description provided for @corePhotosStepShare.
  ///
  /// In en, this message translates to:
  /// **'Tap Share.'**
  String get corePhotosStepShare;

  /// No description provided for @corePhotosStepUseAsWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Tap Use as Wallpaper.'**
  String get corePhotosStepUseAsWallpaper;

  /// Version message in the changelog sheet.
  ///
  /// In en, this message translates to:
  /// **'You are on version {version}.'**
  String corePopupAppVersion(String version);

  /// Warning shown before removing profile information.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get corePopupCannotUndo;

  /// Item name in the cover photo removal confirmation.
  ///
  /// In en, this message translates to:
  /// **'cover photo'**
  String get corePopupCoverPhoto;

  /// Confirmation action for discarding profile edits.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get corePopupDiscard;

  /// Item name in the profile photo removal confirmation.
  ///
  /// In en, this message translates to:
  /// **'profile photo'**
  String get corePopupProfilePhoto;

  /// Title for the app changelog sheet.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get corePopupWhatsNew;

  /// No description provided for @corePreviousWallpaperRestored.
  ///
  /// In en, this message translates to:
  /// **'Previous wallpaper restored'**
  String get corePreviousWallpaperRestored;

  /// No description provided for @coreProfileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile. Please try again.'**
  String get coreProfileSaveFailed;

  /// No description provided for @coreProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get coreProfileUpdated;

  /// Toast after a referral is recorded for a signed-out user.
  ///
  /// In en, this message translates to:
  /// **'Referral saved. Sign in to claim +{coins} coins.'**
  String coreReferralSaved(int coins);

  /// No description provided for @coreRelativeTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day ago} other{{count} days ago}}'**
  String coreRelativeTimeDaysAgo(int count);

  /// No description provided for @coreRelativeTimeDaysFromNow.
  ///
  /// In en, this message translates to:
  /// **'in {count, plural, one{1 day} other{{count} days}}'**
  String coreRelativeTimeDaysFromNow(int count);

  /// No description provided for @coreRelativeTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 hour ago} other{{count} hours ago}}'**
  String coreRelativeTimeHoursAgo(int count);

  /// No description provided for @coreRelativeTimeHoursFromNow.
  ///
  /// In en, this message translates to:
  /// **'in {count, plural, one{1 hour} other{{count} hours}}'**
  String coreRelativeTimeHoursFromNow(int count);

  /// No description provided for @coreRelativeTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get coreRelativeTimeJustNow;

  /// No description provided for @coreRelativeTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 minute ago} other{{count} minutes ago}}'**
  String coreRelativeTimeMinutesAgo(int count);

  /// No description provided for @coreRelativeTimeMinutesFromNow.
  ///
  /// In en, this message translates to:
  /// **'in {count, plural, one{1 minute} other{{count} minutes}}'**
  String coreRelativeTimeMinutesFromNow(int count);

  /// No description provided for @coreRemoveBio.
  ///
  /// In en, this message translates to:
  /// **'Remove bio'**
  String get coreRemoveBio;

  /// No description provided for @coreReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get coreReport;

  /// No description provided for @coreReportCouldNotSubmit.
  ///
  /// In en, this message translates to:
  /// **'Could not submit your report. Please try again.'**
  String get coreReportCouldNotSubmit;

  /// No description provided for @coreReportDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Anything else we should know'**
  String get coreReportDetailsHint;

  /// No description provided for @coreReportDetailsOptional.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get coreReportDetailsOptional;

  /// No description provided for @coreReportReasonCopyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright / ownership'**
  String get coreReportReasonCopyright;

  /// No description provided for @coreReportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or hate'**
  String get coreReportReasonHarassment;

  /// No description provided for @coreReportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get coreReportReasonOther;

  /// No description provided for @coreReportReasonSexual.
  ///
  /// In en, this message translates to:
  /// **'Sexual or adult content'**
  String get coreReportReasonSexual;

  /// No description provided for @coreReportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or misleading'**
  String get coreReportReasonSpam;

  /// No description provided for @coreReportSent.
  ///
  /// In en, this message translates to:
  /// **'Report sent. Thank you.'**
  String get coreReportSent;

  /// No description provided for @coreRestorePreviousWallpaperFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the previous wallpaper. Set it again from Wallpaper history.'**
  String get coreRestorePreviousWallpaperFailed;

  /// No description provided for @coreRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get coreRetry;

  /// No description provided for @coreRetryImage.
  ///
  /// In en, this message translates to:
  /// **'Retry image'**
  String get coreRetryImage;

  /// Retry action for one screen after a partial wallpaper set.
  ///
  /// In en, this message translates to:
  /// **'Retry {screen}'**
  String coreRetryOnScreen(String screen);

  /// No description provided for @coreSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get coreSaveChanges;

  /// No description provided for @coreSeeFullChangelog.
  ///
  /// In en, this message translates to:
  /// **'See the full changelog'**
  String get coreSeeFullChangelog;

  /// No description provided for @coreSeeMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get coreSeeMore;

  /// Accessible count of selected items.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String coreSelectCount(int count);

  /// No description provided for @coreSendReport.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get coreSendReport;

  /// No description provided for @coreSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get coreSet;

  /// No description provided for @coreSetItAsWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set it as your wallpaper'**
  String get coreSetItAsWallpaper;

  /// No description provided for @coreSetWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set as wallpaper'**
  String get coreSetWallpaper;

  /// Accessible action label for setting a wallpaper on a selected screen.
  ///
  /// In en, this message translates to:
  /// **'Set as wallpaper on {screen}'**
  String coreSetWallpaperOn(String screen);

  /// No description provided for @coreShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get coreShare;

  /// Text shared with a wallpaper image card.
  ///
  /// In en, this message translates to:
  /// **'🔥Check this out ➜ {link}'**
  String coreShareCardClipboard(String link);

  /// No description provided for @coreShareFormatStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get coreShareFormatStory;

  /// No description provided for @coreShareFormatPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get coreShareFormatPost;

  /// No description provided for @coreShareFormatClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get coreShareFormatClean;

  /// No description provided for @coreShareTargetInstagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get coreShareTargetInstagram;

  /// No description provided for @coreShareTargetCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get coreShareTargetCopyLink;

  /// No description provided for @coreShareTargetSaveImage.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get coreShareTargetSaveImage;

  /// No description provided for @coreShareTargetMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get coreShareTargetMore;

  /// Byline on a shared wallpaper image. creator is a handle such as @maya.
  ///
  /// In en, this message translates to:
  /// **'by {creator}'**
  String coreShareCardBy(String creator);

  /// No description provided for @coreShareImageSaved.
  ///
  /// In en, this message translates to:
  /// **'Image saved'**
  String get coreShareImageSaved;

  /// No description provided for @coreShareImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the image. Try again.'**
  String get coreShareImageFailed;

  /// No description provided for @coreShareInstagramFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Instagram. Try again.'**
  String get coreShareInstagramFailed;

  /// No description provided for @coreSharePreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make this image. More shares the link instead.'**
  String get coreSharePreviewFailed;

  /// No description provided for @coreShareLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Sharing link copied!'**
  String get coreShareLinkCopied;

  /// Share-sheet text for the user's profile link.
  ///
  /// In en, this message translates to:
  /// **'Hey check out my profile on Prism ➜ {link}'**
  String coreShareProfileClipboard(String link);

  /// Clipboard text for a wallpaper share link.
  ///
  /// In en, this message translates to:
  /// **'Hey check this out ➜ {link}'**
  String coreShareWallpaperClipboard(String link);

  /// No description provided for @coreShareWallpaperGeneric.
  ///
  /// In en, this message translates to:
  /// **'This bundled wallpaper is available in the Prism app.'**
  String get coreShareWallpaperGeneric;

  /// No description provided for @coreSignInFeatureBody.
  ///
  /// In en, this message translates to:
  /// **'Your account keeps your coins, favourites and uploads in one place.'**
  String get coreSignInFeatureBody;

  /// Sign-in requirement heading for a feature.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use {feature}'**
  String coreSignInFeatureTitle(String feature);

  /// No description provided for @coreSignInPopupBody.
  ///
  /// In en, this message translates to:
  /// **'Keep your favourites, uploads and coins on every device.'**
  String get coreSignInPopupBody;

  /// No description provided for @coreSignInPopupTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Prism'**
  String get coreSignInPopupTitle;

  /// No description provided for @coreSignInPromptAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get coreSignInPromptAction;

  /// No description provided for @coreSignInToReportContent.
  ///
  /// In en, this message translates to:
  /// **'Sign in to report content'**
  String get coreSignInToReportContent;

  /// No description provided for @coreSignInToSyncFavourites.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your favourites on every device'**
  String get coreSignInToSyncFavourites;

  /// No description provided for @coreSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get coreSigningIn;

  /// No description provided for @coreSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get coreSomethingWentWrong;

  /// Next streak reward label.
  ///
  /// In en, this message translates to:
  /// **'Next +{coins}'**
  String coreStreakNext(int coins);

  /// Screen reader summary of streak and next reward.
  ///
  /// In en, this message translates to:
  /// **'{days} day streak, next reward {coins} coins'**
  String coreStreakSemantics(int days, int coins);

  /// Label for the custom accent color option.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get coreCustomAccent;

  /// Label for the hex color code text field.
  ///
  /// In en, this message translates to:
  /// **'Hex code'**
  String get coreCustomAccentHex;

  /// Label for the hue slider of the custom accent color picker.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get coreCustomAccentHue;

  /// Label for the saturation slider of the custom accent color picker.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get coreCustomAccentSaturation;

  /// Label for the lightness slider of the custom accent color picker.
  ///
  /// In en, this message translates to:
  /// **'Lightness'**
  String get coreCustomAccentLightness;

  /// Error shown when the hex color code is not 6 hex digits.
  ///
  /// In en, this message translates to:
  /// **'Enter 6 hex digits, like #E57697.'**
  String get coreCustomAccentInvalidHex;

  /// Warning shown when the custom accent is too close to the theme background.
  ///
  /// In en, this message translates to:
  /// **'This color is hard to see on this theme. Pick a lighter or darker shade.'**
  String get coreCustomAccentLowContrast;

  /// Button label that applies the custom accent color.
  ///
  /// In en, this message translates to:
  /// **'Use color'**
  String get coreCustomAccentApply;

  /// Accessibility label for a selectable system accent colour.
  ///
  /// In en, this message translates to:
  /// **'Accent colour {index} of {count}'**
  String coreThemeAccentSemanticLabel(int index, int count);

  /// No description provided for @coreThemeAmoled.
  ///
  /// In en, this message translates to:
  /// **'AMOLED'**
  String get coreThemeAmoled;

  /// No description provided for @coreThemeCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get coreThemeCoffee;

  /// No description provided for @coreThemeCottonBlue.
  ///
  /// In en, this message translates to:
  /// **'Cotton Blue'**
  String get coreThemeCottonBlue;

  /// No description provided for @coreThemeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom theme'**
  String get coreThemeCustom;

  /// No description provided for @coreThemeDeepOcean.
  ///
  /// In en, this message translates to:
  /// **'Deep Ocean'**
  String get coreThemeDeepOcean;

  /// No description provided for @coreThemeFrostWhite.
  ///
  /// In en, this message translates to:
  /// **'Frost White'**
  String get coreThemeFrostWhite;

  /// No description provided for @coreThemeJungle.
  ///
  /// In en, this message translates to:
  /// **'Jungle'**
  String get coreThemeJungle;

  /// No description provided for @coreThemeLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get coreThemeLocked;

  /// No description provided for @coreThemeMaterialDark.
  ///
  /// In en, this message translates to:
  /// **'Material Dark'**
  String get coreThemeMaterialDark;

  /// No description provided for @coreThemeMaterialYou.
  ///
  /// In en, this message translates to:
  /// **'Material You'**
  String get coreThemeMaterialYou;

  /// No description provided for @coreThemeOlive.
  ///
  /// In en, this message translates to:
  /// **'Olive'**
  String get coreThemeOlive;

  /// No description provided for @coreThemePepper.
  ///
  /// In en, this message translates to:
  /// **'Pepper'**
  String get coreThemePepper;

  /// No description provided for @coreThemeRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get coreThemeRose;

  /// No description provided for @coreThemeSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get coreThemeSky;

  /// No description provided for @coreThemeSteel.
  ///
  /// In en, this message translates to:
  /// **'Steel'**
  String get coreThemeSteel;

  /// No description provided for @coreThemeSpooky.
  ///
  /// In en, this message translates to:
  /// **'Spooky'**
  String get coreThemeSpooky;

  /// No description provided for @spookyBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'The Spooky theme is here'**
  String get spookyBannerTitle;

  /// No description provided for @spookyBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Orange, black and a few spiders. Free. Tap to try it.'**
  String get spookyBannerSubtitle;

  /// No description provided for @spookyAnnouncementTitle.
  ///
  /// In en, this message translates to:
  /// **'New: the Spooky theme 🎃'**
  String get spookyAnnouncementTitle;

  /// No description provided for @spookyAnnouncementBody.
  ///
  /// In en, this message translates to:
  /// **'Orange, black and a few spiders. It is free. Tap to try it.'**
  String get spookyAnnouncementBody;

  /// No description provided for @coreThemeDiwali.
  ///
  /// In en, this message translates to:
  /// **'Diwali'**
  String get coreThemeDiwali;

  /// No description provided for @diwaliBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'The Diwali theme is here'**
  String get diwaliBannerTitle;

  /// No description provided for @diwaliBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Diyas, fireworks and gold. Free. Tap to try it.'**
  String get diwaliBannerSubtitle;

  /// No description provided for @diwaliAnnouncementTitle.
  ///
  /// In en, this message translates to:
  /// **'New: the Diwali theme 🪔'**
  String get diwaliAnnouncementTitle;

  /// No description provided for @diwaliAnnouncementBody.
  ///
  /// In en, this message translates to:
  /// **'Diyas, fireworks and gold. It is free. Tap to try it.'**
  String get diwaliAnnouncementBody;

  /// No description provided for @coreThisPageDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'This page does not exist'**
  String get coreThisPageDoesNotExist;

  /// No description provided for @coreTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get coreTryAgain;

  /// No description provided for @coreUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get coreUndo;

  /// Increase direction for coin balance accessibility text.
  ///
  /// In en, this message translates to:
  /// **'up {coins}'**
  String coreUp(int coins);

  /// No description provided for @coreUploadFailureDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'You reached today’s upload limit. Try again tomorrow.'**
  String get coreUploadFailureDailyLimit;

  /// No description provided for @coreUploadFailureFileType.
  ///
  /// In en, this message translates to:
  /// **'That file type is not supported. Use a JPG, PNG, WebP or HEIC image.'**
  String get coreUploadFailureFileType;

  /// No description provided for @coreUploadFailureGeneric.
  ///
  /// In en, this message translates to:
  /// **'The upload did not finish. Your image is still here, so you can try again.'**
  String get coreUploadFailureGeneric;

  /// No description provided for @coreUploadFailureInProgress.
  ///
  /// In en, this message translates to:
  /// **'An upload is already in progress. Wait a moment, then try again.'**
  String get coreUploadFailureInProgress;

  /// No description provided for @coreUploadFailureOversize.
  ///
  /// In en, this message translates to:
  /// **'This image is over 15 MB. Choose a smaller one.'**
  String get coreUploadFailureOversize;

  /// No description provided for @coreUploadFailureSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to upload.'**
  String get coreUploadFailureSignIn;

  /// No description provided for @coreUploadFailureWeeklyLimit.
  ///
  /// In en, this message translates to:
  /// **'You reached this week’s free upload limit.'**
  String get coreUploadFailureWeeklyLimit;

  /// No description provided for @coreUploadSubmittedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your wall is submitted and is under review.'**
  String get coreUploadSubmittedSuccess;

  /// No description provided for @coreUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get coreUsername;

  /// No description provided for @coreUsernameCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check the username. Try again.'**
  String get coreUsernameCheckFailed;

  /// No description provided for @coreUsernameRequiredToShareProfile.
  ///
  /// In en, this message translates to:
  /// **'Set a username to share your profile'**
  String get coreUsernameRequiredToShareProfile;

  /// No description provided for @coreWallpaperApplied.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper set successfully!'**
  String get coreWallpaperApplied;

  /// No description provided for @coreWallpaperBothScreens.
  ///
  /// In en, this message translates to:
  /// **'Both screens'**
  String get coreWallpaperBothScreens;

  /// Screen reader label for a wallpaper uploaded by a named creator.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper by {name}'**
  String coreWallpaperBySemanticLabel(String name);

  /// No description provided for @coreWallpaperDownloadedPictures.
  ///
  /// In en, this message translates to:
  /// **'Wall downloaded in Pictures/Prism!'**
  String get coreWallpaperDownloadedPictures;

  /// No description provided for @coreWallpaperEditApplyColorFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply the colour. Try again.'**
  String get coreWallpaperEditApplyColorFailed;

  /// No description provided for @coreWallpaperErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set the wallpaper.'**
  String get coreWallpaperErrorGeneric;

  /// No description provided for @coreWallpaperErrorImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This image is too large for your device to set.'**
  String get coreWallpaperErrorImageTooLarge;

  /// No description provided for @coreWallpaperErrorInvalidVideo.
  ///
  /// In en, this message translates to:
  /// **'That video cannot be played as a wallpaper. Try another clip.'**
  String get coreWallpaperErrorInvalidVideo;

  /// No description provided for @coreWallpaperErrorLiveGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set the live wallpaper. Try again.'**
  String get coreWallpaperErrorLiveGeneric;

  /// No description provided for @coreWallpaperErrorMemory.
  ///
  /// In en, this message translates to:
  /// **'Not enough memory. Close other apps and try again.'**
  String get coreWallpaperErrorMemory;

  /// No description provided for @coreWallpaperErrorNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Your device or work profile does not allow wallpaper changes.'**
  String get coreWallpaperErrorNotAllowed;

  /// No description provided for @coreWallpaperErrorPermission.
  ///
  /// In en, this message translates to:
  /// **'Prism does not have permission to read that file.'**
  String get coreWallpaperErrorPermission;

  /// No description provided for @coreWallpaperErrorReadFile.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the file. Try again.'**
  String get coreWallpaperErrorReadFile;

  /// No description provided for @coreWallpaperErrorSourceTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is too large for a live wallpaper.'**
  String get coreWallpaperErrorSourceTooLarge;

  /// No description provided for @coreWallpaperErrorStyle.
  ///
  /// In en, this message translates to:
  /// **'This device could not start that style. Try another one.'**
  String get coreWallpaperErrorStyle;

  /// No description provided for @coreWallpaperErrorSystemPreview.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the system preview.'**
  String get coreWallpaperErrorSystemPreview;

  /// No description provided for @coreWallpaperErrorTextureDimensions.
  ///
  /// In en, this message translates to:
  /// **'That image is too large for a live wallpaper.'**
  String get coreWallpaperErrorTextureDimensions;

  /// No description provided for @coreWallpaperErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timed out. Check your connection and try again.'**
  String get coreWallpaperErrorTimeout;

  /// No description provided for @coreWallpaperHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get coreWallpaperHomeScreen;

  /// No description provided for @coreWallpaperHomeSetLockFailed.
  ///
  /// In en, this message translates to:
  /// **'Home screen set. Lock screen failed.'**
  String get coreWallpaperHomeSetLockFailed;

  /// No description provided for @coreWallpaperLinkCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t copy the link. Try again.'**
  String get coreWallpaperLinkCopyFailed;

  /// No description provided for @coreWallpaperLinkCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the share link. Try again.'**
  String get coreWallpaperLinkCreateFailed;

  /// No description provided for @coreWallpaperLoadTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Timed out loading the wallpaper. Check your connection and try again.'**
  String get coreWallpaperLoadTimedOut;

  /// No description provided for @coreWallpaperLockScreen.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get coreWallpaperLockScreen;

  /// No description provided for @coreWallpaperOfflineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This wallpaper is not saved on this device. Connect to the internet and try again.'**
  String get coreWallpaperOfflineUnavailable;

  /// Feedback when one screen was set but the second screen failed.
  ///
  /// In en, this message translates to:
  /// **'{applied} set. {failed} failed.'**
  String coreWallpaperPartialSet(String applied, String failed);

  /// No description provided for @coreWallpaperPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Check out this amazing wallpaper from Prism.'**
  String get coreWallpaperPreviewDescription;

  /// No description provided for @coreWallpaperPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper on Prism'**
  String get coreWallpaperPreviewTitle;

  /// No description provided for @coreWallpaperSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set the wallpaper. Try again.'**
  String get coreWallpaperSaveFailed;

  /// No description provided for @coreWallpaperSavedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Saved to Photos.'**
  String get coreWallpaperSavedPhotos;

  /// No description provided for @coreWallpaperSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Your ad reward was added.'**
  String get coreWallpaperSavedToast;

  /// Save confirmation combined with an optional Lock Screen Depth Effect tip.
  ///
  /// In en, this message translates to:
  /// **'{saved} {tip}'**
  String coreWallpaperSavedWithTip(String saved, String tip);

  /// No description provided for @coreWallpaperSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get coreWallpaperSemanticLabel;

  /// No description provided for @coreWallpaperSet.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper set'**
  String get coreWallpaperSet;

  /// No description provided for @coreWallpaperShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share this wallpaper right now.'**
  String get coreWallpaperShareFailed;

  /// No description provided for @coreWallpaperShareRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share this wallpaper. Try again.'**
  String get coreWallpaperShareRetryFailed;

  /// No description provided for @debugAdminReviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Content moderation and push notification tool'**
  String get debugAdminReviewDescription;

  /// No description provided for @debugAdminShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Admin shortcuts'**
  String get debugAdminShortcuts;

  /// No description provided for @debugLiveActivityPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview Live Activity'**
  String get debugLiveActivityPreview;

  /// No description provided for @debugLiveActivityPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Runs a sample AI generation activity: ready after 8 seconds'**
  String get debugLiveActivityPreviewDescription;

  /// No description provided for @debugLiveActivityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live Activities are off or not supported'**
  String get debugLiveActivityUnavailable;

  /// No description provided for @debugReviewActivityPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview review queue activity'**
  String get debugReviewActivityPreview;

  /// No description provided for @debugReviewActivityPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows the walls waiting for review on the Lock Screen'**
  String get debugReviewActivityPreviewDescription;

  /// No description provided for @debugAllTags.
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get debugAllTags;

  /// No description provided for @debugAndroidVersion.
  ///
  /// In en, this message translates to:
  /// **'Android Version'**
  String get debugAndroidVersion;

  /// No description provided for @debugAnimationSpeed.
  ///
  /// In en, this message translates to:
  /// **'Animation speed'**
  String get debugAnimationSpeed;

  /// No description provided for @debugAppInfo.
  ///
  /// In en, this message translates to:
  /// **'App info'**
  String get debugAppInfo;

  /// No description provided for @debugAppName.
  ///
  /// In en, this message translates to:
  /// **'App Name'**
  String get debugAppName;

  /// No description provided for @debugAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get debugAppVersion;

  /// No description provided for @debugAutoScrollOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off auto-scroll'**
  String get debugAutoScrollOff;

  /// No description provided for @debugAutoScrollOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on auto-scroll'**
  String get debugAutoScrollOn;

  /// No description provided for @debugBackendName.
  ///
  /// In en, this message translates to:
  /// **'Backend: {backend}'**
  String debugBackendName(String backend);

  /// No description provided for @debugBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get debugBoard;

  /// No description provided for @debugBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get debugBrand;

  /// No description provided for @debugBuildNumber.
  ///
  /// In en, this message translates to:
  /// **'Build Number'**
  String get debugBuildNumber;

  /// No description provided for @debugBuildSignature.
  ///
  /// In en, this message translates to:
  /// **'Build Signature'**
  String get debugBuildSignature;

  /// No description provided for @debugCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'App cache cleared'**
  String get debugCacheCleared;

  /// No description provided for @debugCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get debugCancel;

  /// No description provided for @debugCheckLogsRetry.
  ///
  /// In en, this message translates to:
  /// **'Check the logs, then try again.'**
  String get debugCheckLogsRetry;

  /// No description provided for @debugClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get debugClear;

  /// No description provided for @debugClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get debugClearAll;

  /// No description provided for @debugClearAllStorageBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes all locally stored data. The app may behave unexpectedly until restarted.'**
  String get debugClearAllStorageBody;

  /// No description provided for @debugClearAllStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all storage?'**
  String get debugClearAllStorageTitle;

  /// No description provided for @debugClearAppCache.
  ///
  /// In en, this message translates to:
  /// **'Clear app cache'**
  String get debugClearAppCache;

  /// No description provided for @debugClearAppCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'Clear images, feed and notification cache'**
  String get debugClearAppCacheDescription;

  /// No description provided for @debugClearImageCache.
  ///
  /// In en, this message translates to:
  /// **'Clear image cache'**
  String get debugClearImageCache;

  /// No description provided for @debugClearImageCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'Evict in-memory image cache'**
  String get debugClearImageCacheDescription;

  /// No description provided for @debugClearLogsBody.
  ///
  /// In en, this message translates to:
  /// **'This removes every log entry held in memory.'**
  String get debugClearLogsBody;

  /// No description provided for @debugClearLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear logs?'**
  String get debugClearLogsTitle;

  /// No description provided for @debugClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get debugClearSearch;

  /// No description provided for @debugCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get debugCoins;

  /// No description provided for @debugCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get debugCopied;

  /// No description provided for @debugCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get debugCopiedToClipboard;

  /// No description provided for @debugCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get debugCopy;

  /// No description provided for @debugCopyDiagnosticReport.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostic report'**
  String get debugCopyDiagnosticReport;

  /// No description provided for @debugCopyFiltered.
  ///
  /// In en, this message translates to:
  /// **'Copy all (filtered)'**
  String get debugCopyFiltered;

  /// No description provided for @debugCopyFullDetail.
  ///
  /// In en, this message translates to:
  /// **'Copy full detail'**
  String get debugCopyFullDetail;

  /// No description provided for @debugCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy {title}'**
  String debugCopyTitle(String title);

  /// No description provided for @debugCopyValue.
  ///
  /// In en, this message translates to:
  /// **'Copy value'**
  String get debugCopyValue;

  /// No description provided for @debugCouldNotClearCache.
  ///
  /// In en, this message translates to:
  /// **'Could not clear the app cache: {error}'**
  String debugCouldNotClearCache(String error);

  /// No description provided for @debugCouldNotSaveValue.
  ///
  /// In en, this message translates to:
  /// **'Could not save the value'**
  String get debugCouldNotSaveValue;

  /// No description provided for @debugCrashApp.
  ///
  /// In en, this message translates to:
  /// **'Crash the app'**
  String get debugCrashApp;

  /// No description provided for @debugDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get debugDangerZone;

  /// No description provided for @debugDarkCard.
  ///
  /// In en, this message translates to:
  /// **'Dark card'**
  String get debugDarkCard;

  /// No description provided for @debugDefaultValue.
  ///
  /// In en, this message translates to:
  /// **'(default)'**
  String get debugDefaultValue;

  /// No description provided for @debugDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get debugDelete;

  /// No description provided for @debugDeleteKey.
  ///
  /// In en, this message translates to:
  /// **'Delete key'**
  String get debugDeleteKey;

  /// No description provided for @debugDeleteKeyBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{key}\" from local storage.'**
  String debugDeleteKeyBody(String key);

  /// No description provided for @debugDeleteKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete key?'**
  String get debugDeleteKeyTitle;

  /// No description provided for @debugDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get debugDevice;

  /// No description provided for @debugDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get debugDeviceName;

  /// No description provided for @debugDevicePixelRatio.
  ///
  /// In en, this message translates to:
  /// **'Device Pixel Ratio'**
  String get debugDevicePixelRatio;

  /// No description provided for @debugDiagnosticCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic report copied to clipboard'**
  String get debugDiagnosticCopied;

  /// No description provided for @debugDiagnosticReportHeading.
  ///
  /// In en, this message translates to:
  /// **'=== Prism Debug Diagnostic Report ==='**
  String get debugDiagnosticReportHeading;

  /// No description provided for @debugEditValue.
  ///
  /// In en, this message translates to:
  /// **'Edit value'**
  String get debugEditValue;

  /// No description provided for @debugEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get debugEmail;

  /// No description provided for @debugEmptyList.
  ///
  /// In en, this message translates to:
  /// **'Empty list'**
  String get debugEmptyList;

  /// No description provided for @debugEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get debugEnvironment;

  /// No description provided for @debugError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get debugError;

  /// No description provided for @debugErrorCopied.
  ///
  /// In en, this message translates to:
  /// **'Error copied'**
  String get debugErrorCopied;

  /// No description provided for @debugErrorStreakLost.
  ///
  /// In en, this message translates to:
  /// **'Error, streak lost'**
  String get debugErrorStreakLost;

  /// No description provided for @debugErrorValue.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get debugErrorValue;

  /// No description provided for @debugExportFile.
  ///
  /// In en, this message translates to:
  /// **'Export as file'**
  String get debugExportFile;

  /// No description provided for @debugFavouriteAdded.
  ///
  /// In en, this message translates to:
  /// **'Favourite added'**
  String get debugFavouriteAdded;

  /// No description provided for @debugFilterByTag.
  ///
  /// In en, this message translates to:
  /// **'Filter by tag'**
  String get debugFilterByTag;

  /// No description provided for @debugFilterKeys.
  ///
  /// In en, this message translates to:
  /// **'Filter keys'**
  String get debugFilterKeys;

  /// No description provided for @debugFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get debugFingerprint;

  /// No description provided for @debugFirestoreTelemetryDescription.
  ///
  /// In en, this message translates to:
  /// **'View Firestore read and write profiling'**
  String get debugFirestoreTelemetryDescription;

  /// No description provided for @debugFlagsReset.
  ///
  /// In en, this message translates to:
  /// **'Debug flags reset'**
  String get debugFlagsReset;

  /// No description provided for @debugForceCrash.
  ///
  /// In en, this message translates to:
  /// **'Force crash'**
  String get debugForceCrash;

  /// No description provided for @debugForceCrashBody.
  ///
  /// In en, this message translates to:
  /// **'This throws an exception to check that Sentry reports errors.'**
  String get debugForceCrashBody;

  /// No description provided for @debugForceCrashDescription.
  ///
  /// In en, this message translates to:
  /// **'Throw an exception to test Sentry reporting'**
  String get debugForceCrashDescription;

  /// No description provided for @debugForceCrashTitle.
  ///
  /// In en, this message translates to:
  /// **'Force crash?'**
  String get debugForceCrashTitle;

  /// No description provided for @debugGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated: {date}'**
  String debugGeneratedAt(String date);

  /// No description provided for @debugHardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get debugHardware;

  /// No description provided for @debugIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get debugIdentifier;

  /// No description provided for @debugImageCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Image cache cleared'**
  String get debugImageCacheCleared;

  /// No description provided for @debugIsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Is Admin'**
  String get debugIsAdmin;

  /// No description provided for @debugIsPremium.
  ///
  /// In en, this message translates to:
  /// **'Is Premium'**
  String get debugIsPremium;

  /// No description provided for @debugLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get debugLevel;

  /// No description provided for @debugLightCard.
  ///
  /// In en, this message translates to:
  /// **'Light card'**
  String get debugLightCard;

  /// No description provided for @debugLoadingSearch.
  ///
  /// In en, this message translates to:
  /// **'Loading, search'**
  String get debugLoadingSearch;

  /// No description provided for @debugLogDetail.
  ///
  /// In en, this message translates to:
  /// **'Log detail'**
  String get debugLogDetail;

  /// No description provided for @debugLogEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} entry} other{{count} entries}}'**
  String debugLogEntryCount(int count);

  /// No description provided for @debugLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Logged In'**
  String get debugLoggedIn;

  /// No description provided for @debugLoggingAndNetwork.
  ///
  /// In en, this message translates to:
  /// **'Logging and network'**
  String get debugLoggingAndNetwork;

  /// No description provided for @debugLogicalSize.
  ///
  /// In en, this message translates to:
  /// **'Logical Size'**
  String get debugLogicalSize;

  /// No description provided for @debugLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get debugLogs;

  /// No description provided for @debugLogsAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Log lines show up here as the app runs.'**
  String get debugLogsAppearHere;

  /// No description provided for @debugMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get debugMaintenance;

  /// No description provided for @debugManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get debugManufacturer;

  /// No description provided for @debugMascot.
  ///
  /// In en, this message translates to:
  /// **'Mascot'**
  String get debugMascot;

  /// No description provided for @debugMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get debugMessage;

  /// No description provided for @debugMixpanelEnabled.
  ///
  /// In en, this message translates to:
  /// **'Mixpanel Enabled'**
  String get debugMixpanelEnabled;

  /// No description provided for @debugMixpanelTokenPresent.
  ///
  /// In en, this message translates to:
  /// **'Mixpanel Token Present'**
  String get debugMixpanelTokenPresent;

  /// No description provided for @debugModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get debugModel;

  /// No description provided for @debugMoodCalm.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get debugMoodCalm;

  /// No description provided for @debugMoodCelebrate.
  ///
  /// In en, this message translates to:
  /// **'Celebrate'**
  String get debugMoodCelebrate;

  /// No description provided for @debugMoodCurious.
  ///
  /// In en, this message translates to:
  /// **'Curious'**
  String get debugMoodCurious;

  /// No description provided for @debugMoodHappy.
  ///
  /// In en, this message translates to:
  /// **'Happy'**
  String get debugMoodHappy;

  /// No description provided for @debugMoodLove.
  ///
  /// In en, this message translates to:
  /// **'Love'**
  String get debugMoodLove;

  /// No description provided for @debugMoodProud.
  ///
  /// In en, this message translates to:
  /// **'Proud'**
  String get debugMoodProud;

  /// No description provided for @debugMoodSad.
  ///
  /// In en, this message translates to:
  /// **'Sad'**
  String get debugMoodSad;

  /// No description provided for @debugMoodSleepy.
  ///
  /// In en, this message translates to:
  /// **'Sleepy'**
  String get debugMoodSleepy;

  /// No description provided for @debugMoodSurprised.
  ///
  /// In en, this message translates to:
  /// **'Surprised'**
  String get debugMoodSurprised;

  /// No description provided for @debugMoodWorried.
  ///
  /// In en, this message translates to:
  /// **'Worried'**
  String get debugMoodWorried;

  /// No description provided for @debugName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get debugName;

  /// No description provided for @debugNoKeysFound.
  ///
  /// In en, this message translates to:
  /// **'No keys found'**
  String get debugNoKeysFound;

  /// No description provided for @debugNoLogs.
  ///
  /// In en, this message translates to:
  /// **'No logs'**
  String get debugNoLogs;

  /// No description provided for @debugNoMatchingLogs.
  ///
  /// In en, this message translates to:
  /// **'No log line matches the filters.'**
  String get debugNoMatchingLogs;

  /// No description provided for @debugNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get debugNotAvailable;

  /// No description provided for @debugNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get debugNotSignedIn;

  /// No description provided for @debugNothingNew.
  ///
  /// In en, this message translates to:
  /// **'Nothing new'**
  String get debugNothingNew;

  /// No description provided for @debugOfflineStreakRisk.
  ///
  /// In en, this message translates to:
  /// **'Offline, streak at risk'**
  String get debugOfflineStreakRisk;

  /// No description provided for @debugPackage.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get debugPackage;

  /// No description provided for @debugPackageName.
  ///
  /// In en, this message translates to:
  /// **'Package Name'**
  String get debugPackageName;

  /// No description provided for @debugPaintBaselines.
  ///
  /// In en, this message translates to:
  /// **'Paint baselines'**
  String get debugPaintBaselines;

  /// No description provided for @debugPaintBaselinesDescription.
  ///
  /// In en, this message translates to:
  /// **'Show text baseline guides'**
  String get debugPaintBaselinesDescription;

  /// No description provided for @debugPaintSize.
  ///
  /// In en, this message translates to:
  /// **'Paint size'**
  String get debugPaintSize;

  /// No description provided for @debugPaintSizeDescription.
  ///
  /// In en, this message translates to:
  /// **'Show layout bounds on all widgets'**
  String get debugPaintSizeDescription;

  /// No description provided for @debugPaintSizeWarning.
  ///
  /// In en, this message translates to:
  /// **'Paint size, repaint rainbow and baselines only work in debug and profile builds.'**
  String get debugPaintSizeWarning;

  /// No description provided for @debugPerformanceOverlay.
  ///
  /// In en, this message translates to:
  /// **'Performance overlay'**
  String get debugPerformanceOverlay;

  /// No description provided for @debugPerformanceOverlayDescription.
  ///
  /// In en, this message translates to:
  /// **'GPU and CPU usage graphs'**
  String get debugPerformanceOverlayDescription;

  /// No description provided for @debugPersistenceBackend.
  ///
  /// In en, this message translates to:
  /// **'Persistence Backend'**
  String get debugPersistenceBackend;

  /// No description provided for @debugPexelsKeyPresent.
  ///
  /// In en, this message translates to:
  /// **'Pexels Key Present'**
  String get debugPexelsKeyPresent;

  /// No description provided for @debugPhysicalDevice.
  ///
  /// In en, this message translates to:
  /// **'Is Physical Device'**
  String get debugPhysicalDevice;

  /// No description provided for @debugPhysicalSize.
  ///
  /// In en, this message translates to:
  /// **'Physical Size'**
  String get debugPhysicalSize;

  /// No description provided for @debugPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get debugPlatform;

  /// No description provided for @debugRcApiKeyPresent.
  ///
  /// In en, this message translates to:
  /// **'RC API Key Present'**
  String get debugRcApiKeyPresent;

  /// No description provided for @debugReduceMotionPose.
  ///
  /// In en, this message translates to:
  /// **'Shows the reduce-motion pose of each mood'**
  String get debugReduceMotionPose;

  /// No description provided for @debugRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get debugRefresh;

  /// No description provided for @debugRemoteConfig.
  ///
  /// In en, this message translates to:
  /// **'Remote Config'**
  String get debugRemoteConfig;

  /// No description provided for @debugRemoteConfigUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Remote Config unavailable'**
  String get debugRemoteConfigUnavailable;

  /// No description provided for @debugRendering.
  ///
  /// In en, this message translates to:
  /// **'Rendering'**
  String get debugRendering;

  /// No description provided for @debugRepaintRainbow.
  ///
  /// In en, this message translates to:
  /// **'Repaint rainbow'**
  String get debugRepaintRainbow;

  /// No description provided for @debugRepaintRainbowDescription.
  ///
  /// In en, this message translates to:
  /// **'Highlight repainted areas in rotating colors'**
  String get debugRepaintRainbowDescription;

  /// No description provided for @debugResetFlags.
  ///
  /// In en, this message translates to:
  /// **'Reset all debug flags'**
  String get debugResetFlags;

  /// No description provided for @debugResetFlagsDescription.
  ///
  /// In en, this message translates to:
  /// **'Restore all toggles to default values'**
  String get debugResetFlagsDescription;

  /// No description provided for @debugSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get debugSave;

  /// No description provided for @debugSaveValueAsText.
  ///
  /// In en, this message translates to:
  /// **'Saving writes the value as text.'**
  String get debugSaveValueAsText;

  /// No description provided for @debugScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get debugScreen;

  /// No description provided for @debugSdkInt.
  ///
  /// In en, this message translates to:
  /// **'SDK Int'**
  String get debugSdkInt;

  /// No description provided for @debugSearchLogs.
  ///
  /// In en, this message translates to:
  /// **'Search logs'**
  String get debugSearchLogs;

  /// No description provided for @debugSemanticsDebugger.
  ///
  /// In en, this message translates to:
  /// **'Semantics debugger'**
  String get debugSemanticsDebugger;

  /// No description provided for @debugSemanticsDebuggerDescription.
  ///
  /// In en, this message translates to:
  /// **'Overlay accessibility tree labels'**
  String get debugSemanticsDebuggerDescription;

  /// No description provided for @debugSentryDsnPresent.
  ///
  /// In en, this message translates to:
  /// **'Sentry DSN Present'**
  String get debugSentryDsnPresent;

  /// No description provided for @debugSentryEnabled.
  ///
  /// In en, this message translates to:
  /// **'Sentry Enabled'**
  String get debugSentryEnabled;

  /// No description provided for @debugSentryEnv.
  ///
  /// In en, this message translates to:
  /// **'Sentry Env'**
  String get debugSentryEnv;

  /// No description provided for @debugSequence.
  ///
  /// In en, this message translates to:
  /// **'Sequence'**
  String get debugSequence;

  /// No description provided for @debugShowLogToasts.
  ///
  /// In en, this message translates to:
  /// **'Show log toasts'**
  String get debugShowLogToasts;

  /// No description provided for @debugShowLogToastsDescription.
  ///
  /// In en, this message translates to:
  /// **'Display log entries as brief overlay toasts'**
  String get debugShowLogToastsDescription;

  /// No description provided for @debugSimulateNoInternet.
  ///
  /// In en, this message translates to:
  /// **'Simulate no internet'**
  String get debugSimulateNoInternet;

  /// No description provided for @debugSimulateNoInternetDescription.
  ///
  /// In en, this message translates to:
  /// **'Overrides connectivity checks to report offline'**
  String get debugSimulateNoInternetDescription;

  /// No description provided for @debugSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get debugSpeed;

  /// No description provided for @debugStackTrace.
  ///
  /// In en, this message translates to:
  /// **'Stack trace'**
  String get debugStackTrace;

  /// No description provided for @debugStackTraceCopied.
  ///
  /// In en, this message translates to:
  /// **'Stack trace copied'**
  String get debugStackTraceCopied;

  /// No description provided for @debugStillPoses.
  ///
  /// In en, this message translates to:
  /// **'Still poses'**
  String get debugStillPoses;

  /// No description provided for @debugStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get debugStorage;

  /// No description provided for @debugStorageCleared.
  ///
  /// In en, this message translates to:
  /// **'All storage cleared'**
  String get debugStorageCleared;

  /// No description provided for @debugStorageKeyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} key} other{{count} keys}}'**
  String debugStorageKeyCount(int count);

  /// No description provided for @debugStorageNotInitialized.
  ///
  /// In en, this message translates to:
  /// **'Storage not initialized'**
  String get debugStorageNotInitialized;

  /// No description provided for @debugStorageReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read storage'**
  String get debugStorageReadError;

  /// No description provided for @debugStreakCoinsPurchase.
  ///
  /// In en, this message translates to:
  /// **'Streak, coins, purchase'**
  String get debugStreakCoinsPurchase;

  /// No description provided for @debugStreakKeptToday.
  ///
  /// In en, this message translates to:
  /// **'Streak kept today'**
  String get debugStreakKeptToday;

  /// No description provided for @debugSubscriptionTier.
  ///
  /// In en, this message translates to:
  /// **'Subscription Tier'**
  String get debugSubscriptionTier;

  /// No description provided for @debugSystemName.
  ///
  /// In en, this message translates to:
  /// **'System Name'**
  String get debugSystemName;

  /// No description provided for @debugSystemVersion.
  ///
  /// In en, this message translates to:
  /// **'System Version'**
  String get debugSystemVersion;

  /// No description provided for @debugTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get debugTime;

  /// No description provided for @debugTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debugTitle;

  /// No description provided for @debugTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get debugTools;

  /// No description provided for @debugTypeName.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String debugTypeName(String type);

  /// No description provided for @debugUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get debugUser;

  /// No description provided for @debugUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get debugUserId;

  /// No description provided for @debugUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get debugUsername;

  /// No description provided for @debugValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get debugValue;

  /// No description provided for @debugVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get debugVersion;

  /// No description provided for @debugWallpaperSetSaved.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper set or saved'**
  String get debugWallpaperSetSaved;

  /// No description provided for @debugWotdNotification.
  ///
  /// In en, this message translates to:
  /// **'Wall of the Day, notification'**
  String get debugWotdNotification;

  /// Action to choose a local image before opening a wallpaper tool.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get deepLinkInputChooseImage;

  /// Instructions on the image chooser page opened from a deep link.
  ///
  /// In en, this message translates to:
  /// **'Choose an image from your gallery to continue.'**
  String get deepLinkInputChooseImageDescription;

  /// Page title while choosing an image for clock preview.
  ///
  /// In en, this message translates to:
  /// **'Clock preview'**
  String get deepLinkInputClockPreviewTitle;

  /// Page title while choosing an image to edit.
  ///
  /// In en, this message translates to:
  /// **'Edit a wallpaper'**
  String get deepLinkInputEditTitle;

  /// Page title while choosing an image for wallpaper filters.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper filters'**
  String get deepLinkInputFiltersTitle;

  /// Recoverable error shown when the image picker fails or returns an unusable image.
  ///
  /// In en, this message translates to:
  /// **'Could not open your gallery. Please try again.'**
  String get deepLinkInputGalleryError;

  /// Page title while choosing an image for a live wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Live wallpaper'**
  String get deepLinkInputLiveTitle;

  /// Page title while choosing an image for photo preview.
  ///
  /// In en, this message translates to:
  /// **'Photo preview'**
  String get deepLinkInputPhotoPreviewTitle;

  /// Page title while choosing an image to position as wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Position a wallpaper'**
  String get deepLinkInputPositionTitle;

  /// Page title while choosing an image to upload.
  ///
  /// In en, this message translates to:
  /// **'Upload a wallpaper'**
  String get deepLinkInputUploadTitle;

  /// Page title while choosing an image to preview or download.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper preview'**
  String get deepLinkInputWallpaperPreviewTitle;

  /// No description provided for @economyActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get economyActivity;

  /// No description provided for @economyActivityEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Watch a video or keep your streak to earn your first coins.'**
  String get economyActivityEmptyMessage;

  /// No description provided for @economyActivityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load activity.'**
  String get economyActivityLoadFailed;

  /// No description provided for @economyAdCreditFailure.
  ///
  /// In en, this message translates to:
  /// **'Unable to credit coins right now.'**
  String get economyAdCreditFailure;

  /// No description provided for @economyAdDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily limit reached. Back tomorrow.'**
  String get economyAdDailyLimit;

  /// No description provided for @economyAdNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Ad was not completed.'**
  String get economyAdNotCompleted;

  /// No description provided for @economyAdOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Check your connection and try again.'**
  String get economyAdOffline;

  /// No description provided for @economyAdRewardDetails.
  ///
  /// In en, this message translates to:
  /// **'First one of the day +{first}, then +{reward}. Up to {maximum} a day.'**
  String economyAdRewardDetails(int first, int reward, int maximum);

  /// No description provided for @economyAdRewardPending.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm your reward yet. The coins arrive when you are back online.'**
  String get economyAdRewardPending;

  /// No description provided for @economyAdUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No ad is available right now. Try again later.'**
  String get economyAdUnavailable;

  /// No description provided for @economyAddPhotoBio.
  ///
  /// In en, this message translates to:
  /// **'Add a photo and a bio'**
  String get economyAddPhotoBio;

  /// No description provided for @economyAddedToBalance.
  ///
  /// In en, this message translates to:
  /// **'Added to your balance'**
  String get economyAddedToBalance;

  /// No description provided for @economyAddedToCollection.
  ///
  /// In en, this message translates to:
  /// **'Added to your collection'**
  String get economyAddedToCollection;

  /// No description provided for @economyAddedToXp.
  ///
  /// In en, this message translates to:
  /// **'Added to your XP'**
  String get economyAddedToXp;

  /// No description provided for @economyAdsOffPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Ads are off. Change this in Settings > Privacy.'**
  String get economyAdsOffPrivacy;

  /// No description provided for @economyAiBusyRefunded.
  ///
  /// In en, this message translates to:
  /// **'AI is very busy right now. Try again later. Your coins were returned.'**
  String get economyAiBusyRefunded;

  /// No description provided for @economyAiChargeUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm the charge. Any coins taken will be refunded.'**
  String get economyAiChargeUnconfirmed;

  /// No description provided for @economyAiCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Check status'**
  String get economyAiCheckStatus;

  /// No description provided for @economyAiCoinsNeeded.
  ///
  /// In en, this message translates to:
  /// **'You need {cost} coins. You have {balance}.'**
  String economyAiCoinsNeeded(int cost, int balance);

  /// No description provided for @economyAiConnectToGenerate.
  ///
  /// In en, this message translates to:
  /// **'No connection. Connect to the internet, then try again.'**
  String get economyAiConnectToGenerate;

  /// No description provided for @economyAiCouldNotConfirmSubmission.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm the submission. Check Review Status before trying again.'**
  String get economyAiCouldNotConfirmSubmission;

  /// No description provided for @economyAiCropMayDiffer.
  ///
  /// In en, this message translates to:
  /// **'Crop may differ slightly on your device.'**
  String get economyAiCropMayDiffer;

  /// AI wallpaper Live Activity text shown on the lock screen and Dynamic Island.
  ///
  /// In en, this message translates to:
  /// **'Creating your wallpaper'**
  String get aiLiveActivityGenerating;

  /// AI wallpaper Live Activity text shown on the lock screen and Dynamic Island.
  ///
  /// In en, this message translates to:
  /// **'Your wallpaper is ready'**
  String get aiLiveActivityReady;

  /// AI wallpaper Live Activity text shown on the lock screen and Dynamic Island.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create it'**
  String get aiLiveActivityFailed;

  /// AI wallpaper Live Activity text shown on the lock screen and Dynamic Island.
  ///
  /// In en, this message translates to:
  /// **'Still working on it'**
  String get aiLiveActivityStale;

  /// AI wallpaper Live Activity text shown on the lock screen and Dynamic Island.
  ///
  /// In en, this message translates to:
  /// **'Open in Prism'**
  String get aiLiveActivityOpen;

  /// No description provided for @economyAiDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'You reached today\'s AI limit.'**
  String get economyAiDailyLimit;

  /// No description provided for @economyAiDescribeChanges.
  ///
  /// In en, this message translates to:
  /// **'Say what you want different, such as colors, mood or details.'**
  String get economyAiDescribeChanges;

  /// No description provided for @economyAiDescribeScene.
  ///
  /// In en, this message translates to:
  /// **'Describe a scene to generate.'**
  String get economyAiDescribeScene;

  /// No description provided for @economyAiDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download! Please retry.'**
  String get economyAiDownloadFailed;

  /// No description provided for @economyAiFailureWithRefund.
  ///
  /// In en, this message translates to:
  /// **'{message}{state, select, refunded{ Coins refunded.} pending{ Refund pending.} other{ Refund could not be completed.}}'**
  String economyAiFailureWithRefund(String message, String state);

  /// No description provided for @economyAiGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get economyAiGenerate;

  /// No description provided for @economyAiGenerateAnother.
  ///
  /// In en, this message translates to:
  /// **'Generate another'**
  String get economyAiGenerateAnother;

  /// No description provided for @economyAiGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate right now. Try again.'**
  String get economyAiGenerateFailed;

  /// No description provided for @economyAiGenerateGenericFailure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get economyAiGenerateGenericFailure;

  /// No description provided for @economyAiGeneratedWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Generated wallpaper'**
  String get economyAiGeneratedWallpaper;

  /// No description provided for @economyAiGenerationFrom.
  ///
  /// In en, this message translates to:
  /// **'Generation from {date}'**
  String economyAiGenerationFrom(String date);

  /// No description provided for @economyAiGenerationRollingOut.
  ///
  /// In en, this message translates to:
  /// **'AI generation is currently rolling out. Please try again soon.'**
  String get economyAiGenerationRollingOut;

  /// No description provided for @economyAiGenerationTime.
  ///
  /// In en, this message translates to:
  /// **'This takes about 20 seconds'**
  String get economyAiGenerationTime;

  /// No description provided for @economyAiHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Each wallpaper you generate appears here, so you can compare or switch back.'**
  String get economyAiHistoryEmpty;

  /// No description provided for @economyAiHistoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load history. Pull to refresh.'**
  String get economyAiHistoryFailed;

  /// AI wallpaper generation status shown while matching the output to the device screen.
  ///
  /// In en, this message translates to:
  /// **'Matching your screen size…'**
  String get economyAiMatchingScreenSize;

  /// AI wallpaper generation status shown while applying the selected style.
  ///
  /// In en, this message translates to:
  /// **'Applying your style…'**
  String get economyAiApplyingStyle;

  /// AI wallpaper generation status shown while completing the wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Finalizing your wallpaper…'**
  String get economyAiFinalizingWallpaper;

  /// Example hint in the AI wallpaper remix text field.
  ///
  /// In en, this message translates to:
  /// **'Darker sky, warmer palette, softer edges…'**
  String get economyAiRemixHint;

  /// No description provided for @economyAiNeedCoinsToGenerate.
  ///
  /// In en, this message translates to:
  /// **'Need {cost} coins to generate.'**
  String economyAiNeedCoinsToGenerate(int cost);

  /// Toast shown when an action needs more coins than the user has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Need {count} more coin.} other{Need {count} more coins.}}'**
  String economyNeedMoreCoins(int count);

  /// No description provided for @economyAiNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get economyAiNoConnection;

  /// No description provided for @economyAiNoConnectionRetry.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again.'**
  String get economyAiNoConnectionRetry;

  /// No description provided for @economyAiOfflineHistory.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline or the network failed. Pull to refresh when you\'re back.'**
  String get economyAiOfflineHistory;

  /// No description provided for @economyAiOfflineSavedHistory.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Saved history is still available.'**
  String get economyAiOfflineSavedHistory;

  /// No description provided for @economyAiPaymentCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment check failed. Your coins will be returned.'**
  String get economyAiPaymentCheckFailed;

  /// No description provided for @economyAiPreparingShare.
  ///
  /// In en, this message translates to:
  /// **'Preparing share'**
  String get economyAiPreparingShare;

  /// No description provided for @economyAiPromptBlocked.
  ///
  /// In en, this message translates to:
  /// **'That prompt is not allowed.'**
  String get economyAiPromptBlocked;

  /// No description provided for @economyAiPromptTooLong.
  ///
  /// In en, this message translates to:
  /// **'Description is too long (max {maximum} characters).'**
  String economyAiPromptTooLong(int maximum);

  /// No description provided for @economyAiQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get economyAiQuality;

  /// No description provided for @economyAiQualityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get economyAiQualityBalanced;

  /// No description provided for @economyAiQualityFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get economyAiQualityFast;

  /// No description provided for @economyAiQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get economyAiQualityHigh;

  /// No description provided for @economyAiQualitySemantics.
  ///
  /// In en, this message translates to:
  /// **'{quality}, {cost} coins'**
  String economyAiQualitySemantics(String quality, int cost);

  /// No description provided for @economyAiRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get economyAiRecent;

  /// No description provided for @economyAiRefineExplanation.
  ///
  /// In en, this message translates to:
  /// **'Say what should change. This makes a new wallpaper from the same prompt with a new seed, so it can look quite different.'**
  String get economyAiRefineExplanation;

  /// No description provided for @economyAiResultBlocked.
  ///
  /// In en, this message translates to:
  /// **'The result was blocked. Try another prompt.'**
  String get economyAiResultBlocked;

  /// No description provided for @economyAiRolloutBody.
  ///
  /// In en, this message translates to:
  /// **'It is on for {percent}% of accounts so far. Try again soon.'**
  String economyAiRolloutBody(int percent);

  /// No description provided for @economyAiRolloutTitle.
  ///
  /// In en, this message translates to:
  /// **'AI wallpaper is opening gradually'**
  String get economyAiRolloutTitle;

  /// No description provided for @economyAiSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get economyAiSave;

  /// No description provided for @economyAiSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save that file. Try again.'**
  String get economyAiSaveFailed;

  /// No description provided for @economyAiSceneIdea.
  ///
  /// In en, this message translates to:
  /// **'Scene idea'**
  String get economyAiSceneIdea;

  /// No description provided for @economyAiSceneIdeaMessage.
  ///
  /// In en, this message translates to:
  /// **'Use this scene in your description (editable)'**
  String get economyAiSceneIdeaMessage;

  /// No description provided for @economyAiSetAsWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set as wallpaper'**
  String get economyAiSetAsWallpaper;

  /// No description provided for @economyAiShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get economyAiShare;

  /// No description provided for @economyAiShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share. Please try again.'**
  String get economyAiShareFailed;

  /// No description provided for @economyAiShareReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Moderators review submissions before they appear in Prism. Only share work you have rights to.'**
  String get economyAiShareReviewNotice;

  /// No description provided for @economyAiShareWithCommunity.
  ///
  /// In en, this message translates to:
  /// **'Share with the community?'**
  String get economyAiShareWithCommunity;

  /// No description provided for @economyAiShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get economyAiShuffle;

  /// No description provided for @economyAiShuffleMessage.
  ///
  /// In en, this message translates to:
  /// **'Shuffle a new example description'**
  String get economyAiShuffleMessage;

  /// No description provided for @economyAiStillWorking.
  ///
  /// In en, this message translates to:
  /// **'Still working on your last image.'**
  String get economyAiStillWorking;

  /// No description provided for @economyAiStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get economyAiStyle;

  /// No description provided for @economyAiStyleAbstract.
  ///
  /// In en, this message translates to:
  /// **'Abstract'**
  String get economyAiStyleAbstract;

  /// No description provided for @economyAiStyleAnime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get economyAiStyleAnime;

  /// No description provided for @economyAiStyleCyberpunk.
  ///
  /// In en, this message translates to:
  /// **'Cyberpunk'**
  String get economyAiStyleCyberpunk;

  /// No description provided for @economyAiStyleMeshGradient.
  ///
  /// In en, this message translates to:
  /// **'Mesh Gradient'**
  String get economyAiStyleMeshGradient;

  /// No description provided for @economyAiStyleMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get economyAiStyleMinimal;

  /// No description provided for @economyAiStyleNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get economyAiStyleNature;

  /// No description provided for @economyAiStyleSemantics.
  ///
  /// In en, this message translates to:
  /// **'Style: {style}'**
  String economyAiStyleSemantics(String style);

  /// Title of the sheet that shows a large preview of every AI wallpaper style.
  ///
  /// In en, this message translates to:
  /// **'Choose a style'**
  String get economyAiStyleSheetTitle;

  /// Line under the style sheet title. Every style preview shows this one scene.
  ///
  /// In en, this message translates to:
  /// **'Every preview shows the same scene: a lighthouse on a cliff at dusk.'**
  String get economyAiStyleSheetSubject;

  /// No description provided for @economyAiStyleWatercolor.
  ///
  /// In en, this message translates to:
  /// **'Watercolor'**
  String get economyAiStyleWatercolor;

  /// No description provided for @economyAiStyleSpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get economyAiStyleSpace;

  /// No description provided for @economyAiStyleSynthwave.
  ///
  /// In en, this message translates to:
  /// **'Synthwave'**
  String get economyAiStyleSynthwave;

  /// No description provided for @economyAiStylePixelArt.
  ///
  /// In en, this message translates to:
  /// **'Pixel Art'**
  String get economyAiStylePixelArt;

  /// No description provided for @economyAiStyleRender3d.
  ///
  /// In en, this message translates to:
  /// **'3D Render'**
  String get economyAiStyleRender3d;

  /// No description provided for @economyAiStyleOilPainting.
  ///
  /// In en, this message translates to:
  /// **'Oil Painting'**
  String get economyAiStyleOilPainting;

  /// No description provided for @economyAiStyleUkiyoE.
  ///
  /// In en, this message translates to:
  /// **'Ukiyo-e'**
  String get economyAiStyleUkiyoE;

  /// No description provided for @economyAiSubmissionUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Submission status is unconfirmed. Check before retrying.'**
  String get economyAiSubmissionUnconfirmed;

  /// No description provided for @economyAiSubmitDisabled.
  ///
  /// In en, this message translates to:
  /// **'AI submit is currently disabled.'**
  String get economyAiSubmitDisabled;

  /// No description provided for @economyAiSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Submit failed. Please retry.'**
  String get economyAiSubmitFailed;

  /// No description provided for @economyAiSubmitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for community review'**
  String get economyAiSubmitForReview;

  /// No description provided for @economyAiSubmitStatusUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Submission status is unconfirmed. Check Review Status before trying again.'**
  String get economyAiSubmitStatusUnconfirmed;

  /// No description provided for @economyAiSubmittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review.'**
  String get economyAiSubmittedForReview;

  /// No description provided for @economyAiTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get economyAiTryAgain;

  /// No description provided for @economyAiTryAnother.
  ///
  /// In en, this message translates to:
  /// **'Try another'**
  String get economyAiTryAnother;

  /// No description provided for @economyAiTryAnotherVersion.
  ///
  /// In en, this message translates to:
  /// **'Try another version'**
  String get economyAiTryAnotherVersion;

  /// No description provided for @economyAiUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'We turned it off for a short while. Check back soon.'**
  String get economyAiUnavailableBody;

  /// No description provided for @economyAiUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'AI wallpaper is off for now'**
  String get economyAiUnavailableTitle;

  /// No description provided for @economyAiVariationTooLong.
  ///
  /// In en, this message translates to:
  /// **'That description is too long (max {maximum} characters).'**
  String economyAiVariationTooLong(int maximum);

  /// No description provided for @economyAiVariationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Try another is not available right now.'**
  String get economyAiVariationUnavailable;

  /// No description provided for @economyAiWallpaper.
  ///
  /// In en, this message translates to:
  /// **'AI wallpaper'**
  String get economyAiWallpaper;

  /// No description provided for @economyAiWatermarkNote.
  ///
  /// In en, this message translates to:
  /// **'Free images carry a Prism watermark. Pro removes it.'**
  String get economyAiWatermarkNote;

  /// No description provided for @economyAllRankRewardsCollected.
  ///
  /// In en, this message translates to:
  /// **'All rank rewards collected'**
  String get economyAllRankRewardsCollected;

  /// No description provided for @economyAllSpinsUsed.
  ///
  /// In en, this message translates to:
  /// **'All spins used'**
  String get economyAllSpinsUsed;

  /// No description provided for @economyBackTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Back tomorrow'**
  String get economyBackTomorrow;

  /// No description provided for @economyBadge.
  ///
  /// In en, this message translates to:
  /// **'Badge'**
  String get economyBadge;

  /// No description provided for @economyBadgeAiArtist.
  ///
  /// In en, this message translates to:
  /// **'AI Artist'**
  String get economyBadgeAiArtist;

  /// No description provided for @economyBadgeAiArtistDescription.
  ///
  /// In en, this message translates to:
  /// **'Generate 10 AI wallpapers'**
  String get economyBadgeAiArtistDescription;

  /// No description provided for @economyBadgeArtCurator.
  ///
  /// In en, this message translates to:
  /// **'Art Curator'**
  String get economyBadgeArtCurator;

  /// No description provided for @economyBadgeArtCuratorDescription.
  ///
  /// In en, this message translates to:
  /// **'Favourite 50 wallpapers'**
  String get economyBadgeArtCuratorDescription;

  /// No description provided for @economyBadgeCollector.
  ///
  /// In en, this message translates to:
  /// **'Collector'**
  String get economyBadgeCollector;

  /// No description provided for @economyBadgeCollectorDescription.
  ///
  /// In en, this message translates to:
  /// **'Favourite 10 wallpapers'**
  String get economyBadgeCollectorDescription;

  /// No description provided for @economyBadgeCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get economyBadgeCreator;

  /// No description provided for @economyBadgeCreatorDescription.
  ///
  /// In en, this message translates to:
  /// **'Get a wallpaper approved'**
  String get economyBadgeCreatorDescription;

  /// No description provided for @economyBadgeDescription.
  ///
  /// In en, this message translates to:
  /// **'A badge in Prism'**
  String get economyBadgeDescription;

  /// No description provided for @economyBadgeEarned.
  ///
  /// In en, this message translates to:
  /// **'Badge earned'**
  String get economyBadgeEarned;

  /// No description provided for @economyBadgeEarnedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} earned'**
  String economyBadgeEarnedCount(int count, int total);

  /// No description provided for @economyBadgeName.
  ///
  /// In en, this message translates to:
  /// **'{name} badge'**
  String economyBadgeName(String name);

  /// No description provided for @economyBadgePrismVeteran.
  ///
  /// In en, this message translates to:
  /// **'Prism Veteran'**
  String get economyBadgePrismVeteran;

  /// No description provided for @economyBadgePrismVeteranDescription.
  ///
  /// In en, this message translates to:
  /// **'Use Prism for 30 days and reach a 7 day streak'**
  String get economyBadgePrismVeteranDescription;

  /// No description provided for @economyBadgeProfileComplete.
  ///
  /// In en, this message translates to:
  /// **'Profile Complete'**
  String get economyBadgeProfileComplete;

  /// No description provided for @economyBadgeProfileCompleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a photo, username, bio and a link'**
  String get economyBadgeProfileCompleteDescription;

  /// No description provided for @economyBadgeSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {status}. {description}'**
  String economyBadgeSemantics(String name, String status, String description);

  /// No description provided for @economyBadgeSocialButterfly.
  ///
  /// In en, this message translates to:
  /// **'Social Butterfly'**
  String get economyBadgeSocialButterfly;

  /// No description provided for @economyBadgeSocialButterflyDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow 10 creators'**
  String get economyBadgeSocialButterflyDescription;

  /// No description provided for @economyBadgeStatusEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get economyBadgeStatusEarned;

  /// No description provided for @economyBadgeStatusLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get economyBadgeStatusLocked;

  /// No description provided for @economyBadgeStreakMaster.
  ///
  /// In en, this message translates to:
  /// **'Streak Master'**
  String get economyBadgeStreakMaster;

  /// No description provided for @economyBadgeStreakMasterDescription.
  ///
  /// In en, this message translates to:
  /// **'Reach a 28 day streak'**
  String get economyBadgeStreakMasterDescription;

  /// No description provided for @economyBadgeWeekWarrior.
  ///
  /// In en, this message translates to:
  /// **'Week Warrior'**
  String get economyBadgeWeekWarrior;

  /// No description provided for @economyBadgeWeekWarriorDescription.
  ///
  /// In en, this message translates to:
  /// **'Reach a 7 day streak'**
  String get economyBadgeWeekWarriorDescription;

  /// No description provided for @economyBadges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get economyBadges;

  /// No description provided for @economyBalanceSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count} Prism coins'**
  String economyBalanceSemantics(int count);

  /// No description provided for @economyBestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best {count, plural, one{1 day} other{{count} days}}'**
  String economyBestStreak(int count);

  /// No description provided for @economyBoost.
  ///
  /// In en, this message translates to:
  /// **'Boost'**
  String get economyBoost;

  /// No description provided for @economyBoostInfo.
  ///
  /// In en, this message translates to:
  /// **'Put one of your approved wallpapers at the front of Trending. A boost costs {amount} coins. Open your wallpaper and tap Boost.'**
  String economyBoostInfo(int amount);

  /// No description provided for @economyBuildStreakDaily.
  ///
  /// In en, this message translates to:
  /// **'Open Prism every day to build a streak.'**
  String get economyBuildStreakDaily;

  /// No description provided for @economyBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get economyBuy;

  /// No description provided for @economyBuyPremium.
  ///
  /// In en, this message translates to:
  /// **'Buy premium'**
  String get economyBuyPremium;

  /// No description provided for @economyCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get economyCancel;

  /// No description provided for @economyChestBonusDone.
  ///
  /// In en, this message translates to:
  /// **'Bonus quest done: your coins are doubled.'**
  String get economyChestBonusDone;

  /// No description provided for @economyChestBonusToDouble.
  ///
  /// In en, this message translates to:
  /// **'Do today\'s bonus quest first to double your coins.'**
  String get economyChestBonusToDouble;

  /// No description provided for @economyChestBoosterSemantics.
  ///
  /// In en, this message translates to:
  /// **'{title}. {caption}'**
  String economyChestBoosterSemantics(String title, String caption);

  /// No description provided for @economyChestCoinsPrize.
  ///
  /// In en, this message translates to:
  /// **'{coins, plural, one{1 coin} other{{coins} coins}}'**
  String economyChestCoinsPrize(int coins);

  /// No description provided for @economyChestDoFirst.
  ///
  /// In en, this message translates to:
  /// **'Do this first to double your chest'**
  String get economyChestDoFirst;

  /// No description provided for @economyChestDoubled.
  ///
  /// In en, this message translates to:
  /// **'Chest doubled'**
  String get economyChestDoubled;

  /// No description provided for @economyChestDoubledByBonus.
  ///
  /// In en, this message translates to:
  /// **' Doubled by your bonus quest.'**
  String get economyChestDoubledByBonus;

  /// No description provided for @economyChestFreeToday.
  ///
  /// In en, this message translates to:
  /// **'Free today'**
  String get economyChestFreeToday;

  /// No description provided for @economyChestNeedCoins.
  ///
  /// In en, this message translates to:
  /// **'The chest costs {price} coins. You have {balance}. Watch a video to earn more.'**
  String economyChestNeedCoins(int price, int balance);

  /// No description provided for @economyChestNewCosmetic.
  ///
  /// In en, this message translates to:
  /// **'a new {kind}: {name}'**
  String economyChestNewCosmetic(String kind, String name);

  /// No description provided for @economyChestNewKind.
  ///
  /// In en, this message translates to:
  /// **'New {kind}'**
  String economyChestNewKind(String kind);

  /// No description provided for @economyChestOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Prism. Try again.'**
  String get economyChestOpenFailed;

  /// No description provided for @economyChestOpenFor.
  ///
  /// In en, this message translates to:
  /// **'Open it for {price} coins, or finish {count, plural, one{1 more quest} other{{count} more quests}} to open it free.'**
  String economyChestOpenFor(int price, int count);

  /// No description provided for @economyChestOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get economyChestOpened;

  /// No description provided for @economyChestOpenedDoubledTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Opened and doubled. A new one tomorrow.'**
  String get economyChestOpenedDoubledTomorrow;

  /// No description provided for @economyChestOpenedReset.
  ///
  /// In en, this message translates to:
  /// **'Opened. A new chest in {time}.'**
  String economyChestOpenedReset(String time);

  /// No description provided for @economyChestOpenedTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Opened. A new one tomorrow.'**
  String get economyChestOpenedTomorrow;

  /// No description provided for @economyChestOwnCosmeticCoins.
  ///
  /// In en, this message translates to:
  /// **'You own every cosmetic, so it pays coins'**
  String get economyChestOwnCosmeticCoins;

  /// No description provided for @economyChestOwnEveryCosmetic.
  ///
  /// In en, this message translates to:
  /// **'You own every cosmetic'**
  String get economyChestOwnEveryCosmetic;

  /// No description provided for @economyChestPriceChanged.
  ///
  /// In en, this message translates to:
  /// **'The price changed. Check it and open again.'**
  String get economyChestPriceChanged;

  /// No description provided for @economyChestPriceFreeAfter.
  ///
  /// In en, this message translates to:
  /// **'{price} coins, or free after {count, plural, one{1 more quest} other{{count} more quests}}'**
  String economyChestPriceFreeAfter(int price, int count);

  /// No description provided for @economyChestPrizeSemantics.
  ///
  /// In en, this message translates to:
  /// **'{tier}. You won {prize}.{doubled, select, true{ Doubled by your bonus quest.} other{}}{xp, plural, =0{} one{ Plus 1 XP.} other{ Plus {xp} XP.}}'**
  String economyChestPrizeSemantics(String tier, String prize, String doubled, int xp);

  /// No description provided for @economyChestQuestsFree.
  ///
  /// In en, this message translates to:
  /// **'Your quests made it free today.'**
  String get economyChestQuestsFree;

  /// No description provided for @economyChestReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to open'**
  String get economyChestReady;

  /// No description provided for @economyChestReadyPaid.
  ///
  /// In en, this message translates to:
  /// **'Ready to open. {done} of {total} quests done'**
  String economyChestReadyPaid(int done, int total);

  /// No description provided for @economyChestResetHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String economyChestResetHours(int hours);

  /// No description provided for @economyChestResetHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String economyChestResetHoursMinutes(int hours, int minutes);

  /// No description provided for @economyChestResetMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String economyChestResetMinutes(int minutes);

  /// No description provided for @economyChestTierCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get economyChestTierCommon;

  /// No description provided for @economyChestTierEpic.
  ///
  /// In en, this message translates to:
  /// **'Epic'**
  String get economyChestTierEpic;

  /// No description provided for @economyChestTierLegendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get economyChestTierLegendary;

  /// No description provided for @economyChestTierRare.
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get economyChestTierRare;

  /// No description provided for @economyChestXpLine.
  ///
  /// In en, this message translates to:
  /// **'Opening it gives {xp} XP.'**
  String economyChestXpLine(int xp);

  /// No description provided for @economyClaimedTodayDay7Chest.
  ///
  /// In en, this message translates to:
  /// **'Today is done. Come back tomorrow for your day 7 chest.'**
  String get economyClaimedTodayDay7Chest;

  /// No description provided for @economyClaimedTodayReward.
  ///
  /// In en, this message translates to:
  /// **'Today is done. Come back tomorrow for +{coins} coins.'**
  String economyClaimedTodayReward(int coins);

  /// No description provided for @economyClosePreview.
  ///
  /// In en, this message translates to:
  /// **'Close preview'**
  String get economyClosePreview;

  /// No description provided for @economyCoinActivitySemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}, {date}, {amount} {coins, plural, one{coin} other{coins}}'**
  String economyCoinActivitySemantics(String label, String date, String amount, int coins);

  /// No description provided for @economyCoinBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance {balance}'**
  String economyCoinBalance(int balance);

  /// No description provided for @economyCoinGateRefundUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'{action}. Your refund could not be confirmed.'**
  String economyCoinGateRefundUnconfirmed(String action);

  /// No description provided for @economyCoinGateRefunded.
  ///
  /// In en, this message translates to:
  /// **'{action}. {coins, plural, one{1 coin refunded.} other{{coins} coins refunded.}}'**
  String economyCoinGateRefunded(String action, int coins);

  /// No description provided for @economyCoinHistoryEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get economyCoinHistoryEarned;

  /// No description provided for @economyCoinHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No coin activity yet.'**
  String get economyCoinHistoryEmpty;

  /// No description provided for @economyCoinHistoryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your coin history.'**
  String get economyCoinHistoryLoadFailed;

  /// No description provided for @economyCoinHistoryNoLoadedRows.
  ///
  /// In en, this message translates to:
  /// **'Nothing here in the rows loaded so far.'**
  String get economyCoinHistoryNoLoadedRows;

  /// No description provided for @economyCoinHistoryNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get economyCoinHistoryNothingHere;

  /// No description provided for @economyCoinHistoryRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get economyCoinHistoryRefunds;

  /// No description provided for @economyCoinHistoryRowSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}{hasDescription, select, true{, {description}} other{}}, {date}, {amount} {coins, plural, one{coin} other{coins}}, {balance}'**
  String economyCoinHistoryRowSemantics(
    String label,
    String hasDescription,
    String description,
    String date,
    String amount,
    int coins,
    String balance,
  );

  /// No description provided for @economyCoinHistorySpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get economyCoinHistorySpent;

  /// No description provided for @economyCoinHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Coin history'**
  String get economyCoinHistoryTitle;

  /// No description provided for @economyCoinSpendFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to process coins right now.'**
  String get economyCoinSpendFailed;

  /// No description provided for @economyCoins.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 coin} other{{count} coins}}'**
  String economyCoins(int count);

  /// No description provided for @economyCoinsAreYoursToSpend.
  ///
  /// In en, this message translates to:
  /// **'Coins are yours to spend'**
  String get economyCoinsAreYoursToSpend;

  /// No description provided for @economyCoinsEarned.
  ///
  /// In en, this message translates to:
  /// **'+{count, plural, one{1 coin} other{{count} coins}}'**
  String economyCoinsEarned(int count);

  /// No description provided for @economyCoinsRange.
  ///
  /// In en, this message translates to:
  /// **'+{minimum} to +{maximum}'**
  String economyCoinsRange(int minimum, int maximum);

  /// No description provided for @economyCoinsSpendingDetails.
  ///
  /// In en, this message translates to:
  /// **'Coins pay for wallpapers, tools and Shop items. XP is progress, not a balance you spend. Spending coins never lowers your XP.'**
  String get economyCoinsSpendingDetails;

  /// No description provided for @economyCoinsWhatYouCanDo.
  ///
  /// In en, this message translates to:
  /// **'What you can do with them'**
  String get economyCoinsWhatYouCanDo;

  /// No description provided for @economyCoinsWord.
  ///
  /// In en, this message translates to:
  /// **'coins'**
  String get economyCoinsWord;

  /// No description provided for @economyCollectionItemSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category}, {status}. {caption}'**
  String economyCollectionItemSemantics(String category, String status, String caption);

  /// No description provided for @economyCollectionKeepStreakMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep a {days} day streak to unlock this wallpaper{hasCoins, select, true{, or use {coins} coins to unlock it now} other{}}.'**
  String economyCollectionKeepStreakMessage(int days, int coins, String hasCoins);

  /// No description provided for @economyCollectionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this collection'**
  String get economyCollectionLoadFailed;

  /// No description provided for @economyCollectionNeedCoinsMessage.
  ///
  /// In en, this message translates to:
  /// **'You need {coins} coins to unlock this wallpaper.'**
  String economyCollectionNeedCoinsMessage(int coins);

  /// No description provided for @economyCollectionRequirementsUnmet.
  ///
  /// In en, this message translates to:
  /// **'This wallpaper is not available yet.'**
  String get economyCollectionRequirementsUnmet;

  /// No description provided for @economyCollectionStillLocked.
  ///
  /// In en, this message translates to:
  /// **'Still locked'**
  String get economyCollectionStillLocked;

  /// No description provided for @economyCollectionUnlockedAtDays.
  ///
  /// In en, this message translates to:
  /// **'Unlocked at a {days} day streak'**
  String economyCollectionUnlockedAtDays(int days);

  /// No description provided for @economyCollectionUnlockedWithCoins.
  ///
  /// In en, this message translates to:
  /// **'Unlocked with coins'**
  String get economyCollectionUnlockedWithCoins;

  /// No description provided for @economyCollectionUnlocksAtCoins.
  ///
  /// In en, this message translates to:
  /// **'Unlocks for {coins} coins'**
  String economyCollectionUnlocksAtCoins(int coins);

  /// No description provided for @economyCollectionUnlocksAtDays.
  ///
  /// In en, this message translates to:
  /// **'Unlocks at a {days} day streak'**
  String economyCollectionUnlocksAtDays(int days);

  /// No description provided for @economyCompleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get economyCompleteProfile;

  /// No description provided for @economyCosmetic.
  ///
  /// In en, this message translates to:
  /// **'cosmetic'**
  String get economyCosmetic;

  /// No description provided for @economyCosmeticAppIcon.
  ///
  /// In en, this message translates to:
  /// **'app icon'**
  String get economyCosmeticAppIcon;

  /// No description provided for @economyCosmeticFrame.
  ///
  /// In en, this message translates to:
  /// **'frame'**
  String get economyCosmeticFrame;

  /// No description provided for @economyCosmeticNameGlow.
  ///
  /// In en, this message translates to:
  /// **'name glow'**
  String get economyCosmeticNameGlow;

  /// No description provided for @economyCosmeticTheme.
  ///
  /// In en, this message translates to:
  /// **'theme'**
  String get economyCosmeticTheme;

  /// No description provided for @economyCountdownDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String economyCountdownDaysHours(int days, int hours);

  /// No description provided for @economyCountdownHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String economyCountdownHoursMinutes(int hours, int minutes);

  /// No description provided for @economyCountdownMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String economyCountdownMinutes(int minutes);

  /// No description provided for @economyCreatorApprovedWalls.
  ///
  /// In en, this message translates to:
  /// **'Approved wallpapers'**
  String get economyCreatorApprovedWalls;

  /// No description provided for @economyCreatorIntro.
  ///
  /// In en, this message translates to:
  /// **'Earn XP when your wallpapers are approved and new members favourite them. Progress appears after your first qualifying contribution.'**
  String get economyCreatorIntro;

  /// No description provided for @economyCreatorMilestoneProgress.
  ///
  /// In en, this message translates to:
  /// **'{label}: {current} / {target}'**
  String economyCreatorMilestoneProgress(String label, int current, int target);

  /// No description provided for @economyCreatorMilestoneSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label} milestone'**
  String economyCreatorMilestoneSemantics(String label);

  /// No description provided for @economyCreatorMilestones.
  ///
  /// In en, this message translates to:
  /// **'Creator milestones'**
  String get economyCreatorMilestones;

  /// No description provided for @economyCreatorMilestonesComplete.
  ///
  /// In en, this message translates to:
  /// **'{label} milestones complete'**
  String economyCreatorMilestonesComplete(String label);

  /// No description provided for @economyCreatorNewMembersThisWeek.
  ///
  /// In en, this message translates to:
  /// **'{count} new members favourited your wallpapers this week'**
  String economyCreatorNewMembersThisWeek(int count);

  /// No description provided for @economyCreatorNextMilestone.
  ///
  /// In en, this message translates to:
  /// **'Next milestone: +{xp} XP'**
  String economyCreatorNextMilestone(int xp);

  /// No description provided for @economyCreatorProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'{current} of {target}'**
  String economyCreatorProgressSemantics(int current, int target);

  /// No description provided for @economyCreatorQualifyingMembers.
  ///
  /// In en, this message translates to:
  /// **'Qualifying members'**
  String get economyCreatorQualifyingMembers;

  /// No description provided for @economyCreatorRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh progress'**
  String get economyCreatorRefresh;

  /// No description provided for @economyCreatorRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing creator progress…'**
  String get economyCreatorRefreshing;

  /// No description provided for @economyCreatorRules.
  ///
  /// In en, this message translates to:
  /// **'Approved wallpapers must be your own eligible uploads. Older uploads may be ineligible if Prism cannot verify the original upload. Each other member counts once across all your eligible work, on their first qualifying favourite. They must be signed in, have a verified email and an account at least seven days old. Your own favourites do not count. Counts are historical, not your current audience. Removing favourites does not undo XP. Creator milestones earn extra XP. Weeks run Monday to Sunday in UTC; delayed activity can appear in a later week.'**
  String get economyCreatorRules;

  /// No description provided for @economyCreatorSavedRefresh.
  ///
  /// In en, this message translates to:
  /// **'Saved progress. Refresh to update.'**
  String get economyCreatorSavedRefresh;

  /// No description provided for @economyCreatorSavedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Saved progress. Refresh is unavailable.'**
  String get economyCreatorSavedUnavailable;

  /// No description provided for @economyCreatorThisWeekSummary.
  ///
  /// In en, this message translates to:
  /// **'{walls} eligible wallpapers approved · {xp} milestone XP'**
  String economyCreatorThisWeekSummary(int walls, int xp);

  /// No description provided for @economyCreatorTrackingSince.
  ///
  /// In en, this message translates to:
  /// **'Tracking since {date} UTC'**
  String economyCreatorTrackingSince(String date);

  /// No description provided for @economyCreatorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Creator progress is unavailable.'**
  String get economyCreatorUnavailable;

  /// No description provided for @economyCreatorWeekRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end} UTC'**
  String economyCreatorWeekRange(String start, String end);

  /// No description provided for @economyCreatorWeekSummary.
  ///
  /// In en, this message translates to:
  /// **'{walls} eligible wallpapers approved · {members} new qualifying members · {xp} milestone XP'**
  String economyCreatorWeekSummary(int walls, int members, int xp);

  /// No description provided for @economyCreatorWhatCounts.
  ///
  /// In en, this message translates to:
  /// **'What counts & history'**
  String get economyCreatorWhatCounts;

  /// No description provided for @economyDailyChest.
  ///
  /// In en, this message translates to:
  /// **'Daily chest'**
  String get economyDailyChest;

  /// No description provided for @economyDailyChestSemantics.
  ///
  /// In en, this message translates to:
  /// **'Daily chest, {state}. {caption}{hasXp, select, true{. {xpLine}} other{}}'**
  String economyDailyChestSemantics(String state, String caption, String hasXp, String xpLine);

  /// No description provided for @economyDailyChestTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily chest'**
  String get economyDailyChestTitle;

  /// No description provided for @economyDailyQuests.
  ///
  /// In en, this message translates to:
  /// **'Daily quests'**
  String get economyDailyQuests;

  /// No description provided for @economyDailyStreak.
  ///
  /// In en, this message translates to:
  /// **'Daily streak'**
  String get economyDailyStreak;

  /// No description provided for @economyDay7Chest.
  ///
  /// In en, this message translates to:
  /// **'Day 7 chest'**
  String get economyDay7Chest;

  /// No description provided for @economyDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String economyDayLabel(int day);

  /// No description provided for @economyDayStreakMilestone.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak!'**
  String economyDayStreakMilestone(int days);

  /// No description provided for @economyDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{day} other{days}}'**
  String economyDays(int count);

  /// No description provided for @economyDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day ago} other{{count} days ago}}'**
  String economyDaysAgo(int count);

  /// No description provided for @economyDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get economyDownload;

  /// No description provided for @economyDownloadAccountChanged.
  ///
  /// In en, this message translates to:
  /// **'Account changed. Please try saving again.'**
  String get economyDownloadAccountChanged;

  /// No description provided for @economyDownloadAgain.
  ///
  /// In en, this message translates to:
  /// **'Download again'**
  String get economyDownloadAgain;

  /// No description provided for @economyDownloadAgainCost.
  ///
  /// In en, this message translates to:
  /// **'Download again (-{cost} coins)'**
  String economyDownloadAgainCost(int cost);

  /// No description provided for @economyDownloadAlreadyInDownloads.
  ///
  /// In en, this message translates to:
  /// **'Already in Downloads'**
  String get economyDownloadAlreadyInDownloads;

  /// No description provided for @economyDownloadCoinsNeeded.
  ///
  /// In en, this message translates to:
  /// **'You need {missing} more coins to save this wallpaper.{watch, select, true{ Each ad adds {reward}.} other{}}{adState, select, disabled{ Ads are off. Change this in Settings > Privacy.} limit{ Daily limit reached. Back tomorrow.} other{}}'**
  String economyDownloadCoinsNeeded(int missing, int reward, String watch, String adState);

  /// No description provided for @economyDownloadCost.
  ///
  /// In en, this message translates to:
  /// **'{label} · {cost}'**
  String economyDownloadCost(String label, int cost);

  /// No description provided for @economyDownloadCostSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}. Costs {cost} coins'**
  String economyDownloadCostSemantics(String label, int cost);

  /// No description provided for @economyDownloadFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get economyDownloadFailedLabel;

  /// No description provided for @economyDownloadFreeDownloadsLeftSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}. Free, {count, plural, one{1 free download left} other{{count} free downloads left}}'**
  String economyDownloadFreeDownloadsLeftSemantics(String label, int count);

  /// No description provided for @economyDownloadFreeFor.
  ///
  /// In en, this message translates to:
  /// **'{label} · Free'**
  String economyDownloadFreeFor(String label);

  /// No description provided for @economyDownloadFreeLeftFor.
  ///
  /// In en, this message translates to:
  /// **'{label} · Free · {count} left'**
  String economyDownloadFreeLeftFor(String label, int count);

  /// No description provided for @economyDownloadFreeOwnedSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}. Free, you own this wallpaper'**
  String economyDownloadFreeOwnedSemantics(String label);

  /// No description provided for @economyDownloadFreeWithPassSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}. Free with your pass'**
  String economyDownloadFreeWithPassSemantics(String label);

  /// No description provided for @economyDownloadFreeWithPro.
  ///
  /// In en, this message translates to:
  /// **'Free with Pro'**
  String get economyDownloadFreeWithPro;

  /// No description provided for @economyDownloadFreeWithProSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}. Free with Pro'**
  String economyDownloadFreeWithProSemantics(String label);

  /// No description provided for @economyDownloadLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No download link available.'**
  String get economyDownloadLinkUnavailable;

  /// No description provided for @economyDownloadProGuestMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save this wallpaper with coins, or get Prism Pro.'**
  String get economyDownloadProGuestMessage;

  /// No description provided for @economyDownloadSaveLocalCopy.
  ///
  /// In en, this message translates to:
  /// **'Save local copy'**
  String get economyDownloadSaveLocalCopy;

  /// No description provided for @economyDownloadSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get economyDownloadSaved;

  /// No description provided for @economyDownloadSavedBefore.
  ///
  /// In en, this message translates to:
  /// **'You saved this wallpaper before.'**
  String get economyDownloadSavedBefore;

  /// No description provided for @economyDownloadSavedInDownloads.
  ///
  /// In en, this message translates to:
  /// **'Saved. Already in Downloads'**
  String get economyDownloadSavedInDownloads;

  /// No description provided for @economyDownloadThisWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Download this wallpaper'**
  String get economyDownloadThisWallpaper;

  /// No description provided for @economyDownloadWaitForCurrent.
  ///
  /// In en, this message translates to:
  /// **'Wait for download to complete!'**
  String get economyDownloadWaitForCurrent;

  /// No description provided for @economyDownloadWatchAdMessage.
  ///
  /// In en, this message translates to:
  /// **'Watch a small video ad to download this wallpaper.'**
  String get economyDownloadWatchAdMessage;

  /// No description provided for @economyDownloadWatchAdPrivacyMessage.
  ///
  /// In en, this message translates to:
  /// **'Watch a small video ad to download this wallpaper. Ads are off. Change this in Settings > Privacy.'**
  String get economyDownloadWatchAdPrivacyMessage;

  /// No description provided for @economyDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get economyDownloads;

  /// No description provided for @economyDownloadsInfo.
  ///
  /// In en, this message translates to:
  /// **'Each wallpaper download costs {amount} coins.{hasFree, select, true{ Your first {freeCount} are free.} other{}} Pro makes downloads free.'**
  String economyDownloadsInfo(int amount, int freeCount, String hasFree);

  /// No description provided for @economyDrawAllTicketsHeld.
  ///
  /// In en, this message translates to:
  /// **'You already hold all {maximum} tickets this week.'**
  String economyDrawAllTicketsHeld(int maximum);

  /// No description provided for @economyDrawBuyTicket.
  ///
  /// In en, this message translates to:
  /// **'Buy a ticket · {price}'**
  String economyDrawBuyTicket(int price);

  /// No description provided for @economyDrawClosed.
  ///
  /// In en, this message translates to:
  /// **'This draw is closed. The next one opens Monday.'**
  String get economyDrawClosed;

  /// No description provided for @economyDrawClosesIn.
  ///
  /// In en, this message translates to:
  /// **'Closes in {time}'**
  String economyDrawClosesIn(String time);

  /// No description provided for @economyDrawLastWinner.
  ///
  /// In en, this message translates to:
  /// **'Last winner'**
  String get economyDrawLastWinner;

  /// No description provided for @economyDrawLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the Draw'**
  String get economyDrawLoadFailed;

  /// No description provided for @economyDrawNotEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins for a ticket.'**
  String get economyDrawNotEnoughCoins;

  /// No description provided for @economyDrawNotOpen.
  ///
  /// In en, this message translates to:
  /// **'The Draw is not open yet.'**
  String get economyDrawNotOpen;

  /// No description provided for @economyDrawOfficialRules.
  ///
  /// In en, this message translates to:
  /// **'Official rules'**
  String get economyDrawOfficialRules;

  /// No description provided for @economyDrawPrizeDescription.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, one{1 month} other{{months} months}} of Pro + the Prism frame'**
  String economyDrawPrizeDescription(int months);

  /// No description provided for @economyDrawProNotEligible.
  ///
  /// In en, this message translates to:
  /// **'Pro members are not eligible.'**
  String get economyDrawProNotEligible;

  /// No description provided for @economyDrawPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t buy a ticket. Try again.'**
  String get economyDrawPurchaseFailed;

  /// No description provided for @economyDrawThisWeeksPrize.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK\'S PRIZE'**
  String get economyDrawThisWeeksPrize;

  /// No description provided for @economyDrawTicketBought.
  ///
  /// In en, this message translates to:
  /// **'Ticket bought. You hold {tickets} of {maximum}.'**
  String economyDrawTicketBought(int tickets, int maximum);

  /// No description provided for @economyDrawTicketCost.
  ///
  /// In en, this message translates to:
  /// **'Tickets cost {price} coins'**
  String economyDrawTicketCost(int price);

  /// No description provided for @economyDrawTicketsAndPeople.
  ///
  /// In en, this message translates to:
  /// **'{tickets, plural, one{1 ticket} other{{tickets} tickets}} from {people, plural, one{1 person} other{{people} people}}'**
  String economyDrawTicketsAndPeople(int tickets, int people);

  /// No description provided for @economyDrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Prism Draw'**
  String get economyDrawTitle;

  /// No description provided for @economyDrawYourChance.
  ///
  /// In en, this message translates to:
  /// **'Your chance: {mine}/{pot}'**
  String economyDrawYourChance(int mine, int pot);

  /// No description provided for @economyDrawYourTickets.
  ///
  /// In en, this message translates to:
  /// **'Your tickets: {tickets} of {maximum}'**
  String economyDrawYourTickets(int tickets, int maximum);

  /// No description provided for @economyDropAlreadyUnlocked.
  ///
  /// In en, this message translates to:
  /// **'You already have this one.'**
  String get economyDropAlreadyUnlocked;

  /// No description provided for @economyDropByCreator.
  ///
  /// In en, this message translates to:
  /// **'by {creator}'**
  String economyDropByCreator(String creator);

  /// No description provided for @economyDropCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'Weekly Drop, {time}, {unlocked} of {total} collected'**
  String economyDropCardSemantics(String time, int unlocked, int total);

  /// No description provided for @economyDropCarouselDetail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 wall} other{{count} walls}} · {time}'**
  String economyDropCarouselDetail(int count, String time);

  /// No description provided for @economyDropCarouselSemantics.
  ///
  /// In en, this message translates to:
  /// **'Weekly Drop, {title}, {detail}{lastCall, select, true{, last call} other{}}'**
  String economyDropCarouselSemantics(String title, String detail, String lastCall);

  /// No description provided for @economyDropCollected.
  ///
  /// In en, this message translates to:
  /// **'{owned} of {total} collected'**
  String economyDropCollected(int owned, int total);

  /// No description provided for @economyDropDates.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String economyDropDates(String start, String end);

  /// No description provided for @economyDropEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get economyDropEnded;

  /// No description provided for @economyDropEndedHeadline.
  ///
  /// In en, this message translates to:
  /// **'This Drop has ended'**
  String get economyDropEndedHeadline;

  /// No description provided for @economyDropEndsInDaysHours.
  ///
  /// In en, this message translates to:
  /// **'Ends in {days, plural, one{1d} other{{days}d}} {hours, plural, one{1h} other{{hours}h}}'**
  String economyDropEndsInDaysHours(int days, int hours);

  /// No description provided for @economyDropEndsInHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'Ends in {hours, plural, one{1h} other{{hours}h}} {minutes, plural, one{1m} other{{minutes}m}}'**
  String economyDropEndsInHoursMinutes(int hours, int minutes);

  /// No description provided for @economyDropEndsInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Ends in {minutes}m'**
  String economyDropEndsInMinutes(int minutes);

  /// No description provided for @economyDropGone.
  ///
  /// In en, this message translates to:
  /// **'This Drop is gone'**
  String get economyDropGone;

  /// No description provided for @economyDropLastCallLabel.
  ///
  /// In en, this message translates to:
  /// **'Last call'**
  String get economyDropLastCallLabel;

  /// No description provided for @economyDropLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the Drop'**
  String get economyDropLoadFailed;

  /// No description provided for @economyDropLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get economyDropLocked;

  /// No description provided for @economyDropMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get economyDropMissed;

  /// No description provided for @economyDropOver.
  ///
  /// In en, this message translates to:
  /// **'This Drop is over.'**
  String get economyDropOver;

  /// No description provided for @economyDropPastDrops.
  ///
  /// In en, this message translates to:
  /// **'Past drops'**
  String get economyDropPastDrops;

  /// No description provided for @economyDropPosition.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String economyDropPosition(int index, int total);

  /// No description provided for @economyDropPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop preview'**
  String get economyDropPreviewTitle;

  /// No description provided for @economyDropRename.
  ///
  /// In en, this message translates to:
  /// **'Rename Drop'**
  String get economyDropRename;

  /// No description provided for @economyDropRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename the Drop. Try again.'**
  String get economyDropRenameFailed;

  /// No description provided for @economyDropRenameHint.
  ///
  /// In en, this message translates to:
  /// **'Drop name'**
  String get economyDropRenameHint;

  /// No description provided for @economyDropRenamed.
  ///
  /// In en, this message translates to:
  /// **'Drop renamed'**
  String get economyDropRenamed;

  /// No description provided for @economyDropSave.
  ///
  /// In en, this message translates to:
  /// **'Save {coins}'**
  String economyDropSave(int coins);

  /// No description provided for @economyDropStats.
  ///
  /// In en, this message translates to:
  /// **'{walls} · {count, plural, one{1 collector} other{{count} collectors}}'**
  String economyDropStats(String walls, int count);

  /// No description provided for @economyDropTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get economyDropTitle;

  /// No description provided for @economyDropUnlockAll.
  ///
  /// In en, this message translates to:
  /// **'Unlock all {count} for {price}'**
  String economyDropUnlockAll(int count, int price);

  /// No description provided for @economyDropUnlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t unlock this. Try again.'**
  String get economyDropUnlockFailed;

  /// No description provided for @economyDropUnlockFor.
  ///
  /// In en, this message translates to:
  /// **'Unlock for {price}'**
  String economyDropUnlockFor(int price);

  /// No description provided for @economyDropUnlockWall.
  ///
  /// In en, this message translates to:
  /// **'Unlock this wall for {price}'**
  String economyDropUnlockWall(int price);

  /// No description provided for @economyDropUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get economyDropUnlocked;

  /// No description provided for @economyDropUnlockedCount.
  ///
  /// In en, this message translates to:
  /// **'{unlocked}/{total} unlocked'**
  String economyDropUnlockedCount(int unlocked, int total);

  /// No description provided for @economyDropUnlockedCountToast.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Wall unlocked} other{{count} walls unlocked}}'**
  String economyDropUnlockedCountToast(int count);

  /// No description provided for @economyDropUnlockedWall.
  ///
  /// In en, this message translates to:
  /// **'Unlocked wall'**
  String get economyDropUnlockedWall;

  /// No description provided for @economyDropUnlockedWallBy.
  ///
  /// In en, this message translates to:
  /// **'Unlocked wall by {creator}'**
  String economyDropUnlockedWallBy(String creator);

  /// No description provided for @economyDropWallBySemantics.
  ///
  /// In en, this message translates to:
  /// **'{state} wall {serial} by {creator}'**
  String economyDropWallBySemantics(String state, String serial, String creator);

  /// No description provided for @economyDropWallCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 wall} other{{count} walls}}'**
  String economyDropWallCount(int count);

  /// No description provided for @economyDropWallSemantics.
  ///
  /// In en, this message translates to:
  /// **'{state} wall {serial}'**
  String economyDropWallSemantics(String state, String serial);

  /// No description provided for @economyDropWallpaperUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This wallpaper is unavailable'**
  String get economyDropWallpaperUnavailable;

  /// No description provided for @economyDropWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String economyDropWeekOf(String date);

  /// No description provided for @economyDropYourVault.
  ///
  /// In en, this message translates to:
  /// **'Your vault'**
  String get economyDropYourVault;

  /// No description provided for @economyDrops.
  ///
  /// In en, this message translates to:
  /// **'Drops'**
  String get economyDrops;

  /// No description provided for @economyEarnCoins.
  ///
  /// In en, this message translates to:
  /// **'Earn coins'**
  String get economyEarnCoins;

  /// No description provided for @economyEarnXpAsYouGo.
  ///
  /// In en, this message translates to:
  /// **'Earn XP as you go'**
  String get economyEarnXpAsYouGo;

  /// No description provided for @economyEarnedAtRank.
  ///
  /// In en, this message translates to:
  /// **'Earned at {rank}'**
  String economyEarnedAtRank(String rank);

  /// No description provided for @economyEquipped.
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get economyEquipped;

  /// No description provided for @economyEveryChestPays.
  ///
  /// In en, this message translates to:
  /// **'Every chest pays something.'**
  String get economyEveryChestPays;

  /// No description provided for @economyEverySpinPays.
  ///
  /// In en, this message translates to:
  /// **'Every spin pays something.'**
  String get economyEverySpinPays;

  /// No description provided for @economyFallbackCoins.
  ///
  /// In en, this message translates to:
  /// **'Pays {count} coins if you own them all'**
  String economyFallbackCoins(int count);

  /// No description provided for @economyFinishDay7Chest.
  ///
  /// In en, this message translates to:
  /// **'Finish day 7 for a chest of +{minimum} to +{maximum}'**
  String economyFinishDay7Chest(int minimum, int maximum);

  /// No description provided for @economyFinishStreakWeek.
  ///
  /// In en, this message translates to:
  /// **'Finish a week of streak days.'**
  String get economyFinishStreakWeek;

  /// No description provided for @economyFirstDownloadsFree.
  ///
  /// In en, this message translates to:
  /// **'First {count} free'**
  String economyFirstDownloadsFree(int count);

  /// No description provided for @economyFirstUpload.
  ///
  /// In en, this message translates to:
  /// **'First upload'**
  String get economyFirstUpload;

  /// No description provided for @economyFreeDailySpin.
  ///
  /// In en, this message translates to:
  /// **'Free daily spin'**
  String get economyFreeDailySpin;

  /// No description provided for @economyFreeDownloadsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} free left'**
  String economyFreeDownloadsLeft(int count);

  /// No description provided for @economyFreeSpin.
  ///
  /// In en, this message translates to:
  /// **'Free spin'**
  String get economyFreeSpin;

  /// No description provided for @economyFreeSpinReady.
  ///
  /// In en, this message translates to:
  /// **'Free spin ready{count, plural, =0{} one{. 1 paid spin left today.} other{. {count} paid spins left today.}}'**
  String economyFreeSpinReady(int count);

  /// No description provided for @economyFreezeAdded.
  ///
  /// In en, this message translates to:
  /// **'Streak freeze added.'**
  String get economyFreezeAdded;

  /// No description provided for @economyFreezeAlreadyAtLimit.
  ///
  /// In en, this message translates to:
  /// **'You already hold {count, plural, one{1 freeze} other{{count} freezes}}.'**
  String economyFreezeAlreadyAtLimit(int count);

  /// No description provided for @economyFreezeBalanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance after: {balance}'**
  String economyFreezeBalanceAfter(int balance);

  /// No description provided for @economyFreezeBuyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Buy a streak freeze for {cost} coins?'**
  String economyFreezeBuyConfirm(int cost);

  /// No description provided for @economyFreezeBuyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not buy a freeze. Try again.'**
  String get economyFreezeBuyFailed;

  /// No description provided for @economyFreezeCount.
  ///
  /// In en, this message translates to:
  /// **'{held} of {total}'**
  String economyFreezeCount(int held, int total);

  /// No description provided for @economyFreezeDescription.
  ///
  /// In en, this message translates to:
  /// **'Saves your streak if you miss a day. It applies on its own.'**
  String get economyFreezeDescription;

  /// No description provided for @economyFreezeFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get economyFreezeFull;

  /// No description provided for @economyFreezeGetOne.
  ///
  /// In en, this message translates to:
  /// **'Get one · {cost}'**
  String economyFreezeGetOne(int cost);

  /// No description provided for @economyFreezeHeld.
  ///
  /// In en, this message translates to:
  /// **'Freeze held'**
  String get economyFreezeHeld;

  /// No description provided for @economyFreezeNeedCoins.
  ///
  /// In en, this message translates to:
  /// **'You need {cost} coins.'**
  String economyFreezeNeedCoins(int cost);

  /// No description provided for @economyFreezeSlotEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty freeze slot'**
  String get economyFreezeSlotEmpty;

  /// No description provided for @economyFreezeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Streak freeze is not available right now. Try again later.'**
  String get economyFreezeUnavailable;

  /// No description provided for @economyFreshLeaderboardDetails.
  ///
  /// In en, this message translates to:
  /// **'The leaderboard uses weekly XP, which resets every Monday at 00:00 UTC. Your lifetime XP, rank and earned cosmetics stay.'**
  String get economyFreshLeaderboardDetails;

  /// No description provided for @economyFreshLeaderboardWeekly.
  ///
  /// In en, this message translates to:
  /// **'A fresh leaderboard each week'**
  String get economyFreshLeaderboardWeekly;

  /// No description provided for @economyGetCoins.
  ///
  /// In en, this message translates to:
  /// **'Get coins'**
  String get economyGetCoins;

  /// No description provided for @economyGetCoinsChestCost.
  ///
  /// In en, this message translates to:
  /// **'Get coins. The chest costs {price} coins'**
  String economyGetCoinsChestCost(int price);

  /// No description provided for @economyGetCoinsForSpin.
  ///
  /// In en, this message translates to:
  /// **'Get coins. A spin costs {price} coins'**
  String economyGetCoinsForSpin(int price);

  /// No description provided for @economyGetFreezeNextTime.
  ///
  /// In en, this message translates to:
  /// **'Get a freeze for next time'**
  String get economyGetFreezeNextTime;

  /// No description provided for @economyGetPro.
  ///
  /// In en, this message translates to:
  /// **'Get Pro'**
  String get economyGetPro;

  /// No description provided for @economyGiftPass.
  ///
  /// In en, this message translates to:
  /// **'Gift a pass'**
  String get economyGiftPass;

  /// No description provided for @economyGiftPassInfo.
  ///
  /// In en, this message translates to:
  /// **'Give a friend 24 hours of Pro content for {amount} coins. Open their profile and tap Gift a 24 h pass.'**
  String economyGiftPassInfo(int amount);

  /// No description provided for @economyGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get economyGotIt;

  /// No description provided for @economyHighestRankReached.
  ///
  /// In en, this message translates to:
  /// **'Highest rank reached: {rank}'**
  String economyHighestRankReached(String rank);

  /// No description provided for @economyHighestRankReachedShort.
  ///
  /// In en, this message translates to:
  /// **'Highest rank reached'**
  String get economyHighestRankReachedShort;

  /// No description provided for @economyHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get economyHomeScreen;

  /// No description provided for @economyInviteFriend.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get economyInviteFriend;

  /// No description provided for @economyJackpotAddedToBalance.
  ///
  /// In en, this message translates to:
  /// **'Jackpot. Added to your balance'**
  String get economyJackpotAddedToBalance;

  /// No description provided for @economyKeepStreakToday.
  ///
  /// In en, this message translates to:
  /// **'Open Prism today to keep your streak.'**
  String get economyKeepStreakToday;

  /// No description provided for @economyLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get economyLastWeek;

  /// No description provided for @economyLeaderboardEntrySemantics.
  ///
  /// In en, this message translates to:
  /// **'{position}, {name}{isMe, select, true{, you} other{}}, {xp} XP this week{hasRank, select, true{, {rank} lifetime rank} other{}}'**
  String economyLeaderboardEntrySemantics(int position, String name, String isMe, int xp, String hasRank, String rank);

  /// No description provided for @economyLeaderboardFollowTip.
  ///
  /// In en, this message translates to:
  /// **'Your score is included. Follow creators to compare weekly XP.'**
  String get economyLeaderboardFollowTip;

  /// No description provided for @economyLeaderboardFollowToSee.
  ///
  /// In en, this message translates to:
  /// **'Follow creators to see them here.'**
  String get economyLeaderboardFollowToSee;

  /// No description provided for @economyLeaderboardFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get economyLeaderboardFollowing;

  /// No description provided for @economyLeaderboardFriendsCaption.
  ///
  /// In en, this message translates to:
  /// **'You and people you follow · pull to refresh'**
  String get economyLeaderboardFriendsCaption;

  /// No description provided for @economyLeaderboardFriendsDetails.
  ///
  /// In en, this message translates to:
  /// **'Includes your score and up to the first 90 accounts you follow. Deleted accounts are left out; there is no minimum account age. Scores load when you first open this tab. Pull to refresh. Your score reflects your latest synced XP.'**
  String get economyLeaderboardFriendsDetails;

  /// No description provided for @economyLeaderboardGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get economyLeaderboardGlobal;

  /// No description provided for @economyLeaderboardGlobalCaption.
  ///
  /// In en, this message translates to:
  /// **'Top 50 · updated about every 3 hours'**
  String get economyLeaderboardGlobalCaption;

  /// No description provided for @economyLeaderboardGlobalDetails.
  ///
  /// In en, this message translates to:
  /// **'Shows up to 50 accounts by weekly XP. Accounts must be at least 7 days old; deleted accounts are left out. The snapshot updates about every 3 hours, so new XP may take time to appear. Pulling to refresh loads the latest snapshot.'**
  String get economyLeaderboardGlobalDetails;

  /// No description provided for @economyLeaderboardHowScoringWorks.
  ///
  /// In en, this message translates to:
  /// **'How leaderboard scoring works'**
  String get economyLeaderboardHowScoringWorks;

  /// No description provided for @economyLeaderboardLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the leaderboard'**
  String get economyLeaderboardLoadFailed;

  /// No description provided for @economyLeaderboardNoRankings.
  ///
  /// In en, this message translates to:
  /// **'No rankings yet'**
  String get economyLeaderboardNoRankings;

  /// No description provided for @economyLeaderboardOffline.
  ///
  /// In en, this message translates to:
  /// **'If you are offline, saved scores may be shown.'**
  String get economyLeaderboardOffline;

  /// No description provided for @economyLeaderboardRankedByXp.
  ///
  /// In en, this message translates to:
  /// **'Ranked by XP earned this week'**
  String get economyLeaderboardRankedByXp;

  /// No description provided for @economyLeaderboardReset.
  ///
  /// In en, this message translates to:
  /// **'Resets Monday 00:00 UTC · {days, plural, one{1d} other{{days}d}} {hours, plural, one{1h} other{{hours}h}} left'**
  String economyLeaderboardReset(int days, int hours);

  /// No description provided for @economyLeaderboardScoringIntro.
  ///
  /// In en, this message translates to:
  /// **'Positions use XP earned this week. Rank labels, such as Silver, use lifetime XP. Weekly XP resets Monday at 00:00 UTC; lifetime XP and rank stay.'**
  String get economyLeaderboardScoringIntro;

  /// No description provided for @economyLeaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get economyLeaderboardTitle;

  /// No description provided for @economyLifetimePermanentDetails.
  ///
  /// In en, this message translates to:
  /// **'Lifetime XP sets your rank and never resets. Rank cosmetics arrive automatically in your inventory, cost no coins and stay yours. Choose when to equip them in the Shop.'**
  String get economyLifetimePermanentDetails;

  /// No description provided for @economyLifetimePermanentRewards.
  ///
  /// In en, this message translates to:
  /// **'Lifetime progress, permanent rewards'**
  String get economyLifetimePermanentRewards;

  /// No description provided for @economyLifetimeXp.
  ///
  /// In en, this message translates to:
  /// **'{xp} lifetime XP'**
  String economyLifetimeXp(String xp);

  /// No description provided for @economyLifetimeXpNeverResets.
  ///
  /// In en, this message translates to:
  /// **'Lifetime XP never resets.'**
  String get economyLifetimeXpNeverResets;

  /// No description provided for @economyLoadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Loading a video'**
  String get economyLoadingVideo;

  /// No description provided for @economyLockScreen.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get economyLockScreen;

  /// No description provided for @economyMystery.
  ///
  /// In en, this message translates to:
  /// **'Mystery'**
  String get economyMystery;

  /// No description provided for @economyMysteryCosmetic.
  ///
  /// In en, this message translates to:
  /// **'Mystery cosmetic'**
  String get economyMysteryCosmetic;

  /// No description provided for @economyNewBadge.
  ///
  /// In en, this message translates to:
  /// **'New badge'**
  String get economyNewBadge;

  /// No description provided for @economyNewCosmetic.
  ///
  /// In en, this message translates to:
  /// **'New {kind}: {name}'**
  String economyNewCosmetic(String kind, String name);

  /// No description provided for @economyNewUnknownCosmetic.
  ///
  /// In en, this message translates to:
  /// **'New cosmetic'**
  String get economyNewUnknownCosmetic;

  /// No description provided for @economyNextDropMonday.
  ///
  /// In en, this message translates to:
  /// **'The next Drop lands Monday.'**
  String get economyNextDropMonday;

  /// No description provided for @economyNextReward.
  ///
  /// In en, this message translates to:
  /// **'Next reward: {reward}'**
  String economyNextReward(String reward);

  /// No description provided for @economyNice.
  ///
  /// In en, this message translates to:
  /// **'Nice'**
  String get economyNice;

  /// No description provided for @economyNoDropNow.
  ///
  /// In en, this message translates to:
  /// **'No Drop right now'**
  String get economyNoDropNow;

  /// No description provided for @economyNoSpinsLeft.
  ///
  /// In en, this message translates to:
  /// **'No spins left today.'**
  String get economyNoSpinsLeft;

  /// No description provided for @economyNotEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get economyNotEnoughCoins;

  /// No description provided for @economyNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get economyNotNow;

  /// No description provided for @economyOddsTierSemantics.
  ///
  /// In en, this message translates to:
  /// **'{tier}, {odds}'**
  String economyOddsTierSemantics(String tier, String odds);

  /// No description provided for @economyOddsTitle.
  ///
  /// In en, this message translates to:
  /// **'The odds'**
  String get economyOddsTitle;

  /// No description provided for @economyOnceADay.
  ///
  /// In en, this message translates to:
  /// **'Once a day'**
  String get economyOnceADay;

  /// No description provided for @economyOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get economyOpen;

  /// No description provided for @economyOpenChestCost.
  ///
  /// In en, this message translates to:
  /// **'Open the chest, {price} coins'**
  String economyOpenChestCost(int price);

  /// No description provided for @economyOpenChestFree.
  ///
  /// In en, this message translates to:
  /// **'Open the chest, free'**
  String get economyOpenChestFree;

  /// No description provided for @economyOpenChestLoading.
  ///
  /// In en, this message translates to:
  /// **'Open the chest. Loading'**
  String get economyOpenChestLoading;

  /// No description provided for @economyOpenDaily.
  ///
  /// In en, this message translates to:
  /// **'Open Prism every day.'**
  String get economyOpenDaily;

  /// No description provided for @economyOpenDailyPro.
  ///
  /// In en, this message translates to:
  /// **'Open Prism every day. Pro earns x{multiplier}.'**
  String economyOpenDailyPro(String multiplier);

  /// No description provided for @economyOpenFree.
  ///
  /// In en, this message translates to:
  /// **'Open free'**
  String get economyOpenFree;

  /// No description provided for @economyOpenShop.
  ///
  /// In en, this message translates to:
  /// **'Open Shop'**
  String get economyOpenShop;

  /// No description provided for @economyOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening'**
  String get economyOpening;

  /// No description provided for @economyOwned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get economyOwned;

  /// No description provided for @economyPremiumCollection.
  ///
  /// In en, this message translates to:
  /// **'Premium collection'**
  String get economyPremiumCollection;

  /// No description provided for @economyPriceCoins.
  ///
  /// In en, this message translates to:
  /// **'{amount} coins'**
  String economyPriceCoins(int amount);

  /// No description provided for @economyPriceCoinsForHours.
  ///
  /// In en, this message translates to:
  /// **'{amount} coins for {hours} hours'**
  String economyPriceCoinsForHours(int amount, int hours);

  /// No description provided for @economyPriceCoinsPerWall.
  ///
  /// In en, this message translates to:
  /// **'{amount} a wall'**
  String economyPriceCoinsPerWall(int amount);

  /// No description provided for @economyPriceCoinsPerWallSemantics.
  ///
  /// In en, this message translates to:
  /// **'{amount} coins a wall'**
  String economyPriceCoinsPerWallSemantics(int amount);

  /// No description provided for @economyPriceCoinsWithNote.
  ///
  /// In en, this message translates to:
  /// **'{amount} coins{hasNote, select, true{, {note}} other{}}'**
  String economyPriceCoinsWithNote(int amount, String note, String hasNote);

  /// No description provided for @economyPriceForHours.
  ///
  /// In en, this message translates to:
  /// **'{amount} for {hours} h'**
  String economyPriceForHours(int amount, int hours);

  /// No description provided for @economyPriceFrom.
  ///
  /// In en, this message translates to:
  /// **'from {amount}'**
  String economyPriceFrom(int amount);

  /// No description provided for @economyPriceFromCoins.
  ///
  /// In en, this message translates to:
  /// **'from {amount} coins'**
  String economyPriceFromCoins(int amount);

  /// No description provided for @economyPrizeWheel.
  ///
  /// In en, this message translates to:
  /// **'Prize wheel'**
  String get economyPrizeWheel;

  /// No description provided for @economyPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get economyPro;

  /// No description provided for @economyProDailyFreeSpin.
  ///
  /// In en, this message translates to:
  /// **'Pro members get a free spin every day'**
  String get economyProDailyFreeSpin;

  /// No description provided for @economyProDownloadsFilters.
  ///
  /// In en, this message translates to:
  /// **'With Pro, downloads and filters are free.'**
  String get economyProDownloadsFilters;

  /// No description provided for @economyProPrice.
  ///
  /// In en, this message translates to:
  /// **'Pro price'**
  String get economyProPrice;

  /// No description provided for @economyProWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Pro wallpaper'**
  String get economyProWallpaper;

  /// No description provided for @economyQuestBrowse10.
  ///
  /// In en, this message translates to:
  /// **'Look at 10 walls'**
  String get economyQuestBrowse10;

  /// No description provided for @economyQuestColourSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by colour'**
  String get economyQuestColourSearch;

  /// No description provided for @economyQuestDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'{coins, plural, =0{{xp, plural, =0{Quest done} other{Quest done: +{xp} XP}}} one{Quest done: +1 coin{xp, plural, =0{} other{ · +{xp} XP}}} other{Quest done: +{coins} coins{xp, plural, =0{} other{ · +{xp} XP}}}}'**
  String economyQuestDoneMessage(int coins, int xp);

  /// No description provided for @economyQuestDownload2.
  ///
  /// In en, this message translates to:
  /// **'Download 2 walls'**
  String get economyQuestDownload2;

  /// No description provided for @economyQuestFav3.
  ///
  /// In en, this message translates to:
  /// **'Favourite 3 walls'**
  String get economyQuestFav3;

  /// No description provided for @economyQuestNewIn.
  ///
  /// In en, this message translates to:
  /// **'New in {time}'**
  String economyQuestNewIn(String time);

  /// No description provided for @economyQuestProSpin.
  ///
  /// In en, this message translates to:
  /// **'Take your free spin'**
  String get economyQuestProSpin;

  /// No description provided for @economyQuestSetWall.
  ///
  /// In en, this message translates to:
  /// **'Set or save a wallpaper'**
  String get economyQuestSetWall;

  /// No description provided for @economyQuestShareWall.
  ///
  /// In en, this message translates to:
  /// **'Share a wallpaper'**
  String get economyQuestShareWall;

  /// No description provided for @economyQuestTileSemantics.
  ///
  /// In en, this message translates to:
  /// **'{title}, {isDone, select, true{done} other{{progress} of {target}}}{hasCoins, select, true{. Earns {coins, plural, one{1 coin} other{{coins} coins}}} other{}}{hasXp, select, true{. Earns {xp} XP} other{}}{isWeekly, select, true{. Weekly quest{hasEnds, select, true{, ends in {endsIn}} other{}}} other{}}'**
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
  );

  /// No description provided for @economyQuestTrending.
  ///
  /// In en, this message translates to:
  /// **'See what\'s trending'**
  String get economyQuestTrending;

  /// No description provided for @economyQuestUnknown.
  ///
  /// In en, this message translates to:
  /// **'Complete a quest'**
  String get economyQuestUnknown;

  /// No description provided for @economyQuestWatchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch a video'**
  String get economyQuestWatchAd;

  /// No description provided for @economyQuestWeeklySet5.
  ///
  /// In en, this message translates to:
  /// **'Save or set 5 walls'**
  String get economyQuestWeeklySet5;

  /// No description provided for @economyQuestWotd.
  ///
  /// In en, this message translates to:
  /// **'Open today\'s Wall of the Day'**
  String get economyQuestWotd;

  /// No description provided for @economyRankBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get economyRankBronze;

  /// No description provided for @economyRankGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get economyRankGold;

  /// No description provided for @economyRankGrowsWithXp.
  ///
  /// In en, this message translates to:
  /// **'Your rank grows with lifetime XP.'**
  String get economyRankGrowsWithXp;

  /// No description provided for @economyRankInfoSemantics.
  ///
  /// In en, this message translates to:
  /// **'{rank} rank. How XP and rank rewards work'**
  String economyRankInfoSemantics(String rank);

  /// No description provided for @economyRankPrism.
  ///
  /// In en, this message translates to:
  /// **'Prism'**
  String get economyRankPrism;

  /// No description provided for @economyRankProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'{rank} rank progress'**
  String economyRankProgressSemantics(String rank);

  /// No description provided for @economyRankRewardAtRank.
  ///
  /// In en, this message translates to:
  /// **'Yours automatically at {rank} · {xp} XP'**
  String economyRankRewardAtRank(String rank, String xp);

  /// No description provided for @economyRankRewardMilestone.
  ///
  /// In en, this message translates to:
  /// **'{rank} · {xp} XP\n{reward}'**
  String economyRankRewardMilestone(String rank, String xp, String reward);

  /// No description provided for @economyRankRewardSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing to your inventory. It is yours to keep.'**
  String get economyRankRewardSyncing;

  /// No description provided for @economyRankRewardsHelp.
  ///
  /// In en, this message translates to:
  /// **'How XP and rank rewards work'**
  String get economyRankRewardsHelp;

  /// No description provided for @economyRankSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get economyRankSilver;

  /// No description provided for @economyRankTag.
  ///
  /// In en, this message translates to:
  /// **'{rank} rank'**
  String economyRankTag(String rank);

  /// No description provided for @economyRankUnknown.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get economyRankUnknown;

  /// No description provided for @economyReferralBothGet.
  ///
  /// In en, this message translates to:
  /// **'You both get {coins, plural, one{1 coin} other{{coins} coins}}'**
  String economyReferralBothGet(int coins);

  /// No description provided for @economyRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get economyRestore;

  /// No description provided for @economyRestoreStreak.
  ///
  /// In en, this message translates to:
  /// **'Restore your {days}-day streak · {coins} coins'**
  String economyRestoreStreak(int days, int coins);

  /// No description provided for @economyRewardEarned.
  ///
  /// In en, this message translates to:
  /// **'{reward} earned'**
  String economyRewardEarned(String reward);

  /// No description provided for @economyRewardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get economyRewardsTitle;

  /// No description provided for @economySameActivitySameXp.
  ///
  /// In en, this message translates to:
  /// **'The same activity earns the same XP'**
  String get economySameActivitySameXp;

  /// No description provided for @economySameActivityXpDetails.
  ///
  /// In en, this message translates to:
  /// **'Ads, Pro spins, Pro daily bonuses, referrals and refunds earn no XP. Pro and coin multipliers do not increase XP. Coin rewards stay separate.'**
  String get economySameActivityXpDetails;

  /// No description provided for @economySeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get economySeeAll;

  /// No description provided for @economySeeBadges.
  ///
  /// In en, this message translates to:
  /// **'See badges'**
  String get economySeeBadges;

  /// No description provided for @economySeeItInShop.
  ///
  /// In en, this message translates to:
  /// **'See it in the Shop'**
  String get economySeeItInShop;

  /// No description provided for @economySeeOdds.
  ///
  /// In en, this message translates to:
  /// **'See the odds'**
  String get economySeeOdds;

  /// No description provided for @economySeePro.
  ///
  /// In en, this message translates to:
  /// **'See Pro'**
  String get economySeePro;

  /// No description provided for @economySeeRewards.
  ///
  /// In en, this message translates to:
  /// **'See rewards'**
  String get economySeeRewards;

  /// No description provided for @economyShareWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Share a wallpaper'**
  String get economyShareWallpaper;

  /// No description provided for @economyShopAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'You already own this'**
  String get economyShopAlreadyOwned;

  /// No description provided for @economyShopAurora.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get economyShopAurora;

  /// No description provided for @economyShopBuyFor.
  ///
  /// In en, this message translates to:
  /// **'Buy for {price}'**
  String economyShopBuyFor(int price);

  /// No description provided for @economyShopChangeIconFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change the icon'**
  String get economyShopChangeIconFailed;

  /// No description provided for @economyShopCoinsShort.
  ///
  /// In en, this message translates to:
  /// **'You need {count} more coins.'**
  String economyShopCoinsShort(int count);

  /// No description provided for @economyShopCottonBlue.
  ///
  /// In en, this message translates to:
  /// **'Cotton Blue'**
  String get economyShopCottonBlue;

  /// No description provided for @economyShopDeepOcean.
  ///
  /// In en, this message translates to:
  /// **'Deep Ocean'**
  String get economyShopDeepOcean;

  /// No description provided for @economyShopDefaultIcon.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get economyShopDefaultIcon;

  /// No description provided for @economyShopEarnXp.
  ///
  /// In en, this message translates to:
  /// **'Earn XP'**
  String get economyShopEarnXp;

  /// No description provided for @economyShopEarnedAtLifetimeXp.
  ///
  /// In en, this message translates to:
  /// **'Earned at {rank} rank with lifetime XP.'**
  String economyShopEarnedAtLifetimeXp(String rank);

  /// No description provided for @economyShopEmber.
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get economyShopEmber;

  /// No description provided for @economyShopEquip.
  ///
  /// In en, this message translates to:
  /// **'Equip'**
  String get economyShopEquip;

  /// No description provided for @economyShopEquipFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change this. Try again.'**
  String get economyShopEquipFailed;

  /// No description provided for @economyShopEquipped.
  ///
  /// In en, this message translates to:
  /// **'{name} equipped'**
  String economyShopEquipped(String name);

  /// No description provided for @economyShopFounders.
  ///
  /// In en, this message translates to:
  /// **'Founders'**
  String get economyShopFounders;

  /// No description provided for @economyShopFrames.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get economyShopFrames;

  /// No description provided for @economyShopGlass.
  ///
  /// In en, this message translates to:
  /// **'Glass'**
  String get economyShopGlass;

  /// No description provided for @economyShopGlowPreviewName.
  ///
  /// In en, this message translates to:
  /// **'Glint'**
  String get economyShopGlowPreviewName;

  /// No description provided for @economyShopGlows.
  ///
  /// In en, this message translates to:
  /// **'Glows'**
  String get economyShopGlows;

  /// No description provided for @economyShopGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get economyShopGold;

  /// No description provided for @economyShopIconEnabled.
  ///
  /// In en, this message translates to:
  /// **'{name} icon is on'**
  String economyShopIconEnabled(String name);

  /// No description provided for @economyShopIcons.
  ///
  /// In en, this message translates to:
  /// **'Icons'**
  String get economyShopIcons;

  /// No description provided for @economyShopItemSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {status}'**
  String economyShopItemSemantics(String name, String status);

  /// No description provided for @economyShopJungle.
  ///
  /// In en, this message translates to:
  /// **'Jungle'**
  String get economyShopJungle;

  /// No description provided for @economyShopMono.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get economyShopMono;

  /// No description provided for @economyShopNeedMoreCoins.
  ///
  /// In en, this message translates to:
  /// **'You need more coins for this'**
  String get economyShopNeedMoreCoins;

  /// No description provided for @economyShopNoir.
  ///
  /// In en, this message translates to:
  /// **'Noir'**
  String get economyShopNoir;

  /// No description provided for @economyShopOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get economyShopOcean;

  /// No description provided for @economyShopOlive.
  ///
  /// In en, this message translates to:
  /// **'Olive'**
  String get economyShopOlive;

  /// No description provided for @economyShopPepper.
  ///
  /// In en, this message translates to:
  /// **'Pepper'**
  String get economyShopPepper;

  /// No description provided for @economyShopPrism.
  ///
  /// In en, this message translates to:
  /// **'Prism'**
  String get economyShopPrism;

  /// No description provided for @economyShopProOnly.
  ///
  /// In en, this message translates to:
  /// **'This item is for Pro members'**
  String get economyShopProOnly;

  /// No description provided for @economyShopPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not buy this. Try again.'**
  String get economyShopPurchaseFailed;

  /// No description provided for @economyShopPurchased.
  ///
  /// In en, this message translates to:
  /// **'{name} is yours'**
  String economyShopPurchased(String name);

  /// No description provided for @economyShopRankLocked.
  ///
  /// In en, this message translates to:
  /// **'Reach {rank} rank to unlock this'**
  String economyShopRankLocked(String rank);

  /// No description provided for @economyShopRankReachedSyncing.
  ///
  /// In en, this message translates to:
  /// **'Rank reached. Your reward is syncing.'**
  String get economyShopRankReachedSyncing;

  /// No description provided for @economyShopRankRewardSynced.
  ///
  /// In en, this message translates to:
  /// **'{name} rank reward synced'**
  String economyShopRankRewardSynced(String name);

  /// No description provided for @economyShopReachRankToBuy.
  ///
  /// In en, this message translates to:
  /// **'Reach {rank} rank to buy this.'**
  String economyShopReachRankToBuy(String rank);

  /// No description provided for @economyShopRing.
  ///
  /// In en, this message translates to:
  /// **'Ring'**
  String get economyShopRing;

  /// No description provided for @economyShopRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get economyShopRose;

  /// No description provided for @economyShopSaleUntil.
  ///
  /// In en, this message translates to:
  /// **'Limited. On sale until {date}.'**
  String economyShopSaleUntil(String date);

  /// No description provided for @economyShopSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get economyShopSky;

  /// No description provided for @economyShopSoldOut.
  ///
  /// In en, this message translates to:
  /// **'This limited item is sold out'**
  String get economyShopSoldOut;

  /// No description provided for @economyShopSteel.
  ///
  /// In en, this message translates to:
  /// **'Steel'**
  String get economyShopSteel;

  /// No description provided for @economyShopSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get economyShopSunset;

  /// No description provided for @economyShopSyncReward.
  ///
  /// In en, this message translates to:
  /// **'Sync reward'**
  String get economyShopSyncReward;

  /// No description provided for @economyShopThemes.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get economyShopThemes;

  /// No description provided for @economyShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get economyShopTitle;

  /// No description provided for @economyShopUnequip.
  ///
  /// In en, this message translates to:
  /// **'Unequip'**
  String get economyShopUnequip;

  /// No description provided for @economyShopUnequipped.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String economyShopUnequipped(String name);

  /// No description provided for @economyShopUseIcon.
  ///
  /// In en, this message translates to:
  /// **'Use icon'**
  String get economyShopUseIcon;

  /// No description provided for @economyShopUseTheme.
  ///
  /// In en, this message translates to:
  /// **'Use theme'**
  String get economyShopUseTheme;

  /// No description provided for @economyShopWearingNeedsPro.
  ///
  /// In en, this message translates to:
  /// **'Wearing this needs Pro.'**
  String get economyShopWearingNeedsPro;

  /// No description provided for @economyShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get economyShowMore;

  /// No description provided for @economySignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get economySignIn;

  /// No description provided for @economySoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get economySoldOut;

  /// No description provided for @economySoon.
  ///
  /// In en, this message translates to:
  /// **'soon'**
  String get economySoon;

  /// No description provided for @economySpendItemSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}, {price}'**
  String economySpendItemSemantics(String label, String price);

  /// No description provided for @economySpin.
  ///
  /// In en, this message translates to:
  /// **'SPIN'**
  String get economySpin;

  /// No description provided for @economySpinAgain.
  ///
  /// In en, this message translates to:
  /// **'Spin again'**
  String get economySpinAgain;

  /// No description provided for @economySpinAgainFree.
  ///
  /// In en, this message translates to:
  /// **'Spin again, free spin'**
  String get economySpinAgainFree;

  /// No description provided for @economySpinAgainPrice.
  ///
  /// In en, this message translates to:
  /// **'Spin again, {price} coins'**
  String economySpinAgainPrice(int price);

  /// No description provided for @economySpinCardCaption.
  ///
  /// In en, this message translates to:
  /// **'{price} coins a spin. Win up to {maximum} coins or a cosmetic'**
  String economySpinCardCaption(int price, int maximum);

  /// No description provided for @economySpinCosts.
  ///
  /// In en, this message translates to:
  /// **'A spin costs {price} coins'**
  String economySpinCosts(int price);

  /// No description provided for @economySpinFree.
  ///
  /// In en, this message translates to:
  /// **'Spin, free spin'**
  String get economySpinFree;

  /// No description provided for @economySpinPrice.
  ///
  /// In en, this message translates to:
  /// **'Spin, {price} coins'**
  String economySpinPrice(int price);

  /// No description provided for @economySpinPriceChanged.
  ///
  /// In en, this message translates to:
  /// **'The price changed. Check it and spin again.'**
  String get economySpinPriceChanged;

  /// No description provided for @economySpinShortBalanceMessage.
  ///
  /// In en, this message translates to:
  /// **'A spin costs {price} coins. You have {balance}. Watch a video to earn more.'**
  String economySpinShortBalanceMessage(int price, int balance);

  /// No description provided for @economySpinTheWheel.
  ///
  /// In en, this message translates to:
  /// **'Spin the wheel'**
  String get economySpinTheWheel;

  /// No description provided for @economySpinWheelCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'Spin the wheel. {caption}'**
  String economySpinWheelCardSemantics(String caption);

  /// No description provided for @economySpinning.
  ///
  /// In en, this message translates to:
  /// **'Spinning'**
  String get economySpinning;

  /// No description provided for @economySpinsLeftToday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 spin} other{{count} spins}} left today.'**
  String economySpinsLeftToday(int count);

  /// No description provided for @economyStreak.
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get economyStreak;

  /// No description provided for @economyStreakChestReward.
  ///
  /// In en, this message translates to:
  /// **'+{coins} Day 7 chest'**
  String economyStreakChestReward(int coins);

  /// No description provided for @economyStreakCollection.
  ///
  /// In en, this message translates to:
  /// **'Streak collection'**
  String get economyStreakCollection;

  /// No description provided for @economyStreakCollectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Unlock wallpapers by keeping your streak or using coins.'**
  String get economyStreakCollectionDescription;

  /// No description provided for @economyStreakCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day streak} other{{count} days streak}}'**
  String economyStreakCount(int count);

  /// No description provided for @economyStreakCycleSemantics.
  ///
  /// In en, this message translates to:
  /// **'Day {day}{showReward, select, true{, plus {reward} coins} other{}}{state, select, done{, done} today{, today} other{}}'**
  String economyStreakCycleSemantics(int day, String showReward, int reward, String state);

  /// No description provided for @economyStreakDailyReward.
  ///
  /// In en, this message translates to:
  /// **'+{coins} today'**
  String economyStreakDailyReward(int coins);

  /// No description provided for @economyStreakDayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of your streak'**
  String economyStreakDayNumber(int day);

  /// No description provided for @economyStreakFreeze.
  ///
  /// In en, this message translates to:
  /// **'Streak freeze'**
  String get economyStreakFreeze;

  /// No description provided for @economyStreakFreezeSaved.
  ///
  /// In en, this message translates to:
  /// **'A freeze saved your {days}-day streak'**
  String economyStreakFreezeSaved(int days);

  /// No description provided for @economyStreakFreezesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 freeze left} other{{count} freezes left}}'**
  String economyStreakFreezesLeft(int count);

  /// No description provided for @economyStreakProReward.
  ///
  /// In en, this message translates to:
  /// **'+{coins} x{multiplier} Pro'**
  String economyStreakProReward(int coins, String multiplier);

  /// No description provided for @economyStreakRescueCooldown.
  ///
  /// In en, this message translates to:
  /// **'You can restore one streak every 30 days.'**
  String get economyStreakRescueCooldown;

  /// No description provided for @economyStreakRescueExpired.
  ///
  /// In en, this message translates to:
  /// **'The 48 hours to restore this streak are over.'**
  String get economyStreakRescueExpired;

  /// No description provided for @economyStreakRescueFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore your streak. Try again.'**
  String get economyStreakRescueFailed;

  /// No description provided for @economyStreakRescueUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This streak can\'t be restored now.'**
  String get economyStreakRescueUnavailable;

  /// No description provided for @economyStreakReset.
  ///
  /// In en, this message translates to:
  /// **'Your streak reset'**
  String get economyStreakReset;

  /// No description provided for @economyStreakResetMessage.
  ///
  /// In en, this message translates to:
  /// **'You were on {days} days. Start again today, +{coins} coins.'**
  String economyStreakResetMessage(int days, int coins);

  /// No description provided for @economyStreakRestoreShort.
  ///
  /// In en, this message translates to:
  /// **'You have {balance}. You need {cost}.'**
  String economyStreakRestoreShort(int balance, int cost);

  /// No description provided for @economyStreakRestored.
  ///
  /// In en, this message translates to:
  /// **'Your streak is back'**
  String get economyStreakRestored;

  /// No description provided for @economyStreakRestoredCount.
  ///
  /// In en, this message translates to:
  /// **'You are on {count} days again.'**
  String economyStreakRestoredCount(int count);

  /// No description provided for @economyToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get economyToday;

  /// No description provided for @economyUnknownCosmetic.
  ///
  /// In en, this message translates to:
  /// **'Cosmetic'**
  String get economyUnknownCosmetic;

  /// No description provided for @economyUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String economyUntil(String date);

  /// No description provided for @economyUpToCoins.
  ///
  /// In en, this message translates to:
  /// **'Up to +{count}'**
  String economyUpToCoins(int count);

  /// No description provided for @economyUpgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get economyUpgradeToPro;

  /// No description provided for @economyUseReward.
  ///
  /// In en, this message translates to:
  /// **'Use {reward}'**
  String economyUseReward(String reward);

  /// No description provided for @economyUseYourCoins.
  ///
  /// In en, this message translates to:
  /// **'Use your coins'**
  String get economyUseYourCoins;

  /// No description provided for @economyWatchAd.
  ///
  /// In en, this message translates to:
  /// **'Watch ad'**
  String get economyWatchAd;

  /// No description provided for @economyWatchVideo.
  ///
  /// In en, this message translates to:
  /// **'Watch a video'**
  String get economyWatchVideo;

  /// No description provided for @economyWatchVideoRewardAdsLeft.
  ///
  /// In en, this message translates to:
  /// **'Watch a video · {count, plural, one{1 ad} other{{count} ads}} left today'**
  String economyWatchVideoRewardAdsLeft(int count);

  /// No description provided for @economyWatchVideoRewardCoins.
  ///
  /// In en, this message translates to:
  /// **'Watch a video (+{coins})'**
  String economyWatchVideoRewardCoins(int coins);

  /// No description provided for @economyWeekComplete.
  ///
  /// In en, this message translates to:
  /// **'Week complete!'**
  String get economyWeekComplete;

  /// No description provided for @economyWeekly.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY'**
  String get economyWeekly;

  /// No description provided for @economyWeeklyDraw.
  ///
  /// In en, this message translates to:
  /// **'Weekly draw'**
  String get economyWeeklyDraw;

  /// No description provided for @economyWeeklyDrop.
  ///
  /// In en, this message translates to:
  /// **'Weekly Drop'**
  String get economyWeeklyDrop;

  /// No description provided for @economyWeeklyEndsIn.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY · {time}'**
  String economyWeeklyEndsIn(String time);

  /// No description provided for @economyWeeklyXpFriendsEveryone.
  ///
  /// In en, this message translates to:
  /// **'Weekly XP, friends and everyone'**
  String get economyWeeklyXpFriendsEveryone;

  /// No description provided for @economyWonCoins.
  ///
  /// In en, this message translates to:
  /// **'You won {coins, plural, one{1 coin} other{{coins} coins}}'**
  String economyWonCoins(int coins);

  /// No description provided for @economyWonCosmetic.
  ///
  /// In en, this message translates to:
  /// **'You won a new {kind}: {name}'**
  String economyWonCosmetic(String kind, String name);

  /// No description provided for @economyWonUnknownCosmetic.
  ///
  /// In en, this message translates to:
  /// **'You won a cosmetic'**
  String get economyWonUnknownCosmetic;

  /// No description provided for @economyWonXp.
  ///
  /// In en, this message translates to:
  /// **'You won {xp} XP'**
  String economyWonXp(int xp);

  /// No description provided for @economyXp.
  ///
  /// In en, this message translates to:
  /// **'{count} XP'**
  String economyXp(int count);

  /// No description provided for @economyXpActivityDetails.
  ///
  /// In en, this message translates to:
  /// **'Daily streaks earn {dailyStreak} XP, plus {streakWeek} XP for completing a seven-day cycle. Quest chests earn {questChest} XP. Your first valid upload earns {upload} XP; profile completion earns {profile} XP. Daily quests award {dailyQuest} XP each; the weekly quest awards {weeklyQuest} XP. Some badges and creator milestones also earn XP.'**
  String economyXpActivityDetails(
    int dailyStreak,
    int streakWeek,
    int questChest,
    int upload,
    int profile,
    int dailyQuest,
    int weeklyQuest,
  );

  /// No description provided for @economyXpAwarded.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String economyXpAwarded(int xp);

  /// No description provided for @economyXpRanksRewards.
  ///
  /// In en, this message translates to:
  /// **'XP, ranks & rewards'**
  String get economyXpRanksRewards;

  /// No description provided for @economyXpToRank.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP to {rank}'**
  String economyXpToRank(String xp, String rank);

  /// No description provided for @economyXpUnit.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get economyXpUnit;

  /// No description provided for @economyYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get economyYesterday;

  /// No description provided for @economyYouHaveCoins.
  ///
  /// In en, this message translates to:
  /// **'You have {count} coins'**
  String economyYouHaveCoins(int count);

  /// No description provided for @economyYourXp.
  ///
  /// In en, this message translates to:
  /// **'YOUR XP'**
  String get economyYourXp;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get errorNetwork;

  /// Live status announcement when the app regains network connectivity.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get navigationBackOnline;

  /// Live status announcement while the app has no network connection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get navigationNoInternetConnection;

  /// Tooltip for the floating bottom bar control that scrolls content to the top.
  ///
  /// In en, this message translates to:
  /// **'Scroll to top'**
  String get navigationScrollToTop;

  /// No description provided for @notifActivateToCollapse.
  ///
  /// In en, this message translates to:
  /// **'Activate to collapse.'**
  String get notifActivateToCollapse;

  /// No description provided for @notifActivateToExpand.
  ///
  /// In en, this message translates to:
  /// **'Activate to expand.'**
  String get notifActivateToExpand;

  /// No description provided for @notifChannelDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get notifChannelDownloads;

  /// No description provided for @notifChannelDownloadsDescription.
  ///
  /// In en, this message translates to:
  /// **'Get notifications for download progress of wallpapers.'**
  String get notifChannelDownloadsDescription;

  /// No description provided for @notifChannelDraw.
  ///
  /// In en, this message translates to:
  /// **'Prism Draw'**
  String get notifChannelDraw;

  /// No description provided for @notifChannelDrawDescription.
  ///
  /// In en, this message translates to:
  /// **'Draw results and prizes.'**
  String get notifChannelDrawDescription;

  /// No description provided for @notifChannelDrops.
  ///
  /// In en, this message translates to:
  /// **'Weekly Drops'**
  String get notifChannelDrops;

  /// No description provided for @notifChannelDropsDescription.
  ///
  /// In en, this message translates to:
  /// **'When a new Drop is live and before it ends.'**
  String get notifChannelDropsDescription;

  /// No description provided for @notifChannelFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get notifChannelFollowers;

  /// No description provided for @notifChannelFollowersDescription.
  ///
  /// In en, this message translates to:
  /// **'Get notifications for new followers.'**
  String get notifChannelFollowersDescription;

  /// No description provided for @notifChannelGifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get notifChannelGifts;

  /// No description provided for @notifChannelGiftsDescription.
  ///
  /// In en, this message translates to:
  /// **'A friend sent you a Pro pass.'**
  String get notifChannelGiftsDescription;

  /// No description provided for @notifChannelGroup.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifChannelGroup;

  /// No description provided for @notifChannelGroupDescription.
  ///
  /// In en, this message translates to:
  /// **'All Prism Notifications'**
  String get notifChannelGroupDescription;

  /// No description provided for @notifChannelModeration.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get notifChannelModeration;

  /// No description provided for @notifChannelModerationDescription.
  ///
  /// In en, this message translates to:
  /// **'Reports and review requests for Prism admins.'**
  String get notifChannelModerationDescription;

  /// No description provided for @notifChannelPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get notifChannelPosts;

  /// No description provided for @notifChannelPostsDescription.
  ///
  /// In en, this message translates to:
  /// **'Get notifications for posts from artists you follow.'**
  String get notifChannelPostsDescription;

  /// No description provided for @notifChannelRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get notifChannelRecommendations;

  /// No description provided for @notifChannelRecommendationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Get notifications for recommendations from Prism.'**
  String get notifChannelRecommendationsDescription;

  /// No description provided for @notifChannelStreaks.
  ///
  /// In en, this message translates to:
  /// **'Streak reminders'**
  String get notifChannelStreaks;

  /// No description provided for @notifChannelStreaksDescription.
  ///
  /// In en, this message translates to:
  /// **'8 PM reminder to keep your login streak alive.'**
  String get notifChannelStreaksDescription;

  /// No description provided for @notifChannelWotd.
  ///
  /// In en, this message translates to:
  /// **'Wall of the Day'**
  String get notifChannelWotd;

  /// No description provided for @notifChannelWotdDescription.
  ///
  /// In en, this message translates to:
  /// **'Daily featured wallpaper notification at 9 AM.'**
  String get notifChannelWotdDescription;

  /// No description provided for @notifClearDeviceMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes them from this device.'**
  String get notifClearDeviceMessage;

  /// No description provided for @notifClearInbox.
  ///
  /// In en, this message translates to:
  /// **'Clear inbox'**
  String get notifClearInbox;

  /// No description provided for @notifClearInboxAction.
  ///
  /// In en, this message translates to:
  /// **'Clear inbox'**
  String get notifClearInboxAction;

  /// No description provided for @notifClearManyTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear {count} notifications?'**
  String notifClearManyTitle(int count);

  /// No description provided for @notifClearOneTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear this notification?'**
  String get notifClearOneTitle;

  /// No description provided for @notifCollapsed.
  ///
  /// In en, this message translates to:
  /// **'Collapsed'**
  String get notifCollapsed;

  /// No description provided for @notifDownloadedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 wall downloaded.} other{{count} walls downloaded.}}'**
  String notifDownloadedTitle(int count);

  /// No description provided for @notifDownloadingWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Downloading wallpaper'**
  String get notifDownloadingWallpaper;

  /// No description provided for @notifEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'New followers, approvals and the Wall of the Day show up here.'**
  String get notifEmptyBody;

  /// No description provided for @notifEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notifEmptyTitle;

  /// No description provided for @notifExpanded.
  ///
  /// In en, this message translates to:
  /// **'Expanded'**
  String get notifExpanded;

  /// No description provided for @notifGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notifGenericTitle;

  /// No description provided for @notifGroupAndMore.
  ///
  /// In en, this message translates to:
  /// **'{message} and {otherCount, plural, one{1 more.} other{{otherCount} more.}}'**
  String notifGroupAndMore(String message, int otherCount);

  /// No description provided for @notifGroupApprovals.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{approval} other{approvals}}'**
  String notifGroupApprovals(int count);

  /// No description provided for @notifGroupCountAction.
  ///
  /// In en, this message translates to:
  /// **'{count} {label} · {action}'**
  String notifGroupCountAction(int count, String label, String action);

  /// No description provided for @notifGroupCreatorSummary.
  ///
  /// In en, this message translates to:
  /// **'From {name} and {otherCount, plural, one{1 other creator.} other{{otherCount} other creators.}}'**
  String notifGroupCreatorSummary(String name, int otherCount);

  /// No description provided for @notifGroupDailyPicks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{daily pick} other{daily picks}}'**
  String notifGroupDailyPicks(int count);

  /// No description provided for @notifGroupDayRows.
  ///
  /// In en, this message translates to:
  /// **'Each row is a different day; times are on the right.'**
  String get notifGroupDayRows;

  /// No description provided for @notifGroupFollowerSummary.
  ///
  /// In en, this message translates to:
  /// **'{name} and {otherCount, plural, one{1 other followed you.} other{{otherCount} others followed you.}}'**
  String notifGroupFollowerSummary(String name, int otherCount);

  /// No description provided for @notifGroupFollowers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{new follower} other{new followers}}'**
  String notifGroupFollowers(int count);

  /// No description provided for @notifGroupHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get notifGroupHide;

  /// No description provided for @notifGroupNotifications.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{notification} other{notifications}}'**
  String notifGroupNotifications(int count);

  /// No description provided for @notifGroupNotificationsRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 notification removed} other{{count} notifications removed}}'**
  String notifGroupNotificationsRemoved(int count);

  /// No description provided for @notifGroupSameMessage.
  ///
  /// In en, this message translates to:
  /// **'Same message sent {count} times. Compare timestamps to see when.'**
  String notifGroupSameMessage(int count);

  /// No description provided for @notifGroupSemantics.
  ///
  /// In en, this message translates to:
  /// **'{title}. {summary}. {expandedState}. {unreadStatus} {action}'**
  String notifGroupSemantics(String title, String summary, String expandedState, String unreadStatus, String action);

  /// No description provided for @notifGroupSeveralCreators.
  ///
  /// In en, this message translates to:
  /// **'Several creators. Expand to see each wall.'**
  String get notifGroupSeveralCreators;

  /// No description provided for @notifGroupShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get notifGroupShowAll;

  /// No description provided for @notifGroupSummaryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 notification in this group.} other{{count} notifications in this group.}}'**
  String notifGroupSummaryCount(int count);

  /// No description provided for @notifGroupWallLive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{wall went live} other{walls went live}}'**
  String notifGroupWallLive(int count);

  /// No description provided for @notifHasUnread.
  ///
  /// In en, this message translates to:
  /// **'Has unread.'**
  String get notifHasUnread;

  /// No description provided for @notifInboxCleared.
  ///
  /// In en, this message translates to:
  /// **'Inbox cleared'**
  String get notifInboxCleared;

  /// No description provided for @notifLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your notifications'**
  String get notifLoadErrorTitle;

  /// No description provided for @notifMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notifMarkAllRead;

  /// No description provided for @notifOfflineSaved.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load new notifications. What you see below is saved on this device.'**
  String get notifOfflineSaved;

  /// No description provided for @notifOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get notifOpenSettings;

  /// No description provided for @notifPermissionOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off. Turn them on in system settings first.'**
  String get notifPermissionOff;

  /// No description provided for @notifPermissionOffForApp.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for Prism.'**
  String get notifPermissionOffForApp;

  /// No description provided for @notifPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get notifPreferences;

  /// No description provided for @notifPushDrawWinnerBody.
  ///
  /// In en, this message translates to:
  /// **'One month of Pro and the Prism frame are yours.'**
  String get notifPushDrawWinnerBody;

  /// No description provided for @notifPushDrawWinnerTitle.
  ///
  /// In en, this message translates to:
  /// **'You won the Prism Draw'**
  String get notifPushDrawWinnerTitle;

  /// No description provided for @notifPushDropLastCallBody.
  ///
  /// In en, this message translates to:
  /// **'{dropTitle} ends in {hours, plural, one{1 hour} other{{hours} hours}}. Then these walls are gone for a month.'**
  String notifPushDropLastCallBody(String dropTitle, int hours);

  /// No description provided for @notifPushDropLastCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Last call on this week\'s Drop'**
  String get notifPushDropLastCallTitle;

  /// No description provided for @notifPushDropLiveBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 wall, this week only. Preview it before it is gone.} other{{count} walls, this week only. Preview them before they are gone.}}'**
  String notifPushDropLiveBody(int count);

  /// No description provided for @notifPushDropLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'A new Drop is live'**
  String get notifPushDropLiveTitle;

  /// No description provided for @notifPushFollowDigestTitleOne.
  ///
  /// In en, this message translates to:
  /// **'{artistName} posted a new wall'**
  String notifPushFollowDigestTitleOne(String artistName);

  /// No description provided for @notifPushFollowDigestTitleSolo.
  ///
  /// In en, this message translates to:
  /// **'{artistName} posted {wallCount} new walls'**
  String notifPushFollowDigestTitleSolo(String artistName, int wallCount);

  /// No description provided for @notifPushFollowDigestTitlePair.
  ///
  /// In en, this message translates to:
  /// **'{artistName} and {secondArtistName} posted {wallCount} new walls'**
  String notifPushFollowDigestTitlePair(String artistName, String secondArtistName, int wallCount);

  /// No description provided for @notifPushFollowDigestTitleGroup.
  ///
  /// In en, this message translates to:
  /// **'{artistName} and {otherCount} others posted {wallCount} new walls'**
  String notifPushFollowDigestTitleGroup(String artistName, int otherCount, int wallCount);

  /// No description provided for @notifPushFollowDigestBodyUntitled.
  ///
  /// In en, this message translates to:
  /// **'Tap to see them all.'**
  String get notifPushFollowDigestBodyUntitled;

  /// No description provided for @notifPushGiftReceivedBody.
  ///
  /// In en, this message translates to:
  /// **'Premium collections and premium walls are open until tomorrow.'**
  String get notifPushGiftReceivedBody;

  /// No description provided for @notifPushGiftReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'{senderName} sent you a 24-hour Pro pass'**
  String notifPushGiftReceivedTitle(String senderName);

  /// No description provided for @notifPushNewContentReportBody.
  ///
  /// In en, this message translates to:
  /// **'{contentType} · {reason} · doc {targetId}'**
  String notifPushNewContentReportBody(String contentType, String reason, String targetId);

  /// No description provided for @notifPushNewContentReportTitle.
  ///
  /// In en, this message translates to:
  /// **'New content report'**
  String get notifPushNewContentReportTitle;

  /// No description provided for @notifPushNewFollowerBody.
  ///
  /// In en, this message translates to:
  /// **'{followerName} is now following you.'**
  String notifPushNewFollowerBody(String followerName);

  /// No description provided for @notifPushNewFollowerTitle.
  ///
  /// In en, this message translates to:
  /// **'You have a new follower! 🎉'**
  String get notifPushNewFollowerTitle;

  /// No description provided for @notifPushReportReviewBody.
  ///
  /// In en, this message translates to:
  /// **'{contentType} · {reason} · open for over 12 hours'**
  String notifPushReportReviewBody(String contentType, String reason);

  /// No description provided for @notifPushReportReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Report waiting for review'**
  String get notifPushReportReviewTitle;

  /// No description provided for @notifPushStreakReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Open Prism now to keep your login streak alive 🔥'**
  String get notifPushStreakReminderBody;

  /// No description provided for @notifPushStreakReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Your streak is about to break!'**
  String get notifPushStreakReminderTitle;

  /// No description provided for @notifPushWallApprovedAdminBody.
  ///
  /// In en, this message translates to:
  /// **'\"{wallTitle}\" by {artistName} is now live.'**
  String notifPushWallApprovedAdminBody(String wallTitle, String artistName);

  /// No description provided for @notifPushWallApprovedAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Wall approved ✅'**
  String get notifPushWallApprovedAdminTitle;

  /// No description provided for @notifPushWallApprovedArtistBody.
  ///
  /// In en, this message translates to:
  /// **'\"{wallTitle}\" has been approved and is now visible to everyone.'**
  String notifPushWallApprovedArtistBody(String wallTitle);

  /// No description provided for @notifPushWallApprovedArtistBodyUntitled.
  ///
  /// In en, this message translates to:
  /// **'Your wallpaper has been approved and is now visible to everyone.'**
  String get notifPushWallApprovedArtistBodyUntitled;

  /// No description provided for @notifPushWallApprovedArtistTitle.
  ///
  /// In en, this message translates to:
  /// **'Your wallpaper is live! 🎉'**
  String get notifPushWallApprovedArtistTitle;

  /// No description provided for @notifPushWallLiveFollowersBody.
  ///
  /// In en, this message translates to:
  /// **'\"{wallTitle}\" is now live on Prism.'**
  String notifPushWallLiveFollowersBody(String wallTitle);

  /// No description provided for @notifPushWallLiveFollowersTitle.
  ///
  /// In en, this message translates to:
  /// **'New wall by {artistName}'**
  String notifPushWallLiveFollowersTitle(String artistName);

  /// No description provided for @notifPushWallSubmittedBody.
  ///
  /// In en, this message translates to:
  /// **'New post by {artistName} ({artistEmail}) is up for review.'**
  String notifPushWallSubmittedBody(String artistName, String artistEmail);

  /// No description provided for @notifPushWallSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'New Premium Wall for review! 🎉'**
  String get notifPushWallSubmittedTitle;

  /// No description provided for @notifPushWinBack14Body.
  ///
  /// In en, this message translates to:
  /// **'Come see what creators added this fortnight.'**
  String get notifPushWinBack14Body;

  /// No description provided for @notifPushWinBack14Title.
  ///
  /// In en, this message translates to:
  /// **'New walls are waiting'**
  String get notifPushWinBack14Title;

  /// No description provided for @notifPushWinBack30Body.
  ///
  /// In en, this message translates to:
  /// **'Make a wallpaper that feels like you.'**
  String get notifPushWinBack30Body;

  /// No description provided for @notifPushWinBack30Title.
  ///
  /// In en, this message translates to:
  /// **'New AI styles to try'**
  String get notifPushWinBack30Title;

  /// No description provided for @notifPushWinBack60Body.
  ///
  /// In en, this message translates to:
  /// **'Your next favourite wall is a tap away.'**
  String get notifPushWinBack60Body;

  /// No description provided for @notifPushWinBack60Title.
  ///
  /// In en, this message translates to:
  /// **'Prism misses you'**
  String get notifPushWinBack60Title;

  /// No description provided for @notifPushWinBack7Body.
  ///
  /// In en, this message translates to:
  /// **'Fresh wallpapers landed while you were away.'**
  String get notifPushWinBack7Body;

  /// No description provided for @notifPushWinBack7Title.
  ///
  /// In en, this message translates to:
  /// **'Your feed has new walls'**
  String get notifPushWinBack7Title;

  /// No description provided for @notifPushWotdAudienceBody.
  ///
  /// In en, this message translates to:
  /// **'{wallTitle}'**
  String notifPushWotdAudienceBody(String wallTitle);

  /// No description provided for @notifPushWotdAudienceBodyUntitled.
  ///
  /// In en, this message translates to:
  /// **'Open Prism to see today\'s Wall of the Day.'**
  String get notifPushWotdAudienceBodyUntitled;

  /// No description provided for @notifPushWotdAudienceTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Wall of the Day is here'**
  String get notifPushWotdAudienceTitle;

  /// No description provided for @notifPushWotdCreatorBody.
  ///
  /// In en, this message translates to:
  /// **'Prism picked your wallpaper for everyone today. Thank you for sharing it.'**
  String get notifPushWotdCreatorBody;

  /// No description provided for @notifPushWotdCreatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Your wallpaper is the Wall of the Day'**
  String get notifPushWotdCreatorTitle;

  /// No description provided for @notifRead.
  ///
  /// In en, this message translates to:
  /// **'Already read'**
  String get notifRead;

  /// No description provided for @notifRemoved.
  ///
  /// In en, this message translates to:
  /// **'Notification removed'**
  String get notifRemoved;

  /// No description provided for @notifReportUnknownContentType.
  ///
  /// In en, this message translates to:
  /// **'content'**
  String get notifReportUnknownContentType;

  /// No description provided for @notifSemanticsRow.
  ///
  /// In en, this message translates to:
  /// **'{message}. {time}. {readStatus}'**
  String notifSemanticsRow(String message, String time, String readStatus);

  /// No description provided for @notifSettingDrops.
  ///
  /// In en, this message translates to:
  /// **'Weekly Drops'**
  String get notifSettingDrops;

  /// No description provided for @notifSettingDropsDescription.
  ///
  /// In en, this message translates to:
  /// **'Alerts when a new Drop is live and before it ends.'**
  String get notifSettingDropsDescription;

  /// No description provided for @notifSettingFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get notifSettingFollowers;

  /// No description provided for @notifSettingFollowersDescription.
  ///
  /// In en, this message translates to:
  /// **'Alerts when someone new follows you.'**
  String get notifSettingFollowersDescription;

  /// No description provided for @notifSettingPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get notifSettingPosts;

  /// No description provided for @notifSettingPostsDescription.
  ///
  /// In en, this message translates to:
  /// **'Alerts when creators you follow share new work.'**
  String get notifSettingPostsDescription;

  /// No description provided for @notifSettingRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get notifSettingRecommendations;

  /// No description provided for @notifSettingRecommendationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Tips, news and wallpaper picks from Prism.'**
  String get notifSettingRecommendationsDescription;

  /// No description provided for @notifSettingStreaks.
  ///
  /// In en, this message translates to:
  /// **'Streak reminders'**
  String get notifSettingStreaks;

  /// No description provided for @notifSettingStreaksDescription.
  ///
  /// In en, this message translates to:
  /// **'Evening heads-up around 8 PM if your login streak is about to break.'**
  String get notifSettingStreaksDescription;

  /// No description provided for @notifSettingWotd.
  ///
  /// In en, this message translates to:
  /// **'Wall of the Day'**
  String get notifSettingWotd;

  /// No description provided for @notifSettingWotdDescription.
  ///
  /// In en, this message translates to:
  /// **'A daily wallpaper pick.'**
  String get notifSettingWotdDescription;

  /// No description provided for @notifSignInToChange.
  ///
  /// In en, this message translates to:
  /// **'Sign in to change this setting.'**
  String get notifSignInToChange;

  /// No description provided for @notifSignInToTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to turn on'**
  String get notifSignInToTurnOn;

  /// No description provided for @notifTapToOpenPrism.
  ///
  /// In en, this message translates to:
  /// **'Tap to open Prism.'**
  String get notifTapToOpenPrism;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notifToday;

  /// No description provided for @notifUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get notifUndo;

  /// No description provided for @notifUnread.
  ///
  /// In en, this message translates to:
  /// **'Not read yet'**
  String get notifUnread;

  /// No description provided for @notifYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notifYesterday;

  /// No description provided for @notifYesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String notifYesterdayAt(String time);

  /// No description provided for @onboardingAiGenerateError.
  ///
  /// In en, this message translates to:
  /// **'something went wrong.\ntap generate to try again.'**
  String get onboardingAiGenerateError;

  /// No description provided for @onboardingAiGeneratePrompt.
  ///
  /// In en, this message translates to:
  /// **'tap generate to create\nyour unique wallpaper'**
  String get onboardingAiGeneratePrompt;

  /// No description provided for @onboardingAiGenerating.
  ///
  /// In en, this message translates to:
  /// **'crafting your wallpaper…'**
  String get onboardingAiGenerating;

  /// No description provided for @onboardingBrowseGuest.
  ///
  /// In en, this message translates to:
  /// **'Browse without an account'**
  String get onboardingBrowseGuest;

  /// No description provided for @onboardingCategoriesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'we could not load categories, you can skip this step'**
  String get onboardingCategoriesUnavailable;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingContinueApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get onboardingContinueApple;

  /// No description provided for @onboardingContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get onboardingContinueGoogle;

  /// No description provided for @onboardingContinueSelected.
  ///
  /// In en, this message translates to:
  /// **'continue ({count} selected)'**
  String onboardingContinueSelected(int count);

  /// No description provided for @onboardingCouldNotLogOut.
  ///
  /// In en, this message translates to:
  /// **'Could not log out. Please try again.'**
  String get onboardingCouldNotLogOut;

  /// No description provided for @onboardingCreatorsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'we could not load creators, you can skip this step'**
  String get onboardingCreatorsUnavailable;

  /// No description provided for @onboardingFirstAiWallpaper.
  ///
  /// In en, this message translates to:
  /// **'your first wallpaper, generated by AI'**
  String get onboardingFirstAiWallpaper;

  /// No description provided for @onboardingFirstWallpaperSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your wallpaper. Try again or skip.'**
  String get onboardingFirstWallpaperSaveFailed;

  /// No description provided for @onboardingFirstWallpaperSavedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Saved to Photos!'**
  String get onboardingFirstWallpaperSavedPhotos;

  /// No description provided for @onboardingFirstWallpaperSet.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper set!'**
  String get onboardingFirstWallpaperSet;

  /// No description provided for @onboardingFirstWallpaperSetFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set your wallpaper. Try again or skip.'**
  String get onboardingFirstWallpaperSetFailed;

  /// No description provided for @onboardingFirstWallpaperSetHome.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper set on your home screen.'**
  String get onboardingFirstWallpaperSetHome;

  /// No description provided for @onboardingFirstWallpaperSetHomeLock.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper set on your home and lock screens.'**
  String get onboardingFirstWallpaperSetHomeLock;

  /// No description provided for @onboardingFirstWallpaperSetLock.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper set on your lock screen.'**
  String get onboardingFirstWallpaperSetLock;

  /// No description provided for @onboardingFollow.
  ///
  /// In en, this message translates to:
  /// **'follow'**
  String get onboardingFollow;

  /// No description provided for @onboardingFollowCreatorMinimum.
  ///
  /// In en, this message translates to:
  /// **'we are suggesting you follow these {count} creators'**
  String onboardingFollowCreatorMinimum(int count);

  /// No description provided for @onboardingFollowerCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} follower} other{{count} followers}}'**
  String onboardingFollowerCount(int count);

  /// No description provided for @onboardingFollowing.
  ///
  /// In en, this message translates to:
  /// **'following'**
  String get onboardingFollowing;

  /// No description provided for @onboardingGenerateFailure.
  ///
  /// In en, this message translates to:
  /// **'something went wrong — tap generate to try again'**
  String get onboardingGenerateFailure;

  /// No description provided for @onboardingGenerateSuccess.
  ///
  /// In en, this message translates to:
  /// **'looking good! opening your wallpaper'**
  String get onboardingGenerateSuccess;

  /// No description provided for @onboardingGenerateWallpaper.
  ///
  /// In en, this message translates to:
  /// **'generate my wallpaper'**
  String get onboardingGenerateWallpaper;

  /// No description provided for @onboardingHeadlineCreators.
  ///
  /// In en, this message translates to:
  /// **'Find your people'**
  String get onboardingHeadlineCreators;

  /// No description provided for @onboardingHeadlineCustomize.
  ///
  /// In en, this message translates to:
  /// **'Make it yours'**
  String get onboardingHeadlineCustomize;

  /// No description provided for @onboardingHeadlineGenerate.
  ///
  /// In en, this message translates to:
  /// **'Create your\nfirst wallpaper'**
  String get onboardingHeadlineGenerate;

  /// No description provided for @onboardingHeadlineInterests.
  ///
  /// In en, this message translates to:
  /// **'Pick your vibe'**
  String get onboardingHeadlineInterests;

  /// No description provided for @onboardingLoadCategoriesFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load categories.'**
  String get onboardingLoadCategoriesFailed;

  /// No description provided for @onboardingLoadCreatorsFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load creators.'**
  String get onboardingLoadCreatorsFailed;

  /// No description provided for @onboardingPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get onboardingPro;

  /// No description provided for @onboardingProFree.
  ///
  /// In en, this message translates to:
  /// **'  →  free for you'**
  String get onboardingProFree;

  /// No description provided for @onboardingRecoveryCreatorsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load creators. Check your connection and tap Reload.'**
  String get onboardingRecoveryCreatorsFailed;

  /// No description provided for @onboardingRecoveryFollowFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t follow these creators. Try again.'**
  String get onboardingRecoveryFollowFailed;

  /// No description provided for @onboardingRecoveryFollowFailedHelper.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t follow these creators. check your connection and try again'**
  String get onboardingRecoveryFollowFailedHelper;

  /// No description provided for @onboardingRecoveryReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get onboardingRecoveryReload;

  /// No description provided for @onboardingRecoveryRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get onboardingRecoveryRetry;

  /// No description provided for @onboardingRecoverySaveInterestsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your picks. Try again.'**
  String get onboardingRecoverySaveInterestsFailed;

  /// No description provided for @onboardingRecoverySaveInterestsFailedHelper.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t save your picks. check your connection and try again'**
  String get onboardingRecoverySaveInterestsFailedHelper;

  /// No description provided for @onboardingRecoverySessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get onboardingRecoverySessionExpired;

  /// No description provided for @onboardingRecoverySessionExpiredHelper.
  ///
  /// In en, this message translates to:
  /// **'your session has expired. sign in again to continue'**
  String get onboardingRecoverySessionExpiredHelper;

  /// No description provided for @onboardingRecoverySetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t finish setup. Try again.'**
  String get onboardingRecoverySetupFailed;

  /// No description provided for @onboardingRecoverySetupFailedHelper.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t finish setup. check your connection and try again'**
  String get onboardingRecoverySetupFailedHelper;

  /// No description provided for @onboardingRecoverySignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get onboardingRecoverySignIn;

  /// No description provided for @onboardingReloadLower.
  ///
  /// In en, this message translates to:
  /// **'reload'**
  String get onboardingReloadLower;

  /// No description provided for @onboardingSavePhotos.
  ///
  /// In en, this message translates to:
  /// **'save to photos'**
  String get onboardingSavePhotos;

  /// No description provided for @onboardingSelectInterestMinimum.
  ///
  /// In en, this message translates to:
  /// **'select at least {count} categories to personalize your feed'**
  String onboardingSelectInterestMinimum(int count);

  /// No description provided for @onboardingSetWallpaper.
  ///
  /// In en, this message translates to:
  /// **'set as wallpaper'**
  String get onboardingSetWallpaper;

  /// No description provided for @onboardingSignInAgainLower.
  ///
  /// In en, this message translates to:
  /// **'sign in again'**
  String get onboardingSignInAgainLower;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingSkipLower.
  ///
  /// In en, this message translates to:
  /// **'skip'**
  String get onboardingSkipLower;

  /// No description provided for @onboardingTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Terms and Privacy policy first.'**
  String get onboardingTermsRequired;

  /// No description provided for @onboardingTryAgainLower.
  ///
  /// In en, this message translates to:
  /// **'try again'**
  String get onboardingTryAgainLower;

  /// No description provided for @onboardingWallpaperForInterest.
  ///
  /// In en, this message translates to:
  /// **'we picked this wallpaper based on your interest in {category}'**
  String onboardingWallpaperForInterest(String category);

  /// No description provided for @onboardingWallpaperJustForYou.
  ///
  /// In en, this message translates to:
  /// **'we picked this wallpaper just for you'**
  String get onboardingWallpaperJustForYou;

  /// No description provided for @onboardingWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Millions of premium wallpapers from top artists.'**
  String get onboardingWelcomeDescription;

  /// No description provided for @onboardingWelcomeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your screen, reimagined.'**
  String get onboardingWelcomeHeadline;

  /// Introductory message on the Prism Premium plans page.
  ///
  /// In en, this message translates to:
  /// **'Explore Prism Premium plans.'**
  String get premiumPageExplorePlans;

  /// Message shown on the Prism Premium page when plans cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Plans are not available right now. Check your connection and try again.'**
  String get premiumPagePlansUnavailable;

  /// Title of the Prism Premium page.
  ///
  /// In en, this message translates to:
  /// **'Prism Premium'**
  String get premiumPageTitle;

  /// Action to retry loading Prism Premium plans.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get premiumPageTryAgain;

  /// Action to open the Prism Premium purchase plans.
  ///
  /// In en, this message translates to:
  /// **'View plans'**
  String get premiumPageViewPlans;

  /// A guest purchase or restore has active store entitlement locally, but account-based features require sign-in and server confirmation.
  ///
  /// In en, this message translates to:
  /// **'Your store purchase is active on this device. Sign in to use account-based Pro features.'**
  String get premiumGuestStorePurchaseActive;

  /// Toast after a purchase when the store has it but the server has not confirmed Pro yet.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is saved. Pro can take a minute to unlock.'**
  String get premiumPurchasePending;

  /// Toast after a purchase that neither the store nor the server could confirm.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm your purchase. Try Restore purchases in Settings.'**
  String get premiumPurchaseUnconfirmed;

  /// Wallpaper interface text: wallpaperAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get wallpaperAccentColor;

  /// Wallpaper interface text: wallpaperAccentColorsOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original wallpaper colors'**
  String get wallpaperAccentColorsOriginal;

  /// No description provided for @wallpaperResetOriginal.
  ///
  /// In en, this message translates to:
  /// **'Reset to original'**
  String get wallpaperResetOriginal;

  /// Filter option to show all wallpaper sources.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get wallpaperAll;

  /// Setting label for choosing where to apply a wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get wallpaperApplyTo;

  /// Message shown when auto-rotate is opened on an unsupported platform.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate is only available on Android.'**
  String get wallpaperAutoRotateAndroidOnly;

  /// Auto-rotate target setting section label.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get wallpaperAutoRotateApplyTo;

  /// Instructions copied to help keep auto-rotate running.
  ///
  /// In en, this message translates to:
  /// **'Open Settings, then Apps, Prism, Battery. Set battery use to Unrestricted.'**
  String get wallpaperAutoRotateBatterySteps;

  /// Battery settings guidance for auto-rotate.
  ///
  /// In en, this message translates to:
  /// **'If wallpapers stop changing, set battery use for Prism to Unrestricted. Open settings, then Apps, Prism, Battery.'**
  String get wallpaperAutoRotateBatteryTip;

  /// Target for applying rotated wallpapers to both screens.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get wallpaperAutoRotateBothScreens;

  /// Error shown when auto-rotate cannot change the wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Could not change wallpaper.'**
  String get wallpaperAutoRotateChangeError;

  /// Auto-rotate change interval setting section label.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get wallpaperAutoRotateChangeLabel;

  /// Description of the charging-only auto-rotate option.
  ///
  /// In en, this message translates to:
  /// **'Change when plugged in, at most once per interval'**
  String get wallpaperAutoRotateChargingDescription;

  /// Auto-rotate option to change wallpapers only while charging.
  ///
  /// In en, this message translates to:
  /// **'Only while charging'**
  String get wallpaperAutoRotateChargingOnly;

  /// Action to copy the auto-rotate battery instructions.
  ///
  /// In en, this message translates to:
  /// **'Copy steps'**
  String get wallpaperAutoRotateCopySteps;

  /// Auto-rotate status message when startup fails.
  ///
  /// In en, this message translates to:
  /// **'Could not start. Try again.'**
  String get wallpaperAutoRotateCouldNotStart;

  /// Auto-rotate wallpaper download progress.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {cached} of {total} {total, plural, one{wallpaper} other{wallpapers}}'**
  String wallpaperAutoRotateDownloadedCount(int cached, int total);

  /// Expiry date and time for the active auto-rotate pass.
  ///
  /// In en, this message translates to:
  /// **'Pass active until {date}'**
  String wallpaperAutoRotateEnabledUntil(String date);

  /// Action to dismiss the auto-rotate battery notice.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get wallpaperAutoRotateGotIt;

  /// Target for applying rotated wallpapers to the home screen.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get wallpaperAutoRotateHomeScreen;

  /// Auto-rotate interval of twelve hours.
  ///
  /// In en, this message translates to:
  /// **'Every 12 hours'**
  String get wallpaperAutoRotateInterval12Hours;

  /// Auto-rotate interval of fifteen minutes.
  ///
  /// In en, this message translates to:
  /// **'Every 15 min (battery heavy)'**
  String get wallpaperAutoRotateInterval15;

  /// Auto-rotate interval of thirty minutes.
  ///
  /// In en, this message translates to:
  /// **'Every 30 min'**
  String get wallpaperAutoRotateInterval30;

  /// Auto-rotate interval of three days.
  ///
  /// In en, this message translates to:
  /// **'Every 3 days'**
  String get wallpaperAutoRotateInterval3Days;

  /// Auto-rotate interval of three hours.
  ///
  /// In en, this message translates to:
  /// **'Every 3 hours'**
  String get wallpaperAutoRotateInterval3Hours;

  /// Auto-rotate interval of six hours.
  ///
  /// In en, this message translates to:
  /// **'Every 6 hours'**
  String get wallpaperAutoRotateInterval6Hours;

  /// Auto-rotate interval of one day.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get wallpaperAutoRotateIntervalDay;

  /// Auto-rotate interval of one hour.
  ///
  /// In en, this message translates to:
  /// **'Every hour'**
  String get wallpaperAutoRotateIntervalHour;

  /// Auto-rotate interval of one week.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get wallpaperAutoRotateIntervalWeek;

  /// Section title for battery settings that help auto-rotate keep running.
  ///
  /// In en, this message translates to:
  /// **'Keep it running'**
  String get wallpaperAutoRotateKeepRunning;

  /// Error shown when auto-rotate settings cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load auto-rotate settings.'**
  String get wallpaperAutoRotateLoadError;

  /// Loading message while auto-rotate source wallpapers are fetched.
  ///
  /// In en, this message translates to:
  /// **'Loading wallpapers'**
  String get wallpaperAutoRotateLoadingWalls;

  /// Target for applying rotated wallpapers to the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get wallpaperAutoRotateLockScreen;

  /// Summary of the wallpaper count in the auto-rotate mix.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 wallpaper from {source} in the mix} other{{count} wallpapers from {source} in the mix}}'**
  String wallpaperAutoRotateMix(int count, String source);

  /// Summary for a capped auto-rotate source, with the count and limit in one translatable message.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 wallpaper from {source} in the mix. Using your first 100.} other{{count} wallpapers from {source} in the mix. Using your first 100.}}'**
  String wallpaperAutoRotateMixCapped(int count, String source);

  /// Auto-rotate status with the local time of the next change.
  ///
  /// In en, this message translates to:
  /// **'Next change around {time}'**
  String wallpaperAutoRotateNextChange(String time);

  /// Category name used as the source in the auto-rotate mix.
  ///
  /// In en, this message translates to:
  /// **'{category}'**
  String wallpaperAutoRotateNounCategory(String category);

  /// Source description for downloaded wallpapers in the auto-rotate mix.
  ///
  /// In en, this message translates to:
  /// **'downloads'**
  String get wallpaperAutoRotateNounDownloads;

  /// Source description for favourite wallpapers in the auto-rotate mix.
  ///
  /// In en, this message translates to:
  /// **'favourites'**
  String get wallpaperAutoRotateNounFavourites;

  /// Source name for wallpapers saved in history in the auto-rotate mix.
  ///
  /// In en, this message translates to:
  /// **'your history'**
  String get wallpaperAutoRotateNounHistory;

  /// Source description for past daily picks in the auto-rotate mix.
  ///
  /// In en, this message translates to:
  /// **'Wall of the Day picks'**
  String get wallpaperAutoRotateNounWotd;

  /// Status shown when auto-rotate is off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get wallpaperAutoRotateOff;

  /// Notice that auto-rotate stopped after the plan or pass ended.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate is off because your Prism Pro plan or pass ended.'**
  String get wallpaperAutoRotateOffEnded;

  /// Action to open downloads from auto-rotate setup.
  ///
  /// In en, this message translates to:
  /// **'Open downloads'**
  String get wallpaperAutoRotateOpenDownloads;

  /// Action to open favourites from auto-rotate setup.
  ///
  /// In en, this message translates to:
  /// **'Open favourites'**
  String get wallpaperAutoRotateOpenFavourites;

  /// Confirmation that the seven-day auto-rotate pass is active.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate is on for 7 days.'**
  String get wallpaperAutoRotatePassEnabled;

  /// Button label to buy a seven-day auto-rotate pass.
  ///
  /// In en, this message translates to:
  /// **'7-day pass · {coins} coins'**
  String wallpaperAutoRotatePassPurchase(int coins);

  /// Title for selecting an auto-rotate wallpaper category.
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get wallpaperAutoRotatePickCategory;

  /// Auto-rotate wallpaper preparation progress.
  ///
  /// In en, this message translates to:
  /// **'Preparing {count, plural, one{1 wallpaper} other{{count} wallpapers}}'**
  String wallpaperAutoRotatePreparing(int count);

  /// Description of the auto-rotate pass and Prism Pro options.
  ///
  /// In en, this message translates to:
  /// **'Try it for 7 days with coins, or get Prism Pro.'**
  String get wallpaperAutoRotateProBody;

  /// Message introducing auto-rotate as a Prism Pro feature.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate is a Prism Pro feature.'**
  String get wallpaperAutoRotateProTitle;

  /// Number of wallpapers ready for auto-rotate.
  ///
  /// In en, this message translates to:
  /// **'{cached} of {total} {total, plural, one{wallpaper} other{wallpapers}} ready'**
  String wallpaperAutoRotateReadyCount(int cached, int total);

  /// Status shown when auto-rotate is scheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get wallpaperAutoRotateScheduled;

  /// Auto-rotate option to shuffle wallpaper order.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get wallpaperAutoRotateShuffle;

  /// Description of the auto-rotate shuffle option.
  ///
  /// In en, this message translates to:
  /// **'Random order instead of one after another'**
  String get wallpaperAutoRotateShuffleDescription;

  /// Auto-rotate source for a selected category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get wallpaperAutoRotateSourceCategory;

  /// Auto-rotate source for downloaded wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get wallpaperAutoRotateSourceDownloads;

  /// Auto-rotate source for favourite wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get wallpaperAutoRotateSourceFavourites;

  /// Auto-rotate source for wallpapers in history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get wallpaperAutoRotateSourceHistory;

  /// Auto-rotate source setting section label.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get wallpaperAutoRotateSourceLabel;

  /// Error shown when auto-rotate source wallpapers cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load wallpapers. Check your connection.'**
  String get wallpaperAutoRotateSourceLoadError;

  /// Auto-rotate source for past Wall of the Day picks.
  ///
  /// In en, this message translates to:
  /// **'Wall of the Day'**
  String get wallpaperAutoRotateSourceWotd;

  /// Error shown when wallpaper rotation cannot start.
  ///
  /// In en, this message translates to:
  /// **'Could not start wallpaper rotation.'**
  String get wallpaperAutoRotateStartError;

  /// Status shown while auto-rotate is starting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get wallpaperAutoRotateStarting;

  /// Auto-rotate status setting section label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get wallpaperAutoRotateStatusLabel;

  /// Confirmation that auto-rotate setup instructions were copied.
  ///
  /// In en, this message translates to:
  /// **'Steps copied.'**
  String get wallpaperAutoRotateStepsCopied;

  /// Error shown when wallpaper rotation cannot be stopped.
  ///
  /// In en, this message translates to:
  /// **'Could not stop wallpaper rotation.'**
  String get wallpaperAutoRotateStopError;

  /// Auto-rotate settings screen title.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate'**
  String get wallpaperAutoRotateTitle;

  /// Notice when the selected category has too few wallpapers.
  ///
  /// In en, this message translates to:
  /// **'This category has fewer than 2 wallpapers. Pick another one.'**
  String get wallpaperAutoRotateTooFewCategory;

  /// Notice when there are too few downloaded wallpapers to rotate.
  ///
  /// In en, this message translates to:
  /// **'Download at least 2 wallpapers to rotate them.'**
  String get wallpaperAutoRotateTooFewDownloads;

  /// Notice when there are too few favourite wallpapers to rotate.
  ///
  /// In en, this message translates to:
  /// **'Favourite at least 2 wallpapers to rotate them.'**
  String get wallpaperAutoRotateTooFewFavourites;

  /// Notice when history has too few wallpapers to rotate.
  ///
  /// In en, this message translates to:
  /// **'Set at least 2 wallpapers from Prism to rotate them.'**
  String get wallpaperAutoRotateTooFewHistory;

  /// Notice when the Wall of the Day archive has too few picks.
  ///
  /// In en, this message translates to:
  /// **'There are not enough past picks yet.'**
  String get wallpaperAutoRotateTooFewWotd;

  /// Error shown when an auto-rotate pass cannot be unlocked.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t unlock auto-rotate. Try again.'**
  String get wallpaperAutoRotateUnlockError;

  /// Error shown when auto-rotate settings cannot be updated.
  ///
  /// In en, this message translates to:
  /// **'Could not update auto-rotate.'**
  String get wallpaperAutoRotateUpdateError;

  /// Action to return from the auto-rotate screen.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get wallpaperBack;

  /// Wallpaper interface text: wallpaperBlockCreator.
  ///
  /// In en, this message translates to:
  /// **'Block creator'**
  String get wallpaperBlockCreator;

  /// Error shown when a wallpaper creator profile cannot be found.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find this creator. Try again.'**
  String get wallpaperBlockCreatorNotFound;

  /// Notice that a wallpaper boost is already active.
  ///
  /// In en, this message translates to:
  /// **'Already boosted.'**
  String get wallpaperBoostAlready;

  /// Notice that a wallpaper boost is already active until a given time.
  ///
  /// In en, this message translates to:
  /// **'Already boosted until {time}.'**
  String wallpaperBoostAlreadyUntil(String time);

  /// Confirmation button for purchasing a wallpaper boost.
  ///
  /// In en, this message translates to:
  /// **'Boost for {coins} coins'**
  String wallpaperBoostConfirmButton(int coins);

  /// Confirmation message explaining the wallpaper boost duration and price.
  ///
  /// In en, this message translates to:
  /// **'Show this wallpaper in the Home carousel and at the top of Trending for 24 hours for {coins} coins.'**
  String wallpaperBoostConfirmMessage(int coins);

  /// Summary of the wallpaper boost duration and price.
  ///
  /// In en, this message translates to:
  /// **'24 hours at the top · {coins} coins'**
  String wallpaperBoostDurationAndCost(int coins);

  /// Error shown when a wallpaper boost fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t boost this wallpaper. Try again.'**
  String get wallpaperBoostFailed;

  /// Error shown when the current user cannot boost this wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Only approved wallpapers you uploaded can be boosted.'**
  String get wallpaperBoostOnlyApproved;

  /// Error shown when all wallpaper boost slots are occupied.
  ///
  /// In en, this message translates to:
  /// **'All boost slots are taken. Try again later.'**
  String get wallpaperBoostSlotsTaken;

  /// Error showing when the next wallpaper boost slot becomes free.
  ///
  /// In en, this message translates to:
  /// **'All boost slots are taken. The next one frees up {time}.'**
  String wallpaperBoostSlotsTakenUntil(String time);

  /// Title for the wallpaper boost action.
  ///
  /// In en, this message translates to:
  /// **'Boost to Trending'**
  String get wallpaperBoostTitle;

  /// Confirmation that the wallpaper boost is active.
  ///
  /// In en, this message translates to:
  /// **'Boosted. It is live on Home and in Trending.'**
  String get wallpaperBoostedSuccess;

  /// Badge indicating that a wallpaper has an active boost.
  ///
  /// In en, this message translates to:
  /// **'Boosted'**
  String get wallpaperBoostedTag;

  /// Status showing when a wallpaper boost expires.
  ///
  /// In en, this message translates to:
  /// **'Boosted until {time}'**
  String wallpaperBoostedUntil(String time);

  /// Action to browse wallpapers from the empty downloads screen.
  ///
  /// In en, this message translates to:
  /// **'Browse wallpapers'**
  String get wallpaperBrowseWallpapers;

  /// Wallpaper title or recommendation text: wallpaperByCreator.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper by {name}'**
  String wallpaperByCreator(String name);

  /// Wallpaper title or recommendation text: wallpaperByPrismCreator.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper by Prism creator'**
  String get wallpaperByPrismCreator;

  /// Wallpaper and feed interface text: wallpaperCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get wallpaperCategories;

  /// Category setting label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get wallpaperCategory;

  /// Empty state body when a category has no wallpapers.
  ///
  /// In en, this message translates to:
  /// **'New ones land often. Check back soon.'**
  String get wallpaperCategoryFeedEmptyBody;

  /// Empty state title when a category has no wallpapers.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers here yet'**
  String get wallpaperCategoryFeedEmptyTitle;

  /// Wallpaper and feed interface text: wallpaperCategoryNamed.
  ///
  /// In en, this message translates to:
  /// **'Category, {name}'**
  String wallpaperCategoryNamed(String name);

  /// Action to change the wallpaper immediately.
  ///
  /// In en, this message translates to:
  /// **'Change now'**
  String get wallpaperChangeNow;

  /// Empty-state message for a list that may have new content soon.
  ///
  /// In en, this message translates to:
  /// **'Check back soon.'**
  String get wallpaperCheckBackSoon;

  /// Empty state text for the Wall of the Day archive.
  ///
  /// In en, this message translates to:
  /// **'Check back tomorrow.'**
  String get wallpaperCheckBackTomorrow;

  /// Message prompting the user to retry after a network issue.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get wallpaperCheckConnection;

  /// Action to clear wallpaper history.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get wallpaperClear;

  /// Action to remove all favourites filters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get wallpaperClearFilters;

  /// Action to clear wallpaper history.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get wallpaperClearHistoryAction;

  /// Confirmation dialog text before clearing wallpaper history.
  ///
  /// In en, this message translates to:
  /// **'This removes the list of wallpapers you set. Your wallpapers stay as they are.'**
  String get wallpaperClearHistoryBody;

  /// Confirmation dialog title before clearing wallpaper history.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get wallpaperClearHistoryTitle;

  /// Accessibility label for clearing the favourites search.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get wallpaperClearSearch;

  /// Accessibility label for closing the wallpaper clock preview.
  ///
  /// In en, this message translates to:
  /// **'Close preview'**
  String get wallpaperClosePreview;

  /// Accessibility label for closing the wallpaper details panel.
  ///
  /// In en, this message translates to:
  /// **'Collapse wallpaper details'**
  String get wallpaperCollapseDetails;

  /// Wallpaper and feed interface text: wallpaperCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get wallpaperCollection;

  /// Title shown when a collection cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this collection'**
  String get wallpaperCollectionLoadError;

  /// Wallpaper and feed interface text: wallpaperCollectionNamed.
  ///
  /// In en, this message translates to:
  /// **'Collection, {name}'**
  String wallpaperCollectionNamed(String name);

  /// Confirmation shown after spending coins to unlock a collection preview.
  ///
  /// In en, this message translates to:
  /// **'Preview unlocked for 24 hours (-{coins} coins).'**
  String wallpaperCollectionPreviewUnlocked(int coins);

  /// Error shown when refreshing a wallpaper collection fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh. Pull down to try again.'**
  String get wallpaperCollectionRefreshError;

  /// Wallpaper and feed interface text: wallpaperCollectionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh, or check back soon.'**
  String get wallpaperCollectionsEmptyBody;

  /// Wallpaper and feed interface text: wallpaperCollectionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get wallpaperCollectionsEmptyTitle;

  /// Accessibility hint for copying an accent color hex value.
  ///
  /// In en, this message translates to:
  /// **'Long press to copy hex color'**
  String get wallpaperCopyAccentHexHint;

  /// Number of wallpapers in a collection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No wallpapers} =1{1 wallpaper} other{{count} wallpapers}}'**
  String wallpaperCount(int count);

  /// Action to delete a downloaded wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get wallpaperDelete;

  /// Confirmation text before deleting multiple downloaded wallpapers.
  ///
  /// In en, this message translates to:
  /// **'They are removed from this device. You can download them again later.'**
  String get wallpaperDeleteManyDownloadsBody;

  /// Confirmation title before deleting multiple downloaded wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} downloads?'**
  String wallpaperDeleteManyDownloadsTitle(int count);

  /// Confirmation text before deleting one downloaded wallpaper.
  ///
  /// In en, this message translates to:
  /// **'It is removed from this device. You can download it again later.'**
  String get wallpaperDeleteOneDownloadBody;

  /// Confirmation title before deleting one downloaded wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Delete this download?'**
  String get wallpaperDeleteOneDownloadTitle;

  /// Wallpaper interface text: wallpaperDepthEditorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In the Lock Screen editor, tap ••• then Depth Effect.'**
  String get wallpaperDepthEditorSubtitle;

  /// Name of the iOS lock screen depth effect.
  ///
  /// In en, this message translates to:
  /// **'Depth Effect'**
  String get wallpaperDepthEffect;

  /// Wallpaper interface text: wallpaperDepthSubjectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your subject sits in front of the clock.'**
  String get wallpaperDepthSubjectSubtitle;

  /// Spatial Scene text: wallpaperSpatialScene.
  ///
  /// In en, this message translates to:
  /// **'Spatial Scene'**
  String get wallpaperSpatialScene;

  /// Spatial Scene text: wallpaperSpatialGreatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear depth. Makes a strong 3D Lock Screen.'**
  String get wallpaperSpatialGreatSubtitle;

  /// Spatial Scene text: wallpaperSpatialOkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Some depth. The 3D effect is gentle.'**
  String get wallpaperSpatialOkSubtitle;

  /// Spatial Scene text: wallpaperSpatialGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Set it as a Spatial Scene'**
  String get wallpaperSpatialGuideTitle;

  /// Spatial Scene text: wallpaperSpatialGuideBody.
  ///
  /// In en, this message translates to:
  /// **'On iPhone 12 or later with iOS 26:'**
  String get wallpaperSpatialGuideBody;

  /// Spatial Scene text: wallpaperSpatialStepSave.
  ///
  /// In en, this message translates to:
  /// **'Save this wall to Photos.'**
  String get wallpaperSpatialStepSave;

  /// Spatial Scene text: wallpaperSpatialStepPick.
  ///
  /// In en, this message translates to:
  /// **'On the Lock Screen, touch and hold your screen. Tap the Add button, tap Photos, then select the photo.'**
  String get wallpaperSpatialStepPick;

  /// Spatial Scene text: wallpaperSpatialStepButton.
  ///
  /// In en, this message translates to:
  /// **'Tap the Spatial Scene button to turn the 3D effect on, then tap Add.'**
  String get wallpaperSpatialStepButton;

  /// Spatial Scene text: wallpaperSpatialPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'3D'**
  String get wallpaperSpatialPreviewLabel;

  /// Spatial Scene text: wallpaperSpatialPreviewOn.
  ///
  /// In en, this message translates to:
  /// **'Preview in 3D'**
  String get wallpaperSpatialPreviewOn;

  /// Spatial Scene text: wallpaperSpatialPreviewOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off the 3D preview'**
  String get wallpaperSpatialPreviewOff;

  /// Spatial Scene text: wallpaperSpatialDragHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to tilt'**
  String get wallpaperSpatialDragHint;

  /// Toast shown after copying a wallpaper color's hex code.
  ///
  /// In en, this message translates to:
  /// **'Color code copied to clipboard'**
  String get wallpaperDetailColorCodeCopied;

  /// Wallpaper interface text: wallpaperDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper not found'**
  String get wallpaperDetailNotFound;

  /// Wallpaper interface text: wallpaperDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get wallpaperDiscard;

  /// Action to dismiss a message or banner.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get wallpaperDismiss;

  /// Wallpaper interface text: wallpaperDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get wallpaperDownload;

  /// Wallpaper interface text: wallpaperDownloadCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 download} other{{count} downloads}}'**
  String wallpaperDownloadCount(int count);

  /// Sort downloads by wallpaper name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get wallpaperDownloadSortName;

  /// Sort downloads by newest first.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get wallpaperDownloadSortNewest;

  /// Sort downloads by oldest first.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get wallpaperDownloadSortOldest;

  /// Wallpaper interface text: wallpaperDownloadWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Download wallpaper'**
  String get wallpaperDownloadWallpaper;

  /// Wallpaper interface text: wallpaperDownloadedWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Downloaded wallpaper'**
  String get wallpaperDownloadedWallpaper;

  /// Wallpaper interface text: wallpaperDownloadedWallpaperUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Downloaded wallpaper is unavailable'**
  String get wallpaperDownloadedWallpaperUnavailable;

  /// Error shown when one or more downloaded wallpapers could not be deleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Couldn\'t delete 1 download.} other{Couldn\'t delete {count} downloads.}}'**
  String wallpaperDownloadsDeleteError(int count);

  /// Empty state description for the downloads list.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers you download are kept here.'**
  String get wallpaperDownloadsEmptyBody;

  /// Empty state title when the user has no downloaded wallpapers.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet'**
  String get wallpaperDownloadsEmptyTitle;

  /// Title shown when the downloads list cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your downloads'**
  String get wallpaperDownloadsLoadError;

  /// Help text shown when the downloads list cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Check your storage access and try again.'**
  String get wallpaperDownloadsLoadHelp;

  /// Error shown when refreshing downloaded wallpapers fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh downloads. Try again.'**
  String get wallpaperDownloadsRefreshError;

  /// Error shown when sharing downloaded wallpapers fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share. Try again.'**
  String get wallpaperDownloadsShareError;

  /// Title for the downloaded wallpapers screen.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get wallpaperDownloadsTitle;

  /// Action to open the wallpaper editor.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get wallpaperEdit;

  /// Wallpaper interface text: wallpaperEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit wallpaper'**
  String get wallpaperEditTitle;

  /// Accessibility label for opening the wallpaper details panel.
  ///
  /// In en, this message translates to:
  /// **'Expand wallpaper details'**
  String get wallpaperExpandDetails;

  /// Wallpaper interface text: wallpaperFavourite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get wallpaperFavourite;

  /// Confirmation shown after adding a wallpaper to favourites.
  ///
  /// In en, this message translates to:
  /// **'Added to favourites.'**
  String get wallpaperFavouriteAddedToast;

  /// Confirmation message when clearing signed-in account favourites.
  ///
  /// In en, this message translates to:
  /// **'This removes them from your account.'**
  String get wallpaperFavouriteClearAccountMessage;

  /// Menu action to clear all favourites.
  ///
  /// In en, this message translates to:
  /// **'Clear all favourites'**
  String get wallpaperFavouriteClearAll;

  /// Confirmation message when clearing guest favourites.
  ///
  /// In en, this message translates to:
  /// **'This removes them from this device.'**
  String get wallpaperFavouriteClearDeviceMessage;

  /// Error shown when all favourites cannot be cleared.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t clear favourites. Try again.'**
  String get wallpaperFavouriteClearError;

  /// Confirmation title before clearing multiple favourites.
  ///
  /// In en, this message translates to:
  /// **'Clear {count} favourites?'**
  String wallpaperFavouriteClearManyTitle(int count);

  /// Confirmation title before clearing one favourite.
  ///
  /// In en, this message translates to:
  /// **'Clear 1 favourite?'**
  String get wallpaperFavouriteClearOneTitle;

  /// Undo notice after clearing favourites.
  ///
  /// In en, this message translates to:
  /// **'Cleared {count, plural, one{1 favourite} other{{count} favourites}}'**
  String wallpaperFavouriteClearedMany(int count);

  /// Undo notice after clearing one favourite.
  ///
  /// In en, this message translates to:
  /// **'Cleared 1 favourite'**
  String get wallpaperFavouriteClearedOne;

  /// Localized number of favourite wallpapers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No favourites} one{1 favourite} other{{count} favourites}}'**
  String wallpaperFavouriteCount(int count);

  /// Empty state description for the favourites list.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a wallpaper to keep it here.'**
  String get wallpaperFavouriteEmptyBody;

  /// Empty state title when there are no favourites.
  ///
  /// In en, this message translates to:
  /// **'No favourites yet'**
  String get wallpaperFavouriteEmptyTitle;

  /// Menu action to export favourites.
  ///
  /// In en, this message translates to:
  /// **'Export favourites'**
  String get wallpaperFavouriteExport;

  /// Message shown when there are no favourites to export.
  ///
  /// In en, this message translates to:
  /// **'No favourites to export yet.'**
  String get wallpaperFavouriteExportEmpty;

  /// Error shown when favourites cannot be exported.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export favourites. Try again.'**
  String get wallpaperFavouriteExportError;

  /// Guest prompt to sign in and sync favourites across devices.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep them on every device'**
  String get wallpaperFavouriteGuestPrompt;

  /// Error state title when favourites cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your favourites'**
  String get wallpaperFavouriteLoadError;

  /// Accessibility label for the favourites actions menu.
  ///
  /// In en, this message translates to:
  /// **'More favourites actions'**
  String get wallpaperFavouriteMoreActions;

  /// Empty state title when no favourites match filters.
  ///
  /// In en, this message translates to:
  /// **'No matching favourites'**
  String get wallpaperFavouriteNoMatch;

  /// Status shown when a favourite did not sync.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get wallpaperFavouriteNotSynced;

  /// Notice that saved favourites are shown after refresh fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh favourites. Showing your saved list.'**
  String get wallpaperFavouriteRefreshFallback;

  /// Action to remove an unavailable favourite.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get wallpaperFavouriteRemove;

  /// Action to remove selected wallpapers from favourites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get wallpaperFavouriteRemoveAction;

  /// Error shown when selected favourites cannot be removed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove favourites. Try again.'**
  String get wallpaperFavouriteRemoveError;

  /// Undo notice after removing favourites.
  ///
  /// In en, this message translates to:
  /// **'Removed {count, plural, one{1 favourite} other{{count} favourites}}'**
  String wallpaperFavouriteRemovedMany(int count);

  /// Undo notice after removing one favourite.
  ///
  /// In en, this message translates to:
  /// **'Removed from favourites'**
  String get wallpaperFavouriteRemovedOne;

  /// Confirmation shown after removing a wallpaper from favourites.
  ///
  /// In en, this message translates to:
  /// **'Removed from favourites.'**
  String get wallpaperFavouriteRemovedToast;

  /// Error shown when an undo action cannot restore favourites.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore favourites.'**
  String get wallpaperFavouriteRestoreError;

  /// Search field hint in the favourites list.
  ///
  /// In en, this message translates to:
  /// **'Search by creator or category'**
  String get wallpaperFavouriteSearchHint;

  /// Hint that setting multiple selected favourites uses the first selected wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set uses the first one you picked'**
  String get wallpaperFavouriteSetUsesFirst;

  /// Error shown when selected favourites cannot be shared.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share. Try again.'**
  String get wallpaperFavouriteShareError;

  /// Sort favourites by oldest first.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get wallpaperFavouriteSortOldest;

  /// Sort favourites by recently added.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get wallpaperFavouriteSortRecentlyAdded;

  /// Sort favourites by source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get wallpaperFavouriteSortSource;

  /// Accessibility label and tooltip for the heart on a wallpaper already in the user's favourites.
  ///
  /// In en, this message translates to:
  /// **'In your favourites'**
  String get wallpaperFavouriteStatus;

  /// Help text when no favourites match current filters.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or source.'**
  String get wallpaperFavouriteTryDifferent;

  /// Message shown when an old favourite cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'This favourite is from an older version and cannot be opened. Press and hold to remove it.'**
  String get wallpaperFavouriteUnavailableLegacy;

  /// Status shown while a favourite waits to sync.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get wallpaperFavouriteWaitingSync;

  /// Title of the favourites screen.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get wallpaperFavouritesTitle;

  /// Wallpaper and feed interface text: wallpaperFeedAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get wallpaperFeedAnnouncement;

  /// Message shown after the user has seen all available personalized wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh. New picks will land here.'**
  String get wallpaperFeedCaughtUpBody;

  /// Title shown when there are no more personalized wallpapers to show.
  ///
  /// In en, this message translates to:
  /// **'You are all caught up'**
  String get wallpaperFeedCaughtUpTitle;

  /// Wallpaper and feed interface text: wallpaperFeedClearHistoryError.
  ///
  /// In en, this message translates to:
  /// **'Could not clear history. Try again.'**
  String get wallpaperFeedClearHistoryError;

  /// Wallpaper and feed interface text: wallpaperFeedDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get wallpaperFeedDiscovery;

  /// Wallpaper and feed interface text: wallpaperFeedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Follow creators or choose interests so we can surface more of what you like.'**
  String get wallpaperFeedEmptyBody;

  /// Wallpaper and feed interface text: wallpaperFeedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Shape this feed'**
  String get wallpaperFeedEmptyTitle;

  /// Empty-state title when a signed-in user follows no creators.
  ///
  /// In en, this message translates to:
  /// **'Follow creators to see their new wallpapers here'**
  String get wallpaperFeedFollowingEmptyTitle;

  /// Error title when the Following feed cannot load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your following feed'**
  String get wallpaperFeedFollowingLoadError;

  /// Error title when the Latest feed cannot load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the latest wallpapers'**
  String get wallpaperFeedLatestLoadError;

  /// Wallpaper and feed interface text: wallpaperFeedLearnedFromYou.
  ///
  /// In en, this message translates to:
  /// **'Learned from you'**
  String get wallpaperFeedLearnedFromYou;

  /// Wallpaper and feed interface text: wallpaperFeedLearningEmpty.
  ///
  /// In en, this message translates to:
  /// **'Open, save and set walls to teach your feed.'**
  String get wallpaperFeedLearningEmpty;

  /// Wallpaper and feed interface text: wallpaperFeedLearningHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Learning history cleared'**
  String get wallpaperFeedLearningHistoryCleared;

  /// Title shown when the personalized feed cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your feed'**
  String get wallpaperFeedLoadError;

  /// Wallpaper and feed interface text: wallpaperFeedLoadMoreError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more. Try again'**
  String get wallpaperFeedLoadMoreError;

  /// Personalized feed discovery mix option: Adventurous.
  ///
  /// In en, this message translates to:
  /// **'Adventurous'**
  String get wallpaperFeedMixAdventurous;

  /// Wallpaper and feed interface text: wallpaperFeedMixAdventurousDescription.
  ///
  /// In en, this message translates to:
  /// **'More walls from outside your taste.'**
  String get wallpaperFeedMixAdventurousDescription;

  /// Personalized feed discovery mix option: Balanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get wallpaperFeedMixBalanced;

  /// Wallpaper and feed interface text: wallpaperFeedMixBalancedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your taste, with a few surprises.'**
  String get wallpaperFeedMixBalancedDescription;

  /// Personalized feed discovery mix option: Familiar.
  ///
  /// In en, this message translates to:
  /// **'Familiar'**
  String get wallpaperFeedMixFamiliar;

  /// Wallpaper and feed interface text: wallpaperFeedMixFamiliarDescription.
  ///
  /// In en, this message translates to:
  /// **'Mostly what you already love.'**
  String get wallpaperFeedMixFamiliarDescription;

  /// Wallpaper and feed interface text: wallpaperFeedPickAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Pick at least {count}'**
  String wallpaperFeedPickAtLeast(int count);

  /// Wallpaper and feed interface text: wallpaperFeedPickedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} picked'**
  String wallpaperFeedPickedCount(int count);

  /// Empty-state title when the Popular feed has no wallpapers.
  ///
  /// In en, this message translates to:
  /// **'No popular wallpapers yet'**
  String get wallpaperFeedPopularEmptyTitle;

  /// Error title when the Popular feed cannot load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load popular wallpapers'**
  String get wallpaperFeedPopularLoadError;

  /// Empty-state hint to refresh the Latest or Popular wallpaper feed.
  ///
  /// In en, this message translates to:
  /// **'Pull down to refresh.'**
  String get wallpaperFeedPullToRefresh;

  /// Error shown when refreshing the personalized feed fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh your feed.'**
  String get wallpaperFeedRefreshError;

  /// Wallpaper and feed interface text: wallpaperFeedSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save feed settings. Try again.'**
  String get wallpaperFeedSaveError;

  /// Home feed tab interface text: Double tap to open feed settings.
  ///
  /// In en, this message translates to:
  /// **'Double tap to open feed settings'**
  String get wallpaperFeedSettingsHint;

  /// Wallpaper and feed interface text: wallpaperFeedStartingPoints.
  ///
  /// In en, this message translates to:
  /// **'Starting points'**
  String get wallpaperFeedStartingPoints;

  /// Home feed tab interface text: Following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get wallpaperFeedTabFollowing;

  /// Home feed tab interface text: For you.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get wallpaperFeedTabForYou;

  /// Home feed tab interface text: Latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get wallpaperFeedTabLatest;

  /// Home feed tab interface text: Popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get wallpaperFeedTabPopular;

  /// Home feed tab interface text: Trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get wallpaperFeedTabTrending;

  /// Wallpaper and feed interface text: wallpaperFeedTuneDescription.
  ///
  /// In en, this message translates to:
  /// **'Prism learns from what you open, save and set.'**
  String get wallpaperFeedTuneDescription;

  /// Wallpaper and feed interface text: wallpaperFeedTuneTitle.
  ///
  /// In en, this message translates to:
  /// **'Tune your feed'**
  String get wallpaperFeedTuneTitle;

  /// Home feed tab interface text: Updating.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get wallpaperFeedUpdating;

  /// Title shown when a wallpaper feed cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load wallpapers'**
  String get wallpaperFeedWallsLoadError;

  /// Confirmation after asking to see fewer similar wallpapers.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see fewer wallpapers like this.'**
  String get wallpaperFewerLikeThisConfirmation;

  /// Wallpaper and feed interface text: wallpaperFewerLikeThisUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get wallpaperFewerLikeThisUndo;

  /// Explanation shown when a downloaded wallpaper file is unavailable.
  ///
  /// In en, this message translates to:
  /// **'The file may have been moved or deleted.'**
  String get wallpaperFileMovedOrDeleted;

  /// Coin shortfall message for applying a premium wallpaper filter.
  ///
  /// In en, this message translates to:
  /// **'Applying this filter costs {coins} coins. You need {missing} more coins.'**
  String wallpaperFilterApplyCost(int coins, int missing);

  /// Label for the blur adjustment slider.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get wallpaperFilterBlur;

  /// Label for the brightness adjustment slider.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get wallpaperFilterBrightness;

  /// Label for the edge image effect.
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get wallpaperFilterEffectEdge;

  /// Label for the emboss image effect.
  ///
  /// In en, this message translates to:
  /// **'Emboss'**
  String get wallpaperFilterEffectEmboss;

  /// Label for the high pass image effect.
  ///
  /// In en, this message translates to:
  /// **'High Pass'**
  String get wallpaperFilterEffectHighPass;

  /// Label for the sharpen image effect.
  ///
  /// In en, this message translates to:
  /// **'Sharpen'**
  String get wallpaperFilterEffectSharpen;

  /// Wallpaper interface text: wallpaperFilterHoldToCompare.
  ///
  /// In en, this message translates to:
  /// **'Hold to compare'**
  String get wallpaperFilterHoldToCompare;

  /// Label for the hue adjustment slider.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get wallpaperFilterHue;

  /// Label for the lightness adjustment slider.
  ///
  /// In en, this message translates to:
  /// **'Lightness'**
  String get wallpaperFilterLightness;

  /// Wallpaper interface text: wallpaperFilterLightnessUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Lightness is unavailable on this device.'**
  String get wallpaperFilterLightnessUnavailable;

  /// Wallpaper interface text: wallpaperFilterNeedCoins.
  ///
  /// In en, this message translates to:
  /// **'Need coins for premium filter'**
  String get wallpaperFilterNeedCoins;

  /// Wallpaper interface text: wallpaperFilterOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get wallpaperFilterOriginal;

  /// Label for the saturation adjustment slider.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get wallpaperFilterSaturation;

  /// Error shown when an edited wallpaper cannot be saved.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save wallpaper. Please retry!'**
  String get wallpaperFilterSaveError;

  /// Tab label for the wallpaper adjustment panel.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get wallpaperFilterTabAdjustments;

  /// Tab label for the wallpaper filter selection panel.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get wallpaperFilterTabFilters;

  /// Confirmation shown after spending coins to unlock a premium filter.
  ///
  /// In en, this message translates to:
  /// **'Premium filter unlocked for this edit (-{coins} coins).'**
  String wallpaperFilterUnlocked(int coins);

  /// Wallpaper placement fit option that fills empty areas with a blur.
  ///
  /// In en, this message translates to:
  /// **'Fit with blur'**
  String get wallpaperFitBlur;

  /// Wallpaper placement fit option that fills empty areas with a colour.
  ///
  /// In en, this message translates to:
  /// **'Fit with colour'**
  String get wallpaperFitColour;

  /// Wallpaper placement fit option that fills the screen.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get wallpaperFitFill;

  /// Generic error shown when a wallpaper operation fails unexpectedly.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong!'**
  String get wallpaperGenericError;

  /// Wallpaper detail action to return to the previous screen.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get wallpaperGoBack;

  /// Confirmation after reducing similar wallpaper recommendations.
  ///
  /// In en, this message translates to:
  /// **'Got it. You\'ll see fewer like this.'**
  String get wallpaperGotItFewerLikeThis;

  /// Accessibility label and action that hides the buttons: on the wallpaper preview, and on the wallpaper detail screen where it also hides the system bars.
  ///
  /// In en, this message translates to:
  /// **'Hide controls'**
  String get wallpaperHidePreviewControls;

  /// Target label when a wallpaper is set on both screens.
  ///
  /// In en, this message translates to:
  /// **'Both screens'**
  String get wallpaperHistoryBothScreens;

  /// Label for a wallpaper currently set on a device screen.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get wallpaperHistoryCurrent;

  /// Prefix used in an accessibility description for a currently set wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Current. '**
  String get wallpaperHistoryCurrentPrefix;

  /// Empty state description for wallpaper history.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers you set will show up here, so you can set them again.'**
  String get wallpaperHistoryEmptyBody;

  /// Empty state title for wallpaper history.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers yet'**
  String get wallpaperHistoryEmptyTitle;

  /// Action to remove a wallpaper from history.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get wallpaperHistoryRemoveAction;

  /// Accessible name for the Prism logo.
  ///
  /// In en, this message translates to:
  /// **'Prism'**
  String get wallpaperHomeAppName;

  /// Accessibility hint describing wallpaper image gestures.
  ///
  /// In en, this message translates to:
  /// **'Hold for favourite, share, and reset actions. Scroll for details.'**
  String get wallpaperImageSemanticHint;

  /// Accessibility action on the wallpaper detail card that shows the previous wallpaper of the feed it was opened from.
  ///
  /// In en, this message translates to:
  /// **'Previous wallpaper'**
  String get wallpaperPreviousInFeed;

  /// Accessibility action on the wallpaper detail card that shows the next wallpaper of the feed it was opened from.
  ///
  /// In en, this message translates to:
  /// **'Next wallpaper'**
  String get wallpaperNextInFeed;

  /// Accessibility label for the wallpaper image.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get wallpaperImageSemanticLabel;

  /// Small hint shown once on the wallpaper detail screen. A tap on the wallpaper hides every button and the system bars.
  ///
  /// In en, this message translates to:
  /// **'Tap to hide controls'**
  String get wallpaperImmersiveHint;

  /// Message shown when the user lacks coins for an auto-rotate pass.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins. Earn coins in Rewards.'**
  String get wallpaperInsufficientCoins;

  /// Accessibility label for a learned wallpaper interest and its strength.
  ///
  /// In en, this message translates to:
  /// **'Learned: {label}, {percent} percent'**
  String wallpaperInterestLearnedLabel(String label, int percent);

  /// Accessibility label for an interest tile and whether it is selected.
  ///
  /// In en, this message translates to:
  /// **'Interest: {name}, {selection}'**
  String wallpaperInterestSelectedLabel(String name, String selection);

  /// Wallpaper title or recommendation text: wallpaperLandscapeCrop.
  ///
  /// In en, this message translates to:
  /// **'Landscape wallpaper: the sides will be cropped'**
  String get wallpaperLandscapeCrop;

  /// Wallpaper and feed interface text: wallpaperLibraryCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get wallpaperLibraryCollections;

  /// Downloads tab label in the library.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get wallpaperLibraryDownloads;

  /// Favourites tab label in the library.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get wallpaperLibraryFavourites;

  /// History tab label in the library.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get wallpaperLibraryHistory;

  /// Library screen title.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get wallpaperLibraryTitle;

  /// Wallpaper interface text: wallpaperLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get wallpaperLive;

  /// Confirmation after successfully setting a live wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Live wallpaper set.'**
  String get wallpaperLiveApplied;

  /// Accessibility description for the live photo preview.
  ///
  /// In en, this message translates to:
  /// **'{style} preview'**
  String wallpaperLiveApplyPhotoDescription(String style);

  /// Live wallpaper setting to save battery.
  ///
  /// In en, this message translates to:
  /// **'Battery saver'**
  String get wallpaperLiveBatterySaver;

  /// Action to choose a different video for a live wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Choose another video'**
  String get wallpaperLiveChooseAnotherVideo;

  /// Action to choose a video for a live wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Choose a video'**
  String get wallpaperLiveChooseVideo;

  /// Instruction to confirm a live wallpaper in Android's system preview.
  ///
  /// In en, this message translates to:
  /// **'Confirm in the system preview.'**
  String get wallpaperLiveConfirmPreview;

  /// Title shown when the selected live wallpaper mode is unsupported.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get wallpaperLiveDeviceUnavailable;

  /// Generic error shown when a live wallpaper cannot be set.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set the live wallpaper. Try again.'**
  String get wallpaperLiveErrorGeneric;

  /// Error shown when an image exceeds live wallpaper size limits.
  ///
  /// In en, this message translates to:
  /// **'That image is too large for a live wallpaper.'**
  String get wallpaperLiveErrorImageTooLarge;

  /// Error shown when a live wallpaper operation runs out of memory.
  ///
  /// In en, this message translates to:
  /// **'Not enough memory. Close other apps and try again.'**
  String get wallpaperLiveErrorMemory;

  /// Error shown when wallpaper changes are restricted on the device.
  ///
  /// In en, this message translates to:
  /// **'Your device or work profile does not allow wallpaper changes.'**
  String get wallpaperLiveErrorNotAllowed;

  /// Error shown when Prism cannot read a live wallpaper file due to permissions.
  ///
  /// In en, this message translates to:
  /// **'Prism does not have permission to read that file.'**
  String get wallpaperLiveErrorPermission;

  /// Error shown when the Android live wallpaper preview cannot open.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the system preview.'**
  String get wallpaperLiveErrorPreview;

  /// Error shown when a live wallpaper file cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the file. Try again.'**
  String get wallpaperLiveErrorReadFile;

  /// Error shown when a shader live wallpaper style cannot start.
  ///
  /// In en, this message translates to:
  /// **'This device could not start that style. Try another one.'**
  String get wallpaperLiveErrorStyle;

  /// Error shown when a live wallpaper operation times out.
  ///
  /// In en, this message translates to:
  /// **'Timed out. Check your connection and try again.'**
  String get wallpaperLiveErrorTimeout;

  /// Error shown when a live wallpaper file exceeds device size limits.
  ///
  /// In en, this message translates to:
  /// **'That file is too large for a live wallpaper.'**
  String get wallpaperLiveErrorTooLarge;

  /// Error shown when a video cannot be used as a live wallpaper.
  ///
  /// In en, this message translates to:
  /// **'That video cannot be played as a wallpaper. Try another clip.'**
  String get wallpaperLiveErrorVideo;

  /// Video live wallpaper frame rate setting.
  ///
  /// In en, this message translates to:
  /// **'{fps} frames per second'**
  String wallpaperLiveFps(int fps);

  /// Accessibility description for the live gradient preview.
  ///
  /// In en, this message translates to:
  /// **'{style} preview'**
  String wallpaperLiveGradientDescription(String style);

  /// Accessibility description for a gradient colour swatch.
  ///
  /// In en, this message translates to:
  /// **'Gradient colour {index} of {count}'**
  String wallpaperLiveGradientSwatch(String index, String count);

  /// Instruction shown when Android needs Prism to stay open while setting a live wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Keep Prism open and try again.'**
  String get wallpaperLiveKeepPrismOpen;

  /// Live wallpaper mode using a gradient.
  ///
  /// In en, this message translates to:
  /// **'Gradients'**
  String get wallpaperLiveModeGradients;

  /// Live wallpaper mode using a photo.
  ///
  /// In en, this message translates to:
  /// **'Make it live'**
  String get wallpaperLiveModePhoto;

  /// Live wallpaper mode using a video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get wallpaperLiveModeVideo;

  /// Accessibility label when the user has not chosen a video.
  ///
  /// In en, this message translates to:
  /// **'No video chosen'**
  String get wallpaperLiveNoVideo;

  /// Instruction for confirming a live wallpaper in Android's system preview.
  ///
  /// In en, this message translates to:
  /// **'Android opens a preview. Tap Set wallpaper there.'**
  String get wallpaperLivePreviewInstruction;

  /// Message shown when a live wallpaper style requires Prism Pro.
  ///
  /// In en, this message translates to:
  /// **'This style is part of Prism Pro.'**
  String get wallpaperLiveProStyleRequired;

  /// Action to set the selected live wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set live wallpaper'**
  String get wallpaperLiveSetAction;

  /// Explanation shown when shader wallpapers are unsupported.
  ///
  /// In en, this message translates to:
  /// **'This device cannot run shader live wallpapers. Try Video.'**
  String get wallpaperLiveShaderUnsupported;

  /// Name of the Aurora live wallpaper gradient style.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get wallpaperLiveStyleAurora;

  /// Description of the Aurora live wallpaper gradient style.
  ///
  /// In en, this message translates to:
  /// **'Soft ribbons of colour.'**
  String get wallpaperLiveStyleAuroraDescription;

  /// Name of the Breathe live wallpaper motion style.
  ///
  /// In en, this message translates to:
  /// **'Breathe'**
  String get wallpaperLiveStyleBreathe;

  /// Description of the Breathe live wallpaper motion style.
  ///
  /// In en, this message translates to:
  /// **'A gentle pulse, in and out.'**
  String get wallpaperLiveStyleBreatheDescription;

  /// Name of the Drift live wallpaper motion style.
  ///
  /// In en, this message translates to:
  /// **'Drift'**
  String get wallpaperLiveStyleDrift;

  /// Description of the Drift live wallpaper motion style.
  ///
  /// In en, this message translates to:
  /// **'Slow pan and zoom. Follows your home screen swipes.'**
  String get wallpaperLiveStyleDriftDescription;

  /// Name of the Mesh live wallpaper gradient style.
  ///
  /// In en, this message translates to:
  /// **'Mesh'**
  String get wallpaperLiveStyleMesh;

  /// Description of the Mesh live wallpaper gradient style.
  ///
  /// In en, this message translates to:
  /// **'Blended colour that slowly shifts.'**
  String get wallpaperLiveStyleMeshDescription;

  /// Name of the Plasma live wallpaper gradient style.
  ///
  /// In en, this message translates to:
  /// **'Plasma'**
  String get wallpaperLiveStylePlasma;

  /// Description of the Plasma live wallpaper gradient style.
  ///
  /// In en, this message translates to:
  /// **'Smooth, flowing colour.'**
  String get wallpaperLiveStylePlasmaDescription;

  /// Name of the Ripple live wallpaper motion style.
  ///
  /// In en, this message translates to:
  /// **'Ripple'**
  String get wallpaperLiveStyleRipple;

  /// Description of the Ripple live wallpaper motion style.
  ///
  /// In en, this message translates to:
  /// **'Water rings that spread from your touch.'**
  String get wallpaperLiveStyleRippleDescription;

  /// Name of the Shimmer live wallpaper motion style.
  ///
  /// In en, this message translates to:
  /// **'Shimmer'**
  String get wallpaperLiveStyleShimmer;

  /// Description of the Shimmer live wallpaper motion style.
  ///
  /// In en, this message translates to:
  /// **'A soft sweep of light.'**
  String get wallpaperLiveStyleShimmerDescription;

  /// Live wallpaper style that moves the photo in depth as you swipe home screens and tilt the phone.
  ///
  /// In en, this message translates to:
  /// **'3D'**
  String get wallpaperLiveStyleDepth;

  /// Description of the 3D live wallpaper style.
  ///
  /// In en, this message translates to:
  /// **'The photo moves in depth as you swipe your home screens and tilt your phone.'**
  String get wallpaperLiveStyleDepthDescription;

  /// Name of the Starfield live wallpaper gradient style.
  ///
  /// In en, this message translates to:
  /// **'Starfield'**
  String get wallpaperLiveStyleStarfield;

  /// Description of the Starfield live wallpaper gradient style.
  ///
  /// In en, this message translates to:
  /// **'Twinkling stars on pure black.'**
  String get wallpaperLiveStyleStarfieldDescription;

  /// Confirmation that a paid live wallpaper style was unlocked.
  ///
  /// In en, this message translates to:
  /// **'{style} is unlocked for 7 days.'**
  String wallpaperLiveStyleUnlocked(String style);

  /// Name of the Waves live wallpaper gradient style.
  ///
  /// In en, this message translates to:
  /// **'Waves'**
  String get wallpaperLiveStyleWaves;

  /// Description of the Waves live wallpaper gradient style.
  ///
  /// In en, this message translates to:
  /// **'Layered waves that roll.'**
  String get wallpaperLiveStyleWavesDescription;

  /// Error shown when a wallpaper image cannot be prepared for live use because download failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the wallpaper. Check your connection and try again.'**
  String get wallpaperLiveTextureDownloadFailed;

  /// Error shown when a wallpaper image cannot be prepared for live use.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t prepare the wallpaper.'**
  String get wallpaperLiveTexturePrepareFailed;

  /// Error shown when a wallpaper image is too detailed for live rendering.
  ///
  /// In en, this message translates to:
  /// **'That wallpaper is too detailed to animate.'**
  String get wallpaperLiveTextureTooDetailed;

  /// Title of the live wallpapers screen.
  ///
  /// In en, this message translates to:
  /// **'Live wallpapers'**
  String get wallpaperLiveTitle;

  /// Explanation that live wallpapers need Android and OpenGL support.
  ///
  /// In en, this message translates to:
  /// **'They need an Android phone that supports OpenGL live wallpapers.'**
  String get wallpaperLiveUnavailableBody;

  /// Title shown when live wallpapers are unsupported on this device.
  ///
  /// In en, this message translates to:
  /// **'Live wallpapers are not available'**
  String get wallpaperLiveUnavailableTitle;

  /// Action label to unlock a live style with coins.
  ///
  /// In en, this message translates to:
  /// **'Unlock · {coins} coins'**
  String wallpaperLiveUnlockCoins(String coins);

  /// Error shown when a live wallpaper style cannot be unlocked.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t unlock {style}. Try again.'**
  String wallpaperLiveUnlockError(String style);

  /// Action to unlock a live style for seven days with coins.
  ///
  /// In en, this message translates to:
  /// **'Unlock {style} for 7 days · {coins} coins'**
  String wallpaperLiveUnlockStyleAction(String style, String coins);

  /// Description of paid style unlock options.
  ///
  /// In en, this message translates to:
  /// **'Unlock it for 7 days with coins, or get Prism Pro for every style.'**
  String get wallpaperLiveUnlockStyleBody;

  /// Title for unlocking a paid live wallpaper style.
  ///
  /// In en, this message translates to:
  /// **'{style} is a paid style'**
  String wallpaperLiveUnlockStyleTitle(String style);

  /// Error shown when the device cannot display live wallpapers.
  ///
  /// In en, this message translates to:
  /// **'This device cannot show live wallpapers.'**
  String get wallpaperLiveUnsupported;

  /// Accessibility label when a video has been chosen.
  ///
  /// In en, this message translates to:
  /// **'Chosen video'**
  String get wallpaperLiveVideoChosen;

  /// Details about video live wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Plays on your home screen with the sound off. Up to 256 MB.'**
  String get wallpaperLiveVideoDescription;

  /// Error shown when the selected video cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read that video. Pick it again.'**
  String get wallpaperLiveVideoReadFailed;

  /// Error shown when a selected video exceeds the supported file size.
  ///
  /// In en, this message translates to:
  /// **'That video is larger than 256 MB. Pick a shorter clip.'**
  String get wallpaperLiveVideoTooLarge;

  /// Explanation shown when video wallpapers are unsupported.
  ///
  /// In en, this message translates to:
  /// **'This device cannot play a video as a wallpaper.'**
  String get wallpaperLiveVideoUnsupported;

  /// Loading status shown while the wallpaper filter preview image loads.
  ///
  /// In en, this message translates to:
  /// **'Loading image'**
  String get wallpaperLoadingImage;

  /// Loading status shown while wallpaper details are being loaded.
  ///
  /// In en, this message translates to:
  /// **'Loading wallpaper'**
  String get wallpaperLoadingWallpaper;

  /// Wallpaper title or recommendation text: wallpaperLowResolutionScreen.
  ///
  /// In en, this message translates to:
  /// **'Low resolution for your screen'**
  String get wallpaperLowResolutionScreen;

  /// Accessibility label for applying a live wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Make it live'**
  String get wallpaperMakeItLive;

  /// Theme option to match the device accent colour.
  ///
  /// In en, this message translates to:
  /// **'Match system colour'**
  String get wallpaperMatchSystemColour;

  /// Wallpaper interface text: wallpaperMoreLikeThis.
  ///
  /// In en, this message translates to:
  /// **'More like this'**
  String get wallpaperMoreLikeThis;

  /// Collections tab label and accessibility name.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get wallpaperNavCollections;

  /// Home tab label and accessibility name.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get wallpaperNavHome;

  /// Rewards tab label and accessibility name.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get wallpaperNavRewards;

  /// Search tab label and accessibility name.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get wallpaperNavSearch;

  /// Badge marking a newly added feature.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get wallpaperNew;

  /// Action to dismiss the notification permission explainer.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get wallpaperNotNow;

  /// Accessibility state for an item that is not selected.
  ///
  /// In en, this message translates to:
  /// **'not selected'**
  String get wallpaperNotSelected;

  /// Description of the benefits of enabling notifications.
  ///
  /// In en, this message translates to:
  /// **'One hand-picked wallpaper each morning, plus streak reminders. No spam.'**
  String get wallpaperNotificationPromptBody;

  /// Title for the notification permission explainer.
  ///
  /// In en, this message translates to:
  /// **'Get the Wall of the Day'**
  String get wallpaperNotificationPromptTitle;

  /// Accessibility label for the offline indicator.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get wallpaperOffline;

  /// Explanation shown when the app version is no longer supported.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is no longer supported. Update Prism to keep using it.'**
  String wallpaperOldVersionBody(String version);

  /// Title shown when the app version is no longer supported.
  ///
  /// In en, this message translates to:
  /// **'Time to update'**
  String get wallpaperOldVersionTitle;

  /// Wallpaper title or recommendation text: wallpaperOnPrism.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper on Prism'**
  String get wallpaperOnPrism;

  /// Error title shown when a wallpaper cannot be loaded for viewing or placement.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this wallpaper'**
  String get wallpaperOpenError;

  /// Title shown when a downloaded wallpaper file cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this wallpaper'**
  String get wallpaperOpenFileError;

  /// Accessibility label for the notifications button.
  ///
  /// In en, this message translates to:
  /// **'Open notifications'**
  String get wallpaperOpenNotifications;

  /// Filter label for wallpapers from another source.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get wallpaperOtherSource;

  /// Empty state title when the archive has no past picks.
  ///
  /// In en, this message translates to:
  /// **'No past picks yet'**
  String get wallpaperPastPicksEmpty;

  /// Error shown when past daily picks cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load past picks'**
  String get wallpaperPastPicksLoadError;

  /// Title for the archive of past Wall of the Day picks.
  ///
  /// In en, this message translates to:
  /// **'Past picks'**
  String get wallpaperPastPicksTitle;

  /// Label for adjusting wallpaper dim level.
  ///
  /// In en, this message translates to:
  /// **'Dim'**
  String get wallpaperPlacementDim;

  /// Notice that wallpaper placement preview may differ by launcher.
  ///
  /// In en, this message translates to:
  /// **'Approximate. Your launcher may differ.'**
  String get wallpaperPositionApproximate;

  /// Accessibility label for premium content.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get wallpaperPremium;

  /// Wallpaper and feed interface text: wallpaperPremiumCollection.
  ///
  /// In en, this message translates to:
  /// **'Premium collection'**
  String get wallpaperPremiumCollection;

  /// Wallpaper and feed interface text: wallpaperPremiumCollectionNamed.
  ///
  /// In en, this message translates to:
  /// **'Premium collection, {name}'**
  String wallpaperPremiumCollectionNamed(String name);

  /// Preview mode option for the home screen.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get wallpaperPreviewHome;

  /// Home screen preview icon style: clear glass app icons (iOS).
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get wallpaperPreviewIconClear;

  /// Home screen preview icon style: dark app icons (iOS).
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get wallpaperPreviewIconDark;

  /// Home screen preview icon style: normal colourful app icons.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get wallpaperPreviewIconDefault;

  /// Accessibility label of the picker that changes how app icons look in the home screen preview.
  ///
  /// In en, this message translates to:
  /// **'Icon style'**
  String get wallpaperPreviewIconStyle;

  /// Home screen preview icon style: Android themed icons coloured from the wallpaper (Material You).
  ///
  /// In en, this message translates to:
  /// **'Themed'**
  String get wallpaperPreviewIconThemed;

  /// Home screen preview icon style: one-colour app icons tinted from the wallpaper (iOS).
  ///
  /// In en, this message translates to:
  /// **'Tinted'**
  String get wallpaperPreviewIconTinted;

  /// Preview mode option for the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get wallpaperPreviewLock;

  /// Tooltip for the button that opens a full-screen preview of the wallpaper on a mock phone lock and home screen.
  ///
  /// In en, this message translates to:
  /// **'Preview on your screen'**
  String get wallpaperPreviewOnScreen;

  /// Button in the wallpaper preview that sets the wallpaper on the lock and home screens.
  ///
  /// In en, this message translates to:
  /// **'Set on both screens'**
  String get wallpaperPreviewSetBoth;

  /// Button in the wallpaper preview that sets the wallpaper on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Set on home screen'**
  String get wallpaperPreviewSetHome;

  /// Button in the wallpaper preview that sets the wallpaper on the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Set on lock screen'**
  String get wallpaperPreviewSetLock;

  /// Action to spend coins on a premium collection preview.
  ///
  /// In en, this message translates to:
  /// **'Unlock for 24 hours (-{cost})'**
  String wallpaperPreviewUnlock24Hours(int cost);

  /// Premium collection preview cost message.
  ///
  /// In en, this message translates to:
  /// **'Preview this premium collection for 24 hours for {cost} coins.'**
  String wallpaperPreviewUnlockCost(int cost);

  /// Premium collection preview cost message when a user needs more coins.
  ///
  /// In en, this message translates to:
  /// **'A 24 hour preview costs {cost} coins. You need {missing} more.'**
  String wallpaperPreviewUnlockCostMissing(int cost, int missing);

  /// Action to watch an ad and then unlock a premium collection preview.
  ///
  /// In en, this message translates to:
  /// **'{adOption} and unlock'**
  String wallpaperPreviewWatchAdUnlock(String adOption);

  /// Progress message shown while a wallpaper edit is exported.
  ///
  /// In en, this message translates to:
  /// **'Processing wallpaper'**
  String get wallpaperProcessing;

  /// Error shown when a creator profile link cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not open profile'**
  String get wallpaperProfileOpenError;

  /// Action to add a wallpaper quick tile to Android Quick Settings.
  ///
  /// In en, this message translates to:
  /// **'Add to Quick Settings'**
  String get wallpaperQuickAddAction;

  /// Description of the random favourite wallpaper quick tile.
  ///
  /// In en, this message translates to:
  /// **'Applies a random wallpaper from your favourites. Sign in and favourite some wallpapers first.'**
  String get wallpaperQuickFavouriteDescription;

  /// Title of the random favourite wallpaper quick tile.
  ///
  /// In en, this message translates to:
  /// **'Random favourite tile'**
  String get wallpaperQuickFavouriteTitle;

  /// Title of the instructions for manually adding a quick tile.
  ///
  /// In en, this message translates to:
  /// **'How to add a tile'**
  String get wallpaperQuickHowToTitle;

  /// Description of the category shuffle quick tile.
  ///
  /// In en, this message translates to:
  /// **'Tap the tile to apply a random wallpaper from the category you pick.'**
  String get wallpaperQuickShuffleDescription;

  /// Title of the quick tile that applies a random wallpaper from a category.
  ///
  /// In en, this message translates to:
  /// **'Shuffle wallpaper tile'**
  String get wallpaperQuickShuffleTitle;

  /// Second step for manually adding a Quick Settings tile.
  ///
  /// In en, this message translates to:
  /// **'Tap the pencil or edit icon.'**
  String get wallpaperQuickStepEdit;

  /// Final step for manually adding a Quick Settings tile.
  ///
  /// In en, this message translates to:
  /// **'Find the Prism tiles and drag them to your active tiles.'**
  String get wallpaperQuickStepFindPrism;

  /// First step for manually adding a Quick Settings tile.
  ///
  /// In en, this message translates to:
  /// **'Pull down the notification shade twice.'**
  String get wallpaperQuickStepShade;

  /// Quick tile target option for both screens.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get wallpaperQuickTargetBoth;

  /// Quick tile target option for the home screen.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get wallpaperQuickTargetHome;

  /// Quick tile target option for the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get wallpaperQuickTargetLock;

  /// Instructions shown when Prism cannot add the wallpaper tile directly.
  ///
  /// In en, this message translates to:
  /// **'Could not add the tile. Add it by hand from the Quick Settings edit screen.'**
  String get wallpaperQuickTileAddError;

  /// Confirmation after adding a wallpaper tile to Android Quick Settings.
  ///
  /// In en, this message translates to:
  /// **'Tile added to Quick Settings.'**
  String get wallpaperQuickTileAdded;

  /// Notice shown when the wallpaper tile is already in Android Quick Settings.
  ///
  /// In en, this message translates to:
  /// **'This tile is already in Quick Settings.'**
  String get wallpaperQuickTileAlreadyAdded;

  /// Notice when the user declines to add the wallpaper tile.
  ///
  /// In en, this message translates to:
  /// **'Tile not added. You can add it any time.'**
  String get wallpaperQuickTileNotAdded;

  /// Error shown when quick tile settings cannot be saved.
  ///
  /// In en, this message translates to:
  /// **'Could not save quick tile settings'**
  String get wallpaperQuickTileSaveError;

  /// Error state title when quick tile settings cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your quick tiles'**
  String get wallpaperQuickTilesLoadError;

  /// Title of the Android quick tile settings screen.
  ///
  /// In en, this message translates to:
  /// **'Quick tiles'**
  String get wallpaperQuickTilesTitle;

  /// Description of the Wall of the Day quick tile.
  ///
  /// In en, this message translates to:
  /// **'Applies today\'s Wall of the Day. Open Prism once a day to cache the latest one.'**
  String get wallpaperQuickWotdDescription;

  /// Title of the Wall of the Day quick tile.
  ///
  /// In en, this message translates to:
  /// **'Wall of the Day tile'**
  String get wallpaperQuickWotdTitle;

  /// Wallpaper and feed interface text: wallpaperRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get wallpaperRefresh;

  /// Confirmation after removing a wallpaper from history.
  ///
  /// In en, this message translates to:
  /// **'Removed from history'**
  String get wallpaperRemovedFromHistory;

  /// Wallpaper interface text: wallpaperReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get wallpaperReport;

  /// Action to reset wallpaper placement adjustments.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get wallpaperReset;

  /// Wallpaper and feed interface text: wallpaperSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get wallpaperSave;

  /// Wallpaper interface text: wallpaperSaveToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Save to Photos'**
  String get wallpaperSaveToPhotos;

  /// Wallpaper interface text: wallpaperSavedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get wallpaperSavedOnDevice;

  /// Wallpaper interface text: wallpaperSearchTag.
  ///
  /// In en, this message translates to:
  /// **'Search {tag}'**
  String wallpaperSearchTag(String tag);

  /// Action to view the Prism Pro offer.
  ///
  /// In en, this message translates to:
  /// **'See Prism Pro'**
  String get wallpaperSeePrismPro;

  /// Accessibility state for an item that is selected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get wallpaperSelected;

  /// Wallpaper and feed interface text: wallpaperServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the servers'**
  String get wallpaperServerUnavailable;

  /// Message shown when a user session expires.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in again.'**
  String get wallpaperSessionEnded;

  /// Wallpaper interface text: wallpaperSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get wallpaperSet;

  /// Wallpaper menu action to set this wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set as wallpaper'**
  String get wallpaperSetAsWallpaper;

  /// Wallpaper interface text: wallpaperSetCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Set once} other{Set {count} times}}'**
  String wallpaperSetCount(int count);

  /// Segment on the Set screen that targets the home screen.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get setScreenTargetHome;

  /// Segment on the Set screen that targets the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get setScreenTargetLock;

  /// Segment on the Set screen that targets the home and lock screens.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get setScreenTargetBoth;

  /// Screen reader label for the group of target segments on the Set screen.
  ///
  /// In en, this message translates to:
  /// **'Where to set it'**
  String get setScreenTargetGroup;

  /// Check on the Set screen. When on, Set uses this screen next time without showing the Set screen.
  ///
  /// In en, this message translates to:
  /// **'Remember this choice'**
  String get setScreenRemember;

  /// Caption under "Remember this choice" when it is checked.
  ///
  /// In en, this message translates to:
  /// **'Set skips this screen next time. Touch and hold Set to come back.'**
  String get setScreenRememberHint;

  /// Button on the Set screen that opens the screen to pan, zoom, fit and dim the wallpaper. Also the title of that screen.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get setScreenAdjust;

  /// Button on the Set screen that shows more ways to set the wallpaper.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get setScreenMore;

  /// Menu item on the Set screen. The current wallpaper goes on the home screen and the user picks a different one for the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Use another wall for the lock screen'**
  String get setScreenPairLock;

  /// Button in the Adjust screen that opens the Android system editor to pick the exact area of the wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Open system editor'**
  String get setScreenOpenSystemEditor;

  /// Tooltip for the close button on the Set screen.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get setScreenClose;

  /// Action to share selected wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get wallpaperShare;

  /// Wallpaper menu action to share its link.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get wallpaperShareLink;

  /// Step to add the Prism wallpaper and system wallpaper actions in Shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Add the action \"Get Prism Wallpaper\". Then add the action \"Set Wallpaper\".'**
  String get wallpaperShortcutsAddActionsSteps;

  /// Explanation of how iOS Shortcuts can change wallpapers automatically.
  ///
  /// In en, this message translates to:
  /// **'Use Shortcuts to set a wallpaper on a schedule or trigger. Prepare the source below before running it.'**
  String get wallpaperShortcutsBody;

  /// Section title for choosing wallpaper data in Shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Pick what Prism sends'**
  String get wallpaperShortcutsChoosePrismData;

  /// Step to choose a trigger for an iOS Shortcuts wallpaper automation.
  ///
  /// In en, this message translates to:
  /// **'In the shortcut editor, open Automation if needed. Choose and configure a trigger, such as Time of Day, opening an app, or connecting a charger.'**
  String get wallpaperShortcutsChooseTriggerSteps;

  /// Step to disable confirmation and save an iOS Shortcuts automation.
  ///
  /// In en, this message translates to:
  /// **'Review the run options shown and save the shortcut or automation. If \"Ask Before Running\" appears, turn it off for automatic runs.'**
  String get wallpaperShortcutsDisableConfirmationSteps;

  /// Headline describing automatic wallpaper changes through Shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Change your wallpaper automatically'**
  String get wallpaperShortcutsHeadline;

  /// Action to open Apple's Shortcuts app.
  ///
  /// In en, this message translates to:
  /// **'Open Shortcuts'**
  String get wallpaperShortcutsOpenAction;

  /// First step in creating a wallpaper automation in iOS Shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Open Shortcuts. If there is an Automation tab, tap it, then New Automation. Otherwise, tap Add (+), then Edit if shown.'**
  String get wallpaperShortcutsOpenAutomationSteps;

  /// Message shown when the Shortcuts app cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not open Shortcuts. Open the app yourself.'**
  String get wallpaperShortcutsOpenError;

  /// Shortcuts source option for a random favourite wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Random favourite'**
  String get wallpaperShortcutsSourceFavourite;

  /// Description of the random favourite Shortcuts source.
  ///
  /// In en, this message translates to:
  /// **'A random favourite available to Shortcuts. Heart wallpapers in Prism first. Some protected wallpapers may not be available. It avoids the last pick when another favourite is available.'**
  String get wallpaperShortcutsSourceFavouriteDescription;

  /// Shortcuts source option for the daily wallpaper pick.
  ///
  /// In en, this message translates to:
  /// **'Wall of the Day'**
  String get wallpaperShortcutsSourceWotd;

  /// Description of the Wall of the Day Shortcuts source.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Prism pick. Download today\'s original in Prism first. When the daily pick changes, download the new original before running this source.'**
  String get wallpaperShortcutsSourceWotdDescription;

  /// Section title for iOS Shortcuts setup instructions.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get wallpaperShortcutsSteps;

  /// Title of the iOS Shortcuts guide screen.
  ///
  /// In en, this message translates to:
  /// **'Change automatically'**
  String get wallpaperShortcutsTitle;

  /// Wallpaper menu action to reduce similar recommendations.
  ///
  /// In en, this message translates to:
  /// **'Show less like this'**
  String get wallpaperShowLessLikeThis;

  /// Accessibility label and action that shows the buttons again, on the wallpaper preview and on the wallpaper detail screen.
  ///
  /// In en, this message translates to:
  /// **'Show controls'**
  String get wallpaperShowPreviewControls;

  /// Action to sign in to Prism.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get wallpaperSignIn;

  /// Message shown when a signed-out user selects a premium filter.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use premium filters with coins.'**
  String get wallpaperSignInForPremiumFilters;

  /// Wallpaper interface text: wallpaperSortDownloads.
  ///
  /// In en, this message translates to:
  /// **'Sort downloads'**
  String get wallpaperSortDownloads;

  /// Title shown when app startup fails.
  ///
  /// In en, this message translates to:
  /// **'Prism could not start'**
  String get wallpaperStartupFailed;

  /// Section title for choosing the dark theme accent colour.
  ///
  /// In en, this message translates to:
  /// **'Dark Accent Color'**
  String get wallpaperThemeDarkAccent;

  /// Section title for dark theme choices.
  ///
  /// In en, this message translates to:
  /// **'Dark Themes'**
  String get wallpaperThemeDarkThemes;

  /// Button label that sets a wallpaper color as the app accent.
  ///
  /// In en, this message translates to:
  /// **'Use as app accent'**
  String get wallpaperUseAsAppAccent;

  /// Snackbar message shown after the app accent changes from a wallpaper.
  ///
  /// In en, this message translates to:
  /// **'App accent updated'**
  String get wallpaperAppAccentUpdated;

  /// Section title for choosing the light theme accent colour.
  ///
  /// In en, this message translates to:
  /// **'Light Accent Color'**
  String get wallpaperThemeLightAccent;

  /// Section title for light theme choices.
  ///
  /// In en, this message translates to:
  /// **'Light Themes'**
  String get wallpaperThemeLightThemes;

  /// Dark app theme mode option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get wallpaperThemeModeDark;

  /// Light app theme mode option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get wallpaperThemeModeLight;

  /// App theme mode option that follows the system light or dark appearance.
  ///
  /// In en, this message translates to:
  /// **'System (Light/Dark)'**
  String get wallpaperThemeModeSystem;

  /// Setting that selects the app theme mode.
  ///
  /// In en, this message translates to:
  /// **'Theme Preference'**
  String get wallpaperThemePreference;

  /// Description of the app theme preference options.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred theme mode. System mode automatically switches between light and dark depending on your device mode.'**
  String get wallpaperThemePreferenceDescription;

  /// Theme selection screen title.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get wallpaperThemeTitle;

  /// Wallpaper interface text: wallpaperTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get wallpaperTitle;

  /// Empty-state title when no wallpapers are trending.
  ///
  /// In en, this message translates to:
  /// **'Nothing is trending yet'**
  String get wallpaperTrendingEmptyTitle;

  /// Title shown when trending wallpapers cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load trending wallpapers'**
  String get wallpaperTrendingLoadError;

  /// Action to retry a failed wallpaper operation.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get wallpaperTryAgain;

  /// Action to turn off auto-rotate.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get wallpaperTurnOff;

  /// Action to proceed to the system notification permission prompt.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get wallpaperTurnOnNotifications;

  /// Label shown when a favourite wallpaper image is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get wallpaperUnavailable;

  /// Wallpaper interface text: wallpaperUnfavourite.
  ///
  /// In en, this message translates to:
  /// **'Unfavourite'**
  String get wallpaperUnfavourite;

  /// Accessibility hint for unread notifications.
  ///
  /// In en, this message translates to:
  /// **'Has unread items'**
  String get wallpaperUnreadItems;

  /// Action to update the app from the app store.
  ///
  /// In en, this message translates to:
  /// **'Update Prism'**
  String get wallpaperUpdatePrism;

  /// Wallpaper upload interface text: wallpaperUploadAction.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get wallpaperUploadAction;

  /// Wallpaper interface text: wallpaperUploadAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get wallpaperUploadAddTag;

  /// Wallpaper interface text: wallpaperUploadAddTagHint.
  ///
  /// In en, this message translates to:
  /// **'Add a tag, then tap Done'**
  String get wallpaperUploadAddTagHint;

  /// Subtitle for generating a wallpaper with AI.
  ///
  /// In en, this message translates to:
  /// **'Describe a scene and generate a phone wallpaper'**
  String get wallpaperUploadAiSubtitle;

  /// Wallpaper upload interface text: wallpaperUploadApprovalInfo.
  ///
  /// In en, this message translates to:
  /// **'Your wallpaper appears in the community after approval. Track it in Your uploads.'**
  String get wallpaperUploadApprovalInfo;

  /// Wallpaper interface text: wallpaperUploadBatchPosition.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper {position} of {total}'**
  String wallpaperUploadBatchPosition(int position, int total);

  /// Accessibility label for the current upload batch position and number of submitted wallpapers.
  ///
  /// In en, this message translates to:
  /// **'{label}. {count} submitted.'**
  String wallpaperUploadBatchSubmitted(String label, int count);

  /// Upload batch summary showing how many wallpapers were not submitted.
  ///
  /// In en, this message translates to:
  /// **'{submitted}. {notSent} not sent.'**
  String wallpaperUploadBatchSummaryNotSent(String submitted, int notSent);

  /// Upload batch summary showing how many wallpapers were submitted.
  ///
  /// In en, this message translates to:
  /// **'{submittedCount} of {total} wallpapers submitted'**
  String wallpaperUploadBatchSummarySubmitted(int submittedCount, int total);

  /// Label for the brightness adjustment slider.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get wallpaperUploadBrightness;

  /// Wallpaper upload interface text: wallpaperUploadCheckReviewStatus.
  ///
  /// In en, this message translates to:
  /// **'Check review status'**
  String get wallpaperUploadCheckReviewStatus;

  /// Action to pick another image after upload preparation fails.
  ///
  /// In en, this message translates to:
  /// **'Choose another image'**
  String get wallpaperUploadChooseAnotherImage;

  /// Subtitle for resuming a saved wallpaper upload.
  ///
  /// In en, this message translates to:
  /// **'Continue editing your saved wallpaper'**
  String get wallpaperUploadContinueDraft;

  /// Label for the contrast adjustment slider.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get wallpaperUploadContrast;

  /// Title for the create sheet.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get wallpaperUploadCreateTitle;

  /// Title in the confirmation dialog for deleting a submitted wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Delete this wallpaper?'**
  String get wallpaperUploadDeleteConfirmTitle;

  /// Error shown when deleting an uploaded wallpaper fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete. Try again.'**
  String get wallpaperUploadDeleteError;

  /// Error shown when the user cannot delete an upload because they are signed into another account.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete. Sign in with the account you used to upload, then try again.'**
  String get wallpaperUploadDeletePermissionError;

  /// Wallpaper interface text: wallpaperUploadDeleteWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Delete wallpaper'**
  String get wallpaperUploadDeleteWallpaper;

  /// Confirmation shown after deleting a submitted wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper deleted.'**
  String get wallpaperUploadDeleted;

  /// Wallpaper interface text: wallpaperUploadDetailsOptional.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get wallpaperUploadDetailsOptional;

  /// Body in a confirmation dialog for discarding an upload.
  ///
  /// In en, this message translates to:
  /// **'Uploaded files will be removed. Your selected image will stay on your device.'**
  String get wallpaperUploadDiscardBody;

  /// Wallpaper interface text: wallpaperUploadDiscardEditsBody.
  ///
  /// In en, this message translates to:
  /// **'Your changes will be lost.'**
  String get wallpaperUploadDiscardEditsBody;

  /// Wallpaper interface text: wallpaperUploadDiscardEditsTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard your edits?'**
  String get wallpaperUploadDiscardEditsTitle;

  /// Error shown when an upload cannot be discarded.
  ///
  /// In en, this message translates to:
  /// **'Could not discard this upload. Try again.'**
  String get wallpaperUploadDiscardError;

  /// Title in a confirmation dialog for discarding an upload.
  ///
  /// In en, this message translates to:
  /// **'Discard this upload?'**
  String get wallpaperUploadDiscardTitle;

  /// Error shown when downloading a submitted wallpaper fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download. Try again.'**
  String get wallpaperUploadDownloadError;

  /// Progress message shown while a submitted wallpaper is downloaded.
  ///
  /// In en, this message translates to:
  /// **'Starting download'**
  String get wallpaperUploadDownloadStarting;

  /// Error shown when an upload draft cannot be saved.
  ///
  /// In en, this message translates to:
  /// **'Could not save this draft. Try again.'**
  String get wallpaperUploadDraftSaveError;

  /// Wallpaper interface text: wallpaperUploadEditBatch.
  ///
  /// In en, this message translates to:
  /// **'Edit wallpaper {position} of {total}'**
  String wallpaperUploadEditBatch(int position, int total);

  /// Error shown when edits to an uploaded wallpaper cannot be saved.
  ///
  /// In en, this message translates to:
  /// **'Could not save your edits. Try again.'**
  String get wallpaperUploadEditSaveError;

  /// Label for the image file size in the upload preview.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get wallpaperUploadFileSize;

  /// Active upload check while wallpaper files upload.
  ///
  /// In en, this message translates to:
  /// **'Uploading the wallpaper and its preview'**
  String get wallpaperUploadFilesCheckActive;

  /// Completed upload check for uploading wallpaper files.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper and preview uploaded'**
  String get wallpaperUploadFilesCheckDone;

  /// Pending upload check for uploading wallpaper files.
  ///
  /// In en, this message translates to:
  /// **'Upload the wallpaper and its preview'**
  String get wallpaperUploadFilesCheckPending;

  /// Error shown when temporary upload files cannot be removed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove uploaded files. Try again.'**
  String get wallpaperUploadFilesRemoveError;

  /// Wallpaper interface text: wallpaperUploadFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get wallpaperUploadFlip;

  /// Message shown when the free weekly upload quota is reached.
  ///
  /// In en, this message translates to:
  /// **'Free users can upload {count} wallpapers per week.'**
  String wallpaperUploadFreeQuotaMessage(int count);

  /// Subtitle for uploading an image from the device gallery.
  ///
  /// In en, this message translates to:
  /// **'From your gallery'**
  String get wallpaperUploadFromGallery;

  /// Wallpaper interface text: wallpaperUploadFullImageError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the full image.'**
  String get wallpaperUploadFullImageError;

  /// Wallpaper interface text: wallpaperUploadInReview.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get wallpaperUploadInReview;

  /// Wallpaper upload interface text: wallpaperUploadKeepDraft.
  ///
  /// In en, this message translates to:
  /// **'Keep draft'**
  String get wallpaperUploadKeepDraft;

  /// Wallpaper upload interface text: wallpaperUploadLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Keep your draft to resume later, or discard it and remove uploaded files.'**
  String get wallpaperUploadLeaveBody;

  /// Wallpaper upload interface text: wallpaperUploadLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this upload?'**
  String get wallpaperUploadLeaveTitle;

  /// Wallpaper interface text: wallpaperUploadMaxTagsReached.
  ///
  /// In en, this message translates to:
  /// **'You added {count} tags'**
  String wallpaperUploadMaxTagsReached(int count);

  /// Guideline shown before a user submits a wallpaper upload.
  ///
  /// In en, this message translates to:
  /// **'Only upload original, high-quality wallpapers. Do not upload content from other apps.'**
  String get wallpaperUploadOriginalContentGuideline;

  /// Active upload check while image files are prepared.
  ///
  /// In en, this message translates to:
  /// **'Preparing your image and a smaller preview'**
  String get wallpaperUploadPrepareCheckActive;

  /// Completed upload check for image preparation.
  ///
  /// In en, this message translates to:
  /// **'Image and preview are ready'**
  String get wallpaperUploadPrepareCheckDone;

  /// Pending upload check for preparing image files.
  ///
  /// In en, this message translates to:
  /// **'Prepare your image and a smaller preview'**
  String get wallpaperUploadPrepareCheckPending;

  /// Error shown when a selected image could not be prepared.
  ///
  /// In en, this message translates to:
  /// **'We could not prepare this image. Try again or choose another image.'**
  String get wallpaperUploadPrepareError;

  /// Soft warning shown when an uploaded wallpaper is landscape oriented.
  ///
  /// In en, this message translates to:
  /// **'This image is wide. Phone wallpapers look best in portrait.'**
  String get wallpaperUploadQualityLandscape;

  /// Soft warning shown when an uploaded image may look blurry at phone size.
  ///
  /// In en, this message translates to:
  /// **'This image is {width}x{height}. It can look soft on a phone. {recommendedShortSide} px on the short side is best.'**
  String wallpaperUploadQualityLowResolution(int width, int height, int recommendedShortSide);

  /// Error shown when files cannot be removed after the weekly upload limit is reached.
  ///
  /// In en, this message translates to:
  /// **'You reached the upload limit, but we could not remove the uploaded files. Tap Back to try removing them again.'**
  String get wallpaperUploadQuotaCleanupFailed;

  /// Error shown when the weekly free wallpaper upload limit is reached.
  ///
  /// In en, this message translates to:
  /// **'You have reached this week’s free wallpaper upload limit.'**
  String get wallpaperUploadQuotaReached;

  /// Number of free wallpaper uploads remaining this week.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {total} free uploads left this week'**
  String wallpaperUploadQuotaRemaining(int remaining, int total);

  /// Wallpaper interface text: wallpaperUploadRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get wallpaperUploadRejected;

  /// Error shown when the user's rejected wallpaper submissions cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your rejected submissions.'**
  String get wallpaperUploadRejectedSectionError;

  /// Fallback review feedback when a submission has no rejection reason.
  ///
  /// In en, this message translates to:
  /// **'No specific reason was provided. Check your wallpaper details, then upload it again.'**
  String get wallpaperUploadRejectionFallback;

  /// Wallpaper interface text: wallpaperUploadRejectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Why it was rejected'**
  String get wallpaperUploadRejectionTitle;

  /// Wallpaper interface text: wallpaperUploadRemoveTag.
  ///
  /// In en, this message translates to:
  /// **'Remove tag {tag}'**
  String wallpaperUploadRemoveTag(String tag);

  /// Wallpaper interface text: wallpaperUploadResetAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Reset adjustments'**
  String get wallpaperUploadResetAdjustments;

  /// Label for the image resolution in the upload preview.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get wallpaperUploadResolution;

  /// Action to resume editing a saved wallpaper upload.
  ///
  /// In en, this message translates to:
  /// **'Resume saved upload'**
  String get wallpaperUploadResumeDraft;

  /// Action to retry a wallpaper submission.
  ///
  /// In en, this message translates to:
  /// **'Retry submit'**
  String get wallpaperUploadRetrySubmit;

  /// Active upload check while the submission is saved for review.
  ///
  /// In en, this message translates to:
  /// **'Saving your submission for review'**
  String get wallpaperUploadReviewCheckActive;

  /// Completed upload check after a submission is saved for review.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review'**
  String get wallpaperUploadReviewCheckDone;

  /// Pending upload check for moderator review.
  ///
  /// In en, this message translates to:
  /// **'Moderators review it before it appears in Prism'**
  String get wallpaperUploadReviewCheckPending;

  /// Empty-state description for the upload review list.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers you upload show their review status here.'**
  String get wallpaperUploadReviewEmptyBody;

  /// Empty-state title when there are no uploads in review.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get wallpaperUploadReviewEmptyTitle;

  /// Title shown when uploaded wallpaper review status cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your uploads'**
  String get wallpaperUploadReviewLoadError;

  /// Error shown when the user's pending wallpaper submissions cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your submissions.'**
  String get wallpaperUploadReviewSectionError;

  /// Wallpaper interface text: wallpaperUploadRotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get wallpaperUploadRotateLeft;

  /// Wallpaper interface text: wallpaperUploadRotateRight.
  ///
  /// In en, this message translates to:
  /// **'Rotate right'**
  String get wallpaperUploadRotateRight;

  /// Label for the saturation adjustment slider.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get wallpaperUploadSaturation;

  /// Confirmation shown after saving an uploaded wallpaper to the device.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper saved to Pictures/Prism'**
  String get wallpaperUploadSavedToPictures;

  /// Wallpaper upload interface text: wallpaperUploadSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this wallpaper'**
  String get wallpaperUploadSkip;

  /// Upload progress title after image preparation fails.
  ///
  /// In en, this message translates to:
  /// **'Image could not be prepared'**
  String get wallpaperUploadStagePrepareFailed;

  /// Upload progress title while an image is being prepared.
  ///
  /// In en, this message translates to:
  /// **'Preparing wallpaper'**
  String get wallpaperUploadStagePreparing;

  /// Upload progress title when the user reaches the free upload limit.
  ///
  /// In en, this message translates to:
  /// **'Upload limit reached'**
  String get wallpaperUploadStageQuotaReached;

  /// Upload progress title when a wallpaper is ready for submission.
  ///
  /// In en, this message translates to:
  /// **'Ready to submit'**
  String get wallpaperUploadStageReady;

  /// Upload progress title when submission status cannot be confirmed.
  ///
  /// In en, this message translates to:
  /// **'Submission did not finish'**
  String get wallpaperUploadStageSubmissionFailed;

  /// Upload progress title while a submission is being saved.
  ///
  /// In en, this message translates to:
  /// **'Submitting wallpaper'**
  String get wallpaperUploadStageSubmitting;

  /// Upload progress title after file upload fails.
  ///
  /// In en, this message translates to:
  /// **'Upload did not finish'**
  String get wallpaperUploadStageUploadFailed;

  /// Upload progress title while wallpaper files are uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading wallpaper'**
  String get wallpaperUploadStageUploading;

  /// Error shown when the app cannot confirm whether a wallpaper submission completed.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm the submission. Check your review status before trying again.'**
  String get wallpaperUploadSubmissionUnconfirmed;

  /// Wallpaper interface text: wallpaperUploadTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get wallpaperUploadTags;

  /// Wallpaper interface text: wallpaperUploadTagsHelp.
  ///
  /// In en, this message translates to:
  /// **'Up to {count}. Tags help people find your wallpaper.'**
  String wallpaperUploadTagsHelp(int count);

  /// Wallpaper upload interface text: wallpaperUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload wallpaper'**
  String get wallpaperUploadTitle;

  /// Wallpaper interface text: wallpaperUploadTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Name your wallpaper'**
  String get wallpaperUploadTitleHint;

  /// Accessibility label for opening an uploaded wallpaper.
  ///
  /// In en, this message translates to:
  /// **'View wallpaper'**
  String get wallpaperUploadViewWallpaper;

  /// Wallpaper interface text: wallpaperUploadYourUploads.
  ///
  /// In en, this message translates to:
  /// **'Your uploads'**
  String get wallpaperUploadYourUploads;

  /// Description of matching the device accent colour.
  ///
  /// In en, this message translates to:
  /// **'Use the accent colour of your phone'**
  String get wallpaperUsePhoneAccent;

  /// No description provided for @wallpaperThemeMaterialYouNote.
  ///
  /// In en, this message translates to:
  /// **'Material You takes its colours from your wallpaper.'**
  String get wallpaperThemeMaterialYouNote;

  /// Wallpaper interface text: wallpaperViewCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 view} other{{count} views}}'**
  String wallpaperViewCount(int count);

  /// Fallback shown when the service returns a view count that cannot be parsed.
  ///
  /// In en, this message translates to:
  /// **'View count unavailable'**
  String get wallpaperViewCountUnavailable;

  /// Accessibility label for the daily featured wallpaper with its creator.
  ///
  /// In en, this message translates to:
  /// **'Wall of the day by {name}'**
  String wallpaperWotdByPhotographer(String name);

  /// No description provided for @economyAiPromptSceneAnime1.
  ///
  /// In en, this message translates to:
  /// **'a cat napping on a sunlit train platform'**
  String get economyAiPromptSceneAnime1;

  /// No description provided for @economyAiPromptSceneAnime2.
  ///
  /// In en, this message translates to:
  /// **'towering summer clouds over rice fields'**
  String get economyAiPromptSceneAnime2;

  /// No description provided for @economyAiPromptSceneAnime3.
  ///
  /// In en, this message translates to:
  /// **'a ramen stall glowing on a rainy back street'**
  String get economyAiPromptSceneAnime3;

  /// No description provided for @economyAiPromptSceneAnime4.
  ///
  /// In en, this message translates to:
  /// **'a hilltop shrine gate above a sea of clouds'**
  String get economyAiPromptSceneAnime4;

  /// No description provided for @economyAiPromptSceneAnime5.
  ///
  /// In en, this message translates to:
  /// **'fireworks over a river at a summer festival'**
  String get economyAiPromptSceneAnime5;

  /// No description provided for @economyAiPromptSceneAnime6.
  ///
  /// In en, this message translates to:
  /// **'a quiet classroom with petals drifting in'**
  String get economyAiPromptSceneAnime6;

  /// No description provided for @economyAiPromptSceneAnime7.
  ///
  /// In en, this message translates to:
  /// **'a seaside road with a lone bus stop at dusk'**
  String get economyAiPromptSceneAnime7;

  /// No description provided for @economyAiPromptSceneAnime8.
  ///
  /// In en, this message translates to:
  /// **'a sky whale drifting over a sleepy town'**
  String get economyAiPromptSceneAnime8;

  /// No description provided for @economyAiPromptSceneMinimal1.
  ///
  /// In en, this message translates to:
  /// **'a single paper boat on still pale water'**
  String get economyAiPromptSceneMinimal1;

  /// No description provided for @economyAiPromptSceneMinimal2.
  ///
  /// In en, this message translates to:
  /// **'one arch of light over an empty plain'**
  String get economyAiPromptSceneMinimal2;

  /// No description provided for @economyAiPromptSceneMinimal3.
  ///
  /// In en, this message translates to:
  /// **'a lone tree on a gentle snowy slope'**
  String get economyAiPromptSceneMinimal3;

  /// No description provided for @economyAiPromptSceneMinimal4.
  ///
  /// In en, this message translates to:
  /// **'two overlapping circles on soft grain'**
  String get economyAiPromptSceneMinimal4;

  /// No description provided for @economyAiPromptSceneMinimal5.
  ///
  /// In en, this message translates to:
  /// **'a thin horizon line splitting sea and sky'**
  String get economyAiPromptSceneMinimal5;

  /// No description provided for @economyAiPromptSceneMinimal6.
  ///
  /// In en, this message translates to:
  /// **'a single feather falling through empty space'**
  String get economyAiPromptSceneMinimal6;

  /// No description provided for @economyAiPromptSceneMinimal7.
  ///
  /// In en, this message translates to:
  /// **'stacked smooth pebbles on a pale backdrop'**
  String get economyAiPromptSceneMinimal7;

  /// No description provided for @economyAiPromptSceneMinimal8.
  ///
  /// In en, this message translates to:
  /// **'a crescent shadow on a soft plaster wall'**
  String get economyAiPromptSceneMinimal8;

  /// No description provided for @economyAiPromptSceneCyberpunk1.
  ///
  /// In en, this message translates to:
  /// **'a rain-soaked noodle bar under neon glow'**
  String get economyAiPromptSceneCyberpunk1;

  /// No description provided for @economyAiPromptSceneCyberpunk2.
  ///
  /// In en, this message translates to:
  /// **'a hover train threading between megatowers'**
  String get economyAiPromptSceneCyberpunk2;

  /// No description provided for @economyAiPromptSceneCyberpunk3.
  ///
  /// In en, this message translates to:
  /// **'a lone android on a rooftop in the rain'**
  String get economyAiPromptSceneCyberpunk3;

  /// No description provided for @economyAiPromptSceneCyberpunk4.
  ///
  /// In en, this message translates to:
  /// **'a glowing data highway into a vast city'**
  String get economyAiPromptSceneCyberpunk4;

  /// No description provided for @economyAiPromptSceneCyberpunk5.
  ///
  /// In en, this message translates to:
  /// **'a night market under a tangle of cables'**
  String get economyAiPromptSceneCyberpunk5;

  /// No description provided for @economyAiPromptSceneCyberpunk6.
  ///
  /// In en, this message translates to:
  /// **'a chrome motorbike parked in a neon alley'**
  String get economyAiPromptSceneCyberpunk6;

  /// No description provided for @economyAiPromptSceneCyberpunk7.
  ///
  /// In en, this message translates to:
  /// **'a hologram moon rising over city towers'**
  String get economyAiPromptSceneCyberpunk7;

  /// No description provided for @economyAiPromptSceneCyberpunk8.
  ///
  /// In en, this message translates to:
  /// **'a flooded street mirroring a wall of screens'**
  String get economyAiPromptSceneCyberpunk8;

  /// No description provided for @economyAiPromptSceneWatercolor1.
  ///
  /// In en, this message translates to:
  /// **'a lavender field fading into morning mist'**
  String get economyAiPromptSceneWatercolor1;

  /// No description provided for @economyAiPromptSceneWatercolor2.
  ///
  /// In en, this message translates to:
  /// **'a small fishing village by a calm harbor'**
  String get economyAiPromptSceneWatercolor2;

  /// No description provided for @economyAiPromptSceneWatercolor3.
  ///
  /// In en, this message translates to:
  /// **'wild poppies swaying beside a country lane'**
  String get economyAiPromptSceneWatercolor3;

  /// No description provided for @economyAiPromptSceneWatercolor4.
  ///
  /// In en, this message translates to:
  /// **'a hot air balloon over soft green hills'**
  String get economyAiPromptSceneWatercolor4;

  /// No description provided for @economyAiPromptSceneWatercolor5.
  ///
  /// In en, this message translates to:
  /// **'a heron standing in a reed-filled pond'**
  String get economyAiPromptSceneWatercolor5;

  /// No description provided for @economyAiPromptSceneWatercolor6.
  ///
  /// In en, this message translates to:
  /// **'a rainy city street with blurred lamps'**
  String get economyAiPromptSceneWatercolor6;

  /// No description provided for @economyAiPromptSceneWatercolor7.
  ///
  /// In en, this message translates to:
  /// **'a teacup steaming beside an open window'**
  String get economyAiPromptSceneWatercolor7;

  /// No description provided for @economyAiPromptSceneWatercolor8.
  ///
  /// In en, this message translates to:
  /// **'snowy pines along a winding frozen creek'**
  String get economyAiPromptSceneWatercolor8;

  /// No description provided for @economyAiPromptSceneMeshGradient1.
  ///
  /// In en, this message translates to:
  /// **'soft color blobs melting into each other'**
  String get economyAiPromptSceneMeshGradient1;

  /// No description provided for @economyAiPromptSceneMeshGradient2.
  ///
  /// In en, this message translates to:
  /// **'a silky gradient wave folding on itself'**
  String get economyAiPromptSceneMeshGradient2;

  /// No description provided for @economyAiPromptSceneMeshGradient3.
  ///
  /// In en, this message translates to:
  /// **'glowing orbs blending on a velvet backdrop'**
  String get economyAiPromptSceneMeshGradient3;

  /// No description provided for @economyAiPromptSceneMeshGradient4.
  ///
  /// In en, this message translates to:
  /// **'an aurora-like gradient sweeping upward'**
  String get economyAiPromptSceneMeshGradient4;

  /// No description provided for @economyAiPromptSceneMeshGradient5.
  ///
  /// In en, this message translates to:
  /// **'liquid color pools with a fine grain'**
  String get economyAiPromptSceneMeshGradient5;

  /// No description provided for @economyAiPromptSceneMeshGradient6.
  ///
  /// In en, this message translates to:
  /// **'a warm-to-cool gradient with soft noise'**
  String get economyAiPromptSceneMeshGradient6;

  /// No description provided for @economyAiPromptSceneMeshGradient7.
  ///
  /// In en, this message translates to:
  /// **'overlapping translucent gradient petals'**
  String get economyAiPromptSceneMeshGradient7;

  /// No description provided for @economyAiPromptSceneMeshGradient8.
  ///
  /// In en, this message translates to:
  /// **'a blurred sunset of fluid color bands'**
  String get economyAiPromptSceneMeshGradient8;

  /// No description provided for @economyAiPromptSceneAbstract1.
  ///
  /// In en, this message translates to:
  /// **'interlocking glass shards catching light'**
  String get economyAiPromptSceneAbstract1;

  /// No description provided for @economyAiPromptSceneAbstract2.
  ///
  /// In en, this message translates to:
  /// **'flowing ink clouds suspended in water'**
  String get economyAiPromptSceneAbstract2;

  /// No description provided for @economyAiPromptSceneAbstract3.
  ///
  /// In en, this message translates to:
  /// **'a spiral of folded ribbons in motion'**
  String get economyAiPromptSceneAbstract3;

  /// No description provided for @economyAiPromptSceneAbstract4.
  ///
  /// In en, this message translates to:
  /// **'shattered marble with veins of gold'**
  String get economyAiPromptSceneAbstract4;

  /// No description provided for @economyAiPromptSceneAbstract5.
  ///
  /// In en, this message translates to:
  /// **'rippling topographic lines in layers'**
  String get economyAiPromptSceneAbstract5;

  /// No description provided for @economyAiPromptSceneAbstract6.
  ///
  /// In en, this message translates to:
  /// **'floating spheres casting long shadows'**
  String get economyAiPromptSceneAbstract6;

  /// No description provided for @economyAiPromptSceneAbstract7.
  ///
  /// In en, this message translates to:
  /// **'smoke trails curling into a vortex'**
  String get economyAiPromptSceneAbstract7;

  /// No description provided for @economyAiPromptSceneAbstract8.
  ///
  /// In en, this message translates to:
  /// **'a field of soft cubes rising in waves'**
  String get economyAiPromptSceneAbstract8;

  /// No description provided for @economyAiPromptSceneNature1.
  ///
  /// In en, this message translates to:
  /// **'a waterfall pouring into a mossy gorge'**
  String get economyAiPromptSceneNature1;

  /// No description provided for @economyAiPromptSceneNature2.
  ///
  /// In en, this message translates to:
  /// **'a field of sunflowers under a big sky'**
  String get economyAiPromptSceneNature2;

  /// No description provided for @economyAiPromptSceneNature3.
  ///
  /// In en, this message translates to:
  /// **'a frozen lake with cracks of blue ice'**
  String get economyAiPromptSceneNature3;

  /// No description provided for @economyAiPromptSceneNature4.
  ///
  /// In en, this message translates to:
  /// **'cherry trees lining a quiet river path'**
  String get economyAiPromptSceneNature4;

  /// No description provided for @economyAiPromptSceneNature5.
  ///
  /// In en, this message translates to:
  /// **'a tropical lagoon seen from above'**
  String get economyAiPromptSceneNature5;

  /// No description provided for @economyAiPromptSceneNature6.
  ///
  /// In en, this message translates to:
  /// **'autumn maples reflected in a still pond'**
  String get economyAiPromptSceneNature6;

  /// No description provided for @economyAiPromptSceneNature7.
  ///
  /// In en, this message translates to:
  /// **'a lone fox in fresh snow at dawn'**
  String get economyAiPromptSceneNature7;

  /// No description provided for @economyAiPromptSceneNature8.
  ///
  /// In en, this message translates to:
  /// **'storm clouds rolling over green highlands'**
  String get economyAiPromptSceneNature8;

  /// No description provided for @economyAiPromptSceneSpace1.
  ///
  /// In en, this message translates to:
  /// **'a ringed planet rising over a moon horizon'**
  String get economyAiPromptSceneSpace1;

  /// No description provided for @economyAiPromptSceneSpace2.
  ///
  /// In en, this message translates to:
  /// **'a spiral galaxy glowing in deep space'**
  String get economyAiPromptSceneSpace2;

  /// No description provided for @economyAiPromptSceneSpace3.
  ///
  /// In en, this message translates to:
  /// **'an astronaut floating above a blue planet'**
  String get economyAiPromptSceneSpace3;

  /// No description provided for @economyAiPromptSceneSpace4.
  ///
  /// In en, this message translates to:
  /// **'a nebula shaped like a blooming flower'**
  String get economyAiPromptSceneSpace4;

  /// No description provided for @economyAiPromptSceneSpace5.
  ///
  /// In en, this message translates to:
  /// **'twin suns setting over an alien desert'**
  String get economyAiPromptSceneSpace5;

  /// No description provided for @economyAiPromptSceneSpace6.
  ///
  /// In en, this message translates to:
  /// **'a space station orbiting a gas giant'**
  String get economyAiPromptSceneSpace6;

  /// No description provided for @economyAiPromptSceneSpace7.
  ///
  /// In en, this message translates to:
  /// **'a meteor shower over a quiet observatory'**
  String get economyAiPromptSceneSpace7;

  /// No description provided for @economyAiPromptSceneSpace8.
  ///
  /// In en, this message translates to:
  /// **'an eclipse with a bright diamond ring'**
  String get economyAiPromptSceneSpace8;

  /// No description provided for @economyAiPromptSceneSynthwave1.
  ///
  /// In en, this message translates to:
  /// **'a neon grid road racing toward a sunset'**
  String get economyAiPromptSceneSynthwave1;

  /// No description provided for @economyAiPromptSceneSynthwave2.
  ///
  /// In en, this message translates to:
  /// **'a palm-lined coast under a striped sun'**
  String get economyAiPromptSceneSynthwave2;

  /// No description provided for @economyAiPromptSceneSynthwave3.
  ///
  /// In en, this message translates to:
  /// **'a retro sports car on an endless highway'**
  String get economyAiPromptSceneSynthwave3;

  /// No description provided for @economyAiPromptSceneSynthwave4.
  ///
  /// In en, this message translates to:
  /// **'wireframe mountains under a magenta sky'**
  String get economyAiPromptSceneSynthwave4;

  /// No description provided for @economyAiPromptSceneSynthwave5.
  ///
  /// In en, this message translates to:
  /// **'a chrome sun sinking into a glowing sea'**
  String get economyAiPromptSceneSynthwave5;

  /// No description provided for @economyAiPromptSceneSynthwave6.
  ///
  /// In en, this message translates to:
  /// **'a retro arcade glowing on a rainy night'**
  String get economyAiPromptSceneSynthwave6;

  /// No description provided for @economyAiPromptSceneSynthwave7.
  ///
  /// In en, this message translates to:
  /// **'a cassette tape floating in neon space'**
  String get economyAiPromptSceneSynthwave7;

  /// No description provided for @economyAiPromptSceneSynthwave8.
  ///
  /// In en, this message translates to:
  /// **'a lone palm tree against a laser horizon'**
  String get economyAiPromptSceneSynthwave8;

  /// No description provided for @economyAiPromptScenePixelArt1.
  ///
  /// In en, this message translates to:
  /// **'a cozy cabin in a snowy forest at night'**
  String get economyAiPromptScenePixelArt1;

  /// No description provided for @economyAiPromptScenePixelArt2.
  ///
  /// In en, this message translates to:
  /// **'a castle on a cliff above the sea'**
  String get economyAiPromptScenePixelArt2;

  /// No description provided for @economyAiPromptScenePixelArt3.
  ///
  /// In en, this message translates to:
  /// **'a tiny town with glowing windows'**
  String get economyAiPromptScenePixelArt3;

  /// No description provided for @economyAiPromptScenePixelArt4.
  ///
  /// In en, this message translates to:
  /// **'a starship over a purple alien world'**
  String get economyAiPromptScenePixelArt4;

  /// No description provided for @economyAiPromptScenePixelArt5.
  ///
  /// In en, this message translates to:
  /// **'a waterfall in a lush jungle valley'**
  String get economyAiPromptScenePixelArt5;

  /// No description provided for @economyAiPromptScenePixelArt6.
  ///
  /// In en, this message translates to:
  /// **'a fishing pier under a full moon'**
  String get economyAiPromptScenePixelArt6;

  /// No description provided for @economyAiPromptScenePixelArt7.
  ///
  /// In en, this message translates to:
  /// **'a cherry blossom temple in spring'**
  String get economyAiPromptScenePixelArt7;

  /// No description provided for @economyAiPromptScenePixelArt8.
  ///
  /// In en, this message translates to:
  /// **'a train crossing a bridge at sunset'**
  String get economyAiPromptScenePixelArt8;

  /// No description provided for @economyAiPromptSceneRender3d1.
  ///
  /// In en, this message translates to:
  /// **'glossy clay shapes stacked in balance'**
  String get economyAiPromptSceneRender3d1;

  /// No description provided for @economyAiPromptSceneRender3d2.
  ///
  /// In en, this message translates to:
  /// **'frosted glass ribbons on a pastel stage'**
  String get economyAiPromptSceneRender3d2;

  /// No description provided for @economyAiPromptSceneRender3d3.
  ///
  /// In en, this message translates to:
  /// **'a tiny island floating on a soft cloud'**
  String get economyAiPromptSceneRender3d3;

  /// No description provided for @economyAiPromptSceneRender3d4.
  ///
  /// In en, this message translates to:
  /// **'inflated chrome bubbles in soft light'**
  String get economyAiPromptSceneRender3d4;

  /// No description provided for @economyAiPromptSceneRender3d5.
  ///
  /// In en, this message translates to:
  /// **'a miniature desert with a lone cactus'**
  String get economyAiPromptSceneRender3d5;

  /// No description provided for @economyAiPromptSceneRender3d6.
  ///
  /// In en, this message translates to:
  /// **'a cozy room diorama inside a cube'**
  String get economyAiPromptSceneRender3d6;

  /// No description provided for @economyAiPromptSceneRender3d7.
  ///
  /// In en, this message translates to:
  /// **'floating marble arches over still water'**
  String get economyAiPromptSceneRender3d7;

  /// No description provided for @economyAiPromptSceneRender3d8.
  ///
  /// In en, this message translates to:
  /// **'candy-colored waves frozen in motion'**
  String get economyAiPromptSceneRender3d8;

  /// No description provided for @economyAiPromptSceneOilPainting1.
  ///
  /// In en, this message translates to:
  /// **'a stormy sea crashing against a rocky shore'**
  String get economyAiPromptSceneOilPainting1;

  /// No description provided for @economyAiPromptSceneOilPainting2.
  ///
  /// In en, this message translates to:
  /// **'a sunlit poppy meadow with a farmhouse'**
  String get economyAiPromptSceneOilPainting2;

  /// No description provided for @economyAiPromptSceneOilPainting3.
  ///
  /// In en, this message translates to:
  /// **'a still life of lemons and a blue vase'**
  String get economyAiPromptSceneOilPainting3;

  /// No description provided for @economyAiPromptSceneOilPainting4.
  ///
  /// In en, this message translates to:
  /// **'a misty harbor at dawn with old ships'**
  String get economyAiPromptSceneOilPainting4;

  /// No description provided for @economyAiPromptSceneOilPainting5.
  ///
  /// In en, this message translates to:
  /// **'a forest path ablaze with autumn color'**
  String get economyAiPromptSceneOilPainting5;

  /// No description provided for @economyAiPromptSceneOilPainting6.
  ///
  /// In en, this message translates to:
  /// **'a moonlit canal lined with old houses'**
  String get economyAiPromptSceneOilPainting6;

  /// No description provided for @economyAiPromptSceneOilPainting7.
  ///
  /// In en, this message translates to:
  /// **'a wheat field rippling before a storm'**
  String get economyAiPromptSceneOilPainting7;

  /// No description provided for @economyAiPromptSceneOilPainting8.
  ///
  /// In en, this message translates to:
  /// **'a single rose in a glass on a dark table'**
  String get economyAiPromptSceneOilPainting8;

  /// No description provided for @economyAiPromptSceneUkiyoE1.
  ///
  /// In en, this message translates to:
  /// **'a great wave curling beneath a pale moon'**
  String get economyAiPromptSceneUkiyoE1;

  /// No description provided for @economyAiPromptSceneUkiyoE2.
  ///
  /// In en, this message translates to:
  /// **'a snow-covered pagoda at twilight'**
  String get economyAiPromptSceneUkiyoE2;

  /// No description provided for @economyAiPromptSceneUkiyoE3.
  ///
  /// In en, this message translates to:
  /// **'cranes flying over a misty mountain'**
  String get economyAiPromptSceneUkiyoE3;

  /// No description provided for @economyAiPromptSceneUkiyoE4.
  ///
  /// In en, this message translates to:
  /// **'a wooden bridge under falling cherry petals'**
  String get economyAiPromptSceneUkiyoE4;

  /// No description provided for @economyAiPromptSceneUkiyoE5.
  ///
  /// In en, this message translates to:
  /// **'fishing boats on a rough indigo sea'**
  String get economyAiPromptSceneUkiyoE5;

  /// No description provided for @economyAiPromptSceneUkiyoE6.
  ///
  /// In en, this message translates to:
  /// **'a red sun over a volcanic peak'**
  String get economyAiPromptSceneUkiyoE6;

  /// No description provided for @economyAiPromptSceneUkiyoE7.
  ///
  /// In en, this message translates to:
  /// **'a koi pond beneath weeping willows'**
  String get economyAiPromptSceneUkiyoE7;

  /// No description provided for @economyAiPromptSceneUkiyoE8.
  ///
  /// In en, this message translates to:
  /// **'rain falling over a quiet riverside town'**
  String get economyAiPromptSceneUkiyoE8;

  /// No description provided for @economyAiPromptLightingMorningHaze.
  ///
  /// In en, this message translates to:
  /// **'soft morning haze'**
  String get economyAiPromptLightingMorningHaze;

  /// No description provided for @economyAiPromptLightingGoldenHour.
  ///
  /// In en, this message translates to:
  /// **'golden hour glow'**
  String get economyAiPromptLightingGoldenHour;

  /// No description provided for @economyAiPromptLightingMoonlight.
  ///
  /// In en, this message translates to:
  /// **'cool moonlight'**
  String get economyAiPromptLightingMoonlight;

  /// No description provided for @economyAiPromptLightingNeonRim.
  ///
  /// In en, this message translates to:
  /// **'neon rim light'**
  String get economyAiPromptLightingNeonRim;

  /// No description provided for @economyAiPromptLightingBacklight.
  ///
  /// In en, this message translates to:
  /// **'warm backlight'**
  String get economyAiPromptLightingBacklight;

  /// No description provided for @economyAiPromptLightingGodRays.
  ///
  /// In en, this message translates to:
  /// **'soft god rays'**
  String get economyAiPromptLightingGodRays;

  /// No description provided for @economyAiPromptLightingStudio.
  ///
  /// In en, this message translates to:
  /// **'even studio light'**
  String get economyAiPromptLightingStudio;

  /// No description provided for @economyAiPromptLightingTwilight.
  ///
  /// In en, this message translates to:
  /// **'deep blue twilight'**
  String get economyAiPromptLightingTwilight;

  /// No description provided for @economyAiPromptPaletteTealAmber.
  ///
  /// In en, this message translates to:
  /// **'teal and amber hues'**
  String get economyAiPromptPaletteTealAmber;

  /// No description provided for @economyAiPromptPaletteIndigoRose.
  ///
  /// In en, this message translates to:
  /// **'indigo and rose hues'**
  String get economyAiPromptPaletteIndigoRose;

  /// No description provided for @economyAiPromptPaletteSageCream.
  ///
  /// In en, this message translates to:
  /// **'sage green and cream'**
  String get economyAiPromptPaletteSageCream;

  /// No description provided for @economyAiPromptPaletteBlackNeonPink.
  ///
  /// In en, this message translates to:
  /// **'black with neon pink'**
  String get economyAiPromptPaletteBlackNeonPink;

  /// No description provided for @economyAiPromptPalettePastelPeach.
  ///
  /// In en, this message translates to:
  /// **'soft pastel peach'**
  String get economyAiPromptPalettePastelPeach;

  /// No description provided for @economyAiPromptPaletteEmeraldGold.
  ///
  /// In en, this message translates to:
  /// **'emerald and gold'**
  String get economyAiPromptPaletteEmeraldGold;

  /// No description provided for @economyAiPromptPaletteOceanBlue.
  ///
  /// In en, this message translates to:
  /// **'shades of ocean blue'**
  String get economyAiPromptPaletteOceanBlue;

  /// No description provided for @economyAiPromptPaletteCrimsonCharcoal.
  ///
  /// In en, this message translates to:
  /// **'crimson and charcoal'**
  String get economyAiPromptPaletteCrimsonCharcoal;

  /// No description provided for @economyAiPromptSuffix.
  ///
  /// In en, this message translates to:
  /// **'vertical phone wallpaper, no text'**
  String get economyAiPromptSuffix;

  /// A complete AI wallpaper prompt. Translate the whole message naturally.
  ///
  /// In en, this message translates to:
  /// **'{scene}, {lighting}, {palette}, {suffix}'**
  String economyAiPromptComposition(String scene, String lighting, String palette, String suffix);

  /// An AI wallpaper scene prompt with wallpaper instructions.
  ///
  /// In en, this message translates to:
  /// **'{scene}, {suffix}'**
  String economyAiPromptSceneOnly(String scene, String suffix);

  /// No description provided for @economyAiMadeWithPrism.
  ///
  /// In en, this message translates to:
  /// **'Made with Prism AI'**
  String get economyAiMadeWithPrism;

  /// No description provided for @onboardingAiPromptFallback.
  ///
  /// In en, this message translates to:
  /// **'a beautiful wallpaper'**
  String get onboardingAiPromptFallback;

  /// No description provided for @onboardingAiPromptNature1.
  ///
  /// In en, this message translates to:
  /// **'a glacier lake at sunrise with mirror-still water and pink mountain peaks'**
  String get onboardingAiPromptNature1;

  /// No description provided for @onboardingAiPromptNature2.
  ///
  /// In en, this message translates to:
  /// **'a moss-covered forest stream with soft light falling through tall ferns'**
  String get onboardingAiPromptNature2;

  /// No description provided for @onboardingAiPromptNature3.
  ///
  /// In en, this message translates to:
  /// **'a field of wildflowers under a vast evening sky with drifting clouds'**
  String get onboardingAiPromptNature3;

  /// No description provided for @onboardingAiPromptNature4.
  ///
  /// In en, this message translates to:
  /// **'a black sand beach with turquoise waves and sea stacks at dusk'**
  String get onboardingAiPromptNature4;

  /// No description provided for @onboardingAiPromptNature5.
  ///
  /// In en, this message translates to:
  /// **'northern lights over a snowy pine forest beside a frozen lake'**
  String get onboardingAiPromptNature5;

  /// No description provided for @onboardingAiPromptAbstract1.
  ///
  /// In en, this message translates to:
  /// **'translucent glass ribbons twisting through soft light with iridescent edges'**
  String get onboardingAiPromptAbstract1;

  /// No description provided for @onboardingAiPromptAbstract2.
  ///
  /// In en, this message translates to:
  /// **'ink clouds blooming in water in deep blue and gold with rich soft detail'**
  String get onboardingAiPromptAbstract2;

  /// No description provided for @onboardingAiPromptAbstract3.
  ///
  /// In en, this message translates to:
  /// **'layered paper-like waves in warm sunset colors with gentle shadows'**
  String get onboardingAiPromptAbstract3;

  /// No description provided for @onboardingAiPromptAbstract4.
  ///
  /// In en, this message translates to:
  /// **'a sculpted marble swirl with gold veins on a deep charcoal background'**
  String get onboardingAiPromptAbstract4;

  /// No description provided for @onboardingAiPromptAbstract5.
  ///
  /// In en, this message translates to:
  /// **'floating chrome spheres reflecting a pastel sky in calm open space'**
  String get onboardingAiPromptAbstract5;

  /// No description provided for @onboardingAiPromptWatercolor1.
  ///
  /// In en, this message translates to:
  /// **'a watercolor seaside village with pastel houses and boats at sunrise'**
  String get onboardingAiPromptWatercolor1;

  /// No description provided for @onboardingAiPromptWatercolor2.
  ///
  /// In en, this message translates to:
  /// **'loose watercolor wildflowers in blush pink and sage on textured paper'**
  String get onboardingAiPromptWatercolor2;

  /// No description provided for @onboardingAiPromptWatercolor3.
  ///
  /// In en, this message translates to:
  /// **'a misty watercolor lake with a small wooden dock and distant hills'**
  String get onboardingAiPromptWatercolor3;

  /// No description provided for @onboardingAiPromptWatercolor4.
  ///
  /// In en, this message translates to:
  /// **'a watercolor night sky with soft violet clouds and a glowing moon'**
  String get onboardingAiPromptWatercolor4;

  /// No description provided for @onboardingAiPromptWatercolor5.
  ///
  /// In en, this message translates to:
  /// **'a watercolor autumn forest in warm washes of orange and gold'**
  String get onboardingAiPromptWatercolor5;

  /// No description provided for @onboardingAiPromptMinimal1.
  ///
  /// In en, this message translates to:
  /// **'a single sun setting over a calm sea with flat colors and a wide empty sky'**
  String get onboardingAiPromptMinimal1;

  /// No description provided for @onboardingAiPromptMinimal2.
  ///
  /// In en, this message translates to:
  /// **'soft layered hills in muted sand tones under a pale gradient sky'**
  String get onboardingAiPromptMinimal2;

  /// No description provided for @onboardingAiPromptMinimal3.
  ///
  /// In en, this message translates to:
  /// **'one bare tree on a snowy hill with plenty of quiet empty space'**
  String get onboardingAiPromptMinimal3;

  /// No description provided for @onboardingAiPromptMinimal4.
  ///
  /// In en, this message translates to:
  /// **'a lone sailboat on a still lake at dawn in simple shapes and soft tones'**
  String get onboardingAiPromptMinimal4;

  /// No description provided for @onboardingAiPromptMinimal5.
  ///
  /// In en, this message translates to:
  /// **'gentle concentric arches in terracotta and cream with fine grain'**
  String get onboardingAiPromptMinimal5;

  /// No description provided for @onboardingAiPromptAnime1.
  ///
  /// In en, this message translates to:
  /// **'an anime summer sky with towering clouds over a quiet seaside railway'**
  String get onboardingAiPromptAnime1;

  /// No description provided for @onboardingAiPromptAnime2.
  ///
  /// In en, this message translates to:
  /// **'an anime night city seen from a hilltop with warm lights and a sky of stars'**
  String get onboardingAiPromptAnime2;

  /// No description provided for @onboardingAiPromptAnime3.
  ///
  /// In en, this message translates to:
  /// **'an anime forest shrine with glowing spirits drifting in soft green light'**
  String get onboardingAiPromptAnime3;

  /// No description provided for @onboardingAiPromptAnime4.
  ///
  /// In en, this message translates to:
  /// **'an anime rainy street at dusk with glowing shop lights and puddle reflections'**
  String get onboardingAiPromptAnime4;

  /// No description provided for @onboardingAiPromptAnime5.
  ///
  /// In en, this message translates to:
  /// **'an anime meadow at golden hour with wind sweeping through tall grass'**
  String get onboardingAiPromptAnime5;

  /// No description provided for @onboardingAiPromptMeshGradient1.
  ///
  /// In en, this message translates to:
  /// **'a smooth mesh gradient of tangerine, pink and violet with soft grain'**
  String get onboardingAiPromptMeshGradient1;

  /// No description provided for @onboardingAiPromptMeshGradient2.
  ///
  /// In en, this message translates to:
  /// **'a deep mesh gradient of navy and teal with a glowing lime highlight'**
  String get onboardingAiPromptMeshGradient2;

  /// No description provided for @onboardingAiPromptMeshGradient3.
  ///
  /// In en, this message translates to:
  /// **'a soft mesh gradient of sky blue, lavender and warm cream'**
  String get onboardingAiPromptMeshGradient3;

  /// No description provided for @onboardingAiPromptMeshGradient4.
  ///
  /// In en, this message translates to:
  /// **'a bold mesh gradient of crimson and gold flowing like silk'**
  String get onboardingAiPromptMeshGradient4;

  /// No description provided for @onboardingAiPromptMeshGradient5.
  ///
  /// In en, this message translates to:
  /// **'a calm mesh gradient of sage, mint and pale sand with gentle light'**
  String get onboardingAiPromptMeshGradient5;

  /// No description provided for @onboardingAiPromptCyberpunk1.
  ///
  /// In en, this message translates to:
  /// **'a cyberpunk street at night in the rain with neon reflections and steam'**
  String get onboardingAiPromptCyberpunk1;

  /// No description provided for @onboardingAiPromptCyberpunk2.
  ///
  /// In en, this message translates to:
  /// **'a towering neon city seen from a rooftop with flying cars streaking past'**
  String get onboardingAiPromptCyberpunk2;

  /// No description provided for @onboardingAiPromptCyberpunk3.
  ///
  /// In en, this message translates to:
  /// **'a quiet cyberpunk canal lined with glowing shops and floating lanterns'**
  String get onboardingAiPromptCyberpunk3;

  /// No description provided for @onboardingAiPromptCyberpunk4.
  ///
  /// In en, this message translates to:
  /// **'a cyberpunk skyline at dawn with glass towers in pink and teal haze'**
  String get onboardingAiPromptCyberpunk4;

  /// No description provided for @onboardingAiPromptCyberpunk5.
  ///
  /// In en, this message translates to:
  /// **'a lone motorbike on a neon bridge over a misty futuristic city'**
  String get onboardingAiPromptCyberpunk5;

  /// No description provided for @onboardingAiPromptSpace1.
  ///
  /// In en, this message translates to:
  /// **'a ringed gas giant rising over a rocky moon with stars filling the black sky'**
  String get onboardingAiPromptSpace1;

  /// No description provided for @onboardingAiPromptSpace2.
  ///
  /// In en, this message translates to:
  /// **'a colorful nebula in violet and teal with bright young stars'**
  String get onboardingAiPromptSpace2;

  /// No description provided for @onboardingAiPromptSpace3.
  ///
  /// In en, this message translates to:
  /// **'a spiral galaxy seen face-on with a glowing core and dusty blue arms'**
  String get onboardingAiPromptSpace3;

  /// No description provided for @onboardingAiPromptSpace4.
  ///
  /// In en, this message translates to:
  /// **'an astronaut drifting above Earth at sunrise with a thin blue atmosphere'**
  String get onboardingAiPromptSpace4;

  /// No description provided for @onboardingAiPromptSpace5.
  ///
  /// In en, this message translates to:
  /// **'a total solar eclipse over a silent mountain range'**
  String get onboardingAiPromptSpace5;

  /// No description provided for @onboardingAiPromptSynthwave1.
  ///
  /// In en, this message translates to:
  /// **'a synthwave sunset with a striped sun over a glowing neon grid'**
  String get onboardingAiPromptSynthwave1;

  /// No description provided for @onboardingAiPromptSynthwave2.
  ///
  /// In en, this message translates to:
  /// **'a retro car driving toward a magenta sun on an empty coastal road'**
  String get onboardingAiPromptSynthwave2;

  /// No description provided for @onboardingAiPromptSynthwave3.
  ///
  /// In en, this message translates to:
  /// **'wireframe mountains under a starry purple sky with a chrome sun'**
  String get onboardingAiPromptSynthwave3;

  /// No description provided for @onboardingAiPromptSynthwave4.
  ///
  /// In en, this message translates to:
  /// **'a synthwave beach with palm silhouettes and a glowing pink horizon'**
  String get onboardingAiPromptSynthwave4;

  /// No description provided for @onboardingAiPromptSynthwave5.
  ///
  /// In en, this message translates to:
  /// **'a retro city skyline at night in pink and cyan neon haze'**
  String get onboardingAiPromptSynthwave5;

  /// No description provided for @onboardingAiPromptPixelArt1.
  ///
  /// In en, this message translates to:
  /// **'a pixel art cabin in a snowy forest with warm glowing windows at night'**
  String get onboardingAiPromptPixelArt1;

  /// No description provided for @onboardingAiPromptPixelArt2.
  ///
  /// In en, this message translates to:
  /// **'a pixel art seaside town at sunset with boats in the harbor'**
  String get onboardingAiPromptPixelArt2;

  /// No description provided for @onboardingAiPromptPixelArt3.
  ///
  /// In en, this message translates to:
  /// **'a pixel art castle on a floating island above the clouds'**
  String get onboardingAiPromptPixelArt3;

  /// No description provided for @onboardingAiPromptPixelArt4.
  ///
  /// In en, this message translates to:
  /// **'a pixel art night sky over a quiet lake with fireflies'**
  String get onboardingAiPromptPixelArt4;

  /// No description provided for @onboardingAiPromptPixelArt5.
  ///
  /// In en, this message translates to:
  /// **'a pixel art cherry blossom path leading to a small temple'**
  String get onboardingAiPromptPixelArt5;

  /// No description provided for @onboardingAiPromptRender3d1.
  ///
  /// In en, this message translates to:
  /// **'a 3D render of soft clay shapes in pastel colors with gentle shadows'**
  String get onboardingAiPromptRender3d1;

  /// No description provided for @onboardingAiPromptRender3d2.
  ///
  /// In en, this message translates to:
  /// **'a 3D render of a tiny floating island with a waterfall and trees'**
  String get onboardingAiPromptRender3d2;

  /// No description provided for @onboardingAiPromptRender3d3.
  ///
  /// In en, this message translates to:
  /// **'a 3D render of glossy glass waves in blue and violet under studio light'**
  String get onboardingAiPromptRender3d3;

  /// No description provided for @onboardingAiPromptRender3d4.
  ///
  /// In en, this message translates to:
  /// **'a 3D render of a cozy miniature room inside a glowing cube'**
  String get onboardingAiPromptRender3d4;

  /// No description provided for @onboardingAiPromptRender3d5.
  ///
  /// In en, this message translates to:
  /// **'a 3D render of chrome bubbles floating over a calm pink sea'**
  String get onboardingAiPromptRender3d5;

  /// No description provided for @onboardingAiPromptOilPainting1.
  ///
  /// In en, this message translates to:
  /// **'an oil painting of a stormy sea with a small ship under a dramatic sky'**
  String get onboardingAiPromptOilPainting1;

  /// No description provided for @onboardingAiPromptOilPainting2.
  ///
  /// In en, this message translates to:
  /// **'an oil painting of a sunlit poppy field with a distant farmhouse'**
  String get onboardingAiPromptOilPainting2;

  /// No description provided for @onboardingAiPromptOilPainting3.
  ///
  /// In en, this message translates to:
  /// **'an oil painting of a misty harbor at dawn with old wooden boats'**
  String get onboardingAiPromptOilPainting3;

  /// No description provided for @onboardingAiPromptOilPainting4.
  ///
  /// In en, this message translates to:
  /// **'an oil painting of an autumn forest path in thick, rich brushstrokes'**
  String get onboardingAiPromptOilPainting4;

  /// No description provided for @onboardingAiPromptOilPainting5.
  ///
  /// In en, this message translates to:
  /// **'an oil painting of a moonlit canal town with warm glowing windows'**
  String get onboardingAiPromptOilPainting5;

  /// No description provided for @onboardingAiPromptUkiyoE1.
  ///
  /// In en, this message translates to:
  /// **'a ukiyo-e great wave under a pale moon with a snowy mountain far away'**
  String get onboardingAiPromptUkiyoE1;

  /// No description provided for @onboardingAiPromptUkiyoE2.
  ///
  /// In en, this message translates to:
  /// **'a ukiyo-e snowy village at night with glowing paper lanterns'**
  String get onboardingAiPromptUkiyoE2;

  /// No description provided for @onboardingAiPromptUkiyoE3.
  ///
  /// In en, this message translates to:
  /// **'a ukiyo-e scene of cranes flying over misty mountains at dawn'**
  String get onboardingAiPromptUkiyoE3;

  /// No description provided for @onboardingAiPromptUkiyoE4.
  ///
  /// In en, this message translates to:
  /// **'a ukiyo-e wooden bridge under cherry blossoms on a spring day'**
  String get onboardingAiPromptUkiyoE4;

  /// No description provided for @onboardingAiPromptUkiyoE5.
  ///
  /// In en, this message translates to:
  /// **'a ukiyo-e red sun over a calm indigo sea with small fishing boats'**
  String get onboardingAiPromptUkiyoE5;

  /// Creator byline for the daily featured wallpaper.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String wallpaperWotdByline(String name);

  /// Label for the archive of past daily wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Past picks'**
  String get wallpaperWotdPastPicks;

  /// Accessibility label for a past Wall of the Day wallpaper and its pick date.
  ///
  /// In en, this message translates to:
  /// **'{wallpaper}, picked {date}'**
  String wallpaperWotdPickedOn(String wallpaper, String date);

  /// Accessibility label for opening the Wall of the Day archive.
  ///
  /// In en, this message translates to:
  /// **'See past walls of the day'**
  String get wallpaperWotdSeePast;

  /// Title and accessibility label for the daily featured wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Wall of the day'**
  String get wallpaperWotdTitle;

  /// Accessibility label for the profile button.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get wallpaperYourProfile;

  /// Settings row title that opens the iOS widget guide.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get widgetsSettingsTitle;

  /// Settings row subtitle for the iOS widget guide.
  ///
  /// In en, this message translates to:
  /// **'Add Prism to your Home Screen and Lock Screen'**
  String get widgetsSettingsSubtitle;

  /// Title of the sheet that teaches how to add Prism iOS widgets.
  ///
  /// In en, this message translates to:
  /// **'Add Prism widgets'**
  String get widgetsGuideTitle;

  /// Segment label for the Home Screen widget steps.
  ///
  /// In en, this message translates to:
  /// **'Home Screen'**
  String get widgetsGuideHomeTab;

  /// Segment label for the Lock Screen widget steps.
  ///
  /// In en, this message translates to:
  /// **'Lock Screen'**
  String get widgetsGuideLockTab;

  /// Step 1 to add a widget to the Home Screen.
  ///
  /// In en, this message translates to:
  /// **'Touch and hold an empty area of your Home Screen until the apps jiggle.'**
  String get widgetsGuideHomeStep1;

  /// Step 2 to add a widget to the Home Screen.
  ///
  /// In en, this message translates to:
  /// **'Tap Edit, then tap Add Widget.'**
  String get widgetsGuideHomeStep2;

  /// Step 3 to add a widget to the Home Screen.
  ///
  /// In en, this message translates to:
  /// **'Search for Prism, pick a size, then tap Add Widget.'**
  String get widgetsGuideHomeStep3;

  /// Step 1 to add a widget to the Lock Screen.
  ///
  /// In en, this message translates to:
  /// **'Touch and hold your Lock Screen, then tap Customize.'**
  String get widgetsGuideLockStep1;

  /// Step 2 to add a widget to the Lock Screen.
  ///
  /// In en, this message translates to:
  /// **'Tap Lock Screen, then tap the widget area under the clock.'**
  String get widgetsGuideLockStep2;

  /// Step 3 to add a widget to the Lock Screen.
  ///
  /// In en, this message translates to:
  /// **'Pick Prism, then tap a widget to add it.'**
  String get widgetsGuideLockStep3;

  /// Accessibility label for the Home Screen widget illustration.
  ///
  /// In en, this message translates to:
  /// **'A phone with the Wall of the Day widget on the Home Screen'**
  String get widgetsGuideHomeIllustration;

  /// Accessibility label for the Lock Screen widget illustration.
  ///
  /// In en, this message translates to:
  /// **'A phone with Prism widgets on the Lock Screen'**
  String get widgetsGuideLockIllustration;

  /// Button that closes the widget guide sheet.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get widgetsGuideDone;

  /// Title of the card on Wall of the Day that promotes the Home Screen widget.
  ///
  /// In en, this message translates to:
  /// **'Wall of the Day on your Home Screen'**
  String get widgetsCardTitle;

  /// Body of the card on Wall of the Day that promotes the Home Screen widget.
  ///
  /// In en, this message translates to:
  /// **'Add the widget and see a new wall every day.'**
  String get widgetsCardBody;

  /// Button on the Wall of the Day widget card that opens the widget guide.
  ///
  /// In en, this message translates to:
  /// **'Show me how'**
  String get widgetsCardAction;

  /// Tooltip and label for the button that dismisses the Wall of the Day widget card.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get widgetsCardDismiss;

  /// Heading for the user's folders of saved wallpapers in the Library.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get foldersTitle;

  /// Action and sheet title for saving a wallpaper into one or more of the user's folders.
  ///
  /// In en, this message translates to:
  /// **'Save to folder'**
  String get foldersSaveToFolder;

  /// Action on the toast shown after a wallpaper is favourited. Opens the folder picker.
  ///
  /// In en, this message translates to:
  /// **'Add to folder'**
  String get foldersAddToFolder;

  /// Label of the card, row and sheet that create a new folder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get foldersNewFolder;

  /// Hint in the text field for a folder name.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get foldersNameHint;

  /// Button that creates a folder with the typed name.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get foldersCreate;

  /// Tooltip of the icon button that adds the typed folder name.
  ///
  /// In en, this message translates to:
  /// **'Create folder'**
  String get foldersCreateFolder;

  /// Tag on a suggested folder name when the user has no folders yet.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get foldersSuggested;

  /// Tag on a folder row that is created when the user taps Done.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get foldersNewTag;

  /// Number of wallpapers in a folder.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No wallpapers} =1{1 wallpaper} other{{count} wallpapers}}'**
  String foldersItemCount(int count);

  /// Confirmation after saving a wallpaper to folders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved to 1 folder.} other{Saved to {count} folders.}}'**
  String foldersSavedToCount(int count);

  /// Confirmation after the user changes which folders hold a wallpaper without adding it to a new one.
  ///
  /// In en, this message translates to:
  /// **'Folders updated.'**
  String get foldersUpdated;

  /// Error after a folder save fails.
  ///
  /// In en, this message translates to:
  /// **'Could not save to folders. Try again.'**
  String get foldersSaveFailed;

  /// Error after a rename, delete or removal fails.
  ///
  /// In en, this message translates to:
  /// **'Could not update the folder. Try again.'**
  String get foldersUpdateFailed;

  /// Menu action that renames a folder.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get foldersRename;

  /// Title of the sheet that renames a folder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get foldersRenameTitle;

  /// Menu action that deletes a folder.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get foldersDelete;

  /// Title of the confirm before deleting a folder. name is the folder name the user typed.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String foldersDeleteTitle(String name);

  /// Message in the confirm before deleting a folder.
  ///
  /// In en, this message translates to:
  /// **'The wallpapers stay in your favourites.'**
  String get foldersDeleteMessage;

  /// Confirm button that deletes a folder.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get foldersDeleteConfirm;

  /// Confirmation after a folder is deleted.
  ///
  /// In en, this message translates to:
  /// **'Folder deleted.'**
  String get foldersDeleted;

  /// Title of the confirm before removing a wallpaper from a folder.
  ///
  /// In en, this message translates to:
  /// **'Remove from this folder?'**
  String get foldersRemoveTitle;

  /// Message in the confirm before removing a wallpaper from a folder.
  ///
  /// In en, this message translates to:
  /// **'It stays in your favourites.'**
  String get foldersRemoveMessage;

  /// Confirm button that removes a wallpaper from a folder.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get foldersRemoveConfirm;

  /// Confirmation after a wallpaper is removed from a folder.
  ///
  /// In en, this message translates to:
  /// **'Removed from the folder.'**
  String get foldersRemoved;

  /// Title of the empty state of a folder.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get foldersEmptyTitle;

  /// Body of the empty state of a folder.
  ///
  /// In en, this message translates to:
  /// **'Hold the heart on a wallpaper to save it here.'**
  String get foldersEmptyBody;

  /// Title of the error state of a folder.
  ///
  /// In en, this message translates to:
  /// **'Could not load this folder.'**
  String get foldersLoadError;

  /// Title when a folder link points to a folder that is gone or belongs to someone else.
  ///
  /// In en, this message translates to:
  /// **'This folder is not available'**
  String get foldersNotFoundTitle;

  /// Body when a folder link points to a folder that is gone.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted.'**
  String get foldersNotFoundBody;

  /// Feature name in the sign-in prompt, as in 'Sign in to use folders'.
  ///
  /// In en, this message translates to:
  /// **'folders'**
  String get foldersSignInFeature;

  /// Tooltip of the folder page overflow menu.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get foldersMoreOptions;

  /// Suggested folder name for wallpapers to use on the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get foldersSuggestionLockScreen;

  /// Suggested folder name for wallpapers to use on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get foldersSuggestionHomeScreen;

  /// Home mood name for soft, pastel wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Dreamy'**
  String get moodDreamyTitle;

  /// One line under the Dreamy mood title.
  ///
  /// In en, this message translates to:
  /// **'Soft skies and pastel light.'**
  String get moodDreamyBody;

  /// Home mood name for dark, calm wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Dark and quiet'**
  String get moodDarkQuietTitle;

  /// One line under the Dark and quiet mood title.
  ///
  /// In en, this message translates to:
  /// **'Low light, easy on the eyes.'**
  String get moodDarkQuietBody;

  /// Home mood name for saturated, colourful wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Bright and bold'**
  String get moodBrightBoldTitle;

  /// One line under the Bright and bold mood title.
  ///
  /// In en, this message translates to:
  /// **'Big colour to wake up your screen.'**
  String get moodBrightBoldBody;

  /// Home mood name for simple, uncluttered wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get moodMinimalTitle;

  /// One line under the Minimal mood title.
  ///
  /// In en, this message translates to:
  /// **'Simple shapes and room to breathe.'**
  String get moodMinimalBody;

  /// Home mood name for wallpapers that work as iOS 26 Spatial Scenes. Keep "Spatial" as Apple's feature name.
  ///
  /// In en, this message translates to:
  /// **'Spatial ready'**
  String get moodSpatialReadyTitle;

  /// One line under the Spatial ready mood title. "Spatial Scene" is Apple's iOS 26 feature name.
  ///
  /// In en, this message translates to:
  /// **'Made to pop as a Spatial Scene.'**
  String get moodSpatialReadyBody;

  /// Home mood name for wallpapers that work with the iOS Lock Screen Depth Effect.
  ///
  /// In en, this message translates to:
  /// **'Depth ready'**
  String get moodDepthReadyTitle;

  /// One line under the Depth ready mood title. Refers to the Lock Screen clock.
  ///
  /// In en, this message translates to:
  /// **'The subject steps in front of your clock.'**
  String get moodDepthReadyBody;

  /// Accessibility label for the row of mood chips on Home.
  ///
  /// In en, this message translates to:
  /// **'Moods'**
  String get moodChipRowLabel;

  /// Button on a Home mood row that opens the full mood page.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get moodSeeAll;

  /// Accessibility hint for the See all button. {mood} is a mood name such as Dreamy.
  ///
  /// In en, this message translates to:
  /// **'Opens all {mood} wallpapers'**
  String moodSeeAllHint(String mood);

  /// Error title on a mood page when the walls fail to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load these wallpapers'**
  String get moodLoadError;

  /// Empty state title on a mood page.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers here yet'**
  String get moodEmptyTitle;

  /// Empty state body on a mood page.
  ///
  /// In en, this message translates to:
  /// **'New wallpapers join every day.'**
  String get moodEmptyBody;

  /// Accessibility description for a wallpaper history tile.
  ///
  /// In en, this message translates to:
  /// **'{current}Set again. {target}, {date}'**
  String wallpaperHistoryTileSemantic(String current, String target, String date);

  /// Title of the wallpaper history screen.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper history'**
  String get wallpaperHistoryTitle;

  /// Description for the history introduction in the library.
  ///
  /// In en, this message translates to:
  /// **'The wallpapers you set, so you can set them again.'**
  String get wallpaperLibraryHistoryBody;

  /// Title for the history introduction in the library.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper history'**
  String get wallpaperLibraryHistoryTitle;

  /// Action to open wallpaper history.
  ///
  /// In en, this message translates to:
  /// **'Open history'**
  String get wallpaperLibraryOpenHistory;

  /// Section heading for recently set wallpapers.
  ///
  /// In en, this message translates to:
  /// **'Recently set'**
  String get wallpaperRecentlySet;

  /// Accessibility label to set a recently set wallpaper again.
  ///
  /// In en, this message translates to:
  /// **'Set this wallpaper again'**
  String get wallpaperSetAgain;

  /// Accessibility label for the favourites sort menu.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get wallpaperSort;

  /// Headline on each round of the This or that quiz, above two wallpapers side by side.
  ///
  /// In en, this message translates to:
  /// **'Pick the one you like more'**
  String get tasteQuizTitle;

  /// Small label above the quiz headline on rounds that show wallpapers from categories the user did not pick.
  ///
  /// In en, this message translates to:
  /// **'Wild card'**
  String get tasteQuizWildCard;

  /// Quiz progress, for example 1 of 6.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String tasteQuizProgress(int current, int total);

  /// Screen reader label for the quiz progress.
  ///
  /// In en, this message translates to:
  /// **'Round {current} of {total}'**
  String tasteQuizProgressLabel(int current, int total);

  /// Button that ends the This or that quiz early and continues.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tasteQuizSkip;

  /// Screen reader label for one of the two wallpapers in a quiz round.
  ///
  /// In en, this message translates to:
  /// **'Pick this wallpaper, {position} of {total}'**
  String tasteQuizPickLabel(int position, int total);

  /// Title of the short screen after the quiz that shows the wallpapers the feed will lead with.
  ///
  /// In en, this message translates to:
  /// **'Tuning your feed'**
  String get tasteQuizTuningTitle;

  /// One line that describes the user's picks. tone is dark or light, density is minimal or busy, and tag is a wallpaper tag such as neon, shown as stored.
  ///
  /// In en, this message translates to:
  /// **'{tone, select, dark{Dark} other{Light}}, {density, select, minimal{minimal} other{detailed}}, a bit of {tag}'**
  String tasteQuizSummaryFull(String tone, String density, String tag);

  /// One line that describes the user's picks. tone is dark or light, density is minimal or busy.
  ///
  /// In en, this message translates to:
  /// **'{tone, select, dark{Dark} other{Light}} and {density, select, minimal{minimal} other{detailed}}'**
  String tasteQuizSummaryToneDensity(String tone, String density);

  /// One line that describes the user's picks. tone is dark or light, and tag is a wallpaper tag such as neon, shown as stored.
  ///
  /// In en, this message translates to:
  /// **'{tone, select, dark{Dark} other{Light}}, with a bit of {tag}'**
  String tasteQuizSummaryToneTag(String tone, String tag);

  /// One line that describes the user's picks. density is minimal or busy, and tag is a wallpaper tag such as neon, shown as stored.
  ///
  /// In en, this message translates to:
  /// **'{density, select, minimal{Minimal} other{Detailed}}, with a bit of {tag}'**
  String tasteQuizSummaryDensityTag(String density, String tag);

  /// One line that describes the user's picks. tone is dark or light.
  ///
  /// In en, this message translates to:
  /// **'{tone, select, dark{Mostly dark walls} other{Mostly light walls}}'**
  String tasteQuizSummaryTone(String tone);

  /// One line that describes the user's picks. density is minimal or busy.
  ///
  /// In en, this message translates to:
  /// **'{density, select, minimal{Mostly minimal walls} other{Mostly detailed walls}}'**
  String tasteQuizSummaryDensity(String density);

  /// One line that describes the user's picks. tag is a wallpaper tag such as neon, shown as stored.
  ///
  /// In en, this message translates to:
  /// **'More {tag} walls'**
  String tasteQuizSummaryTag(String tag);

  /// Shown after the quiz when the picks do not clearly agree on a style.
  ///
  /// In en, this message translates to:
  /// **'Your feed is ready'**
  String get tasteQuizSummaryReady;

  /// Button in the Tune your feed sheet that runs the This or that quiz again. This or that is the quiz name.
  ///
  /// In en, this message translates to:
  /// **'Retake This or that'**
  String get tasteQuizRetake;

  /// Toast when the walls for a quiz retake do not load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load walls. Check your connection and try again.'**
  String get tasteQuizRetakeFailed;

  /// Label on a folder that others can see.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get foldersPublic;

  /// Folder menu action that lets others see the folder.
  ///
  /// In en, this message translates to:
  /// **'Make public'**
  String get foldersMakePublic;

  /// Folder menu action that hides the folder from others.
  ///
  /// In en, this message translates to:
  /// **'Make private'**
  String get foldersMakePrivate;

  /// Title of the dialog before a folder becomes public.
  ///
  /// In en, this message translates to:
  /// **'Make this folder public?'**
  String get foldersMakePublicTitle;

  /// One line that says what others see when a folder is public.
  ///
  /// In en, this message translates to:
  /// **'Anyone on Prism can see its name and wallpapers, follow it and open its link. Links you share keep their preview even if you make it private later.'**
  String get foldersMakePublicMessage;

  /// Title of the dialog before a public folder becomes private.
  ///
  /// In en, this message translates to:
  /// **'Make this folder private?'**
  String get foldersMakePrivateTitle;

  /// One line that says what happens when a public folder becomes private.
  ///
  /// In en, this message translates to:
  /// **'Only you will see it. Its link stops working and its followers lose it.'**
  String get foldersMakePrivateMessage;

  /// Toast after a folder becomes public.
  ///
  /// In en, this message translates to:
  /// **'This folder is now public.'**
  String get foldersMadePublic;

  /// Toast after a folder becomes private.
  ///
  /// In en, this message translates to:
  /// **'This folder is now private.'**
  String get foldersMadePrivate;

  /// Toast when the folder name cannot be shown to others.
  ///
  /// In en, this message translates to:
  /// **'Rename this folder to make it public.'**
  String get foldersPublicNameRefused;

  /// Toast when a moderator hid the folder.
  ///
  /// In en, this message translates to:
  /// **'This folder was hidden after reports, so it cannot be public.'**
  String get foldersHiddenRefused;

  /// Toast when the daily limit for folder changes is reached.
  ///
  /// In en, this message translates to:
  /// **'You changed folders too many times today. Try again tomorrow.'**
  String get foldersLimitRefused;

  /// Button that follows a public folder.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get foldersFollow;

  /// Button state when the user follows a public folder. Tap to unfollow.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get foldersFollowing;

  /// Number of people who follow a public folder.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No followers} =1{1 follower} other{{count} followers}}'**
  String foldersFollowerCount(int count);

  /// Owner line on a public folder page.
  ///
  /// In en, this message translates to:
  /// **'By {name}'**
  String foldersByOwner(String name);

  /// Action and tooltip that shares a public folder link.
  ///
  /// In en, this message translates to:
  /// **'Share folder'**
  String get foldersShare;

  /// Menu action that reports a public folder.
  ///
  /// In en, this message translates to:
  /// **'Report folder'**
  String get foldersReport;

  /// Title when a shared folder cannot be shown.
  ///
  /// In en, this message translates to:
  /// **'This folder is private or no longer exists'**
  String get foldersUnavailableTitle;

  /// Body when a shared folder cannot be shown.
  ///
  /// In en, this message translates to:
  /// **'The owner may have made it private or deleted it.'**
  String get foldersUnavailableBody;

  /// Toast when following or unfollowing a folder fails.
  ///
  /// In en, this message translates to:
  /// **'Could not update the follow. Try again.'**
  String get foldersFollowFailed;

  /// Heading of the public folders the user follows, in the Library.
  ///
  /// In en, this message translates to:
  /// **'Folders you follow'**
  String get foldersYouFollow;

  /// Title when a public folder has no wallpapers others can see.
  ///
  /// In en, this message translates to:
  /// **'No wallpapers here yet'**
  String get foldersPublicEmptyTitle;

  /// Body when a public folder has no wallpapers others can see.
  ///
  /// In en, this message translates to:
  /// **'New wallpapers show here when the owner adds them.'**
  String get foldersPublicEmptyBody;

  /// Notification setting for new wallpapers in followed folders.
  ///
  /// In en, this message translates to:
  /// **'Folders you follow'**
  String get notifSettingFolders;

  /// Description of the followed folders notification setting.
  ///
  /// In en, this message translates to:
  /// **'New wallpapers in folders you follow, once a day'**
  String get notifSettingFoldersDescription;

  /// Title of the daily push for new wallpapers in one followed folder.
  ///
  /// In en, this message translates to:
  /// **'New in {folderName}'**
  String notifPushFolderDigestTitleOne(String folderName);

  /// Title of the daily push for new wallpapers in several followed folders.
  ///
  /// In en, this message translates to:
  /// **'New in {folderName} and {count} more'**
  String notifPushFolderDigestTitleMore(String folderName, int count);

  /// History tab segment on Android: walls the user set as wallpaper or downloaded.
  ///
  /// In en, this message translates to:
  /// **'Set and downloaded'**
  String get historySetAndDownloaded;

  /// History tab segment on iOS, where the app cannot set wallpapers: walls the user downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get historyDownloaded;

  /// History tab segment: walls the user opened recently on this device.
  ///
  /// In en, this message translates to:
  /// **'Recently viewed'**
  String get historyRecentlyViewed;

  /// One line above the Set and downloaded list for a signed-in user.
  ///
  /// In en, this message translates to:
  /// **'Saved to your account, so these come back on a new phone.'**
  String get historySyncedNote;

  /// One line above the Set and downloaded list for a signed-out user.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep these on a new phone.'**
  String get historySyncedNoteGuest;

  /// Label under a history tile: the user set this wall as wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get historyActionSet;

  /// Label under a history tile: the user downloaded this wall.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get historyActionDownloaded;

  /// Screen reader label of a history tile from the account. action is Set or Downloaded, time is when.
  ///
  /// In en, this message translates to:
  /// **'{action} at {time}'**
  String historySyncedTileLabel(String action, String time);

  /// Body of the confirm dialog before clearing the Set and downloaded list.
  ///
  /// In en, this message translates to:
  /// **'This removes the list here and in your account. Your wallpapers and downloads stay as they are.'**
  String get historyClearSyncedBody;

  /// Title of the confirm dialog before clearing the recently viewed list.
  ///
  /// In en, this message translates to:
  /// **'Clear recently viewed?'**
  String get historyClearViewedTitle;

  /// Body of the confirm dialog before clearing the recently viewed list.
  ///
  /// In en, this message translates to:
  /// **'This removes the wallpapers you opened from this list and from Home.'**
  String get historyClearViewedBody;

  /// Confirm button that clears the recently viewed list.
  ///
  /// In en, this message translates to:
  /// **'Clear recently viewed'**
  String get historyClearViewedAction;

  /// Empty state body of the Set and downloaded list on Android.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers you set or download show up here, so you can find them again.'**
  String get historyEmptyBodyAndroid;

  /// Empty state body of the Downloaded list on iOS.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers you download show up here, so you can find them again.'**
  String get historyEmptyBodyIos;

  /// Empty state title of the recently viewed list.
  ///
  /// In en, this message translates to:
  /// **'Nothing viewed yet'**
  String get historyViewedEmptyTitle;

  /// Empty state body of the recently viewed list.
  ///
  /// In en, this message translates to:
  /// **'Wallpapers you open show up here, so you can find them again.'**
  String get historyViewedEmptyBody;

  /// Empty state title of the recently viewed list when the Save viewing history setting is off.
  ///
  /// In en, this message translates to:
  /// **'Viewing history is off'**
  String get historyViewedOffTitle;

  /// Empty state body of the recently viewed list when the setting is off.
  ///
  /// In en, this message translates to:
  /// **'Turn on Save viewing history to see the wallpapers you open here.'**
  String get historyViewedOffBody;

  /// Button in the recently viewed empty state that turns on the Save viewing history setting.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get historyViewedOffAction;

  /// Screen reader label of a recently viewed tile. time is when it was viewed.
  ///
  /// In en, this message translates to:
  /// **'Open wallpaper, viewed at {time}'**
  String historyViewedTileLabel(String time);

  /// Title of the Home row that shows walls the user opened recently but did not save, set or download.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off'**
  String get pickUpTitle;

  /// Screen reader label of a tile in the Pick up where you left off row.
  ///
  /// In en, this message translates to:
  /// **'Open wallpaper {index} of {count}'**
  String pickUpTileLabel(int index, int count);

  /// Settings switch. On: the app remembers the walls the user opens on this device.
  ///
  /// In en, this message translates to:
  /// **'Save viewing history'**
  String get settingsSaveViewingHistory;

  /// Subtitle of the Save viewing history switch.
  ///
  /// In en, this message translates to:
  /// **'Shows the wallpapers you open in History and on Home. Turning this off clears the list.'**
  String get settingsSaveViewingHistoryBody;

  /// Toast when Clear on the Set and downloaded list cannot reach the account. Nothing was cleared.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t clear history. Check your connection and try again.'**
  String get historyClearFailed;

  /// Auto-rotate source chip that rotates the walls of one of the user's folders.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get wallpaperAutoRotateSourceFolder;

  /// Auto-rotate source chip when a folder is chosen. folder is the folder name the user typed.
  ///
  /// In en, this message translates to:
  /// **'Folder: {folder}'**
  String wallpaperAutoRotateSourceFolderNamed(String folder);

  /// How the mix line names a folder source. folder is the folder name the user typed.
  ///
  /// In en, this message translates to:
  /// **'{folder}'**
  String wallpaperAutoRotateNounFolder(String folder);

  /// Shown when the chosen folder has fewer than 2 wallpapers that auto-rotate can use.
  ///
  /// In en, this message translates to:
  /// **'This folder needs at least 2 wallpapers that can rotate. Prism wallpapers rotate after you download them.'**
  String get wallpaperAutoRotateTooFewFolder;

  /// Button that opens the chosen folder from the auto-rotate screen.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get wallpaperAutoRotateOpenFolder;

  /// Title of the sheet that lists the user's folders for auto-rotate.
  ///
  /// In en, this message translates to:
  /// **'Pick a folder'**
  String get wallpaperAutoRotatePickFolder;

  /// Empty state of the auto-rotate folder picker.
  ///
  /// In en, this message translates to:
  /// **'You have no folders yet. Save a wallpaper to a folder, then pick it here.'**
  String get wallpaperAutoRotateNoFolders;

  /// Title of the card that asks the user to confirm a folder as the auto-rotate source. folder is the folder name the user typed.
  ///
  /// In en, this message translates to:
  /// **'Rotate {folder}?'**
  String wallpaperAutoRotateConfirmFolderTitle(String folder);

  /// Body of the card that asks the user to confirm a folder as the auto-rotate source.
  ///
  /// In en, this message translates to:
  /// **'Your wallpaper changes to one from this folder, on the schedule below.'**
  String get wallpaperAutoRotateConfirmFolderBody;

  /// Button that makes the folder the auto-rotate source and turns auto-rotate on.
  ///
  /// In en, this message translates to:
  /// **'Rotate this folder'**
  String get wallpaperAutoRotateConfirmFolderAction;

  /// Toast when auto-rotate stopped because its folder was deleted. folder is the folder name the user typed.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate is off because the folder {folder} was deleted.'**
  String wallpaperAutoRotateStoppedFolderDeleted(String folder);

  /// Toast when auto-rotate stopped because its folder has too few usable wallpapers. folder is the folder name the user typed.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate is off because the folder {folder} has fewer than 2 wallpapers.'**
  String wallpaperAutoRotateStoppedFolderEmpty(String folder);

  /// Folder page menu item that opens auto-rotate with this folder chosen. Android only.
  ///
  /// In en, this message translates to:
  /// **'Rotate this folder'**
  String get foldersRotateThisFolder;

  /// Small label on a folder page when auto-rotate uses this folder.
  ///
  /// In en, this message translates to:
  /// **'Rotating'**
  String get foldersRotating;

  /// Tooltip and screen reader label of the Rotating label on a folder page.
  ///
  /// In en, this message translates to:
  /// **'Auto-rotate uses this folder'**
  String get foldersRotatingDescription;

  /// Toast hint explaining how to reset the selected wallpaper accent.
  ///
  /// In en, this message translates to:
  /// **'Hold for actions, including Reset to original'**
  String get wallpaperAccentResetHint;

  /// Title of the wall requests page.
  ///
  /// In en, this message translates to:
  /// **'Wall requests'**
  String get wallRequestsTitle;

  /// Tab with the most upvoted open requests of the last 30 days.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get wallRequestsTabTop;

  /// Tab with the newest open requests.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get wallRequestsTabNew;

  /// Tab with requests that a wall filled.
  ///
  /// In en, this message translates to:
  /// **'Filled'**
  String get wallRequestsTabFilled;

  /// Button that opens the request sheet.
  ///
  /// In en, this message translates to:
  /// **'Request a wall'**
  String get wallRequestsAsk;

  /// Empty Top or New tab title.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get wallRequestsEmptyTopTitle;

  /// Empty Top or New tab body.
  ///
  /// In en, this message translates to:
  /// **'Ask for the wall you can\'t find. Others can upvote it.'**
  String get wallRequestsEmptyTopBody;

  /// Empty Filled tab title.
  ///
  /// In en, this message translates to:
  /// **'Nothing filled yet'**
  String get wallRequestsEmptyFilledTitle;

  /// Empty Filled tab body.
  ///
  /// In en, this message translates to:
  /// **'Filled requests show up here with the wall that answered them.'**
  String get wallRequestsEmptyFilledBody;

  /// Error state title on the requests page.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load requests'**
  String get wallRequestsLoadFailed;

  /// Retry button on the requests page.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get wallRequestsRetry;

  /// Vote count on a request row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No votes} =1{1 vote} other{{count} votes}}'**
  String wallRequestVotes(int count);

  /// Tooltip and label of the upvote button.
  ///
  /// In en, this message translates to:
  /// **'Upvote'**
  String get wallRequestUpvote;

  /// Tooltip of the upvote button when the user already upvoted.
  ///
  /// In en, this message translates to:
  /// **'Remove upvote'**
  String get wallRequestRemoveUpvote;

  /// Label on the user's own request row.
  ///
  /// In en, this message translates to:
  /// **'Your request'**
  String get wallRequestMine;

  /// Requester name when the profile has no name.
  ///
  /// In en, this message translates to:
  /// **'A Prism user'**
  String get wallRequestSomeone;

  /// Label on a filled request; name is the creator.
  ///
  /// In en, this message translates to:
  /// **'Filled by {name}'**
  String wallRequestFilledByCreator(String name);

  /// Label on a request that Prism Studio filled.
  ///
  /// In en, this message translates to:
  /// **'Made by Prism Studio'**
  String get wallRequestFilledByStudio;

  /// Semantics label of the filled wall thumbnail.
  ///
  /// In en, this message translates to:
  /// **'Open the wall'**
  String get wallRequestOpenWall;

  /// Tooltip of the row menu button.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get wallRequestMoreActions;

  /// Row menu action that reports a request.
  ///
  /// In en, this message translates to:
  /// **'Report request'**
  String get wallRequestReport;

  /// Admin row menu action that hides a request.
  ///
  /// In en, this message translates to:
  /// **'Hide request'**
  String get wallRequestHide;

  /// Admin row menu action that shows a hidden request again.
  ///
  /// In en, this message translates to:
  /// **'Show request'**
  String get wallRequestUnhide;

  /// Admin label on a hidden request.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get wallRequestHiddenLabel;

  /// Title of the request sheet.
  ///
  /// In en, this message translates to:
  /// **'Request a wall'**
  String get wallRequestSheetTitle;

  /// Hint in the request text field.
  ///
  /// In en, this message translates to:
  /// **'Describe it, like dark minimal mountains'**
  String get wallRequestSheetHint;

  /// Label above the tag chips in the request sheet.
  ///
  /// In en, this message translates to:
  /// **'Tags, up to 3'**
  String get wallRequestSheetTags;

  /// Submit button of the request sheet.
  ///
  /// In en, this message translates to:
  /// **'Request it'**
  String get wallRequestSheetSubmit;

  /// Shown in the sheet or a toast to a signed-out user.
  ///
  /// In en, this message translates to:
  /// **'Sign in to request walls and upvote them.'**
  String get wallRequestSignIn;

  /// Title when a close open request exists.
  ///
  /// In en, this message translates to:
  /// **'Someone asked for this already'**
  String get wallRequestDuplicateTitle;

  /// Body when a close open request exists.
  ///
  /// In en, this message translates to:
  /// **'Upvote it so creators see it sooner.'**
  String get wallRequestDuplicateBody;

  /// Button that upvotes the close request instead of making a new one.
  ///
  /// In en, this message translates to:
  /// **'Upvote this instead'**
  String get wallRequestUpvoteInstead;

  /// Button that makes a new request although a close one exists.
  ///
  /// In en, this message translates to:
  /// **'Request mine anyway'**
  String get wallRequestCreateAnyway;

  /// Title when the close request is the user's own.
  ///
  /// In en, this message translates to:
  /// **'You asked for this already'**
  String get wallRequestDuplicateMine;

  /// Title when the user already upvoted the close request.
  ///
  /// In en, this message translates to:
  /// **'You upvoted this already'**
  String get wallRequestDuplicateVoted;

  /// Button that goes back to the text field from the duplicate card.
  ///
  /// In en, this message translates to:
  /// **'Edit my request'**
  String get wallRequestEditText;

  /// Toast after a request is made.
  ///
  /// In en, this message translates to:
  /// **'Request sent. We\'ll tell you when it\'s filled.'**
  String get wallRequestCreated;

  /// Toast after the user upvotes the close request.
  ///
  /// In en, this message translates to:
  /// **'Upvoted. We\'ll tell you when it\'s filled.'**
  String get wallRequestUpvoted;

  /// Error when the server refuses the request text.
  ///
  /// In en, this message translates to:
  /// **'Use 3 to 80 characters, and keep it friendly.'**
  String get wallRequestErrorText;

  /// Error at the daily request limit.
  ///
  /// In en, this message translates to:
  /// **'You can make 3 requests a day. Try again tomorrow.'**
  String get wallRequestErrorLimit;

  /// Error when the user upvotes their own request.
  ///
  /// In en, this message translates to:
  /// **'You can\'t upvote your own request.'**
  String get wallRequestErrorOwn;

  /// Error when the user votes on a filled request.
  ///
  /// In en, this message translates to:
  /// **'This request is already filled.'**
  String get wallRequestErrorClosed;

  /// Error when the request is hidden or deleted.
  ///
  /// In en, this message translates to:
  /// **'This request isn\'t available anymore.'**
  String get wallRequestErrorGone;

  /// Error for any other failure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get wallRequestErrorGeneric;

  /// Line above the request button in an empty search.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find it?'**
  String get searchRequestPrompt;

  /// Button in an empty search that opens the request sheet with the query.
  ///
  /// In en, this message translates to:
  /// **'Request it'**
  String get searchRequestAction;

  /// Discover row that opens the requests page.
  ///
  /// In en, this message translates to:
  /// **'Wall requests'**
  String get discoverRequestsTitle;

  /// Subtitle of the Discover row for wall requests.
  ///
  /// In en, this message translates to:
  /// **'Ask for a wall, or upvote one'**
  String get discoverRequestsSubtitle;

  /// Upload form row that links the wall to a request.
  ///
  /// In en, this message translates to:
  /// **'Fills a request'**
  String get uploadFillsRequest;

  /// Subtitle of the upload row when no request is picked.
  ///
  /// In en, this message translates to:
  /// **'Optional. Pick the request this wall answers.'**
  String get uploadFillsRequestHint;

  /// Tooltip of the button that removes the picked request.
  ///
  /// In en, this message translates to:
  /// **'Remove request'**
  String get uploadFillsRequestClear;

  /// Title of the request picker in the upload flow.
  ///
  /// In en, this message translates to:
  /// **'Which request does it fill?'**
  String get requestPickerTitle;

  /// Hint of the search field in the request picker.
  ///
  /// In en, this message translates to:
  /// **'Search requests'**
  String get requestPickerSearch;

  /// Empty state of the request picker.
  ///
  /// In en, this message translates to:
  /// **'No open requests match'**
  String get requestPickerEmpty;

  /// Push and inbox title when a wall request is filled.
  ///
  /// In en, this message translates to:
  /// **'Your request is here'**
  String get notifPushWallRequestFilledTitle;

  /// Push and inbox body when a wall request is filled: the request text.
  ///
  /// In en, this message translates to:
  /// **'{requestText}'**
  String notifPushWallRequestFilledBody(String requestText);

  /// Age of a request made less than a minute ago.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get wallRequestAgeNow;

  /// Age of a request in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String wallRequestAgeMinutes(int count);

  /// Age of a request in hours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String wallRequestAgeHours(int count);

  /// Age of a request in days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String wallRequestAgeDays(int count);

  /// Age of a request in weeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week ago} other{{count} weeks ago}}'**
  String wallRequestAgeWeeks(int count);

  /// Error when an account younger than 10 days tries to request or vote.
  ///
  /// In en, this message translates to:
  /// **'Your account can request walls and vote once it\'s 10 days old.'**
  String get wallRequestErrorAccountAge;

  /// Admin review card label: the text of the request this wall says it fills.
  ///
  /// In en, this message translates to:
  /// **'Fills request'**
  String get adminFillsRequest;

  /// Short label of the button that opens the AI tab with this wallpaper's prompt.
  ///
  /// In en, this message translates to:
  /// **'Remix'**
  String get wallRemixAction;

  /// Tooltip of the Remix button on an AI wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Remix this wallpaper with AI'**
  String get wallRemixActionTooltip;

  /// Chip in the AI tab that names the wallpaper being remixed.
  ///
  /// In en, this message translates to:
  /// **'Remixing {title} by {creator}'**
  String wallRemixingChip(String title, String creator);

  /// Tooltip of the x on the remix chip. It removes the link to the original wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Remove remix link'**
  String get wallRemixDropLinkTooltip;

  /// Name used for a wallpaper that has no title, inside remix copy.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get wallRemixUntitled;

  /// Name used for a creator with no public name, inside remix copy.
  ///
  /// In en, this message translates to:
  /// **'a Prism creator'**
  String get wallRemixUnknownCreator;

  /// Heading of the row of remixes on a wallpaper's details.
  ///
  /// In en, this message translates to:
  /// **'Remixes'**
  String get wallRemixesTitle;

  /// Number of remixes next to the Remixes heading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 remix} other{{count} remixes}}'**
  String wallRemixesCount(int count);

  /// Screen reader label of one remix in the Remixes row.
  ///
  /// In en, this message translates to:
  /// **'Open remix by {creator}'**
  String wallRemixOpenRemixLabel(String creator);

  /// Credit row on a remix. It opens the original wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Remix of {title} by {creator}'**
  String wallRemixOfLabel(String title, String creator);

  /// Tooltip of the credit row on a remix.
  ///
  /// In en, this message translates to:
  /// **'Open the original wallpaper'**
  String get wallRemixOfTooltip;

  /// Note on the AI submit sheet. Shared AI wallpapers show their prompt to anyone who remixes them.
  ///
  /// In en, this message translates to:
  /// **'Anyone can see your prompt and remix this wallpaper.'**
  String get economyAiSubmitPromptNotice;

  /// Inbox title when another creator's remix of your wallpaper is approved.
  ///
  /// In en, this message translates to:
  /// **'Your wallpaper was remixed'**
  String get notifPushWallRemixedTitle;

  /// Inbox body when another creator remixes your wallpaper.
  ///
  /// In en, this message translates to:
  /// **'{remixerName} remixed {wallTitle}.'**
  String notifPushWallRemixedBody(String remixerName, String wallTitle);

  /// Inbox body when another creator remixes your untitled wallpaper.
  ///
  /// In en, this message translates to:
  /// **'{remixerName} remixed your wallpaper.'**
  String notifPushWallRemixedBodyUntitled(String remixerName);

  /// Intro text in the report a problem sheet.
  ///
  /// In en, this message translates to:
  /// **'Tell us what went wrong. Reports have no email address or sign-in tokens.'**
  String get reportSheetMessage;

  /// Report topic chip: app crashed or froze.
  ///
  /// In en, this message translates to:
  /// **'Crash/freeze'**
  String get reportTopicCrashFreeze;

  /// Report topic chip: wallpaper could not be set.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper won\'t set'**
  String get reportTopicWallpaperWontSet;

  /// Report topic chip: something looks visually broken.
  ///
  /// In en, this message translates to:
  /// **'Looks broken'**
  String get reportTopicLooksBroken;

  /// Report topic chip: app is slow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get reportTopicSlow;

  /// Report topic chip: any other problem.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportTopicOther;

  /// Hint text of the note field in the report sheet.
  ///
  /// In en, this message translates to:
  /// **'What happened? What did you expect?'**
  String get reportNoteHint;

  /// Title of the screenshot row in the report sheet.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get reportScreenshotTitle;

  /// Subtitle of the screenshot row when no screenshot is attached.
  ///
  /// In en, this message translates to:
  /// **'Show us what you see.'**
  String get reportScreenshotEmpty;

  /// Subtitle of the screenshot row when a screenshot is attached.
  ///
  /// In en, this message translates to:
  /// **'Tap to view. Check it before you send.'**
  String get reportScreenshotAttached;

  /// Button to add a screenshot to the report.
  ///
  /// In en, this message translates to:
  /// **'Add screenshot'**
  String get reportAddScreenshot;

  /// Button to remove the attached screenshot.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get reportRemoveScreenshot;

  /// Tooltip or label to view the attached screenshot.
  ///
  /// In en, this message translates to:
  /// **'View screenshot'**
  String get reportViewScreenshot;

  /// Switch label to include device info and recent logs in the report.
  ///
  /// In en, this message translates to:
  /// **'Include device info & recent logs'**
  String get reportIncludeDiagnostics;

  /// Button to expand the list of included diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Show what\'s included'**
  String get reportShowDiagnostics;

  /// Button to collapse the list of included diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get reportHideDiagnostics;

  /// Button that sends the report.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSend;

  /// Button that shares the report as a file.
  ///
  /// In en, this message translates to:
  /// **'Share as file'**
  String get reportShareAsFile;

  /// Confirmation after the report is sent, with a short reference code.
  ///
  /// In en, this message translates to:
  /// **'Thanks, report sent. Reference {reference}'**
  String reportSent(String reference);

  /// Title of the dialog shown when the report fails to send.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send'**
  String get reportCouldNotSend;

  /// Body of the dialog shown when the report fails to send.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again, or share the report as a file.'**
  String get reportCouldNotSendBody;

  /// Dialog action to share the report as a file after a send failure.
  ///
  /// In en, this message translates to:
  /// **'Share instead'**
  String get reportShareInstead;

  /// Settings toggle label for shake to report.
  ///
  /// In en, this message translates to:
  /// **'Shake to report'**
  String get reportShakeToReport;

  /// Settings toggle subtitle for shake to report.
  ///
  /// In en, this message translates to:
  /// **'Shake your phone on any screen to report a problem'**
  String get reportShakeToReportSubtitle;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en', 'es', 'hi', 'id', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
