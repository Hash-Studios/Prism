// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get foldersLibraryEmptyTitle => 'Noch keine Ordner';

  @override
  String get foldersLibraryEmptyBody =>
      'Halte das Herz bei einem Hintergrundbild gedrückt, um es in einem Ordner zu speichern.';

  @override
  String get foldersLoadAllError => 'Deine Ordner konnten nicht geladen werden';

  @override
  String get galleryEmptyBody => 'Sie wurden entfernt oder sind nicht mehr öffentlich.';

  @override
  String get galleryEmptyTitle => 'Diese Hintergrundbilder sind weg';

  @override
  String get galleryScreenTitle => 'Hintergrundbilder für dich';

  @override
  String wallpaperFavouriteSearchCountHint(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Favoriten durchsuchen',
      one: '1 Favorit durchsuchen',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteSortAndFilter => 'Sortieren und filtern';

  @override
  String get wallpaperFavouriteSortBy => 'Sortieren nach';

  @override
  String get wallpaperFavouriteFilterSource => 'Quelle';

  @override
  String get wallpaperHistorySetAgain => 'Erneut festlegen';

  @override
  String wallpaperHistoryTileLabel(String current, String target, String time) {
    return '$current$target, festgelegt um $time';
  }

  @override
  String get wallpaperProviderWallhaven => 'Wallhaven';

  @override
  String get economyExportFailedLabel => 'Export fehlgeschlagen';

  @override
  String get coreSignInCreatorSearchFeature => 'Suche nach Kreativen';

  @override
  String get debugLogExportSubject => 'Prism-Debugprotokolle';

  @override
  String get accountAbout => 'Über';

  @override
  String get accountAboutPrism => 'Über Prism';

  @override
  String get accountAccount => 'Konto';

  @override
  String get accountAccountDeletionSubscriptionWarning =>
      'Dein Store-Abonnement wird durch das Löschen deines Kontos nicht gekündigt. Es wird weiter abgerechnet, bis du es im Store kündigst.';

  @override
  String get accountAdPrivacyChoices => 'Datenschutzeinstellungen für Werbung';

  @override
  String get accountAddProfilePhoto => 'Profilbild hinzufügen';

  @override
  String get accountAddSocialLink => 'Social-Media-Link hinzufügen';

  @override
  String get accountAdmin => 'Admin';

  @override
  String get accountAdminModeration => 'Admin-Moderation';

  @override
  String accountAndroidSharePitch(String url) {
    return 'Entdecke Android-Personalisierung neu! Sieh dir Prism an –\n$url';
  }

  @override
  String get accountAnyResolution => 'Beliebig';

  @override
  String get accountAppName => 'Prism Wallpapers';

  @override
  String get accountAppearance => 'Erscheinungsbild';

  @override
  String get accountApply => 'Anwenden';

  @override
  String get accountAskEveryTime => 'Jedes Mal fragen';

  @override
  String get accountAudience => 'Zielgruppe';

  @override
  String get accountAutoRotateWallpapers => 'Hintergrundbilder automatisch wechseln';

  @override
  String get accountBlock => 'Blockieren';

  @override
  String get accountBlockActionFailed => 'Blockierte Konten konnten nicht aktualisiert werden.';

  @override
  String get accountBlockActionPendingSync =>
      'Deine Änderung ist auf diesem Gerät gespeichert und wird synchronisiert, sobald es möglich ist.';

  @override
  String get accountBlockConfirmationUserFallback => 'diese Person';

  @override
  String accountBlockThisUserTitle(String name) {
    return '$name blockieren?';
  }

  @override
  String get accountBlockUser => 'Person blockieren';

  @override
  String accountBlockUserMessage(String name) {
    return 'Du entfolgst $name, siehst keine Hintergrundbilder dieser Person mehr in Feeds und erhältst keine Benachrichtigungen über neue Beiträge.';
  }

  @override
  String get accountBlockedAccounts => 'Blockierte Konten';

  @override
  String get accountBlockedAccountsEmptyBody =>
      'Durch das Blockieren werden die Beiträge aus deinem Feed ausgeblendet. Dein öffentliches Profil und deine Hintergrundbilder kann die Person möglicherweise weiterhin sehen.';

  @override
  String get accountBlockedAccountsLoadError => 'Blockierte Konten konnten nicht geladen werden.';

  @override
  String get accountBlockedListUserFallback => 'Blockierte Person';

  @override
  String get accountBlockedProfileBody =>
      'Ihre Hintergrundbilder werden in deinen Feeds ausgeblendet und du erhältst keine Benachrichtigungen dazu. Du kannst die Person jederzeit wieder freigeben.';

  @override
  String get accountBringBackSubscription => 'Früheres Abonnement wieder aufnehmen';

  @override
  String get accountBrowseByCategory => 'Nach Kategorie stöbern';

  @override
  String get accountBrowseByColour => 'Nach Farbe stöbern';

  @override
  String get accountBuyPremium => 'Premium kaufen';

  @override
  String get accountCacheCleared => 'Cache geleert.';

  @override
  String accountCacheClearedBytes(String size) {
    return '$size geleert.';
  }

  @override
  String accountCachedImageSize(String size) {
    return '$size an zwischengespeicherten Bildern';
  }

  @override
  String get accountCancel => 'Abbrechen';

  @override
  String get accountCannotGiftThisAccount => 'Du kannst diesem Konto kein Geschenk senden.';

  @override
  String accountCategorySemanticLabel(String name) {
    return 'Kategorie, $name';
  }

  @override
  String get accountChangeAutomatically => 'Automatisch ändern';

  @override
  String get accountChangeCoverPhoto => 'Titelbild ändern';

  @override
  String get accountChangeOrCancelStore => 'Im Store ändern oder kündigen';

  @override
  String get accountChangePhoto => 'Foto ändern';

  @override
  String get accountChangeWallpaperOnTimer => 'Hintergrundbild nach Zeitplan wechseln';

  @override
  String get accountCheckConnectionTryAgain => 'Überprüfe deine Verbindung und versuche es erneut.';

  @override
  String get accountClear => 'Leeren';

  @override
  String get accountClearAllDownloads => 'Alle Downloads löschen';

  @override
  String get accountClearAllFavouritesQuestion => 'Alle Favoriten entfernen?';

  @override
  String get accountClearCache => 'Cache leeren';

  @override
  String get accountClearCacheConfirmMessage =>
      'Zwischengespeicherte Bilder werden entfernt. Bei Bedarf werden sie erneut geladen.';

  @override
  String accountClearCacheConfirmSizeMessage(String size) {
    return '$size an zwischengespeicherten Bildern werden entfernt. Bei Bedarf werden sie erneut geladen.';
  }

  @override
  String get accountClearCacheQuestion => 'Cache leeren?';

  @override
  String get accountClearCacheTitle => 'Cache leeren';

  @override
  String get accountClearCachedImages => 'Lokal zwischengespeicherte Bilder löschen';

  @override
  String get accountClearColour => 'Farbe zurücksetzen';

  @override
  String get accountClearDepthEffect => 'Tiefeneffekt zurücksetzen';

  @override
  String get accountClearSpatialScene => 'Räumlich zurücksetzen';

  @override
  String get accountClearFavouriteWallpapers => 'Favorisierte Hintergrundbilder entfernen';

  @override
  String get accountClearFavourites => 'Favoriten entfernen';

  @override
  String accountClearFavouritesCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favorisierte Hintergrundbilder werden',
      one: '1 favorisiertes Hintergrundbild wird',
    );
    return '$_temp0 aus deinem Konto entfernt. Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get accountClearFavouritesMessage =>
      'Alle deine favorisierten Hintergrundbilder werden aus deinem Konto entfernt. Das kann nicht rückgängig gemacht werden.';

  @override
  String get accountClearLearnedTaste => 'Erlernte Vorlieben löschen';

  @override
  String accountClearLearnedTasteCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Vorlieben',
      one: '1 Vorliebe',
    );
    return 'Prism vergisst $_temp0, die aus den von dir angesehenen und gespeicherten Inhalten gelernt wurden. Dein Feed richtet sich dann wieder nach deinen ausgewählten Interessen. Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get accountClearLearnedTasteQuestion => 'Erlernte Vorlieben löschen?';

  @override
  String get accountClearSearch => 'Suche löschen';

  @override
  String get accountColour => 'Farbe';

  @override
  String accountCommitCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Commits',
      one: '1 Commit',
      zero: 'Keine Commits',
    );
    return '$_temp0';
  }

  @override
  String get accountCompleteProfile => 'Profil vervollständigen';

  @override
  String get accountCompleteYourProfile => 'Vervollständige dein Profil';

  @override
  String get accountConnectionTryAgain => 'Überprüfe deine Verbindung und versuche es erneut.';

  @override
  String get accountContent => 'Inhalt';

  @override
  String get accountContributor => 'Mitwirkende Person';

  @override
  String accountContributorCommitCount(String login, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Commits',
      one: '1 Commit',
      zero: 'keine Commits',
    );
    return '$login, $_temp0';
  }

  @override
  String get accountCopy => 'Kopieren';

  @override
  String get accountCopyLink => 'Link kopieren';

  @override
  String get accountCouldNotBuildReport => 'Der Bericht konnte nicht erstellt werden. Versuche es erneut.';

  @override
  String get accountCouldNotClearFavourites =>
      'Favorisierte Hintergrundbilder konnten nicht entfernt werden. Versuche es erneut.';

  @override
  String get accountCouldNotClearLearnedTaste =>
      'Erlernte Vorlieben konnten nicht gelöscht werden. Versuche es erneut.';

  @override
  String get accountCouldNotCreateLink => 'Der Link konnte nicht erstellt werden. Versuche es erneut.';

  @override
  String get accountCouldNotDeleteDownloads => 'Downloads konnten nicht gelöscht werden. Versuche es erneut.';

  @override
  String accountCouldNotFollowPerson(String name) {
    return 'Du konntest $name nicht folgen. Versuche es erneut.';
  }

  @override
  String get accountCouldNotLoadFollowers => 'Follower konnten nicht geladen werden.';

  @override
  String get accountCouldNotLoadFollowing => 'Konten, denen du folgst, konnten nicht geladen werden.';

  @override
  String get accountCouldNotLoadTeam => 'Das Team konnte nicht geladen werden.';

  @override
  String get accountCouldNotLoadThisProfile => 'Dieses Profil konnte nicht geladen werden.';

  @override
  String get accountCouldNotLoadTrending => 'Trends konnten nicht geladen werden.';

  @override
  String get accountCouldNotLoadWallpapers => 'Hintergrundbilder konnten nicht geladen werden.';

  @override
  String accountCouldNotOpenAddress(String address) {
    return '$address konnte nicht geöffnet werden.';
  }

  @override
  String get accountCouldNotOpenLink => 'Der Link konnte nicht geöffnet werden. Versuche es erneut.';

  @override
  String get accountCouldNotOpenStore => 'Der Store konnte nicht geöffnet werden. Versuche es erneut.';

  @override
  String get accountCouldNotOpenThisLink => 'Dieser Link konnte nicht geöffnet werden.';

  @override
  String get accountCouldNotRefreshSearch =>
      'Die Suche konnte nicht aktualisiert werden. Ziehe zum erneuten Laden nach unten.';

  @override
  String get accountCouldNotRemoveSavedOffline =>
      'Offline gespeicherte Hintergrundbilder konnten nicht entfernt werden. Versuche es erneut.';

  @override
  String get accountCouldNotRestorePurchases => 'Käufe konnten nicht wiederhergestellt werden. Versuche es erneut.';

  @override
  String get accountCouldNotSearchCreators => 'Kreative konnten nicht gesucht werden.';

  @override
  String get accountCouldNotSearchRightNow => 'Die Suche ist gerade nicht möglich.';

  @override
  String get accountCouldNotSendGift => 'Das Geschenk konnte nicht gesendet werden. Versuche es erneut.';

  @override
  String get accountCouldNotShareReport => 'Der Bericht konnte nicht geteilt werden. Versuche es erneut.';

  @override
  String accountCouldNotUnfollowPerson(String name) {
    return 'Du konntest $name nicht entfolgen. Versuche es erneut.';
  }

  @override
  String get accountCreatorFallback => 'Prism-Creator';

  @override
  String get accountCreatorSearchEmptyBody => 'Prüfe die Schreibweise oder versuche einen anderen Namen.';

  @override
  String get accountCurrentSignedInAccountRequired => 'Bitte wähle das Konto aus, mit dem du gerade angemeldet bist.';

  @override
  String get accountDataSaver => 'Datensparmodus';

  @override
  String get accountDataSaverDescription =>
      'Spart mobile Daten. Hintergrundbilder werden als Vorschaubilder geöffnet, Feeds nicht vorab geladen und Karussells nicht automatisch abgespielt.';

  @override
  String get accountDatabaseUsageStats => 'Datenbanknutzung und Statistiken';

  @override
  String get accountDebugPanel => 'Debug-Bereich';

  @override
  String get accountDefaultActionForSet => 'Standardaktion für „Festlegen“';

  @override
  String get accountDeleteAccount => 'Konto löschen';

  @override
  String get accountDeleteAccountConfirmation =>
      'Dadurch wird dein Konto dauerhaft gelöscht, deine persönlichen Daten werden entfernt und du wirst abgemeldet.\n\nDeine hochgeladenen Hintergrundbilder bleiben als „Gelöschtes Konto“ sichtbar.\n\nDiese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get accountDeleteAccountReauthNote => 'Als Nächstes bestätigst du deine Identität mit Google oder Apple.';

  @override
  String get accountDeleteAll => 'Alles löschen';

  @override
  String get accountDeleteAllDownloadsQuestion => 'Alle Downloads löschen?';

  @override
  String accountDeleteDownloadsCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString heruntergeladene Hintergrundbilder werden',
      one: '1 heruntergeladenes Hintergrundbild wird',
    );
    return '$_temp0 aus „Downloads“ gelöscht. Offline gespeicherte Kopien sind davon nicht betroffen. Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get accountDeleteDownloadsMessage =>
      'Heruntergeladene Hintergrundbilder werden aus „Downloads“ gelöscht. Offline gespeicherte Kopien sind davon nicht betroffen. Das kann nicht rückgängig gemacht werden.';

  @override
  String get accountDeleteYourAccountQuestion => 'Dein Konto löschen?';

  @override
  String get accountDeletingYourAccount => 'Dein Konto wird gelöscht';

  @override
  String get accountDepthEffect => 'Tiefeneffekt';

  @override
  String get accountDepthEffectClockSemanticLabel => 'Tiefeneffekt, Motiv vor der Uhr';

  @override
  String get accountSpatialScene => 'Räumlich';

  @override
  String get accountSpatialSceneSubtitle => 'Walls mit klarer 3D-Tiefe';

  @override
  String get accountSpatialSceneSemanticLabel => 'Räumlich, Walls mit klarer 3D-Tiefe';

  @override
  String accountDownloadedWallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString heruntergeladene Hintergrundbilder; offline gespeicherte Kopien bleiben erhalten',
      one: '1 heruntergeladenes Hintergrundbild; offline gespeicherte Kopien bleiben erhalten',
      zero: 'Keine heruntergeladenen Hintergrundbilder; offline gespeicherte Kopien bleiben erhalten',
    );
    return '$_temp0';
  }

  @override
  String get accountDownloadsDeleted => 'Alle Downloads gelöscht.';

  @override
  String get accountEarnCoins => 'Coins verdienen';

  @override
  String accountEarnProfileCompletionCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Verdiene $coinsString Coins, wenn du dein Profil vervollständigst';
  }

  @override
  String get accountEditCover => 'Titelbild bearbeiten';

  @override
  String get accountEditProfile => 'Profil bearbeiten';

  @override
  String get accountExportFavourites => 'Favoriten exportieren';

  @override
  String get accountFavouritesCleared => 'Alle favorisierten Hintergrundbilder entfernt.';

  @override
  String get accountFeedback => 'FEEDBACK';

  @override
  String get accountFeedbackSubject => 'Prism-Feedback';

  @override
  String get accountFields => 'Felder';

  @override
  String get accountFilters => 'Filter';

  @override
  String get accountFindCreators => 'Kreative finden';

  @override
  String get accountFinishYourProfile => 'Vervollständige dein Profil';

  @override
  String get accountFirestoreTelemetry => 'Firestore-Telemetrie';

  @override
  String get accountFollow => 'Folgen';

  @override
  String accountFollowPerson(String name) {
    return '$name folgen';
  }

  @override
  String accountFollowedPerson(String name) {
    return 'Du folgst jetzt $name!';
  }

  @override
  String get accountFollowers => 'Follower';

  @override
  String accountFollowersCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Follower',
      one: '1 Follower',
      zero: 'Keine Follower',
    );
    return '$_temp0';
  }

  @override
  String accountFollowersCountLabel(String compactCount) {
    return '$compactCount Follower';
  }

  @override
  String get accountFollowersEmptyMessage => 'Hier erscheinen die Personen, die diesem Konto folgen.';

  @override
  String get accountFollowing => 'Folge ich';

  @override
  String accountFollowingCountLabel(String compactCount) {
    return '$compactCount gefolgt';
  }

  @override
  String get accountFollowingEmptyMessage => 'Hier erscheinen die Konten, denen du von hier aus folgst.';

  @override
  String get accountForgetFeedLearned => 'Vergiss, was dein Feed über dich gelernt hat';

  @override
  String get accountFromPrism => 'Von Prism';

  @override
  String get accountGiftLimitReached => 'Das Geschenklimit ist vorerst erreicht. Versuche es morgen erneut.';

  @override
  String accountGiftPassMessage(String recipientName, int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$recipientName erhält 24 Stunden lang Premium-Sammlungen und Premium-Hintergrundbilder. Kostet $priceString Coins.';
  }

  @override
  String get accountGiftPassTitle => '24-Stunden-Pro-Pass verschenken';

  @override
  String get accountGiftPassTooltip => '24-h-Pass verschenken';

  @override
  String get accountGiftsOpenAfterSevenDays => 'Geschenke sind verfügbar, sobald dein Konto 7 Tage alt ist.';

  @override
  String get accountHapticFeedback => 'Haptisches Feedback';

  @override
  String get accountHelp => 'Hilfe';

  @override
  String get accountHomeAndLockScreens => 'Start- und Sperrbildschirm';

  @override
  String get accountHomeScreen => 'Startbildschirm';

  @override
  String get accountInviteFriends => 'Freunde einladen';

  @override
  String get accountInviteLinkCouldNotCreate => 'Dein Einladungslink konnte nicht erstellt werden.';

  @override
  String accountInviteRewardHeadline(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Verschenke $coinsString, erhalte $coinsString';
  }

  @override
  String accountInviteRewardMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Dein Freund erhält $coinsString Coins, wenn er beitritt. Du erhältst ebenfalls $coinsString.';
  }

  @override
  String get accountInviteShareFailed => 'Die Einladung kann gerade nicht geteilt werden.';

  @override
  String accountIosSharePitch(String url) {
    return 'Entdecke die Personalisierung deines Smartphones neu! Sieh dir Prism an –\n$url';
  }

  @override
  String get accountLater => 'Später';

  @override
  String get accountLatest => 'Neueste';

  @override
  String get accountLearnedTasteCleared => 'Erlernte Vorlieben gelöscht.';

  @override
  String get accountLibrary => 'Mediathek';

  @override
  String get accountLightDarkAccentColour => 'Hell, dunkel und Akzentfarbe';

  @override
  String get accountLink => 'Link';

  @override
  String get accountLinkCopied => 'Link kopiert';

  @override
  String get accountLinkType => 'Linktyp';

  @override
  String get accountLinkTypeBehance => 'Behance';

  @override
  String get accountLinkTypeBioLink => 'bio.link';

  @override
  String get accountLinkTypeBuyMeACoffee => 'Buy Me a Coffee';

  @override
  String get accountLinkTypeCustom => 'Benutzerdefinierter Link';

  @override
  String get accountLinkTypeDeviantArt => 'DeviantArt';

  @override
  String get accountLinkTypeDribbble => 'Dribbble';

  @override
  String get accountLinkTypeEmail => 'E-Mail';

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
    return 'Linktyp, $name';
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
  String get accountLiveWallpapers => 'Live-Hintergrundbilder';

  @override
  String get accountLoadingTeam => 'Team wird geladen';

  @override
  String get accountLockScreen => 'Sperrbildschirm';

  @override
  String get accountLogOut => 'Abmelden';

  @override
  String get accountLogOutOfPrismQuestion => 'Von Prism abmelden?';

  @override
  String get accountLogOutQuestion => 'Abmelden?';

  @override
  String get accountLogoutConfirmation =>
      'Beim Abmelden werden der Verlauf und die auf diesem Gerät erlernten Vorlieben gelöscht. Favoriten, Coins und Profil bleiben mit deinem Konto verknüpft.';

  @override
  String get accountLogoutFailed => 'Abmeldung fehlgeschlagen. Versuche es erneut.';

  @override
  String get accountLogsNetworkToolsStorage => 'Protokolle, Netzwerk, Tools und Speicher';

  @override
  String get accountMadeWithLoveInIndia => 'Mit ❤ in Indien und Flutter entwickelt!';

  @override
  String get accountManageBlockedPeople => 'Blockierte Personen verwalten';

  @override
  String get accountManageSubscription => 'Abonnement verwalten';

  @override
  String get accountMenu => 'Menü';

  @override
  String get accountMinResolution => 'Mindestauflösung';

  @override
  String get accountMoreLinks => 'Weitere Links';

  @override
  String get accountMoreOptions => 'Weitere Optionen';

  @override
  String get accountMovingGradientsMotionVideo => 'Bewegte Farbverläufe, Animationen und Videos';

  @override
  String get accountMyAccent => 'Meine Akzentfarbe';

  @override
  String get accountNoBlockedAccounts => 'Keine blockierten Konten';

  @override
  String get accountNoContributors => 'Noch keine Mitwirkenden vorhanden.';

  @override
  String get accountNoCreatorsFound => 'Keine Kreativen gefunden';

  @override
  String get accountNoDownloadsToRemove => 'Du hast keine Downloads zu entfernen.';

  @override
  String get accountNoFollowersYet => 'Noch keine Follower';

  @override
  String get accountNoPurchasesToRestore => 'Für dieses Konto gibt es keine Käufe zum Wiederherstellen.';

  @override
  String get accountNoResults => 'Keine Ergebnisse';

  @override
  String accountNoWallpapersForFilters(String filters) {
    return 'Keine $filters-Hintergrundbilder gefunden';
  }

  @override
  String accountNoWallpapersForQueryWithFilters(String query) {
    return 'Keine Hintergrundbilder für $query mit den ausgewählten Filtern gefunden.';
  }

  @override
  String get accountNoWallpapersFound => 'Keine Hintergrundbilder gefunden';

  @override
  String accountNoWallpapersFoundForQuery(String query) {
    return 'Keine Hintergrundbilder für $query gefunden';
  }

  @override
  String get accountNoWallpapersYet => 'Noch keine Hintergrundbilder';

  @override
  String accountNobodyMatchesUsername(String query) {
    return 'Niemand entspricht „$query“. Versuche einen anderen Nutzernamen.';
  }

  @override
  String get accountNotEnoughCoinsEarnInRewards => 'Nicht genug Coins. Verdiene Coins bei „Belohnungen“.';

  @override
  String get accountNotFollowingAnyoneYet => 'Du folgst noch niemandem';

  @override
  String get accountNotSynced => 'Nicht synchronisiert';

  @override
  String get accountNothingLearnedYet => 'Prism hat noch nichts gelernt.';

  @override
  String get accountNotificationPreferences => 'Benachrichtigungseinstellungen';

  @override
  String get accountNotificationTypes => 'Hintergrundbild des Tages, Follower, Beiträge und mehr';

  @override
  String get accountNotifications => 'Benachrichtigungen';

  @override
  String get accountOpenYourProfile => 'Dein Profil öffnen';

  @override
  String get accountOpeningProfileEditor => 'Profilbearbeitung wird geöffnet';

  @override
  String get accountOpens => 'Öffnungen';

  @override
  String get accountOtherContributors => 'Weitere Mitwirkende';

  @override
  String accountPassSentToPerson(String name) {
    return 'Pass an $name gesendet.';
  }

  @override
  String accountPersonAlreadyHasPro(String name) {
    return '$name hat bereits Pro.';
  }

  @override
  String get accountPersonalise => 'Personalisieren';

  @override
  String get accountPortraitOnly => 'Nur Hochformat';

  @override
  String get accountPremiumBenefitsActive =>
      'Du hast Zugriff auf alle Premium-Hintergrundbilder, kostenlose Downloads und kostenlose Filter.';

  @override
  String get accountPremiumBenefitsInactive =>
      'Schalte Premium-Hintergrundbilder, kostenlose Downloads und kostenlose Filter frei.';

  @override
  String get accountPreview => 'Vorschau';

  @override
  String get accountPrismListPrivacySubtitle => 'So geht Prism mit deinen Daten um';

  @override
  String get accountPrismPro => 'Prism Pro';

  @override
  String get accountPrivacyAction => 'DATENSCHUTZ';

  @override
  String get accountPrivacyAndData => 'Datenschutz und Daten';

  @override
  String get accountPrivacyPolicy => 'Datenschutzerklärung';

  @override
  String get accountProBadge => 'Pro';

  @override
  String get accountProWallpaperSemantics => 'Pro-Hintergrundbild';

  @override
  String get accountProblemReportSharePrompt =>
      'Beschreibe bitte, was schiefgelaufen ist. Die Berichtdatei enthält die Details.';

  @override
  String get accountProblemReportShareSubject => 'Prism-Fehlerbericht';

  @override
  String get accountProfile => 'Profil';

  @override
  String get accountProfileNotAvailable => 'Profil nicht verfügbar';

  @override
  String get accountProfileNotAvailableBody =>
      'Diese Person verwendet keine aktuelle Version von Prism. Daher kann ihr Profil nicht angezeigt werden.';

  @override
  String accountProfileNudgeMessage(int percent, int coins) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Dein Profil ist zu $percentString% vollständig. Vervollständige es und verdiene $coinsString Prism Coins.';
  }

  @override
  String accountProfilePercentComplete(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Profil zu $percentString% vollständig';
  }

  @override
  String accountProfilePersonSemantics(String name, String username) {
    return '$name, @$username';
  }

  @override
  String get accountProfiles => 'Profile';

  @override
  String get accountPurchases => 'Käufe';

  @override
  String get accountPurchasesRestored => 'Käufe wiederhergestellt.';

  @override
  String get accountPurchasesRestoredPending =>
      'Käufe wiederhergestellt. Es kann eine Minute dauern, bis Pro freigeschaltet wird.';

  @override
  String get accountQuickTiles => 'Schnelleinstellungen';

  @override
  String get accountRateApp => 'BEWERTEN';

  @override
  String get accountRecentSearches => 'Letzte Suchanfragen';

  @override
  String get accountRelevance => 'Relevanz';

  @override
  String get accountRemoveAllFavouriteWallpapers => 'Alle favorisierten Hintergrundbilder entfernen';

  @override
  String get accountRemoveCoverPhoto => 'Titelbild entfernen';

  @override
  String get accountRemoveFilesDownloadsOfflineStay =>
      'Dateien aus „Downloads“ entfernen; offline gespeicherte Kopien bleiben erhalten';

  @override
  String get accountRemoveLink => 'Link entfernen';

  @override
  String get accountRemovePhoto => 'Foto entfernen';

  @override
  String get accountRemoveSavedOffline => 'Offline gespeicherte Inhalte entfernen';

  @override
  String accountRemoveSavedOfflineCountMessage(String size) {
    return '$size der offline gespeicherten Originale werden entfernt. Downloads, Entwürfe und Katalogdaten bleiben unverändert.';
  }

  @override
  String get accountRemoveSavedOfflineMessage =>
      'Offline gespeicherte Originale von diesem Gerät entfernen. Downloads, Entwürfe und Katalogdaten bleiben unverändert.';

  @override
  String get accountRemoveSavedOfflineQuestion => 'Offline gespeicherte Hintergrundbilder entfernen?';

  @override
  String get accountReportAProblem => 'Problem melden';

  @override
  String accountReportPreviewNotice(String email) {
    return 'Dieser Bericht enthält deine App-Version, dein Gerät und aktuelle Protokolle. Er enthält weder deine E-Mail-Adresse noch Anmeldetokens. Lies ihn durch und teile ihn anschließend mit $email.';
  }

  @override
  String get accountReportProblemSubtitle => 'Teile deine App-Protokolle mit dem Prism-Team';

  @override
  String get accountReportUser => 'Person melden';

  @override
  String get accountReset => 'Zurücksetzen';

  @override
  String get accountResetFilters => 'Filter zurücksetzen';

  @override
  String get accountResolution1080 => '1080p';

  @override
  String get accountResolution1440 => '1440p';

  @override
  String get accountResolution4k => '4K';

  @override
  String get accountRestorePurchases => 'Käufe wiederherstellen';

  @override
  String get accountRestoringPurchases => 'Käufe werden wiederhergestellt…';

  @override
  String accountResultsForQuery(String query) {
    return 'Ergebnisse für $query';
  }

  @override
  String get accountRetry => 'Erneut versuchen';

  @override
  String get accountReviewOrChangeAdConsent => 'Deine Werbeeinwilligung ansehen oder ändern';

  @override
  String get accountReviewStatus => 'Prüfstatus';

  @override
  String get accountReviewSubmittedContent => 'Eingereichte Inhalte prüfen';

  @override
  String get accountSaveFavouritesAsFile => 'Kopie deiner Favoriten als Datei speichern';

  @override
  String get accountSavedOffline => 'Offline gespeichert';

  @override
  String get accountSavedOfflineRemoved => 'Offline gespeicherte Hintergrundbilder entfernt.';

  @override
  String accountSavedOfflineStorageUnavailable(int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'Speicher nicht verfügbar · Limit: $limitString MiB';
  }

  @override
  String accountSavedOfflineStorageUsed(String size, int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$size belegt · Limit: $limitString MiB';
  }

  @override
  String get accountSavedOnThisDevice => 'Auf diesem Gerät gespeichert';

  @override
  String get accountSearch => 'Suchen';

  @override
  String get accountSearchByUsername => 'Nach Nutzername suchen';

  @override
  String get accountSearchCreators => 'Kreative suchen';

  @override
  String get accountSearchCreatorsByName => 'Kreative nach Namen suchen';

  @override
  String get accountSearchFilters => 'Filter';

  @override
  String get accountSearchPrismUsersByName => 'Prism-Nutzer nach Namen suchen';

  @override
  String get accountSearchWallpapers => 'Hintergrundbilder suchen';

  @override
  String get accountSeeChangelog => 'Änderungsprotokoll ansehen';

  @override
  String get accountSendGift => 'Geschenk senden';

  @override
  String get accountSendProfileLink => 'Link zu deinem Prism-Profil senden';

  @override
  String get accountSetUpQuickTiles => 'Schnelleinstellungen einrichten';

  @override
  String get accountSetUsername => 'Nutzernamen festlegen';

  @override
  String get accountSettings => 'Einstellungen';

  @override
  String get accountShare => 'Teilen';

  @override
  String get accountShareInvite => 'Einladung teilen';

  @override
  String get accountSharePrism => 'Prism teilen';

  @override
  String get accountSharePrismFriendSubtitle => 'Einem Freund einen Link senden';

  @override
  String get accountShareProfile => 'Profil teilen';

  @override
  String get accountShareProfileLinkFailed => 'Der Link konnte nicht erstellt werden. Versuche es erneut.';

  @override
  String get accountShareYourProfile => 'Teile dein Profil';

  @override
  String get accountShop => 'Shop';

  @override
  String get accountShowAnimeWallpapers => 'Anime-Hintergrundbilder anzeigen';

  @override
  String get accountShowSketchyWallpapers => 'Freizügige Hintergrundbilder anzeigen';

  @override
  String get accountSignIn => 'Anmelden';

  @override
  String get accountSignInAgainToDelete =>
      'Melde dich bitte ab und wieder an. Versuche anschließend erneut, dein Konto zu löschen.';

  @override
  String get accountSignInBenefits => 'Melde dich an, damit deine Favoriten, Coins und dein Profil erhalten bleiben.';

  @override
  String get accountSignInForInviteLink => 'Melde dich an, um deinen Einladungslink zu erhalten.';

  @override
  String get accountSignInToPrism => 'Bei Prism anmelden';

  @override
  String get accountSocialGithub => 'GITHUB';

  @override
  String get accountSocialInstagram => 'INSTAGRAM';

  @override
  String get accountSocialTelegram => 'TELEGRAM';

  @override
  String get accountSocialTwitter => 'TWITTER';

  @override
  String get accountSomethingWentWrongTryAgain => 'Etwas ist schiefgelaufen. Versuche es erneut.';

  @override
  String get accountSort => 'Sortieren';

  @override
  String get accountStorage => 'Speicher';

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
  String get accountSubjectCanSitInFrontOfClock => 'Motiv kann vor der Uhr liegen';

  @override
  String get accountSubjectInFrontOfClock => 'Motiv vor der Uhr';

  @override
  String get accountTerms => 'Bedingungen';

  @override
  String get accountTermsAction => 'BEDINGUNGEN';

  @override
  String accountTermsAgreementSemanticLabel(String terms, String privacy) {
    return 'Wenn du fortfährst, stimmst du $terms und $privacy zu';
  }

  @override
  String get accountTermsOfUse => 'Nutzungsbedingungen';

  @override
  String get accountTheTeam => 'Das Team';

  @override
  String get accountThemes => 'Designs';

  @override
  String get accountThemesIconsFrames => 'Designs, Symbole, Rahmen';

  @override
  String get accountThisUser => 'diese Person';

  @override
  String get accountTop => 'Top';

  @override
  String get accountTrackSubmittedWallpapers => 'Verfolge deine eingereichten Hintergrundbilder';

  @override
  String get accountTrendingNow => 'Gerade im Trend';

  @override
  String get accountTryAgain => 'Erneut versuchen';

  @override
  String get accountTryFewerFilters => 'Versuche es mit weniger Filtern.';

  @override
  String get accountTryShorterOrDifferentWord => 'Versuche ein kürzeres oder anderes Wort.';

  @override
  String get accountUnblock => 'Blockierung aufheben';

  @override
  String get accountUnblockUserMessage => 'Ihre Beiträge erscheinen wieder in deinem Feed.';

  @override
  String accountUnblockUserTitle(String name) {
    return 'Blockierung für $name aufheben?';
  }

  @override
  String get accountUnfollow => 'Entfolgen';

  @override
  String accountUnfollowPerson(String name) {
    return '$name entfolgen';
  }

  @override
  String accountUnfollowedPerson(String name) {
    return 'Du folgst $name nicht mehr!';
  }

  @override
  String get accountUnlimitedUploadsFilters => 'Unbegrenzte Uploads und Filter';

  @override
  String get accountUploadFirstWallpaper => 'Lade dein erstes Hintergrundbild hoch, um deine Galerie zu starten.';

  @override
  String get accountUseShortcutsAutomation => 'Eine Kurzbefehle-Automation verwenden';

  @override
  String accountUserBlocked(String name) {
    return '$name blockiert';
  }

  @override
  String get accountUserUnblocked => 'Blockierung aufgehoben';

  @override
  String accountVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get accountVibrateOnTapsAndActions => 'Bei Tippen und Aktionen vibrieren';

  @override
  String get accountWaitingToSync => 'Warten auf Synchronisierung';

  @override
  String get accountWallpaperHistory => 'Verlauf der Hintergrundbilder';

  @override
  String get accountWallpaperManagerTagline => 'Ein vielseitiger Manager für Hintergrundbilder.';

  @override
  String get accountWallpaperSourceNames => 'Prism verwendet Wallhaven und Pexels für Hintergrundbilder.';

  @override
  String get accountWallpaperSources => 'Quellen für Hintergrundbilder';

  @override
  String get accountWallpaperSourcesMessage => 'Prism nutzt diese Dienste, um dir Hintergrundbilder bereitzustellen.';

  @override
  String get accountWallpapersSetBefore => 'Früher festgelegte Hintergrundbilder';

  @override
  String get accountWhatsNew => 'Neuigkeiten';

  @override
  String get accountWhatsNewAction => 'NEUIGKEITEN';

  @override
  String get accountWriteBio => 'Biografie schreiben';

  @override
  String accountYouBlockedUser(String name) {
    return 'Du hast $name blockiert';
  }

  @override
  String get accountYourContent => 'Deine Inhalte';

  @override
  String get accountYourProfile => 'dein Profil';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionClose => 'Schließen';

  @override
  String get actionDone => 'Fertig';

  @override
  String get actionRetry => 'Erneut versuchen';

  @override
  String get adminAllCaughtUp => 'Alles erledigt';

  @override
  String get adminAllUsers => 'Alle Nutzer';

  @override
  String get adminAnnouncementInbox => 'Ankündigung (Posteingang)';

  @override
  String get adminAnonymous => 'Anonym';

  @override
  String get adminApprovalFailed => 'Freigabe fehlgeschlagen. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get adminApprove => 'Freigeben';

  @override
  String get adminApproved => 'Freigegeben';

  @override
  String get adminBackToReviewList => 'Zurück zur Prüfliste';

  @override
  String get adminBatchActionFailed => 'Diese Prüfaktion konnte nicht abgeschlossen werden. Versuch es erneut.';

  @override
  String get adminBatchComplete => 'Stapel abgeschlossen';

  @override
  String get adminBodyLabel => 'Text';

  @override
  String get adminBodyRequired => 'Der Text ist erforderlich';

  @override
  String get adminBy => 'Von';

  @override
  String get adminByCollection => 'Nach Sammlung';

  @override
  String get adminByOperation => 'Nach Vorgang';

  @override
  String get adminBySourceTop15 => 'Nach Quelle (Top 15)';

  @override
  String get adminCancel => 'Abbrechen';

  @override
  String get adminChangeDepthEffect => 'Tiefeneffekt ändern';

  @override
  String get adminCheckConnectionRetry => 'Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get adminClose => 'Schließen';

  @override
  String adminContentTypeReport(String type) {
    return '$type-Meldung';
  }

  @override
  String get adminCopyAllData => 'Alle Daten kopieren';

  @override
  String get adminCouldNotLoadWallpaper => 'Hintergrundbild konnte nicht geladen werden';

  @override
  String get adminCreatorWillSeeFeedback => 'Der Creator sieht dieses Feedback.';

  @override
  String get adminDepth => 'Tiefe';

  @override
  String adminDepthTier(String tier) {
    return 'Tiefe: $tier';
  }

  @override
  String get adminDepthTierAuto => 'Automatisch';

  @override
  String get adminDepthTierMenu => 'Menü';

  @override
  String get adminDepthTierNone => 'Keine';

  @override
  String get adminDepthTierNotChecked => 'Nicht geprüft';

  @override
  String get adminDrop => 'Drop';

  @override
  String get adminEmail => 'E-Mail';

  @override
  String get adminEmailExample => 'user@example.com';

  @override
  String get adminEmailRequired => 'E-Mail ist erforderlich';

  @override
  String get adminEstimatedDocumentReads => 'Geschätzte Dokumentaufrufe';

  @override
  String get adminEstimatedDocumentWrites => 'Geschätzte Dokumentänderungen';

  @override
  String adminFactLabel(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminFirestoreTelemetry => 'Firestore-Telemetrie';

  @override
  String get adminFollowersScreen => 'Follower-Ansicht';

  @override
  String get adminFreeUsers => 'Kostenlose Nutzer';

  @override
  String get adminGeneral => 'Allgemein';

  @override
  String get adminImageUrlOptional => 'Bild-URL (optional)';

  @override
  String get adminKeepWallpaper => 'Hintergrundbild behalten';

  @override
  String get adminLast14Days => 'Letzte 14 Tage';

  @override
  String get adminList => 'Liste';

  @override
  String get adminLoadNextBatch => 'Nächsten Stapel laden';

  @override
  String get adminLoadingNotificationCounts => 'Benachrichtigungszahlen werden geladen.';

  @override
  String get adminMarkReviewed => 'Als geprüft markieren';

  @override
  String get adminMarkReviewedFailed => 'Die Meldung konnte nicht als geprüft markiert werden. Versuch es erneut.';

  @override
  String get adminMarkedReviewed => 'Als geprüft markiert';

  @override
  String adminModerationDuplicate(int percent) {
    return 'Sieht aus wie ein Prism-Hintergrund · $percent%';
  }

  @override
  String get adminModerationHint => 'Das sind nur Hinweise. Prüf es, bevor du ablehnst.';

  @override
  String adminModerationLogo(String logo) {
    return 'Logo: $logo';
  }

  @override
  String get adminModerationLogos => 'Logos';

  @override
  String get adminModerationOpenFailed => 'Die Seite konnte nicht geöffnet werden.';

  @override
  String adminModerationOpenPage(String host) {
    return '$host öffnen';
  }

  @override
  String get adminModerationSignals => 'Prüfhinweise';

  @override
  String get adminModerationSimilarWall => 'Ähnlicher Prism-Hintergrund';

  @override
  String adminModerationSimilarity(int percent) {
    return '$percent% ähnlich';
  }

  @override
  String adminModerationText(String words) {
    return 'Text: $words';
  }

  @override
  String get adminModerationTextInImage => 'Text im Bild';

  @override
  String adminModerationUnsafe(String categories) {
    return 'Nicht sicher: $categories';
  }

  @override
  String get adminModerationUnsafeCategories => 'Nicht sichere Kategorien';

  @override
  String adminModerationWeb(String host) {
    return 'Gefunden auf $host';
  }

  @override
  String adminModerationWebMore(String host, int more) {
    return 'Gefunden auf $host +$more';
  }

  @override
  String get adminModerationWebPages => 'Im Web gefunden';

  @override
  String get adminNewWallpapersPending => 'Neue Hintergrundbilder erscheinen hier, sobald jemand eines hochlädt.';

  @override
  String get adminNoNotificationCounts => 'Noch keine Benachrichtigungszahlen.';

  @override
  String get adminNoOpenReports => 'Keine offenen Meldungen';

  @override
  String get adminNoReasonGiven => 'Kein Grund angegeben';

  @override
  String get adminNoTelemetryData => 'Keine Telemetriedaten zum Kopieren';

  @override
  String get adminNoTelemetryYet => 'Noch keine Telemetrie';

  @override
  String get adminNoWallpapersPending => 'Keine Hintergrundbilder zur Prüfung.';

  @override
  String get adminNothingToReview => 'Nichts zu prüfen';

  @override
  String get adminNotificationCountExplanation =>
      '„Angenommen“ bedeutet, dass Firebase den Push übernommen hat. Ein Push an das Kontothema und das Gerätetoken zählt doppelt. Das bedeutet nicht, dass er angesehen wurde.';

  @override
  String get adminNotificationCountsLoadError => 'Benachrichtigungszahlen konnten nicht geladen werden.';

  @override
  String get adminNotificationIrreversible =>
      'Diese Benachrichtigung wird an alle in dieser Gruppe gesendet. Du kannst das nicht rückgängig machen.';

  @override
  String get adminNotificationQueueFailed => 'Die Benachrichtigung konnte nicht vorgemerkt werden. Versuch es erneut.';

  @override
  String get adminNotificationQueued => 'Benachrichtigung vorgemerkt. Die Cloud Function sendet sie in Kürze.';

  @override
  String get adminNotifications => 'Benachrichtigungen';

  @override
  String get adminOpenReportsLoadError => 'Offene Meldungen konnten nicht geladen werden.';

  @override
  String get adminOpenWallpaper => 'Hintergrundbild öffnen';

  @override
  String adminOperationCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Vorgänge',
      one: '$countString Vorgang',
    );
    return '$_temp0';
  }

  @override
  String get adminPendingWallsLoadError => 'Ausstehende Hintergrundbilder konnten nicht geladen werden.';

  @override
  String get adminPremiumUsers => 'Premium-Nutzer';

  @override
  String adminReadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Lesezugriffe',
      one: '$countString Lesezugriff',
    );
    return '$_temp0';
  }

  @override
  String get adminReasonBlurry => 'Unscharf';

  @override
  String get adminReasonBlurryBody => 'Das Bild ist unscharf oder stark komprimiert. Lade eine schärfere Version hoch.';

  @override
  String get adminReasonCopyright => 'Urheberrecht';

  @override
  String get adminReasonCopyrightBody =>
      'Dieses Bild könnte jemand anderem gehören. Lade nur Hintergrundbilder hoch, die du selbst erstellt hast oder für die du die Rechte besitzt.';

  @override
  String get adminReasonDuplicate => 'Duplikat';

  @override
  String get adminReasonDuplicateBody => 'Dieses Hintergrundbild ist bereits auf Prism vorhanden.';

  @override
  String get adminReasonHint => 'Erkläre, was geändert werden muss';

  @override
  String get adminReasonLabel => 'Grund';

  @override
  String get adminReasonLowResolution => 'Niedrige Auflösung';

  @override
  String get adminReasonLowResolutionBody =>
      'Die Auflösung ist zu niedrig. Lade ein Bild mit mindestens 1080 px an der kurzen Seite hoch.';

  @override
  String get adminReasonNotWallpaper => 'Kein Hintergrundbild';

  @override
  String get adminReasonNotWallpaperBody =>
      'Dieses Bild eignet sich nicht als Handy-Hintergrundbild. Verwende ein Hochformat, das den Bildschirm ausfüllt.';

  @override
  String get adminReasonOther => 'Sonstiges';

  @override
  String get adminReasonWatermark => 'Wasserzeichen';

  @override
  String get adminReasonWatermarkBody =>
      'Das Bild enthält ein Wasserzeichen. Lade eine Version ohne Wasserzeichen hoch.';

  @override
  String get adminRefresh => 'Aktualisieren';

  @override
  String get adminReject => 'Ablehnen';

  @override
  String get adminRejectReasonRequired => 'Gib einen Grund ein, bevor du diesen Eintrag ablehnst.';

  @override
  String get adminRejectSaveFailed =>
      'Diese Entscheidung konnte nicht gespeichert werden. Dein Grund ist noch vorhanden. Versuch es erneut.';

  @override
  String get adminRejectWallpaper => 'Hintergrundbild ablehnen';

  @override
  String get adminRemove => 'Entfernen';

  @override
  String get adminRemoveWallpaper => 'Hintergrundbild entfernen';

  @override
  String get adminRemovedFromNextDrop => 'Aus dem nächsten Drop entfernt';

  @override
  String get adminReportDismissFailed => 'Die Meldung konnte nicht verworfen werden. Versuch es erneut.';

  @override
  String get adminReportDismissedKept => 'Meldung verworfen. Hintergrundbild behalten.';

  @override
  String get adminReported => 'Gemeldet';

  @override
  String get adminReporter => 'Meldende Person';

  @override
  String get adminReports => 'Meldungen';

  @override
  String get adminReserve => 'Reservieren';

  @override
  String get adminReserveForDrop => 'Für Drop reservieren';

  @override
  String get adminReserveUpdateFailed => 'Die Drop-Reservierung konnte nicht aktualisiert werden. Versuch es erneut.';

  @override
  String get adminReservedForNextDrop => 'Für den nächsten Drop reserviert';

  @override
  String get adminRetry => 'Erneut versuchen';

  @override
  String adminReviewProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString/$totalString';
  }

  @override
  String get adminSendNotification => 'Benachrichtigung senden';

  @override
  String adminSendToAudience(String audience) {
    return 'An $audience senden?';
  }

  @override
  String get adminSkip => 'Überspringen';

  @override
  String get adminSpecificUser => 'Bestimmter Nutzer (E-Mail)';

  @override
  String get adminSwipeInstructions => 'Wische nach rechts zum Freigeben und nach links zum Ablehnen';

  @override
  String get adminSwipeReview => 'Wischprüfung';

  @override
  String get adminTarget => 'Ziel';

  @override
  String get adminTelemetryCopied =>
      'In die Zwischenablage kopiert. Füge den Text zum Analysieren an anderer Stelle ein.';

  @override
  String get adminTelemetryReadError => 'Telemetriedaten konnten nicht gelesen werden';

  @override
  String get adminTitle => 'Admin-Moderation';

  @override
  String get adminTitleLabel => 'Titel';

  @override
  String get adminTitleRequired => 'Titel ist erforderlich';

  @override
  String get adminTotalEvents => 'Ereignisse gesamt';

  @override
  String get adminTryAgain => 'Erneut versuchen';

  @override
  String get adminUndo => 'Rückgängig';

  @override
  String get adminUndoSuccessful => 'Erfolgreich rückgängig gemacht';

  @override
  String get adminUnknown => 'Unbekannt';

  @override
  String get adminUnreserve => 'Reservierung aufheben';

  @override
  String get adminUntitled => 'Ohne Titel';

  @override
  String get adminUploaded => 'Hochgeladen';

  @override
  String get adminUseAppForEvents => 'Verwende die App, um Firestore-Ereignisse zu erzeugen.';

  @override
  String get adminUserEmail => 'E-Mail des Nutzers';

  @override
  String get adminUserReportsShowHere => 'Meldungen von Nutzern erscheinen hier.';

  @override
  String get adminValidEmailRequired => 'Gib eine gültige E-Mail-Adresse ein';

  @override
  String get adminView => 'Ansehen';

  @override
  String get adminViewFullWallpaper => 'Ganzes Hintergrundbild ansehen';

  @override
  String get adminWallId => 'ID';

  @override
  String get adminWallOfTheDay => 'Hintergrundbild des Tages';

  @override
  String get adminWallOrUpload => 'Hintergrundbild oder Upload';

  @override
  String get adminWallpaperAlreadyGone => 'Hintergrundbild war bereits entfernt. Meldung geschlossen.';

  @override
  String get adminWallpaperApproved => 'Hintergrundbild freigegeben';

  @override
  String get adminWallpaperFullScreen => 'Hintergrundbild, Vollbild';

  @override
  String get adminWallpaperRejected => 'Hintergrundbild abgelehnt';

  @override
  String get adminWallpaperRemoved => 'Hintergrundbild entfernt';

  @override
  String get adminWallpaperReport => 'Meldung zum Hintergrundbild';

  @override
  String get adminWallpaperToReview => 'Zu prüfendes Hintergrundbild';

  @override
  String adminWallpapersRemaining(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Hintergrundbilder übrig',
      one: '$countString Hintergrundbild übrig',
    );
    return '$_temp0';
  }

  @override
  String get adminWalls => 'Hintergrundbilder';

  @override
  String adminWriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Schreibvorgänge',
      one: '$countString Schreibvorgang',
    );
    return '$_temp0';
  }

  @override
  String get appLinkRetryWhenOnline => 'Keine Verbindung. Wir öffnen diesen Link, sobald du wieder online bist.';

  @override
  String get appTitle => 'Prism';

  @override
  String get coreBack => 'Zurück';

  @override
  String get coreBio => 'Bio';

  @override
  String get coreBlockCreatorAfterReport => 'Diesen Creator ebenfalls blockieren';

  @override
  String get coreBothScreens => 'beide Bildschirme';

  @override
  String get coreCancel => 'Abbrechen';

  @override
  String get coreCancelSelection => 'Auswahl abbrechen';

  @override
  String get coreCancelSignIn => 'Jetzt nicht';

  @override
  String get coreCategoryAbstract => 'Abstrakt';

  @override
  String get coreCategoryAerial => 'Luftaufnahme';

  @override
  String get coreCategoryAesthetic => 'Ästhetisch';

  @override
  String get coreCategoryAiArt => 'KI-Kunst';

  @override
  String get coreCategoryAnimals => 'Tiere';

  @override
  String get coreCategoryAnime => 'Anime';

  @override
  String get coreCategoryArchitecture => 'Architektur';

  @override
  String get coreCategoryArtistic => 'Künstlerisch';

  @override
  String get coreCategoryBirds => 'Vögel';

  @override
  String get coreCategoryCars => 'Autos';

  @override
  String get coreCategoryCity => 'Stadt';

  @override
  String get coreCategoryClouds => 'Wolken';

  @override
  String get coreCategoryComic => 'Comic';

  @override
  String get coreCategoryCyberpunk => 'Cyberpunk';

  @override
  String get coreCategoryDark => 'Dunkel';

  @override
  String get coreCategoryDefault => 'Kategorie';

  @override
  String get coreCategoryFantasy => 'Fantasy';

  @override
  String get coreCategoryFashion => 'Mode';

  @override
  String get coreCategoryFlowers => 'Blumen';

  @override
  String get coreCategoryFood => 'Essen';

  @override
  String get coreCategoryForest => 'Wald';

  @override
  String get coreCategoryGalaxy => 'Galaxie';

  @override
  String get coreCategoryGaming => 'Gaming';

  @override
  String get coreCategoryGradient => 'Farbverlauf';

  @override
  String get coreCategoryIllustration => 'Illustration';

  @override
  String get coreCategoryKawaii => 'Kawaii';

  @override
  String get coreCategoryLandscape => 'Landschaft';

  @override
  String get coreCategoryMinimal => 'Minimalistisch';

  @override
  String get coreCategoryMusic => 'Musik';

  @override
  String get coreCategoryNature => 'Natur';

  @override
  String get coreCategoryNeon => 'Neon';

  @override
  String get coreCategoryOcean => 'Ozean';

  @override
  String get coreCategoryPortraits => 'Porträts';

  @override
  String get coreCategoryQuotes => 'Zitate';

  @override
  String get coreCategoryRender3d => '3D-Rendering';

  @override
  String get coreCategoryRobots => 'Roboter';

  @override
  String get coreCategoryScenery => 'Kulisse';

  @override
  String get coreCategorySpace => 'Weltraum';

  @override
  String get coreCategorySpiritual => 'Spirituell';

  @override
  String get coreCategorySports => 'Sport';

  @override
  String get coreCategoryTech => 'Technik';

  @override
  String get coreCategoryTextures => 'Texturen';

  @override
  String get coreCategoryUnderTheSea => 'Unterwasser';

  @override
  String get coreCategoryVehicles => 'Fahrzeuge';

  @override
  String get coreCategoryVintage => 'Vintage';

  @override
  String get coreCategoryWarriors => 'Krieger';

  @override
  String get coreChangeWallpaperTarget => 'Festlegen des Hintergrundbilds ändern';

  @override
  String get coreChangelogLatest => 'Neueste';

  @override
  String get coreChooseReportReason => 'Wähle einen Grund';

  @override
  String get coreChooseUsername => 'Wähle einen verfügbaren Nutzernamen.';

  @override
  String get coreCoinAiWallpaper => 'KI-Hintergrundbild';

  @override
  String get coreCoinAutoRotatePass => 'Automatischer Wechsel, 7 Tage';

  @override
  String get coreCoinBadgeReward => 'Abzeichen-Belohnung';

  @override
  String coreCoinBalance(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString Prism Coins';
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
  String get coreCoinCoinsReturned => 'Coins zurückerstattet';

  @override
  String get coreCoinCollectionPreview => 'Sammlungsvorschau, 24 Std.';

  @override
  String get coreCoinDailyChest => 'Tägliche Truhe';

  @override
  String get coreCoinDailyStreak => 'Tägliche Serie';

  @override
  String coreCoinDailyStreakDay(String day) {
    return 'Tägliche Serie, Tag $day';
  }

  @override
  String get coreCoinDay7Chest => 'Truhe an Tag 7';

  @override
  String get coreCoinDrawTicket => 'Ziehungsticket';

  @override
  String get coreCoinDropPack => 'Drop-Paket';

  @override
  String get coreCoinDropWall => 'Drop-Hintergrundbild';

  @override
  String get coreCoinFirstUpload => 'Erster Upload';

  @override
  String get coreCoinGiftPass => 'Geschenk: 24-Stunden-Pass';

  @override
  String get coreCoinInviteReward => 'Einladungsbelohnung';

  @override
  String get coreCoinLiveWallpaperStyle => 'Live-Hintergrundbildstil';

  @override
  String get coreCoinPremiumFilter => 'Premium-Filter';

  @override
  String get coreCoinPremiumWallpaper => 'Premium-Hintergrundbild';

  @override
  String get coreCoinProDailyBonus => 'Täglicher Pro-Bonus';

  @override
  String get coreCoinProSpin => 'Pro-Dreh';

  @override
  String get coreCoinProStreakBonus => 'Pro-Serienbonus';

  @override
  String get coreCoinProfileComplete => 'Profil vollständig';

  @override
  String get coreCoinQuest => 'Quest';

  @override
  String coreCoinRefund(String target) {
    return 'Erstattung: $target';
  }

  @override
  String get coreCoinShop => 'Shop';

  @override
  String get coreCoinSpinWheel => 'Glücksrad drehen';

  @override
  String get coreCoinStreakFreeze => 'Serien-Schutz';

  @override
  String get coreCoinStreakRestore => 'Serie wiederherstellen';

  @override
  String get coreCoinWallpaperDownload => 'Hintergrundbild-Download';

  @override
  String get coreCoinWatchedVideo => 'Video angesehen';

  @override
  String get coreCoinWeekBonus => 'Wochenbonus';

  @override
  String get coreColorBlack => 'Schwarz';

  @override
  String get coreColorBlue => 'Blau';

  @override
  String get coreColorBrown => 'Braun';

  @override
  String get coreColorGreen => 'Grün';

  @override
  String get coreColorGrey => 'Grau';

  @override
  String get coreColorOrange => 'Orange';

  @override
  String get coreColorPink => 'Pink';

  @override
  String get coreColorPurple => 'Violett';

  @override
  String get coreColorRed => 'Rot';

  @override
  String get coreColorTeal => 'Türkis';

  @override
  String get coreColorWhite => 'Weiß';

  @override
  String get coreColorYellow => 'Gelb';

  @override
  String get coreConfirmWallpaperPreview => 'Bestätige das Hintergrundbild in der Systemvorschau.';

  @override
  String get coreContentNotAvailable => 'Dieser Inhalt ist nicht mehr verfügbar';

  @override
  String get coreContentReportUser => 'Nutzer';

  @override
  String get coreContentReportWallpaper => 'Hintergrundbild';

  @override
  String coreContentReportWhy(String contentType) {
    return 'Warum meldest du $contentType?';
  }

  @override
  String coreContentReportWhyWithDetails(String contentType, String details) {
    return 'Warum meldest du $contentType ($details)?';
  }

  @override
  String get coreContinueWithApple => 'Mit Apple fortfahren';

  @override
  String get coreContinueWithGoogle => 'Mit Google fortfahren';

  @override
  String get coreContributorCouldNotLoad => 'Dieses Profil konnte nicht geladen werden';

  @override
  String get coreContributorGithub => 'GitHub';

  @override
  String get coreContributorTwitter => 'Twitter';

  @override
  String get coreContributorWebsite => 'Website';

  @override
  String get coreCouldNotLoadChangelog => 'Änderungsprotokoll konnte nicht geladen werden';

  @override
  String get coreCouldNotLoadWallpaperForEditing => 'Hintergrundbild konnte nicht zur Bearbeitung geladen werden';

  @override
  String get coreCouldNotUpdateFavourites => 'Favoriten konnten nicht aktualisiert werden. Versuch es erneut.';

  @override
  String get coreCreatorPreviewDescription => 'Sieh dir dieses Creator-Profil auf Prism an.';

  @override
  String get coreDefaultBanner => 'Tritt unserem Telegram-Kanal bei';

  @override
  String get coreDepthEffectAutoLongTip =>
      'Der Tiefeneffekt wird automatisch aktiviert. Unter iOS 18 solltest du keine Widgets im Bereich unter der Uhr platzieren.';

  @override
  String get coreDepthEffectAutoTip => 'Der Tiefeneffekt wird automatisch aktiviert.';

  @override
  String get coreDepthEffectBadge => 'Tiefe';

  @override
  String get coreDepthEffectBadgeSemantic => 'Funktioniert mit Tiefeneffekt';

  @override
  String get coreDepthEffectMenuShortTip => 'Tippe auf ••• und dann auf Tiefeneffekt.';

  @override
  String get coreDepthEffectMenuTip => 'Tippe im Sperrbildschirm-Editor auf ••• und dann auf Tiefeneffekt.';

  @override
  String get coreSpatialBadge => 'Räumlich';

  @override
  String get coreSpatialBadgeSemantic => 'Funktioniert als räumliche Szene';

  @override
  String get coreSpatialSceneTip => 'Tippe im Sperrbildschirm-Editor auf die Schaltfläche Räumliche Szene.';

  @override
  String get coreDeviceCannotSetScreen => 'Dieses Gerät kann dieses Bild nicht als Hintergrundbild festlegen.';

  @override
  String get coreDone => 'Fertig';

  @override
  String coreDown(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '−$coinsString';
  }

  @override
  String get coreDownloadNotFinishedCoinsReturned =>
      'Dein letzter Download wurde nicht abgeschlossen. Die Coins wurden zurückerstattet.';

  @override
  String get coreDownloadPrismPreviewDescription => 'Lade Prism herunter und entdecke wunderschöne Hintergrundbilder.';

  @override
  String get coreEdit => 'Bearbeiten';

  @override
  String get coreEditBioHint => 'Erzähl anderen etwas über dich …';

  @override
  String get coreEditDiscardBody => 'Deine Änderungen wurden nicht gespeichert.';

  @override
  String get coreEditDiscardTitle => 'Änderungen verwerfen?';

  @override
  String get coreEditEmailInvalid => 'Gib eine gültige E-Mail-Adresse ein.';

  @override
  String coreEditKindLinkInvalid(String kind) {
    return 'Gib einen gültigen $kind-Link ein.';
  }

  @override
  String get coreEditLinkInvalid => 'Gib einen gültigen Link ein.';

  @override
  String get coreEditProfile => 'Profil bearbeiten';

  @override
  String coreEditProfileLink(String kind) {
    return '$kind-Link';
  }

  @override
  String get coreEditRemoveBioTitle => 'Bio entfernen?';

  @override
  String get coreEditRemoveConfirm => 'Entfernen';

  @override
  String coreEditRemoveTitle(String item) {
    return '$item entfernen?';
  }

  @override
  String get coreEditUsernameAvailable => 'Nutzername verfügbar';

  @override
  String get coreEditUsernameChars => 'Verwende nur Buchstaben, Zahlen und Unterstriche.';

  @override
  String get coreEditUsernameAllCaps => 'Verwende mindestens einen Kleinbuchstaben.';

  @override
  String coreEditUsernameMinLength(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Verwende mindestens $lengthString Zeichen.';
  }

  @override
  String coreEditUsernameRule(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Verwende mindestens $lengthString Buchstaben, Zahlen oder Unterstriche (_).';
  }

  @override
  String get coreEditUsernameTaken => 'Dieser Nutzername ist bereits vergeben.';

  @override
  String get coreEditUsernameTakenSemantic => 'Nutzername vergeben';

  @override
  String get coreFavourite => 'Favorit';

  @override
  String coreFileSizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String get coreGenericSignInError => 'Etwas ist schiefgelaufen. Bitte versuch es erneut!';

  @override
  String get coreGoHome => 'Zur Startseite';

  @override
  String get coreGooglePlayServicesSignInError =>
      'Du kannst dich mit Google Play-Diensten auf diesem Gerät nicht anmelden.';

  @override
  String get coreGoogleSignInNetworkError =>
      'Die Google-Anmeldung ist fehlgeschlagen. Prüfe deine Verbindung und versuch es erneut.';

  @override
  String get coreHomeScreen => 'Startbildschirm';

  @override
  String get coreHomeScreenSetupUnavailable => 'Einrichtungen für den Startbildschirm sind nicht mehr verfügbar.';

  @override
  String get coreInvalidLinkBody => 'Der geöffnete Link ist ungültig oder nicht mehr verfügbar.';

  @override
  String coreInvitedToPrismTitle(String name) {
    return '$name hat dich zu Prism eingeladen';
  }

  @override
  String get coreIosWallpaperGuideBody =>
      'Unter iOS können Apps das Hintergrundbild nicht ändern. Schließe den Vorgang in Fotos ab:';

  @override
  String get coreJoinPrismPreviewTitle => 'Prism beitreten';

  @override
  String get coreKeepPrismOpen => 'Lass Prism geöffnet und versuch es erneut.';

  @override
  String get coreLoading => 'Wird geladen';

  @override
  String get coreLoadingMoreFailed => 'Weitere Inhalte konnten nicht geladen werden. Tippe zum erneuten Versuchen.';

  @override
  String get coreLoadingWallpaper => 'Hintergrundbild wird geladen';

  @override
  String get coreLockScreen => 'Sperrbildschirm';

  @override
  String get coreMatchAccent => 'Akzentfarbe übernehmen';

  @override
  String get coreName => 'Name';

  @override
  String get coreNoWallpaperUrl => 'Keine URL für das Hintergrundbild verfügbar';

  @override
  String get coreNotNow => 'Jetzt nicht';

  @override
  String get coreOpenPhotos => 'Fotos öffnen';

  @override
  String get coreOpenSettings => 'Einstellungen öffnen';

  @override
  String get corePairPickerDownloads => 'Downloads';

  @override
  String get corePairPickerFavourites => 'Favoriten';

  @override
  String get corePairPickerHistory => 'Verlauf';

  @override
  String get corePairPickerNoDownloads => 'Noch keine Downloads.';

  @override
  String get corePairPickerNoFavourites => 'Noch keine Favoriten.';

  @override
  String get corePairPickerNoHistory => 'Noch kein Verlauf.';

  @override
  String get corePairPickerTitle => 'Wähle ein Hintergrundbild für den Sperrbildschirm';

  @override
  String get corePairPickerUseWallpaper => 'Dieses Hintergrundbild für den Sperrbildschirm verwenden';

  @override
  String get corePhotosPermissionMessage =>
      'Erlaube Prism in den Einstellungen, Fotos hinzuzufügen und Hintergrundbilder zu speichern.';

  @override
  String get corePhotosStepOpen => 'Öffne Fotos.';

  @override
  String get corePhotosStepShare => 'Tippe auf „Teilen“.';

  @override
  String get corePhotosStepUseAsWallpaper => 'Tippe auf „Als Hintergrundbild verwenden“.';

  @override
  String corePopupAppVersion(String version) {
    return 'Du verwendest Version $version.';
  }

  @override
  String get corePopupCannotUndo => 'Das kann nicht rückgängig gemacht werden.';

  @override
  String get corePopupCoverPhoto => 'Titelbild';

  @override
  String get corePopupDiscard => 'Verwerfen';

  @override
  String get corePopupProfilePhoto => 'Profilbild';

  @override
  String get corePopupWhatsNew => 'Neuigkeiten';

  @override
  String get corePreviousWallpaperRestored => 'Vorheriges Hintergrundbild wiederhergestellt';

  @override
  String get coreProfileSaveFailed => 'Dein Profil konnte nicht gespeichert werden. Bitte versuch es erneut.';

  @override
  String get coreProfileUpdated => 'Profil aktualisiert';

  @override
  String coreReferralSaved(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Empfehlung gespeichert. Melde dich an, um +$coinsString Coins zu erhalten.';
  }

  @override
  String coreRelativeTimeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'vor $countString Tagen', one: 'vor 1 Tag');
    return '$_temp0';
  }

  @override
  String coreRelativeTimeDaysFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Tagen', one: '1 Tag');
    return 'in $_temp0';
  }

  @override
  String coreRelativeTimeHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $countString Stunden',
      one: 'vor 1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeHoursFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Stunden', one: '1 Stunde');
    return 'in $_temp0';
  }

  @override
  String get coreRelativeTimeJustNow => 'Gerade eben';

  @override
  String coreRelativeTimeMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $countString Minuten',
      one: 'vor 1 Minute',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeMinutesFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Minuten', one: '1 Minute');
    return 'in $_temp0';
  }

  @override
  String get coreRemoveBio => 'Bio entfernen';

  @override
  String get coreReport => 'Melden';

  @override
  String get coreReportCouldNotSubmit => 'Deine Meldung konnte nicht gesendet werden. Bitte versuch es erneut.';

  @override
  String get coreReportDetailsHint => 'Gibt es noch etwas, das wir wissen sollten?';

  @override
  String get coreReportDetailsOptional => 'Details (optional)';

  @override
  String get coreReportReasonCopyright => 'Urheberrecht / Eigentumsrechte';

  @override
  String get coreReportReasonHarassment => 'Belästigung oder Hass';

  @override
  String get coreReportReasonOther => 'Sonstiges';

  @override
  String get coreReportReasonSexual => 'Sexuelle Inhalte oder Inhalte für Erwachsene';

  @override
  String get coreReportReasonSpam => 'Spam oder irreführende Inhalte';

  @override
  String get coreReportSent => 'Meldung gesendet. Danke.';

  @override
  String get coreRestorePreviousWallpaperFailed =>
      'Das vorherige Hintergrundbild konnte nicht wiederhergestellt werden. Lege es erneut im Hintergrundbildverlauf fest.';

  @override
  String get coreRetry => 'Erneut versuchen';

  @override
  String get coreRetryImage => 'Bild erneut versuchen';

  @override
  String coreRetryOnScreen(String screen) {
    return '$screen erneut versuchen';
  }

  @override
  String get coreSaveChanges => 'Änderungen speichern';

  @override
  String get coreSeeFullChangelog => 'Vollständiges Änderungsprotokoll ansehen';

  @override
  String get coreSeeMore => 'Mehr ansehen';

  @override
  String coreSelectCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString ausgewählt';
  }

  @override
  String get coreSendReport => 'Meldung senden';

  @override
  String get coreSet => 'Festlegen';

  @override
  String get coreSetItAsWallpaper => 'Als Hintergrundbild festlegen';

  @override
  String get coreSetWallpaper => 'Als Hintergrundbild festlegen';

  @override
  String coreSetWallpaperOn(String screen) {
    return 'Als Hintergrundbild auf $screen festlegen';
  }

  @override
  String get coreShare => 'Teilen';

  @override
  String coreShareCardClipboard(String link) {
    return '🔥Sieh dir das an ➜ $link';
  }

  @override
  String get coreShareFormatStory => 'Story';

  @override
  String get coreShareFormatPost => 'Beitrag';

  @override
  String get coreShareFormatClean => 'Schlicht';

  @override
  String get coreShareTargetInstagram => 'Instagram';

  @override
  String get coreShareTargetCopyLink => 'Link kopieren';

  @override
  String get coreShareTargetSaveImage => 'Bild speichern';

  @override
  String get coreShareTargetMore => 'Mehr';

  @override
  String coreShareCardBy(String creator) {
    return 'von $creator';
  }

  @override
  String get coreShareImageSaved => 'Bild gespeichert';

  @override
  String get coreShareImageFailed => 'Das Bild konnte nicht gespeichert werden. Versuch es erneut.';

  @override
  String get coreShareInstagramFailed => 'Instagram konnte nicht geöffnet werden. Versuch es erneut.';

  @override
  String get coreSharePreviewFailed => 'Dieses Bild konnte nicht erstellt werden. Über „Mehr“ wird der Link geteilt.';

  @override
  String get coreShareLinkCopied => 'Freigabelink kopiert!';

  @override
  String coreShareProfileClipboard(String link) {
    return 'Sieh dir mein Profil auf Prism an ➜ $link';
  }

  @override
  String coreShareWallpaperClipboard(String link) {
    return 'Sieh dir das an ➜ $link';
  }

  @override
  String get coreShareWallpaperGeneric => 'Dieses Hintergrundbild ist in der Prism-App verfügbar.';

  @override
  String get coreSignInFeatureBody => 'Mit deinem Konto sind deine Coins, Favoriten und Uploads an einem Ort.';

  @override
  String coreSignInFeatureTitle(String feature) {
    return 'Melde dich für „$feature“ an';
  }

  @override
  String get coreSignInPopupBody => 'Nutze deine Favoriten, Uploads und Coins auf allen Geräten.';

  @override
  String get coreSignInPopupTitle => 'Bei Prism anmelden';

  @override
  String get coreSignInPromptAction => 'Anmelden';

  @override
  String get coreSignInToReportContent => 'Melde dich an, um Inhalte zu melden';

  @override
  String get coreSignInToSyncFavourites => 'Melde dich an, damit deine Favoriten auf allen Geräten verfügbar sind';

  @override
  String get coreSigningIn => 'Anmeldung läuft';

  @override
  String get coreSomethingWentWrong => 'Etwas ist schiefgelaufen. Versuch es erneut.';

  @override
  String coreStreakNext(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Als Nächstes +$coinsString';
  }

  @override
  String coreStreakSemantics(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$daysString Tage in Folge, nächste Belohnung: $coinsString Coins';
  }

  @override
  String get coreCustomAccent => 'Eigene Farbe';

  @override
  String get coreCustomAccentHex => 'Hex-Code';

  @override
  String get coreCustomAccentHue => 'Farbton';

  @override
  String get coreCustomAccentSaturation => 'Sättigung';

  @override
  String get coreCustomAccentLightness => 'Helligkeit';

  @override
  String get coreCustomAccentInvalidHex => 'Gib 6 Hex-Ziffern ein, z. B. #E57697.';

  @override
  String get coreCustomAccentLowContrast =>
      'Diese Farbe ist in diesem Design schwer zu erkennen. Wähle einen helleren oder dunkleren Ton.';

  @override
  String get coreCustomAccentApply => 'Farbe verwenden';

  @override
  String coreThemeAccentSemanticLabel(int index, int count) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Akzentfarbe $indexString von $countString';
  }

  @override
  String get coreThemeAmoled => 'AMOLED';

  @override
  String get coreThemeCoffee => 'Kaffee';

  @override
  String get coreThemeCottonBlue => 'Baumwollblau';

  @override
  String get coreThemeCustom => 'Eigenes Design';

  @override
  String get coreThemeDeepOcean => 'Tiefer Ozean';

  @override
  String get coreThemeFrostWhite => 'Frostweiß';

  @override
  String get coreThemeJungle => 'Dschungel';

  @override
  String get coreThemeLocked => 'Gesperrt';

  @override
  String get coreThemeMaterialDark => 'Material Dunkel';

  @override
  String get coreThemeMaterialYou => 'Material You';

  @override
  String get coreThemeOlive => 'Olive';

  @override
  String get coreThemePepper => 'Pfeffer';

  @override
  String get coreThemeRose => 'Rose';

  @override
  String get coreThemeSky => 'Himmel';

  @override
  String get coreThemeSteel => 'Stahl';

  @override
  String get coreThemeSpooky => 'Gruselig';

  @override
  String get spookyBannerTitle => 'Das Gruselig-Theme ist da';

  @override
  String get spookyBannerSubtitle => 'Orange, Schwarz und ein paar Spinnen. Kostenlos. Tippen zum Ausprobieren.';

  @override
  String get spookyAnnouncementTitle => 'Neu: das Gruselig-Theme 🎃';

  @override
  String get spookyAnnouncementBody =>
      'Orange, Schwarz und ein paar Spinnen. Es ist kostenlos. Tippen zum Ausprobieren.';

  @override
  String get coreThemeDiwali => 'Diwali';

  @override
  String get diwaliBannerTitle => 'Das Diwali-Theme ist da';

  @override
  String get diwaliBannerSubtitle => 'Diyas, Feuerwerk und Gold. Kostenlos. Tippen zum Ausprobieren.';

  @override
  String get diwaliAnnouncementTitle => 'Neu: das Diwali-Theme 🪔';

  @override
  String get diwaliAnnouncementBody => 'Diyas, Feuerwerk und Gold. Es ist kostenlos. Tippen zum Ausprobieren.';

  @override
  String get coreThisPageDoesNotExist => 'Diese Seite gibt es nicht';

  @override
  String get coreTryAgain => 'Erneut versuchen';

  @override
  String get coreUndo => 'Rückgängig';

  @override
  String coreUp(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString';
  }

  @override
  String get coreUploadFailureDailyLimit => 'Du hast dein Upload-Limit für heute erreicht. Versuch es morgen erneut.';

  @override
  String get coreUploadFailureFileType =>
      'Dieser Dateityp wird nicht unterstützt. Verwende ein JPG-, PNG-, WebP- oder HEIC-Bild.';

  @override
  String get coreUploadFailureGeneric =>
      'Der Upload wurde nicht abgeschlossen. Dein Bild ist noch da, du kannst es also erneut versuchen.';

  @override
  String get coreUploadFailureInProgress => 'Ein Upload läuft bereits. Warte kurz und versuch es dann erneut.';

  @override
  String get coreUploadFailureOversize => 'Dieses Bild ist größer als 15 MB. Wähle ein kleineres Bild.';

  @override
  String get coreUploadFailureSignIn => 'Melde dich erneut an, um etwas hochzuladen.';

  @override
  String get coreUploadFailureWeeklyLimit => 'Du hast dein wöchentliches Limit für kostenlose Uploads erreicht.';

  @override
  String get coreUploadSubmittedSuccess => 'Dein Hintergrundbild wurde eingereicht und wird geprüft.';

  @override
  String get coreUsername => 'Nutzername';

  @override
  String get coreUsernameCheckFailed => 'Der Nutzername konnte nicht geprüft werden. Versuch es erneut.';

  @override
  String get coreUsernameRequiredToShareProfile => 'Lege einen Nutzernamen fest, um dein Profil zu teilen';

  @override
  String get coreWallpaperApplied => 'Hintergrundbild erfolgreich festgelegt!';

  @override
  String get coreWallpaperBothScreens => 'Beide Bildschirme';

  @override
  String coreWallpaperBySemanticLabel(String name) {
    return 'Hintergrundbild von $name';
  }

  @override
  String get coreWallpaperDownloadedPictures => 'Hintergrundbild in Pictures/Prism gespeichert';

  @override
  String get coreWallpaperEditApplyColorFailed => 'Die Farbe konnte nicht angewendet werden. Versuch es erneut.';

  @override
  String get coreWallpaperErrorGeneric => 'Hintergrundbild konnte nicht festgelegt werden.';

  @override
  String get coreWallpaperErrorImageTooLarge =>
      'Dieses Bild ist zu groß, um es auf deinem Gerät als Hintergrundbild festzulegen.';

  @override
  String get coreWallpaperErrorInvalidVideo =>
      'Dieser Clip kann nicht als Hintergrundbild wiedergegeben werden. Versuch es mit einem anderen.';

  @override
  String get coreWallpaperErrorLiveGeneric => 'Live-Hintergrundbild konnte nicht festgelegt werden. Versuch es erneut.';

  @override
  String get coreWallpaperErrorMemory => 'Nicht genügend Speicher. Schließe andere Apps und versuch es erneut.';

  @override
  String get coreWallpaperErrorNotAllowed =>
      'Dein Gerät oder Arbeitsprofil erlaubt keine Änderungen am Hintergrundbild.';

  @override
  String get coreWallpaperErrorPermission => 'Prism darf diese Datei nicht lesen.';

  @override
  String get coreWallpaperErrorReadFile => 'Die Datei konnte nicht gelesen werden. Versuch es erneut.';

  @override
  String get coreWallpaperErrorSourceTooLarge => 'Diese Datei ist zu groß für ein Live-Hintergrundbild.';

  @override
  String get coreWallpaperErrorStyle => 'Dieses Gerät konnte diesen Stil nicht starten. Versuch es mit einem anderen.';

  @override
  String get coreWallpaperErrorSystemPreview => 'Die Systemvorschau konnte nicht geöffnet werden.';

  @override
  String get coreWallpaperErrorTextureDimensions => 'Dieses Bild ist zu groß für ein Live-Hintergrundbild.';

  @override
  String get coreWallpaperErrorTimeout => 'Zeitüberschreitung. Prüfe deine Verbindung und versuch es erneut.';

  @override
  String get coreWallpaperHomeScreen => 'Startbildschirm';

  @override
  String get coreWallpaperHomeSetLockFailed =>
      'Hintergrundbild für den Startbildschirm festgelegt. Das Festlegen für den Sperrbildschirm ist fehlgeschlagen.';

  @override
  String get coreWallpaperLinkCopyFailed => 'Der Link konnte nicht kopiert werden. Versuch es erneut.';

  @override
  String get coreWallpaperLinkCreateFailed => 'Der Freigabelink konnte nicht erstellt werden. Versuch es erneut.';

  @override
  String get coreWallpaperLoadTimedOut =>
      'Beim Laden des Hintergrundbilds ist eine Zeitüberschreitung aufgetreten. Prüfe deine Verbindung und versuch es erneut.';

  @override
  String get coreWallpaperLockScreen => 'Sperrbildschirm';

  @override
  String get coreWallpaperOfflineUnavailable =>
      'Dieses Hintergrundbild ist nicht auf diesem Gerät gespeichert. Stelle eine Internetverbindung her und versuch es erneut.';

  @override
  String coreWallpaperPartialSet(String applied, String failed) {
    return '$applied festgelegt. $failed fehlgeschlagen.';
  }

  @override
  String get coreWallpaperPreviewDescription => 'Sieh dir dieses tolle Hintergrundbild von Prism an.';

  @override
  String get coreWallpaperPreviewTitle => 'Hintergrundbild auf Prism';

  @override
  String get coreWallpaperSaveFailed => 'Hintergrundbild konnte nicht festgelegt werden. Versuch es erneut.';

  @override
  String get coreWallpaperSavedPhotos => 'In Fotos gespeichert.';

  @override
  String get coreWallpaperSavedToast => 'Deine Werbe-Belohnung wurde gutgeschrieben.';

  @override
  String coreWallpaperSavedWithTip(String saved, String tip) {
    return '$saved $tip';
  }

  @override
  String get coreWallpaperSemanticLabel => 'Hintergrundbild';

  @override
  String get coreWallpaperSet => 'Hintergrundbild festgelegt';

  @override
  String get coreWallpaperShareFailed => 'Dieses Hintergrundbild kann gerade nicht geteilt werden.';

  @override
  String get coreWallpaperShareRetryFailed => 'Dieses Hintergrundbild konnte nicht geteilt werden. Versuch es erneut.';

  @override
  String get debugAdminReviewDescription => 'Tool zur Inhaltsmoderation und für Push-Benachrichtigungen';

  @override
  String get debugAdminShortcuts => 'Admin-Kurzbefehle';

  @override
  String get debugLiveActivityPreview => 'Live-Activity-Vorschau';

  @override
  String get debugLiveActivityPreviewDescription => 'Startet eine Beispiel-Aktivität: fertig nach 8 Sekunden';

  @override
  String get debugLiveActivityUnavailable => 'Live-Aktivitäten sind aus oder nicht unterstützt';

  @override
  String get debugReviewActivityPreview => 'Vorschau der Prüfwarteschlangen-Aktivität';

  @override
  String get debugReviewActivityPreviewDescription =>
      'Zeigt die Hintergrundbilder, die auf Prüfung warten, auf dem Sperrbildschirm';

  @override
  String get debugAllTags => 'Alle Tags';

  @override
  String get debugAndroidVersion => 'Android-Version';

  @override
  String get debugAnimationSpeed => 'Animationsgeschwindigkeit';

  @override
  String get debugAppInfo => 'App-Info';

  @override
  String get debugAppName => 'App-Name';

  @override
  String get debugAppVersion => 'App-Version';

  @override
  String get debugAutoScrollOff => 'Automatisches Scrollen ausschalten';

  @override
  String get debugAutoScrollOn => 'Automatisches Scrollen einschalten';

  @override
  String debugBackendName(String backend) {
    return 'Backend: $backend';
  }

  @override
  String get debugBoard => 'Hauptplatine';

  @override
  String get debugBrand => 'Marke';

  @override
  String get debugBuildNumber => 'Build-Nummer';

  @override
  String get debugBuildSignature => 'Build-Signatur';

  @override
  String get debugCacheCleared => 'App-Cache geleert';

  @override
  String get debugCancel => 'Abbrechen';

  @override
  String get debugCheckLogsRetry => 'Prüfe die Logs und versuche es erneut.';

  @override
  String get debugClear => 'Leeren';

  @override
  String get debugClearAll => 'Alles leeren';

  @override
  String get debugClearAllStorageBody =>
      'Dadurch werden alle lokal gespeicherten Daten endgültig gelöscht. Bis zum Neustart verhält sich die App möglicherweise unerwartet.';

  @override
  String get debugClearAllStorageTitle => 'Gesamten Speicher leeren?';

  @override
  String get debugClearAppCache => 'App-Cache leeren';

  @override
  String get debugClearAppCacheDescription => 'Cache für Bilder, Feed und Benachrichtigungen leeren';

  @override
  String get debugClearImageCache => 'Bild-Cache leeren';

  @override
  String get debugClearImageCacheDescription => 'Bild-Cache im Arbeitsspeicher leeren';

  @override
  String get debugClearLogsBody => 'Dadurch werden alle im Arbeitsspeicher gespeicherten Log-Einträge entfernt.';

  @override
  String get debugClearLogsTitle => 'Logs leeren?';

  @override
  String get debugClearSearch => 'Suche leeren';

  @override
  String get debugCoins => 'Coins';

  @override
  String get debugCopied => 'Kopiert';

  @override
  String get debugCopiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get debugCopy => 'Kopieren';

  @override
  String get debugCopyDiagnosticReport => 'Diagnosebericht kopieren';

  @override
  String get debugCopyFiltered => 'Alle gefilterten kopieren';

  @override
  String get debugCopyFullDetail => 'Vollständige Details kopieren';

  @override
  String debugCopyTitle(String title) {
    return '$title kopieren';
  }

  @override
  String get debugCopyValue => 'Wert kopieren';

  @override
  String debugCouldNotClearCache(String error) {
    return 'App-Cache konnte nicht geleert werden: $error';
  }

  @override
  String get debugCouldNotSaveValue => 'Wert konnte nicht gespeichert werden';

  @override
  String get debugCrashApp => 'App zum Absturz bringen';

  @override
  String get debugDangerZone => 'Gefahrenbereich';

  @override
  String get debugDarkCard => 'Dunkle Karte';

  @override
  String get debugDefaultValue => '(Standard)';

  @override
  String get debugDelete => 'Löschen';

  @override
  String get debugDeleteKey => 'Schlüssel löschen';

  @override
  String debugDeleteKeyBody(String key) {
    return '„$key“ aus dem lokalen Speicher löschen.';
  }

  @override
  String get debugDeleteKeyTitle => 'Schlüssel löschen?';

  @override
  String get debugDevice => 'Gerät';

  @override
  String get debugDeviceName => 'Gerät';

  @override
  String get debugDevicePixelRatio => 'Geräte-Pixelverhältnis';

  @override
  String get debugDiagnosticCopied => 'Diagnosebericht in die Zwischenablage kopiert';

  @override
  String get debugDiagnosticReportHeading => '=== Prism-Diagnosebericht ===';

  @override
  String get debugEditValue => 'Wert bearbeiten';

  @override
  String get debugEmail => 'E-Mail';

  @override
  String get debugEmptyList => 'Leere Liste';

  @override
  String get debugEnvironment => 'Umgebung';

  @override
  String get debugError => 'Fehler';

  @override
  String get debugErrorCopied => 'Fehler kopiert';

  @override
  String get debugErrorStreakLost => 'Fehler, Serie verloren';

  @override
  String get debugErrorValue => 'Fehler';

  @override
  String get debugExportFile => 'Als Datei exportieren';

  @override
  String get debugFavouriteAdded => 'Zu Favoriten hinzugefügt';

  @override
  String get debugFilterByTag => 'Nach Tag filtern';

  @override
  String get debugFilterKeys => 'Schlüssel filtern';

  @override
  String get debugFingerprint => 'Fingerabdruck';

  @override
  String get debugFirestoreTelemetryDescription => 'Firestore-Lese- und Schreibvorgänge analysieren';

  @override
  String get debugFlagsReset => 'Debug-Schalter zurückgesetzt';

  @override
  String get debugForceCrash => 'Absturz erzwingen';

  @override
  String get debugForceCrashBody => 'Dadurch wird eine Ausnahme ausgelöst, um zu prüfen, ob Sentry Fehler meldet.';

  @override
  String get debugForceCrashDescription => 'Eine Ausnahme auslösen, um die Fehlererfassung durch Sentry zu testen';

  @override
  String get debugForceCrashTitle => 'Absturz erzwingen?';

  @override
  String debugGeneratedAt(String date) {
    return 'Erstellt: $date';
  }

  @override
  String get debugHardware => 'Hardware';

  @override
  String get debugIdentifier => 'Kennung';

  @override
  String get debugImageCacheCleared => 'Bild-Cache geleert';

  @override
  String get debugIsAdmin => 'Ist Admin';

  @override
  String get debugIsPremium => 'Hat Premium';

  @override
  String get debugLevel => 'Level';

  @override
  String get debugLightCard => 'Helle Karte';

  @override
  String get debugLoadingSearch => 'Suche wird geladen';

  @override
  String get debugLogDetail => 'Log-Details';

  @override
  String debugLogEntryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Einträge',
      one: '$countString Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get debugLoggedIn => 'Angemeldet';

  @override
  String get debugLoggingAndNetwork => 'Protokollierung und Netzwerk';

  @override
  String get debugLogicalSize => 'Logische Größe';

  @override
  String get debugLogs => 'Protokolle';

  @override
  String get debugLogsAppearHere => 'Während die App läuft, erscheinen hier Log-Einträge.';

  @override
  String get debugMaintenance => 'Wartung';

  @override
  String get debugManufacturer => 'Hersteller';

  @override
  String get debugMascot => 'Maskottchen';

  @override
  String get debugMessage => 'Nachricht';

  @override
  String get debugMixpanelEnabled => 'Mixpanel aktiviert';

  @override
  String get debugMixpanelTokenPresent => 'Mixpanel-Token vorhanden';

  @override
  String get debugModel => 'Modell';

  @override
  String get debugMoodCalm => 'Ruhig';

  @override
  String get debugMoodCelebrate => 'Feierlich';

  @override
  String get debugMoodCurious => 'Neugierig';

  @override
  String get debugMoodHappy => 'Fröhlich';

  @override
  String get debugMoodLove => 'Verliebt';

  @override
  String get debugMoodProud => 'Stolz';

  @override
  String get debugMoodSad => 'Traurig';

  @override
  String get debugMoodSleepy => 'Müde';

  @override
  String get debugMoodSurprised => 'Überrascht';

  @override
  String get debugMoodWorried => 'Besorgt';

  @override
  String get debugName => 'Name';

  @override
  String get debugNoKeysFound => 'Keine Schlüssel gefunden';

  @override
  String get debugNoLogs => 'Keine Logs';

  @override
  String get debugNoMatchingLogs => 'Kein Log-Eintrag entspricht den Filtern.';

  @override
  String get debugNotAvailable => 'Nicht verfügbar';

  @override
  String get debugNotSignedIn => 'Nicht angemeldet';

  @override
  String get debugNothingNew => 'Nichts Neues';

  @override
  String get debugOfflineStreakRisk => 'Offline, Serie gefährdet';

  @override
  String get debugPackage => 'Paket';

  @override
  String get debugPackageName => 'Paketname';

  @override
  String get debugPaintBaselines => 'Grundlinien anzeigen';

  @override
  String get debugPaintBaselinesDescription => 'Hilfslinien für Textgrundlinien anzeigen';

  @override
  String get debugPaintSize => 'Größen visualisieren';

  @override
  String get debugPaintSizeDescription => 'Layoutbegrenzungen aller Widgets anzeigen';

  @override
  String get debugPaintSizeWarning =>
      'Größenvisualisierung, Neuzeichnungs-Regenbogen und Grundlinien funktionieren nur in Debug- und Profile-Builds.';

  @override
  String get debugPerformanceOverlay => 'Performance-Anzeige';

  @override
  String get debugPerformanceOverlayDescription => 'Diagramme zur GPU- und CPU-Auslastung';

  @override
  String get debugPersistenceBackend => 'Speicher-Backend';

  @override
  String get debugPexelsKeyPresent => 'Pexels-Schlüssel vorhanden';

  @override
  String get debugPhysicalDevice => 'Ist ein physisches Gerät';

  @override
  String get debugPhysicalSize => 'Physische Größe';

  @override
  String get debugPlatform => 'Plattform';

  @override
  String get debugRcApiKeyPresent => 'RC-API-Schlüssel vorhanden';

  @override
  String get debugReduceMotionPose => 'Zeigt die Pose jeder Stimmung bei reduzierter Bewegung';

  @override
  String get debugRefresh => 'Aktualisieren';

  @override
  String get debugRemoteConfig => 'Remote Config';

  @override
  String get debugRemoteConfigUnavailable => 'Remote Config nicht verfügbar';

  @override
  String get debugRendering => 'Darstellung';

  @override
  String get debugRepaintRainbow => 'Neuzeichnungs-Regenbogen';

  @override
  String get debugRepaintRainbowDescription => 'Neu gezeichnete Bereiche in wechselnden Farben hervorheben';

  @override
  String get debugResetFlags => 'Alle Debug-Schalter zurücksetzen';

  @override
  String get debugResetFlagsDescription => 'Alle Schalter auf ihre Standardwerte zurücksetzen';

  @override
  String get debugSave => 'Speichern';

  @override
  String get debugSaveValueAsText => 'Beim Speichern wird der Wert als Text abgelegt.';

  @override
  String get debugScreen => 'Bildschirm';

  @override
  String get debugSdkInt => 'SDK-Integer';

  @override
  String get debugSearchLogs => 'Logs durchsuchen';

  @override
  String get debugSemanticsDebugger => 'Semantics-Debugger';

  @override
  String get debugSemanticsDebuggerDescription => 'Beschriftungen des Bedienungshilfen-Baums einblenden';

  @override
  String get debugSentryDsnPresent => 'Sentry-DSN vorhanden';

  @override
  String get debugSentryEnabled => 'Sentry aktiviert';

  @override
  String get debugSentryEnv => 'Sentry-Umgebung';

  @override
  String get debugSequence => 'Abfolge';

  @override
  String get debugShowLogToasts => 'Log-Toasts anzeigen';

  @override
  String get debugShowLogToastsDescription => 'Log-Einträge kurz als Overlays einblenden';

  @override
  String get debugSimulateNoInternet => 'Keine Internetverbindung simulieren';

  @override
  String get debugSimulateNoInternetDescription => 'Überschreibt die Verbindungsprüfung und meldet Offline-Status';

  @override
  String get debugSpeed => 'Geschwindigkeit';

  @override
  String get debugStackTrace => 'Stacktrace';

  @override
  String get debugStackTraceCopied => 'Stacktrace kopiert';

  @override
  String get debugStillPoses => 'Statische Posen';

  @override
  String get debugStorage => 'Speicher';

  @override
  String get debugStorageCleared => 'Gesamter Speicher geleert';

  @override
  String debugStorageKeyCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Schlüssel',
      one: '$countString Schlüssel',
    );
    return '$_temp0';
  }

  @override
  String get debugStorageNotInitialized => 'Speicher nicht initialisiert';

  @override
  String get debugStorageReadError => 'Speicher konnte nicht gelesen werden';

  @override
  String get debugStreakCoinsPurchase => 'Serie, Coins, Kauf';

  @override
  String get debugStreakKeptToday => 'Serie heute fortgesetzt';

  @override
  String get debugSubscriptionTier => 'Abostufe';

  @override
  String get debugSystemName => 'Systemname';

  @override
  String get debugSystemVersion => 'Systemversion';

  @override
  String get debugTime => 'Zeit';

  @override
  String get debugTitle => 'Debug';

  @override
  String get debugTools => 'Werkzeuge';

  @override
  String debugTypeName(String type) {
    return 'Typ: $type';
  }

  @override
  String get debugUser => 'Nutzer';

  @override
  String get debugUserId => 'Nutzer-ID';

  @override
  String get debugUsername => 'Nutzername';

  @override
  String get debugValue => 'Wert';

  @override
  String get debugVersion => 'Version';

  @override
  String get debugWallpaperSetSaved => 'Hintergrundbild festgelegt oder gespeichert';

  @override
  String get debugWotdNotification => 'Hintergrundbild des Tages, Benachrichtigung';

  @override
  String get deepLinkInputChooseImage => 'Bild auswählen';

  @override
  String get deepLinkInputChooseImageDescription => 'Wähle ein Bild aus deiner Galerie, um fortzufahren.';

  @override
  String get deepLinkInputClockPreviewTitle => 'Uhrvorschau';

  @override
  String get deepLinkInputEditTitle => 'Hintergrundbild bearbeiten';

  @override
  String get deepLinkInputFiltersTitle => 'Hintergrundbildfilter';

  @override
  String get deepLinkInputGalleryError => 'Deine Galerie konnte nicht geöffnet werden. Bitte versuch es erneut.';

  @override
  String get deepLinkInputLiveTitle => 'Live-Hintergrundbild';

  @override
  String get deepLinkInputPhotoPreviewTitle => 'Fotovorschau';

  @override
  String get deepLinkInputPositionTitle => 'Hintergrundbild positionieren';

  @override
  String get deepLinkInputUploadTitle => 'Hintergrundbild hochladen';

  @override
  String get deepLinkInputWallpaperPreviewTitle => 'Hintergrundbildvorschau';

  @override
  String get economyActivity => 'Aktivität';

  @override
  String get economyActivityEmptyMessage =>
      'Sieh dir ein Video an oder halte deine Serie aufrecht, um deine ersten Coins zu verdienen.';

  @override
  String get economyActivityLoadFailed => 'Aktivität konnte nicht geladen werden.';

  @override
  String get economyAdCreditFailure => 'Coins können gerade nicht gutgeschrieben werden.';

  @override
  String get economyAdDailyLimit => 'Tageslimit erreicht. Morgen geht\'s weiter.';

  @override
  String get economyAdNotCompleted => 'Die Werbung wurde nicht vollständig angesehen.';

  @override
  String get economyAdOffline => 'Du bist offline. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String economyAdRewardDetails(int first, int reward, int maximum) {
    final intl.NumberFormat firstNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String firstString = firstNumberFormat.format(first);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Beim ersten Mal heute +$firstString, danach +$rewardString. Bis zu $maximumString pro Tag.';
  }

  @override
  String get economyAdRewardPending =>
      'Wir konnten deine Belohnung noch nicht bestätigen. Die Coins kommen an, sobald du wieder online bist.';

  @override
  String get economyAdUnavailable => 'Gerade ist keine Werbung verfügbar. Versuch es später noch einmal.';

  @override
  String get economyAddPhotoBio => 'Foto und Bio hinzufügen';

  @override
  String get economyAddedToBalance => 'Deinem Guthaben hinzugefügt';

  @override
  String get economyAddedToCollection => 'Deiner Sammlung hinzugefügt';

  @override
  String get economyAddedToXp => 'Deinen XP hinzugefügt';

  @override
  String get economyAdsOffPrivacy => 'Werbung ist deaktiviert. Ändere das unter Einstellungen > Datenschutz.';

  @override
  String get economyAiBusyRefunded =>
      'Die KI ist gerade stark ausgelastet. Versuch es später noch einmal. Deine Coins wurden zurückerstattet.';

  @override
  String get economyAiChargeUnconfirmed =>
      'Die Abbuchung konnte nicht bestätigt werden. Abgezogene Coins werden zurückerstattet.';

  @override
  String get economyAiCheckStatus => 'Status prüfen';

  @override
  String economyAiCoinsNeeded(int cost, int balance) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Du brauchst $costString Coins. Du hast $balanceString.';
  }

  @override
  String get economyAiConnectToGenerate =>
      'Keine Verbindung. Stell eine Internetverbindung her und versuche es erneut.';

  @override
  String get economyAiCouldNotConfirmSubmission =>
      'Die Einsendung konnte nicht bestätigt werden. Prüfe den Prüfstatus, bevor du es erneut versuchst.';

  @override
  String get economyAiCropMayDiffer => 'Der Zuschnitt kann auf deinem Gerät leicht abweichen.';

  @override
  String get aiLiveActivityGenerating => 'Dein Wallpaper wird erstellt';

  @override
  String get aiLiveActivityReady => 'Dein Wallpaper ist fertig';

  @override
  String get aiLiveActivityFailed => 'Konnte nicht erstellt werden';

  @override
  String get aiLiveActivityStale => 'Arbeitet noch daran';

  @override
  String get aiLiveActivityOpen => 'In Prism öffnen';

  @override
  String get economyAiDailyLimit => 'Du hast das heutige KI-Limit erreicht.';

  @override
  String get economyAiDescribeChanges =>
      'Beschreibe, was anders sein soll, zum Beispiel Farben, Stimmung oder Details.';

  @override
  String get economyAiDescribeScene => 'Beschreibe eine Szene, die erstellt werden soll.';

  @override
  String get economyAiDownloadFailed => 'Download fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String economyAiFailureWithRefund(String message, String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'refunded': ' Coins erstattet.',
      'pending': ' Rückerstattung ausstehend.',
      'other': ' Rückerstattung konnte nicht abgeschlossen werden.',
    });
    return '$message$_temp0';
  }

  @override
  String get economyAiGenerate => 'Erstellen';

  @override
  String get economyAiGenerateAnother => 'Weiteres erstellen';

  @override
  String get economyAiGenerateFailed => 'Das Erstellen ist gerade nicht möglich. Versuch es erneut.';

  @override
  String get economyAiGenerateGenericFailure => 'Etwas ist schiefgelaufen. Versuch es erneut.';

  @override
  String get economyAiGeneratedWallpaper => 'Erstelltes Hintergrundbild';

  @override
  String economyAiGenerationFrom(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get economyAiGenerationRollingOut =>
      'Die KI-Erstellung wird gerade schrittweise freigeschaltet. Versuch es bald noch einmal.';

  @override
  String get economyAiGenerationTime => 'Dauert etwa 20 Sekunden';

  @override
  String get economyAiHistoryEmpty =>
      'Hier erscheint jedes Hintergrundbild, das du erstellst. So kannst du es vergleichen oder zurückwechseln.';

  @override
  String get economyAiHistoryFailed => 'Verlauf konnte nicht geladen werden. Zieh zum Aktualisieren nach unten.';

  @override
  String get economyAiMatchingScreenSize => 'An deine Bildschirmgröße anpassen…';

  @override
  String get economyAiApplyingStyle => 'Dein Stil wird angewendet…';

  @override
  String get economyAiFinalizingWallpaper => 'Dein Hintergrundbild wird fertiggestellt…';

  @override
  String get economyAiRemixHint => 'Dunklerer Himmel, wärmere Farben, weichere Kanten…';

  @override
  String economyAiNeedCoinsToGenerate(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Zum Erstellen brauchst du $costString Coins.';
  }

  @override
  String economyNeedMoreCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dir fehlen noch $countString Coins.',
      one: 'Dir fehlt noch $countString Coin.',
    );
    return '$_temp0';
  }

  @override
  String get economyAiNoConnection => 'Keine Verbindung. Prüfe dein Netzwerk und versuche es erneut.';

  @override
  String get economyAiNoConnectionRetry => 'Keine Verbindung. Versuch es erneut.';

  @override
  String get economyAiOfflineHistory =>
      'Du bist offline oder das Netzwerk ist ausgefallen. Zieh zum Aktualisieren nach unten, wenn du wieder online bist.';

  @override
  String get economyAiOfflineSavedHistory => 'Du bist offline. Dein gespeicherter Verlauf ist weiterhin verfügbar.';

  @override
  String get economyAiPaymentCheckFailed => 'Zahlung konnte nicht geprüft werden. Deine Coins werden zurückerstattet.';

  @override
  String get economyAiPreparingShare => 'Teilen wird vorbereitet';

  @override
  String get economyAiPromptBlocked => 'Diese Beschreibung ist nicht zulässig.';

  @override
  String economyAiPromptTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Die Beschreibung ist zu lang (maximal $maximumString Zeichen).';
  }

  @override
  String get economyAiQuality => 'Qualität';

  @override
  String get economyAiQualityBalanced => 'Ausgewogen';

  @override
  String get economyAiQualityFast => 'Schnell';

  @override
  String get economyAiQualityHigh => 'Hohe Qualität';

  @override
  String economyAiQualitySemantics(String quality, int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '$quality, $costString Coins';
  }

  @override
  String get economyAiRecent => 'Zuletzt verwendet';

  @override
  String get economyAiRefineExplanation =>
      'Beschreibe, was sich ändern soll. So entsteht mit derselben Beschreibung und einem neuen Seed ein neues Hintergrundbild, das ganz anders aussehen kann.';

  @override
  String get economyAiResultBlocked => 'Das Ergebnis wurde blockiert. Versuch es mit einer anderen Beschreibung.';

  @override
  String economyAiRolloutBody(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Für $percentString% der Konten ist es bereits verfügbar. Versuch es bald noch einmal.';
  }

  @override
  String get economyAiRolloutTitle => 'KI-Hintergrundbilder werden nach und nach freigeschaltet';

  @override
  String get economyAiSave => 'Speichern';

  @override
  String get economyAiSaveFailed => 'Datei konnte nicht gespeichert werden. Versuch es erneut.';

  @override
  String get economyAiSceneIdea => 'Szenenidee';

  @override
  String get economyAiSceneIdeaMessage => 'Diese Szene in deiner Beschreibung verwenden (bearbeitbar)';

  @override
  String get economyAiSetAsWallpaper => 'Als Hintergrundbild festlegen';

  @override
  String get economyAiShare => 'Teilen';

  @override
  String get economyAiShareFailed => 'Teilen fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get economyAiShareReviewNotice =>
      'Moderator:innen prüfen Einsendungen, bevor sie auf Prism erscheinen. Teile nur Werke, an denen du die Rechte hast.';

  @override
  String get economyAiShareWithCommunity => 'Mit der Community teilen?';

  @override
  String get economyAiShuffle => 'Mischen';

  @override
  String get economyAiShuffleMessage => 'Eine neue Beispielbeschreibung anzeigen';

  @override
  String get economyAiStillWorking => 'Dein letztes Bild wird noch erstellt.';

  @override
  String get economyAiStyle => 'Stil';

  @override
  String get economyAiStyleAbstract => 'Abstrakt';

  @override
  String get economyAiStyleAnime => 'Anime';

  @override
  String get economyAiStyleCyberpunk => 'Cyberpunk';

  @override
  String get economyAiStyleMeshGradient => 'Mesh-Verlauf';

  @override
  String get economyAiStyleMinimal => 'Minimalistisch';

  @override
  String get economyAiStyleNature => 'Natur';

  @override
  String economyAiStyleSemantics(String style) {
    return 'Stil: $style';
  }

  @override
  String get economyAiStyleWatercolor => 'Aquarell';

  @override
  String get economyAiStyleSpace => 'Weltraum';

  @override
  String get economyAiStyleSynthwave => 'Synthwave';

  @override
  String get economyAiStylePixelArt => 'Pixel Art';

  @override
  String get economyAiStyleRender3d => '3D-Rendering';

  @override
  String get economyAiStyleOilPainting => 'Ölgemälde';

  @override
  String get economyAiStyleUkiyoE => 'Ukiyo-e';

  @override
  String get economyAiSubmissionUnconfirmed =>
      'Der Status der Einsendung ist unbestätigt. Prüfe ihn, bevor du es erneut versuchst.';

  @override
  String get economyAiSubmitDisabled => 'KI-Einsendungen sind derzeit deaktiviert.';

  @override
  String get economyAiSubmitFailed => 'Einsendung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get economyAiSubmitForReview => 'Zur Prüfung durch die Community einreichen';

  @override
  String get economyAiSubmitStatusUnconfirmed =>
      'Der Status der Einsendung ist unbestätigt. Prüfe den Prüfstatus, bevor du es erneut versuchst.';

  @override
  String get economyAiSubmittedForReview => 'Zur Prüfung eingereicht.';

  @override
  String get economyAiTryAgain => 'Erneut versuchen';

  @override
  String get economyAiTryAnother => 'Andere ausprobieren';

  @override
  String get economyAiTryAnotherVersion => 'Andere Version ausprobieren';

  @override
  String get economyAiUnavailableBody => 'Wir haben die Funktion kurzzeitig deaktiviert. Schau bald wieder vorbei.';

  @override
  String get economyAiUnavailableTitle => 'KI-Hintergrundbilder sind vorübergehend deaktiviert';

  @override
  String economyAiVariationTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Die Beschreibung ist zu lang (maximal $maximumString Zeichen).';
  }

  @override
  String get economyAiVariationUnavailable => '„Andere ausprobieren“ ist gerade nicht verfügbar.';

  @override
  String get economyAiWallpaper => 'KI-Hintergrundbild';

  @override
  String get economyAiWatermarkNote => 'Kostenlose Bilder tragen ein Prism-Wasserzeichen. Mit Pro wird es entfernt.';

  @override
  String get economyAllRankRewardsCollected => 'Alle Rangbelohnungen abgeholt';

  @override
  String get economyAllSpinsUsed => 'Alle Drehungen verbraucht';

  @override
  String get economyBackTomorrow => 'Morgen wieder da';

  @override
  String get economyBadge => 'Abzeichen';

  @override
  String get economyBadgeAiArtist => 'KI-Künstler:in';

  @override
  String get economyBadgeAiArtistDescription => '10 KI-Hintergrundbilder erstellen';

  @override
  String get economyBadgeArtCurator => 'Kunstkurator:in';

  @override
  String get economyBadgeArtCuratorDescription => '50 Hintergrundbilder favorisieren';

  @override
  String get economyBadgeCollector => 'Sammler:in';

  @override
  String get economyBadgeCollectorDescription => '10 Hintergrundbilder favorisieren';

  @override
  String get economyBadgeCreator => 'Creator';

  @override
  String get economyBadgeCreatorDescription => 'Ein Hintergrundbild genehmigen lassen';

  @override
  String get economyBadgeDescription => 'Ein Abzeichen in Prism';

  @override
  String get economyBadgeEarned => 'Abzeichen verdient';

  @override
  String economyBadgeEarnedCount(int count, int total) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$countString von $totalString verdient';
  }

  @override
  String economyBadgeName(String name) {
    return 'Abzeichen „$name“';
  }

  @override
  String get economyBadgePrismVeteran => 'Prism-Veteran:in';

  @override
  String get economyBadgePrismVeteranDescription => 'Prism 30 Tage lang nutzen und eine 7-Tage-Serie erreichen';

  @override
  String get economyBadgeProfileComplete => 'Profil vollständig';

  @override
  String get economyBadgeProfileCompleteDescription => 'Foto, Benutzername, Bio und Link hinzufügen';

  @override
  String economyBadgeSemantics(String name, String status, String description) {
    return '$name, $status. $description';
  }

  @override
  String get economyBadgeSocialButterfly => 'Kontaktfreudig';

  @override
  String get economyBadgeSocialButterflyDescription => '10 Creator folgen';

  @override
  String get economyBadgeStatusEarned => 'Verdient';

  @override
  String get economyBadgeStatusLocked => 'Gesperrt';

  @override
  String get economyBadgeStreakMaster => 'Serienprofi';

  @override
  String get economyBadgeStreakMasterDescription => 'Eine 28-Tage-Serie erreichen';

  @override
  String get economyBadgeWeekWarrior => 'Wochenkrieger:in';

  @override
  String get economyBadgeWeekWarriorDescription => 'Eine 7-Tage-Serie erreichen';

  @override
  String get economyBadges => 'Abzeichen';

  @override
  String economyBalanceSemantics(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString Prism Coins';
  }

  @override
  String economyBestStreak(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Tage', one: '1 Tag');
    return 'Beste Serie: $_temp0';
  }

  @override
  String get economyBoost => 'Boost';

  @override
  String economyBoostInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Setze eines deiner genehmigten Hintergrundbilder an den Anfang der Trendseite. Ein Boost kostet $amountString Coins. Öffne dein Hintergrundbild und tippe auf „Boost“.';
  }

  @override
  String get economyBuildStreakDaily => 'Öffne Prism jeden Tag, um deine Serie aufzubauen.';

  @override
  String get economyBuy => 'Kaufen';

  @override
  String get economyBuyPremium => 'Premium kaufen';

  @override
  String get economyCancel => 'Abbrechen';

  @override
  String get economyChestBonusDone => 'Bonus-Aufgabe erledigt: Deine Coins wurden verdoppelt.';

  @override
  String get economyChestBonusToDouble => 'Erledige zuerst die heutige Bonus-Aufgabe, um deine Coins zu verdoppeln.';

  @override
  String economyChestBoosterSemantics(String title, String caption) {
    return '$title. $caption';
  }

  @override
  String economyChestCoinsPrize(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString Coins', one: '1 Coin');
    return '$_temp0';
  }

  @override
  String get economyChestDoFirst => 'Erledige das zuerst, um deine Truhe zu verdoppeln';

  @override
  String get economyChestDoubled => 'Truhe verdoppelt';

  @override
  String get economyChestDoubledByBonus => ' Durch deine Bonus-Aufgabe verdoppelt.';

  @override
  String get economyChestFreeToday => 'Heute kostenlos';

  @override
  String economyChestNeedCoins(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Die Truhe kostet $priceString Coins. Du hast $balanceString. Sieh dir ein Video an, um mehr zu verdienen.';
  }

  @override
  String economyChestNewCosmetic(String kind, String name) {
    return 'neues $kind: $name';
  }

  @override
  String economyChestNewKind(String kind) {
    return 'Neu: $kind';
  }

  @override
  String get economyChestOpenFailed => 'Prism konnte nicht erreicht werden. Versuch es erneut.';

  @override
  String economyChestOpenFor(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Aufgaben', one: '1 Aufgabe');
    return 'Öffne sie für $priceString Coins oder erledige noch $_temp0, um sie kostenlos zu öffnen.';
  }

  @override
  String get economyChestOpened => 'Geöffnet';

  @override
  String get economyChestOpenedDoubledTomorrow => 'Geöffnet und verdoppelt. Morgen gibt es eine neue.';

  @override
  String economyChestOpenedReset(String time) {
    return 'Geöffnet. Eine neue Truhe gibt es in $time.';
  }

  @override
  String get economyChestOpenedTomorrow => 'Geöffnet. Morgen gibt es eine neue Truhe.';

  @override
  String get economyChestOwnCosmeticCoins => 'Du besitzt alle kosmetischen Extras. Deshalb gibt es Coins.';

  @override
  String get economyChestOwnEveryCosmetic => 'Du besitzt alle kosmetischen Extras.';

  @override
  String get economyChestPriceChanged => 'Der Preis hat sich geändert. Prüfe ihn und öffne die Truhe erneut.';

  @override
  String economyChestPriceFreeAfter(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString weiteren Aufgaben',
      one: '1 weiteren Aufgabe',
    );
    return '$priceString Coins oder kostenlos nach $_temp0';
  }

  @override
  String economyChestPrizeSemantics(String tier, String prize, String doubled, int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(doubled, {'true': ' Durch deine Bonus-Aufgabe verdoppelt.', 'other': ''});
    String _temp1 = intl.Intl.pluralLogic(
      xp,
      locale: localeName,
      other: ' Dazu $xpString XP.',
      one: ' Dazu 1 XP.',
      zero: '',
    );
    return '$tier. Du hast $prize gewonnen.$_temp0$_temp1';
  }

  @override
  String get economyChestQuestsFree => 'Durch deine Aufgaben ist sie heute kostenlos.';

  @override
  String get economyChestReady => 'Bereit zum Öffnen';

  @override
  String economyChestReadyPaid(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Bereit zum Öffnen. $doneString von $totalString Aufgaben erledigt';
  }

  @override
  String economyChestResetHours(int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$hoursString Std.';
  }

  @override
  String economyChestResetHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$hoursString Std. $minutesString Min.';
  }

  @override
  String economyChestResetMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$minutesString Min.';
  }

  @override
  String get economyChestTierCommon => 'Gewöhnlich';

  @override
  String get economyChestTierEpic => 'Episch';

  @override
  String get economyChestTierLegendary => 'Legendär';

  @override
  String get economyChestTierRare => 'Selten';

  @override
  String economyChestXpLine(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Beim Öffnen erhältst du $xpString XP.';
  }

  @override
  String get economyClaimedTodayDay7Chest => 'Für heute bist du fertig. Komm morgen für deine Truhe an Tag 7 wieder.';

  @override
  String economyClaimedTodayReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Für heute bist du fertig. Komm morgen für +$coinsString Coins wieder.';
  }

  @override
  String get economyClosePreview => 'Vorschau schließen';

  @override
  String economyCoinActivitySemantics(String label, String date, String amount, int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'Coins', one: 'Coin');
    return '$label, $date, $amount $_temp0';
  }

  @override
  String economyCoinBalance(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Guthaben $balanceString';
  }

  @override
  String economyCoinGateRefundUnconfirmed(String action) {
    return '$action. Deine Rückerstattung konnte nicht bestätigt werden.';
  }

  @override
  String economyCoinGateRefunded(String action, int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString Coins erstattet.',
      one: '1 Coin erstattet.',
    );
    return '$action. $_temp0';
  }

  @override
  String get economyCoinHistoryEarned => 'Verdient';

  @override
  String get economyCoinHistoryEmpty => 'Noch keine Coin-Aktivitäten.';

  @override
  String get economyCoinHistoryLoadFailed => 'Dein Coin-Verlauf konnte nicht geladen werden.';

  @override
  String get economyCoinHistoryNoLoadedRows => 'In den bisher geladenen Einträgen ist nichts zu sehen.';

  @override
  String get economyCoinHistoryNothingHere => 'Hier gibt es noch nichts.';

  @override
  String get economyCoinHistoryRefunds => 'Rückerstattungen';

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
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'Coins', one: 'Coin');
    return '$label$_temp0, $date, $amount $_temp1, $balance';
  }

  @override
  String get economyCoinHistorySpent => 'Ausgegeben';

  @override
  String get economyCoinHistoryTitle => 'Coin-Verlauf';

  @override
  String get economyCoinSpendFailed => 'Coins können gerade nicht verarbeitet werden.';

  @override
  String economyCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Coins', one: '1 Coin');
    return '$_temp0';
  }

  @override
  String get economyCoinsAreYoursToSpend => 'Du kannst deine Coins ausgeben';

  @override
  String economyCoinsEarned(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Coins', one: '1 Coin');
    return '+$_temp0';
  }

  @override
  String economyCoinsRange(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '+$minimumString bis +$maximumString';
  }

  @override
  String get economyCoinsSpendingDetails =>
      'Mit Coins bezahlst du Hintergrundbilder, Tools und Shop-Artikel. XP zeigen deinen Fortschritt und sind kein ausgebbares Guthaben. Wenn du Coins ausgibst, sinken deine XP nicht.';

  @override
  String get economyCoinsWhatYouCanDo => 'Was du damit machen kannst';

  @override
  String get economyCoinsWord => 'Coins';

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
      'true': ', oder nutze $coinsString Coins, um es jetzt freizuschalten',
      'other': '',
    });
    return 'Halte deine Serie $daysString Tage lang aufrecht, um dieses Hintergrundbild freizuschalten$_temp0.';
  }

  @override
  String get economyCollectionLoadFailed => 'Diese Sammlung konnte nicht geladen werden.';

  @override
  String economyCollectionNeedCoinsMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Du brauchst $coinsString Coins, um dieses Hintergrundbild freizuschalten.';
  }

  @override
  String get economyCollectionRequirementsUnmet => 'Dieses Hintergrundbild ist noch nicht verfügbar.';

  @override
  String get economyCollectionStillLocked => 'Noch gesperrt';

  @override
  String economyCollectionUnlockedAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Mit einer $daysString-Tage-Serie freigeschaltet';
  }

  @override
  String get economyCollectionUnlockedWithCoins => 'Mit Coins freigeschaltet';

  @override
  String economyCollectionUnlocksAtCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Für $coinsString Coins freischaltbar';
  }

  @override
  String economyCollectionUnlocksAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Mit einer $daysString-Tage-Serie freischaltbar';
  }

  @override
  String get economyCompleteProfile => 'Vervollständige dein Profil';

  @override
  String get economyCosmetic => 'kosmetisches Extra';

  @override
  String get economyCosmeticAppIcon => 'App-Symbol';

  @override
  String get economyCosmeticFrame => 'Rahmen';

  @override
  String get economyCosmeticNameGlow => 'Namensleuchten';

  @override
  String get economyCosmeticTheme => 'Design';

  @override
  String economyCountdownDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$daysString T. $hoursString Std.';
  }

  @override
  String economyCountdownHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$hoursString Std. $minutesString Min.';
  }

  @override
  String economyCountdownMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$minutesString Min.';
  }

  @override
  String get economyCreatorApprovedWalls => 'Genehmigte Hintergrundbilder';

  @override
  String get economyCreatorIntro =>
      'Verdiene XP, wenn deine Hintergrundbilder genehmigt werden und neue Mitglieder sie favorisieren. Dein Fortschritt wird nach deinem ersten qualifizierenden Beitrag angezeigt.';

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
    return 'Meilenstein: $label';
  }

  @override
  String get economyCreatorMilestones => 'Creator-Meilensteine';

  @override
  String economyCreatorMilestonesComplete(String label) {
    return 'Meilensteine für $label abgeschlossen';
  }

  @override
  String economyCreatorNewMembersThisWeek(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Diese Woche haben $countString neue Mitglieder deine Hintergrundbilder favorisiert.';
  }

  @override
  String economyCreatorNextMilestone(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Nächster Meilenstein: +$xpString XP';
  }

  @override
  String economyCreatorProgressSemantics(int current, int target) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$currentString von $targetString';
  }

  @override
  String get economyCreatorQualifyingMembers => 'Qualifizierende Mitglieder';

  @override
  String get economyCreatorRefresh => 'Fortschritt aktualisieren';

  @override
  String get economyCreatorRefreshing => 'Creator-Fortschritt wird aktualisiert…';

  @override
  String get economyCreatorRules =>
      'Genehmigte Hintergrundbilder müssen eigene, teilnahmeberechtigte Uploads sein. Ältere Uploads zählen möglicherweise nicht, wenn Prism den ursprünglichen Upload nicht verifizieren kann. Jedes andere Mitglied zählt über alle deine teilnahmeberechtigten Werke hinweg einmal, wenn es erstmals ein qualifizierendes Hintergrundbild favorisiert. Das Mitglied muss angemeldet sein, eine bestätigte E-Mail-Adresse und ein mindestens sieben Tage altes Konto haben. Deine eigenen Favoriten zählen nicht. Die Zahlen zeigen vergangene Aktivitäten, nicht dein aktuelles Publikum. Wenn Favoriten entfernt werden, gehen XP nicht verloren. Für Creator-Meilensteine gibt es zusätzliche XP. Die Wochen laufen von Montag bis Sonntag nach UTC. Verspätete Aktivitäten können in einer späteren Woche erscheinen.';

  @override
  String get economyCreatorSavedRefresh => 'Fortschritt gespeichert. Aktualisiere ihn, um die neuesten Werte zu sehen.';

  @override
  String get economyCreatorSavedUnavailable => 'Fortschritt gespeichert. Aktualisieren ist nicht verfügbar.';

  @override
  String economyCreatorThisWeekSummary(int walls, int xp) {
    final intl.NumberFormat wallsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String wallsString = wallsNumberFormat.format(walls);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$wallsString teilnahmeberechtigte Hintergrundbilder genehmigt · $xpString Meilenstein-XP';
  }

  @override
  String economyCreatorTrackingSince(String date) {
    return 'Erfasst seit $date UTC';
  }

  @override
  String get economyCreatorUnavailable => 'Creator-Fortschritt ist nicht verfügbar.';

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

    return '$wallsString teilnahmeberechtigte Hintergrundbilder genehmigt · $membersString neue qualifizierende Mitglieder · $xpString Meilenstein-XP';
  }

  @override
  String get economyCreatorWhatCounts => 'Was zählt und Verlauf';

  @override
  String get economyDailyChest => 'Tägliche Truhe';

  @override
  String economyDailyChestSemantics(String state, String caption, String hasXp, String xpLine) {
    String _temp0 = intl.Intl.selectLogic(hasXp, {'true': '. $xpLine', 'other': ''});
    return 'Tägliche Truhe, $state. $caption$_temp0';
  }

  @override
  String get economyDailyChestTitle => 'Tägliche Truhe';

  @override
  String get economyDailyQuests => 'Tägliche Aufgaben';

  @override
  String get economyDailyStreak => 'Tägliche Serie';

  @override
  String get economyDay7Chest => 'Truhe an Tag 7';

  @override
  String economyDayLabel(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Tag $dayString';
  }

  @override
  String economyDayStreakMilestone(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return '$daysString-Tage-Serie!';
  }

  @override
  String economyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Tage', one: 'Tag');
    return '$_temp0';
  }

  @override
  String economyDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Tagen', one: '1 Tag');
    return 'Vor $_temp0';
  }

  @override
  String get economyDownload => 'Herunterladen';

  @override
  String get economyDownloadAccountChanged => 'Konto gewechselt. Bitte speichere es erneut.';

  @override
  String get economyDownloadAgain => 'Erneut herunterladen';

  @override
  String economyDownloadAgainCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Erneut herunterladen (-$costString Coins)';
  }

  @override
  String get economyDownloadAlreadyInDownloads => 'Bereits in den Downloads';

  @override
  String economyDownloadCoinsNeeded(int missing, int reward, String watch, String adState) {
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(watch, {'true': ' Pro Werbung erhältst du $rewardString.', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(adState, {
      'disabled': ' Werbung ist deaktiviert. Ändere das unter Einstellungen > Datenschutz.',
      'limit': ' Tageslimit erreicht. Morgen geht\'s weiter.',
      'other': '',
    });
    return 'Du brauchst noch $missingString Coins, um dieses Hintergrundbild zu speichern.$_temp0$_temp1';
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

    return '$label. Kostet $costString Coins';
  }

  @override
  String get economyDownloadFailedLabel => 'Download fehlgeschlagen';

  @override
  String economyDownloadFreeDownloadsLeftSemantics(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString kostenlose Downloads',
      one: '1 kostenloser Download',
    );
    return '$label. Kostenlos, noch $_temp0';
  }

  @override
  String economyDownloadFreeFor(String label) {
    return '$label · Kostenlos';
  }

  @override
  String economyDownloadFreeLeftFor(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label · Kostenlos · noch $countString';
  }

  @override
  String economyDownloadFreeOwnedSemantics(String label) {
    return '$label. Kostenlos, dieses Hintergrundbild gehört dir';
  }

  @override
  String economyDownloadFreeWithPassSemantics(String label) {
    return '$label. Mit deinem Pass kostenlos';
  }

  @override
  String get economyDownloadFreeWithPro => 'Mit Pro kostenlos';

  @override
  String economyDownloadFreeWithProSemantics(String label) {
    return '$label. Mit Pro kostenlos';
  }

  @override
  String get economyDownloadLinkUnavailable => 'Kein Download-Link verfügbar.';

  @override
  String get economyDownloadProGuestMessage =>
      'Melde dich an, um dieses Hintergrundbild mit Coins zu speichern, oder hol dir Prism Pro.';

  @override
  String get economyDownloadSaveLocalCopy => 'Lokale Kopie speichern';

  @override
  String get economyDownloadSaved => 'Gespeichert';

  @override
  String get economyDownloadSavedBefore => 'Du hast dieses Hintergrundbild bereits gespeichert.';

  @override
  String get economyDownloadSavedInDownloads => 'Gespeichert. Bereits in den Downloads';

  @override
  String get economyDownloadThisWallpaper => 'Dieses Hintergrundbild herunterladen';

  @override
  String get economyDownloadWaitForCurrent => 'Warte, bis der Download abgeschlossen ist!';

  @override
  String get economyDownloadWatchAdMessage =>
      'Sieh dir eine kurze Werbeanzeige an, um dieses Hintergrundbild herunterzuladen.';

  @override
  String get economyDownloadWatchAdPrivacyMessage =>
      'Sieh dir eine kurze Werbeanzeige an, um dieses Hintergrundbild herunterzuladen. Werbung ist deaktiviert. Ändere das unter Einstellungen > Datenschutz.';

  @override
  String get economyDownloads => 'Downloads';

  @override
  String economyDownloadsInfo(int amount, int freeCount, String hasFree) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat freeCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String freeCountString = freeCountNumberFormat.format(freeCount);

    String _temp0 = intl.Intl.selectLogic(hasFree, {
      'true': ' Deine ersten $freeCountString Downloads sind kostenlos.',
      'other': '',
    });
    return 'Jeder Download eines Hintergrundbilds kostet $amountString Coins.$_temp0 Mit Pro sind Downloads kostenlos.';
  }

  @override
  String economyDrawAllTicketsHeld(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Du hast diese Woche bereits alle $maximumString Tickets.';
  }

  @override
  String economyDrawBuyTicket(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Ticket kaufen · $priceString';
  }

  @override
  String get economyDrawClosed => 'Diese Ziehung ist geschlossen. Die nächste beginnt am Montag.';

  @override
  String economyDrawClosesIn(String time) {
    return 'Endet in $time';
  }

  @override
  String get economyDrawLastWinner => 'Letzte Gewinner:in';

  @override
  String get economyDrawLoadFailed => 'Die Ziehung konnte nicht geladen werden.';

  @override
  String get economyDrawNotEnoughCoins => 'Nicht genug Coins für ein Ticket.';

  @override
  String get economyDrawNotOpen => 'Die Ziehung hat noch nicht begonnen.';

  @override
  String get economyDrawOfficialRules => 'Offizielle Regeln';

  @override
  String economyDrawPrizeDescription(int months) {
    final intl.NumberFormat monthsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(months, locale: localeName, other: '$monthsString Monate', one: '1 Monat');
    return '$_temp0 Pro + der Prism-Rahmen';
  }

  @override
  String get economyDrawProNotEligible => 'Pro-Mitglieder sind nicht teilnahmeberechtigt.';

  @override
  String get economyDrawPurchaseFailed => 'Ticket konnte nicht gekauft werden. Versuch es erneut.';

  @override
  String get economyDrawThisWeeksPrize => 'DIESWÖCHIGER GEWINN';

  @override
  String economyDrawTicketBought(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Ticket gekauft. Du hast $ticketsString von $maximumString.';
  }

  @override
  String economyDrawTicketCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Tickets kosten $priceString Coins';
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
      other: '$ticketsString Tickets',
      one: '1 Ticket',
    );
    String _temp1 = intl.Intl.pluralLogic(people, locale: localeName, other: '$peopleString Personen', one: '1 Person');
    return '$_temp0 von $_temp1';
  }

  @override
  String get economyDrawTitle => 'Prism-Verlosung';

  @override
  String economyDrawYourChance(int mine, int pot) {
    final intl.NumberFormat mineNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String mineString = mineNumberFormat.format(mine);
    final intl.NumberFormat potNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String potString = potNumberFormat.format(pot);

    return 'Deine Chance: $mineString/$potString';
  }

  @override
  String economyDrawYourTickets(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Deine Tickets: $ticketsString von $maximumString';
  }

  @override
  String get economyDropAlreadyUnlocked => 'Du hast dieses Hintergrundbild bereits.';

  @override
  String economyDropByCreator(String creator) {
    return 'von $creator';
  }

  @override
  String economyDropCardSemantics(String time, int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Wöchentlicher Drop, $time, $unlockedString von $totalString gesammelt';
  }

  @override
  String economyDropCarouselDetail(int count, String time) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Hintergrundbilder',
      one: '1 Hintergrundbild',
    );
    return '$_temp0 · $time';
  }

  @override
  String economyDropCarouselSemantics(String title, String detail, String lastCall) {
    String _temp0 = intl.Intl.selectLogic(lastCall, {'true': ', letzter Aufruf', 'other': ''});
    return 'Wöchentlicher Drop, $title, $detail$_temp0';
  }

  @override
  String economyDropCollected(int owned, int total) {
    final intl.NumberFormat ownedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ownedString = ownedNumberFormat.format(owned);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$ownedString von $totalString gesammelt';
  }

  @override
  String economyDropDates(String start, String end) {
    return '$start bis $end';
  }

  @override
  String get economyDropEnded => 'Beendet';

  @override
  String get economyDropEndedHeadline => 'Dieser Drop ist beendet';

  @override
  String economyDropEndsInDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$daysString T.', one: '1 T.');
    String _temp1 = intl.Intl.pluralLogic(hours, locale: localeName, other: '$hoursString Std.', one: '1 Std.');
    return 'Endet in $_temp0 $_temp1';
  }

  @override
  String economyDropEndsInHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(hours, locale: localeName, other: '$hoursString Std.', one: '1 Std.');
    String _temp1 = intl.Intl.pluralLogic(minutes, locale: localeName, other: '$minutesString Min.', one: '1 Min.');
    return 'Endet in $_temp0 $_temp1';
  }

  @override
  String economyDropEndsInMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return 'Endet in $minutesString Min.';
  }

  @override
  String get economyDropGone => 'Dieser Drop ist nicht mehr verfügbar';

  @override
  String get economyDropLastCallLabel => 'Letzter Aufruf';

  @override
  String get economyDropLoadFailed => 'Der Drop konnte nicht geladen werden.';

  @override
  String get economyDropLocked => 'Gesperrt';

  @override
  String get economyDropMissed => 'Verpasst';

  @override
  String get economyDropOver => 'Dieser Drop ist vorbei.';

  @override
  String get economyDropPastDrops => 'Vergangene Drops';

  @override
  String economyDropPosition(int index, int total) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$indexString von $totalString';
  }

  @override
  String get economyDropPreviewTitle => 'Drop-Vorschau';

  @override
  String get economyDropRename => 'Drop umbenennen';

  @override
  String get economyDropRenameFailed => 'Der Drop konnte nicht umbenannt werden. Versuch es erneut.';

  @override
  String get economyDropRenameHint => 'Name des Drops';

  @override
  String get economyDropRenamed => 'Drop umbenannt';

  @override
  String economyDropSave(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString sparen';
  }

  @override
  String economyDropStats(String walls, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Sammler:innen',
      one: '1 Sammler:in',
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

    return 'Alle $countString für $priceString freischalten';
  }

  @override
  String get economyDropUnlockFailed => 'Freischalten fehlgeschlagen. Versuch es erneut.';

  @override
  String economyDropUnlockFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Für $priceString freischalten';
  }

  @override
  String economyDropUnlockWall(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Dieses Hintergrundbild für $priceString freischalten';
  }

  @override
  String get economyDropUnlocked => 'Freigeschaltet';

  @override
  String economyDropUnlockedCount(int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$unlockedString/$totalString freigeschaltet';
  }

  @override
  String economyDropUnlockedCountToast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Hintergrundbilder freigeschaltet',
      one: 'Hintergrundbild freigeschaltet',
    );
    return '$_temp0';
  }

  @override
  String get economyDropUnlockedWall => 'Hintergrundbild freigeschaltet';

  @override
  String economyDropUnlockedWallBy(String creator) {
    return 'Hintergrundbild von $creator freigeschaltet';
  }

  @override
  String economyDropWallBySemantics(String state, String serial, String creator) {
    return '$state Hintergrundbild $serial von $creator';
  }

  @override
  String economyDropWallCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Hintergrundbilder',
      one: '1 Hintergrundbild',
    );
    return '$_temp0';
  }

  @override
  String economyDropWallSemantics(String state, String serial) {
    return '$state Hintergrundbild $serial';
  }

  @override
  String get economyDropWallpaperUnavailable => 'Dieses Hintergrundbild ist nicht verfügbar.';

  @override
  String economyDropWeekOf(String date) {
    return 'Woche vom $date';
  }

  @override
  String get economyDropYourVault => 'Dein Archiv';

  @override
  String get economyDrops => 'Drops';

  @override
  String get economyEarnCoins => 'Coins verdienen';

  @override
  String get economyEarnXpAsYouGo => 'Nebenbei XP verdienen';

  @override
  String economyEarnedAtRank(String rank) {
    return 'Mit Rang $rank verdient';
  }

  @override
  String get economyEquipped => 'Ausgerüstet';

  @override
  String get economyEveryChestPays => 'Jede Truhe enthält eine Belohnung.';

  @override
  String get economyEverySpinPays => 'Bei jeder Drehung gewinnst du etwas.';

  @override
  String economyFallbackCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Du erhältst $countString Coins, wenn du bereits alle besitzt.';
  }

  @override
  String economyFinishDay7Chest(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Schließe Tag 7 ab und erhalte eine Truhe mit +$minimumString bis +$maximumString';
  }

  @override
  String get economyFinishStreakWeek => 'Schließe eine Woche mit Serientagen ab.';

  @override
  String economyFirstDownloadsFree(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Die ersten $countString kostenlos';
  }

  @override
  String get economyFirstUpload => 'Erster Upload';

  @override
  String get economyFreeDailySpin => 'Tägliche kostenlose Drehung';

  @override
  String economyFreeDownloadsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Noch $countString kostenlos';
  }

  @override
  String get economyFreeSpin => 'Kostenlose Drehung';

  @override
  String economyFreeSpinReady(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '. Heute noch $countString kostenpflichtige Drehungen.',
      one: '. Heute noch 1 kostenpflichtige Drehung.',
      zero: '',
    );
    return 'Kostenlose Drehung bereit$_temp0';
  }

  @override
  String get economyFreezeAdded => 'Serien-Schutz hinzugefügt.';

  @override
  String economyFreezeAlreadyAtLimit(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Tage', one: '1 Tag');
    return 'Dein Serien-Schutz reicht bereits für $_temp0.';
  }

  @override
  String economyFreezeBalanceAfter(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Guthaben danach: $balanceString';
  }

  @override
  String economyFreezeBuyConfirm(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Serien-Schutz für $costString Coins kaufen?';
  }

  @override
  String get economyFreezeBuyFailed => 'Serien-Schutz konnte nicht gekauft werden. Versuch es erneut.';

  @override
  String economyFreezeCount(int held, int total) {
    final intl.NumberFormat heldNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String heldString = heldNumberFormat.format(held);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$heldString von $totalString';
  }

  @override
  String get economyFreezeDescription =>
      'Sichert deine Serie, wenn du einen Tag verpasst. Wird automatisch angewendet.';

  @override
  String get economyFreezeFull => 'Voll';

  @override
  String economyFreezeGetOne(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Einen holen · $costString';
  }

  @override
  String get economyFreezeHeld => 'Serien-Schutz vorhanden';

  @override
  String economyFreezeNeedCoins(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Du brauchst $costString Coins.';
  }

  @override
  String get economyFreezeSlotEmpty => 'Leerer Serien-Schutz-Platz';

  @override
  String get economyFreezeUnavailable => 'Serien-Schutz ist gerade nicht verfügbar. Versuch es später erneut.';

  @override
  String get economyFreshLeaderboardDetails =>
      'Die Rangliste basiert auf wöchentlichen XP und wird jeden Montag um 00:00 UTC zurückgesetzt. Deine gesamten XP, dein Rang und deine verdienten kosmetischen Extras bleiben erhalten.';

  @override
  String get economyFreshLeaderboardWeekly => 'Jede Woche eine neue Rangliste';

  @override
  String get economyGetCoins => 'Coins holen';

  @override
  String economyGetCoinsChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Coins holen. Die Truhe kostet $priceString Coins';
  }

  @override
  String economyGetCoinsForSpin(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Coins holen. Eine Drehung kostet $priceString Coins';
  }

  @override
  String get economyGetFreezeNextTime => 'Serien-Schutz fürs nächste Mal holen';

  @override
  String get economyGetPro => 'Pro holen';

  @override
  String get economyGiftPass => 'Pass verschenken';

  @override
  String economyGiftPassInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Schenke einem Freund für $amountString Coins 24 Stunden lang Pro-Inhalte. Öffne das Profil und tippe auf „24-Stunden-Pass verschenken“.';
  }

  @override
  String get economyGotIt => 'Alles klar';

  @override
  String economyHighestRankReached(String rank) {
    return 'Höchster Rang erreicht: $rank';
  }

  @override
  String get economyHighestRankReachedShort => 'Höchster Rang erreicht';

  @override
  String get economyHomeScreen => 'Startbildschirm';

  @override
  String get economyInviteFriend => 'Freund einladen';

  @override
  String get economyJackpotAddedToBalance => 'Jackpot! Deinem Guthaben hinzugefügt';

  @override
  String get economyKeepStreakToday => 'Öffne Prism heute, damit deine Serie weiterläuft.';

  @override
  String get economyLastWeek => 'Letzte Woche';

  @override
  String economyLeaderboardEntrySemantics(int position, String name, String isMe, int xp, String hasRank, String rank) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(isMe, {'true': ', du', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(hasRank, {'true': ', Rang auf Lebenszeit: $rank', 'other': ''});
    return '$positionString, $name$_temp0, diese Woche $xpString XP$_temp1';
  }

  @override
  String get economyLeaderboardFollowTip =>
      'Dein Ergebnis ist dabei. Folge Creator:innen, um wöchentliche XP zu vergleichen.';

  @override
  String get economyLeaderboardFollowToSee => 'Folge Creator:innen, um sie hier zu sehen.';

  @override
  String get economyLeaderboardFollowing => 'Ich folge';

  @override
  String get economyLeaderboardFriendsCaption =>
      'Du und die Personen, denen du folgst · zum Aktualisieren nach unten ziehen';

  @override
  String get economyLeaderboardFriendsDetails =>
      'Enthält dein Ergebnis und bis zu die ersten 90 Konten, denen du folgst. Gelöschte Konten werden ausgelassen, ein Mindestalter für Konten gibt es nicht. Ergebnisse werden geladen, wenn du diesen Tab zum ersten Mal öffnest. Zum Aktualisieren nach unten ziehen. Dein Ergebnis basiert auf deinen zuletzt synchronisierten XP.';

  @override
  String get economyLeaderboardGlobal => 'Global';

  @override
  String get economyLeaderboardGlobalCaption => 'Top 50 · etwa alle 3 Stunden aktualisiert';

  @override
  String get economyLeaderboardGlobalDetails =>
      'Zeigt bis zu 50 Konten nach wöchentlichen XP. Konten müssen mindestens 7 Tage alt sein. Gelöschte Konten werden ausgelassen. Der Stand wird etwa alle 3 Stunden aktualisiert, deshalb können neue XP verspätet erscheinen. Wenn du zum Aktualisieren nach unten ziehst, wird der neueste Stand geladen.';

  @override
  String get economyLeaderboardHowScoringWorks => 'So funktioniert die Ranglistenwertung';

  @override
  String get economyLeaderboardLoadFailed => 'Rangliste konnte nicht geladen werden.';

  @override
  String get economyLeaderboardNoRankings => 'Noch keine Rangliste';

  @override
  String get economyLeaderboardOffline =>
      'Wenn du offline bist, werden möglicherweise gespeicherte Ergebnisse angezeigt.';

  @override
  String get economyLeaderboardRankedByXp => 'Sortiert nach den diese Woche verdienten XP';

  @override
  String economyLeaderboardReset(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$daysString T.', one: '1 T.');
    String _temp1 = intl.Intl.pluralLogic(hours, locale: localeName, other: '$hoursString Std.', one: '1 Std.');
    return 'Wird Montag um 00:00 UTC zurückgesetzt · noch $_temp0 $_temp1';
  }

  @override
  String get economyLeaderboardScoringIntro =>
      'Die Plätze richten sich nach den diese Woche verdienten XP. Rangbezeichnungen wie Silber richten sich nach den gesamten XP. Wöchentliche XP werden montags um 00:00 UTC zurückgesetzt. Deine gesamten XP und dein Rang bleiben bestehen.';

  @override
  String get economyLeaderboardTitle => 'Rangliste';

  @override
  String get economyLifetimePermanentDetails =>
      'Deine gesamten XP bestimmen deinen Rang und werden nie zurückgesetzt. Kosmetische Rangbelohnungen landen automatisch in deinem Inventar, kosten keine Coins und bleiben dauerhaft bei dir. Im Shop entscheidest du, wann du sie ausrüstest.';

  @override
  String get economyLifetimePermanentRewards => 'Dauerhafter Fortschritt, bleibende Belohnungen';

  @override
  String economyLifetimeXp(String xp) {
    return '$xp XP insgesamt';
  }

  @override
  String get economyLifetimeXpNeverResets => 'Deine gesamten XP werden nie zurückgesetzt.';

  @override
  String get economyLoadingVideo => 'Video wird geladen';

  @override
  String get economyLockScreen => 'Sperrbildschirm';

  @override
  String get economyMystery => 'Überraschung';

  @override
  String get economyMysteryCosmetic => 'Überraschungs-Extra';

  @override
  String get economyNewBadge => 'Neues Abzeichen';

  @override
  String economyNewCosmetic(String kind, String name) {
    return 'Neues $kind: $name';
  }

  @override
  String get economyNewUnknownCosmetic => 'Neues kosmetisches Extra';

  @override
  String get economyNextDropMonday => 'Der nächste Drop erscheint am Montag.';

  @override
  String economyNextReward(String reward) {
    return 'Nächste Belohnung: $reward';
  }

  @override
  String get economyNice => 'Super';

  @override
  String get economyNoDropNow => 'Aktuell kein Drop';

  @override
  String get economyNoSpinsLeft => 'Heute keine Drehungen mehr übrig.';

  @override
  String get economyNotEnoughCoins => 'Nicht genug Coins';

  @override
  String get economyNotNow => 'Nicht jetzt';

  @override
  String economyOddsTierSemantics(String tier, String odds) {
    return '$tier, $odds';
  }

  @override
  String get economyOddsTitle => 'Gewinnchancen';

  @override
  String get economyOnceADay => 'Einmal täglich';

  @override
  String get economyOpen => 'Öffnen';

  @override
  String economyOpenChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Truhe öffnen, $priceString Coins';
  }

  @override
  String get economyOpenChestFree => 'Truhe kostenlos öffnen';

  @override
  String get economyOpenChestLoading => 'Truhe öffnen. Wird geladen';

  @override
  String get economyOpenDaily => 'Öffne Prism jeden Tag.';

  @override
  String economyOpenDailyPro(String multiplier) {
    return 'Öffne Prism jeden Tag. Mit Pro erhältst du x$multiplier.';
  }

  @override
  String get economyOpenFree => 'Kostenlos öffnen';

  @override
  String get economyOpenShop => 'Shop öffnen';

  @override
  String get economyOpening => 'Wird geöffnet';

  @override
  String get economyOwned => 'In deinem Besitz';

  @override
  String get economyPremiumCollection => 'Premium-Sammlung';

  @override
  String economyPriceCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString Coins';
  }

  @override
  String economyPriceCoinsForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$amountString Coins für $hoursString Stunden';
  }

  @override
  String economyPriceCoinsPerWall(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString pro Hintergrundbild';
  }

  @override
  String economyPriceCoinsPerWallSemantics(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString Coins pro Hintergrundbild';
  }

  @override
  String economyPriceCoinsWithNote(int amount, String note, String hasNote) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(hasNote, {'true': ', $note', 'other': ''});
    return '$amountString Coins$_temp0';
  }

  @override
  String economyPriceForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$amountString für $hoursString Std.';
  }

  @override
  String economyPriceFrom(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'ab $amountString';
  }

  @override
  String economyPriceFromCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'ab $amountString Coins';
  }

  @override
  String get economyPrizeWheel => 'Glücksrad';

  @override
  String get economyPro => 'Pro';

  @override
  String get economyProDailyFreeSpin => 'Pro-Mitglieder erhalten jeden Tag eine kostenlose Drehung.';

  @override
  String get economyProDownloadsFilters => 'Mit Pro sind Downloads und Filter kostenlos.';

  @override
  String get economyProPrice => 'Pro-Preis';

  @override
  String get economyProWallpaper => 'Pro-Hintergrundbild';

  @override
  String get economyQuestBrowse10 => '10 Hintergrundbilder ansehen';

  @override
  String get economyQuestColourSearch => 'Nach Farbe suchen';

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
      other: 'Aufgabe erledigt: +$xpString XP',
      zero: 'Aufgabe erledigt',
    );
    String _temp3 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Aufgabe erledigt: +$coinsString Coins$_temp0',
      one: 'Aufgabe erledigt: +1 Coin$_temp1',
      zero: '$_temp2',
    );
    return '$_temp3';
  }

  @override
  String get economyQuestDownload2 => '2 Hintergrundbilder herunterladen';

  @override
  String get economyQuestFav3 => '3 Hintergrundbilder favorisieren';

  @override
  String economyQuestNewIn(String time) {
    return 'Neu in $time';
  }

  @override
  String get economyQuestProSpin => 'Kostenlose Drehung nutzen';

  @override
  String get economyQuestSetWall => 'Hintergrundbild festlegen oder speichern';

  @override
  String get economyQuestShareWall => 'Hintergrundbild teilen';

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

    String _temp0 = intl.Intl.selectLogic(isDone, {'true': 'erledigt', 'other': '$progressString von $targetString'});
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString Coins', one: '1 Coin');
    String _temp2 = intl.Intl.selectLogic(hasCoins, {'true': '. Bringt $_temp1', 'other': ''});
    String _temp3 = intl.Intl.selectLogic(hasXp, {'true': '. Bringt $xpString XP', 'other': ''});
    String _temp4 = intl.Intl.selectLogic(hasEnds, {'true': ', endet in $endsIn', 'other': ''});
    String _temp5 = intl.Intl.selectLogic(isWeekly, {'true': '. Wöchentliche Aufgabe$_temp4', 'other': ''});
    return '$title, $_temp0$_temp2$_temp3$_temp5';
  }

  @override
  String get economyQuestTrending => 'Trends ansehen';

  @override
  String get economyQuestUnknown => 'Aufgabe abschließen';

  @override
  String get economyQuestWatchAd => 'Video ansehen';

  @override
  String get economyQuestWeeklySet5 => '5 Hintergrundbilder speichern oder festlegen';

  @override
  String get economyQuestWotd => 'Hintergrundbild des Tages öffnen';

  @override
  String get economyRankBronze => 'Bronze';

  @override
  String get economyRankGold => 'Gold';

  @override
  String get economyRankGrowsWithXp => 'Dein Rang steigt mit deinen gesamten XP.';

  @override
  String economyRankInfoSemantics(String rank) {
    return 'Rang $rank. So funktionieren XP und Rangbelohnungen';
  }

  @override
  String get economyRankPrism => 'Prism';

  @override
  String economyRankProgressSemantics(String rank) {
    return 'Fortschritt für Rang $rank';
  }

  @override
  String economyRankRewardAtRank(String rank, String xp) {
    return 'Ab Rang $rank automatisch für dich · $xp XP';
  }

  @override
  String economyRankRewardMilestone(String rank, String xp, String reward) {
    return '$rank · $xp XP\n$reward';
  }

  @override
  String get economyRankRewardSyncing => 'Wird mit deinem Inventar synchronisiert. Es gehört dir.';

  @override
  String get economyRankRewardsHelp => 'So funktionieren XP und Rangbelohnungen';

  @override
  String get economyRankSilver => 'Silber';

  @override
  String economyRankTag(String rank) {
    return 'Rang $rank';
  }

  @override
  String get economyRankUnknown => 'Rang';

  @override
  String economyReferralBothGet(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString Coins', one: '1 Coin');
    return 'Ihr erhaltet beide $_temp0';
  }

  @override
  String get economyRestore => 'Wiederherstellen';

  @override
  String economyRestoreStreak(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Deine $daysString-Tage-Serie wiederherstellen · $coinsString Coins';
  }

  @override
  String economyRewardEarned(String reward) {
    return '$reward verdient';
  }

  @override
  String get economyRewardsTitle => 'Belohnungen';

  @override
  String get economySameActivitySameXp => 'Für dieselbe Aktivität gibt es immer gleich viele XP.';

  @override
  String get economySameActivityXpDetails =>
      'Für Werbung, Pro-Drehungen, tägliche Pro-Boni, Empfehlungen und Rückerstattungen gibt es keine XP. Pro- und Coin-Multiplikatoren erhöhen deine XP nicht. Coin-Belohnungen bleiben davon getrennt.';

  @override
  String get economySeeAll => 'Alle ansehen';

  @override
  String get economySeeBadges => 'Abzeichen ansehen';

  @override
  String get economySeeItInShop => 'Im Shop ansehen';

  @override
  String get economySeeOdds => 'Gewinnchancen ansehen';

  @override
  String get economySeePro => 'Pro ansehen';

  @override
  String get economySeeRewards => 'Belohnungen ansehen';

  @override
  String get economyShareWallpaper => 'Hintergrundbild teilen';

  @override
  String get economyShopAlreadyOwned => 'Du besitzt diesen Artikel bereits.';

  @override
  String get economyShopAurora => 'Aurora';

  @override
  String economyShopBuyFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Für $priceString kaufen';
  }

  @override
  String get economyShopChangeIconFailed => 'Symbol konnte nicht geändert werden.';

  @override
  String economyShopCoinsShort(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Du brauchst noch $countString Coins.';
  }

  @override
  String get economyShopCottonBlue => 'Baumwollblau';

  @override
  String get economyShopDeepOcean => 'Tiefsee';

  @override
  String get economyShopDefaultIcon => 'Standard';

  @override
  String get economyShopEarnXp => 'XP verdienen';

  @override
  String economyShopEarnedAtLifetimeXp(String rank) {
    return 'Mit Rang $rank und deinen gesamten XP verdient.';
  }

  @override
  String get economyShopEmber => 'Glut';

  @override
  String get economyShopEquip => 'Ausrüsten';

  @override
  String get economyShopEquipFailed => 'Änderung fehlgeschlagen. Versuch es erneut.';

  @override
  String economyShopEquipped(String name) {
    return '$name ausgerüstet';
  }

  @override
  String get economyShopFounders => 'Gründer:innen';

  @override
  String get economyShopFrames => 'Rahmen';

  @override
  String get economyShopGlass => 'Glas';

  @override
  String get economyShopGlowPreviewName => 'Schimmer';

  @override
  String get economyShopGlows => 'Leuchteffekte';

  @override
  String get economyShopGold => 'Gold';

  @override
  String economyShopIconEnabled(String name) {
    return 'Symbol $name ist aktiviert';
  }

  @override
  String get economyShopIcons => 'Symbole';

  @override
  String economyShopItemSemantics(String name, String status) {
    return '$name, $status';
  }

  @override
  String get economyShopJungle => 'Dschungel';

  @override
  String get economyShopMono => 'Mono';

  @override
  String get economyShopNeedMoreCoins => 'Dafür brauchst du mehr Coins.';

  @override
  String get economyShopNoir => 'Noir';

  @override
  String get economyShopOcean => 'Ozean';

  @override
  String get economyShopOlive => 'Oliv';

  @override
  String get economyShopPepper => 'Pfeffer';

  @override
  String get economyShopPrism => 'Prism';

  @override
  String get economyShopProOnly => 'Dieser Artikel ist nur für Pro-Mitglieder.';

  @override
  String get economyShopPurchaseFailed => 'Kauf fehlgeschlagen. Versuch es erneut.';

  @override
  String economyShopPurchased(String name) {
    return '$name gehört jetzt dir';
  }

  @override
  String economyShopRankLocked(String rank) {
    return 'Erreiche Rang $rank, um das freizuschalten.';
  }

  @override
  String get economyShopRankReachedSyncing => 'Rang erreicht. Deine Belohnung wird synchronisiert.';

  @override
  String economyShopRankRewardSynced(String name) {
    return 'Belohnung für Rang $name synchronisiert';
  }

  @override
  String economyShopReachRankToBuy(String rank) {
    return 'Erreiche Rang $rank, um das zu kaufen.';
  }

  @override
  String get economyShopRing => 'Ring';

  @override
  String get economyShopRose => 'Rose';

  @override
  String economyShopSaleUntil(String date) {
    return 'Begrenzt verfügbar. Im Angebot bis $date.';
  }

  @override
  String get economyShopSky => 'Himmel';

  @override
  String get economyShopSoldOut => 'Dieser limitierte Artikel ist ausverkauft.';

  @override
  String get economyShopSteel => 'Stahl';

  @override
  String get economyShopSunset => 'Sonnenuntergang';

  @override
  String get economyShopSyncReward => 'Belohnung synchronisieren';

  @override
  String get economyShopThemes => 'Designs';

  @override
  String get economyShopTitle => 'Shop';

  @override
  String get economyShopUnequip => 'Ablegen';

  @override
  String economyShopUnequipped(String name) {
    return '$name abgelegt';
  }

  @override
  String get economyShopUseIcon => 'Symbol verwenden';

  @override
  String get economyShopUseTheme => 'Design verwenden';

  @override
  String get economyShopWearingNeedsPro => 'Zum Tragen brauchst du Pro.';

  @override
  String get economyShowMore => 'Mehr anzeigen';

  @override
  String get economySignIn => 'Anmelden';

  @override
  String get economySoldOut => 'Ausverkauft';

  @override
  String get economySoon => 'bald';

  @override
  String economySpendItemSemantics(String label, String price) {
    return '$label, $price';
  }

  @override
  String get economySpin => 'DREHEN';

  @override
  String get economySpinAgain => 'Erneut drehen';

  @override
  String get economySpinAgainFree => 'Erneut drehen, kostenlose Drehung';

  @override
  String economySpinAgainPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Erneut drehen, $priceString Coins';
  }

  @override
  String economySpinCardCaption(int price, int maximum) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Eine Drehung kostet $priceString Coins. Gewinne bis zu $maximumString Coins oder ein kosmetisches Extra.';
  }

  @override
  String economySpinCosts(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Eine Drehung kostet $priceString Coins';
  }

  @override
  String get economySpinFree => 'Drehen, kostenlose Drehung';

  @override
  String economySpinPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Drehen, $priceString Coins';
  }

  @override
  String get economySpinPriceChanged => 'Der Preis hat sich geändert. Prüfe ihn und dreh erneut.';

  @override
  String economySpinShortBalanceMessage(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Eine Drehung kostet $priceString Coins. Du hast $balanceString. Sieh dir ein Video an, um mehr zu verdienen.';
  }

  @override
  String get economySpinTheWheel => 'Am Rad drehen';

  @override
  String economySpinWheelCardSemantics(String caption) {
    return 'Am Rad drehen. $caption';
  }

  @override
  String get economySpinning => 'Wird gedreht';

  @override
  String economySpinsLeftToday(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Drehungen', one: '1 Drehung');
    return 'Heute noch $_temp0 übrig.';
  }

  @override
  String get economyStreak => 'SERIE';

  @override
  String economyStreakChestReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString Truhe an Tag 7';
  }

  @override
  String get economyStreakCollection => 'Serien-Sammlung';

  @override
  String get economyStreakCollectionDescription =>
      'Schalte Hintergrundbilder frei, indem du deine Serie aufrechterhältst oder Coins einsetzt.';

  @override
  String economyStreakCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString-Tage-Serie',
      one: '1-Tages-Serie',
    );
    return '$_temp0';
  }

  @override
  String economyStreakCycleSemantics(int day, String showReward, int reward, String state) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(showReward, {'true': ', plus $rewardString Coins', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(state, {'done': ', erledigt', 'today': ', heute', 'other': ''});
    return 'Tag $dayString$_temp0$_temp1';
  }

  @override
  String economyStreakDailyReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Heute +$coinsString';
  }

  @override
  String economyStreakDayNumber(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Tag $dayString deiner Serie';
  }

  @override
  String get economyStreakFreeze => 'Serien-Schutz';

  @override
  String economyStreakFreezeSaved(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Serien-Schutz hat deine $daysString-Tage-Serie gerettet';
  }

  @override
  String economyStreakFreezesLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Tage', one: '1 Tag');
    return 'Serien-Schutz für noch $_temp0';
  }

  @override
  String economyStreakProReward(int coins, String multiplier) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString x$multiplier mit Pro';
  }

  @override
  String get economyStreakRescueCooldown => 'Du kannst alle 30 Tage eine Serie wiederherstellen.';

  @override
  String get economyStreakRescueExpired => 'Die 48 Stunden zum Wiederherstellen dieser Serie sind vorbei.';

  @override
  String get economyStreakRescueFailed => 'Deine Serie konnte nicht wiederhergestellt werden. Versuch es erneut.';

  @override
  String get economyStreakRescueUnavailable => 'Diese Serie kann jetzt nicht wiederhergestellt werden.';

  @override
  String get economyStreakReset => 'Deine Serie wurde zurückgesetzt';

  @override
  String economyStreakResetMessage(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Du hattest eine Serie von $daysString Tagen. Fang heute neu an und erhalte +$coinsString Coins.';
  }

  @override
  String economyStreakRestoreShort(int balance, int cost) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Du hast $balanceString. Du brauchst $costString.';
  }

  @override
  String get economyStreakRestored => 'Deine Serie ist wieder da';

  @override
  String economyStreakRestoredCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Du hast jetzt wieder eine Serie von $countString Tagen.';
  }

  @override
  String get economyToday => 'Heute';

  @override
  String get economyUnknownCosmetic => 'Kosmetisches Extra';

  @override
  String economyUntil(String date) {
    return 'Bis $date';
  }

  @override
  String economyUpToCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Bis zu +$countString';
  }

  @override
  String get economyUpgradeToPro => 'Auf Pro upgraden';

  @override
  String economyUseReward(String reward) {
    return '$reward verwenden';
  }

  @override
  String get economyUseYourCoins => 'Deine Coins verwenden';

  @override
  String get economyWatchAd => 'Werbung ansehen';

  @override
  String get economyWatchVideo => 'Video ansehen';

  @override
  String economyWatchVideoRewardAdsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Anzeigen', one: '1 Anzeige');
    return 'Video ansehen · heute noch $_temp0';
  }

  @override
  String economyWatchVideoRewardCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Video ansehen (+$coinsString)';
  }

  @override
  String get economyWeekComplete => 'Woche abgeschlossen!';

  @override
  String get economyWeekly => 'WÖCHENTLICH';

  @override
  String get economyWeeklyDraw => 'Wöchentliche Verlosung';

  @override
  String get economyWeeklyDrop => 'Wöchentlicher Drop';

  @override
  String economyWeeklyEndsIn(String time) {
    return 'WÖCHENTLICH · $time';
  }

  @override
  String get economyWeeklyXpFriendsEveryone => 'Wöchentliche XP, Freund:innen und alle';

  @override
  String economyWonCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString Coins', one: '1 Coin');
    return 'Du hast $_temp0 gewonnen';
  }

  @override
  String economyWonCosmetic(String kind, String name) {
    return 'Du hast ein neues $kind gewonnen: $name';
  }

  @override
  String get economyWonUnknownCosmetic => 'Du hast ein kosmetisches Extra gewonnen';

  @override
  String economyWonXp(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Du hast $xpString XP gewonnen';
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

    return 'Für tägliche Serien gibt es $dailyStreakString XP und für einen abgeschlossenen 7-Tage-Zyklus zusätzlich $streakWeekString XP. Für Aufgaben-Truhen gibt es $questChestString XP. Dein erster gültiger Upload bringt $uploadString XP, ein vollständiges Profil $profileString XP. Für jede tägliche Aufgabe gibt es $dailyQuestString XP, für die wöchentliche Aufgabe $weeklyQuestString XP. Auch manche Abzeichen und Creator-Meilensteine bringen XP.';
  }

  @override
  String economyXpAwarded(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '+$xpString XP';
  }

  @override
  String get economyXpRanksRewards => 'XP, Ränge und Belohnungen';

  @override
  String economyXpToRank(String xp, String rank) {
    return 'Noch $xp XP bis Rang $rank';
  }

  @override
  String get economyXpUnit => 'XP';

  @override
  String get economyYesterday => 'Gestern';

  @override
  String economyYouHaveCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Du hast $countString Coins';
  }

  @override
  String get economyYourXp => 'DEINE XP';

  @override
  String get errorGeneric => 'Etwas ist schiefgelaufen. Bitte versuch es erneut.';

  @override
  String get errorNetwork => 'Prüfe deine Verbindung und versuch es erneut.';

  @override
  String get navigationBackOnline => 'Wieder online';

  @override
  String get navigationNoInternetConnection => 'Keine Internetverbindung';

  @override
  String get navigationScrollToTop => 'Nach oben scrollen';

  @override
  String get notifActivateToCollapse => 'Zum Einklappen aktivieren.';

  @override
  String get notifActivateToExpand => 'Zum Ausklappen aktivieren.';

  @override
  String get notifChannelDownloads => 'Downloads';

  @override
  String get notifChannelDownloadsDescription =>
      'Benachrichtigungen zum Fortschritt deiner Hintergrundbilder-Downloads.';

  @override
  String get notifChannelDraw => 'Prism Draw';

  @override
  String get notifChannelDrawDescription => 'Ergebnisse und Gewinne der Verlosung.';

  @override
  String get notifChannelDrops => 'Wöchentliche Drops';

  @override
  String get notifChannelDropsDescription => 'Wenn ein neuer Drop erscheint und bevor er endet.';

  @override
  String get notifChannelFollowers => 'Follower';

  @override
  String get notifChannelFollowersDescription => 'Benachrichtigungen über neue Follower.';

  @override
  String get notifChannelGifts => 'Geschenke';

  @override
  String get notifChannelGiftsDescription => 'Ein Freund hat dir einen Pro-Pass geschenkt.';

  @override
  String get notifChannelGroup => 'Benachrichtigungen';

  @override
  String get notifChannelGroupDescription => 'Alle Prism-Benachrichtigungen';

  @override
  String get notifChannelModeration => 'Moderation';

  @override
  String get notifChannelModerationDescription => 'Meldungen und Prüfungsanfragen für Prism-Admins.';

  @override
  String get notifChannelPosts => 'Beiträge';

  @override
  String get notifChannelPostsDescription => 'Neue Beiträge von Künstlern, denen du folgst.';

  @override
  String get notifChannelRecommendations => 'Empfehlungen';

  @override
  String get notifChannelRecommendationsDescription => 'Empfehlungen von Prism.';

  @override
  String get notifChannelStreaks => 'Erinnerungen an deine Serie';

  @override
  String get notifChannelStreaksDescription => 'Erinnerung um 20 Uhr, damit deine Anmelde-Serie bestehen bleibt.';

  @override
  String get notifChannelWotd => 'Hintergrundbild des Tages';

  @override
  String get notifChannelWotdDescription => 'Tägliche Benachrichtigung zum Hintergrundbild des Tages um 9 Uhr.';

  @override
  String get notifClearDeviceMessage => 'Dadurch werden sie von diesem Gerät entfernt.';

  @override
  String get notifClearInbox => 'Posteingang leeren';

  @override
  String get notifClearInboxAction => 'Posteingang leeren';

  @override
  String notifClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString Benachrichtigungen entfernen?';
  }

  @override
  String get notifClearOneTitle => 'Diese Benachrichtigung entfernen?';

  @override
  String get notifCollapsed => 'Eingeklappt';

  @override
  String notifDownloadedTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Hintergrundbilder heruntergeladen.',
      one: '1 Hintergrundbild heruntergeladen.',
    );
    return '$_temp0';
  }

  @override
  String get notifDownloadingWallpaper => 'Hintergrundbild wird heruntergeladen';

  @override
  String get notifEmptyBody => 'Neue Follower, Freigaben und das Hintergrundbild des Tages erscheinen hier.';

  @override
  String get notifEmptyTitle => 'Keine Benachrichtigungen';

  @override
  String get notifExpanded => 'Ausgeklappt';

  @override
  String get notifGenericTitle => 'Benachrichtigung';

  @override
  String notifGroupAndMore(String message, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString weitere.',
      one: '1 weitere.',
    );
    return '$message und $_temp0';
  }

  @override
  String notifGroupApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Freigaben', one: 'Freigabe');
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
      other: '$otherCountString weiteren Künstlern.',
      one: '1 weiteren Künstler.',
    );
    return 'Von $name und $_temp0';
  }

  @override
  String notifGroupDailyPicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Tagesauswahlen', one: 'Tagesauswahl');
    return '$_temp0';
  }

  @override
  String get notifGroupDayRows => 'Jede Zeile steht für einen anderen Tag. Die Uhrzeiten stehen rechts.';

  @override
  String notifGroupFollowerSummary(String name, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString weitere Personen folgen dir.',
      one: '1 weitere Person folgen dir.',
    );
    return '$name und $_temp0';
  }

  @override
  String notifGroupFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'neue Follower', one: 'neuer Follower');
    return '$_temp0';
  }

  @override
  String get notifGroupHide => 'Ausblenden';

  @override
  String notifGroupNotifications(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Benachrichtigungen',
      one: 'Benachrichtigung',
    );
    return '$_temp0';
  }

  @override
  String notifGroupNotificationsRemoved(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Benachrichtigungen entfernt',
      one: '1 Benachrichtigung entfernt',
    );
    return '$_temp0';
  }

  @override
  String notifGroupSameMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Dieselbe Nachricht wurde $countString-mal gesendet. An den Zeitstempeln siehst du wann.';
  }

  @override
  String notifGroupSemantics(String title, String summary, String expandedState, String unreadStatus, String action) {
    return '$title. $summary. $expandedState. $unreadStatus $action';
  }

  @override
  String get notifGroupSeveralCreators => 'Mehrere Künstler. Klappe die Gruppe aus, um jedes Hintergrundbild zu sehen.';

  @override
  String get notifGroupShowAll => 'Alle anzeigen';

  @override
  String notifGroupSummaryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Benachrichtigungen in dieser Gruppe.',
      one: '1 Benachrichtigung in dieser Gruppe.',
    );
    return '$_temp0';
  }

  @override
  String notifGroupWallLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hintergrundbilder veröffentlicht',
      one: 'Hintergrundbild veröffentlicht',
    );
    return '$_temp0';
  }

  @override
  String get notifHasUnread => 'Enthält ungelesene Nachrichten.';

  @override
  String get notifInboxCleared => 'Posteingang geleert';

  @override
  String get notifLoadErrorTitle => 'Deine Benachrichtigungen konnten nicht geladen werden';

  @override
  String get notifMarkAllRead => 'Alle als gelesen markieren';

  @override
  String get notifOfflineSaved =>
      'Neue Benachrichtigungen konnten nicht geladen werden. Die angezeigten sind auf diesem Gerät gespeichert.';

  @override
  String get notifOpenSettings => 'Einstellungen öffnen';

  @override
  String get notifPermissionOff =>
      'Benachrichtigungen sind ausgeschaltet. Aktiviere sie zuerst in den Systemeinstellungen.';

  @override
  String get notifPermissionOffForApp => 'Benachrichtigungen für Prism sind ausgeschaltet.';

  @override
  String get notifPreferences => 'Benachrichtigungseinstellungen';

  @override
  String get notifPushDrawWinnerBody => 'Ein Monat Pro und der Prism-Rahmen gehören dir.';

  @override
  String get notifPushDrawWinnerTitle => 'Du hast bei Prism Draw gewonnen';

  @override
  String notifPushDropLastCallBody(String dropTitle, int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(hours, locale: localeName, other: '$hoursString Stunden', one: '1 Stunde');
    return '$dropTitle endet in $_temp0. Danach sind diese Hintergrundbilder einen Monat lang weg.';
  }

  @override
  String get notifPushDropLastCallTitle => 'Letzte Chance für den Drop dieser Woche';

  @override
  String notifPushDropLiveBody(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Hintergrundbilder, nur diese Woche. Sieh sie dir an, bevor sie weg sind.',
      one: '1 Hintergrundbild, nur diese Woche. Sieh es dir an, bevor es weg ist.',
    );
    return '$_temp0';
  }

  @override
  String get notifPushDropLiveTitle => 'Ein neuer Drop ist da';

  @override
  String notifPushFollowDigestTitleOne(String artistName) {
    return '$artistName hat ein neues Hintergrundbild veröffentlicht';
  }

  @override
  String notifPushFollowDigestTitleSolo(String artistName, int wallCount) {
    return '$artistName hat $wallCount neue Hintergrundbilder veröffentlicht';
  }

  @override
  String notifPushFollowDigestTitlePair(String artistName, String secondArtistName, int wallCount) {
    return '$artistName und $secondArtistName haben $wallCount neue Hintergrundbilder veröffentlicht';
  }

  @override
  String notifPushFollowDigestTitleGroup(String artistName, int otherCount, int wallCount) {
    return '$artistName und $otherCount weitere haben $wallCount neue Hintergrundbilder veröffentlicht';
  }

  @override
  String get notifPushFollowDigestBodyUntitled => 'Tippe, um sie alle zu sehen.';

  @override
  String get notifPushGiftReceivedBody =>
      'Premium-Sammlungen und Premium-Hintergrundbilder sind 24 Stunden lang freigeschaltet.';

  @override
  String notifPushGiftReceivedTitle(String senderName) {
    return '$senderName hat dir einen 24-Stunden-Pro-Pass geschenkt';
  }

  @override
  String notifPushNewContentReportBody(String contentType, String reason, String targetId) {
    return '$contentType · $reason · Dokument $targetId';
  }

  @override
  String get notifPushNewContentReportTitle => 'Neue Inhaltsmeldung';

  @override
  String notifPushNewFollowerBody(String followerName) {
    return '$followerName folgt dir jetzt.';
  }

  @override
  String get notifPushNewFollowerTitle => 'Du hast einen neuen Follower! 🎉';

  @override
  String notifPushReportReviewBody(String contentType, String reason) {
    return '$contentType · $reason · seit über 12 Stunden offen';
  }

  @override
  String get notifPushReportReviewTitle => 'Meldung wartet auf Prüfung';

  @override
  String get notifPushStreakReminderBody => 'Öffne jetzt Prism, damit deine Anmelde-Serie bestehen bleibt 🔥';

  @override
  String get notifPushStreakReminderTitle => 'Deine Serie ist kurz vorm Ende!';

  @override
  String notifPushWallApprovedAdminBody(String wallTitle, String artistName) {
    return '„$wallTitle“ von $artistName ist jetzt online.';
  }

  @override
  String get notifPushWallApprovedAdminTitle => 'Hintergrundbild freigegeben ✅';

  @override
  String notifPushWallApprovedArtistBody(String wallTitle) {
    return '„$wallTitle“ wurde freigegeben und ist jetzt für alle sichtbar.';
  }

  @override
  String get notifPushWallApprovedArtistBodyUntitled =>
      'Dein Hintergrundbild wurde freigegeben und ist jetzt für alle sichtbar.';

  @override
  String get notifPushWallApprovedArtistTitle => 'Dein Hintergrundbild ist online! 🎉';

  @override
  String notifPushWallLiveFollowersBody(String wallTitle) {
    return '„$wallTitle“ ist jetzt auf Prism verfügbar.';
  }

  @override
  String notifPushWallLiveFollowersTitle(String artistName) {
    return 'Neues Hintergrundbild von $artistName';
  }

  @override
  String notifPushWallSubmittedBody(String artistName, String artistEmail) {
    return 'Neuer Beitrag von $artistName ($artistEmail) wartet auf Prüfung.';
  }

  @override
  String get notifPushWallSubmittedTitle => 'Neues Premium-Hintergrundbild zur Prüfung! 🎉';

  @override
  String get notifPushWinBack14Body => 'Entdecke, was Künstler in den letzten zwei Wochen hinzugefügt haben.';

  @override
  String get notifPushWinBack14Title => 'Neue Hintergrundbilder warten auf dich';

  @override
  String get notifPushWinBack30Body => 'Gestalte ein Hintergrundbild, das zu dir passt.';

  @override
  String get notifPushWinBack30Title => 'Probiere neue KI-Stile aus';

  @override
  String get notifPushWinBack60Body => 'Dein nächstes Lieblingshintergrundbild ist nur einen Fingertipp entfernt.';

  @override
  String get notifPushWinBack60Title => 'Prism vermisst dich';

  @override
  String get notifPushWinBack7Body => 'Während du weg warst, sind neue Hintergrundbilder erschienen.';

  @override
  String get notifPushWinBack7Title => 'Dein Feed hat neue Hintergrundbilder';

  @override
  String notifPushWotdAudienceBody(String wallTitle) {
    return '$wallTitle';
  }

  @override
  String get notifPushWotdAudienceBodyUntitled => 'Öffne Prism und entdecke das Hintergrundbild des Tages.';

  @override
  String get notifPushWotdAudienceTitle => 'Das heutige Hintergrundbild des Tages ist da';

  @override
  String get notifPushWotdCreatorBody =>
      'Prism hat dein Hintergrundbild heute für alle ausgewählt. Danke, dass du es teilst.';

  @override
  String get notifPushWotdCreatorTitle => 'Dein Hintergrundbild wurde als Hintergrundbild des Tages ausgewählt';

  @override
  String get notifRead => 'Bereits gelesen';

  @override
  String get notifRemoved => 'Benachrichtigung entfernt';

  @override
  String get notifReportUnknownContentType => 'Inhalt';

  @override
  String notifSemanticsRow(String message, String time, String readStatus) {
    return '$message. $time. $readStatus';
  }

  @override
  String get notifSettingDrops => 'Wöchentliche Drops';

  @override
  String get notifSettingDropsDescription => 'Hinweise, wenn ein neuer Drop erscheint und bevor er endet.';

  @override
  String get notifSettingFollowers => 'Follower';

  @override
  String get notifSettingFollowersDescription => 'Hinweise, wenn dir jemand Neues folgt.';

  @override
  String get notifSettingPosts => 'Beiträge';

  @override
  String get notifSettingPostsDescription => 'Neue Beiträge von Künstlern, denen du folgst.';

  @override
  String get notifSettingRecommendations => 'Empfehlungen';

  @override
  String get notifSettingRecommendationsDescription => 'Tipps, Neuigkeiten und Hintergrundbild-Auswahl von Prism.';

  @override
  String get notifSettingStreaks => 'Erinnerungen an deine Serie';

  @override
  String get notifSettingStreaksDescription => 'Abends gegen 20 Uhr, wenn deine Anmelde-Serie bald endet.';

  @override
  String get notifSettingWotd => 'Hintergrundbild des Tages';

  @override
  String get notifSettingWotdDescription => 'Eine tägliche Hintergrundbild-Auswahl.';

  @override
  String get notifSignInToChange => 'Melde dich an, um diese Einstellung zu ändern.';

  @override
  String get notifSignInToTurnOn => 'Melde dich an, um Benachrichtigungen einzuschalten';

  @override
  String get notifTapToOpenPrism => 'Tippe, um Prism zu öffnen.';

  @override
  String get notifTitle => 'Benachrichtigungen';

  @override
  String get notifToday => 'Heute';

  @override
  String get notifUndo => 'Rückgängig';

  @override
  String get notifUnread => 'Noch nicht gelesen';

  @override
  String get notifYesterday => 'Gestern';

  @override
  String notifYesterdayAt(String time) {
    return 'Gestern, $time';
  }

  @override
  String get onboardingAiGenerateError =>
      'Etwas ist schiefgelaufen.\nTippe auf „Generieren“, um es erneut zu versuchen.';

  @override
  String get onboardingAiGeneratePrompt =>
      'Tippe auf „Generieren“, um\ndein einzigartiges Hintergrundbild zu erstellen';

  @override
  String get onboardingAiGenerating => 'Dein Hintergrundbild wird gestaltet …';

  @override
  String get onboardingBrowseGuest => 'Ohne Konto stöbern';

  @override
  String get onboardingCategoriesUnavailable =>
      'Kategorien konnten nicht geladen werden. Du kannst diesen Schritt überspringen.';

  @override
  String get onboardingContinue => 'Weiter';

  @override
  String get onboardingContinueApple => 'Mit Apple fortfahren';

  @override
  String get onboardingContinueGoogle => 'Mit Google fortfahren';

  @override
  String onboardingContinueSelected(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Weiter ($countString ausgewählt)';
  }

  @override
  String get onboardingCouldNotLogOut => 'Abmelden nicht möglich. Bitte versuche es erneut.';

  @override
  String get onboardingCreatorsUnavailable =>
      'Künstler konnten nicht geladen werden. Du kannst diesen Schritt überspringen.';

  @override
  String get onboardingFirstAiWallpaper => 'Dein erstes KI-generiertes Hintergrundbild';

  @override
  String get onboardingFirstWallpaperSaveFailed =>
      'Dein Hintergrundbild konnte nicht gespeichert werden. Versuche es erneut oder überspringe den Schritt.';

  @override
  String get onboardingFirstWallpaperSavedPhotos => 'In Fotos gespeichert!';

  @override
  String get onboardingFirstWallpaperSet => 'Hintergrundbild festgelegt!';

  @override
  String get onboardingFirstWallpaperSetFailed =>
      'Hintergrundbild konnte nicht festgelegt werden. Versuche es erneut oder überspringe den Schritt.';

  @override
  String get onboardingFirstWallpaperSetHome => 'Hintergrundbild für den Startbildschirm festgelegt.';

  @override
  String get onboardingFirstWallpaperSetHomeLock => 'Hintergrundbild für Start- und Sperrbildschirm festgelegt.';

  @override
  String get onboardingFirstWallpaperSetLock => 'Hintergrundbild für den Sperrbildschirm festgelegt.';

  @override
  String get onboardingFollow => 'Folgen';

  @override
  String onboardingFollowCreatorMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Wir empfehlen dir, diesen $countString Künstlern zu folgen';
  }

  @override
  String onboardingFollowerCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Follower',
      one: '$countString Follower',
    );
    return '$_temp0';
  }

  @override
  String get onboardingFollowing => 'Du folgst';

  @override
  String get onboardingGenerateFailure =>
      'Etwas ist schiefgelaufen. Tippe auf „Generieren“, um es erneut zu versuchen.';

  @override
  String get onboardingGenerateSuccess => 'Sieht gut aus! Dein Hintergrundbild wird geöffnet.';

  @override
  String get onboardingGenerateWallpaper => 'Mein Hintergrundbild generieren';

  @override
  String get onboardingHeadlineCreators => 'Finde deine Leute';

  @override
  String get onboardingHeadlineCustomize => 'Mach es zu deinem';

  @override
  String get onboardingHeadlineGenerate => 'Erstelle dein\nerstes Hintergrundbild';

  @override
  String get onboardingHeadlineInterests => 'Wähle deinen Stil';

  @override
  String get onboardingLoadCategoriesFailed => 'Kategorien konnten nicht geladen werden.';

  @override
  String get onboardingLoadCreatorsFailed => 'Künstler konnten nicht geladen werden.';

  @override
  String get onboardingPro => 'Pro';

  @override
  String get onboardingProFree => '   →  kostenlos für dich';

  @override
  String get onboardingRecoveryCreatorsFailed =>
      'Künstler konnten nicht geladen werden. Prüfe deine Verbindung und tippe auf „Neu laden“.';

  @override
  String get onboardingRecoveryFollowFailed => 'Diesen Künstlern konnte nicht gefolgt werden. Versuche es erneut.';

  @override
  String get onboardingRecoveryFollowFailedHelper =>
      'Diesen Künstlern konnte nicht gefolgt werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get onboardingRecoveryReload => 'Neu laden';

  @override
  String get onboardingRecoveryRetry => 'Erneut versuchen';

  @override
  String get onboardingRecoverySaveInterestsFailed =>
      'Deine Auswahl konnte nicht gespeichert werden. Versuche es erneut.';

  @override
  String get onboardingRecoverySaveInterestsFailedHelper =>
      'Deine Auswahl konnte nicht gespeichert werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get onboardingRecoverySessionExpired => 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';

  @override
  String get onboardingRecoverySessionExpiredHelper =>
      'Deine Sitzung ist abgelaufen. Melde dich erneut an, um fortzufahren.';

  @override
  String get onboardingRecoverySetupFailed => 'Einrichtung nicht abgeschlossen. Versuche es erneut.';

  @override
  String get onboardingRecoverySetupFailedHelper =>
      'Einrichtung nicht abgeschlossen. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get onboardingRecoverySignIn => 'Erneut anmelden';

  @override
  String get onboardingReloadLower => 'neu laden';

  @override
  String get onboardingSavePhotos => 'In Fotos speichern';

  @override
  String onboardingSelectInterestMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Wähle mindestens $countString Kategorien aus, damit wir deinen Feed personalisieren können';
  }

  @override
  String get onboardingSetWallpaper => 'Als Hintergrundbild festlegen';

  @override
  String get onboardingSignInAgainLower => 'erneut anmelden';

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingSkipLower => 'überspringen';

  @override
  String get onboardingTermsRequired => 'Bitte stimme zuerst den Nutzungsbedingungen und der Datenschutzerklärung zu.';

  @override
  String get onboardingTryAgainLower => 'erneut versuchen';

  @override
  String onboardingWallpaperForInterest(String category) {
    return 'Wir haben dieses Hintergrundbild passend zu deinem Interesse an $category ausgewählt.';
  }

  @override
  String get onboardingWallpaperJustForYou => 'Wir haben dieses Hintergrundbild nur für dich ausgewählt.';

  @override
  String get onboardingWelcomeDescription => 'Millionen Premium-Hintergrundbilder von großartigen Künstlern.';

  @override
  String get onboardingWelcomeHeadline => 'Dein Bildschirm, neu gedacht.';

  @override
  String get premiumPageExplorePlans => 'Entdecke die Prism-Premium-Abos.';

  @override
  String get premiumPagePlansUnavailable =>
      'Die Abos sind gerade nicht verfügbar. Prüfe deine Verbindung und versuch es erneut.';

  @override
  String get premiumPageTitle => 'Prism Premium';

  @override
  String get premiumPageTryAgain => 'Erneut versuchen';

  @override
  String get premiumPageViewPlans => 'Abos ansehen';

  @override
  String get premiumGuestStorePurchaseActive =>
      'Dein Store-Kauf ist auf diesem Gerät aktiv. Melde dich an, um kontobasierte Pro-Funktionen zu nutzen.';

  @override
  String get premiumPurchasePending =>
      'Dein Kauf wurde gespeichert. Es kann eine Minute dauern, bis Pro freigeschaltet wird.';

  @override
  String get premiumPurchaseUnconfirmed =>
      'Dein Kauf konnte nicht bestätigt werden. Versuche es in den Einstellungen mit „Käufe wiederherstellen“.';

  @override
  String get wallpaperAccentColor => 'Akzentfarbe';

  @override
  String get wallpaperAccentColorsOriginal => 'Originalfarben des Hintergrundbilds';

  @override
  String get wallpaperResetOriginal => 'Zurück zum Original';

  @override
  String get wallpaperAccentResetHint => 'Gedrückt halten für Aktionen, auch Zurück zum Original';

  @override
  String get wallpaperAll => 'Alle';

  @override
  String get wallpaperApplyTo => 'Anwenden auf';

  @override
  String get wallpaperAutoRotateAndroidOnly => 'Automatischer Wechsel ist nur unter Android verfügbar.';

  @override
  String get wallpaperAutoRotateApplyTo => 'Anwenden auf';

  @override
  String get wallpaperAutoRotateBatterySteps =>
      'Öffne Einstellungen, dann Apps, Prism und Akku. Stelle die Akkunutzung auf „Uneingeschränkt“.';

  @override
  String get wallpaperAutoRotateBatteryTip =>
      'Wenn sich Hintergrundbilder nicht mehr ändern, stelle die Akkunutzung für Prism auf „Uneingeschränkt“. Öffne dazu Einstellungen, Apps, Prism und Akku.';

  @override
  String get wallpaperAutoRotateBothScreens => 'Beide';

  @override
  String get wallpaperAutoRotateChangeError => 'Hintergrundbild konnte nicht geändert werden.';

  @override
  String get wallpaperAutoRotateChangeLabel => 'Ändern';

  @override
  String get wallpaperAutoRotateChargingDescription =>
      'Bei angeschlossenem Ladegerät wechseln, höchstens einmal pro Intervall';

  @override
  String get wallpaperAutoRotateChargingOnly => 'Nur während des Ladens';

  @override
  String get wallpaperAutoRotateCopySteps => 'Anleitung kopieren';

  @override
  String get wallpaperAutoRotateCouldNotStart => 'Start nicht möglich. Versuche es erneut.';

  @override
  String wallpaperAutoRotateDownloadedCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Hintergrundbilder',
      one: 'Hintergrundbild',
    );
    return '$cachedString von $totalString $_temp0 heruntergeladen';
  }

  @override
  String wallpaperAutoRotateEnabledUntil(String date) {
    return 'Pass aktiv bis $date';
  }

  @override
  String get wallpaperAutoRotateGotIt => 'Verstanden';

  @override
  String get wallpaperAutoRotateHomeScreen => 'Startbildschirm';

  @override
  String get wallpaperAutoRotateInterval12Hours => 'Alle 12 Stunden';

  @override
  String get wallpaperAutoRotateInterval15 => 'Alle 15 Min. (hoher Akkuverbrauch)';

  @override
  String get wallpaperAutoRotateInterval30 => 'Alle 30 Min.';

  @override
  String get wallpaperAutoRotateInterval3Days => 'Alle 3 Tage';

  @override
  String get wallpaperAutoRotateInterval3Hours => 'Alle 3 Stunden';

  @override
  String get wallpaperAutoRotateInterval6Hours => 'Alle 6 Stunden';

  @override
  String get wallpaperAutoRotateIntervalDay => 'Jeden Tag';

  @override
  String get wallpaperAutoRotateIntervalHour => 'Jede Stunde';

  @override
  String get wallpaperAutoRotateIntervalWeek => 'Jede Woche';

  @override
  String get wallpaperAutoRotateKeepRunning => 'Weiterlaufen lassen';

  @override
  String get wallpaperAutoRotateLoadError =>
      'Einstellungen für den automatischen Wechsel konnten nicht geladen werden.';

  @override
  String get wallpaperAutoRotateLoadingWalls => 'Hintergrundbilder werden geladen';

  @override
  String get wallpaperAutoRotateLockScreen => 'Sperrbildschirm';

  @override
  String wallpaperAutoRotateMix(int count, String source) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Hintergrundbilder von $source in der Auswahl',
      one: '1 Hintergrundbild von $source in der Auswahl',
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
      other: '$countString Hintergrundbilder von $source in der Auswahl. Die ersten 100 werden verwendet.',
      one: '1 Hintergrundbild von $source in der Auswahl. Die ersten 100 werden verwendet.',
    );
    return '$_temp0';
  }

  @override
  String wallpaperAutoRotateNextChange(String time) {
    return 'Nächster Wechsel gegen $time';
  }

  @override
  String wallpaperAutoRotateNounCategory(String category) {
    return '$category';
  }

  @override
  String get wallpaperAutoRotateNounDownloads => 'Downloads';

  @override
  String get wallpaperAutoRotateNounFavourites => 'Favoriten';

  @override
  String get wallpaperAutoRotateNounHistory => 'dein Verlauf';

  @override
  String get wallpaperAutoRotateNounWotd => 'Hintergrundbild des Tages';

  @override
  String get wallpaperAutoRotateOff => 'Aus';

  @override
  String get wallpaperAutoRotateOffEnded =>
      'Der automatische Wechsel ist aus, weil dein Prism-Pro-Abo oder Pass abgelaufen ist.';

  @override
  String get wallpaperAutoRotateOpenDownloads => 'Downloads öffnen';

  @override
  String get wallpaperAutoRotateOpenFavourites => 'Favoriten öffnen';

  @override
  String get wallpaperAutoRotatePassEnabled => 'Der automatische Wechsel ist 7 Tage lang aktiv.';

  @override
  String wallpaperAutoRotatePassPurchase(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '7-Tage-Pass · $coinsString Coins';
  }

  @override
  String get wallpaperAutoRotatePickCategory => 'Kategorie auswählen';

  @override
  String wallpaperAutoRotatePreparing(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Hintergrundbilder werden vorbereitet',
      one: '1 Hintergrundbild wird vorbereitet',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperAutoRotateProBody => 'Teste die Funktion 7 Tage lang mit Coins oder hol dir Prism Pro.';

  @override
  String get wallpaperAutoRotateProTitle => 'Automatischer Wechsel ist eine Prism-Pro-Funktion.';

  @override
  String wallpaperAutoRotateReadyCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Hintergrundbilder',
      one: 'Hintergrundbild',
    );
    return '$cachedString von $totalString $_temp0 bereit';
  }

  @override
  String get wallpaperAutoRotateScheduled => 'Geplant';

  @override
  String get wallpaperAutoRotateShuffle => 'Zufällige Reihenfolge';

  @override
  String get wallpaperAutoRotateShuffleDescription => 'Zufällige statt fortlaufender Reihenfolge';

  @override
  String get wallpaperAutoRotateSourceCategory => 'Kategorie';

  @override
  String get wallpaperAutoRotateSourceDownloads => 'Downloads';

  @override
  String get wallpaperAutoRotateSourceFavourites => 'Favoriten';

  @override
  String get wallpaperAutoRotateSourceHistory => 'Verlauf';

  @override
  String get wallpaperAutoRotateSourceLabel => 'Quelle';

  @override
  String get wallpaperAutoRotateSourceLoadError =>
      'Hintergrundbilder konnten nicht geladen werden. Prüfe deine Verbindung.';

  @override
  String get wallpaperAutoRotateSourceWotd => 'Hintergrundbild des Tages';

  @override
  String get wallpaperAutoRotateStartError => 'Automatischer Hintergrundbild-Wechsel konnte nicht gestartet werden.';

  @override
  String get wallpaperAutoRotateStarting => 'Wird gestartet';

  @override
  String get wallpaperAutoRotateStatusLabel => 'Status';

  @override
  String get wallpaperAutoRotateStepsCopied => 'Anleitung kopiert.';

  @override
  String get wallpaperAutoRotateStopError => 'Automatischer Hintergrundbild-Wechsel konnte nicht beendet werden.';

  @override
  String get wallpaperAutoRotateTitle => 'Automatischer Wechsel';

  @override
  String get wallpaperAutoRotateTooFewCategory =>
      'Diese Kategorie enthält weniger als 2 Hintergrundbilder. Wähle eine andere.';

  @override
  String get wallpaperAutoRotateTooFewDownloads =>
      'Lade mindestens 2 Hintergrundbilder herunter, um sie automatisch zu wechseln.';

  @override
  String get wallpaperAutoRotateTooFewFavourites =>
      'Füge mindestens 2 Hintergrundbilder zu deinen Favoriten hinzu, um sie automatisch zu wechseln.';

  @override
  String get wallpaperAutoRotateTooFewHistory =>
      'Lege mindestens 2 Hintergrundbilder aus Prism fest, um sie automatisch zu wechseln.';

  @override
  String get wallpaperAutoRotateTooFewWotd => 'Es gibt noch nicht genug vergangene Tagesauswahlen.';

  @override
  String get wallpaperAutoRotateUnlockError =>
      'Automatischer Wechsel konnte nicht freigeschaltet werden. Versuche es erneut.';

  @override
  String get wallpaperAutoRotateUpdateError => 'Automatischer Wechsel konnte nicht aktualisiert werden.';

  @override
  String get wallpaperBack => 'Zurück';

  @override
  String get wallpaperBlockCreator => 'Künstler blockieren';

  @override
  String get wallpaperBlockCreatorNotFound => 'Künstler nicht gefunden. Versuche es erneut.';

  @override
  String get wallpaperBoostAlready => 'Bereits hervorgehoben.';

  @override
  String wallpaperBoostAlreadyUntil(String time) {
    return 'Bereits bis $time hervorgehoben.';
  }

  @override
  String wallpaperBoostConfirmButton(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Für $coinsString Coins hervorheben';
  }

  @override
  String wallpaperBoostConfirmMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Zeige dieses Hintergrundbild 24 Stunden lang im Startseiten-Karussell und ganz oben bei „Im Trend“ für $coinsString Coins.';
  }

  @override
  String wallpaperBoostDurationAndCost(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '24 Stunden ganz oben · $coinsString Coins';
  }

  @override
  String get wallpaperBoostFailed => 'Dieses Hintergrundbild konnte nicht hervorgehoben werden. Versuche es erneut.';

  @override
  String get wallpaperBoostOnlyApproved =>
      'Nur freigegebene Hintergrundbilder, die du hochgeladen hast, können hervorgehoben werden.';

  @override
  String get wallpaperBoostSlotsTaken => 'Alle Plätze zum Hervorheben sind belegt. Versuche es später erneut.';

  @override
  String wallpaperBoostSlotsTakenUntil(String time) {
    return 'Alle Plätze zum Hervorheben sind belegt. Der nächste wird um $time frei.';
  }

  @override
  String get wallpaperBoostTitle => 'Im Trend hervorheben';

  @override
  String get wallpaperBoostedSuccess => 'Hervorgehoben. Jetzt auf der Startseite und bei „Im Trend“ sichtbar.';

  @override
  String get wallpaperBoostedTag => 'Hervorgehoben';

  @override
  String wallpaperBoostedUntil(String time) {
    return 'Hervorgehoben bis $time';
  }

  @override
  String get wallpaperBrowseWallpapers => 'Hintergrundbilder entdecken';

  @override
  String wallpaperByCreator(String name) {
    return 'Hintergrundbild von $name';
  }

  @override
  String get wallpaperByPrismCreator => 'Hintergrundbild von einem Prism-Künstler';

  @override
  String get wallpaperCategories => 'Kategorien';

  @override
  String get wallpaperCategory => 'Kategorie';

  @override
  String get wallpaperCategoryFeedEmptyBody => 'Es kommen regelmäßig neue dazu. Schau bald wieder vorbei.';

  @override
  String get wallpaperCategoryFeedEmptyTitle => 'Hier gibt es noch keine Hintergrundbilder';

  @override
  String wallpaperCategoryNamed(String name) {
    return 'Kategorie, $name';
  }

  @override
  String get wallpaperChangeNow => 'Jetzt ändern';

  @override
  String get wallpaperCheckBackSoon => 'Schau bald wieder vorbei.';

  @override
  String get wallpaperCheckBackTomorrow => 'Schau morgen wieder vorbei.';

  @override
  String get wallpaperCheckConnection => 'Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get wallpaperClear => 'Leeren';

  @override
  String get wallpaperClearFilters => 'Filter zurücksetzen';

  @override
  String get wallpaperClearHistoryAction => 'Verlauf leeren';

  @override
  String get wallpaperClearHistoryBody =>
      'Dadurch wird die Liste der von dir festgelegten Hintergrundbilder entfernt. Deine Hintergrundbilder bleiben unverändert.';

  @override
  String get wallpaperClearHistoryTitle => 'Verlauf leeren?';

  @override
  String get wallpaperClearSearch => 'Suche leeren';

  @override
  String get wallpaperClosePreview => 'Vorschau schließen';

  @override
  String get wallpaperCollapseDetails => 'Details zum Hintergrundbild einklappen';

  @override
  String get wallpaperCollection => 'Sammlung';

  @override
  String get wallpaperCollectionLoadError => 'Diese Sammlung konnte nicht geladen werden';

  @override
  String wallpaperCollectionNamed(String name) {
    return 'Sammlung, $name';
  }

  @override
  String wallpaperCollectionPreviewUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Vorschau für 24 Stunden freigeschaltet (−$coinsString Coins).';
  }

  @override
  String get wallpaperCollectionRefreshError => 'Aktualisieren nicht möglich. Zum erneuten Laden nach unten ziehen.';

  @override
  String get wallpaperCollectionsEmptyBody => 'Ziehe zum Aktualisieren nach unten oder schau bald wieder vorbei.';

  @override
  String get wallpaperCollectionsEmptyTitle => 'Noch keine Sammlungen';

  @override
  String get wallpaperCopyAccentHexHint => 'Zum Kopieren des Hex-Farbwerts lange drücken';

  @override
  String wallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Hintergrundbilder',
      one: '1 Hintergrundbild',
      zero: 'Keine Hintergrundbilder',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDelete => 'Löschen';

  @override
  String get wallpaperDeleteManyDownloadsBody =>
      'Sie werden von diesem Gerät entfernt. Du kannst sie später erneut herunterladen.';

  @override
  String wallpaperDeleteManyDownloadsTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString Downloads löschen?';
  }

  @override
  String get wallpaperDeleteOneDownloadBody =>
      'Es wird von diesem Gerät entfernt. Du kannst es später erneut herunterladen.';

  @override
  String get wallpaperDeleteOneDownloadTitle => 'Diesen Download löschen?';

  @override
  String get wallpaperDepthEditorSubtitle => 'Tippe im Sperrbildschirm-Editor auf ••• und dann auf „Tiefeneffekt“.';

  @override
  String get wallpaperDepthEffect => 'Tiefeneffekt';

  @override
  String get wallpaperDepthSubjectSubtitle => 'Dein Motiv liegt vor der Uhr.';

  @override
  String get wallpaperSpatialScene => 'Räumliche Szene';

  @override
  String get wallpaperSpatialGreatSubtitle => 'Klare Tiefe. Ergibt einen starken 3D-Sperrbildschirm.';

  @override
  String get wallpaperSpatialOkSubtitle => 'Etwas Tiefe. Der 3D-Effekt ist sanft.';

  @override
  String get wallpaperSpatialGuideTitle => 'Als räumliche Szene festlegen';

  @override
  String get wallpaperSpatialGuideBody => 'Auf dem iPhone 12 oder neuer mit iOS 26:';

  @override
  String get wallpaperSpatialStepSave => 'Speichere dieses Wallpaper in Fotos.';

  @override
  String get wallpaperSpatialStepPick =>
      'Berühre und halte auf dem Sperrbildschirm den Bildschirm. Tippe auf die Taste Hinzufügen, tippe auf Fotos und wähle dann das Foto aus.';

  @override
  String get wallpaperSpatialStepButton =>
      'Tippe auf die Schaltfläche Räumliche Szene, um den 3D-Effekt einzuschalten, und dann auf Hinzufügen.';

  @override
  String get wallpaperSpatialPreviewLabel => '3D';

  @override
  String get wallpaperSpatialPreviewOn => 'In 3D ansehen';

  @override
  String get wallpaperSpatialPreviewOff => '3D-Vorschau ausschalten';

  @override
  String get wallpaperSpatialDragHint => 'Ziehen zum Neigen';

  @override
  String get wallpaperDetailColorCodeCopied => 'Farbcode in die Zwischenablage kopiert';

  @override
  String get wallpaperDetailNotFound => 'Hintergrundbild nicht gefunden';

  @override
  String get wallpaperDiscard => 'Verwerfen';

  @override
  String get wallpaperDismiss => 'Schließen';

  @override
  String get wallpaperDownload => 'Herunterladen';

  @override
  String wallpaperDownloadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Downloads',
      one: '1 Download',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadSortName => 'Name';

  @override
  String get wallpaperDownloadSortNewest => 'Neueste zuerst';

  @override
  String get wallpaperDownloadSortOldest => 'Älteste zuerst';

  @override
  String get wallpaperDownloadWallpaper => 'Hintergrundbild herunterladen';

  @override
  String get wallpaperDownloadedWallpaper => 'Heruntergeladenes Hintergrundbild';

  @override
  String get wallpaperDownloadedWallpaperUnavailable => 'Heruntergeladenes Hintergrundbild nicht verfügbar';

  @override
  String wallpaperDownloadsDeleteError(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Downloads konnten nicht gelöscht werden.',
      one: '1 Download konnte nicht gelöscht werden.',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadsEmptyBody => 'Hier findest du deine heruntergeladenen Hintergrundbilder.';

  @override
  String get wallpaperDownloadsEmptyTitle => 'Noch keine Downloads';

  @override
  String get wallpaperDownloadsLoadError => 'Deine Downloads konnten nicht geladen werden';

  @override
  String get wallpaperDownloadsLoadHelp => 'Prüfe den Speicherzugriff und versuche es erneut.';

  @override
  String get wallpaperDownloadsRefreshError => 'Downloads konnten nicht aktualisiert werden. Versuche es erneut.';

  @override
  String get wallpaperDownloadsShareError => 'Teilen nicht möglich. Versuche es erneut.';

  @override
  String get wallpaperDownloadsTitle => 'Downloads';

  @override
  String get wallpaperEdit => 'Bearbeiten';

  @override
  String get wallpaperEditTitle => 'Hintergrundbild bearbeiten';

  @override
  String get wallpaperExpandDetails => 'Details zum Hintergrundbild ausklappen';

  @override
  String get wallpaperFavourite => 'Zu Favoriten hinzufügen';

  @override
  String get wallpaperFavouriteAddedToast => 'Zu Favoriten hinzugefügt.';

  @override
  String get wallpaperFavouriteClearAccountMessage => 'Dadurch werden sie aus deinem Konto entfernt.';

  @override
  String get wallpaperFavouriteClearAll => 'Alle Favoriten entfernen';

  @override
  String get wallpaperFavouriteClearDeviceMessage => 'Dadurch werden sie von diesem Gerät entfernt.';

  @override
  String get wallpaperFavouriteClearError => 'Favoriten konnten nicht entfernt werden. Versuche es erneut.';

  @override
  String wallpaperFavouriteClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString Favoriten entfernen?';
  }

  @override
  String get wallpaperFavouriteClearOneTitle => '1 Favorit entfernen?';

  @override
  String wallpaperFavouriteClearedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Favoriten entfernt',
      one: '1 Favorit entfernt',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteClearedOne => '1 Favorit entfernt';

  @override
  String wallpaperFavouriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Favoriten',
      one: '1 Favorit',
      zero: 'Keine Favoriten',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteEmptyBody => 'Tippe bei einem Hintergrundbild auf das Herz, um es hier zu speichern.';

  @override
  String get wallpaperFavouriteEmptyTitle => 'Noch keine Favoriten';

  @override
  String get wallpaperFavouriteExport => 'Favoriten exportieren';

  @override
  String get wallpaperFavouriteExportEmpty => 'Noch keine Favoriten zum Exportieren.';

  @override
  String get wallpaperFavouriteExportError => 'Favoriten konnten nicht exportiert werden. Versuche es erneut.';

  @override
  String get wallpaperFavouriteGuestPrompt => 'Melde dich an, damit deine Favoriten auf allen Geräten verfügbar sind';

  @override
  String get wallpaperFavouriteLoadError => 'Deine Favoriten konnten nicht geladen werden';

  @override
  String get wallpaperFavouriteMoreActions => 'Weitere Aktionen für Favoriten';

  @override
  String get wallpaperFavouriteNoMatch => 'Keine passenden Favoriten';

  @override
  String get wallpaperFavouriteNotSynced => 'Nicht synchronisiert';

  @override
  String get wallpaperFavouriteRefreshFallback =>
      'Favoriten konnten nicht aktualisiert werden. Deine gespeicherte Liste wird angezeigt.';

  @override
  String get wallpaperFavouriteRemove => 'Entfernen';

  @override
  String get wallpaperFavouriteRemoveAction => 'Aus Favoriten entfernen';

  @override
  String get wallpaperFavouriteRemoveError => 'Favoriten konnten nicht entfernt werden. Versuche es erneut.';

  @override
  String wallpaperFavouriteRemovedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Favoriten entfernt',
      one: '1 Favorit entfernt',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteRemovedOne => 'Aus Favoriten entfernt';

  @override
  String get wallpaperFavouriteRemovedToast => 'Aus Favoriten entfernt.';

  @override
  String get wallpaperFavouriteRestoreError => 'Favoriten konnten nicht wiederhergestellt werden.';

  @override
  String get wallpaperFavouriteSearchHint => 'Nach Künstler oder Kategorie suchen';

  @override
  String get wallpaperFavouriteSetUsesFirst => 'Festgelegt wird das zuerst ausgewählte Hintergrundbild';

  @override
  String get wallpaperFavouriteShareError => 'Teilen nicht möglich. Versuche es erneut.';

  @override
  String get wallpaperFavouriteSortOldest => 'Älteste zuerst';

  @override
  String get wallpaperFavouriteSortRecentlyAdded => 'Zuletzt hinzugefügt';

  @override
  String get wallpaperFavouriteSortSource => 'Quelle';

  @override
  String get wallpaperFavouriteStatus => 'In deinen Favoriten';

  @override
  String get wallpaperFavouriteTryDifferent => 'Versuche eine andere Suche oder Quelle.';

  @override
  String get wallpaperFavouriteUnavailableLegacy =>
      'Dieser Favorit stammt aus einer älteren Version und kann nicht geöffnet werden. Zum Entfernen gedrückt halten.';

  @override
  String get wallpaperFavouriteWaitingSync => 'Wartet auf Synchronisierung';

  @override
  String get wallpaperFavouritesTitle => 'Favoriten';

  @override
  String get wallpaperFeedAnnouncement => 'Ankündigung';

  @override
  String get wallpaperFeedCaughtUpBody => 'Ziehe zum Aktualisieren nach unten. Hier erscheinen neue Empfehlungen.';

  @override
  String get wallpaperFeedCaughtUpTitle => 'Du bist auf dem neuesten Stand';

  @override
  String get wallpaperFeedClearHistoryError => 'Verlauf konnte nicht geleert werden. Versuche es erneut.';

  @override
  String get wallpaperFeedDiscovery => 'Entdecken';

  @override
  String get wallpaperFeedEmptyBody =>
      'Folge Künstlern oder wähle Interessen aus, damit wir dir mehr von dem zeigen können, was dir gefällt.';

  @override
  String get wallpaperFeedEmptyTitle => 'Gestalte deinen Feed';

  @override
  String get wallpaperFeedFollowingEmptyTitle => 'Folge Künstlern, um ihre neuen Hintergrundbilder hier zu sehen';

  @override
  String get wallpaperFeedFollowingLoadError =>
      'Dein Feed mit neuen Beiträgen von Künstlern, denen du folgst, konnte nicht geladen werden';

  @override
  String get wallpaperFeedLatestLoadError => 'Die neuesten Hintergrundbilder konnten nicht geladen werden';

  @override
  String get wallpaperFeedLearnedFromYou => 'Von dir gelernt';

  @override
  String get wallpaperFeedLearningEmpty =>
      'Öffne, speichere und verwende Hintergrundbilder, um deinem Feed zu zeigen, was dir gefällt.';

  @override
  String get wallpaperFeedLearningHistoryCleared => 'Lernverlauf geleert';

  @override
  String get wallpaperFeedLoadError => 'Dein Feed konnte nicht geladen werden';

  @override
  String get wallpaperFeedLoadMoreError => 'Weitere Inhalte konnten nicht geladen werden. Versuche es erneut.';

  @override
  String get wallpaperFeedMixAdventurous => 'Abenteuerlustig';

  @override
  String get wallpaperFeedMixAdventurousDescription => 'Mehr Hintergrundbilder abseits deines Geschmacks.';

  @override
  String get wallpaperFeedMixBalanced => 'Ausgewogen';

  @override
  String get wallpaperFeedMixBalancedDescription => 'Dein Geschmack, mit ein paar Überraschungen.';

  @override
  String get wallpaperFeedMixFamiliar => 'Vertraut';

  @override
  String get wallpaperFeedMixFamiliarDescription => 'Vor allem das, was dir ohnehin gefällt.';

  @override
  String wallpaperFeedPickAtLeast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Wähle mindestens $countString aus';
  }

  @override
  String wallpaperFeedPickedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString ausgewählt';
  }

  @override
  String get wallpaperFeedPopularEmptyTitle => 'Noch keine beliebten Hintergrundbilder';

  @override
  String get wallpaperFeedPopularLoadError => 'Beliebte Hintergrundbilder konnten nicht geladen werden';

  @override
  String get wallpaperFeedPullToRefresh => 'Zum Aktualisieren nach unten ziehen.';

  @override
  String get wallpaperFeedRefreshError => 'Dein Feed konnte nicht aktualisiert werden.';

  @override
  String get wallpaperFeedSaveError => 'Feed-Einstellungen konnten nicht gespeichert werden. Versuche es erneut.';

  @override
  String get wallpaperFeedSettingsHint => 'Doppeltippen, um die Feed-Einstellungen zu öffnen';

  @override
  String get wallpaperFeedStartingPoints => 'Ausgangspunkte';

  @override
  String get wallpaperFeedTabFollowing => 'Ich folge';

  @override
  String get wallpaperFeedTabForYou => 'Für dich';

  @override
  String get wallpaperFeedTabLatest => 'Neueste';

  @override
  String get wallpaperFeedTabPopular => 'Beliebt';

  @override
  String get wallpaperFeedTabTrending => 'Im Trend';

  @override
  String get wallpaperFeedTuneDescription => 'Prism lernt daraus, was du öffnest, speicherst und festlegst.';

  @override
  String get wallpaperFeedTuneTitle => 'Passe deinen Feed an';

  @override
  String get wallpaperFeedUpdating => 'Wird aktualisiert';

  @override
  String get wallpaperFeedWallsLoadError => 'Hintergrundbilder konnten nicht geladen werden';

  @override
  String get wallpaperFewerLikeThisConfirmation => 'Du wirst weniger Hintergrundbilder dieser Art sehen.';

  @override
  String get wallpaperFewerLikeThisUndo => 'Rückgängig';

  @override
  String get wallpaperFileMovedOrDeleted => 'Die Datei wurde möglicherweise verschoben oder gelöscht.';

  @override
  String wallpaperFilterApplyCost(int coins, int missing) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'Dieser Filter kostet $coinsString Coins. Dir fehlen noch $missingString.';
  }

  @override
  String get wallpaperFilterBlur => 'Weichzeichnen';

  @override
  String get wallpaperFilterBrightness => 'Helligkeit';

  @override
  String get wallpaperFilterEffectEdge => 'Kanten';

  @override
  String get wallpaperFilterEffectEmboss => 'Relief';

  @override
  String get wallpaperFilterEffectHighPass => 'Hochpass';

  @override
  String get wallpaperFilterEffectSharpen => 'Schärfen';

  @override
  String get wallpaperFilterHoldToCompare => 'Zum Vergleichen gedrückt halten';

  @override
  String get wallpaperFilterHue => 'Farbton';

  @override
  String get wallpaperFilterLightness => 'Farbhelligkeit';

  @override
  String get wallpaperFilterLightnessUnavailable => 'Farbhelligkeit ist auf diesem Gerät nicht verfügbar.';

  @override
  String get wallpaperFilterNeedCoins => 'Für den Premium-Filter brauchst du Coins';

  @override
  String get wallpaperFilterOriginal => 'Original';

  @override
  String get wallpaperFilterSaturation => 'Sättigung';

  @override
  String get wallpaperFilterSaveError =>
      'Die Hintergrundbildfilter konnten nicht gespeichert werden. Bitte versuche es erneut!';

  @override
  String get wallpaperFilterTabAdjustments => 'Anpassen';

  @override
  String get wallpaperFilterTabFilters => 'Filter';

  @override
  String wallpaperFilterUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Premium-Filter für diese Bearbeitung freigeschaltet (−$coinsString Coins).';
  }

  @override
  String get wallpaperFitBlur => 'Mit Weichzeichner einpassen';

  @override
  String get wallpaperFitColour => 'Mit Farbe einpassen';

  @override
  String get wallpaperFitFill => 'Ausfüllen';

  @override
  String get wallpaperGenericError => 'Etwas ist schiefgelaufen!';

  @override
  String get wallpaperGoBack => 'Zurückgehen';

  @override
  String get wallpaperGotItFewerLikeThis => 'Verstanden. Du wirst weniger Hintergrundbilder dieser Art sehen.';

  @override
  String get wallpaperHidePreviewControls => 'Steuerelemente ausblenden';

  @override
  String get wallpaperHistoryBothScreens => 'Beide Bildschirme';

  @override
  String get wallpaperHistoryCurrent => 'Aktuell';

  @override
  String get wallpaperHistoryCurrentPrefix => 'Aktuell. ';

  @override
  String get wallpaperHistoryEmptyBody =>
      'Hier erscheinen Hintergrundbilder, die du festlegst. So kannst du sie erneut verwenden.';

  @override
  String get wallpaperHistoryEmptyTitle => 'Noch keine Hintergrundbilder';

  @override
  String get wallpaperHistoryRemoveAction => 'Aus dem Verlauf entfernen';

  @override
  String get wallpaperHomeAppName => 'Prism';

  @override
  String get wallpaperImageSemanticHint =>
      'Tippen, um die Akzentfarbe zu wechseln. Gedrückt halten für Favoriten, Teilen und Zurücksetzen. Für Details scrollen.';

  @override
  String get wallpaperPreviousInFeed => 'Vorheriges Hintergrundbild';

  @override
  String get wallpaperNextInFeed => 'Nächstes Hintergrundbild';

  @override
  String get wallpaperImageSemanticLabel => 'Hintergrundbild';

  @override
  String get wallpaperInsufficientCoins => 'Nicht genug Coins. Verdiene Coins bei „Belohnungen“.';

  @override
  String wallpaperInterestLearnedLabel(String label, int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Gelernt: $label, $percentString Prozent';
  }

  @override
  String wallpaperInterestSelectedLabel(String name, String selection) {
    return 'Interesse: $name, $selection';
  }

  @override
  String get wallpaperLandscapeCrop => 'Querformat-Hintergrundbild. Die Seiten werden abgeschnitten.';

  @override
  String get wallpaperLibraryCollections => 'Sammlungen';

  @override
  String get wallpaperLibraryDownloads => 'Downloads';

  @override
  String get wallpaperLibraryFavourites => 'Favoriten';

  @override
  String get wallpaperLibraryHistory => 'Verlauf';

  @override
  String get wallpaperLibraryTitle => 'Mediathek';

  @override
  String get wallpaperLive => 'Live';

  @override
  String get wallpaperLiveApplied => 'Live-Hintergrundbild festgelegt.';

  @override
  String wallpaperLiveApplyPhotoDescription(String style) {
    return 'Vorschau: $style';
  }

  @override
  String get wallpaperLiveBatterySaver => 'Energiesparmodus';

  @override
  String get wallpaperLiveChooseAnotherVideo => 'Anderes Video auswählen';

  @override
  String get wallpaperLiveChooseVideo => 'Video auswählen';

  @override
  String get wallpaperLiveConfirmPreview => 'Bestätige in der Systemvorschau.';

  @override
  String get wallpaperLiveDeviceUnavailable => 'Auf diesem Gerät nicht verfügbar';

  @override
  String get wallpaperLiveErrorGeneric => 'Live-Hintergrundbild konnte nicht festgelegt werden. Versuche es erneut.';

  @override
  String get wallpaperLiveErrorImageTooLarge => 'Dieses Bild ist für ein Live-Hintergrundbild zu groß.';

  @override
  String get wallpaperLiveErrorMemory => 'Nicht genug Speicher. Schließe andere Apps und versuche es erneut.';

  @override
  String get wallpaperLiveErrorNotAllowed =>
      'Dein Gerät oder Arbeitsprofil erlaubt keine Änderungen am Hintergrundbild.';

  @override
  String get wallpaperLiveErrorPermission => 'Prism darf diese Datei nicht lesen.';

  @override
  String get wallpaperLiveErrorPreview => 'Systemvorschau konnte nicht geöffnet werden.';

  @override
  String get wallpaperLiveErrorReadFile => 'Datei konnte nicht gelesen werden. Versuche es erneut.';

  @override
  String get wallpaperLiveErrorStyle =>
      'Dieser Stil konnte auf dem Gerät nicht gestartet werden. Probiere einen anderen.';

  @override
  String get wallpaperLiveErrorTimeout => 'Zeitüberschreitung. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get wallpaperLiveErrorTooLarge => 'Diese Datei ist für ein Live-Hintergrundbild zu groß.';

  @override
  String get wallpaperLiveErrorVideo =>
      'Dieses Video kann nicht als Hintergrundbild verwendet werden. Probiere einen anderen Clip.';

  @override
  String wallpaperLiveFps(int fps) {
    final intl.NumberFormat fpsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String fpsString = fpsNumberFormat.format(fps);

    return '$fpsString Bilder pro Sekunde';
  }

  @override
  String wallpaperLiveGradientDescription(String style) {
    return 'Vorschau: $style';
  }

  @override
  String wallpaperLiveGradientSwatch(String index, String count) {
    return 'Farbverlauf $index von $count';
  }

  @override
  String get wallpaperLiveKeepPrismOpen => 'Lass Prism geöffnet und versuche es erneut.';

  @override
  String get wallpaperLiveModeGradients => 'Farbverläufe';

  @override
  String get wallpaperLiveModePhoto => 'Foto animieren';

  @override
  String get wallpaperLiveModeVideo => 'Video';

  @override
  String get wallpaperLiveNoVideo => 'Kein Video ausgewählt';

  @override
  String get wallpaperLivePreviewInstruction =>
      'Android öffnet eine Vorschau. Tippe dort auf „Hintergrundbild festlegen“.';

  @override
  String get wallpaperLiveProStyleRequired => 'Dieser Stil ist Teil von Prism Pro.';

  @override
  String get wallpaperLiveSetAction => 'Live-Hintergrundbild festlegen';

  @override
  String get wallpaperLiveShaderUnsupported =>
      'Dieses Gerät unterstützt keine Shader-Live-Hintergrundbilder. Probiere Video aus.';

  @override
  String get wallpaperLiveStyleAurora => 'Aurora';

  @override
  String get wallpaperLiveStyleAuroraDescription => 'Sanfte Farbbänder.';

  @override
  String get wallpaperLiveStyleBreathe => 'Atmen';

  @override
  String get wallpaperLiveStyleBreatheDescription => 'Ein sanftes Pulsieren, ein und aus.';

  @override
  String get wallpaperLiveStyleDrift => 'Treiben';

  @override
  String get wallpaperLiveStyleDriftDescription =>
      'Langsames Schwenken und Zoomen, folgt deinen Wischbewegungen auf dem Startbildschirm.';

  @override
  String get wallpaperLiveStyleMesh => 'Netz';

  @override
  String get wallpaperLiveStyleMeshDescription => 'Vermischte Farben, die sich langsam verändern.';

  @override
  String get wallpaperLiveStylePlasma => 'Plasma';

  @override
  String get wallpaperLiveStylePlasmaDescription => 'Sanfte, fließende Farben.';

  @override
  String get wallpaperLiveStyleRipple => 'Kräuselung';

  @override
  String get wallpaperLiveStyleRippleDescription => 'Wasserringe, die sich bei Berührung ausbreiten.';

  @override
  String get wallpaperLiveStyleShimmer => 'Schimmern';

  @override
  String get wallpaperLiveStyleShimmerDescription => 'Ein sanfter Lichtschein, der über das Bild wandert.';

  @override
  String get wallpaperLiveStyleDepth => '3D';

  @override
  String get wallpaperLiveStyleDepthDescription =>
      'Das Foto bewegt sich in die Tiefe, wenn du zwischen Startbildschirmen wischst und das Handy neigst.';

  @override
  String get wallpaperLiveStyleStarfield => 'Sternenfeld';

  @override
  String get wallpaperLiveStyleStarfieldDescription => 'Funkelnde Sterne auf tiefschwarzem Hintergrund.';

  @override
  String wallpaperLiveStyleUnlocked(String style) {
    return '$style ist 7 Tage lang freigeschaltet.';
  }

  @override
  String get wallpaperLiveStyleWaves => 'Wellen';

  @override
  String get wallpaperLiveStyleWavesDescription => 'Mehrere sich bewegende Wellen.';

  @override
  String get wallpaperLiveTextureDownloadFailed =>
      'Hintergrundbild konnte nicht heruntergeladen werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get wallpaperLiveTexturePrepareFailed => 'Hintergrundbild konnte nicht vorbereitet werden.';

  @override
  String get wallpaperLiveTextureTooDetailed => 'Dieses Hintergrundbild ist zu detailreich für eine Animation.';

  @override
  String get wallpaperLiveTitle => 'Live-Hintergrundbilder';

  @override
  String get wallpaperLiveUnavailableBody =>
      'Dafür ist ein Android-Smartphone mit Unterstützung für OpenGL-Live-Hintergrundbilder erforderlich.';

  @override
  String get wallpaperLiveUnavailableTitle => 'Live-Hintergrundbilder sind nicht verfügbar';

  @override
  String wallpaperLiveUnlockCoins(String coins) {
    return 'Freischalten · $coins Coins';
  }

  @override
  String wallpaperLiveUnlockError(String style) {
    return '$style konnte nicht freigeschaltet werden. Versuche es erneut.';
  }

  @override
  String wallpaperLiveUnlockStyleAction(String style, String coins) {
    return '$style 7 Tage freischalten · $coins Coins';
  }

  @override
  String get wallpaperLiveUnlockStyleBody =>
      'Schalte den Stil 7 Tage lang mit Coins frei oder hol dir Prism Pro für alle Stile.';

  @override
  String wallpaperLiveUnlockStyleTitle(String style) {
    return '$style ist ein kostenpflichtiger Stil';
  }

  @override
  String get wallpaperLiveUnsupported => 'Dieses Gerät kann keine Live-Hintergrundbilder anzeigen.';

  @override
  String get wallpaperLiveVideoChosen => 'Video ausgewählt';

  @override
  String get wallpaperLiveVideoDescription => 'Wird ohne Ton auf deinem Startbildschirm abgespielt. Bis zu 256 MB.';

  @override
  String get wallpaperLiveVideoReadFailed => 'Video konnte nicht gelesen werden. Wähle es erneut aus.';

  @override
  String get wallpaperLiveVideoTooLarge => 'Dieses Video ist größer als 256 MB. Wähle einen kürzeren Clip.';

  @override
  String get wallpaperLiveVideoUnsupported => 'Dieses Gerät kann kein Video als Hintergrundbild abspielen.';

  @override
  String get wallpaperLoadingImage => 'Bild wird geladen';

  @override
  String get wallpaperLoadingWallpaper => 'Hintergrundbild wird geladen';

  @override
  String get wallpaperLowResolutionScreen => 'Niedrige Auflösung für deinen Bildschirm';

  @override
  String get wallpaperMakeItLive => 'Animieren';

  @override
  String get wallpaperMatchSystemColour => 'Systemfarbe übernehmen';

  @override
  String get wallpaperMoreLikeThis => 'Mehr davon';

  @override
  String get wallpaperNavCollections => 'Sammlungen';

  @override
  String get wallpaperNavHome => 'Startseite';

  @override
  String get wallpaperNavRewards => 'Belohnungen';

  @override
  String get wallpaperNavSearch => 'Suche';

  @override
  String get wallpaperNew => 'Neu';

  @override
  String get wallpaperNotNow => 'Nicht jetzt';

  @override
  String get wallpaperNotSelected => 'nicht ausgewählt';

  @override
  String get wallpaperNotificationPromptBody =>
      'Jeden Morgen ein handverlesenes Hintergrundbild und Erinnerungen an deine Serie. Kein Spam.';

  @override
  String get wallpaperNotificationPromptTitle => 'Entdecke das Hintergrundbild des Tages';

  @override
  String get wallpaperOffline => 'Offline';

  @override
  String wallpaperOldVersionBody(String version) {
    return 'Version $version wird nicht mehr unterstützt. Aktualisiere Prism, um es weiterhin zu nutzen.';
  }

  @override
  String get wallpaperOldVersionTitle => 'Zeit für ein Update';

  @override
  String get wallpaperOnPrism => 'Hintergrundbild auf Prism';

  @override
  String get wallpaperOpenError => 'Dieses Hintergrundbild konnte nicht geladen werden';

  @override
  String get wallpaperOpenFileError => 'Dieses Hintergrundbild konnte nicht geöffnet werden';

  @override
  String get wallpaperOpenNotifications => 'Benachrichtigungen öffnen';

  @override
  String get wallpaperOtherSource => 'Sonstiges';

  @override
  String get wallpaperPastPicksEmpty => 'Noch keine vergangenen Tagesauswahlen';

  @override
  String get wallpaperPastPicksLoadError => 'Vergangene Tagesauswahlen konnten nicht geladen werden';

  @override
  String get wallpaperPastPicksTitle => 'Frühere Auswahlen';

  @override
  String get wallpaperPlacementDim => 'Abdunkeln';

  @override
  String get wallpaperPositionApproximate => 'Ungefähr. Dein Launcher kann abweichen.';

  @override
  String get wallpaperPremium => 'Premium';

  @override
  String get wallpaperPremiumCollection => 'Premium-Sammlung';

  @override
  String wallpaperPremiumCollectionNamed(String name) {
    return 'Premium-Sammlung, $name';
  }

  @override
  String get wallpaperPreviewHome => 'Startbildschirm';

  @override
  String get wallpaperPreviewIconClear => 'Klar';

  @override
  String get wallpaperPreviewIconDark => 'Dunkel';

  @override
  String get wallpaperPreviewIconDefault => 'Standard';

  @override
  String get wallpaperPreviewIconStyle => 'Symbolstil';

  @override
  String get wallpaperPreviewIconThemed => 'Themenbasiert';

  @override
  String get wallpaperPreviewIconTinted => 'Getönt';

  @override
  String get wallpaperPreviewLock => 'Sperrbildschirm';

  @override
  String get wallpaperPreviewOnScreen => 'Vorschau auf deinem Bildschirm';

  @override
  String get wallpaperPreviewSetBoth => 'Auf beiden Bildschirmen festlegen';

  @override
  String get wallpaperPreviewSetHome => 'Auf Startbildschirm festlegen';

  @override
  String get wallpaperPreviewSetLock => 'Auf Sperrbildschirm festlegen';

  @override
  String wallpaperPreviewUnlock24Hours(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Für 24 Stunden freischalten (−$costString)';
  }

  @override
  String wallpaperPreviewUnlockCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Sieh dir diese Premium-Sammlung 24 Stunden lang für $costString Coins an.';
  }

  @override
  String wallpaperPreviewUnlockCostMissing(int cost, int missing) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'Eine Vorschau für 24 Stunden kostet $costString Coins. Dir fehlen noch $missingString.';
  }

  @override
  String wallpaperPreviewWatchAdUnlock(String adOption) {
    return '$adOption und freischalten';
  }

  @override
  String get wallpaperProcessing => 'Hintergrundbild wird verarbeitet';

  @override
  String get wallpaperProfileOpenError => 'Profil konnte nicht geöffnet werden';

  @override
  String get wallpaperQuickAddAction => 'Zu den Schnelleinstellungen hinzufügen';

  @override
  String get wallpaperQuickFavouriteDescription =>
      'Legt zufällig ein Hintergrundbild aus deinen Favoriten fest. Melde dich an und füge zuerst einige Hintergrundbilder zu deinen Favoriten hinzu.';

  @override
  String get wallpaperQuickFavouriteTitle => 'Kachel für zufälligen Favoriten';

  @override
  String get wallpaperQuickHowToTitle => 'Kachel hinzufügen';

  @override
  String get wallpaperQuickShuffleDescription =>
      'Tippe auf die Kachel, um zufällig ein Hintergrundbild aus der ausgewählten Kategorie festzulegen.';

  @override
  String get wallpaperQuickShuffleTitle => 'Kachel für zufälliges Hintergrundbild';

  @override
  String get wallpaperQuickStepEdit => 'Tippe auf den Stift oder das Bearbeitungssymbol.';

  @override
  String get wallpaperQuickStepFindPrism => 'Suche die Prism-Kacheln und ziehe sie zu deinen aktiven Kacheln.';

  @override
  String get wallpaperQuickStepShade => 'Wische zweimal nach unten, um die Benachrichtigungsleiste zu öffnen.';

  @override
  String get wallpaperQuickTargetBoth => 'Beide';

  @override
  String get wallpaperQuickTargetHome => 'Startbildschirm';

  @override
  String get wallpaperQuickTargetLock => 'Sperrbildschirm';

  @override
  String get wallpaperQuickTileAddError =>
      'Kachel konnte nicht hinzugefügt werden. Füge sie manuell über die Bearbeitung der Schnelleinstellungen hinzu.';

  @override
  String get wallpaperQuickTileAdded => 'Kachel zu den Schnelleinstellungen hinzugefügt.';

  @override
  String get wallpaperQuickTileAlreadyAdded => 'Diese Kachel ist bereits in den Schnelleinstellungen.';

  @override
  String get wallpaperQuickTileNotAdded => 'Kachel nicht hinzugefügt. Du kannst sie jederzeit hinzufügen.';

  @override
  String get wallpaperQuickTileSaveError =>
      'Einstellungen der Schnelleinstellungskachel konnten nicht gespeichert werden';

  @override
  String get wallpaperQuickTilesLoadError => 'Deine Schnelleinstellungskacheln konnten nicht geladen werden';

  @override
  String get wallpaperQuickTilesTitle => 'Schnelleinstellungskacheln';

  @override
  String get wallpaperQuickWotdDescription =>
      'Legt das Hintergrundbild des Tages fest. Öffne Prism einmal täglich, damit die neueste Auswahl gespeichert wird.';

  @override
  String get wallpaperQuickWotdTitle => 'Kachel „Hintergrundbild des Tages“';

  @override
  String get wallpaperRefresh => 'Aktualisieren';

  @override
  String get wallpaperRemovedFromHistory => 'Aus dem Verlauf entfernt';

  @override
  String get wallpaperReport => 'Melden';

  @override
  String get wallpaperReset => 'Zurücksetzen';

  @override
  String get wallpaperSave => 'Speichern';

  @override
  String get wallpaperSaveToPhotos => 'In Fotos speichern';

  @override
  String get wallpaperSavedOnDevice => 'Auf diesem Gerät gespeichert';

  @override
  String wallpaperSearchTag(String tag) {
    return 'Nach $tag suchen';
  }

  @override
  String get wallpaperSeePrismPro => 'Prism Pro ansehen';

  @override
  String get wallpaperSelected => 'ausgewählt';

  @override
  String get wallpaperServerUnavailable => 'Server nicht erreichbar';

  @override
  String get wallpaperSessionEnded => 'Deine Sitzung ist abgelaufen. Melde dich erneut an.';

  @override
  String get wallpaperSet => 'Festlegen';

  @override
  String get wallpaperSetAsWallpaper => 'Als Hintergrundbild festlegen';

  @override
  String wallpaperSetCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString-mal festgelegt',
      one: 'Einmal festgelegt',
    );
    return '$_temp0';
  }

  @override
  String get setScreenTargetHome => 'Startbildschirm';

  @override
  String get setScreenTargetLock => 'Sperrbildschirm';

  @override
  String get setScreenTargetBoth => 'Beide';

  @override
  String get setScreenTargetGroup => 'Wo festlegen';

  @override
  String get setScreenRemember => 'Auswahl merken';

  @override
  String get setScreenRememberHint =>
      'Festlegen überspringt diesen Bildschirm beim nächsten Mal. Halte Festlegen gedrückt, um zurückzukehren.';

  @override
  String get setScreenAdjust => 'Anpassen';

  @override
  String get setScreenMore => 'Mehr';

  @override
  String get setScreenPairLock => 'Anderes Hintergrundbild für den Sperrbildschirm verwenden';

  @override
  String get setScreenOpenSystemEditor => 'Systemeditor öffnen';

  @override
  String get setScreenClose => 'Schließen';

  @override
  String get wallpaperShare => 'Teilen';

  @override
  String get wallpaperShareLink => 'Link teilen';

  @override
  String get wallpaperShortcutsAddActionsSteps =>
      'Füge die Aktion „Prism-Hintergrundbild abrufen“ hinzu. Füge dann die Aktion „Hintergrundbild festlegen“ hinzu.';

  @override
  String get wallpaperShortcutsBody =>
      'Nutze Kurzbefehle, um ein Hintergrundbild nach Zeitplan oder Auslöser festzulegen. Bereite vorher die Quelle unten vor.';

  @override
  String get wallpaperShortcutsChoosePrismData => 'Wähle aus, was Prism sendet';

  @override
  String get wallpaperShortcutsChooseTriggerSteps =>
      'Öffne im Kurzbefehl-Editor bei Bedarf Automation. Wähle und konfiguriere einen Auslöser, etwa Tageszeit, Öffnen einer App oder Anschließen eines Ladegeräts.';

  @override
  String get wallpaperShortcutsDisableConfirmationSteps =>
      'Prüfe die angezeigten Ausführungsoptionen und speichere den Kurzbefehl oder die Automation. Falls \"Vor Ausführen bestätigen\" erscheint, schalte es für automatische Ausführungen aus.';

  @override
  String get wallpaperShortcutsHeadline => 'Hintergrundbild automatisch ändern';

  @override
  String get wallpaperShortcutsOpenAction => 'Kurzbefehle öffnen';

  @override
  String get wallpaperShortcutsOpenAutomationSteps =>
      'Öffne Kurzbefehle. Gibt es einen Tab \"Automation\", tippe darauf und dann auf \"Neue Automation\". Sonst tippe auf Hinzufügen (+) und auf Bearbeiten, falls es angezeigt wird.';

  @override
  String get wallpaperShortcutsOpenError => 'Kurzbefehle konnten nicht geöffnet werden. Öffne die App selbst.';

  @override
  String get wallpaperShortcutsSourceFavourite => 'Zufälliger Favorit';

  @override
  String get wallpaperShortcutsSourceFavouriteDescription =>
      'Ein zufälliger, für Kurzbefehle verfügbarer Favorit. Markiere zuerst Hintergrundbilder in Prism mit einem Herz. Manche geschützten Bilder sind nicht verfügbar. Wenn ein anderer Favorit verfügbar ist, wird die letzte Auswahl übersprungen.';

  @override
  String get wallpaperShortcutsSourceWotd => 'Hintergrundbild des Tages';

  @override
  String get wallpaperShortcutsSourceWotdDescription =>
      'Die heutige Prism-Auswahl. Lade zuerst das heutige Original in Prism herunter. Wenn die Tagesauswahl wechselt, lade vor der nächsten Nutzung dieser Quelle das neue Original herunter.';

  @override
  String get wallpaperShortcutsSteps => 'Schritte';

  @override
  String get wallpaperShortcutsTitle => 'Automatisch ändern';

  @override
  String get wallpaperShowLessLikeThis => 'Weniger davon anzeigen';

  @override
  String get wallpaperShowPreviewControls => 'Steuerelemente einblenden';

  @override
  String get wallpaperSignIn => 'Anmelden';

  @override
  String get wallpaperSignInForPremiumFilters => 'Melde dich an, um Premium-Filter mit Coins zu verwenden.';

  @override
  String get wallpaperSortDownloads => 'Downloads sortieren';

  @override
  String get wallpaperStartupFailed => 'Prism konnte nicht gestartet werden';

  @override
  String get wallpaperThemeDarkAccent => 'Akzentfarbe für dunkles Design';

  @override
  String get wallpaperThemeDarkThemes => 'Dunkle Designs';

  @override
  String get wallpaperUseAsAppAccent => 'Als App-Akzentfarbe verwenden';

  @override
  String get wallpaperAppAccentUpdated => 'App-Akzentfarbe aktualisiert';

  @override
  String get wallpaperThemeLightAccent => 'Akzentfarbe für helles Design';

  @override
  String get wallpaperThemeLightThemes => 'Helle Designs';

  @override
  String get wallpaperThemeModeDark => 'Dunkel';

  @override
  String get wallpaperThemeModeLight => 'Hell';

  @override
  String get wallpaperThemeModeSystem => 'System (hell/dunkel)';

  @override
  String get wallpaperThemePreference => 'Design-Einstellung';

  @override
  String get wallpaperThemePreferenceDescription =>
      'Wähle dein bevorzugtes Design. Im Systemmodus wechselt es automatisch passend zum Design deines Geräts.';

  @override
  String get wallpaperThemeTitle => 'Designs';

  @override
  String get wallpaperTitle => 'Titel';

  @override
  String get wallpaperTrendingEmptyTitle => 'Noch nichts im Trend';

  @override
  String get wallpaperTrendingLoadError => 'Hintergrundbilder im Trend konnten nicht geladen werden';

  @override
  String get wallpaperTryAgain => 'Erneut versuchen';

  @override
  String get wallpaperTurnOff => 'Ausschalten';

  @override
  String get wallpaperTurnOnNotifications => 'Benachrichtigungen einschalten';

  @override
  String get wallpaperUnavailable => 'Nicht verfügbar';

  @override
  String get wallpaperUnfavourite => 'Aus Favoriten entfernen';

  @override
  String get wallpaperUnreadItems => 'Enthält ungelesene Elemente';

  @override
  String get wallpaperUpdatePrism => 'Prism aktualisieren';

  @override
  String get wallpaperUploadAction => 'Hochladen';

  @override
  String get wallpaperUploadAddTag => 'Tag hinzufügen';

  @override
  String get wallpaperUploadAddTagHint => 'Füge einen Tag hinzu und tippe dann auf „Fertig“';

  @override
  String get wallpaperUploadAiSubtitle => 'Beschreibe eine Szene und erstelle ein Hintergrundbild fürs Smartphone';

  @override
  String get wallpaperUploadApprovalInfo =>
      'Nach der Freigabe erscheint dein Hintergrundbild in der Community. Verfolge den Status unter „Deine Uploads“.';

  @override
  String wallpaperUploadBatchPosition(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Hintergrundbild $positionString von $totalString';
  }

  @override
  String wallpaperUploadBatchSubmitted(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label. $countString eingereicht.';
  }

  @override
  String wallpaperUploadBatchSummaryNotSent(String submitted, int notSent) {
    final intl.NumberFormat notSentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String notSentString = notSentNumberFormat.format(notSent);

    return '$submitted. $notSentString nicht gesendet.';
  }

  @override
  String wallpaperUploadBatchSummarySubmitted(int submittedCount, int total) {
    final intl.NumberFormat submittedCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String submittedCountString = submittedCountNumberFormat.format(submittedCount);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$submittedCountString von $totalString Hintergrundbildern eingereicht';
  }

  @override
  String get wallpaperUploadBrightness => 'Helligkeit';

  @override
  String get wallpaperUploadCheckReviewStatus => 'Prüfstatus ansehen';

  @override
  String get wallpaperUploadChooseAnotherImage => 'Anderes Bild auswählen';

  @override
  String get wallpaperUploadContinueDraft => 'Gespeichertes Hintergrundbild weiter bearbeiten';

  @override
  String get wallpaperUploadContrast => 'Kontrast';

  @override
  String get wallpaperUploadCreateTitle => 'Erstellen';

  @override
  String get wallpaperUploadDeleteConfirmTitle => 'Dieses Hintergrundbild löschen?';

  @override
  String get wallpaperUploadDeleteError => 'Löschen nicht möglich. Versuche es erneut.';

  @override
  String get wallpaperUploadDeletePermissionError =>
      'Löschen nicht möglich. Melde dich mit dem Konto an, mit dem du es hochgeladen hast, und versuche es erneut.';

  @override
  String get wallpaperUploadDeleteWallpaper => 'Hintergrundbild löschen';

  @override
  String get wallpaperUploadDeleted => 'Hintergrundbild gelöscht.';

  @override
  String get wallpaperUploadDetailsOptional => 'Details (optional)';

  @override
  String get wallpaperUploadDiscardBody =>
      'Hochgeladene Dateien werden entfernt. Das ausgewählte Bild bleibt auf deinem Gerät.';

  @override
  String get wallpaperUploadDiscardEditsBody => 'Deine Änderungen gehen verloren.';

  @override
  String get wallpaperUploadDiscardEditsTitle => 'Änderungen verwerfen?';

  @override
  String get wallpaperUploadDiscardError => 'Upload konnte nicht verworfen werden. Versuche es erneut.';

  @override
  String get wallpaperUploadDiscardTitle => 'Diesen Upload verwerfen?';

  @override
  String get wallpaperUploadDownloadError => 'Herunterladen nicht möglich. Versuche es erneut.';

  @override
  String get wallpaperUploadDownloadStarting => 'Download wird gestartet';

  @override
  String get wallpaperUploadDraftSaveError => 'Entwurf konnte nicht gespeichert werden. Versuche es erneut.';

  @override
  String wallpaperUploadEditBatch(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Hintergrundbild $positionString von $totalString bearbeiten';
  }

  @override
  String get wallpaperUploadEditSaveError => 'Deine Änderungen konnten nicht gespeichert werden. Versuche es erneut.';

  @override
  String get wallpaperUploadFileSize => 'Dateigröße';

  @override
  String get wallpaperUploadFilesCheckActive => 'Hintergrundbild und Vorschau werden hochgeladen';

  @override
  String get wallpaperUploadFilesCheckDone => 'Hintergrundbild und Vorschau hochgeladen';

  @override
  String get wallpaperUploadFilesCheckPending => 'Hintergrundbild und Vorschau hochladen';

  @override
  String get wallpaperUploadFilesRemoveError =>
      'Hochgeladene Dateien konnten nicht entfernt werden. Versuche es erneut.';

  @override
  String get wallpaperUploadFlip => 'Spiegeln';

  @override
  String wallpaperUploadFreeQuotaMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Kostenlose Konten können $countString Hintergrundbilder pro Woche hochladen.';
  }

  @override
  String get wallpaperUploadFromGallery => 'Aus deiner Galerie';

  @override
  String get wallpaperUploadFullImageError => 'Das vollständige Bild konnte nicht geladen werden.';

  @override
  String get wallpaperUploadInReview => 'Wird geprüft';

  @override
  String get wallpaperUploadKeepDraft => 'Entwurf behalten';

  @override
  String get wallpaperUploadLeaveBody =>
      'Behalte den Entwurf, um später weiterzumachen, oder verwerfe ihn und entferne die hochgeladenen Dateien.';

  @override
  String get wallpaperUploadLeaveTitle => 'Upload verlassen?';

  @override
  String wallpaperUploadMaxTagsReached(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Du hast $countString Tags hinzugefügt';
  }

  @override
  String get wallpaperUploadOriginalContentGuideline =>
      'Lade nur eigene, hochwertige Hintergrundbilder hoch. Lade keine Inhalte aus anderen Apps hoch.';

  @override
  String get wallpaperUploadPrepareCheckActive => 'Bild und kleinere Vorschau werden vorbereitet';

  @override
  String get wallpaperUploadPrepareCheckDone => 'Bild und Vorschau sind bereit';

  @override
  String get wallpaperUploadPrepareCheckPending => 'Bild und kleinere Vorschau vorbereiten';

  @override
  String get wallpaperUploadPrepareError =>
      'Bild konnte nicht vorbereitet werden. Versuche es erneut oder wähle ein anderes Bild.';

  @override
  String get wallpaperUploadQualityLandscape =>
      'Dieses Bild ist breit. Smartphone-Hintergrundbilder sehen im Hochformat am besten aus.';

  @override
  String wallpaperUploadQualityLowResolution(int width, int height, int recommendedShortSide) {
    final intl.NumberFormat widthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String widthString = widthNumberFormat.format(width);
    final intl.NumberFormat recommendedShortSideNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String recommendedShortSideString = recommendedShortSideNumberFormat.format(recommendedShortSide);

    return 'Dieses Bild hat $widthString × $height Pixel. Auf einem Smartphone kann es unscharf wirken. Mindestens $recommendedShortSideString Pixel an der kurzen Seite sind ideal.';
  }

  @override
  String get wallpaperUploadQuotaCleanupFailed =>
      'Du hast das Upload-Limit erreicht, aber die hochgeladenen Dateien konnten nicht entfernt werden. Tippe auf „Zurück“, um es erneut zu versuchen.';

  @override
  String get wallpaperUploadQuotaReached =>
      'Du hast das wöchentliche Limit für kostenlose Hintergrundbild-Uploads erreicht.';

  @override
  String wallpaperUploadQuotaRemaining(int remaining, int total) {
    final intl.NumberFormat remainingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Diese Woche noch $remainingString von $totalString kostenlosen Uploads verfügbar';
  }

  @override
  String get wallpaperUploadRejected => 'Abgelehnt';

  @override
  String get wallpaperUploadRejectedSectionError => 'Abgelehnte Einreichungen konnten nicht geladen werden.';

  @override
  String get wallpaperUploadRejectionFallback =>
      'Es wurde kein bestimmter Grund angegeben. Prüfe deine Hintergrundbild-Details und lade es erneut hoch.';

  @override
  String get wallpaperUploadRejectionTitle => 'Warum wurde es abgelehnt?';

  @override
  String wallpaperUploadRemoveTag(String tag) {
    return 'Tag $tag entfernen';
  }

  @override
  String get wallpaperUploadResetAdjustments => 'Anpassungen zurücksetzen';

  @override
  String get wallpaperUploadResolution => 'Auflösung';

  @override
  String get wallpaperUploadResumeDraft => 'Gespeicherten Upload fortsetzen';

  @override
  String get wallpaperUploadRetrySubmit => 'Erneut einreichen';

  @override
  String get wallpaperUploadReviewCheckActive => 'Einreichung wird zur Prüfung gespeichert';

  @override
  String get wallpaperUploadReviewCheckDone => 'Zur Prüfung eingereicht';

  @override
  String get wallpaperUploadReviewCheckPending =>
      'Moderatoren prüfen das Hintergrundbild, bevor es auf Prism erscheint';

  @override
  String get wallpaperUploadReviewEmptyBody => 'Hier siehst du den Prüfstatus deiner hochgeladenen Hintergrundbilder.';

  @override
  String get wallpaperUploadReviewEmptyTitle => 'Noch nichts vorhanden';

  @override
  String get wallpaperUploadReviewLoadError => 'Deine Uploads konnten nicht geladen werden';

  @override
  String get wallpaperUploadReviewSectionError => 'Deine Einreichungen konnten nicht geladen werden.';

  @override
  String get wallpaperUploadRotateLeft => 'Nach links drehen';

  @override
  String get wallpaperUploadRotateRight => 'Nach rechts drehen';

  @override
  String get wallpaperUploadSaturation => 'Sättigung';

  @override
  String get wallpaperUploadSavedToPictures => 'Hintergrundbild in Pictures/Prism gespeichert';

  @override
  String get wallpaperUploadSkip => 'Dieses Hintergrundbild überspringen';

  @override
  String get wallpaperUploadStagePrepareFailed => 'Bild konnte nicht vorbereitet werden';

  @override
  String get wallpaperUploadStagePreparing => 'Hintergrundbild wird vorbereitet';

  @override
  String get wallpaperUploadStageQuotaReached => 'Upload-Limit erreicht';

  @override
  String get wallpaperUploadStageReady => 'Zum Einreichen bereit';

  @override
  String get wallpaperUploadStageSubmissionFailed => 'Einreichung nicht abgeschlossen';

  @override
  String get wallpaperUploadStageSubmitting => 'Hintergrundbild wird eingereicht';

  @override
  String get wallpaperUploadStageUploadFailed => 'Upload nicht abgeschlossen';

  @override
  String get wallpaperUploadStageUploading => 'Hintergrundbild wird hochgeladen';

  @override
  String get wallpaperUploadSubmissionUnconfirmed =>
      'Einreichung konnte nicht bestätigt werden. Prüfe den Prüfstatus, bevor du es erneut versuchst.';

  @override
  String get wallpaperUploadTags => 'Tags';

  @override
  String wallpaperUploadTagsHelp(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Bis zu $countString. Mit Tags finden andere dein Hintergrundbild.';
  }

  @override
  String get wallpaperUploadTitle => 'Hintergrundbild hochladen';

  @override
  String get wallpaperUploadTitleHint => 'Benenne dein Hintergrundbild';

  @override
  String get wallpaperUploadViewWallpaper => 'Hintergrundbild ansehen';

  @override
  String get wallpaperUploadYourUploads => 'Deine Uploads';

  @override
  String get wallpaperUsePhoneAccent => 'Akzentfarbe deines Smartphones verwenden';

  @override
  String get wallpaperThemeMaterialYouNote => 'Material You übernimmt die Farben von deinem Hintergrundbild.';

  @override
  String wallpaperViewCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString Aufrufe', one: '1 Aufruf');
    return '$_temp0';
  }

  @override
  String get wallpaperViewCountUnavailable => 'Aufrufzahl nicht verfügbar';

  @override
  String wallpaperWotdByPhotographer(String name) {
    return 'Hintergrundbild des Tages von $name';
  }

  @override
  String get economyAiPromptSceneAnime1 => 'Eine Katze döst auf dem sonnigen Bahnsteig';

  @override
  String get economyAiPromptSceneAnime2 => 'Hohe Sommerwolken über Reisfeldern';

  @override
  String get economyAiPromptSceneAnime3 => 'Ein Ramen-Stand leuchtet in regnerischer Gasse';

  @override
  String get economyAiPromptSceneAnime4 => 'Ein Schreintor auf dem Hügel über Wolken';

  @override
  String get economyAiPromptSceneAnime5 => 'Feuerwerk über dem Fluss beim Sommerfest';

  @override
  String get economyAiPromptSceneAnime6 => 'Ein stilles Klassenzimmer, Blütenblätter wehen';

  @override
  String get economyAiPromptSceneAnime7 => 'Küstenstraße mit einsamer Bushaltestelle';

  @override
  String get economyAiPromptSceneAnime8 => 'Ein Himmelswal über einer verschlafenen Stadt';

  @override
  String get economyAiPromptSceneMinimal1 => 'Ein Papierboot auf stillem, hellem Wasser';

  @override
  String get economyAiPromptSceneMinimal2 => 'Ein Lichtbogen über leerer Ebene';

  @override
  String get economyAiPromptSceneMinimal3 => 'Ein einsamer Baum am sanften Schneehang';

  @override
  String get economyAiPromptSceneMinimal4 => 'Zwei sich überlappende Kreise auf Körnung';

  @override
  String get economyAiPromptSceneMinimal5 => 'Eine feine Horizontlinie trennt Meer und Himmel';

  @override
  String get economyAiPromptSceneMinimal6 => 'Eine einzelne Feder fällt durch leeren Raum';

  @override
  String get economyAiPromptSceneMinimal7 => 'Gestapelte glatte Kiesel vor hellem Grund';

  @override
  String get economyAiPromptSceneMinimal8 => 'Ein Schattenbogen auf weicher Putzwand';

  @override
  String get economyAiPromptSceneCyberpunk1 => 'Eine Nudelbar im Neonlicht und Regen';

  @override
  String get economyAiPromptSceneCyberpunk2 => 'Eine Schwebebahn zwischen Megatürmen';

  @override
  String get economyAiPromptSceneCyberpunk3 => 'Ein einsamer Androide auf dem Dach im Regen';

  @override
  String get economyAiPromptSceneCyberpunk4 => 'Eine leuchtende Datenstraße in die Megacity';

  @override
  String get economyAiPromptSceneCyberpunk5 => 'Ein Nachtmarkt unter einem Kabelgewirr';

  @override
  String get economyAiPromptSceneCyberpunk6 => 'Ein Chrom-Motorrad in einer Neon-Gasse';

  @override
  String get economyAiPromptSceneCyberpunk7 => 'Ein Hologramm-Mond über den Stadttürmen';

  @override
  String get economyAiPromptSceneCyberpunk8 => 'Eine überflutete Straße spiegelt Bildschirme';

  @override
  String get economyAiPromptSceneWatercolor1 => 'Ein Lavendelfeld im Morgennebel';

  @override
  String get economyAiPromptSceneWatercolor2 => 'Ein kleines Fischerdorf am ruhigen Hafen';

  @override
  String get economyAiPromptSceneWatercolor3 => 'Wilder Mohn am Rand eines Feldwegs';

  @override
  String get economyAiPromptSceneWatercolor4 => 'Ein Heißluftballon über grünen Hügeln';

  @override
  String get economyAiPromptSceneWatercolor5 => 'Ein Reiher im schilfreichen Teich';

  @override
  String get economyAiPromptSceneWatercolor6 => 'Eine Regenstraße mit verschwommenen Laternen';

  @override
  String get economyAiPromptSceneWatercolor7 => 'Eine dampfende Teetasse am offenen Fenster';

  @override
  String get economyAiPromptSceneWatercolor8 => 'Verschneite Kiefern an einem Eisbach';

  @override
  String get economyAiPromptSceneMeshGradient1 => 'Weiche Farbflecken, die ineinander verfließen';

  @override
  String get economyAiPromptSceneMeshGradient2 => 'Eine seidige Farbverlaufswelle, die sich faltet';

  @override
  String get economyAiPromptSceneMeshGradient3 => 'Leuchtende Kugeln auf samtigem Grund';

  @override
  String get economyAiPromptSceneMeshGradient4 => 'Ein Verlauf wie Polarlicht, aufwärts strömend';

  @override
  String get economyAiPromptSceneMeshGradient5 => 'Flüssige Farbpfützen mit feiner Körnung';

  @override
  String get economyAiPromptSceneMeshGradient6 => 'Ein warm-kalter Verlauf mit zartem Rauschen';

  @override
  String get economyAiPromptSceneMeshGradient7 => 'Überlappende, durchscheinende Verlaufsblätter';

  @override
  String get economyAiPromptSceneMeshGradient8 => 'Verschwommener Sonnenuntergang aus Farbbändern';

  @override
  String get economyAiPromptSceneAbstract1 => 'Ineinandergreifende Glasscherben im Licht';

  @override
  String get economyAiPromptSceneAbstract2 => 'Fließende Tintenwolken im Wasser';

  @override
  String get economyAiPromptSceneAbstract3 => 'Eine Spirale aus gefalteten Bändern';

  @override
  String get economyAiPromptSceneAbstract4 => 'Zersplitterter Marmor mit Goldadern';

  @override
  String get economyAiPromptSceneAbstract5 => 'Gewellte Höhenlinien in Schichten';

  @override
  String get economyAiPromptSceneAbstract6 => 'Schwebende Kugeln mit langen Schatten';

  @override
  String get economyAiPromptSceneAbstract7 => 'Rauchfäden, die sich zum Wirbel drehen';

  @override
  String get economyAiPromptSceneAbstract8 => 'Ein Feld weicher Würfel in Wellen';

  @override
  String get economyAiPromptSceneNature1 => 'Ein Wasserfall stürzt in eine moosige Schlucht';

  @override
  String get economyAiPromptSceneNature2 => 'Ein Sonnenblumenfeld unter weitem Himmel';

  @override
  String get economyAiPromptSceneNature3 => 'Ein zugefrorener See mit blauen Eisrissen';

  @override
  String get economyAiPromptSceneNature4 => 'Kirschbäume am stillen Flussweg';

  @override
  String get economyAiPromptSceneNature5 => 'Eine tropische Lagune von oben';

  @override
  String get economyAiPromptSceneNature6 => 'Herbstahorn spiegelt sich im stillen Teich';

  @override
  String get economyAiPromptSceneNature7 => 'Ein einsamer Fuchs im Neuschnee bei Dämmerung';

  @override
  String get economyAiPromptSceneNature8 => 'Gewitterwolken über grünem Hochland';

  @override
  String get economyAiPromptSceneSpace1 => 'Ein Ringplanet geht über dem Mondhorizont auf';

  @override
  String get economyAiPromptSceneSpace2 => 'Eine Spiralgalaxie leuchtet im tiefen All';

  @override
  String get economyAiPromptSceneSpace3 => 'Ein Astronaut schwebt über einem blauen Planeten';

  @override
  String get economyAiPromptSceneSpace4 => 'Ein Nebel in Form einer blühenden Blume';

  @override
  String get economyAiPromptSceneSpace5 => 'Zwei Sonnen sinken über einer fremden Wüste';

  @override
  String get economyAiPromptSceneSpace6 => 'Eine Raumstation umkreist einen Gasriesen';

  @override
  String get economyAiPromptSceneSpace7 => 'Ein Meteorschauer über der stillen Sternwarte';

  @override
  String get economyAiPromptSceneSpace8 => 'Eine Sonnenfinsternis mit hellem Diamantring';

  @override
  String get economyAiPromptSceneSynthwave1 => 'Neon-Gitterstraße zum Sonnenuntergang';

  @override
  String get economyAiPromptSceneSynthwave2 => 'Eine palmengesäumte Küste unter Streifensonne';

  @override
  String get economyAiPromptSceneSynthwave3 => 'Ein Retro-Sportwagen auf endloser Autobahn';

  @override
  String get economyAiPromptSceneSynthwave4 => 'Gittermodell-Berge unter magentafarbenem Himmel';

  @override
  String get economyAiPromptSceneSynthwave5 => 'Eine Chromsonne versinkt im leuchtenden Meer';

  @override
  String get economyAiPromptSceneSynthwave6 => 'Retro-Spielhalle in regnerischer Nacht';

  @override
  String get economyAiPromptSceneSynthwave7 => 'Eine Kassette schwebt im Neon-Weltraum';

  @override
  String get economyAiPromptSceneSynthwave8 => 'Eine einsame Palme vor Laser-Horizont';

  @override
  String get economyAiPromptScenePixelArt1 => 'Eine gemütliche Hütte im Winterwald bei Nacht';

  @override
  String get economyAiPromptScenePixelArt2 => 'Eine Burg auf der Klippe über dem Meer';

  @override
  String get economyAiPromptScenePixelArt3 => 'Eine winzige Stadt mit leuchtenden Fenstern';

  @override
  String get economyAiPromptScenePixelArt4 => 'Ein Raumschiff über violetter Fremdwelt';

  @override
  String get economyAiPromptScenePixelArt5 => 'Ein Wasserfall im üppigen Dschungeltal';

  @override
  String get economyAiPromptScenePixelArt6 => 'Ein Angelsteg unter dem Vollmond';

  @override
  String get economyAiPromptScenePixelArt7 => 'Ein Kirschblütentempel im Frühling';

  @override
  String get economyAiPromptScenePixelArt8 => 'Ein Zug quert bei Sonnenuntergang eine Brücke';

  @override
  String get economyAiPromptSceneRender3d1 => 'Glänzende Tonformen, ausbalanciert gestapelt';

  @override
  String get economyAiPromptSceneRender3d2 => 'Bänder aus Milchglas auf Pastellbühne';

  @override
  String get economyAiPromptSceneRender3d3 => 'Eine kleine Insel auf einer weichen Wolke';

  @override
  String get economyAiPromptSceneRender3d4 => 'Aufgeblasene Chromblasen im weichen Licht';

  @override
  String get economyAiPromptSceneRender3d5 => 'Eine Miniaturwüste mit einsamem Kaktus';

  @override
  String get economyAiPromptSceneRender3d6 => 'Ein gemütliches Zimmer-Diorama im Würfel';

  @override
  String get economyAiPromptSceneRender3d7 => 'Schwebende Marmorbögen über stillem Wasser';

  @override
  String get economyAiPromptSceneRender3d8 => 'Bonbonfarbene Wellen, in Bewegung erstarrt';

  @override
  String get economyAiPromptSceneOilPainting1 => 'Stürmische See, die an Felsen brandet';

  @override
  String get economyAiPromptSceneOilPainting2 => 'Sonnige Mohnwiese mit einem Bauernhaus';

  @override
  String get economyAiPromptSceneOilPainting3 => 'Stillleben mit Zitronen und blauer Vase';

  @override
  String get economyAiPromptSceneOilPainting4 => 'Neblige Hafenmorgen mit alten Schiffen';

  @override
  String get economyAiPromptSceneOilPainting5 => 'Ein Waldweg in glühenden Herbstfarben';

  @override
  String get economyAiPromptSceneOilPainting6 => 'Ein mondheller Kanal mit alten Häusern';

  @override
  String get economyAiPromptSceneOilPainting7 => 'Ein Weizenfeld wogt vor dem Sturm';

  @override
  String get economyAiPromptSceneOilPainting8 => 'Eine Rose im Glas auf dunklem Tisch';

  @override
  String get economyAiPromptSceneUkiyoE1 => 'Eine große Welle unter fahlem Mond';

  @override
  String get economyAiPromptSceneUkiyoE2 => 'Eine verschneite Pagode in der Dämmerung';

  @override
  String get economyAiPromptSceneUkiyoE3 => 'Kraniche fliegen über einen Nebelberg';

  @override
  String get economyAiPromptSceneUkiyoE4 => 'Eine Holzbrücke unter fallenden Kirschblüten';

  @override
  String get economyAiPromptSceneUkiyoE5 => 'Fischerboote auf rauer Indigo-See';

  @override
  String get economyAiPromptSceneUkiyoE6 => 'Eine rote Sonne über einem Vulkangipfel';

  @override
  String get economyAiPromptSceneUkiyoE7 => 'Ein Koi-Teich unter Trauerweiden';

  @override
  String get economyAiPromptSceneUkiyoE8 => 'Regen über einer stillen Flussstadt';

  @override
  String get economyAiPromptLightingMorningHaze => 'zarter Morgendunst';

  @override
  String get economyAiPromptLightingGoldenHour => 'goldene Stunde';

  @override
  String get economyAiPromptLightingMoonlight => 'kühles Mondlicht';

  @override
  String get economyAiPromptLightingNeonRim => 'Neon-Kantenlicht';

  @override
  String get economyAiPromptLightingBacklight => 'warmes Gegenlicht';

  @override
  String get economyAiPromptLightingGodRays => 'Lichtstrahlen';

  @override
  String get economyAiPromptLightingStudio => 'Studiolicht';

  @override
  String get economyAiPromptLightingTwilight => 'blaue Dämmerung';

  @override
  String get economyAiPromptPaletteTealAmber => 'Petrol und Bernstein';

  @override
  String get economyAiPromptPaletteIndigoRose => 'Indigo und Rosé';

  @override
  String get economyAiPromptPaletteSageCream => 'Salbeigrün und Creme';

  @override
  String get economyAiPromptPaletteBlackNeonPink => 'Schwarz, Neonpink';

  @override
  String get economyAiPromptPalettePastelPeach => 'Pastellpfirsich';

  @override
  String get economyAiPromptPaletteEmeraldGold => 'Smaragd und Gold';

  @override
  String get economyAiPromptPaletteOceanBlue => 'Ozeanblau-Töne';

  @override
  String get economyAiPromptPaletteCrimsonCharcoal => 'Rot und Anthrazit';

  @override
  String get economyAiPromptSuffix => 'Smartphone-Hintergrund hochkant, ohne Text';

  @override
  String economyAiPromptComposition(String scene, String lighting, String palette, String suffix) {
    return '$scene, $lighting, $palette. $suffix';
  }

  @override
  String economyAiPromptSceneOnly(String scene, String suffix) {
    return '$scene, $suffix';
  }

  @override
  String get economyAiMadeWithPrism => 'Mit Prism AI erstellt';

  @override
  String get onboardingAiPromptFallback => 'ein wunderschönes Hintergrundbild';

  @override
  String get onboardingAiPromptNature1 => 'Ein Gletschersee bei Sonnenaufgang, spiegelglatt, rosa Berggipfel';

  @override
  String get onboardingAiPromptNature2 => 'Ein moosiger Waldbach, weiches Licht fällt durch hohe Farne';

  @override
  String get onboardingAiPromptNature3 => 'Eine Wildblumenwiese unter weitem Abendhimmel mit ziehenden Wolken';

  @override
  String get onboardingAiPromptNature4 => 'Ein schwarzer Sandstrand mit türkisen Wellen und Felsnadeln im Abendlicht';

  @override
  String get onboardingAiPromptNature5 => 'Nordlichter über verschneitem Kiefernwald an einem gefrorenen See';

  @override
  String get onboardingAiPromptAbstract1 =>
      'Durchscheinende Glasbänder winden sich durch weiches Licht, schillernde Kanten';

  @override
  String get onboardingAiPromptAbstract2 => 'Tintenwolken blühen im Wasser, tiefes Blau und Gold, weiche Details';

  @override
  String get onboardingAiPromptAbstract3 =>
      'Geschichtete Papierwellen in warmen Sonnenuntergangsfarben, sanfte Schatten';

  @override
  String get onboardingAiPromptAbstract4 => 'Ein gemeißelter Marmorwirbel mit Goldadern auf tiefem Anthrazit';

  @override
  String get onboardingAiPromptAbstract5 => 'Schwebende Chromkugeln spiegeln einen Pastellhimmel im ruhigen Raum';

  @override
  String get onboardingAiPromptWatercolor1 => 'Ein Aquarell-Küstendorf mit Pastellhäusern und Booten bei Sonnenaufgang';

  @override
  String get onboardingAiPromptWatercolor2 =>
      'Lockere Aquarell-Wildblumen in Rosa und Salbei auf strukturiertem Papier';

  @override
  String get onboardingAiPromptWatercolor3 => 'Ein nebliger Aquarellsee mit kleinem Holzsteg und fernen Hügeln';

  @override
  String get onboardingAiPromptWatercolor4 => 'Ein Aquarell-Nachthimmel mit violetten Wolken und leuchtendem Mond';

  @override
  String get onboardingAiPromptWatercolor5 => 'Ein Aquarell-Herbstwald in warmen Orange- und Goldtönen';

  @override
  String get onboardingAiPromptMinimal1 =>
      'Eine einzelne Sonne sinkt über ruhigem Meer, flache Farben, weiter leerer Himmel';

  @override
  String get onboardingAiPromptMinimal2 => 'Weiche Hügelschichten in gedämpften Sandtönen unter hellem Farbverlauf';

  @override
  String get onboardingAiPromptMinimal3 => 'Ein kahler Baum auf verschneitem Hügel mit viel stiller Leere';

  @override
  String get onboardingAiPromptMinimal4 => 'Ein einsames Segelboot auf stillem See im Morgengrauen, einfache Formen';

  @override
  String get onboardingAiPromptMinimal5 => 'Sanfte konzentrische Bögen in Terrakotta und Creme mit feiner Körnung';

  @override
  String get onboardingAiPromptAnime1 => 'Ein Anime-Sommerhimmel mit hohen Wolken über einer stillen Küstenbahn';

  @override
  String get onboardingAiPromptAnime2 => 'Eine Anime-Nachtstadt vom Hügel mit warmen Lichtern und Sternenhimmel';

  @override
  String get onboardingAiPromptAnime3 => 'Ein Anime-Waldschrein, leuchtende Geister schweben im grünen Licht';

  @override
  String get onboardingAiPromptAnime4 => 'Eine Anime-Regenstraße im Abendlicht mit leuchtenden Läden und Pfützen';

  @override
  String get onboardingAiPromptAnime5 => 'Eine Anime-Wiese zur goldenen Stunde, Wind im hohen Gras';

  @override
  String get onboardingAiPromptMeshGradient1 =>
      'Ein weicher Mesh-Verlauf aus Mandarine, Rosa und Violett mit feiner Körnung';

  @override
  String get onboardingAiPromptMeshGradient2 =>
      'Ein tiefer Mesh-Verlauf aus Marine und Petrol mit leuchtendem Limettenakzent';

  @override
  String get onboardingAiPromptMeshGradient3 => 'Ein sanfter Mesh-Verlauf aus Himmelblau, Lavendel und warmer Creme';

  @override
  String get onboardingAiPromptMeshGradient4 => 'Ein kräftiger Mesh-Verlauf aus Karmesin und Gold, fließend wie Seide';

  @override
  String get onboardingAiPromptMeshGradient5 => 'Ein ruhiger Mesh-Verlauf aus Salbei, Minze und hellem Sand';

  @override
  String get onboardingAiPromptCyberpunk1 => 'Eine Cyberpunk-Straße bei Nacht im Regen mit Neonspiegelungen und Dampf';

  @override
  String get onboardingAiPromptCyberpunk2 => 'Eine Neon-Megacity vom Dach, fliegende Autos ziehen vorbei';

  @override
  String get onboardingAiPromptCyberpunk3 =>
      'Ein stiller Cyberpunk-Kanal mit leuchtenden Läden und schwebenden Laternen';

  @override
  String get onboardingAiPromptCyberpunk4 => 'Eine Cyberpunk-Skyline im Morgengrauen, Glastürme in rosa-türkisem Dunst';

  @override
  String get onboardingAiPromptCyberpunk5 => 'Ein einsames Motorrad auf einer Neonbrücke über nebliger Zukunftsstadt';

  @override
  String get onboardingAiPromptSpace1 => 'Ein Ringplanet geht über einem Felsmond auf, Sterne am schwarzen Himmel';

  @override
  String get onboardingAiPromptSpace2 => 'Ein bunter Nebel in Violett und Türkis mit hellen jungen Sternen';

  @override
  String get onboardingAiPromptSpace3 => 'Eine Spiralgalaxie von oben mit leuchtendem Kern und staubigen blauen Armen';

  @override
  String get onboardingAiPromptSpace4 => 'Ein Astronaut treibt bei Sonnenaufgang über der Erde, dünne blaue Atmosphäre';

  @override
  String get onboardingAiPromptSpace5 => 'Eine totale Sonnenfinsternis über einer stillen Bergkette';

  @override
  String get onboardingAiPromptSynthwave1 =>
      'Ein Synthwave-Sonnenuntergang mit Streifensonne über leuchtendem Neongitter';

  @override
  String get onboardingAiPromptSynthwave2 =>
      'Ein Retro-Auto fährt auf leerer Küstenstraße auf eine magentafarbene Sonne zu';

  @override
  String get onboardingAiPromptSynthwave3 => 'Gittermodell-Berge unter violettem Sternenhimmel mit Chromsonne';

  @override
  String get onboardingAiPromptSynthwave4 => 'Ein Synthwave-Strand mit Palmensilhouetten und rosa leuchtendem Horizont';

  @override
  String get onboardingAiPromptSynthwave5 => 'Eine Retro-Skyline bei Nacht in rosa und cyanfarbenem Neondunst';

  @override
  String get onboardingAiPromptPixelArt1 => 'Eine Pixel-Art-Hütte im Winterwald, warme Fenster leuchten in der Nacht';

  @override
  String get onboardingAiPromptPixelArt2 => 'Eine Pixel-Art-Küstenstadt bei Sonnenuntergang, Boote im Hafen';

  @override
  String get onboardingAiPromptPixelArt3 => 'Eine Pixel-Art-Burg auf einer schwebenden Insel über den Wolken';

  @override
  String get onboardingAiPromptPixelArt4 => 'Ein Pixel-Art-Nachthimmel über stillem See mit Glühwürmchen';

  @override
  String get onboardingAiPromptPixelArt5 => 'Ein Pixel-Art-Kirschblütenweg zu einem kleinen Tempel';

  @override
  String get onboardingAiPromptRender3d1 => 'Ein 3D-Rendering weicher Tonformen in Pastellfarben mit sanften Schatten';

  @override
  String get onboardingAiPromptRender3d2 => 'Ein 3D-Rendering einer kleinen Schwebeinsel mit Wasserfall und Bäumen';

  @override
  String get onboardingAiPromptRender3d3 => 'Ein 3D-Rendering glänzender Glaswellen in Blau und Violett im Studiolicht';

  @override
  String get onboardingAiPromptRender3d4 =>
      'Ein 3D-Rendering eines gemütlichen Miniaturzimmers in einem leuchtenden Würfel';

  @override
  String get onboardingAiPromptRender3d5 => 'Ein 3D-Rendering von Chromblasen über einem ruhigen rosa Meer';

  @override
  String get onboardingAiPromptOilPainting1 =>
      'Ein Ölgemälde einer stürmischen See mit kleinem Schiff unter dramatischem Himmel';

  @override
  String get onboardingAiPromptOilPainting2 => 'Ein Ölgemälde eines sonnigen Mohnfelds mit fernem Bauernhaus';

  @override
  String get onboardingAiPromptOilPainting3 =>
      'Ein Ölgemälde eines nebligen Hafens im Morgengrauen mit alten Holzbooten';

  @override
  String get onboardingAiPromptOilPainting4 => 'Ein Ölgemälde eines Herbstwaldwegs in dicken, satten Pinselstrichen';

  @override
  String get onboardingAiPromptOilPainting5 =>
      'Ein Ölgemälde einer mondhellen Kanalstadt mit warm leuchtenden Fenstern';

  @override
  String get onboardingAiPromptUkiyoE1 => 'Eine Ukiyo-e-Welle unter fahlem Mond, ein verschneiter Berg in der Ferne';

  @override
  String get onboardingAiPromptUkiyoE2 => 'Ein verschneites Ukiyo-e-Dorf bei Nacht mit leuchtenden Papierlaternen';

  @override
  String get onboardingAiPromptUkiyoE3 => 'Eine Ukiyo-e-Szene: Kraniche fliegen im Morgengrauen über Nebelberge';

  @override
  String get onboardingAiPromptUkiyoE4 => 'Eine Ukiyo-e-Holzbrücke unter Kirschblüten an einem Frühlingstag';

  @override
  String get onboardingAiPromptUkiyoE5 => 'Eine Ukiyo-e-Szene: rote Sonne über ruhiger Indigo-See mit Fischerbooten';

  @override
  String wallpaperWotdByline(String name) {
    return 'von $name';
  }

  @override
  String get wallpaperWotdPastPicks => 'Frühere Auswahlen';

  @override
  String wallpaperWotdPickedOn(String wallpaper, String date) {
    return '$wallpaper, ausgewählt am $date';
  }

  @override
  String get wallpaperWotdSeePast => 'Frühere Hintergrundbilder des Tages ansehen';

  @override
  String get wallpaperWotdTitle => 'Hintergrundbild des Tages';

  @override
  String get wallpaperYourProfile => 'Dein Profil';

  @override
  String get widgetsSettingsTitle => 'Widgets';

  @override
  String get widgetsSettingsSubtitle => 'Prism zum Home-Bildschirm und Sperrbildschirm hinzufügen';

  @override
  String get widgetsGuideTitle => 'Prism-Widgets hinzufügen';

  @override
  String get widgetsGuideHomeTab => 'Home-Bildschirm';

  @override
  String get widgetsGuideLockTab => 'Sperrbildschirm';

  @override
  String get widgetsGuideHomeStep1 =>
      'Lege den Finger auf eine freie Stelle des Home-Bildschirms, bis die Apps wackeln.';

  @override
  String get widgetsGuideHomeStep2 => 'Tippe auf „Bearbeiten“ und dann auf „Widget hinzufügen“.';

  @override
  String get widgetsGuideHomeStep3 => 'Suche nach Prism, wähle eine Größe und tippe auf „Widget hinzufügen“.';

  @override
  String get widgetsGuideLockStep1 => 'Lege den Finger auf den Sperrbildschirm und tippe auf „Anpassen“.';

  @override
  String get widgetsGuideLockStep2 => 'Tippe auf „Sperrbildschirm“ und dann auf den Widget-Bereich unter der Uhr.';

  @override
  String get widgetsGuideLockStep3 => 'Wähle Prism und tippe auf ein Widget, um es hinzuzufügen.';

  @override
  String get widgetsGuideHomeIllustration =>
      'Ein Telefon mit dem Widget „Hintergrundbild des Tages“ auf dem Home-Bildschirm';

  @override
  String get widgetsGuideLockIllustration => 'Ein Telefon mit Prism-Widgets auf dem Sperrbildschirm';

  @override
  String get widgetsGuideDone => 'Fertig';

  @override
  String get widgetsCardTitle => 'Hintergrundbild des Tages auf deinem Home-Bildschirm';

  @override
  String get widgetsCardBody => 'Füge das Widget hinzu und sieh jeden Tag ein neues Hintergrundbild.';

  @override
  String get widgetsCardAction => 'Zeig mir, wie';

  @override
  String get widgetsCardDismiss => 'Schließen';

  @override
  String get foldersTitle => 'Ordner';

  @override
  String get foldersSaveToFolder => 'In Ordner speichern';

  @override
  String get foldersAddToFolder => 'Zu Ordner hinzufügen';

  @override
  String get foldersNewFolder => 'Neuer Ordner';

  @override
  String get foldersNameHint => 'Ordnername';

  @override
  String get foldersCreate => 'Erstellen';

  @override
  String get foldersCreateFolder => 'Ordner erstellen';

  @override
  String get foldersSuggested => 'Vorschlag';

  @override
  String get foldersNewTag => 'Neu';

  @override
  String foldersItemCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Hintergrundbilder',
      one: '1 Hintergrundbild',
      zero: 'Keine Hintergrundbilder',
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
      other: 'In $countString Ordnern gespeichert.',
      one: 'In 1 Ordner gespeichert.',
    );
    return '$_temp0';
  }

  @override
  String get foldersUpdated => 'Ordner aktualisiert.';

  @override
  String get foldersSaveFailed => 'Speichern in Ordnern fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get foldersUpdateFailed => 'Ordner konnte nicht aktualisiert werden. Bitte versuche es erneut.';

  @override
  String get foldersRename => 'Umbenennen';

  @override
  String get foldersRenameTitle => 'Ordner umbenennen';

  @override
  String get foldersDelete => 'Löschen';

  @override
  String foldersDeleteTitle(String name) {
    return '$name löschen?';
  }

  @override
  String get foldersDeleteMessage => 'Die Hintergrundbilder bleiben in deinen Favoriten.';

  @override
  String get foldersDeleteConfirm => 'Ordner löschen';

  @override
  String get foldersDeleted => 'Ordner gelöscht.';

  @override
  String get foldersRemoveTitle => 'Aus diesem Ordner entfernen?';

  @override
  String get foldersRemoveMessage => 'Es bleibt in deinen Favoriten.';

  @override
  String get foldersRemoveConfirm => 'Entfernen';

  @override
  String get foldersRemoved => 'Aus dem Ordner entfernt.';

  @override
  String get foldersEmptyTitle => 'Dieser Ordner ist leer';

  @override
  String get foldersEmptyBody => 'Halte das Herz bei einem Hintergrundbild gedrückt, um es hier zu speichern.';

  @override
  String get foldersLoadError => 'Dieser Ordner konnte nicht geladen werden.';

  @override
  String get foldersNotFoundTitle => 'Dieser Ordner ist nicht verfügbar';

  @override
  String get foldersNotFoundBody => 'Er wurde möglicherweise gelöscht.';

  @override
  String get foldersSignInFeature => 'Ordner';

  @override
  String get foldersMoreOptions => 'Weitere Optionen';

  @override
  String get foldersSuggestionLockScreen => 'Sperrbildschirm';

  @override
  String get foldersSuggestionHomeScreen => 'Startbildschirm';

  @override
  String get moodDreamyTitle => 'Verträumt';

  @override
  String get moodDreamyBody => 'Weiche Himmel und pastellfarbenes Licht.';

  @override
  String get moodDarkQuietTitle => 'Dunkel und ruhig';

  @override
  String get moodDarkQuietBody => 'Wenig Licht, sanft für die Augen.';

  @override
  String get moodBrightBoldTitle => 'Hell und kräftig';

  @override
  String get moodBrightBoldBody => 'Viel Farbe, damit dein Display erwacht.';

  @override
  String get moodMinimalTitle => 'Minimal';

  @override
  String get moodMinimalBody => 'Einfache Formen und viel Freiraum.';

  @override
  String get moodSpatialReadyTitle => 'Bereit für räumliche Szenen';

  @override
  String get moodSpatialReadyBody => 'Gemacht, damit sie als räumliche Szene wirkt.';

  @override
  String get moodDepthReadyTitle => 'Bereit für Tiefeneffekt';

  @override
  String get moodDepthReadyBody => 'Das Motiv schiebt sich vor deine Uhr.';

  @override
  String get moodChipRowLabel => 'Stimmungen';

  @override
  String get moodSeeAll => 'Alle anzeigen';

  @override
  String moodSeeAllHint(String mood) {
    return 'Öffnet alle Hintergründe der Stimmung $mood';
  }

  @override
  String get moodLoadError => 'Diese Hintergründe konnten nicht geladen werden';

  @override
  String get moodEmptyTitle => 'Hier gibt es noch keine Hintergründe';

  @override
  String get moodEmptyBody => 'Jeden Tag kommen neue Hintergründe dazu.';

  @override
  String wallpaperHistoryTileSemantic(String current, String target, String date) {
    return '${current}Erneut festlegen. $target, $date';
  }

  @override
  String get wallpaperHistoryTitle => 'Verlauf der Hintergrundbilder';

  @override
  String get wallpaperLibraryHistoryBody =>
      'Hier findest du Hintergrundbilder, die du festgelegt hast, und kannst sie erneut verwenden.';

  @override
  String get wallpaperLibraryHistoryTitle => 'Verlauf der Hintergrundbilder';

  @override
  String get wallpaperLibraryOpenHistory => 'Verlauf öffnen';

  @override
  String get wallpaperRecentlySet => 'Kürzlich festgelegt';

  @override
  String get wallpaperSetAgain => 'Dieses Hintergrundbild erneut festlegen';

  @override
  String get wallpaperSort => 'Sortieren';

  @override
  String get tasteQuizTitle => 'Welches gefällt dir besser?';

  @override
  String get tasteQuizWildCard => 'Wildcard';

  @override
  String tasteQuizProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString von $totalString';
  }

  @override
  String tasteQuizProgressLabel(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Runde $currentString von $totalString';
  }

  @override
  String get tasteQuizSkip => 'Überspringen';

  @override
  String tasteQuizPickLabel(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Dieses Hintergrundbild wählen, $positionString von $totalString';
  }

  @override
  String get tasteQuizTuningTitle => 'Dein Feed wird angepasst';

  @override
  String tasteQuizSummaryFull(String tone, String density, String tag) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Dunkel', 'other': 'Hell'});
    String _temp1 = intl.Intl.selectLogic(density, {'minimal': 'minimal', 'other': 'detailliert'});
    return '$_temp0, $_temp1, etwas $tag';
  }

  @override
  String tasteQuizSummaryToneDensity(String tone, String density) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Dunkel', 'other': 'Hell'});
    String _temp1 = intl.Intl.selectLogic(density, {'minimal': 'minimal', 'other': 'detailliert'});
    return '$_temp0 und $_temp1';
  }

  @override
  String tasteQuizSummaryToneTag(String tone, String tag) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Dunkel', 'other': 'Hell'});
    return '$_temp0, mit etwas $tag';
  }

  @override
  String tasteQuizSummaryDensityTag(String density, String tag) {
    String _temp0 = intl.Intl.selectLogic(density, {'minimal': 'Minimal', 'other': 'Detailliert'});
    return '$_temp0, mit etwas $tag';
  }

  @override
  String tasteQuizSummaryTone(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'dark': 'Meist dunkle Hintergrundbilder',
      'other': 'Meist helle Hintergrundbilder',
    });
    return '$_temp0';
  }

  @override
  String tasteQuizSummaryDensity(String density) {
    String _temp0 = intl.Intl.selectLogic(density, {
      'minimal': 'Meist minimale Hintergrundbilder',
      'other': 'Meist detailreiche Hintergrundbilder',
    });
    return '$_temp0';
  }

  @override
  String tasteQuizSummaryTag(String tag) {
    return 'Mehr Hintergrundbilder mit $tag';
  }

  @override
  String get tasteQuizSummaryReady => 'Dein Feed ist bereit';

  @override
  String get tasteQuizRetake => 'Das oder das erneut starten';

  @override
  String get tasteQuizRetakeFailed =>
      'Hintergrundbilder konnten nicht geladen werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get foldersPublic => 'Öffentlich';

  @override
  String get foldersMakePublic => 'Öffentlich machen';

  @override
  String get foldersMakePrivate => 'Privat machen';

  @override
  String get foldersMakePublicTitle => 'Diesen Ordner öffentlich machen?';

  @override
  String get foldersMakePublicMessage =>
      'Alle in Prism können seinen Namen und die Hintergrundbilder sehen, ihm folgen und seinen Link öffnen. Geteilte Links behalten ihre Vorschau, auch wenn du ihn später privat machst.';

  @override
  String get foldersMakePrivateTitle => 'Diesen Ordner privat machen?';

  @override
  String get foldersMakePrivateMessage =>
      'Nur du siehst ihn. Sein Link funktioniert nicht mehr und seine Follower verlieren ihn.';

  @override
  String get foldersMadePublic => 'Dieser Ordner ist jetzt öffentlich.';

  @override
  String get foldersMadePrivate => 'Dieser Ordner ist jetzt privat.';

  @override
  String get foldersPublicNameRefused => 'Benenne diesen Ordner um, damit er öffentlich werden kann.';

  @override
  String get foldersHiddenRefused =>
      'Dieser Ordner wurde nach Meldungen ausgeblendet, daher kann er nicht öffentlich sein.';

  @override
  String get foldersLimitRefused => 'Du hast Ordner heute zu oft geändert. Versuche es morgen erneut.';

  @override
  String get foldersFollow => 'Folgen';

  @override
  String get foldersFollowing => 'Gefolgt';

  @override
  String foldersFollowerCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Follower',
      one: '1 Follower',
      zero: 'Keine Follower',
    );
    return '$_temp0';
  }

  @override
  String foldersByOwner(String name) {
    return 'Von $name';
  }

  @override
  String get foldersShare => 'Ordner teilen';

  @override
  String get foldersReport => 'Ordner melden';

  @override
  String get foldersUnavailableTitle => 'Dieser Ordner ist privat oder existiert nicht mehr';

  @override
  String get foldersUnavailableBody => 'Der Besitzer hat ihn vielleicht privat gemacht oder gelöscht.';

  @override
  String get foldersFollowFailed => 'Das Folgen konnte nicht aktualisiert werden. Versuche es erneut.';

  @override
  String get foldersYouFollow => 'Ordner, denen du folgst';

  @override
  String get foldersPublicEmptyTitle => 'Hier gibt es noch keine Hintergrundbilder';

  @override
  String get foldersPublicEmptyBody => 'Neue Hintergrundbilder erscheinen hier, sobald der Besitzer sie hinzufügt.';

  @override
  String get notifSettingFolders => 'Ordner, denen du folgst';

  @override
  String get notifSettingFoldersDescription => 'Neue Hintergrundbilder in Ordnern, denen du folgst, einmal am Tag';

  @override
  String notifPushFolderDigestTitleOne(String folderName) {
    return 'Neu in $folderName';
  }

  @override
  String notifPushFolderDigestTitleMore(String folderName, int count) {
    return 'Neu in $folderName und $count weiteren';
  }

  @override
  String get historySetAndDownloaded => 'Gesetzt und heruntergeladen';

  @override
  String get historyDownloaded => 'Heruntergeladen';

  @override
  String get historyRecentlyViewed => 'Zuletzt angesehen';

  @override
  String get historySyncedNote => 'In deinem Konto gespeichert, damit sie auf einem neuen Handy wieder da sind.';

  @override
  String get historySyncedNoteGuest => 'Melde dich an, damit sie auf einem neuen Handy bleiben.';

  @override
  String get historyActionSet => 'Gesetzt';

  @override
  String get historyActionDownloaded => 'Heruntergeladen';

  @override
  String historySyncedTileLabel(String action, String time) {
    return '$action um $time';
  }

  @override
  String get historyClearSyncedBody =>
      'Die Liste wird hier und in deinem Konto entfernt. Deine Hintergrundbilder und Downloads bleiben erhalten.';

  @override
  String get historyClearViewedTitle => 'Zuletzt angesehene löschen?';

  @override
  String get historyClearViewedBody =>
      'Die Hintergrundbilder, die du geöffnet hast, werden aus dieser Liste und von der Startseite entfernt.';

  @override
  String get historyClearViewedAction => 'Zuletzt angesehene löschen';

  @override
  String get historyEmptyBodyAndroid =>
      'Hintergrundbilder, die du setzt oder herunterlädst, erscheinen hier, damit du sie wiederfindest.';

  @override
  String get historyEmptyBodyIos =>
      'Hintergrundbilder, die du herunterlädst, erscheinen hier, damit du sie wiederfindest.';

  @override
  String get historyViewedEmptyTitle => 'Noch nichts angesehen';

  @override
  String get historyViewedEmptyBody =>
      'Hintergrundbilder, die du öffnest, erscheinen hier, damit du sie wiederfindest.';

  @override
  String get historyViewedOffTitle => 'Ansichtsverlauf ist aus';

  @override
  String get historyViewedOffBody =>
      'Schalte Ansichtsverlauf speichern ein, um die Hintergrundbilder zu sehen, die du hier öffnest.';

  @override
  String get historyViewedOffAction => 'Einschalten';

  @override
  String historyViewedTileLabel(String time) {
    return 'Hintergrundbild öffnen, angesehen um $time';
  }

  @override
  String get pickUpTitle => 'Dort weitermachen, wo du aufgehört hast';

  @override
  String pickUpTileLabel(int index, int count) {
    return 'Hintergrundbild $index von $count öffnen';
  }

  @override
  String get settingsSaveViewingHistory => 'Ansichtsverlauf speichern';

  @override
  String get settingsSaveViewingHistoryBody =>
      'Zeigt die Hintergrundbilder, die du öffnest, im Verlauf und auf der Startseite. Wenn du das ausschaltest, wird die Liste gelöscht.';

  @override
  String get historyClearFailed =>
      'Der Verlauf konnte nicht gelöscht werden. Prüfe deine Verbindung und versuche es erneut.';
}
