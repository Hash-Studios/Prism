// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get wallpaperProviderWallhaven => 'Wallhaven';

  @override
  String get economyExportFailedLabel => 'No se pudo exportar';

  @override
  String get coreSignInCreatorSearchFeature => 'la búsqueda de creadores';

  @override
  String get debugLogExportSubject => 'Registros de depuración de Prism';

  @override
  String get accountAbout => 'Acerca de';

  @override
  String get accountAboutPrism => 'Acerca de Prism';

  @override
  String get accountAccount => 'Cuenta';

  @override
  String get accountAccountDeletionSubscriptionWarning =>
      'La suscripción de la tienda no se cancela al eliminar tu cuenta. Se seguirá cobrando hasta que la canceles en la tienda.';

  @override
  String get accountAdPrivacyChoices => 'Opciones de privacidad de anuncios';

  @override
  String get accountAddProfilePhoto => 'Añadir foto de perfil';

  @override
  String get accountAddSocialLink => 'Añadir un enlace social';

  @override
  String get accountAdmin => 'Administración';

  @override
  String get accountAdminModeration => 'Moderación de administración';

  @override
  String accountAndroidSharePitch(String url) {
    return '¡Vuelve a enamorarte de la personalización de Android! Descubre Prism:\n$url';
  }

  @override
  String get accountAnyResolution => 'Cualquiera';

  @override
  String get accountAppName => 'Prism Wallpapers';

  @override
  String get accountAppearance => 'Apariencia';

  @override
  String get accountApply => 'Aplicar';

  @override
  String get accountAskEveryTime => 'Preguntar cada vez';

  @override
  String get accountAudience => 'Audiencia';

  @override
  String get accountAutoRotateWallpapers => 'Cambiar fondos automáticamente';

  @override
  String get accountBlock => 'Bloquear';

  @override
  String get accountBlockActionFailed => 'No se pudo actualizar la lista de cuentas bloqueadas';

  @override
  String get accountBlockActionPendingSync =>
      'El cambio se guardó en este dispositivo y se sincronizará cuando sea posible.';

  @override
  String get accountBlockConfirmationUserFallback => 'esta persona';

  @override
  String accountBlockThisUserTitle(String name) {
    return '¿Bloquear a $name?';
  }

  @override
  String get accountBlockUser => 'Bloquear usuario';

  @override
  String accountBlockUserMessage(String name) {
    return 'Dejarás de seguir a $name, no verás sus fondos en las novedades y dejarás de recibir notificaciones sobre sus nuevas publicaciones.';
  }

  @override
  String get accountBlockedAccounts => 'Cuentas bloqueadas';

  @override
  String get accountBlockedAccountsEmptyBody =>
      'Al bloquear una cuenta, sus publicaciones dejan de aparecer en tus novedades. Aun así, es posible que pueda ver tu perfil público y tus fondos.';

  @override
  String get accountBlockedAccountsLoadError => 'No se pudieron cargar las cuentas bloqueadas';

  @override
  String get accountBlockedListUserFallback => 'Usuario bloqueado';

  @override
  String get accountBlockedProfileBody =>
      'Sus fondos no aparecerán en tus novedades ni recibirás sus notificaciones. Puedes desbloquear a esta persona cuando quieras.';

  @override
  String get accountBringBackSubscription => 'Restaurar una suscripción anterior';

  @override
  String get accountBrowseByCategory => 'Explorar por categoría';

  @override
  String get accountBrowseByColour => 'Explorar por color';

  @override
  String get accountBuyPremium => 'Comprar Premium';

  @override
  String get accountCacheCleared => 'Caché borrada.';

  @override
  String accountCacheClearedBytes(String size) {
    return 'Se borraron $size.';
  }

  @override
  String accountCachedImageSize(String size) {
    return '$size de imágenes en caché';
  }

  @override
  String get accountCancel => 'Cancelar';

  @override
  String get accountCannotGiftThisAccount => 'No puedes enviar un regalo a esta cuenta.';

  @override
  String accountCategorySemanticLabel(String name) {
    return 'Categoría, $name';
  }

  @override
  String get accountChangeAutomatically => 'Cambiar automáticamente';

  @override
  String get accountChangeCoverPhoto => 'Cambiar foto de portada';

  @override
  String get accountChangeOrCancelStore => 'Cambiar o cancelar en la tienda';

  @override
  String get accountChangePhoto => 'Cambiar foto';

  @override
  String get accountChangeWallpaperOnTimer => 'Cambiar el fondo con un temporizador';

  @override
  String get accountCheckConnectionTryAgain => 'Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get accountClear => 'Borrar';

  @override
  String get accountClearAllDownloads => 'Borrar todas las descargas';

  @override
  String get accountClearAllFavouritesQuestion => '¿Borrar todos los favoritos?';

  @override
  String get accountClearCache => 'Borrar caché';

  @override
  String get accountClearCacheConfirmMessage =>
      'Se borrarán las imágenes en caché. Se volverán a cargar cuando las necesites.';

  @override
  String accountClearCacheConfirmSizeMessage(String size) {
    return 'Se borrarán $size de imágenes en caché. Se volverán a cargar cuando las necesites.';
  }

  @override
  String get accountClearCacheQuestion => '¿Borrar la caché?';

  @override
  String get accountClearCacheTitle => 'Borrar caché';

  @override
  String get accountClearCachedImages => 'Borrar imágenes guardadas en caché localmente';

  @override
  String get accountClearColour => 'Borrar color';

  @override
  String get accountClearDepthEffect => 'Borrar efecto de profundidad';

  @override
  String get accountClearFavouriteWallpapers => 'Borrar fondos favoritos';

  @override
  String get accountClearFavourites => 'Borrar favoritos';

  @override
  String accountClearFavouritesCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se borrarán $countString fondos favoritos',
      one: 'Se borrará 1 fondo favorito',
    );
    return '$_temp0 de tu cuenta. Esta acción no se puede deshacer.';
  }

  @override
  String get accountClearFavouritesMessage =>
      'Se borrarán todos los fondos favoritos de tu cuenta. Esta acción no se puede deshacer.';

  @override
  String get accountClearLearnedTaste => 'Borrar preferencias aprendidas';

  @override
  String accountClearLearnedTasteCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'las $countString cosas que aprendió',
      one: 'lo que aprendió',
    );
    return 'Prism olvidará $_temp0 de lo que viste y guardaste. Tu feed volverá a usar los intereses que elegiste. Esta acción no se puede deshacer.';
  }

  @override
  String get accountClearLearnedTasteQuestion => '¿Borrar las preferencias aprendidas?';

  @override
  String get accountClearSearch => 'Borrar búsqueda';

  @override
  String get accountColour => 'Color';

  @override
  String accountCommitCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString commits',
      one: '1 commit',
      zero: 'Ningún commit',
    );
    return '$_temp0';
  }

  @override
  String get accountCompleteProfile => 'Completar perfil';

  @override
  String get accountCompleteYourProfile => 'Completa tu perfil';

  @override
  String get accountConnectionTryAgain => 'Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get accountContent => 'Contenido';

  @override
  String get accountContributor => 'Colaborador';

  @override
  String accountContributorCommitCount(String login, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString commits',
      one: '1 commit',
      zero: 'ningún commit',
    );
    return '$login, $_temp0';
  }

  @override
  String get accountCopy => 'Copiar';

  @override
  String get accountCopyLink => 'Copiar enlace';

  @override
  String get accountCouldNotBuildReport => 'No se pudo generar el informe. Inténtalo de nuevo.';

  @override
  String get accountCouldNotClearFavourites => 'No se pudieron borrar los fondos favoritos. Inténtalo de nuevo.';

  @override
  String get accountCouldNotClearLearnedTaste =>
      'No se pudieron borrar las preferencias aprendidas. Inténtalo de nuevo.';

  @override
  String get accountCouldNotCreateLink => 'No se pudo crear el enlace. Inténtalo de nuevo.';

  @override
  String get accountCouldNotDeleteDownloads => 'No se pudieron borrar las descargas. Inténtalo de nuevo.';

  @override
  String accountCouldNotFollowPerson(String name) {
    return 'No se pudo seguir a $name. Inténtalo de nuevo.';
  }

  @override
  String get accountCouldNotLoadFollowers => 'No se pudieron cargar los seguidores';

  @override
  String get accountCouldNotLoadFollowing => 'No se pudieron cargar las cuentas que sigue';

  @override
  String get accountCouldNotLoadTeam => 'No se pudo cargar el equipo';

  @override
  String get accountCouldNotLoadThisProfile => 'No se pudo cargar este perfil';

  @override
  String get accountCouldNotLoadTrending => 'No se pudieron cargar las tendencias';

  @override
  String get accountCouldNotLoadWallpapers => 'No se pudieron cargar los fondos';

  @override
  String accountCouldNotOpenAddress(String address) {
    return 'No se pudo abrir $address';
  }

  @override
  String get accountCouldNotOpenLink => 'No se pudo abrir el enlace. Inténtalo de nuevo.';

  @override
  String get accountCouldNotOpenStore => 'No se pudo abrir la tienda. Inténtalo de nuevo.';

  @override
  String get accountCouldNotOpenThisLink => 'No se pudo abrir este enlace.';

  @override
  String get accountCouldNotRefreshSearch => 'No se pudo actualizar. Desliza hacia abajo para intentarlo de nuevo.';

  @override
  String get accountCouldNotRemoveSavedOffline =>
      'No se pudieron borrar los fondos guardados sin conexión. Inténtalo de nuevo.';

  @override
  String get accountCouldNotRestorePurchases => 'No se pudieron restaurar las compras. Inténtalo de nuevo.';

  @override
  String get accountCouldNotSearchCreators => 'No se pudieron buscar creadores';

  @override
  String get accountCouldNotSearchRightNow => 'No se pudo buscar en este momento';

  @override
  String get accountCouldNotSendGift => 'No se pudo enviar el regalo. Inténtalo de nuevo.';

  @override
  String get accountCouldNotShareReport => 'No se pudo compartir el informe. Inténtalo de nuevo.';

  @override
  String accountCouldNotUnfollowPerson(String name) {
    return 'No se pudo dejar de seguir a $name. Inténtalo de nuevo.';
  }

  @override
  String get accountCreatorFallback => 'Creador de Prism';

  @override
  String get accountCreatorSearchEmptyBody => 'Comprueba la ortografía o prueba con otro nombre.';

  @override
  String get accountCurrentSignedInAccountRequired => 'Selecciona la cuenta con la que tienes la sesión iniciada.';

  @override
  String get accountDataSaver => 'Ahorro de datos';

  @override
  String get accountDataSaverDescription =>
      'Ahorra datos móviles. Los fondos se abren como miniaturas, las novedades no se cargan por adelantado y los carruseles no se reproducen automáticamente.';

  @override
  String get accountDatabaseUsageStats => 'Uso y estadísticas de la base de datos';

  @override
  String get accountDebugPanel => 'Panel de depuración';

  @override
  String get accountDefaultActionForSet => 'Acción predeterminada al aplicar';

  @override
  String get accountDeleteAccount => 'Eliminar cuenta';

  @override
  String get accountDeleteAccountConfirmation =>
      'Esto eliminará tu cuenta de forma permanente, borrará tus datos personales y cerrará tu sesión.\n\nLos fondos que hayas subido seguirán visibles como \"Cuenta eliminada\".\n\nEsta acción no se puede deshacer.';

  @override
  String get accountDeleteAccountReauthNote => 'A continuación, confirmarás tu identidad con Google o Apple.';

  @override
  String get accountDeleteAll => 'Borrar todo';

  @override
  String get accountDeleteAllDownloadsQuestion => '¿Borrar todas las descargas?';

  @override
  String accountDeleteDownloadsCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fondos descargados',
      one: '1 fondo descargado',
    );
    return 'Se eliminarán $_temp0 de Descargas. Las copias guardadas sin conexión no se verán afectadas. Esta acción no se puede deshacer.';
  }

  @override
  String get accountDeleteDownloadsMessage =>
      'Los fondos descargados se eliminarán de Descargas. Las copias guardadas sin conexión no se verán afectadas. Esta acción no se puede deshacer.';

  @override
  String get accountDeleteYourAccountQuestion => '¿Eliminar tu cuenta?';

  @override
  String get accountDeletingYourAccount => 'Eliminando tu cuenta';

  @override
  String get accountDepthEffect => 'Efecto de profundidad';

  @override
  String get accountDepthEffectClockSemanticLabel => 'Efecto de profundidad, el sujeto delante del reloj';

  @override
  String accountDownloadedWallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fondos descargados; las copias guardadas sin conexión se conservan',
      one: '1 fondo descargado; las copias guardadas sin conexión se conservan',
      zero: 'No hay fondos descargados; las copias guardadas sin conexión se conservan',
    );
    return '$_temp0';
  }

  @override
  String get accountDownloadsDeleted => 'Se borraron todas las descargas.';

  @override
  String get accountEarnCoins => 'Ganar monedas';

  @override
  String accountEarnProfileCompletionCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Gana $coinsString monedas al completar tu perfil';
  }

  @override
  String get accountEditCover => 'Editar portada';

  @override
  String get accountEditProfile => 'Editar perfil';

  @override
  String get accountExportFavourites => 'Exportar favoritos';

  @override
  String get accountFavouritesCleared => 'Se borraron todos los fondos favoritos.';

  @override
  String get accountFeedback => 'COMENTARIOS';

  @override
  String get accountFeedbackSubject => 'Comentarios sobre Prism';

  @override
  String get accountFields => 'Campos';

  @override
  String get accountFilters => 'Filtros';

  @override
  String get accountFindCreators => 'Buscar creadores';

  @override
  String get accountFinishYourProfile => 'Completa tu perfil';

  @override
  String get accountFirestoreTelemetry => 'Telemetría de Firestore';

  @override
  String get accountFollow => 'Seguir';

  @override
  String accountFollowPerson(String name) {
    return 'Seguir a $name';
  }

  @override
  String accountFollowedPerson(String name) {
    return '¡Sigues a $name!';
  }

  @override
  String get accountFollowers => 'Seguidores';

  @override
  String accountFollowersCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString seguidores',
      one: '1 seguidor',
      zero: 'Sin seguidores',
    );
    return '$_temp0';
  }

  @override
  String accountFollowersCountLabel(String compactCount) {
    return '$compactCount seguidores';
  }

  @override
  String get accountFollowersEmptyMessage => 'Aquí aparecerán las personas que sigan esta cuenta.';

  @override
  String get accountFollowing => 'Siguiendo';

  @override
  String accountFollowingCountLabel(String compactCount) {
    return 'Siguiendo a $compactCount';
  }

  @override
  String get accountFollowingEmptyMessage => 'Aquí aparecerán las cuentas que sigas desde esta sección.';

  @override
  String get accountForgetFeedLearned => 'Borrar lo que tu feed ha aprendido de ti';

  @override
  String get accountFromPrism => 'De Prism';

  @override
  String get accountGiftLimitReached => 'Por ahora, alcanzaste el límite de regalos. Inténtalo de nuevo mañana.';

  @override
  String accountGiftPassMessage(String recipientName, int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$recipientName tendrá acceso a las colecciones prémium y a los fondos de pantalla prémium hasta mañana. Cuesta $priceString monedas.';
  }

  @override
  String get accountGiftPassTitle => 'Regalar un pase Pro de 24 horas';

  @override
  String get accountGiftPassTooltip => 'Regalar un pase de 24 h';

  @override
  String get accountGiftsOpenAfterSevenDays => 'Podrás enviar regalos cuando tu cuenta tenga 7 días.';

  @override
  String get accountHapticFeedback => 'Respuesta háptica';

  @override
  String get accountHelp => 'Ayuda';

  @override
  String get accountHomeAndLockScreens => 'Pantallas de inicio y bloqueo';

  @override
  String get accountHomeScreen => 'Pantalla de inicio';

  @override
  String get accountInviteFriends => 'Invitar a amigos';

  @override
  String get accountInviteLinkCouldNotCreate => 'No se pudo crear tu enlace de invitación.';

  @override
  String accountInviteRewardHeadline(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Da $coinsString, recibe $coinsString';
  }

  @override
  String accountInviteRewardMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Tu amigo recibirá $coinsString monedas al unirse. Tú también recibirás $coinsString.';
  }

  @override
  String get accountInviteShareFailed => 'No se pudo compartir la invitación en este momento.';

  @override
  String accountIosSharePitch(String url) {
    return '¡Vuelve a enamorarte de la personalización de tu teléfono! Descubre Prism:\n$url';
  }

  @override
  String get accountLater => 'Más tarde';

  @override
  String get accountLatest => 'Más recientes';

  @override
  String get accountLearnedTasteCleared => 'Se borraron las preferencias aprendidas.';

  @override
  String get accountLibrary => 'Biblioteca';

  @override
  String get accountLightDarkAccentColour => 'Colores claro, oscuro y de acento';

  @override
  String get accountLink => 'Enlace';

  @override
  String get accountLinkCopied => 'Enlace copiado';

  @override
  String get accountLinkType => 'Tipo de enlace';

  @override
  String get accountLinkTypeBehance => 'Behance';

  @override
  String get accountLinkTypeBioLink => 'bio.link';

  @override
  String get accountLinkTypeBuyMeACoffee => 'Buy Me a Coffee';

  @override
  String get accountLinkTypeCustom => 'Enlace personalizado';

  @override
  String get accountLinkTypeDeviantArt => 'DeviantArt';

  @override
  String get accountLinkTypeDribbble => 'Dribbble';

  @override
  String get accountLinkTypeEmail => 'Correo electrónico';

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
    return 'Tipo de enlace, $name';
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
  String get accountLiveWallpapers => 'Fondos animados';

  @override
  String get accountLoadingTeam => 'Cargando el equipo';

  @override
  String get accountLockScreen => 'Pantalla de bloqueo';

  @override
  String get accountLogOut => 'Cerrar sesión';

  @override
  String get accountLogOutOfPrismQuestion => '¿Cerrar sesión en Prism?';

  @override
  String get accountLogOutQuestion => '¿Cerrar sesión?';

  @override
  String get accountLogoutConfirmation =>
      'Al cerrar sesión, se borrarán el historial y las preferencias aprendidas de este dispositivo. Tus favoritos, monedas y perfil seguirán en tu cuenta.';

  @override
  String get accountLogoutFailed => 'No se pudo cerrar sesión. Inténtalo de nuevo.';

  @override
  String get accountLogsNetworkToolsStorage => 'Registros, red, herramientas y almacenamiento';

  @override
  String get accountMadeWithLoveInIndia => 'Hecho con ❤ en India con Flutter';

  @override
  String get accountManageBlockedPeople => 'Gestionar personas bloqueadas';

  @override
  String get accountManageSubscription => 'Gestionar suscripción';

  @override
  String get accountMenu => 'Menú';

  @override
  String get accountMinResolution => 'Resolución mínima';

  @override
  String get accountMoreLinks => 'Más enlaces';

  @override
  String get accountMoreOptions => 'Más opciones';

  @override
  String get accountMovingGradientsMotionVideo => 'Degradados en movimiento, animación y vídeo';

  @override
  String get accountMyAccent => 'Mi color de acento';

  @override
  String get accountNoBlockedAccounts => 'No hay cuentas bloqueadas';

  @override
  String get accountNoContributors => 'Aún no hay colaboradores para mostrar.';

  @override
  String get accountNoCreatorsFound => 'No se encontraron creadores';

  @override
  String get accountNoDownloadsToRemove => 'No tienes descargas que eliminar.';

  @override
  String get accountNoFollowersYet => 'Aún no tienes seguidores';

  @override
  String get accountNoPurchasesToRestore => 'No hay compras que restaurar en esta cuenta.';

  @override
  String get accountNoResults => 'No hay resultados';

  @override
  String accountNoWallpapersForFilters(String filters) {
    return 'No se encontraron fondos de pantalla con $filters';
  }

  @override
  String accountNoWallpapersForQueryWithFilters(String query) {
    return 'No se encontraron fondos de pantalla para $query con los filtros seleccionados.';
  }

  @override
  String get accountNoWallpapersFound => 'No se encontraron fondos de pantalla';

  @override
  String accountNoWallpapersFoundForQuery(String query) {
    return 'No se encontraron fondos de pantalla para $query';
  }

  @override
  String get accountNoWallpapersYet => 'Aún no hay fondos de pantalla';

  @override
  String accountNobodyMatchesUsername(String query) {
    return 'Nadie coincide con «$query». Prueba con otro nombre de usuario.';
  }

  @override
  String get accountNotEnoughCoinsEarnInRewards => 'No tienes suficientes monedas. Consigue más en Recompensas.';

  @override
  String get accountNotFollowingAnyoneYet => 'Aún no sigues a nadie';

  @override
  String get accountNotSynced => 'Sin sincronizar';

  @override
  String get accountNothingLearnedYet => 'Prism aún no ha aprendido nada.';

  @override
  String get accountNotificationPreferences => 'Preferencias de notificaciones';

  @override
  String get accountNotificationTypes => 'Muro del día, seguidores, publicaciones y más';

  @override
  String get accountNotifications => 'Notificaciones';

  @override
  String get accountOpenYourProfile => 'Abrir tu perfil';

  @override
  String get accountOpeningProfileEditor => 'Abriendo el editor de perfil';

  @override
  String get accountOpens => 'Aperturas';

  @override
  String get accountOtherContributors => 'Otros colaboradores';

  @override
  String accountPassSentToPerson(String name) {
    return 'Se envió el pase a $name.';
  }

  @override
  String accountPersonAlreadyHasPro(String name) {
    return '$name ya tiene Pro.';
  }

  @override
  String get accountPersonalise => 'Personalización';

  @override
  String get accountPortraitOnly => 'Solo vertical';

  @override
  String get accountPremiumBenefitsActive =>
      'Tienes todos los fondos de pantalla prémium, descargas gratis y filtros gratis.';

  @override
  String get accountPremiumBenefitsInactive =>
      'Desbloquea fondos de pantalla prémium, descargas gratis y filtros gratis.';

  @override
  String get accountPreview => 'Vista previa';

  @override
  String get accountPrismListPrivacySubtitle => 'Cómo gestiona Prism tus datos';

  @override
  String get accountPrismPro => 'Prism Pro';

  @override
  String get accountPrivacyAction => 'PRIVACIDAD';

  @override
  String get accountPrivacyAndData => 'Privacidad y datos';

  @override
  String get accountPrivacyPolicy => 'Política de privacidad';

  @override
  String get accountProBadge => 'Pro';

  @override
  String get accountProWallpaperSemantics => 'Fondo de pantalla Pro';

  @override
  String get accountProblemReportSharePrompt =>
      'Describe qué ha ocurrido. El archivo del informe contiene los detalles.';

  @override
  String get accountProblemReportShareSubject => 'Informe de problemas de Prism';

  @override
  String get accountProfile => 'Perfil';

  @override
  String get accountProfileNotAvailable => 'Perfil no disponible';

  @override
  String get accountProfileNotAvailableBody =>
      'Esta persona no usa la versión más reciente de Prism, por lo que no se puede mostrar su perfil.';

  @override
  String accountProfileNudgeMessage(int percent, int coins) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Tu perfil está completo al $percentString %. Complétalo para ganar $coinsString monedas Prism.';
  }

  @override
  String accountProfilePercentComplete(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Perfil completo al $percentString %';
  }

  @override
  String accountProfilePersonSemantics(String name, String username) {
    return '$name, @$username';
  }

  @override
  String get accountProfiles => 'perfiles';

  @override
  String get accountPurchases => 'Compras';

  @override
  String get accountPurchasesRestored => 'Compras restauradas.';

  @override
  String get accountPurchasesRestoredPending => 'Compras restauradas. Pro puede tardar un minuto en activarse.';

  @override
  String get accountQuickTiles => 'Accesos rápidos';

  @override
  String get accountRateApp => 'VALORAR';

  @override
  String get accountRecentSearches => 'Búsquedas recientes';

  @override
  String get accountRelevance => 'Relevancia';

  @override
  String get accountRemoveAllFavouriteWallpapers => 'Eliminar todos los fondos favoritos';

  @override
  String get accountRemoveCoverPhoto => 'Eliminar foto de portada';

  @override
  String get accountRemoveFilesDownloadsOfflineStay =>
      'Eliminar archivos de Descargas; las copias guardadas sin conexión se conservan';

  @override
  String get accountRemoveLink => 'Eliminar enlace';

  @override
  String get accountRemovePhoto => 'Eliminar foto';

  @override
  String get accountRemoveSavedOffline => 'Eliminar contenido guardado sin conexión';

  @override
  String accountRemoveSavedOfflineCountMessage(String size) {
    return 'Se eliminarán $size de los originales guardados sin conexión. Las descargas, los borradores y los datos del catálogo no se modificarán.';
  }

  @override
  String get accountRemoveSavedOfflineMessage =>
      'Eliminar de este dispositivo los originales guardados sin conexión. Las descargas, los borradores y los datos del catálogo no se modificarán.';

  @override
  String get accountRemoveSavedOfflineQuestion => '¿Eliminar los fondos de pantalla guardados sin conexión?';

  @override
  String get accountReportAProblem => 'Informar de un problema';

  @override
  String accountReportPreviewNotice(String email) {
    return 'Este informe incluye la versión de la aplicación, los datos del dispositivo y los registros recientes. No contiene tu correo electrónico ni tokens de inicio de sesión. Léelo y compártelo con $email.';
  }

  @override
  String get accountReportProblemSubtitle => 'Compartir los registros de la aplicación con el equipo de Prism';

  @override
  String get accountReportUser => 'Denunciar usuario';

  @override
  String get accountReset => 'Restablecer';

  @override
  String get accountResetFilters => 'Restablecer filtros';

  @override
  String get accountResolution1080 => '1080p';

  @override
  String get accountResolution1440 => '1440p';

  @override
  String get accountResolution4k => '4K';

  @override
  String get accountRestorePurchases => 'Restaurar compras';

  @override
  String get accountRestoringPurchases => 'Restaurando compras…';

  @override
  String accountResultsForQuery(String query) {
    return 'Resultados para $query';
  }

  @override
  String get accountRetry => 'Reintentar';

  @override
  String get accountReviewOrChangeAdConsent => 'Revisar o cambiar tu consentimiento para los anuncios';

  @override
  String get accountReviewStatus => 'Estado de revisión';

  @override
  String get accountReviewSubmittedContent => 'Revisar el contenido enviado';

  @override
  String get accountSaveFavouritesAsFile => 'Guardar una copia de tus favoritos en un archivo';

  @override
  String get accountSavedOffline => 'Guardados sin conexión';

  @override
  String get accountSavedOfflineRemoved => 'Se eliminaron los fondos de pantalla guardados sin conexión.';

  @override
  String accountSavedOfflineStorageUnavailable(int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'Almacenamiento no disponible · límite de $limitString MiB';
  }

  @override
  String accountSavedOfflineStorageUsed(String size, int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$size usados · límite de $limitString MiB';
  }

  @override
  String get accountSavedOnThisDevice => 'Guardados en este dispositivo';

  @override
  String get accountSearch => 'Buscar';

  @override
  String get accountSearchByUsername => 'Buscar por nombre de usuario';

  @override
  String get accountSearchCreators => 'Buscar creadores';

  @override
  String get accountSearchCreatorsByName => 'Buscar creadores por nombre';

  @override
  String get accountSearchFilters => 'Filtros';

  @override
  String get accountSearchPrismUsersByName => 'Buscar usuarios de Prism por nombre';

  @override
  String get accountSearchWallpapers => 'Buscar fondos de pantalla';

  @override
  String get accountSeeChangelog => 'Ver el registro de cambios';

  @override
  String get accountSendGift => 'Enviar regalo';

  @override
  String get accountSendProfileLink => 'Enviar un enlace a tu perfil de Prism';

  @override
  String get accountSetUpQuickTiles => 'Configurar los accesos rápidos';

  @override
  String get accountSetUsername => 'Elegir nombre de usuario';

  @override
  String get accountSettings => 'Ajustes';

  @override
  String get accountShare => 'Compartir';

  @override
  String get accountShareInvite => 'Compartir invitación';

  @override
  String get accountSharePrism => 'Compartir Prism';

  @override
  String get accountSharePrismFriendSubtitle => 'Enviar un enlace a una amistad';

  @override
  String get accountShareProfile => 'Compartir perfil';

  @override
  String get accountShareProfileLinkFailed => 'No se pudo crear el enlace. Inténtalo de nuevo.';

  @override
  String get accountShareYourProfile => 'Compartir tu perfil';

  @override
  String get accountShop => 'Tienda';

  @override
  String get accountShowAnimeWallpapers => 'Mostrar fondos de pantalla de anime';

  @override
  String get accountShowSketchyWallpapers => 'Mostrar fondos de pantalla sugerentes';

  @override
  String get accountSignIn => 'Iniciar sesión';

  @override
  String get accountSignInAgainToDelete => 'Cierra sesión y vuelve a iniciarla; después, intenta eliminar tu cuenta.';

  @override
  String get accountSignInBenefits => 'Inicia sesión para conservar tus favoritos, monedas y perfil';

  @override
  String get accountSignInForInviteLink => 'Inicia sesión para obtener tu enlace de invitación.';

  @override
  String get accountSignInToPrism => 'Iniciar sesión en Prism';

  @override
  String get accountSocialGithub => 'GITHUB';

  @override
  String get accountSocialInstagram => 'INSTAGRAM';

  @override
  String get accountSocialTelegram => 'TELEGRAM';

  @override
  String get accountSocialTwitter => 'TWITTER';

  @override
  String get accountSomethingWentWrongTryAgain => 'Se ha producido un error. Inténtalo de nuevo.';

  @override
  String get accountSort => 'Ordenar';

  @override
  String get accountStorage => 'Almacenamiento';

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
  String get accountSubjectCanSitInFrontOfClock => 'El sujeto puede aparecer delante del reloj';

  @override
  String get accountSubjectInFrontOfClock => 'Sujeto delante del reloj';

  @override
  String get accountTerms => 'Condiciones';

  @override
  String get accountTermsAction => 'CONDICIONES';

  @override
  String accountTermsAgreementSemanticLabel(String terms, String privacy) {
    return 'Al continuar, aceptas $terms y $privacy';
  }

  @override
  String get accountTermsOfUse => 'Condiciones de uso';

  @override
  String get accountTheTeam => 'El equipo';

  @override
  String get accountThemes => 'Temas';

  @override
  String get accountThemesIconsFrames => 'Temas, iconos y marcos';

  @override
  String get accountThisUser => 'esta persona';

  @override
  String get accountTop => 'Más populares';

  @override
  String get accountTrackSubmittedWallpapers => 'Consulta el estado de los fondos de pantalla que has enviado';

  @override
  String get accountTrendingNow => 'Tendencias actuales';

  @override
  String get accountTryAgain => 'Intentar de nuevo';

  @override
  String get accountTryFewerFilters => 'Prueba con menos filtros.';

  @override
  String get accountTryShorterOrDifferentWord => 'Prueba con una palabra más corta o diferente.';

  @override
  String get accountUnblock => 'Desbloquear';

  @override
  String get accountUnblockUserMessage => 'Sus publicaciones volverán a aparecer en tu feed.';

  @override
  String accountUnblockUserTitle(String name) {
    return '¿Desbloquear a $name?';
  }

  @override
  String get accountUnfollow => 'Dejar de seguir';

  @override
  String accountUnfollowPerson(String name) {
    return 'Dejar de seguir a $name';
  }

  @override
  String accountUnfollowedPerson(String name) {
    return '¡Has dejado de seguir a $name!';
  }

  @override
  String get accountUnlimitedUploadsFilters => 'Subidas y filtros ilimitados';

  @override
  String get accountUploadFirstWallpaper => 'Sube tu primer fondo de pantalla para empezar tu galería.';

  @override
  String get accountUseShortcutsAutomation => 'Usar una automatización de Atajos';

  @override
  String accountUserBlocked(String name) {
    return 'Has bloqueado a $name';
  }

  @override
  String get accountUserUnblocked => 'Se ha desbloqueado a la persona';

  @override
  String accountVersionLabel(String version) {
    return 'Versión $version';
  }

  @override
  String get accountVibrateOnTapsAndActions => 'Vibrar al tocar y realizar acciones';

  @override
  String get accountWaitingToSync => 'Esperando a sincronizar';

  @override
  String get accountWallpaperHistory => 'Historial de fondos de pantalla';

  @override
  String get accountWallpaperManagerTagline => 'Un gestor de fondos de pantalla repleto de funciones.';

  @override
  String get accountWallpaperSourceNames => 'Prism usa Wallhaven y Pexels para ofrecer fondos de pantalla';

  @override
  String get accountWallpaperSources => 'Fuentes de fondos de pantalla';

  @override
  String get accountWallpaperSourcesMessage => 'Prism usa estos servicios para ofrecerte fondos de pantalla.';

  @override
  String get accountWallpapersSetBefore => 'Fondos de pantalla que ya has usado';

  @override
  String get accountWhatsNew => 'Novedades';

  @override
  String get accountWhatsNewAction => 'NOVEDADES';

  @override
  String get accountWriteBio => 'Escribir biografía';

  @override
  String accountYouBlockedUser(String name) {
    return 'Has bloqueado a $name';
  }

  @override
  String get accountYourContent => 'Tu contenido';

  @override
  String get accountYourProfile => 'tu perfil';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get actionDone => 'Listo';

  @override
  String get actionRetry => 'Intentar de nuevo';

  @override
  String get adminAllCaughtUp => 'Estás al día';

  @override
  String get adminAllUsers => 'Todos los usuarios';

  @override
  String get adminAnnouncementInbox => 'Anuncio (bandeja de entrada)';

  @override
  String get adminAnonymous => 'Anónimo';

  @override
  String get adminApprovalFailed => 'No se pudo aprobar. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get adminApprove => 'Aprobar';

  @override
  String get adminApproved => 'Aprobado';

  @override
  String get adminBackToReviewList => 'Volver a la lista de revisión';

  @override
  String get adminBatchActionFailed => 'No se pudo completar esta acción de revisión. Inténtalo de nuevo.';

  @override
  String get adminBatchComplete => 'Lote completado';

  @override
  String get adminBodyLabel => 'Cuerpo';

  @override
  String get adminBodyRequired => 'El cuerpo es obligatorio';

  @override
  String get adminBy => 'Por';

  @override
  String get adminByCollection => 'Por colección';

  @override
  String get adminByOperation => 'Por operación';

  @override
  String get adminBySourceTop15 => 'Por fuente (15 principales)';

  @override
  String get adminCancel => 'Cancelar';

  @override
  String get adminChangeDepthEffect => 'Cambiar el efecto de profundidad';

  @override
  String get adminCheckConnectionRetry => 'Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get adminClose => 'Cerrar';

  @override
  String adminContentTypeReport(String type) {
    return 'Informe de $type';
  }

  @override
  String get adminCopyAllData => 'Copiar todos los datos';

  @override
  String get adminCouldNotLoadWallpaper => 'No se pudo cargar el fondo de pantalla';

  @override
  String get adminCreatorWillSeeFeedback => 'El creador verá estos comentarios.';

  @override
  String get adminDepth => 'Profundidad';

  @override
  String adminDepthTier(String tier) {
    return 'Profundidad: $tier';
  }

  @override
  String get adminDepthTierAuto => 'Automático';

  @override
  String get adminDepthTierMenu => 'Menú';

  @override
  String get adminDepthTierNone => 'Ninguno';

  @override
  String get adminDepthTierNotChecked => 'Sin comprobar';

  @override
  String get adminDrop => 'Drop';

  @override
  String get adminEmail => 'Correo electrónico';

  @override
  String get adminEmailExample => 'user@example.com';

  @override
  String get adminEmailRequired => 'El correo electrónico es obligatorio';

  @override
  String get adminEstimatedDocumentReads => 'Lecturas de documentos estimadas';

  @override
  String get adminEstimatedDocumentWrites => 'Escrituras de documentos estimadas';

  @override
  String adminFactLabel(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminFirestoreTelemetry => 'Telemetría de Firestore';

  @override
  String get adminFollowersScreen => 'Pantalla de seguidores';

  @override
  String get adminFreeUsers => 'Usuarios gratuitos';

  @override
  String get adminGeneral => 'General';

  @override
  String get adminImageUrlOptional => 'URL de la imagen (opcional)';

  @override
  String get adminKeepWallpaper => 'Conservar fondo de pantalla';

  @override
  String get adminLast14Days => 'Últimos 14 días';

  @override
  String get adminList => 'Lista';

  @override
  String get adminLoadNextBatch => 'Cargar el siguiente grupo';

  @override
  String get adminLoadingNotificationCounts => 'Cargando recuentos de notificaciones.';

  @override
  String get adminMarkReviewed => 'Marcar como revisado';

  @override
  String get adminMarkReviewedFailed => 'No se pudo marcar el reporte como revisado. Inténtalo de nuevo.';

  @override
  String get adminMarkedReviewed => 'Marcado como revisado';

  @override
  String adminModerationDuplicate(int percent) {
    return 'Se parece a un fondo de Prism · $percent%';
  }

  @override
  String get adminModerationHint => 'Son solo pistas. Compruébalo antes de rechazar.';

  @override
  String adminModerationLogo(String logo) {
    return 'Logotipo: $logo';
  }

  @override
  String get adminModerationLogos => 'Logotipos';

  @override
  String get adminModerationOpenFailed => 'No se pudo abrir la página.';

  @override
  String adminModerationOpenPage(String host) {
    return 'Abrir $host';
  }

  @override
  String get adminModerationSignals => 'Señales de revisión';

  @override
  String get adminModerationSimilarWall => 'Fondo de Prism parecido';

  @override
  String adminModerationSimilarity(int percent) {
    return '$percent% parecido';
  }

  @override
  String adminModerationText(String words) {
    return 'Texto: $words';
  }

  @override
  String get adminModerationTextInImage => 'Texto en la imagen';

  @override
  String adminModerationUnsafe(String categories) {
    return 'No seguro: $categories';
  }

  @override
  String get adminModerationUnsafeCategories => 'Categorías no seguras';

  @override
  String adminModerationWeb(String host) {
    return 'Encontrado en $host';
  }

  @override
  String adminModerationWebMore(String host, int more) {
    return 'Encontrado en $host +$more';
  }

  @override
  String get adminModerationWebPages => 'Encontrado en la web';

  @override
  String get adminNewWallpapersPending => 'Los fondos nuevos aparecerán aquí cuando alguien suba uno.';

  @override
  String get adminNoNotificationCounts => 'Aún no hay recuentos de notificaciones.';

  @override
  String get adminNoOpenReports => 'No hay reportes abiertos';

  @override
  String get adminNoReasonGiven => 'No se indicó ningún motivo';

  @override
  String get adminNoTelemetryData => 'No hay datos de telemetría que copiar';

  @override
  String get adminNoTelemetryYet => 'Aún no hay telemetría';

  @override
  String get adminNoWallpapersPending => 'No hay fondos pendientes de revisión.';

  @override
  String get adminNothingToReview => 'No hay nada que revisar';

  @override
  String get adminNotificationCountExplanation =>
      'Aceptada significa que Firebase recibió la notificación push. Un envío al tema de la cuenta y otro al token del dispositivo cuentan como dos. No significa que se haya visto.';

  @override
  String get adminNotificationCountsLoadError => 'No se pudieron cargar los recuentos de notificaciones.';

  @override
  String get adminNotificationIrreversible =>
      'Esta notificación se enviará a todas las personas de este grupo. No podrás retirarla.';

  @override
  String get adminNotificationQueueFailed => 'No se pudo añadir la notificación a la cola. Inténtalo de nuevo.';

  @override
  String get adminNotificationQueued => 'Notificación añadida a la cola. La función de Cloud la enviará en breve.';

  @override
  String get adminNotifications => 'Notificaciones';

  @override
  String get adminOpenReportsLoadError => 'No se pudieron cargar los reportes abiertos.';

  @override
  String get adminOpenWallpaper => 'Abrir fondo de pantalla';

  @override
  String adminOperationCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString operaciones',
      one: '$countString operación',
    );
    return '$_temp0';
  }

  @override
  String get adminPendingWallsLoadError => 'No se pudieron cargar los fondos pendientes.';

  @override
  String get adminPremiumUsers => 'Usuarios Premium';

  @override
  String adminReadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString lecturas',
      one: '$countString lectura',
    );
    return '$_temp0';
  }

  @override
  String get adminReasonBlurry => 'Borrosa';

  @override
  String get adminReasonBlurryBody => 'La imagen está borrosa o muy comprimida. Sube una versión más nítida.';

  @override
  String get adminReasonCopyright => 'Derechos de autor';

  @override
  String get adminReasonCopyrightBody =>
      'Es posible que esta imagen sea obra de otra persona. Sube solo fondos que hayas creado o para los que tengas los derechos.';

  @override
  String get adminReasonDuplicate => 'Duplicada';

  @override
  String get adminReasonDuplicateBody => 'Este fondo es una copia de otro que ya está en Prism.';

  @override
  String get adminReasonHint => 'Explica qué se debe cambiar';

  @override
  String get adminReasonLabel => 'Motivo';

  @override
  String get adminReasonLowResolution => 'Baja resolución';

  @override
  String get adminReasonLowResolutionBody =>
      'La resolución es demasiado baja. Sube una imagen cuyo lado más corto mida al menos 1080 px.';

  @override
  String get adminReasonNotWallpaper => 'No es un fondo de pantalla';

  @override
  String get adminReasonNotWallpaperBody =>
      'Esta imagen no sirve como fondo de pantalla para un teléfono. Usa una imagen vertical que ocupe toda la pantalla.';

  @override
  String get adminReasonOther => 'Otro';

  @override
  String get adminReasonWatermark => 'Marca de agua';

  @override
  String get adminReasonWatermarkBody => 'La imagen tiene una marca de agua. Sube una versión sin ella.';

  @override
  String get adminRefresh => 'Actualizar';

  @override
  String get adminReject => 'Rechazar';

  @override
  String get adminRejectReasonRequired => 'Escribe un motivo antes de rechazar este elemento.';

  @override
  String get adminRejectSaveFailed => 'No se pudo guardar esta decisión. El motivo sigue aquí. Inténtalo de nuevo.';

  @override
  String get adminRejectWallpaper => 'Rechazar fondo de pantalla';

  @override
  String get adminRemove => 'Quitar';

  @override
  String get adminRemoveWallpaper => 'Quitar fondo de pantalla';

  @override
  String get adminRemovedFromNextDrop => 'Quitado del próximo Drop';

  @override
  String get adminReportDismissFailed => 'No se pudo descartar el reporte. Inténtalo de nuevo.';

  @override
  String get adminReportDismissedKept => 'Reporte descartado. Se conservó el fondo de pantalla.';

  @override
  String get adminReported => 'Reportado';

  @override
  String get adminReporter => 'Persona que lo reportó';

  @override
  String get adminReports => 'Reportes';

  @override
  String get adminReserve => 'Reservar';

  @override
  String get adminReserveForDrop => 'Reservar para Drop';

  @override
  String get adminReserveUpdateFailed => 'No se pudo actualizar la reserva de Drop. Inténtalo de nuevo.';

  @override
  String get adminReservedForNextDrop => 'Reservado para el próximo Drop';

  @override
  String get adminRetry => 'Reintentar';

  @override
  String adminReviewProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString/$totalString';
  }

  @override
  String get adminSendNotification => 'Enviar notificación';

  @override
  String adminSendToAudience(String audience) {
    return '¿Enviar a $audience?';
  }

  @override
  String get adminSkip => 'Omitir';

  @override
  String get adminSpecificUser => 'Usuario específico (correo electrónico)';

  @override
  String get adminSwipeInstructions => 'Desliza a la derecha para aprobar y a la izquierda para rechazar';

  @override
  String get adminSwipeReview => 'Revisión con deslizamiento';

  @override
  String get adminTarget => 'Destino';

  @override
  String get adminTelemetryCopied => 'Copiado al portapapeles. Pégalo en otro lugar para analizarlo.';

  @override
  String get adminTelemetryReadError => 'No se pudo leer la telemetría';

  @override
  String get adminTitle => 'Moderación de administración';

  @override
  String get adminTitleLabel => 'Título';

  @override
  String get adminTitleRequired => 'El título es obligatorio';

  @override
  String get adminTotalEvents => 'Total de eventos';

  @override
  String get adminTryAgain => 'Intentar de nuevo';

  @override
  String get adminUndo => 'Deshacer';

  @override
  String get adminUndoSuccessful => 'Se deshizo correctamente';

  @override
  String get adminUnknown => 'Desconocido';

  @override
  String get adminUnreserve => 'Cancelar reserva';

  @override
  String get adminUntitled => 'Sin título';

  @override
  String get adminUploaded => 'Subido';

  @override
  String get adminUseAppForEvents => 'Usa la aplicación para generar eventos de Firestore.';

  @override
  String get adminUserEmail => 'Correo electrónico del usuario';

  @override
  String get adminUserReportsShowHere => 'Los reportes de los usuarios aparecerán aquí.';

  @override
  String get adminValidEmailRequired => 'Introduce un correo electrónico válido';

  @override
  String get adminView => 'Ver';

  @override
  String get adminViewFullWallpaper => 'Ver el fondo de pantalla completo';

  @override
  String get adminWallId => 'ID';

  @override
  String get adminWallOfTheDay => 'Fondo del día';

  @override
  String get adminWallOrUpload => 'Fondo o subida';

  @override
  String get adminWallpaperAlreadyGone => 'El fondo ya no estaba. Se cerró el reporte.';

  @override
  String get adminWallpaperApproved => 'Fondo de pantalla aprobado';

  @override
  String get adminWallpaperFullScreen => 'Fondo de pantalla a pantalla completa';

  @override
  String get adminWallpaperRejected => 'Fondo de pantalla rechazado';

  @override
  String get adminWallpaperRemoved => 'Fondo de pantalla eliminado';

  @override
  String get adminWallpaperReport => 'Reporte de fondo de pantalla';

  @override
  String get adminWallpaperToReview => 'Fondo de pantalla por revisar';

  @override
  String adminWallpapersRemaining(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fondos de pantalla restantes',
      one: '$countString fondo de pantalla restante',
    );
    return '$_temp0';
  }

  @override
  String get adminWalls => 'Fondos';

  @override
  String adminWriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString escrituras',
      one: '$countString escritura',
    );
    return '$_temp0';
  }

  @override
  String get appLinkRetryWhenOnline => 'No hay conexión. Abriremos este enlace cuando vuelvas a estar conectado.';

  @override
  String get appTitle => 'Prism';

  @override
  String get coreBack => 'Atrás';

  @override
  String get coreBio => 'Biografía';

  @override
  String get coreBlockCreatorAfterReport => 'Bloquear también a este creador';

  @override
  String get coreBothScreens => 'ambas pantallas';

  @override
  String get coreCancel => 'Cancelar';

  @override
  String get coreCancelSelection => 'Cancelar selección';

  @override
  String get coreCancelSignIn => 'Ahora no';

  @override
  String get coreCategoryAbstract => 'Abstracto';

  @override
  String get coreCategoryAerial => 'Aéreo';

  @override
  String get coreCategoryAesthetic => 'Estética';

  @override
  String get coreCategoryAiArt => 'Arte con IA';

  @override
  String get coreCategoryAnimals => 'Animales';

  @override
  String get coreCategoryAnime => 'Anime';

  @override
  String get coreCategoryArchitecture => 'Arquitectura';

  @override
  String get coreCategoryArtistic => 'Artístico';

  @override
  String get coreCategoryBirds => 'Aves';

  @override
  String get coreCategoryCars => 'Coches';

  @override
  String get coreCategoryCity => 'Ciudad';

  @override
  String get coreCategoryClouds => 'Nubes';

  @override
  String get coreCategoryComic => 'Cómic';

  @override
  String get coreCategoryCyberpunk => 'Ciberpunk';

  @override
  String get coreCategoryDark => 'Oscuro';

  @override
  String get coreCategoryDefault => 'Categoría';

  @override
  String get coreCategoryFantasy => 'Fantasía';

  @override
  String get coreCategoryFashion => 'Moda';

  @override
  String get coreCategoryFlowers => 'Flores';

  @override
  String get coreCategoryFood => 'Comida';

  @override
  String get coreCategoryForest => 'Bosque';

  @override
  String get coreCategoryGalaxy => 'Galaxia';

  @override
  String get coreCategoryGaming => 'Videojuegos';

  @override
  String get coreCategoryGradient => 'Degradado';

  @override
  String get coreCategoryIllustration => 'Ilustración';

  @override
  String get coreCategoryKawaii => 'Kawaii';

  @override
  String get coreCategoryLandscape => 'Paisaje';

  @override
  String get coreCategoryMinimal => 'Minimalista';

  @override
  String get coreCategoryMusic => 'Música';

  @override
  String get coreCategoryNature => 'Naturaleza';

  @override
  String get coreCategoryNeon => 'Neón';

  @override
  String get coreCategoryOcean => 'Océano';

  @override
  String get coreCategoryPortraits => 'Retratos';

  @override
  String get coreCategoryQuotes => 'Frases';

  @override
  String get coreCategoryRender3d => 'Renderizado 3D';

  @override
  String get coreCategoryRobots => 'Robots';

  @override
  String get coreCategoryScenery => 'Paisajes';

  @override
  String get coreCategorySpace => 'Espacio';

  @override
  String get coreCategorySpiritual => 'Espiritualidad';

  @override
  String get coreCategorySports => 'Deportes';

  @override
  String get coreCategoryTech => 'Tecnología';

  @override
  String get coreCategoryTextures => 'Texturas';

  @override
  String get coreCategoryUnderTheSea => 'Bajo el mar';

  @override
  String get coreCategoryVehicles => 'Vehículos';

  @override
  String get coreCategoryVintage => 'Vintage';

  @override
  String get coreCategoryWarriors => 'Guerreros';

  @override
  String get coreChangeWallpaperTarget => 'Cambiar dónde se aplica el fondo de pantalla';

  @override
  String get coreChangelogLatest => 'Más reciente';

  @override
  String get coreChooseReportReason => 'Elige un motivo';

  @override
  String get coreChooseUsername => 'Elige un nombre de usuario disponible.';

  @override
  String get coreCoinAiWallpaper => 'Fondo de pantalla con IA';

  @override
  String get coreCoinAutoRotatePass => 'Pase de rotación automática, 7 días';

  @override
  String get coreCoinBadgeReward => 'Recompensa de insignia';

  @override
  String coreCoinBalance(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString monedas Prism';
  }

  @override
  String coreCoinBalanceChange(String balance, String change) {
    return '$balance, $change';
  }

  @override
  String get coreCoinBoost => 'Impulso';

  @override
  String get coreCoinCoins => 'Monedas';

  @override
  String get coreCoinCoinsReturned => 'Monedas devueltas';

  @override
  String get coreCoinCollectionPreview => 'Vista previa de la colección, 24 h';

  @override
  String get coreCoinDailyChest => 'Cofre diario';

  @override
  String get coreCoinDailyStreak => 'Racha diaria';

  @override
  String coreCoinDailyStreakDay(String day) {
    return 'Racha diaria, día $day';
  }

  @override
  String get coreCoinDay7Chest => 'Cofre del día 7';

  @override
  String get coreCoinDrawTicket => 'Boleto de sorteo';

  @override
  String get coreCoinDropPack => 'Paquete sorpresa';

  @override
  String get coreCoinDropWall => 'Fondo sorpresa';

  @override
  String get coreCoinFirstUpload => 'Primera subida';

  @override
  String get coreCoinGiftPass => 'Regalo: pase de 24 h';

  @override
  String get coreCoinInviteReward => 'Recompensa por invitación';

  @override
  String get coreCoinLiveWallpaperStyle => 'Estilo de fondo animado';

  @override
  String get coreCoinPremiumFilter => 'Filtro prémium';

  @override
  String get coreCoinPremiumWallpaper => 'Fondo prémium';

  @override
  String get coreCoinProDailyBonus => 'Bono diario Pro';

  @override
  String get coreCoinProSpin => 'Giro Pro';

  @override
  String get coreCoinProStreakBonus => 'Bono de racha Pro';

  @override
  String get coreCoinProfileComplete => 'Perfil completado';

  @override
  String get coreCoinQuest => 'Misión';

  @override
  String coreCoinRefund(String target) {
    return 'Reembolso: $target';
  }

  @override
  String get coreCoinShop => 'Tienda';

  @override
  String get coreCoinSpinWheel => 'Girar la ruleta';

  @override
  String get coreCoinStreakFreeze => 'Congelar racha';

  @override
  String get coreCoinStreakRestore => 'Restaurar racha';

  @override
  String get coreCoinWallpaperDownload => 'Descarga de fondo de pantalla';

  @override
  String get coreCoinWatchedVideo => 'Vídeo visto';

  @override
  String get coreCoinWeekBonus => 'Bono semanal';

  @override
  String get coreColorBlack => 'Negro';

  @override
  String get coreColorBlue => 'Azul';

  @override
  String get coreColorBrown => 'Marrón';

  @override
  String get coreColorGreen => 'Verde';

  @override
  String get coreColorGrey => 'Gris';

  @override
  String get coreColorOrange => 'Naranja';

  @override
  String get coreColorPink => 'Rosa';

  @override
  String get coreColorPurple => 'Morado';

  @override
  String get coreColorRed => 'Rojo';

  @override
  String get coreColorTeal => 'Verde azulado';

  @override
  String get coreColorWhite => 'Blanco';

  @override
  String get coreColorYellow => 'Amarillo';

  @override
  String get coreConfirmWallpaperPreview => 'Confirma el fondo de pantalla en la vista previa del sistema.';

  @override
  String get coreContentNotAvailable => 'Este elemento ya no está disponible';

  @override
  String get coreContentReportUser => 'usuario';

  @override
  String get coreContentReportWallpaper => 'fondo de pantalla';

  @override
  String coreContentReportWhy(String contentType) {
    return '¿Por qué denuncias este $contentType?';
  }

  @override
  String coreContentReportWhyWithDetails(String contentType, String details) {
    return '¿Por qué denuncias este $contentType ($details)?';
  }

  @override
  String get coreContinueWithApple => 'Continuar con Apple';

  @override
  String get coreContinueWithGoogle => 'Continuar con Google';

  @override
  String get coreContributorCouldNotLoad => 'No se pudo cargar este perfil';

  @override
  String get coreContributorGithub => 'GitHub';

  @override
  String get coreContributorTwitter => 'Twitter';

  @override
  String get coreContributorWebsite => 'Sitio web';

  @override
  String get coreCouldNotLoadChangelog => 'No se pudo cargar el registro de cambios';

  @override
  String get coreCouldNotLoadWallpaperForEditing => 'No se pudo cargar el fondo de pantalla para editarlo';

  @override
  String get coreCouldNotUpdateFavourites => 'No se pudieron actualizar tus favoritos. Inténtalo de nuevo.';

  @override
  String get coreCreatorPreviewDescription => 'Descubre este perfil de creador en Prism.';

  @override
  String get coreDefaultBanner => 'Únete a nuestro Telegram';

  @override
  String get coreDepthEffectAutoLongTip =>
      'El efecto de profundidad se activa automáticamente. En iOS 18 o versiones anteriores, deja libre de widgets el espacio debajo del reloj.';

  @override
  String get coreDepthEffectAutoTip => 'El efecto de profundidad se activa automáticamente.';

  @override
  String get coreDepthEffectBadge => 'Profundidad';

  @override
  String get coreDepthEffectBadgeSemantic => 'Compatible con el efecto de profundidad';

  @override
  String get coreDepthEffectMenuShortTip => 'Toca ••• y luego Efecto de profundidad.';

  @override
  String get coreDepthEffectMenuTip =>
      'En el editor de la pantalla de bloqueo, toca ••• y luego Efecto de profundidad.';

  @override
  String get coreDeviceCannotSetScreen => 'Este dispositivo no puede configurar esa pantalla.';

  @override
  String get coreDone => 'Listo';

  @override
  String coreDown(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'bajada de $coinsString';
  }

  @override
  String get coreDownloadNotFinishedCoinsReturned => 'La descarga anterior no se completó. Se devolvieron las monedas.';

  @override
  String get coreDownloadPrismPreviewDescription => 'Descarga Prism para descubrir fondos de pantalla increíbles.';

  @override
  String get coreEdit => 'Editar';

  @override
  String get coreEditBioHint => 'Cuéntales a los demás sobre ti…';

  @override
  String get coreEditDiscardBody => 'No se han guardado los cambios.';

  @override
  String get coreEditDiscardTitle => '¿Descartar los cambios?';

  @override
  String get coreEditEmailInvalid => 'Introduce una dirección de correo electrónico válida.';

  @override
  String coreEditKindLinkInvalid(String kind) {
    return 'Introduce un enlace de $kind válido.';
  }

  @override
  String get coreEditLinkInvalid => 'Introduce un enlace válido.';

  @override
  String get coreEditProfile => 'Editar perfil';

  @override
  String coreEditProfileLink(String kind) {
    return 'Enlace de $kind';
  }

  @override
  String get coreEditRemoveBioTitle => '¿Eliminar la biografía?';

  @override
  String get coreEditRemoveConfirm => 'Eliminar';

  @override
  String coreEditRemoveTitle(String item) {
    return '¿Eliminar $item?';
  }

  @override
  String get coreEditUsernameAvailable => 'Nombre de usuario disponible';

  @override
  String get coreEditUsernameChars => 'Usa solo letras, números y guiones bajos.';

  @override
  String get coreEditUsernameAllCaps => 'Usa al menos una letra minúscula.';

  @override
  String coreEditUsernameMinLength(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Usa al menos $lengthString caracteres.';
  }

  @override
  String coreEditUsernameRule(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Usa $lengthString o más letras, números o guiones bajos (_).';
  }

  @override
  String get coreEditUsernameTaken => 'Ese nombre de usuario ya está en uso.';

  @override
  String get coreEditUsernameTakenSemantic => 'Nombre de usuario en uso';

  @override
  String get coreFavourite => 'Favorito';

  @override
  String coreFileSizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String get coreGenericSignInError => 'Se produjo un error. ¡Inténtalo de nuevo!';

  @override
  String get coreGoHome => 'Ir al inicio';

  @override
  String get coreGooglePlayServicesSignInError =>
      'No se puede iniciar sesión con Google Play Services en este dispositivo.';

  @override
  String get coreGoogleSignInNetworkError =>
      'No se pudo iniciar sesión con Google. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get coreHomeScreen => 'pantalla de inicio';

  @override
  String get coreHomeScreenSetupUnavailable => 'Las configuraciones de la pantalla de inicio ya no están disponibles.';

  @override
  String get coreInvalidLinkBody => 'El enlace que abriste no es válido o ya no está disponible.';

  @override
  String coreInvitedToPrismTitle(String name) {
    return '$name te invitó a Prism';
  }

  @override
  String get coreIosWallpaperGuideBody =>
      'iOS no permite que las apps cambien el fondo de pantalla. Termina el proceso en Fotos:';

  @override
  String get coreJoinPrismPreviewTitle => 'Únete a Prism';

  @override
  String get coreKeepPrismOpen => 'Mantén Prism abierto e inténtalo de nuevo.';

  @override
  String get coreLoading => 'Cargando';

  @override
  String get coreLoadingMoreFailed => 'No se pudo cargar más. Toca para volver a intentarlo';

  @override
  String get coreLoadingWallpaper => 'Cargando fondo de pantalla';

  @override
  String get coreLockScreen => 'pantalla de bloqueo';

  @override
  String get coreMatchAccent => 'Usar el color de acento';

  @override
  String get coreName => 'Nombre';

  @override
  String get coreNoWallpaperUrl => 'No hay ninguna URL disponible para el fondo de pantalla';

  @override
  String get coreNotNow => 'Ahora no';

  @override
  String get coreOpenPhotos => 'Abrir Fotos';

  @override
  String get coreOpenSettings => 'Abrir ajustes';

  @override
  String get corePairPickerDownloads => 'Descargas';

  @override
  String get corePairPickerFavourites => 'Favoritos';

  @override
  String get corePairPickerHistory => 'Historial';

  @override
  String get corePairPickerNoDownloads => 'Aún no hay descargas.';

  @override
  String get corePairPickerNoFavourites => 'Aún no hay favoritos.';

  @override
  String get corePairPickerNoHistory => 'Aún no hay historial.';

  @override
  String get corePairPickerTitle => 'Elige un fondo para la pantalla bloqueada';

  @override
  String get corePairPickerUseWallpaper => 'Usar este fondo en la pantalla bloqueada';

  @override
  String get corePhotosPermissionMessage =>
      'Permite que Prism añada fotos desde Ajustes para guardar fondos de pantalla.';

  @override
  String get corePhotosStepOpen => 'Abre Fotos.';

  @override
  String get corePhotosStepShare => 'Toca Compartir.';

  @override
  String get corePhotosStepUseAsWallpaper => 'Toca Usar como fondo de pantalla.';

  @override
  String corePopupAppVersion(String version) {
    return 'Tienes la versión $version.';
  }

  @override
  String get corePopupCannotUndo => 'Esta acción no se puede deshacer.';

  @override
  String get corePopupCoverPhoto => 'foto de portada';

  @override
  String get corePopupDiscard => 'Descartar';

  @override
  String get corePopupProfilePhoto => 'foto de perfil';

  @override
  String get corePopupWhatsNew => 'Novedades';

  @override
  String get corePreviousWallpaperRestored => 'Se restauró el fondo de pantalla anterior';

  @override
  String get coreProfileSaveFailed => 'No se pudo guardar tu perfil. Inténtalo de nuevo.';

  @override
  String get coreProfileUpdated => 'Perfil actualizado';

  @override
  String coreReferralSaved(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Invitación guardada. Inicia sesión para reclamar +$coinsString monedas.';
  }

  @override
  String coreRelativeTimeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $countString días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeDaysFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString días', one: '1 día');
    return 'dentro de $_temp0';
  }

  @override
  String coreRelativeTimeHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $countString horas',
      one: 'hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeHoursFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString horas', one: '1 hora');
    return 'dentro de $_temp0';
  }

  @override
  String get coreRelativeTimeJustNow => 'Justo ahora';

  @override
  String coreRelativeTimeMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $countString minutos',
      one: 'hace 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String coreRelativeTimeMinutesFromNow(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString minutos', one: '1 minuto');
    return 'dentro de $_temp0';
  }

  @override
  String get coreRemoveBio => 'Eliminar biografía';

  @override
  String get coreReport => 'Denunciar';

  @override
  String get coreReportCouldNotSubmit => 'No se pudo enviar la denuncia. Inténtalo de nuevo.';

  @override
  String get coreReportDetailsHint => '¿Hay algo más que debamos saber?';

  @override
  String get coreReportDetailsOptional => 'Detalles (opcional)';

  @override
  String get coreReportReasonCopyright => 'Derechos de autor o propiedad';

  @override
  String get coreReportReasonHarassment => 'Acoso o discurso de odio';

  @override
  String get coreReportReasonOther => 'Otro';

  @override
  String get coreReportReasonSexual => 'Contenido sexual o para adultos';

  @override
  String get coreReportReasonSpam => 'Spam o contenido engañoso';

  @override
  String get coreReportSent => 'Denuncia enviada. Gracias.';

  @override
  String get coreRestorePreviousWallpaperFailed =>
      'No se pudo restaurar el fondo anterior. Vuelve a configurarlo desde el historial de fondos.';

  @override
  String get coreRetry => 'Volver a intentar';

  @override
  String get coreRetryImage => 'Volver a intentar la imagen';

  @override
  String coreRetryOnScreen(String screen) {
    return 'Volver a intentar en $screen';
  }

  @override
  String get coreSaveChanges => 'Guardar cambios';

  @override
  String get coreSeeFullChangelog => 'Ver el registro de cambios completo';

  @override
  String get coreSeeMore => 'Ver más';

  @override
  String coreSelectCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString seleccionados';
  }

  @override
  String get coreSendReport => 'Enviar denuncia';

  @override
  String get coreSet => 'Configurar';

  @override
  String get coreSetItAsWallpaper => 'Configúralo como fondo de pantalla';

  @override
  String get coreSetWallpaper => 'Configurar como fondo de pantalla';

  @override
  String coreSetWallpaperOn(String screen) {
    return 'Configurar como fondo de pantalla en $screen';
  }

  @override
  String get coreShare => 'Compartir';

  @override
  String coreShareCardClipboard(String link) {
    return '🔥¡Mira esto! ➜ $link';
  }

  @override
  String get coreShareFormatStory => 'Historia';

  @override
  String get coreShareFormatPost => 'Publicación';

  @override
  String get coreShareFormatClean => 'Minimalista';

  @override
  String get coreShareTargetInstagram => 'Instagram';

  @override
  String get coreShareTargetCopyLink => 'Copiar enlace';

  @override
  String get coreShareTargetSaveImage => 'Guardar imagen';

  @override
  String get coreShareTargetMore => 'Más';

  @override
  String coreShareCardBy(String creator) {
    return 'por $creator';
  }

  @override
  String get coreShareImageSaved => 'Imagen guardada';

  @override
  String get coreShareImageFailed => 'No se pudo guardar la imagen. Inténtalo de nuevo.';

  @override
  String get coreShareInstagramFailed => 'No se pudo abrir Instagram. Inténtalo de nuevo.';

  @override
  String get coreSharePreviewFailed => 'No se pudo crear esta imagen. Con Más se comparte el enlace en su lugar.';

  @override
  String get coreShareLinkCopied => '¡Se copió el enlace para compartir!';

  @override
  String coreShareProfileClipboard(String link) {
    return 'Mira mi perfil en Prism ➜ $link';
  }

  @override
  String coreShareWallpaperClipboard(String link) {
    return 'Mira esto ➜ $link';
  }

  @override
  String get coreShareWallpaperGeneric => 'Este fondo incluido está disponible en la app de Prism.';

  @override
  String get coreSignInFeatureBody => 'Tu cuenta reúne tus monedas, favoritos y subidas en un solo lugar.';

  @override
  String coreSignInFeatureTitle(String feature) {
    return 'Inicia sesión para usar $feature';
  }

  @override
  String get coreSignInPopupBody => 'Accede a tus favoritos, subidas y monedas desde cualquier dispositivo.';

  @override
  String get coreSignInPopupTitle => 'Inicia sesión en Prism';

  @override
  String get coreSignInPromptAction => 'Iniciar sesión';

  @override
  String get coreSignInToReportContent => 'Inicia sesión para denunciar contenido';

  @override
  String get coreSignInToSyncFavourites => 'Inicia sesión para tener tus favoritos en todos tus dispositivos';

  @override
  String get coreSigningIn => 'Iniciando sesión';

  @override
  String get coreSomethingWentWrong => 'Se produjo un error. Inténtalo de nuevo.';

  @override
  String coreStreakNext(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Siguiente: +$coinsString';
  }

  @override
  String coreStreakSemantics(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Racha de $daysString días; próxima recompensa: $coinsString monedas';
  }

  @override
  String get coreCustomAccent => 'Color personalizado';

  @override
  String get coreCustomAccentHex => 'Código hexadecimal';

  @override
  String get coreCustomAccentHue => 'Tono';

  @override
  String get coreCustomAccentSaturation => 'Saturación';

  @override
  String get coreCustomAccentLightness => 'Luminosidad';

  @override
  String get coreCustomAccentInvalidHex => 'Introduce 6 dígitos hexadecimales, como #E57697.';

  @override
  String get coreCustomAccentLowContrast => 'Este color se ve mal en este tema. Elige un tono más claro u oscuro.';

  @override
  String get coreCustomAccentApply => 'Usar color';

  @override
  String coreThemeAccentSemanticLabel(int index, int count) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Color de acento $indexString de $countString';
  }

  @override
  String get coreThemeAmoled => 'AMOLED';

  @override
  String get coreThemeCoffee => 'Café';

  @override
  String get coreThemeCottonBlue => 'Azul algodón';

  @override
  String get coreThemeCustom => 'Tema personalizado';

  @override
  String get coreThemeDeepOcean => 'Océano profundo';

  @override
  String get coreThemeFrostWhite => 'Blanco escarcha';

  @override
  String get coreThemeJungle => 'Selva';

  @override
  String get coreThemeLocked => 'Bloqueado';

  @override
  String get coreThemeMaterialDark => 'Material oscuro';

  @override
  String get coreThemeMaterialYou => 'Material You';

  @override
  String get coreThemeOlive => 'Oliva';

  @override
  String get coreThemePepper => 'Pimienta';

  @override
  String get coreThemeRose => 'Rosa';

  @override
  String get coreThemeSky => 'Cielo';

  @override
  String get coreThemeSteel => 'Acero';

  @override
  String get coreThemeSpooky => 'Terror';

  @override
  String get spookyBannerTitle => 'Llega el tema Terror';

  @override
  String get spookyBannerSubtitle => 'Naranja, negro y algunas arañas. Gratis. Toca para probarlo.';

  @override
  String get spookyAnnouncementTitle => 'Nuevo: el tema Terror 🎃';

  @override
  String get spookyAnnouncementBody => 'Naranja, negro y algunas arañas. Es gratis. Toca para probarlo.';

  @override
  String get coreThemeDiwali => 'Diwali';

  @override
  String get diwaliBannerTitle => 'Llegó el tema Diwali';

  @override
  String get diwaliBannerSubtitle => 'Diyas, fuegos artificiales y oro. Gratis. Toca para probarlo.';

  @override
  String get diwaliAnnouncementTitle => 'Nuevo: el tema Diwali 🪔';

  @override
  String get diwaliAnnouncementBody => 'Diyas, fuegos artificiales y oro. Es gratis. Toca para probarlo.';

  @override
  String get coreThisPageDoesNotExist => 'Esta página no existe';

  @override
  String get coreTryAgain => 'Volver a intentar';

  @override
  String get coreUndo => 'Deshacer';

  @override
  String coreUp(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'subida de $coinsString';
  }

  @override
  String get coreUploadFailureDailyLimit => 'Has alcanzado el límite de subidas de hoy. Inténtalo de nuevo mañana.';

  @override
  String get coreUploadFailureFileType =>
      'Este tipo de archivo no es compatible. Usa una imagen JPG, PNG, WebP o HEIC.';

  @override
  String get coreUploadFailureGeneric =>
      'No se completó la subida. Tu imagen sigue aquí, así que puedes volver a intentarlo.';

  @override
  String get coreUploadFailureInProgress => 'Ya hay una subida en curso. Espera un momento e inténtalo de nuevo.';

  @override
  String get coreUploadFailureOversize => 'Esta imagen supera los 15 MB. Elige una más pequeña.';

  @override
  String get coreUploadFailureSignIn => 'Vuelve a iniciar sesión para subirla.';

  @override
  String get coreUploadFailureWeeklyLimit => 'Has alcanzado el límite semanal de subidas gratuitas.';

  @override
  String get coreUploadSubmittedSuccess => 'Tu fondo se ha enviado y está en revisión.';

  @override
  String get coreUsername => 'Nombre de usuario';

  @override
  String get coreUsernameCheckFailed => 'No se pudo comprobar el nombre de usuario. Inténtalo de nuevo.';

  @override
  String get coreUsernameRequiredToShareProfile => 'Configura un nombre de usuario para compartir tu perfil';

  @override
  String get coreWallpaperApplied => '¡Fondo de pantalla configurado correctamente!';

  @override
  String get coreWallpaperBothScreens => 'Ambas pantallas';

  @override
  String coreWallpaperBySemanticLabel(String name) {
    return 'Fondo de pantalla de $name';
  }

  @override
  String get coreWallpaperDownloadedPictures => 'Fondo descargado en Pictures/Prism.';

  @override
  String get coreWallpaperEditApplyColorFailed => 'No se pudo aplicar el color. Inténtalo de nuevo.';

  @override
  String get coreWallpaperErrorGeneric => 'No se pudo configurar el fondo de pantalla.';

  @override
  String get coreWallpaperErrorImageTooLarge =>
      'Esta imagen es demasiado grande para usarla como fondo de pantalla en tu dispositivo.';

  @override
  String get coreWallpaperErrorInvalidVideo => 'No se puede usar ese video como fondo animado. Prueba con otro clip.';

  @override
  String get coreWallpaperErrorLiveGeneric => 'No se pudo configurar el fondo animado. Inténtalo de nuevo.';

  @override
  String get coreWallpaperErrorMemory => 'No hay suficiente memoria. Cierra otras apps e inténtalo de nuevo.';

  @override
  String get coreWallpaperErrorNotAllowed =>
      'Tu dispositivo o perfil de trabajo no permite cambiar el fondo de pantalla.';

  @override
  String get coreWallpaperErrorPermission => 'Prism no tiene permiso para leer ese archivo.';

  @override
  String get coreWallpaperErrorReadFile => 'No se pudo leer el archivo. Inténtalo de nuevo.';

  @override
  String get coreWallpaperErrorSourceTooLarge => 'Ese archivo es demasiado grande para usarlo como fondo animado.';

  @override
  String get coreWallpaperErrorStyle => 'Este dispositivo no pudo iniciar ese estilo. Prueba con otro.';

  @override
  String get coreWallpaperErrorSystemPreview => 'No se pudo abrir la vista previa del sistema.';

  @override
  String get coreWallpaperErrorTextureDimensions => 'Esa imagen es demasiado grande para usarla como fondo animado.';

  @override
  String get coreWallpaperErrorTimeout => 'Se agotó el tiempo de espera. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get coreWallpaperHomeScreen => 'Pantalla de inicio';

  @override
  String get coreWallpaperHomeSetLockFailed =>
      'Se configuró la pantalla de inicio, pero no se pudo configurar la pantalla de bloqueo.';

  @override
  String get coreWallpaperLinkCopyFailed => 'No se pudo copiar el enlace. Inténtalo de nuevo.';

  @override
  String get coreWallpaperLinkCreateFailed => 'No se pudo crear el enlace para compartir. Inténtalo de nuevo.';

  @override
  String get coreWallpaperLoadTimedOut =>
      'Se agotó el tiempo de espera al cargar el fondo de pantalla. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get coreWallpaperLockScreen => 'Pantalla de bloqueo';

  @override
  String get coreWallpaperOfflineUnavailable =>
      'Este fondo de pantalla no está guardado en este dispositivo. Conéctate a Internet e inténtalo de nuevo.';

  @override
  String coreWallpaperPartialSet(String applied, String failed) {
    return 'Se configuró $applied. No se pudo configurar $failed.';
  }

  @override
  String get coreWallpaperPreviewDescription => 'Mira este increíble fondo de pantalla de Prism.';

  @override
  String get coreWallpaperPreviewTitle => 'Fondo de pantalla en Prism';

  @override
  String get coreWallpaperSaveFailed => 'No se pudo configurar el fondo de pantalla. Inténtalo de nuevo.';

  @override
  String get coreWallpaperSavedPhotos => 'Guardado en Fotos.';

  @override
  String get coreWallpaperSavedToast => 'Se añadió la recompensa del anuncio.';

  @override
  String coreWallpaperSavedWithTip(String saved, String tip) {
    return '$saved $tip';
  }

  @override
  String get coreWallpaperSemanticLabel => 'Fondo de pantalla';

  @override
  String get coreWallpaperSet => 'Fondo de pantalla configurado';

  @override
  String get coreWallpaperShareFailed => 'No se pudo compartir este fondo de pantalla en este momento.';

  @override
  String get coreWallpaperShareRetryFailed => 'No se pudo compartir este fondo de pantalla. Inténtalo de nuevo.';

  @override
  String get debugAdminReviewDescription => 'Herramienta de moderación de contenido y notificaciones push';

  @override
  String get debugAdminShortcuts => 'Accesos directos de administración';

  @override
  String get debugLiveActivityPreview => 'Vista previa de Live Activity';

  @override
  String get debugLiveActivityPreviewDescription => 'Ejecuta una actividad de ejemplo: lista tras 8 segundos';

  @override
  String get debugLiveActivityUnavailable => 'Las Live Activities están desactivadas o no son compatibles';

  @override
  String get debugReviewActivityPreview => 'Vista previa de la actividad de la cola de revisión';

  @override
  String get debugReviewActivityPreviewDescription =>
      'Muestra los fondos de pantalla pendientes de revisión en la pantalla de bloqueo';

  @override
  String get debugAllTags => 'Todas las etiquetas';

  @override
  String get debugAndroidVersion => 'Versión de Android';

  @override
  String get debugAnimationSpeed => 'Velocidad de animación';

  @override
  String get debugAppInfo => 'Información de la app';

  @override
  String get debugAppName => 'Nombre de la app';

  @override
  String get debugAppVersion => 'Versión de la app';

  @override
  String get debugAutoScrollOff => 'Desactivar desplazamiento automático';

  @override
  String get debugAutoScrollOn => 'Activar desplazamiento automático';

  @override
  String debugBackendName(String backend) {
    return 'Backend: $backend';
  }

  @override
  String get debugBoard => 'Tablero';

  @override
  String get debugBrand => 'Marca';

  @override
  String get debugBuildNumber => 'Número de compilación';

  @override
  String get debugBuildSignature => 'Firma de compilación';

  @override
  String get debugCacheCleared => 'Se borró la caché de la app';

  @override
  String get debugCancel => 'Cancelar';

  @override
  String get debugCheckLogsRetry => 'Revisa los registros e inténtalo de nuevo.';

  @override
  String get debugClear => 'Borrar';

  @override
  String get debugClearAll => 'Borrar todo';

  @override
  String get debugClearAllStorageBody =>
      'Esto eliminará permanentemente todos los datos almacenados localmente. Es posible que la app no funcione correctamente hasta que la reinicies.';

  @override
  String get debugClearAllStorageTitle => '¿Borrar todo el almacenamiento?';

  @override
  String get debugClearAppCache => 'Borrar caché de la app';

  @override
  String get debugClearAppCacheDescription => 'Borrar la caché de imágenes, contenido y notificaciones';

  @override
  String get debugClearImageCache => 'Borrar caché de imágenes';

  @override
  String get debugClearImageCacheDescription => 'Vaciar la caché de imágenes en memoria';

  @override
  String get debugClearLogsBody => 'Esto eliminará todas las entradas del registro guardadas en memoria.';

  @override
  String get debugClearLogsTitle => '¿Borrar los registros?';

  @override
  String get debugClearSearch => 'Borrar búsqueda';

  @override
  String get debugCoins => 'Monedas';

  @override
  String get debugCopied => 'Copiado';

  @override
  String get debugCopiedToClipboard => 'Copiado al portapapeles';

  @override
  String get debugCopy => 'Copiar';

  @override
  String get debugCopyDiagnosticReport => 'Copiar informe de diagnóstico';

  @override
  String get debugCopyFiltered => 'Copiar todo (filtrado)';

  @override
  String get debugCopyFullDetail => 'Copiar todos los detalles';

  @override
  String debugCopyTitle(String title) {
    return 'Copiar $title';
  }

  @override
  String get debugCopyValue => 'Copiar valor';

  @override
  String debugCouldNotClearCache(String error) {
    return 'No se pudo borrar la caché de la app: $error';
  }

  @override
  String get debugCouldNotSaveValue => 'No se pudo guardar el valor';

  @override
  String get debugCrashApp => 'Provocar un fallo en la app';

  @override
  String get debugDangerZone => 'Zona de peligro';

  @override
  String get debugDarkCard => 'Tarjeta oscura';

  @override
  String get debugDefaultValue => '(predeterminado)';

  @override
  String get debugDelete => 'Eliminar';

  @override
  String get debugDeleteKey => 'Eliminar clave';

  @override
  String debugDeleteKeyBody(String key) {
    return 'Eliminar «$key» del almacenamiento local.';
  }

  @override
  String get debugDeleteKeyTitle => '¿Eliminar la clave?';

  @override
  String get debugDevice => 'Dispositivo';

  @override
  String get debugDeviceName => 'Dispositivo';

  @override
  String get debugDevicePixelRatio => 'Relación de píxeles del dispositivo';

  @override
  String get debugDiagnosticCopied => 'Informe de diagnóstico copiado al portapapeles';

  @override
  String get debugDiagnosticReportHeading => '=== Informe de diagnóstico de Prism ===';

  @override
  String get debugEditValue => 'Editar valor';

  @override
  String get debugEmail => 'Correo electrónico';

  @override
  String get debugEmptyList => 'Lista vacía';

  @override
  String get debugEnvironment => 'Entorno';

  @override
  String get debugError => 'Error';

  @override
  String get debugErrorCopied => 'Error copiado';

  @override
  String get debugErrorStreakLost => 'Error; racha perdida';

  @override
  String get debugErrorValue => 'error';

  @override
  String get debugExportFile => 'Exportar como archivo';

  @override
  String get debugFavouriteAdded => 'Añadido a favoritos';

  @override
  String get debugFilterByTag => 'Filtrar por etiqueta';

  @override
  String get debugFilterKeys => 'Filtrar claves';

  @override
  String get debugFingerprint => 'Huella digital';

  @override
  String get debugFirestoreTelemetryDescription => 'Ver el perfil de lecturas y escrituras de Firestore';

  @override
  String get debugFlagsReset => 'Se restablecieron los indicadores de depuración';

  @override
  String get debugForceCrash => 'Forzar fallo';

  @override
  String get debugForceCrashBody => 'Esto genera una excepción para comprobar que Sentry informa de los errores.';

  @override
  String get debugForceCrashDescription => 'Generar una excepción para probar los informes de Sentry';

  @override
  String get debugForceCrashTitle => '¿Forzar un fallo?';

  @override
  String debugGeneratedAt(String date) {
    return 'Generado: $date';
  }

  @override
  String get debugHardware => 'Hardware';

  @override
  String get debugIdentifier => 'Identificador';

  @override
  String get debugImageCacheCleared => 'Se borró la caché de imágenes';

  @override
  String get debugIsAdmin => 'Es administrador';

  @override
  String get debugIsPremium => 'Tiene Premium';

  @override
  String get debugLevel => 'Nivel';

  @override
  String get debugLightCard => 'Tarjeta clara';

  @override
  String get debugLoadingSearch => 'Cargando búsqueda';

  @override
  String get debugLogDetail => 'Detalle del registro';

  @override
  String debugLogEntryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString entradas',
      one: '$countString entrada',
    );
    return '$_temp0';
  }

  @override
  String get debugLoggedIn => 'Sesión iniciada';

  @override
  String get debugLoggingAndNetwork => 'Registros y red';

  @override
  String get debugLogicalSize => 'Tamaño lógico';

  @override
  String get debugLogs => 'Registros';

  @override
  String get debugLogsAppearHere => 'Las líneas del registro aparecerán aquí mientras se ejecuta la app.';

  @override
  String get debugMaintenance => 'Mantenimiento';

  @override
  String get debugManufacturer => 'Fabricante';

  @override
  String get debugMascot => 'Mascota';

  @override
  String get debugMessage => 'Mensaje';

  @override
  String get debugMixpanelEnabled => 'Mixpanel activado';

  @override
  String get debugMixpanelTokenPresent => 'Token de Mixpanel disponible';

  @override
  String get debugModel => 'Modelo';

  @override
  String get debugMoodCalm => 'Tranquilo';

  @override
  String get debugMoodCelebrate => 'Celebrar';

  @override
  String get debugMoodCurious => 'Curioso';

  @override
  String get debugMoodHappy => 'Feliz';

  @override
  String get debugMoodLove => 'Amor';

  @override
  String get debugMoodProud => 'Orgulloso';

  @override
  String get debugMoodSad => 'Triste';

  @override
  String get debugMoodSleepy => 'Soñoliento';

  @override
  String get debugMoodSurprised => 'Sorprendido';

  @override
  String get debugMoodWorried => 'Preocupado';

  @override
  String get debugName => 'Nombre';

  @override
  String get debugNoKeysFound => 'No se encontraron claves';

  @override
  String get debugNoLogs => 'No hay registros';

  @override
  String get debugNoMatchingLogs => 'Ninguna línea del registro coincide con los filtros.';

  @override
  String get debugNotAvailable => 'No disponible';

  @override
  String get debugNotSignedIn => 'No has iniciado sesión';

  @override
  String get debugNothingNew => 'Nada nuevo';

  @override
  String get debugOfflineStreakRisk => 'Sin conexión; la racha está en riesgo';

  @override
  String get debugPackage => 'Paquete';

  @override
  String get debugPackageName => 'Nombre del paquete';

  @override
  String get debugPaintBaselines => 'Mostrar líneas base';

  @override
  String get debugPaintBaselinesDescription => 'Mostrar guías de línea base del texto';

  @override
  String get debugPaintSize => 'Mostrar tamaños';

  @override
  String get debugPaintSizeDescription => 'Mostrar los límites de diseño de todos los widgets';

  @override
  String get debugPaintSizeWarning =>
      'Mostrar tamaños, áreas repintadas y líneas base solo funciona en compilaciones de depuración y perfil.';

  @override
  String get debugPerformanceOverlay => 'Superposición de rendimiento';

  @override
  String get debugPerformanceOverlayDescription => 'Gráficos de uso de GPU y CPU';

  @override
  String get debugPersistenceBackend => 'Backend de persistencia';

  @override
  String get debugPexelsKeyPresent => 'Clave de Pexels disponible';

  @override
  String get debugPhysicalDevice => 'Es un dispositivo físico';

  @override
  String get debugPhysicalSize => 'Tamaño físico';

  @override
  String get debugPlatform => 'Plataforma';

  @override
  String get debugRcApiKeyPresent => 'Clave de API de RC disponible';

  @override
  String get debugReduceMotionPose => 'Muestra la pose de movimiento reducido de cada estado de ánimo';

  @override
  String get debugRefresh => 'Actualizar';

  @override
  String get debugRemoteConfig => 'Configuración remota';

  @override
  String get debugRemoteConfigUnavailable => 'Configuración remota no disponible';

  @override
  String get debugRendering => 'Renderizado';

  @override
  String get debugRepaintRainbow => 'Arcoíris de repintado';

  @override
  String get debugRepaintRainbowDescription => 'Resaltar las áreas repintadas con colores que van cambiando';

  @override
  String get debugResetFlags => 'Restablecer todos los indicadores de depuración';

  @override
  String get debugResetFlagsDescription => 'Restaurar todos los interruptores a sus valores predeterminados';

  @override
  String get debugSave => 'Guardar';

  @override
  String get debugSaveValueAsText => 'Al guardar, el valor se escribe como texto.';

  @override
  String get debugScreen => 'Pantalla';

  @override
  String get debugSdkInt => 'Entero del SDK';

  @override
  String get debugSearchLogs => 'Buscar en los registros';

  @override
  String get debugSemanticsDebugger => 'Depurador de semántica';

  @override
  String get debugSemanticsDebuggerDescription => 'Superponer las etiquetas del árbol de accesibilidad';

  @override
  String get debugSentryDsnPresent => 'DSN de Sentry disponible';

  @override
  String get debugSentryEnabled => 'Sentry activado';

  @override
  String get debugSentryEnv => 'Entorno de Sentry';

  @override
  String get debugSequence => 'Secuencia';

  @override
  String get debugShowLogToasts => 'Mostrar avisos de registros';

  @override
  String get debugShowLogToastsDescription => 'Mostrar las entradas del registro como avisos breves superpuestos';

  @override
  String get debugSimulateNoInternet => 'Simular falta de Internet';

  @override
  String get debugSimulateNoInternetDescription =>
      'Fuerza las comprobaciones de conectividad a indicar que no hay conexión';

  @override
  String get debugSpeed => 'Velocidad';

  @override
  String get debugStackTrace => 'Seguimiento de pila';

  @override
  String get debugStackTraceCopied => 'Seguimiento de pila copiado';

  @override
  String get debugStillPoses => 'Poses estáticas';

  @override
  String get debugStorage => 'Almacenamiento';

  @override
  String get debugStorageCleared => 'Se borró todo el almacenamiento';

  @override
  String debugStorageKeyCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString claves',
      one: '$countString clave',
    );
    return '$_temp0';
  }

  @override
  String get debugStorageNotInitialized => 'El almacenamiento no está inicializado';

  @override
  String get debugStorageReadError => 'No se pudo leer el almacenamiento';

  @override
  String get debugStreakCoinsPurchase => 'Racha, monedas, compra';

  @override
  String get debugStreakKeptToday => 'Racha mantenida hoy';

  @override
  String get debugSubscriptionTier => 'Nivel de suscripción';

  @override
  String get debugSystemName => 'Nombre del sistema';

  @override
  String get debugSystemVersion => 'Versión del sistema';

  @override
  String get debugTime => 'Hora';

  @override
  String get debugTitle => 'Depuración';

  @override
  String get debugTools => 'Herramientas';

  @override
  String debugTypeName(String type) {
    return 'Tipo: $type';
  }

  @override
  String get debugUser => 'Usuario';

  @override
  String get debugUserId => 'ID de usuario';

  @override
  String get debugUsername => 'Nombre de usuario';

  @override
  String get debugValue => 'Valor';

  @override
  String get debugVersion => 'Versión';

  @override
  String get debugWallpaperSetSaved => 'Fondo de pantalla aplicado o guardado';

  @override
  String get debugWotdNotification => 'Fondo del día, notificación';

  @override
  String get deepLinkInputChooseImage => 'Elegir imagen';

  @override
  String get deepLinkInputChooseImageDescription => 'Elige una imagen de tu galería para continuar.';

  @override
  String get deepLinkInputClockPreviewTitle => 'Vista previa del reloj';

  @override
  String get deepLinkInputEditTitle => 'Editar un fondo de pantalla';

  @override
  String get deepLinkInputFiltersTitle => 'Filtros de fondos de pantalla';

  @override
  String get deepLinkInputGalleryError => 'No se pudo abrir la galería. Inténtalo de nuevo.';

  @override
  String get deepLinkInputLiveTitle => 'Fondo de pantalla animado';

  @override
  String get deepLinkInputPhotoPreviewTitle => 'Vista previa de la foto';

  @override
  String get deepLinkInputPositionTitle => 'Ajustar un fondo de pantalla';

  @override
  String get deepLinkInputUploadTitle => 'Subir un fondo de pantalla';

  @override
  String get deepLinkInputWallpaperPreviewTitle => 'Vista previa del fondo de pantalla';

  @override
  String get economyActivity => 'Actividad';

  @override
  String get economyActivityEmptyMessage => 'Mira un video o mantén tu racha para ganar tus primeras monedas.';

  @override
  String get economyActivityLoadFailed => 'No se pudo cargar la actividad.';

  @override
  String get economyAdCreditFailure => 'No se pudieron acreditar las monedas ahora.';

  @override
  String get economyAdDailyLimit => 'Alcanzaste el límite diario. Vuelve mañana.';

  @override
  String get economyAdNotCompleted => 'No se completó el anuncio.';

  @override
  String get economyAdOffline => 'No tienes conexión. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String economyAdRewardDetails(int first, int reward, int maximum) {
    final intl.NumberFormat firstNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String firstString = firstNumberFormat.format(first);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'El primero del día: +$firstString; después: +$rewardString. Hasta $maximumString al día.';
  }

  @override
  String get economyAdRewardPending =>
      'Aún no pudimos confirmar tu recompensa. Recibirás las monedas cuando vuelvas a tener conexión.';

  @override
  String get economyAdUnavailable => 'No hay anuncios disponibles ahora. Inténtalo más tarde.';

  @override
  String get economyAddPhotoBio => 'Añade una foto y una biografía';

  @override
  String get economyAddedToBalance => 'Añadido a tu saldo';

  @override
  String get economyAddedToCollection => 'Añadido a tu colección';

  @override
  String get economyAddedToXp => 'Añadido a tus XP';

  @override
  String get economyAdsOffPrivacy => 'Los anuncios están desactivados. Puedes cambiarlo en Ajustes > Privacidad.';

  @override
  String get economyAiBusyRefunded => 'La IA está muy ocupada ahora. Inténtalo más tarde. Te devolvimos las monedas.';

  @override
  String get economyAiChargeUnconfirmed =>
      'No se pudo confirmar el cobro. Te reembolsaremos las monedas que se hayan descontado.';

  @override
  String get economyAiCheckStatus => 'Comprobar estado';

  @override
  String economyAiCoinsNeeded(int cost, int balance) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Necesitas $costString monedas. Tienes $balanceString.';
  }

  @override
  String get economyAiConnectToGenerate => 'No hay conexión. Conéctate a Internet e inténtalo de nuevo.';

  @override
  String get economyAiCouldNotConfirmSubmission =>
      'No se pudo confirmar el envío. Comprueba el estado de revisión antes de volver a intentarlo.';

  @override
  String get economyAiCropMayDiffer => 'El recorte puede variar ligeramente en tu dispositivo.';

  @override
  String get aiLiveActivityGenerating => 'Creando tu fondo de pantalla';

  @override
  String get aiLiveActivityReady => 'Tu fondo de pantalla está listo';

  @override
  String get aiLiveActivityFailed => 'No se pudo crear';

  @override
  String get aiLiveActivityStale => 'Todavía trabajando en ello';

  @override
  String get aiLiveActivityOpen => 'Abrir en Prism';

  @override
  String get economyAiDailyLimit => 'Alcanzaste el límite diario de IA.';

  @override
  String get economyAiDescribeChanges => 'Indica qué quieres cambiar, como los colores, el ambiente o los detalles.';

  @override
  String get economyAiDescribeScene => 'Describe una escena para generar.';

  @override
  String get economyAiDownloadFailed => 'No se pudo descargar. Inténtalo de nuevo.';

  @override
  String economyAiFailureWithRefund(String message, String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'refunded': ' Se reembolsaron las monedas.',
      'pending': ' El reembolso está pendiente.',
      'other': ' No se pudo completar el reembolso.',
    });
    return '$message$_temp0';
  }

  @override
  String get economyAiGenerate => 'Generar';

  @override
  String get economyAiGenerateAnother => 'Generar otro';

  @override
  String get economyAiGenerateFailed => 'No se pudo generar ahora. Inténtalo de nuevo.';

  @override
  String get economyAiGenerateGenericFailure => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get economyAiGeneratedWallpaper => 'Fondo de pantalla generado';

  @override
  String economyAiGenerationFrom(String date) {
    return 'Generación del $date';
  }

  @override
  String get economyAiGenerationRollingOut =>
      'La generación con IA se está habilitando gradualmente. Inténtalo de nuevo pronto.';

  @override
  String get economyAiGenerationTime => 'Tarda unos 20 segundos';

  @override
  String get economyAiHistoryEmpty =>
      'Cada fondo de pantalla que generes aparecerá aquí para que puedas compararlo o volver a usarlo.';

  @override
  String get economyAiHistoryFailed => 'No se pudo cargar el historial. Desliza hacia abajo para actualizar.';

  @override
  String get economyAiMatchingScreenSize => 'Adaptando al tamaño de tu pantalla…';

  @override
  String get economyAiApplyingStyle => 'Aplicando tu estilo…';

  @override
  String get economyAiFinalizingWallpaper => 'Terminando tu fondo de pantalla…';

  @override
  String get economyAiRemixHint => 'Un cielo más oscuro, tonos más cálidos, bordes más suaves…';

  @override
  String economyAiNeedCoinsToGenerate(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Necesitas $costString monedas para generar.';
  }

  @override
  String economyNeedMoreCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Necesitas $countString monedas más.',
      one: 'Necesitas $countString moneda más.',
    );
    return '$_temp0';
  }

  @override
  String get economyAiNoConnection => 'No hay conexión. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get economyAiNoConnectionRetry => 'No hay conexión. Inténtalo de nuevo.';

  @override
  String get economyAiOfflineHistory =>
      'No tienes conexión o hubo un error de red. Desliza hacia abajo para actualizar cuando vuelvas a tener conexión.';

  @override
  String get economyAiOfflineSavedHistory => 'No tienes conexión. El historial guardado sigue disponible.';

  @override
  String get economyAiPaymentCheckFailed => 'No se pudo comprobar el pago. Te devolveremos las monedas.';

  @override
  String get economyAiPreparingShare => 'Preparando para compartir';

  @override
  String get economyAiPromptBlocked => 'No se permite esa descripción.';

  @override
  String economyAiPromptTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'La descripción es demasiado larga (máximo: $maximumString caracteres).';
  }

  @override
  String get economyAiQuality => 'Calidad';

  @override
  String get economyAiQualityBalanced => 'Equilibrada';

  @override
  String get economyAiQualityFast => 'Rápida';

  @override
  String get economyAiQualityHigh => 'Alta';

  @override
  String economyAiQualitySemantics(String quality, int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '$quality, $costString monedas';
  }

  @override
  String get economyAiRecent => 'Recientes';

  @override
  String get economyAiRefineExplanation =>
      'Indica qué quieres cambiar. Se generará un fondo nuevo con la misma descripción y una nueva semilla, así que puede verse bastante diferente.';

  @override
  String get economyAiResultBlocked => 'Se bloqueó el resultado. Prueba con otra descripción.';

  @override
  String economyAiRolloutBody(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Ya está disponible para el $percentString% de las cuentas. Inténtalo de nuevo pronto.';
  }

  @override
  String get economyAiRolloutTitle => 'La función de fondos con IA se está habilitando gradualmente';

  @override
  String get economyAiSave => 'Guardar';

  @override
  String get economyAiSaveFailed => 'No se pudo guardar el archivo. Inténtalo de nuevo.';

  @override
  String get economyAiSceneIdea => 'Idea de escena';

  @override
  String get economyAiSceneIdeaMessage => 'Usa esta escena en tu descripción (puedes editarla)';

  @override
  String get economyAiSetAsWallpaper => 'Establecer como fondo de pantalla';

  @override
  String get economyAiShare => 'Compartir';

  @override
  String get economyAiShareFailed => 'No se pudo compartir. Inténtalo de nuevo.';

  @override
  String get economyAiShareReviewNotice =>
      'Los moderadores revisan los envíos antes de que aparezcan en Prism. Comparte solo contenido sobre el que tengas derechos.';

  @override
  String get economyAiShareWithCommunity => '¿Compartir con la comunidad?';

  @override
  String get economyAiShuffle => 'Mezclar';

  @override
  String get economyAiShuffleMessage => 'Mostrar otra descripción de ejemplo';

  @override
  String get economyAiStillWorking => 'Todavía estamos procesando tu última imagen.';

  @override
  String get economyAiStyle => 'Estilo';

  @override
  String get economyAiStyleAbstract => 'Abstracto';

  @override
  String get economyAiStyleAnime => 'Anime';

  @override
  String get economyAiStyleCyberpunk => 'Ciberpunk';

  @override
  String get economyAiStyleMeshGradient => 'Degradado de malla';

  @override
  String get economyAiStyleMinimal => 'Minimalista';

  @override
  String get economyAiStyleNature => 'Naturaleza';

  @override
  String economyAiStyleSemantics(String style) {
    return 'Estilo: $style';
  }

  @override
  String get economyAiStyleWatercolor => 'Acuarela';

  @override
  String get economyAiStyleSpace => 'Espacio';

  @override
  String get economyAiStyleSynthwave => 'Synthwave';

  @override
  String get economyAiStylePixelArt => 'Pixel art';

  @override
  String get economyAiStyleRender3d => 'Render 3D';

  @override
  String get economyAiStyleOilPainting => 'Óleo';

  @override
  String get economyAiStyleUkiyoE => 'Ukiyo-e';

  @override
  String get economyAiSubmissionUnconfirmed =>
      'No se confirmó el estado del envío. Compruébalo antes de volver a intentarlo.';

  @override
  String get economyAiSubmitDisabled => 'El envío a la IA está desactivado por ahora.';

  @override
  String get economyAiSubmitFailed => 'No se pudo enviar. Inténtalo de nuevo.';

  @override
  String get economyAiSubmitForReview => 'Enviar para revisión de la comunidad';

  @override
  String get economyAiSubmitStatusUnconfirmed =>
      'No se confirmó el estado del envío. Comprueba el estado de revisión antes de volver a intentarlo.';

  @override
  String get economyAiSubmittedForReview => 'Enviado para revisión.';

  @override
  String get economyAiTryAgain => 'Intentar de nuevo';

  @override
  String get economyAiTryAnother => 'Probar otra';

  @override
  String get economyAiTryAnotherVersion => 'Probar otra versión';

  @override
  String get economyAiUnavailableBody => 'La desactivamos por un tiempo. Vuelve a consultar pronto.';

  @override
  String get economyAiUnavailableTitle => 'Los fondos con IA no están disponibles por ahora';

  @override
  String economyAiVariationTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'La descripción es demasiado larga (máximo: $maximumString caracteres).';
  }

  @override
  String get economyAiVariationUnavailable => 'La opción «Probar otra» no está disponible ahora.';

  @override
  String get economyAiWallpaper => 'Fondo de pantalla con IA';

  @override
  String get economyAiWatermarkNote => 'Las imágenes gratuitas incluyen una marca de agua de Prism. Pro la elimina.';

  @override
  String get economyAllRankRewardsCollected => 'Ya reclamaste todas las recompensas de rango';

  @override
  String get economyAllSpinsUsed => 'Ya usaste todos los giros';

  @override
  String get economyBackTomorrow => 'Vuelve mañana';

  @override
  String get economyBadge => 'Insignia';

  @override
  String get economyBadgeAiArtist => 'Artista de IA';

  @override
  String get economyBadgeAiArtistDescription => 'Genera 10 fondos de pantalla con IA';

  @override
  String get economyBadgeArtCurator => 'Curador de arte';

  @override
  String get economyBadgeArtCuratorDescription => 'Añade 50 fondos a tus favoritos';

  @override
  String get economyBadgeCollector => 'Coleccionista';

  @override
  String get economyBadgeCollectorDescription => 'Añade 10 fondos a tus favoritos';

  @override
  String get economyBadgeCreator => 'Creador';

  @override
  String get economyBadgeCreatorDescription => 'Consigue que aprueben un fondo de pantalla';

  @override
  String get economyBadgeDescription => 'Una insignia de Prism';

  @override
  String get economyBadgeEarned => 'Insignia obtenida';

  @override
  String economyBadgeEarnedCount(int count, int total) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Obtenidas: $countString de $totalString';
  }

  @override
  String economyBadgeName(String name) {
    return 'Insignia: $name';
  }

  @override
  String get economyBadgePrismVeteran => 'Veterano de Prism';

  @override
  String get economyBadgePrismVeteranDescription => 'Usa Prism durante 30 días y alcanza una racha de 7 días';

  @override
  String get economyBadgeProfileComplete => 'Perfil completo';

  @override
  String get economyBadgeProfileCompleteDescription =>
      'Añade una foto, un nombre de usuario, una biografía y un enlace';

  @override
  String economyBadgeSemantics(String name, String status, String description) {
    return '$name, $status. $description';
  }

  @override
  String get economyBadgeSocialButterfly => 'Mariposa social';

  @override
  String get economyBadgeSocialButterflyDescription => 'Sigue a 10 creadores';

  @override
  String get economyBadgeStatusEarned => 'Obtenida';

  @override
  String get economyBadgeStatusLocked => 'Bloqueada';

  @override
  String get economyBadgeStreakMaster => 'Maestro de las rachas';

  @override
  String get economyBadgeStreakMasterDescription => 'Alcanza una racha de 28 días';

  @override
  String get economyBadgeWeekWarrior => 'Guerrero semanal';

  @override
  String get economyBadgeWeekWarriorDescription => 'Alcanza una racha de 7 días';

  @override
  String get economyBadges => 'Insignias';

  @override
  String economyBalanceSemantics(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString monedas de Prism';
  }

  @override
  String economyBestStreak(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString días', one: '1 día');
    return 'Mejor racha: $_temp0';
  }

  @override
  String get economyBoost => 'Impulsar';

  @override
  String economyBoostInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Destaca uno de tus fondos aprobados al principio de Tendencias. Impulsarlo cuesta $amountString monedas. Abre el fondo y toca «Impulsar».';
  }

  @override
  String get economyBuildStreakDaily => 'Abre Prism todos los días para crear una racha.';

  @override
  String get economyBuy => 'Comprar';

  @override
  String get economyBuyPremium => 'Comprar Premium';

  @override
  String get economyCancel => 'Cancelar';

  @override
  String get economyChestBonusDone => 'Misión adicional completada: duplicaste tus monedas.';

  @override
  String get economyChestBonusToDouble => 'Completa primero la misión adicional de hoy para duplicar tus monedas.';

  @override
  String economyChestBoosterSemantics(String title, String caption) {
    return '$title. $caption';
  }

  @override
  String economyChestCoinsPrize(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString monedas', one: '1 moneda');
    return '$_temp0';
  }

  @override
  String get economyChestDoFirst => 'Haz esto primero para duplicar el contenido del cofre';

  @override
  String get economyChestDoubled => 'Cofre duplicado';

  @override
  String get economyChestDoubledByBonus => ' Duplicado por tu misión adicional.';

  @override
  String get economyChestFreeToday => 'Gratis hoy';

  @override
  String economyChestNeedCoins(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'El cofre cuesta $priceString monedas. Tienes $balanceString. Mira un video para ganar más.';
  }

  @override
  String economyChestNewCosmetic(String kind, String name) {
    return 'un nuevo artículo de $kind: $name';
  }

  @override
  String economyChestNewKind(String kind) {
    return 'Nuevo artículo de $kind';
  }

  @override
  String get economyChestOpenFailed => 'No se pudo conectar con Prism. Inténtalo de nuevo.';

  @override
  String economyChestOpenFor(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString misiones más',
      one: '1 misión más',
    );
    return 'Ábrelo por $priceString monedas o completa $_temp0 para abrirlo gratis.';
  }

  @override
  String get economyChestOpened => 'Abierto';

  @override
  String get economyChestOpenedDoubledTomorrow => 'Abierto y duplicado. Habrá otro mañana.';

  @override
  String economyChestOpenedReset(String time) {
    return 'Abierto. Habrá un cofre nuevo en $time.';
  }

  @override
  String get economyChestOpenedTomorrow => 'Abierto. Habrá otro mañana.';

  @override
  String get economyChestOwnCosmeticCoins => 'Ya tienes todos los artículos cosméticos, así que recibirás monedas';

  @override
  String get economyChestOwnEveryCosmetic => 'Ya tienes todos los artículos cosméticos';

  @override
  String get economyChestPriceChanged => 'El precio cambió. Compruébalo y vuelve a abrirlo.';

  @override
  String economyChestPriceFreeAfter(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString misiones más',
      one: '1 misión más',
    );
    return '$priceString monedas o gratis al completar $_temp0';
  }

  @override
  String economyChestPrizeSemantics(String tier, String prize, String doubled, int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(doubled, {'true': ' Duplicado por tu misión adicional.', 'other': ''});
    String _temp1 = intl.Intl.pluralLogic(
      xp,
      locale: localeName,
      other: ' Además, $xpString XP.',
      one: ' Además, 1 XP.',
      zero: '',
    );
    return '$tier. Ganaste $prize.$_temp0$_temp1';
  }

  @override
  String get economyChestQuestsFree => 'Tus misiones hicieron que hoy fuera gratis.';

  @override
  String get economyChestReady => 'Listo para abrir';

  @override
  String economyChestReadyPaid(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Listo para abrir. Completaste $doneString de $totalString misiones';
  }

  @override
  String economyChestResetHours(int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$hoursString h';
  }

  @override
  String economyChestResetHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$hoursString h $minutesString min';
  }

  @override
  String economyChestResetMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$minutesString min';
  }

  @override
  String get economyChestTierCommon => 'Común';

  @override
  String get economyChestTierEpic => 'Épico';

  @override
  String get economyChestTierLegendary => 'Legendario';

  @override
  String get economyChestTierRare => 'Raro';

  @override
  String economyChestXpLine(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Al abrirlo, obtendrás $xpString XP.';
  }

  @override
  String get economyClaimedTodayDay7Chest => 'Por hoy terminaste. Vuelve mañana para recibir el cofre del día 7.';

  @override
  String economyClaimedTodayReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Por hoy terminaste. Vuelve mañana para recibir +$coinsString monedas.';
  }

  @override
  String get economyClosePreview => 'Cerrar vista previa';

  @override
  String economyCoinActivitySemantics(String label, String date, String amount, int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'monedas', one: 'moneda');
    return '$label, $date, $amount $_temp0';
  }

  @override
  String economyCoinBalance(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Saldo: $balanceString';
  }

  @override
  String economyCoinGateRefundUnconfirmed(String action) {
    return '$action. No se pudo confirmar tu reembolso.';
  }

  @override
  String economyCoinGateRefunded(String action, int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Se reembolsaron $coinsString monedas.',
      one: 'Se reembolsó 1 moneda.',
    );
    return '$action. $_temp0';
  }

  @override
  String get economyCoinHistoryEarned => 'Ganadas';

  @override
  String get economyCoinHistoryEmpty => 'Aún no hay actividad con monedas.';

  @override
  String get economyCoinHistoryLoadFailed => 'No se pudo cargar tu historial de monedas.';

  @override
  String get economyCoinHistoryNoLoadedRows => 'No hay nada en las filas cargadas hasta ahora.';

  @override
  String get economyCoinHistoryNothingHere => 'Aún no hay nada aquí.';

  @override
  String get economyCoinHistoryRefunds => 'Reembolsos';

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
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'monedas', one: 'moneda');
    return '$label$_temp0, $date, $amount $_temp1, $balance';
  }

  @override
  String get economyCoinHistorySpent => 'Gastadas';

  @override
  String get economyCoinHistoryTitle => 'Historial de monedas';

  @override
  String get economyCoinSpendFailed => 'No se pueden procesar las monedas en este momento.';

  @override
  String economyCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString monedas', one: '1 moneda');
    return '$_temp0';
  }

  @override
  String get economyCoinsAreYoursToSpend => 'Puedes gastar tus monedas como quieras';

  @override
  String economyCoinsEarned(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString monedas', one: '1 moneda');
    return '+$_temp0';
  }

  @override
  String economyCoinsRange(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '+$minimumString a +$maximumString';
  }

  @override
  String get economyCoinsSpendingDetails =>
      'Usa monedas para conseguir fondos de pantalla, herramientas y artículos de la tienda. Los XP indican tu progreso, no son un saldo que puedas gastar. Gastar monedas nunca reduce tus XP.';

  @override
  String get economyCoinsWhatYouCanDo => 'En qué puedes usarlas';

  @override
  String get economyCoinsWord => 'monedas';

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
      'true': ', o usa $coinsString monedas para desbloquearlo ahora',
      'other': '',
    });
    return 'Mantén una racha de $daysString días para desbloquear este fondo de pantalla$_temp0.';
  }

  @override
  String get economyCollectionLoadFailed => 'No se pudo cargar esta colección';

  @override
  String economyCollectionNeedCoinsMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Necesitas $coinsString monedas para desbloquear este fondo de pantalla.';
  }

  @override
  String get economyCollectionRequirementsUnmet => 'Este fondo de pantalla aún no está disponible.';

  @override
  String get economyCollectionStillLocked => 'Aún está bloqueado';

  @override
  String economyCollectionUnlockedAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Desbloqueado al alcanzar una racha de $daysString días';
  }

  @override
  String get economyCollectionUnlockedWithCoins => 'Desbloqueado con monedas';

  @override
  String economyCollectionUnlocksAtCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Se desbloquea por $coinsString monedas';
  }

  @override
  String economyCollectionUnlocksAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Se desbloquea al alcanzar una racha de $daysString días';
  }

  @override
  String get economyCompleteProfile => 'Completa tu perfil';

  @override
  String get economyCosmetic => 'elemento cosmético';

  @override
  String get economyCosmeticAppIcon => 'icono de la app';

  @override
  String get economyCosmeticFrame => 'marco';

  @override
  String get economyCosmeticNameGlow => 'brillo del nombre';

  @override
  String get economyCosmeticTheme => 'tema';

  @override
  String economyCountdownDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$daysString d $hoursString h';
  }

  @override
  String economyCountdownHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$hoursString h $minutesString min';
  }

  @override
  String economyCountdownMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '$minutesString min';
  }

  @override
  String get economyCreatorApprovedWalls => 'Fondos de pantalla aprobados';

  @override
  String get economyCreatorIntro =>
      'Gana XP cuando aprueben tus fondos de pantalla y cuando los nuevos miembros los añadan a favoritos. Tu progreso aparecerá tras tu primera contribución válida.';

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
    return 'Hito de $label';
  }

  @override
  String get economyCreatorMilestones => 'Hitos de creador';

  @override
  String economyCreatorMilestonesComplete(String label) {
    return 'Hitos de $label completados';
  }

  @override
  String economyCreatorNewMembersThisWeek(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString miembros nuevos añadieron tus fondos de pantalla a favoritos esta semana';
  }

  @override
  String economyCreatorNextMilestone(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Siguiente hito: +$xpString XP';
  }

  @override
  String economyCreatorProgressSemantics(int current, int target) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat targetNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String targetString = targetNumberFormat.format(target);

    return '$currentString de $targetString';
  }

  @override
  String get economyCreatorQualifyingMembers => 'Miembros que cumplen los requisitos';

  @override
  String get economyCreatorRefresh => 'Actualizar progreso';

  @override
  String get economyCreatorRefreshing => 'Actualizando el progreso de creador…';

  @override
  String get economyCreatorRules =>
      'Los fondos de pantalla aprobados deben ser subidas propias que cumplan los requisitos. Es posible que las subidas antiguas no sean válidas si Prism no puede verificar quién las subió originalmente. Cada miembro cuenta una sola vez entre todos tus trabajos válidos, cuando añade por primera vez uno de ellos a favoritos y cumple los requisitos. Debe haber iniciado sesión, tener el correo verificado y una cuenta de al menos siete días. Tus propios favoritos no cuentan. Las cifras son históricas, no representan tu audiencia actual. Si alguien quita un favorito, no se restan los XP. Los hitos de creador otorgan XP adicionales. Las semanas van de lunes a domingo según la hora UTC; la actividad puede aparecer con retraso en una semana posterior.';

  @override
  String get economyCreatorSavedRefresh => 'Progreso guardado. Actualiza para ver los cambios.';

  @override
  String get economyCreatorSavedUnavailable => 'Progreso guardado. No se puede actualizar ahora.';

  @override
  String economyCreatorThisWeekSummary(int walls, int xp) {
    final intl.NumberFormat wallsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String wallsString = wallsNumberFormat.format(walls);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$wallsString fondos de pantalla válidos aprobados · $xpString XP por hitos';
  }

  @override
  String economyCreatorTrackingSince(String date) {
    return 'Seguimiento desde $date UTC';
  }

  @override
  String get economyCreatorUnavailable => 'El progreso de creador no está disponible.';

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

    return '$wallsString fondos de pantalla válidos aprobados · $membersString miembros nuevos que cumplen los requisitos · $xpString XP por hitos';
  }

  @override
  String get economyCreatorWhatCounts => 'Qué cuenta y el historial';

  @override
  String get economyDailyChest => 'Cofre diario';

  @override
  String economyDailyChestSemantics(String state, String caption, String hasXp, String xpLine) {
    String _temp0 = intl.Intl.selectLogic(hasXp, {'true': '. $xpLine', 'other': ''});
    return 'Cofre diario, $state. $caption$_temp0';
  }

  @override
  String get economyDailyChestTitle => 'Cofre diario';

  @override
  String get economyDailyQuests => 'Misiones diarias';

  @override
  String get economyDailyStreak => 'Racha diaria';

  @override
  String get economyDay7Chest => 'Cofre del día 7';

  @override
  String economyDayLabel(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Día $dayString';
  }

  @override
  String economyDayStreakMilestone(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return '¡Racha de $daysString días!';
  }

  @override
  String economyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'días', one: 'día');
    return '$_temp0';
  }

  @override
  String economyDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $countString días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String get economyDownload => 'Descargar';

  @override
  String get economyDownloadAccountChanged => 'La cuenta ha cambiado. Vuelve a intentar guardar.';

  @override
  String get economyDownloadAgain => 'Descargar de nuevo';

  @override
  String economyDownloadAgainCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Descargar de nuevo (-$costString monedas)';
  }

  @override
  String get economyDownloadAlreadyInDownloads => 'Ya está en Descargas';

  @override
  String economyDownloadCoinsNeeded(int missing, int reward, String watch, String adState) {
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(watch, {'true': ' Cada anuncio te da $rewardString.', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(adState, {
      'disabled': ' Los anuncios están desactivados. Puedes cambiarlo en Ajustes > Privacidad.',
      'limit': ' Has alcanzado el límite diario. Vuelve mañana.',
      'other': '',
    });
    return 'Necesitas $missingString monedas más para guardar este fondo de pantalla.$_temp0$_temp1';
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

    return '$label. Cuesta $costString monedas';
  }

  @override
  String get economyDownloadFailedLabel => 'No se pudo descargar';

  @override
  String economyDownloadFreeDownloadsLeftSemantics(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'quedan $countString descargas gratis',
      one: 'queda 1 descarga gratis',
    );
    return '$label. Gratis, $_temp0';
  }

  @override
  String economyDownloadFreeFor(String label) {
    return '$label · Gratis';
  }

  @override
  String economyDownloadFreeLeftFor(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label · Gratis · quedan $countString';
  }

  @override
  String economyDownloadFreeOwnedSemantics(String label) {
    return '$label. Gratis, este fondo de pantalla es tuyo';
  }

  @override
  String economyDownloadFreeWithPassSemantics(String label) {
    return '$label. Gratis con tu pase';
  }

  @override
  String get economyDownloadFreeWithPro => 'Gratis con Pro';

  @override
  String economyDownloadFreeWithProSemantics(String label) {
    return '$label. Gratis con Pro';
  }

  @override
  String get economyDownloadLinkUnavailable => 'No hay ningún enlace de descarga disponible.';

  @override
  String get economyDownloadProGuestMessage =>
      'Inicia sesión para guardar este fondo de pantalla con monedas o consigue Prism Pro.';

  @override
  String get economyDownloadSaveLocalCopy => 'Guardar una copia local';

  @override
  String get economyDownloadSaved => 'Guardado';

  @override
  String get economyDownloadSavedBefore => 'Ya habías guardado este fondo de pantalla.';

  @override
  String get economyDownloadSavedInDownloads => 'Guardado. Ya está en Descargas';

  @override
  String get economyDownloadThisWallpaper => 'Descargar este fondo de pantalla';

  @override
  String get economyDownloadWaitForCurrent => '¡Espera a que termine la descarga!';

  @override
  String get economyDownloadWatchAdMessage => 'Mira un breve anuncio de video para descargar este fondo de pantalla.';

  @override
  String get economyDownloadWatchAdPrivacyMessage =>
      'Mira un breve anuncio de vídeo para descargar este fondo de pantalla. Los anuncios están desactivados. Puedes cambiarlo en Ajustes > Privacidad.';

  @override
  String get economyDownloads => 'Descargas';

  @override
  String economyDownloadsInfo(int amount, int freeCount, String hasFree) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat freeCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String freeCountString = freeCountNumberFormat.format(freeCount);

    String _temp0 = intl.Intl.selectLogic(hasFree, {'true': ' Las primeras $freeCountString son gratis.', 'other': ''});
    return 'Cada descarga de un fondo de pantalla cuesta $amountString monedas.$_temp0 Con Pro, las descargas son gratis.';
  }

  @override
  String economyDrawAllTicketsHeld(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Ya tienes los $maximumString boletos permitidos esta semana.';
  }

  @override
  String economyDrawBuyTicket(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Comprar un boleto · $priceString';
  }

  @override
  String get economyDrawClosed => 'El sorteo está cerrado. El próximo empieza el lunes.';

  @override
  String economyDrawClosesIn(String time) {
    return 'Cierra en $time';
  }

  @override
  String get economyDrawLastWinner => 'Último ganador';

  @override
  String get economyDrawLoadFailed => 'No se pudo cargar el sorteo';

  @override
  String get economyDrawNotEnoughCoins => 'No tienes suficientes monedas para comprar un boleto.';

  @override
  String get economyDrawNotOpen => 'El sorteo aún no está abierto.';

  @override
  String get economyDrawOfficialRules => 'Reglas oficiales';

  @override
  String economyDrawPrizeDescription(int months) {
    final intl.NumberFormat monthsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(months, locale: localeName, other: '$monthsString meses', one: '1 mes');
    return '$_temp0 de Pro + el marco de Prism';
  }

  @override
  String get economyDrawProNotEligible => 'Los miembros de Pro no pueden participar.';

  @override
  String get economyDrawPurchaseFailed => 'No se pudo comprar el boleto. Inténtalo de nuevo.';

  @override
  String get economyDrawThisWeeksPrize => 'PREMIO DE ESTA SEMANA';

  @override
  String economyDrawTicketBought(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Boleto comprado. Tienes $ticketsString de $maximumString.';
  }

  @override
  String economyDrawTicketCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Los boletos cuestan $priceString monedas';
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
      other: '$ticketsString boletos',
      one: '1 boleto',
    );
    String _temp1 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$peopleString personas',
      one: '1 persona',
    );
    return '$_temp0 de $_temp1';
  }

  @override
  String get economyDrawTitle => 'Sorteo de Prism';

  @override
  String economyDrawYourChance(int mine, int pot) {
    final intl.NumberFormat mineNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String mineString = mineNumberFormat.format(mine);
    final intl.NumberFormat potNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String potString = potNumberFormat.format(pot);

    return 'Tu probabilidad: $mineString/$potString';
  }

  @override
  String economyDrawYourTickets(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Tus boletos: $ticketsString de $maximumString';
  }

  @override
  String get economyDropAlreadyUnlocked => 'Ya tienes este elemento.';

  @override
  String economyDropByCreator(String creator) {
    return 'de $creator';
  }

  @override
  String economyDropCardSemantics(String time, int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Drop semanal, $time, $unlockedString de $totalString recopilados';
  }

  @override
  String economyDropCarouselDetail(int count, String time) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fondos de pantalla',
      one: '1 fondo de pantalla',
    );
    return '$_temp0 · $time';
  }

  @override
  String economyDropCarouselSemantics(String title, String detail, String lastCall) {
    String _temp0 = intl.Intl.selectLogic(lastCall, {'true': ', última oportunidad', 'other': ''});
    return 'Drop semanal, $title, $detail$_temp0';
  }

  @override
  String economyDropCollected(int owned, int total) {
    final intl.NumberFormat ownedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ownedString = ownedNumberFormat.format(owned);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$ownedString de $totalString recopilados';
  }

  @override
  String economyDropDates(String start, String end) {
    return '$start a $end';
  }

  @override
  String get economyDropEnded => 'Finalizado';

  @override
  String get economyDropEndedHeadline => 'Este Drop ha terminado';

  @override
  String economyDropEndsInDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$daysString d', one: '1 d');
    String _temp1 = intl.Intl.pluralLogic(hours, locale: localeName, other: '$hoursString h', one: '1 h');
    return 'Termina en $_temp0 $_temp1';
  }

  @override
  String economyDropEndsInHoursMinutes(int hours, int minutes) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    String _temp0 = intl.Intl.pluralLogic(hours, locale: localeName, other: '$hoursString h', one: '1 h');
    String _temp1 = intl.Intl.pluralLogic(minutes, locale: localeName, other: '$minutesString min', one: '1 min');
    return 'Termina en $_temp0 $_temp1';
  }

  @override
  String economyDropEndsInMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return 'Termina en $minutesString min';
  }

  @override
  String get economyDropGone => 'Este Drop ya no está disponible';

  @override
  String get economyDropLastCallLabel => 'Última oportunidad';

  @override
  String get economyDropLoadFailed => 'No se pudo cargar The Drop';

  @override
  String get economyDropLocked => 'Bloqueado';

  @override
  String get economyDropMissed => 'No conseguido';

  @override
  String get economyDropOver => 'Este Drop ha terminado.';

  @override
  String get economyDropPastDrops => 'Drops anteriores';

  @override
  String economyDropPosition(int index, int total) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$indexString de $totalString';
  }

  @override
  String get economyDropPreviewTitle => 'Vista previa del Drop';

  @override
  String get economyDropRename => 'Renombrar Drop';

  @override
  String get economyDropRenameFailed => 'No se pudo renombrar el Drop. Inténtalo de nuevo.';

  @override
  String get economyDropRenameHint => 'Nombre del Drop';

  @override
  String get economyDropRenamed => 'Drop renombrado';

  @override
  String economyDropSave(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Ahorra $coinsString';
  }

  @override
  String economyDropStats(String walls, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString personas lo han conseguido',
      one: '1 persona lo ha conseguido',
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

    return 'Desbloquear los $countString por $priceString';
  }

  @override
  String get economyDropUnlockFailed => 'No se pudo desbloquear. Inténtalo de nuevo.';

  @override
  String economyDropUnlockFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Desbloquear por $priceString';
  }

  @override
  String economyDropUnlockWall(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Desbloquear este fondo por $priceString';
  }

  @override
  String get economyDropUnlocked => 'Desbloqueado';

  @override
  String economyDropUnlockedCount(int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$unlockedString/$totalString desbloqueados';
  }

  @override
  String economyDropUnlockedCountToast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fondos de pantalla desbloqueados',
      one: 'Fondo de pantalla desbloqueado',
    );
    return '$_temp0';
  }

  @override
  String get economyDropUnlockedWall => 'Fondo de pantalla desbloqueado';

  @override
  String economyDropUnlockedWallBy(String creator) {
    return 'Fondo de pantalla de $creator desbloqueado';
  }

  @override
  String economyDropWallBySemantics(String state, String serial, String creator) {
    return 'Fondo de pantalla $serial de $creator, $state';
  }

  @override
  String economyDropWallCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fondos de pantalla',
      one: '1 fondo de pantalla',
    );
    return '$_temp0';
  }

  @override
  String economyDropWallSemantics(String state, String serial) {
    return 'Fondo de pantalla $serial, $state';
  }

  @override
  String get economyDropWallpaperUnavailable => 'Este fondo de pantalla no está disponible';

  @override
  String economyDropWeekOf(String date) {
    return 'Semana del $date';
  }

  @override
  String get economyDropYourVault => 'Tu colección';

  @override
  String get economyDrops => 'Drops';

  @override
  String get economyEarnCoins => 'Gana monedas';

  @override
  String get economyEarnXpAsYouGo => 'Gana XP mientras avanzas';

  @override
  String economyEarnedAtRank(String rank) {
    return 'Conseguido al alcanzar el rango $rank';
  }

  @override
  String get economyEquipped => 'Equipado';

  @override
  String get economyEveryChestPays => 'Todos los cofres dan alguna recompensa.';

  @override
  String get economyEverySpinPays => 'Cada giro da alguna recompensa.';

  @override
  String economyFallbackCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Recibes $countString monedas si ya tienes todos';
  }

  @override
  String economyFinishDay7Chest(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Completa el día 7 para conseguir un cofre con +$minimumString a +$maximumString';
  }

  @override
  String get economyFinishStreakWeek => 'Completa una semana de racha diaria.';

  @override
  String economyFirstDownloadsFree(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Los primeros $countString son gratis';
  }

  @override
  String get economyFirstUpload => 'Primera subida';

  @override
  String get economyFreeDailySpin => 'Giro diario gratis';

  @override
  String economyFreeDownloadsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Quedan $countString gratis';
  }

  @override
  String get economyFreeSpin => 'Giro gratis';

  @override
  String economyFreeSpinReady(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '. Te quedan $countString giros de pago hoy.',
      one: '. Te queda 1 giro de pago hoy.',
      zero: '',
    );
    return 'Giro gratis listo$_temp0';
  }

  @override
  String get economyFreezeAdded => 'Se añadió una protección de racha.';

  @override
  String economyFreezeAlreadyAtLimit(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString protecciones',
      one: '1 protección',
    );
    return 'Ya tienes $_temp0.';
  }

  @override
  String economyFreezeBalanceAfter(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Saldo después: $balanceString';
  }

  @override
  String economyFreezeBuyConfirm(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '¿Quieres comprar una protección de racha por $costString monedas?';
  }

  @override
  String get economyFreezeBuyFailed => 'No se pudo comprar la protección. Inténtalo de nuevo.';

  @override
  String economyFreezeCount(int held, int total) {
    final intl.NumberFormat heldNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String heldString = heldNumberFormat.format(held);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$heldString de $totalString';
  }

  @override
  String get economyFreezeDescription => 'Protege tu racha si te saltas un día. Se aplica automáticamente.';

  @override
  String get economyFreezeFull => 'Completo';

  @override
  String economyFreezeGetOne(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Conseguir una · $costString';
  }

  @override
  String get economyFreezeHeld => 'Protección disponible';

  @override
  String economyFreezeNeedCoins(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Necesitas $costString monedas.';
  }

  @override
  String get economyFreezeSlotEmpty => 'Espacio de protección vacío';

  @override
  String get economyFreezeUnavailable => 'La protección de racha no está disponible ahora. Inténtalo más tarde.';

  @override
  String get economyFreshLeaderboardDetails =>
      'La clasificación usa los XP semanales y se reinicia cada lunes a las 00:00 UTC. Se conservan tus XP totales, tu rango y los elementos cosméticos que hayas conseguido.';

  @override
  String get economyFreshLeaderboardWeekly => 'Una clasificación nueva cada semana';

  @override
  String get economyGetCoins => 'Conseguir monedas';

  @override
  String economyGetCoinsChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Conseguir monedas. El cofre cuesta $priceString monedas';
  }

  @override
  String economyGetCoinsForSpin(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Conseguir monedas. Un giro cuesta $priceString monedas';
  }

  @override
  String get economyGetFreezeNextTime => 'Conseguir una protección para la próxima vez';

  @override
  String get economyGetPro => 'Conseguir Pro';

  @override
  String get economyGiftPass => 'Regalar un pase';

  @override
  String economyGiftPassInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Regala a un amigo 24 horas de contenido Pro por $amountString monedas. Abre su perfil y toca Regalar pase de 24 h.';
  }

  @override
  String get economyGotIt => 'Entendido';

  @override
  String economyHighestRankReached(String rank) {
    return 'Rango más alto alcanzado: $rank';
  }

  @override
  String get economyHighestRankReachedShort => 'Rango más alto alcanzado';

  @override
  String get economyHomeScreen => 'Pantalla de inicio';

  @override
  String get economyInviteFriend => 'Invitar a un amigo';

  @override
  String get economyJackpotAddedToBalance => '¡Premio mayor! Se añadió a tu saldo';

  @override
  String get economyKeepStreakToday => 'Abre Prism hoy para mantener tu racha.';

  @override
  String get economyLastWeek => 'La semana pasada';

  @override
  String economyLeaderboardEntrySemantics(int position, String name, String isMe, int xp, String hasRank, String rank) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(isMe, {'true': ', tú', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(hasRank, {'true': ', rango de por vida $rank', 'other': ''});
    return '$positionString, $name$_temp0, $xpString XP esta semana$_temp1';
  }

  @override
  String get economyLeaderboardFollowTip =>
      'Tu puntuación está incluida. Sigue a creadores para comparar los XP semanales.';

  @override
  String get economyLeaderboardFollowToSee => 'Sigue a creadores para verlos aquí.';

  @override
  String get economyLeaderboardFollowing => 'Siguiendo';

  @override
  String get economyLeaderboardFriendsCaption => 'Tú y las personas que sigues · desliza para actualizar';

  @override
  String get economyLeaderboardFriendsDetails =>
      'Incluye tu puntuación y hasta las primeras 90 cuentas que sigues. Se excluyen las cuentas eliminadas; no hay una antigüedad mínima para las cuentas. Las puntuaciones se cargan la primera vez que abres esta pestaña. Desliza para actualizar. Tu puntuación refleja tus XP sincronizados más recientes.';

  @override
  String get economyLeaderboardGlobal => 'Global';

  @override
  String get economyLeaderboardGlobalCaption => '50 primeros · se actualiza cada 3 horas aproximadamente';

  @override
  String get economyLeaderboardGlobalDetails =>
      'Muestra hasta 50 cuentas según los XP semanales. Las cuentas deben tener al menos 7 días; se excluyen las cuentas eliminadas. La instantánea se actualiza cada 3 horas aproximadamente, así que los XP nuevos pueden tardar en aparecer. Desliza para cargar la instantánea más reciente.';

  @override
  String get economyLeaderboardHowScoringWorks => 'Cómo funciona la puntuación de la clasificación';

  @override
  String get economyLeaderboardLoadFailed => 'No se pudo cargar la clasificación';

  @override
  String get economyLeaderboardNoRankings => 'Aún no hay posiciones';

  @override
  String get economyLeaderboardOffline =>
      'Si no tienes conexión, es posible que se muestren las puntuaciones guardadas.';

  @override
  String get economyLeaderboardRankedByXp => 'Ordenado por los XP obtenidos esta semana';

  @override
  String economyLeaderboardReset(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$daysString d', one: '1 d');
    String _temp1 = intl.Intl.pluralLogic(hours, locale: localeName, other: '$hoursString h', one: '1 h');
    return 'Se reinicia el lunes a las 00:00 UTC · quedan $_temp0 y $_temp1';
  }

  @override
  String get economyLeaderboardScoringIntro =>
      'Las posiciones se basan en los XP obtenidos esta semana. Las etiquetas de rango, como Plata, se basan en los XP de por vida. Los XP semanales se reinician el lunes a las 00:00 UTC; los XP de por vida y el rango se mantienen.';

  @override
  String get economyLeaderboardTitle => 'Clasificación';

  @override
  String get economyLifetimePermanentDetails =>
      'Los XP de por vida determinan tu rango y nunca se reinician. Los elementos cosméticos de rango aparecen automáticamente en tu inventario, no cuestan monedas y son tuyos para siempre. Elige cuándo equiparlos en la Tienda.';

  @override
  String get economyLifetimePermanentRewards => 'Progreso de por vida, recompensas permanentes';

  @override
  String economyLifetimeXp(String xp) {
    return '$xp XP de por vida';
  }

  @override
  String get economyLifetimeXpNeverResets => 'Los XP de por vida nunca se reinician.';

  @override
  String get economyLoadingVideo => 'Cargando un video';

  @override
  String get economyLockScreen => 'Pantalla de bloqueo';

  @override
  String get economyMystery => 'Misterioso';

  @override
  String get economyMysteryCosmetic => 'Elemento cosmético misterioso';

  @override
  String get economyNewBadge => 'Insignia nueva';

  @override
  String economyNewCosmetic(String kind, String name) {
    return 'Nuevo elemento de tipo $kind: $name';
  }

  @override
  String get economyNewUnknownCosmetic => 'Elemento cosmético nuevo';

  @override
  String get economyNextDropMonday => 'El próximo lanzamiento llega el lunes.';

  @override
  String economyNextReward(String reward) {
    return 'Próxima recompensa: $reward';
  }

  @override
  String get economyNice => '¡Genial!';

  @override
  String get economyNoDropNow => 'Ahora no hay ningún lanzamiento';

  @override
  String get economyNoSpinsLeft => 'Hoy no te quedan giros.';

  @override
  String get economyNotEnoughCoins => 'No tienes suficientes monedas';

  @override
  String get economyNotNow => 'Ahora no';

  @override
  String economyOddsTierSemantics(String tier, String odds) {
    return '$tier, $odds';
  }

  @override
  String get economyOddsTitle => 'Probabilidades';

  @override
  String get economyOnceADay => 'Una vez al día';

  @override
  String get economyOpen => 'Abrir';

  @override
  String economyOpenChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Abrir el cofre, $priceString monedas';
  }

  @override
  String get economyOpenChestFree => 'Abrir el cofre gratis';

  @override
  String get economyOpenChestLoading => 'Abriendo el cofre. Cargando';

  @override
  String get economyOpenDaily => 'Abre Prism todos los días.';

  @override
  String economyOpenDailyPro(String multiplier) {
    return 'Abre Prism todos los días. Pro gana x$multiplier.';
  }

  @override
  String get economyOpenFree => 'Abrir gratis';

  @override
  String get economyOpenShop => 'Abrir la Tienda';

  @override
  String get economyOpening => 'Abriendo';

  @override
  String get economyOwned => 'En tu colección';

  @override
  String get economyPremiumCollection => 'Colección Premium';

  @override
  String economyPriceCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString monedas';
  }

  @override
  String economyPriceCoinsForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$amountString monedas por $hoursString horas';
  }

  @override
  String economyPriceCoinsPerWall(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString por fondo';
  }

  @override
  String economyPriceCoinsPerWallSemantics(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString monedas por fondo';
  }

  @override
  String economyPriceCoinsWithNote(int amount, String note, String hasNote) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(hasNote, {'true': ', $note', 'other': ''});
    return '$amountString monedas$_temp0';
  }

  @override
  String economyPriceForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$amountString por $hoursString h';
  }

  @override
  String economyPriceFrom(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'desde $amountString';
  }

  @override
  String economyPriceFromCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'desde $amountString monedas';
  }

  @override
  String get economyPrizeWheel => 'Ruleta de premios';

  @override
  String get economyPro => 'Pro';

  @override
  String get economyProDailyFreeSpin => 'Los miembros Pro reciben un giro gratis cada día';

  @override
  String get economyProDownloadsFilters => 'Con Pro, las descargas y los filtros son gratis.';

  @override
  String get economyProPrice => 'Precio de Pro';

  @override
  String get economyProWallpaper => 'Fondo Pro';

  @override
  String get economyQuestBrowse10 => 'Explora 10 fondos';

  @override
  String get economyQuestColourSearch => 'Busca por color';

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
      other: 'Misión completada: +$xpString XP',
      zero: 'Misión completada',
    );
    String _temp3 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Misión completada: +$coinsString monedas$_temp0',
      one: 'Misión completada: +1 moneda$_temp1',
      zero: '$_temp2',
    );
    return '$_temp3';
  }

  @override
  String get economyQuestDownload2 => 'Descarga 2 fondos';

  @override
  String get economyQuestFav3 => 'Añade 3 fondos a favoritos';

  @override
  String economyQuestNewIn(String time) {
    return 'Novedades de $time';
  }

  @override
  String get economyQuestProSpin => 'Usa tu giro gratis';

  @override
  String get economyQuestSetWall => 'Configura o guarda un fondo de pantalla';

  @override
  String get economyQuestShareWall => 'Comparte un fondo de pantalla';

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

    String _temp0 = intl.Intl.selectLogic(isDone, {'true': 'completada', 'other': '$progressString de $targetString'});
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString monedas', one: '1 moneda');
    String _temp2 = intl.Intl.selectLogic(hasCoins, {'true': '. Obtienes $_temp1', 'other': ''});
    String _temp3 = intl.Intl.selectLogic(hasXp, {'true': '. Obtienes $xpString XP', 'other': ''});
    String _temp4 = intl.Intl.selectLogic(hasEnds, {'true': ', termina en $endsIn', 'other': ''});
    String _temp5 = intl.Intl.selectLogic(isWeekly, {'true': '. Misión semanal$_temp4', 'other': ''});
    return '$title, $_temp0$_temp2$_temp3$_temp5';
  }

  @override
  String get economyQuestTrending => 'Descubre las tendencias';

  @override
  String get economyQuestUnknown => 'Completa una misión';

  @override
  String get economyQuestWatchAd => 'Mira un video';

  @override
  String get economyQuestWeeklySet5 => 'Guarda o configura 5 fondos';

  @override
  String get economyQuestWotd => 'Abre el fondo del día de hoy';

  @override
  String get economyRankBronze => 'Bronce';

  @override
  String get economyRankGold => 'Oro';

  @override
  String get economyRankGrowsWithXp => 'Tu rango aumenta con tus XP de por vida.';

  @override
  String economyRankInfoSemantics(String rank) {
    return 'Rango $rank. Cómo funcionan los XP y las recompensas de rango';
  }

  @override
  String get economyRankPrism => 'Prism';

  @override
  String economyRankProgressSemantics(String rank) {
    return 'Progreso del rango $rank';
  }

  @override
  String economyRankRewardAtRank(String rank, String xp) {
    return 'Tuyo automáticamente al alcanzar $rank · $xp XP';
  }

  @override
  String economyRankRewardMilestone(String rank, String xp, String reward) {
    return '$rank · $xp XP\n$reward';
  }

  @override
  String get economyRankRewardSyncing => 'Sincronizando con tu inventario. Es tuyo para siempre.';

  @override
  String get economyRankRewardsHelp => 'Cómo funcionan los XP y las recompensas de rango';

  @override
  String get economyRankSilver => 'Plata';

  @override
  String economyRankTag(String rank) {
    return 'Rango $rank';
  }

  @override
  String get economyRankUnknown => 'Rango';

  @override
  String economyReferralBothGet(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString monedas', one: '1 moneda');
    return 'Ambos reciben $_temp0';
  }

  @override
  String get economyRestore => 'Restaurar';

  @override
  String economyRestoreStreak(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Restaurar tu racha de $daysString días · $coinsString monedas';
  }

  @override
  String economyRewardEarned(String reward) {
    return 'Recompensa obtenida: $reward';
  }

  @override
  String get economyRewardsTitle => 'Recompensas';

  @override
  String get economySameActivitySameXp => 'La misma actividad otorga los mismos XP';

  @override
  String get economySameActivityXpDetails =>
      'Los anuncios, los giros Pro, las bonificaciones diarias Pro, las invitaciones y los reembolsos no otorgan XP. Pro y los multiplicadores de monedas no aumentan los XP. Las recompensas en monedas se contabilizan por separado.';

  @override
  String get economySeeAll => 'Ver todo';

  @override
  String get economySeeBadges => 'Ver insignias';

  @override
  String get economySeeItInShop => 'Ver en la Tienda';

  @override
  String get economySeeOdds => 'Ver probabilidades';

  @override
  String get economySeePro => 'Ver Pro';

  @override
  String get economySeeRewards => 'Ver recompensas';

  @override
  String get economyShareWallpaper => 'Compartir un fondo de pantalla';

  @override
  String get economyShopAlreadyOwned => 'Ya tienes este elemento';

  @override
  String get economyShopAurora => 'Aurora';

  @override
  String economyShopBuyFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Comprar por $priceString';
  }

  @override
  String get economyShopChangeIconFailed => 'No se pudo cambiar el icono';

  @override
  String economyShopCoinsShort(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Te faltan $countString monedas.';
  }

  @override
  String get economyShopCottonBlue => 'Azul algodón';

  @override
  String get economyShopDeepOcean => 'Océano profundo';

  @override
  String get economyShopDefaultIcon => 'Predeterminado';

  @override
  String get economyShopEarnXp => 'Gana XP';

  @override
  String economyShopEarnedAtLifetimeXp(String rank) {
    return 'Obtenido al alcanzar el rango $rank con XP de por vida.';
  }

  @override
  String get economyShopEmber => 'Ascua';

  @override
  String get economyShopEquip => 'Equipar';

  @override
  String get economyShopEquipFailed => 'No se pudo cambiar. Inténtalo de nuevo.';

  @override
  String economyShopEquipped(String name) {
    return '$name equipado';
  }

  @override
  String get economyShopFounders => 'Fundadores';

  @override
  String get economyShopFrames => 'Marcos';

  @override
  String get economyShopGlass => 'Cristal';

  @override
  String get economyShopGlowPreviewName => 'Destello';

  @override
  String get economyShopGlows => 'Resplandores';

  @override
  String get economyShopGold => 'Oro';

  @override
  String economyShopIconEnabled(String name) {
    return 'El icono $name está activado';
  }

  @override
  String get economyShopIcons => 'Iconos';

  @override
  String economyShopItemSemantics(String name, String status) {
    return '$name, $status';
  }

  @override
  String get economyShopJungle => 'Jungla';

  @override
  String get economyShopMono => 'Monocromo';

  @override
  String get economyShopNeedMoreCoins => 'Necesitas más monedas para esto';

  @override
  String get economyShopNoir => 'Noir';

  @override
  String get economyShopOcean => 'Océano';

  @override
  String get economyShopOlive => 'Oliva';

  @override
  String get economyShopPepper => 'Pimienta';

  @override
  String get economyShopPrism => 'Prism';

  @override
  String get economyShopProOnly => 'Este elemento es solo para miembros Pro';

  @override
  String get economyShopPurchaseFailed => 'No se pudo comprar. Inténtalo de nuevo.';

  @override
  String economyShopPurchased(String name) {
    return '$name ya es tuyo';
  }

  @override
  String economyShopRankLocked(String rank) {
    return 'Alcanza el rango $rank para desbloquearlo';
  }

  @override
  String get economyShopRankReachedSyncing => 'Rango alcanzado. Sincronizando tu recompensa.';

  @override
  String economyShopRankRewardSynced(String name) {
    return 'Recompensa del rango $name sincronizada';
  }

  @override
  String economyShopReachRankToBuy(String rank) {
    return 'Alcanza el rango $rank para comprarlo.';
  }

  @override
  String get economyShopRing => 'Anillo';

  @override
  String get economyShopRose => 'Rosa';

  @override
  String economyShopSaleUntil(String date) {
    return 'Oferta por tiempo limitado. Disponible hasta el $date.';
  }

  @override
  String get economyShopSky => 'Cielo';

  @override
  String get economyShopSoldOut => 'Este elemento de edición limitada está agotado';

  @override
  String get economyShopSteel => 'Acero';

  @override
  String get economyShopSunset => 'Atardecer';

  @override
  String get economyShopSyncReward => 'Sincronizar recompensa';

  @override
  String get economyShopThemes => 'Temas';

  @override
  String get economyShopTitle => 'Tienda';

  @override
  String get economyShopUnequip => 'Quitar';

  @override
  String economyShopUnequipped(String name) {
    return 'Se quitó $name';
  }

  @override
  String get economyShopUseIcon => 'Usar icono';

  @override
  String get economyShopUseTheme => 'Usar tema';

  @override
  String get economyShopWearingNeedsPro => 'Para llevarlo necesitas Pro.';

  @override
  String get economyShowMore => 'Mostrar más';

  @override
  String get economySignIn => 'Iniciar sesión';

  @override
  String get economySoldOut => 'Agotado';

  @override
  String get economySoon => 'pronto';

  @override
  String economySpendItemSemantics(String label, String price) {
    return '$label, $price';
  }

  @override
  String get economySpin => 'GIRAR';

  @override
  String get economySpinAgain => 'Girar de nuevo';

  @override
  String get economySpinAgainFree => 'Girar de nuevo, giro gratis';

  @override
  String economySpinAgainPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Girar de nuevo, $priceString monedas';
  }

  @override
  String economySpinCardCaption(int price, int maximum) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '$priceString monedas por giro. Gana hasta $maximumString monedas o un elemento cosmético';
  }

  @override
  String economySpinCosts(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Un giro cuesta $priceString monedas';
  }

  @override
  String get economySpinFree => 'Girar, giro gratis';

  @override
  String economySpinPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Girar, $priceString monedas';
  }

  @override
  String get economySpinPriceChanged => 'El precio ha cambiado. Compruébalo y vuelve a girar.';

  @override
  String economySpinShortBalanceMessage(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Un giro cuesta $priceString monedas. Tienes $balanceString. Mira un video para ganar más.';
  }

  @override
  String get economySpinTheWheel => 'Gira la ruleta';

  @override
  String economySpinWheelCardSemantics(String caption) {
    return 'Gira la ruleta. $caption';
  }

  @override
  String get economySpinning => 'Girando';

  @override
  String economySpinsLeftToday(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString giros', one: '1 giro');
    return 'Hoy te quedan $_temp0.';
  }

  @override
  String get economyStreak => 'RACHA';

  @override
  String economyStreakChestReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString cofre del día 7';
  }

  @override
  String get economyStreakCollection => 'Colección de rachas';

  @override
  String get economyStreakCollectionDescription =>
      'Desbloquea fondos de pantalla manteniendo tu racha o usando monedas.';

  @override
  String economyStreakCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString días', one: '1 día');
    return 'Racha de $_temp0';
  }

  @override
  String economyStreakCycleSemantics(int day, String showReward, int reward, String state) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(showReward, {'true': ', más $rewardString monedas', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(state, {'done': ', completado', 'today': ', hoy', 'other': ''});
    return 'Día $dayString$_temp0$_temp1';
  }

  @override
  String economyStreakDailyReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString hoy';
  }

  @override
  String economyStreakDayNumber(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Día $dayString de tu racha';
  }

  @override
  String get economyStreakFreeze => 'Protección de racha';

  @override
  String economyStreakFreezeSaved(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Una protección salvó tu racha de $daysString días';
  }

  @override
  String economyStreakFreezesLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $countString protecciones',
      one: 'Queda 1 protección',
    );
    return '$_temp0';
  }

  @override
  String economyStreakProReward(int coins, String multiplier) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString x$multiplier con Pro';
  }

  @override
  String get economyStreakRescueCooldown => 'Puedes restaurar una racha cada 30 días.';

  @override
  String get economyStreakRescueExpired => 'Ya pasó el plazo de 48 horas para restaurar esta racha.';

  @override
  String get economyStreakRescueFailed => 'No se pudo restaurar tu racha. Inténtalo de nuevo.';

  @override
  String get economyStreakRescueUnavailable => 'Ya no se puede restaurar esta racha.';

  @override
  String get economyStreakReset => 'Tu racha se reinició';

  @override
  String economyStreakResetMessage(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Llevabas $daysString días. Empieza de nuevo hoy y gana +$coinsString monedas.';
  }

  @override
  String economyStreakRestoreShort(int balance, int cost) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Tienes $balanceString. Necesitas $costString.';
  }

  @override
  String get economyStreakRestored => 'Has recuperado tu racha';

  @override
  String economyStreakRestoredCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Vuelves a llevar $countString días.';
  }

  @override
  String get economyToday => 'Hoy';

  @override
  String get economyUnknownCosmetic => 'Artículo estético';

  @override
  String economyUntil(String date) {
    return 'Hasta $date';
  }

  @override
  String economyUpToCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Hasta +$countString';
  }

  @override
  String get economyUpgradeToPro => 'Pásate a Pro';

  @override
  String economyUseReward(String reward) {
    return 'Usar $reward';
  }

  @override
  String get economyUseYourCoins => 'Usa tus monedas';

  @override
  String get economyWatchAd => 'Ver anuncio';

  @override
  String get economyWatchVideo => 'Ver un video';

  @override
  String economyWatchVideoRewardAdsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString anuncios', one: '1 anuncio');
    return 'Ver un video · quedan $_temp0 hoy';
  }

  @override
  String economyWatchVideoRewardCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Ver un video (+$coinsString)';
  }

  @override
  String get economyWeekComplete => '¡Semana completada!';

  @override
  String get economyWeekly => 'SEMANAL';

  @override
  String get economyWeeklyDraw => 'Sorteo semanal';

  @override
  String get economyWeeklyDrop => 'Novedad semanal';

  @override
  String economyWeeklyEndsIn(String time) {
    return 'SEMANAL · $time';
  }

  @override
  String get economyWeeklyXpFriendsEveryone => 'XP semanal, amistades y comunidad';

  @override
  String economyWonCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coinsString monedas', one: '1 moneda');
    return 'Has ganado $_temp0';
  }

  @override
  String economyWonCosmetic(String kind, String name) {
    return 'Has ganado un nuevo artículo de tipo $kind: $name';
  }

  @override
  String get economyWonUnknownCosmetic => 'Has ganado un artículo estético';

  @override
  String economyWonXp(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Has ganado $xpString XP';
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

    return 'Las rachas diarias dan $dailyStreakString XP, y completar un ciclo de siete días suma $streakWeekString XP. Los cofres de misión dan $questChestString XP. Tu primera publicación válida da $uploadString XP; completar tu perfil da $profileString XP. Cada misión diaria otorga $dailyQuestString XP; la misión semanal otorga $weeklyQuestString XP. Algunas insignias y metas de creador también dan XP.';
  }

  @override
  String economyXpAwarded(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '+$xpString XP';
  }

  @override
  String get economyXpRanksRewards => 'XP, rangos y recompensas';

  @override
  String economyXpToRank(String xp, String rank) {
    return '$xp XP para llegar a $rank';
  }

  @override
  String get economyXpUnit => 'XP';

  @override
  String get economyYesterday => 'Ayer';

  @override
  String economyYouHaveCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Tienes $countString monedas';
  }

  @override
  String get economyYourXp => 'TU XP';

  @override
  String get errorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get errorNetwork => 'Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get navigationBackOnline => 'Conexión restablecida';

  @override
  String get navigationNoInternetConnection => 'Sin conexión a internet';

  @override
  String get navigationScrollToTop => 'Ir al principio';

  @override
  String get notifActivateToCollapse => 'Activa para contraer.';

  @override
  String get notifActivateToExpand => 'Activa para expandir.';

  @override
  String get notifChannelDownloads => 'Descargas';

  @override
  String get notifChannelDownloadsDescription =>
      'Recibe notificaciones sobre el progreso de descarga de fondos de pantalla.';

  @override
  String get notifChannelDraw => 'Sorteo de Prism';

  @override
  String get notifChannelDrawDescription => 'Resultados y premios del sorteo.';

  @override
  String get notifChannelDrops => 'Novedades semanales';

  @override
  String get notifChannelDropsDescription => 'Cuando haya una novedad y antes de que termine.';

  @override
  String get notifChannelFollowers => 'Seguidores';

  @override
  String get notifChannelFollowersDescription => 'Recibe notificaciones sobre nuevos seguidores.';

  @override
  String get notifChannelGifts => 'Regalos';

  @override
  String get notifChannelGiftsDescription => 'Un amigo te envió un pase Pro.';

  @override
  String get notifChannelGroup => 'Notificaciones';

  @override
  String get notifChannelGroupDescription => 'Todas las notificaciones de Prism';

  @override
  String get notifChannelModeration => 'Moderación';

  @override
  String get notifChannelModerationDescription => 'Denuncias y solicitudes de revisión para administradores de Prism.';

  @override
  String get notifChannelPosts => 'Publicaciones';

  @override
  String get notifChannelPostsDescription => 'Recibe notificaciones de los artistas que sigues.';

  @override
  String get notifChannelRecommendations => 'Recomendaciones';

  @override
  String get notifChannelRecommendationsDescription => 'Recibe recomendaciones de Prism.';

  @override
  String get notifChannelStreaks => 'Recordatorios de racha';

  @override
  String get notifChannelStreaksDescription => 'Recordatorio a las 8 p. m. para mantener tu racha de inicio de sesión.';

  @override
  String get notifChannelWotd => 'Muro del día';

  @override
  String get notifChannelWotdDescription => 'Notificación del fondo de pantalla destacado del día a las 9 a. m.';

  @override
  String get notifClearDeviceMessage => 'Se quitarán de este dispositivo.';

  @override
  String get notifClearInbox => 'Vaciar bandeja';

  @override
  String get notifClearInboxAction => 'Vaciar bandeja';

  @override
  String notifClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '¿Quitar $countString notificaciones?';
  }

  @override
  String get notifClearOneTitle => '¿Quitar esta notificación?';

  @override
  String get notifCollapsed => 'Contraído';

  @override
  String notifDownloadedTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se descargaron $countString fondos de pantalla.',
      one: 'Se descargó 1 fondo de pantalla.',
    );
    return '$_temp0';
  }

  @override
  String get notifDownloadingWallpaper => 'Descargando fondo de pantalla';

  @override
  String get notifEmptyBody => 'Aquí aparecerán los nuevos seguidores, las aprobaciones y el Muro del día.';

  @override
  String get notifEmptyTitle => 'No hay notificaciones';

  @override
  String get notifExpanded => 'Expandido';

  @override
  String get notifGenericTitle => 'Notificación';

  @override
  String notifGroupAndMore(String message, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString más.',
      one: '1 más.',
    );
    return '$message y $_temp0';
  }

  @override
  String notifGroupApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'aprobaciones', one: 'aprobación');
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
      other: '$otherCountString creadores más.',
      one: '1 creador más.',
    );
    return 'De $name y $_temp0';
  }

  @override
  String notifGroupDailyPicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'selecciones diarias',
      one: 'selección diaria',
    );
    return '$_temp0';
  }

  @override
  String get notifGroupDayRows => 'Cada fila corresponde a un día; las horas aparecen a la derecha.';

  @override
  String notifGroupFollowerSummary(String name, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString personas más te siguieron.',
      one: '1 persona más te siguió.',
    );
    return '$name y $_temp0';
  }

  @override
  String notifGroupFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'nuevos seguidores', one: 'nuevo seguidor');
    return '$_temp0';
  }

  @override
  String get notifGroupHide => 'Ocultar';

  @override
  String notifGroupNotifications(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'notificaciones', one: 'notificación');
    return '$_temp0';
  }

  @override
  String notifGroupNotificationsRemoved(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se quitaron $countString notificaciones',
      one: 'Se quitó 1 notificación',
    );
    return '$_temp0';
  }

  @override
  String notifGroupSameMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'El mismo mensaje se envió $countString veces. Compara las horas para ver cuándo.';
  }

  @override
  String notifGroupSemantics(String title, String summary, String expandedState, String unreadStatus, String action) {
    return '$title. $summary. $expandedState. $unreadStatus $action';
  }

  @override
  String get notifGroupSeveralCreators => 'Varios creadores. Expande para ver cada fondo.';

  @override
  String get notifGroupShowAll => 'Mostrar todo';

  @override
  String notifGroupSummaryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString notificaciones en este grupo.',
      one: '1 notificación en este grupo.',
    );
    return '$_temp0';
  }

  @override
  String notifGroupWallLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fondos de pantalla publicados',
      one: 'fondo de pantalla publicado',
    );
    return '$_temp0';
  }

  @override
  String get notifHasUnread => 'Hay elementos sin leer.';

  @override
  String get notifInboxCleared => 'Bandeja vaciada';

  @override
  String get notifLoadErrorTitle => 'No se pudieron cargar tus notificaciones';

  @override
  String get notifMarkAllRead => 'Marcar todo como leído';

  @override
  String get notifOfflineSaved =>
      'No se pudieron cargar notificaciones nuevas. Lo que ves a continuación está guardado en este dispositivo.';

  @override
  String get notifOpenSettings => 'Abrir ajustes';

  @override
  String get notifPermissionOff =>
      'Las notificaciones están desactivadas. Actívalas primero en los ajustes del sistema.';

  @override
  String get notifPermissionOffForApp => 'Las notificaciones de Prism están desactivadas.';

  @override
  String get notifPreferences => 'Preferencias de notificaciones';

  @override
  String get notifPushDrawWinnerBody => 'Ya tienes un mes de Pro y el marco de Prism.';

  @override
  String get notifPushDrawWinnerTitle => 'Ganaste el sorteo de Prism';

  @override
  String notifPushDropLastCallBody(String dropTitle, int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(hours, locale: localeName, other: '$hoursString horas', one: '1 hora');
    return '$dropTitle termina en $_temp0. Después, estos fondos desaparecerán durante un mes.';
  }

  @override
  String get notifPushDropLastCallTitle => 'Último aviso de la novedad de esta semana';

  @override
  String notifPushDropLiveBody(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fondos de pantalla, solo esta semana. Échales un vistazo antes de que desaparezcan.',
      one: 'Un fondo de pantalla, solo esta semana. Échale un vistazo antes de que desaparezca.',
    );
    return '$_temp0';
  }

  @override
  String get notifPushDropLiveTitle => 'Hay una novedad';

  @override
  String get notifPushGiftReceivedBody =>
      'Tienes acceso a las colecciones prémium y a los fondos de pantalla prémium hasta mañana.';

  @override
  String notifPushGiftReceivedTitle(String senderName) {
    return '$senderName te envió un pase Pro de 24 horas';
  }

  @override
  String notifPushNewContentReportBody(String contentType, String reason, String targetId) {
    return '$contentType · $reason · doc. $targetId';
  }

  @override
  String get notifPushNewContentReportTitle => 'Nueva denuncia de contenido';

  @override
  String notifPushNewFollowerBody(String followerName) {
    return '$followerName ahora te sigue.';
  }

  @override
  String get notifPushNewFollowerTitle => '¡Tienes un nuevo seguidor! 🎉';

  @override
  String notifPushReportReviewBody(String contentType, String reason) {
    return '$contentType · $reason · pendiente desde hace más de 12 horas';
  }

  @override
  String get notifPushReportReviewTitle => 'Denuncia pendiente de revisión';

  @override
  String get notifPushStreakReminderBody => 'Abre Prism ahora para mantener tu racha de inicio de sesión 🔥';

  @override
  String get notifPushStreakReminderTitle => '¡Tu racha está a punto de terminar!';

  @override
  String notifPushWallApprovedAdminBody(String wallTitle, String artistName) {
    return '«$wallTitle», de $artistName, ya está publicado.';
  }

  @override
  String get notifPushWallApprovedAdminTitle => 'Fondo de pantalla aprobado ✅';

  @override
  String notifPushWallApprovedArtistBody(String wallTitle) {
    return '«$wallTitle» se aprobó y ya está disponible para todos.';
  }

  @override
  String get notifPushWallApprovedArtistBodyUntitled =>
      'Tu fondo de pantalla se aprobó y ya está disponible para todos.';

  @override
  String get notifPushWallApprovedArtistTitle => '¡Tu fondo de pantalla ya está publicado! 🎉';

  @override
  String notifPushWallLiveFollowersBody(String wallTitle) {
    return '«$wallTitle» ya está en Prism.';
  }

  @override
  String notifPushWallLiveFollowersTitle(String artistName) {
    return 'Nuevo fondo de $artistName';
  }

  @override
  String notifPushWallSubmittedBody(String artistName, String artistEmail) {
    return 'La nueva publicación de $artistName ($artistEmail) está pendiente de revisión.';
  }

  @override
  String get notifPushWallSubmittedTitle => '¡Nuevo fondo prémium para revisar! 🎉';

  @override
  String get notifPushWinBack14Body => 'Descubre lo que han creado los artistas en las últimas dos semanas.';

  @override
  String get notifPushWinBack14Title => 'Hay nuevos fondos esperándote';

  @override
  String get notifPushWinBack30Body => 'Crea un fondo de pantalla que vaya contigo.';

  @override
  String get notifPushWinBack30Title => 'Prueba nuevos estilos de IA';

  @override
  String get notifPushWinBack60Body => 'Tu próximo fondo favorito está a un toque.';

  @override
  String get notifPushWinBack60Title => 'Prism te extraña';

  @override
  String get notifPushWinBack7Body => 'Han llegado nuevos fondos de pantalla mientras no estabas.';

  @override
  String get notifPushWinBack7Title => 'Hay nuevos fondos en tu feed';

  @override
  String notifPushWotdAudienceBody(String wallTitle) {
    return '$wallTitle';
  }

  @override
  String get notifPushWotdAudienceBodyUntitled => 'Abre Prism para ver el Muro del día de hoy.';

  @override
  String get notifPushWotdAudienceTitle => 'Ya llegó el Muro del día';

  @override
  String get notifPushWotdCreatorBody =>
      'Hoy Prism eligió tu fondo de pantalla para toda la comunidad. Gracias por compartirlo.';

  @override
  String get notifPushWotdCreatorTitle => 'Tu fondo de pantalla es el Muro del día';

  @override
  String get notifRead => 'Ya leída';

  @override
  String get notifRemoved => 'Notificación quitada';

  @override
  String get notifReportUnknownContentType => 'contenido';

  @override
  String notifSemanticsRow(String message, String time, String readStatus) {
    return '$message. $time. $readStatus';
  }

  @override
  String get notifSettingDrops => 'Novedades semanales';

  @override
  String get notifSettingDropsDescription => 'Avisos cuando haya una novedad y antes de que termine.';

  @override
  String get notifSettingFollowers => 'Seguidores';

  @override
  String get notifSettingFollowersDescription => 'Avisos cuando alguien nuevo te siga.';

  @override
  String get notifSettingPosts => 'Publicaciones';

  @override
  String get notifSettingPostsDescription => 'Avisos cuando los creadores que sigues compartan algo nuevo.';

  @override
  String get notifSettingRecommendations => 'Recomendaciones';

  @override
  String get notifSettingRecommendationsDescription =>
      'Consejos, novedades y fondos de pantalla recomendados por Prism.';

  @override
  String get notifSettingStreaks => 'Recordatorios de racha';

  @override
  String get notifSettingStreaksDescription =>
      'Aviso por la tarde, alrededor de las 8 p. m., si tu racha de inicio de sesión está a punto de terminar.';

  @override
  String get notifSettingWotd => 'Muro del día';

  @override
  String get notifSettingWotdDescription => 'Una selección diaria de fondos de pantalla.';

  @override
  String get notifSignInToChange => 'Inicia sesión para cambiar este ajuste.';

  @override
  String get notifSignInToTurnOn => 'Inicia sesión para activar';

  @override
  String get notifTapToOpenPrism => 'Toca para abrir Prism.';

  @override
  String get notifTitle => 'Notificaciones';

  @override
  String get notifToday => 'Hoy';

  @override
  String get notifUndo => 'Deshacer';

  @override
  String get notifUnread => 'Aún no leída';

  @override
  String get notifYesterday => 'Ayer';

  @override
  String notifYesterdayAt(String time) {
    return 'Ayer, $time';
  }

  @override
  String get onboardingAiGenerateError => 'algo salió mal.\ntoca Generar para intentarlo de nuevo.';

  @override
  String get onboardingAiGeneratePrompt => 'toca Generar para crear\ntu fondo de pantalla único';

  @override
  String get onboardingAiGenerating => 'creando tu fondo de pantalla…';

  @override
  String get onboardingBrowseGuest => 'Explorar sin una cuenta';

  @override
  String get onboardingCategoriesUnavailable => 'no pudimos cargar las categorías; puedes omitir este paso';

  @override
  String get onboardingContinue => 'continuar';

  @override
  String get onboardingContinueApple => 'Continuar con Apple';

  @override
  String get onboardingContinueGoogle => 'Continuar con Google';

  @override
  String onboardingContinueSelected(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'continuar ($countString seleccionadas)';
  }

  @override
  String get onboardingCouldNotLogOut => 'No se pudo cerrar la sesión. Inténtalo de nuevo.';

  @override
  String get onboardingCreatorsUnavailable => 'no pudimos cargar los creadores; puedes omitir este paso';

  @override
  String get onboardingFirstAiWallpaper => 'tu primer fondo de pantalla, creado con IA';

  @override
  String get onboardingFirstWallpaperSaveFailed =>
      'No se pudo guardar tu fondo de pantalla. Inténtalo de nuevo u omite este paso.';

  @override
  String get onboardingFirstWallpaperSavedPhotos => '¡Guardado en Fotos!';

  @override
  String get onboardingFirstWallpaperSet => '¡Fondo de pantalla aplicado!';

  @override
  String get onboardingFirstWallpaperSetFailed =>
      'No se pudo aplicar tu fondo de pantalla. Inténtalo de nuevo u omite este paso.';

  @override
  String get onboardingFirstWallpaperSetHome => 'Fondo de pantalla aplicado a la pantalla de inicio.';

  @override
  String get onboardingFirstWallpaperSetHomeLock =>
      'Fondo de pantalla aplicado a las pantallas de inicio y de bloqueo.';

  @override
  String get onboardingFirstWallpaperSetLock => 'Fondo de pantalla aplicado a la pantalla de bloqueo.';

  @override
  String get onboardingFollow => 'seguir';

  @override
  String onboardingFollowCreatorMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'te sugerimos seguir a estos $countString creadores';
  }

  @override
  String onboardingFollowerCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString seguidores',
      one: '$countString seguidor',
    );
    return '$_temp0';
  }

  @override
  String get onboardingFollowing => 'siguiendo';

  @override
  String get onboardingGenerateFailure => 'algo salió mal; toca Generar para intentarlo de nuevo';

  @override
  String get onboardingGenerateSuccess => '¡se ve genial! Abriendo tu fondo de pantalla';

  @override
  String get onboardingGenerateWallpaper => 'generar mi fondo de pantalla';

  @override
  String get onboardingHeadlineCreators => 'Encuentra a tu gente';

  @override
  String get onboardingHeadlineCustomize => 'Hazlo a tu manera';

  @override
  String get onboardingHeadlineGenerate => 'Crea tu\nprimer fondo de pantalla';

  @override
  String get onboardingHeadlineInterests => 'Elige tu estilo';

  @override
  String get onboardingLoadCategoriesFailed => 'No pudimos cargar las categorías.';

  @override
  String get onboardingLoadCreatorsFailed => 'No pudimos cargar los creadores.';

  @override
  String get onboardingPro => 'Pro';

  @override
  String get onboardingProFree => '  →  gratis para ti';

  @override
  String get onboardingRecoveryCreatorsFailed =>
      'No se pudieron cargar los creadores. Comprueba tu conexión y toca Volver a cargar.';

  @override
  String get onboardingRecoveryFollowFailed => 'No se pudo seguir a estos creadores. Inténtalo de nuevo.';

  @override
  String get onboardingRecoveryFollowFailedHelper =>
      'no se pudo seguir a estos creadores. comprueba tu conexión e inténtalo de nuevo';

  @override
  String get onboardingRecoveryReload => 'Volver a cargar';

  @override
  String get onboardingRecoveryRetry => 'Intentar de nuevo';

  @override
  String get onboardingRecoverySaveInterestsFailed => 'No se pudieron guardar tus selecciones. Inténtalo de nuevo.';

  @override
  String get onboardingRecoverySaveInterestsFailedHelper =>
      'no se pudieron guardar tus selecciones. comprueba tu conexión e inténtalo de nuevo';

  @override
  String get onboardingRecoverySessionExpired => 'Tu sesión ha caducado. Inicia sesión de nuevo.';

  @override
  String get onboardingRecoverySessionExpiredHelper => 'tu sesión ha caducado. inicia sesión para continuar';

  @override
  String get onboardingRecoverySetupFailed => 'No se pudo completar la configuración. Inténtalo de nuevo.';

  @override
  String get onboardingRecoverySetupFailedHelper =>
      'no se pudo completar la configuración. comprueba tu conexión e inténtalo de nuevo';

  @override
  String get onboardingRecoverySignIn => 'Iniciar sesión de nuevo';

  @override
  String get onboardingReloadLower => 'volver a cargar';

  @override
  String get onboardingSavePhotos => 'guardar en Fotos';

  @override
  String onboardingSelectInterestMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'selecciona al menos $countString categorías para personalizar tu feed';
  }

  @override
  String get onboardingSetWallpaper => 'establecer como fondo de pantalla';

  @override
  String get onboardingSignInAgainLower => 'iniciar sesión de nuevo';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingSkipLower => 'omitir';

  @override
  String get onboardingTermsRequired => 'Acepta primero los Términos y la Política de privacidad.';

  @override
  String get onboardingTryAgainLower => 'intentar de nuevo';

  @override
  String onboardingWallpaperForInterest(String category) {
    return 'elegimos este fondo de pantalla según tu interés en $category';
  }

  @override
  String get onboardingWallpaperJustForYou => 'elegimos este fondo de pantalla solo para ti';

  @override
  String get onboardingWelcomeDescription => 'Millones de fondos de pantalla prémium de los mejores artistas.';

  @override
  String get onboardingWelcomeHeadline => 'Reimagina tu pantalla.';

  @override
  String get premiumPageExplorePlans => 'Descubre los planes de Prism Premium.';

  @override
  String get premiumPagePlansUnavailable =>
      'Los planes no están disponibles en este momento. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get premiumPageTitle => 'Prism Premium';

  @override
  String get premiumPageTryAgain => 'Intentar de nuevo';

  @override
  String get premiumPageViewPlans => 'Ver planes';

  @override
  String get premiumGuestStorePurchaseActive =>
      'Tu compra de la tienda está activa en este dispositivo. Inicia sesión para usar las funciones Pro vinculadas a tu cuenta.';

  @override
  String get premiumPurchasePending => 'Tu compra está guardada. Pro puede tardar un minuto en activarse.';

  @override
  String get premiumPurchaseUnconfirmed =>
      'No se pudo confirmar tu compra. Intenta usar «Restaurar compras» en Ajustes.';

  @override
  String get wallpaperAccentColor => 'Color de acento';

  @override
  String get wallpaperAccentColorsOriginal => 'Colores originales del fondo de pantalla';

  @override
  String get wallpaperResetOriginal => 'Restablecer original';

  @override
  String get wallpaperAccentResetHint => 'Mantén pulsado para ver acciones, incluida Restablecer original';

  @override
  String get wallpaperAll => 'Todos';

  @override
  String get wallpaperApplyTo => 'Aplicar a';

  @override
  String get wallpaperAutoRotateAndroidOnly => 'La rotación automática solo está disponible en Android.';

  @override
  String get wallpaperAutoRotateApplyTo => 'Aplicar a';

  @override
  String get wallpaperAutoRotateBatterySteps =>
      'Abre Ajustes, luego Aplicaciones, Prism y Batería. Configura el uso de batería como Sin restricciones.';

  @override
  String get wallpaperAutoRotateBatteryTip =>
      'Si los fondos de pantalla dejan de cambiar, configura el uso de batería de Prism como Sin restricciones. Abre Ajustes, luego Aplicaciones, Prism y Batería.';

  @override
  String get wallpaperAutoRotateBothScreens => 'Ambas';

  @override
  String get wallpaperAutoRotateChangeError => 'No se pudo cambiar el fondo de pantalla.';

  @override
  String get wallpaperAutoRotateChangeLabel => 'Frecuencia de cambio';

  @override
  String get wallpaperAutoRotateChargingDescription =>
      'Cambiar cuando esté conectado a la corriente, como máximo una vez por intervalo';

  @override
  String get wallpaperAutoRotateChargingOnly => 'Solo mientras se carga';

  @override
  String get wallpaperAutoRotateCopySteps => 'Copiar pasos';

  @override
  String get wallpaperAutoRotateCouldNotStart => 'No se pudo iniciar. Inténtalo de nuevo.';

  @override
  String wallpaperAutoRotateDownloadedCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'fondos de pantalla',
      one: 'fondo de pantalla',
    );
    return 'Se descargaron $cachedString de $totalString $_temp0';
  }

  @override
  String wallpaperAutoRotateEnabledUntil(String date) {
    return 'Pase activo hasta $date';
  }

  @override
  String get wallpaperAutoRotateGotIt => 'Entendido';

  @override
  String get wallpaperAutoRotateHomeScreen => 'Pantalla de inicio';

  @override
  String get wallpaperAutoRotateInterval12Hours => 'Cada 12 horas';

  @override
  String get wallpaperAutoRotateInterval15 => 'Cada 15 min (consume mucha batería)';

  @override
  String get wallpaperAutoRotateInterval30 => 'Cada 30 min';

  @override
  String get wallpaperAutoRotateInterval3Days => 'Cada 3 días';

  @override
  String get wallpaperAutoRotateInterval3Hours => 'Cada 3 horas';

  @override
  String get wallpaperAutoRotateInterval6Hours => 'Cada 6 horas';

  @override
  String get wallpaperAutoRotateIntervalDay => 'Cada día';

  @override
  String get wallpaperAutoRotateIntervalHour => 'Cada hora';

  @override
  String get wallpaperAutoRotateIntervalWeek => 'Cada semana';

  @override
  String get wallpaperAutoRotateKeepRunning => 'Mantener activa';

  @override
  String get wallpaperAutoRotateLoadError => 'No se pudo cargar la configuración de rotación automática.';

  @override
  String get wallpaperAutoRotateLoadingWalls => 'Cargando fondos de pantalla';

  @override
  String get wallpaperAutoRotateLockScreen => 'Pantalla de bloqueo';

  @override
  String wallpaperAutoRotateMix(int count, String source) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fondos de pantalla de $source en la selección',
      one: '1 fondo de pantalla de $source en la selección',
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
      other: '$countString fondos de pantalla de $source en la selección. Se usarán los primeros 100.',
      one: '1 fondo de pantalla de $source en la selección. Se usarán los primeros 100.',
    );
    return '$_temp0';
  }

  @override
  String wallpaperAutoRotateNextChange(String time) {
    return 'Próximo cambio alrededor de las $time';
  }

  @override
  String wallpaperAutoRotateNounCategory(String category) {
    return '$category';
  }

  @override
  String get wallpaperAutoRotateNounDownloads => 'descargas';

  @override
  String get wallpaperAutoRotateNounFavourites => 'favoritos';

  @override
  String get wallpaperAutoRotateNounHistory => 'tu historial';

  @override
  String get wallpaperAutoRotateNounWotd => 'selecciones del Muro del día';

  @override
  String get wallpaperAutoRotateOff => 'Desactivada';

  @override
  String get wallpaperAutoRotateOffEnded =>
      'La rotación automática está desactivada porque terminó tu plan o pase de Prism Pro.';

  @override
  String get wallpaperAutoRotateOpenDownloads => 'Abrir descargas';

  @override
  String get wallpaperAutoRotateOpenFavourites => 'Abrir favoritos';

  @override
  String get wallpaperAutoRotatePassEnabled => 'La rotación automática estará activa durante 7 días.';

  @override
  String wallpaperAutoRotatePassPurchase(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Pase de 7 días · $coinsString monedas';
  }

  @override
  String get wallpaperAutoRotatePickCategory => 'Elige una categoría';

  @override
  String wallpaperAutoRotatePreparing(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fondos de pantalla',
      one: '1 fondo de pantalla',
    );
    return 'Preparando $_temp0';
  }

  @override
  String get wallpaperAutoRotateProBody => 'Pruébala durante 7 días con monedas o consigue Prism Pro.';

  @override
  String get wallpaperAutoRotateProTitle => 'La rotación automática es una función de Prism Pro.';

  @override
  String wallpaperAutoRotateReadyCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'fondos de pantalla listos',
      one: 'fondo de pantalla listo',
    );
    return '$cachedString de $totalString $_temp0';
  }

  @override
  String get wallpaperAutoRotateScheduled => 'Programada';

  @override
  String get wallpaperAutoRotateShuffle => 'Orden aleatorio';

  @override
  String get wallpaperAutoRotateShuffleDescription => 'Orden aleatorio en lugar de uno tras otro';

  @override
  String get wallpaperAutoRotateSourceCategory => 'Categoría';

  @override
  String get wallpaperAutoRotateSourceDownloads => 'Descargas';

  @override
  String get wallpaperAutoRotateSourceFavourites => 'Favoritos';

  @override
  String get wallpaperAutoRotateSourceHistory => 'Historial';

  @override
  String get wallpaperAutoRotateSourceLabel => 'Origen';

  @override
  String get wallpaperAutoRotateSourceLoadError =>
      'No se pudieron cargar los fondos de pantalla. Comprueba tu conexión.';

  @override
  String get wallpaperAutoRotateSourceWotd => 'Muro del día';

  @override
  String get wallpaperAutoRotateStartError => 'No se pudo iniciar la rotación de fondos de pantalla.';

  @override
  String get wallpaperAutoRotateStarting => 'Iniciando';

  @override
  String get wallpaperAutoRotateStatusLabel => 'Estado';

  @override
  String get wallpaperAutoRotateStepsCopied => 'Se copiaron los pasos.';

  @override
  String get wallpaperAutoRotateStopError => 'No se pudo detener la rotación de fondos de pantalla.';

  @override
  String get wallpaperAutoRotateTitle => 'Rotación automática';

  @override
  String get wallpaperAutoRotateTooFewCategory => 'Esta categoría tiene menos de 2 fondos de pantalla. Elige otra.';

  @override
  String get wallpaperAutoRotateTooFewDownloads => 'Descarga al menos 2 fondos de pantalla para alternarlos.';

  @override
  String get wallpaperAutoRotateTooFewFavourites => 'Añade al menos 2 fondos de pantalla a favoritos para alternarlos.';

  @override
  String get wallpaperAutoRotateTooFewHistory => 'Establece al menos 2 fondos de pantalla de Prism para alternarlos.';

  @override
  String get wallpaperAutoRotateTooFewWotd => 'Aún no hay suficientes selecciones anteriores.';

  @override
  String get wallpaperAutoRotateUnlockError => 'No se pudo desbloquear la rotación automática. Inténtalo de nuevo.';

  @override
  String get wallpaperAutoRotateUpdateError => 'No se pudo actualizar la rotación automática.';

  @override
  String get wallpaperBack => 'Atrás';

  @override
  String get wallpaperBlockCreator => 'Bloquear creador';

  @override
  String get wallpaperBlockCreatorNotFound => 'No se encontró este creador. Inténtalo de nuevo.';

  @override
  String get wallpaperBoostAlready => 'Ya tiene un impulso activo.';

  @override
  String wallpaperBoostAlreadyUntil(String time) {
    return 'Ya tiene un impulso activo hasta $time.';
  }

  @override
  String wallpaperBoostConfirmButton(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Impulsar por $coinsString monedas';
  }

  @override
  String wallpaperBoostConfirmMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Muestra este fondo de pantalla en el carrusel de Inicio y al principio de Tendencias durante 24 horas por $coinsString monedas.';
  }

  @override
  String wallpaperBoostDurationAndCost(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '24 horas en los primeros puestos · $coinsString monedas';
  }

  @override
  String get wallpaperBoostFailed => 'No se pudo impulsar este fondo de pantalla. Inténtalo de nuevo.';

  @override
  String get wallpaperBoostOnlyApproved =>
      'Solo puedes impulsar los fondos de pantalla que hayas subido y que estén aprobados.';

  @override
  String get wallpaperBoostSlotsTaken => 'Todos los espacios para impulsos están ocupados. Inténtalo más tarde.';

  @override
  String wallpaperBoostSlotsTakenUntil(String time) {
    return 'Todos los espacios para impulsos están ocupados. El próximo quedará libre a las $time.';
  }

  @override
  String get wallpaperBoostTitle => 'Impulsar en Tendencias';

  @override
  String get wallpaperBoostedSuccess => 'Impulso activado. Ya aparece en Inicio y en Tendencias.';

  @override
  String get wallpaperBoostedTag => 'Con impulso';

  @override
  String wallpaperBoostedUntil(String time) {
    return 'Con impulso hasta $time';
  }

  @override
  String get wallpaperBrowseWallpapers => 'Explorar fondos de pantalla';

  @override
  String wallpaperByCreator(String name) {
    return 'Fondo de pantalla de $name';
  }

  @override
  String get wallpaperByPrismCreator => 'Fondo de pantalla de un creador de Prism';

  @override
  String get wallpaperCategories => 'Categorías';

  @override
  String get wallpaperCategory => 'Categoría';

  @override
  String get wallpaperCategoryFeedEmptyBody => 'Añadimos nuevos con frecuencia. Vuelve pronto.';

  @override
  String get wallpaperCategoryFeedEmptyTitle => 'Aún no hay fondos de pantalla aquí';

  @override
  String wallpaperCategoryNamed(String name) {
    return 'Categoría, $name';
  }

  @override
  String get wallpaperChangeNow => 'Cambiar ahora';

  @override
  String get wallpaperCheckBackSoon => 'Vuelve pronto.';

  @override
  String get wallpaperCheckBackTomorrow => 'Vuelve mañana.';

  @override
  String get wallpaperCheckConnection => 'Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get wallpaperClear => 'Borrar';

  @override
  String get wallpaperClearFilters => 'Borrar filtros';

  @override
  String get wallpaperClearHistoryAction => 'Borrar historial';

  @override
  String get wallpaperClearHistoryBody =>
      'Se borrará la lista de fondos de pantalla que has establecido. Los fondos de pantalla seguirán tal como están.';

  @override
  String get wallpaperClearHistoryTitle => '¿Borrar el historial?';

  @override
  String get wallpaperClearSearch => 'Borrar búsqueda';

  @override
  String get wallpaperClosePreview => 'Cerrar vista previa';

  @override
  String get wallpaperCollapseDetails => 'Contraer detalles del fondo de pantalla';

  @override
  String get wallpaperCollection => 'Colección';

  @override
  String get wallpaperCollectionLoadError => 'No se pudo cargar esta colección';

  @override
  String wallpaperCollectionNamed(String name) {
    return 'Colección, $name';
  }

  @override
  String wallpaperCollectionPreviewUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Vista previa desbloqueada durante 24 horas (-$coinsString monedas).';
  }

  @override
  String get wallpaperCollectionRefreshError => 'No se pudo actualizar. Desliza hacia abajo para volver a intentarlo.';

  @override
  String get wallpaperCollectionsEmptyBody => 'Desliza hacia abajo para actualizar o vuelve pronto.';

  @override
  String get wallpaperCollectionsEmptyTitle => 'Aún no hay colecciones';

  @override
  String get wallpaperCopyAccentHexHint => 'Mantén pulsado para copiar el código hexadecimal del color';

  @override
  String wallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fondos de pantalla',
      one: '1 fondo de pantalla',
      zero: 'Ningún fondo de pantalla',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDelete => 'Eliminar';

  @override
  String get wallpaperDeleteManyDownloadsBody =>
      'Se eliminarán de este dispositivo. Puedes volver a descargarlos más tarde.';

  @override
  String wallpaperDeleteManyDownloadsTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '¿Eliminar $countString descargas?';
  }

  @override
  String get wallpaperDeleteOneDownloadBody =>
      'Se eliminará de este dispositivo. Puedes volver a descargarlo más tarde.';

  @override
  String get wallpaperDeleteOneDownloadTitle => '¿Eliminar esta descarga?';

  @override
  String get wallpaperDepthEditorSubtitle =>
      'En el editor de la pantalla de bloqueo, toca ••• y luego Efecto de profundidad.';

  @override
  String get wallpaperDepthEffect => 'Efecto de profundidad';

  @override
  String get wallpaperDepthSubjectSubtitle => 'El sujeto queda delante del reloj.';

  @override
  String get wallpaperDetailColorCodeCopied => 'Se copió el código de color al portapapeles';

  @override
  String get wallpaperDetailNotFound => 'No se encontró el fondo de pantalla';

  @override
  String get wallpaperDiscard => 'Descartar';

  @override
  String get wallpaperDismiss => 'Descartar';

  @override
  String get wallpaperDownload => 'Descargar';

  @override
  String wallpaperDownloadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString descargas',
      one: '1 descarga',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadSortName => 'Nombre';

  @override
  String get wallpaperDownloadSortNewest => 'Más recientes';

  @override
  String get wallpaperDownloadSortOldest => 'Más antiguos';

  @override
  String get wallpaperDownloadWallpaper => 'Descargar fondo de pantalla';

  @override
  String get wallpaperDownloadedWallpaper => 'Fondo de pantalla descargado';

  @override
  String get wallpaperDownloadedWallpaperUnavailable => 'El fondo de pantalla descargado no está disponible';

  @override
  String wallpaperDownloadsDeleteError(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron eliminar $countString descargas.',
      one: 'No se pudo eliminar 1 descarga.',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadsEmptyBody => 'Aquí se guardan los fondos de pantalla que descargas.';

  @override
  String get wallpaperDownloadsEmptyTitle => 'Aún no hay descargas';

  @override
  String get wallpaperDownloadsLoadError => 'No se pudieron cargar tus descargas';

  @override
  String get wallpaperDownloadsLoadHelp => 'Comprueba el acceso al almacenamiento e inténtalo de nuevo.';

  @override
  String get wallpaperDownloadsRefreshError => 'No se pudieron actualizar las descargas. Inténtalo de nuevo.';

  @override
  String get wallpaperDownloadsShareError => 'No se pudo compartir. Inténtalo de nuevo.';

  @override
  String get wallpaperDownloadsTitle => 'Descargas';

  @override
  String get wallpaperEdit => 'Editar';

  @override
  String get wallpaperEditTitle => 'Editar fondo de pantalla';

  @override
  String get wallpaperExpandDetails => 'Expandir detalles del fondo de pantalla';

  @override
  String get wallpaperFavourite => 'Añadir a favoritos';

  @override
  String get wallpaperFavouriteAddedToast => 'Añadido a favoritos.';

  @override
  String get wallpaperFavouriteClearAccountMessage => 'Se eliminarán de tu cuenta.';

  @override
  String get wallpaperFavouriteClearAll => 'Borrar todos los favoritos';

  @override
  String get wallpaperFavouriteClearDeviceMessage => 'Se eliminarán de este dispositivo.';

  @override
  String get wallpaperFavouriteClearError => 'No se pudieron borrar los favoritos. Inténtalo de nuevo.';

  @override
  String wallpaperFavouriteClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '¿Borrar $countString favoritos?';
  }

  @override
  String get wallpaperFavouriteClearOneTitle => '¿Borrar 1 favorito?';

  @override
  String wallpaperFavouriteClearedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favoritos',
      one: '1 favorito',
    );
    return 'Se borraron $_temp0';
  }

  @override
  String get wallpaperFavouriteClearedOne => 'Se borró 1 favorito';

  @override
  String wallpaperFavouriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favoritos',
      one: '1 favorito',
      zero: 'Ningún favorito',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteEmptyBody => 'Toca el corazón de un fondo de pantalla para guardarlo aquí.';

  @override
  String get wallpaperFavouriteEmptyTitle => 'Aún no tienes favoritos';

  @override
  String get wallpaperFavouriteExport => 'Exportar favoritos';

  @override
  String get wallpaperFavouriteExportEmpty => 'Aún no hay favoritos para exportar.';

  @override
  String get wallpaperFavouriteExportError => 'No se pudieron exportar los favoritos. Inténtalo de nuevo.';

  @override
  String get wallpaperFavouriteGuestPrompt => 'Inicia sesión para tenerlos en todos tus dispositivos';

  @override
  String get wallpaperFavouriteLoadError => 'No se pudieron cargar tus favoritos';

  @override
  String get wallpaperFavouriteMoreActions => 'Más acciones de favoritos';

  @override
  String get wallpaperFavouriteNoMatch => 'No hay favoritos que coincidan';

  @override
  String get wallpaperFavouriteNotSynced => 'Sin sincronizar';

  @override
  String get wallpaperFavouriteRefreshFallback =>
      'No se pudieron actualizar los favoritos. Se muestra la lista guardada.';

  @override
  String get wallpaperFavouriteRemove => 'Quitar';

  @override
  String get wallpaperFavouriteRemoveAction => 'Quitar de favoritos';

  @override
  String get wallpaperFavouriteRemoveError => 'No se pudieron quitar los favoritos. Inténtalo de nuevo.';

  @override
  String wallpaperFavouriteRemovedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favoritos',
      one: '1 favorito',
    );
    return 'Se quitaron $_temp0';
  }

  @override
  String get wallpaperFavouriteRemovedOne => 'Se quitó de favoritos';

  @override
  String get wallpaperFavouriteRemovedToast => 'Se quitó de favoritos.';

  @override
  String get wallpaperFavouriteRestoreError => 'No se pudieron restaurar los favoritos.';

  @override
  String get wallpaperFavouriteSearchHint => 'Buscar por creador o categoría';

  @override
  String get wallpaperFavouriteSetUsesFirst => 'Se aplicará el primer fondo que seleccionaste';

  @override
  String get wallpaperFavouriteShareError => 'No se pudieron compartir. Inténtalo de nuevo.';

  @override
  String get wallpaperFavouriteSortOldest => 'Más antiguos';

  @override
  String get wallpaperFavouriteSortRecentlyAdded => 'Añadidos recientemente';

  @override
  String get wallpaperFavouriteSortSource => 'Origen';

  @override
  String get wallpaperFavouriteStatus => 'En tus favoritos';

  @override
  String get wallpaperFavouriteTryDifferent => 'Prueba con otra búsqueda u otro origen.';

  @override
  String get wallpaperFavouriteUnavailableLegacy =>
      'Este favorito es de una versión anterior y no se puede abrir. Mantén pulsado para quitarlo.';

  @override
  String get wallpaperFavouriteWaitingSync => 'Esperando a sincronizar';

  @override
  String get wallpaperFavouritesTitle => 'Favoritos';

  @override
  String get wallpaperFeedAnnouncement => 'Anuncio';

  @override
  String get wallpaperFeedCaughtUpBody =>
      'Desliza hacia abajo para actualizar. Aquí aparecerán nuevas recomendaciones.';

  @override
  String get wallpaperFeedCaughtUpTitle => 'Ya viste todo por ahora';

  @override
  String get wallpaperFeedClearHistoryError => 'No se pudo borrar el historial. Inténtalo de nuevo.';

  @override
  String get wallpaperFeedDiscovery => 'Descubrir';

  @override
  String get wallpaperFeedEmptyBody => 'Sigue a creadores o elige tus intereses para ver más contenido que te guste.';

  @override
  String get wallpaperFeedEmptyTitle => 'Personaliza este feed';

  @override
  String get wallpaperFeedFollowingEmptyTitle => 'Sigue a creadores para ver aquí sus nuevos fondos de pantalla';

  @override
  String get wallpaperFeedFollowingLoadError => 'No se pudo cargar el feed de cuentas que sigues';

  @override
  String get wallpaperFeedLatestLoadError => 'No se pudieron cargar los fondos de pantalla más recientes';

  @override
  String get wallpaperFeedLearnedFromYou => 'Aprendido de ti';

  @override
  String get wallpaperFeedLearningEmpty => 'Abre, guarda y aplica fondos para personalizar tu feed.';

  @override
  String get wallpaperFeedLearningHistoryCleared => 'Se borró el historial de aprendizaje';

  @override
  String get wallpaperFeedLoadError => 'No se pudo cargar tu feed';

  @override
  String get wallpaperFeedLoadMoreError => 'No se pudo cargar más contenido. Inténtalo de nuevo';

  @override
  String get wallpaperFeedMixAdventurous => 'Arriesgado';

  @override
  String get wallpaperFeedMixAdventurousDescription => 'Más fondos fuera de tus gustos habituales.';

  @override
  String get wallpaperFeedMixBalanced => 'Equilibrado';

  @override
  String get wallpaperFeedMixBalancedDescription => 'Tus gustos, con algunas sorpresas.';

  @override
  String get wallpaperFeedMixFamiliar => 'Conocido';

  @override
  String get wallpaperFeedMixFamiliarDescription => 'Sobre todo, lo que ya te encanta.';

  @override
  String wallpaperFeedPickAtLeast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Elige al menos $countString';
  }

  @override
  String wallpaperFeedPickedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString seleccionados';
  }

  @override
  String get wallpaperFeedPopularEmptyTitle => 'Aún no hay fondos de pantalla populares';

  @override
  String get wallpaperFeedPopularLoadError => 'No se pudieron cargar los fondos de pantalla populares';

  @override
  String get wallpaperFeedPullToRefresh => 'Desliza hacia abajo para actualizar.';

  @override
  String get wallpaperFeedRefreshError => 'No se pudo actualizar tu feed.';

  @override
  String get wallpaperFeedSaveError => 'No se pudo guardar la configuración del feed. Inténtalo de nuevo.';

  @override
  String get wallpaperFeedSettingsHint => 'Toca dos veces para abrir la configuración del feed';

  @override
  String get wallpaperFeedStartingPoints => 'Para empezar';

  @override
  String get wallpaperFeedTabFollowing => 'Siguiendo';

  @override
  String get wallpaperFeedTabForYou => 'Para ti';

  @override
  String get wallpaperFeedTabLatest => 'Más recientes';

  @override
  String get wallpaperFeedTabPopular => 'Populares';

  @override
  String get wallpaperFeedTabTrending => 'En tendencia';

  @override
  String get wallpaperFeedTuneDescription => 'Prism aprende de los fondos que abres, guardas y aplicas.';

  @override
  String get wallpaperFeedTuneTitle => 'Personaliza tu feed';

  @override
  String get wallpaperFeedUpdating => 'Actualizando';

  @override
  String get wallpaperFeedWallsLoadError => 'No se pudieron cargar los fondos de pantalla';

  @override
  String get wallpaperFewerLikeThisConfirmation => 'Verás menos fondos de pantalla como este.';

  @override
  String get wallpaperFewerLikeThisUndo => 'Deshacer';

  @override
  String get wallpaperFileMovedOrDeleted => 'Es posible que el archivo se haya movido o eliminado.';

  @override
  String wallpaperFilterApplyCost(int coins, int missing) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'Aplicar este filtro cuesta $coinsString monedas. Te faltan $missingString.';
  }

  @override
  String get wallpaperFilterBlur => 'Desenfoque';

  @override
  String get wallpaperFilterBrightness => 'Brillo';

  @override
  String get wallpaperFilterEffectEdge => 'Bordes';

  @override
  String get wallpaperFilterEffectEmboss => 'Relieve';

  @override
  String get wallpaperFilterEffectHighPass => 'Paso alto';

  @override
  String get wallpaperFilterEffectSharpen => 'Enfoque';

  @override
  String get wallpaperFilterHoldToCompare => 'Mantén pulsado para comparar';

  @override
  String get wallpaperFilterHue => 'Tono';

  @override
  String get wallpaperFilterLightness => 'Luminosidad';

  @override
  String get wallpaperFilterLightnessUnavailable => 'La luminosidad no está disponible en este dispositivo.';

  @override
  String get wallpaperFilterNeedCoins => 'Necesitas monedas para el filtro prémium';

  @override
  String get wallpaperFilterOriginal => 'Original';

  @override
  String get wallpaperFilterSaturation => 'Saturación';

  @override
  String get wallpaperFilterSaveError => 'No se pudo guardar el fondo de pantalla. ¡Inténtalo de nuevo!';

  @override
  String get wallpaperFilterTabAdjustments => 'Ajustes';

  @override
  String get wallpaperFilterTabFilters => 'Filtros';

  @override
  String wallpaperFilterUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Filtro prémium desbloqueado para esta edición (-$coinsString monedas).';
  }

  @override
  String get wallpaperFitBlur => 'Ajustar con desenfoque';

  @override
  String get wallpaperFitColour => 'Ajustar con color';

  @override
  String get wallpaperFitFill => 'Rellenar';

  @override
  String get wallpaperGenericError => '¡Algo salió mal!';

  @override
  String get wallpaperGoBack => 'Volver';

  @override
  String get wallpaperGotItFewerLikeThis => 'Entendido. Verás menos fondos como este.';

  @override
  String get wallpaperHidePreviewControls => 'Ocultar controles';

  @override
  String get wallpaperHistoryBothScreens => 'Ambas pantallas';

  @override
  String get wallpaperHistoryCurrent => 'Actual';

  @override
  String get wallpaperHistoryCurrentPrefix => 'Actual. ';

  @override
  String get wallpaperHistoryEmptyBody => 'Aquí aparecerán los fondos que apliques para que puedas volver a usarlos.';

  @override
  String get wallpaperHistoryEmptyTitle => 'Aún no hay fondos de pantalla';

  @override
  String get wallpaperHistoryRemoveAction => 'Quitar del historial';

  @override
  String wallpaperHistoryTileSemantic(String current, String target, String date) {
    return '${current}Aplicar de nuevo. $target, $date';
  }

  @override
  String get wallpaperHistoryTitle => 'Historial de fondos de pantalla';

  @override
  String get wallpaperHomeAppName => 'Prism';

  @override
  String get wallpaperImageSemanticHint =>
      'Toca para cambiar el color. Mantén pulsado para favoritos, compartir y restablecer. Desplázate para ver los detalles.';

  @override
  String get wallpaperPreviousInFeed => 'Fondo de pantalla anterior';

  @override
  String get wallpaperNextInFeed => 'Siguiente fondo de pantalla';

  @override
  String get wallpaperImageSemanticLabel => 'Fondo de pantalla';

  @override
  String get wallpaperInsufficientCoins => 'No tienes suficientes monedas. Gana monedas en Recompensas.';

  @override
  String wallpaperInterestLearnedLabel(String label, int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Aprendido: $label, $percentString por ciento';
  }

  @override
  String wallpaperInterestSelectedLabel(String name, String selection) {
    return 'Interés: $name, $selection';
  }

  @override
  String get wallpaperLandscapeCrop => 'Fondo de pantalla horizontal: se recortarán los lados';

  @override
  String get wallpaperLibraryCollections => 'Colecciones';

  @override
  String get wallpaperLibraryDownloads => 'Descargas';

  @override
  String get wallpaperLibraryFavourites => 'Favoritos';

  @override
  String get wallpaperLibraryHistory => 'Historial';

  @override
  String get wallpaperLibraryHistoryBody => 'Los fondos que aplicaste, para que puedas volver a usarlos.';

  @override
  String get wallpaperLibraryHistoryTitle => 'Historial de fondos de pantalla';

  @override
  String get wallpaperLibraryOpenHistory => 'Abrir historial';

  @override
  String get wallpaperLibraryTitle => 'Biblioteca';

  @override
  String get wallpaperLive => 'En vivo';

  @override
  String get wallpaperLiveApplied => 'Fondo de pantalla animado aplicado.';

  @override
  String wallpaperLiveApplyPhotoDescription(String style) {
    return 'Vista previa de $style';
  }

  @override
  String get wallpaperLiveBatterySaver => 'Ahorro de batería';

  @override
  String get wallpaperLiveChooseAnotherVideo => 'Elegir otro video';

  @override
  String get wallpaperLiveChooseVideo => 'Elegir un video';

  @override
  String get wallpaperLiveConfirmPreview => 'Confirma la selección en la vista previa del sistema.';

  @override
  String get wallpaperLiveDeviceUnavailable => 'No está disponible en este dispositivo';

  @override
  String get wallpaperLiveErrorGeneric => 'No se pudo aplicar el fondo animado. Inténtalo de nuevo.';

  @override
  String get wallpaperLiveErrorImageTooLarge => 'La imagen es demasiado grande para usarla como fondo animado.';

  @override
  String get wallpaperLiveErrorMemory => 'No hay suficiente memoria. Cierra otras aplicaciones e inténtalo de nuevo.';

  @override
  String get wallpaperLiveErrorNotAllowed =>
      'Tu dispositivo o perfil de trabajo no permite cambiar el fondo de pantalla.';

  @override
  String get wallpaperLiveErrorPermission => 'Prism no tiene permiso para leer ese archivo.';

  @override
  String get wallpaperLiveErrorPreview => 'No se pudo abrir la vista previa del sistema.';

  @override
  String get wallpaperLiveErrorReadFile => 'No se pudo leer el archivo. Inténtalo de nuevo.';

  @override
  String get wallpaperLiveErrorStyle => 'Este dispositivo no pudo iniciar ese estilo. Prueba con otro.';

  @override
  String get wallpaperLiveErrorTimeout => 'Se agotó el tiempo de espera. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get wallpaperLiveErrorTooLarge => 'El archivo es demasiado grande para usarlo como fondo animado.';

  @override
  String get wallpaperLiveErrorVideo => 'No se puede usar ese video como fondo de pantalla. Prueba con otro clip.';

  @override
  String wallpaperLiveFps(int fps) {
    final intl.NumberFormat fpsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String fpsString = fpsNumberFormat.format(fps);

    return '$fpsString fotogramas por segundo';
  }

  @override
  String wallpaperLiveGradientDescription(String style) {
    return 'Vista previa de $style';
  }

  @override
  String wallpaperLiveGradientSwatch(String index, String count) {
    return 'Color del degradado $index de $count';
  }

  @override
  String get wallpaperLiveKeepPrismOpen => 'Mantén Prism abierto e inténtalo de nuevo.';

  @override
  String get wallpaperLiveModeGradients => 'Degradados';

  @override
  String get wallpaperLiveModePhoto => 'Dale vida a una foto';

  @override
  String get wallpaperLiveModeVideo => 'Video';

  @override
  String get wallpaperLiveNoVideo => 'No se eligió ningún video';

  @override
  String get wallpaperLivePreviewInstruction =>
      'Android abrirá una vista previa. Allí, toca Aplicar fondo de pantalla.';

  @override
  String get wallpaperLiveProStyleRequired => 'Este estilo forma parte de Prism Pro.';

  @override
  String get wallpaperLiveSetAction => 'Aplicar fondo animado';

  @override
  String get wallpaperLiveShaderUnsupported =>
      'Este dispositivo no puede ejecutar fondos animados con shaders. Prueba con un video.';

  @override
  String get wallpaperLiveStyleAurora => 'Aurora';

  @override
  String get wallpaperLiveStyleAuroraDescription => 'Suaves franjas de color.';

  @override
  String get wallpaperLiveStyleBreathe => 'Respirar';

  @override
  String get wallpaperLiveStyleBreatheDescription => 'Una pulsación suave, de dentro hacia fuera.';

  @override
  String get wallpaperLiveStyleDrift => 'Deriva';

  @override
  String get wallpaperLiveStyleDriftDescription =>
      'Paneo y zoom lentos. Sigue tus deslizamientos en la pantalla de inicio.';

  @override
  String get wallpaperLiveStyleMesh => 'Malla';

  @override
  String get wallpaperLiveStyleMeshDescription => 'Colores mezclados que cambian lentamente.';

  @override
  String get wallpaperLiveStylePlasma => 'Plasma';

  @override
  String get wallpaperLiveStylePlasmaDescription => 'Color fluido y uniforme.';

  @override
  String get wallpaperLiveStyleRipple => 'Ondas';

  @override
  String get wallpaperLiveStyleRippleDescription => 'Ondas de agua que se expanden desde donde tocas.';

  @override
  String get wallpaperLiveStyleShimmer => 'Destello';

  @override
  String get wallpaperLiveStyleShimmerDescription => 'Un suave destello de luz.';

  @override
  String get wallpaperLiveStyleStarfield => 'Campo de estrellas';

  @override
  String get wallpaperLiveStyleStarfieldDescription => 'Estrellas brillantes sobre un fondo completamente negro.';

  @override
  String wallpaperLiveStyleUnlocked(String style) {
    return '$style está desbloqueado durante 7 días.';
  }

  @override
  String get wallpaperLiveStyleWaves => 'Olas';

  @override
  String get wallpaperLiveStyleWavesDescription => 'Olas en capas que se desplazan.';

  @override
  String get wallpaperLiveTextureDownloadFailed =>
      'No se pudo descargar el fondo de pantalla. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get wallpaperLiveTexturePrepareFailed => 'No se pudo preparar el fondo de pantalla.';

  @override
  String get wallpaperLiveTextureTooDetailed => 'Ese fondo tiene demasiados detalles para animarlo.';

  @override
  String get wallpaperLiveTitle => 'Fondos de pantalla animados';

  @override
  String get wallpaperLiveUnavailableBody => 'Se necesita un teléfono Android compatible con fondos animados OpenGL.';

  @override
  String get wallpaperLiveUnavailableTitle => 'Los fondos de pantalla animados no están disponibles';

  @override
  String wallpaperLiveUnlockCoins(String coins) {
    return 'Desbloquear · $coins monedas';
  }

  @override
  String wallpaperLiveUnlockError(String style) {
    return 'No se pudo desbloquear $style. Inténtalo de nuevo.';
  }

  @override
  String wallpaperLiveUnlockStyleAction(String style, String coins) {
    return 'Desbloquear $style durante 7 días · $coins monedas';
  }

  @override
  String get wallpaperLiveUnlockStyleBody =>
      'Desbloquéalo durante 7 días con monedas o consigue Prism Pro para acceder a todos los estilos.';

  @override
  String wallpaperLiveUnlockStyleTitle(String style) {
    return '$style es un estilo de pago';
  }

  @override
  String get wallpaperLiveUnsupported => 'Este dispositivo no puede mostrar fondos de pantalla animados.';

  @override
  String get wallpaperLiveVideoChosen => 'Video seleccionado';

  @override
  String get wallpaperLiveVideoDescription => 'Se reproduce en la pantalla de inicio sin sonido. Hasta 256 MB.';

  @override
  String get wallpaperLiveVideoReadFailed => 'No se pudo leer ese video. Selecciónalo de nuevo.';

  @override
  String get wallpaperLiveVideoTooLarge => 'El video supera los 256 MB. Elige un clip más corto.';

  @override
  String get wallpaperLiveVideoUnsupported => 'Este dispositivo no puede usar videos como fondo de pantalla.';

  @override
  String get wallpaperLoadingImage => 'Cargando imagen';

  @override
  String get wallpaperLoadingWallpaper => 'Cargando fondo de pantalla';

  @override
  String get wallpaperLowResolutionScreen => 'Resolución baja para tu pantalla';

  @override
  String get wallpaperMakeItLive => 'Aplicar como fondo animado';

  @override
  String get wallpaperMatchSystemColour => 'Usar el color del sistema';

  @override
  String get wallpaperMoreLikeThis => 'Más como este';

  @override
  String get wallpaperNavCollections => 'Colecciones';

  @override
  String get wallpaperNavHome => 'Inicio';

  @override
  String get wallpaperNavRewards => 'Recompensas';

  @override
  String get wallpaperNavSearch => 'Buscar';

  @override
  String get wallpaperNew => 'Nuevo';

  @override
  String get wallpaperNotNow => 'Ahora no';

  @override
  String get wallpaperNotSelected => 'no seleccionado';

  @override
  String get wallpaperNotificationPromptBody =>
      'Un fondo elegido a mano cada mañana y recordatorios para mantener tu racha. Sin spam.';

  @override
  String get wallpaperNotificationPromptTitle => 'Descubre el Fondo del día';

  @override
  String get wallpaperOffline => 'Sin conexión';

  @override
  String wallpaperOldVersionBody(String version) {
    return 'La versión $version ya no es compatible. Actualiza Prism para seguir usándola.';
  }

  @override
  String get wallpaperOldVersionTitle => 'Es hora de actualizar';

  @override
  String get wallpaperOnPrism => 'Fondo de pantalla en Prism';

  @override
  String get wallpaperOpenError => 'No se pudo cargar este fondo de pantalla';

  @override
  String get wallpaperOpenFileError => 'No se pudo abrir este fondo de pantalla';

  @override
  String get wallpaperOpenNotifications => 'Abrir notificaciones';

  @override
  String get wallpaperOtherSource => 'Otra fuente';

  @override
  String get wallpaperPastPicksEmpty => 'Aún no hay selecciones anteriores';

  @override
  String get wallpaperPastPicksLoadError => 'No se pudieron cargar las selecciones anteriores';

  @override
  String get wallpaperPastPicksTitle => 'Selecciones anteriores';

  @override
  String get wallpaperPlacementDim => 'Oscurecer';

  @override
  String get wallpaperPositionApproximate => 'Es aproximado. El resultado puede variar según el launcher.';

  @override
  String get wallpaperPremium => 'Premium';

  @override
  String get wallpaperPremiumCollection => 'Colección Premium';

  @override
  String wallpaperPremiumCollectionNamed(String name) {
    return 'Colección Premium, $name';
  }

  @override
  String get wallpaperPreviewHome => 'Inicio';

  @override
  String get wallpaperPreviewIconClear => 'Transparente';

  @override
  String get wallpaperPreviewIconDark => 'Oscuro';

  @override
  String get wallpaperPreviewIconDefault => 'Predeterminado';

  @override
  String get wallpaperPreviewIconStyle => 'Estilo de iconos';

  @override
  String get wallpaperPreviewIconThemed => 'Temático';

  @override
  String get wallpaperPreviewIconTinted => 'Tintado';

  @override
  String get wallpaperPreviewLock => 'Bloqueo';

  @override
  String get wallpaperPreviewOnScreen => 'Vista previa en tu pantalla';

  @override
  String get wallpaperPreviewSetBoth => 'Configurar en ambas pantallas';

  @override
  String get wallpaperPreviewSetHome => 'Configurar en pantalla de inicio';

  @override
  String get wallpaperPreviewSetLock => 'Configurar en pantalla de bloqueo';

  @override
  String wallpaperPreviewUnlock24Hours(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Desbloquear durante 24 horas (-$costString)';
  }

  @override
  String wallpaperPreviewUnlockCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Previsualiza esta colección Premium durante 24 horas por $costString monedas.';
  }

  @override
  String wallpaperPreviewUnlockCostMissing(int cost, int missing) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'Una vista previa de 24 horas cuesta $costString monedas. Te faltan $missingString.';
  }

  @override
  String wallpaperPreviewWatchAdUnlock(String adOption) {
    return '$adOption y desbloquear';
  }

  @override
  String get wallpaperProcessing => 'Procesando fondo de pantalla';

  @override
  String get wallpaperProfileOpenError => 'No se pudo abrir el perfil';

  @override
  String get wallpaperQuickAddAction => 'Añadir a Ajustes rápidos';

  @override
  String get wallpaperQuickFavouriteDescription =>
      'Aplica un fondo de pantalla aleatorio de tus favoritos. Inicia sesión y añade algunos fondos a favoritos primero.';

  @override
  String get wallpaperQuickFavouriteTitle => 'Acceso directo a un favorito aleatorio';

  @override
  String get wallpaperQuickHowToTitle => 'Cómo añadir un acceso directo';

  @override
  String get wallpaperQuickShuffleDescription =>
      'Toca el acceso directo para aplicar un fondo de pantalla aleatorio de la categoría que elijas.';

  @override
  String get wallpaperQuickShuffleTitle => 'Acceso directo para cambiar de fondo';

  @override
  String get wallpaperQuickStepEdit => 'Toca el lápiz o el icono de edición.';

  @override
  String get wallpaperQuickStepFindPrism => 'Busca los accesos directos de Prism y arrástralos a los accesos activos.';

  @override
  String get wallpaperQuickStepShade => 'Desliza hacia abajo dos veces desde la parte superior de la pantalla.';

  @override
  String get wallpaperQuickTargetBoth => 'Ambas';

  @override
  String get wallpaperQuickTargetHome => 'Inicio';

  @override
  String get wallpaperQuickTargetLock => 'Bloqueo';

  @override
  String get wallpaperQuickTileAddError =>
      'No se pudo añadir el acceso directo. Añádelo manualmente desde la pantalla de edición de Ajustes rápidos.';

  @override
  String get wallpaperQuickTileAdded => 'Acceso directo añadido a Ajustes rápidos.';

  @override
  String get wallpaperQuickTileAlreadyAdded => 'Este acceso directo ya está en Ajustes rápidos.';

  @override
  String get wallpaperQuickTileNotAdded => 'No se añadió el acceso directo. Puedes añadirlo cuando quieras.';

  @override
  String get wallpaperQuickTileSaveError => 'No se pudo guardar la configuración de los accesos directos';

  @override
  String get wallpaperQuickTilesLoadError => 'No se pudieron cargar tus accesos directos';

  @override
  String get wallpaperQuickTilesTitle => 'Accesos rápidos';

  @override
  String get wallpaperQuickWotdDescription =>
      'Aplica el fondo del día de hoy. Abre Prism una vez al día para guardar el más reciente en la caché.';

  @override
  String get wallpaperQuickWotdTitle => 'Acceso directo al fondo del día';

  @override
  String get wallpaperRecentlySet => 'Usados recientemente';

  @override
  String get wallpaperRefresh => 'Actualizar';

  @override
  String get wallpaperRemovedFromHistory => 'Se quitó del historial';

  @override
  String get wallpaperReport => 'Denunciar';

  @override
  String get wallpaperReset => 'Restablecer';

  @override
  String get wallpaperSave => 'Guardar';

  @override
  String get wallpaperSaveToPhotos => 'Guardar en Fotos';

  @override
  String get wallpaperSavedOnDevice => 'Guardado en este dispositivo';

  @override
  String wallpaperSearchTag(String tag) {
    return 'Buscar $tag';
  }

  @override
  String get wallpaperSeePrismPro => 'Ver Prism Pro';

  @override
  String get wallpaperSelected => 'seleccionado';

  @override
  String get wallpaperServerUnavailable => 'No se puede conectar con los servidores';

  @override
  String get wallpaperSessionEnded => 'Tu sesión ha caducado. Vuelve a iniciar sesión.';

  @override
  String get wallpaperSet => 'Aplicar';

  @override
  String get wallpaperSetAgain => 'Volver a aplicar este fondo de pantalla';

  @override
  String get wallpaperSetAsWallpaper => 'Establecer como fondo de pantalla';

  @override
  String wallpaperSetCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aplicado $countString veces',
      one: 'Aplicado una vez',
    );
    return '$_temp0';
  }

  @override
  String get setScreenTargetHome => 'Pantalla de inicio';

  @override
  String get setScreenTargetLock => 'Pantalla de bloqueo';

  @override
  String get setScreenTargetBoth => 'Ambas';

  @override
  String get setScreenTargetGroup => 'Dónde configurarlo';

  @override
  String get setScreenRemember => 'Recordar esta elección';

  @override
  String get setScreenRememberHint =>
      'Configurar omite esta pantalla la próxima vez. Mantén pulsado Configurar para volver.';

  @override
  String get setScreenAdjust => 'Ajustar';

  @override
  String get setScreenMore => 'Más';

  @override
  String get setScreenPairLock => 'Usar otro fondo para la pantalla de bloqueo';

  @override
  String get setScreenOpenSystemEditor => 'Abrir editor del sistema';

  @override
  String get setScreenClose => 'Cerrar';

  @override
  String get wallpaperShare => 'Compartir';

  @override
  String get wallpaperShareLink => 'Compartir enlace';

  @override
  String get wallpaperShortcutsAddActionsSteps =>
      'Añade la acción \"Get Prism Wallpaper\". Después, añade la acción \"Set Wallpaper\".';

  @override
  String get wallpaperShortcutsBody =>
      'Usa Atajos para poner un fondo según un horario o activador. Prepara la fuente de abajo antes de ejecutarlo.';

  @override
  String get wallpaperShortcutsChoosePrismData => 'Elige qué datos envía Prism';

  @override
  String get wallpaperShortcutsChooseTriggerSteps =>
      'En el editor de atajos, abre Automatización si hace falta. Elige y configura un activador, como una hora del día, abrir una app o conectar un cargador.';

  @override
  String get wallpaperShortcutsDisableConfirmationSteps =>
      'Revisa las opciones de ejecución que aparezcan y guarda el atajo o la automatización. Si aparece \"Preguntar antes de ejecutar\", desactívalo para que se ejecute automáticamente.';

  @override
  String get wallpaperShortcutsHeadline => 'Cambia tu fondo de pantalla automáticamente';

  @override
  String get wallpaperShortcutsOpenAction => 'Abrir Atajos';

  @override
  String get wallpaperShortcutsOpenAutomationSteps =>
      'Abre Atajos. Si hay una pestaña Automatización, tócala y luego Nueva automatización. Si no, toca Añadir (+) y después Editar si aparece.';

  @override
  String get wallpaperShortcutsOpenError => 'No se pudo abrir Atajos. Abre la app manualmente.';

  @override
  String get wallpaperShortcutsSourceFavourite => 'Favorito aleatorio';

  @override
  String get wallpaperShortcutsSourceFavouriteDescription =>
      'Un favorito aleatorio disponible para Atajos. Marca fondos como favoritos en Prism primero. Algunos fondos protegidos pueden no estar disponibles. Evita repetir el último si hay otro favorito disponible.';

  @override
  String get wallpaperShortcutsSourceWotd => 'Fondo del día';

  @override
  String get wallpaperShortcutsSourceWotdDescription =>
      'La selección de hoy de Prism. Descarga primero el original de hoy en Prism. Cuando cambie la selección diaria, descarga el nuevo original antes de ejecutar esta fuente.';

  @override
  String get wallpaperShortcutsSteps => 'Pasos';

  @override
  String get wallpaperShortcutsTitle => 'Cambiar automáticamente';

  @override
  String get wallpaperShowLessLikeThis => 'Mostrar menos como este';

  @override
  String get wallpaperShowPreviewControls => 'Mostrar controles';

  @override
  String get wallpaperSignIn => 'Iniciar sesión';

  @override
  String get wallpaperSignInForPremiumFilters => 'Inicia sesión para usar filtros Premium con monedas.';

  @override
  String get wallpaperSort => 'Ordenar';

  @override
  String get wallpaperSortDownloads => 'Ordenar descargas';

  @override
  String get wallpaperStartupFailed => 'No se pudo iniciar Prism';

  @override
  String get wallpaperThemeDarkAccent => 'Color de acento oscuro';

  @override
  String get wallpaperThemeDarkThemes => 'Temas oscuros';

  @override
  String get wallpaperUseAsAppAccent => 'Usar como color de acento de la app';

  @override
  String get wallpaperAppAccentUpdated => 'Color de acento de la app actualizado';

  @override
  String get wallpaperThemeLightAccent => 'Color de acento claro';

  @override
  String get wallpaperThemeLightThemes => 'Temas claros';

  @override
  String get wallpaperThemeModeDark => 'Oscuro';

  @override
  String get wallpaperThemeModeLight => 'Claro';

  @override
  String get wallpaperThemeModeSystem => 'Sistema (claro/oscuro)';

  @override
  String get wallpaperThemePreference => 'Preferencia de tema';

  @override
  String get wallpaperThemePreferenceDescription =>
      'Elige el tema que prefieras. El modo del sistema cambia automáticamente entre claro y oscuro según la configuración de tu dispositivo.';

  @override
  String get wallpaperThemeTitle => 'Temas';

  @override
  String get wallpaperTitle => 'Título';

  @override
  String get wallpaperTrendingEmptyTitle => 'Aún no hay fondos populares';

  @override
  String get wallpaperTrendingLoadError => 'No se pudieron cargar los fondos populares';

  @override
  String get wallpaperTryAgain => 'Intentar de nuevo';

  @override
  String get wallpaperTurnOff => 'Desactivar';

  @override
  String get wallpaperTurnOnNotifications => 'Activar notificaciones';

  @override
  String get wallpaperUnavailable => 'No disponible';

  @override
  String get wallpaperUnfavourite => 'Quitar de favoritos';

  @override
  String get wallpaperUnreadItems => 'Tiene elementos sin leer';

  @override
  String get wallpaperUpdatePrism => 'Actualizar Prism';

  @override
  String get wallpaperUploadAction => 'Subir';

  @override
  String get wallpaperUploadAddTag => 'Añadir etiqueta';

  @override
  String get wallpaperUploadAddTagHint => 'Añade una etiqueta y toca Listo';

  @override
  String get wallpaperUploadAiSubtitle => 'Describe una escena y crea un fondo de pantalla para tu teléfono';

  @override
  String get wallpaperUploadApprovalInfo =>
      'Tu fondo aparecerá en la comunidad cuando se apruebe. Puedes seguir su estado en Tus subidas.';

  @override
  String wallpaperUploadBatchPosition(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Fondo de pantalla $positionString de $totalString';
  }

  @override
  String wallpaperUploadBatchSubmitted(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label. Se enviaron $countString.';
  }

  @override
  String wallpaperUploadBatchSummaryNotSent(String submitted, int notSent) {
    final intl.NumberFormat notSentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String notSentString = notSentNumberFormat.format(notSent);

    return '$submitted. No se enviaron $notSentString.';
  }

  @override
  String wallpaperUploadBatchSummarySubmitted(int submittedCount, int total) {
    final intl.NumberFormat submittedCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String submittedCountString = submittedCountNumberFormat.format(submittedCount);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Se enviaron $submittedCountString de $totalString fondos de pantalla';
  }

  @override
  String get wallpaperUploadBrightness => 'Brillo';

  @override
  String get wallpaperUploadCheckReviewStatus => 'Consultar estado de revisión';

  @override
  String get wallpaperUploadChooseAnotherImage => 'Elegir otra imagen';

  @override
  String get wallpaperUploadContinueDraft => 'Seguir editando el fondo guardado';

  @override
  String get wallpaperUploadContrast => 'Contraste';

  @override
  String get wallpaperUploadCreateTitle => 'Crear';

  @override
  String get wallpaperUploadDeleteConfirmTitle => '¿Eliminar este fondo de pantalla?';

  @override
  String get wallpaperUploadDeleteError => 'No se pudo eliminar. Inténtalo de nuevo.';

  @override
  String get wallpaperUploadDeletePermissionError =>
      'No se pudo eliminar. Inicia sesión con la cuenta que usaste para subirlo e inténtalo de nuevo.';

  @override
  String get wallpaperUploadDeleteWallpaper => 'Eliminar fondo de pantalla';

  @override
  String get wallpaperUploadDeleted => 'Fondo de pantalla eliminado.';

  @override
  String get wallpaperUploadDetailsOptional => 'Detalles (opcional)';

  @override
  String get wallpaperUploadDiscardBody =>
      'Se quitarán los archivos subidos. La imagen que seleccionaste seguirá en tu dispositivo.';

  @override
  String get wallpaperUploadDiscardEditsBody => 'Se perderán los cambios.';

  @override
  String get wallpaperUploadDiscardEditsTitle => '¿Descartar los cambios?';

  @override
  String get wallpaperUploadDiscardError => 'No se pudo descartar esta subida. Inténtalo de nuevo.';

  @override
  String get wallpaperUploadDiscardTitle => '¿Descartar esta subida?';

  @override
  String get wallpaperUploadDownloadError => 'No se pudo descargar. Inténtalo de nuevo.';

  @override
  String get wallpaperUploadDownloadStarting => 'Iniciando descarga';

  @override
  String get wallpaperUploadDraftSaveError => 'No se pudo guardar el borrador. Inténtalo de nuevo.';

  @override
  String wallpaperUploadEditBatch(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Editar fondo de pantalla $positionString de $totalString';
  }

  @override
  String get wallpaperUploadEditSaveError => 'No se pudieron guardar los cambios. Inténtalo de nuevo.';

  @override
  String get wallpaperUploadFileSize => 'Tamaño';

  @override
  String get wallpaperUploadFilesCheckActive => 'Subiendo el fondo de pantalla y su vista previa';

  @override
  String get wallpaperUploadFilesCheckDone => 'Fondo de pantalla y vista previa subidos';

  @override
  String get wallpaperUploadFilesCheckPending => 'Subir el fondo de pantalla y su vista previa';

  @override
  String get wallpaperUploadFilesRemoveError => 'No se pudieron quitar los archivos subidos. Inténtalo de nuevo.';

  @override
  String get wallpaperUploadFlip => 'Voltear';

  @override
  String wallpaperUploadFreeQuotaMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Las cuentas gratuitas pueden subir $countString fondos de pantalla por semana.';
  }

  @override
  String get wallpaperUploadFromGallery => 'Desde tu galería';

  @override
  String get wallpaperUploadFullImageError => 'No se pudo cargar la imagen completa.';

  @override
  String get wallpaperUploadInReview => 'En revisión';

  @override
  String get wallpaperUploadKeepDraft => 'Conservar borrador';

  @override
  String get wallpaperUploadLeaveBody =>
      'Conserva el borrador para continuar más tarde o descártalo para quitar los archivos subidos.';

  @override
  String get wallpaperUploadLeaveTitle => '¿Salir de esta subida?';

  @override
  String wallpaperUploadMaxTagsReached(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Has añadido $countString etiquetas';
  }

  @override
  String get wallpaperUploadOriginalContentGuideline =>
      'Sube solo fondos de pantalla originales y de alta calidad. No subas contenido de otras apps.';

  @override
  String get wallpaperUploadPrepareCheckActive => 'Preparando la imagen y una vista previa más pequeña';

  @override
  String get wallpaperUploadPrepareCheckDone => 'La imagen y la vista previa están listas';

  @override
  String get wallpaperUploadPrepareCheckPending => 'Preparar la imagen y una vista previa más pequeña';

  @override
  String get wallpaperUploadPrepareError => 'No se pudo preparar esta imagen. Inténtalo de nuevo o elige otra.';

  @override
  String get wallpaperUploadQualityLandscape =>
      'Esta imagen es apaisada. Los fondos para teléfono se ven mejor en vertical.';

  @override
  String wallpaperUploadQualityLowResolution(int width, int height, int recommendedShortSide) {
    final intl.NumberFormat widthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String widthString = widthNumberFormat.format(width);
    final intl.NumberFormat recommendedShortSideNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String recommendedShortSideString = recommendedShortSideNumberFormat.format(recommendedShortSide);

    return 'Esta imagen mide ${widthString}x$height. Puede verse borrosa en un teléfono. Lo ideal es que el lado más corto mida $recommendedShortSideString px.';
  }

  @override
  String get wallpaperUploadQuotaCleanupFailed =>
      'Has alcanzado el límite de subidas, pero no se pudieron quitar los archivos subidos. Toca Atrás para volver a intentarlo.';

  @override
  String get wallpaperUploadQuotaReached =>
      'Has alcanzado el límite semanal de fondos de pantalla que puedes subir gratis.';

  @override
  String wallpaperUploadQuotaRemaining(int remaining, int total) {
    final intl.NumberFormat remainingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Te quedan $remainingString de $totalString subidas gratuitas esta semana';
  }

  @override
  String get wallpaperUploadRejected => 'Rechazado';

  @override
  String get wallpaperUploadRejectedSectionError => 'No se pudieron cargar tus envíos rechazados.';

  @override
  String get wallpaperUploadRejectionFallback =>
      'No se indicó un motivo concreto. Revisa los detalles del fondo de pantalla y vuelve a subirlo.';

  @override
  String get wallpaperUploadRejectionTitle => 'Motivo del rechazo';

  @override
  String wallpaperUploadRemoveTag(String tag) {
    return 'Quitar la etiqueta $tag';
  }

  @override
  String get wallpaperUploadResetAdjustments => 'Restablecer ajustes';

  @override
  String get wallpaperUploadResolution => 'Resolución';

  @override
  String get wallpaperUploadResumeDraft => 'Reanudar subida guardada';

  @override
  String get wallpaperUploadRetrySubmit => 'Reintentar envío';

  @override
  String get wallpaperUploadReviewCheckActive => 'Guardando tu envío para revisión';

  @override
  String get wallpaperUploadReviewCheckDone => 'Enviado para revisión';

  @override
  String get wallpaperUploadReviewCheckPending => 'El equipo de moderación lo revisará antes de que aparezca en Prism';

  @override
  String get wallpaperUploadReviewEmptyBody => 'Aquí puedes consultar el estado de revisión de los fondos que subas.';

  @override
  String get wallpaperUploadReviewEmptyTitle => 'Todavía no hay nada';

  @override
  String get wallpaperUploadReviewLoadError => 'No se pudieron cargar tus subidas';

  @override
  String get wallpaperUploadReviewSectionError => 'No se pudieron cargar tus envíos.';

  @override
  String get wallpaperUploadRotateLeft => 'Girar a la izquierda';

  @override
  String get wallpaperUploadRotateRight => 'Girar a la derecha';

  @override
  String get wallpaperUploadSaturation => 'Saturación';

  @override
  String get wallpaperUploadSavedToPictures => 'Fondo de pantalla guardado en Pictures/Prism';

  @override
  String get wallpaperUploadSkip => 'Omitir este fondo de pantalla';

  @override
  String get wallpaperUploadStagePrepareFailed => 'No se pudo preparar la imagen';

  @override
  String get wallpaperUploadStagePreparing => 'Preparando el fondo de pantalla';

  @override
  String get wallpaperUploadStageQuotaReached => 'Límite de subidas alcanzado';

  @override
  String get wallpaperUploadStageReady => 'Listo para enviar';

  @override
  String get wallpaperUploadStageSubmissionFailed => 'No se pudo completar el envío';

  @override
  String get wallpaperUploadStageSubmitting => 'Enviando el fondo de pantalla';

  @override
  String get wallpaperUploadStageUploadFailed => 'No se pudo completar la subida';

  @override
  String get wallpaperUploadStageUploading => 'Subiendo el fondo de pantalla';

  @override
  String get wallpaperUploadSubmissionUnconfirmed =>
      'No se pudo confirmar el envío. Consulta el estado de revisión antes de volver a intentarlo.';

  @override
  String get wallpaperUploadTags => 'Etiquetas';

  @override
  String wallpaperUploadTagsHelp(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Hasta $countString. Las etiquetas ayudan a otras personas a encontrar tu fondo de pantalla.';
  }

  @override
  String get wallpaperUploadTitle => 'Subir fondo de pantalla';

  @override
  String get wallpaperUploadTitleHint => 'Ponle un nombre a tu fondo de pantalla';

  @override
  String get wallpaperUploadViewWallpaper => 'Ver fondo de pantalla';

  @override
  String get wallpaperUploadYourUploads => 'Tus subidas';

  @override
  String get wallpaperUsePhoneAccent => 'Usar el color de acento de tu teléfono';

  @override
  String get wallpaperThemeMaterialYouNote => 'Material You toma los colores de tu fondo de pantalla.';

  @override
  String wallpaperViewCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString visualizaciones',
      one: '1 visualización',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperViewCountUnavailable => 'Número de visualizaciones no disponible';

  @override
  String wallpaperWotdByPhotographer(String name) {
    return 'Fondo del día de $name';
  }

  @override
  String get economyAiPromptSceneAnime1 => 'un gato dormitando en un andén soleado';

  @override
  String get economyAiPromptSceneAnime2 => 'nubes de verano gigantes sobre arrozales';

  @override
  String get economyAiPromptSceneAnime3 => 'un puesto de ramen luminoso en una calle lluviosa';

  @override
  String get economyAiPromptSceneAnime4 => 'un torii en una colina sobre un mar de nubes';

  @override
  String get economyAiPromptSceneAnime5 => 'fuegos artificiales sobre un río en un festival';

  @override
  String get economyAiPromptSceneAnime6 => 'un aula tranquila con pétalos entrando al viento';

  @override
  String get economyAiPromptSceneAnime7 => 'una carretera costera con una parada solitaria';

  @override
  String get economyAiPromptSceneAnime8 => 'una ballena celeste flotando sobre un pueblo';

  @override
  String get economyAiPromptSceneMinimal1 => 'un barquito de papel sobre agua pálida y quieta';

  @override
  String get economyAiPromptSceneMinimal2 => 'un arco de luz sobre una llanura vacía';

  @override
  String get economyAiPromptSceneMinimal3 => 'un árbol solitario en una suave ladera nevada';

  @override
  String get economyAiPromptSceneMinimal4 => 'dos círculos superpuestos sobre grano suave';

  @override
  String get economyAiPromptSceneMinimal5 => 'una fina línea de horizonte entre mar y cielo';

  @override
  String get economyAiPromptSceneMinimal6 => 'una sola pluma cayendo por el espacio vacío';

  @override
  String get economyAiPromptSceneMinimal7 => 'guijarros lisos apilados sobre fondo claro';

  @override
  String get economyAiPromptSceneMinimal8 => 'una sombra en media luna sobre un muro de yeso';

  @override
  String get economyAiPromptSceneCyberpunk1 => 'un bar de fideos bajo la lluvia y luces de neón';

  @override
  String get economyAiPromptSceneCyberpunk2 => 'un tren flotante entre megatorres';

  @override
  String get economyAiPromptSceneCyberpunk3 => 'un androide solitario en una azotea bajo la lluvia';

  @override
  String get economyAiPromptSceneCyberpunk4 => 'una autopista de datos hacia una ciudad inmensa';

  @override
  String get economyAiPromptSceneCyberpunk5 => 'un mercado nocturno bajo una maraña de cables';

  @override
  String get economyAiPromptSceneCyberpunk6 => 'una moto cromada aparcada en un callejón neón';

  @override
  String get economyAiPromptSceneCyberpunk7 => 'una luna holográfica sobre torres de la ciudad';

  @override
  String get economyAiPromptSceneCyberpunk8 => 'una calle inundada que refleja pantallas';

  @override
  String get economyAiPromptSceneWatercolor1 => 'un campo de lavanda entre la bruma matinal';

  @override
  String get economyAiPromptSceneWatercolor2 => 'un pueblo pesquero junto a un puerto tranquilo';

  @override
  String get economyAiPromptSceneWatercolor3 => 'amapolas silvestres junto a un camino rural';

  @override
  String get economyAiPromptSceneWatercolor4 => 'un globo aerostático sobre suaves colinas verdes';

  @override
  String get economyAiPromptSceneWatercolor5 => 'una garza en un estanque lleno de juncos';

  @override
  String get economyAiPromptSceneWatercolor6 => 'una calle lluviosa con farolas difuminadas';

  @override
  String get economyAiPromptSceneWatercolor7 => 'una taza humeante junto a una ventana abierta';

  @override
  String get economyAiPromptSceneWatercolor8 => 'pinos nevados junto a un arroyo helado y sinuoso';

  @override
  String get economyAiPromptSceneMeshGradient1 => 'manchas de color suaves fundiéndose entre sí';

  @override
  String get economyAiPromptSceneMeshGradient2 => 'una ola de degradado sedoso plegándose';

  @override
  String get economyAiPromptSceneMeshGradient3 => 'orbes brillantes sobre un fondo aterciopelado';

  @override
  String get economyAiPromptSceneMeshGradient4 => 'un degradado tipo aurora que sube en barrido';

  @override
  String get economyAiPromptSceneMeshGradient5 => 'charcos de color líquido con grano fino';

  @override
  String get economyAiPromptSceneMeshGradient6 => 'un degradado de cálido a frío con ruido suave';

  @override
  String get economyAiPromptSceneMeshGradient7 => 'pétalos translúcidos de degradado superpuestos';

  @override
  String get economyAiPromptSceneMeshGradient8 => 'un atardecer difuminado de bandas de color fluido';

  @override
  String get economyAiPromptSceneAbstract1 => 'vidrios rotos entrelazados que atrapan la luz';

  @override
  String get economyAiPromptSceneAbstract2 => 'nubes de tinta fluyendo suspendidas en el agua';

  @override
  String get economyAiPromptSceneAbstract3 => 'una espiral de cintas plegadas en movimiento';

  @override
  String get economyAiPromptSceneAbstract4 => 'mármol roto con vetas de oro';

  @override
  String get economyAiPromptSceneAbstract5 => 'ondulantes curvas de nivel en capas';

  @override
  String get economyAiPromptSceneAbstract6 => 'esferas flotantes que proyectan largas sombras';

  @override
  String get economyAiPromptSceneAbstract7 => 'estelas de humo que se enroscan en un vórtice';

  @override
  String get economyAiPromptSceneAbstract8 => 'un campo de cubos suaves que se alza en olas';

  @override
  String get economyAiPromptSceneNature1 => 'una cascada cayendo a un desfiladero de musgo';

  @override
  String get economyAiPromptSceneNature2 => 'un campo de girasoles bajo un cielo inmenso';

  @override
  String get economyAiPromptSceneNature3 => 'un lago helado con grietas de hielo azul';

  @override
  String get economyAiPromptSceneNature4 => 'cerezos a lo largo de un sendero junto al río';

  @override
  String get economyAiPromptSceneNature5 => 'una laguna tropical vista desde arriba';

  @override
  String get economyAiPromptSceneNature6 => 'arces otoñales reflejados en un estanque quieto';

  @override
  String get economyAiPromptSceneNature7 => 'un zorro solitario en nieve fresca al alba';

  @override
  String get economyAiPromptSceneNature8 => 'nubes de tormenta sobre verdes tierras altas';

  @override
  String get economyAiPromptSceneSpace1 => 'un planeta con anillos sobre el horizonte lunar';

  @override
  String get economyAiPromptSceneSpace2 => 'una galaxia espiral brillando en el espacio';

  @override
  String get economyAiPromptSceneSpace3 => 'un astronauta flotando sobre un planeta azul';

  @override
  String get economyAiPromptSceneSpace4 => 'una nebulosa con forma de flor abierta';

  @override
  String get economyAiPromptSceneSpace5 => 'dos soles poniéndose sobre un desierto alienígena';

  @override
  String get economyAiPromptSceneSpace6 => 'una estación espacial orbitando un gigante gaseoso';

  @override
  String get economyAiPromptSceneSpace7 => 'una lluvia de meteoros sobre un observatorio';

  @override
  String get economyAiPromptSceneSpace8 => 'un eclipse con un brillante anillo de diamante';

  @override
  String get economyAiPromptSceneSynthwave1 => 'una carretera de rejilla neón hacia el ocaso';

  @override
  String get economyAiPromptSceneSynthwave2 => 'una costa de palmeras bajo un sol a rayas';

  @override
  String get economyAiPromptSceneSynthwave3 => 'un deportivo retro en una autopista sin fin';

  @override
  String get economyAiPromptSceneSynthwave4 => 'montañas de alambre bajo un cielo magenta';

  @override
  String get economyAiPromptSceneSynthwave5 => 'un sol cromado hundiéndose en un mar brillante';

  @override
  String get economyAiPromptSceneSynthwave6 => 'un salón recreativo retro brillando en la lluvia';

  @override
  String get economyAiPromptSceneSynthwave7 => 'un casete flotando en un espacio de neón';

  @override
  String get economyAiPromptSceneSynthwave8 => 'una palmera solitaria ante un horizonte láser';

  @override
  String get economyAiPromptScenePixelArt1 => 'una cabaña acogedora en un bosque nevado de noche';

  @override
  String get economyAiPromptScenePixelArt2 => 'un castillo en un acantilado sobre el mar';

  @override
  String get economyAiPromptScenePixelArt3 => 'un pueblito con ventanas encendidas';

  @override
  String get economyAiPromptScenePixelArt4 => 'una nave sobre un mundo alienígena morado';

  @override
  String get economyAiPromptScenePixelArt5 => 'una cascada en un valle de selva frondosa';

  @override
  String get economyAiPromptScenePixelArt6 => 'un muelle de pesca bajo la luna llena';

  @override
  String get economyAiPromptScenePixelArt7 => 'un templo con cerezos en flor en primavera';

  @override
  String get economyAiPromptScenePixelArt8 => 'un tren cruzando un puente al atardecer';

  @override
  String get economyAiPromptSceneRender3d1 => 'formas de arcilla brillante apiladas en equilibrio';

  @override
  String get economyAiPromptSceneRender3d2 => 'cintas de vidrio esmerilado sobre escenario pastel';

  @override
  String get economyAiPromptSceneRender3d3 => 'una isla diminuta flotando sobre una nube suave';

  @override
  String get economyAiPromptSceneRender3d4 => 'burbujas de cromo hinchadas bajo luz suave';

  @override
  String get economyAiPromptSceneRender3d5 => 'un desierto en miniatura con un cactus solitario';

  @override
  String get economyAiPromptSceneRender3d6 => 'un diorama de sala acogedora dentro de un cubo';

  @override
  String get economyAiPromptSceneRender3d7 => 'arcos de mármol flotando sobre agua en calma';

  @override
  String get economyAiPromptSceneRender3d8 => 'olas color caramelo congeladas en movimiento';

  @override
  String get economyAiPromptSceneOilPainting1 => 'un mar tormentoso rompiendo contra la costa rocosa';

  @override
  String get economyAiPromptSceneOilPainting2 => 'un prado de amapolas al sol con una granja';

  @override
  String get economyAiPromptSceneOilPainting3 => 'un bodegón de limones y un jarrón azul';

  @override
  String get economyAiPromptSceneOilPainting4 => 'un puerto brumoso al alba con barcos viejos';

  @override
  String get economyAiPromptSceneOilPainting5 => 'un sendero del bosque ardiendo en colores otoñales';

  @override
  String get economyAiPromptSceneOilPainting6 => 'un canal bajo la luna con casas antiguas';

  @override
  String get economyAiPromptSceneOilPainting7 => 'un campo de trigo ondulando antes de la tormenta';

  @override
  String get economyAiPromptSceneOilPainting8 => 'una rosa en un vaso sobre una mesa oscura';

  @override
  String get economyAiPromptSceneUkiyoE1 => 'una gran ola rizándose bajo una luna pálida';

  @override
  String get economyAiPromptSceneUkiyoE2 => 'una pagoda cubierta de nieve al anochecer';

  @override
  String get economyAiPromptSceneUkiyoE3 => 'grullas volando sobre una montaña neblinosa';

  @override
  String get economyAiPromptSceneUkiyoE4 => 'un puente de madera bajo pétalos de cerezo';

  @override
  String get economyAiPromptSceneUkiyoE5 => 'barcas de pesca en un mar añil agitado';

  @override
  String get economyAiPromptSceneUkiyoE6 => 'un sol rojo sobre un pico volcánico';

  @override
  String get economyAiPromptSceneUkiyoE7 => 'un estanque de carpas bajo sauces llorones';

  @override
  String get economyAiPromptSceneUkiyoE8 => 'lluvia cayendo sobre un pueblo junto al río';

  @override
  String get economyAiPromptLightingMorningHaze => 'bruma matinal suave';

  @override
  String get economyAiPromptLightingGoldenHour => 'luz dorada del ocaso';

  @override
  String get economyAiPromptLightingMoonlight => 'fría luz de luna';

  @override
  String get economyAiPromptLightingNeonRim => 'contraluz de neón';

  @override
  String get economyAiPromptLightingBacklight => 'contraluz cálido';

  @override
  String get economyAiPromptLightingGodRays => 'suaves rayos de luz';

  @override
  String get economyAiPromptLightingStudio => 'luz de estudio';

  @override
  String get economyAiPromptLightingTwilight => 'crepúsculo azul';

  @override
  String get economyAiPromptPaletteTealAmber => 'tonos turquesa y ámbar';

  @override
  String get economyAiPromptPaletteIndigoRose => 'tonos índigo y rosa';

  @override
  String get economyAiPromptPaletteSageCream => 'verde salvia y crema';

  @override
  String get economyAiPromptPaletteBlackNeonPink => 'negro con rosa neón';

  @override
  String get economyAiPromptPalettePastelPeach => 'durazno pastel suave';

  @override
  String get economyAiPromptPaletteEmeraldGold => 'esmeralda y dorado';

  @override
  String get economyAiPromptPaletteOceanBlue => 'matices de azul marino';

  @override
  String get economyAiPromptPaletteCrimsonCharcoal => 'carmesí y carbón';

  @override
  String get economyAiPromptSuffix => 'fondo vertical de móvil, sin texto';

  @override
  String economyAiPromptComposition(String scene, String lighting, String palette, String suffix) {
    return '$scene, $lighting, $palette. $suffix';
  }

  @override
  String economyAiPromptSceneOnly(String scene, String suffix) {
    return '$scene, $suffix';
  }

  @override
  String get economyAiMadeWithPrism => 'Creado con Prism AI';

  @override
  String get onboardingAiPromptFallback => 'un fondo de pantalla precioso';

  @override
  String get onboardingAiPromptNature1 => 'un lago glaciar al amanecer, agua como espejo y cumbres rosadas';

  @override
  String get onboardingAiPromptNature2 => 'un arroyo de bosque musgoso con luz suave entre helechos altos';

  @override
  String get onboardingAiPromptNature3 => 'un campo de flores silvestres bajo un vasto cielo vespertino';

  @override
  String get onboardingAiPromptNature4 => 'una playa de arena negra con olas turquesa y farallones al ocaso';

  @override
  String get onboardingAiPromptNature5 => 'auroras boreales sobre un pinar nevado junto a un lago helado';

  @override
  String get onboardingAiPromptAbstract1 => 'cintas de vidrio translúcido girando en luz suave con bordes iridiscentes';

  @override
  String get onboardingAiPromptAbstract2 => 'nubes de tinta floreciendo en agua, azul profundo y oro, detalle suave';

  @override
  String get onboardingAiPromptAbstract3 => 'olas de capas de papel en tonos cálidos de atardecer y sombras suaves';

  @override
  String get onboardingAiPromptAbstract4 => 'un remolino de mármol esculpido con vetas doradas sobre fondo carbón';

  @override
  String get onboardingAiPromptAbstract5 => 'esferas cromadas flotando y reflejando un cielo pastel en calma';

  @override
  String get onboardingAiPromptWatercolor1 => 'un pueblo costero en acuarela con casas pastel y barcas al amanecer';

  @override
  String get onboardingAiPromptWatercolor2 =>
      'flores silvestres sueltas en acuarela, rosa y salvia, sobre papel rugoso';

  @override
  String get onboardingAiPromptWatercolor3 => 'un lago brumoso en acuarela con un muelle de madera y colinas lejanas';

  @override
  String get onboardingAiPromptWatercolor4 => 'un cielo nocturno en acuarela con nubes violeta y una luna brillante';

  @override
  String get onboardingAiPromptWatercolor5 => 'un bosque otoñal en acuarela con cálidas veladuras naranjas y doradas';

  @override
  String get onboardingAiPromptMinimal1 => 'un sol poniéndose sobre un mar en calma, colores planos y cielo amplio';

  @override
  String get onboardingAiPromptMinimal2 => 'colinas suaves en capas, tonos arena apagados y cielo degradado pálido';

  @override
  String get onboardingAiPromptMinimal3 => 'un árbol sin hojas en una colina nevada con mucho espacio vacío';

  @override
  String get onboardingAiPromptMinimal4 =>
      'un velero solitario en un lago quieto al alba, formas simples y tonos suaves';

  @override
  String get onboardingAiPromptMinimal5 => 'arcos concéntricos suaves en terracota y crema con grano fino';

  @override
  String get onboardingAiPromptAnime1 => 'un cielo de verano estilo anime con nubes enormes sobre una vía costera';

  @override
  String get onboardingAiPromptAnime2 => 'una ciudad nocturna de anime desde una colina, luces cálidas y estrellas';

  @override
  String get onboardingAiPromptAnime3 => 'un santuario de bosque de anime con espíritus brillantes en luz verde suave';

  @override
  String get onboardingAiPromptAnime4 => 'una calle de anime lluviosa al anochecer, luces de tiendas y charcos';

  @override
  String get onboardingAiPromptAnime5 => 'una pradera de anime a la hora dorada con el viento en la hierba alta';

  @override
  String get onboardingAiPromptMeshGradient1 =>
      'un degradado de malla suave de mandarina, rosa y violeta con grano fino';

  @override
  String get onboardingAiPromptMeshGradient2 =>
      'un degradado de malla profundo azul marino y turquesa con un toque lima';

  @override
  String get onboardingAiPromptMeshGradient3 => 'un degradado de malla suave de azul cielo, lavanda y crema cálida';

  @override
  String get onboardingAiPromptMeshGradient4 => 'un degradado de malla intenso carmesí y oro, fluyendo como seda';

  @override
  String get onboardingAiPromptMeshGradient5 => 'un degradado de malla sereno de salvia, menta y arena clara';

  @override
  String get onboardingAiPromptCyberpunk1 => 'una calle ciberpunk nocturna bajo la lluvia, reflejos de neón y vapor';

  @override
  String get onboardingAiPromptCyberpunk2 => 'una ciudad de neón desde una azotea, con coches voladores cruzando';

  @override
  String get onboardingAiPromptCyberpunk3 =>
      'un canal ciberpunk tranquilo con tiendas luminosas y farolillos flotantes';

  @override
  String get onboardingAiPromptCyberpunk4 =>
      'un horizonte ciberpunk al alba, torres de cristal y bruma rosa y turquesa';

  @override
  String get onboardingAiPromptCyberpunk5 =>
      'una moto solitaria en un puente de neón sobre una ciudad futurista brumosa';

  @override
  String get onboardingAiPromptSpace1 => 'un gigante gaseoso con anillos sobre una luna rocosa y cielo de estrellas';

  @override
  String get onboardingAiPromptSpace2 => 'una nebulosa colorida violeta y turquesa con estrellas jóvenes brillantes';

  @override
  String get onboardingAiPromptSpace3 => 'una galaxia espiral de frente, con núcleo brillante y brazos azules de polvo';

  @override
  String get onboardingAiPromptSpace4 => 'un astronauta a la deriva sobre la Tierra al amanecer, fina atmósfera azul';

  @override
  String get onboardingAiPromptSpace5 => 'un eclipse solar total sobre una cordillera silenciosa';

  @override
  String get onboardingAiPromptSynthwave1 => 'un atardecer synthwave con sol a rayas sobre una rejilla de neón';

  @override
  String get onboardingAiPromptSynthwave2 => 'un coche retro hacia un sol magenta por una carretera costera vacía';

  @override
  String get onboardingAiPromptSynthwave3 => 'montañas de alambre bajo un cielo violeta estrellado y un sol cromado';

  @override
  String get onboardingAiPromptSynthwave4 => 'una playa synthwave con siluetas de palmeras y horizonte rosa brillante';

  @override
  String get onboardingAiPromptSynthwave5 => 'un horizonte urbano retro de noche entre neón rosa y cian';

  @override
  String get onboardingAiPromptPixelArt1 => 'una cabaña en pixel art en un bosque nevado, ventanas cálidas de noche';

  @override
  String get onboardingAiPromptPixelArt2 => 'un pueblo costero en pixel art al atardecer con barcos en el puerto';

  @override
  String get onboardingAiPromptPixelArt3 => 'un castillo en pixel art sobre una isla flotante entre nubes';

  @override
  String get onboardingAiPromptPixelArt4 => 'un cielo nocturno en pixel art sobre un lago tranquilo con luciérnagas';

  @override
  String get onboardingAiPromptPixelArt5 => 'un sendero de cerezos en flor en pixel art hacia un templo pequeño';

  @override
  String get onboardingAiPromptRender3d1 => 'un render 3D de formas de arcilla suaves en pasteles con sombras tenues';

  @override
  String get onboardingAiPromptRender3d2 => 'un render 3D de una isla flotante con cascada y árboles';

  @override
  String get onboardingAiPromptRender3d3 => 'un render 3D de olas de vidrio azul y violeta bajo luz de estudio';

  @override
  String get onboardingAiPromptRender3d4 => 'un render 3D de una habitación en miniatura dentro de un cubo brillante';

  @override
  String get onboardingAiPromptRender3d5 => 'un render 3D de burbujas cromadas flotando sobre un mar rosa en calma';

  @override
  String get onboardingAiPromptOilPainting1 => 'un óleo de un mar tormentoso con un barquito bajo un cielo dramático';

  @override
  String get onboardingAiPromptOilPainting2 => 'un óleo de un campo de amapolas al sol con una granja a lo lejos';

  @override
  String get onboardingAiPromptOilPainting3 => 'un óleo de un puerto brumoso al alba con viejas barcas de madera';

  @override
  String get onboardingAiPromptOilPainting4 => 'un óleo de un sendero otoñal con pinceladas gruesas y ricas';

  @override
  String get onboardingAiPromptOilPainting5 => 'un óleo de un pueblo con canal a la luz de la luna y ventanas cálidas';

  @override
  String get onboardingAiPromptUkiyoE1 => 'una gran ola ukiyo-e bajo una luna pálida y un monte nevado lejano';

  @override
  String get onboardingAiPromptUkiyoE2 => 'un pueblo nevado ukiyo-e de noche con farolillos de papel encendidos';

  @override
  String get onboardingAiPromptUkiyoE3 => 'una escena ukiyo-e de grullas volando sobre montañas neblinosas al alba';

  @override
  String get onboardingAiPromptUkiyoE4 => 'un puente de madera ukiyo-e bajo cerezos en flor en primavera';

  @override
  String get onboardingAiPromptUkiyoE5 => 'un sol rojo ukiyo-e sobre un mar índigo en calma con barcas pequeñas';

  @override
  String wallpaperWotdByline(String name) {
    return 'de $name';
  }

  @override
  String get wallpaperWotdPastPicks => 'Selecciones anteriores';

  @override
  String wallpaperWotdPickedOn(String wallpaper, String date) {
    return '$wallpaper, seleccionado el $date';
  }

  @override
  String get wallpaperWotdSeePast => 'Ver fondos del día anteriores';

  @override
  String get wallpaperWotdTitle => 'Fondo del día';

  @override
  String get wallpaperYourProfile => 'Tu perfil';

  @override
  String get widgetsSettingsTitle => 'Widgets';

  @override
  String get widgetsSettingsSubtitle => 'Añade Prism a tu pantalla de inicio y a la pantalla bloqueada';

  @override
  String get widgetsGuideTitle => 'Añadir widgets de Prism';

  @override
  String get widgetsGuideHomeTab => 'Pantalla de inicio';

  @override
  String get widgetsGuideLockTab => 'Pantalla bloqueada';

  @override
  String get widgetsGuideHomeStep1 =>
      'Mantén pulsada una zona vacía de la pantalla de inicio hasta que las apps se muevan.';

  @override
  String get widgetsGuideHomeStep2 => 'Toca Editar y después Añadir widget.';

  @override
  String get widgetsGuideHomeStep3 => 'Busca Prism, elige un tamaño y toca Añadir widget.';

  @override
  String get widgetsGuideLockStep1 => 'Mantén pulsada la pantalla bloqueada y toca Personalizar.';

  @override
  String get widgetsGuideLockStep2 => 'Toca Pantalla bloqueada y después la zona de widgets bajo el reloj.';

  @override
  String get widgetsGuideLockStep3 => 'Elige Prism y toca un widget para añadirlo.';

  @override
  String get widgetsGuideHomeIllustration => 'Un teléfono con el widget Fondo del día en la pantalla de inicio';

  @override
  String get widgetsGuideLockIllustration => 'Un teléfono con widgets de Prism en la pantalla bloqueada';

  @override
  String get widgetsGuideDone => 'Listo';

  @override
  String get widgetsCardTitle => 'El fondo del día en tu pantalla de inicio';

  @override
  String get widgetsCardBody => 'Añade el widget y ve un fondo nuevo cada día.';

  @override
  String get widgetsCardAction => 'Muéstrame cómo';

  @override
  String get widgetsCardDismiss => 'Descartar';
}
