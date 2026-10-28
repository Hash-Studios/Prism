// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get wallpaperProviderWallhaven => 'Wallhaven';

  @override
  String get economyExportFailedLabel => 'Ekspor gagal';

  @override
  String get coreSignInCreatorSearchFeature => 'pencarian kreator';

  @override
  String get debugLogExportSubject => 'Log Debug Prism';

  @override
  String get accountAbout => 'Tentang';

  @override
  String get accountAboutPrism => 'Tentang Prism';

  @override
  String get accountAccount => 'Akun';

  @override
  String get accountAccountDeletionSubscriptionWarning =>
      'Langganan Anda di toko aplikasi tidak dibatalkan saat Anda menghapus akun. Tagihan akan terus berjalan sampai Anda membatalkannya di toko aplikasi.';

  @override
  String get accountAdPrivacyChoices => 'Pilihan privasi iklan';

  @override
  String get accountAddProfilePhoto => 'Tambahkan foto profil';

  @override
  String get accountAddSocialLink => 'Tambahkan satu tautan sosial';

  @override
  String get accountAdmin => 'Admin';

  @override
  String get accountAdminModeration => 'Moderasi admin';

  @override
  String accountAndroidSharePitch(String url) {
    return 'Jatuh cinta lagi dengan kustomisasi Android! Coba Prism -\n$url';
  }

  @override
  String get accountAnyResolution => 'Apa saja';

  @override
  String get accountAppName => 'Prism Wallpapers';

  @override
  String get accountAppearance => 'Tampilan';

  @override
  String get accountApply => 'Terapkan';

  @override
  String get accountAskEveryTime => 'Tanyakan setiap kali';

  @override
  String get accountAudience => 'Audiens';

  @override
  String get accountAutoRotateWallpapers => 'Ganti wallpaper otomatis';

  @override
  String get accountBlock => 'Blokir';

  @override
  String get accountBlockActionFailed => 'Akun yang diblokir tidak dapat diperbarui';

  @override
  String get accountBlockActionPendingSync =>
      'Perubahan Anda tersimpan di perangkat ini dan akan disinkronkan saat memungkinkan.';

  @override
  String get accountBlockConfirmationUserFallback => 'pengguna ini';

  @override
  String accountBlockThisUserTitle(String name) {
    return 'Blokir $name?';
  }

  @override
  String get accountBlockUser => 'Blokir pengguna';

  @override
  String accountBlockUserMessage(String name) {
    return 'Anda akan berhenti mengikuti $name, tidak lagi melihat wallpaper mereka di feed, dan tidak akan menerima notifikasi tentang kiriman baru mereka.';
  }

  @override
  String get accountBlockedAccounts => 'Akun yang diblokir';

  @override
  String get accountBlockedAccountsEmptyBody =>
      'Memblokir akan menyembunyikan kiriman mereka dari feed Anda. Mereka mungkin masih dapat melihat profil dan wallpaper publik Anda.';

  @override
  String get accountBlockedAccountsLoadError => 'Akun yang diblokir tidak dapat dimuat';

  @override
  String get accountBlockedListUserFallback => 'Pengguna yang diblokir';

  @override
  String get accountBlockedProfileBody =>
      'Wallpaper mereka disembunyikan dari feed dan notifikasi Anda. Anda dapat membuka blokir kapan saja.';

  @override
  String get accountBringBackSubscription => 'Pulihkan langganan sebelumnya';

  @override
  String get accountBrowseByCategory => 'Jelajahi berdasarkan kategori';

  @override
  String get accountBrowseByColour => 'Jelajahi berdasarkan warna';

  @override
  String get accountBuyPremium => 'Beli Premium';

  @override
  String get accountCacheCleared => 'Cache dihapus.';

  @override
  String accountCacheClearedBytes(String size) {
    return '$size dihapus.';
  }

  @override
  String accountCachedImageSize(String size) {
    return '$size gambar dalam cache';
  }

  @override
  String get accountCancel => 'Batal';

  @override
  String get accountCannotGiftThisAccount => 'Anda tidak dapat mengirim hadiah ke akun ini.';

  @override
  String accountCategorySemanticLabel(String name) {
    return 'Kategori, $name';
  }

  @override
  String get accountChangeAutomatically => 'Ganti otomatis';

  @override
  String get accountChangeCoverPhoto => 'Ganti foto sampul';

  @override
  String get accountChangeOrCancelStore => 'Ubah atau batalkan di toko aplikasi';

  @override
  String get accountChangePhoto => 'Ganti foto';

  @override
  String get accountChangeWallpaperOnTimer => 'Ganti wallpaper sesuai jadwal';

  @override
  String get accountCheckConnectionTryAgain => 'Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get accountClear => 'Hapus';

  @override
  String get accountClearAllDownloads => 'Hapus semua unduhan';

  @override
  String get accountClearAllFavouritesQuestion => 'Hapus semua favorit?';

  @override
  String get accountClearCache => 'Hapus cache';

  @override
  String get accountClearCacheConfirmMessage =>
      'Gambar dalam cache akan dihapus. Gambar akan dimuat lagi saat diperlukan.';

  @override
  String accountClearCacheConfirmSizeMessage(String size) {
    return '$size gambar dalam cache akan dihapus. Gambar akan dimuat lagi saat diperlukan.';
  }

  @override
  String get accountClearCacheQuestion => 'Hapus cache?';

  @override
  String get accountClearCacheTitle => 'Hapus cache';

  @override
  String get accountClearCachedImages => 'Hapus gambar yang disimpan sementara di perangkat';

  @override
  String get accountClearColour => 'Hapus warna';

  @override
  String get accountClearDepthEffect => 'Hapus Efek Kedalaman';

  @override
  String get accountClearFavouriteWallpapers => 'Hapus wallpaper favorit';

  @override
  String get accountClearFavourites => 'Hapus favorit';

  @override
  String accountClearFavouritesCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper favorit dihapus',
      one: '1 wallpaper favorit dihapus',
    );
    return '$_temp0 dari akun Anda. Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String get accountClearFavouritesMessage =>
      'Semua wallpaper favorit dihapus dari akun Anda. Tindakan ini tidak dapat dibatalkan.';

  @override
  String get accountClearLearnedTaste => 'Hapus preferensi yang dipelajari';

  @override
  String accountClearLearnedTasteCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString hal', one: '1 hal');
    return 'Prism akan melupakan $_temp0 yang dipelajari dari apa yang Anda lihat dan simpan. Feed Anda akan kembali menggunakan minat yang dipilih. Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String get accountClearLearnedTasteQuestion => 'Hapus preferensi yang dipelajari?';

  @override
  String get accountClearSearch => 'Hapus pencarian';

  @override
  String get accountColour => 'Warna';

  @override
  String accountCommitCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString commit',
      one: '1 commit',
      zero: 'Tidak ada commit',
    );
    return '$_temp0';
  }

  @override
  String get accountCompleteProfile => 'Lengkapi profil';

  @override
  String get accountCompleteYourProfile => 'Lengkapi profil Anda';

  @override
  String get accountConnectionTryAgain => 'Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get accountContent => 'Konten';

  @override
  String get accountContributor => 'Kontributor';

  @override
  String accountContributorCommitCount(String login, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString commit',
      one: '1 commit',
      zero: 'tanpa commit',
    );
    return '$login, $_temp0';
  }

  @override
  String get accountCopy => 'Salin';

  @override
  String get accountCopyLink => 'Salin tautan';

  @override
  String get accountCouldNotBuildReport => 'Laporan tidak dapat dibuat. Coba lagi.';

  @override
  String get accountCouldNotClearFavourites => 'Wallpaper favorit tidak dapat dihapus. Coba lagi.';

  @override
  String get accountCouldNotClearLearnedTaste => 'Preferensi yang dipelajari tidak dapat dihapus. Coba lagi.';

  @override
  String get accountCouldNotCreateLink => 'Tautan tidak dapat dibuat. Coba lagi.';

  @override
  String get accountCouldNotDeleteDownloads => 'Unduhan tidak dapat dihapus. Coba lagi.';

  @override
  String accountCouldNotFollowPerson(String name) {
    return 'Tidak dapat mengikuti $name. Coba lagi.';
  }

  @override
  String get accountCouldNotLoadFollowers => 'Pengikut tidak dapat dimuat';

  @override
  String get accountCouldNotLoadFollowing => 'Daftar yang diikuti tidak dapat dimuat';

  @override
  String get accountCouldNotLoadTeam => 'Tim tidak dapat dimuat';

  @override
  String get accountCouldNotLoadThisProfile => 'Profil ini tidak dapat dimuat';

  @override
  String get accountCouldNotLoadTrending => 'Wallpaper populer tidak dapat dimuat';

  @override
  String get accountCouldNotLoadWallpapers => 'Wallpaper tidak dapat dimuat';

  @override
  String accountCouldNotOpenAddress(String address) {
    return 'Tidak dapat membuka $address';
  }

  @override
  String get accountCouldNotOpenLink => 'Tautan tidak dapat dibuka. Coba lagi.';

  @override
  String get accountCouldNotOpenStore => 'Toko aplikasi tidak dapat dibuka. Coba lagi.';

  @override
  String get accountCouldNotOpenThisLink => 'Tautan ini tidak dapat dibuka.';

  @override
  String get accountCouldNotRefreshSearch => 'Tidak dapat memuat ulang. Tarik ke bawah untuk mencoba lagi.';

  @override
  String get accountCouldNotRemoveSavedOffline => 'Wallpaper offline tersimpan tidak dapat dihapus. Coba lagi.';

  @override
  String get accountCouldNotRestorePurchases => 'Pembelian tidak dapat dipulihkan. Coba lagi.';

  @override
  String get accountCouldNotSearchCreators => 'Kreator tidak dapat ditelusuri';

  @override
  String get accountCouldNotSearchRightNow => 'Pencarian tidak tersedia saat ini';

  @override
  String get accountCouldNotSendGift => 'Hadiah tidak dapat dikirim. Coba lagi.';

  @override
  String get accountCouldNotShareReport => 'Laporan tidak dapat dibagikan. Coba lagi.';

  @override
  String accountCouldNotUnfollowPerson(String name) {
    return 'Tidak dapat berhenti mengikuti $name. Coba lagi.';
  }

  @override
  String get accountCreatorFallback => 'Kreator Prism';

  @override
  String get accountCreatorSearchEmptyBody => 'Periksa ejaan atau coba nama lain.';

  @override
  String get accountCurrentSignedInAccountRequired => 'Pilih akun yang saat ini Anda gunakan untuk masuk.';

  @override
  String get accountDataSaver => 'Hemat data';

  @override
  String get accountDataSaverDescription =>
      'Menghemat data seluler. Wallpaper dibuka sebagai gambar mini, feed tidak dimuat lebih dulu, dan carousel tidak diputar otomatis.';

  @override
  String get accountDatabaseUsageStats => 'Penggunaan database dan statistik';

  @override
  String get accountDebugPanel => 'Panel debug';

  @override
  String get accountDefaultActionForSet => 'Tindakan bawaan untuk Atur';

  @override
  String get accountDeleteAccount => 'Hapus akun';

  @override
  String get accountDeleteAccountConfirmation =>
      'Akun Anda akan dihapus permanen, data pribadi Anda akan dihapus, dan Anda akan keluar.\n\nWallpaper yang Anda unggah akan tetap terlihat sebagai \"Akun Dihapus\".\n\nTindakan ini tidak dapat dibatalkan.';

  @override
  String get accountDeleteAccountReauthNote => 'Selanjutnya, Anda akan mengonfirmasi dengan Google atau Apple.';

  @override
  String get accountDeleteAll => 'Hapus semua';

  @override
  String get accountDeleteAllDownloadsQuestion => 'Hapus semua unduhan?';

  @override
  String accountDeleteDownloadsCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper yang diunduh dihapus',
      one: '1 wallpaper yang diunduh dihapus',
    );
    return '$_temp0 dari Unduhan. Salinan yang disimpan offline tidak terpengaruh. Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String get accountDeleteDownloadsMessage =>
      'Wallpaper yang diunduh dihapus dari Unduhan. Salinan yang disimpan offline tidak terpengaruh. Tindakan ini tidak dapat dibatalkan.';

  @override
  String get accountDeleteYourAccountQuestion => 'Hapus akun Anda?';

  @override
  String get accountDeletingYourAccount => 'Menghapus akun Anda';

  @override
  String get accountDepthEffect => 'Efek Kedalaman';

  @override
  String get accountDepthEffectClockSemanticLabel => 'Efek Kedalaman, subjek berada di depan jam';

  @override
  String accountDownloadedWallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper yang diunduh; salinan offline tetap tersimpan',
      one: '1 wallpaper yang diunduh; salinan offline tetap tersimpan',
      zero: 'Tidak ada wallpaper yang diunduh; salinan offline tetap tersimpan',
    );
    return '$_temp0';
  }

  @override
  String get accountDownloadsDeleted => 'Semua unduhan dihapus.';

  @override
  String get accountEarnCoins => 'Dapatkan koin';

  @override
  String accountEarnProfileCompletionCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Dapatkan $coinsString koin setelah profil selesai';
  }

  @override
  String get accountEditCover => 'Edit sampul';

  @override
  String get accountEditProfile => 'Edit profil';

  @override
  String get accountExportFavourites => 'Ekspor favorit';

  @override
  String get accountFavouritesCleared => 'Semua wallpaper favorit dihapus.';

  @override
  String get accountFeedback => 'MASUKAN';

  @override
  String get accountFeedbackSubject => 'Masukan Prism';

  @override
  String get accountFields => 'Kolom';

  @override
  String get accountFilters => 'Filter';

  @override
  String get accountFindCreators => 'Cari kreator';

  @override
  String get accountFinishYourProfile => 'Selesaikan profil Anda';

  @override
  String get accountFirestoreTelemetry => 'Telemetri Firestore';

  @override
  String get accountFollow => 'Ikuti';

  @override
  String accountFollowPerson(String name) {
    return 'Ikuti $name';
  }

  @override
  String accountFollowedPerson(String name) {
    return 'Anda mengikuti $name!';
  }

  @override
  String get accountFollowers => 'Pengikut';

  @override
  String accountFollowersCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString pengikut',
      one: '1 pengikut',
      zero: 'Tidak ada pengikut',
    );
    return '$_temp0';
  }

  @override
  String accountFollowersCountLabel(String compactCount) {
    return '$compactCount Pengikut';
  }

  @override
  String get accountFollowersEmptyMessage => 'Orang yang mengikuti akun ini akan muncul di sini.';

  @override
  String get accountFollowing => 'Mengikuti';

  @override
  String accountFollowingCountLabel(String compactCount) {
    return '$compactCount Mengikuti';
  }

  @override
  String get accountFollowingEmptyMessage => 'Akun yang Anda ikuti akan muncul di sini.';

  @override
  String get accountForgetFeedLearned => 'Hapus preferensi yang dipelajari feed tentang Anda';

  @override
  String get accountFromPrism => 'Dari Prism';

  @override
  String get accountGiftLimitReached => 'Batas hadiah tercapai untuk saat ini. Coba lagi besok.';

  @override
  String accountGiftPassMessage(String recipientName, int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$recipientName akan mendapat koleksi premium dan wallpaper premium selama 24 jam. Biayanya $priceString koin.';
  }

  @override
  String get accountGiftPassTitle => 'Hadiahkan akses Pro 24 jam';

  @override
  String get accountGiftPassTooltip => 'Hadiahkan akses 24 jam';

  @override
  String get accountGiftsOpenAfterSevenDays => 'Fitur hadiah tersedia setelah akun Anda berusia 7 hari.';

  @override
  String get accountHapticFeedback => 'Umpan balik haptik';

  @override
  String get accountHelp => 'Bantuan';

  @override
  String get accountHomeAndLockScreens => 'Layar utama dan layar kunci';

  @override
  String get accountHomeScreen => 'Layar utama';

  @override
  String get accountInviteFriends => 'Undang teman';

  @override
  String get accountInviteLinkCouldNotCreate => 'Tautan undangan Anda tidak dapat dibuat.';

  @override
  String accountInviteRewardHeadline(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Berikan $coinsString, dapatkan $coinsString';
  }

  @override
  String accountInviteRewardMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Teman Anda mendapat $coinsString koin saat bergabung. Anda juga mendapat $coinsString.';
  }

  @override
  String get accountInviteShareFailed => 'Undangan tidak dapat dibagikan saat ini.';

  @override
  String accountIosSharePitch(String url) {
    return 'Jatuh cinta lagi dengan personalisasi ponsel Anda! Coba Prism -\n$url';
  }

  @override
  String get accountLater => 'Nanti';

  @override
  String get accountLatest => 'Terbaru';

  @override
  String get accountLearnedTasteCleared => 'Preferensi yang dipelajari dihapus.';

  @override
  String get accountLibrary => 'Pustaka';

  @override
  String get accountLightDarkAccentColour => 'Warna terang, gelap, dan aksen';

  @override
  String get accountLink => 'Tautan';

  @override
  String get accountLinkCopied => 'Tautan disalin';

  @override
  String get accountLinkType => 'Jenis tautan';

  @override
  String get accountLinkTypeBehance => 'Behance';

  @override
  String get accountLinkTypeBioLink => 'bio.link';

  @override
  String get accountLinkTypeBuyMeACoffee => 'Buy Me a Coffee';

  @override
  String get accountLinkTypeCustom => 'Tautan kustom';

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
    return 'Jenis tautan, $name';
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
  String get accountLiveWallpapers => 'Wallpaper bergerak';

  @override
  String get accountLoadingTeam => 'Memuat tim';

  @override
  String get accountLockScreen => 'Layar kunci';

  @override
  String get accountLogOut => 'Keluar';

  @override
  String get accountLogOutOfPrismQuestion => 'Keluar dari Prism?';

  @override
  String get accountLogOutQuestion => 'Keluar?';

  @override
  String get accountLogoutConfirmation =>
      'Keluar akan menghapus riwayat dan preferensi yang dipelajari di perangkat ini. Favorit, koin, dan profil tetap tersimpan di akun Anda.';

  @override
  String get accountLogoutFailed => 'Tidak dapat keluar. Coba lagi.';

  @override
  String get accountLogsNetworkToolsStorage => 'Log, jaringan, alat, dan penyimpanan';

  @override
  String get accountMadeWithLoveInIndia => 'Dibuat dengan ❤ di India menggunakan Flutter!';

  @override
  String get accountManageBlockedPeople => 'Kelola orang yang Anda blokir';

  @override
  String get accountManageSubscription => 'Kelola langganan';

  @override
  String get accountMenu => 'Menu';

  @override
  String get accountMinResolution => 'Resolusi minimum';

  @override
  String get accountMoreLinks => 'Tautan lainnya';

  @override
  String get accountMoreOptions => 'Opsi lainnya';

  @override
  String get accountMovingGradientsMotionVideo => 'Gradien bergerak, animasi, dan video';

  @override
  String get accountMyAccent => 'Warna aksen saya';

  @override
  String get accountNoBlockedAccounts => 'Tidak ada akun yang diblokir';

  @override
  String get accountNoContributors => 'Belum ada kontributor untuk ditampilkan.';

  @override
  String get accountNoCreatorsFound => 'Kreator tidak ditemukan';

  @override
  String get accountNoDownloadsToRemove => 'Tidak ada unduhan untuk dihapus.';

  @override
  String get accountNoFollowersYet => 'Belum ada pengikut';

  @override
  String get accountNoPurchasesToRestore => 'Tidak ada pembelian untuk dipulihkan di akun ini.';

  @override
  String get accountNoResults => 'Tidak ada hasil';

  @override
  String accountNoWallpapersForFilters(String filters) {
    return 'Tidak ada wallpaper $filters yang ditemukan';
  }

  @override
  String accountNoWallpapersForQueryWithFilters(String query) {
    return 'Tidak ada wallpaper untuk $query dengan filter yang dipilih.';
  }

  @override
  String get accountNoWallpapersFound => 'Wallpaper tidak ditemukan';

  @override
  String accountNoWallpapersFoundForQuery(String query) {
    return 'Wallpaper untuk $query tidak ditemukan';
  }

  @override
  String get accountNoWallpapersYet => 'Belum ada wallpaper';

  @override
  String accountNobodyMatchesUsername(String query) {
    return 'Tidak ada yang cocok dengan \"$query\". Coba nama pengguna lain.';
  }

  @override
  String get accountNotEnoughCoinsEarnInRewards => 'Koin tidak cukup. Dapatkan koin di Hadiah.';

  @override
  String get accountNotFollowingAnyoneYet => 'Belum mengikuti siapa pun';

  @override
  String get accountNotSynced => 'Belum disinkronkan';

  @override
  String get accountNothingLearnedYet => 'Prism belum mempelajari apa pun.';

  @override
  String get accountNotificationPreferences => 'Preferensi notifikasi';

  @override
  String get accountNotificationTypes => 'Wallpaper Hari Ini, pengikut, kiriman, dan lainnya';

  @override
  String get accountNotifications => 'Notifikasi';

  @override
  String get accountOpenYourProfile => 'Buka profil Anda';

  @override
  String get accountOpeningProfileEditor => 'Membuka editor profil';

  @override
  String get accountOpens => 'Dibuka';

  @override
  String get accountOtherContributors => 'Kontributor lainnya';

  @override
  String accountPassSentToPerson(String name) {
    return 'Akses telah dikirim kepada $name.';
  }

  @override
  String accountPersonAlreadyHasPro(String name) {
    return '$name sudah memiliki Pro.';
  }

  @override
  String get accountPersonalise => 'Personalisasi';

  @override
  String get accountPortraitOnly => 'Khusus potret';

  @override
  String get accountPremiumBenefitsActive =>
      'Anda mendapat semua wallpaper premium, unduhan gratis, dan filter gratis.';

  @override
  String get accountPremiumBenefitsInactive => 'Buka akses ke wallpaper premium, unduhan gratis, dan filter gratis.';

  @override
  String get accountPreview => 'Pratinjau';

  @override
  String get accountPrismListPrivacySubtitle => 'Cara Prism menangani data Anda';

  @override
  String get accountPrismPro => 'Prism Pro';

  @override
  String get accountPrivacyAction => 'PRIVASI';

  @override
  String get accountPrivacyAndData => 'Privasi dan data';

  @override
  String get accountPrivacyPolicy => 'Kebijakan privasi';

  @override
  String get accountProBadge => 'Pro';

  @override
  String get accountProWallpaperSemantics => 'Wallpaper Pro';

  @override
  String get accountProblemReportSharePrompt => 'Jelaskan masalah yang terjadi. Detailnya ada di file laporan.';

  @override
  String get accountProblemReportShareSubject => 'Laporan masalah Prism';

  @override
  String get accountProfile => 'Profil';

  @override
  String get accountProfileNotAvailable => 'Profil tidak tersedia';

  @override
  String get accountProfileNotAvailableBody =>
      'Pengguna ini tidak aktif di versi Prism terbaru, jadi profilnya tidak dapat ditampilkan.';

  @override
  String accountProfileNudgeMessage(int percent, int coins) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Profil Anda sudah $percentString% lengkap. Selesaikan untuk mendapatkan $coinsString koin Prism.';
  }

  @override
  String accountProfilePercentComplete(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Profil $percentString% lengkap';
  }

  @override
  String accountProfilePersonSemantics(String name, String username) {
    return '$name, @$username';
  }

  @override
  String get accountProfiles => 'profil';

  @override
  String get accountPurchases => 'Pembelian';

  @override
  String get accountPurchasesRestored => 'Pembelian dipulihkan.';

  @override
  String get accountPurchasesRestoredPending => 'Pembelian dipulihkan. Pro mungkin perlu waktu satu menit untuk aktif.';

  @override
  String get accountQuickTiles => 'Tile Cepat';

  @override
  String get accountRateApp => 'NILAI';

  @override
  String get accountRecentSearches => 'Pencarian terbaru';

  @override
  String get accountRelevance => 'Relevansi';

  @override
  String get accountRemoveAllFavouriteWallpapers => 'Hapus semua wallpaper favorit';

  @override
  String get accountRemoveCoverPhoto => 'Hapus foto sampul';

  @override
  String get accountRemoveFilesDownloadsOfflineStay => 'Hapus file dari Unduhan; salinan offline tetap tersimpan';

  @override
  String get accountRemoveLink => 'Hapus tautan';

  @override
  String get accountRemovePhoto => 'Hapus foto';

  @override
  String get accountRemoveSavedOffline => 'Hapus yang disimpan offline';

  @override
  String accountRemoveSavedOfflineCountMessage(String size) {
    return '$size dari wallpaper asli yang disimpan offline akan dihapus. Unduhan, draf, dan data katalog tidak akan berubah.';
  }

  @override
  String get accountRemoveSavedOfflineMessage =>
      'Hapus wallpaper asli yang disimpan offline dari perangkat ini. Unduhan, draf, dan data katalog tidak akan berubah.';

  @override
  String get accountRemoveSavedOfflineQuestion => 'Hapus wallpaper yang disimpan offline?';

  @override
  String get accountReportAProblem => 'Laporkan masalah';

  @override
  String accountReportPreviewNotice(String email) {
    return 'Laporan ini berisi versi aplikasi, perangkat, dan log terbaru Anda. Tidak ada alamat email atau token masuk. Baca laporan, lalu bagikan kepada $email.';
  }

  @override
  String get accountReportProblemSubtitle => 'Bagikan log aplikasi Anda dengan tim Prism';

  @override
  String get accountReportUser => 'Laporkan pengguna';

  @override
  String get accountReset => 'Atur ulang';

  @override
  String get accountResetFilters => 'Atur ulang filter';

  @override
  String get accountResolution1080 => '1080p';

  @override
  String get accountResolution1440 => '1440p';

  @override
  String get accountResolution4k => '4K';

  @override
  String get accountRestorePurchases => 'Pulihkan pembelian';

  @override
  String get accountRestoringPurchases => 'Memulihkan pembelian…';

  @override
  String accountResultsForQuery(String query) {
    return 'Hasil untuk $query';
  }

  @override
  String get accountRetry => 'Coba lagi';

  @override
  String get accountReviewOrChangeAdConsent => 'Tinjau atau ubah izin iklan Anda';

  @override
  String get accountReviewStatus => 'Status peninjauan';

  @override
  String get accountReviewSubmittedContent => 'Tinjau konten yang dikirimkan';

  @override
  String get accountSaveFavouritesAsFile => 'Simpan salinan favorit Anda sebagai file';

  @override
  String get accountSavedOffline => 'Disimpan offline';

  @override
  String get accountSavedOfflineRemoved => 'Wallpaper yang disimpan offline dihapus.';

  @override
  String accountSavedOfflineStorageUnavailable(int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'Penyimpanan tidak tersedia · batas $limitString MiB';
  }

  @override
  String accountSavedOfflineStorageUsed(String size, int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$size digunakan · batas $limitString MiB';
  }

  @override
  String get accountSavedOnThisDevice => 'Disimpan di perangkat ini';

  @override
  String get accountSearch => 'Cari';

  @override
  String get accountSearchByUsername => 'Cari berdasarkan nama pengguna';

  @override
  String get accountSearchCreators => 'Cari kreator';

  @override
  String get accountSearchCreatorsByName => 'Cari kreator berdasarkan nama';

  @override
  String get accountSearchFilters => 'Filter';

  @override
  String get accountSearchPrismUsersByName => 'Cari pengguna Prism berdasarkan nama';

  @override
  String get accountSearchWallpapers => 'Cari wallpaper';

  @override
  String get accountSeeChangelog => 'Lihat catatan perubahan';

  @override
  String get accountSendGift => 'Kirim hadiah';

  @override
  String get accountSendProfileLink => 'Kirim tautan ke profil Prism Anda';

  @override
  String get accountSetUpQuickTiles => 'Siapkan tile Setelan Cepat';

  @override
  String get accountSetUsername => 'Atur nama pengguna';

  @override
  String get accountSettings => 'Setelan';

  @override
  String get accountShare => 'Bagikan';

  @override
  String get accountShareInvite => 'Bagikan undangan';

  @override
  String get accountSharePrism => 'Bagikan Prism';

  @override
  String get accountSharePrismFriendSubtitle => 'Kirim tautan kepada teman';

  @override
  String get accountShareProfile => 'Bagikan profil';

  @override
  String get accountShareProfileLinkFailed => 'Tautan tidak dapat dibuat. Coba lagi.';

  @override
  String get accountShareYourProfile => 'Bagikan profil Anda';

  @override
  String get accountShop => 'Toko';

  @override
  String get accountShowAnimeWallpapers => 'Tampilkan wallpaper anime';

  @override
  String get accountShowSketchyWallpapers => 'Tampilkan wallpaper dewasa';

  @override
  String get accountSignIn => 'Masuk';

  @override
  String get accountSignInAgainToDelete => 'Keluar lalu masuk lagi, kemudian coba hapus akun Anda.';

  @override
  String get accountSignInBenefits => 'Masuk untuk menyimpan favorit, koin, dan profil Anda';

  @override
  String get accountSignInForInviteLink => 'Masuk untuk mendapatkan tautan undangan.';

  @override
  String get accountSignInToPrism => 'Masuk ke Prism';

  @override
  String get accountSocialGithub => 'GITHUB';

  @override
  String get accountSocialInstagram => 'INSTAGRAM';

  @override
  String get accountSocialTelegram => 'TELEGRAM';

  @override
  String get accountSocialTwitter => 'TWITTER';

  @override
  String get accountSomethingWentWrongTryAgain => 'Terjadi kesalahan. Coba lagi.';

  @override
  String get accountSort => 'Urutkan';

  @override
  String get accountStorage => 'Penyimpanan';

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
  String get accountSubjectCanSitInFrontOfClock => 'Subjek dapat berada di depan jam';

  @override
  String get accountSubjectInFrontOfClock => 'Subjek di depan jam';

  @override
  String get accountTerms => 'Ketentuan';

  @override
  String get accountTermsAction => 'KETENTUAN';

  @override
  String accountTermsAgreementSemanticLabel(String terms, String privacy) {
    return 'Dengan melanjutkan, Anda menyetujui $terms dan $privacy';
  }

  @override
  String get accountTermsOfUse => 'Ketentuan penggunaan';

  @override
  String get accountTheTeam => 'Tim';

  @override
  String get accountThemes => 'Tema';

  @override
  String get accountThemesIconsFrames => 'Tema, ikon, bingkai';

  @override
  String get accountThisUser => 'pengguna ini';

  @override
  String get accountTop => 'Teratas';

  @override
  String get accountTrackSubmittedWallpapers => 'Lacak wallpaper yang Anda kirimkan';

  @override
  String get accountTrendingNow => 'Sedang tren';

  @override
  String get accountTryAgain => 'Coba lagi';

  @override
  String get accountTryFewerFilters => 'Coba kurangi filter.';

  @override
  String get accountTryShorterOrDifferentWord => 'Coba kata yang lebih singkat atau kata lain.';

  @override
  String get accountUnblock => 'Buka blokir';

  @override
  String get accountUnblockUserMessage => 'Kiriman mereka akan muncul lagi di feed Anda.';

  @override
  String accountUnblockUserTitle(String name) {
    return 'Buka blokir $name?';
  }

  @override
  String get accountUnfollow => 'Berhenti mengikuti';

  @override
  String accountUnfollowPerson(String name) {
    return 'Berhenti mengikuti $name';
  }

  @override
  String accountUnfollowedPerson(String name) {
    return 'Anda berhenti mengikuti $name!';
  }

  @override
  String get accountUnlimitedUploadsFilters => 'Unggahan dan filter tanpa batas';

  @override
  String get accountUploadFirstWallpaper => 'Unggah wallpaper pertama Anda untuk memulai galeri.';

  @override
  String get accountUseShortcutsAutomation => 'Gunakan otomatisasi Pintasan';

  @override
  String accountUserBlocked(String name) {
    return 'Anda memblokir $name';
  }

  @override
  String get accountUserUnblocked => 'Blokir dibuka';

  @override
  String accountVersionLabel(String version) {
    return 'Versi $version';
  }

  @override
  String get accountVibrateOnTapsAndActions => 'Getarkan perangkat saat mengetuk dan melakukan tindakan';

  @override
  String get accountWaitingToSync => 'Menunggu sinkronisasi';

  @override
  String get accountWallpaperHistory => 'Riwayat wallpaper';

  @override
  String get accountWallpaperManagerTagline => 'Pengelola wallpaper dengan fitur lengkap.';

  @override
  String get accountWallpaperSourceNames => 'Prism menggunakan Wallhaven dan Pexels untuk wallpaper';

  @override
  String get accountWallpaperSources => 'Sumber wallpaper';

  @override
  String get accountWallpaperSourcesMessage => 'Prism menggunakan layanan ini untuk menyediakan wallpaper.';

  @override
  String get accountWallpapersSetBefore => 'Wallpaper yang pernah Anda pasang';

  @override
  String get accountWhatsNew => 'Yang baru';

  @override
  String get accountWhatsNewAction => 'YANG BARU';

  @override
  String get accountWriteBio => 'Tulis bio';

  @override
  String accountYouBlockedUser(String name) {
    return 'Anda memblokir $name';
  }

  @override
  String get accountYourContent => 'Konten Anda';

  @override
  String get accountYourProfile => 'profil Anda';

  @override
  String get actionCancel => 'Batal';

  @override
  String get actionClose => 'Tutup';

  @override
  String get actionDone => 'Selesai';

  @override
  String get actionRetry => 'Coba lagi';

  @override
  String get adminAllCaughtUp => 'Semua sudah ditinjau';

  @override
  String get adminAllUsers => 'Semua pengguna';

  @override
  String get adminAnnouncementInbox => 'Pengumuman (kotak masuk)';

  @override
  String get adminAnonymous => 'Anonim';

  @override
  String get adminApprovalFailed => 'Persetujuan gagal. Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get adminApprove => 'Setujui';

  @override
  String get adminApproved => 'Disetujui';

  @override
  String get adminBackToReviewList => 'Kembali ke daftar tinjauan';

  @override
  String get adminBatchActionFailed => 'Tindakan tinjauan ini tidak dapat diselesaikan. Coba lagi.';

  @override
  String get adminBatchComplete => 'Tinjauan batch selesai';

  @override
  String get adminBodyLabel => 'Isi';

  @override
  String get adminBodyRequired => 'Isi wajib diisi';

  @override
  String get adminBy => 'Oleh';

  @override
  String get adminByCollection => 'Berdasarkan koleksi';

  @override
  String get adminByOperation => 'Berdasarkan operasi';

  @override
  String get adminBySourceTop15 => 'Berdasarkan sumber (15 teratas)';

  @override
  String get adminCancel => 'Batal';

  @override
  String get adminChangeDepthEffect => 'Ubah efek kedalaman';

  @override
  String get adminCheckConnectionRetry => 'Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get adminClose => 'Tutup';

  @override
  String adminContentTypeReport(String type) {
    return 'Laporan $type';
  }

  @override
  String get adminCopyAllData => 'Salin semua data';

  @override
  String get adminCouldNotLoadWallpaper => 'Wallpaper tidak dapat dimuat';

  @override
  String get adminCreatorWillSeeFeedback => 'Kreator akan melihat masukan ini.';

  @override
  String get adminDepth => 'Kedalaman';

  @override
  String adminDepthTier(String tier) {
    return 'Kedalaman: $tier';
  }

  @override
  String get adminDepthTierAuto => 'Otomatis';

  @override
  String get adminDepthTierMenu => 'Menu';

  @override
  String get adminDepthTierNone => 'Tidak ada';

  @override
  String get adminDepthTierNotChecked => 'Belum diperiksa';

  @override
  String get adminDrop => 'Drop';

  @override
  String get adminEmail => 'Email';

  @override
  String get adminEmailExample => 'user@example.com';

  @override
  String get adminEmailRequired => 'Email wajib diisi';

  @override
  String get adminEstimatedDocumentReads => 'Perkiraan pembacaan dokumen';

  @override
  String get adminEstimatedDocumentWrites => 'Perkiraan penulisan dokumen';

  @override
  String adminFactLabel(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminFirestoreTelemetry => 'Telemetri Firestore';

  @override
  String get adminFollowersScreen => 'Layar pengikut';

  @override
  String get adminFreeUsers => 'Pengguna gratis';

  @override
  String get adminGeneral => 'Umum';

  @override
  String get adminImageUrlOptional => 'URL gambar (opsional)';

  @override
  String get adminKeepWallpaper => 'Pertahankan wallpaper';

  @override
  String get adminLast14Days => '14 hari terakhir';

  @override
  String get adminList => 'Daftar';

  @override
  String get adminLoadNextBatch => 'Muat batch berikutnya';

  @override
  String get adminLoadingNotificationCounts => 'Memuat jumlah notifikasi.';

  @override
  String get adminMarkReviewed => 'Tandai sudah ditinjau';

  @override
  String get adminMarkReviewedFailed => 'Laporan tidak dapat ditandai sudah ditinjau. Coba lagi.';

  @override
  String get adminMarkedReviewed => 'Ditandai sudah ditinjau';

  @override
  String adminModerationDuplicate(int percent) {
    return 'Sepertinya mirip wallpaper Prism · $percent%';
  }

  @override
  String get adminModerationHint => 'Ini hanya petunjuk. Periksa sebelum menolak.';

  @override
  String adminModerationLogo(String logo) {
    return 'Logo: $logo';
  }

  @override
  String get adminModerationLogos => 'Logo';

  @override
  String get adminModerationOpenFailed => 'Halaman tidak dapat dibuka.';

  @override
  String adminModerationOpenPage(String host) {
    return 'Buka $host';
  }

  @override
  String get adminModerationSignals => 'Sinyal peninjauan';

  @override
  String get adminModerationSimilarWall => 'Wallpaper Prism serupa';

  @override
  String adminModerationSimilarity(int percent) {
    return '$percent% mirip';
  }

  @override
  String adminModerationText(String words) {
    return 'Teks: $words';
  }

  @override
  String get adminModerationTextInImage => 'Teks dalam gambar';

  @override
  String adminModerationUnsafe(String categories) {
    return 'Tidak aman: $categories';
  }

  @override
  String get adminModerationUnsafeCategories => 'Kategori konten tidak aman';

  @override
  String adminModerationWeb(String host) {
    return 'Ditemukan di $host';
  }

  @override
  String adminModerationWebMore(String host, int more) {
    return 'Ditemukan di $host +$more';
  }

  @override
  String get adminModerationWebPages => 'Ditemukan di web';

  @override
  String get adminNewWallpapersPending => 'Wallpaper baru akan muncul di sini saat seseorang mengunggahnya.';

  @override
  String get adminNoNotificationCounts => 'Belum ada jumlah notifikasi.';

  @override
  String get adminNoOpenReports => 'Tidak ada laporan terbuka';

  @override
  String get adminNoReasonGiven => 'Tidak ada alasan yang diberikan';

  @override
  String get adminNoTelemetryData => 'Tidak ada data telemetri untuk disalin';

  @override
  String get adminNoTelemetryYet => 'Belum ada telemetri';

  @override
  String get adminNoWallpapersPending => 'Tidak ada wallpaper yang menunggu tinjauan.';

  @override
  String get adminNothingToReview => 'Tidak ada yang perlu ditinjau';

  @override
  String get adminNotificationCountExplanation =>
      'Diterima berarti Firebase menerima push. Push ke topik akun dan token perangkat dihitung dua kali. Ini bukan berarti telah dilihat.';

  @override
  String get adminNotificationCountsLoadError => 'Jumlah notifikasi tidak dapat dimuat.';

  @override
  String get adminNotificationIrreversible =>
      'Notifikasi ini dikirim ke semua orang dalam grup ini. Anda tidak dapat membatalkannya.';

  @override
  String get adminNotificationQueueFailed => 'Notifikasi tidak dapat dimasukkan ke antrean. Coba lagi.';

  @override
  String get adminNotificationQueued => 'Notifikasi masuk antrean. Cloud Function akan segera mengirimkannya.';

  @override
  String get adminNotifications => 'Notifikasi';

  @override
  String get adminOpenReportsLoadError => 'Laporan terbuka tidak dapat dimuat.';

  @override
  String get adminOpenWallpaper => 'Buka wallpaper';

  @override
  String adminOperationCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString operasi',
      one: '$countString operasi',
    );
    return '$_temp0';
  }

  @override
  String get adminPendingWallsLoadError => 'Wallpaper yang menunggu tidak dapat dimuat.';

  @override
  String get adminPremiumUsers => 'Pengguna Premium';

  @override
  String adminReadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString pembacaan',
      one: '$countString pembacaan',
    );
    return '$_temp0';
  }

  @override
  String get adminReasonBlurry => 'Buram';

  @override
  String get adminReasonBlurryBody => 'Gambar buram atau sangat terkompresi. Unggah versi yang lebih tajam.';

  @override
  String get adminReasonCopyright => 'Hak cipta';

  @override
  String get adminReasonCopyrightBody =>
      'Gambar ini mungkin karya orang lain. Unggah hanya wallpaper yang Anda buat atau yang hak penggunaannya Anda miliki.';

  @override
  String get adminReasonDuplicate => 'Duplikat';

  @override
  String get adminReasonDuplicateBody => 'Wallpaper ini duplikat dari wallpaper yang sudah ada di Prism.';

  @override
  String get adminReasonHint => 'Jelaskan apa yang perlu diubah';

  @override
  String get adminReasonLabel => 'Alasan';

  @override
  String get adminReasonLowResolution => 'Resolusi rendah';

  @override
  String get adminReasonLowResolutionBody =>
      'Resolusi terlalu rendah. Unggah gambar dengan sisi pendek minimal 1080 px.';

  @override
  String get adminReasonNotWallpaper => 'Bukan wallpaper';

  @override
  String get adminReasonNotWallpaperBody =>
      'Gambar ini tidak cocok sebagai wallpaper ponsel. Gunakan gambar potret yang memenuhi layar.';

  @override
  String get adminReasonOther => 'Lainnya';

  @override
  String get adminReasonWatermark => 'Tanda air';

  @override
  String get adminReasonWatermarkBody => 'Gambar memiliki tanda air. Unggah versi tanpa tanda air.';

  @override
  String get adminRefresh => 'Muat ulang';

  @override
  String get adminReject => 'Tolak';

  @override
  String get adminRejectReasonRequired => 'Masukkan alasan sebelum menolak item ini.';

  @override
  String get adminRejectSaveFailed => 'Keputusan ini tidak dapat disimpan. Alasan Anda masih ada. Coba lagi.';

  @override
  String get adminRejectWallpaper => 'Tolak wallpaper';

  @override
  String get adminRemove => 'Hapus';

  @override
  String get adminRemoveWallpaper => 'Hapus wallpaper';

  @override
  String get adminRemovedFromNextDrop => 'Dihapus dari Drop berikutnya';

  @override
  String get adminReportDismissFailed => 'Laporan tidak dapat ditutup. Coba lagi.';

  @override
  String get adminReportDismissedKept => 'Laporan ditutup. Wallpaper dipertahankan.';

  @override
  String get adminReported => 'Dilaporkan';

  @override
  String get adminReporter => 'Pelapor';

  @override
  String get adminReports => 'Laporan';

  @override
  String get adminReserve => 'Cadangkan';

  @override
  String get adminReserveForDrop => 'Cadangkan untuk Drop';

  @override
  String get adminReserveUpdateFailed => 'Cadangan Drop tidak dapat diperbarui. Coba lagi.';

  @override
  String get adminReservedForNextDrop => 'Dicadangkan untuk Drop berikutnya';

  @override
  String get adminRetry => 'Coba lagi';

  @override
  String adminReviewProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString/$totalString';
  }

  @override
  String get adminSendNotification => 'Kirim notifikasi';

  @override
  String adminSendToAudience(String audience) {
    return 'Kirim ke $audience?';
  }

  @override
  String get adminSkip => 'Lewati';

  @override
  String get adminSpecificUser => 'Pengguna tertentu (email)';

  @override
  String get adminSwipeInstructions => 'Geser ke kanan untuk menyetujui, ke kiri untuk menolak';

  @override
  String get adminSwipeReview => 'Tinjauan dengan geser';

  @override
  String get adminTarget => 'Target';

  @override
  String get adminTelemetryCopied => 'Disalin ke papan klip. Tempel di tempat lain untuk menganalisisnya.';

  @override
  String get adminTelemetryReadError => 'Telemetri tidak dapat dibaca';

  @override
  String get adminTitle => 'Moderasi admin';

  @override
  String get adminTitleLabel => 'Judul';

  @override
  String get adminTitleRequired => 'Judul wajib diisi';

  @override
  String get adminTotalEvents => 'Total peristiwa';

  @override
  String get adminTryAgain => 'Coba lagi';

  @override
  String get adminUndo => 'Urungkan';

  @override
  String get adminUndoSuccessful => 'Berhasil diurungkan';

  @override
  String get adminUnknown => 'Tidak diketahui';

  @override
  String get adminUnreserve => 'Batalkan pencadangan';

  @override
  String get adminUntitled => 'Tanpa judul';

  @override
  String get adminUploaded => 'Diunggah';

  @override
  String get adminUseAppForEvents => 'Gunakan aplikasi untuk membuat peristiwa Firestore.';

  @override
  String get adminUserEmail => 'Email pengguna';

  @override
  String get adminUserReportsShowHere => 'Laporan dari pengguna akan muncul di sini.';

  @override
  String get adminValidEmailRequired => 'Masukkan email yang valid';

  @override
  String get adminView => 'Lihat';

  @override
  String get adminViewFullWallpaper => 'Lihat wallpaper penuh';

  @override
  String get adminWallId => 'ID';

  @override
  String get adminWallOfTheDay => 'Wallpaper Hari Ini';

  @override
  String get adminWallOrUpload => 'Wallpaper atau unggahan';

  @override
  String get adminWallpaperAlreadyGone => 'Wallpaper sudah tidak ada. Laporan ditutup.';

  @override
  String get adminWallpaperApproved => 'Wallpaper disetujui';

  @override
  String get adminWallpaperFullScreen => 'Wallpaper, layar penuh';

  @override
  String get adminWallpaperRejected => 'Wallpaper ditolak';

  @override
  String get adminWallpaperRemoved => 'Wallpaper dihapus';

  @override
  String get adminWallpaperReport => 'Laporan wallpaper';

  @override
  String get adminWallpaperToReview => 'Wallpaper untuk ditinjau';

  @override
  String adminWallpapersRemaining(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper tersisa',
      one: '$countString wallpaper tersisa',
    );
    return '$_temp0';
  }

  @override
  String get adminWalls => 'Wallpaper';

  @override
  String adminWriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString penulisan',
      one: '$countString penulisan',
    );
    return '$_temp0';
  }

  @override
  String get appLinkRetryWhenOnline => 'Tidak ada koneksi. Tautan ini akan dibuka saat Anda kembali online.';

  @override
  String get appTitle => 'Prism';

  @override
  String get coreBack => 'Kembali';

  @override
  String get coreBio => 'Bio';

  @override
  String get coreBlockCreatorAfterReport => 'Blokir kreator ini juga';

  @override
  String get coreBothScreens => 'kedua layar';

  @override
  String get coreCancel => 'Batal';

  @override
  String get coreCancelSelection => 'Batalkan pilihan';

  @override
  String get coreCancelSignIn => 'Jangan sekarang';

  @override
  String get coreCategoryAbstract => 'Abstrak';

  @override
  String get coreCategoryAerial => 'Pemandangan udara';

  @override
  String get coreCategoryAesthetic => 'Estetis';

  @override
  String get coreCategoryAiArt => 'Seni AI';

  @override
  String get coreCategoryAnimals => 'Hewan';

  @override
  String get coreCategoryAnime => 'Anime';

  @override
  String get coreCategoryArchitecture => 'Arsitektur';

  @override
  String get coreCategoryArtistic => 'Artistik';

  @override
  String get coreCategoryBirds => 'Burung';

  @override
  String get coreCategoryCars => 'Mobil';

  @override
  String get coreCategoryCity => 'Kota';

  @override
  String get coreCategoryClouds => 'Awan';

  @override
  String get coreCategoryComic => 'Komik';

  @override
  String get coreCategoryCyberpunk => 'Cyberpunk';

  @override
  String get coreCategoryDark => 'Gelap';

  @override
  String get coreCategoryDefault => 'Kategori';

  @override
  String get coreCategoryFantasy => 'Fantasi';

  @override
  String get coreCategoryFashion => 'Mode';

  @override
  String get coreCategoryFlowers => 'Bunga';

  @override
  String get coreCategoryFood => 'Makanan';

  @override
  String get coreCategoryForest => 'Hutan';

  @override
  String get coreCategoryGalaxy => 'Galaksi';

  @override
  String get coreCategoryGaming => 'Game';

  @override
  String get coreCategoryGradient => 'Gradien';

  @override
  String get coreCategoryIllustration => 'Ilustrasi';

  @override
  String get coreCategoryKawaii => 'Kawaii';

  @override
  String get coreCategoryLandscape => 'Pemandangan';

  @override
  String get coreCategoryMinimal => 'Minimalis';

  @override
  String get coreCategoryMusic => 'Musik';

  @override
  String get coreCategoryNature => 'Alam';

  @override
  String get coreCategoryNeon => 'Neon';

  @override
  String get coreCategoryOcean => 'Laut';

  @override
  String get coreCategoryPortraits => 'Potret';

  @override
  String get coreCategoryQuotes => 'Kutipan';

  @override
  String get coreCategoryRender3d => 'Render 3D';

  @override
  String get coreCategoryRobots => 'Robot';

  @override
  String get coreCategoryScenery => 'Panorama';

  @override
  String get coreCategorySpace => 'Antariksa';

  @override
  String get coreCategorySpiritual => 'Spiritual';

  @override
  String get coreCategorySports => 'Olahraga';

  @override
  String get coreCategoryTech => 'Teknologi';

  @override
  String get coreCategoryTextures => 'Tekstur';

  @override
  String get coreCategoryUnderTheSea => 'Bawah laut';

  @override
  String get coreCategoryVehicles => 'Kendaraan';

  @override
  String get coreCategoryVintage => 'Vintage';

  @override
  String get coreCategoryWarriors => 'Pejuang';

  @override
  String get coreChangeWallpaperTarget => 'Ubah layar tempat wallpaper dipasang';

  @override
  String get coreChangelogLatest => 'Terbaru';

  @override
  String get coreChooseReportReason => 'Pilih alasan';

  @override
  String get coreChooseUsername => 'Pilih nama pengguna yang tersedia.';

  @override
  String get coreCoinAiWallpaper => 'Wallpaper AI';

  @override
  String get coreCoinAutoRotatePass => 'Akses putar otomatis, 7 hari';

  @override
  String get coreCoinBadgeReward => 'Hadiah lencana';

  @override
  String coreCoinBalance(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString koin Prism';
  }

  @override
  String coreCoinBalanceChange(String balance, String change) {
    return '$balance, $change';
  }

  @override
  String get coreCoinBoost => 'Promosikan';

  @override
  String get coreCoinCoins => 'Koin';

  @override
  String get coreCoinCoinsReturned => 'Koin dikembalikan';

  @override
  String get coreCoinCollectionPreview => 'Pratinjau koleksi, 24 jam';

  @override
  String get coreCoinDailyChest => 'Peti harian';

  @override
  String get coreCoinDailyStreak => 'Rangkaian harian';

  @override
  String coreCoinDailyStreakDay(String day) {
    return 'Rangkaian harian, hari $day';
  }

  @override
  String get coreCoinDay7Chest => 'Peti hari ke-7';

  @override
  String get coreCoinDrawTicket => 'Tiket Draw';

  @override
  String get coreCoinDropPack => 'Paket Drop';

  @override
  String get coreCoinDropWall => 'Wallpaper Drop';

  @override
  String get coreCoinFirstUpload => 'Unggahan pertama';

  @override
  String get coreCoinGiftPass => 'Hadiah: akses 24 jam';

  @override
  String get coreCoinInviteReward => 'Hadiah undangan';

  @override
  String get coreCoinLiveWallpaperStyle => 'Gaya wallpaper bergerak';

  @override
  String get coreCoinPremiumFilter => 'Filter Premium';

  @override
  String get coreCoinPremiumWallpaper => 'Wallpaper Premium';

  @override
  String get coreCoinProDailyBonus => 'Bonus harian Pro';

  @override
  String get coreCoinProSpin => 'Putaran Pro';

  @override
  String get coreCoinProStreakBonus => 'Bonus rangkaian Pro';

  @override
  String get coreCoinProfileComplete => 'Profil lengkap';

  @override
  String get coreCoinQuest => 'Misi';

  @override
  String coreCoinRefund(String target) {
    return 'Pengembalian dana: $target';
  }

  @override
  String get coreCoinShop => 'Toko';

  @override
  String get coreCoinSpinWheel => 'Putar roda';

  @override
  String get coreCoinStreakFreeze => 'Perlindungan rangkaian';

  @override
  String get coreCoinStreakRestore => 'Pemulihan rangkaian';

  @override
  String get coreCoinWallpaperDownload => 'Unduhan wallpaper';

  @override
  String get coreCoinWatchedVideo => 'Menonton video';

  @override
  String get coreCoinWeekBonus => 'Bonus mingguan';

  @override
  String get coreColorBlack => 'Hitam';

  @override
  String get coreColorBlue => 'Biru';

  @override
  String get coreColorBrown => 'Cokelat';

  @override
  String get coreColorGreen => 'Hijau';

  @override
  String get coreColorGrey => 'Abu-abu';

  @override
  String get coreColorOrange => 'Oranye';

  @override
  String get coreColorPink => 'Merah muda';

  @override
  String get coreColorPurple => 'Ungu';

  @override
  String get coreColorRed => 'Merah';

  @override
  String get coreColorTeal => 'Hijau kebiruan';

  @override
  String get coreColorWhite => 'Putih';

  @override
  String get coreColorYellow => 'Kuning';

  @override
  String get coreConfirmWallpaperPreview => 'Konfirmasi wallpaper di pratinjau sistem.';

  @override
  String get coreContentNotAvailable => 'Item itu sudah tidak tersedia';

  @override
  String get coreContentReportUser => 'pengguna';

  @override
  String get coreContentReportWallpaper => 'wallpaper';

  @override
  String coreContentReportWhy(String contentType) {
    return 'Mengapa Anda melaporkan $contentType ini?';
  }

  @override
  String coreContentReportWhyWithDetails(String contentType, String details) {
    return 'Mengapa Anda melaporkan $contentType ini ($details)?';
  }

  @override
  String get coreContinueWithApple => 'Lanjutkan dengan Apple';

  @override
  String get coreContinueWithGoogle => 'Lanjutkan dengan Google';

  @override
  String get coreContributorCouldNotLoad => 'Profil ini tidak dapat dimuat';

  @override
  String get coreContributorGithub => 'GitHub';

  @override
  String get coreContributorTwitter => 'Twitter';

  @override
  String get coreContributorWebsite => 'Situs web';

  @override
  String get coreCouldNotLoadChangelog => 'Catatan perubahan tidak dapat dimuat';

  @override
  String get coreCouldNotLoadWallpaperForEditing => 'Wallpaper tidak dapat dimuat untuk diedit';

  @override
  String get coreCouldNotUpdateFavourites => 'Favorit tidak dapat diperbarui. Coba lagi.';

  @override
  String get coreCreatorPreviewDescription => 'Lihat profil kreator ini di Prism.';

  @override
  String get coreDefaultBanner => 'Gabung ke Telegram kami';

  @override
  String get coreDepthEffectAutoLongTip =>
      'Efek Kedalaman aktif secara otomatis. Di iOS 18 atau versi lebih lama, jangan letakkan widget di ruang bawah jam.';

  @override
  String get coreDepthEffectAutoTip => 'Efek Kedalaman aktif secara otomatis.';

  @override
  String get coreDepthEffectBadge => 'Kedalaman';

  @override
  String get coreDepthEffectBadgeSemantic => 'Mendukung Efek Kedalaman';

  @override
  String get coreDepthEffectMenuShortTip => 'Ketuk ••• lalu Efek Kedalaman.';

  @override
  String get coreDepthEffectMenuTip => 'Di editor Layar Kunci, ketuk ••• lalu Efek Kedalaman.';

  @override
  String get coreDeviceCannotSetScreen => 'Perangkat ini tidak dapat memasang wallpaper di layar itu.';

  @override
  String get coreDone => 'Selesai';

  @override
  String coreDown(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'turun $coinsString';
  }

  @override
  String get coreDownloadNotFinishedCoinsReturned => 'Unduhan terakhir Anda tidak selesai. Koin telah dikembalikan.';

  @override
  String get coreDownloadPrismPreviewDescription => 'Unduh Prism untuk menemukan wallpaper yang indah.';

  @override
  String get coreEdit => 'Edit';

  @override
  String get coreEditBioHint => 'Ceritakan tentang diri Anda…';

  @override
  String get coreEditDiscardBody => 'Perubahan Anda belum disimpan.';

  @override
  String get coreEditDiscardTitle => 'Buang perubahan?';

  @override
  String get coreEditEmailInvalid => 'Masukkan alamat email yang valid.';

  @override
  String coreEditKindLinkInvalid(String kind) {
    return 'Masukkan tautan $kind yang valid.';
  }

  @override
  String get coreEditLinkInvalid => 'Masukkan tautan yang valid.';

  @override
  String get coreEditProfile => 'Edit profil';

  @override
  String coreEditProfileLink(String kind) {
    return 'Tautan $kind';
  }

  @override
  String get coreEditRemoveBioTitle => 'Hapus bio?';

  @override
  String get coreEditRemoveConfirm => 'Hapus';

  @override
  String coreEditRemoveTitle(String item) {
    return 'Hapus $item?';
  }

  @override
  String get coreEditUsernameAvailable => 'Nama pengguna tersedia';

  @override
  String get coreEditUsernameChars => 'Gunakan hanya huruf, angka, dan garis bawah.';

  @override
  String get coreEditUsernameAllCaps => 'Gunakan setidaknya satu huruf kecil.';

  @override
  String coreEditUsernameMinLength(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Gunakan setidaknya $lengthString karakter.';
  }

  @override
  String coreEditUsernameRule(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Gunakan minimal $lengthString huruf, angka, atau garis bawah (_).';
  }

  @override
  String get coreEditUsernameTaken => 'Nama pengguna itu sudah digunakan.';

  @override
  String get coreEditUsernameTakenSemantic => 'Nama pengguna sudah digunakan';

  @override
  String get coreFavourite => 'Favorit';

  @override
  String coreFileSizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String get coreGenericSignInError => 'Terjadi kesalahan. Silakan coba lagi!';

  @override
  String get coreGoHome => 'Ke beranda';

  @override
  String get coreGooglePlayServicesSignInError =>
      'Layanan Google Play di perangkat ini tidak dapat digunakan untuk masuk.';

  @override
  String get coreGoogleSignInNetworkError => 'Gagal masuk dengan Google. Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get coreHomeScreen => 'layar utama';

  @override
  String get coreHomeScreenSetupUnavailable => 'Pengaturan layar utama sudah tidak tersedia.';

  @override
  String get coreInvalidLinkBody => 'Tautan yang Anda buka tidak valid atau sudah tidak tersedia.';

  @override
  String coreInvitedToPrismTitle(String name) {
    return '$name mengundang Anda ke Prism';
  }

  @override
  String get coreIosWallpaperGuideBody => 'iOS tidak mengizinkan aplikasi mengubah wallpaper. Selesaikan melalui Foto:';

  @override
  String get coreJoinPrismPreviewTitle => 'Gabung ke Prism';

  @override
  String get coreKeepPrismOpen => 'Biarkan Prism tetap terbuka, lalu coba lagi.';

  @override
  String get coreLoading => 'Memuat';

  @override
  String get coreLoadingMoreFailed => 'Tidak dapat memuat lagi. Ketuk untuk mencoba kembali';

  @override
  String get coreLoadingWallpaper => 'Memuat wallpaper';

  @override
  String get coreLockScreen => 'layar kunci';

  @override
  String get coreMatchAccent => 'Sesuaikan dengan warna aksen';

  @override
  String get coreName => 'Nama';

  @override
  String get coreNoWallpaperUrl => 'URL wallpaper tidak tersedia';

  @override
  String get coreNotNow => 'Jangan sekarang';

  @override
  String get coreOpenPhotos => 'Buka Foto';

  @override
  String get coreOpenSettings => 'Buka Pengaturan';

  @override
  String get corePairPickerDownloads => 'Unduhan';

  @override
  String get corePairPickerFavourites => 'Favorit';

  @override
  String get corePairPickerHistory => 'Riwayat';

  @override
  String get corePairPickerNoDownloads => 'Belum ada unduhan.';

  @override
  String get corePairPickerNoFavourites => 'Belum ada favorit.';

  @override
  String get corePairPickerNoHistory => 'Belum ada riwayat.';

  @override
  String get corePairPickerTitle => 'Pilih wallpaper layar kunci';

  @override
  String get corePairPickerUseWallpaper => 'Gunakan wallpaper ini untuk layar kunci';

  @override
  String get corePhotosPermissionMessage =>
      'Izinkan Prism menambahkan foto melalui Pengaturan untuk menyimpan wallpaper.';

  @override
  String get corePhotosStepOpen => 'Buka Foto.';

  @override
  String get corePhotosStepShare => 'Ketuk Bagikan.';

  @override
  String get corePhotosStepUseAsWallpaper => 'Ketuk Gunakan sebagai Wallpaper.';

  @override
  String corePopupAppVersion(String version) {
    return 'Anda menggunakan versi $version.';
  }

  @override
  String get corePopupCannotUndo => 'Tindakan ini tidak dapat dibatalkan.';

  @override
  String get corePopupCoverPhoto => 'foto sampul';

  @override
  String get corePopupDiscard => 'Buang';

  @override
  String get corePopupProfilePhoto => 'foto profil';

  @override
  String get corePopupWhatsNew => 'Yang baru';

  @override
  String get corePreviousWallpaperRestored => 'Wallpaper sebelumnya dipulihkan';

  @override
  String get coreProfileSaveFailed => 'Profil Anda tidak dapat disimpan. Silakan coba lagi.';

  @override
  String get coreProfileUpdated => 'Profil diperbarui';

  @override
  String coreReferralSaved(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Referensi disimpan. Masuk untuk mengklaim +$coinsString koin.';
  }

  @override
  String coreRelativeTimeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hari yang lalu',
      one: '1 hari yang lalu',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeDaysFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString hari', one: '1 hari');
    return 'dalam $_temp0';
  }

  @override
  String coreRelativeTimeHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString jam yang lalu',
      one: '1 jam yang lalu',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeHoursFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString jam', one: '1 jam');
    return 'dalam $_temp0';
  }

  @override
  String get coreRelativeTimeJustNow => 'Baru saja';

  @override
  String coreRelativeTimeMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString menit yang lalu',
      one: '1 menit yang lalu',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeMinutesFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString menit', one: '1 menit');
    return 'dalam $_temp0';
  }

  @override
  String get coreRemoveBio => 'Hapus bio';

  @override
  String get coreReport => 'Laporkan';

  @override
  String get coreReportCouldNotSubmit => 'Laporan Anda tidak dapat dikirim. Silakan coba lagi.';

  @override
  String get coreReportDetailsHint => 'Ada hal lain yang perlu kami ketahui?';

  @override
  String get coreReportDetailsOptional => 'Detail (opsional)';

  @override
  String get coreReportReasonCopyright => 'Hak cipta / kepemilikan';

  @override
  String get coreReportReasonHarassment => 'Pelecehan atau ujaran kebencian';

  @override
  String get coreReportReasonOther => 'Lainnya';

  @override
  String get coreReportReasonSexual => 'Konten seksual atau dewasa';

  @override
  String get coreReportReasonSpam => 'Spam atau menyesatkan';

  @override
  String get coreReportSent => 'Laporan terkirim. Terima kasih.';

  @override
  String get coreRestorePreviousWallpaperFailed =>
      'Wallpaper sebelumnya tidak dapat dipulihkan. Pasang kembali dari riwayat wallpaper.';

  @override
  String get coreRetry => 'Coba lagi';

  @override
  String get coreRetryImage => 'Coba gambar lagi';

  @override
  String coreRetryOnScreen(String screen) {
    return 'Coba lagi di $screen';
  }

  @override
  String get coreSaveChanges => 'Simpan perubahan';

  @override
  String get coreSeeFullChangelog => 'Lihat catatan perubahan lengkap';

  @override
  String get coreSeeMore => 'Lihat selengkapnya';

  @override
  String coreSelectCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString dipilih';
  }

  @override
  String get coreSendReport => 'Kirim laporan';

  @override
  String get coreSet => 'Pasang';

  @override
  String get coreSetItAsWallpaper => 'Pasang sebagai wallpaper';

  @override
  String get coreSetWallpaper => 'Pasang sebagai wallpaper';

  @override
  String coreSetWallpaperOn(String screen) {
    return 'Pasang sebagai wallpaper di $screen';
  }

  @override
  String get coreShare => 'Bagikan';

  @override
  String coreShareCardClipboard(String link) {
    return '🔥Lihat ini ➜ $link';
  }

  @override
  String get coreShareFormatStory => 'Story';

  @override
  String get coreShareFormatPost => 'Postingan';

  @override
  String get coreShareFormatClean => 'Polos';

  @override
  String get coreShareTargetInstagram => 'Instagram';

  @override
  String get coreShareTargetCopyLink => 'Salin tautan';

  @override
  String get coreShareTargetSaveImage => 'Simpan gambar';

  @override
  String get coreShareTargetMore => 'Lainnya';

  @override
  String coreShareCardBy(String creator) {
    return 'oleh $creator';
  }

  @override
  String get coreShareImageSaved => 'Gambar disimpan';

  @override
  String get coreShareImageFailed => 'Gambar tidak dapat disimpan. Coba lagi.';

  @override
  String get coreShareInstagramFailed => 'Instagram tidak dapat dibuka. Coba lagi.';

  @override
  String get coreSharePreviewFailed => 'Gambar ini tidak dapat dibuat. Gunakan Lainnya untuk membagikan tautan.';

  @override
  String get coreShareLinkCopied => 'Tautan berbagi disalin!';

  @override
  String coreShareProfileClipboard(String link) {
    return 'Hai, lihat profil saya di Prism ➜ $link';
  }

  @override
  String coreShareWallpaperClipboard(String link) {
    return 'Hai, lihat ini ➜ $link';
  }

  @override
  String get coreShareWallpaperGeneric => 'Wallpaper dalam paket ini tersedia di aplikasi Prism.';

  @override
  String get coreSignInFeatureBody => 'Akun Anda menyimpan koin, favorit, dan unggahan di satu tempat.';

  @override
  String coreSignInFeatureTitle(String feature) {
    return 'Masuk untuk menggunakan $feature';
  }

  @override
  String get coreSignInPopupBody => 'Simpan favorit, unggahan, dan koin Anda di setiap perangkat.';

  @override
  String get coreSignInPopupTitle => 'Masuk ke Prism';

  @override
  String get coreSignInPromptAction => 'Masuk';

  @override
  String get coreSignInToReportContent => 'Masuk untuk melaporkan konten';

  @override
  String get coreSignInToSyncFavourites => 'Masuk agar favorit Anda tersedia di setiap perangkat';

  @override
  String get coreSigningIn => 'Sedang masuk';

  @override
  String get coreSomethingWentWrong => 'Terjadi kesalahan. Coba lagi.';

  @override
  String coreStreakNext(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Berikutnya +$coinsString';
  }

  @override
  String coreStreakSemantics(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Rangkaian harian $daysString hari, hadiah berikutnya $coinsString koin';
  }

  @override
  String get coreCustomAccent => 'Warna kustom';

  @override
  String get coreCustomAccentHex => 'Kode hex';

  @override
  String get coreCustomAccentHue => 'Rona';

  @override
  String get coreCustomAccentSaturation => 'Saturasi';

  @override
  String get coreCustomAccentLightness => 'Kecerahan';

  @override
  String get coreCustomAccentInvalidHex => 'Masukkan 6 digit hex, seperti #E57697.';

  @override
  String get coreCustomAccentLowContrast =>
      'Warna ini sulit terlihat di tema ini. Pilih warna yang lebih terang atau lebih gelap.';

  @override
  String get coreCustomAccentApply => 'Gunakan warna';

  @override
  String coreThemeAccentSemanticLabel(int index, int count) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Warna aksen $indexString dari $countString';
  }

  @override
  String get coreThemeAmoled => 'AMOLED';

  @override
  String get coreThemeCoffee => 'Kopi';

  @override
  String get coreThemeCottonBlue => 'Biru Kapas';

  @override
  String get coreThemeCustom => 'Tema kustom';

  @override
  String get coreThemeDeepOcean => 'Laut Dalam';

  @override
  String get coreThemeFrostWhite => 'Putih Beku';

  @override
  String get coreThemeJungle => 'Rimba';

  @override
  String get coreThemeLocked => 'Terkunci';

  @override
  String get coreThemeMaterialDark => 'Gelap Material';

  @override
  String get coreThemeMaterialYou => 'Material You';

  @override
  String get coreThemeOlive => 'Zaitun';

  @override
  String get coreThemePepper => 'Lada';

  @override
  String get coreThemeRose => 'Mawar';

  @override
  String get coreThemeSky => 'Langit';

  @override
  String get coreThemeSteel => 'Baja';

  @override
  String get coreThemeSpooky => 'Seram';

  @override
  String get spookyBannerTitle => 'Tema Seram sudah hadir';

  @override
  String get spookyBannerSubtitle => 'Oranye, hitam, dan beberapa laba-laba. Gratis. Ketuk untuk mencoba.';

  @override
  String get spookyAnnouncementTitle => 'Baru: tema Seram 🎃';

  @override
  String get spookyAnnouncementBody => 'Oranye, hitam, dan beberapa laba-laba. Gratis. Ketuk untuk mencoba.';

  @override
  String get coreThemeDiwali => 'Diwali';

  @override
  String get diwaliBannerTitle => 'Tema Diwali sudah hadir';

  @override
  String get diwaliBannerSubtitle => 'Diya, kembang api, dan emas. Gratis. Ketuk untuk mencoba.';

  @override
  String get diwaliAnnouncementTitle => 'Baru: tema Diwali 🪔';

  @override
  String get diwaliAnnouncementBody => 'Diya, kembang api, dan emas. Gratis. Ketuk untuk mencoba.';

  @override
  String get coreThisPageDoesNotExist => 'Halaman ini tidak ada';

  @override
  String get coreTryAgain => 'Coba lagi';

  @override
  String get coreUndo => 'Urungkan';

  @override
  String coreUp(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'naik $coinsString';
  }

  @override
  String get coreUploadFailureDailyLimit => 'Anda mencapai batas unggahan hari ini. Coba lagi besok.';

  @override
  String get coreUploadFailureFileType => 'Jenis file ini tidak didukung. Gunakan gambar JPG, PNG, WebP, atau HEIC.';

  @override
  String get coreUploadFailureGeneric => 'Unggahan belum selesai. Gambar Anda masih ada, jadi Anda dapat mencoba lagi.';

  @override
  String get coreUploadFailureInProgress => 'Unggahan sedang berlangsung. Tunggu sebentar, lalu coba lagi.';

  @override
  String get coreUploadFailureOversize => 'Ukuran gambar ini lebih dari 15 MB. Pilih gambar yang lebih kecil.';

  @override
  String get coreUploadFailureSignIn => 'Masuk kembali untuk mengunggah.';

  @override
  String get coreUploadFailureWeeklyLimit => 'Anda mencapai batas unggahan gratis minggu ini.';

  @override
  String get coreUploadSubmittedSuccess => 'Wallpaper Anda telah dikirim dan sedang ditinjau.';

  @override
  String get coreUsername => 'Nama pengguna';

  @override
  String get coreUsernameCheckFailed => 'Nama pengguna tidak dapat diperiksa. Coba lagi.';

  @override
  String get coreUsernameRequiredToShareProfile => 'Tetapkan nama pengguna untuk membagikan profil Anda';

  @override
  String get coreWallpaperApplied => 'Wallpaper berhasil dipasang!';

  @override
  String get coreWallpaperBothScreens => 'Kedua layar';

  @override
  String coreWallpaperBySemanticLabel(String name) {
    return 'Wallpaper oleh $name';
  }

  @override
  String get coreWallpaperDownloadedPictures => 'Wallpaper diunduh ke Pictures/Prism!';

  @override
  String get coreWallpaperEditApplyColorFailed => 'Warna tidak dapat diterapkan. Coba lagi.';

  @override
  String get coreWallpaperErrorGeneric => 'Wallpaper tidak dapat dipasang.';

  @override
  String get coreWallpaperErrorImageTooLarge => 'Gambar ini terlalu besar untuk dipasang di perangkat Anda.';

  @override
  String get coreWallpaperErrorInvalidVideo => 'Video ini tidak dapat diputar sebagai wallpaper. Coba klip lain.';

  @override
  String get coreWallpaperErrorLiveGeneric => 'Wallpaper bergerak tidak dapat dipasang. Coba lagi.';

  @override
  String get coreWallpaperErrorMemory => 'Memori tidak cukup. Tutup aplikasi lain, lalu coba lagi.';

  @override
  String get coreWallpaperErrorNotAllowed => 'Perangkat atau profil kerja Anda tidak mengizinkan perubahan wallpaper.';

  @override
  String get coreWallpaperErrorPermission => 'Prism tidak memiliki izin untuk membaca file itu.';

  @override
  String get coreWallpaperErrorReadFile => 'File tidak dapat dibaca. Coba lagi.';

  @override
  String get coreWallpaperErrorSourceTooLarge => 'File itu terlalu besar untuk dijadikan wallpaper bergerak.';

  @override
  String get coreWallpaperErrorStyle => 'Perangkat ini tidak dapat memulai gaya itu. Coba gaya lain.';

  @override
  String get coreWallpaperErrorSystemPreview => 'Pratinjau sistem tidak dapat dibuka.';

  @override
  String get coreWallpaperErrorTextureDimensions => 'Gambar itu terlalu besar untuk dijadikan wallpaper bergerak.';

  @override
  String get coreWallpaperErrorTimeout => 'Waktu habis. Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get coreWallpaperHomeScreen => 'Layar utama';

  @override
  String get coreWallpaperHomeSetLockFailed => 'Wallpaper layar utama terpasang. Layar kunci gagal dipasang.';

  @override
  String get coreWallpaperLinkCopyFailed => 'Tautan tidak dapat disalin. Coba lagi.';

  @override
  String get coreWallpaperLinkCreateFailed => 'Tautan berbagi tidak dapat dibuat. Coba lagi.';

  @override
  String get coreWallpaperLoadTimedOut => 'Waktu habis saat memuat wallpaper. Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get coreWallpaperLockScreen => 'Layar kunci';

  @override
  String get coreWallpaperOfflineUnavailable =>
      'Wallpaper ini tidak tersimpan di perangkat ini. Sambungkan ke internet, lalu coba lagi.';

  @override
  String coreWallpaperPartialSet(String applied, String failed) {
    return '$applied terpasang. $failed gagal.';
  }

  @override
  String get coreWallpaperPreviewDescription => 'Lihat wallpaper menarik ini dari Prism.';

  @override
  String get coreWallpaperPreviewTitle => 'Wallpaper di Prism';

  @override
  String get coreWallpaperSaveFailed => 'Wallpaper tidak dapat dipasang. Coba lagi.';

  @override
  String get coreWallpaperSavedPhotos => 'Disimpan ke Foto.';

  @override
  String get coreWallpaperSavedToast => 'Hadiah iklan Anda telah ditambahkan.';

  @override
  String coreWallpaperSavedWithTip(String saved, String tip) {
    return '$saved $tip';
  }

  @override
  String get coreWallpaperSemanticLabel => 'Wallpaper';

  @override
  String get coreWallpaperSet => 'Wallpaper terpasang';

  @override
  String get coreWallpaperShareFailed => 'Wallpaper ini tidak dapat dibagikan sekarang.';

  @override
  String get coreWallpaperShareRetryFailed => 'Wallpaper ini tidak dapat dibagikan. Coba lagi.';

  @override
  String get debugAdminReviewDescription => 'Alat moderasi konten dan notifikasi push';

  @override
  String get debugAdminShortcuts => 'Pintasan admin';

  @override
  String get debugLiveActivityPreview => 'Pratinjau Live Activity';

  @override
  String get debugLiveActivityPreviewDescription => 'Menjalankan contoh aktivitas: siap setelah 8 detik';

  @override
  String get debugLiveActivityUnavailable => 'Live Activities nonaktif atau tidak didukung';

  @override
  String get debugReviewActivityPreview => 'Pratinjau aktivitas antrean tinjauan';

  @override
  String get debugReviewActivityPreviewDescription => 'Menampilkan wallpaper yang menunggu tinjauan di Layar Kunci';

  @override
  String get debugAllTags => 'Semua tag';

  @override
  String get debugAndroidVersion => 'Versi Android';

  @override
  String get debugAnimationSpeed => 'Kecepatan animasi';

  @override
  String get debugAppInfo => 'Info aplikasi';

  @override
  String get debugAppName => 'Nama aplikasi';

  @override
  String get debugAppVersion => 'Versi aplikasi';

  @override
  String get debugAutoScrollOff => 'Matikan gulir otomatis';

  @override
  String get debugAutoScrollOn => 'Aktifkan gulir otomatis';

  @override
  String debugBackendName(String backend) {
    return 'Backend: $backend';
  }

  @override
  String get debugBoard => 'Papan';

  @override
  String get debugBrand => 'Merek';

  @override
  String get debugBuildNumber => 'Nomor build';

  @override
  String get debugBuildSignature => 'Tanda tangan build';

  @override
  String get debugCacheCleared => 'Cache aplikasi dihapus';

  @override
  String get debugCancel => 'Batal';

  @override
  String get debugCheckLogsRetry => 'Periksa log, lalu coba lagi.';

  @override
  String get debugClear => 'Hapus';

  @override
  String get debugClearAll => 'Hapus semua';

  @override
  String get debugClearAllStorageBody =>
      'Ini akan menghapus permanen semua data yang disimpan secara lokal. Aplikasi mungkin berperilaku tidak semestinya sampai dimulai ulang.';

  @override
  String get debugClearAllStorageTitle => 'Hapus semua penyimpanan?';

  @override
  String get debugClearAppCache => 'Hapus cache aplikasi';

  @override
  String get debugClearAppCacheDescription => 'Hapus cache gambar, feed, dan notifikasi';

  @override
  String get debugClearImageCache => 'Hapus cache gambar';

  @override
  String get debugClearImageCacheDescription => 'Kosongkan cache gambar di memori';

  @override
  String get debugClearLogsBody => 'Ini menghapus semua entri log yang tersimpan di memori.';

  @override
  String get debugClearLogsTitle => 'Hapus log?';

  @override
  String get debugClearSearch => 'Hapus pencarian';

  @override
  String get debugCoins => 'Koin';

  @override
  String get debugCopied => 'Disalin';

  @override
  String get debugCopiedToClipboard => 'Disalin ke papan klip';

  @override
  String get debugCopy => 'Salin';

  @override
  String get debugCopyDiagnosticReport => 'Salin laporan diagnostik';

  @override
  String get debugCopyFiltered => 'Salin semua (yang difilter)';

  @override
  String get debugCopyFullDetail => 'Salin detail lengkap';

  @override
  String debugCopyTitle(String title) {
    return 'Salin $title';
  }

  @override
  String get debugCopyValue => 'Salin nilai';

  @override
  String debugCouldNotClearCache(String error) {
    return 'Cache aplikasi tidak dapat dihapus: $error';
  }

  @override
  String get debugCouldNotSaveValue => 'Nilai tidak dapat disimpan';

  @override
  String get debugCrashApp => 'Buat aplikasi crash';

  @override
  String get debugDangerZone => 'Zona berbahaya';

  @override
  String get debugDarkCard => 'Kartu gelap';

  @override
  String get debugDefaultValue => '(bawaan)';

  @override
  String get debugDelete => 'Hapus';

  @override
  String get debugDeleteKey => 'Hapus kunci';

  @override
  String debugDeleteKeyBody(String key) {
    return 'Hapus \"$key\" dari penyimpanan lokal.';
  }

  @override
  String get debugDeleteKeyTitle => 'Hapus kunci?';

  @override
  String get debugDevice => 'Perangkat';

  @override
  String get debugDeviceName => 'Perangkat';

  @override
  String get debugDevicePixelRatio => 'Rasio piksel perangkat';

  @override
  String get debugDiagnosticCopied => 'Laporan diagnostik disalin ke papan klip';

  @override
  String get debugDiagnosticReportHeading => '=== Laporan Diagnostik Debug Prism ===';

  @override
  String get debugEditValue => 'Edit nilai';

  @override
  String get debugEmail => 'Email';

  @override
  String get debugEmptyList => 'Daftar kosong';

  @override
  String get debugEnvironment => 'Lingkungan';

  @override
  String get debugError => 'Kesalahan';

  @override
  String get debugErrorCopied => 'Kesalahan disalin';

  @override
  String get debugErrorStreakLost => 'Kesalahan, rangkaian harian terputus';

  @override
  String get debugErrorValue => 'kesalahan';

  @override
  String get debugExportFile => 'Ekspor sebagai file';

  @override
  String get debugFavouriteAdded => 'Ditambahkan ke favorit';

  @override
  String get debugFilterByTag => 'Filter berdasarkan tag';

  @override
  String get debugFilterKeys => 'Filter kunci';

  @override
  String get debugFingerprint => 'Sidik jari';

  @override
  String get debugFirestoreTelemetryDescription => 'Lihat profil pembacaan dan penulisan Firestore';

  @override
  String get debugFlagsReset => 'Flag debug direset';

  @override
  String get debugForceCrash => 'Paksa crash';

  @override
  String get debugForceCrashBody => 'Ini memicu pengecualian untuk memeriksa apakah Sentry melaporkan kesalahan.';

  @override
  String get debugForceCrashDescription => 'Picu pengecualian untuk menguji pelaporan Sentry';

  @override
  String get debugForceCrashTitle => 'Paksa crash?';

  @override
  String debugGeneratedAt(String date) {
    return 'Dibuat: $date';
  }

  @override
  String get debugHardware => 'Perangkat keras';

  @override
  String get debugIdentifier => 'Pengenal';

  @override
  String get debugImageCacheCleared => 'Cache gambar dihapus';

  @override
  String get debugIsAdmin => 'Adalah admin';

  @override
  String get debugIsPremium => 'Adalah Premium';

  @override
  String get debugLevel => 'Level';

  @override
  String get debugLightCard => 'Kartu terang';

  @override
  String get debugLoadingSearch => 'Memuat, mencari';

  @override
  String get debugLogDetail => 'Detail log';

  @override
  String debugLogEntryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString entri',
      one: '$countString entri',
    );
    return '$_temp0';
  }

  @override
  String get debugLoggedIn => 'Sudah masuk';

  @override
  String get debugLoggingAndNetwork => 'Pencatatan log dan jaringan';

  @override
  String get debugLogicalSize => 'Ukuran logis';

  @override
  String get debugLogs => 'Log';

  @override
  String get debugLogsAppearHere => 'Baris log akan muncul di sini saat aplikasi berjalan.';

  @override
  String get debugMaintenance => 'Pemeliharaan';

  @override
  String get debugManufacturer => 'Produsen';

  @override
  String get debugMascot => 'Maskot';

  @override
  String get debugMessage => 'Pesan';

  @override
  String get debugMixpanelEnabled => 'Mixpanel aktif';

  @override
  String get debugMixpanelTokenPresent => 'Token Mixpanel tersedia';

  @override
  String get debugModel => 'Model';

  @override
  String get debugMoodCalm => 'Tenang';

  @override
  String get debugMoodCelebrate => 'Merayakan';

  @override
  String get debugMoodCurious => 'Penasaran';

  @override
  String get debugMoodHappy => 'Senang';

  @override
  String get debugMoodLove => 'Cinta';

  @override
  String get debugMoodProud => 'Bangga';

  @override
  String get debugMoodSad => 'Sedih';

  @override
  String get debugMoodSleepy => 'Mengantuk';

  @override
  String get debugMoodSurprised => 'Terkejut';

  @override
  String get debugMoodWorried => 'Khawatir';

  @override
  String get debugName => 'Nama';

  @override
  String get debugNoKeysFound => 'Tidak ada kunci ditemukan';

  @override
  String get debugNoLogs => 'Tidak ada log';

  @override
  String get debugNoMatchingLogs => 'Tidak ada baris log yang cocok dengan filter.';

  @override
  String get debugNotAvailable => 'Tidak tersedia';

  @override
  String get debugNotSignedIn => 'Belum masuk';

  @override
  String get debugNothingNew => 'Tidak ada yang baru';

  @override
  String get debugOfflineStreakRisk => 'Luring, rangkaian harian berisiko terputus';

  @override
  String get debugPackage => 'Paket';

  @override
  String get debugPackageName => 'Nama paket';

  @override
  String get debugPaintBaselines => 'Garis dasar teks';

  @override
  String get debugPaintBaselinesDescription => 'Tampilkan panduan garis dasar teks';

  @override
  String get debugPaintSize => 'Ukuran layout';

  @override
  String get debugPaintSizeDescription => 'Tampilkan batas layout pada semua widget';

  @override
  String get debugPaintSizeWarning =>
      'Ukuran layout, warna pelukisan ulang, dan garis dasar hanya berfungsi dalam build debug dan profile.';

  @override
  String get debugPerformanceOverlay => 'Lapisan performa';

  @override
  String get debugPerformanceOverlayDescription => 'Grafik penggunaan GPU dan CPU';

  @override
  String get debugPersistenceBackend => 'Backend persistensi';

  @override
  String get debugPexelsKeyPresent => 'Kunci Pexels tersedia';

  @override
  String get debugPhysicalDevice => 'Perangkat fisik';

  @override
  String get debugPhysicalSize => 'Ukuran fisik';

  @override
  String get debugPlatform => 'Platform';

  @override
  String get debugRcApiKeyPresent => 'Kunci API RC tersedia';

  @override
  String get debugReduceMotionPose => 'Menampilkan pose setiap suasana saat gerakan dikurangi';

  @override
  String get debugRefresh => 'Muat ulang';

  @override
  String get debugRemoteConfig => 'Remote Config';

  @override
  String get debugRemoteConfigUnavailable => 'Remote Config tidak tersedia';

  @override
  String get debugRendering => 'Perenderan';

  @override
  String get debugRepaintRainbow => 'Warna pelukisan ulang';

  @override
  String get debugRepaintRainbowDescription => 'Sorot area yang dilukis ulang dengan warna berganti';

  @override
  String get debugResetFlags => 'Reset semua flag debug';

  @override
  String get debugResetFlagsDescription => 'Kembalikan semua toggle ke nilai default';

  @override
  String get debugSave => 'Simpan';

  @override
  String get debugSaveValueAsText => 'Menyimpan akan menulis nilai sebagai teks.';

  @override
  String get debugScreen => 'Layar';

  @override
  String get debugSdkInt => 'SDK Int';

  @override
  String get debugSearchLogs => 'Cari log';

  @override
  String get debugSemanticsDebugger => 'Debugger semantik';

  @override
  String get debugSemanticsDebuggerDescription => 'Lapisi layar dengan label pohon aksesibilitas';

  @override
  String get debugSentryDsnPresent => 'DSN Sentry tersedia';

  @override
  String get debugSentryEnabled => 'Sentry aktif';

  @override
  String get debugSentryEnv => 'Lingkungan Sentry';

  @override
  String get debugSequence => 'Urutan';

  @override
  String get debugShowLogToasts => 'Tampilkan toast log';

  @override
  String get debugShowLogToastsDescription => 'Tampilkan entri log sebagai toast singkat';

  @override
  String get debugSimulateNoInternet => 'Simulasikan tanpa internet';

  @override
  String get debugSimulateNoInternetDescription => 'Paksa pemeriksaan konektivitas melaporkan luring';

  @override
  String get debugSpeed => 'Kecepatan';

  @override
  String get debugStackTrace => 'Jejak tumpukan';

  @override
  String get debugStackTraceCopied => 'Jejak tumpukan disalin';

  @override
  String get debugStillPoses => 'Pose diam';

  @override
  String get debugStorage => 'Penyimpanan';

  @override
  String get debugStorageCleared => 'Semua penyimpanan dihapus';

  @override
  String debugStorageKeyCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString kunci',
      one: '$countString kunci',
    );
    return '$_temp0';
  }

  @override
  String get debugStorageNotInitialized => 'Penyimpanan belum diinisialisasi';

  @override
  String get debugStorageReadError => 'Penyimpanan tidak dapat dibaca';

  @override
  String get debugStreakCoinsPurchase => 'Rangkaian harian, koin, pembelian';

  @override
  String get debugStreakKeptToday => 'Rangkaian harian bertahan hari ini';

  @override
  String get debugSubscriptionTier => 'Tingkat langganan';

  @override
  String get debugSystemName => 'Nama sistem';

  @override
  String get debugSystemVersion => 'Versi sistem';

  @override
  String get debugTime => 'Waktu';

  @override
  String get debugTitle => 'Debug';

  @override
  String get debugTools => 'Alat';

  @override
  String debugTypeName(String type) {
    return 'Jenis: $type';
  }

  @override
  String get debugUser => 'Pengguna';

  @override
  String get debugUserId => 'ID pengguna';

  @override
  String get debugUsername => 'Nama pengguna';

  @override
  String get debugValue => 'Nilai';

  @override
  String get debugVersion => 'Versi';

  @override
  String get debugWallpaperSetSaved => 'Wallpaper diterapkan atau disimpan';

  @override
  String get debugWotdNotification => 'Notifikasi Wallpaper Hari Ini';

  @override
  String get deepLinkInputChooseImage => 'Pilih gambar';

  @override
  String get deepLinkInputChooseImageDescription => 'Pilih gambar dari galeri untuk melanjutkan.';

  @override
  String get deepLinkInputClockPreviewTitle => 'Pratinjau jam';

  @override
  String get deepLinkInputEditTitle => 'Edit wallpaper';

  @override
  String get deepLinkInputFiltersTitle => 'Filter wallpaper';

  @override
  String get deepLinkInputGalleryError => 'Tidak dapat membuka galeri. Coba lagi.';

  @override
  String get deepLinkInputLiveTitle => 'Wallpaper bergerak';

  @override
  String get deepLinkInputPhotoPreviewTitle => 'Pratinjau foto';

  @override
  String get deepLinkInputPositionTitle => 'Atur posisi wallpaper';

  @override
  String get deepLinkInputUploadTitle => 'Unggah wallpaper';

  @override
  String get deepLinkInputWallpaperPreviewTitle => 'Pratinjau wallpaper';

  @override
  String get economyActivity => 'Aktivitas';

  @override
  String get economyActivityEmptyMessage =>
      'Tonton video atau pertahankan rangkaian harian Anda untuk mendapatkan koin pertama.';

  @override
  String get economyActivityLoadFailed => 'Aktivitas tidak dapat dimuat.';

  @override
  String get economyAdCreditFailure => 'Koin tidak dapat ditambahkan sekarang.';

  @override
  String get economyAdDailyLimit => 'Batas harian tercapai. Kembali lagi besok.';

  @override
  String get economyAdNotCompleted => 'Iklan belum selesai ditonton.';

  @override
  String get economyAdOffline => 'Anda sedang offline. Periksa koneksi, lalu coba lagi.';

  @override
  String economyAdRewardDetails(int first, int reward, int maximum) {
    final intl.NumberFormat firstNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String firstString = firstNumberFormat.format(first);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Pertama hari ini +$firstString, lalu +$rewardString. Hingga $maximumString per hari.';
  }

  @override
  String get economyAdRewardPending =>
      'Hadiah Anda belum dapat dikonfirmasi. Koin akan masuk saat Anda kembali online.';

  @override
  String get economyAdUnavailable => 'Iklan belum tersedia. Coba lagi nanti.';

  @override
  String get economyAddPhotoBio => 'Tambahkan foto dan bio';

  @override
  String get economyAddedToBalance => 'Ditambahkan ke saldo Anda';

  @override
  String get economyAddedToCollection => 'Ditambahkan ke koleksi Anda';

  @override
  String get economyAddedToXp => 'Ditambahkan ke XP Anda';

  @override
  String get economyAdsOffPrivacy => 'Iklan dinonaktifkan. Ubah ini di Pengaturan > Privasi.';

  @override
  String get economyAiBusyRefunded => 'AI sedang sibuk. Coba lagi nanti. Koin Anda telah dikembalikan.';

  @override
  String get economyAiChargeUnconfirmed => 'Tagihan tidak dapat dikonfirmasi. Koin yang terpotong akan dikembalikan.';

  @override
  String get economyAiCheckStatus => 'Periksa status';

  @override
  String economyAiCoinsNeeded(int cost, int balance) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Anda membutuhkan $costString koin. Saldo Anda $balanceString.';
  }

  @override
  String get economyAiConnectToGenerate => 'Tidak ada koneksi. Sambungkan ke internet, lalu coba lagi.';

  @override
  String get economyAiCouldNotConfirmSubmission =>
      'Pengiriman tidak dapat dikonfirmasi. Periksa Status Tinjauan sebelum mencoba lagi.';

  @override
  String get economyAiCropMayDiffer => 'Hasil potongan mungkin sedikit berbeda di perangkat Anda.';

  @override
  String get aiLiveActivityGenerating => 'Membuat wallpaper kamu';

  @override
  String get aiLiveActivityReady => 'Wallpaper kamu sudah siap';

  @override
  String get aiLiveActivityFailed => 'Tidak dapat dibuat';

  @override
  String get aiLiveActivityStale => 'Masih mengerjakannya';

  @override
  String get aiLiveActivityOpen => 'Buka di Prism';

  @override
  String get economyAiDailyLimit => 'Anda mencapai batas AI hari ini.';

  @override
  String get economyAiDescribeChanges => 'Sebutkan perubahan yang Anda inginkan, seperti warna, suasana, atau detail.';

  @override
  String get economyAiDescribeScene => 'Jelaskan adegan yang ingin dibuat.';

  @override
  String get economyAiDownloadFailed => 'Unduhan gagal! Silakan coba lagi.';

  @override
  String economyAiFailureWithRefund(String message, String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'refunded': ' Koin dikembalikan.',
      'pending': ' Pengembalian tertunda.',
      'other': ' Pengembalian dana tidak dapat diselesaikan.',
    });
    return '$message$_temp0';
  }

  @override
  String get economyAiGenerate => 'Buat';

  @override
  String get economyAiGenerateAnother => 'Buat lagi';

  @override
  String get economyAiGenerateFailed => 'Tidak dapat membuat sekarang. Coba lagi.';

  @override
  String get economyAiGenerateGenericFailure => 'Terjadi kesalahan. Coba lagi.';

  @override
  String get economyAiGeneratedWallpaper => 'Wallpaper yang dibuat';

  @override
  String economyAiGenerationFrom(String date) {
    return 'Dibuat pada $date';
  }

  @override
  String get economyAiGenerationRollingOut => 'Pembuatan AI sedang diluncurkan bertahap. Silakan coba lagi nanti.';

  @override
  String get economyAiGenerationTime => 'Proses ini memakan waktu sekitar 20 detik';

  @override
  String get economyAiHistoryEmpty =>
      'Setiap wallpaper yang Anda buat akan muncul di sini, agar Anda dapat membandingkan atau beralih kembali.';

  @override
  String get economyAiHistoryFailed => 'Riwayat tidak dapat dimuat. Tarik untuk memuat ulang.';

  @override
  String get economyAiMatchingScreenSize => 'Menyesuaikan dengan ukuran layar Anda…';

  @override
  String get economyAiApplyingStyle => 'Menerapkan gaya pilihan Anda…';

  @override
  String get economyAiFinalizingWallpaper => 'Menyelesaikan wallpaper Anda…';

  @override
  String get economyAiRemixHint => 'Langit lebih gelap, palet lebih hangat, tepi lebih lembut…';

  @override
  String economyAiNeedCoinsToGenerate(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Anda membutuhkan $costString koin untuk membuat wallpaper.';
  }

  @override
  String economyNeedMoreCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Perlu $countString koin lagi.',
      one: 'Perlu $countString koin lagi.',
    );
    return '$_temp0';
  }

  @override
  String get economyAiNoConnection => 'Tidak ada koneksi. Periksa jaringan Anda, lalu coba lagi.';

  @override
  String get economyAiNoConnectionRetry => 'Tidak ada koneksi. Coba lagi.';

  @override
  String get economyAiOfflineHistory =>
      'Anda sedang offline atau jaringan bermasalah. Tarik untuk memuat ulang saat Anda kembali online.';

  @override
  String get economyAiOfflineSavedHistory => 'Anda sedang offline. Riwayat tersimpan tetap tersedia.';

  @override
  String get economyAiPaymentCheckFailed => 'Pembayaran gagal diverifikasi. Koin Anda akan dikembalikan.';

  @override
  String get economyAiPreparingShare => 'Menyiapkan untuk dibagikan';

  @override
  String get economyAiPromptBlocked => 'Prompt itu tidak diizinkan.';

  @override
  String economyAiPromptTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Deskripsi terlalu panjang (maks. $maximumString karakter).';
  }

  @override
  String get economyAiQuality => 'Kualitas';

  @override
  String get economyAiQualityBalanced => 'Seimbang';

  @override
  String get economyAiQualityFast => 'Cepat';

  @override
  String get economyAiQualityHigh => 'Tinggi';

  @override
  String economyAiQualitySemantics(String quality, int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '$quality, $costString koin';
  }

  @override
  String get economyAiRecent => 'Terbaru';

  @override
  String get economyAiRefineExplanation =>
      'Sebutkan perubahan yang Anda inginkan. Ini akan membuat wallpaper baru dari prompt yang sama dengan seed baru, sehingga hasilnya bisa sangat berbeda.';

  @override
  String get economyAiResultBlocked => 'Hasil ini diblokir. Coba prompt lain.';

  @override
  String economyAiRolloutBody(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Fitur ini tersedia untuk $percentString% akun. Coba lagi nanti.';
  }

  @override
  String get economyAiRolloutTitle => 'Wallpaper AI diluncurkan bertahap';

  @override
  String get economyAiSave => 'Simpan';

  @override
  String get economyAiSaveFailed => 'File itu tidak dapat disimpan. Coba lagi.';

  @override
  String get economyAiSceneIdea => 'Ide adegan';

  @override
  String get economyAiSceneIdeaMessage => 'Gunakan adegan ini dalam deskripsi Anda (dapat diedit)';

  @override
  String get economyAiSetAsWallpaper => 'Pasang sebagai wallpaper';

  @override
  String get economyAiShare => 'Bagikan';

  @override
  String get economyAiShareFailed => 'Tidak dapat membagikan. Silakan coba lagi.';

  @override
  String get economyAiShareReviewNotice =>
      'Moderator meninjau kiriman sebelum ditampilkan di Prism. Bagikan hanya karya yang haknya Anda miliki.';

  @override
  String get economyAiShareWithCommunity => 'Bagikan ke komunitas?';

  @override
  String get economyAiShuffle => 'Acak';

  @override
  String get economyAiShuffleMessage => 'Acak contoh deskripsi baru';

  @override
  String get economyAiStillWorking => 'Gambar terakhir Anda masih diproses.';

  @override
  String get economyAiStyle => 'Gaya';

  @override
  String get economyAiStyleAbstract => 'Abstrak';

  @override
  String get economyAiStyleAnime => 'Anime';

  @override
  String get economyAiStyleCyberpunk => 'Cyberpunk';

  @override
  String get economyAiStyleMeshGradient => 'Gradien Mesh';

  @override
  String get economyAiStyleMinimal => 'Minimalis';

  @override
  String get economyAiStyleNature => 'Alam';

  @override
  String economyAiStyleSemantics(String style) {
    return 'Gaya: $style';
  }

  @override
  String get economyAiStyleWatercolor => 'Cat air';

  @override
  String get economyAiStyleSpace => 'Luar Angkasa';

  @override
  String get economyAiStyleSynthwave => 'Synthwave';

  @override
  String get economyAiStylePixelArt => 'Pixel Art';

  @override
  String get economyAiStyleRender3d => 'Render 3D';

  @override
  String get economyAiStyleOilPainting => 'Lukisan Minyak';

  @override
  String get economyAiStyleUkiyoE => 'Ukiyo-e';

  @override
  String get economyAiSubmissionUnconfirmed => 'Status pengiriman belum dikonfirmasi. Periksa sebelum mencoba lagi.';

  @override
  String get economyAiSubmitDisabled => 'Pengiriman AI sedang dinonaktifkan.';

  @override
  String get economyAiSubmitFailed => 'Pengiriman gagal. Silakan coba lagi.';

  @override
  String get economyAiSubmitForReview => 'Kirim untuk ditinjau komunitas';

  @override
  String get economyAiSubmitStatusUnconfirmed =>
      'Status pengiriman belum dikonfirmasi. Periksa Status Tinjauan sebelum mencoba lagi.';

  @override
  String get economyAiSubmittedForReview => 'Dikirim untuk ditinjau.';

  @override
  String get economyAiTryAgain => 'Coba lagi';

  @override
  String get economyAiTryAnother => 'Coba yang lain';

  @override
  String get economyAiTryAnotherVersion => 'Coba versi lain';

  @override
  String get economyAiUnavailableBody => 'Fitur ini dinonaktifkan sementara. Periksa lagi nanti.';

  @override
  String get economyAiUnavailableTitle => 'Wallpaper AI sedang tidak tersedia';

  @override
  String economyAiVariationTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Deskripsi itu terlalu panjang (maks. $maximumString karakter).';
  }

  @override
  String get economyAiVariationUnavailable => 'Fitur coba yang lain sedang tidak tersedia.';

  @override
  String get economyAiWallpaper => 'Wallpaper AI';

  @override
  String get economyAiWatermarkNote => 'Gambar gratis memiliki tanda air Prism. Pro menghapusnya.';

  @override
  String get economyAllRankRewardsCollected => 'Semua hadiah peringkat telah dikumpulkan';

  @override
  String get economyAllSpinsUsed => 'Semua putaran telah digunakan';

  @override
  String get economyBackTomorrow => 'Kembali lagi besok';

  @override
  String get economyBadge => 'Lencana';

  @override
  String get economyBadgeAiArtist => 'Seniman AI';

  @override
  String get economyBadgeAiArtistDescription => 'Buat 10 wallpaper AI';

  @override
  String get economyBadgeArtCurator => 'Kurator Seni';

  @override
  String get economyBadgeArtCuratorDescription => 'Favoritkan 50 wallpaper';

  @override
  String get economyBadgeCollector => 'Kolektor';

  @override
  String get economyBadgeCollectorDescription => 'Favoritkan 10 wallpaper';

  @override
  String get economyBadgeCreator => 'Kreator';

  @override
  String get economyBadgeCreatorDescription => 'Dapatkan persetujuan untuk sebuah wallpaper';

  @override
  String get economyBadgeDescription => 'Lencana di Prism';

  @override
  String get economyBadgeEarned => 'Lencana diperoleh';

  @override
  String economyBadgeEarnedCount(int count, int total) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$countString dari $totalString diperoleh';
  }

  @override
  String economyBadgeName(String name) {
    return 'Lencana $name';
  }

  @override
  String get economyBadgePrismVeteran => 'Veteran Prism';

  @override
  String get economyBadgePrismVeteranDescription => 'Gunakan Prism selama 30 hari dan capai rangkaian harian 7 hari';

  @override
  String get economyBadgeProfileComplete => 'Profil Lengkap';

  @override
  String get economyBadgeProfileCompleteDescription => 'Tambahkan foto, nama pengguna, bio, dan tautan';

  @override
  String economyBadgeSemantics(String name, String status, String description) {
    return '$name, $status. $description';
  }

  @override
  String get economyBadgeSocialButterfly => 'Sosialita';

  @override
  String get economyBadgeSocialButterflyDescription => 'Ikuti 10 kreator';

  @override
  String get economyBadgeStatusEarned => 'Diperoleh';

  @override
  String get economyBadgeStatusLocked => 'Terkunci';

  @override
  String get economyBadgeStreakMaster => 'Ahli Rangkaian';

  @override
  String get economyBadgeStreakMasterDescription => 'Capai rangkaian harian 28 hari';

  @override
  String get economyBadgeWeekWarrior => 'Pejuang Mingguan';

  @override
  String get economyBadgeWeekWarriorDescription => 'Capai rangkaian harian 7 hari';

  @override
  String get economyBadges => 'Lencana';

  @override
  String economyBalanceSemantics(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString koin Prism';
  }

  @override
  String economyBestStreak(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString hari', one: '1 hari');
    return 'Rangkaian terbaik $_temp0';
  }

  @override
  String get economyBoost => 'Promosikan';

  @override
  String economyBoostInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Tempatkan salah satu wallpaper Anda yang disetujui di bagian teratas Trending. Promosi memerlukan $amountString koin. Buka wallpaper Anda, lalu ketuk Promosikan.';
  }

  @override
  String get economyBuildStreakDaily => 'Buka Prism setiap hari untuk membangun rangkaian harian.';

  @override
  String get economyBuy => 'Beli';

  @override
  String get economyBuyPremium => 'Beli Premium';

  @override
  String get economyCancel => 'Batal';

  @override
  String get economyChestBonusDone => 'Misi bonus selesai: koin Anda menjadi dua kali lipat.';

  @override
  String get economyChestBonusToDouble => 'Selesaikan misi bonus hari ini lebih dulu untuk menggandakan koin Anda.';

  @override
  String economyChestBoosterSemantics(String title, String caption) {
    return '$title. $caption';
  }

  @override
  String economyChestCoinsPrize(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString koin', one: '1 koin');
    return '$_temp0';
  }

  @override
  String get economyChestDoFirst => 'Selesaikan ini terlebih dahulu untuk menggandakan isi peti';

  @override
  String get economyChestDoubled => 'Isi peti digandakan';

  @override
  String get economyChestDoubledByBonus => ' Digandakan oleh misi bonus Anda.';

  @override
  String get economyChestFreeToday => 'Gratis hari ini';

  @override
  String economyChestNeedCoins(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Peti ini berharga $priceString koin. Saldo Anda $balanceString. Tonton video untuk mendapatkan koin.';
  }

  @override
  String economyChestNewCosmetic(String kind, String name) {
    return '$kind baru: $name';
  }

  @override
  String economyChestNewKind(String kind) {
    return '$kind baru';
  }

  @override
  String get economyChestOpenFailed => 'Tidak dapat terhubung ke Prism. Coba lagi.';

  @override
  String economyChestOpenFor(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString misi lagi',
      one: '1 misi lagi',
    );
    return 'Buka seharga $priceString koin, atau selesaikan $_temp0 untuk membukanya secara gratis.';
  }

  @override
  String get economyChestOpened => 'Dibuka';

  @override
  String get economyChestOpenedDoubledTomorrow => 'Dibuka dan digandakan. Peti baru tersedia besok.';

  @override
  String economyChestOpenedReset(String time) {
    return 'Dibuka. Peti baru tersedia dalam $time.';
  }

  @override
  String get economyChestOpenedTomorrow => 'Dibuka. Peti baru tersedia besok.';

  @override
  String get economyChestOwnCosmeticCoins => 'Anda sudah memiliki semua kosmetik, jadi hadiahnya berupa koin';

  @override
  String get economyChestOwnEveryCosmetic => 'Anda sudah memiliki semua kosmetik';

  @override
  String get economyChestPriceChanged => 'Harganya berubah. Periksa, lalu buka lagi.';

  @override
  String economyChestPriceFreeAfter(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString misi lagi',
      one: '1 misi lagi',
    );
    return '$priceString koin, atau gratis setelah $_temp0';
  }

  @override
  String economyChestPrizeSemantics(String tier, String prize, String doubled, int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(doubled, {'true': ' Digandakan oleh misi bonus Anda.', 'other': ''});
    String _temp1 = intl.Intl.pluralLogic(
      xp,
      locale: localeName,
      other: ' Ditambah $xpString XP.',
      one: ' Ditambah 1 XP.',
      zero: '',
    );
    return '$tier. Anda memenangkan $prize.$_temp0$_temp1';
  }

  @override
  String get economyChestQuestsFree => 'Misi Anda membuat peti ini gratis hari ini.';

  @override
  String get economyChestReady => 'Siap dibuka';

  @override
  String economyChestReadyPaid(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Siap dibuka. $doneString dari $totalString misi selesai';
  }

  @override
  String economyChestResetHours(int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '${hoursString}j';
  }

  @override
  String economyChestResetHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '${hoursString}j ${minutesString}m';
  }

  @override
  String economyChestResetMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$minutesString mnt';
  }

  @override
  String get economyChestTierCommon => 'Umum';

  @override
  String get economyChestTierEpic => 'Epik';

  @override
  String get economyChestTierLegendary => 'Legendaris';

  @override
  String get economyChestTierRare => 'Langka';

  @override
  String economyChestXpLine(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Membukanya memberikan $xpString XP.';
  }

  @override
  String get economyClaimedTodayDay7Chest => 'Cukup untuk hari ini. Kembali besok untuk peti hari ke-7.';

  @override
  String economyClaimedTodayReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Cukup untuk hari ini. Kembali besok untuk +$coinsString koin.';
  }

  @override
  String get economyClosePreview => 'Tutup pratinjau';

  @override
  String economyCoinActivitySemantics(String label, String date, String amount, int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'koin', one: 'koin');
    return '$label, $date, $amount $_temp0';
  }

  @override
  String economyCoinBalance(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Saldo $balanceString';
  }

  @override
  String economyCoinGateRefundUnconfirmed(String action) {
    return '$action. Pengembalian dana Anda belum dapat dikonfirmasi.';
  }

  @override
  String economyCoinGateRefunded(String action, int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString koin dikembalikan.',
      one: '1 koin dikembalikan.',
    );
    return '$action. $_temp0';
  }

  @override
  String get economyCoinHistoryEarned => 'Diperoleh';

  @override
  String get economyCoinHistoryEmpty => 'Belum ada aktivitas koin.';

  @override
  String get economyCoinHistoryLoadFailed => 'Riwayat koin Anda tidak dapat dimuat.';

  @override
  String get economyCoinHistoryNoLoadedRows => 'Belum ada data pada daftar yang dimuat.';

  @override
  String get economyCoinHistoryNothingHere => 'Belum ada apa pun di sini.';

  @override
  String get economyCoinHistoryRefunds => 'Pengembalian dana';

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
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'koin', one: 'koin');
    return '$label$_temp0, $date, $amount $_temp1, $balance';
  }

  @override
  String get economyCoinHistorySpent => 'Digunakan';

  @override
  String get economyCoinHistoryTitle => 'Riwayat koin';

  @override
  String get economyCoinSpendFailed => 'Koin tidak dapat diproses sekarang.';

  @override
  String economyCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString koin', one: '1 koin');
    return '$_temp0';
  }

  @override
  String get economyCoinsAreYoursToSpend => 'Koin dapat Anda gunakan';

  @override
  String economyCoinsEarned(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString koin', one: '1 koin');
    return '+$_temp0';
  }

  @override
  String economyCoinsRange(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '+$minimumString hingga +$maximumString';
  }

  @override
  String get economyCoinsSpendingDetails =>
      'Koin digunakan untuk membeli wallpaper, alat, dan item Toko. XP adalah progres, bukan saldo untuk dibelanjakan. Penggunaan koin tidak mengurangi XP Anda.';

  @override
  String get economyCoinsWhatYouCanDo => 'Yang dapat Anda lakukan dengan koin';

  @override
  String get economyCoinsWord => 'koin';

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
      'true': ', atau gunakan $coinsString koin untuk membukanya sekarang',
      'other': '',
    });
    return 'Pertahankan rangkaian harian $daysString hari untuk membuka wallpaper ini$_temp0.';
  }

  @override
  String get economyCollectionLoadFailed => 'Koleksi ini tidak dapat dimuat';

  @override
  String economyCollectionNeedCoinsMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Anda membutuhkan $coinsString koin untuk membuka wallpaper ini.';
  }

  @override
  String get economyCollectionRequirementsUnmet => 'Wallpaper ini belum tersedia.';

  @override
  String get economyCollectionStillLocked => 'Masih terkunci';

  @override
  String economyCollectionUnlockedAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Terbuka setelah rangkaian harian $daysString hari';
  }

  @override
  String get economyCollectionUnlockedWithCoins => 'Dibuka dengan koin';

  @override
  String economyCollectionUnlocksAtCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Dapat dibuka seharga $coinsString koin';
  }

  @override
  String economyCollectionUnlocksAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Dapat dibuka setelah rangkaian harian $daysString hari';
  }

  @override
  String get economyCompleteProfile => 'Lengkapi profil Anda';

  @override
  String get economyCosmetic => 'kosmetik';

  @override
  String get economyCosmeticAppIcon => 'ikon aplikasi';

  @override
  String get economyCosmeticFrame => 'bingkai';

  @override
  String get economyCosmeticNameGlow => 'kilau nama';

  @override
  String get economyCosmeticTheme => 'tema';

  @override
  String economyCountdownDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '${daysString}h ${hoursString}j';
  }

  @override
  String economyCountdownHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '${hoursString}j ${minutesString}m';
  }

  @override
  String economyCountdownMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$minutesString mnt';
  }

  @override
  String get economyCreatorApprovedWalls => 'Wallpaper yang disetujui';

  @override
  String get economyCreatorIntro =>
      'Dapatkan XP saat wallpaper Anda disetujui dan anggota baru memfavoritkannya. Progres muncul setelah kontribusi pertama yang memenuhi syarat.';

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
    return 'Pencapaian $label';
  }

  @override
  String get economyCreatorMilestones => 'Pencapaian kreator';

  @override
  String economyCreatorMilestonesComplete(String label) {
    return 'Pencapaian $label selesai';
  }

  @override
  String economyCreatorNewMembersThisWeek(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString anggota baru memfavoritkan wallpaper Anda minggu ini';
  }

  @override
  String economyCreatorNextMilestone(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Pencapaian berikutnya: +$xpString XP';
  }

  @override
  String economyCreatorProgressSemantics(int current, int target) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$currentString dari $targetString';
  }

  @override
  String get economyCreatorQualifyingMembers => 'Anggota yang memenuhi syarat';

  @override
  String get economyCreatorRefresh => 'Muat ulang progres';

  @override
  String get economyCreatorRefreshing => 'Memuat ulang progres kreator…';

  @override
  String get economyCreatorRules =>
      'Wallpaper yang disetujui harus berasal dari unggahan Anda sendiri yang memenuhi syarat. Unggahan lama mungkin tidak memenuhi syarat jika Prism tidak dapat memverifikasi unggahan aslinya. Setiap anggota lain dihitung satu kali untuk semua karya Anda yang memenuhi syarat, saat mereka pertama kali memfavoritkan karya yang memenuhi syarat. Mereka harus masuk, memiliki email terverifikasi, dan akun berusia setidaknya tujuh hari. Favorit dari Anda sendiri tidak dihitung. Jumlah ini adalah catatan historis, bukan audiens Anda saat ini. Menghapus favorit tidak membatalkan XP. Pencapaian kreator memberikan XP tambahan. Minggu berlangsung Senin hingga Minggu dalam UTC; aktivitas yang terlambat dapat muncul pada minggu berikutnya.';

  @override
  String get economyCreatorSavedRefresh => 'Progres disimpan. Muat ulang untuk memperbarui.';

  @override
  String get economyCreatorSavedUnavailable => 'Progres disimpan. Fitur muat ulang tidak tersedia.';

  @override
  String economyCreatorThisWeekSummary(int walls, int xp) {
    final intl.NumberFormat wallsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String wallsString = wallsNumberFormat.format(walls);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$wallsString wallpaper yang memenuhi syarat disetujui · $xpString XP pencapaian';
  }

  @override
  String economyCreatorTrackingSince(String date) {
    return 'Pelacakan sejak $date UTC';
  }

  @override
  String get economyCreatorUnavailable => 'Progres kreator tidak tersedia.';

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

    return '$wallsString wallpaper yang memenuhi syarat disetujui · $membersString anggota baru yang memenuhi syarat · $xpString XP pencapaian';
  }

  @override
  String get economyCreatorWhatCounts => 'Yang dihitung & riwayat';

  @override
  String get economyDailyChest => 'Peti harian';

  @override
  String economyDailyChestSemantics(String state, String caption, String hasXp, String xpLine) {
    String _temp0 = intl.Intl.selectLogic(hasXp, {'true': '. $xpLine', 'other': ''});
    return 'Peti harian, $state. $caption$_temp0';
  }

  @override
  String get economyDailyChestTitle => 'Peti harian';

  @override
  String get economyDailyQuests => 'Misi harian';

  @override
  String get economyDailyStreak => 'Rangkaian harian';

  @override
  String get economyDay7Chest => 'Peti hari ke-7';

  @override
  String economyDayLabel(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Hari $dayString';
  }

  @override
  String economyDayStreakMilestone(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Rangkaian harian $daysString hari!';
  }

  @override
  String economyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'hari', one: 'hari');
    return '$_temp0';
  }

  @override
  String economyDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString hari yang lalu',
      one: '1 hari yang lalu',
    );
    return '$_temp0';
  }

  @override
  String get economyDownload => 'Unduh';

  @override
  String get economyDownloadAccountChanged => 'Akun berubah. Silakan coba simpan lagi.';

  @override
  String get economyDownloadAgain => 'Unduh lagi';

  @override
  String economyDownloadAgainCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Unduh lagi (-$costString koin)';
  }

  @override
  String get economyDownloadAlreadyInDownloads => 'Sudah ada di Unduhan';

  @override
  String economyDownloadCoinsNeeded(int missing, int reward, String watch, String adState) {
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(watch, {'true': ' Setiap iklan memberikan $rewardString.', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(adState, {
      'disabled': ' Iklan dinonaktifkan. Ubah ini di Pengaturan > Privasi.',
      'limit': ' Batas harian tercapai. Kembali lagi besok.',
      'other': '',
    });
    return 'Anda membutuhkan $missingString koin lagi untuk menyimpan wallpaper ini.$_temp0$_temp1';
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

    return '$label. Berharga $costString koin';
  }

  @override
  String get economyDownloadFailedLabel => 'Unduhan gagal';

  @override
  String economyDownloadFreeDownloadsLeftSemantics(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString unduhan gratis',
      one: '1 unduhan gratis',
    );
    return '$label. Gratis, sisa $_temp0';
  }

  @override
  String economyDownloadFreeFor(String label) {
    return '$label · Gratis';
  }

  @override
  String economyDownloadFreeLeftFor(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label · Gratis · sisa $countString';
  }

  @override
  String economyDownloadFreeOwnedSemantics(String label) {
    return '$label. Gratis, wallpaper ini milik Anda';
  }

  @override
  String economyDownloadFreeWithPassSemantics(String label) {
    return '$label. Gratis dengan akses Anda';
  }

  @override
  String get economyDownloadFreeWithPro => 'Gratis dengan Pro';

  @override
  String economyDownloadFreeWithProSemantics(String label) {
    return '$label. Gratis dengan Pro';
  }

  @override
  String get economyDownloadLinkUnavailable => 'Tautan unduhan tidak tersedia.';

  @override
  String get economyDownloadProGuestMessage =>
      'Masuk untuk menyimpan wallpaper ini dengan koin, atau dapatkan Prism Pro.';

  @override
  String get economyDownloadSaveLocalCopy => 'Simpan salinan lokal';

  @override
  String get economyDownloadSaved => 'Tersimpan';

  @override
  String get economyDownloadSavedBefore => 'Anda sudah pernah menyimpan wallpaper ini.';

  @override
  String get economyDownloadSavedInDownloads => 'Tersimpan. Sudah ada di Unduhan';

  @override
  String get economyDownloadThisWallpaper => 'Unduh wallpaper ini';

  @override
  String get economyDownloadWaitForCurrent => 'Tunggu hingga unduhan selesai!';

  @override
  String get economyDownloadWatchAdMessage => 'Tonton iklan video singkat untuk mengunduh wallpaper ini.';

  @override
  String get economyDownloadWatchAdPrivacyMessage =>
      'Tonton iklan video singkat untuk mengunduh wallpaper ini. Iklan dinonaktifkan. Ubah ini di Pengaturan > Privasi.';

  @override
  String get economyDownloads => 'Unduhan';

  @override
  String economyDownloadsInfo(int amount, int freeCount, String hasFree) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat freeCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String freeCountString = freeCountNumberFormat.format(freeCount);

    String _temp0 = intl.Intl.selectLogic(hasFree, {
      'true': ' $freeCountString unduhan pertama Anda gratis.',
      'other': '',
    });
    return 'Setiap unduhan wallpaper berharga $amountString koin.$_temp0 Unduhan gratis dengan Pro.';
  }

  @override
  String economyDrawAllTicketsHeld(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Anda sudah memiliki semua $maximumString tiket minggu ini.';
  }

  @override
  String economyDrawBuyTicket(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Beli tiket · $priceString';
  }

  @override
  String get economyDrawClosed => 'Draw ini ditutup. Draw berikutnya dibuka hari Senin.';

  @override
  String economyDrawClosesIn(String time) {
    return 'Ditutup dalam $time';
  }

  @override
  String get economyDrawLastWinner => 'Pemenang terakhir';

  @override
  String get economyDrawLoadFailed => 'Draw tidak dapat dimuat';

  @override
  String get economyDrawNotEnoughCoins => 'Koin Anda tidak cukup untuk membeli tiket.';

  @override
  String get economyDrawNotOpen => 'Draw belum dibuka.';

  @override
  String get economyDrawOfficialRules => 'Aturan resmi';

  @override
  String economyDrawPrizeDescription(int months) {
    final intl.NumberFormat monthsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(months, locale: localeName, other: '$monthsString bulan', one: '1 bulan');
    return 'Pro selama $_temp0 + bingkai Prism';
  }

  @override
  String get economyDrawProNotEligible => 'Anggota Pro tidak memenuhi syarat.';

  @override
  String get economyDrawPurchaseFailed => 'Tiket tidak dapat dibeli. Coba lagi.';

  @override
  String get economyDrawThisWeeksPrize => 'HADIAH MINGGU INI';

  @override
  String economyDrawTicketBought(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Tiket dibeli. Anda memiliki $ticketsString dari $maximumString.';
  }

  @override
  String economyDrawTicketCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Harga tiket: $priceString koin';
  }

  @override
  String economyDrawTicketsAndPeople(int tickets, int people) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat peopleNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String peopleString = peopleNumberFormat.format(people);

    String _temp0 = intl.Intl.pluralLogic(tickets, locale: localeName, other: '$ticketsString tiket', one: '1 tiket');
    String _temp1 = intl.Intl.pluralLogic(people, locale: localeName, other: '$peopleString orang', one: '1 orang');
    return '$_temp0 dari $_temp1';
  }

  @override
  String get economyDrawTitle => 'Prism Draw';

  @override
  String economyDrawYourChance(int mine, int pot) {
    final intl.NumberFormat mineNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String mineString = mineNumberFormat.format(mine);
    final intl.NumberFormat potNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String potString = potNumberFormat.format(pot);

    return 'Peluang Anda: $mineString/$potString';
  }

  @override
  String economyDrawYourTickets(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Tiket Anda: $ticketsString dari $maximumString';
  }

  @override
  String get economyDropAlreadyUnlocked => 'Anda sudah memiliki item ini.';

  @override
  String economyDropByCreator(String creator) {
    return 'oleh $creator';
  }

  @override
  String economyDropCardSemantics(String time, int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Drop mingguan, $time, $unlockedString dari $totalString telah dikumpulkan';
  }

  @override
  String economyDropCarouselDetail(int count, String time) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper',
      one: '1 wallpaper',
    );
    return '$_temp0 · $time';
  }

  @override
  String economyDropCarouselSemantics(String title, String detail, String lastCall) {
    String _temp0 = intl.Intl.selectLogic(lastCall, {'true': ', kesempatan terakhir', 'other': ''});
    return 'Drop mingguan, $title, $detail$_temp0';
  }

  @override
  String economyDropCollected(int owned, int total) {
    final intl.NumberFormat ownedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ownedString = ownedNumberFormat.format(owned);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$ownedString dari $totalString telah dikumpulkan';
  }

  @override
  String economyDropDates(String start, String end) {
    return '$start sampai $end';
  }

  @override
  String get economyDropEnded => 'Berakhir';

  @override
  String get economyDropEndedHeadline => 'Drop ini telah berakhir';

  @override
  String economyDropEndsInDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '${daysString}h', one: '1h');
    String _temp1 = intl.Intl.pluralLogic(hours, locale: localeName, other: '${hoursString}j', one: '1j');
    return 'Berakhir dalam $_temp0 $_temp1';
  }

  @override
  String economyDropEndsInHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(hours, locale: localeName, other: '${hoursString}j', one: '1j');
    String _temp1 = intl.Intl.pluralLogic(minutes, locale: localeName, other: '${minutesString}m', one: '1m');
    return 'Berakhir dalam $_temp0 $_temp1';
  }

  @override
  String economyDropEndsInMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return 'Berakhir dalam ${minutesString}m';
  }

  @override
  String get economyDropGone => 'Drop ini sudah tidak tersedia';

  @override
  String get economyDropLastCallLabel => 'Kesempatan terakhir';

  @override
  String get economyDropLoadFailed => 'Drop tidak dapat dimuat';

  @override
  String get economyDropLocked => 'Terkunci';

  @override
  String get economyDropMissed => 'Terlewat';

  @override
  String get economyDropOver => 'Drop ini sudah berakhir.';

  @override
  String get economyDropPastDrops => 'Drop sebelumnya';

  @override
  String economyDropPosition(int index, int total) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$indexString dari $totalString';
  }

  @override
  String get economyDropPreviewTitle => 'Pratinjau Drop';

  @override
  String get economyDropRename => 'Ganti nama Drop';

  @override
  String get economyDropRenameFailed => 'Nama Drop tidak dapat diubah. Coba lagi.';

  @override
  String get economyDropRenameHint => 'Nama Drop';

  @override
  String get economyDropRenamed => 'Nama Drop diubah';

  @override
  String economyDropSave(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Hemat $coinsString';
  }

  @override
  String economyDropStats(String walls, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString kolektor', one: '1 kolektor');
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

    return 'Buka semua $countString seharga $priceString';
  }

  @override
  String get economyDropUnlockFailed => 'Item ini tidak dapat dibuka. Coba lagi.';

  @override
  String economyDropUnlockFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Buka seharga $priceString';
  }

  @override
  String economyDropUnlockWall(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Buka wallpaper ini seharga $priceString';
  }

  @override
  String get economyDropUnlocked => 'Terbuka';

  @override
  String economyDropUnlockedCount(int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$unlockedString/$totalString terbuka';
  }

  @override
  String economyDropUnlockedCountToast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper terbuka',
      one: 'Wallpaper terbuka',
    );
    return '$_temp0';
  }

  @override
  String get economyDropUnlockedWall => 'Wallpaper terbuka';

  @override
  String economyDropUnlockedWallBy(String creator) {
    return 'Wallpaper terbuka oleh $creator';
  }

  @override
  String economyDropWallBySemantics(String state, String serial, String creator) {
    return 'Wallpaper $serial $state oleh $creator';
  }

  @override
  String economyDropWallCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper',
      one: '1 wallpaper',
    );
    return '$_temp0';
  }

  @override
  String economyDropWallSemantics(String state, String serial) {
    return 'Wallpaper $serial $state';
  }

  @override
  String get economyDropWallpaperUnavailable => 'Wallpaper ini tidak tersedia';

  @override
  String economyDropWeekOf(String date) {
    return 'Pekan $date';
  }

  @override
  String get economyDropYourVault => 'Koleksi Anda';

  @override
  String get economyDrops => 'Drops';

  @override
  String get economyEarnCoins => 'Dapatkan koin';

  @override
  String get economyEarnXpAsYouGo => 'Dapatkan XP selama beraktivitas';

  @override
  String economyEarnedAtRank(String rank) {
    return 'Diperoleh pada peringkat $rank';
  }

  @override
  String get economyEquipped => 'Dipakai';

  @override
  String get economyEveryChestPays => 'Setiap peti memberikan hadiah.';

  @override
  String get economyEverySpinPays => 'Setiap putaran memberikan hadiah.';

  @override
  String economyFallbackCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Memberikan $countString koin jika Anda sudah memiliki semuanya';
  }

  @override
  String economyFinishDay7Chest(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Selesaikan hari ke-7 untuk mendapat peti berisi +$minimumString hingga +$maximumString';
  }

  @override
  String get economyFinishStreakWeek => 'Selesaikan rangkaian harian selama seminggu.';

  @override
  String economyFirstDownloadsFree(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString pertama gratis';
  }

  @override
  String get economyFirstUpload => 'Unggahan pertama';

  @override
  String get economyFreeDailySpin => 'Putaran harian gratis';

  @override
  String economyFreeDownloadsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Sisa $countString unduhan gratis';
  }

  @override
  String get economyFreeSpin => 'Putaran gratis';

  @override
  String economyFreeSpinReady(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '. Sisa $countString putaran berbayar hari ini.',
      one: '. Sisa 1 putaran berbayar hari ini.',
      zero: '',
    );
    return 'Putaran gratis siap$_temp0';
  }

  @override
  String get economyFreezeAdded => 'Perlindungan rangkaian ditambahkan.';

  @override
  String economyFreezeAlreadyAtLimit(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString perlindungan',
      one: '1 perlindungan',
    );
    return 'Anda sudah memiliki $_temp0.';
  }

  @override
  String economyFreezeBalanceAfter(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Saldo setelahnya: $balanceString';
  }

  @override
  String economyFreezeBuyConfirm(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Beli perlindungan rangkaian seharga $costString koin?';
  }

  @override
  String get economyFreezeBuyFailed => 'Perlindungan tidak dapat dibeli. Coba lagi.';

  @override
  String economyFreezeCount(int held, int total) {
    final intl.NumberFormat heldNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String heldString = heldNumberFormat.format(held);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$heldString dari $totalString';
  }

  @override
  String get economyFreezeDescription =>
      'Melindungi rangkaian harian Anda jika Anda melewatkan satu hari. Perlindungan ini digunakan secara otomatis.';

  @override
  String get economyFreezeFull => 'Penuh';

  @override
  String economyFreezeGetOne(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Dapatkan satu · $costString';
  }

  @override
  String get economyFreezeHeld => 'Perlindungan tersimpan';

  @override
  String economyFreezeNeedCoins(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Anda membutuhkan $costString koin.';
  }

  @override
  String get economyFreezeSlotEmpty => 'Slot perlindungan kosong';

  @override
  String get economyFreezeUnavailable => 'Perlindungan rangkaian sedang tidak tersedia. Coba lagi nanti.';

  @override
  String get economyFreshLeaderboardDetails =>
      'Papan peringkat menggunakan XP mingguan yang direset setiap Senin pukul 00.00 UTC. Total XP, peringkat, dan kosmetik yang Anda peroleh tetap ada.';

  @override
  String get economyFreshLeaderboardWeekly => 'Papan peringkat baru setiap minggu';

  @override
  String get economyGetCoins => 'Dapatkan koin';

  @override
  String economyGetCoinsChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Dapatkan koin. Peti berharga $priceString koin';
  }

  @override
  String economyGetCoinsForSpin(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Dapatkan koin. Putaran berharga $priceString koin';
  }

  @override
  String get economyGetFreezeNextTime => 'Dapatkan perlindungan untuk kesempatan berikutnya';

  @override
  String get economyGetPro => 'Dapatkan Pro';

  @override
  String get economyGiftPass => 'Hadiahkan akses';

  @override
  String economyGiftPassInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Berikan akses konten Pro kepada teman selama 24 jam seharga $amountString koin. Buka profilnya, lalu ketuk Hadiahkan akses 24 jam.';
  }

  @override
  String get economyGotIt => 'Mengerti';

  @override
  String economyHighestRankReached(String rank) {
    return 'Peringkat tertinggi yang dicapai: $rank';
  }

  @override
  String get economyHighestRankReachedShort => 'Peringkat tertinggi tercapai';

  @override
  String get economyHomeScreen => 'Layar utama';

  @override
  String get economyInviteFriend => 'Undang teman';

  @override
  String get economyJackpotAddedToBalance => 'Jackpot. Ditambahkan ke saldo Anda';

  @override
  String get economyKeepStreakToday => 'Buka Prism hari ini untuk mempertahankan rangkaian harian Anda.';

  @override
  String get economyLastWeek => 'Minggu lalu';

  @override
  String economyLeaderboardEntrySemantics(int position, String name, String isMe, int xp, String hasRank, String rank) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(isMe, {'true': ', Anda', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(hasRank, {'true': ', peringkat keseluruhan $rank', 'other': ''});
    return '$positionString, $name$_temp0, $xpString XP minggu ini$_temp1';
  }

  @override
  String get economyLeaderboardFollowTip => 'Skor Anda disertakan. Ikuti kreator untuk membandingkan XP mingguan.';

  @override
  String get economyLeaderboardFollowToSee => 'Ikuti kreator untuk melihat mereka di sini.';

  @override
  String get economyLeaderboardFollowing => 'Mengikuti';

  @override
  String get economyLeaderboardFriendsCaption => 'Anda dan orang yang Anda ikuti · tarik untuk memuat ulang';

  @override
  String get economyLeaderboardFriendsDetails =>
      'Termasuk skor Anda dan hingga 90 akun pertama yang Anda ikuti. Akun yang dihapus tidak disertakan; tidak ada batas minimum usia akun. Skor dimuat saat Anda pertama kali membuka tab ini. Tarik untuk memuat ulang. Skor Anda mencerminkan XP terbaru yang disinkronkan.';

  @override
  String get economyLeaderboardGlobal => 'Global';

  @override
  String get economyLeaderboardGlobalCaption => '50 teratas · diperbarui sekitar setiap 3 jam';

  @override
  String get economyLeaderboardGlobalDetails =>
      'Menampilkan hingga 50 akun berdasarkan XP mingguan. Akun harus berusia setidaknya 7 hari; akun yang dihapus tidak disertakan. Data diperbarui sekitar setiap 3 jam, jadi XP baru mungkin perlu waktu untuk muncul. Tarik untuk memuat data terbaru.';

  @override
  String get economyLeaderboardHowScoringWorks => 'Cara kerja penilaian papan peringkat';

  @override
  String get economyLeaderboardLoadFailed => 'Papan peringkat tidak dapat dimuat';

  @override
  String get economyLeaderboardNoRankings => 'Belum ada peringkat';

  @override
  String get economyLeaderboardOffline => 'Jika Anda offline, skor tersimpan mungkin ditampilkan.';

  @override
  String get economyLeaderboardRankedByXp => 'Diurutkan berdasarkan XP yang diperoleh minggu ini';

  @override
  String economyLeaderboardReset(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '${daysString}h', one: '1h');
    String _temp1 = intl.Intl.pluralLogic(hours, locale: localeName, other: '${hoursString}j', one: '1j');
    return 'Direset Senin pukul 00.00 UTC · tersisa $_temp0 $_temp1';
  }

  @override
  String get economyLeaderboardScoringIntro =>
      'Posisi ditentukan oleh XP yang diperoleh minggu ini. Label peringkat, seperti Perak, menggunakan total XP. XP mingguan direset setiap Senin pukul 00.00 UTC; total XP dan peringkat tetap.';

  @override
  String get economyLeaderboardTitle => 'Papan peringkat';

  @override
  String get economyLifetimePermanentDetails =>
      'Total XP menentukan peringkat Anda dan tidak pernah direset. Kosmetik peringkat otomatis masuk ke inventaris Anda, tidak memerlukan koin, dan tetap menjadi milik Anda. Pilih kapan akan memakainya di Toko.';

  @override
  String get economyLifetimePermanentRewards => 'Progres keseluruhan, hadiah permanen';

  @override
  String economyLifetimeXp(String xp) {
    return '$xp total XP';
  }

  @override
  String get economyLifetimeXpNeverResets => 'Total XP tidak pernah direset.';

  @override
  String get economyLoadingVideo => 'Memuat video';

  @override
  String get economyLockScreen => 'Layar kunci';

  @override
  String get economyMystery => 'Misteri';

  @override
  String get economyMysteryCosmetic => 'Kosmetik misteri';

  @override
  String get economyNewBadge => 'Lencana baru';

  @override
  String economyNewCosmetic(String kind, String name) {
    return '$kind baru: $name';
  }

  @override
  String get economyNewUnknownCosmetic => 'Kosmetik baru';

  @override
  String get economyNextDropMonday => 'Drop berikutnya hadir hari Senin.';

  @override
  String economyNextReward(String reward) {
    return 'Hadiah berikutnya: $reward';
  }

  @override
  String get economyNice => 'Bagus';

  @override
  String get economyNoDropNow => 'Tidak ada Drop saat ini';

  @override
  String get economyNoSpinsLeft => 'Tidak ada putaran tersisa hari ini.';

  @override
  String get economyNotEnoughCoins => 'Koin tidak cukup';

  @override
  String get economyNotNow => 'Jangan sekarang';

  @override
  String economyOddsTierSemantics(String tier, String odds) {
    return '$tier, $odds';
  }

  @override
  String get economyOddsTitle => 'Peluang';

  @override
  String get economyOnceADay => 'Sekali sehari';

  @override
  String get economyOpen => 'Buka';

  @override
  String economyOpenChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Buka peti, $priceString koin';
  }

  @override
  String get economyOpenChestFree => 'Buka peti, gratis';

  @override
  String get economyOpenChestLoading => 'Membuka peti. Memuat';

  @override
  String get economyOpenDaily => 'Buka Prism setiap hari.';

  @override
  String economyOpenDailyPro(String multiplier) {
    return 'Buka Prism setiap hari. Pro mendapatkan x$multiplier.';
  }

  @override
  String get economyOpenFree => 'Buka gratis';

  @override
  String get economyOpenShop => 'Buka Toko';

  @override
  String get economyOpening => 'Membuka';

  @override
  String get economyOwned => 'Dimiliki';

  @override
  String get economyPremiumCollection => 'Koleksi Premium';

  @override
  String economyPriceCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString koin';
  }

  @override
  String economyPriceCoinsForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$amountString koin selama $hoursString jam';
  }

  @override
  String economyPriceCoinsPerWall(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString per wallpaper';
  }

  @override
  String economyPriceCoinsPerWallSemantics(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString koin per wallpaper';
  }

  @override
  String economyPriceCoinsWithNote(int amount, String note, String hasNote) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(hasNote, {'true': ', $note', 'other': ''});
    return '$amountString koin$_temp0';
  }

  @override
  String economyPriceForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$amountString selama $hoursString jam';
  }

  @override
  String economyPriceFrom(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'mulai dari $amountString';
  }

  @override
  String economyPriceFromCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'mulai dari $amountString koin';
  }

  @override
  String get economyPrizeWheel => 'Roda hadiah';

  @override
  String get economyPro => 'Pro';

  @override
  String get economyProDailyFreeSpin => 'Anggota Pro mendapat satu putaran gratis setiap hari';

  @override
  String get economyProDownloadsFilters => 'Dengan Pro, unduhan dan filter gratis.';

  @override
  String get economyProPrice => 'Harga Pro';

  @override
  String get economyProWallpaper => 'Wallpaper Pro';

  @override
  String get economyQuestBrowse10 => 'Lihat 10 wallpaper';

  @override
  String get economyQuestColourSearch => 'Cari berdasarkan warna';

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
      other: 'Misi selesai: +$xpString XP',
      zero: 'Misi selesai',
    );
    String _temp3 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Misi selesai: +$coinsString koin$_temp0',
      one: 'Misi selesai: +1 koin$_temp1',
      zero: '$_temp2',
    );
    return '$_temp3';
  }

  @override
  String get economyQuestDownload2 => 'Unduh 2 wallpaper';

  @override
  String get economyQuestFav3 => 'Favoritkan 3 wallpaper';

  @override
  String economyQuestNewIn(String time) {
    return 'Baru dalam $time';
  }

  @override
  String get economyQuestProSpin => 'Gunakan putaran gratis Anda';

  @override
  String get economyQuestSetWall => 'Pasang atau simpan wallpaper';

  @override
  String get economyQuestShareWall => 'Bagikan wallpaper';

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

    String _temp0 = intl.Intl.selectLogic(isDone, {'true': 'selesai', 'other': '$progressString dari $targetString'});
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString koin', one: '1 koin');
    String _temp2 = intl.Intl.selectLogic(hasCoins, {'true': '. Hadiah $_temp1', 'other': ''});
    String _temp3 = intl.Intl.selectLogic(hasXp, {'true': '. Hadiah $xpString XP', 'other': ''});
    String _temp4 = intl.Intl.selectLogic(hasEnds, {'true': ', berakhir dalam $endsIn', 'other': ''});
    String _temp5 = intl.Intl.selectLogic(isWeekly, {'true': '. Misi mingguan$_temp4', 'other': ''});
    return '$title, $_temp0$_temp2$_temp3$_temp5';
  }

  @override
  String get economyQuestTrending => 'Lihat yang sedang tren';

  @override
  String get economyQuestUnknown => 'Selesaikan misi';

  @override
  String get economyQuestWatchAd => 'Tonton video';

  @override
  String get economyQuestWeeklySet5 => 'Simpan atau pasang 5 wallpaper';

  @override
  String get economyQuestWotd => 'Buka Wallpaper Hari Ini';

  @override
  String get economyRankBronze => 'Perunggu';

  @override
  String get economyRankGold => 'Emas';

  @override
  String get economyRankGrowsWithXp => 'Peringkat Anda meningkat seiring total XP.';

  @override
  String economyRankInfoSemantics(String rank) {
    return 'Peringkat $rank. Cara kerja XP dan hadiah peringkat';
  }

  @override
  String get economyRankPrism => 'Prism';

  @override
  String economyRankProgressSemantics(String rank) {
    return 'Progres peringkat $rank';
  }

  @override
  String economyRankRewardAtRank(String rank, String xp) {
    return 'Otomatis menjadi milik Anda pada peringkat $rank · $xp XP';
  }

  @override
  String economyRankRewardMilestone(String rank, String xp, String reward) {
    return '$rank · $xp XP\n$reward';
  }

  @override
  String get economyRankRewardSyncing => 'Disinkronkan ke inventaris Anda. Hadiah ini tetap menjadi milik Anda.';

  @override
  String get economyRankRewardsHelp => 'Cara kerja XP dan hadiah peringkat';

  @override
  String get economyRankSilver => 'Perak';

  @override
  String economyRankTag(String rank) {
    return 'Peringkat $rank';
  }

  @override
  String get economyRankUnknown => 'Peringkat';

  @override
  String economyReferralBothGet(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString koin', one: '1 koin');
    return 'Anda berdua mendapat $_temp0';
  }

  @override
  String get economyRestore => 'Pulihkan';

  @override
  String economyRestoreStreak(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Pulihkan rangkaian harian $daysString hari Anda · $coinsString koin';
  }

  @override
  String economyRewardEarned(String reward) {
    return '$reward diperoleh';
  }

  @override
  String get economyRewardsTitle => 'Hadiah';

  @override
  String get economySameActivitySameXp => 'Aktivitas yang sama memberikan XP yang sama';

  @override
  String get economySameActivityXpDetails =>
      'Iklan, putaran Pro, bonus harian Pro, referensi, dan pengembalian dana tidak memberikan XP. Pengganda Pro dan koin tidak menambah XP. Hadiah koin tetap terpisah.';

  @override
  String get economySeeAll => 'Lihat semua';

  @override
  String get economySeeBadges => 'Lihat lencana';

  @override
  String get economySeeItInShop => 'Lihat di Toko';

  @override
  String get economySeeOdds => 'Lihat peluang';

  @override
  String get economySeePro => 'Lihat Pro';

  @override
  String get economySeeRewards => 'Lihat hadiah';

  @override
  String get economyShareWallpaper => 'Bagikan wallpaper';

  @override
  String get economyShopAlreadyOwned => 'Anda sudah memiliki ini';

  @override
  String get economyShopAurora => 'Aurora';

  @override
  String economyShopBuyFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Beli seharga $priceString';
  }

  @override
  String get economyShopChangeIconFailed => 'Ikon tidak dapat diubah';

  @override
  String economyShopCoinsShort(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Anda membutuhkan $countString koin lagi.';
  }

  @override
  String get economyShopCottonBlue => 'Biru Kapas';

  @override
  String get economyShopDeepOcean => 'Laut Dalam';

  @override
  String get economyShopDefaultIcon => 'Bawaan';

  @override
  String get economyShopEarnXp => 'Dapatkan XP';

  @override
  String economyShopEarnedAtLifetimeXp(String rank) {
    return 'Diperoleh pada peringkat $rank dengan total XP.';
  }

  @override
  String get economyShopEmber => 'Bara';

  @override
  String get economyShopEquip => 'Pakai';

  @override
  String get economyShopEquipFailed => 'Item ini tidak dapat diubah. Coba lagi.';

  @override
  String economyShopEquipped(String name) {
    return '$name dipakai';
  }

  @override
  String get economyShopFounders => 'Pendiri';

  @override
  String get economyShopFrames => 'Bingkai';

  @override
  String get economyShopGlass => 'Kaca';

  @override
  String get economyShopGlowPreviewName => 'Kilau';

  @override
  String get economyShopGlows => 'Kilau';

  @override
  String get economyShopGold => 'Emas';

  @override
  String economyShopIconEnabled(String name) {
    return 'Ikon $name aktif';
  }

  @override
  String get economyShopIcons => 'Ikon';

  @override
  String economyShopItemSemantics(String name, String status) {
    return '$name, $status';
  }

  @override
  String get economyShopJungle => 'Rimba';

  @override
  String get economyShopMono => 'Mono';

  @override
  String get economyShopNeedMoreCoins => 'Koin Anda tidak cukup untuk item ini';

  @override
  String get economyShopNoir => 'Noir';

  @override
  String get economyShopOcean => 'Laut';

  @override
  String get economyShopOlive => 'Zaitun';

  @override
  String get economyShopPepper => 'Lada';

  @override
  String get economyShopPrism => 'Prism';

  @override
  String get economyShopProOnly => 'Item ini khusus untuk anggota Pro';

  @override
  String get economyShopPurchaseFailed => 'Item ini tidak dapat dibeli. Coba lagi.';

  @override
  String economyShopPurchased(String name) {
    return '$name kini menjadi milik Anda';
  }

  @override
  String economyShopRankLocked(String rank) {
    return 'Capai peringkat $rank untuk membuka item ini';
  }

  @override
  String get economyShopRankReachedSyncing => 'Peringkat tercapai. Hadiah Anda sedang disinkronkan.';

  @override
  String economyShopRankRewardSynced(String name) {
    return 'Hadiah peringkat $name disinkronkan';
  }

  @override
  String economyShopReachRankToBuy(String rank) {
    return 'Capai peringkat $rank untuk membeli item ini.';
  }

  @override
  String get economyShopRing => 'Cincin';

  @override
  String get economyShopRose => 'Mawar';

  @override
  String economyShopSaleUntil(String date) {
    return 'Terbatas. Diskon hingga $date.';
  }

  @override
  String get economyShopSky => 'Langit';

  @override
  String get economyShopSoldOut => 'Item terbatas ini habis';

  @override
  String get economyShopSteel => 'Baja';

  @override
  String get economyShopSunset => 'Senja';

  @override
  String get economyShopSyncReward => 'Sinkronkan hadiah';

  @override
  String get economyShopThemes => 'Tema';

  @override
  String get economyShopTitle => 'Toko';

  @override
  String get economyShopUnequip => 'Lepas';

  @override
  String economyShopUnequipped(String name) {
    return '$name dilepas';
  }

  @override
  String get economyShopUseIcon => 'Gunakan ikon';

  @override
  String get economyShopUseTheme => 'Gunakan tema';

  @override
  String get economyShopWearingNeedsPro => 'Item ini hanya dapat dipakai dengan Pro.';

  @override
  String get economyShowMore => 'Tampilkan lebih banyak';

  @override
  String get economySignIn => 'Masuk';

  @override
  String get economySoldOut => 'Habis';

  @override
  String get economySoon => 'segera';

  @override
  String economySpendItemSemantics(String label, String price) {
    return '$label, $price';
  }

  @override
  String get economySpin => 'PUTAR';

  @override
  String get economySpinAgain => 'Putar lagi';

  @override
  String get economySpinAgainFree => 'Putar lagi, putaran gratis';

  @override
  String economySpinAgainPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Putar lagi, $priceString koin';
  }

  @override
  String economySpinCardCaption(int price, int maximum) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '$priceString koin per putaran. Menangkan hingga $maximumString koin atau kosmetik';
  }

  @override
  String economySpinCosts(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Satu putaran berharga $priceString koin';
  }

  @override
  String get economySpinFree => 'Putar, putaran gratis';

  @override
  String economySpinPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Putar, $priceString koin';
  }

  @override
  String get economySpinPriceChanged => 'Harganya berubah. Periksa, lalu putar lagi.';

  @override
  String economySpinShortBalanceMessage(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Satu putaran berharga $priceString koin. Saldo Anda $balanceString. Tonton video untuk mendapatkan koin.';
  }

  @override
  String get economySpinTheWheel => 'Putar roda';

  @override
  String economySpinWheelCardSemantics(String caption) {
    return 'Putar roda. $caption';
  }

  @override
  String get economySpinning => 'Memutar';

  @override
  String economySpinsLeftToday(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString putaran', one: '1 putaran');
    return 'Sisa $_temp0 hari ini.';
  }

  @override
  String get economyStreak => 'RANGKAIAN HARIAN';

  @override
  String economyStreakChestReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString Peti hari ke-7';
  }

  @override
  String get economyStreakCollection => 'Koleksi Rangkaian';

  @override
  String get economyStreakCollectionDescription =>
      'Buka wallpaper dengan mempertahankan rangkaian harian atau menggunakan koin.';

  @override
  String economyStreakCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString hari', one: '1 hari');
    return 'Rangkaian harian $_temp0';
  }

  @override
  String economyStreakCycleSemantics(int day, String showReward, int reward, String state) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(showReward, {'true': ', ditambah $rewardString koin', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(state, {'done': ', selesai', 'today': ', hari ini', 'other': ''});
    return 'Hari $dayString$_temp0$_temp1';
  }

  @override
  String economyStreakDailyReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString hari ini';
  }

  @override
  String economyStreakDayNumber(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Hari ke-$dayString dalam rangkaian harian Anda';
  }

  @override
  String get economyStreakFreeze => 'Perlindungan rangkaian';

  @override
  String economyStreakFreezeSaved(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Perlindungan menyelamatkan rangkaian harian $daysString hari Anda';
  }

  @override
  String economyStreakFreezesLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString perlindungan',
      one: '1 perlindungan',
    );
    return 'Sisa $_temp0';
  }

  @override
  String economyStreakProReward(int coins, String multiplier) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString x$multiplier Pro';
  }

  @override
  String get economyStreakRescueCooldown => 'Anda dapat memulihkan rangkaian harian sekali setiap 30 hari.';

  @override
  String get economyStreakRescueExpired => 'Batas waktu 48 jam untuk memulihkan rangkaian ini telah berakhir.';

  @override
  String get economyStreakRescueFailed => 'Rangkaian harian Anda tidak dapat dipulihkan. Coba lagi.';

  @override
  String get economyStreakRescueUnavailable => 'Rangkaian harian ini tidak dapat dipulihkan sekarang.';

  @override
  String get economyStreakReset => 'Rangkaian harian Anda direset';

  @override
  String economyStreakResetMessage(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Rangkaian Anda mencapai $daysString hari. Mulai lagi hari ini, +$coinsString koin.';
  }

  @override
  String economyStreakRestoreShort(int balance, int cost) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Saldo Anda $balanceString. Anda membutuhkan $costString.';
  }

  @override
  String get economyStreakRestored => 'Rangkaian harian Anda pulih';

  @override
  String economyStreakRestoredCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Rangkaian harian Anda kini kembali $countString hari.';
  }

  @override
  String get economyToday => 'Hari ini';

  @override
  String get economyUnknownCosmetic => 'Kosmetik';

  @override
  String economyUntil(String date) {
    return 'Hingga $date';
  }

  @override
  String economyUpToCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Hingga +$countString';
  }

  @override
  String get economyUpgradeToPro => 'Tingkatkan ke Pro';

  @override
  String economyUseReward(String reward) {
    return 'Gunakan $reward';
  }

  @override
  String get economyUseYourCoins => 'Gunakan koin Anda';

  @override
  String get economyWatchAd => 'Tonton iklan';

  @override
  String get economyWatchVideo => 'Tonton video';

  @override
  String economyWatchVideoRewardAdsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString iklan', one: '1 iklan');
    return 'Tonton video · sisa $_temp0 hari ini';
  }

  @override
  String economyWatchVideoRewardCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Tonton video (+$coinsString)';
  }

  @override
  String get economyWeekComplete => 'Minggu selesai!';

  @override
  String get economyWeekly => 'MINGGUAN';

  @override
  String get economyWeeklyDraw => 'Draw mingguan';

  @override
  String get economyWeeklyDrop => 'Drop mingguan';

  @override
  String economyWeeklyEndsIn(String time) {
    return 'MINGGUAN · $time';
  }

  @override
  String get economyWeeklyXpFriendsEveryone => 'XP mingguan, teman, dan semua orang';

  @override
  String economyWonCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString koin', one: '1 koin');
    return 'Anda memenangkan $_temp0';
  }

  @override
  String economyWonCosmetic(String kind, String name) {
    return 'Anda memenangkan $kind baru: $name';
  }

  @override
  String get economyWonUnknownCosmetic => 'Anda memenangkan kosmetik';

  @override
  String economyWonXp(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Anda memenangkan $xpString XP';
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

    return 'Rangkaian harian memberikan $dailyStreakString XP, ditambah $streakWeekString XP setelah menyelesaikan siklus tujuh hari. Peti misi memberikan $questChestString XP. Unggahan valid pertama Anda memberikan $uploadString XP; melengkapi profil memberikan $profileString XP. Setiap misi harian memberikan $dailyQuestString XP; misi mingguan memberikan $weeklyQuestString XP. Beberapa lencana dan pencapaian kreator juga memberikan XP.';
  }

  @override
  String economyXpAwarded(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '+$xpString XP';
  }

  @override
  String get economyXpRanksRewards => 'XP, peringkat & hadiah';

  @override
  String economyXpToRank(String xp, String rank) {
    return '$xp XP lagi untuk mencapai $rank';
  }

  @override
  String get economyXpUnit => 'XP';

  @override
  String get economyYesterday => 'Kemarin';

  @override
  String economyYouHaveCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Anda memiliki $countString koin';
  }

  @override
  String get economyYourXp => 'XP ANDA';

  @override
  String get errorGeneric => 'Terjadi kesalahan. Coba lagi.';

  @override
  String get errorNetwork => 'Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get navigationBackOnline => 'Kembali online';

  @override
  String get navigationNoInternetConnection => 'Tidak ada koneksi internet';

  @override
  String get navigationScrollToTop => 'Gulir ke atas';

  @override
  String get notifActivateToCollapse => 'Aktifkan untuk menciutkan.';

  @override
  String get notifActivateToExpand => 'Aktifkan untuk memperluas.';

  @override
  String get notifChannelDownloads => 'Unduhan';

  @override
  String get notifChannelDownloadsDescription => 'Dapatkan notifikasi tentang progres unduhan wallpaper.';

  @override
  String get notifChannelDraw => 'Prism Draw';

  @override
  String get notifChannelDrawDescription => 'Hasil undian dan hadiah.';

  @override
  String get notifChannelDrops => 'Drop Mingguan';

  @override
  String get notifChannelDropsDescription => 'Saat Drop baru dimulai dan sebelum berakhir.';

  @override
  String get notifChannelFollowers => 'Pengikut';

  @override
  String get notifChannelFollowersDescription => 'Dapatkan notifikasi tentang pengikut baru.';

  @override
  String get notifChannelGifts => 'Hadiah';

  @override
  String get notifChannelGiftsDescription => 'Teman mengirimi Anda akses Pro.';

  @override
  String get notifChannelGroup => 'Notifikasi';

  @override
  String get notifChannelGroupDescription => 'Semua notifikasi Prism';

  @override
  String get notifChannelModeration => 'Moderasi';

  @override
  String get notifChannelModerationDescription => 'Laporan dan permintaan tinjauan untuk admin Prism.';

  @override
  String get notifChannelPosts => 'Postingan';

  @override
  String get notifChannelPostsDescription => 'Dapatkan notifikasi tentang postingan dari artis yang Anda ikuti.';

  @override
  String get notifChannelRecommendations => 'Rekomendasi';

  @override
  String get notifChannelRecommendationsDescription => 'Dapatkan notifikasi rekomendasi dari Prism.';

  @override
  String get notifChannelStreaks => 'Pengingat rangkaian harian';

  @override
  String get notifChannelStreaksDescription => 'Pengingat pukul 20.00 agar rangkaian login harian Anda tetap berjalan.';

  @override
  String get notifChannelWotd => 'Wallpaper Hari Ini';

  @override
  String get notifChannelWotdDescription => 'Notifikasi wallpaper pilihan harian pukul 09.00.';

  @override
  String get notifClearDeviceMessage => 'Ini akan menghapusnya dari perangkat ini.';

  @override
  String get notifClearInbox => 'Kosongkan kotak masuk';

  @override
  String get notifClearInboxAction => 'Kosongkan kotak masuk';

  @override
  String notifClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Hapus $countString notifikasi?';
  }

  @override
  String get notifClearOneTitle => 'Hapus notifikasi ini?';

  @override
  String get notifCollapsed => 'Diciutkan';

  @override
  String notifDownloadedTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper diunduh.',
      one: '1 wallpaper diunduh.',
    );
    return '$_temp0';
  }

  @override
  String get notifDownloadingWallpaper => 'Mengunduh wallpaper';

  @override
  String get notifEmptyBody => 'Pengikut baru, persetujuan, dan Wallpaper Hari Ini akan muncul di sini.';

  @override
  String get notifEmptyTitle => 'Tidak ada notifikasi';

  @override
  String get notifExpanded => 'Diperluas';

  @override
  String get notifGenericTitle => 'Notifikasi';

  @override
  String notifGroupAndMore(String message, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString lainnya.',
      one: '1 lainnya.',
    );
    return '$message dan $_temp0';
  }

  @override
  String notifGroupApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'persetujuan', one: 'persetujuan');
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
      other: '$otherCountString kreator lain.',
      one: '1 kreator lain.',
    );
    return 'Dari $name dan $_temp0';
  }

  @override
  String notifGroupDailyPicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'pilihan harian', one: 'pilihan harian');
    return '$_temp0';
  }

  @override
  String get notifGroupDayRows => 'Setiap baris menunjukkan hari yang berbeda; waktu ada di sebelah kanan.';

  @override
  String notifGroupFollowerSummary(String name, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString orang lain mulai mengikuti Anda.',
      one: '1 orang lain mulai mengikuti Anda.',
    );
    return '$name dan $_temp0';
  }

  @override
  String notifGroupFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'pengikut baru', one: 'pengikut baru');
    return '$_temp0';
  }

  @override
  String get notifGroupHide => 'Sembunyikan';

  @override
  String notifGroupNotifications(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'notifikasi', one: 'notifikasi');
    return '$_temp0';
  }

  @override
  String notifGroupNotificationsRemoved(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString notifikasi dihapus',
      one: '1 notifikasi dihapus',
    );
    return '$_temp0';
  }

  @override
  String notifGroupSameMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Pesan yang sama dikirim $countString kali. Bandingkan stempel waktu untuk melihat kapan.';
  }

  @override
  String notifGroupSemantics(String title, String summary, String expandedState, String unreadStatus, String action) {
    return '$title. $summary. $expandedState. $unreadStatus $action';
  }

  @override
  String get notifGroupSeveralCreators => 'Beberapa kreator. Perluas untuk melihat setiap wallpaper.';

  @override
  String get notifGroupShowAll => 'Tampilkan semua';

  @override
  String notifGroupSummaryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString notifikasi dalam grup ini.',
      one: '1 notifikasi dalam grup ini.',
    );
    return '$_temp0';
  }

  @override
  String notifGroupWallLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'wallpaper tayang',
      one: 'wallpaper tayang',
    );
    return '$_temp0';
  }

  @override
  String get notifHasUnread => 'Ada yang belum dibaca.';

  @override
  String get notifInboxCleared => 'Kotak masuk dikosongkan';

  @override
  String get notifLoadErrorTitle => 'Notifikasi Anda tidak dapat dimuat';

  @override
  String get notifMarkAllRead => 'Tandai semua sudah dibaca';

  @override
  String get notifOfflineSaved =>
      'Notifikasi baru tidak dapat dimuat. Yang Anda lihat di bawah tersimpan di perangkat ini.';

  @override
  String get notifOpenSettings => 'Buka pengaturan';

  @override
  String get notifPermissionOff => 'Notifikasi nonaktif. Aktifkan terlebih dahulu di pengaturan sistem.';

  @override
  String get notifPermissionOffForApp => 'Notifikasi untuk Prism nonaktif.';

  @override
  String get notifPreferences => 'Preferensi notifikasi';

  @override
  String get notifPushDrawWinnerBody => 'Akses Pro selama satu bulan dan bingkai Prism menjadi milik Anda.';

  @override
  String get notifPushDrawWinnerTitle => 'Anda menang di Prism Draw';

  @override
  String notifPushDropLastCallBody(String dropTitle, int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(hours, locale: localeName, other: '$hoursString jam', one: '1 jam');
    return '$dropTitle berakhir dalam $_temp0. Setelah itu, wallpaper ini tidak tersedia selama sebulan.';
  }

  @override
  String get notifPushDropLastCallTitle => 'Kesempatan terakhir untuk Drop minggu ini';

  @override
  String notifPushDropLiveBody(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper, hanya minggu ini. Lihat pratinjaunya sebelum hilang.',
      one: '1 wallpaper, hanya minggu ini. Lihat pratinjaunya sebelum hilang.',
    );
    return '$_temp0';
  }

  @override
  String get notifPushDropLiveTitle => 'Drop baru telah dimulai';

  @override
  String get notifPushGiftReceivedBody => 'Koleksi Premium dan wallpaper Premium tersedia selama 24 jam.';

  @override
  String notifPushGiftReceivedTitle(String senderName) {
    return '$senderName mengirimi Anda akses Pro selama 24 jam';
  }

  @override
  String notifPushNewContentReportBody(String contentType, String reason, String targetId) {
    return '$contentType · $reason · dok $targetId';
  }

  @override
  String get notifPushNewContentReportTitle => 'Laporan konten baru';

  @override
  String notifPushNewFollowerBody(String followerName) {
    return '$followerName kini mengikuti Anda.';
  }

  @override
  String get notifPushNewFollowerTitle => 'Anda memiliki pengikut baru! 🎉';

  @override
  String notifPushReportReviewBody(String contentType, String reason) {
    return '$contentType · $reason · terbuka lebih dari 12 jam';
  }

  @override
  String get notifPushReportReviewTitle => 'Laporan menunggu tinjauan';

  @override
  String get notifPushStreakReminderBody => 'Buka Prism sekarang agar rangkaian login harian Anda tetap berjalan 🔥';

  @override
  String get notifPushStreakReminderTitle => 'Rangkaian harian Anda akan segera terputus!';

  @override
  String notifPushWallApprovedAdminBody(String wallTitle, String artistName) {
    return '\"$wallTitle\" karya $artistName kini tayang.';
  }

  @override
  String get notifPushWallApprovedAdminTitle => 'Wallpaper disetujui ✅';

  @override
  String notifPushWallApprovedArtistBody(String wallTitle) {
    return '\"$wallTitle\" telah disetujui dan kini dapat dilihat semua orang.';
  }

  @override
  String get notifPushWallApprovedArtistBodyUntitled =>
      'Wallpaper Anda telah disetujui dan kini dapat dilihat semua orang.';

  @override
  String get notifPushWallApprovedArtistTitle => 'Wallpaper Anda kini tayang! 🎉';

  @override
  String notifPushWallLiveFollowersBody(String wallTitle) {
    return '\"$wallTitle\" kini tayang di Prism.';
  }

  @override
  String notifPushWallLiveFollowersTitle(String artistName) {
    return 'Wallpaper baru dari $artistName';
  }

  @override
  String notifPushWallSubmittedBody(String artistName, String artistEmail) {
    return 'Postingan baru dari $artistName ($artistEmail) menunggu tinjauan.';
  }

  @override
  String get notifPushWallSubmittedTitle => 'Wallpaper Premium baru untuk ditinjau! 🎉';

  @override
  String get notifPushWinBack14Body => 'Lihat karya baru yang ditambahkan para kreator dalam dua minggu terakhir.';

  @override
  String get notifPushWinBack14Title => 'Wallpaper baru menanti';

  @override
  String get notifPushWinBack30Body => 'Buat wallpaper yang terasa seperti diri Anda.';

  @override
  String get notifPushWinBack30Title => 'Gaya AI baru untuk dicoba';

  @override
  String get notifPushWinBack60Body => 'Wallpaper favorit Anda berikutnya hanya sejauh satu ketukan.';

  @override
  String get notifPushWinBack60Title => 'Prism merindukan Anda';

  @override
  String get notifPushWinBack7Body => 'Wallpaper baru hadir saat Anda pergi.';

  @override
  String get notifPushWinBack7Title => 'Feed Anda punya wallpaper baru';

  @override
  String notifPushWotdAudienceBody(String wallTitle) {
    return '$wallTitle';
  }

  @override
  String get notifPushWotdAudienceBodyUntitled => 'Buka Prism untuk melihat Wallpaper Hari Ini.';

  @override
  String get notifPushWotdAudienceTitle => 'Wallpaper Hari Ini sudah hadir';

  @override
  String get notifPushWotdCreatorBody =>
      'Hari ini Prism memilih wallpaper Anda untuk semua orang. Terima kasih telah membagikannya.';

  @override
  String get notifPushWotdCreatorTitle => 'Wallpaper Anda menjadi Wallpaper Hari Ini';

  @override
  String get notifRead => 'Sudah dibaca';

  @override
  String get notifRemoved => 'Notifikasi dihapus';

  @override
  String get notifReportUnknownContentType => 'konten';

  @override
  String notifSemanticsRow(String message, String time, String readStatus) {
    return '$message. $time. $readStatus';
  }

  @override
  String get notifSettingDrops => 'Drop Mingguan';

  @override
  String get notifSettingDropsDescription => 'Peringatan saat Drop baru dimulai dan sebelum berakhir.';

  @override
  String get notifSettingFollowers => 'Pengikut';

  @override
  String get notifSettingFollowersDescription => 'Peringatan saat seseorang mulai mengikuti Anda.';

  @override
  String get notifSettingPosts => 'Postingan';

  @override
  String get notifSettingPostsDescription => 'Peringatan saat kreator yang Anda ikuti membagikan karya baru.';

  @override
  String get notifSettingRecommendations => 'Rekomendasi';

  @override
  String get notifSettingRecommendationsDescription => 'Tips, berita, dan pilihan wallpaper dari Prism.';

  @override
  String get notifSettingStreaks => 'Pengingat rangkaian harian';

  @override
  String get notifSettingStreaksDescription =>
      'Pengingat menjelang malam sekitar pukul 20.00 jika rangkaian login harian Anda akan terputus.';

  @override
  String get notifSettingWotd => 'Wallpaper Hari Ini';

  @override
  String get notifSettingWotdDescription => 'Pilihan wallpaper harian.';

  @override
  String get notifSignInToChange => 'Masuk untuk mengubah pengaturan ini.';

  @override
  String get notifSignInToTurnOn => 'Masuk untuk mengaktifkan';

  @override
  String get notifTapToOpenPrism => 'Ketuk untuk membuka Prism.';

  @override
  String get notifTitle => 'Notifikasi';

  @override
  String get notifToday => 'Hari ini';

  @override
  String get notifUndo => 'Urungkan';

  @override
  String get notifUnread => 'Belum dibaca';

  @override
  String get notifYesterday => 'Kemarin';

  @override
  String notifYesterdayAt(String time) {
    return 'Kemarin, $time';
  }

  @override
  String get onboardingAiGenerateError => 'Terjadi kesalahan.\nKetuk Buat untuk mencoba lagi.';

  @override
  String get onboardingAiGeneratePrompt => 'Ketuk Buat untuk membuat\nwallpaper unik Anda';

  @override
  String get onboardingAiGenerating => 'Sedang membuat wallpaper Anda…';

  @override
  String get onboardingBrowseGuest => 'Jelajahi tanpa akun';

  @override
  String get onboardingCategoriesUnavailable => 'Kategori tidak dapat dimuat. Anda dapat melewati langkah ini.';

  @override
  String get onboardingContinue => 'Lanjutkan';

  @override
  String get onboardingContinueApple => 'Lanjutkan dengan Apple';

  @override
  String get onboardingContinueGoogle => 'Lanjutkan dengan Google';

  @override
  String onboardingContinueSelected(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Lanjutkan ($countString dipilih)';
  }

  @override
  String get onboardingCouldNotLogOut => 'Tidak dapat keluar. Coba lagi.';

  @override
  String get onboardingCreatorsUnavailable => 'Kreator tidak dapat dimuat. Anda dapat melewati langkah ini.';

  @override
  String get onboardingFirstAiWallpaper => 'Wallpaper pertama Anda, dibuat dengan AI';

  @override
  String get onboardingFirstWallpaperSaveFailed => 'Wallpaper tidak dapat disimpan. Coba lagi atau lewati.';

  @override
  String get onboardingFirstWallpaperSavedPhotos => 'Disimpan ke Foto!';

  @override
  String get onboardingFirstWallpaperSet => 'Wallpaper berhasil dipasang!';

  @override
  String get onboardingFirstWallpaperSetFailed => 'Wallpaper tidak dapat dipasang. Coba lagi atau lewati.';

  @override
  String get onboardingFirstWallpaperSetHome => 'Wallpaper dipasang di layar utama.';

  @override
  String get onboardingFirstWallpaperSetHomeLock => 'Wallpaper dipasang di layar utama dan layar kunci.';

  @override
  String get onboardingFirstWallpaperSetLock => 'Wallpaper dipasang di layar kunci.';

  @override
  String get onboardingFollow => 'Ikuti';

  @override
  String onboardingFollowCreatorMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Kami menyarankan Anda mengikuti $countString kreator ini';
  }

  @override
  String onboardingFollowerCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString pengikut');
    return '$_temp0';
  }

  @override
  String get onboardingFollowing => 'Mengikuti';

  @override
  String get onboardingGenerateFailure => 'Terjadi kesalahan. Ketuk Buat untuk mencoba lagi.';

  @override
  String get onboardingGenerateSuccess => 'Hasilnya bagus! Membuka wallpaper Anda';

  @override
  String get onboardingGenerateWallpaper => 'Buat wallpaper saya';

  @override
  String get onboardingHeadlineCreators => 'Temukan kreator favorit Anda';

  @override
  String get onboardingHeadlineCustomize => 'Jadikan milik Anda';

  @override
  String get onboardingHeadlineGenerate => 'Buat wallpaper\npertama Anda';

  @override
  String get onboardingHeadlineInterests => 'Pilih gaya yang Anda suka';

  @override
  String get onboardingLoadCategoriesFailed => 'Kategori tidak dapat dimuat.';

  @override
  String get onboardingLoadCreatorsFailed => 'Kreator tidak dapat dimuat.';

  @override
  String get onboardingPro => 'Pro';

  @override
  String get onboardingProFree => '  →  gratis untuk Anda';

  @override
  String get onboardingRecoveryCreatorsFailed => 'Kreator tidak dapat dimuat. Periksa koneksi lalu ketuk Muat ulang.';

  @override
  String get onboardingRecoveryFollowFailed => 'Kreator ini tidak dapat diikuti. Coba lagi.';

  @override
  String get onboardingRecoveryFollowFailedHelper =>
      'Kreator ini tidak dapat diikuti. Periksa koneksi, lalu coba lagi.';

  @override
  String get onboardingRecoveryReload => 'Muat ulang';

  @override
  String get onboardingRecoveryRetry => 'Coba lagi';

  @override
  String get onboardingRecoverySaveInterestsFailed => 'Pilihan Anda tidak dapat disimpan. Coba lagi.';

  @override
  String get onboardingRecoverySaveInterestsFailedHelper =>
      'Pilihan Anda tidak dapat disimpan. Periksa koneksi, lalu coba lagi.';

  @override
  String get onboardingRecoverySessionExpired => 'Sesi Anda telah berakhir. Silakan masuk lagi.';

  @override
  String get onboardingRecoverySessionExpiredHelper => 'Sesi Anda telah berakhir. Masuk lagi untuk melanjutkan.';

  @override
  String get onboardingRecoverySetupFailed => 'Penyiapan tidak selesai. Coba lagi.';

  @override
  String get onboardingRecoverySetupFailedHelper => 'Penyiapan tidak selesai. Periksa koneksi, lalu coba lagi.';

  @override
  String get onboardingRecoverySignIn => 'Masuk lagi';

  @override
  String get onboardingReloadLower => 'muat ulang';

  @override
  String get onboardingSavePhotos => 'simpan ke Foto';

  @override
  String onboardingSelectInterestMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Pilih setidaknya $countString kategori agar beranda Anda sesuai minat.';
  }

  @override
  String get onboardingSetWallpaper => 'pasang sebagai wallpaper';

  @override
  String get onboardingSignInAgainLower => 'masuk lagi';

  @override
  String get onboardingSkip => 'Lewati';

  @override
  String get onboardingSkipLower => 'lewati';

  @override
  String get onboardingTermsRequired => 'Setujui Ketentuan dan Kebijakan Privasi terlebih dahulu.';

  @override
  String get onboardingTryAgainLower => 'coba lagi';

  @override
  String onboardingWallpaperForInterest(String category) {
    return 'Wallpaper ini dipilih berdasarkan minat Anda pada $category';
  }

  @override
  String get onboardingWallpaperJustForYou => 'Wallpaper ini dipilih khusus untuk Anda';

  @override
  String get onboardingWelcomeDescription => 'Jutaan wallpaper premium dari para seniman terbaik.';

  @override
  String get onboardingWelcomeHeadline => 'Tampilan layar Anda, dengan nuansa baru.';

  @override
  String get premiumPageExplorePlans => 'Lihat paket Prism Premium.';

  @override
  String get premiumPagePlansUnavailable => 'Paket belum tersedia. Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get premiumPageTitle => 'Prism Premium';

  @override
  String get premiumPageTryAgain => 'Coba lagi';

  @override
  String get premiumPageViewPlans => 'Lihat paket';

  @override
  String get premiumGuestStorePurchaseActive =>
      'Pembelian toko Anda aktif di perangkat ini. Masuk untuk menggunakan fitur Pro berbasis akun.';

  @override
  String get premiumPurchasePending => 'Pembelian Anda tersimpan. Pro mungkin perlu waktu satu menit untuk aktif.';

  @override
  String get premiumPurchaseUnconfirmed =>
      'Pembelian Anda tidak dapat dikonfirmasi. Coba Pulihkan pembelian di Pengaturan.';

  @override
  String get wallpaperAccentColor => 'Warna aksen';

  @override
  String get wallpaperAccentColorsOriginal => 'Warna asli wallpaper';

  @override
  String get wallpaperResetOriginal => 'Kembali ke asli';

  @override
  String get wallpaperAccentResetHint => 'Tahan untuk tindakan, termasuk Kembali ke asli';

  @override
  String get wallpaperAll => 'Semua';

  @override
  String get wallpaperApplyTo => 'Terapkan ke';

  @override
  String get wallpaperAutoRotateAndroidOnly => 'Putar otomatis hanya tersedia di Android.';

  @override
  String get wallpaperAutoRotateApplyTo => 'Terapkan ke';

  @override
  String get wallpaperAutoRotateBatterySteps =>
      'Buka Setelan, lalu Aplikasi, Prism, Baterai. Atur penggunaan baterai ke Tanpa batas.';

  @override
  String get wallpaperAutoRotateBatteryTip =>
      'Jika wallpaper berhenti berganti, atur penggunaan baterai Prism ke Tanpa batas. Buka Setelan, lalu Aplikasi, Prism, Baterai.';

  @override
  String get wallpaperAutoRotateBothScreens => 'Keduanya';

  @override
  String get wallpaperAutoRotateChangeError => 'Wallpaper tidak dapat diubah.';

  @override
  String get wallpaperAutoRotateChangeLabel => 'Ubah';

  @override
  String get wallpaperAutoRotateChargingDescription =>
      'Berganti saat perangkat tersambung ke pengisi daya, paling sering sekali per interval';

  @override
  String get wallpaperAutoRotateChargingOnly => 'Hanya saat mengisi daya';

  @override
  String get wallpaperAutoRotateCopySteps => 'Salin langkah';

  @override
  String get wallpaperAutoRotateCouldNotStart => 'Tidak dapat memulai. Coba lagi.';

  @override
  String wallpaperAutoRotateDownloadedCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: 'wallpaper', one: 'wallpaper');
    return '$cachedString dari $totalString $_temp0 diunduh';
  }

  @override
  String wallpaperAutoRotateEnabledUntil(String date) {
    return 'Akses aktif hingga $date';
  }

  @override
  String get wallpaperAutoRotateGotIt => 'Mengerti';

  @override
  String get wallpaperAutoRotateHomeScreen => 'Layar utama';

  @override
  String get wallpaperAutoRotateInterval12Hours => 'Setiap 12 jam';

  @override
  String get wallpaperAutoRotateInterval15 => 'Setiap 15 menit (boros baterai)';

  @override
  String get wallpaperAutoRotateInterval30 => 'Setiap 30 menit';

  @override
  String get wallpaperAutoRotateInterval3Days => 'Setiap 3 hari';

  @override
  String get wallpaperAutoRotateInterval3Hours => 'Setiap 3 jam';

  @override
  String get wallpaperAutoRotateInterval6Hours => 'Setiap 6 jam';

  @override
  String get wallpaperAutoRotateIntervalDay => 'Setiap hari';

  @override
  String get wallpaperAutoRotateIntervalHour => 'Setiap jam';

  @override
  String get wallpaperAutoRotateIntervalWeek => 'Setiap minggu';

  @override
  String get wallpaperAutoRotateKeepRunning => 'Biarkan tetap berjalan';

  @override
  String get wallpaperAutoRotateLoadError => 'Setelan putar otomatis tidak dapat dimuat.';

  @override
  String get wallpaperAutoRotateLoadingWalls => 'Memuat wallpaper';

  @override
  String get wallpaperAutoRotateLockScreen => 'Layar kunci';

  @override
  String wallpaperAutoRotateMix(int count, String source) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper dari $source dalam pilihan',
      one: '1 wallpaper dari $source dalam pilihan',
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
      other: '$countString wallpaper dari $source dalam pilihan. Menggunakan 100 yang pertama.',
      one: '1 wallpaper dari $source dalam pilihan. Menggunakan 100 yang pertama.',
    );
    return '$_temp0';
  }

  @override
  String wallpaperAutoRotateNextChange(String time) {
    return 'Berganti berikutnya sekitar pukul $time';
  }

  @override
  String wallpaperAutoRotateNounCategory(String category) {
    return '$category';
  }

  @override
  String get wallpaperAutoRotateNounDownloads => 'unduhan';

  @override
  String get wallpaperAutoRotateNounFavourites => 'favorit';

  @override
  String get wallpaperAutoRotateNounHistory => 'riwayat Anda';

  @override
  String get wallpaperAutoRotateNounWotd => 'pilihan Wallpaper Hari Ini';

  @override
  String get wallpaperAutoRotateOff => 'Nonaktif';

  @override
  String get wallpaperAutoRotateOffEnded =>
      'Putar otomatis nonaktif karena paket atau akses Prism Pro Anda telah berakhir.';

  @override
  String get wallpaperAutoRotateOpenDownloads => 'Buka unduhan';

  @override
  String get wallpaperAutoRotateOpenFavourites => 'Buka favorit';

  @override
  String get wallpaperAutoRotatePassEnabled => 'Putar otomatis aktif selama 7 hari.';

  @override
  String wallpaperAutoRotatePassPurchase(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Akses 7 hari · $coinsString koin';
  }

  @override
  String get wallpaperAutoRotatePickCategory => 'Pilih kategori';

  @override
  String wallpaperAutoRotatePreparing(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper',
      one: '1 wallpaper',
    );
    return 'Menyiapkan $_temp0';
  }

  @override
  String get wallpaperAutoRotateProBody => 'Coba selama 7 hari dengan koin, atau dapatkan Prism Pro.';

  @override
  String get wallpaperAutoRotateProTitle => 'Putar otomatis adalah fitur Prism Pro.';

  @override
  String wallpaperAutoRotateReadyCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(total, locale: localeName, other: 'wallpaper', one: 'wallpaper');
    return '$cachedString dari $totalString $_temp0 siap';
  }

  @override
  String get wallpaperAutoRotateScheduled => 'Terjadwal';

  @override
  String get wallpaperAutoRotateShuffle => 'Acak';

  @override
  String get wallpaperAutoRotateShuffleDescription => 'Urutan acak, bukan satu per satu';

  @override
  String get wallpaperAutoRotateSourceCategory => 'Kategori';

  @override
  String get wallpaperAutoRotateSourceDownloads => 'Unduhan';

  @override
  String get wallpaperAutoRotateSourceFavourites => 'Favorit';

  @override
  String get wallpaperAutoRotateSourceHistory => 'Riwayat';

  @override
  String get wallpaperAutoRotateSourceLabel => 'Sumber';

  @override
  String get wallpaperAutoRotateSourceLoadError => 'Wallpaper tidak dapat dimuat. Periksa koneksi Anda.';

  @override
  String get wallpaperAutoRotateSourceWotd => 'Wallpaper Hari Ini';

  @override
  String get wallpaperAutoRotateStartError => 'Rotasi wallpaper tidak dapat dimulai.';

  @override
  String get wallpaperAutoRotateStarting => 'Memulai';

  @override
  String get wallpaperAutoRotateStatusLabel => 'Status';

  @override
  String get wallpaperAutoRotateStepsCopied => 'Langkah-langkah disalin.';

  @override
  String get wallpaperAutoRotateStopError => 'Rotasi wallpaper tidak dapat dihentikan.';

  @override
  String get wallpaperAutoRotateTitle => 'Putar otomatis';

  @override
  String get wallpaperAutoRotateTooFewCategory => 'Kategori ini memiliki kurang dari 2 wallpaper. Pilih kategori lain.';

  @override
  String get wallpaperAutoRotateTooFewDownloads => 'Unduh setidaknya 2 wallpaper untuk merotasinya.';

  @override
  String get wallpaperAutoRotateTooFewFavourites => 'Tambahkan setidaknya 2 wallpaper ke favorit untuk merotasinya.';

  @override
  String get wallpaperAutoRotateTooFewHistory => 'Pasang setidaknya 2 wallpaper dari Prism untuk merotasinya.';

  @override
  String get wallpaperAutoRotateTooFewWotd => 'Belum cukup banyak pilihan sebelumnya.';

  @override
  String get wallpaperAutoRotateUnlockError => 'Putar otomatis tidak dapat dibuka. Coba lagi.';

  @override
  String get wallpaperAutoRotateUpdateError => 'Putar otomatis tidak dapat diperbarui.';

  @override
  String get wallpaperBack => 'Kembali';

  @override
  String get wallpaperBlockCreator => 'Blokir kreator';

  @override
  String get wallpaperBlockCreatorNotFound => 'Kreator ini tidak ditemukan. Coba lagi.';

  @override
  String get wallpaperBoostAlready => 'Sudah dipromosikan.';

  @override
  String wallpaperBoostAlreadyUntil(String time) {
    return 'Sudah dipromosikan hingga $time.';
  }

  @override
  String wallpaperBoostConfirmButton(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Promosikan seharga $coinsString koin';
  }

  @override
  String wallpaperBoostConfirmMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Tampilkan wallpaper ini di karusel Beranda dan di urutan teratas Tren selama 24 jam seharga $coinsString koin.';
  }

  @override
  String wallpaperBoostDurationAndCost(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '24 jam di urutan teratas · $coinsString koin';
  }

  @override
  String get wallpaperBoostFailed => 'Wallpaper ini tidak dapat dipromosikan. Coba lagi.';

  @override
  String get wallpaperBoostOnlyApproved =>
      'Hanya wallpaper yang Anda unggah dan telah disetujui yang dapat dipromosikan.';

  @override
  String get wallpaperBoostSlotsTaken => 'Semua slot promosi terisi. Coba lagi nanti.';

  @override
  String wallpaperBoostSlotsTakenUntil(String time) {
    return 'Semua slot promosi terisi. Slot berikutnya tersedia pada $time.';
  }

  @override
  String get wallpaperBoostTitle => 'Promosikan ke Tren';

  @override
  String get wallpaperBoostedSuccess => 'Berhasil dipromosikan. Kini tampil di Beranda dan Tren.';

  @override
  String get wallpaperBoostedTag => 'Dipromosikan';

  @override
  String wallpaperBoostedUntil(String time) {
    return 'Dipromosikan hingga $time';
  }

  @override
  String get wallpaperBrowseWallpapers => 'Jelajahi wallpaper';

  @override
  String wallpaperByCreator(String name) {
    return 'Wallpaper oleh $name';
  }

  @override
  String get wallpaperByPrismCreator => 'Wallpaper oleh kreator Prism';

  @override
  String get wallpaperCategories => 'Kategori';

  @override
  String get wallpaperCategory => 'Kategori';

  @override
  String get wallpaperCategoryFeedEmptyBody => 'Wallpaper baru terus ditambahkan. Silakan mampir lagi nanti.';

  @override
  String get wallpaperCategoryFeedEmptyTitle => 'Belum ada wallpaper di sini';

  @override
  String wallpaperCategoryNamed(String name) {
    return 'Kategori, $name';
  }

  @override
  String get wallpaperChangeNow => 'Ubah sekarang';

  @override
  String get wallpaperCheckBackSoon => 'Silakan periksa kembali nanti.';

  @override
  String get wallpaperCheckBackTomorrow => 'Silakan periksa kembali besok.';

  @override
  String get wallpaperCheckConnection => 'Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get wallpaperClear => 'Hapus';

  @override
  String get wallpaperClearFilters => 'Hapus filter';

  @override
  String get wallpaperClearHistoryAction => 'Hapus riwayat';

  @override
  String get wallpaperClearHistoryBody =>
      'Daftar wallpaper yang Anda pasang akan dihapus. Wallpaper Anda tetap terpasang.';

  @override
  String get wallpaperClearHistoryTitle => 'Hapus riwayat?';

  @override
  String get wallpaperClearSearch => 'Hapus pencarian';

  @override
  String get wallpaperClosePreview => 'Tutup pratinjau';

  @override
  String get wallpaperCollapseDetails => 'Ciutkan detail wallpaper';

  @override
  String get wallpaperCollection => 'Koleksi';

  @override
  String get wallpaperCollectionLoadError => 'Koleksi ini tidak dapat dimuat';

  @override
  String wallpaperCollectionNamed(String name) {
    return 'Koleksi, $name';
  }

  @override
  String wallpaperCollectionPreviewUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Pratinjau dibuka selama 24 jam (-$coinsString koin).';
  }

  @override
  String get wallpaperCollectionRefreshError => 'Tidak dapat memuat ulang. Tarik ke bawah untuk mencoba lagi.';

  @override
  String get wallpaperCollectionsEmptyBody => 'Tarik ke bawah untuk memuat ulang, atau silakan mampir lagi nanti.';

  @override
  String get wallpaperCollectionsEmptyTitle => 'Belum ada koleksi';

  @override
  String get wallpaperCopyAccentHexHint => 'Tekan lama untuk menyalin kode warna heksadesimal';

  @override
  String wallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper',
      zero: 'Tidak ada wallpaper',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDelete => 'Hapus';

  @override
  String get wallpaperDeleteManyDownloadsBody =>
      'Wallpaper akan dihapus dari perangkat ini. Anda dapat mengunduhnya lagi nanti.';

  @override
  String wallpaperDeleteManyDownloadsTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Hapus $countString unduhan?';
  }

  @override
  String get wallpaperDeleteOneDownloadBody =>
      'Wallpaper akan dihapus dari perangkat ini. Anda dapat mengunduhnya lagi nanti.';

  @override
  String get wallpaperDeleteOneDownloadTitle => 'Hapus unduhan ini?';

  @override
  String get wallpaperDepthEditorSubtitle => 'Di editor Layar Kunci, ketuk ••• lalu Efek Kedalaman.';

  @override
  String get wallpaperDepthEffect => 'Efek Kedalaman';

  @override
  String get wallpaperDepthSubjectSubtitle => 'Subjek Anda akan tampil di depan jam.';

  @override
  String get wallpaperDetailColorCodeCopied => 'Kode warna disalin ke papan klip';

  @override
  String get wallpaperDetailNotFound => 'Wallpaper tidak ditemukan';

  @override
  String get wallpaperDiscard => 'Buang';

  @override
  String get wallpaperDismiss => 'Tutup';

  @override
  String get wallpaperDownload => 'Unduh';

  @override
  String wallpaperDownloadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString unduhan', one: '1 unduhan');
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadSortName => 'Nama';

  @override
  String get wallpaperDownloadSortNewest => 'Terbaru';

  @override
  String get wallpaperDownloadSortOldest => 'Terlama';

  @override
  String get wallpaperDownloadWallpaper => 'Unduh wallpaper';

  @override
  String get wallpaperDownloadedWallpaper => 'Wallpaper yang diunduh';

  @override
  String get wallpaperDownloadedWallpaperUnavailable => 'Wallpaper yang diunduh tidak tersedia';

  @override
  String wallpaperDownloadsDeleteError(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString unduhan tidak dapat dihapus.',
      one: '1 unduhan tidak dapat dihapus.',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadsEmptyBody => 'Wallpaper yang Anda unduh tersimpan di sini.';

  @override
  String get wallpaperDownloadsEmptyTitle => 'Belum ada unduhan';

  @override
  String get wallpaperDownloadsLoadError => 'Unduhan Anda tidak dapat dimuat';

  @override
  String get wallpaperDownloadsLoadHelp => 'Periksa akses penyimpanan Anda, lalu coba lagi.';

  @override
  String get wallpaperDownloadsRefreshError => 'Unduhan tidak dapat dimuat ulang. Coba lagi.';

  @override
  String get wallpaperDownloadsShareError => 'Tidak dapat membagikan. Coba lagi.';

  @override
  String get wallpaperDownloadsTitle => 'Unduhan';

  @override
  String get wallpaperEdit => 'Edit';

  @override
  String get wallpaperEditTitle => 'Edit wallpaper';

  @override
  String get wallpaperExpandDetails => 'Perluas detail wallpaper';

  @override
  String get wallpaperFavourite => 'Favorit';

  @override
  String get wallpaperFavouriteAddedToast => 'Ditambahkan ke favorit.';

  @override
  String get wallpaperFavouriteClearAccountMessage => 'Wallpaper akan dihapus dari akun Anda.';

  @override
  String get wallpaperFavouriteClearAll => 'Hapus semua favorit';

  @override
  String get wallpaperFavouriteClearDeviceMessage => 'Wallpaper akan dihapus dari perangkat ini.';

  @override
  String get wallpaperFavouriteClearError => 'Favorit tidak dapat dihapus. Coba lagi.';

  @override
  String wallpaperFavouriteClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Hapus $countString favorit?';
  }

  @override
  String get wallpaperFavouriteClearOneTitle => 'Hapus 1 favorit?';

  @override
  String wallpaperFavouriteClearedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favorit dihapus',
      one: '1 favorit dihapus',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteClearedOne => '1 favorit dihapus';

  @override
  String wallpaperFavouriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favorit',
      one: '1 favorit',
      zero: 'Tidak ada favorit',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteEmptyBody => 'Ketuk ikon hati pada wallpaper untuk menyimpannya di sini.';

  @override
  String get wallpaperFavouriteEmptyTitle => 'Belum ada favorit';

  @override
  String get wallpaperFavouriteExport => 'Ekspor favorit';

  @override
  String get wallpaperFavouriteExportEmpty => 'Belum ada favorit untuk diekspor.';

  @override
  String get wallpaperFavouriteExportError => 'Favorit tidak dapat diekspor. Coba lagi.';

  @override
  String get wallpaperFavouriteGuestPrompt => 'Masuk agar favorit Anda tersedia di semua perangkat';

  @override
  String get wallpaperFavouriteLoadError => 'Favorit Anda tidak dapat dimuat';

  @override
  String get wallpaperFavouriteMoreActions => 'Tindakan lainnya untuk favorit';

  @override
  String get wallpaperFavouriteNoMatch => 'Tidak ada favorit yang cocok';

  @override
  String get wallpaperFavouriteNotSynced => 'Belum disinkronkan';

  @override
  String get wallpaperFavouriteRefreshFallback =>
      'Favorit tidak dapat dimuat ulang. Menampilkan daftar yang tersimpan.';

  @override
  String get wallpaperFavouriteRemove => 'Hapus';

  @override
  String get wallpaperFavouriteRemoveAction => 'Hapus dari favorit';

  @override
  String get wallpaperFavouriteRemoveError => 'Favorit tidak dapat dihapus. Coba lagi.';

  @override
  String wallpaperFavouriteRemovedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favorit dihapus',
      one: '1 favorit dihapus',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteRemovedOne => 'Dihapus dari favorit';

  @override
  String get wallpaperFavouriteRemovedToast => 'Dihapus dari favorit.';

  @override
  String get wallpaperFavouriteRestoreError => 'Favorit tidak dapat dipulihkan.';

  @override
  String get wallpaperFavouriteSearchHint => 'Cari berdasarkan kreator atau kategori';

  @override
  String get wallpaperFavouriteSetUsesFirst => 'Wallpaper yang dipasang adalah pilihan pertama Anda';

  @override
  String get wallpaperFavouriteShareError => 'Tidak dapat membagikan. Coba lagi.';

  @override
  String get wallpaperFavouriteSortOldest => 'Terlama';

  @override
  String get wallpaperFavouriteSortRecentlyAdded => 'Baru ditambahkan';

  @override
  String get wallpaperFavouriteSortSource => 'Sumber';

  @override
  String get wallpaperFavouriteStatus => 'Di daftar favorit Anda';

  @override
  String get wallpaperFavouriteTryDifferent => 'Coba kata pencarian atau sumber lain.';

  @override
  String get wallpaperFavouriteUnavailableLegacy =>
      'Favorit ini berasal dari versi lama dan tidak dapat dibuka. Tekan lama untuk menghapusnya.';

  @override
  String get wallpaperFavouriteWaitingSync => 'Menunggu sinkronisasi';

  @override
  String get wallpaperFavouritesTitle => 'Favorit';

  @override
  String get wallpaperFeedAnnouncement => 'Pengumuman';

  @override
  String get wallpaperFeedCaughtUpBody => 'Tarik ke bawah untuk memuat ulang. Pilihan baru akan muncul di sini.';

  @override
  String get wallpaperFeedCaughtUpTitle => 'Anda sudah melihat semuanya';

  @override
  String get wallpaperFeedClearHistoryError => 'Riwayat tidak dapat dihapus. Coba lagi.';

  @override
  String get wallpaperFeedDiscovery => 'Jelajahi';

  @override
  String get wallpaperFeedEmptyBody =>
      'Ikuti kreator atau pilih minat agar kami dapat menampilkan lebih banyak konten yang Anda sukai.';

  @override
  String get wallpaperFeedEmptyTitle => 'Sesuaikan beranda ini';

  @override
  String get wallpaperFeedFollowingEmptyTitle => 'Ikuti kreator untuk melihat wallpaper terbaru mereka di sini';

  @override
  String get wallpaperFeedFollowingLoadError => 'Feed kreator yang Anda ikuti tidak dapat dimuat';

  @override
  String get wallpaperFeedLatestLoadError => 'Wallpaper terbaru tidak dapat dimuat';

  @override
  String get wallpaperFeedLearnedFromYou => 'Dipersonalisasi untuk Anda';

  @override
  String get wallpaperFeedLearningEmpty => 'Buka, simpan, dan pasang wallpaper untuk menyesuaikan feed Anda.';

  @override
  String get wallpaperFeedLearningHistoryCleared => 'Riwayat personalisasi dihapus';

  @override
  String get wallpaperFeedLoadError => 'Feed Anda tidak dapat dimuat';

  @override
  String get wallpaperFeedLoadMoreError => 'Konten lainnya tidak dapat dimuat. Coba lagi';

  @override
  String get wallpaperFeedMixAdventurous => 'Jelajah';

  @override
  String get wallpaperFeedMixAdventurousDescription => 'Lebih banyak wallpaper di luar selera Anda.';

  @override
  String get wallpaperFeedMixBalanced => 'Seimbang';

  @override
  String get wallpaperFeedMixBalancedDescription => 'Sesuai selera Anda, dengan beberapa kejutan.';

  @override
  String get wallpaperFeedMixFamiliar => 'Akrab';

  @override
  String get wallpaperFeedMixFamiliarDescription => 'Sebagian besar sesuai dengan yang Anda sukai.';

  @override
  String wallpaperFeedPickAtLeast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Pilih setidaknya $countString';
  }

  @override
  String wallpaperFeedPickedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString dipilih';
  }

  @override
  String get wallpaperFeedPopularEmptyTitle => 'Belum ada wallpaper populer';

  @override
  String get wallpaperFeedPopularLoadError => 'Wallpaper populer tidak dapat dimuat';

  @override
  String get wallpaperFeedPullToRefresh => 'Tarik ke bawah untuk memuat ulang.';

  @override
  String get wallpaperFeedRefreshError => 'Feed Anda tidak dapat dimuat ulang.';

  @override
  String get wallpaperFeedSaveError => 'Setelan feed tidak dapat disimpan. Coba lagi.';

  @override
  String get wallpaperFeedSettingsHint => 'Ketuk dua kali untuk membuka setelan feed';

  @override
  String get wallpaperFeedStartingPoints => 'Pilihan awal';

  @override
  String get wallpaperFeedTabFollowing => 'Mengikuti';

  @override
  String get wallpaperFeedTabForYou => 'Untuk Anda';

  @override
  String get wallpaperFeedTabLatest => 'Terbaru';

  @override
  String get wallpaperFeedTabPopular => 'Populer';

  @override
  String get wallpaperFeedTabTrending => 'Tren';

  @override
  String get wallpaperFeedTuneDescription => 'Prism mempelajari wallpaper yang Anda buka, simpan, dan pasang.';

  @override
  String get wallpaperFeedTuneTitle => 'Sesuaikan feed Anda';

  @override
  String get wallpaperFeedUpdating => 'Memperbarui';

  @override
  String get wallpaperFeedWallsLoadError => 'Wallpaper tidak dapat dimuat';

  @override
  String get wallpaperFewerLikeThisConfirmation => 'Anda akan melihat lebih sedikit wallpaper seperti ini.';

  @override
  String get wallpaperFewerLikeThisUndo => 'Urungkan';

  @override
  String get wallpaperFileMovedOrDeleted => 'File mungkin telah dipindahkan atau dihapus.';

  @override
  String wallpaperFilterApplyCost(int coins, int missing) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'Menerapkan filter ini membutuhkan $coinsString koin. Anda kekurangan $missingString koin.';
  }

  @override
  String get wallpaperFilterBlur => 'Buram';

  @override
  String get wallpaperFilterBrightness => 'Kecerahan';

  @override
  String get wallpaperFilterEffectEdge => 'Tepi';

  @override
  String get wallpaperFilterEffectEmboss => 'Relief';

  @override
  String get wallpaperFilterEffectHighPass => 'High Pass';

  @override
  String get wallpaperFilterEffectSharpen => 'Pertajam';

  @override
  String get wallpaperFilterHoldToCompare => 'Tekan dan tahan untuk membandingkan';

  @override
  String get wallpaperFilterHue => 'Corak';

  @override
  String get wallpaperFilterLightness => 'Tingkat terang';

  @override
  String get wallpaperFilterLightnessUnavailable => 'Pengaturan tingkat terang tidak tersedia di perangkat ini.';

  @override
  String get wallpaperFilterNeedCoins => 'Koin diperlukan untuk filter premium';

  @override
  String get wallpaperFilterOriginal => 'Asli';

  @override
  String get wallpaperFilterSaturation => 'Saturasi';

  @override
  String get wallpaperFilterSaveError => 'Wallpaper tidak dapat disimpan. Silakan coba lagi!';

  @override
  String get wallpaperFilterTabAdjustments => 'Penyesuaian';

  @override
  String get wallpaperFilterTabFilters => 'Filter';

  @override
  String wallpaperFilterUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Filter premium dibuka untuk edit ini (-$coinsString koin).';
  }

  @override
  String get wallpaperFitBlur => 'Paskan dengan efek buram';

  @override
  String get wallpaperFitColour => 'Paskan dengan warna';

  @override
  String get wallpaperFitFill => 'Isi layar';

  @override
  String get wallpaperGenericError => 'Terjadi kesalahan!';

  @override
  String get wallpaperGoBack => 'Kembali';

  @override
  String get wallpaperGotItFewerLikeThis => 'Mengerti. Anda akan melihat lebih sedikit wallpaper seperti ini.';

  @override
  String get wallpaperHidePreviewControls => 'Sembunyikan kontrol';

  @override
  String get wallpaperHistoryBothScreens => 'Kedua layar';

  @override
  String get wallpaperHistoryCurrent => 'Saat ini';

  @override
  String get wallpaperHistoryCurrentPrefix => 'Saat ini. ';

  @override
  String get wallpaperHistoryEmptyBody => 'Wallpaper yang Anda pasang akan muncul di sini agar dapat dipasang lagi.';

  @override
  String get wallpaperHistoryEmptyTitle => 'Belum ada wallpaper';

  @override
  String get wallpaperHistoryRemoveAction => 'Hapus dari riwayat';

  @override
  String wallpaperHistoryTileSemantic(String current, String target, String date) {
    return '${current}Pasang lagi. $target, $date';
  }

  @override
  String get wallpaperHistoryTitle => 'Riwayat wallpaper';

  @override
  String get wallpaperHomeAppName => 'Prism';

  @override
  String get wallpaperImageSemanticHint =>
      'Ketuk untuk mengganti warna aksen. Tahan untuk favorit, berbagi, dan reset. Gulir untuk detail.';

  @override
  String get wallpaperPreviousInFeed => 'Wallpaper sebelumnya';

  @override
  String get wallpaperNextInFeed => 'Wallpaper berikutnya';

  @override
  String get wallpaperImageSemanticLabel => 'Wallpaper';

  @override
  String get wallpaperInsufficientCoins => 'Koin tidak cukup. Dapatkan koin di Hadiah.';

  @override
  String wallpaperInterestLearnedLabel(String label, int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Dipelajari: $label, $percentString persen';
  }

  @override
  String wallpaperInterestSelectedLabel(String name, String selection) {
    return 'Minat: $name, $selection';
  }

  @override
  String get wallpaperLandscapeCrop => 'Wallpaper lanskap: bagian samping akan terpotong';

  @override
  String get wallpaperLibraryCollections => 'Koleksi';

  @override
  String get wallpaperLibraryDownloads => 'Unduhan';

  @override
  String get wallpaperLibraryFavourites => 'Favorit';

  @override
  String get wallpaperLibraryHistory => 'Riwayat';

  @override
  String get wallpaperLibraryHistoryBody => 'Wallpaper yang pernah Anda pasang, agar dapat dipasang lagi.';

  @override
  String get wallpaperLibraryHistoryTitle => 'Riwayat wallpaper';

  @override
  String get wallpaperLibraryOpenHistory => 'Buka riwayat';

  @override
  String get wallpaperLibraryTitle => 'Koleksi saya';

  @override
  String get wallpaperLive => 'Wallpaper bergerak';

  @override
  String get wallpaperLiveApplied => 'Wallpaper bergerak berhasil dipasang.';

  @override
  String wallpaperLiveApplyPhotoDescription(String style) {
    return 'Pratinjau $style';
  }

  @override
  String get wallpaperLiveBatterySaver => 'Penghemat baterai';

  @override
  String get wallpaperLiveChooseAnotherVideo => 'Pilih video lain';

  @override
  String get wallpaperLiveChooseVideo => 'Pilih video';

  @override
  String get wallpaperLiveConfirmPreview => 'Konfirmasikan di pratinjau sistem.';

  @override
  String get wallpaperLiveDeviceUnavailable => 'Tidak tersedia di perangkat ini';

  @override
  String get wallpaperLiveErrorGeneric => 'Wallpaper bergerak tidak dapat dipasang. Coba lagi.';

  @override
  String get wallpaperLiveErrorImageTooLarge => 'Gambar ini terlalu besar untuk dijadikan wallpaper bergerak.';

  @override
  String get wallpaperLiveErrorMemory => 'Memori tidak cukup. Tutup aplikasi lain, lalu coba lagi.';

  @override
  String get wallpaperLiveErrorNotAllowed => 'Perangkat atau profil kerja Anda tidak mengizinkan perubahan wallpaper.';

  @override
  String get wallpaperLiveErrorPermission => 'Prism tidak memiliki izin untuk membaca file tersebut.';

  @override
  String get wallpaperLiveErrorPreview => 'Pratinjau sistem tidak dapat dibuka.';

  @override
  String get wallpaperLiveErrorReadFile => 'File tidak dapat dibaca. Coba lagi.';

  @override
  String get wallpaperLiveErrorStyle => 'Perangkat ini tidak dapat menjalankan gaya tersebut. Coba gaya lain.';

  @override
  String get wallpaperLiveErrorTimeout => 'Waktu koneksi habis. Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get wallpaperLiveErrorTooLarge => 'File ini terlalu besar untuk dijadikan wallpaper bergerak.';

  @override
  String get wallpaperLiveErrorVideo => 'Video ini tidak dapat diputar sebagai wallpaper. Coba klip lain.';

  @override
  String wallpaperLiveFps(int fps) {
    final intl.NumberFormat fpsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String fpsString = fpsNumberFormat.format(fps);

    return '$fpsString bingkai per detik';
  }

  @override
  String wallpaperLiveGradientDescription(String style) {
    return 'Pratinjau $style';
  }

  @override
  String wallpaperLiveGradientSwatch(String index, String count) {
    return 'Gradien warna $index dari $count';
  }

  @override
  String get wallpaperLiveKeepPrismOpen => 'Biarkan Prism tetap terbuka, lalu coba lagi.';

  @override
  String get wallpaperLiveModeGradients => 'Gradien';

  @override
  String get wallpaperLiveModePhoto => 'Jadikan bergerak';

  @override
  String get wallpaperLiveModeVideo => 'Video';

  @override
  String get wallpaperLiveNoVideo => 'Belum ada video yang dipilih';

  @override
  String get wallpaperLivePreviewInstruction => 'Android akan membuka pratinjau. Ketuk Pasang wallpaper di sana.';

  @override
  String get wallpaperLiveProStyleRequired => 'Gaya ini termasuk dalam Prism Pro.';

  @override
  String get wallpaperLiveSetAction => 'Pasang wallpaper bergerak';

  @override
  String get wallpaperLiveShaderUnsupported =>
      'Perangkat ini tidak mendukung wallpaper bergerak berbasis shader. Coba Video.';

  @override
  String get wallpaperLiveStyleAurora => 'Aurora';

  @override
  String get wallpaperLiveStyleAuroraDescription => 'Pita warna yang lembut.';

  @override
  String get wallpaperLiveStyleBreathe => 'Bernapas';

  @override
  String get wallpaperLiveStyleBreatheDescription => 'Denyut lembut yang mengembang dan menyusut.';

  @override
  String get wallpaperLiveStyleDrift => 'Mengalir';

  @override
  String get wallpaperLiveStyleDriftDescription => 'Geser dan perbesar perlahan, mengikuti usapan di layar utama.';

  @override
  String get wallpaperLiveStyleMesh => 'Jaring';

  @override
  String get wallpaperLiveStyleMeshDescription => 'Perpaduan warna yang berubah perlahan.';

  @override
  String get wallpaperLiveStylePlasma => 'Plasma';

  @override
  String get wallpaperLiveStylePlasmaDescription => 'Warna yang mengalir dengan lembut.';

  @override
  String get wallpaperLiveStyleRipple => 'Riak';

  @override
  String get wallpaperLiveStyleRippleDescription => 'Lingkaran air yang menyebar dari sentuhan Anda.';

  @override
  String get wallpaperLiveStyleShimmer => 'Kilau';

  @override
  String get wallpaperLiveStyleShimmerDescription => 'Sapuan cahaya yang lembut.';

  @override
  String get wallpaperLiveStyleStarfield => 'Hamparan bintang';

  @override
  String get wallpaperLiveStyleStarfieldDescription => 'Bintang berkelap-kelip di atas latar hitam pekat.';

  @override
  String wallpaperLiveStyleUnlocked(String style) {
    return '$style terbuka selama 7 hari.';
  }

  @override
  String get wallpaperLiveStyleWaves => 'Ombak';

  @override
  String get wallpaperLiveStyleWavesDescription => 'Lapisan ombak yang bergulung.';

  @override
  String get wallpaperLiveTextureDownloadFailed =>
      'Wallpaper tidak dapat diunduh. Periksa koneksi Anda, lalu coba lagi.';

  @override
  String get wallpaperLiveTexturePrepareFailed => 'Wallpaper tidak dapat disiapkan.';

  @override
  String get wallpaperLiveTextureTooDetailed => 'Wallpaper ini terlalu detail untuk dianimasikan.';

  @override
  String get wallpaperLiveTitle => 'Wallpaper bergerak';

  @override
  String get wallpaperLiveUnavailableBody =>
      'Fitur ini memerlukan ponsel Android yang mendukung wallpaper bergerak OpenGL.';

  @override
  String get wallpaperLiveUnavailableTitle => 'Wallpaper bergerak tidak tersedia';

  @override
  String wallpaperLiveUnlockCoins(String coins) {
    return 'Buka · $coins koin';
  }

  @override
  String wallpaperLiveUnlockError(String style) {
    return '$style tidak dapat dibuka. Coba lagi.';
  }

  @override
  String wallpaperLiveUnlockStyleAction(String style, String coins) {
    return 'Buka $style selama 7 hari · $coins koin';
  }

  @override
  String get wallpaperLiveUnlockStyleBody =>
      'Buka selama 7 hari dengan koin, atau dapatkan Prism Pro untuk menggunakan semua gaya.';

  @override
  String wallpaperLiveUnlockStyleTitle(String style) {
    return '$style adalah gaya berbayar';
  }

  @override
  String get wallpaperLiveUnsupported => 'Perangkat ini tidak mendukung wallpaper bergerak.';

  @override
  String get wallpaperLiveVideoChosen => 'Video yang dipilih';

  @override
  String get wallpaperLiveVideoDescription => 'Diputar di layar utama tanpa suara. Maksimal 256 MB.';

  @override
  String get wallpaperLiveVideoReadFailed => 'Video tidak dapat dibaca. Pilih lagi.';

  @override
  String get wallpaperLiveVideoTooLarge => 'Ukuran video ini lebih dari 256 MB. Pilih klip yang lebih pendek.';

  @override
  String get wallpaperLiveVideoUnsupported => 'Perangkat ini tidak mendukung video sebagai wallpaper.';

  @override
  String get wallpaperLoadingImage => 'Memuat gambar';

  @override
  String get wallpaperLoadingWallpaper => 'Memuat wallpaper';

  @override
  String get wallpaperLowResolutionScreen => 'Resolusi terlalu rendah untuk layar Anda';

  @override
  String get wallpaperMakeItLive => 'Jadikan wallpaper bergerak';

  @override
  String get wallpaperMatchSystemColour => 'Sesuaikan dengan warna sistem';

  @override
  String get wallpaperMoreLikeThis => 'Lainnya seperti ini';

  @override
  String get wallpaperNavCollections => 'Koleksi';

  @override
  String get wallpaperNavHome => 'Beranda';

  @override
  String get wallpaperNavRewards => 'Hadiah';

  @override
  String get wallpaperNavSearch => 'Cari';

  @override
  String get wallpaperNew => 'Baru';

  @override
  String get wallpaperNotNow => 'Nanti saja';

  @override
  String get wallpaperNotSelected => 'belum dipilih';

  @override
  String get wallpaperNotificationPromptBody =>
      'Satu wallpaper pilihan setiap pagi, serta pengingat rangkaian harian. Tanpa spam.';

  @override
  String get wallpaperNotificationPromptTitle => 'Dapatkan Wallpaper Hari Ini';

  @override
  String get wallpaperOffline => 'Luring';

  @override
  String wallpaperOldVersionBody(String version) {
    return 'Versi $version tidak lagi didukung. Perbarui Prism untuk terus menggunakannya.';
  }

  @override
  String get wallpaperOldVersionTitle => 'Saatnya memperbarui';

  @override
  String get wallpaperOnPrism => 'Wallpaper di Prism';

  @override
  String get wallpaperOpenError => 'Wallpaper ini tidak dapat dimuat';

  @override
  String get wallpaperOpenFileError => 'Wallpaper ini tidak dapat dibuka';

  @override
  String get wallpaperOpenNotifications => 'Buka notifikasi';

  @override
  String get wallpaperOtherSource => 'Lainnya';

  @override
  String get wallpaperPastPicksEmpty => 'Belum ada pilihan sebelumnya';

  @override
  String get wallpaperPastPicksLoadError => 'Pilihan sebelumnya tidak dapat dimuat';

  @override
  String get wallpaperPastPicksTitle => 'Pilihan sebelumnya';

  @override
  String get wallpaperPlacementDim => 'Redupkan';

  @override
  String get wallpaperPositionApproximate => 'Perkiraan. Tampilan mungkin berbeda di peluncur Anda.';

  @override
  String get wallpaperPremium => 'Premium';

  @override
  String get wallpaperPremiumCollection => 'Koleksi premium';

  @override
  String wallpaperPremiumCollectionNamed(String name) {
    return 'Koleksi premium, $name';
  }

  @override
  String get wallpaperPreviewHome => 'Layar utama';

  @override
  String get wallpaperPreviewIconClear => 'Bening';

  @override
  String get wallpaperPreviewIconDark => 'Gelap';

  @override
  String get wallpaperPreviewIconDefault => 'Default';

  @override
  String get wallpaperPreviewIconStyle => 'Gaya ikon';

  @override
  String get wallpaperPreviewIconThemed => 'Bertema';

  @override
  String get wallpaperPreviewIconTinted => 'Berwarna';

  @override
  String get wallpaperPreviewLock => 'Layar kunci';

  @override
  String get wallpaperPreviewOnScreen => 'Pratinjau di layar Anda';

  @override
  String get wallpaperPreviewSetBoth => 'Pasang di kedua layar';

  @override
  String get wallpaperPreviewSetHome => 'Pasang di layar utama';

  @override
  String get wallpaperPreviewSetLock => 'Pasang di layar kunci';

  @override
  String wallpaperPreviewUnlock24Hours(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Buka selama 24 jam (-$costString)';
  }

  @override
  String wallpaperPreviewUnlockCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Pratinjau koleksi premium ini selama 24 jam seharga $costString koin.';
  }

  @override
  String wallpaperPreviewUnlockCostMissing(int cost, int missing) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'Pratinjau 24 jam membutuhkan $costString koin. Anda kekurangan $missingString koin.';
  }

  @override
  String wallpaperPreviewWatchAdUnlock(String adOption) {
    return '$adOption dan buka';
  }

  @override
  String get wallpaperProcessing => 'Memproses wallpaper';

  @override
  String get wallpaperProfileOpenError => 'Profil tidak dapat dibuka';

  @override
  String get wallpaperQuickAddAction => 'Tambahkan ke Setelan Cepat';

  @override
  String get wallpaperQuickFavouriteDescription =>
      'Memasang wallpaper acak dari favorit Anda. Masuk dan tambahkan beberapa wallpaper ke favorit terlebih dahulu.';

  @override
  String get wallpaperQuickFavouriteTitle => 'Tile favorit acak';

  @override
  String get wallpaperQuickHowToTitle => 'Cara menambahkan tile';

  @override
  String get wallpaperQuickShuffleDescription =>
      'Ketuk tile untuk memasang wallpaper acak dari kategori yang Anda pilih.';

  @override
  String get wallpaperQuickShuffleTitle => 'Tile acak wallpaper';

  @override
  String get wallpaperQuickStepEdit => 'Ketuk ikon pensil atau ikon edit.';

  @override
  String get wallpaperQuickStepFindPrism => 'Cari tile Prism, lalu seret ke tile aktif.';

  @override
  String get wallpaperQuickStepShade => 'Geser bilah notifikasi ke bawah dua kali.';

  @override
  String get wallpaperQuickTargetBoth => 'Keduanya';

  @override
  String get wallpaperQuickTargetHome => 'Layar utama';

  @override
  String get wallpaperQuickTargetLock => 'Layar kunci';

  @override
  String get wallpaperQuickTileAddError =>
      'Tile tidak dapat ditambahkan. Tambahkan secara manual dari layar edit Setelan Cepat.';

  @override
  String get wallpaperQuickTileAdded => 'Tile ditambahkan ke Setelan Cepat.';

  @override
  String get wallpaperQuickTileAlreadyAdded => 'Tile ini sudah ada di Setelan Cepat.';

  @override
  String get wallpaperQuickTileNotAdded => 'Tile belum ditambahkan. Anda dapat menambahkannya kapan saja.';

  @override
  String get wallpaperQuickTileSaveError => 'Setelan tile cepat tidak dapat disimpan';

  @override
  String get wallpaperQuickTilesLoadError => 'Tile cepat Anda tidak dapat dimuat';

  @override
  String get wallpaperQuickTilesTitle => 'Tile cepat';

  @override
  String get wallpaperQuickWotdDescription =>
      'Memasang Wallpaper Hari Ini. Buka Prism sekali sehari untuk menyimpan pilihan terbaru.';

  @override
  String get wallpaperQuickWotdTitle => 'Pintasan Wallpaper Hari Ini';

  @override
  String get wallpaperRecentlySet => 'Baru dipasang';

  @override
  String get wallpaperRefresh => 'Muat ulang';

  @override
  String get wallpaperRemovedFromHistory => 'Dihapus dari riwayat';

  @override
  String get wallpaperReport => 'Laporkan';

  @override
  String get wallpaperReset => 'Atur ulang';

  @override
  String get wallpaperSave => 'Simpan';

  @override
  String get wallpaperSaveToPhotos => 'Simpan ke Foto';

  @override
  String get wallpaperSavedOnDevice => 'Disimpan di perangkat ini';

  @override
  String wallpaperSearchTag(String tag) {
    return 'Cari $tag';
  }

  @override
  String get wallpaperSeePrismPro => 'Lihat Prism Pro';

  @override
  String get wallpaperSelected => 'dipilih';

  @override
  String get wallpaperServerUnavailable => 'Tidak dapat terhubung ke server';

  @override
  String get wallpaperSessionEnded => 'Sesi Anda telah berakhir. Masuk lagi.';

  @override
  String get wallpaperSet => 'Pasang';

  @override
  String get wallpaperSetAgain => 'Pasang wallpaper ini lagi';

  @override
  String get wallpaperSetAsWallpaper => 'Jadikan wallpaper';

  @override
  String wallpaperSetCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dipasang $countString kali',
      one: 'Dipasang sekali',
    );
    return '$_temp0';
  }

  @override
  String get setScreenTargetHome => 'Layar utama';

  @override
  String get setScreenTargetLock => 'Layar kunci';

  @override
  String get setScreenTargetBoth => 'Keduanya';

  @override
  String get setScreenTargetGroup => 'Pasang di mana';

  @override
  String get setScreenRemember => 'Ingat pilihan ini';

  @override
  String get setScreenRememberHint => 'Pasang melewati layar ini lain kali. Tahan Pasang untuk kembali.';

  @override
  String get setScreenAdjust => 'Sesuaikan';

  @override
  String get setScreenMore => 'Lainnya';

  @override
  String get setScreenPairLock => 'Pakai wallpaper lain untuk layar kunci';

  @override
  String get setScreenOpenSystemEditor => 'Buka editor sistem';

  @override
  String get setScreenClose => 'Tutup';

  @override
  String get wallpaperShare => 'Bagikan';

  @override
  String get wallpaperShareLink => 'Bagikan tautan';

  @override
  String get wallpaperShortcutsAddActionsSteps =>
      'Tambahkan tindakan \"Dapatkan Wallpaper Prism\". Lalu tambahkan tindakan \"Pasang Wallpaper\".';

  @override
  String get wallpaperShortcutsBody =>
      'Gunakan Pintasan untuk memasang wallpaper sesuai jadwal atau pemicu. Siapkan sumber di bawah sebelum menjalankannya.';

  @override
  String get wallpaperShortcutsChoosePrismData => 'Pilih data yang dikirim Prism';

  @override
  String get wallpaperShortcutsChooseTriggerSteps =>
      'Di editor pintasan, buka Automasi jika perlu. Pilih dan atur pemicu, seperti Waktu, membuka app, atau menghubungkan pengisi daya.';

  @override
  String get wallpaperShortcutsDisableConfirmationSteps =>
      'Tinjau opsi menjalankan yang ditampilkan dan simpan pintasan atau automasi. Jika \"Tanya Sebelum Menjalankan\" muncul, nonaktifkan agar berjalan otomatis.';

  @override
  String get wallpaperShortcutsHeadline => 'Ubah wallpaper secara otomatis';

  @override
  String get wallpaperShortcutsOpenAction => 'Buka Pintasan';

  @override
  String get wallpaperShortcutsOpenAutomationSteps =>
      'Buka Pintasan. Jika ada tab Automasi, ketuk tab itu, lalu Automasi Baru. Jika tidak, ketuk Tambah (+), lalu Edit jika ditampilkan.';

  @override
  String get wallpaperShortcutsOpenError => 'Pintasan tidak dapat dibuka. Buka app secara manual.';

  @override
  String get wallpaperShortcutsSourceFavourite => 'Favorit acak';

  @override
  String get wallpaperShortcutsSourceFavouriteDescription =>
      'Favorit acak yang tersedia untuk Pintasan. Sukai wallpaper di Prism terlebih dahulu. Beberapa wallpaper terlindungi mungkin tidak tersedia. Pilihan terakhir dihindari jika ada favorit lain yang tersedia.';

  @override
  String get wallpaperShortcutsSourceWotd => 'Wallpaper Hari Ini';

  @override
  String get wallpaperShortcutsSourceWotdDescription =>
      'Pilihan Prism hari ini. Unduh gambar asli hari ini di Prism terlebih dahulu. Saat pilihan harian berubah, unduh gambar asli yang baru sebelum menjalankan sumber ini.';

  @override
  String get wallpaperShortcutsSteps => 'Langkah-langkah';

  @override
  String get wallpaperShortcutsTitle => 'Ubah secara otomatis';

  @override
  String get wallpaperShowLessLikeThis => 'Tampilkan lebih sedikit seperti ini';

  @override
  String get wallpaperShowPreviewControls => 'Tampilkan kontrol';

  @override
  String get wallpaperSignIn => 'Masuk';

  @override
  String get wallpaperSignInForPremiumFilters => 'Masuk untuk menggunakan filter premium dengan koin.';

  @override
  String get wallpaperSort => 'Urutkan';

  @override
  String get wallpaperSortDownloads => 'Urutkan unduhan';

  @override
  String get wallpaperStartupFailed => 'Prism tidak dapat dimulai';

  @override
  String get wallpaperThemeDarkAccent => 'Warna Aksen Gelap';

  @override
  String get wallpaperThemeDarkThemes => 'Tema Gelap';

  @override
  String get wallpaperUseAsAppAccent => 'Gunakan sebagai aksen aplikasi';

  @override
  String get wallpaperAppAccentUpdated => 'Aksen aplikasi diperbarui';

  @override
  String get wallpaperThemeLightAccent => 'Warna Aksen Terang';

  @override
  String get wallpaperThemeLightThemes => 'Tema Terang';

  @override
  String get wallpaperThemeModeDark => 'Gelap';

  @override
  String get wallpaperThemeModeLight => 'Terang';

  @override
  String get wallpaperThemeModeSystem => 'Sistem (terang/gelap)';

  @override
  String get wallpaperThemePreference => 'Preferensi tema';

  @override
  String get wallpaperThemePreferenceDescription =>
      'Pilih tema yang Anda sukai. Mode sistem beralih otomatis antara tema terang dan gelap mengikuti setelan perangkat.';

  @override
  String get wallpaperThemeTitle => 'Tema';

  @override
  String get wallpaperTitle => 'Judul';

  @override
  String get wallpaperTrendingEmptyTitle => 'Belum ada yang sedang tren';

  @override
  String get wallpaperTrendingLoadError => 'Wallpaper tren tidak dapat dimuat';

  @override
  String get wallpaperTryAgain => 'Coba lagi';

  @override
  String get wallpaperTurnOff => 'Nonaktifkan';

  @override
  String get wallpaperTurnOnNotifications => 'Aktifkan notifikasi';

  @override
  String get wallpaperUnavailable => 'Tidak tersedia';

  @override
  String get wallpaperUnfavourite => 'Hapus dari favorit';

  @override
  String get wallpaperUnreadItems => 'Memiliki item yang belum dibaca';

  @override
  String get wallpaperUpdatePrism => 'Perbarui Prism';

  @override
  String get wallpaperUploadAction => 'Unggah';

  @override
  String get wallpaperUploadAddTag => 'Tambahkan tag';

  @override
  String get wallpaperUploadAddTagHint => 'Tambahkan tag, lalu ketuk Selesai';

  @override
  String get wallpaperUploadAiSubtitle => 'Jelaskan suasana untuk membuat wallpaper ponsel';

  @override
  String get wallpaperUploadApprovalInfo =>
      'Wallpaper Anda akan tampil di komunitas setelah disetujui. Pantau statusnya di Unggahan Anda.';

  @override
  String wallpaperUploadBatchPosition(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Wallpaper $positionString dari $totalString';
  }

  @override
  String wallpaperUploadBatchSubmitted(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label. $countString dikirim.';
  }

  @override
  String wallpaperUploadBatchSummaryNotSent(String submitted, int notSent) {
    final intl.NumberFormat notSentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String notSentString = notSentNumberFormat.format(notSent);

    return '$submitted. $notSentString belum dikirim.';
  }

  @override
  String wallpaperUploadBatchSummarySubmitted(int submittedCount, int total) {
    final intl.NumberFormat submittedCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String submittedCountString = submittedCountNumberFormat.format(submittedCount);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$submittedCountString dari $totalString wallpaper dikirim';
  }

  @override
  String get wallpaperUploadBrightness => 'Kecerahan';

  @override
  String get wallpaperUploadCheckReviewStatus => 'Periksa status peninjauan';

  @override
  String get wallpaperUploadChooseAnotherImage => 'Pilih gambar lain';

  @override
  String get wallpaperUploadContinueDraft => 'Lanjutkan mengedit wallpaper yang tersimpan';

  @override
  String get wallpaperUploadContrast => 'Kontras';

  @override
  String get wallpaperUploadCreateTitle => 'Buat';

  @override
  String get wallpaperUploadDeleteConfirmTitle => 'Hapus wallpaper ini?';

  @override
  String get wallpaperUploadDeleteError => 'Tidak dapat menghapus. Coba lagi.';

  @override
  String get wallpaperUploadDeletePermissionError =>
      'Tidak dapat menghapus. Masuk dengan akun yang digunakan untuk mengunggah, lalu coba lagi.';

  @override
  String get wallpaperUploadDeleteWallpaper => 'Hapus wallpaper';

  @override
  String get wallpaperUploadDeleted => 'Wallpaper dihapus.';

  @override
  String get wallpaperUploadDetailsOptional => 'Detail (opsional)';

  @override
  String get wallpaperUploadDiscardBody =>
      'File yang diunggah akan dihapus. Gambar yang Anda pilih akan tetap tersimpan di perangkat.';

  @override
  String get wallpaperUploadDiscardEditsBody => 'Perubahan Anda akan hilang.';

  @override
  String get wallpaperUploadDiscardEditsTitle => 'Buang perubahan?';

  @override
  String get wallpaperUploadDiscardError => 'Unggahan ini tidak dapat dibuang. Coba lagi.';

  @override
  String get wallpaperUploadDiscardTitle => 'Buang unggahan ini?';

  @override
  String get wallpaperUploadDownloadError => 'Tidak dapat mengunduh. Coba lagi.';

  @override
  String get wallpaperUploadDownloadStarting => 'Memulai unduhan';

  @override
  String get wallpaperUploadDraftSaveError => 'Draf ini tidak dapat disimpan. Coba lagi.';

  @override
  String wallpaperUploadEditBatch(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Edit wallpaper $positionString dari $totalString';
  }

  @override
  String get wallpaperUploadEditSaveError => 'Perubahan Anda tidak dapat disimpan. Coba lagi.';

  @override
  String get wallpaperUploadFileSize => 'Ukuran';

  @override
  String get wallpaperUploadFilesCheckActive => 'Mengunggah wallpaper dan pratinjaunya';

  @override
  String get wallpaperUploadFilesCheckDone => 'Wallpaper dan pratinjau berhasil diunggah';

  @override
  String get wallpaperUploadFilesCheckPending => 'Unggah wallpaper dan pratinjaunya';

  @override
  String get wallpaperUploadFilesRemoveError => 'File yang diunggah tidak dapat dihapus. Coba lagi.';

  @override
  String get wallpaperUploadFlip => 'Balik';

  @override
  String wallpaperUploadFreeQuotaMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Pengguna gratis dapat mengunggah $countString wallpaper per minggu.';
  }

  @override
  String get wallpaperUploadFromGallery => 'Dari galeri Anda';

  @override
  String get wallpaperUploadFullImageError => 'Gambar penuh tidak dapat dimuat.';

  @override
  String get wallpaperUploadInReview => 'Sedang ditinjau';

  @override
  String get wallpaperUploadKeepDraft => 'Simpan draf';

  @override
  String get wallpaperUploadLeaveBody =>
      'Simpan draf untuk melanjutkan nanti, atau buang draf dan hapus file yang diunggah.';

  @override
  String get wallpaperUploadLeaveTitle => 'Keluar dari unggahan ini?';

  @override
  String wallpaperUploadMaxTagsReached(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Anda telah menambahkan $countString tag';
  }

  @override
  String get wallpaperUploadOriginalContentGuideline =>
      'Unggah hanya wallpaper orisinal berkualitas tinggi. Jangan unggah konten dari aplikasi lain.';

  @override
  String get wallpaperUploadPrepareCheckActive => 'Menyiapkan gambar dan pratinjau berukuran lebih kecil';

  @override
  String get wallpaperUploadPrepareCheckDone => 'Gambar dan pratinjau siap';

  @override
  String get wallpaperUploadPrepareCheckPending => 'Siapkan gambar dan pratinjau berukuran lebih kecil';

  @override
  String get wallpaperUploadPrepareError => 'Gambar ini tidak dapat disiapkan. Coba lagi atau pilih gambar lain.';

  @override
  String get wallpaperUploadQualityLandscape =>
      'Gambar ini melebar. Wallpaper ponsel paling cocok menggunakan orientasi potret.';

  @override
  String wallpaperUploadQualityLowResolution(int width, int height, int recommendedShortSide) {
    final intl.NumberFormat widthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String widthString = widthNumberFormat.format(width);
    final intl.NumberFormat recommendedShortSideNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String recommendedShortSideString = recommendedShortSideNumberFormat.format(recommendedShortSide);

    return 'Resolusi gambar ini ${widthString}x$height. Tampilannya mungkin buram di ponsel. Sisi pendek sebaiknya berukuran $recommendedShortSideString px.';
  }

  @override
  String get wallpaperUploadQuotaCleanupFailed =>
      'Batas unggahan tercapai, tetapi file yang diunggah tidak dapat dihapus. Ketuk Kembali untuk mencoba menghapusnya lagi.';

  @override
  String get wallpaperUploadQuotaReached => 'Batas unggahan wallpaper gratis minggu ini telah tercapai.';

  @override
  String wallpaperUploadQuotaRemaining(int remaining, int total) {
    final intl.NumberFormat remainingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Sisa $remainingString dari $totalString unggahan gratis minggu ini';
  }

  @override
  String get wallpaperUploadRejected => 'Ditolak';

  @override
  String get wallpaperUploadRejectedSectionError => 'Kiriman Anda yang ditolak tidak dapat dimuat.';

  @override
  String get wallpaperUploadRejectionFallback =>
      'Tidak ada alasan khusus yang diberikan. Periksa detail wallpaper, lalu unggah lagi.';

  @override
  String get wallpaperUploadRejectionTitle => 'Alasan penolakan';

  @override
  String wallpaperUploadRemoveTag(String tag) {
    return 'Hapus tag $tag';
  }

  @override
  String get wallpaperUploadResetAdjustments => 'Atur ulang penyesuaian';

  @override
  String get wallpaperUploadResolution => 'Resolusi';

  @override
  String get wallpaperUploadResumeDraft => 'Lanjutkan draf unggahan';

  @override
  String get wallpaperUploadRetrySubmit => 'Coba kirim lagi';

  @override
  String get wallpaperUploadReviewCheckActive => 'Menyimpan kiriman Anda untuk ditinjau';

  @override
  String get wallpaperUploadReviewCheckDone => 'Dikirim untuk ditinjau';

  @override
  String get wallpaperUploadReviewCheckPending => 'Moderator akan meninjau sebelum konten tampil di Prism';

  @override
  String get wallpaperUploadReviewEmptyBody => 'Status peninjauan wallpaper yang Anda unggah akan muncul di sini.';

  @override
  String get wallpaperUploadReviewEmptyTitle => 'Belum ada apa pun di sini';

  @override
  String get wallpaperUploadReviewLoadError => 'Unggahan Anda tidak dapat dimuat';

  @override
  String get wallpaperUploadReviewSectionError => 'Kiriman Anda tidak dapat dimuat.';

  @override
  String get wallpaperUploadRotateLeft => 'Putar ke kiri';

  @override
  String get wallpaperUploadRotateRight => 'Putar ke kanan';

  @override
  String get wallpaperUploadSaturation => 'Saturasi';

  @override
  String get wallpaperUploadSavedToPictures => 'Wallpaper disimpan ke Pictures/Prism';

  @override
  String get wallpaperUploadSkip => 'Lewati wallpaper ini';

  @override
  String get wallpaperUploadStagePrepareFailed => 'Gambar tidak dapat disiapkan';

  @override
  String get wallpaperUploadStagePreparing => 'Menyiapkan wallpaper';

  @override
  String get wallpaperUploadStageQuotaReached => 'Batas unggahan tercapai';

  @override
  String get wallpaperUploadStageReady => 'Siap dikirim';

  @override
  String get wallpaperUploadStageSubmissionFailed => 'Pengiriman tidak selesai';

  @override
  String get wallpaperUploadStageSubmitting => 'Mengirim wallpaper';

  @override
  String get wallpaperUploadStageUploadFailed => 'Pengunggahan tidak selesai';

  @override
  String get wallpaperUploadStageUploading => 'Mengunggah wallpaper';

  @override
  String get wallpaperUploadSubmissionUnconfirmed =>
      'Pengiriman tidak dapat dikonfirmasi. Periksa status peninjauan sebelum mencoba lagi.';

  @override
  String get wallpaperUploadTags => 'Tag';

  @override
  String wallpaperUploadTagsHelp(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Maksimal $countString. Tag membantu orang menemukan wallpaper Anda.';
  }

  @override
  String get wallpaperUploadTitle => 'Unggah wallpaper';

  @override
  String get wallpaperUploadTitleHint => 'Beri nama wallpaper Anda';

  @override
  String get wallpaperUploadViewWallpaper => 'Lihat wallpaper';

  @override
  String get wallpaperUploadYourUploads => 'Unggahan Anda';

  @override
  String get wallpaperUsePhoneAccent => 'Gunakan warna aksen ponsel Anda';

  @override
  String get wallpaperThemeMaterialYouNote => 'Material You mengambil warna dari wallpaper Anda.';

  @override
  String wallpaperViewCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString kali dilihat',
      one: '1 kali dilihat',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperViewCountUnavailable => 'Jumlah tayangan tidak tersedia';

  @override
  String wallpaperWotdByPhotographer(String name) {
    return 'Wallpaper Hari Ini oleh $name';
  }

  @override
  String get economyAiPromptSceneAnime1 => 'kucing tidur di peron kereta yang diterpa matahari';

  @override
  String get economyAiPromptSceneAnime2 => 'awan musim panas menjulang di atas sawah';

  @override
  String get economyAiPromptSceneAnime3 => 'warung ramen bercahaya di gang belakang yang hujan';

  @override
  String get economyAiPromptSceneAnime4 => 'gerbang kuil di puncak bukit di atas lautan awan';

  @override
  String get economyAiPromptSceneAnime5 => 'kembang api di atas sungai di festival musim panas';

  @override
  String get economyAiPromptSceneAnime6 => 'kelas sunyi dengan kelopak bunga berterbangan';

  @override
  String get economyAiPromptSceneAnime7 => 'jalan tepi laut dengan halte sendirian saat senja';

  @override
  String get economyAiPromptSceneAnime8 => 'paus langit melayang di atas kota yang terlelap';

  @override
  String get economyAiPromptSceneMinimal1 => 'satu perahu kertas di atas air tenang yang pucat';

  @override
  String get economyAiPromptSceneMinimal2 => 'satu lengkung cahaya di atas dataran kosong';

  @override
  String get economyAiPromptSceneMinimal3 => 'pohon sendirian di lereng salju yang landai';

  @override
  String get economyAiPromptSceneMinimal4 => 'dua lingkaran bertumpuk di atas butiran halus';

  @override
  String get economyAiPromptSceneMinimal5 => 'garis cakrawala tipis memisahkan laut dan langit';

  @override
  String get economyAiPromptSceneMinimal6 => 'sehelai bulu jatuh melintasi ruang kosong';

  @override
  String get economyAiPromptSceneMinimal7 => 'tumpukan kerikil licin di latar yang pucat';

  @override
  String get economyAiPromptSceneMinimal8 => 'bayangan sabit di dinding plester yang lembut';

  @override
  String get economyAiPromptSceneCyberpunk1 => 'kedai mi basah hujan di bawah cahaya neon';

  @override
  String get economyAiPromptSceneCyberpunk2 => 'kereta melayang menyusuri menara-menara raksasa';

  @override
  String get economyAiPromptSceneCyberpunk3 => 'android sendirian di atap gedung saat hujan';

  @override
  String get economyAiPromptSceneCyberpunk4 => 'jalan tol data bercahaya menuju kota raksasa';

  @override
  String get economyAiPromptSceneCyberpunk5 => 'pasar malam di bawah kusutnya kabel';

  @override
  String get economyAiPromptSceneCyberpunk6 => 'motor krom terparkir di lorong neon';

  @override
  String get economyAiPromptSceneCyberpunk7 => 'bulan hologram terbit di atas menara kota';

  @override
  String get economyAiPromptSceneCyberpunk8 => 'jalan tergenang yang memantulkan dinding layar';

  @override
  String get economyAiPromptSceneWatercolor1 => 'ladang lavender memudar ke dalam kabut pagi';

  @override
  String get economyAiPromptSceneWatercolor2 => 'desa nelayan mungil di tepi pelabuhan yang tenang';

  @override
  String get economyAiPromptSceneWatercolor3 => 'bunga poppy liar bergoyang di tepi jalan desa';

  @override
  String get economyAiPromptSceneWatercolor4 => 'balon udara di atas perbukitan hijau yang lembut';

  @override
  String get economyAiPromptSceneWatercolor5 => 'bangau berdiri di kolam penuh alang-alang';

  @override
  String get economyAiPromptSceneWatercolor6 => 'jalan kota berhujan dengan lampu yang buram';

  @override
  String get economyAiPromptSceneWatercolor7 => 'cangkir teh mengepul di samping jendela terbuka';

  @override
  String get economyAiPromptSceneWatercolor8 => 'pinus bersalju di tepi anak sungai beku berkelok';

  @override
  String get economyAiPromptSceneMeshGradient1 => 'bercak warna lembut yang saling melebur';

  @override
  String get economyAiPromptSceneMeshGradient2 => 'gelombang gradasi sutra yang melipat dirinya';

  @override
  String get economyAiPromptSceneMeshGradient3 => 'bola cahaya berpendar menyatu di latar beledu';

  @override
  String get economyAiPromptSceneMeshGradient4 => 'gradasi ala aurora menyapu ke atas';

  @override
  String get economyAiPromptSceneMeshGradient5 => 'genangan warna cair dengan butiran halus';

  @override
  String get economyAiPromptSceneMeshGradient6 => 'gradasi hangat ke dingin dengan noise lembut';

  @override
  String get economyAiPromptSceneMeshGradient7 => 'kelopak gradasi tembus pandang yang bertumpuk';

  @override
  String get economyAiPromptSceneMeshGradient8 => 'senja buram dari pita warna yang mengalir';

  @override
  String get economyAiPromptSceneAbstract1 => 'pecahan kaca saling mengait menangkap cahaya';

  @override
  String get economyAiPromptSceneAbstract2 => 'awan tinta mengalir melayang di dalam air';

  @override
  String get economyAiPromptSceneAbstract3 => 'spiral pita terlipat yang bergerak';

  @override
  String get economyAiPromptSceneAbstract4 => 'marmer pecah dengan urat emas';

  @override
  String get economyAiPromptSceneAbstract5 => 'garis topografi beriak berlapis-lapis';

  @override
  String get economyAiPromptSceneAbstract6 => 'bola-bola melayang menjatuhkan bayangan panjang';

  @override
  String get economyAiPromptSceneAbstract7 => 'jejak asap melengkung menjadi pusaran';

  @override
  String get economyAiPromptSceneAbstract8 => 'hamparan kubus lembut naik bergelombang';

  @override
  String get economyAiPromptSceneNature1 => 'air terjun mengalir ke ngarai berlumut';

  @override
  String get economyAiPromptSceneNature2 => 'ladang bunga matahari di bawah langit luas';

  @override
  String get economyAiPromptSceneNature3 => 'danau beku dengan retakan es biru';

  @override
  String get economyAiPromptSceneNature4 => 'pohon sakura berjajar di jalan tepi sungai tenang';

  @override
  String get economyAiPromptSceneNature5 => 'laguna tropis dilihat dari atas';

  @override
  String get economyAiPromptSceneNature6 => 'maple musim gugur terpantul di kolam tenang';

  @override
  String get economyAiPromptSceneNature7 => 'seekor rubah sendirian di salju segar saat fajar';

  @override
  String get economyAiPromptSceneNature8 => 'awan badai bergulung di atas dataran tinggi hijau';

  @override
  String get economyAiPromptSceneSpace1 => 'planet bercincin terbit di atas cakrawala bulan';

  @override
  String get economyAiPromptSceneSpace2 => 'galaksi spiral berpendar di luar angkasa';

  @override
  String get economyAiPromptSceneSpace3 => 'astronaut melayang di atas planet biru';

  @override
  String get economyAiPromptSceneSpace4 => 'nebula berbentuk bunga yang sedang mekar';

  @override
  String get economyAiPromptSceneSpace5 => 'dua matahari terbenam di atas gurun asing';

  @override
  String get economyAiPromptSceneSpace6 => 'stasiun luar angkasa mengorbit raksasa gas';

  @override
  String get economyAiPromptSceneSpace7 => 'hujan meteor di atas observatorium sunyi';

  @override
  String get economyAiPromptSceneSpace8 => 'gerhana dengan cincin berlian yang terang';

  @override
  String get economyAiPromptSceneSynthwave1 => 'jalan grid neon melaju menuju matahari terbenam';

  @override
  String get economyAiPromptSceneSynthwave2 => 'pantai berpalem di bawah matahari bergaris';

  @override
  String get economyAiPromptSceneSynthwave3 => 'mobil sport retro di jalan tol tanpa ujung';

  @override
  String get economyAiPromptSceneSynthwave4 => 'gunung wireframe di bawah langit magenta';

  @override
  String get economyAiPromptSceneSynthwave5 => 'matahari krom tenggelam ke laut berpendar';

  @override
  String get economyAiPromptSceneSynthwave6 => 'arkade retro bercahaya di malam hujan';

  @override
  String get economyAiPromptSceneSynthwave7 => 'kaset pita melayang di ruang neon';

  @override
  String get economyAiPromptSceneSynthwave8 => 'sebatang palem sendirian di depan cakrawala laser';

  @override
  String get economyAiPromptScenePixelArt1 => 'pondok nyaman di hutan bersalju saat malam';

  @override
  String get economyAiPromptScenePixelArt2 => 'kastil di tebing di atas laut';

  @override
  String get economyAiPromptScenePixelArt3 => 'kota mungil dengan jendela-jendela bercahaya';

  @override
  String get economyAiPromptScenePixelArt4 => 'pesawat bintang di atas dunia asing ungu';

  @override
  String get economyAiPromptScenePixelArt5 => 'air terjun di lembah rimba yang subur';

  @override
  String get economyAiPromptScenePixelArt6 => 'dermaga pemancingan di bawah bulan purnama';

  @override
  String get economyAiPromptScenePixelArt7 => 'kuil bunga sakura di musim semi';

  @override
  String get economyAiPromptScenePixelArt8 => 'kereta melintasi jembatan saat matahari terbenam';

  @override
  String get economyAiPromptSceneRender3d1 => 'bentuk tanah liat mengilap bertumpuk seimbang';

  @override
  String get economyAiPromptSceneRender3d2 => 'pita kaca buram di panggung pastel';

  @override
  String get economyAiPromptSceneRender3d3 => 'pulau mungil melayang di atas awan lembut';

  @override
  String get economyAiPromptSceneRender3d4 => 'gelembung krom menggembung dalam cahaya lembut';

  @override
  String get economyAiPromptSceneRender3d5 => 'gurun miniatur dengan satu kaktus';

  @override
  String get economyAiPromptSceneRender3d6 => 'diorama kamar nyaman di dalam kubus';

  @override
  String get economyAiPromptSceneRender3d7 => 'lengkungan marmer melayang di atas air tenang';

  @override
  String get economyAiPromptSceneRender3d8 => 'ombak warna permen yang membeku';

  @override
  String get economyAiPromptSceneOilPainting1 => 'laut badai menghantam pantai berbatu';

  @override
  String get economyAiPromptSceneOilPainting2 => 'padang poppy diterpa matahari dengan rumah tani';

  @override
  String get economyAiPromptSceneOilPainting3 => 'still life berisi lemon dan vas biru';

  @override
  String get economyAiPromptSceneOilPainting4 => 'pelabuhan berkabut saat fajar dengan kapal tua';

  @override
  String get economyAiPromptSceneOilPainting5 => 'jalan hutan menyala oleh warna musim gugur';

  @override
  String get economyAiPromptSceneOilPainting6 => 'kanal diterangi bulan diapit rumah-rumah tua';

  @override
  String get economyAiPromptSceneOilPainting7 => 'ladang gandum beriak sebelum badai';

  @override
  String get economyAiPromptSceneOilPainting8 => 'setangkai mawar dalam gelas di meja gelap';

  @override
  String get economyAiPromptSceneUkiyoE1 => 'ombak besar menggulung di bawah bulan pucat';

  @override
  String get economyAiPromptSceneUkiyoE2 => 'pagoda tertutup salju saat senja';

  @override
  String get economyAiPromptSceneUkiyoE3 => 'burung bangau terbang di atas gunung berkabut';

  @override
  String get economyAiPromptSceneUkiyoE4 => 'jembatan kayu di bawah kelopak sakura berguguran';

  @override
  String get economyAiPromptSceneUkiyoE5 => 'perahu nelayan di laut nila yang bergelora';

  @override
  String get economyAiPromptSceneUkiyoE6 => 'matahari merah di atas puncak gunung berapi';

  @override
  String get economyAiPromptSceneUkiyoE7 => 'kolam koi di bawah pohon willow menjuntai';

  @override
  String get economyAiPromptSceneUkiyoE8 => 'hujan turun di kota tepi sungai yang sunyi';

  @override
  String get economyAiPromptLightingMorningHaze => 'kabut pagi lembut';

  @override
  String get economyAiPromptLightingGoldenHour => 'cahaya jam emas';

  @override
  String get economyAiPromptLightingMoonlight => 'cahaya bulan sejuk';

  @override
  String get economyAiPromptLightingNeonRim => 'cahaya tepi neon';

  @override
  String get economyAiPromptLightingBacklight => 'cahaya latar hangat';

  @override
  String get economyAiPromptLightingGodRays => 'sinar surya lembut';

  @override
  String get economyAiPromptLightingStudio => 'cahaya studio merata';

  @override
  String get economyAiPromptLightingTwilight => 'senja biru pekat';

  @override
  String get economyAiPromptPaletteTealAmber => 'nuansa teal dan amber';

  @override
  String get economyAiPromptPaletteIndigoRose => 'nuansa nila dan mawar';

  @override
  String get economyAiPromptPaletteSageCream => 'hijau sage dan krem';

  @override
  String get economyAiPromptPaletteBlackNeonPink => 'hitam dengan pink neon';

  @override
  String get economyAiPromptPalettePastelPeach => 'persik pastel lembut';

  @override
  String get economyAiPromptPaletteEmeraldGold => 'zamrud dan emas';

  @override
  String get economyAiPromptPaletteOceanBlue => 'nuansa biru laut';

  @override
  String get economyAiPromptPaletteCrimsonCharcoal => 'merah tua dan arang';

  @override
  String get economyAiPromptSuffix => 'wallpaper ponsel vertikal tanpa teks';

  @override
  String economyAiPromptComposition(String scene, String lighting, String palette, String suffix) {
    return '$scene, $lighting, palet $palette, $suffix';
  }

  @override
  String economyAiPromptSceneOnly(String scene, String suffix) {
    return '$scene, $suffix';
  }

  @override
  String get economyAiMadeWithPrism => 'Dibuat dengan Prism AI';

  @override
  String get onboardingAiPromptFallback => 'wallpaper yang indah';

  @override
  String get onboardingAiPromptNature1 =>
      'danau gletser saat matahari terbit, air setenang cermin, puncak gunung merah muda';

  @override
  String get onboardingAiPromptNature2 => 'aliran hutan berlumut dengan cahaya lembut menembus pakis tinggi';

  @override
  String get onboardingAiPromptNature3 => 'ladang bunga liar di bawah langit sore yang luas dengan awan berarak';

  @override
  String get onboardingAiPromptNature4 => 'pantai pasir hitam dengan ombak toska dan karang laut saat senja';

  @override
  String get onboardingAiPromptNature5 => 'aurora di atas hutan pinus bersalju di tepi danau beku';

  @override
  String get onboardingAiPromptAbstract1 =>
      'pita kaca tembus pandang meliuk dalam cahaya lembut dengan tepi berkilau pelangi';

  @override
  String get onboardingAiPromptAbstract2 => 'awan tinta mekar di air, biru tua dan emas dengan detail halus';

  @override
  String get onboardingAiPromptAbstract3 =>
      'gelombang berlapis seperti kertas dalam warna senja hangat, bayangan lembut';

  @override
  String get onboardingAiPromptAbstract4 => 'pusaran marmer berukir dengan urat emas di latar arang pekat';

  @override
  String get onboardingAiPromptAbstract5 => 'bola krom melayang memantulkan langit pastel di ruang terbuka yang tenang';

  @override
  String get onboardingAiPromptWatercolor1 => 'desa pantai cat air dengan rumah pastel dan perahu saat matahari terbit';

  @override
  String get onboardingAiPromptWatercolor2 => 'bunga liar cat air merah muda dan sage di atas kertas bertekstur';

  @override
  String get onboardingAiPromptWatercolor3 => 'danau berkabut cat air dengan dermaga kayu kecil dan perbukitan jauh';

  @override
  String get onboardingAiPromptWatercolor4 => 'langit malam cat air dengan awan ungu lembut dan bulan berpendar';

  @override
  String get onboardingAiPromptWatercolor5 => 'hutan musim gugur cat air dalam sapuan hangat oranye dan emas';

  @override
  String get onboardingAiPromptMinimal1 =>
      'satu matahari terbenam di laut tenang, warna datar, langit luas yang kosong';

  @override
  String get onboardingAiPromptMinimal2 => 'perbukitan berlapis warna pasir kalem di bawah langit gradasi pucat';

  @override
  String get onboardingAiPromptMinimal3 => 'satu pohon gundul di bukit bersalju dengan banyak ruang kosong yang sunyi';

  @override
  String get onboardingAiPromptMinimal4 =>
      'perahu layar sendirian di danau tenang saat fajar, bentuk sederhana, warna lembut';

  @override
  String get onboardingAiPromptMinimal5 => 'lengkungan konsentris lembut warna terakota dan krem dengan butiran halus';

  @override
  String get onboardingAiPromptAnime1 =>
      'langit musim panas gaya anime, awan menjulang di atas rel tepi laut yang sepi';

  @override
  String get onboardingAiPromptAnime2 => 'kota malam gaya anime dari puncak bukit, lampu hangat, langit penuh bintang';

  @override
  String get onboardingAiPromptAnime3 =>
      'kuil hutan gaya anime dengan roh bercahaya melayang dalam cahaya hijau lembut';

  @override
  String get onboardingAiPromptAnime4 => 'jalan hujan gaya anime saat senja, lampu toko berpendar, pantulan genangan';

  @override
  String get onboardingAiPromptAnime5 => 'padang rumput gaya anime saat jam emas dengan angin menyapu rumput tinggi';

  @override
  String get onboardingAiPromptMeshGradient1 => 'gradasi mesh halus jingga, merah muda, dan ungu dengan butiran lembut';

  @override
  String get onboardingAiPromptMeshGradient2 =>
      'gradasi mesh pekat biru tua dan teal dengan sorot hijau limau berpendar';

  @override
  String get onboardingAiPromptMeshGradient3 => 'gradasi mesh lembut biru langit, lavender, dan krem hangat';

  @override
  String get onboardingAiPromptMeshGradient4 => 'gradasi mesh berani merah tua dan emas yang mengalir seperti sutra';

  @override
  String get onboardingAiPromptMeshGradient5 => 'gradasi mesh tenang sage, mint, dan pasir pucat dengan cahaya lembut';

  @override
  String get onboardingAiPromptCyberpunk1 => 'jalan cyberpunk malam hari saat hujan dengan pantulan neon dan uap';

  @override
  String get onboardingAiPromptCyberpunk2 => 'kota neon menjulang dari atap gedung, mobil terbang melesat lewat';

  @override
  String get onboardingAiPromptCyberpunk3 => 'kanal cyberpunk tenang diapit toko berpendar dan lampion melayang';

  @override
  String get onboardingAiPromptCyberpunk4 => 'cakrawala cyberpunk saat fajar, menara kaca dalam kabut pink dan teal';

  @override
  String get onboardingAiPromptCyberpunk5 => 'motor sendirian di jembatan neon di atas kota futuristik berkabut';

  @override
  String get onboardingAiPromptSpace1 =>
      'raksasa gas bercincin terbit di atas bulan berbatu, bintang memenuhi langit hitam';

  @override
  String get onboardingAiPromptSpace2 => 'nebula penuh warna ungu dan teal dengan bintang muda yang terang';

  @override
  String get onboardingAiPromptSpace3 => 'galaksi spiral dari depan dengan inti berpendar dan lengan biru berdebu';

  @override
  String get onboardingAiPromptSpace4 => 'astronaut melayang di atas Bumi saat matahari terbit, atmosfer biru tipis';

  @override
  String get onboardingAiPromptSpace5 => 'gerhana matahari total di atas barisan pegunungan yang sunyi';

  @override
  String get onboardingAiPromptSynthwave1 =>
      'matahari terbenam synthwave, matahari bergaris di atas grid neon berpendar';

  @override
  String get onboardingAiPromptSynthwave2 => 'mobil retro melaju menuju matahari magenta di jalan pesisir yang sepi';

  @override
  String get onboardingAiPromptSynthwave3 => 'gunung wireframe di bawah langit ungu berbintang dengan matahari krom';

  @override
  String get onboardingAiPromptSynthwave4 => 'pantai synthwave dengan siluet palem dan cakrawala pink berpendar';

  @override
  String get onboardingAiPromptSynthwave5 => 'cakrawala kota retro malam hari dalam kabut neon pink dan cyan';

  @override
  String get onboardingAiPromptPixelArt1 =>
      'pondok pixel art di hutan bersalju, jendela hangat berpendar di malam hari';

  @override
  String get onboardingAiPromptPixelArt2 => 'kota pesisir pixel art saat matahari terbenam dengan perahu di pelabuhan';

  @override
  String get onboardingAiPromptPixelArt3 => 'kastil pixel art di pulau melayang di atas awan';

  @override
  String get onboardingAiPromptPixelArt4 => 'langit malam pixel art di atas danau tenang dengan kunang-kunang';

  @override
  String get onboardingAiPromptPixelArt5 => 'jalan bunga sakura pixel art menuju kuil kecil';

  @override
  String get onboardingAiPromptRender3d1 => 'render 3D bentuk tanah liat lembut warna pastel dengan bayangan halus';

  @override
  String get onboardingAiPromptRender3d2 => 'render 3D pulau mungil melayang dengan air terjun dan pepohonan';

  @override
  String get onboardingAiPromptRender3d3 => 'render 3D ombak kaca mengilap biru dan ungu di bawah cahaya studio';

  @override
  String get onboardingAiPromptRender3d4 => 'render 3D kamar miniatur nyaman di dalam kubus berpendar';

  @override
  String get onboardingAiPromptRender3d5 => 'render 3D gelembung krom melayang di atas laut pink yang tenang';

  @override
  String get onboardingAiPromptOilPainting1 => 'lukisan minyak laut badai dengan kapal kecil di bawah langit dramatis';

  @override
  String get onboardingAiPromptOilPainting2 => 'lukisan minyak ladang poppy diterpa matahari dengan rumah tani jauh';

  @override
  String get onboardingAiPromptOilPainting3 => 'lukisan minyak pelabuhan berkabut saat fajar dengan perahu kayu tua';

  @override
  String get onboardingAiPromptOilPainting4 => 'lukisan minyak jalan hutan musim gugur dengan sapuan kuas tebal';

  @override
  String get onboardingAiPromptOilPainting5 =>
      'lukisan minyak kota kanal diterangi bulan dengan jendela hangat berpendar';

  @override
  String get onboardingAiPromptUkiyoE1 => 'ombak besar ukiyo-e di bawah bulan pucat, gunung bersalju di kejauhan';

  @override
  String get onboardingAiPromptUkiyoE2 => 'desa bersalju ukiyo-e di malam hari dengan lampion kertas berpendar';

  @override
  String get onboardingAiPromptUkiyoE3 => 'pemandangan ukiyo-e burung bangau terbang di atas gunung berkabut';

  @override
  String get onboardingAiPromptUkiyoE4 => 'jembatan kayu ukiyo-e di bawah bunga sakura pada hari musim semi';

  @override
  String get onboardingAiPromptUkiyoE5 => 'matahari merah ukiyo-e di atas laut nila tenang dengan perahu nelayan';

  @override
  String wallpaperWotdByline(String name) {
    return 'oleh $name';
  }

  @override
  String get wallpaperWotdPastPicks => 'Pilihan sebelumnya';

  @override
  String wallpaperWotdPickedOn(String wallpaper, String date) {
    return '$wallpaper, dipilih $date';
  }

  @override
  String get wallpaperWotdSeePast => 'Lihat Wallpaper Hari Ini sebelumnya';

  @override
  String get wallpaperWotdTitle => 'Wallpaper Hari Ini';

  @override
  String get wallpaperYourProfile => 'Profil Anda';

  @override
  String get widgetsSettingsTitle => 'Widget';

  @override
  String get widgetsSettingsSubtitle => 'Tambahkan Prism ke Layar Utama dan Layar Terkunci';

  @override
  String get widgetsGuideTitle => 'Tambahkan widget Prism';

  @override
  String get widgetsGuideHomeTab => 'Layar Utama';

  @override
  String get widgetsGuideLockTab => 'Layar Terkunci';

  @override
  String get widgetsGuideHomeStep1 => 'Sentuh dan tahan area kosong di Layar Utama sampai aplikasi bergoyang.';

  @override
  String get widgetsGuideHomeStep2 => 'Ketuk Edit, lalu ketuk Tambah Widget.';

  @override
  String get widgetsGuideHomeStep3 => 'Cari Prism, pilih ukuran, lalu ketuk Tambah Widget.';

  @override
  String get widgetsGuideLockStep1 => 'Sentuh dan tahan Layar Terkunci, lalu ketuk Sesuaikan.';

  @override
  String get widgetsGuideLockStep2 => 'Ketuk Layar Terkunci, lalu ketuk area widget di bawah jam.';

  @override
  String get widgetsGuideLockStep3 => 'Pilih Prism, lalu ketuk widget untuk menambahkannya.';

  @override
  String get widgetsGuideHomeIllustration => 'Ponsel dengan widget Wallpaper Hari Ini di Layar Utama';

  @override
  String get widgetsGuideLockIllustration => 'Ponsel dengan widget Prism di Layar Terkunci';

  @override
  String get widgetsGuideDone => 'Selesai';

  @override
  String get widgetsCardTitle => 'Wallpaper Hari Ini di Layar Utama';

  @override
  String get widgetsCardBody => 'Tambahkan widget dan lihat wallpaper baru setiap hari.';

  @override
  String get widgetsCardAction => 'Tunjukkan caranya';

  @override
  String get widgetsCardDismiss => 'Tutup';

  @override
  String get foldersTitle => 'Folder';

  @override
  String get foldersSaveToFolder => 'Simpan ke folder';

  @override
  String get foldersAddToFolder => 'Tambahkan ke folder';

  @override
  String get foldersNewFolder => 'Folder baru';

  @override
  String get foldersNameHint => 'Nama folder';

  @override
  String get foldersCreate => 'Buat';

  @override
  String get foldersCreateFolder => 'Buat folder';

  @override
  String get foldersSuggested => 'Disarankan';

  @override
  String get foldersNewTag => 'Baru';

  @override
  String foldersItemCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString wallpaper',
      one: '1 wallpaper',
      zero: 'Tidak ada wallpaper',
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
      other: 'Disimpan ke $countString folder.',
      one: 'Disimpan ke 1 folder.',
    );
    return '$_temp0';
  }

  @override
  String get foldersUpdated => 'Folder diperbarui.';

  @override
  String get foldersSaveFailed => 'Tidak dapat menyimpan ke folder. Coba lagi.';

  @override
  String get foldersUpdateFailed => 'Tidak dapat memperbarui folder. Coba lagi.';

  @override
  String get foldersRename => 'Ganti nama';

  @override
  String get foldersRenameTitle => 'Ganti nama folder';

  @override
  String get foldersDelete => 'Hapus';

  @override
  String foldersDeleteTitle(String name) {
    return 'Hapus $name?';
  }

  @override
  String get foldersDeleteMessage => 'Wallpaper tetap ada di favorit Anda.';

  @override
  String get foldersDeleteConfirm => 'Hapus folder';

  @override
  String get foldersDeleted => 'Folder dihapus.';

  @override
  String get foldersRemoveTitle => 'Hapus dari folder ini?';

  @override
  String get foldersRemoveMessage => 'Wallpaper ini tetap ada di favorit Anda.';

  @override
  String get foldersRemoveConfirm => 'Hapus';

  @override
  String get foldersRemoved => 'Dihapus dari folder.';

  @override
  String get foldersEmptyTitle => 'Folder ini kosong';

  @override
  String get foldersEmptyBody => 'Tekan lama ikon hati pada wallpaper untuk menyimpannya di sini.';

  @override
  String get foldersNoFolders => 'Atur wallpaper tersimpan Anda ke dalam folder.';

  @override
  String get foldersLoadError => 'Folder ini tidak dapat dimuat.';

  @override
  String get foldersNotFoundTitle => 'Folder ini tidak tersedia';

  @override
  String get foldersNotFoundBody => 'Mungkin folder ini sudah dihapus.';

  @override
  String get foldersSignInFeature => 'folder';

  @override
  String get foldersMoreOptions => 'Opsi lainnya';

  @override
  String get foldersSuggestionLockScreen => 'Layar kunci';

  @override
  String get foldersSuggestionHomeScreen => 'Layar utama';
}
