// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get economyAd => 'Anúncio';

  @override
  String economyWatchAdForCoins(int reward) {
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    return 'Assistir a anúncio por $rewardString moedas';
  }

  @override
  String economyCoinsMissing(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Faltam $countString moedas.';
  }

  @override
  String economyCoinsRemainAfterAd(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Você ainda pode precisar de $countString moedas após o anúncio';
  }

  @override
  String get economyAdAutomaticPurchase =>
      'Se o seu saldo após a recompensa cobrir o preço, este item será comprado automaticamente.';

  @override
  String get economyAdVerificationPending =>
      'Sua recompensa está aguardando verificação. As moedas aparecerão após a confirmação.';

  @override
  String get foldersLibraryEmptyTitle => 'Nenhuma pasta ainda';

  @override
  String get foldersLibraryEmptyBody => 'Segure o coração em um papel de parede para salvá-lo em uma pasta.';

  @override
  String get foldersLoadAllError => 'Não foi possível carregar suas pastas';

  @override
  String get galleryEmptyBody => 'Foram removidos ou não são mais públicos.';

  @override
  String get galleryEmptyTitle => 'Esses papéis de parede sumiram';

  @override
  String get galleryScreenTitle => 'Papéis de parede para você';

  @override
  String get favouritePin => 'Fixar no topo';

  @override
  String get favouriteUnpin => 'Desafixar';

  @override
  String get favouritePinnedToast => 'Fixado no topo dos Favoritos';

  @override
  String get favouriteUnpinnedToast => 'Desafixado';

  @override
  String get favouritePinnedBadge => 'Fixado';

  @override
  String favouritePinLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Você pode fixar até $count favoritos. Desafixe um para fixar este papel de parede.',
    );
    return '$_temp0';
  }

  @override
  String get favouritePinFailed => 'Não foi possível atualizar o fixado. Verifique sua conexão e tente novamente.';

  @override
  String wallpaperFavouriteSearchCountHint(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pesquisar em $countString favoritos',
      one: 'Pesquisar em 1 favorito',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteSortAndFilter => 'Organizar e filtrar';

  @override
  String get wallpaperFavouriteSortBy => 'Organizar por';

  @override
  String get wallpaperFavouriteFilterSource => 'Fonte';

  @override
  String get wallpaperHistorySetAgain => 'Definir novamente';

  @override
  String wallpaperHistoryTileLabel(String current, String target, String time) {
    return '$current$target, definido às $time';
  }

  @override
  String get wallpaperProviderWallhaven => 'Wallhaven';

  @override
  String get duoTitle => 'Surpresa Duo';

  @override
  String get duoAiFormatLabel => 'Criar uma surpresa Duo';

  @override
  String get duoPresetNotice =>
      'O Prism mostra o lado direito na prévia com o celular dobrado. Alinhe manualmente o original salvo e confira as duas vistas na prévia de papel de parede do sistema. Esta é uma predefinição do Prism, não um recorte automático do iOS.';

  @override
  String get duoFoldedPromptLabel => 'Vista com o celular dobrado';

  @override
  String get duoFoldedPromptExample => 'Um gato sonolento ao lado de uma janela';

  @override
  String get duoRevealedPromptLabel => 'A surpresa ao abrir';

  @override
  String get duoRevealedPromptExample => 'Uma pequena nave espacial do lado de fora da janela';

  @override
  String get duoPromptValidation => 'Descreva as duas vistas com 1 a 160 caracteres em cada uma.';

  @override
  String get duoMoodBody => 'Um papel de parede. Mais surpresas ao abrir.';

  @override
  String get duoDeviceName => 'iPhone Duo';

  @override
  String get duoPhoneDevice => 'Celular';

  @override
  String get duoFold => 'Dobrar';

  @override
  String get duoUnfold => 'Abrir';

  @override
  String get duoFolded => 'Dobrado';

  @override
  String get duoUnfolded => 'Aberto';

  @override
  String get duoAndroidCropNotice =>
      'O Prism mostra o lado direito na prévia com o celular dobrado. O Android pode recortar a imagem de outra forma. Confira a prévia de papel de parede do sistema antes de aplicar.';

  @override
  String get duoGetOnPrism => 'Encontre no Prism';

  @override
  String get duoGuideTitle => 'Configure sua surpresa Duo';

  @override
  String get duoGuideOpen =>
      'Abra o original salvo no Fotos, toque em Compartilhar e depois em Usar como Papel de Parede.';

  @override
  String get duoGuideAlign =>
      'Alinhe manualmente a imagem inteira para que a vista com o celular dobrado mostre o lado direito.';

  @override
  String get duoGuideCheck =>
      'Confira as vistas com o celular dobrado e aberto na prévia do sistema e adicione o papel de parede.';

  @override
  String get duoWebTitle => 'Papéis de parede para iPhone Duo | Prism';

  @override
  String get duoWebDescription =>
      'Um papel de parede com uma segunda cena escondida. Explore papéis de parede originais com surpresa Duo no Prism.';

  @override
  String get duoWebHeading => 'Um papel de parede. Uma história que se amplia.';

  @override
  String get duoWebIntro =>
      'Uma cena tranquila ao dobrar. Outra história ao abrir. Veja as duas vistas de cada papel de parede original.';

  @override
  String get duoWebEmpty => 'A primeira coleção Duo está em análise.';

  @override
  String get duoWebEmptyBody => 'Explore o Prism enquanto conferimos cada papel de parede nas duas vistas.';

  @override
  String get duoWebFolded => 'Prévia com o celular dobrado';

  @override
  String get duoWebUnfolded => 'Original com o celular aberto';

  @override
  String get duoWebPresetNotice =>
      'Estas prévias usam a predefinição do Prism para o lado direito, não um recorte automático da Apple. Salve o original completo, alinhe manualmente e confira as vistas com o celular dobrado e aberto na prévia de papel de parede do sistema.';

  @override
  String get duoWebOpenPrism => 'Abrir no Prism';

  @override
  String get duoWebExplore => 'Explorar o Prism';

  @override
  String get duoWebAppStore => 'Baixar na App Store';

  @override
  String get duoWebPlayStore => 'Disponível no Google Play';

  @override
  String get economyExportFailedLabel => 'Falha ao exportar';

  @override
  String get coreSignInCreatorSearchFeature => 'busca de criadores';

  @override
  String get debugLogExportSubject => 'Logs de depuração do Prism';

  @override
  String get accountAbout => 'Sobre';

  @override
  String get accountAboutPrism => 'Sobre o Prism';

  @override
  String get accountAccount => 'Conta';

  @override
  String get accountAccountDeletionSubscriptionWarning =>
      'A assinatura da loja não é cancelada quando você exclui sua conta. A cobrança continua até você cancelá-la na loja.';

  @override
  String get accountAdPrivacyChoices => 'Opções de privacidade dos anúncios';

  @override
  String get accountAddProfilePhoto => 'Adicionar foto do perfil';

  @override
  String get accountAddSocialLink => 'Adicionar link de rede social';

  @override
  String get accountAdmin => 'Administrador';

  @override
  String get accountAdminModeration => 'Moderação administrativa';

  @override
  String accountAndroidSharePitch(String url) {
    return 'Apaixone-se de novo pela personalização do Android! Conheça o Prism -\n$url';
  }

  @override
  String get accountAnyResolution => 'Qualquer';

  @override
  String get accountAppName => 'Prism Wallpapers';

  @override
  String get accountAppearance => 'Aparência';

  @override
  String get accountApply => 'Aplicar';

  @override
  String get accountAskEveryTime => 'Perguntar sempre';

  @override
  String get accountAudience => 'Público';

  @override
  String get accountAutoRotateWallpapers => 'Trocar papéis de parede automaticamente';

  @override
  String get accountBlock => 'Bloquear';

  @override
  String get accountBlockActionFailed => 'Não foi possível atualizar as contas bloqueadas';

  @override
  String get accountBlockActionPendingSync =>
      'Sua alteração foi salva neste dispositivo e será sincronizada assim que possível.';

  @override
  String get accountBlockConfirmationUserFallback => 'esta pessoa';

  @override
  String accountBlockThisUserTitle(String name) {
    return 'Bloquear $name?';
  }

  @override
  String get accountBlockUser => 'Bloquear usuário';

  @override
  String accountBlockUserMessage(String name) {
    return 'Você deixará de seguir $name, não verá mais os papéis de parede dessa pessoa no feed e não receberá notificações sobre as novas publicações dela.';
  }

  @override
  String get accountBlockedAccounts => 'Contas bloqueadas';

  @override
  String get accountBlockedAccountsEmptyBody =>
      'Bloquear alguém oculta as publicações dessa pessoa no seu feed. Ela ainda poderá ver seu perfil e seus papéis de parede públicos.';

  @override
  String get accountBlockedAccountsLoadError => 'Não foi possível carregar as contas bloqueadas';

  @override
  String get accountBlockedListUserFallback => 'Usuário bloqueado';

  @override
  String get accountBlockedProfileBody =>
      'Os papéis de parede dessa pessoa ficam ocultos no seu feed e nas notificações. Você pode desbloqueá-la quando quiser.';

  @override
  String get accountBringBackSubscription => 'Reativar uma assinatura anterior';

  @override
  String get accountBrowseByCategory => 'Explorar por categoria';

  @override
  String get accountBrowseByColour => 'Explorar por cor';

  @override
  String get accountBuyPremium => 'Comprar o Premium';

  @override
  String get accountCacheCleared => 'Cache limpo.';

  @override
  String accountCacheClearedBytes(String size) {
    return '$size removidos.';
  }

  @override
  String accountCachedImageSize(String size) {
    return '$size de imagens em cache';
  }

  @override
  String get accountCancel => 'Cancelar';

  @override
  String get accountCannotGiftThisAccount => 'Não é possível enviar um presente para esta conta.';

  @override
  String accountCategorySemanticLabel(String name) {
    return 'Categoria, $name';
  }

  @override
  String get accountChangeAutomatically => 'Alterar automaticamente';

  @override
  String get accountChangeCoverPhoto => 'Alterar foto da capa';

  @override
  String get accountChangeOrCancelStore => 'Alterar ou cancelar na loja';

  @override
  String get accountChangePhoto => 'Alterar foto';

  @override
  String get accountChangeWallpaperOnTimer => 'Trocar o papel de parede com um temporizador';

  @override
  String get accountCheckConnectionTryAgain => 'Verifique sua conexão e tente novamente.';

  @override
  String get accountClear => 'Limpar';

  @override
  String get accountClearAllDownloads => 'Excluir todos os downloads';

  @override
  String get accountClearAllFavouritesQuestion => 'Excluir todos os favoritos?';

  @override
  String get accountClearCache => 'Limpar cache';

  @override
  String get accountClearCacheConfirmMessage =>
      'As imagens em cache serão removidas. Elas serão carregadas novamente quando você precisar.';

  @override
  String accountClearCacheConfirmSizeMessage(String size) {
    return '$size de imagens em cache serão removidos. Elas serão carregadas novamente quando você precisar.';
  }

  @override
  String get accountClearCacheQuestion => 'Limpar o cache?';

  @override
  String get accountClearCacheTitle => 'Limpar cache';

  @override
  String get accountClearCachedImages => 'Limpar imagens salvas em cache neste dispositivo';

  @override
  String get accountClearColour => 'Limpar cor';

  @override
  String get accountClearDepthEffect => 'Remover efeito de profundidade';

  @override
  String get accountClearSpatialScene => 'Remover espacial';

  @override
  String get accountClearFavouriteWallpapers => 'Excluir papéis de parede favoritos';

  @override
  String get accountClearFavourites => 'Excluir favoritos';

  @override
  String accountClearFavouritesCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede favoritos serão removidos',
      one: '1 papel de parede favorito será removido',
      zero: '$countString papéis de parede favoritos serão removidos',
    );
    return '$_temp0 da sua conta. Não é possível desfazer essa ação.';
  }

  @override
  String get accountClearFavouritesMessage =>
      'Todos os seus papéis de parede favoritos serão removidos da sua conta. Não é possível desfazer essa ação.';

  @override
  String get accountClearLearnedTaste => 'Apagar preferências aprendidas';

  @override
  String accountClearLearnedTasteCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'os $countString itens',
      one: 'o único item',
      zero: 'os $countString itens',
    );
    return 'O Prism vai esquecer $_temp0 que aprendeu com o que você visualizou e salvou. Seu feed voltará a usar os interesses que você escolheu. Não é possível desfazer essa ação.';
  }

  @override
  String get accountClearLearnedTasteQuestion => 'Apagar preferências aprendidas?';

  @override
  String get accountClearSearch => 'Limpar pesquisa';

  @override
  String get accountColour => 'Cor';

  @override
  String accountCommitCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString commits',
      one: '1 commit',
      zero: 'Nenhum commit',
    );
    return '$_temp0';
  }

  @override
  String get accountCompleteProfile => 'Completar perfil';

  @override
  String get accountCompleteYourProfile => 'Complete seu perfil';

  @override
  String get accountConnectionTryAgain => 'Verifique sua conexão e tente novamente.';

  @override
  String get accountContent => 'Conteúdo';

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
      zero: 'nenhum commit',
    );
    return '$login, $_temp0';
  }

  @override
  String get accountCopy => 'Copiar';

  @override
  String get accountCopyLink => 'Copiar link';

  @override
  String get accountCouldNotBuildReport => 'Não foi possível gerar o relatório. Tente novamente.';

  @override
  String get accountCouldNotClearFavourites =>
      'Não foi possível excluir os papéis de parede favoritos. Tente novamente.';

  @override
  String get accountCouldNotClearLearnedTaste => 'Não foi possível apagar as preferências aprendidas. Tente novamente.';

  @override
  String get accountCouldNotCreateLink => 'Não foi possível criar o link. Tente novamente.';

  @override
  String get accountCouldNotDeleteDownloads => 'Não foi possível excluir os downloads. Tente novamente.';

  @override
  String accountCouldNotFollowPerson(String name) {
    return 'Não foi possível seguir $name. Tente novamente.';
  }

  @override
  String get accountCouldNotLoadFollowers => 'Não foi possível carregar os seguidores';

  @override
  String get accountCouldNotLoadFollowing => 'Não foi possível carregar quem você segue';

  @override
  String get accountCouldNotLoadTeam => 'Não foi possível carregar a equipe';

  @override
  String get accountCouldNotLoadThisProfile => 'Não foi possível carregar este perfil';

  @override
  String get accountCouldNotLoadTrending => 'Não foi possível carregar os destaques';

  @override
  String get accountCouldNotLoadWallpapers => 'Não foi possível carregar os papéis de parede';

  @override
  String accountCouldNotOpenAddress(String address) {
    return 'Não foi possível abrir $address';
  }

  @override
  String get accountCouldNotOpenLink => 'Não foi possível abrir o link. Tente novamente.';

  @override
  String get accountCouldNotOpenStore => 'Não foi possível abrir a loja. Tente novamente.';

  @override
  String get accountCouldNotOpenThisLink => 'Não foi possível abrir este link.';

  @override
  String get accountCouldNotRefreshSearch => 'Não foi possível atualizar. Puxe a tela para baixo e tente novamente.';

  @override
  String get accountCouldNotRemoveSavedOffline =>
      'Não foi possível remover os papéis de parede salvos para uso off-line. Tente novamente.';

  @override
  String get accountCouldNotRestorePurchases => 'Não foi possível restaurar as compras. Tente novamente.';

  @override
  String get accountCouldNotSearchCreators => 'Não foi possível pesquisar criadores';

  @override
  String get accountCouldNotSearchRightNow => 'Não foi possível pesquisar agora';

  @override
  String get accountCouldNotSendGift => 'Não foi possível enviar o presente. Tente novamente.';

  @override
  String get accountCouldNotShareReport => 'Não foi possível compartilhar o relatório. Tente novamente.';

  @override
  String accountCouldNotUnfollowPerson(String name) {
    return 'Não foi possível deixar de seguir $name. Tente novamente.';
  }

  @override
  String get accountCreatorFallback => 'Criador do Prism';

  @override
  String get accountCreatorSearchEmptyBody => 'Confira a ortografia ou tente outro nome.';

  @override
  String get accountCurrentSignedInAccountRequired => 'Selecione a conta em que você está conectado no momento.';

  @override
  String get accountDataSaver => 'Economia de dados';

  @override
  String get accountDataSaverDescription =>
      'Economiza dados móveis. Os papéis de parede abrem como miniaturas, os feeds não carregam conteúdo antecipadamente e os carrosséis não iniciam sozinhos.';

  @override
  String get accountDatabaseUsageStats => 'Uso e estatísticas do banco de dados';

  @override
  String get accountDebugPanel => 'Painel de depuração';

  @override
  String get accountDefaultActionForSet => 'Ação padrão para Definir';

  @override
  String get accountDeleteAccount => 'Excluir conta';

  @override
  String get accountDeleteAccountConfirmation =>
      'Sua conta será excluída permanentemente, seus dados pessoais serão removidos e sua sessão será encerrada.\n\nOs papéis de parede que você enviou continuarão visíveis como \"Conta excluída\".\n\nNão é possível desfazer essa ação.';

  @override
  String get accountDeleteAccountReauthNote =>
      'Na próxima etapa, você confirmará sua identidade com o Google ou a Apple.';

  @override
  String get accountDeleteAll => 'Excluir tudo';

  @override
  String get accountDeleteAllDownloadsQuestion => 'Excluir todos os downloads?';

  @override
  String accountDeleteDownloadsCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede baixados serão excluídos',
      one: '1 papel de parede baixado será excluído',
      zero: '$countString papéis de parede baixados serão excluídos',
    );
    return '$_temp0 da seção Downloads. As cópias salvas para uso off-line não serão afetadas. Não é possível desfazer essa ação.';
  }

  @override
  String get accountDeleteDownloadsMessage =>
      'Os papéis de parede baixados serão excluídos da seção Downloads. As cópias salvas para uso off-line não serão afetadas. Não é possível desfazer essa ação.';

  @override
  String get accountDeleteYourAccountQuestion => 'Excluir sua conta?';

  @override
  String get accountDeletingYourAccount => 'Excluindo sua conta';

  @override
  String get accountDepthEffect => 'Efeito de profundidade';

  @override
  String get accountDepthEffectClockSemanticLabel => 'Efeito de profundidade, elemento principal à frente do relógio';

  @override
  String get accountSpatialScene => 'Espacial';

  @override
  String get accountSpatialSceneSubtitle => 'Walls com profundidade 3D nítida';

  @override
  String get accountSpatialSceneSemanticLabel => 'Espacial, walls com profundidade 3D nítida';

  @override
  String accountDownloadedWallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede baixados; as cópias salvas para uso off-line serão mantidas',
      one: '1 papel de parede baixado; as cópias salvas para uso off-line serão mantidas',
      zero: 'Nenhum papel de parede baixado; as cópias salvas para uso off-line serão mantidas',
    );
    return '$_temp0';
  }

  @override
  String get accountDownloadsDeleted => 'Todos os downloads foram excluídos.';

  @override
  String get accountEarnCoins => 'Ganhe moedas';

  @override
  String accountEarnProfileCompletionCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Ganhe $coinsString moedas ao completar seu perfil';
  }

  @override
  String get accountEditCover => 'Editar capa';

  @override
  String get accountEditProfile => 'Editar perfil';

  @override
  String get accountExportFavourites => 'Exportar favoritos';

  @override
  String get accountFavouritesCleared => 'Todos os papéis de parede favoritos foram excluídos.';

  @override
  String get accountFeedback => 'OPINIÃO';

  @override
  String get accountFeedbackSubject => 'Opinião sobre o Prism';

  @override
  String get accountFields => 'Campos';

  @override
  String get accountFilters => 'Filtros';

  @override
  String get accountFindCreators => 'Encontrar criadores';

  @override
  String get accountFinishYourProfile => 'Conclua seu perfil';

  @override
  String get accountFirestoreTelemetry => 'Telemetria do Firestore';

  @override
  String get accountFollow => 'Seguir';

  @override
  String accountFollowPerson(String name) {
    return 'Seguir $name';
  }

  @override
  String accountFollowedPerson(String name) {
    return 'Você está seguindo $name!';
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
      zero: 'Nenhum seguidor',
    );
    return '$_temp0';
  }

  @override
  String accountFollowersCountLabel(String compactCount) {
    return '$compactCount seguidores';
  }

  @override
  String get accountFollowersEmptyMessage => 'As pessoas que seguem esta conta aparecerão aqui.';

  @override
  String get accountFollowing => 'Seguindo';

  @override
  String accountFollowingCountLabel(String compactCount) {
    return '$compactCount seguindo';
  }

  @override
  String get accountFollowingEmptyMessage => 'As contas que você segue aparecerão aqui.';

  @override
  String get accountForgetFeedLearned => 'Apagar o que o feed aprendeu sobre você';

  @override
  String get accountFromPrism => 'Do Prism';

  @override
  String get accountGiftLimitReached => 'Você atingiu o limite de presentes por enquanto. Tente novamente amanhã.';

  @override
  String accountGiftPassMessage(String recipientName, int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$recipientName terá acesso às coleções e aos papéis de parede Premium pelas próximas 24 horas. Custa $priceString moedas.';
  }

  @override
  String get accountGiftPassTitle => 'Presentear com um passe Pro de 24 horas';

  @override
  String get accountGiftPassTooltip => 'Presentear com um passe de 24 h';

  @override
  String get accountGiftsOpenAfterSevenDays => 'Você poderá enviar presentes quando sua conta tiver 7 dias.';

  @override
  String get accountHapticFeedback => 'Resposta tátil';

  @override
  String get accountHelp => 'Ajuda';

  @override
  String get accountHomeAndLockScreens => 'Tela inicial e tela de bloqueio';

  @override
  String get accountHomeScreen => 'Tela inicial';

  @override
  String get accountInviteFriends => 'Convidar amigos';

  @override
  String get accountInviteLinkCouldNotCreate => 'Não foi possível criar seu link de convite.';

  @override
  String accountInviteRewardHeadline(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Dê $coinsString, ganhe $coinsString';
  }

  @override
  String accountInviteRewardMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Seu amigo ganha $coinsString moedas ao entrar. Você também ganha $coinsString.';
  }

  @override
  String get accountInviteShareFailed => 'Não foi possível compartilhar o convite agora.';

  @override
  String accountIosSharePitch(String url) {
    return 'Apaixone-se de novo pela personalização do seu celular! Conheça o Prism -\n$url';
  }

  @override
  String get accountLater => 'Mais tarde';

  @override
  String get accountLatest => 'Mais recentes';

  @override
  String get accountLearnedTasteCleared => 'Preferências aprendidas apagadas.';

  @override
  String get accountLibrary => 'Biblioteca';

  @override
  String get accountLightDarkAccentColour => 'Cores clara, escura e de destaque';

  @override
  String get accountLink => 'Link';

  @override
  String get accountLinkCopied => 'Link copiado';

  @override
  String get accountLinkType => 'Tipo de link';

  @override
  String get accountLinkTypeBehance => 'Behance';

  @override
  String get accountLinkTypeBioLink => 'bio.link';

  @override
  String get accountLinkTypeBuyMeACoffee => 'Buy Me a Coffee';

  @override
  String get accountLinkTypeCustom => 'Link personalizado';

  @override
  String get accountLinkTypeDeviantArt => 'DeviantArt';

  @override
  String get accountLinkTypeDribbble => 'Dribbble';

  @override
  String get accountLinkTypeEmail => 'E-mail';

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
    return 'Tipo de link, $name';
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
  String get accountLiveWallpapers => 'Papéis de parede animados';

  @override
  String get accountLoadingTeam => 'Carregando a equipe';

  @override
  String get accountLockScreen => 'Tela de bloqueio';

  @override
  String get accountLogOut => 'Sair';

  @override
  String get accountLogOutOfPrismQuestion => 'Sair do Prism?';

  @override
  String get accountLogOutQuestion => 'Sair?';

  @override
  String get accountLogoutConfirmation =>
      'Ao sair, o histórico e as preferências aprendidas serão apagados deste dispositivo. Seus favoritos, moedas e perfil continuarão na sua conta.';

  @override
  String get accountLogoutFailed => 'Não foi possível sair. Tente novamente.';

  @override
  String get accountLogsNetworkToolsStorage => 'Registros, rede, ferramentas e armazenamento';

  @override
  String get accountMadeWithLoveInIndia => 'Feito com ❤ na Índia usando Flutter!';

  @override
  String get accountManageBlockedPeople => 'Gerenciar pessoas bloqueadas';

  @override
  String get accountManageSubscription => 'Gerenciar assinatura';

  @override
  String get accountMenu => 'Menu';

  @override
  String get accountMinResolution => 'Resolução mínima';

  @override
  String get accountMoreLinks => 'Mais links';

  @override
  String get accountMoreOptions => 'Mais opções';

  @override
  String get accountMovingGradientsMotionVideo => 'Gradientes em movimento, animações e vídeos';

  @override
  String get accountMyAccent => 'Meu destaque';

  @override
  String get accountNoBlockedAccounts => 'Nenhuma conta bloqueada';

  @override
  String get accountNoContributors => 'Ainda não há colaboradores para mostrar.';

  @override
  String get accountNoCreatorsFound => 'Nenhum criador encontrado';

  @override
  String get accountNoDownloadsToRemove => 'Você não tem downloads para remover.';

  @override
  String get accountNoFollowersYet => 'Ainda não há seguidores';

  @override
  String get accountNoPurchasesToRestore => 'Não há compras para restaurar nesta conta.';

  @override
  String get accountNoResults => 'Nenhum resultado';

  @override
  String accountNoWallpapersForFilters(String filters) {
    return 'Nenhum papel de parede encontrado para $filters';
  }

  @override
  String accountNoWallpapersForQueryWithFilters(String query) {
    return 'Nenhum papel de parede encontrado para $query com os filtros selecionados.';
  }

  @override
  String get accountNoWallpapersFound => 'Nenhum papel de parede encontrado';

  @override
  String accountNoWallpapersFoundForQuery(String query) {
    return 'Nenhum papel de parede encontrado para $query';
  }

  @override
  String get accountNoWallpapersYet => 'Ainda não há papéis de parede';

  @override
  String accountNobodyMatchesUsername(String query) {
    return 'Ninguém corresponde a \"$query\". Tente outro nome de usuário.';
  }

  @override
  String get accountNotEnoughCoinsEarnInRewards => 'Moedas insuficientes. Ganhe moedas em Recompensas.';

  @override
  String get accountNotFollowingAnyoneYet => 'Você ainda não segue ninguém';

  @override
  String get accountNotSynced => 'Não sincronizado';

  @override
  String get accountNothingLearnedYet => 'O Prism ainda não aprendeu nada.';

  @override
  String get accountNotificationPreferences => 'Preferências de notificações';

  @override
  String get accountNotificationTypes => 'Papel de parede do dia, seguidores, publicações e mais';

  @override
  String get accountNotifications => 'Notificações';

  @override
  String get accountOpenYourProfile => 'Abrir seu perfil';

  @override
  String get accountOpeningProfileEditor => 'Abrindo o editor de perfil';

  @override
  String get accountOpens => 'Aberturas';

  @override
  String get accountOtherContributors => 'Outros colaboradores';

  @override
  String accountPassSentToPerson(String name) {
    return 'Passe enviado para $name.';
  }

  @override
  String accountPersonAlreadyHasPro(String name) {
    return '$name já tem o Pro.';
  }

  @override
  String get accountPersonalise => 'Personalizar';

  @override
  String get accountPortraitOnly => 'Somente retrato';

  @override
  String get accountPremiumBenefitsActive =>
      'Você tem acesso a todos os papéis de parede premium, downloads e filtros gratuitos.';

  @override
  String get accountPremiumBenefitsInactive => 'Desbloqueie papéis de parede premium, downloads e filtros gratuitos.';

  @override
  String get accountPreview => 'Prévia';

  @override
  String get accountPrismListPrivacySubtitle => 'Como o Prism usa seus dados';

  @override
  String get accountPrismPro => 'Prism Pro';

  @override
  String get accountPrivacyAction => 'PRIVACIDADE';

  @override
  String get accountPrivacyAndData => 'Privacidade e dados';

  @override
  String get accountPrivacyPolicy => 'Política de privacidade';

  @override
  String get accountProBadge => 'Pro';

  @override
  String get accountProWallpaperSemantics => 'Papel de parede Pro';

  @override
  String get accountProblemReportSharePrompt => 'Descreva o que deu errado. Os detalhes estão no arquivo do relatório.';

  @override
  String get accountProblemReportShareSubject => 'Relatório de problema do Prism';

  @override
  String get accountProfile => 'Perfil';

  @override
  String get accountProfileNotAvailable => 'Perfil indisponível';

  @override
  String get accountProfileNotAvailableBody =>
      'Este usuário não está usando a versão mais recente do Prism, então não é possível exibir o perfil.';

  @override
  String accountProfileNudgeMessage(int percent, int coins) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Seu perfil está $percentString% completo. Complete-o para ganhar $coinsString moedas Prism.';
  }

  @override
  String accountProfilePercentComplete(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Perfil $percentString% completo';
  }

  @override
  String accountProfilePersonSemantics(String name, String username) {
    return '$name, @$username';
  }

  @override
  String get accountProfiles => 'perfis';

  @override
  String get accountPurchases => 'Compras';

  @override
  String get accountPurchasesRestored => 'Compras restauradas.';

  @override
  String get accountPurchasesRestoredPending => 'Compras restauradas. O Pro pode levar um minuto para ser ativado.';

  @override
  String get accountQuickTiles => 'Blocos rápidos';

  @override
  String get accountRateApp => 'AVALIAR';

  @override
  String get accountRecentSearches => 'Buscas recentes';

  @override
  String get accountRelevance => 'Relevância';

  @override
  String get accountRemoveAllFavouriteWallpapers => 'Remover todos os papéis de parede favoritos';

  @override
  String get accountRemoveCoverPhoto => 'Remover foto de capa';

  @override
  String get accountRemoveFilesDownloadsOfflineStay =>
      'Remover arquivos de Downloads; as cópias salvas off-line serão mantidas';

  @override
  String get accountRemoveLink => 'Remover link';

  @override
  String get accountRemovePhoto => 'Remover foto';

  @override
  String get accountRemoveSavedOffline => 'Remover itens salvos off-line';

  @override
  String accountRemoveSavedOfflineCountMessage(String size) {
    return '$size dos originais mantidos off-line serão removidos. Downloads, rascunhos e dados do catálogo não serão alterados.';
  }

  @override
  String get accountRemoveSavedOfflineMessage =>
      'Remover deste dispositivo os originais mantidos off-line. Downloads, rascunhos e dados do catálogo não serão alterados.';

  @override
  String get accountRemoveSavedOfflineQuestion => 'Remover papéis de parede salvos off-line?';

  @override
  String get accountReportAProblem => 'Relatar um problema';

  @override
  String get accountReportProblemSubtitle => 'Envie um relatório de bug para a equipe do Prism';

  @override
  String get accountReportUser => 'Denunciar usuário';

  @override
  String get accountReset => 'Redefinir';

  @override
  String get accountResetFilters => 'Redefinir filtros';

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
  String get accountRetry => 'Tentar novamente';

  @override
  String get accountReviewOrChangeAdConsent => 'Revisar ou alterar seu consentimento para anúncios';

  @override
  String get accountReviewStatus => 'Status da análise';

  @override
  String get accountReviewSubmittedContent => 'Revisar conteúdo enviado';

  @override
  String get accountSaveFavouritesAsFile => 'Salvar uma cópia dos favoritos como arquivo';

  @override
  String get accountSavedOffline => 'Salvo off-line';

  @override
  String get accountSavedOfflineRemoved => 'Papéis de parede salvos off-line removidos.';

  @override
  String accountSavedOfflineStorageUnavailable(int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'Armazenamento indisponível · limite de $limitString MiB';
  }

  @override
  String accountSavedOfflineStorageUsed(String size, int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$size usados · limite de $limitString MiB';
  }

  @override
  String get accountSavedOnThisDevice => 'Salvo neste dispositivo';

  @override
  String get accountSearch => 'Buscar';

  @override
  String get accountSearchByUsername => 'Buscar por nome de usuário';

  @override
  String get accountSearchCreators => 'Buscar criadores';

  @override
  String get accountSearchCreatorsByName => 'Buscar criadores por nome';

  @override
  String get accountSearchFilters => 'Filtros';

  @override
  String get accountSearchPrismUsersByName => 'Buscar usuários do Prism por nome';

  @override
  String get accountSearchWallpapers => 'Buscar papéis de parede';

  @override
  String get accountSeeChangelog => 'Ver registro de alterações';

  @override
  String get accountSendGift => 'Enviar presente';

  @override
  String get accountSendProfileLink => 'Enviar um link para seu perfil do Prism';

  @override
  String get accountSetUpQuickTiles => 'Configurar os blocos das Configurações rápidas';

  @override
  String get accountSetUsername => 'Definir nome de usuário';

  @override
  String get accountSettings => 'Configurações';

  @override
  String get accountShareInvite => 'Compartilhar convite';

  @override
  String get accountSharePrism => 'Compartilhar o Prism';

  @override
  String get accountSharePrismFriendSubtitle => 'Enviar um link para um amigo';

  @override
  String get accountShareProfile => 'Compartilhar perfil';

  @override
  String get accountShareProfileLinkFailed => 'Não foi possível criar o link. Tente novamente.';

  @override
  String get accountShareYourProfile => 'Compartilhar seu perfil';

  @override
  String get accountShop => 'Loja';

  @override
  String get accountShowAnimeWallpapers => 'Mostrar papéis de parede de anime';

  @override
  String get accountShowSketchyWallpapers => 'Mostrar papéis de parede sugestivos';

  @override
  String get accountSignIn => 'Entrar';

  @override
  String get accountSignInAgainToDelete => 'Saia da conta e entre novamente. Depois, tente excluir sua conta.';

  @override
  String get accountSignInBenefits => 'Entre para manter seus favoritos, moedas e perfil';

  @override
  String get accountSignInForInviteLink => 'Entre para obter seu link de convite.';

  @override
  String get accountSignInToPrism => 'Entrar no Prism';

  @override
  String get accountSocialGithub => 'GITHUB';

  @override
  String get accountSocialInstagram => 'INSTAGRAM';

  @override
  String get accountSocialTelegram => 'TELEGRAM';

  @override
  String get accountSocialTwitter => 'TWITTER';

  @override
  String get accountSomethingWentWrongTryAgain => 'Algo deu errado. Tente novamente.';

  @override
  String get accountSort => 'Ordenar';

  @override
  String get accountStorage => 'Armazenamento';

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
  String get accountSubjectCanSitInFrontOfClock => 'O elemento pode ficar na frente do relógio';

  @override
  String get accountSubjectInFrontOfClock => 'Elemento na frente do relógio';

  @override
  String get accountTerms => 'Termos';

  @override
  String get accountTermsAction => 'TERMOS';

  @override
  String accountTermsAgreementSemanticLabel(String terms, String privacy) {
    return 'Ao continuar, você concorda com os $terms e a $privacy';
  }

  @override
  String get accountTermsOfUse => 'Termos de uso';

  @override
  String get accountTheTeam => 'A equipe';

  @override
  String get accountThemes => 'Temas';

  @override
  String get accountThemesIconsFrames => 'Temas, ícones e molduras';

  @override
  String get accountThisUser => 'este usuário';

  @override
  String get accountTop => 'Destaques';

  @override
  String get accountTrackSubmittedWallpapers => 'Acompanhar papéis de parede enviados';

  @override
  String get accountTrendingNow => 'Em alta agora';

  @override
  String get accountTryAgain => 'Tentar novamente';

  @override
  String get accountTryFewerFilters => 'Tente usar menos filtros.';

  @override
  String get accountTryShorterOrDifferentWord => 'Tente usar uma palavra mais curta ou diferente.';

  @override
  String get accountUnblock => 'Desbloquear';

  @override
  String get accountUnblockUserMessage => 'As publicações dessa pessoa voltarão a aparecer no seu feed.';

  @override
  String accountUnblockUserTitle(String name) {
    return 'Desbloquear $name?';
  }

  @override
  String get accountUnfollow => 'Deixar de seguir';

  @override
  String accountUnfollowPerson(String name) {
    return 'Deixar de seguir $name';
  }

  @override
  String accountUnfollowedPerson(String name) {
    return 'Você deixou de seguir $name!';
  }

  @override
  String get accountUnlimitedUploadsFilters => 'Uploads e filtros ilimitados';

  @override
  String get accountUploadFirstWallpaper => 'Envie seu primeiro papel de parede para começar sua galeria.';

  @override
  String get accountUseShortcutsAutomation => 'Usar uma automação do Atalhos';

  @override
  String accountUserBlocked(String name) {
    return 'Você bloqueou $name';
  }

  @override
  String get accountUserUnblocked => 'Usuário desbloqueado';

  @override
  String accountVersionLabel(String version) {
    return 'Versão $version';
  }

  @override
  String get accountVibrateOnTapsAndActions => 'Vibrar ao tocar e realizar ações';

  @override
  String get accountWaitingToSync => 'Aguardando sincronização';

  @override
  String get accountWallpaperHistory => 'Histórico de papéis de parede';

  @override
  String get accountWallpaperManagerTagline => 'Um gerenciador de papéis de parede completo.';

  @override
  String get accountWallpaperSourceNames => 'O Prism usa Wallhaven e Pexels para encontrar papéis de parede';

  @override
  String get accountWallpaperSources => 'Fontes de papéis de parede';

  @override
  String get accountWallpaperSourcesMessage => 'O Prism usa estes serviços para oferecer papéis de parede.';

  @override
  String get accountWallpapersSetBefore => 'Papéis de parede usados anteriormente';

  @override
  String get accountWhatsNew => 'Novidades';

  @override
  String get accountWhatsNewAction => 'NOVIDADES';

  @override
  String get accountWriteBio => 'Escrever biografia';

  @override
  String accountYouBlockedUser(String name) {
    return 'Você bloqueou $name';
  }

  @override
  String get accountYourContent => 'Seu conteúdo';

  @override
  String get accountYourProfile => 'seu perfil';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionClose => 'Fechar';

  @override
  String get actionDone => 'Concluído';

  @override
  String get actionRetry => 'Tentar novamente';

  @override
  String get adminAllCaughtUp => 'Tudo em dia';

  @override
  String get adminAllUsers => 'Todos os usuários';

  @override
  String get adminAnnouncementInbox => 'Anúncio (caixa de entrada)';

  @override
  String get adminAnonymous => 'Anônimo';

  @override
  String get adminApprovalFailed => 'Não foi possível aprovar. Verifique sua conexão e tente novamente.';

  @override
  String get adminApprove => 'Aprovar';

  @override
  String get adminApproved => 'Aprovado';

  @override
  String get adminBackToReviewList => 'Voltar à lista de análise';

  @override
  String get adminBatchActionFailed => 'Não foi possível concluir esta ação de análise. Tente novamente.';

  @override
  String get adminBatchComplete => 'Lote concluído';

  @override
  String get adminBodyLabel => 'Corpo';

  @override
  String get adminBodyRequired => 'O corpo é obrigatório';

  @override
  String get adminBy => 'Por';

  @override
  String get adminByCollection => 'Por coleção';

  @override
  String get adminByOperation => 'Por operação';

  @override
  String get adminBySourceTop15 => 'Por fonte (15 principais)';

  @override
  String get adminCancel => 'Cancelar';

  @override
  String get adminChangeDepthEffect => 'Alterar efeito de profundidade';

  @override
  String get adminCheckConnectionRetry => 'Verifique sua conexão e tente novamente.';

  @override
  String get adminClose => 'Fechar';

  @override
  String adminContentTypeReport(String type) {
    return 'Relatório de $type';
  }

  @override
  String get adminCopyAllData => 'Copiar todos os dados';

  @override
  String get adminCouldNotLoadWallpaper => 'Não foi possível carregar o papel de parede';

  @override
  String get adminCreatorWillSeeFeedback => 'O criador verá este comentário.';

  @override
  String get adminDepth => 'Profundidade';

  @override
  String adminDepthTier(String tier) {
    return 'Profundidade: $tier';
  }

  @override
  String get adminDepthTierAuto => 'Automático';

  @override
  String get adminDepthTierMenu => 'Menu';

  @override
  String get adminDepthTierNone => 'Nenhum';

  @override
  String get adminDepthTierNotChecked => 'Não verificado';

  @override
  String get adminDrop => 'Drop';

  @override
  String get adminEmail => 'E-mail';

  @override
  String get adminEmailExample => 'user@example.com';

  @override
  String get adminEmailRequired => 'O e-mail é obrigatório';

  @override
  String get adminEstimatedDocumentReads => 'Leituras estimadas de documentos';

  @override
  String get adminEstimatedDocumentWrites => 'Gravações estimadas de documentos';

  @override
  String adminFactLabel(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminFirestoreTelemetry => 'Telemetria do Firestore';

  @override
  String get adminFollowersScreen => 'Tela de seguidores';

  @override
  String get adminFreeUsers => 'Usuários gratuitos';

  @override
  String get adminGeneral => 'Geral';

  @override
  String get adminImageUrlOptional => 'URL da imagem (opcional)';

  @override
  String get adminKeepWallpaper => 'Manter papel de parede';

  @override
  String get adminLast14Days => 'Últimos 14 dias';

  @override
  String get adminList => 'Lista';

  @override
  String get adminLoadNextBatch => 'Carregar próximo lote';

  @override
  String get adminLoadingNotificationCounts => 'Carregando contagens de notificações.';

  @override
  String get adminMarkReviewed => 'Marcar como revisado';

  @override
  String get adminMarkReviewedFailed => 'Não foi possível marcar a denúncia como revisada. Tente novamente.';

  @override
  String get adminMarkedReviewed => 'Marcada como revisada';

  @override
  String adminModerationDuplicate(int percent) {
    return 'Parece ser um papel de parede do Prism · $percent%';
  }

  @override
  String get adminModerationHint => 'Estas são apenas indicações. Confira antes de rejeitar.';

  @override
  String adminModerationLogo(String logo) {
    return 'Logotipo: $logo';
  }

  @override
  String get adminModerationLogos => 'Logotipos';

  @override
  String get adminModerationOpenFailed => 'Não foi possível abrir a página.';

  @override
  String adminModerationOpenPage(String host) {
    return 'Abrir $host';
  }

  @override
  String get adminModerationSignals => 'Sinais para análise';

  @override
  String get adminModerationSimilarWall => 'Papel de parede semelhante do Prism';

  @override
  String adminModerationSimilarity(int percent) {
    return '$percent% semelhante';
  }

  @override
  String adminModerationText(String words) {
    return 'Texto: $words';
  }

  @override
  String get adminModerationTextInImage => 'Texto na imagem';

  @override
  String adminModerationUnsafe(String categories) {
    return 'Conteúdo impróprio: $categories';
  }

  @override
  String get adminModerationUnsafeCategories => 'Categorias de conteúdo impróprio';

  @override
  String adminModerationWeb(String host) {
    return 'Encontrado em $host';
  }

  @override
  String adminModerationWebMore(String host, int more) {
    return 'Encontrado em $host +$more';
  }

  @override
  String get adminModerationWebPages => 'Encontrado na web';

  @override
  String get adminNewWallpapersPending => 'Novos papéis de parede aparecerão aqui quando alguém enviar um.';

  @override
  String get adminNoNotificationCounts => 'Ainda não há contagens de notificações.';

  @override
  String get adminNoOpenReports => 'Não há denúncias abertas';

  @override
  String get adminNoReasonGiven => 'Nenhum motivo informado';

  @override
  String get adminNoTelemetryData => 'Não há dados de telemetria para copiar';

  @override
  String get adminNoTelemetryYet => 'Ainda não há telemetria';

  @override
  String get adminNoWallpapersPending => 'Não há papéis de parede aguardando revisão.';

  @override
  String get adminNothingToReview => 'Nada para revisar';

  @override
  String get adminNotificationCountExplanation =>
      'Aceita significa que o Firebase recebeu a notificação push. Uma notificação para o tópico da conta e outra para o token do dispositivo contam duas vezes. Isso não significa que ela foi visualizada.';

  @override
  String get adminNotificationCountsLoadError => 'Não foi possível carregar as contagens de notificações.';

  @override
  String get adminNotificationIrreversible =>
      'Esta notificação será enviada a todos neste grupo. Não é possível desfazer.';

  @override
  String get adminNotificationQueueFailed => 'Não foi possível colocar a notificação na fila. Tente novamente.';

  @override
  String get adminNotificationQueued => 'Notificação na fila. A Cloud Function vai enviá-la em instantes.';

  @override
  String get adminNotifications => 'Notificações';

  @override
  String get adminOpenReportsLoadError => 'Não foi possível carregar as denúncias abertas.';

  @override
  String get adminOpenWallpaper => 'Abrir papel de parede';

  @override
  String adminOperationCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString operações',
      one: '$countString operação',
      zero: '$countString operações',
    );
    return '$_temp0';
  }

  @override
  String get adminPendingWallsLoadError => 'Não foi possível carregar os papéis de parede pendentes.';

  @override
  String get adminPremiumUsers => 'Usuários Premium';

  @override
  String adminReadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString leituras',
      one: '$countString leitura',
      zero: '$countString leituras',
    );
    return '$_temp0';
  }

  @override
  String get adminReasonBlurry => 'Embaçado';

  @override
  String get adminReasonBlurryBody => 'A imagem está embaçada ou muito comprimida. Envie uma versão mais nítida.';

  @override
  String get adminReasonCopyright => 'Direitos autorais';

  @override
  String get adminReasonCopyrightBody =>
      'Esta imagem pode ser de outra pessoa. Envie apenas papéis de parede que você criou ou tem direito de usar.';

  @override
  String get adminReasonDuplicate => 'Duplicado';

  @override
  String get adminReasonDuplicateBody => 'Este papel de parede é igual a outro que já está no Prism.';

  @override
  String get adminReasonHint => 'Explique o que precisa mudar';

  @override
  String get adminReasonLabel => 'Motivo';

  @override
  String get adminReasonLowResolution => 'Baixa resolução';

  @override
  String get adminReasonLowResolutionBody =>
      'A resolução está muito baixa. Envie uma imagem com pelo menos 1080 px no lado menor.';

  @override
  String get adminReasonNotWallpaper => 'Não é um papel de parede';

  @override
  String get adminReasonNotWallpaperBody =>
      'Esta imagem não funciona como papel de parede para celular. Use uma imagem vertical que preencha a tela.';

  @override
  String get adminReasonOther => 'Outro';

  @override
  String get adminReasonWatermark => 'Marca-d\'água';

  @override
  String get adminReasonWatermarkBody => 'A imagem tem uma marca-d\'água. Envie uma versão sem ela.';

  @override
  String get adminRefresh => 'Atualizar';

  @override
  String get adminReject => 'Rejeitar';

  @override
  String get adminRejectReasonRequired => 'Informe um motivo antes de rejeitar este item.';

  @override
  String get adminRejectSaveFailed =>
      'Não foi possível salvar esta decisão. Seu motivo continua aqui. Tente novamente.';

  @override
  String get adminRejectWallpaper => 'Rejeitar papel de parede';

  @override
  String get adminRemove => 'Remover';

  @override
  String get adminRemoveWallpaper => 'Remover papel de parede';

  @override
  String get adminRemovedFromNextDrop => 'Removido do próximo Drop';

  @override
  String get adminReportDismissFailed => 'Não foi possível dispensar a denúncia. Tente novamente.';

  @override
  String get adminReportDismissedKept => 'Denúncia dispensada. Papel de parede mantido.';

  @override
  String get adminReported => 'Denunciado';

  @override
  String get adminReporter => 'Denunciante';

  @override
  String get adminReports => 'Denúncias';

  @override
  String get adminReserve => 'Reservar';

  @override
  String get adminReserveForDrop => 'Reservar para o Drop';

  @override
  String get adminReserveUpdateFailed => 'Não foi possível atualizar a reserva do Drop. Tente novamente.';

  @override
  String get adminReservedForNextDrop => 'Reservado para o próximo Drop';

  @override
  String get adminRetry => 'Tentar novamente';

  @override
  String adminReviewProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString/$totalString';
  }

  @override
  String get adminSendNotification => 'Enviar notificação';

  @override
  String adminSendToAudience(String audience) {
    return 'Enviar para $audience?';
  }

  @override
  String get adminSkip => 'Pular';

  @override
  String get adminSpecificUser => 'Usuário específico (e-mail)';

  @override
  String get adminSwipeInstructions => 'Deslize para a direita para aprovar ou para a esquerda para rejeitar';

  @override
  String get adminSwipeReview => 'Revisão por gesto';

  @override
  String get adminTarget => 'Destino';

  @override
  String get adminTelemetryCopied => 'Copiado para a área de transferência. Cole em outro lugar para analisar.';

  @override
  String get adminTelemetryReadError => 'Não foi possível ler a telemetria';

  @override
  String get adminTitle => 'Moderação administrativa';

  @override
  String get adminTitleLabel => 'Título';

  @override
  String get adminTitleRequired => 'O título é obrigatório';

  @override
  String get adminTotalEvents => 'Total de eventos';

  @override
  String get adminTryAgain => 'Tentar novamente';

  @override
  String get adminUndo => 'Desfazer';

  @override
  String get adminUndoSuccessful => 'Ação desfeita';

  @override
  String get adminUnknown => 'Desconhecido';

  @override
  String get adminUnreserve => 'Cancelar reserva';

  @override
  String get adminUntitled => 'Sem título';

  @override
  String get adminUploaded => 'Enviado';

  @override
  String get adminUseAppForEvents => 'Use o app para gerar eventos do Firestore.';

  @override
  String get adminUserEmail => 'E-mail do usuário';

  @override
  String get adminUserReportsShowHere => 'As denúncias dos usuários aparecerão aqui.';

  @override
  String get adminValidEmailRequired => 'Informe um e-mail válido';

  @override
  String get adminView => 'Ver';

  @override
  String get adminViewFullWallpaper => 'Ver papel de parede completo';

  @override
  String get adminWallId => 'ID';

  @override
  String get adminWallOfTheDay => 'Papel de parede do dia';

  @override
  String get adminWallOrUpload => 'Papel de parede ou envio';

  @override
  String get adminWallpaperAlreadyGone => 'O papel de parede já não estava disponível. Denúncia encerrada.';

  @override
  String get adminWallpaperApproved => 'Papel de parede aprovado';

  @override
  String get adminWallpaperFullScreen => 'Papel de parede em tela cheia';

  @override
  String get adminWallpaperRejected => 'Papel de parede rejeitado';

  @override
  String get adminWallpaperRemoved => 'Papel de parede removido';

  @override
  String get adminWallpaperReport => 'Denúncia de papel de parede';

  @override
  String get adminWallpaperToReview => 'Papel de parede para revisar';

  @override
  String adminWallpapersRemaining(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede restantes',
      one: '$countString papel de parede restante',
      zero: '$countString papéis de parede restantes',
    );
    return '$_temp0';
  }

  @override
  String get adminWalls => 'Papéis de parede';

  @override
  String adminWriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gravações',
      one: '$countString gravação',
      zero: '$countString gravações',
    );
    return '$_temp0';
  }

  @override
  String get appLinkRetryWhenOnline => 'Sem conexão. Vamos abrir este link quando você voltar a ficar online.';

  @override
  String get appTitle => 'Prism';

  @override
  String get coreBack => 'Voltar';

  @override
  String get coreBio => 'Bio';

  @override
  String get coreBlockCreatorAfterReport => 'Bloquear também este criador';

  @override
  String get coreBothScreens => 'ambas as telas';

  @override
  String get coreCancel => 'Cancelar';

  @override
  String get coreCancelSelection => 'Cancelar seleção';

  @override
  String get coreCancelSignIn => 'Agora não';

  @override
  String get coreCategoryAbstract => 'Abstrato';

  @override
  String get coreCategoryAerial => 'Aéreo';

  @override
  String get coreCategoryAesthetic => 'Estético';

  @override
  String get coreCategoryAiArt => 'Arte com IA';

  @override
  String get coreCategoryAnimals => 'Animais';

  @override
  String get coreCategoryAnime => 'Anime';

  @override
  String get coreCategoryArchitecture => 'Arquitetura';

  @override
  String get coreCategoryArtistic => 'Artístico';

  @override
  String get coreCategoryBirds => 'Aves';

  @override
  String get coreCategoryCars => 'Carros';

  @override
  String get coreCategoryCity => 'Cidade';

  @override
  String get coreCategoryClouds => 'Nuvens';

  @override
  String get coreCategoryComic => 'Quadrinhos';

  @override
  String get coreCategoryCyberpunk => 'Cyberpunk';

  @override
  String get coreCategoryDark => 'Sombrio';

  @override
  String get coreCategoryDefault => 'Categoria';

  @override
  String get coreCategoryFantasy => 'Fantasia';

  @override
  String get coreCategoryFashion => 'Moda';

  @override
  String get coreCategoryFlowers => 'Flores';

  @override
  String get coreCategoryFood => 'Comida';

  @override
  String get coreCategoryForest => 'Floresta';

  @override
  String get coreCategoryGalaxy => 'Galáxia';

  @override
  String get coreCategoryGaming => 'Jogos';

  @override
  String get coreCategoryGradient => 'Degradê';

  @override
  String get coreCategoryIllustration => 'Ilustração';

  @override
  String get coreCategoryKawaii => 'Kawaii';

  @override
  String get coreCategoryLandscape => 'Paisagem';

  @override
  String get coreCategoryMinimal => 'Minimalista';

  @override
  String get coreCategoryMusic => 'Música';

  @override
  String get coreCategoryNature => 'Natureza';

  @override
  String get coreCategoryNeon => 'Neon';

  @override
  String get coreCategoryOcean => 'Oceano';

  @override
  String get coreCategoryPortraits => 'Retratos';

  @override
  String get coreCategoryQuotes => 'Frases';

  @override
  String get coreCategoryRender3d => 'Renderização 3D';

  @override
  String get coreCategoryRobots => 'Robôs';

  @override
  String get coreCategoryScenery => 'Cenários';

  @override
  String get coreCategorySpace => 'Espaço';

  @override
  String get coreCategorySpiritual => 'Espiritualidade';

  @override
  String get coreCategorySports => 'Esportes';

  @override
  String get coreCategoryTech => 'Tecnologia';

  @override
  String get coreCategoryTextures => 'Texturas';

  @override
  String get coreCategoryUnderTheSea => 'Fundo do mar';

  @override
  String get coreCategoryVehicles => 'Veículos';

  @override
  String get coreCategoryVintage => 'Retrô';

  @override
  String get coreCategoryWarriors => 'Guerreiros';

  @override
  String get coreChangeWallpaperTarget => 'Alterar onde o papel de parede será definido';

  @override
  String get coreChangelogLatest => 'Mais recentes';

  @override
  String get coreChooseReportReason => 'Escolha um motivo';

  @override
  String get coreChooseUsername => 'Escolha um nome de usuário disponível.';

  @override
  String get coreCoinAiWallpaper => 'Papel de parede com IA';

  @override
  String get coreCoinAutoRotatePass => 'Passe de rotação automática, 7 dias';

  @override
  String get coreCoinBadgeReward => 'Recompensa de selo';

  @override
  String coreCoinBalance(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString moedas Prism';
  }

  @override
  String coreCoinBalanceChange(String balance, String change) {
    return '$balance, $change';
  }

  @override
  String get coreCoinBoost => 'Impulso';

  @override
  String get coreCoinCoins => 'Moedas';

  @override
  String get coreCoinCoinsReturned => 'Moedas devolvidas';

  @override
  String get coreCoinCollectionPreview => 'Prévia da coleção, 24 h';

  @override
  String get coreCoinDailyChest => 'Baú diário';

  @override
  String get coreCoinDailyStreak => 'Sequência diária';

  @override
  String coreCoinDailyStreakDay(String day) {
    return 'Sequência diária, dia $day';
  }

  @override
  String get coreCoinDay7Chest => 'Baú do 7º dia';

  @override
  String get coreCoinDrawTicket => 'Bilhete de sorteio';

  @override
  String get coreCoinDropPack => 'Pacote Drop';

  @override
  String get coreCoinDropWall => 'Papel de parede do Drop';

  @override
  String get coreCoinFirstUpload => 'Primeiro envio';

  @override
  String get coreCoinGiftPass => 'Presente: passe de 24 h';

  @override
  String get coreCoinInviteReward => 'Recompensa por convite';

  @override
  String get coreCoinLiveWallpaperStyle => 'Estilo de papel de parede animado';

  @override
  String get coreCoinPremiumFilter => 'Filtro Premium';

  @override
  String get coreCoinPremiumWallpaper => 'Papel de parede Premium';

  @override
  String get coreCoinProDailyBonus => 'Bônus diário Pro';

  @override
  String get coreCoinProSpin => 'Giro Pro';

  @override
  String get coreCoinProStreakBonus => 'Bônus de sequência Pro';

  @override
  String get coreCoinProfileComplete => 'Perfil completo';

  @override
  String get coreCoinQuest => 'Missão';

  @override
  String coreCoinRefund(String target) {
    return 'Reembolso: $target';
  }

  @override
  String get coreCoinShop => 'Loja';

  @override
  String get coreCoinSpinWheel => 'Girar a roleta';

  @override
  String get coreCoinStreakFreeze => 'Congelamento de sequência';

  @override
  String get coreCoinStreakRestore => 'Restaurar sequência';

  @override
  String get coreCoinWallpaperDownload => 'Download de papel de parede';

  @override
  String get coreCoinWatchedVideo => 'Vídeo assistido';

  @override
  String get coreCoinWeekBonus => 'Bônus semanal';

  @override
  String get coreColorBlack => 'Preto';

  @override
  String get coreColorBlue => 'Azul';

  @override
  String get coreColorBrown => 'Marrom';

  @override
  String get coreColorGreen => 'Verde';

  @override
  String get coreColorGrey => 'Cinza';

  @override
  String get coreColorOrange => 'Laranja';

  @override
  String get coreColorPink => 'Rosa';

  @override
  String get coreColorPurple => 'Roxo';

  @override
  String get coreColorRed => 'Vermelho';

  @override
  String get coreColorTeal => 'Verde-azulado';

  @override
  String get coreColorWhite => 'Branco';

  @override
  String get coreColorYellow => 'Amarelo';

  @override
  String get coreConfirmWallpaperPreview => 'Confirme o papel de parede na prévia do sistema.';

  @override
  String get coreContentNotAvailable => 'Este item não está mais disponível';

  @override
  String get coreContentReportUser => 'usuário';

  @override
  String get coreContentReportWallpaper => 'papel de parede';

  @override
  String coreContentReportWhy(String contentType) {
    return 'Por que você está denunciando este $contentType?';
  }

  @override
  String coreContentReportWhyWithDetails(String contentType, String details) {
    return 'Por que você está denunciando este $contentType ($details)?';
  }

  @override
  String get coreContinueWithApple => 'Continuar com a Apple';

  @override
  String get coreContinueWithGoogle => 'Continuar com o Google';

  @override
  String get coreContributorCouldNotLoad => 'Não foi possível carregar este perfil';

  @override
  String get coreContributorGithub => 'GitHub';

  @override
  String get coreContributorTwitter => 'Twitter';

  @override
  String get coreContributorWebsite => 'Site';

  @override
  String get coreCouldNotLoadChangelog => 'Não foi possível carregar o registro de alterações';

  @override
  String get coreCouldNotLoadWallpaperForEditing => 'Não foi possível carregar o papel de parede para edição';

  @override
  String get coreCouldNotUpdateFavourites => 'Não foi possível atualizar os favoritos. Tente novamente.';

  @override
  String get coreCreatorPreviewDescription => 'Confira o perfil deste criador no Prism.';

  @override
  String get coreDefaultBanner => 'Entre no nosso Telegram';

  @override
  String get coreDepthEffectAutoLongTip =>
      'O Efeito de Profundidade é ativado automaticamente. No iOS 18 ou anterior, deixe desativados os widgets no espaço abaixo do relógio.';

  @override
  String get coreDepthEffectAutoTip => 'O Efeito de Profundidade é ativado automaticamente.';

  @override
  String get coreDepthEffectBadge => 'Profundidade';

  @override
  String get coreDepthEffectBadgeSemantic => 'Compatível com o Efeito de Profundidade';

  @override
  String get coreDepthEffectMenuShortTip => 'Toque em ••• e depois em Efeito de Profundidade.';

  @override
  String get coreDepthEffectMenuTip =>
      'No editor da tela de bloqueio, toque em ••• e depois em Efeito de Profundidade.';

  @override
  String get coreSpatialBadge => 'Espacial';

  @override
  String get coreSpatialBadgeSemantic => 'Funciona como Cena espacial';

  @override
  String get coreSpatialSceneTip => 'No editor da tela de bloqueio, toque no botão Cena espacial.';

  @override
  String get coreDeviceCannotSetScreen => 'Este dispositivo não pode definir essa tela.';

  @override
  String get coreDone => 'Concluído';

  @override
  String coreDown(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'menos $coinsString';
  }

  @override
  String get coreDownloadNotFinishedCoinsReturned => 'O último download não foi concluído. As moedas foram devolvidas.';

  @override
  String get coreDownloadPrismPreviewDescription => 'Baixe o Prism para descobrir papéis de parede incríveis.';

  @override
  String get coreEdit => 'Editar';

  @override
  String get coreEditBioHint => 'Conte um pouco sobre você…';

  @override
  String get coreEditDiscardBody => 'Suas edições não foram salvas.';

  @override
  String get coreEditDiscardTitle => 'Descartar alterações?';

  @override
  String get coreEditEmailInvalid => 'Informe um endereço de e-mail válido.';

  @override
  String coreEditKindLinkInvalid(String kind) {
    return 'Informe um link de $kind válido.';
  }

  @override
  String get coreEditLinkInvalid => 'Informe um link válido.';

  @override
  String get coreEditProfile => 'Editar perfil';

  @override
  String coreEditProfileLink(String kind) {
    return 'Link de $kind';
  }

  @override
  String get coreEditRemoveBioTitle => 'Remover bio?';

  @override
  String get coreEditRemoveConfirm => 'Remover';

  @override
  String coreEditRemoveTitle(String item) {
    return 'Remover $item?';
  }

  @override
  String get coreEditUsernameAvailable => 'Nome de usuário disponível';

  @override
  String get coreEditUsernameChars => 'Use apenas letras, números e sublinhados.';

  @override
  String get coreEditUsernameAllCaps => 'Use pelo menos uma letra minúscula.';

  @override
  String coreEditUsernameMinLength(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Use pelo menos $lengthString caracteres.';
  }

  @override
  String coreEditUsernameRule(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Use pelo menos $lengthString letras, números ou sublinhados (_).';
  }

  @override
  String get coreEditUsernameTaken => 'Esse nome de usuário já está em uso.';

  @override
  String get coreEditUsernameTakenSemantic => 'Nome de usuário indisponível';

  @override
  String get coreFavourite => 'Favoritar';

  @override
  String coreFileSizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String get coreGenericSignInError => 'Algo deu errado. Tente novamente!';

  @override
  String get coreGoHome => 'Ir para o início';

  @override
  String get coreGooglePlayServicesSignInError =>
      'Não é possível fazer login pelos serviços do Google Play neste dispositivo.';

  @override
  String get coreGoogleSignInNetworkError =>
      'Não foi possível fazer login com o Google. Verifique sua conexão e tente novamente.';

  @override
  String get coreHomeScreen => 'tela inicial';

  @override
  String get coreHomeScreenSetupUnavailable => 'As configurações da tela inicial não estão mais disponíveis.';

  @override
  String get coreInvalidLinkBody => 'O link que você abriu é inválido ou não está mais disponível.';

  @override
  String coreInvitedToPrismTitle(String name) {
    return '$name convidou você para o Prism';
  }

  @override
  String get coreIosWallpaperGuideBody =>
      'O iOS não permite que apps alterem seu papel de parede. Conclua pelo app Fotos:';

  @override
  String get coreJoinPrismPreviewTitle => 'Entre no Prism';

  @override
  String get coreKeepPrismOpen => 'Mantenha o Prism aberto e tente novamente.';

  @override
  String get coreLoading => 'Carregando';

  @override
  String get coreLoadingMoreFailed => 'Não foi possível carregar mais. Toque para tentar novamente';

  @override
  String get coreLoadingWallpaper => 'Carregando papel de parede';

  @override
  String get coreLockScreen => 'tela de bloqueio';

  @override
  String get coreMatchAccent => 'Combinar com a cor de destaque';

  @override
  String get coreName => 'Nome';

  @override
  String get coreNoWallpaperUrl => 'Não há URL disponível para este papel de parede';

  @override
  String get coreNotNow => 'Agora não';

  @override
  String get coreOpenPhotos => 'Abrir Fotos';

  @override
  String get coreOpenSettings => 'Abrir ajustes';

  @override
  String get corePairPickerDownloads => 'Downloads';

  @override
  String get corePairPickerFavourites => 'Favoritos';

  @override
  String get corePairPickerHistory => 'Histórico';

  @override
  String get corePairPickerNoDownloads => 'Você ainda não fez downloads.';

  @override
  String get corePairPickerNoFavourites => 'Você ainda não tem favoritos.';

  @override
  String get corePairPickerNoHistory => 'Você ainda não tem histórico.';

  @override
  String get corePairPickerTitle => 'Escolha um papel de parede para a tela de bloqueio';

  @override
  String get corePairPickerUseWallpaper => 'Usar este papel de parede na tela de bloqueio';

  @override
  String get corePhotosPermissionMessage =>
      'Permita que o Prism adicione fotos nos Ajustes para salvar papéis de parede.';

  @override
  String get corePhotosStepOpen => 'Abra o app Fotos.';

  @override
  String get corePhotosStepShare => 'Toque em Compartilhar.';

  @override
  String get corePhotosStepUseAsWallpaper => 'Toque em Usar como Papel de Parede.';

  @override
  String corePopupAppVersion(String version) {
    return 'Você está usando a versão $version.';
  }

  @override
  String get corePopupCannotUndo => 'Não é possível desfazer esta ação.';

  @override
  String get corePopupCoverPhoto => 'foto de capa';

  @override
  String get corePopupDiscard => 'Descartar';

  @override
  String get corePopupProfilePhoto => 'foto do perfil';

  @override
  String get corePopupWhatsNew => 'Novidades';

  @override
  String get corePreviousWallpaperRestored => 'Papel de parede anterior restaurado';

  @override
  String get coreProfileSaveFailed => 'Não foi possível salvar seu perfil. Tente novamente.';

  @override
  String get coreProfileUpdated => 'Perfil atualizado';

  @override
  String coreReferralSaved(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Indicação salva. Entre na sua conta para resgatar +$coinsString moedas.';
  }

  @override
  String coreRelativeTimeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $countString dias',
      one: 'há 1 dia',
      zero: 'há $countString dias',
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
      other: '$countString dias',
      one: '1 dia',
      zero: '$countString dias',
    );
    return 'daqui a $_temp0';
  }

  @override
  String coreRelativeTimeHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $countString horas',
      one: 'há 1 hora',
      zero: 'há $countString horas',
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
      other: '$countString horas',
      one: '1 hora',
      zero: '$countString horas',
    );
    return 'daqui a $_temp0';
  }

  @override
  String get coreRelativeTimeJustNow => 'Agora mesmo';

  @override
  String coreRelativeTimeMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $countString minutos',
      one: 'há 1 minuto',
      zero: 'há $countString minutos',
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
      other: '$countString minutos',
      one: '1 minuto',
      zero: '$countString minutos',
    );
    return 'daqui a $_temp0';
  }

  @override
  String get coreRemoveBio => 'Remover bio';

  @override
  String get coreReport => 'Denunciar';

  @override
  String get coreReportCouldNotSubmit => 'Não foi possível enviar sua denúncia. Tente novamente.';

  @override
  String get coreReportDetailsHint => 'Quer contar mais alguma coisa?';

  @override
  String get coreReportDetailsOptional => 'Detalhes (opcional)';

  @override
  String get coreReportReasonCopyright => 'Direitos autorais / propriedade';

  @override
  String get coreReportReasonHarassment => 'Assédio ou discurso de ódio';

  @override
  String get coreReportReasonOther => 'Outro';

  @override
  String get coreReportReasonSexual => 'Conteúdo sexual ou adulto';

  @override
  String get coreReportReasonSpam => 'Spam ou conteúdo enganoso';

  @override
  String get coreReportSent => 'Denúncia enviada. Agradecemos.';

  @override
  String get coreRestorePreviousWallpaperFailed =>
      'Não foi possível restaurar o papel de parede anterior. Defina-o novamente pelo histórico de papéis de parede.';

  @override
  String get coreRetry => 'Tentar novamente';

  @override
  String get coreRetryImage => 'Tentar imagem novamente';

  @override
  String coreRetryOnScreen(String screen) {
    return 'Tentar novamente em $screen';
  }

  @override
  String get coreSaveChanges => 'Salvar alterações';

  @override
  String get coreSeeFullChangelog => 'Ver registro completo de alterações';

  @override
  String get coreSeeMore => 'Ver mais';

  @override
  String coreSelectCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString selecionados';
  }

  @override
  String get coreSendReport => 'Enviar denúncia';

  @override
  String get coreSet => 'Definir';

  @override
  String get coreSetItAsWallpaper => 'Definir como papel de parede';

  @override
  String get coreSetWallpaper => 'Definir papel de parede';

  @override
  String coreSetWallpaperOn(String screen) {
    return 'Definir papel de parede em $screen';
  }

  @override
  String get coreShare => 'Compartilhar';

  @override
  String coreShareCardClipboard(String link) {
    return '🔥 Confira ➜ $link';
  }

  @override
  String get coreShareFormatStory => 'Story';

  @override
  String get coreShareFormatPost => 'Publicação';

  @override
  String get coreShareFormatClean => 'Minimalista';

  @override
  String get coreShareTargetInstagram => 'Instagram';

  @override
  String get coreShareTargetCopyLink => 'Copiar link';

  @override
  String get coreShareTargetSaveImage => 'Salvar imagem';

  @override
  String get coreShareTargetMore => 'Mais';

  @override
  String coreShareCardBy(String creator) {
    return 'por $creator';
  }

  @override
  String get coreShareImageSaved => 'Imagem salva';

  @override
  String get coreShareImageFailed => 'Não foi possível salvar a imagem. Tente novamente.';

  @override
  String get coreShareInstagramFailed => 'Não foi possível abrir o Instagram. Tente novamente.';

  @override
  String get coreSharePreviewFailed => 'Não foi possível criar esta imagem. Use Mais para compartilhar o link.';

  @override
  String get coreShareLinkCopied => 'Link de compartilhamento copiado!';

  @override
  String coreShareProfileClipboard(String link) {
    return 'Oi! Confira meu perfil no Prism ➜ $link';
  }

  @override
  String coreShareWallpaperClipboard(String link) {
    return 'Oi! Confira este papel de parede ➜ $link';
  }

  @override
  String get coreShareWallpaperGeneric => 'Este papel de parede incluído está disponível no app Prism.';

  @override
  String get coreSignInFeatureBody => 'Sua conta reúne suas moedas, seus favoritos e seus envios.';

  @override
  String coreSignInFeatureTitle(String feature) {
    return 'Entre na sua conta para usar $feature';
  }

  @override
  String get coreSignInPopupBody => 'Tenha seus favoritos, envios e moedas em todos os dispositivos.';

  @override
  String get coreSignInPopupTitle => 'Entre no Prism';

  @override
  String get coreSignInPromptAction => 'Entrar';

  @override
  String get coreSignInToReportContent => 'Entre na sua conta para denunciar conteúdo';

  @override
  String get coreSignInToSyncFavourites => 'Entre na sua conta para acessar seus favoritos em todos os dispositivos';

  @override
  String get coreSigningIn => 'Entrando';

  @override
  String get coreSomethingWentWrong => 'Algo deu errado. Tente novamente.';

  @override
  String coreStreakNext(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Próxima: +$coinsString';
  }

  @override
  String coreStreakSemantics(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Sequência de $daysString dias, próxima recompensa: $coinsString moedas';
  }

  @override
  String get coreCustomAccent => 'Cor personalizada';

  @override
  String get coreCustomAccentHex => 'Código hexadecimal';

  @override
  String get coreCustomAccentHue => 'Matiz';

  @override
  String get coreCustomAccentSaturation => 'Saturação';

  @override
  String get coreCustomAccentLightness => 'Luminosidade';

  @override
  String get coreCustomAccentInvalidHex => 'Digite 6 dígitos hexadecimais, como #E57697.';

  @override
  String get coreCustomAccentLowContrast =>
      'Esta cor é difícil de ver neste tema. Escolha um tom mais claro ou mais escuro.';

  @override
  String get coreCustomAccentApply => 'Usar cor';

  @override
  String coreThemeAccentSemanticLabel(int index, int count) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Cor de destaque $indexString de $countString';
  }

  @override
  String get coreThemeAmoled => 'AMOLED';

  @override
  String get coreThemeCoffee => 'Café';

  @override
  String get coreThemeCottonBlue => 'Azul algodão';

  @override
  String get coreThemeCustom => 'Tema personalizado';

  @override
  String get coreThemeDeepOcean => 'Oceano profundo';

  @override
  String get coreThemeFrostWhite => 'Branco glacial';

  @override
  String get coreThemeJungle => 'Selva';

  @override
  String get coreThemeLocked => 'Bloqueado';

  @override
  String get coreThemeMaterialDark => 'Material escuro';

  @override
  String get coreThemeMaterialYou => 'Material You';

  @override
  String get coreThemeOlive => 'Oliva';

  @override
  String get coreThemePepper => 'Pimenta';

  @override
  String get coreThemeRose => 'Rosa';

  @override
  String get coreThemeSky => 'Céu';

  @override
  String get coreThemeSteel => 'Aço';

  @override
  String get coreThemeSpooky => 'Assustador';

  @override
  String get spookyBannerTitle => 'O tema Assustador chegou';

  @override
  String get spookyBannerSubtitle => 'Laranja, preto e algumas aranhas. Grátis. Toque para experimentar.';

  @override
  String get spookyAnnouncementTitle => 'Novo: o tema Assustador 🎃';

  @override
  String get spookyAnnouncementBody => 'Laranja, preto e algumas aranhas. É grátis. Toque para experimentar.';

  @override
  String get coreThemeDiwali => 'Diwali';

  @override
  String get diwaliBannerTitle => 'O tema Diwali chegou';

  @override
  String get diwaliBannerSubtitle => 'Diyas, fogos de artifício e ouro. Grátis. Toque para experimentar.';

  @override
  String get diwaliAnnouncementTitle => 'Novo: o tema Diwali 🪔';

  @override
  String get diwaliAnnouncementBody => 'Diyas, fogos de artifício e ouro. É grátis. Toque para experimentar.';

  @override
  String get coreThisPageDoesNotExist => 'Esta página não existe';

  @override
  String get coreTryAgain => 'Tentar novamente';

  @override
  String get coreUndo => 'Desfazer';

  @override
  String coreUp(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'mais $coinsString';
  }

  @override
  String get coreUploadFailureDailyLimit => 'Você atingiu o limite de envios de hoje. Tente novamente amanhã.';

  @override
  String get coreUploadFailureFileType =>
      'Este tipo de arquivo não é compatível. Use uma imagem JPG, PNG, WebP ou HEIC.';

  @override
  String get coreUploadFailureGeneric =>
      'O envio não foi concluído. Sua imagem continua aqui para você tentar novamente.';

  @override
  String get coreUploadFailureInProgress => 'Já há um envio em andamento. Aguarde um instante e tente novamente.';

  @override
  String get coreUploadFailureOversize => 'Esta imagem tem mais de 15 MB. Escolha uma menor.';

  @override
  String get coreUploadFailureSignIn => 'Entre novamente para enviar.';

  @override
  String get coreUploadFailureWeeklyLimit => 'Você atingiu o limite semanal de envios gratuitos.';

  @override
  String get coreUploadSubmittedSuccess => 'Seu papel de parede foi enviado e está em análise.';

  @override
  String get coreUsername => 'Nome de usuário';

  @override
  String get coreUsernameCheckFailed => 'Não foi possível verificar o nome de usuário. Tente novamente.';

  @override
  String get coreUsernameRequiredToShareProfile => 'Defina um nome de usuário para compartilhar seu perfil';

  @override
  String get coreWallpaperApplied => 'Papel de parede definido com sucesso!';

  @override
  String get coreWallpaperBothScreens => 'Ambas as telas';

  @override
  String coreWallpaperBySemanticLabel(String name) {
    return 'Papel de parede de $name';
  }

  @override
  String get coreWallpaperDownloadedPictures => 'Papel de parede baixado em Pictures/Prism!';

  @override
  String get coreWallpaperEditApplyColorFailed => 'Não foi possível aplicar a cor. Tente novamente.';

  @override
  String get coreWallpaperErrorGeneric => 'Não foi possível definir o papel de parede.';

  @override
  String get coreWallpaperErrorImageTooLarge => 'Esta imagem é grande demais para o seu dispositivo definir.';

  @override
  String get coreWallpaperErrorInvalidVideo =>
      'Não é possível reproduzir esse vídeo como papel de parede. Tente outro clipe.';

  @override
  String get coreWallpaperErrorLiveGeneric => 'Não foi possível definir o papel de parede animado. Tente novamente.';

  @override
  String get coreWallpaperErrorMemory => 'Memória insuficiente. Feche outros apps e tente novamente.';

  @override
  String get coreWallpaperErrorNotAllowed =>
      'Seu dispositivo ou perfil de trabalho não permite alterar o papel de parede.';

  @override
  String get coreWallpaperErrorPermission => 'O Prism não tem permissão para ler esse arquivo.';

  @override
  String get coreWallpaperErrorReadFile => 'Não foi possível ler o arquivo. Tente novamente.';

  @override
  String get coreWallpaperErrorSourceTooLarge => 'Esse arquivo é grande demais para um papel de parede animado.';

  @override
  String get coreWallpaperErrorStyle => 'Este dispositivo não conseguiu iniciar esse estilo. Tente outro.';

  @override
  String get coreWallpaperErrorSystemPreview => 'Não foi possível abrir a pré-visualização do sistema.';

  @override
  String get coreWallpaperErrorTextureDimensions => 'Essa imagem é grande demais para um papel de parede animado.';

  @override
  String get coreWallpaperErrorTimeout => 'Tempo esgotado. Verifique sua conexão e tente novamente.';

  @override
  String get coreWallpaperHomeScreen => 'Tela inicial';

  @override
  String get coreWallpaperHomeSetLockFailed => 'Tela inicial definida. Falha na tela de bloqueio.';

  @override
  String get coreWallpaperLinkCopyFailed => 'Não foi possível copiar o link. Tente novamente.';

  @override
  String get coreWallpaperLinkCreateFailed => 'Não foi possível criar o link de compartilhamento. Tente novamente.';

  @override
  String get coreWallpaperLoadTimedOut =>
      'Tempo esgotado ao carregar o papel de parede. Verifique sua conexão e tente novamente.';

  @override
  String get coreWallpaperLockScreen => 'Tela de bloqueio';

  @override
  String get coreWallpaperOfflineUnavailable =>
      'Este papel de parede não está salvo neste dispositivo. Conecte-se à internet e tente novamente.';

  @override
  String coreWallpaperPartialSet(String applied, String failed) {
    return '$applied definida. $failed falhou.';
  }

  @override
  String get coreWallpaperPreviewDescription => 'Veja este papel de parede incrível do Prism.';

  @override
  String get coreWallpaperPreviewTitle => 'Papel de parede no Prism';

  @override
  String get coreWallpaperSaveFailed => 'Não foi possível definir o papel de parede. Tente novamente.';

  @override
  String get coreWallpaperSavedPhotos => 'Salvo em Fotos.';

  @override
  String get coreWallpaperSavedToast => 'Sua recompensa do anúncio foi adicionada.';

  @override
  String coreWallpaperSavedWithTip(String saved, String tip) {
    return '$saved $tip';
  }

  @override
  String get coreWallpaperSemanticLabel => 'Papel de parede';

  @override
  String get coreWallpaperSet => 'Papel de parede definido';

  @override
  String get coreWallpaperShareFailed => 'Não foi possível compartilhar este papel de parede agora.';

  @override
  String get coreWallpaperShareRetryFailed => 'Não foi possível compartilhar este papel de parede. Tente novamente.';

  @override
  String get debugAdminReviewDescription => 'Ferramenta de moderação de conteúdo e notificações push';

  @override
  String get debugAdminShortcuts => 'Atalhos de admin';

  @override
  String get debugLiveActivityPreview => 'Pré-visualizar Live Activity';

  @override
  String get debugLiveActivityPreviewDescription => 'Executa uma atividade de exemplo: pronta após 8 segundos';

  @override
  String get debugLiveActivityUnavailable => 'Live Activities estão desativadas ou não são compatíveis';

  @override
  String get debugReviewActivityPreview => 'Pré-visualizar atividade da fila de revisão';

  @override
  String get debugReviewActivityPreviewDescription =>
      'Mostra os papéis de parede aguardando revisão na tela de bloqueio';

  @override
  String get debugAllTags => 'Todas as tags';

  @override
  String get debugAndroidVersion => 'Versão do Android';

  @override
  String get debugAnimationSpeed => 'Velocidade da animação';

  @override
  String get debugAppInfo => 'Informações do app';

  @override
  String get debugAppName => 'Nome do app';

  @override
  String get debugAppVersion => 'Versão do app';

  @override
  String get debugAutoScrollOff => 'Desativar rolagem automática';

  @override
  String get debugAutoScrollOn => 'Ativar rolagem automática';

  @override
  String debugBackendName(String backend) {
    return 'Backend: $backend';
  }

  @override
  String get debugBoard => 'Placa';

  @override
  String get debugBrand => 'Marca';

  @override
  String get debugBuildNumber => 'Número do build';

  @override
  String get debugBuildSignature => 'Assinatura do build';

  @override
  String get debugCacheCleared => 'Cache do app limpo';

  @override
  String get debugCancel => 'Cancelar';

  @override
  String get debugCheckLogsRetry => 'Verifique os logs e tente novamente.';

  @override
  String get debugClear => 'Limpar';

  @override
  String get debugClearAll => 'Limpar tudo';

  @override
  String get debugClearAllStorageBody =>
      'Isso exclui permanentemente todos os dados armazenados localmente. O app pode se comportar de forma inesperada até ser reiniciado.';

  @override
  String get debugClearAllStorageTitle => 'Limpar todo o armazenamento?';

  @override
  String get debugClearAppCache => 'Limpar cache do app';

  @override
  String get debugClearAppCacheDescription => 'Limpar cache de imagens, feed e notificações';

  @override
  String get debugClearImageCache => 'Limpar cache de imagens';

  @override
  String get debugClearImageCacheDescription => 'Remover o cache de imagens da memória';

  @override
  String get debugClearLogsBody => 'Isso remove todas as entradas de log mantidas na memória.';

  @override
  String get debugClearLogsTitle => 'Limpar logs?';

  @override
  String get debugClearSearch => 'Limpar busca';

  @override
  String get debugCoins => 'Moedas';

  @override
  String get debugCopied => 'Copiado';

  @override
  String get debugCopiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get debugCopy => 'Copiar';

  @override
  String get debugCopyDiagnosticReport => 'Copiar relatório de diagnóstico';

  @override
  String get debugCopyFiltered => 'Copiar tudo (filtrado)';

  @override
  String get debugCopyFullDetail => 'Copiar detalhes completos';

  @override
  String debugCopyTitle(String title) {
    return 'Copiar $title';
  }

  @override
  String get debugCopyValue => 'Copiar valor';

  @override
  String debugCouldNotClearCache(String error) {
    return 'Não foi possível limpar o cache do app: $error';
  }

  @override
  String get debugCouldNotSaveValue => 'Não foi possível salvar o valor';

  @override
  String get debugCrashApp => 'Fazer o app travar';

  @override
  String get debugDangerZone => 'Zona de perigo';

  @override
  String get debugDarkCard => 'Cartão escuro';

  @override
  String get debugDefaultValue => '(padrão)';

  @override
  String get debugDelete => 'Excluir';

  @override
  String get debugDeleteKey => 'Excluir chave';

  @override
  String debugDeleteKeyBody(String key) {
    return 'Excluir \"$key\" do armazenamento local.';
  }

  @override
  String get debugDeleteKeyTitle => 'Excluir chave?';

  @override
  String get debugDevice => 'Dispositivo';

  @override
  String get debugDeviceName => 'Dispositivo';

  @override
  String get debugDevicePixelRatio => 'Densidade de pixels do dispositivo';

  @override
  String get debugDiagnosticCopied => 'Relatório de diagnóstico copiado para a área de transferência';

  @override
  String get debugDiagnosticReportHeading => '=== Relatório de Diagnóstico de Depuração do Prism ===';

  @override
  String get debugEditValue => 'Editar valor';

  @override
  String get debugEmail => 'E-mail';

  @override
  String get debugEmptyList => 'Lista vazia';

  @override
  String get debugEnvironment => 'Ambiente';

  @override
  String get debugError => 'Erro';

  @override
  String get debugErrorCopied => 'Erro copiado';

  @override
  String get debugErrorStreakLost => 'Erro, sequência perdida';

  @override
  String get debugErrorValue => 'erro';

  @override
  String get debugExportFile => 'Exportar como arquivo';

  @override
  String get debugFavouriteAdded => 'Favorito adicionado';

  @override
  String get debugFilterByTag => 'Filtrar por tag';

  @override
  String get debugFilterKeys => 'Filtrar chaves';

  @override
  String get debugFingerprint => 'Impressão digital';

  @override
  String get debugFirestoreTelemetryDescription => 'Ver o perfil de leituras e gravações do Firestore';

  @override
  String get debugFlagsReset => 'Flags de depuração redefinidas';

  @override
  String get debugForceCrash => 'Forçar falha';

  @override
  String get debugForceCrashBody => 'Isso gera uma exceção para verificar se o Sentry reporta erros.';

  @override
  String get debugForceCrashDescription => 'Gerar uma exceção para testar os relatórios do Sentry';

  @override
  String get debugForceCrashTitle => 'Forçar falha?';

  @override
  String debugGeneratedAt(String date) {
    return 'Gerado em: $date';
  }

  @override
  String get debugHardware => 'Hardware';

  @override
  String get debugIdentifier => 'Identificador';

  @override
  String get debugImageCacheCleared => 'Cache de imagens limpo';

  @override
  String get debugIsAdmin => 'É admin';

  @override
  String get debugIsPremium => 'É Premium';

  @override
  String get debugLevel => 'Nível';

  @override
  String get debugLightCard => 'Cartão claro';

  @override
  String get debugLoadingSearch => 'Carregando, busca';

  @override
  String get debugLogDetail => 'Detalhes do log';

  @override
  String debugLogEntryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString entradas',
      one: '$countString entrada',
      zero: '$countString entradas',
    );
    return '$_temp0';
  }

  @override
  String get debugLoggedIn => 'Com login';

  @override
  String get debugLoggingAndNetwork => 'Logs e rede';

  @override
  String get debugLogicalSize => 'Tamanho lógico';

  @override
  String get debugLogs => 'Logs';

  @override
  String get debugLogsAppearHere => 'As linhas de log aparecem aqui enquanto o app roda.';

  @override
  String get debugMaintenance => 'Manutenção';

  @override
  String get debugManufacturer => 'Fabricante';

  @override
  String get debugMascot => 'Mascote';

  @override
  String get debugMessage => 'Mensagem';

  @override
  String get debugMixpanelEnabled => 'Mixpanel ativado';

  @override
  String get debugMixpanelTokenPresent => 'Token do Mixpanel presente';

  @override
  String get debugModel => 'Modelo';

  @override
  String get debugMoodCalm => 'Calmo';

  @override
  String get debugMoodCelebrate => 'Comemorando';

  @override
  String get debugMoodCurious => 'Curioso';

  @override
  String get debugMoodHappy => 'Feliz';

  @override
  String get debugMoodLove => 'Apaixonado';

  @override
  String get debugMoodProud => 'Orgulhoso';

  @override
  String get debugMoodSad => 'Triste';

  @override
  String get debugMoodSleepy => 'Sonolento';

  @override
  String get debugMoodSurprised => 'Surpreso';

  @override
  String get debugMoodWorried => 'Preocupado';

  @override
  String get debugName => 'Nome';

  @override
  String get debugNoKeysFound => 'Nenhuma chave encontrada';

  @override
  String get debugNoLogs => 'Nenhum log';

  @override
  String get debugNoMatchingLogs => 'Nenhuma linha de log corresponde aos filtros.';

  @override
  String get debugNotAvailable => 'N/D';

  @override
  String get debugNotSignedIn => 'Sem login';

  @override
  String get debugNothingNew => 'Nada novo';

  @override
  String get debugOfflineStreakRisk => 'Offline, sequência em risco';

  @override
  String get debugPackage => 'Pacote';

  @override
  String get debugPackageName => 'Nome do pacote';

  @override
  String get debugPaintBaselines => 'Pintar linhas de base';

  @override
  String get debugPaintBaselinesDescription => 'Mostrar guias de linha de base do texto';

  @override
  String get debugPaintSize => 'Pintar tamanho';

  @override
  String get debugPaintSizeDescription => 'Mostrar os limites do layout em todos os widgets';

  @override
  String get debugPaintSizeWarning =>
      'Pintar tamanho, arco-íris de repintura e linhas de base só funcionam em builds de depuração e de profile.';

  @override
  String get debugPerformanceOverlay => 'Overlay de desempenho';

  @override
  String get debugPerformanceOverlayDescription => 'Gráficos de uso de GPU e CPU';

  @override
  String get debugPersistenceBackend => 'Backend de persistência';

  @override
  String get debugPexelsKeyPresent => 'Chave do Pexels presente';

  @override
  String get debugPhysicalDevice => 'É dispositivo físico';

  @override
  String get debugPhysicalSize => 'Tamanho físico';

  @override
  String get debugPlatform => 'Plataforma';

  @override
  String get debugRcApiKeyPresent => 'Chave de API do RC presente';

  @override
  String get debugReduceMotionPose => 'Mostra a pose de movimento reduzido de cada humor';

  @override
  String get debugRefresh => 'Atualizar';

  @override
  String get debugRemoteConfig => 'Remote Config';

  @override
  String get debugRemoteConfigUnavailable => 'Remote Config indisponível';

  @override
  String get debugRendering => 'Renderização';

  @override
  String get debugRepaintRainbow => 'Arco-íris de repintura';

  @override
  String get debugRepaintRainbowDescription => 'Destacar áreas repintadas em cores alternadas';

  @override
  String get debugResetFlags => 'Redefinir todas as flags de depuração';

  @override
  String get debugResetFlagsDescription => 'Restaurar todas as opções para os valores padrão';

  @override
  String get debugSave => 'Salvar';

  @override
  String get debugSaveValueAsText => 'Ao salvar, o valor é gravado como texto.';

  @override
  String get debugScreen => 'Tela';

  @override
  String get debugSdkInt => 'Nível do SDK';

  @override
  String get debugSearchLogs => 'Buscar logs';

  @override
  String get debugSemanticsDebugger => 'Depurador de semântica';

  @override
  String get debugSemanticsDebuggerDescription => 'Sobrepor os rótulos da árvore de acessibilidade';

  @override
  String get debugSentryDsnPresent => 'DSN do Sentry presente';

  @override
  String get debugSentryEnabled => 'Sentry ativado';

  @override
  String get debugSentryEnv => 'Ambiente do Sentry';

  @override
  String get debugSequence => 'Sequência';

  @override
  String get debugShowLogToasts => 'Mostrar toasts de log';

  @override
  String get debugShowLogToastsDescription => 'Exibir entradas de log como toasts breves sobrepostos';

  @override
  String get debugSimulateNoInternet => 'Simular sem internet';

  @override
  String get debugSimulateNoInternetDescription => 'Substitui as verificações de conectividade para informar offline';

  @override
  String get debugSpeed => 'Velocidade';

  @override
  String get debugStackTrace => 'Rastreamento da pilha';

  @override
  String get debugStackTraceCopied => 'Rastreamento da pilha copiado';

  @override
  String get debugStillPoses => 'Poses estáticas';

  @override
  String get debugStorage => 'Armazenamento';

  @override
  String get debugStorageCleared => 'Todo o armazenamento foi limpo';

  @override
  String debugStorageKeyCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString chaves',
      one: '$countString chave',
      zero: '$countString chaves',
    );
    return '$_temp0';
  }

  @override
  String get debugStorageNotInitialized => 'Armazenamento não inicializado';

  @override
  String get debugStorageReadError => 'Não foi possível ler o armazenamento';

  @override
  String get debugStreakCoinsPurchase => 'Sequência, moedas, compra';

  @override
  String get debugStreakKeptToday => 'Sequência mantida hoje';

  @override
  String get debugSubscriptionTier => 'Nível da assinatura';

  @override
  String get debugSystemName => 'Nome do sistema';

  @override
  String get debugSystemVersion => 'Versão do sistema';

  @override
  String get debugTime => 'Hora';

  @override
  String get debugTitle => 'Depuração';

  @override
  String get debugTools => 'Ferramentas';

  @override
  String debugTypeName(String type) {
    return 'Tipo: $type';
  }

  @override
  String get debugUser => 'Usuário';

  @override
  String get debugUserId => 'ID do usuário';

  @override
  String get debugUsername => 'Nome de usuário';

  @override
  String get debugValue => 'Valor';

  @override
  String get debugVersion => 'Versão';

  @override
  String get debugWallpaperSetSaved => 'Papel de parede definido ou salvo';

  @override
  String get debugWotdNotification => 'Papel de parede do dia, notificação';

  @override
  String get deepLinkInputChooseImage => 'Escolher imagem';

  @override
  String get deepLinkInputChooseImageDescription => 'Escolha uma imagem da sua galeria para continuar.';

  @override
  String get deepLinkInputClockPreviewTitle => 'Prévia do relógio';

  @override
  String get deepLinkInputEditTitle => 'Editar um papel de parede';

  @override
  String get deepLinkInputFiltersTitle => 'Filtros de papel de parede';

  @override
  String get deepLinkInputGalleryError => 'Não foi possível abrir sua galeria. Tente novamente.';

  @override
  String get deepLinkInputLiveTitle => 'Papel de parede animado';

  @override
  String get deepLinkInputPhotoPreviewTitle => 'Prévia da foto';

  @override
  String get deepLinkInputPositionTitle => 'Posicionar um papel de parede';

  @override
  String get deepLinkInputUploadTitle => 'Enviar um papel de parede';

  @override
  String get deepLinkInputWallpaperPreviewTitle => 'Prévia do papel de parede';

  @override
  String get economyActivity => 'Atividade';

  @override
  String get economyActivityEmptyMessage =>
      'Assista a um vídeo ou mantenha sua sequência para ganhar suas primeiras moedas.';

  @override
  String get economyActivityLoadFailed => 'Não foi possível carregar a atividade.';

  @override
  String get economyAdCreditFailure => 'Não foi possível creditar as moedas agora.';

  @override
  String get economyAdDailyLimit => 'Limite diário atingido. Volte amanhã.';

  @override
  String get economyAdNotCompleted => 'O anúncio não foi concluído.';

  @override
  String get economyAdOffline => 'Você está offline. Verifique sua conexão e tente novamente.';

  @override
  String economyAdRewardDetails(int first, int reward, int maximum) {
    final intl.NumberFormat firstNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String firstString = firstNumberFormat.format(first);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'O primeiro do dia +$firstString, depois +$rewardString. Até $maximumString por dia.';
  }

  @override
  String get economyAdRewardPending =>
      'Ainda não foi possível confirmar sua recompensa. As moedas chegam quando você voltar a ficar online.';

  @override
  String get economyAdUnavailable => 'Nenhum anúncio disponível agora. Tente novamente mais tarde.';

  @override
  String get economyAddPhotoBio => 'Adicione uma foto e uma bio';

  @override
  String get economyAddedToBalance => 'Adicionado ao seu saldo';

  @override
  String get economyAddedToCollection => 'Adicionado à sua coleção';

  @override
  String get economyAddedToXp => 'Adicionado ao seu XP';

  @override
  String get economyAdsOffPrivacy => 'Os anúncios estão desativados. Altere isso em Configurações > Privacidade.';

  @override
  String get economyAiBusyRefunded =>
      'A IA está muito ocupada agora. Tente novamente mais tarde. Suas moedas foram devolvidas.';

  @override
  String get economyAiChargeUnconfirmed =>
      'Não foi possível confirmar a cobrança. Qualquer moeda debitada será devolvida.';

  @override
  String get economyAiCheckStatus => 'Verificar status';

  @override
  String economyAiCoinsNeeded(int cost, int balance) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Você precisa de $costString moedas. Você tem $balanceString.';
  }

  @override
  String get economyAiConnectToGenerate => 'Sem conexão. Conecte-se à internet e tente novamente.';

  @override
  String get economyAiCouldNotConfirmSubmission =>
      'Não foi possível confirmar o envio. Verifique o status da revisão antes de tentar novamente.';

  @override
  String get economyAiCropMayDiffer => 'O corte pode ser um pouco diferente no seu dispositivo.';

  @override
  String get aiLiveActivityGenerating => 'Criando seu papel de parede';

  @override
  String get aiLiveActivityReady => 'Seu papel de parede está pronto';

  @override
  String get aiLiveActivityFailed => 'Não foi possível criar';

  @override
  String get aiLiveActivityStale => 'Ainda trabalhando nisso';

  @override
  String get aiLiveActivityOpen => 'Abrir no Prism';

  @override
  String get aiResultApply => 'Aplicar';

  @override
  String get aiResultEditPrompt => 'Editar descrição';

  @override
  String get aiSessionStripLabel => 'Papéis de parede desta sessão';

  @override
  String aiSessionTake(int index, int count) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Versão $indexString de $countString';
  }

  @override
  String get aiFollowUpWatercolour => 'Em aquarela';

  @override
  String get aiFollowUpNight => 'Versão noturna';

  @override
  String get aiFollowUpMinimal => 'Mais minimalista';

  @override
  String get aiFollowUpWarmer => 'Mais quente';

  @override
  String get aiFollowUpDepth => 'Adicionar profundidade';

  @override
  String aiFollowUpCostLabel(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Cada nova versão custa $costString moedas';
  }

  @override
  String get aiFollowUpConfirmTitle => 'Criar uma nova versão?';

  @override
  String aiFollowUpConfirmBody(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Uma nova versão cria outro papel de parede a partir deste. Cada uma custa $costString moedas.';
  }

  @override
  String get aiFollowUpConfirmAction => 'Criar';

  @override
  String get economyAiDailyLimit => 'Você atingiu o limite de IA de hoje.';

  @override
  String get economyAiDescribeChanges => 'Diga o que você quer diferente, como cores, clima ou detalhes.';

  @override
  String get economyAiDescribeScene => 'Descreva uma cena para gerar.';

  @override
  String get economyAiDownloadFailed => 'Não foi possível baixar! Tente novamente.';

  @override
  String economyAiFailureWithRefund(String message, String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'refunded': ' Moedas devolvidas.',
      'pending': ' Reembolso pendente.',
      'other': ' Não foi possível concluir o reembolso.',
    });
    return '$message$_temp0';
  }

  @override
  String get economyAiGenerate => 'Gerar';

  @override
  String get economyAiGenerateAnother => 'Gerar outro';

  @override
  String get economyAiGenerateFailed => 'Não foi possível gerar agora. Tente novamente.';

  @override
  String get economyAiGenerateGenericFailure => 'Algo deu errado. Tente novamente.';

  @override
  String get economyAiGeneratedWallpaper => 'Papel de parede gerado';

  @override
  String economyAiGenerationFrom(String date) {
    return 'Geração de $date';
  }

  @override
  String get economyAiGenerationRollingOut =>
      'A geração por IA está sendo liberada aos poucos. Tente novamente em breve.';

  @override
  String get economyAiGenerationTime => 'Isso leva cerca de 20 segundos';

  @override
  String get economyAiHistoryEmpty =>
      'Cada papel de parede que você gerar aparece aqui, para você comparar ou voltar a um anterior.';

  @override
  String get economyAiHistoryFailed => 'Não foi possível carregar o histórico. Puxe para atualizar.';

  @override
  String get economyAiMatchingScreenSize => 'Ajustando ao tamanho da sua tela…';

  @override
  String get economyAiApplyingStyle => 'Aplicando seu estilo…';

  @override
  String get economyAiFinalizingWallpaper => 'Finalizando seu papel de parede…';

  @override
  String get economyAiRemixHint => 'Céu mais escuro, cores mais quentes, contornos mais suaves…';

  @override
  String economyAiNeedCoinsToGenerate(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'São necessárias $costString moedas para gerar.';
  }

  @override
  String economyNeedMoreCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $countString moedas.',
      one: 'Falta $countString moeda.',
      zero: 'Faltam $countString moedas.',
    );
    return '$_temp0';
  }

  @override
  String get economyAiNoConnection => 'Sem conexão. Verifique sua rede e tente novamente.';

  @override
  String get economyAiNoConnectionRetry => 'Sem conexão. Tente novamente.';

  @override
  String get economyAiOfflineHistory => 'Você está offline ou a rede falhou. Puxe para atualizar quando voltar.';

  @override
  String get economyAiOfflineSavedHistory => 'Você está offline. O histórico salvo continua disponível.';

  @override
  String get economyAiPaymentCheckFailed => 'A verificação do pagamento falhou. Suas moedas serão devolvidas.';

  @override
  String get economyAiPreparingShare => 'Preparando o compartilhamento';

  @override
  String get economyAiPromptBlocked => 'Esse prompt não é permitido.';

  @override
  String economyAiPromptTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'A descrição é muito longa (máx. $maximumString caracteres).';
  }

  @override
  String get economyAiQuality => 'Qualidade';

  @override
  String get economyAiQualityBalanced => 'Equilibrada';

  @override
  String get economyAiQualityFast => 'Rápida';

  @override
  String get economyAiQualityHigh => 'Qualidade';

  @override
  String economyAiQualitySemantics(String quality, int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '$quality, $costString moedas';
  }

  @override
  String get economyAiRecent => 'Recentes';

  @override
  String get economyAiRefineExplanation =>
      'Diga o que deve mudar. Isso cria um novo papel de parede a partir do mesmo prompt com uma nova semente, então ele pode ficar bem diferente.';

  @override
  String get economyAiResultBlocked => 'O resultado foi bloqueado. Tente outro prompt.';

  @override
  String economyAiRolloutBody(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Está ativo para $percentString% das contas até agora. Tente novamente em breve.';
  }

  @override
  String get economyAiRolloutTitle => 'O papel de parede com IA está sendo liberado aos poucos';

  @override
  String get economyAiSave => 'Salvar';

  @override
  String get economyAiSaveFailed => 'Não foi possível salvar esse arquivo. Tente novamente.';

  @override
  String get economyAiSceneIdea => 'Ideia de cena';

  @override
  String get economyAiSceneIdeaMessage => 'Use esta cena na sua descrição (editável)';

  @override
  String get economyAiSetAsWallpaper => 'Definir como papel de parede';

  @override
  String get economyAiShare => 'Compartilhar';

  @override
  String get economyAiShareFailed => 'Não foi possível compartilhar. Tente novamente.';

  @override
  String get economyAiShareReviewNotice =>
      'Os moderadores revisam os envios antes de eles aparecerem no Prism. Compartilhe apenas trabalhos dos quais você tenha os direitos.';

  @override
  String get economyAiShareWithCommunity => 'Compartilhar com a comunidade?';

  @override
  String get economyAiShuffle => 'Misturar';

  @override
  String get economyAiShuffleMessage => 'Misturar uma nova descrição de exemplo';

  @override
  String get economyAiStillWorking => 'Ainda trabalhando na sua última imagem.';

  @override
  String get economyAiStyle => 'Estilo';

  @override
  String get economyAiStyleAbstract => 'Abstrato';

  @override
  String get economyAiStyleAnime => 'Anime';

  @override
  String get economyAiStyleCyberpunk => 'Cyberpunk';

  @override
  String get economyAiStyleMeshGradient => 'Gradiente de malha';

  @override
  String get economyAiStyleMinimal => 'Minimalista';

  @override
  String get economyAiStyleNature => 'Natureza';

  @override
  String economyAiStyleSemantics(String style) {
    return 'Estilo: $style';
  }

  @override
  String get economyAiStyleSheetTitle => 'Escolha um estilo';

  @override
  String get economyAiStyleSheetSubject => 'Cada prévia mostra a mesma cena: um farol em um penhasco ao entardecer.';

  @override
  String get economyAiStyleWatercolor => 'Aquarela';

  @override
  String get economyAiStyleSpace => 'Espaço';

  @override
  String get economyAiStyleSynthwave => 'Synthwave';

  @override
  String get economyAiStylePixelArt => 'Pixel art';

  @override
  String get economyAiStyleRender3d => 'Render 3D';

  @override
  String get economyAiStyleOilPainting => 'Pintura a óleo';

  @override
  String get economyAiStyleUkiyoE => 'Ukiyo-e';

  @override
  String get economyAiSubmissionUnconfirmed =>
      'O status do envio não foi confirmado. Verifique antes de tentar novamente.';

  @override
  String get economyAiSubmitDisabled => 'O envio de IA está desativado no momento.';

  @override
  String get economyAiSubmitFailed => 'Falha no envio. Tente novamente.';

  @override
  String get economyAiSubmitForReview => 'Enviar para revisão da comunidade';

  @override
  String get economyAiSubmitStatusUnconfirmed =>
      'O status do envio não foi confirmado. Verifique o status da revisão antes de tentar novamente.';

  @override
  String get economyAiSubmittedForReview => 'Enviado para revisão.';

  @override
  String get economyAiTryAgain => 'Tentar novamente';

  @override
  String get economyAiTryAnother => 'Tentar outro';

  @override
  String get economyAiTryAnotherVersion => 'Tentar outra versão';

  @override
  String get economyAiUnavailableBody => 'Desativamos por um curto período. Volte em breve.';

  @override
  String get economyAiUnavailableTitle => 'O papel de parede com IA está desativado por enquanto';

  @override
  String economyAiVariationTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Essa descrição é muito longa (máx. $maximumString caracteres).';
  }

  @override
  String get economyAiVariationUnavailable => 'Tentar outro não está disponível agora.';

  @override
  String get economyAiWallpaper => 'Papel de parede com IA';

  @override
  String get economyAiWatermarkNote => 'Imagens gratuitas têm a marca d\'água do Prism. O Pro a remove.';

  @override
  String get economyAllRankRewardsCollected => 'Todas as recompensas de nível coletadas';

  @override
  String get economyAllSpinsUsed => 'Todos os giros usados';

  @override
  String get economyBackTomorrow => 'Volte amanhã';

  @override
  String get economyBadge => 'Selo';

  @override
  String get economyBadgeAiArtist => 'Artista de IA';

  @override
  String get economyBadgeAiArtistDescription => 'Gere 10 papéis de parede com IA';

  @override
  String get economyBadgeArtCurator => 'Curador de Arte';

  @override
  String get economyBadgeArtCuratorDescription => 'Favorite 50 papéis de parede';

  @override
  String get economyBadgeCollector => 'Colecionador';

  @override
  String get economyBadgeCollectorDescription => 'Favorite 10 papéis de parede';

  @override
  String get economyBadgeCreator => 'Criador';

  @override
  String get economyBadgeCreatorDescription => 'Tenha um papel de parede aprovado';

  @override
  String get economyBadgeDescription => 'Um selo no Prism';

  @override
  String get economyBadgeEarned => 'Selo conquistado';

  @override
  String economyBadgeEarnedCount(int count, int total) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$countString de $totalString conquistados';
  }

  @override
  String economyBadgeName(String name) {
    return 'Selo $name';
  }

  @override
  String get economyBadgePrismVeteran => 'Veterano do Prism';

  @override
  String get economyBadgePrismVeteranDescription => 'Use o Prism por 30 dias e alcance uma sequência de 7 dias';

  @override
  String get economyBadgeProfileComplete => 'Perfil Completo';

  @override
  String get economyBadgeProfileCompleteDescription => 'Adicione uma foto, nome de usuário, bio e um link';

  @override
  String economyBadgeSemantics(String name, String status, String description) {
    return '$name, $status. $description';
  }

  @override
  String get economyBadgeSocialButterfly => 'Sociável';

  @override
  String get economyBadgeSocialButterflyDescription => 'Siga 10 criadores';

  @override
  String get economyBadgeStatusEarned => 'Conquistado';

  @override
  String get economyBadgeStatusLocked => 'Bloqueado';

  @override
  String get economyBadgeStreakMaster => 'Mestre da Sequência';

  @override
  String get economyBadgeStreakMasterDescription => 'Alcance uma sequência de 28 dias';

  @override
  String get economyBadgeWeekWarrior => 'Guerreiro da Semana';

  @override
  String get economyBadgeWeekWarriorDescription => 'Alcance uma sequência de 7 dias';

  @override
  String get economyBadges => 'Selos';

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

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString dias',
      one: '1 dia',
      zero: '$countString dias',
    );
    return 'Melhor: $_temp0';
  }

  @override
  String get economyBoost => 'Impulsionar';

  @override
  String economyBoostInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Coloque um dos seus papéis de parede aprovados no topo de Em alta. Um impulso custa $amountString moedas. Abra seu papel de parede e toque em Impulsionar.';
  }

  @override
  String get economyBuildStreakDaily => 'Abra o Prism todos os dias para criar uma sequência.';

  @override
  String get economyBuy => 'Comprar';

  @override
  String get economyBuyPremium => 'Comprar Premium';

  @override
  String get economyCancel => 'Cancelar';

  @override
  String get economyChestBonusDone => 'Missão bônus concluída: suas moedas foram dobradas.';

  @override
  String get economyChestBonusToDouble => 'Faça primeiro a missão bônus de hoje para dobrar suas moedas.';

  @override
  String economyChestBoosterSemantics(String title, String caption) {
    return '$title. $caption';
  }

  @override
  String economyChestCoinsPrize(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString moedas',
      one: '1 moeda',
      zero: '$coinsString moedas',
    );
    return '$_temp0';
  }

  @override
  String get economyChestDoFirst => 'Faça isto primeiro para dobrar seu baú';

  @override
  String get economyChestDoubled => 'Baú dobrado';

  @override
  String get economyChestDoubledByBonus => ' Dobrado pela sua missão bônus.';

  @override
  String get economyChestFreeToday => 'Grátis hoje';

  @override
  String economyChestNeedCoins(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'O baú custa $priceString moedas. Você tem $balanceString. Assista a um vídeo para ganhar mais.';
  }

  @override
  String economyChestNewCosmetic(String kind, String name) {
    return 'um novo $kind: $name';
  }

  @override
  String economyChestNewKind(String kind) {
    return 'Novo $kind';
  }

  @override
  String get economyChestOpenFailed => 'Não foi possível acessar o Prism. Tente novamente.';

  @override
  String economyChestOpenFor(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $countString missões',
      one: 'mais 1 missão',
      zero: 'mais $countString missões',
    );
    return 'Abra por $priceString moedas ou conclua $_temp0 para abrir de graça.';
  }

  @override
  String get economyChestOpened => 'Aberto';

  @override
  String get economyChestOpenedDoubledTomorrow => 'Aberto e dobrado. Um novo amanhã.';

  @override
  String economyChestOpenedReset(String time) {
    return 'Aberto. Um novo baú em $time.';
  }

  @override
  String get economyChestOpenedTomorrow => 'Aberto. Um novo amanhã.';

  @override
  String get economyChestOwnCosmeticCoins => 'Você tem todos os cosméticos, então ele paga em moedas';

  @override
  String get economyChestOwnEveryCosmetic => 'Você tem todos os cosméticos';

  @override
  String get economyChestPriceChanged => 'O preço mudou. Confira e abra novamente.';

  @override
  String economyChestPriceFreeAfter(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $countString missões',
      one: 'mais 1 missão',
      zero: 'mais $countString missões',
    );
    return '$priceString moedas, ou grátis após $_temp0';
  }

  @override
  String economyChestPrizeSemantics(String tier, String prize, String doubled, int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(doubled, {'true': ' Dobrado pela sua missão bônus.', 'other': ''});
    String _temp1 = intl.Intl.pluralLogic(
      xp,
      locale: localeName,
      other: ' Mais $xpString XP.',
      one: ' Mais 1 XP.',
      zero: '',
    );
    return '$tier. Você ganhou $prize.$_temp0$_temp1';
  }

  @override
  String get economyChestQuestsFree => 'Suas missões deixaram o baú grátis hoje.';

  @override
  String get economyChestReady => 'Pronto para abrir';

  @override
  String economyChestReadyPaid(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Pronto para abrir. $doneString de $totalString missões concluídas';
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

    return '${hoursString}h ${minutesString}min';
  }

  @override
  String economyChestResetMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '${minutesString}min';
  }

  @override
  String get economyChestTierCommon => 'Comum';

  @override
  String get economyChestTierEpic => 'Épico';

  @override
  String get economyChestTierLegendary => 'Lendário';

  @override
  String get economyChestTierRare => 'Raro';

  @override
  String economyChestXpLine(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Abrir o baú dá $xpString XP.';
  }

  @override
  String get economyClaimedTodayDay7Chest =>
      'Sua recompensa de hoje já foi resgatada. Volte amanhã para receber seu baú do dia 7.';

  @override
  String economyClaimedTodayReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Sua recompensa de hoje já foi resgatada. Volte amanhã para ganhar +$coinsString moedas.';
  }

  @override
  String get economyClosePreview => 'Fechar prévia';

  @override
  String economyCoinActivitySemantics(String label, String date, String amount, int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'moedas', one: 'moeda', zero: 'moedas');
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
    return '$action. Não foi possível confirmar seu reembolso.';
  }

  @override
  String economyCoinGateRefunded(String action, int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString moedas reembolsadas.',
      one: '1 moeda reembolsada.',
      zero: '$coinsString moedas reembolsadas.',
    );
    return '$action. $_temp0';
  }

  @override
  String get economyCoinHistoryEarned => 'Ganhas';

  @override
  String get economyCoinHistoryEmpty => 'Nenhuma atividade de moedas ainda.';

  @override
  String get economyCoinHistoryLoadFailed => 'Não foi possível carregar seu histórico de moedas.';

  @override
  String get economyCoinHistoryNoLoadedRows => 'Nenhuma atividade nos registros carregados até agora.';

  @override
  String get economyCoinHistoryNothingHere => 'Nada aqui ainda.';

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
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'moedas', one: 'moeda', zero: 'moedas');
    return '$label$_temp0, $date, $amount $_temp1, $balance';
  }

  @override
  String get economyCoinHistorySpent => 'Gastas';

  @override
  String get economyCoinHistoryTitle => 'Histórico de moedas';

  @override
  String get economyCoinSpendFailed => 'Não foi possível processar as moedas agora.';

  @override
  String economyCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString moedas',
      one: '1 moeda',
      zero: '$countString moedas',
    );
    return '$_temp0';
  }

  @override
  String get economyCoinsAreYoursToSpend => 'As moedas são suas para gastar';

  @override
  String economyCoinsEarned(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString moedas',
      one: '1 moeda',
      zero: '$countString moedas',
    );
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
      'As moedas pagam papéis de parede, ferramentas e itens da Loja. XP é progresso, não um saldo que você gasta. Gastar moedas nunca diminui seu XP.';

  @override
  String get economyCoinsWhatYouCanDo => 'O que você pode fazer com elas';

  @override
  String get economyCoinsWord => 'moedas';

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
      'true': ', ou use $coinsString moedas para desbloqueá-lo agora',
      'other': '',
    });
    return 'Mantenha uma sequência de $daysString dias para desbloquear este papel de parede$_temp0.';
  }

  @override
  String get economyCollectionLoadFailed => 'Não foi possível carregar esta coleção';

  @override
  String economyCollectionNeedCoinsMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Você precisa de $coinsString moedas para desbloquear este papel de parede.';
  }

  @override
  String get economyCollectionRequirementsUnmet => 'Este papel de parede ainda não está disponível.';

  @override
  String get economyCollectionStillLocked => 'Ainda bloqueado';

  @override
  String economyCollectionUnlockedAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Desbloqueado com uma sequência de $daysString dias';
  }

  @override
  String get economyCollectionUnlockedWithCoins => 'Desbloqueado com moedas';

  @override
  String economyCollectionUnlocksAtCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Desbloqueia por $coinsString moedas';
  }

  @override
  String economyCollectionUnlocksAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Desbloqueia com uma sequência de $daysString dias';
  }

  @override
  String get economyCompleteProfile => 'Complete seu perfil';

  @override
  String get economyCosmetic => 'item visual';

  @override
  String get economyCosmeticAppIcon => 'ícone do app';

  @override
  String get economyCosmeticFrame => 'moldura';

  @override
  String get economyCosmeticNameGlow => 'brilho no nome';

  @override
  String get economyCosmeticTheme => 'tema';

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
  String get economyCreatorApprovedWalls => 'Papéis de parede aprovados';

  @override
  String get economyCreatorIntro =>
      'Ganhe XP quando seus papéis de parede forem aprovados e novos membros os favoritarem. O progresso aparece após sua primeira contribuição qualificada.';

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
    return 'Marco de $label';
  }

  @override
  String get economyCreatorMilestones => 'Marcos de criador';

  @override
  String economyCreatorMilestonesComplete(String label) {
    return 'Marcos de $label concluídos';
  }

  @override
  String economyCreatorNewMembersThisWeek(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString novos membros favoritaram seus papéis de parede esta semana';
  }

  @override
  String economyCreatorNextMilestone(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Próximo marco: +$xpString XP';
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
  String get economyCreatorQualifyingMembers => 'Membros qualificados';

  @override
  String get economyCreatorRefresh => 'Atualizar progresso';

  @override
  String get economyCreatorRefreshing => 'Atualizando o progresso do criador…';

  @override
  String get economyCreatorRules =>
      'Os papéis de parede aprovados devem ser envios seus e elegíveis. Envios mais antigos podem ser inelegíveis se o Prism não conseguir verificar o envio original. Cada outro membro conta uma vez em todo o seu trabalho elegível, no primeiro favorito qualificado. Ele precisa ter entrado na conta, ter um e-mail verificado e uma conta com pelo menos sete dias. Seus próprios favoritos não contam. As contagens são históricas, não o seu público atual. Remover favoritos não desfaz o XP. Os marcos de criador rendem XP extra. As semanas vão de segunda a domingo em UTC; atividades atrasadas podem aparecer em uma semana posterior.';

  @override
  String get economyCreatorSavedRefresh => 'Progresso salvo. Atualize para ver as mudanças.';

  @override
  String get economyCreatorSavedUnavailable => 'Progresso salvo. A atualização não está disponível.';

  @override
  String economyCreatorThisWeekSummary(int walls, int xp) {
    final intl.NumberFormat wallsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String wallsString = wallsNumberFormat.format(walls);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$wallsString papéis de parede elegíveis aprovados · $xpString XP de marcos';
  }

  @override
  String economyCreatorTrackingSince(String date) {
    return 'Acompanhando desde $date UTC';
  }

  @override
  String get economyCreatorUnavailable => 'O progresso do criador não está disponível.';

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

    return '$wallsString papéis de parede elegíveis aprovados · $membersString novos membros qualificados · $xpString XP de marcos';
  }

  @override
  String get economyCreatorWhatCounts => 'O que conta e histórico';

  @override
  String get economyDailyChest => 'Baú diário';

  @override
  String economyDailyChestSemantics(String state, String caption, String hasXp, String xpLine) {
    String _temp0 = intl.Intl.selectLogic(hasXp, {'true': '. $xpLine', 'other': ''});
    return 'Baú diário, $state. $caption$_temp0';
  }

  @override
  String get economyDailyChestTitle => 'Baú diário';

  @override
  String get economyDailyQuests => 'Missões diárias';

  @override
  String get economyDailyStreak => 'Sequência diária';

  @override
  String get economyDay7Chest => 'Baú do dia 7';

  @override
  String economyDayLabel(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Dia $dayString';
  }

  @override
  String economyDayStreakMilestone(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Sequência de $daysString dias!';
  }

  @override
  String economyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'dias', one: 'dia', zero: 'dias');
    return '$_temp0';
  }

  @override
  String economyDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $countString dias',
      one: 'há 1 dia',
      zero: 'há $countString dias',
    );
    return '$_temp0';
  }

  @override
  String get economyDownload => 'Baixar';

  @override
  String get economyDownloadAccountChanged => 'A conta mudou. Tente salvar novamente.';

  @override
  String get economyDownloadAgain => 'Baixar novamente';

  @override
  String economyDownloadAgainCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Baixar novamente (-$costString moedas)';
  }

  @override
  String get economyDownloadAlreadyInDownloads => 'Já está em Downloads';

  @override
  String economyDownloadCoinsNeeded(int missing, int reward, String watch, String adState) {
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(watch, {'true': ' Cada anúncio rende $rewardString.', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(adState, {
      'disabled': ' Os anúncios estão desativados. Mude isso em Configurações > Privacidade.',
      'limit': ' Limite diário atingido. Volte amanhã.',
      'other': '',
    });
    return 'Você precisa de mais $missingString moedas para salvar este papel de parede.$_temp0$_temp1';
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

    return '$label. Custa $costString moedas';
  }

  @override
  String get economyDownloadFailedLabel => 'Falha no download';

  @override
  String economyDownloadFreeDownloadsLeftSemantics(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString downloads grátis restantes',
      one: '1 download grátis restante',
      zero: '$countString downloads grátis restantes',
    );
    return '$label. Grátis, $_temp0';
  }

  @override
  String economyDownloadFreeFor(String label) {
    return '$label · Grátis';
  }

  @override
  String economyDownloadFreeLeftFor(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label · Grátis · $countString restantes';
  }

  @override
  String economyDownloadFreeOwnedSemantics(String label) {
    return '$label. Grátis, este papel de parede é seu';
  }

  @override
  String economyDownloadFreeWithPassSemantics(String label) {
    return '$label. Grátis com seu passe';
  }

  @override
  String get economyDownloadFreeWithPro => 'Grátis com o Pro';

  @override
  String economyDownloadFreeWithProSemantics(String label) {
    return '$label. Grátis com o Pro';
  }

  @override
  String get economyDownloadLinkUnavailable => 'Nenhum link de download disponível.';

  @override
  String get economyDownloadProGuestMessage =>
      'Entre para salvar este papel de parede com moedas ou assine o Prism Pro.';

  @override
  String get economyDownloadSaveLocalCopy => 'Salvar cópia local';

  @override
  String get economyDownloadSaved => 'Salvo';

  @override
  String get economyDownloadSavedBefore => 'Você já salvou este papel de parede antes.';

  @override
  String get economyDownloadSavedInDownloads => 'Salvo. Já está em Downloads';

  @override
  String get economyDownloadThisWallpaper => 'Baixar este papel de parede';

  @override
  String get economyDownloadWaitForCurrent => 'Aguarde o download terminar!';

  @override
  String get economyDownloadWatchAdMessage => 'Assista a um pequeno anúncio em vídeo para baixar este papel de parede.';

  @override
  String get economyDownloadWatchAdPrivacyMessage =>
      'Assista a um pequeno anúncio em vídeo para baixar este papel de parede. Os anúncios estão desativados. Mude isso em Configurações > Privacidade.';

  @override
  String get economyDownloads => 'Downloads';

  @override
  String economyDownloadsInfo(int amount, int freeCount, String hasFree) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat freeCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String freeCountString = freeCountNumberFormat.format(freeCount);

    String _temp0 = intl.Intl.selectLogic(hasFree, {'true': ' Os primeiros $freeCountString são grátis.', 'other': ''});
    return 'Cada download de papel de parede custa $amountString moedas.$_temp0 O Pro torna os downloads grátis.';
  }

  @override
  String economyDrawAllTicketsHeld(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Você já tem todos os $maximumString bilhetes desta semana.';
  }

  @override
  String economyDrawBuyTicket(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Comprar um bilhete · $priceString';
  }

  @override
  String get economyDrawClosed => 'Este sorteio está encerrado. O próximo abre na segunda-feira.';

  @override
  String economyDrawClosesIn(String time) {
    return 'Encerra em $time';
  }

  @override
  String get economyDrawLastWinner => 'Último vencedor';

  @override
  String get economyDrawLoadFailed => 'Não foi possível carregar o Sorteio';

  @override
  String get economyDrawNotEnoughCoins => 'Moedas insuficientes para um bilhete.';

  @override
  String get economyDrawNotOpen => 'O Sorteio ainda não está aberto.';

  @override
  String get economyDrawOfficialRules => 'Regras oficiais';

  @override
  String economyDrawPrizeDescription(int months) {
    final intl.NumberFormat monthsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$monthsString meses',
      one: '1 mês',
      zero: '$monthsString meses',
    );
    return '$_temp0 de Pro + a moldura Prism';
  }

  @override
  String get economyDrawProNotEligible => 'Membros Pro não são elegíveis.';

  @override
  String get economyDrawPurchaseFailed => 'Não foi possível comprar um bilhete. Tente novamente.';

  @override
  String get economyDrawThisWeeksPrize => 'PRÊMIO DESTA SEMANA';

  @override
  String economyDrawTicketBought(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Bilhete comprado. Você tem $ticketsString de $maximumString.';
  }

  @override
  String economyDrawTicketCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Os bilhetes custam $priceString moedas';
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
      other: '$ticketsString bilhetes',
      one: '1 bilhete',
      zero: '$ticketsString bilhetes',
    );
    String _temp1 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$peopleString pessoas',
      one: '1 pessoa',
      zero: '$peopleString pessoas',
    );
    return '$_temp0 de $_temp1';
  }

  @override
  String get economyDrawTitle => 'Sorteio Prism';

  @override
  String economyDrawYourChance(int mine, int pot) {
    final intl.NumberFormat mineNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String mineString = mineNumberFormat.format(mine);
    final intl.NumberFormat potNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String potString = potNumberFormat.format(pot);

    return 'Sua chance: $mineString/$potString';
  }

  @override
  String economyDrawYourTickets(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Seus bilhetes: $ticketsString de $maximumString';
  }

  @override
  String get economyDropAlreadyUnlocked => 'Você já tem este.';

  @override
  String economyDropByCreator(String creator) {
    return 'por $creator';
  }

  @override
  String economyDropCardSemantics(String time, int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Drop semanal, $time, $unlockedString de $totalString coletados';
  }

  @override
  String economyDropCarouselDetail(int count, String time) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede',
      one: '1 papel de parede',
      zero: '$countString papéis de parede',
    );
    return '$_temp0 · $time';
  }

  @override
  String economyDropCarouselSemantics(String title, String detail, String lastCall) {
    String _temp0 = intl.Intl.selectLogic(lastCall, {'true': ', última chamada', 'other': ''});
    return 'Drop semanal, $title, $detail$_temp0';
  }

  @override
  String economyDropCollected(int owned, int total) {
    final intl.NumberFormat ownedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ownedString = ownedNumberFormat.format(owned);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$ownedString de $totalString coletados';
  }

  @override
  String economyDropDates(String start, String end) {
    return '$start a $end';
  }

  @override
  String get economyDropEnded => 'Encerrado';

  @override
  String get economyDropEndedHeadline => 'Este Drop terminou';

  @override
  String economyDropEndsInDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '${daysString}d',
      one: '1d',
      zero: '${daysString}d',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '${hoursString}h',
      one: '1h',
      zero: '${hoursString}h',
    );
    return 'Termina em $_temp0 $_temp1';
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
      other: '${hoursString}h',
      one: '1h',
      zero: '${hoursString}h',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '${minutesString}m',
      one: '1m',
      zero: '${minutesString}m',
    );
    return 'Termina em $_temp0 $_temp1';
  }

  @override
  String economyDropEndsInMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return 'Termina em ${minutesString}m';
  }

  @override
  String get economyDropGone => 'Este Drop acabou';

  @override
  String get economyDropLastCallLabel => 'Última chamada';

  @override
  String get economyDropLoadFailed => 'Não foi possível carregar o Drop';

  @override
  String get economyDropLocked => 'Bloqueado';

  @override
  String get economyDropMissed => 'Perdido';

  @override
  String get economyDropOver => 'Este Drop acabou.';

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
  String get economyDropPreviewTitle => 'Prévia do Drop';

  @override
  String get economyDropRename => 'Renomear Drop';

  @override
  String get economyDropRenameFailed => 'Não foi possível renomear o Drop. Tente novamente.';

  @override
  String get economyDropRenameHint => 'Nome do Drop';

  @override
  String get economyDropRenamed => 'Drop renomeado';

  @override
  String economyDropSave(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Economize $coinsString';
  }

  @override
  String economyDropStats(String walls, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString colecionadores',
      one: '1 colecionador',
      zero: '$countString colecionadores',
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

    return 'Desbloquear todos os $countString por $priceString';
  }

  @override
  String get economyDropUnlockFailed => 'Não foi possível desbloquear. Tente novamente.';

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

    return 'Desbloquear este papel de parede por $priceString';
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
      other: '$countString papéis de parede desbloqueados',
      one: 'Papel de parede desbloqueado',
      zero: '$countString papéis de parede desbloqueados',
    );
    return '$_temp0';
  }

  @override
  String get economyDropUnlockedWall => 'Papel de parede desbloqueado';

  @override
  String economyDropUnlockedWallBy(String creator) {
    return 'Papel de parede desbloqueado de $creator';
  }

  @override
  String economyDropWallBySemantics(String state, String serial, String creator) {
    return 'Papel de parede $serial de $creator, $state';
  }

  @override
  String economyDropWallCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede',
      one: '1 papel de parede',
      zero: '$countString papéis de parede',
    );
    return '$_temp0';
  }

  @override
  String economyDropWallSemantics(String state, String serial) {
    return 'Papel de parede $serial, $state';
  }

  @override
  String get economyDropWallpaperUnavailable => 'Este papel de parede não está disponível';

  @override
  String economyDropWeekOf(String date) {
    return 'Semana de $date';
  }

  @override
  String get economyDropYourVault => 'Seu cofre';

  @override
  String get economyDrops => 'Drops';

  @override
  String get economyEarnCoins => 'Ganhe moedas';

  @override
  String get economyEarnXpAsYouGo => 'Ganhe XP conforme você usa';

  @override
  String economyEarnedAtRank(String rank) {
    return 'Conquistado em $rank';
  }

  @override
  String get economyEquipped => 'Equipado';

  @override
  String get economyEveryChestPays => 'Todo baú dá alguma coisa.';

  @override
  String get economyEverySpinPays => 'Todo giro dá alguma coisa.';

  @override
  String economyFallbackCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Paga $countString moedas se você tiver todos';
  }

  @override
  String economyFinishDay7Chest(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Chegue ao dia 7 para um baú de +$minimumString a +$maximumString';
  }

  @override
  String get economyFinishStreakWeek => 'Complete uma semana de sequência.';

  @override
  String economyFirstDownloadsFree(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Primeiros $countString grátis';
  }

  @override
  String get economyFirstUpload => 'Primeiro envio';

  @override
  String get economyFreeDailySpin => 'Giro diário grátis';

  @override
  String economyFreeDownloadsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString grátis restantes';
  }

  @override
  String get economyFreeSpin => 'Giro grátis';

  @override
  String economyFreeSpinReady(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '. $countString giros pagos restantes hoje.',
      one: '. 1 giro pago restante hoje.',
      zero: '',
    );
    return 'Giro grátis pronto$_temp0';
  }

  @override
  String get economyFreezeAdded => 'Congelamento de sequência adicionado.';

  @override
  String economyFreezeAlreadyAtLimit(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString congelamentos',
      one: '1 congelamento',
      zero: '$countString congelamentos',
    );
    return 'Você já tem $_temp0.';
  }

  @override
  String economyFreezeBalanceAfter(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Saldo depois: $balanceString';
  }

  @override
  String economyFreezeBuyConfirm(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Comprar um congelamento de sequência por $costString moedas?';
  }

  @override
  String get economyFreezeBuyFailed => 'Não foi possível comprar um congelamento. Tente novamente.';

  @override
  String economyFreezeCount(int held, int total) {
    final intl.NumberFormat heldNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String heldString = heldNumberFormat.format(held);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$heldString de $totalString';
  }

  @override
  String get economyFreezeDescription => 'Salva sua sequência se você perder um dia. É aplicado automaticamente.';

  @override
  String get economyFreezeFull => 'Cheio';

  @override
  String economyFreezeGetOne(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Pegar um · $costString';
  }

  @override
  String get economyFreezeHeld => 'Congelamento guardado';

  @override
  String economyFreezeNeedCoins(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Você precisa de $costString moedas.';
  }

  @override
  String get economyFreezeSlotEmpty => 'Espaço de congelamento vazio';

  @override
  String get economyFreezeUnavailable =>
      'O congelamento de sequência não está disponível agora. Tente novamente mais tarde.';

  @override
  String get economyFreshLeaderboardDetails =>
      'O ranking usa o XP semanal, que reinicia toda segunda-feira às 00:00 UTC. Seu XP total, sua posição e os itens visuais conquistados permanecem.';

  @override
  String get economyFreshLeaderboardWeekly => 'Um ranking novo toda semana';

  @override
  String get economyGetCoins => 'Obter moedas';

  @override
  String economyGetCoinsChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Obter moedas. O baú custa $priceString moedas';
  }

  @override
  String economyGetCoinsForSpin(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Obter moedas. Um giro custa $priceString moedas';
  }

  @override
  String get economyGetFreezeNextTime => 'Pegue um congelamento para a próxima vez';

  @override
  String get economyGetPro => 'Assinar o Pro';

  @override
  String get economyGiftPass => 'Presentear um passe';

  @override
  String economyGiftPassInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Presenteie um amigo com 24 horas de conteúdo Pro por $amountString moedas. Abra o perfil dele e toque em Presentear passe de 24 h.';
  }

  @override
  String get economyGotIt => 'Entendi';

  @override
  String economyHighestRankReached(String rank) {
    return 'Maior nível alcançado: $rank';
  }

  @override
  String get economyHighestRankReachedShort => 'Maior nível alcançado';

  @override
  String get economyHomeScreen => 'Tela inicial';

  @override
  String get economyInviteFriend => 'Convidar um amigo';

  @override
  String get economyJackpotAddedToBalance => 'Prêmio máximo. Adicionado ao seu saldo';

  @override
  String get economyKeepStreakToday => 'Abra o Prism hoje para manter sua sequência.';

  @override
  String get economyLastWeek => 'Semana passada';

  @override
  String economyLeaderboardEntrySemantics(int position, String name, String isMe, int xp, String hasRank, String rank) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(isMe, {'true': ', você', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(hasRank, {'true': ', nível vitalício $rank', 'other': ''});
    return '$positionString, $name$_temp0, $xpString XP esta semana$_temp1';
  }

  @override
  String get economyLeaderboardFollowTip => 'Sua pontuação está incluída. Siga criadores para comparar o XP semanal.';

  @override
  String get economyLeaderboardFollowToSee => 'Siga criadores para vê-los aqui.';

  @override
  String get economyLeaderboardFollowing => 'Seguindo';

  @override
  String get economyLeaderboardFriendsCaption => 'Você e as pessoas que você segue · puxe para atualizar';

  @override
  String get economyLeaderboardFriendsDetails =>
      'Inclui sua pontuação e até as primeiras 90 contas que você segue. Contas excluídas ficam de fora; não há idade mínima de conta. As pontuações carregam quando você abre esta aba pela primeira vez. Puxe para atualizar. Sua pontuação reflete seu XP sincronizado mais recente.';

  @override
  String get economyLeaderboardGlobal => 'Global';

  @override
  String get economyLeaderboardGlobalCaption => 'Top 50 · atualizado a cada cerca de 3 horas';

  @override
  String get economyLeaderboardGlobalDetails =>
      'Mostra até 50 contas por XP semanal. As contas precisam ter pelo menos 7 dias; contas excluídas ficam de fora. O instantâneo é atualizado a cada cerca de 3 horas, então o XP novo pode demorar a aparecer. Puxar para atualizar carrega o instantâneo mais recente.';

  @override
  String get economyLeaderboardHowScoringWorks => 'Como funciona a pontuação do ranking';

  @override
  String get economyLeaderboardLoadFailed => 'Não foi possível carregar o ranking';

  @override
  String get economyLeaderboardNoRankings => 'Nenhuma classificação ainda';

  @override
  String get economyLeaderboardOffline => 'Se você estiver offline, podem ser exibidas pontuações salvas.';

  @override
  String get economyLeaderboardRankedByXp => 'Classificado pelo XP ganho nesta semana';

  @override
  String economyLeaderboardReset(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '${daysString}d',
      one: '1d',
      zero: '${daysString}d',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '${hoursString}h',
      one: '1h',
      zero: '${hoursString}h',
    );
    return 'Reinicia segunda-feira às 00:00 UTC · $_temp0 $_temp1 restantes';
  }

  @override
  String get economyLeaderboardScoringIntro =>
      'As posições usam o XP ganho nesta semana. Os rótulos de nível, como Prata, usam o XP vitalício. O XP semanal é zerado na segunda-feira às 00:00 UTC; o XP vitalício e o nível permanecem.';

  @override
  String get economyLeaderboardTitle => 'Ranking';

  @override
  String get economyLifetimePermanentDetails =>
      'O XP vitalício define seu nível e nunca é zerado. Os itens de nível chegam automaticamente ao seu inventário, não custam moedas e ficam com você. Escolha quando equipá-los na Loja.';

  @override
  String get economyLifetimePermanentRewards => 'Progresso vitalício, recompensas permanentes';

  @override
  String economyLifetimeXp(String xp) {
    return '$xp XP vitalício';
  }

  @override
  String get economyLifetimeXpNeverResets => 'O XP vitalício nunca é zerado.';

  @override
  String get economyLoadingVideo => 'Carregando um vídeo';

  @override
  String get economyLockScreen => 'Tela de bloqueio';

  @override
  String get economyMystery => 'Mistério';

  @override
  String get economyMysteryCosmetic => 'Item cosmético misterioso';

  @override
  String get economyNewBadge => 'Novo selo';

  @override
  String economyNewCosmetic(String kind, String name) {
    return 'Novo $kind: $name';
  }

  @override
  String get economyNewUnknownCosmetic => 'Novo item cosmético';

  @override
  String get economyNextDropMonday => 'O próximo Drop chega na segunda-feira.';

  @override
  String economyNextReward(String reward) {
    return 'Próxima recompensa: $reward';
  }

  @override
  String get economyNice => 'Legal';

  @override
  String get economyNoDropNow => 'Nenhum Drop agora';

  @override
  String get economyNoSpinsLeft => 'Nenhum giro restante hoje.';

  @override
  String get economyNotEnoughCoins => 'Moedas insuficientes';

  @override
  String get economyNotNow => 'Agora não';

  @override
  String economyOddsTierSemantics(String tier, String odds) {
    return '$tier, $odds';
  }

  @override
  String get economyOddsTitle => 'As chances';

  @override
  String get economyOnceADay => 'Uma vez por dia';

  @override
  String get economyOpen => 'Abrir';

  @override
  String economyOpenChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Abrir o baú, $priceString moedas';
  }

  @override
  String get economyOpenChestFree => 'Abrir o baú, grátis';

  @override
  String get economyOpenChestLoading => 'Abrir o baú. Carregando';

  @override
  String get economyOpenDaily => 'Abra o Prism todos os dias.';

  @override
  String economyOpenDailyPro(String multiplier) {
    return 'Abra o Prism todos os dias. O Pro ganha x$multiplier.';
  }

  @override
  String get economyOpenFree => 'Abrir grátis';

  @override
  String get economyOpenShop => 'Abrir a Loja';

  @override
  String get economyOpening => 'Abrindo';

  @override
  String get economyOwned => 'Adquirido';

  @override
  String get economyPremiumCollection => 'Coleção premium';

  @override
  String economyPriceCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString moedas';
  }

  @override
  String economyPriceCoinsForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$amountString moedas por $hoursString horas';
  }

  @override
  String economyPriceCoinsPerWall(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString por papel de parede';
  }

  @override
  String economyPriceCoinsPerWallSemantics(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString moedas por papel de parede';
  }

  @override
  String economyPriceCoinsWithNote(int amount, String note, String hasNote) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(hasNote, {'true': ', $note', 'other': ''});
    return '$amountString moedas$_temp0';
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

    return 'a partir de $amountString';
  }

  @override
  String economyPriceFromCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'a partir de $amountString moedas';
  }

  @override
  String get economyPrizeWheel => 'Roleta de prêmios';

  @override
  String get economyPro => 'Pro';

  @override
  String get economyProDailyFreeSpin => 'Membros Pro ganham um giro grátis todo dia';

  @override
  String get economyProDownloadsFilters => 'Com o Pro, baixar e usar filtros é grátis.';

  @override
  String get economyProPrice => 'Preço do Pro';

  @override
  String get economyProWallpaper => 'Papel de parede Pro';

  @override
  String get economyQuestBrowse10 => 'Veja 10 papéis de parede';

  @override
  String get economyQuestColourSearch => 'Pesquise por cor';

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
      other: 'Missão cumprida: +$xpString XP',
      zero: 'Missão cumprida',
    );
    String _temp3 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Missão cumprida: +$coinsString moedas$_temp0',
      one: 'Missão cumprida: +1 moeda$_temp1',
      zero: '$_temp2',
    );
    return '$_temp3';
  }

  @override
  String get economyQuestDownload2 => 'Baixe 2 papéis de parede';

  @override
  String get economyQuestFav3 => 'Favorite 3 papéis de parede';

  @override
  String economyQuestNewIn(String time) {
    return 'Novo em $time';
  }

  @override
  String get economyQuestProSpin => 'Use seu giro grátis';

  @override
  String get economyQuestSetWall => 'Defina ou salve um papel de parede';

  @override
  String get economyQuestShareWall => 'Compartilhe um papel de parede';

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

    String _temp0 = intl.Intl.selectLogic(isDone, {'true': 'concluída', 'other': '$progressString de $targetString'});
    String _temp1 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString moedas',
      one: '1 moeda',
      zero: '$coinsString moedas',
    );
    String _temp2 = intl.Intl.selectLogic(hasCoins, {'true': '. Rende $_temp1', 'other': ''});
    String _temp3 = intl.Intl.selectLogic(hasXp, {'true': '. Rende $xpString XP', 'other': ''});
    String _temp4 = intl.Intl.selectLogic(hasEnds, {'true': ', termina em $endsIn', 'other': ''});
    String _temp5 = intl.Intl.selectLogic(isWeekly, {'true': '. Missão semanal$_temp4', 'other': ''});
    return '$title, $_temp0$_temp2$_temp3$_temp5';
  }

  @override
  String get economyQuestTrending => 'Veja o que está em alta';

  @override
  String get economyQuestUnknown => 'Conclua uma missão';

  @override
  String get economyQuestWatchAd => 'Assista a um vídeo';

  @override
  String get economyQuestWeeklySet5 => 'Salve ou defina 5 papéis de parede';

  @override
  String get economyQuestWotd => 'Abra o Papel de Parede do Dia de hoje';

  @override
  String get economyRankBronze => 'Bronze';

  @override
  String get economyRankGold => 'Ouro';

  @override
  String get economyRankGrowsWithXp => 'Seu nível cresce com o XP vitalício.';

  @override
  String economyRankInfoSemantics(String rank) {
    return 'Nível $rank. Como funcionam o XP e as recompensas de nível';
  }

  @override
  String get economyRankPrism => 'Prism';

  @override
  String economyRankProgressSemantics(String rank) {
    return 'Progresso do nível $rank';
  }

  @override
  String economyRankRewardAtRank(String rank, String xp) {
    return 'Seu automaticamente no nível $rank · $xp XP';
  }

  @override
  String economyRankRewardMilestone(String rank, String xp, String reward) {
    return '$rank · $xp XP\n$reward';
  }

  @override
  String get economyRankRewardSyncing => 'Sincronizando com seu inventário. É seu para sempre.';

  @override
  String get economyRankRewardsHelp => 'Como funcionam o XP e as recompensas de nível';

  @override
  String get economyRankSilver => 'Prata';

  @override
  String economyRankTag(String rank) {
    return 'Nível $rank';
  }

  @override
  String get economyRankUnknown => 'Nível';

  @override
  String economyReferralBothGet(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString moedas',
      one: '1 moeda',
      zero: '$coinsString moedas',
    );
    return 'Vocês dois ganham $_temp0';
  }

  @override
  String get economyRestore => 'Restaurar';

  @override
  String economyRestoreStreak(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Restaurar sua sequência de $daysString dias · $coinsString moedas';
  }

  @override
  String economyRewardEarned(String reward) {
    return '$reward conquistado';
  }

  @override
  String get economyRewardsTitle => 'Recompensas';

  @override
  String get economySameActivitySameXp => 'A mesma atividade rende o mesmo XP';

  @override
  String get economySameActivityXpDetails =>
      'Anúncios, giros Pro, bônus diários Pro, indicações e reembolsos não rendem XP. Os multiplicadores Pro e de moedas não aumentam o XP. As recompensas em moedas são separadas.';

  @override
  String get economySeeAll => 'Ver tudo';

  @override
  String get economySeeBadges => 'Ver selos';

  @override
  String get economySeeItInShop => 'Ver na Loja';

  @override
  String get economySeeOdds => 'Ver as chances';

  @override
  String get economySeePro => 'Ver o Pro';

  @override
  String get economySeeRewards => 'Ver recompensas';

  @override
  String get economyShareWallpaper => 'Compartilhar um papel de parede';

  @override
  String get economyShopAlreadyOwned => 'Você já tem este item';

  @override
  String get economyShopAurora => 'Aurora';

  @override
  String economyShopBuyFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Comprar por $priceString';
  }

  @override
  String get economyShopChangeIconFailed => 'Não foi possível trocar o ícone';

  @override
  String economyShopCoinsShort(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Você precisa de mais $countString moedas.';
  }

  @override
  String get economyShopCottonBlue => 'Azul algodão';

  @override
  String get economyShopDeepOcean => 'Oceano profundo';

  @override
  String get economyShopDefaultIcon => 'Padrão';

  @override
  String get economyShopEarnXp => 'Ganhar XP';

  @override
  String economyShopEarnedAtLifetimeXp(String rank) {
    return 'Conquistado no nível $rank com XP vitalício.';
  }

  @override
  String get economyShopEmber => 'Brasa';

  @override
  String get economyShopEquip => 'Equipar';

  @override
  String get economyShopEquipFailed => 'Não foi possível alterar. Tente novamente.';

  @override
  String economyShopEquipped(String name) {
    return '$name equipado';
  }

  @override
  String get economyShopFounders => 'Fundadores';

  @override
  String get economyShopFrames => 'Molduras';

  @override
  String get economyShopGlass => 'Vidro';

  @override
  String get economyShopGlowPreviewName => 'Glint';

  @override
  String get economyShopGlows => 'Brilhos';

  @override
  String get economyShopGold => 'Ouro';

  @override
  String economyShopIconEnabled(String name) {
    return 'Ícone $name ativado';
  }

  @override
  String get economyShopIcons => 'Ícones';

  @override
  String economyShopItemSemantics(String name, String status) {
    return '$name, $status';
  }

  @override
  String get economyShopJungle => 'Selva';

  @override
  String get economyShopMono => 'Mono';

  @override
  String get economyShopNeedMoreCoins => 'Você precisa de mais moedas para isso';

  @override
  String get economyShopNoir => 'Noir';

  @override
  String get economyShopOcean => 'Oceano';

  @override
  String get economyShopOlive => 'Oliva';

  @override
  String get economyShopPepper => 'Pimenta';

  @override
  String get economyShopPrism => 'Prism';

  @override
  String get economyShopProOnly => 'Este item é para membros Pro';

  @override
  String get economyShopPurchaseFailed => 'Não foi possível comprar. Tente novamente.';

  @override
  String economyShopPurchased(String name) {
    return '$name é seu';
  }

  @override
  String economyShopRankLocked(String rank) {
    return 'Alcance o nível $rank para desbloquear';
  }

  @override
  String get economyShopRankReachedSyncing => 'Nível alcançado. Sua recompensa está sincronizando.';

  @override
  String economyShopRankRewardSynced(String name) {
    return 'Recompensa do nível $name sincronizada';
  }

  @override
  String economyShopReachRankToBuy(String rank) {
    return 'Alcance o nível $rank para comprar.';
  }

  @override
  String get economyShopRing => 'Anel';

  @override
  String get economyShopRose => 'Rosa';

  @override
  String economyShopSaleUntil(String date) {
    return 'Edição limitada. Em promoção até $date.';
  }

  @override
  String get economyShopSky => 'Céu';

  @override
  String get economyShopSoldOut => 'Este item limitado esgotou';

  @override
  String get economyShopSteel => 'Aço';

  @override
  String get economyShopSunset => 'Pôr do sol';

  @override
  String get economyShopSyncReward => 'Sincronizar recompensa';

  @override
  String get economyShopThemes => 'Temas';

  @override
  String get economyShopTitle => 'Loja';

  @override
  String get economyShopUnequip => 'Desequipar';

  @override
  String economyShopUnequipped(String name) {
    return '$name removido';
  }

  @override
  String get economyShopUseIcon => 'Usar ícone';

  @override
  String get economyShopUseTheme => 'Usar tema';

  @override
  String get economyShopWearingNeedsPro => 'Usar isto exige o Pro.';

  @override
  String get economyShowMore => 'Mostrar mais';

  @override
  String get economySignIn => 'Entrar';

  @override
  String get economySoldOut => 'Esgotado';

  @override
  String get economySoon => 'em breve';

  @override
  String economySpendItemSemantics(String label, String price) {
    return '$label, $price';
  }

  @override
  String get economySpin => 'GIRAR';

  @override
  String get economySpinAgain => 'Girar de novo';

  @override
  String get economySpinAgainFree => 'Girar de novo, giro grátis';

  @override
  String economySpinAgainPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Girar de novo, $priceString moedas';
  }

  @override
  String economySpinCardCaption(int price, int maximum) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '$priceString moedas por giro. Ganhe até $maximumString moedas ou um item cosmético';
  }

  @override
  String economySpinCosts(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Um giro custa $priceString moedas';
  }

  @override
  String get economySpinFree => 'Girar, giro grátis';

  @override
  String economySpinPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Girar, $priceString moedas';
  }

  @override
  String get economySpinPriceChanged => 'O preço mudou. Confira e gire de novo.';

  @override
  String economySpinShortBalanceMessage(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Um giro custa $priceString moedas. Você tem $balanceString. Assista a um vídeo para ganhar mais.';
  }

  @override
  String get economySpinTheWheel => 'Girar a roleta';

  @override
  String economySpinWheelCardSemantics(String caption) {
    return 'Girar a roleta. $caption';
  }

  @override
  String get economySpinning => 'Girando';

  @override
  String economySpinsLeftToday(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString giros restantes',
      one: '1 giro restante',
      zero: '$countString giros restantes',
    );
    return '$_temp0 hoje.';
  }

  @override
  String get economyStreak => 'SEQUÊNCIA';

  @override
  String economyStreakChestReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString baú do dia 7';
  }

  @override
  String get economyStreakCollection => 'Coleção da sequência';

  @override
  String get economyStreakCollectionDescription =>
      'Desbloqueie papéis de parede mantendo sua sequência ou usando moedas.';

  @override
  String economyStreakCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sequência de $countString dias',
      one: 'Sequência de 1 dia',
      zero: 'Sequência de $countString dias',
    );
    return '$_temp0';
  }

  @override
  String economyStreakCycleSemantics(int day, String showReward, int reward, String state) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(showReward, {'true': ', mais $rewardString moedas', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(state, {'done': ', concluído', 'today': ', hoje', 'other': ''});
    return 'Dia $dayString$_temp0$_temp1';
  }

  @override
  String economyStreakDailyReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString hoje';
  }

  @override
  String economyStreakDayNumber(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Dia $dayString da sua sequência';
  }

  @override
  String get economyStreakFreeze => 'Congelamento de sequência';

  @override
  String economyStreakFreezeSaved(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Um congelamento salvou sua sequência de $daysString dias';
  }

  @override
  String economyStreakFreezesLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString congelamentos restantes',
      one: '1 congelamento restante',
      zero: '$countString congelamentos restantes',
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
  String get economyStreakRescueCooldown => 'Você pode restaurar uma sequência a cada 30 dias.';

  @override
  String get economyStreakRescueExpired => 'As 48 horas para restaurar esta sequência acabaram.';

  @override
  String get economyStreakRescueFailed => 'Não foi possível restaurar sua sequência. Tente novamente.';

  @override
  String get economyStreakRescueUnavailable => 'Esta sequência não pode ser restaurada agora.';

  @override
  String get economyStreakReset => 'Sua sequência foi reiniciada';

  @override
  String economyStreakResetMessage(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Sua sequência era de $daysString dias. Recomece hoje e ganhe +$coinsString moedas.';
  }

  @override
  String economyStreakRestoreShort(int balance, int cost) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Seu saldo é $balanceString. Você precisa de $costString.';
  }

  @override
  String get economyStreakRestored => 'Sua sequência está de volta';

  @override
  String economyStreakRestoredCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Sua sequência voltou para $countString dias.';
  }

  @override
  String get economyToday => 'Hoje';

  @override
  String get economyUnknownCosmetic => 'Cosmético';

  @override
  String economyUntil(String date) {
    return 'Até $date';
  }

  @override
  String economyUpToCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Até +$countString';
  }

  @override
  String get economyUpgradeToPro => 'Assinar Pro';

  @override
  String economyUseReward(String reward) {
    return 'Usar $reward';
  }

  @override
  String get economyUseYourCoins => 'Use suas moedas';

  @override
  String get economyWatchAd => 'Assistir ao anúncio';

  @override
  String get economyWatchVideo => 'Assista a um vídeo';

  @override
  String economyWatchVideoRewardAdsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString anúncios',
      one: '1 anúncio',
      zero: '$countString anúncios',
    );
    return 'Assista a um vídeo · restam $_temp0 hoje';
  }

  @override
  String economyWatchVideoRewardCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Assista a um vídeo (+$coinsString)';
  }

  @override
  String get economyWeekComplete => 'Semana completa!';

  @override
  String get economyWeekly => 'SEMANAL';

  @override
  String get economyWeeklyDraw => 'Sorteio semanal';

  @override
  String get economyWeeklyDrop => 'Drop semanal';

  @override
  String economyWeeklyEndsIn(String time) {
    return 'SEMANAL · $time';
  }

  @override
  String get economyWeeklyXpFriendsEveryone => 'XP semanal, amigos e todos';

  @override
  String economyWonCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString moedas',
      one: '1 moeda',
      zero: '$coinsString moedas',
    );
    return 'Você ganhou $_temp0';
  }

  @override
  String economyWonCosmetic(String kind, String name) {
    return 'Você ganhou um novo $kind: $name';
  }

  @override
  String get economyWonUnknownCosmetic => 'Você ganhou um cosmético';

  @override
  String economyWonXp(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Você ganhou $xpString XP';
  }

  @override
  String economyXp(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '${countString}XP';
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

    return 'As sequências diárias rendem $dailyStreakString XP, além de $streakWeekString XP por completar um ciclo de sete dias. Baús de missões rendem $questChestString XP. Seu primeiro envio válido rende $uploadString XP; completar o perfil rende $profileString XP. Cada missão diária concede $dailyQuestString XP; a missão semanal concede $weeklyQuestString XP. Alguns selos e marcos de criador também rendem XP.';
  }

  @override
  String economyXpAwarded(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '+${xpString}XP';
  }

  @override
  String get economyXpRanksRewards => 'XP, classificações e recompensas';

  @override
  String economyXpToRank(String xp, String rank) {
    return '$xp XP para $rank';
  }

  @override
  String get economyXpUnit => 'XP';

  @override
  String get economyYesterday => 'Ontem';

  @override
  String economyYouHaveCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Você tem $countString moedas';
  }

  @override
  String get economyYourXp => 'SEU XP';

  @override
  String get errorGeneric => 'Algo deu errado. Por favor, tente novamente.';

  @override
  String get errorNetwork => 'Verifique sua conexão e tente novamente.';

  @override
  String get navigationBackOnline => 'De volta on-line';

  @override
  String get navigationNoInternetConnection => 'Sem conexão com a internet';

  @override
  String get navigationScrollToTop => 'Role para cima';

  @override
  String get notifActivateToCollapse => 'Ative para recolher.';

  @override
  String get notifActivateToExpand => 'Ative para expandir.';

  @override
  String get notifChannelDownloads => 'Downloads';

  @override
  String get notifChannelDownloadsDescription =>
      'Receba notificações sobre o andamento do download de papéis de parede.';

  @override
  String get notifChannelDraw => 'Sorteio do Prism';

  @override
  String get notifChannelDrawDescription => 'Sorteios, resultados e prêmios.';

  @override
  String get notifChannelDrops => 'Drops semanais';

  @override
  String get notifChannelDropsDescription => 'Quando um novo Drop estiver ativo e antes de terminar.';

  @override
  String get notifChannelFollowers => 'Seguidores';

  @override
  String get notifChannelFollowersDescription => 'Receba notificações quando ganhar novos seguidores.';

  @override
  String get notifChannelGifts => 'Presentes';

  @override
  String get notifChannelGiftsDescription => 'Um amigo lhe enviou um passe Pro.';

  @override
  String get notifChannelGroup => 'Notificações';

  @override
  String get notifChannelGroupDescription => 'Todas as notificações do Prism';

  @override
  String get notifChannelModeration => 'Moderação';

  @override
  String get notifChannelModerationDescription => 'Denúncias e solicitações de revisão para administradores do Prism.';

  @override
  String get notifChannelPosts => 'Postagens';

  @override
  String get notifChannelPostsDescription => 'Receba notificações de postagens de artistas que você segue.';

  @override
  String get notifChannelRecommendations => 'Recomendações';

  @override
  String get notifChannelRecommendationsDescription => 'Receba notificações de recomendações do Prism.';

  @override
  String get notifChannelStreaks => 'Lembretes de sequência';

  @override
  String get notifChannelStreaksDescription => 'Lembrete às 20h para manter sua sequência de acessos ativa.';

  @override
  String get notifChannelWotd => 'Papel de parede do dia';

  @override
  String get notifChannelWotdDescription => 'Notificação diária de papel de parede em destaque às 9h.';

  @override
  String get notifClearDeviceMessage => 'Isso os remove deste dispositivo.';

  @override
  String get notifClearInbox => 'Limpar caixa de entrada';

  @override
  String get notifClearInboxAction => 'Limpar caixa de entrada';

  @override
  String notifClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Limpar $countString notificações?';
  }

  @override
  String get notifClearOneTitle => 'Limpar esta notificação?';

  @override
  String get notifCollapsed => 'Recolhido';

  @override
  String notifDownloadedTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede baixados.',
      one: '1 papel de parede baixado.',
      zero: '$countString papéis de parede baixados.',
    );
    return '$_temp0';
  }

  @override
  String get notifDownloadingWallpaper => 'Baixando papel de parede';

  @override
  String get notifEmptyBody => 'Novos seguidores, aprovações e o papel de parede do dia aparecem aqui.';

  @override
  String get notifEmptyTitle => 'Sem notificações';

  @override
  String get notifExpanded => 'Expandido';

  @override
  String get notifGenericTitle => 'Notificação';

  @override
  String notifGroupAndMore(String message, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString itens.',
      one: '1 item.',
      zero: '$otherCountString itens.',
    );
    return '$message e mais $_temp0';
  }

  @override
  String notifGroupApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'aprovações',
      one: 'aprovação',
      zero: 'aprovações',
    );
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
      other: '$otherCountString criadores.',
      one: '1 criador.',
      zero: '$otherCountString criadores.',
    );
    return 'De $name e mais $_temp0';
  }

  @override
  String notifGroupDailyPicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'escolhas do dia',
      one: 'escolha do dia',
      zero: 'escolhas do dia',
    );
    return '$_temp0';
  }

  @override
  String get notifGroupDayRows => 'Cada linha corresponde a um dia; os horários aparecem à direita.';

  @override
  String notifGroupFollowerSummary(String name, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString pessoas começaram',
      one: 'uma pessoa começou',
      zero: '$otherCountString pessoas começaram',
    );
    return '$name e mais $_temp0 a seguir você.';
  }

  @override
  String notifGroupFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'novos seguidores',
      one: 'novo seguidor',
      zero: 'novos seguidores',
    );
    return '$_temp0';
  }

  @override
  String get notifGroupHide => 'Esconder';

  @override
  String notifGroupNotifications(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'notificações',
      one: 'notificação',
      zero: 'notificações',
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
      other: '$countString notificações removidas',
      one: '1 notificação removida',
      zero: '$countString notificações removidas',
    );
    return '$_temp0';
  }

  @override
  String notifGroupSameMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'A mesma mensagem foi enviada $countString vezes. Compare as datas e os horários para saber quando.';
  }

  @override
  String notifGroupSemantics(String title, String summary, String expandedState, String unreadStatus, String action) {
    return '$title. $summary. $expandedState. $unreadStatus $action';
  }

  @override
  String get notifGroupSeveralCreators => 'Vários criadores. Expanda para ver cada papel de parede.';

  @override
  String get notifGroupShowAll => 'Mostrar tudo';

  @override
  String notifGroupSummaryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString notificações neste grupo.',
      one: '1 notificação neste grupo.',
      zero: '$countString notificações neste grupo.',
    );
    return '$_temp0';
  }

  @override
  String notifGroupWallLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'papéis de parede publicados',
      one: 'papel de parede publicado',
      zero: 'papéis de parede publicados',
    );
    return '$_temp0';
  }

  @override
  String get notifHasUnread => 'Há notificações não lidas.';

  @override
  String get notifInboxCleared => 'Caixa de entrada limpa';

  @override
  String get notifLoadErrorTitle => 'Não foi possível carregar suas notificações';

  @override
  String get notifMarkAllRead => 'Marcar tudo como lido';

  @override
  String get notifOfflineSaved =>
      'Não foi possível carregar novas notificações. O que você vê abaixo está salvo neste dispositivo.';

  @override
  String get notifOpenSettings => 'Abrir configurações';

  @override
  String get notifPermissionOff => 'As notificações estão desativadas. Ative-as primeiro nas configurações do sistema.';

  @override
  String get notifPermissionOffForApp => 'As notificações estão desativadas para o Prism.';

  @override
  String get notifPreferences => 'Preferências de notificação';

  @override
  String get notifPushDrawWinnerBody => 'Um mês de Pro e a moldura Prism são seus.';

  @override
  String get notifPushDrawWinnerTitle => 'Você ganhou o sorteio do Prism';

  @override
  String notifPushDropLastCallBody(String dropTitle, int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString horas',
      one: '1 hora',
      zero: '$hoursString horas',
    );
    return '$dropTitle termina em $_temp0. Depois, estes papéis de parede ficarão indisponíveis por um mês.';
  }

  @override
  String get notifPushDropLastCallTitle => 'Última chamada no Drop desta semana';

  @override
  String notifPushDropLiveBody(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede, só esta semana. Confira antes que saiam do ar.',
      one: '1 papel de parede, só esta semana. Confira antes que saia do ar.',
      zero: '$countString papéis de parede, só esta semana. Confira antes que saiam do ar.',
    );
    return '$_temp0';
  }

  @override
  String get notifPushDropLiveTitle => 'Um novo Drop está disponível';

  @override
  String notifPushFollowDigestTitleOne(String artistName) {
    return '$artistName publicou um novo papel de parede';
  }

  @override
  String notifPushFollowDigestTitleSolo(String artistName, int wallCount) {
    return '$artistName publicou $wallCount papéis de parede novos';
  }

  @override
  String notifPushFollowDigestTitlePair(String artistName, String secondArtistName, int wallCount) {
    return '$artistName e $secondArtistName publicaram $wallCount papéis de parede novos';
  }

  @override
  String notifPushFollowDigestTitleGroup(String artistName, int otherCount, int wallCount) {
    return '$artistName e mais $otherCount publicaram $wallCount papéis de parede novos';
  }

  @override
  String get notifPushFollowDigestBodyUntitled => 'Toque para ver todos.';

  @override
  String get notifPushGiftReceivedBody => 'As coleções e os papéis de parede premium ficarão disponíveis por 24 horas.';

  @override
  String notifPushGiftReceivedTitle(String senderName) {
    return '$senderName enviou a você um passe Pro de 24 horas';
  }

  @override
  String notifPushNewContentReportBody(String contentType, String reason, String targetId) {
    return '$contentType · $reason · doc. $targetId';
  }

  @override
  String get notifPushNewContentReportTitle => 'Nova denúncia de conteúdo';

  @override
  String notifPushNewFollowerBody(String followerName) {
    return '$followerName agora está seguindo você.';
  }

  @override
  String get notifPushNewFollowerTitle => 'Você tem um novo seguidor! 🎉';

  @override
  String notifPushReportReviewBody(String contentType, String reason) {
    return '$contentType · $reason · aberto por mais de 12 horas';
  }

  @override
  String get notifPushReportReviewTitle => 'Denúncia aguardando análise';

  @override
  String get notifPushStreakReminderBody => 'Abra o Prism agora para manter sua sequência de acessos ativa 🔥';

  @override
  String get notifPushStreakReminderTitle => 'Sua sequência está prestes a acabar!';

  @override
  String notifPushWallApprovedAdminBody(String wallTitle, String artistName) {
    return '\"$wallTitle\" de $artistName já está no ar.';
  }

  @override
  String get notifPushWallApprovedAdminTitle => 'Papel de parede aprovado ✅';

  @override
  String notifPushWallApprovedArtistBody(String wallTitle) {
    return '\"$wallTitle\" foi aprovado e agora está visível para todos.';
  }

  @override
  String get notifPushWallApprovedArtistBodyUntitled =>
      'Seu papel de parede foi aprovado e agora está visível para todos.';

  @override
  String get notifPushWallApprovedArtistTitle => 'Seu papel de parede está ativo! 🎉';

  @override
  String notifPushWallLiveFollowersBody(String wallTitle) {
    return '\"$wallTitle\" foi publicado no Prism.';
  }

  @override
  String notifPushWallLiveFollowersTitle(String artistName) {
    return 'Novo papel de parede de $artistName';
  }

  @override
  String notifPushWallSubmittedBody(String artistName, String artistEmail) {
    return 'Nova postagem de $artistName ($artistEmail) está em análise.';
  }

  @override
  String get notifPushWallSubmittedTitle => 'Novo papel de parede premium para revisão! 🎉';

  @override
  String get notifPushWinBack14Body => 'Venha ver o que os criadores adicionaram nesta quinzena.';

  @override
  String get notifPushWinBack14Title => 'Novos papéis de parede estão esperando';

  @override
  String get notifPushWinBack30Body => 'Faça um papel de parede que se pareça com você.';

  @override
  String get notifPushWinBack30Title => 'Novos estilos de IA para experimentar';

  @override
  String get notifPushWinBack60Body => 'Seu próximo papel de parede favorito está a um toque de distância.';

  @override
  String get notifPushWinBack60Title => 'O Prism sente sua falta';

  @override
  String get notifPushWinBack7Body => 'Novos papéis de parede chegaram enquanto você estava fora.';

  @override
  String get notifPushWinBack7Title => 'Seu feed tem novos papéis de parede';

  @override
  String notifPushWotdAudienceBody(String wallTitle) {
    return '$wallTitle';
  }

  @override
  String get notifPushWotdAudienceBodyUntitled => 'Abra o Prism para ver o papel de parede do dia.';

  @override
  String get notifPushWotdAudienceTitle => 'O papel de parede do dia chegou';

  @override
  String get notifPushWotdCreatorBody =>
      'O Prism escolheu seu papel de parede para todos hoje. Obrigado por compartilhá-lo.';

  @override
  String get notifPushWotdCreatorTitle => 'Seu papel de parede foi escolhido para hoje';

  @override
  String get notifRead => 'Já lida';

  @override
  String get notifRemoved => 'Notificação removida';

  @override
  String get notifReportUnknownContentType => 'conteúdo';

  @override
  String notifSemanticsRow(String message, String time, String readStatus) {
    return '$message. $time. $readStatus';
  }

  @override
  String get notifSettingDrops => 'Drops semanais';

  @override
  String get notifSettingDropsDescription => 'Alertas quando um novo Drop está ativo e antes de terminar.';

  @override
  String get notifSettingFollowers => 'Seguidores';

  @override
  String get notifSettingFollowersDescription => 'Alertas quando alguém novo segue você.';

  @override
  String get notifSettingPosts => 'Postagens';

  @override
  String get notifSettingPostsDescription => 'Alertas quando os criadores que você segue compartilham novos trabalhos.';

  @override
  String get notifSettingRecommendations => 'Recomendações';

  @override
  String get notifSettingRecommendationsDescription => 'Dicas, notícias e opções de papéis de parede do Prism.';

  @override
  String get notifSettingStreaks => 'Lembretes de sequência';

  @override
  String get notifSettingStreaksDescription =>
      'Alerta por volta das 20h caso sua sequência de acessos esteja prestes a acabar.';

  @override
  String get notifSettingWotd => 'Papel de parede do dia';

  @override
  String get notifSettingWotdDescription => 'Um papel de parede escolhido todos os dias.';

  @override
  String get notifSignInToChange => 'Faça login para alterar esta configuração.';

  @override
  String get notifSignInToTurnOn => 'Faça login para ativar';

  @override
  String get notifTapToOpenPrism => 'Toque para abrir o Prism.';

  @override
  String get notifTitle => 'Notificações';

  @override
  String get notifToday => 'Hoje';

  @override
  String get notifUndo => 'Desfazer';

  @override
  String get notifUnread => 'Ainda não lida';

  @override
  String get notifYesterday => 'Ontem';

  @override
  String notifYesterdayAt(String time) {
    return 'Ontem, $time';
  }

  @override
  String get onboardingAiGenerateError => 'Algo deu errado.\nToque em Gerar para tentar novamente.';

  @override
  String get onboardingAiGeneratePrompt => 'Toque em Gerar para criar\nseu papel de parede exclusivo';

  @override
  String get onboardingAiGenerating => 'Criando seu papel de parede…';

  @override
  String get onboardingBrowseGuest => 'Navegue sem uma conta';

  @override
  String get onboardingCategoriesUnavailable => 'não foi possível carregar categorias, você pode pular esta etapa';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingContinueApple => 'Continuar com a Apple';

  @override
  String get onboardingContinueGoogle => 'Continuar com o Google';

  @override
  String onboardingContinueSelected(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Continuar ($countString selecionados)';
  }

  @override
  String get onboardingCouldNotLogOut => 'Não foi possível sair. Por favor, tente novamente.';

  @override
  String get onboardingCreatorsUnavailable => 'não foi possível carregar os criadores, você pode pular esta etapa';

  @override
  String get onboardingFirstAiWallpaper => 'seu primeiro papel de parede, gerado por IA';

  @override
  String get onboardingFirstWallpaperSaveFailed =>
      'Não foi possível salvar seu papel de parede. Tente novamente ou pule.';

  @override
  String get onboardingFirstWallpaperSavedPhotos => 'Salvo no app Fotos!';

  @override
  String get onboardingFirstWallpaperSet => 'Papel de parede definido!';

  @override
  String get onboardingFirstWallpaperSetFailed =>
      'Não foi possível definir seu papel de parede. Tente novamente ou pule.';

  @override
  String get onboardingFirstWallpaperSetHome => 'Papel de parede definido na tela inicial.';

  @override
  String get onboardingFirstWallpaperSetHomeLock => 'Papel de parede definido nas telas inicial e de bloqueio.';

  @override
  String get onboardingFirstWallpaperSetLock => 'Papel de parede definido na tela de bloqueio.';

  @override
  String get onboardingFollow => 'Seguir';

  @override
  String onboardingFollowCreatorMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'sugerimos que você siga estes $countString criadores';
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
      zero: '$countString seguidores',
    );
    return '$_temp0';
  }

  @override
  String get onboardingFollowing => 'Seguindo';

  @override
  String get onboardingGenerateFailure => 'algo deu errado – toque em gerar para tentar novamente';

  @override
  String get onboardingGenerateSuccess => 'ficou ótimo! abrindo seu papel de parede';

  @override
  String get onboardingGenerateWallpaper => 'gerar meu papel de parede';

  @override
  String get onboardingHeadlineCreators => 'Encontre seu pessoal';

  @override
  String get onboardingHeadlineCustomize => 'Deixe do seu jeito';

  @override
  String get onboardingHeadlineGenerate => 'Crie o seu\nprimeiro papel de parede';

  @override
  String get onboardingHeadlineInterests => 'Escolha sua vibração';

  @override
  String get onboardingLoadCategoriesFailed => 'Não foi possível carregar categorias.';

  @override
  String get onboardingLoadCreatorsFailed => 'Não foi possível carregar os criadores.';

  @override
  String get onboardingPro => 'Pro';

  @override
  String get onboardingProFree => '→ grátis para você';

  @override
  String get onboardingRecoveryCreatorsFailed =>
      'Não foi possível carregar os criadores. Verifique sua conexão e toque em Recarregar.';

  @override
  String get onboardingRecoveryFollowFailed => 'Não foi possível seguir estes criadores. Tente novamente.';

  @override
  String get onboardingRecoveryFollowFailedHelper =>
      'não foi possível seguir esses criadores. verifique sua conexão e tente novamente';

  @override
  String get onboardingRecoveryReload => 'Recarregar';

  @override
  String get onboardingRecoveryRetry => 'Tente novamente';

  @override
  String get onboardingRecoverySaveInterestsFailed => 'Não foi possível salvar suas escolhas. Tente novamente.';

  @override
  String get onboardingRecoverySaveInterestsFailedHelper =>
      'não foi possível salvar suas escolhas. verifique sua conexão e tente novamente';

  @override
  String get onboardingRecoverySessionExpired => 'Sua sessão expirou. Faça login novamente.';

  @override
  String get onboardingRecoverySessionExpiredHelper => 'sua sessão expirou. faça login novamente para continuar';

  @override
  String get onboardingRecoverySetupFailed => 'Não foi possível concluir a configuração. Tente novamente.';

  @override
  String get onboardingRecoverySetupFailedHelper =>
      'não foi possível concluir a configuração. verifique sua conexão e tente novamente';

  @override
  String get onboardingRecoverySignIn => 'Faça login novamente';

  @override
  String get onboardingReloadLower => 'recarregar';

  @override
  String get onboardingSavePhotos => 'salvar em fotos';

  @override
  String onboardingSelectInterestMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'selecione pelo menos $countString categorias para personalizar seu feed';
  }

  @override
  String get onboardingSetWallpaper => 'definir como papel de parede';

  @override
  String get onboardingSignInAgainLower => 'faça login novamente';

  @override
  String get onboardingSkip => 'Pular';

  @override
  String get onboardingSkipLower => 'pular';

  @override
  String get onboardingTermsRequired => 'Concorde primeiro com os Termos e a Política de Privacidade.';

  @override
  String get onboardingTryAgainLower => 'tente novamente';

  @override
  String onboardingWallpaperForInterest(String category) {
    return 'escolhemos este papel de parede com base no seu interesse em $category';
  }

  @override
  String get onboardingWallpaperJustForYou => 'escolhemos este papel de parede só para você';

  @override
  String get onboardingWelcomeDescription => 'Milhões de papéis de parede premium de grandes artistas.';

  @override
  String get onboardingWelcomeHeadline => 'Sua tela, reimaginada.';

  @override
  String get premiumPageExplorePlans => 'Explore os planos Prism Premium.';

  @override
  String get premiumPagePlansUnavailable =>
      'Os planos não estão disponíveis no momento. Verifique sua conexão e tente novamente.';

  @override
  String get premiumPageTitle => 'Prism Premium';

  @override
  String get premiumPageTryAgain => 'Tente novamente';

  @override
  String get premiumPageViewPlans => 'Ver planos';

  @override
  String get premiumGuestStorePurchaseActive =>
      'Sua compra na loja está ativa neste dispositivo. Entre para usar os recursos Pro vinculados à conta.';

  @override
  String get premiumPurchasePending => 'Sua compra foi salva. O Pro pode levar um minuto para ser ativado.';

  @override
  String get premiumPurchaseUnconfirmed =>
      'Não foi possível confirmar sua compra. Tente usar Restaurar compras nas Configurações.';

  @override
  String get wallpaperAccentColor => 'Cor de destaque';

  @override
  String get wallpaperAccentColorsOriginal => 'Cores originais do papel de parede';

  @override
  String get wallpaperResetOriginal => 'Restaurar original';

  @override
  String get wallpaperAll => 'Todos';

  @override
  String get wallpaperApplyTo => 'Aplicar em';

  @override
  String get wallpaperAutoRotateApplyTo => 'Aplicar em';

  @override
  String get wallpaperAutoRotateBatterySteps =>
      'Abra Configurações > Apps > Prism > Bateria. Defina o uso da bateria como irrestrito.';

  @override
  String get wallpaperAutoRotateBatteryTip =>
      'Se os papéis de parede pararem de mudar, defina o uso da bateria do Prism como irrestrito. Abra Configurações > Apps > Prism > Bateria.';

  @override
  String get wallpaperAutoRotateBothScreens => 'Ambos';

  @override
  String get wallpaperAutoRotateChangeError => 'Não foi possível alterar o papel de parede.';

  @override
  String get wallpaperAutoRotateChangeLabel => 'Mudar';

  @override
  String get wallpaperAutoRotateChargingDescription => 'Mude quando conectado, no máximo uma vez por intervalo';

  @override
  String get wallpaperAutoRotateChargingOnly => 'Somente durante o carregamento';

  @override
  String get wallpaperAutoRotateCopySteps => 'Copiar etapas';

  @override
  String get wallpaperAutoRotateCouldNotStart => 'Não foi possível iniciar. Tente novamente.';

  @override
  String wallpaperAutoRotateDownloadedCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'papéis de parede',
      one: 'papel de parede',
      zero: 'papéis de parede',
    );
    return 'Baixados $cachedString de $totalString $_temp0';
  }

  @override
  String wallpaperAutoRotateEnabledUntil(String date) {
    return 'Passe ativo até $date';
  }

  @override
  String get wallpaperAutoRotateGotIt => 'Entendi';

  @override
  String get wallpaperAutoRotateHomeScreen => 'Tela inicial';

  @override
  String get wallpaperAutoRotateInterval12Hours => 'A cada 12 horas';

  @override
  String get wallpaperAutoRotateInterval15 => 'A cada 15 minutos (alto consumo de bateria)';

  @override
  String get wallpaperAutoRotateInterval30 => 'A cada 30 minutos';

  @override
  String get wallpaperAutoRotateInterval3Days => 'A cada 3 dias';

  @override
  String get wallpaperAutoRotateInterval3Hours => 'A cada 3 horas';

  @override
  String get wallpaperAutoRotateInterval6Hours => 'A cada 6 horas';

  @override
  String get wallpaperAutoRotateIntervalDay => 'Diariamente';

  @override
  String get wallpaperAutoRotateIntervalHour => 'A cada hora';

  @override
  String get wallpaperAutoRotateIntervalWeek => 'Toda semana';

  @override
  String get wallpaperAutoRotateKeepRunning => 'Continue funcionando';

  @override
  String get wallpaperAutoRotateLoadError => 'Não foi possível carregar as configurações de rotação automática.';

  @override
  String get wallpaperAutoRotateLoadingWalls => 'Carregando papéis de parede';

  @override
  String get wallpaperAutoRotateLockScreen => 'Tela de bloqueio';

  @override
  String wallpaperAutoRotateMix(int count, String source) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede de $source na seleção',
      one: '1 papel de parede de $source na seleção',
      zero: '$countString papéis de parede de $source na seleção',
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
      other: '$countString papéis de parede de $source na seleção. Usando os primeiros 100.',
      one: '1 papel de parede de $source na seleção. Usando os primeiros 100.',
      zero: '$countString papéis de parede de $source na seleção. Usando os primeiros 100.',
    );
    return '$_temp0';
  }

  @override
  String wallpaperAutoRotateNextChange(String time) {
    return 'Próxima mudança em torno de $time';
  }

  @override
  String wallpaperAutoRotateNounCategory(String category) {
    return '$category';
  }

  @override
  String get wallpaperAutoRotateNounDownloads => 'downloads';

  @override
  String get wallpaperAutoRotateNounFavourites => 'favoritos';

  @override
  String get wallpaperAutoRotateNounHistory => 'seu histórico';

  @override
  String get wallpaperAutoRotateNounWotd => 'papéis de parede do dia';

  @override
  String get wallpaperAutoRotateOff => 'Desligado';

  @override
  String get wallpaperAutoRotateOffEnded =>
      'A rotação automática está desativada porque seu plano ou passe do Prism Premium terminou.';

  @override
  String get wallpaperAutoRotateOpenDownloads => 'Abrir downloads';

  @override
  String get wallpaperAutoRotateOpenFavourites => 'Abrir favoritos';

  @override
  String get wallpaperAutoRotatePassEnabled => 'A rotação automática fica ativada por 7 dias.';

  @override
  String wallpaperAutoRotatePassPurchase(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Passe de 7 dias · $coinsString moedas';
  }

  @override
  String get wallpaperAutoRotatePickCategory => 'Escolha uma categoria';

  @override
  String wallpaperAutoRotatePreparing(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede',
      one: '1 papel de parede',
      zero: '$countString papéis de parede',
    );
    return 'Preparando $_temp0';
  }

  @override
  String get wallpaperAutoRotateProBody => 'Experimente por 7 dias com moedas ou adquira o Prism Pro.';

  @override
  String get wallpaperAutoRotateProTitle => 'A rotação automática é um recurso do Prism Pro.';

  @override
  String wallpaperAutoRotateReadyCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'papéis de parede prontos',
      one: 'papel de parede pronto',
      zero: 'papéis de parede prontos',
    );
    return '$cachedString de $totalString $_temp0';
  }

  @override
  String get wallpaperAutoRotateScheduled => 'Agendado';

  @override
  String get wallpaperAutoRotateShuffle => 'Embaralhar';

  @override
  String get wallpaperAutoRotateShuffleDescription => 'Ordem aleatória em vez de uma após a outra';

  @override
  String get wallpaperAutoRotateSourceCategory => 'Categoria';

  @override
  String get wallpaperAutoRotateSourceDownloads => 'Downloads';

  @override
  String get wallpaperAutoRotateSourceFavourites => 'Favoritos';

  @override
  String get wallpaperAutoRotateSourceHistory => 'Histórico';

  @override
  String get wallpaperAutoRotateSourceLabel => 'Fonte';

  @override
  String get wallpaperAutoRotateSourceLoadError =>
      'Não foi possível carregar os papéis de parede. Verifique sua conexão.';

  @override
  String get wallpaperAutoRotateSourceWotd => 'Papel de parede do dia';

  @override
  String get wallpaperAutoRotateStartError => 'Não foi possível iniciar a rotação do papel de parede.';

  @override
  String get wallpaperAutoRotateStarting => 'Começando';

  @override
  String get wallpaperAutoRotateStatusLabel => 'Status';

  @override
  String get wallpaperAutoRotateStepsCopied => 'Etapas copiadas.';

  @override
  String get wallpaperAutoRotateStopError => 'Não foi possível interromper a rotação do papel de parede.';

  @override
  String get wallpaperAutoRotateTitle => 'Rotação automática';

  @override
  String get wallpaperAutoRotateTooFewCategory => 'Esta categoria tem menos de 2 papéis de parede. Escolha outra.';

  @override
  String get wallpaperAutoRotateTooFewDownloads => 'Baixe pelo menos 2 papéis de parede para alternar entre eles.';

  @override
  String get wallpaperAutoRotateTooFewFavourites =>
      'Adicione pelo menos 2 papéis de parede aos favoritos para alternar entre eles.';

  @override
  String get wallpaperAutoRotateTooFewHistory =>
      'Defina pelo menos 2 papéis de parede no Prism para alternar entre eles.';

  @override
  String get wallpaperAutoRotateTooFewWotd => 'Ainda não há escolhas anteriores suficientes.';

  @override
  String get wallpaperAutoRotateUnlockError => 'Não foi possível desbloquear a rotação automática. Tente novamente.';

  @override
  String get wallpaperAutoRotateUpdateError => 'Não foi possível atualizar a rotação automática.';

  @override
  String get wallpaperBack => 'Voltar';

  @override
  String get wallpaperBlockCreator => 'Bloquear criador';

  @override
  String get wallpaperBlockCreatorNotFound => 'Não foi possível encontrar este criador. Tente novamente.';

  @override
  String get wallpaperBoostAlready => 'Já impulsionado.';

  @override
  String wallpaperBoostAlreadyUntil(String time) {
    return 'Já impulsionado até $time.';
  }

  @override
  String wallpaperBoostConfirmButton(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Impulsionar por $coinsString moedas';
  }

  @override
  String wallpaperBoostConfirmMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Destaque este papel de parede no carrossel da tela inicial e no topo de Em alta por 24 horas, por $coinsString moedas.';
  }

  @override
  String wallpaperBoostDurationAndCost(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '24 horas em destaque · $coinsString moedas';
  }

  @override
  String get wallpaperBoostFailed => 'Não foi possível impulsionar este papel de parede. Tente novamente.';

  @override
  String get wallpaperBoostOnlyApproved =>
      'Somente papéis de parede aprovados que você enviou podem ser impulsionados.';

  @override
  String get wallpaperBoostSlotsTaken =>
      'Todas as vagas de impulsionamento estão ocupadas. Tente novamente mais tarde.';

  @override
  String wallpaperBoostSlotsTakenUntil(String time) {
    return 'Todas as vagas de impulsionamento estão ocupadas. A próxima será liberada $time.';
  }

  @override
  String get wallpaperBoostTitle => 'Impulsione Em alta';

  @override
  String get wallpaperBoostedSuccess => 'Impulsionado. Já aparece na tela inicial e em Em alta.';

  @override
  String get wallpaperBoostedTag => 'Impulsionado';

  @override
  String wallpaperBoostedUntil(String time) {
    return 'Impulsionado até $time';
  }

  @override
  String get wallpaperBrowseWallpapers => 'Procure papéis de parede';

  @override
  String wallpaperByCreator(String name) {
    return 'Papel de parede de $name';
  }

  @override
  String get wallpaperByPrismCreator => 'Papel de parede do criador do Prism';

  @override
  String get wallpaperCategories => 'Categorias';

  @override
  String get wallpaperCategory => 'Categoria';

  @override
  String get wallpaperCategoryFeedEmptyBody => 'Novos papéis de parede chegam com frequência. Volte em breve.';

  @override
  String get wallpaperCategoryFeedEmptyTitle => 'Ainda não há papéis de parede aqui';

  @override
  String wallpaperCategoryNamed(String name) {
    return 'Categoria: $name';
  }

  @override
  String get wallpaperChangeNow => 'Mude agora';

  @override
  String get wallpaperCheckBackSoon => 'Volte em breve.';

  @override
  String get wallpaperCheckBackTomorrow => 'Volte amanhã.';

  @override
  String get wallpaperCheckConnection => 'Verifique sua conexão e tente novamente.';

  @override
  String get wallpaperClear => 'Limpar';

  @override
  String get wallpaperClearFilters => 'Limpar filtros';

  @override
  String get wallpaperClearHistoryAction => 'Limpar histórico';

  @override
  String get wallpaperClearHistoryBody =>
      'Isso remove a lista de papéis de parede que você definiu. Seus papéis de parede permanecem como estão.';

  @override
  String get wallpaperClearHistoryTitle => 'Limpar histórico?';

  @override
  String get wallpaperClearSearch => 'Limpar pesquisa';

  @override
  String get wallpaperClosePreview => 'Fechar visualização';

  @override
  String get wallpaperCollapseDetails => 'Recolher detalhes do papel de parede';

  @override
  String get wallpaperCollection => 'Coleção';

  @override
  String get wallpaperCollectionLoadError => 'Não foi possível carregar esta coleção';

  @override
  String wallpaperCollectionNamed(String name) {
    return 'Coleção: $name';
  }

  @override
  String wallpaperCollectionPreviewUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Prévia desbloqueada por 24 horas (-$coinsString moedas).';
  }

  @override
  String get wallpaperCollectionRefreshError => 'Não foi possível atualizar. Puxe para baixo para tentar novamente.';

  @override
  String get wallpaperCollectionsEmptyBody => 'Puxe para baixo para atualizar ou volte em breve.';

  @override
  String get wallpaperCollectionsEmptyTitle => 'Ainda não há coleções';

  @override
  String get wallpaperCopyAccentHexHint => 'Pressione e segure para copiar a cor hexadecimal';

  @override
  String wallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede',
      one: '1 papel de parede',
      zero: 'Nenhum papel de parede',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDelete => 'Excluir';

  @override
  String get wallpaperDeleteManyDownloadsBody =>
      'Eles são removidos deste dispositivo. Você pode baixá-los novamente mais tarde.';

  @override
  String wallpaperDeleteManyDownloadsTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Excluir $countString downloads?';
  }

  @override
  String get wallpaperDeleteOneDownloadBody =>
      'Ele é removido deste dispositivo. Você pode baixá-lo novamente mais tarde.';

  @override
  String get wallpaperDeleteOneDownloadTitle => 'Excluir este download?';

  @override
  String get wallpaperDepthEditorSubtitle =>
      'No editor da tela de bloqueio, toque em ••• e depois em Efeito de profundidade.';

  @override
  String get wallpaperDepthEffect => 'Efeito de profundidade';

  @override
  String get wallpaperDepthSubjectSubtitle => 'O elemento principal da imagem fica na frente do relógio.';

  @override
  String get wallpaperSpatialScene => 'Cena espacial';

  @override
  String get wallpaperSpatialGreatSubtitle => 'Profundidade nítida. Cria uma tela de bloqueio 3D forte.';

  @override
  String get wallpaperSpatialOkSubtitle => 'Alguma profundidade. O efeito 3D é suave.';

  @override
  String get wallpaperSpatialGuideTitle => 'Defina como Cena espacial';

  @override
  String get wallpaperSpatialGuideBody => 'No iPhone 12 ou posterior com iOS 26:';

  @override
  String get wallpaperSpatialStepSave => 'Salve este wallpaper em Fotos.';

  @override
  String get wallpaperSpatialStepPick =>
      'Na tela de bloqueio, toque e mantenha pressionada a tela. Toque no botão Adicionar, toque em Fotos e depois selecione a foto.';

  @override
  String get wallpaperSpatialStepButton =>
      'Toque no botão Cena espacial para ativar o efeito 3D e depois toque em Adicionar.';

  @override
  String get wallpaperSpatialPreviewLabel => '3D';

  @override
  String get wallpaperSpatialPreviewOn => 'Visualizar em 3D';

  @override
  String get wallpaperSpatialPreviewOff => 'Desativar a visualização 3D';

  @override
  String get wallpaperSpatialDragHint => 'Arraste para inclinar';

  @override
  String get wallpaperDetailColorCodeCopied => 'Código de cores copiado para a área de transferência';

  @override
  String get wallpaperDetailNotFound => 'Papel de parede não encontrado';

  @override
  String get wallpaperDiscard => 'Descartar';

  @override
  String get wallpaperDismiss => 'Dispensar';

  @override
  String get wallpaperDownload => 'Baixar';

  @override
  String wallpaperDownloadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString downloads',
      one: '1 download',
      zero: '$countString downloads',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadSortName => 'Nome';

  @override
  String get wallpaperDownloadSortNewest => 'Mais recente';

  @override
  String get wallpaperDownloadSortOldest => 'Mais antigo';

  @override
  String get wallpaperDownloadWallpaper => 'Baixar papel de parede';

  @override
  String get wallpaperDownloadedWallpaper => 'Papel de parede baixado';

  @override
  String get wallpaperDownloadedWallpaperUnavailable => 'O papel de parede baixado não está disponível';

  @override
  String wallpaperDownloadsDeleteError(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Não foi possível excluir $countString downloads.',
      one: 'Não foi possível excluir 1 download.',
      zero: 'Não foi possível excluir $countString downloads.',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadsEmptyBody => 'Os papéis de parede que você baixa são mantidos aqui.';

  @override
  String get wallpaperDownloadsEmptyTitle => 'Ainda não há downloads';

  @override
  String get wallpaperDownloadsLoadError => 'Não foi possível carregar seus downloads';

  @override
  String get wallpaperDownloadsLoadHelp => 'Verifique seu acesso ao armazenamento e tente novamente.';

  @override
  String get wallpaperDownloadsRefreshError => 'Não foi possível atualizar os downloads. Tente novamente.';

  @override
  String get wallpaperDownloadsShareError => 'Não foi possível compartilhar. Tente novamente.';

  @override
  String get wallpaperDownloadsTitle => 'Downloads';

  @override
  String get wallpaperEdit => 'Editar';

  @override
  String get wallpaperEditTitle => 'Editar papel de parede';

  @override
  String get wallpaperExpandDetails => 'Expanda os detalhes do papel de parede';

  @override
  String get wallpaperFavourite => 'Favorito';

  @override
  String get wallpaperFavouriteAddedToast => 'Adicionado aos favoritos.';

  @override
  String get wallpaperFavouriteClearAccountMessage => 'Isso os remove da sua conta.';

  @override
  String get wallpaperFavouriteClearAll => 'Limpar todos os favoritos';

  @override
  String get wallpaperFavouriteClearDeviceMessage => 'Isso os remove deste dispositivo.';

  @override
  String get wallpaperFavouriteClearError => 'Não foi possível limpar os favoritos. Tente novamente.';

  @override
  String wallpaperFavouriteClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Limpar $countString favoritos?';
  }

  @override
  String get wallpaperFavouriteClearOneTitle => 'Limpar 1 favorito?';

  @override
  String wallpaperFavouriteClearedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favoritos removidos',
      one: '1 favorito removido',
      zero: '$countString favoritos removidos',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteClearedOne => '1 favorito removido';

  @override
  String wallpaperFavouriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favoritos',
      one: '1 favorito',
      zero: 'Nenhum favorito',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteEmptyBody => 'Toque no coração em um papel de parede para mantê-lo aqui.';

  @override
  String get wallpaperFavouriteEmptyTitle => 'Ainda não há favoritos';

  @override
  String get wallpaperFavouriteExport => 'Exportar favoritos';

  @override
  String get wallpaperFavouriteExportEmpty => 'Ainda não há favoritos para exportar.';

  @override
  String get wallpaperFavouriteExportError => 'Não foi possível exportar favoritos. Tente novamente.';

  @override
  String get wallpaperFavouriteGuestPrompt => 'Faça login para mantê-los em todos os dispositivos';

  @override
  String get wallpaperFavouriteLoadError => 'Não foi possível carregar seus favoritos';

  @override
  String get wallpaperFavouriteMoreActions => 'Mais ações dos favoritos';

  @override
  String get wallpaperFavouriteNoMatch => 'Não há favoritos correspondentes';

  @override
  String get wallpaperFavouriteNotSynced => 'Não sincronizado';

  @override
  String get wallpaperFavouriteRefreshFallback => 'Não foi possível atualizar os favoritos. Mostrando sua lista salva.';

  @override
  String get wallpaperFavouriteRemove => 'Remover';

  @override
  String get wallpaperFavouriteRemoveAction => 'Remover dos favoritos';

  @override
  String get wallpaperFavouriteRemoveError => 'Não foi possível remover os favoritos. Tente novamente.';

  @override
  String wallpaperFavouriteRemovedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favoritos removidos',
      one: '1 favorito removido',
      zero: '$countString favoritos removidos',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteRemovedOne => 'Removido dos favoritos';

  @override
  String get wallpaperFavouriteRemovedToast => 'Removido dos favoritos.';

  @override
  String get wallpaperFavouriteRestoreError => 'Não foi possível restaurar os favoritos.';

  @override
  String get wallpaperFavouriteSearchHint => 'Pesquise por criador ou categoria';

  @override
  String get wallpaperFavouriteSetUsesFirst => 'A opção Definir usa o primeiro favorito selecionado';

  @override
  String get wallpaperFavouriteShareError => 'Não foi possível compartilhar. Tente novamente.';

  @override
  String get wallpaperFavouriteSortOldest => 'Mais antigo';

  @override
  String get wallpaperFavouriteSortRecentlyAdded => 'Adicionado recentemente';

  @override
  String get wallpaperFavouriteSortSource => 'Fonte';

  @override
  String get wallpaperFavouriteStatus => 'Nos seus favoritos';

  @override
  String get wallpaperFavouriteTryDifferent => 'Tente uma pesquisa ou fonte diferente.';

  @override
  String get wallpaperFavouriteUnavailableLegacy =>
      'Este favorito é de uma versão mais antiga e não pode ser aberto. Pressione e segure para removê-lo.';

  @override
  String get wallpaperFavouriteWaitingSync => 'Aguardando sincronização';

  @override
  String get wallpaperFavouritesTitle => 'Favoritos';

  @override
  String get wallpaperFeedAnnouncement => 'Anúncio';

  @override
  String get wallpaperFeedCaughtUpBody => 'Puxe para baixo para atualizar. Novas escolhas chegarão aqui.';

  @override
  String get wallpaperFeedCaughtUpTitle => 'Você já viu tudo';

  @override
  String get wallpaperFeedClearHistoryError => 'Não foi possível limpar o histórico. Tente novamente.';

  @override
  String get wallpaperFeedDiscovery => 'Descoberta';

  @override
  String get wallpaperFeedEmptyBody =>
      'Siga os criadores ou escolha interesses para que possamos mostrar mais do que você gosta.';

  @override
  String get wallpaperFeedEmptyTitle => 'Dê forma a este feed';

  @override
  String get wallpaperFeedFollowingEmptyTitle => 'Siga os criadores para ver seus novos papéis de parede aqui';

  @override
  String get wallpaperFeedFollowingLoadError => 'Não foi possível carregar o feed de quem você segue';

  @override
  String get wallpaperFeedLatestLoadError => 'Não foi possível carregar os papéis de parede mais recentes';

  @override
  String get wallpaperFeedLearnedFromYou => 'Aprendi com você';

  @override
  String get wallpaperFeedLearningEmpty => 'Abra, salve e defina papéis de parede para personalizar seu feed.';

  @override
  String get wallpaperFeedLearningHistoryCleared => 'Histórico de aprendizagem apagado';

  @override
  String get wallpaperFeedLoadError => 'Não foi possível carregar seu feed';

  @override
  String get wallpaperFeedLoadMoreError => 'Não foi possível carregar mais. Tente novamente';

  @override
  String get wallpaperFeedMixAdventurous => 'Aventureiro';

  @override
  String get wallpaperFeedMixAdventurousDescription => 'Mais papéis de parede fora do seu perfil de interesses.';

  @override
  String get wallpaperFeedMixBalanced => 'Equilibrado';

  @override
  String get wallpaperFeedMixBalancedDescription => 'Ao seu gosto, com algumas surpresas.';

  @override
  String get wallpaperFeedMixFamiliar => 'Familiar';

  @override
  String get wallpaperFeedMixFamiliarDescription => 'Principalmente o que você já ama.';

  @override
  String wallpaperFeedPickAtLeast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Escolha pelo menos $countString';
  }

  @override
  String wallpaperFeedPickedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString escolhido';
  }

  @override
  String get wallpaperFeedPopularEmptyTitle => 'Ainda não há papéis de parede populares';

  @override
  String get wallpaperFeedPopularLoadError => 'Não foi possível carregar papéis de parede populares';

  @override
  String get wallpaperFeedPullToRefresh => 'Puxe para baixo para atualizar.';

  @override
  String get wallpaperFeedRefreshError => 'Não foi possível atualizar seu feed.';

  @override
  String get wallpaperFeedSaveError => 'Não foi possível salvar as configurações do feed. Tente novamente.';

  @override
  String get wallpaperFeedSettingsHint => 'Toque duas vezes para abrir as configurações do feed';

  @override
  String get wallpaperFeedStartingPoints => 'Pontos de partida';

  @override
  String get wallpaperFeedTabFollowing => 'Seguindo';

  @override
  String get wallpaperFeedTabForYou => 'Para você';

  @override
  String get wallpaperFeedTabLatest => 'Mais recente';

  @override
  String get wallpaperFeedTabPopular => 'Popular';

  @override
  String get wallpaperFeedTabTrending => 'Em alta';

  @override
  String get wallpaperFeedTuneDescription => 'O Prism aprende com o que você abre, salva e configura.';

  @override
  String get wallpaperFeedTuneTitle => 'Ajuste seu feed';

  @override
  String get wallpaperFeedUpdating => 'Atualizando';

  @override
  String get wallpaperFeedWallsLoadError => 'Não foi possível carregar os papéis de parede';

  @override
  String get wallpaperFewerLikeThisConfirmation => 'Você verá menos papéis de parede como este.';

  @override
  String get wallpaperFewerLikeThisUndo => 'Desfazer';

  @override
  String get wallpaperFileMovedOrDeleted => 'O arquivo pode ter sido movido ou excluído.';

  @override
  String wallpaperFilterApplyCost(int coins, int missing) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'Aplicar este filtro custa $coinsString moedas. Você precisa de mais $missingString moedas.';
  }

  @override
  String get wallpaperFilterBlur => 'Desfoque';

  @override
  String get wallpaperFilterBrightness => 'Brilho';

  @override
  String get wallpaperFilterEffectEdge => 'Borda';

  @override
  String get wallpaperFilterEffectEmboss => 'Relevo';

  @override
  String get wallpaperFilterEffectHighPass => 'Realce de detalhes';

  @override
  String get wallpaperFilterEffectSharpen => 'Nitidez';

  @override
  String get wallpaperFilterHoldToCompare => 'Segure para comparar';

  @override
  String get wallpaperFilterHue => 'Matiz';

  @override
  String get wallpaperFilterLightness => 'Luminosidade';

  @override
  String get wallpaperFilterLightnessUnavailable => 'A luminosidade não está disponível neste dispositivo.';

  @override
  String get wallpaperFilterNeedCoins => 'Você precisa de moedas para usar este filtro premium';

  @override
  String get wallpaperFilterOriginal => 'Original';

  @override
  String get wallpaperFilterSaturation => 'Saturação';

  @override
  String get wallpaperFilterSaveError => 'Não foi possível salvar o papel de parede. Por favor, tente novamente!';

  @override
  String get wallpaperFilterTabAdjustments => 'Ajustar';

  @override
  String get wallpaperFilterTabFilters => 'Filtros';

  @override
  String wallpaperFilterUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Filtro premium desbloqueado para esta edição (-$coinsString moedas).';
  }

  @override
  String get wallpaperFitBlur => 'Ajustar com desfoque';

  @override
  String get wallpaperFitColour => 'Combine com a cor';

  @override
  String get wallpaperFitFill => 'Preencher';

  @override
  String get wallpaperGenericError => 'Algo deu errado!';

  @override
  String get wallpaperGoBack => 'Volte';

  @override
  String get wallpaperGotItFewerLikeThis => 'Entendi. Você verá menos assim.';

  @override
  String get wallpaperHidePreviewControls => 'Ocultar controles';

  @override
  String get wallpaperHistoryBothScreens => 'Ambas as telas';

  @override
  String get wallpaperHistoryCurrent => 'Atual';

  @override
  String get wallpaperHistoryCurrentPrefix => 'Atual. ';

  @override
  String get wallpaperHistoryEmptyBody =>
      'Os papéis de parede que você definir aparecerão aqui, para que você possa configurá-los novamente.';

  @override
  String get wallpaperHistoryEmptyTitle => 'Ainda não há papéis de parede';

  @override
  String get wallpaperHistoryRemoveAction => 'Remover do histórico';

  @override
  String get wallpaperHomeAppName => 'Prism';

  @override
  String get wallpaperImageSemanticHint => 'Segure para favoritos, compartilhar e restaurar. Role para ver detalhes.';

  @override
  String get wallpaperPreviousInFeed => 'Papel de parede anterior';

  @override
  String get wallpaperNextInFeed => 'Próximo papel de parede';

  @override
  String get wallpaperImageSemanticLabel => 'Papel de parede';

  @override
  String get wallpaperImmersiveHint => 'Toque para ocultar os controles';

  @override
  String get wallpaperInsufficientCoins => 'Não há moedas suficientes. Ganhe moedas em recompensas.';

  @override
  String wallpaperInterestLearnedLabel(String label, int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Aprendido: $label, $percentString por cento';
  }

  @override
  String wallpaperInterestSelectedLabel(String name, String selection) {
    return 'Interesse: $name, $selection';
  }

  @override
  String get wallpaperLandscapeCrop => 'Papel de parede de paisagem: as laterais serão cortadas';

  @override
  String get wallpaperLibraryCollections => 'Coleções';

  @override
  String get wallpaperLibraryDownloads => 'Downloads';

  @override
  String get wallpaperLibraryFavourites => 'Favoritos';

  @override
  String get wallpaperLibraryHistory => 'Histórico';

  @override
  String get wallpaperLibraryTitle => 'Biblioteca';

  @override
  String get wallpaperLive => 'Animado';

  @override
  String get wallpaperLiveApplied => 'Papel de parede animado definido.';

  @override
  String wallpaperLiveApplyPhotoDescription(String style) {
    return 'Visualização do $style';
  }

  @override
  String get wallpaperLiveBatterySaver => 'Economizador de bateria';

  @override
  String get wallpaperLiveChooseAnotherVideo => 'Escolha outro vídeo';

  @override
  String get wallpaperLiveChooseVideo => 'Escolha um vídeo';

  @override
  String get wallpaperLiveConfirmPreview => 'Confirme na visualização do sistema.';

  @override
  String get wallpaperLiveDeviceUnavailable => 'Não disponível neste dispositivo';

  @override
  String get wallpaperLiveErrorGeneric => 'Não foi possível definir o papel de parede animado. Tente novamente.';

  @override
  String get wallpaperLiveErrorImageTooLarge => 'Essa imagem é muito grande para um papel de parede animado.';

  @override
  String get wallpaperLiveErrorMemory => 'Memória insuficiente. Feche outros aplicativos e tente novamente.';

  @override
  String get wallpaperLiveErrorNotAllowed =>
      'Seu dispositivo ou perfil de trabalho não permite alterações no papel de parede.';

  @override
  String get wallpaperLiveErrorPermission => 'O Prism não tem permissão para ler esse arquivo.';

  @override
  String get wallpaperLiveErrorPreview => 'Não foi possível abrir a visualização do sistema.';

  @override
  String get wallpaperLiveErrorReadFile => 'Não foi possível ler o arquivo. Tente novamente.';

  @override
  String get wallpaperLiveErrorStyle => 'Este dispositivo não pôde iniciar esse estilo. Tente outro.';

  @override
  String get wallpaperLiveErrorTimeout => 'Tempo limite esgotado. Verifique sua conexão e tente novamente.';

  @override
  String get wallpaperLiveErrorTooLarge => 'Esse arquivo é muito grande para um papel de parede animado.';

  @override
  String get wallpaperLiveErrorVideo =>
      'Esse vídeo não pode ser reproduzido como papel de parede. Experimente outro clipe.';

  @override
  String wallpaperLiveFps(int fps) {
    final intl.NumberFormat fpsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String fpsString = fpsNumberFormat.format(fps);

    return '$fpsString quadros por segundo';
  }

  @override
  String wallpaperLiveGradientDescription(String style) {
    return 'Visualização do $style';
  }

  @override
  String wallpaperLiveGradientSwatch(String index, String count) {
    return 'Gradiente $index de $count';
  }

  @override
  String get wallpaperLiveKeepPrismOpen => 'Mantenha o Prism aberto e tente novamente.';

  @override
  String get wallpaperLiveModeGradients => 'Gradientes';

  @override
  String get wallpaperLiveModePhoto => 'Animar foto';

  @override
  String get wallpaperLiveModeVideo => 'Vídeo';

  @override
  String get wallpaperLiveNoVideo => 'Nenhum vídeo escolhido';

  @override
  String get wallpaperLivePreviewInstruction => 'O Android abre uma visualização. Toque em Definir papel de parede lá.';

  @override
  String get wallpaperLiveProStyleRequired => 'Este estilo faz parte do Prism Premium.';

  @override
  String get wallpaperLiveSetAction => 'Definir papel de parede animado';

  @override
  String get wallpaperLiveShaderUnsupported =>
      'Este dispositivo não pode executar papéis de parede animados de shader. Experimente o vídeo.';

  @override
  String get wallpaperLiveStyleAurora => 'aurora';

  @override
  String get wallpaperLiveStyleAuroraDescription => 'Faixas suaves de cor.';

  @override
  String get wallpaperLiveStyleBreathe => 'Respirar';

  @override
  String get wallpaperLiveStyleBreatheDescription => 'Um pulso suave, entrando e saindo.';

  @override
  String get wallpaperLiveStyleDrift => 'Deslizar';

  @override
  String get wallpaperLiveStyleDriftDescription => 'Movimento e zoom lentos. Acompanha os movimentos da tela inicial.';

  @override
  String get wallpaperLiveStyleMesh => 'Malha';

  @override
  String get wallpaperLiveStyleMeshDescription => 'Cor mesclada que muda lentamente.';

  @override
  String get wallpaperLiveStylePlasma => 'Plasma';

  @override
  String get wallpaperLiveStylePlasmaDescription => 'Cor suave e fluida.';

  @override
  String get wallpaperLiveStyleRipple => 'Ondulação';

  @override
  String get wallpaperLiveStyleRippleDescription => 'Anéis de água que se espalham com o seu toque.';

  @override
  String get wallpaperLiveStyleShimmer => 'Brilho';

  @override
  String get wallpaperLiveStyleShimmerDescription => 'Uma suave varredura de luz.';

  @override
  String get wallpaperLiveStyleDepth => '3D';

  @override
  String get wallpaperLiveStyleDepthDescription =>
      'A foto se move em profundidade quando você desliza entre as telas iniciais e inclina o celular.';

  @override
  String get wallpaperLiveStyleStarfield => 'Campo Estelar';

  @override
  String get wallpaperLiveStyleStarfieldDescription => 'Estrelas cintilantes em preto puro.';

  @override
  String wallpaperLiveStyleUnlocked(String style) {
    return '$style fica desbloqueado por 7 dias.';
  }

  @override
  String get wallpaperLiveStyleWaves => 'Ondas';

  @override
  String get wallpaperLiveStyleWavesDescription => 'Ondas em camadas que rolam.';

  @override
  String get wallpaperLiveTextureDownloadFailed =>
      'Não foi possível baixar o papel de parede. Verifique sua conexão e tente novamente.';

  @override
  String get wallpaperLiveTexturePrepareFailed => 'Não foi possível preparar o papel de parede.';

  @override
  String get wallpaperLiveTextureTooDetailed => 'Esse papel de parede é muito detalhado para ser animado.';

  @override
  String get wallpaperLiveTitle => 'Papéis de parede animados';

  @override
  String get wallpaperLiveUnavailableBody =>
      'É necessário um celular Android compatível com papéis de parede animados em OpenGL.';

  @override
  String get wallpaperLiveUnavailableTitle => 'Papéis de parede animados não estão disponíveis';

  @override
  String wallpaperLiveUnlockCoins(String coins) {
    return 'Desbloquear · $coins moedas';
  }

  @override
  String wallpaperLiveUnlockError(String style) {
    return 'Não foi possível desbloquear $style. Tente novamente.';
  }

  @override
  String wallpaperLiveUnlockStyleAction(String style, String coins) {
    return 'Desbloquear $style por 7 dias · $coins moedas';
  }

  @override
  String get wallpaperLiveUnlockStyleBody =>
      'Desbloqueie por 7 dias com moedas ou assine o Prism Premium para ter acesso a todos os estilos.';

  @override
  String wallpaperLiveUnlockStyleTitle(String style) {
    return '$style é um estilo pago';
  }

  @override
  String get wallpaperLiveUnsupported => 'Este dispositivo não pode mostrar papéis de parede animados.';

  @override
  String get wallpaperLiveVideoChosen => 'Vídeo escolhido';

  @override
  String get wallpaperLiveVideoDescription => 'Reproduz na tela inicial com o som desligado. Até 256 MB.';

  @override
  String get wallpaperLiveVideoReadFailed => 'Não foi possível ler esse vídeo. Escolha novamente.';

  @override
  String get wallpaperLiveVideoTooLarge => 'Esse vídeo tem mais de 256 MB. Escolha um clipe mais curto.';

  @override
  String get wallpaperLiveVideoUnsupported => 'Este dispositivo não pode reproduzir um vídeo como papel de parede.';

  @override
  String get wallpaperLoadingImage => 'Carregando imagem';

  @override
  String get wallpaperLoadingWallpaper => 'Carregando papel de parede';

  @override
  String get wallpaperLowResolutionScreen => 'Baixa resolução para sua tela';

  @override
  String get wallpaperMakeItLive => 'Animar papel de parede';

  @override
  String get wallpaperMatchSystemColour => 'Corresponder à cor do sistema';

  @override
  String get wallpaperMoreLikeThis => 'Mais como este';

  @override
  String get wallpaperNavCollections => 'Coleções';

  @override
  String get wallpaperNavHome => 'Início';

  @override
  String get wallpaperNavRewards => 'Recompensas';

  @override
  String get wallpaperNavSearch => 'Procurar';

  @override
  String get wallpaperNew => 'Novo';

  @override
  String get wallpaperNotNow => 'Agora não';

  @override
  String get wallpaperNotSelected => 'não selecionado';

  @override
  String get wallpaperNotificationPromptBody =>
      'Um papel de parede escolhido a dedo todas as manhãs, além de lembretes de sequências. Sem spam.';

  @override
  String get wallpaperNotificationPromptTitle => 'Receba o papel de parede do dia';

  @override
  String get wallpaperOffline => 'Off-line';

  @override
  String wallpaperOldVersionBody(String version) {
    return 'A versão $version não é mais suportada. Atualize o Prism para continuar usando-o.';
  }

  @override
  String get wallpaperOldVersionTitle => 'Hora de atualizar';

  @override
  String get wallpaperOnPrism => 'Papel de parede no Prism';

  @override
  String get wallpaperOpenError => 'Não foi possível carregar este papel de parede';

  @override
  String get wallpaperOpenFileError => 'Não foi possível abrir este papel de parede';

  @override
  String get wallpaperOpenNotifications => 'Abrir notificações';

  @override
  String get wallpaperOtherSource => 'Outro';

  @override
  String get wallpaperPastPicksEmpty => 'Nenhuma escolha anterior ainda';

  @override
  String get wallpaperPastPicksLoadError => 'Não foi possível carregar as escolhas anteriores';

  @override
  String get wallpaperPastPicksTitle => 'Escolhas anteriores';

  @override
  String get wallpaperPlacementDim => 'Escurecer';

  @override
  String get wallpaperPositionApproximate =>
      'A posição é aproximada. O app de tela inicial pode exibir o papel de parede de outra forma.';

  @override
  String get wallpaperPremium => 'Premium';

  @override
  String get wallpaperPremiumCollection => 'Coleção premium';

  @override
  String wallpaperPremiumCollectionNamed(String name) {
    return 'Coleção premium: $name';
  }

  @override
  String get wallpaperPreviewHome => 'Tela inicial';

  @override
  String get wallpaperPreviewIconClear => 'Transparente';

  @override
  String get wallpaperPreviewIconDark => 'Escuro';

  @override
  String get wallpaperPreviewIconDefault => 'Padrão';

  @override
  String get wallpaperPreviewIconStyle => 'Estilo dos ícones';

  @override
  String get wallpaperPreviewIconThemed => 'Temático';

  @override
  String get wallpaperPreviewIconTinted => 'Tonalizado';

  @override
  String get wallpaperPreviewLock => 'Tela de bloqueio';

  @override
  String get wallpaperPreviewOnScreen => 'Pré-visualizar na sua tela';

  @override
  String get wallpaperPreviewSetBoth => 'Definir nas duas telas';

  @override
  String get wallpaperPreviewSetHome => 'Definir na tela inicial';

  @override
  String get wallpaperPreviewSetLock => 'Definir na tela de bloqueio';

  @override
  String wallpaperPreviewUnlock24Hours(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Desbloquear por 24 horas (-$costString)';
  }

  @override
  String wallpaperPreviewUnlockCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'A prévia desta coleção premium por 24 horas custa $costString moedas.';
  }

  @override
  String wallpaperPreviewUnlockCostMissing(int cost, int missing) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'A prévia por 24 horas custa $costString moedas. Faltam $missingString.';
  }

  @override
  String wallpaperPreviewWatchAdUnlock(String adOption) {
    return '$adOption e desbloquear';
  }

  @override
  String get wallpaperProcessing => 'Processando papel de parede';

  @override
  String get wallpaperProfileOpenError => 'Não foi possível abrir o perfil';

  @override
  String get wallpaperQuickAddAction => 'Adicionar às configurações rápidas';

  @override
  String get wallpaperQuickFavouriteDescription =>
      'Aplica um papel de parede aleatório dos seus favoritos. Evita repetir o último. Adicione alguns aos favoritos primeiro.';

  @override
  String get wallpaperQuickFavouriteTitle => 'Bloco favorito aleatório';

  @override
  String get wallpaperQuickHowToTitle => 'Como adicionar um bloco';

  @override
  String get wallpaperQuickShuffleDescription =>
      'Toque no bloco para aplicar um papel de parede aleatório da categoria escolhida.';

  @override
  String get wallpaperQuickShuffleTitle => 'Alternar papéis de parede';

  @override
  String get wallpaperQuickStepEdit => 'Toque no lápis ou no ícone de edição.';

  @override
  String get wallpaperQuickStepFindPrism => 'Encontre os blocos do Prism e arraste-os para a área de blocos ativos.';

  @override
  String get wallpaperQuickStepShade => 'Deslize a tela de cima para baixo duas vezes para abrir as notificações.';

  @override
  String get wallpaperQuickTargetBoth => 'Ambos';

  @override
  String get wallpaperQuickTargetHome => 'Tela inicial';

  @override
  String get wallpaperQuickTargetLock => 'Tela de bloqueio';

  @override
  String get wallpaperQuickTileAddError =>
      'Não foi possível adicionar o bloco. Adicione-o manualmente na tela de edição de configurações rápidas.';

  @override
  String get wallpaperQuickTileAdded => 'Bloco adicionado às configurações rápidas.';

  @override
  String get wallpaperQuickTileAlreadyAdded => 'Este bloco já está nas configurações rápidas.';

  @override
  String get wallpaperQuickTileNotAdded => 'Bloco não adicionado. Você pode adicioná-lo a qualquer momento.';

  @override
  String get wallpaperQuickTileSaveError => 'Não foi possível salvar as configurações rápidas do bloco';

  @override
  String get wallpaperQuickTilesLoadError => 'Não foi possível carregar seus blocos rápidos';

  @override
  String get wallpaperQuickTilesTitle => 'Blocos rápidos';

  @override
  String get wallpaperQuickWotdDescription =>
      'Aplica o papel de parede do dia. Abra o Prism uma vez por dia para salvar a versão mais recente no dispositivo.';

  @override
  String get wallpaperQuickWotdTitle => 'Bloco do papel de parede do dia';

  @override
  String get wallpaperRefresh => 'Atualizar';

  @override
  String get wallpaperRemovedFromHistory => 'Removido do histórico';

  @override
  String get wallpaperReport => 'Denunciar';

  @override
  String get wallpaperReset => 'Reiniciar';

  @override
  String get wallpaperSave => 'Salvar';

  @override
  String get wallpaperSaveToPhotos => 'Salvar em fotos';

  @override
  String get wallpaperSavedOnDevice => 'Salvo neste dispositivo';

  @override
  String wallpaperSearchTag(String tag) {
    return 'Pesquisar $tag';
  }

  @override
  String get wallpaperSeePrismPro => 'Conheça o Prism Premium';

  @override
  String get wallpaperSelected => 'selecionado';

  @override
  String get wallpaperServerUnavailable => 'Não foi possível conectar aos servidores';

  @override
  String get wallpaperSessionEnded => 'Sua sessão terminou. Faça login novamente.';

  @override
  String get wallpaperSet => 'Definir';

  @override
  String get wallpaperSetAsWallpaper => 'Definir como papel de parede';

  @override
  String wallpaperSetCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Definido $countString vezes',
      one: 'Definido uma vez',
      zero: 'Definido $countString vezes',
    );
    return '$_temp0';
  }

  @override
  String get setScreenTargetHome => 'Tela inicial';

  @override
  String get setScreenTargetLock => 'Tela de bloqueio';

  @override
  String get setScreenTargetBoth => 'Ambas';

  @override
  String get setScreenTargetGroup => 'Onde definir';

  @override
  String get setScreenRemember => 'Lembrar esta escolha';

  @override
  String get setScreenRememberHint =>
      'Definir pula esta tela na próxima vez. Mantenha Definir pressionado para voltar.';

  @override
  String get setScreenAdjust => 'Ajustar';

  @override
  String get setScreenMore => 'Mais';

  @override
  String get setScreenPairLock => 'Usar outro papel de parede para a tela de bloqueio';

  @override
  String get setScreenOpenSystemEditor => 'Abrir editor do sistema';

  @override
  String get setScreenClose => 'Fechar';

  @override
  String get wallpaperShare => 'Compartilhar';

  @override
  String get wallpaperShareLink => 'Compartilhar link';

  @override
  String get wallpaperShortcutsChoosePrismData => 'Escolha o que o Prism envia';

  @override
  String get wallpaperShortcutsOpenAction => 'Abrir atalhos';

  @override
  String get wallpaperShortcutsOpenError => 'Não foi possível abrir os atalhos. Abra o aplicativo você mesmo.';

  @override
  String get wallpaperShortcutsSourceFavourite => 'Favorito aleatório';

  @override
  String get wallpaperShortcutsSourceWotd => 'Papel de parede do dia';

  @override
  String get wallpaperShortcutsSourceWotdDescription =>
      'A escolha de hoje do Prism. Baixe primeiro o original de hoje no Prism. Quando a escolha diária mudar, baixe o novo original antes de executar esta fonte.';

  @override
  String get wallpaperShortcutsTitle => 'Alterar automaticamente';

  @override
  String get wallpaperShowLessLikeThis => 'Mostrar menos assim';

  @override
  String get wallpaperShowPreviewControls => 'Mostrar controles';

  @override
  String get wallpaperSignIn => 'Entrar';

  @override
  String get wallpaperSignInForPremiumFilters => 'Faça login para usar filtros premium com moedas.';

  @override
  String get wallpaperSortDownloads => 'Classificar downloads';

  @override
  String get wallpaperStartupFailed => 'Não foi possível iniciar o Prism';

  @override
  String get wallpaperThemeDarkAccent => 'Cor de destaque escuro';

  @override
  String get wallpaperThemeDarkThemes => 'Temas escuros';

  @override
  String get wallpaperUseAsAppAccent => 'Usar como cor de destaque do app';

  @override
  String get wallpaperAppAccentUpdated => 'Cor de destaque do app atualizada';

  @override
  String get wallpaperThemeLightAccent => 'Cor de destaque clara';

  @override
  String get wallpaperThemeLightThemes => 'Temas claros';

  @override
  String get wallpaperThemeModeDark => 'Escuro';

  @override
  String get wallpaperThemeModeLight => 'Claro';

  @override
  String get wallpaperThemeModeSystem => 'Sistema (claro/escuro)';

  @override
  String get wallpaperThemePreference => 'Preferência de tema';

  @override
  String get wallpaperThemePreferenceDescription =>
      'Selecione seu modo de tema preferido. O modo do sistema alterna automaticamente entre claro e escuro dependendo do modo do seu dispositivo.';

  @override
  String get wallpaperThemeTitle => 'Temas';

  @override
  String get wallpaperTitle => 'Título';

  @override
  String get wallpaperTrendingEmptyTitle => 'Nada está em alta ainda';

  @override
  String get wallpaperTrendingLoadError => 'Não foi possível carregar os papéis de parede populares';

  @override
  String get wallpaperTryAgain => 'Tente novamente';

  @override
  String get wallpaperTurnOff => 'Desligar';

  @override
  String get wallpaperTurnOnNotifications => 'Ative as notificações';

  @override
  String get wallpaperUnavailable => 'Indisponível';

  @override
  String get wallpaperUnfavourite => 'Remover dos favoritos';

  @override
  String get wallpaperUnreadItems => 'Tem itens não lidos';

  @override
  String get wallpaperUpdatePrism => 'Atualizar o Prism';

  @override
  String get wallpaperUploadAction => 'Enviar';

  @override
  String get wallpaperUploadAddTag => 'Adicionar tag';

  @override
  String get wallpaperUploadAddTagHint => 'Adicione uma tag e toque em Concluído';

  @override
  String get wallpaperUploadAiSubtitle => 'Descreva uma cena e gere um papel de parede para telefone';

  @override
  String get wallpaperUploadApprovalInfo =>
      'Seu papel de parede aparece na comunidade após aprovação. Acompanhe-o em seus uploads.';

  @override
  String wallpaperUploadBatchPosition(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Papel de parede $positionString de $totalString';
  }

  @override
  String wallpaperUploadBatchSubmitted(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label. $countString enviados.';
  }

  @override
  String wallpaperUploadBatchSummaryNotSent(String submitted, int notSent) {
    final intl.NumberFormat notSentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String notSentString = notSentNumberFormat.format(notSent);

    return '$submitted. $notSentString não enviados.';
  }

  @override
  String wallpaperUploadBatchSummarySubmitted(int submittedCount, int total) {
    final intl.NumberFormat submittedCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String submittedCountString = submittedCountNumberFormat.format(submittedCount);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$submittedCountString de $totalString papéis de parede enviados';
  }

  @override
  String get wallpaperUploadBrightness => 'Brilho';

  @override
  String get wallpaperUploadCheckReviewStatus => 'Verifique o status da revisão';

  @override
  String get wallpaperUploadChooseAnotherImage => 'Escolha outra imagem';

  @override
  String get wallpaperUploadContinueDraft => 'Continue editando seu papel de parede salvo';

  @override
  String get wallpaperUploadContrast => 'Contraste';

  @override
  String get wallpaperUploadCreateTitle => 'Criar';

  @override
  String get wallpaperUploadDeleteConfirmTitle => 'Excluir este papel de parede?';

  @override
  String get wallpaperUploadDeleteError => 'Não foi possível excluir. Tente novamente.';

  @override
  String get wallpaperUploadDeletePermissionError =>
      'Não foi possível excluir. Entre na conta usada para enviar o papel de parede e tente novamente.';

  @override
  String get wallpaperUploadDeleteWallpaper => 'Excluir papel de parede';

  @override
  String get wallpaperUploadDeleted => 'Papel de parede excluído.';

  @override
  String get wallpaperUploadDetailsOptional => 'Detalhes (opcional)';

  @override
  String get wallpaperUploadDiscardBody =>
      'Os arquivos enviados serão removidos. A imagem selecionada permanecerá no seu dispositivo.';

  @override
  String get wallpaperUploadDiscardEditsBody => 'Suas alterações serão perdidas.';

  @override
  String get wallpaperUploadDiscardEditsTitle => 'Descartar suas edições?';

  @override
  String get wallpaperUploadDiscardError => 'Não foi possível descartar este envio. Tente novamente.';

  @override
  String get wallpaperUploadDiscardTitle => 'Descartar este envio?';

  @override
  String get wallpaperUploadDownloadError => 'Não foi possível fazer o download. Tente novamente.';

  @override
  String get wallpaperUploadDownloadStarting => 'Iniciando download';

  @override
  String get wallpaperUploadDraftSaveError => 'Não foi possível salvar este rascunho. Tente novamente.';

  @override
  String wallpaperUploadEditBatch(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Editar papel de parede $positionString de $totalString';
  }

  @override
  String get wallpaperUploadEditSaveError => 'Não foi possível salvar suas edições. Tente novamente.';

  @override
  String get wallpaperUploadFileSize => 'Tamanho';

  @override
  String get wallpaperUploadFilesCheckActive => 'Enviando o papel de parede e sua prévia';

  @override
  String get wallpaperUploadFilesCheckDone => 'Papel de parede e prévia enviados';

  @override
  String get wallpaperUploadFilesCheckPending => 'Envie o papel de parede e sua prévia';

  @override
  String get wallpaperUploadFilesRemoveError => 'Não foi possível remover os arquivos enviados. Tente novamente.';

  @override
  String get wallpaperUploadFlip => 'Virar';

  @override
  String wallpaperUploadFreeQuotaMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Usuários do plano gratuito podem enviar $countString papéis de parede por semana.';
  }

  @override
  String get wallpaperUploadFromGallery => 'Da sua galeria';

  @override
  String get wallpaperUploadFullImageError => 'Não foi possível carregar a imagem completa.';

  @override
  String get wallpaperUploadInReview => 'Em revisão';

  @override
  String get wallpaperUploadKeepDraft => 'Manter rascunho';

  @override
  String get wallpaperUploadLeaveBody =>
      'Guarde seu rascunho para retomá-lo mais tarde ou descarte-o e remova os arquivos enviados.';

  @override
  String get wallpaperUploadLeaveTitle => 'Sair deste upload?';

  @override
  String wallpaperUploadMaxTagsReached(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Você adicionou $countString tags';
  }

  @override
  String get wallpaperUploadOriginalContentGuideline =>
      'Envie apenas papéis de parede originais e de alta qualidade. Não envie conteúdo de outros aplicativos.';

  @override
  String get wallpaperUploadPrepareCheckActive => 'Preparando sua imagem e uma visualização menor';

  @override
  String get wallpaperUploadPrepareCheckDone => 'A imagem e a visualização estão prontas';

  @override
  String get wallpaperUploadPrepareCheckPending => 'Prepare sua imagem e uma visualização menor';

  @override
  String get wallpaperUploadPrepareError =>
      'Não pudemos preparar esta imagem. Tente novamente ou escolha outra imagem.';

  @override
  String get wallpaperUploadQualityLandscape =>
      'Esta imagem é ampla. Os papéis de parede do telefone ficam melhores em retrato.';

  @override
  String wallpaperUploadQualityLowResolution(int width, int height, int recommendedShortSide) {
    final intl.NumberFormat widthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String widthString = widthNumberFormat.format(width);
    final intl.NumberFormat recommendedShortSideNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String recommendedShortSideString = recommendedShortSideNumberFormat.format(recommendedShortSide);

    return 'Esta imagem tem $widthString × $height px e pode ficar pouco nítida no celular. O ideal é ter pelo menos $recommendedShortSideString px no lado menor.';
  }

  @override
  String get wallpaperUploadQuotaCleanupFailed =>
      'Você atingiu o limite de upload, mas não foi possível remover os arquivos enviados. Toque em Voltar para tentar removê-los novamente.';

  @override
  String get wallpaperUploadQuotaReached =>
      'Você atingiu o limite semanal de envio de papéis de parede do plano gratuito.';

  @override
  String wallpaperUploadQuotaRemaining(int remaining, int total) {
    final intl.NumberFormat remainingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Restam $remainingString de $totalString envios gratuitos nesta semana';
  }

  @override
  String get wallpaperUploadRejected => 'Reprovado';

  @override
  String get wallpaperUploadRejectedSectionError => 'Não foi possível carregar seus envios rejeitados.';

  @override
  String get wallpaperUploadRejectionFallback =>
      'Nenhum motivo específico foi informado. Confira os detalhes do papel de parede e envie-o novamente.';

  @override
  String get wallpaperUploadRejectionTitle => 'Por que foi rejeitado';

  @override
  String wallpaperUploadRemoveTag(String tag) {
    return 'Remover tag $tag';
  }

  @override
  String get wallpaperUploadResetAdjustments => 'Redefinir ajustes';

  @override
  String get wallpaperUploadResolution => 'Resolução';

  @override
  String get wallpaperUploadResumeDraft => 'Retomar envio salvo';

  @override
  String get wallpaperUploadRetrySubmit => 'Tentar enviar novamente';

  @override
  String get wallpaperUploadReviewCheckActive => 'Salvando seu envio para revisão';

  @override
  String get wallpaperUploadReviewCheckDone => 'Enviado para revisão';

  @override
  String get wallpaperUploadReviewCheckPending =>
      'Os moderadores analisam o papel de parede antes de ele aparecer no Prism';

  @override
  String get wallpaperUploadReviewEmptyBody => 'Os papéis de parede que você envia mostram seu status de revisão aqui.';

  @override
  String get wallpaperUploadReviewEmptyTitle => 'Nada aqui ainda';

  @override
  String get wallpaperUploadReviewLoadError => 'Não foi possível carregar seus uploads';

  @override
  String get wallpaperUploadReviewSectionError => 'Não foi possível carregar seus envios.';

  @override
  String get wallpaperUploadRotateLeft => 'Girar para a esquerda';

  @override
  String get wallpaperUploadRotateRight => 'Girar para a direita';

  @override
  String get wallpaperUploadSaturation => 'Saturação';

  @override
  String get wallpaperUploadSavedToPictures => 'Papel de parede salvo em Pictures/Prism';

  @override
  String get wallpaperUploadSkip => 'Ignorar este papel de parede';

  @override
  String get wallpaperUploadStagePrepareFailed => 'Não foi possível preparar a imagem';

  @override
  String get wallpaperUploadStagePreparing => 'Preparando papel de parede';

  @override
  String get wallpaperUploadStageQuotaReached => 'Limite de upload atingido';

  @override
  String get wallpaperUploadStageReady => 'Pronto para enviar';

  @override
  String get wallpaperUploadStageSubmissionFailed => 'O envio não terminou';

  @override
  String get wallpaperUploadStageSubmitting => 'Enviando papel de parede';

  @override
  String get wallpaperUploadStageUploadFailed => 'O envio não foi concluído';

  @override
  String get wallpaperUploadStageUploading => 'Enviando papel de parede';

  @override
  String get wallpaperUploadSubmissionUnconfirmed =>
      'Não foi possível confirmar o envio. Verifique o status da sua revisão antes de tentar novamente.';

  @override
  String get wallpaperUploadTags => 'Tags';

  @override
  String wallpaperUploadTagsHelp(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Adicione até $countString tags para ajudar as pessoas a encontrar seu papel de parede.';
  }

  @override
  String get wallpaperUploadTitle => 'Enviar papel de parede';

  @override
  String get wallpaperUploadTitleHint => 'Dê um nome ao seu papel de parede';

  @override
  String get wallpaperUploadViewWallpaper => 'Ver papel de parede';

  @override
  String get wallpaperUploadYourUploads => 'Seus envios';

  @override
  String get wallpaperUsePhoneAccent => 'Use a cor de destaque do seu telefone';

  @override
  String get wallpaperThemeMaterialYouNote => 'O Material You usa as cores do seu papel de parede.';

  @override
  String wallpaperViewCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString visualizações',
      one: '1 visualização',
      zero: '$countString visualizações',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperViewCountUnavailable => 'Contagem de visualizações indisponível';

  @override
  String wallpaperWotdByPhotographer(String name) {
    return 'Papel de parede do dia, de $name';
  }

  @override
  String get economyAiPromptSceneAnime1 => 'um gato cochilando numa estação ensolarada';

  @override
  String get economyAiPromptSceneAnime2 => 'nuvens de verão gigantes sobre arrozais';

  @override
  String get economyAiPromptSceneAnime3 => 'uma barraca de lámen brilhando numa rua chuvosa';

  @override
  String get economyAiPromptSceneAnime4 => 'um portal torii numa colina sobre um mar de nuvens';

  @override
  String get economyAiPromptSceneAnime5 => 'fogos de artifício sobre um rio num festival';

  @override
  String get economyAiPromptSceneAnime6 => 'uma sala de aula calma com pétalas entrando';

  @override
  String get economyAiPromptSceneAnime7 => 'uma estrada à beira-mar com um ponto de ônibus';

  @override
  String get economyAiPromptSceneAnime8 => 'uma baleia do céu flutuando sobre uma vila';

  @override
  String get economyAiPromptSceneMinimal1 => 'um barquinho de papel sobre água pálida e parada';

  @override
  String get economyAiPromptSceneMinimal2 => 'um arco de luz sobre uma planície vazia';

  @override
  String get economyAiPromptSceneMinimal3 => 'uma árvore solitária numa suave encosta nevada';

  @override
  String get economyAiPromptSceneMinimal4 => 'dois círculos sobrepostos sobre granulação suave';

  @override
  String get economyAiPromptSceneMinimal5 => 'uma fina linha de horizonte entre mar e céu';

  @override
  String get economyAiPromptSceneMinimal6 => 'uma única pena caindo no espaço vazio';

  @override
  String get economyAiPromptSceneMinimal7 => 'seixos lisos empilhados sobre fundo claro';

  @override
  String get economyAiPromptSceneMinimal8 => 'uma sombra em meia-lua numa parede de gesso';

  @override
  String get economyAiPromptSceneCyberpunk1 => 'um bar de macarrão sob chuva e luzes de neon';

  @override
  String get economyAiPromptSceneCyberpunk2 => 'um trem flutuante entre megatorres';

  @override
  String get economyAiPromptSceneCyberpunk3 => 'um androide solitário num telhado sob a chuva';

  @override
  String get economyAiPromptSceneCyberpunk4 => 'uma estrada de dados rumo a uma cidade imensa';

  @override
  String get economyAiPromptSceneCyberpunk5 => 'um mercado noturno sob um emaranhado de cabos';

  @override
  String get economyAiPromptSceneCyberpunk6 => 'uma moto cromada estacionada num beco neon';

  @override
  String get economyAiPromptSceneCyberpunk7 => 'uma lua holográfica sobre torres da cidade';

  @override
  String get economyAiPromptSceneCyberpunk8 => 'uma rua alagada refletindo um muro de telas';

  @override
  String get economyAiPromptSceneWatercolor1 => 'um campo de lavanda entre a névoa da manhã';

  @override
  String get economyAiPromptSceneWatercolor2 => 'uma vila de pescadores junto a um porto calmo';

  @override
  String get economyAiPromptSceneWatercolor3 => 'papoulas silvestres ao lado de uma estrada rural';

  @override
  String get economyAiPromptSceneWatercolor4 => 'um balão de ar quente sobre colinas verdes';

  @override
  String get economyAiPromptSceneWatercolor5 => 'uma garça num lago cheio de juncos';

  @override
  String get economyAiPromptSceneWatercolor6 => 'uma rua chuvosa com postes desfocados';

  @override
  String get economyAiPromptSceneWatercolor7 => 'uma xícara fumegante ao lado de uma janela aberta';

  @override
  String get economyAiPromptSceneWatercolor8 => 'pinheiros nevados junto a um riacho gelado';

  @override
  String get economyAiPromptSceneMeshGradient1 => 'manchas de cor suaves se fundindo umas nas outras';

  @override
  String get economyAiPromptSceneMeshGradient2 => 'uma onda de gradiente sedoso se dobrando';

  @override
  String get economyAiPromptSceneMeshGradient3 => 'orbes brilhantes sobre um fundo aveludado';

  @override
  String get economyAiPromptSceneMeshGradient4 => 'um gradiente tipo aurora subindo em varredura';

  @override
  String get economyAiPromptSceneMeshGradient5 => 'poças de cor líquida com granulação fina';

  @override
  String get economyAiPromptSceneMeshGradient6 => 'um gradiente de quente a frio com ruído suave';

  @override
  String get economyAiPromptSceneMeshGradient7 => 'pétalas translúcidas de gradiente sobrepostas';

  @override
  String get economyAiPromptSceneMeshGradient8 => 'um pôr do sol desfocado de faixas de cor fluida';

  @override
  String get economyAiPromptSceneAbstract1 => 'cacos de vidro entrelaçados captando a luz';

  @override
  String get economyAiPromptSceneAbstract2 => 'nuvens de tinta fluindo suspensas na água';

  @override
  String get economyAiPromptSceneAbstract3 => 'uma espiral de fitas dobradas em movimento';

  @override
  String get economyAiPromptSceneAbstract4 => 'mármore estilhaçado com veios dourados';

  @override
  String get economyAiPromptSceneAbstract5 => 'curvas de nível ondulantes em camadas';

  @override
  String get economyAiPromptSceneAbstract6 => 'esferas flutuantes projetando longas sombras';

  @override
  String get economyAiPromptSceneAbstract7 => 'rastros de fumaça se enroscando num vórtice';

  @override
  String get economyAiPromptSceneAbstract8 => 'um campo de cubos suaves subindo em ondas';

  @override
  String get economyAiPromptSceneNature1 => 'uma cachoeira caindo num desfiladeiro de musgo';

  @override
  String get economyAiPromptSceneNature2 => 'um campo de girassóis sob um céu imenso';

  @override
  String get economyAiPromptSceneNature3 => 'um lago congelado com rachaduras de gelo azul';

  @override
  String get economyAiPromptSceneNature4 => 'cerejeiras ao longo de um caminho junto ao rio';

  @override
  String get economyAiPromptSceneNature5 => 'uma lagoa tropical vista de cima';

  @override
  String get economyAiPromptSceneNature6 => 'bordos de outono refletidos num lago parado';

  @override
  String get economyAiPromptSceneNature7 => 'uma raposa solitária na neve fresca ao amanhecer';

  @override
  String get economyAiPromptSceneNature8 => 'nuvens de tempestade sobre verdes planaltos';

  @override
  String get economyAiPromptSceneSpace1 => 'um planeta com anéis sobre o horizonte lunar';

  @override
  String get economyAiPromptSceneSpace2 => 'uma galáxia espiral brilhando no espaço profundo';

  @override
  String get economyAiPromptSceneSpace3 => 'um astronauta flutuando sobre um planeta azul';

  @override
  String get economyAiPromptSceneSpace4 => 'uma nebulosa em forma de flor desabrochando';

  @override
  String get economyAiPromptSceneSpace5 => 'dois sóis se pondo sobre um deserto alienígena';

  @override
  String get economyAiPromptSceneSpace6 => 'uma estação espacial orbitando um gigante gasoso';

  @override
  String get economyAiPromptSceneSpace7 => 'uma chuva de meteoros sobre um observatório';

  @override
  String get economyAiPromptSceneSpace8 => 'um eclipse com um brilhante anel de diamante';

  @override
  String get economyAiPromptSceneSynthwave1 => 'uma estrada de grade neon rumo ao pôr do sol';

  @override
  String get economyAiPromptSceneSynthwave2 => 'uma costa de palmeiras sob um sol listrado';

  @override
  String get economyAiPromptSceneSynthwave3 => 'um carro esportivo retrô numa estrada sem fim';

  @override
  String get economyAiPromptSceneSynthwave4 => 'montanhas de arame sob um céu magenta';

  @override
  String get economyAiPromptSceneSynthwave5 => 'um sol cromado afundando num mar brilhante';

  @override
  String get economyAiPromptSceneSynthwave6 => 'um fliperama retrô brilhando numa noite chuvosa';

  @override
  String get economyAiPromptSceneSynthwave7 => 'uma fita cassete flutuando num espaço neon';

  @override
  String get economyAiPromptSceneSynthwave8 => 'uma palmeira solitária num horizonte laser';

  @override
  String get economyAiPromptScenePixelArt1 => 'uma cabana aconchegante na floresta nevada';

  @override
  String get economyAiPromptScenePixelArt2 => 'um castelo num penhasco sobre o mar';

  @override
  String get economyAiPromptScenePixelArt3 => 'uma cidadezinha com janelas acesas';

  @override
  String get economyAiPromptScenePixelArt4 => 'uma nave sobre um mundo alienígena roxo';

  @override
  String get economyAiPromptScenePixelArt5 => 'uma cachoeira num vale de selva exuberante';

  @override
  String get economyAiPromptScenePixelArt6 => 'um píer de pesca sob a lua cheia';

  @override
  String get economyAiPromptScenePixelArt7 => 'um templo com cerejeiras em flor na primavera';

  @override
  String get economyAiPromptScenePixelArt8 => 'um trem cruzando uma ponte ao pôr do sol';

  @override
  String get economyAiPromptSceneRender3d1 => 'formas de argila brilhante em equilíbrio';

  @override
  String get economyAiPromptSceneRender3d2 => 'fitas de vidro fosco sobre um palco pastel';

  @override
  String get economyAiPromptSceneRender3d3 => 'uma ilhazinha flutuando sobre uma nuvem macia';

  @override
  String get economyAiPromptSceneRender3d4 => 'bolhas de cromo infladas sob luz suave';

  @override
  String get economyAiPromptSceneRender3d5 => 'um deserto em miniatura com um cacto solitário';

  @override
  String get economyAiPromptSceneRender3d6 => 'um diorama de sala aconchegante dentro de um cubo';

  @override
  String get economyAiPromptSceneRender3d7 => 'arcos de mármore flutuando sobre água parada';

  @override
  String get economyAiPromptSceneRender3d8 => 'ondas cor de bala congeladas em movimento';

  @override
  String get economyAiPromptSceneOilPainting1 => 'um mar tempestuoso batendo contra a costa rochosa';

  @override
  String get economyAiPromptSceneOilPainting2 => 'um campo de papoulas ao sol com uma fazenda';

  @override
  String get economyAiPromptSceneOilPainting3 => 'uma natureza-morta de limões e um vaso azul';

  @override
  String get economyAiPromptSceneOilPainting4 => 'um porto enevoado ao amanhecer com barcos antigos';

  @override
  String get economyAiPromptSceneOilPainting5 => 'um caminho na floresta em chamas de cores outonais';

  @override
  String get economyAiPromptSceneOilPainting6 => 'um canal ao luar com casas antigas';

  @override
  String get economyAiPromptSceneOilPainting7 => 'um campo de trigo ondulando antes da tempestade';

  @override
  String get economyAiPromptSceneOilPainting8 => 'uma rosa num copo sobre uma mesa escura';

  @override
  String get economyAiPromptSceneUkiyoE1 => 'uma grande onda se curvando sob uma lua pálida';

  @override
  String get economyAiPromptSceneUkiyoE2 => 'um pagode coberto de neve ao anoitecer';

  @override
  String get economyAiPromptSceneUkiyoE3 => 'garças voando sobre uma montanha nebulosa';

  @override
  String get economyAiPromptSceneUkiyoE4 => 'uma ponte de madeira sob pétalas de cerejeira';

  @override
  String get economyAiPromptSceneUkiyoE5 => 'barcos de pesca num mar índigo agitado';

  @override
  String get economyAiPromptSceneUkiyoE6 => 'um sol vermelho sobre um pico vulcânico';

  @override
  String get economyAiPromptSceneUkiyoE7 => 'um lago de carpas sob salgueiros-chorões';

  @override
  String get economyAiPromptSceneUkiyoE8 => 'chuva caindo sobre uma vila junto ao rio';

  @override
  String get economyAiPromptLightingMorningHaze => 'névoa matinal suave';

  @override
  String get economyAiPromptLightingGoldenHour => 'hora dourada suave';

  @override
  String get economyAiPromptLightingMoonlight => 'luz fria do luar';

  @override
  String get economyAiPromptLightingNeonRim => 'contraluz neon';

  @override
  String get economyAiPromptLightingBacklight => 'contraluz quente';

  @override
  String get economyAiPromptLightingGodRays => 'suaves raios de luz';

  @override
  String get economyAiPromptLightingStudio => 'luz de estúdio';

  @override
  String get economyAiPromptLightingTwilight => 'crepúsculo azul';

  @override
  String get economyAiPromptPaletteTealAmber => 'verde-azulado e âmbar';

  @override
  String get economyAiPromptPaletteIndigoRose => 'tons de índigo e rosa';

  @override
  String get economyAiPromptPaletteSageCream => 'verde-sálvia e creme';

  @override
  String get economyAiPromptPaletteBlackNeonPink => 'preto com rosa neon';

  @override
  String get economyAiPromptPalettePastelPeach => 'pêssego pastel suave';

  @override
  String get economyAiPromptPaletteEmeraldGold => 'esmeralda e dourado';

  @override
  String get economyAiPromptPaletteOceanBlue => 'tons de azul-oceano';

  @override
  String get economyAiPromptPaletteCrimsonCharcoal => 'carmim e grafite';

  @override
  String get economyAiPromptSuffix => 'papel de parede vertical para celular, sem texto';

  @override
  String economyAiPromptComposition(String scene, String lighting, String palette, String suffix) {
    return '$scene, $lighting, $palette. $suffix';
  }

  @override
  String economyAiPromptSceneOnly(String scene, String suffix) {
    return '$scene, $suffix';
  }

  @override
  String get economyAiMadeWithPrism => 'Feito com Prism AI';

  @override
  String get onboardingAiPromptFallback => 'um papel de parede incrível';

  @override
  String get onboardingAiPromptNature1 => 'um lago glacial ao amanhecer, água como espelho e picos rosados';

  @override
  String get onboardingAiPromptNature2 => 'um riacho de floresta musgosa com luz suave entre samambaias altas';

  @override
  String get onboardingAiPromptNature3 => 'um campo de flores silvestres sob um vasto céu de fim de tarde';

  @override
  String get onboardingAiPromptNature4 => 'uma praia de areia negra com ondas turquesa e rochedos ao anoitecer';

  @override
  String get onboardingAiPromptNature5 => 'auroras boreais sobre um pinheiral nevado junto a um lago gelado';

  @override
  String get onboardingAiPromptAbstract1 => 'fitas de vidro translúcido girando em luz suave com bordas iridescentes';

  @override
  String get onboardingAiPromptAbstract2 => 'nuvens de tinta na água em azul profundo e dourado, detalhes suaves';

  @override
  String get onboardingAiPromptAbstract3 => 'ondas de camadas de papel em tons quentes de pôr do sol, sombras suaves';

  @override
  String get onboardingAiPromptAbstract4 => 'um redemoinho de mármore esculpido com veios dourados sobre fundo grafite';

  @override
  String get onboardingAiPromptAbstract5 => 'esferas cromadas flutuando e refletindo um céu pastel em calma';

  @override
  String get onboardingAiPromptWatercolor1 => 'uma vila litorânea em aquarela com casas pastel e barcos ao amanhecer';

  @override
  String get onboardingAiPromptWatercolor2 =>
      'flores silvestres soltas em aquarela, rosa e sálvia, sobre papel texturizado';

  @override
  String get onboardingAiPromptWatercolor3 =>
      'um lago enevoado em aquarela com um deque de madeira e colinas distantes';

  @override
  String get onboardingAiPromptWatercolor4 => 'um céu noturno em aquarela com nuvens violeta e uma lua brilhante';

  @override
  String get onboardingAiPromptWatercolor5 =>
      'uma floresta de outono em aquarela com lavagens quentes de laranja e dourado';

  @override
  String get onboardingAiPromptMinimal1 => 'um sol se pondo sobre um mar calmo, cores chapadas e céu amplo e vazio';

  @override
  String get onboardingAiPromptMinimal2 => 'colinas suaves em camadas, tons de areia opacos e céu em degradê pálido';

  @override
  String get onboardingAiPromptMinimal3 => 'uma árvore sem folhas numa colina nevada com muito espaço vazio e calmo';

  @override
  String get onboardingAiPromptMinimal4 =>
      'um veleiro solitário num lago parado ao amanhecer, formas simples e tons suaves';

  @override
  String get onboardingAiPromptMinimal5 => 'arcos concêntricos suaves em terracota e creme com granulação fina';

  @override
  String get onboardingAiPromptAnime1 => 'um céu de verão estilo anime com nuvens enormes sobre uma ferrovia litorânea';

  @override
  String get onboardingAiPromptAnime2 => 'uma cidade noturna de anime vista de uma colina, luzes quentes e estrelas';

  @override
  String get onboardingAiPromptAnime3 => 'um santuário de floresta de anime com espíritos brilhando em luz verde suave';

  @override
  String get onboardingAiPromptAnime4 => 'uma rua de anime chuvosa ao anoitecer, luzes de lojas e reflexos em poças';

  @override
  String get onboardingAiPromptAnime5 => 'um campo de anime na hora dourada com o vento na grama alta';

  @override
  String get onboardingAiPromptMeshGradient1 =>
      'um gradiente em malha suave de tangerina, rosa e violeta com granulação fina';

  @override
  String get onboardingAiPromptMeshGradient2 =>
      'um gradiente em malha profundo de azul-marinho e verde-azulado com toque lima';

  @override
  String get onboardingAiPromptMeshGradient3 => 'um gradiente em malha suave de azul-céu, lavanda e creme quente';

  @override
  String get onboardingAiPromptMeshGradient4 => 'um gradiente em malha intenso de carmim e ouro, fluindo como seda';

  @override
  String get onboardingAiPromptMeshGradient5 => 'um gradiente em malha sereno de sálvia, menta e areia clara';

  @override
  String get onboardingAiPromptCyberpunk1 => 'uma rua cyberpunk à noite na chuva, com reflexos de neon e vapor';

  @override
  String get onboardingAiPromptCyberpunk2 => 'uma cidade neon vista de um terraço, com carros voadores cruzando';

  @override
  String get onboardingAiPromptCyberpunk3 => 'um canal cyberpunk tranquilo com lojas luminosas e lanternas flutuantes';

  @override
  String get onboardingAiPromptCyberpunk4 =>
      'um skyline cyberpunk ao amanhecer, torres de vidro e névoa rosa e turquesa';

  @override
  String get onboardingAiPromptCyberpunk5 => 'uma moto solitária numa ponte neon sobre uma cidade futurista enevoada';

  @override
  String get onboardingAiPromptSpace1 => 'um gigante gasoso com anéis sobre uma lua rochosa e céu cheio de estrelas';

  @override
  String get onboardingAiPromptSpace2 => 'uma nebulosa colorida em violeta e turquesa com jovens estrelas brilhantes';

  @override
  String get onboardingAiPromptSpace3 => 'uma galáxia espiral de frente, com núcleo brilhante e braços azuis de poeira';

  @override
  String get onboardingAiPromptSpace4 => 'um astronauta à deriva sobre a Terra ao nascer do sol, fina atmosfera azul';

  @override
  String get onboardingAiPromptSpace5 => 'um eclipse solar total sobre uma cordilheira silenciosa';

  @override
  String get onboardingAiPromptSynthwave1 => 'um pôr do sol synthwave com sol listrado sobre uma grade neon brilhante';

  @override
  String get onboardingAiPromptSynthwave2 => 'um carro retrô rumo a um sol magenta numa estrada costeira vazia';

  @override
  String get onboardingAiPromptSynthwave3 => 'montanhas de arame sob um céu roxo estrelado e um sol cromado';

  @override
  String get onboardingAiPromptSynthwave4 =>
      'uma praia synthwave com silhuetas de palmeiras e horizonte rosa brilhante';

  @override
  String get onboardingAiPromptSynthwave5 => 'um skyline retrô à noite em névoa de neon rosa e ciano';

  @override
  String get onboardingAiPromptPixelArt1 => 'uma cabana em pixel art numa floresta nevada, janelas quentes à noite';

  @override
  String get onboardingAiPromptPixelArt2 => 'uma cidade litorânea em pixel art ao pôr do sol com barcos no porto';

  @override
  String get onboardingAiPromptPixelArt3 => 'um castelo em pixel art numa ilha flutuante acima das nuvens';

  @override
  String get onboardingAiPromptPixelArt4 => 'um céu noturno em pixel art sobre um lago calmo com vaga-lumes';

  @override
  String get onboardingAiPromptPixelArt5 => 'um caminho de cerejeiras em flor em pixel art até um pequeno templo';

  @override
  String get onboardingAiPromptRender3d1 => 'um render 3D de formas de argila macias em pastéis com sombras suaves';

  @override
  String get onboardingAiPromptRender3d2 => 'um render 3D de uma ilha flutuante com cachoeira e árvores';

  @override
  String get onboardingAiPromptRender3d3 => 'um render 3D de ondas de vidro azul e violeta sob luz de estúdio';

  @override
  String get onboardingAiPromptRender3d4 => 'um render 3D de um quarto em miniatura dentro de um cubo brilhante';

  @override
  String get onboardingAiPromptRender3d5 => 'um render 3D de bolhas cromadas flutuando sobre um mar rosa calmo';

  @override
  String get onboardingAiPromptOilPainting1 =>
      'uma pintura a óleo de um mar tempestuoso com um barco sob um céu dramático';

  @override
  String get onboardingAiPromptOilPainting2 =>
      'uma pintura a óleo de um campo de papoulas ao sol com uma fazenda distante';

  @override
  String get onboardingAiPromptOilPainting3 =>
      'uma pintura a óleo de um porto enevoado ao amanhecer com barcos antigos';

  @override
  String get onboardingAiPromptOilPainting4 =>
      'uma pintura a óleo de um caminho outonal com pinceladas grossas e ricas';

  @override
  String get onboardingAiPromptOilPainting5 => 'uma pintura a óleo de uma cidade com canal ao luar e janelas quentes';

  @override
  String get onboardingAiPromptUkiyoE1 => 'uma grande onda ukiyo-e sob uma lua pálida e uma montanha nevada distante';

  @override
  String get onboardingAiPromptUkiyoE2 => 'uma vila nevada ukiyo-e à noite com lanternas de papel acesas';

  @override
  String get onboardingAiPromptUkiyoE3 => 'uma cena ukiyo-e de garças voando sobre montanhas nebulosas ao amanhecer';

  @override
  String get onboardingAiPromptUkiyoE4 => 'uma ponte de madeira ukiyo-e sob cerejeiras em flor num dia de primavera';

  @override
  String get onboardingAiPromptUkiyoE5 => 'um sol vermelho ukiyo-e sobre um mar índigo calmo com pequenos barcos';

  @override
  String wallpaperWotdByline(String name) {
    return 'por $name';
  }

  @override
  String get wallpaperWotdPastPicks => 'Escolhas anteriores';

  @override
  String wallpaperWotdPickedOn(String wallpaper, String date) {
    return '$wallpaper, escolhido em $date';
  }

  @override
  String get wallpaperWotdSeePast => 'Ver papéis de parede do dia anteriores';

  @override
  String get wallpaperWotdTitle => 'Papel de parede do dia';

  @override
  String get wallpaperYourProfile => 'Seu perfil';

  @override
  String get widgetsSettingsTitle => 'Widgets';

  @override
  String get widgetsSettingsSubtitle => 'Adicione o Prism à Tela de Início e à Tela Bloqueada';

  @override
  String get widgetsGuideTitle => 'Adicionar widgets do Prism';

  @override
  String get widgetsGuideHomeTab => 'Tela de Início';

  @override
  String get widgetsGuideLockTab => 'Tela Bloqueada';

  @override
  String get widgetsGuideHomeStep1 =>
      'Toque e mantenha pressionada uma área vazia da Tela de Início até os apps tremerem.';

  @override
  String get widgetsGuideHomeStep2 => 'Toque em Editar e depois em Adicionar Widget.';

  @override
  String get widgetsGuideHomeStep3 => 'Busque por Prism, escolha um tamanho e toque em Adicionar Widget.';

  @override
  String get widgetsGuideLockStep1 => 'Toque e mantenha pressionada a Tela Bloqueada e toque em Personalizar.';

  @override
  String get widgetsGuideLockStep2 => 'Toque em Tela Bloqueada e depois na área de widgets abaixo do relógio.';

  @override
  String get widgetsGuideLockStep3 => 'Escolha Prism e toque em um widget para adicioná-lo.';

  @override
  String get widgetsGuideHomeIllustration => 'Um celular com o widget Papel de parede do dia na Tela de Início';

  @override
  String get widgetsGuideLockIllustration => 'Um celular com widgets do Prism na Tela Bloqueada';

  @override
  String get widgetsGuideDone => 'OK';

  @override
  String get widgetsCardTitle => 'O papel de parede do dia na sua Tela de Início';

  @override
  String get widgetsCardBody => 'Adicione o widget e veja um papel de parede novo todo dia.';

  @override
  String get widgetsCardAction => 'Mostrar como';

  @override
  String get widgetsCardDismiss => 'Dispensar';

  @override
  String get foldersTitle => 'Pastas';

  @override
  String get foldersSaveToFolder => 'Salvar na pasta';

  @override
  String get foldersAddToFolder => 'Adicionar à pasta';

  @override
  String get foldersNewFolder => 'Nova pasta';

  @override
  String get foldersNameHint => 'Nome da pasta';

  @override
  String get foldersCreate => 'Criar';

  @override
  String get foldersCreateFolder => 'Criar pasta';

  @override
  String get foldersSuggested => 'Sugerida';

  @override
  String get foldersNewTag => 'Nova';

  @override
  String foldersItemCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede',
      one: '1 papel de parede',
      zero: 'Nenhum papel de parede',
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
      other: 'Salvo em $countString pastas.',
      one: 'Salvo em 1 pasta.',
    );
    return '$_temp0';
  }

  @override
  String get foldersUpdated => 'Pastas atualizadas.';

  @override
  String get foldersSaveFailed => 'Não foi possível salvar nas pastas. Tente novamente.';

  @override
  String get foldersUpdateFailed => 'Não foi possível atualizar a pasta. Tente novamente.';

  @override
  String get foldersRename => 'Renomear';

  @override
  String get foldersRenameTitle => 'Renomear pasta';

  @override
  String get foldersDelete => 'Excluir';

  @override
  String foldersDeleteTitle(String name) {
    return 'Excluir $name?';
  }

  @override
  String get foldersDeleteMessage => 'Os papéis de parede continuam nos seus favoritos.';

  @override
  String get foldersDeleteConfirm => 'Excluir pasta';

  @override
  String get foldersDeleted => 'Pasta excluída.';

  @override
  String get foldersRemoveTitle => 'Remover desta pasta?';

  @override
  String get foldersRemoveMessage => 'Continua nos seus favoritos.';

  @override
  String get foldersRemoveConfirm => 'Remover';

  @override
  String get foldersRemoved => 'Removido da pasta.';

  @override
  String get foldersEmptyTitle => 'Esta pasta está vazia';

  @override
  String get foldersEmptyBody => 'Segure o coração em um papel de parede para salvá-lo aqui.';

  @override
  String get foldersLoadError => 'Não foi possível carregar esta pasta.';

  @override
  String get foldersNotFoundTitle => 'Esta pasta não está disponível';

  @override
  String get foldersNotFoundBody => 'Talvez ela tenha sido excluída.';

  @override
  String get foldersSignInFeature => 'pastas';

  @override
  String get foldersMoreOptions => 'Mais opções';

  @override
  String get foldersSuggestionLockScreen => 'Tela de bloqueio';

  @override
  String get foldersSuggestionHomeScreen => 'Tela inicial';

  @override
  String get moodDreamyTitle => 'Sonhador';

  @override
  String get moodDreamyBody => 'Céus suaves e luz pastel.';

  @override
  String get moodDarkQuietTitle => 'Escuro e tranquilo';

  @override
  String get moodDarkQuietBody => 'Pouca luz, fácil para os olhos.';

  @override
  String get moodBrightBoldTitle => 'Vibrante e marcante';

  @override
  String get moodBrightBoldBody => 'Muita cor para acordar sua tela.';

  @override
  String get moodMinimalTitle => 'Minimalista';

  @override
  String get moodMinimalBody => 'Formas simples e espaço para respirar.';

  @override
  String get moodSpatialReadyTitle => 'Pronto para cena espacial';

  @override
  String get moodSpatialReadyBody => 'Feito para se destacar como cena espacial.';

  @override
  String get moodDepthReadyTitle => 'Pronto para efeito de profundidade';

  @override
  String get moodDepthReadyBody => 'O sujeito fica na frente do seu relógio.';

  @override
  String get moodChipRowLabel => 'Humores';

  @override
  String get moodSeeAll => 'Ver tudo';

  @override
  String moodSeeAllHint(String mood) {
    return 'Abre todos os papéis de parede de $mood';
  }

  @override
  String get moodLoadError => 'Não foi possível carregar estes papéis de parede';

  @override
  String get moodEmptyTitle => 'Ainda não há papéis de parede aqui';

  @override
  String get moodEmptyBody => 'Novos papéis de parede chegam todos os dias.';

  @override
  String wallpaperHistoryTileSemantic(String current, String target, String date) {
    return '${current}Defina novamente. $target, $date';
  }

  @override
  String get wallpaperHistoryTitle => 'Histórico do papel de parede';

  @override
  String get wallpaperLibraryHistoryBody =>
      'Os papéis de parede que você definir aparecerão aqui para que possa defini-los novamente.';

  @override
  String get wallpaperLibraryHistoryTitle => 'Histórico do papel de parede';

  @override
  String get wallpaperLibraryOpenHistory => 'Abrir histórico';

  @override
  String get wallpaperRecentlySet => 'Definido recentemente';

  @override
  String get wallpaperSetAgain => 'Defina este papel de parede novamente';

  @override
  String get wallpaperSort => 'Organizar';

  @override
  String get tasteQuizTitle => 'Escolha a que você mais gosta';

  @override
  String get tasteQuizWildCard => 'Coringa';

  @override
  String tasteQuizProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString de $totalString';
  }

  @override
  String tasteQuizProgressLabel(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Rodada $currentString de $totalString';
  }

  @override
  String get tasteQuizSkip => 'Pular';

  @override
  String tasteQuizPickLabel(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Escolher este papel de parede, $positionString de $totalString';
  }

  @override
  String get tasteQuizTuningTitle => 'Ajustando seu feed';

  @override
  String tasteQuizSummaryFull(String tone, String density, String tag) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Escuro', 'other': 'Claro'});
    String _temp1 = intl.Intl.selectLogic(density, {'minimal': 'minimalista', 'other': 'detalhado'});
    return '$_temp0, $_temp1, um toque de $tag';
  }

  @override
  String tasteQuizSummaryToneDensity(String tone, String density) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Escuro', 'other': 'Claro'});
    String _temp1 = intl.Intl.selectLogic(density, {'minimal': 'minimalista', 'other': 'detalhado'});
    return '$_temp0 e $_temp1';
  }

  @override
  String tasteQuizSummaryToneTag(String tone, String tag) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Escuro', 'other': 'Claro'});
    return '$_temp0, com um toque de $tag';
  }

  @override
  String tasteQuizSummaryDensityTag(String density, String tag) {
    String _temp0 = intl.Intl.selectLogic(density, {'minimal': 'Minimalista', 'other': 'Detalhado'});
    return '$_temp0, com um toque de $tag';
  }

  @override
  String tasteQuizSummaryTone(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'dark': 'Papéis de parede mais escuros',
      'other': 'Papéis de parede mais claros',
    });
    return '$_temp0';
  }

  @override
  String tasteQuizSummaryDensity(String density) {
    String _temp0 = intl.Intl.selectLogic(density, {
      'minimal': 'Papéis de parede mais minimalistas',
      'other': 'Papéis de parede mais detalhados',
    });
    return '$_temp0';
  }

  @override
  String tasteQuizSummaryTag(String tag) {
    return 'Mais papéis de parede de $tag';
  }

  @override
  String get tasteQuizSummaryReady => 'Seu feed está pronto';

  @override
  String get tasteQuizRetake => 'Refazer Isso ou aquilo';

  @override
  String get tasteQuizRetakeFailed =>
      'Não foi possível carregar os papéis de parede. Verifique sua conexão e tente novamente.';

  @override
  String get foldersPublic => 'Pública';

  @override
  String get foldersMakePublic => 'Tornar pública';

  @override
  String get foldersMakePrivate => 'Tornar privada';

  @override
  String get foldersMakePublicTitle => 'Tornar esta pasta pública?';

  @override
  String get foldersMakePublicMessage =>
      'Qualquer pessoa no Prism poderá ver o nome e os papéis de parede, seguir a pasta e abrir o link dela. Os links que você compartilhar mantêm a prévia mesmo se você tornar a pasta privada depois.';

  @override
  String get foldersMakePrivateTitle => 'Tornar esta pasta privada?';

  @override
  String get foldersMakePrivateMessage =>
      'Só você vai vê-la. O link deixa de funcionar e os seguidores perdem o acesso.';

  @override
  String get foldersMadePublic => 'Esta pasta agora é pública.';

  @override
  String get foldersMadePrivate => 'Esta pasta agora é privada.';

  @override
  String get foldersPublicNameRefused => 'Renomeie esta pasta para torná-la pública.';

  @override
  String get foldersHiddenRefused => 'Esta pasta foi ocultada após denúncias, por isso não pode ser pública.';

  @override
  String get foldersLimitRefused => 'Você mudou as pastas muitas vezes hoje. Tente novamente amanhã.';

  @override
  String get foldersFollow => 'Seguir';

  @override
  String get foldersFollowing => 'Seguindo';

  @override
  String foldersFollowerCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString seguidores',
      one: '1 seguidor',
      zero: 'Nenhum seguidor',
    );
    return '$_temp0';
  }

  @override
  String foldersByOwner(String name) {
    return 'Por $name';
  }

  @override
  String get foldersShare => 'Compartilhar pasta';

  @override
  String get foldersReport => 'Denunciar pasta';

  @override
  String get foldersUnavailableTitle => 'Esta pasta é privada ou não existe mais';

  @override
  String get foldersUnavailableBody => 'O dono pode ter tornado a pasta privada ou excluído.';

  @override
  String get foldersFollowFailed => 'Não foi possível atualizar o seguimento. Tente novamente.';

  @override
  String get foldersYouFollow => 'Pastas que você segue';

  @override
  String get foldersPublicEmptyTitle => 'Ainda não há papéis de parede aqui';

  @override
  String get foldersPublicEmptyBody => 'Os novos papéis de parede aparecem aqui quando o dono os adiciona.';

  @override
  String get notifSettingFolders => 'Pastas que você segue';

  @override
  String get notifSettingFoldersDescription => 'Novos papéis de parede nas pastas que você segue, uma vez por dia';

  @override
  String notifPushFolderDigestTitleOne(String folderName) {
    return 'Novidade em $folderName';
  }

  @override
  String notifPushFolderDigestTitleMore(String folderName, int count) {
    return 'Novidades em $folderName e mais $count';
  }

  @override
  String get historySetAndDownloaded => 'Definido e baixado';

  @override
  String get historyDownloaded => 'Baixado';

  @override
  String get historyRecentlyViewed => 'Vistos recentemente';

  @override
  String get historySyncedNote => 'Salvo na sua conta, então eles voltam em um celular novo.';

  @override
  String get historySyncedNoteGuest => 'Entre para manter esses itens em um celular novo.';

  @override
  String get historyActionSet => 'Definido';

  @override
  String get historyActionDownloaded => 'Baixado';

  @override
  String historySyncedTileLabel(String action, String time) {
    return '$action às $time';
  }

  @override
  String get historyClearSyncedBody =>
      'Isso remove a lista aqui e na sua conta. Seus papéis de parede e downloads continuam como estão.';

  @override
  String get historyClearViewedTitle => 'Limpar vistos recentemente?';

  @override
  String get historyClearViewedBody => 'Isso remove da lista e do Início os papéis de parede que você abriu.';

  @override
  String get historyClearViewedAction => 'Limpar vistos recentemente';

  @override
  String get historyEmptyBodyAndroid =>
      'Os papéis de parede que você define ou baixa aparecem aqui, para você encontrar de novo.';

  @override
  String get historyEmptyBodyIos => 'Os papéis de parede que você baixa aparecem aqui, para você encontrar de novo.';

  @override
  String get historyViewedEmptyTitle => 'Nada visto ainda';

  @override
  String get historyViewedEmptyBody => 'Os papéis de parede que você abre aparecem aqui, para você encontrar de novo.';

  @override
  String get historyViewedOffTitle => 'O histórico de visualização está desativado';

  @override
  String get historyViewedOffBody =>
      'Ative Salvar histórico de visualização para ver aqui os papéis de parede que você abrir.';

  @override
  String get historyViewedOffAction => 'Ativar';

  @override
  String historyViewedTileLabel(String time) {
    return 'Abrir papel de parede, visto às $time';
  }

  @override
  String get pickUpTitle => 'Continue de onde parou';

  @override
  String pickUpTileLabel(int index, int count) {
    return 'Abrir papel de parede $index de $count';
  }

  @override
  String get settingsSaveViewingHistory => 'Salvar histórico de visualização';

  @override
  String get settingsSaveViewingHistoryBody =>
      'Mostra os papéis de parede que você abre no Histórico e no Início. Desligar isso limpa a lista.';

  @override
  String get historyClearFailed => 'Não foi possível limpar o histórico. Verifique sua conexão e tente de novo.';

  @override
  String get wallpaperAutoRotateSourceFolder => 'Pasta';

  @override
  String wallpaperAutoRotateSourceFolderNamed(String folder) {
    return 'Pasta: $folder';
  }

  @override
  String wallpaperAutoRotateNounFolder(String folder) {
    return '$folder';
  }

  @override
  String get wallpaperAutoRotateTooFewFolder =>
      'Esta pasta precisa de pelo menos 2 papéis de parede que possam rotacionar. Os papéis de parede do Prism rotacionam depois que você os baixa.';

  @override
  String get wallpaperAutoRotateOpenFolder => 'Abrir pasta';

  @override
  String get wallpaperAutoRotatePickFolder => 'Escolha uma pasta';

  @override
  String get wallpaperAutoRotateNoFolders =>
      'Você ainda não tem pastas. Salve um papel de parede em uma pasta e depois escolha-a aqui.';

  @override
  String wallpaperAutoRotateConfirmFolderTitle(String folder) {
    return 'Rotacionar $folder?';
  }

  @override
  String get wallpaperAutoRotateConfirmFolderBody =>
      'Seu papel de parede muda para um desta pasta, de acordo com a programação abaixo.';

  @override
  String get wallpaperAutoRotateConfirmFolderAction => 'Rotacionar esta pasta';

  @override
  String wallpaperAutoRotateStoppedFolderDeleted(String folder) {
    return 'A rotação automática está desativada porque a pasta $folder foi excluída.';
  }

  @override
  String wallpaperAutoRotateStoppedFolderEmpty(String folder) {
    return 'A rotação automática está desativada porque a pasta $folder tem menos de 2 papéis de parede.';
  }

  @override
  String get foldersRotateThisFolder => 'Rotacionar esta pasta';

  @override
  String get foldersRotating => 'Rotacionando';

  @override
  String get foldersRotatingDescription => 'A rotação automática usa esta pasta';

  @override
  String get wallpaperAccentResetHint => 'Toque e segure para ações, incluindo Restaurar original';

  @override
  String get wallRequestsTitle => 'Pedidos de papel de parede';

  @override
  String get wallRequestsTabTop => 'Top';

  @override
  String get wallRequestsTabNew => 'Novos';

  @override
  String get wallRequestsTabFilled => 'Atendidos';

  @override
  String get wallRequestsAsk => 'Pedir um papel de parede';

  @override
  String get wallRequestsEmptyTopTitle => 'Nenhum pedido ainda';

  @override
  String get wallRequestsEmptyTopBody =>
      'Peça o papel de parede que você não encontra. Outras pessoas podem apoiar o pedido.';

  @override
  String get wallRequestsEmptyFilledTitle => 'Nada atendido ainda';

  @override
  String get wallRequestsEmptyFilledBody => 'Os pedidos atendidos aparecem aqui, com o papel de parede que os atendeu.';

  @override
  String get wallRequestsLoadFailed => 'Não foi possível carregar os pedidos';

  @override
  String get wallRequestsRetry => 'Tentar novamente';

  @override
  String wallRequestVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
      zero: 'Nenhum voto',
    );
    return '$_temp0';
  }

  @override
  String get wallRequestUpvote => 'Apoiar';

  @override
  String get wallRequestRemoveUpvote => 'Remover apoio';

  @override
  String get wallRequestMine => 'Seu pedido';

  @override
  String get wallRequestSomeone => 'Um usuário do Prism';

  @override
  String wallRequestFilledByCreator(String name) {
    return 'Atendido por $name';
  }

  @override
  String get wallRequestFilledByStudio => 'Feito pelo Prism Studio';

  @override
  String get wallRequestOpenWall => 'Abrir o papel de parede';

  @override
  String get wallRequestMoreActions => 'Mais ações';

  @override
  String get wallRequestReport => 'Denunciar pedido';

  @override
  String get wallRequestHide => 'Ocultar pedido';

  @override
  String get wallRequestUnhide => 'Mostrar pedido';

  @override
  String get wallRequestHiddenLabel => 'Oculto';

  @override
  String get wallRequestSheetTitle => 'Pedir um papel de parede';

  @override
  String get wallRequestSheetHint => 'Descreva, por exemplo: montanhas escuras e minimalistas';

  @override
  String get wallRequestSheetTags => 'Tags, até 3';

  @override
  String get wallRequestSheetSubmit => 'Enviar pedido';

  @override
  String get wallRequestSignIn => 'Entre para pedir papéis de parede e apoiá-los.';

  @override
  String get wallRequestDuplicateTitle => 'Alguém já pediu isso';

  @override
  String get wallRequestDuplicateBody => 'Apoie o pedido para que os criadores vejam mais rápido.';

  @override
  String get wallRequestUpvoteInstead => 'Apoiar este em vez disso';

  @override
  String get wallRequestCreateAnyway => 'Enviar o meu mesmo assim';

  @override
  String get wallRequestDuplicateMine => 'Você já pediu isso';

  @override
  String get wallRequestDuplicateVoted => 'Você já apoiou isso';

  @override
  String get wallRequestEditText => 'Editar meu pedido';

  @override
  String get wallRequestCreated => 'Pedido enviado. Avisamos quando for atendido.';

  @override
  String get wallRequestUpvoted => 'Apoiado. Avisamos quando for atendido.';

  @override
  String get wallRequestErrorText => 'Use de 3 a 80 caracteres e seja gentil.';

  @override
  String get wallRequestErrorLimit => 'Você pode fazer 3 pedidos por dia. Tente amanhã.';

  @override
  String get wallRequestErrorOwn => 'Você não pode apoiar o seu próprio pedido.';

  @override
  String get wallRequestErrorClosed => 'Este pedido já foi atendido.';

  @override
  String get wallRequestErrorGone => 'Este pedido não está mais disponível.';

  @override
  String get wallRequestErrorGeneric => 'Algo deu errado. Tente novamente.';

  @override
  String get searchRequestPrompt => 'Não encontrou?';

  @override
  String get searchRequestAction => 'Peça';

  @override
  String get discoverRequestsTitle => 'Pedidos de papel de parede';

  @override
  String get discoverRequestsSubtitle => 'Peça um papel de parede ou apoie um pedido';

  @override
  String get uploadFillsRequest => 'Atende a um pedido';

  @override
  String get uploadFillsRequestHint => 'Opcional. Escolha o pedido que este papel de parede atende.';

  @override
  String get uploadFillsRequestClear => 'Remover pedido';

  @override
  String get requestPickerTitle => 'Qual pedido ele atende?';

  @override
  String get requestPickerSearch => 'Pesquisar pedidos';

  @override
  String get requestPickerEmpty => 'Nenhum pedido aberto corresponde';

  @override
  String get notifPushWallRequestFilledTitle => 'Seu pedido chegou';

  @override
  String notifPushWallRequestFilledBody(String requestText) {
    return '$requestText';
  }

  @override
  String get wallRequestAgeNow => 'Agora mesmo';

  @override
  String wallRequestAgeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Há $count minutos', one: 'Há 1 minuto');
    return '$_temp0';
  }

  @override
  String wallRequestAgeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Há $count horas', one: 'Há 1 hora');
    return '$_temp0';
  }

  @override
  String wallRequestAgeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Há $count dias', one: 'Há 1 dia');
    return '$_temp0';
  }

  @override
  String wallRequestAgeWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Há $count semanas', one: 'Há 1 semana');
    return '$_temp0';
  }

  @override
  String get wallRequestErrorAccountAge => 'Sua conta poderá fazer pedidos e votar quando tiver 10 dias.';

  @override
  String get adminFillsRequest => 'Atende o pedido';

  @override
  String get wallRemixAction => 'Remixar';

  @override
  String get wallRemixActionTooltip => 'Remixar este papel de parede com IA';

  @override
  String wallRemixingChip(String title, String creator) {
    return 'Remixando $title de $creator';
  }

  @override
  String get wallRemixDropLinkTooltip => 'Remover vínculo de remix';

  @override
  String get wallRemixUntitled => 'Sem título';

  @override
  String get wallRemixUnknownCreator => 'um criador do Prism';

  @override
  String get wallRemixesTitle => 'Remixes';

  @override
  String wallRemixesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count remixes', one: '1 remix');
    return '$_temp0';
  }

  @override
  String wallRemixOpenRemixLabel(String creator) {
    return 'Abrir remix de $creator';
  }

  @override
  String wallRemixOfLabel(String title, String creator) {
    return 'Remix de $title de $creator';
  }

  @override
  String get wallRemixOfTooltip => 'Abrir o papel de parede original';

  @override
  String get economyAiSubmitPromptNotice => 'Qualquer pessoa pode ver seu prompt e remixar este papel de parede.';

  @override
  String get notifPushWallRemixedTitle => 'Seu papel de parede foi remixado';

  @override
  String notifPushWallRemixedBody(String remixerName, String wallTitle) {
    return '$remixerName remixou $wallTitle.';
  }

  @override
  String notifPushWallRemixedBodyUntitled(String remixerName) {
    return '$remixerName remixou seu papel de parede.';
  }

  @override
  String get wallMetadataDescription => 'Descrição';

  @override
  String get wallMetadataEdit => 'Editar detalhes';

  @override
  String get wallResubmitAction => 'Corrigir e reenviar';

  @override
  String get wallResubmitChooseImage => 'Escolher imagem';

  @override
  String get wallResubmitImageMissing =>
      'A imagem original não está mais disponível. Escolha-a novamente para continuar editando.';

  @override
  String get wallResubmitImageKept => 'Imagem original pronta';

  @override
  String get wallResubmitTitle => 'Corrija seu envio';

  @override
  String get wallUploadUseLastDetails => 'Usar últimos detalhes';

  @override
  String get wallUploadLastDetailsUnavailable => 'Não há detalhes anteriores neste dispositivo.';

  @override
  String get wallUploadWithdraw => 'Retirar envio';

  @override
  String get wallUploadWithdrawTitle => 'Retirar este envio?';

  @override
  String get wallUploadWithdrawBody => 'Isso remove o envio da análise e exclui os arquivos enviados.';

  @override
  String get wallUploadWithdrawn => 'Envio retirado';

  @override
  String get wallUploadDeleteHistory => 'Excluir do histórico';

  @override
  String get wallMetadataInvalid => 'Confira o texto e as tags e tente novamente.';

  @override
  String get wallUploadOwnerChanged => 'Sua conta mudou. Abra este envio novamente.';

  @override
  String get wallResubmitLimit => 'Este papel de parede atingiu os três reenvios vinculados.';

  @override
  String get wallResubmitUnsupported =>
      'Escolha novamente a imagem original. Os detalhes da origem de IA não podem ser reutilizados.';

  @override
  String get wallResubmitUnavailable => 'Não foi possível carregar este envio rejeitado. Tente novamente.';

  @override
  String get wallMetadataEditDetails => 'Editar detalhes';

  @override
  String get wallMetadataApprovedHelp =>
      'Altere o título, a descrição e as tags. A imagem e a categoria permanecem iguais.';

  @override
  String get wallMetadataPendingHelp => 'Atualize estes detalhes antes da análise do seu papel de parede.';

  @override
  String get wallMetadataSave => 'Salvar detalhes';

  @override
  String get wallMetadataSaved => 'Detalhes salvos';

  @override
  String get wallMetadataDiscardTitle => 'Descartar alterações?';

  @override
  String get wallMetadataDiscardBody => 'Seus detalhes não salvos serão perdidos.';

  @override
  String get wallMetadataDiscard => 'Descartar alterações';

  @override
  String get wallMetadataReload => 'Recarregar detalhes';

  @override
  String get wallMetadataReloadTitle => 'Recarregar os detalhes atuais?';

  @override
  String get wallMetadataReloadBody => 'Isso substitui seus detalhes não salvos pela versão atual.';

  @override
  String get wallMetadataConflict =>
      'Estes detalhes foram alterados em outro lugar. Suas edições continuam aqui. Recarregue os detalhes atuais antes de salvar.';

  @override
  String get wallMetadataStatusChanged =>
      'O status de análise deste papel de parede mudou. Suas edições não foram salvas.';

  @override
  String get wallMetadataMissing => 'Este papel de parede não está mais disponível. Suas edições não foram salvas.';

  @override
  String get wallMetadataDenied => 'Você não tem permissão para editar este papel de parede.';

  @override
  String get wallMetadataSignedOut => 'Entre novamente para editar este papel de parede.';

  @override
  String get wallMetadataDailyLimit => 'Você atingiu o limite de edições de hoje. Tente novamente amanhã.';

  @override
  String get wallMetadataUnavailable => 'Não foi possível salvar os detalhes. Verifique sua conexão e tente novamente.';

  @override
  String get wallMetadataLoadFailed => 'Não foi possível carregar os detalhes';

  @override
  String get wallMetadataHistory => 'Histórico de edições';

  @override
  String get wallMetadataHistoryEmpty => 'Nenhuma edição dos detalhes ainda';

  @override
  String get wallMetadataHistoryEmptyBody =>
      'As alterações no título, na descrição e nas tags aprovados aparecem aqui.';

  @override
  String get wallMetadataHistoryFailed => 'Não foi possível carregar o histórico de edições';

  @override
  String get wallMetadataBefore => 'Antes';

  @override
  String get wallMetadataAfter => 'Depois';

  @override
  String get wallMetadataRevert => 'Reverter edição';

  @override
  String get wallMetadataRevertTitle => 'Reverter esta edição?';

  @override
  String get wallMetadataRevertBody =>
      'Restaure apenas o título, a descrição e as tags anteriores mostrados aqui. A imagem e o status de análise não mudarão.';

  @override
  String get wallMetadataReverted => 'Edição revertida';

  @override
  String get wallMetadataLoadMore => 'Carregar mais edições';

  @override
  String get wallMetadataAbsent => 'Não definido';

  @override
  String wallMetadataResubmitted(int attempt) {
    return 'Reenviado · tentativa $attempt de 3';
  }

  @override
  String get wallMetadataPreviousReason => 'Motivo da rejeição anterior';

  @override
  String get wallMetadataContextUnavailable => 'Detalhes do reenvio indisponíveis';

  @override
  String get reportSheetMessage =>
      'Conte o que deu errado. O Prism nunca adiciona seu e-mail nem tokens de acesso. Confira as capturas de tela antes de enviar.';

  @override
  String get reportTopicCrashFreeze => 'Falha/travamento';

  @override
  String get reportTopicWallpaperWontSet => 'O papel de parede não é aplicado';

  @override
  String get reportTopicLooksBroken => 'Parece quebrado';

  @override
  String get reportTopicSlow => 'Lento';

  @override
  String get reportTopicOther => 'Outro';

  @override
  String get reportNoteHint => 'O que aconteceu? O que você esperava?';

  @override
  String get reportScreenshotTitle => 'Captura de tela';

  @override
  String get reportScreenshotEmpty => 'Mostre o que você está vendo.';

  @override
  String get reportScreenshotAttached => 'Toque para ver. Confira antes de enviar.';

  @override
  String get reportAddScreenshot => 'Adicionar captura de tela';

  @override
  String get reportRemoveScreenshot => 'Remover';

  @override
  String get reportViewScreenshot => 'Ver captura de tela';

  @override
  String get reportIncludeDiagnostics => 'Incluir informações do dispositivo e registros recentes';

  @override
  String get reportShowDiagnostics => 'Mostrar o que está incluído';

  @override
  String get reportHideDiagnostics => 'Ocultar detalhes';

  @override
  String get reportSend => 'Enviar relatório';

  @override
  String get reportShareAsFile => 'Compartilhar como arquivo';

  @override
  String reportSent(String reference) {
    return 'Obrigado, relatório enviado. Referência $reference';
  }

  @override
  String get reportCouldNotSend => 'Não foi possível enviar';

  @override
  String get reportCouldNotSendBody =>
      'Verifique sua conexão e tente novamente, ou compartilhe o relatório como arquivo.';

  @override
  String get reportShareInstead => 'Compartilhar em vez disso';

  @override
  String get reportShakeToReport => 'Agitar para relatar';

  @override
  String get reportShakeToReportSubtitle => 'Agite o celular em qualquer tela para relatar um problema';

  @override
  String get accountShowAiWallpapers => 'Mostrar papéis de parede gerados por IA';

  @override
  String get accountShowAiWallpapersSubtitle => 'Desative para ver só papéis de parede feitos por pessoas';

  @override
  String get accountShowAiWallpapersFootnote =>
      'Ocultar papéis de parede de IA nunca oculta seus próprios envios nem seus favoritos.';

  @override
  String get wallpaperFeedHideAi => 'Ocultar IA';

  @override
  String get wallpaperAiGenerated => 'Gerado por IA';

  @override
  String wallpaperAiMadeWith(String model) {
    return 'Feito com $model';
  }

  @override
  String get wallpaperAiMadeWithUnknown => 'Feito com IA';

  @override
  String get wallpaperAiReportWrongLabel => 'Denunciar rótulo errado';

  @override
  String get feedNoHumanWalls => 'Ainda não há papéis de parede feitos por pessoas aqui';

  @override
  String get feedShowAiWalls => 'Mostrar papéis de parede de IA';

  @override
  String get dailyMomentTitle => 'Momento diário';

  @override
  String get dailyMomentStreakTitle => 'Sequência diária';

  @override
  String get dailyMomentChestTitle => 'Baú diário';

  @override
  String get dailyMomentSpinTitle => 'Giro grátis';

  @override
  String get dailyMomentUnavailable => 'Esta recompensa não está mais disponível hoje.';

  @override
  String get dailyMomentError => 'Não foi possível carregar a recompensa. Tente novamente.';

  @override
  String dailyMomentStreakReceipt(int coins, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins moedas recebidas',
      one: '$coins moeda recebida',
    );
    String _temp1 = intl.Intl.pluralLogic(days, locale: localeName, other: '$days dias', one: '$days dia');
    return '$_temp0 · sequência de $_temp1';
  }

  @override
  String get challengeTitle => 'Desafio semanal';

  @override
  String get challengeRules => 'Até 3 criações, revisadas antes de aparecerem.';

  @override
  String challengeVotingRules(String date) {
    return 'Vote em outros criadores até $date UTC.';
  }

  @override
  String get challengeUpload => 'Enviar uma criação';

  @override
  String get challengeAi => 'Criar com IA';

  @override
  String get challengeTop => 'Destaques';

  @override
  String get challengeNew => 'Recentes';

  @override
  String get challengePast => 'Desafios anteriores';

  @override
  String get challengeEmpty => 'As criações aprovadas aparecerão aqui.';

  @override
  String get challengeWaiting => 'A votação terminou. Aguardamos as revisões antes de escolher o vencedor.';

  @override
  String get challengeClosed => 'Este desafio terminou.';

  @override
  String get challengeScheduled => 'Este desafio ainda não começou.';

  @override
  String get challengeNoWinner => 'Este desafio não tem vencedor.';

  @override
  String challengeWinner(String name) {
    return 'Vencedor · $name';
  }

  @override
  String get challengeVote => 'Votar';

  @override
  String get challengeUnvote => 'Remover voto';

  @override
  String challengeVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
      zero: '0 votos',
    );
    return '$_temp0';
  }

  @override
  String get dailyMomentCosmetic => 'Item cosmético adicionado à sua coleção';

  @override
  String dailyMomentReward(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins moedas recebidas',
      one: '$coins moeda recebida',
    );
    return '$_temp0';
  }

  @override
  String get dailyMomentChestBody => 'Abra o baú de hoje quando quiser.';

  @override
  String get dailyMomentSpinBody => 'Seu giro grátis está pronto.';

  @override
  String dailyMomentBalance(int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coins moedas', one: '$coins moeda');
    return 'Saldo: $_temp0';
  }

  @override
  String get dailyMomentDone => 'Concluído';

  @override
  String get dailyMomentRetry => 'Tentar novamente';

  @override
  String get dailyMomentContinue => 'Continuar';

  @override
  String get dailyMomentOpenFree => 'Abrir baú grátis';

  @override
  String dailyMomentOpenChest(int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coins moedas', one: '$coins moeda');
    return 'Abrir por $_temp0';
  }

  @override
  String get dailyMomentSpinAction => 'Girar grátis';

  @override
  String get dailyMomentClose => 'Fechar momento diário';

  @override
  String get dailyMomentToday => 'Hoje';

  @override
  String get dailyMomentReady => 'As recompensas diárias estão prontas';

  @override
  String get dailyMomentComplete => 'Hoje está concluído';

  @override
  String get dailyMomentResume => 'Continuar momento diário';

  @override
  String get dailyMomentMore => 'Mais';

  @override
  String get dailyMomentQuests => 'Missões';

  @override
  String get dailyMomentChestLeft => 'Baú diário disponível';

  @override
  String get dailyMomentSpinLeft => 'Giro grátis disponível';

  @override
  String get dailyMomentStreakLeft => 'Sequência diária disponível';

  @override
  String get challengeShare => 'Compartilhar desafio';

  @override
  String get challengeRemove => 'Remover desafio';

  @override
  String challengeContext(String theme) {
    return 'Desafio · $theme';
  }

  @override
  String get challengeError => 'Não foi possível carregar o desafio. Tente novamente.';

  @override
  String get challengeVoteError => 'Não foi possível salvar seu voto. Tente novamente.';

  @override
  String get challengeSignIn => 'Entre para participar ou votar.';

  @override
  String get challengeLimit => 'Você já enviou 3 wallpapers para este desafio.';

  @override
  String get challengeRetry => 'Tentar novamente';

  @override
  String get challengeOwnEntry => 'Você não pode votar na própria criação.';

  @override
  String get challengeDailyLimit => 'Você atingiu o limite diário de votos.';

  @override
  String get challengeMissing => 'Este desafio ou criação não está mais disponível.';

  @override
  String get challengeBadge => 'Vencedor do desafio';

  @override
  String get challengeBadgeDescription => 'Vença um desafio semanal';

  @override
  String get challengeWinnerNotificationTitle => 'Seu wallpaper venceu';

  @override
  String challengeWinnerNotificationBody(String theme) {
    return 'Sua criação venceu o desafio semanal: $theme.';
  }

  @override
  String get statsTitle => 'Suas estatísticas';

  @override
  String get statsEntry => 'Estatísticas';

  @override
  String get statsViews => 'Visualizações';

  @override
  String get statsSaves => 'Salvos';

  @override
  String get statsSets => 'Vezes aplicado';

  @override
  String get statsDownloads => 'Downloads';

  @override
  String get statsShares => 'Compartilhamentos';

  @override
  String get statsFolderAdds => 'Adições a pastas';

  @override
  String get statsRemixes => 'Remixes';

  @override
  String get statsLoading => 'Carregando suas estatísticas';

  @override
  String get statsError => 'Não foi possível carregar suas estatísticas. Tente novamente.';

  @override
  String get statsRetry => 'Tentar novamente';

  @override
  String get statsEmptyTitle => 'Seu primeiro fundo começa aqui';

  @override
  String get statsEmptyBody => 'Envie um fundo. As estatísticas aparecem após a aprovação.';

  @override
  String get statsUpload => 'Enviar um fundo';

  @override
  String get statsWeekNote =>
      'Esta semana até agora em comparação com a anterior. As semanas começam na segunda-feira, UTC.';

  @override
  String get statsHistoryNote =>
      'Oito semanas, da mais antiga à mais recente. Um traço indica dados indisponíveis. O acompanhamento pode começar no meio da semana, por isso os dados semanais podem ser parciais. A semana atual está incompleta.';

  @override
  String get statsTopWalls => 'Melhores fundos desta semana';

  @override
  String get statsUntitled => 'Fundo sem título';

  @override
  String get statsCountingNote =>
      'O total de salvos conta os favoritos atuais; o valor semanal conta adições. O total de remixes conta os créditos atuais; o valor semanal conta os primeiros créditos aceitos. As adições a pastas são registradas desde o início do acompanhamento.';

  @override
  String get statsUnavailable => 'Indisponível';

  @override
  String get statsWeeklyTitle => 'Seus fundos nesta semana';

  @override
  String statsWeeklyBody(String week) {
    return 'Veja os resultados dos seus fundos em $week.';
  }

  @override
  String statsWallValue(String metric, String value) {
    return '$metric: $value nesta semana';
  }

  @override
  String statsComparison(String current, String previous) {
    return '$current nesta semana · $previous na anterior';
  }

  @override
  String statsTotal(String value) {
    return 'Total: $value';
  }

  @override
  String statsChange(String value) {
    return '$value em comparação com a semana anterior';
  }

  @override
  String statsUpdated(String date) {
    return 'Atualizado em $date UTC';
  }

  @override
  String statsChartWeek(String date, String value) {
    return 'Semana de $date: $value';
  }

  @override
  String statsChartSummary(String metric, String summary) {
    return '$metric, oito semanas. $summary';
  }

  @override
  String get shortcutsGuideHeadline => 'Um papel de parede novo todo dia';

  @override
  String get shortcutsGuideBody =>
      'Configure os Atalhos uma vez. Todo dia, a automação define um papel de parede da sua pasta de rotação. Os 200 mais recentes aparecem uma vez cada antes de qualquer repetição.';

  @override
  String get shortcutsSourceRotation => 'Pasta de rotação';

  @override
  String get shortcutsSourceRotationDescription => 'Embaralha a pasta que você escolheu acima.';

  @override
  String get shortcutsSourceFolder => 'Pasta';

  @override
  String get shortcutsSourceFolderDescription => 'Embaralha uma pasta que você escolher nos Atalhos.';

  @override
  String get shortcutsSourceFavouriteDescription =>
      'Embaralha seus favoritos. Cada um aparece uma vez antes de qualquer um se repetir. Alguns papéis de parede protegidos podem não estar disponíveis.';

  @override
  String get shortcutsRotationNone => 'Nenhuma pasta escolhida';

  @override
  String get shortcutsRotationNoneBody => 'Escolha a pasta que o atalho embaralha.';

  @override
  String get shortcutsRotationPick => 'Escolher uma pasta';

  @override
  String get shortcutsRotationChange => 'Alterar';

  @override
  String get shortcutsRotationStop => 'Parar';

  @override
  String shortcutsStepLabel(int number, String title) {
    return 'Passo $number, $title';
  }

  @override
  String get shortcutsStepAddTitle => 'Adicione o atalho do Prism';

  @override
  String get shortcutsStepAddBody =>
      'Ele pega um papel de parede da sua pasta de rotação e o define como seu papel de parede.';

  @override
  String get shortcutsStepAddAction => 'Adicionar o atalho';

  @override
  String get shortcutsStepAddManualBody => 'Crie nos Atalhos com 2 ações.';

  @override
  String get shortcutsManualNew => 'Nos Atalhos, toque em + para criar um atalho novo.';

  @override
  String get shortcutsManualGet => 'Adicione \"Obter papel de parede do Prism\". Defina Origem como Pasta de rotação.';

  @override
  String get shortcutsManualSet =>
      'Adicione \"Definir Foto de Fundo\". Toque na seta nela e desative Mostrar Pré-Visualização.';

  @override
  String shortcutsManualName(String name) {
    return 'Dê o nome \"$name\" ao atalho.';
  }

  @override
  String get shortcutsStepAutomationTitle => 'Execute todos os dias';

  @override
  String get shortcutsAutomationOpen => 'Nos Atalhos, toque em Automação e depois em +.';

  @override
  String get shortcutsAutomationTime => 'Toque em Hora do Dia. Escolha um horário e depois Diariamente.';

  @override
  String get shortcutsAutomationRun => 'Escolha Executar Imediatamente e depois toque em Avançar.';

  @override
  String shortcutsAutomationPick(String name) {
    return 'Escolha \"$name\" para executar.';
  }

  @override
  String shortcutsAutomationNoTab(String name) {
    return 'Não encontrou a aba Automação? Abra \"$name\", toque em Editar e depois em Automação.';
  }

  @override
  String get shortcutsStepTestTitle => 'Teste agora';

  @override
  String shortcutsStepTestBody(String name) {
    return 'Executa \"$name\" uma vez, para você ver o novo papel de parede agora.';
  }

  @override
  String get shortcutsStepTestAction => 'Executar o atalho';

  @override
  String get foldersRotateDaily => 'Rotacionar esta pasta todo dia';

  @override
  String get autoRotateIosTitle => 'Troque os papéis de parede com os Atalhos';

  @override
  String get autoRotateIosBody =>
      'No iPhone, uma automação dos Atalhos define um papel de parede novo da sua pasta todo dia.';

  @override
  String get autoRotateIosAction => 'Configurar os Atalhos';

  @override
  String get shortcutsAutomationIos16 =>
      'No iOS 16 não existe \"Executar Imediatamente\". Desative \"Perguntar Antes de Executar\".';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get economyAd => 'Anúncio';

  @override
  String economyWatchAdForCoins(int reward) {
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    return 'Assistir a anúncio por $rewardString moedas';
  }

  @override
  String economyCoinsMissing(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Faltam $countString moedas.';
  }

  @override
  String economyCoinsRemainAfterAd(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Você ainda pode precisar de $countString moedas após o anúncio';
  }

  @override
  String get economyAdAutomaticPurchase =>
      'Se o seu saldo após a recompensa cobrir o preço, este item será comprado automaticamente.';

  @override
  String get economyAdVerificationPending =>
      'Sua recompensa está aguardando verificação. As moedas aparecerão após a confirmação.';

  @override
  String get foldersLibraryEmptyTitle => 'Nenhuma pasta ainda';

  @override
  String get foldersLibraryEmptyBody => 'Segure o coração em um papel de parede para salvá-lo em uma pasta.';

  @override
  String get foldersLoadAllError => 'Não foi possível carregar suas pastas';

  @override
  String get galleryEmptyBody => 'Foram removidos ou não são mais públicos.';

  @override
  String get galleryEmptyTitle => 'Esses papéis de parede sumiram';

  @override
  String get galleryScreenTitle => 'Papéis de parede para você';

  @override
  String get favouritePin => 'Fixar no topo';

  @override
  String get favouriteUnpin => 'Desafixar';

  @override
  String get favouritePinnedToast => 'Fixado no topo dos Favoritos';

  @override
  String get favouriteUnpinnedToast => 'Desafixado';

  @override
  String get favouritePinnedBadge => 'Fixado';

  @override
  String favouritePinLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Você pode fixar até $count favoritos. Desafixe um para fixar este papel de parede.',
    );
    return '$_temp0';
  }

  @override
  String get favouritePinFailed => 'Não foi possível atualizar o fixado. Verifique sua conexão e tente novamente.';

  @override
  String wallpaperFavouriteSearchCountHint(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pesquisar em $countString favoritos',
      one: 'Pesquisar em 1 favorito',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteSortAndFilter => 'Organizar e filtrar';

  @override
  String get wallpaperFavouriteSortBy => 'Organizar por';

  @override
  String get wallpaperFavouriteFilterSource => 'Fonte';

  @override
  String get wallpaperHistorySetAgain => 'Definir novamente';

  @override
  String wallpaperHistoryTileLabel(String current, String target, String time) {
    return '$current$target, definido às $time';
  }

  @override
  String get wallpaperProviderWallhaven => 'Wallhaven';

  @override
  String get duoTitle => 'Surpresa Duo';

  @override
  String get duoAiFormatLabel => 'Criar uma surpresa Duo';

  @override
  String get duoPresetNotice =>
      'O Prism mostra o lado direito na prévia com o celular dobrado. Alinhe manualmente o original salvo e confira as duas vistas na prévia de papel de parede do sistema. Esta é uma predefinição do Prism, não um recorte automático do iOS.';

  @override
  String get duoFoldedPromptLabel => 'Vista com o celular dobrado';

  @override
  String get duoFoldedPromptExample => 'Um gato sonolento ao lado de uma janela';

  @override
  String get duoRevealedPromptLabel => 'A surpresa ao abrir';

  @override
  String get duoRevealedPromptExample => 'Uma pequena nave espacial do lado de fora da janela';

  @override
  String get duoPromptValidation => 'Descreva as duas vistas com 1 a 160 caracteres em cada uma.';

  @override
  String get duoMoodBody => 'Um papel de parede. Mais surpresas ao abrir.';

  @override
  String get duoDeviceName => 'iPhone Duo';

  @override
  String get duoPhoneDevice => 'Celular';

  @override
  String get duoFold => 'Dobrar';

  @override
  String get duoUnfold => 'Abrir';

  @override
  String get duoFolded => 'Dobrado';

  @override
  String get duoUnfolded => 'Aberto';

  @override
  String get duoAndroidCropNotice =>
      'O Prism mostra o lado direito na prévia com o celular dobrado. O Android pode recortar a imagem de outra forma. Confira a prévia de papel de parede do sistema antes de aplicar.';

  @override
  String get duoGetOnPrism => 'Encontre no Prism';

  @override
  String get duoGuideTitle => 'Configure sua surpresa Duo';

  @override
  String get duoGuideOpen =>
      'Abra o original salvo no Fotos, toque em Compartilhar e depois em Usar como Papel de Parede.';

  @override
  String get duoGuideAlign =>
      'Alinhe manualmente a imagem inteira para que a vista com o celular dobrado mostre o lado direito.';

  @override
  String get duoGuideCheck =>
      'Confira as vistas com o celular dobrado e aberto na prévia do sistema e adicione o papel de parede.';

  @override
  String get duoWebTitle => 'Papéis de parede para iPhone Duo | Prism';

  @override
  String get duoWebDescription =>
      'Um papel de parede com uma segunda cena escondida. Explore papéis de parede originais com surpresa Duo no Prism.';

  @override
  String get duoWebHeading => 'Um papel de parede. Uma história que se amplia.';

  @override
  String get duoWebIntro =>
      'Uma cena tranquila ao dobrar. Outra história ao abrir. Veja as duas vistas de cada papel de parede original.';

  @override
  String get duoWebEmpty => 'A primeira coleção Duo está em análise.';

  @override
  String get duoWebEmptyBody => 'Explore o Prism enquanto conferimos cada papel de parede nas duas vistas.';

  @override
  String get duoWebFolded => 'Prévia com o celular dobrado';

  @override
  String get duoWebUnfolded => 'Original com o celular aberto';

  @override
  String get duoWebPresetNotice =>
      'Estas prévias usam a predefinição do Prism para o lado direito, não um recorte automático da Apple. Salve o original completo, alinhe manualmente e confira as vistas com o celular dobrado e aberto na prévia de papel de parede do sistema.';

  @override
  String get duoWebOpenPrism => 'Abrir no Prism';

  @override
  String get duoWebExplore => 'Explorar o Prism';

  @override
  String get duoWebAppStore => 'Baixar na App Store';

  @override
  String get duoWebPlayStore => 'Disponível no Google Play';

  @override
  String get economyExportFailedLabel => 'Falha ao exportar';

  @override
  String get coreSignInCreatorSearchFeature => 'busca de criadores';

  @override
  String get debugLogExportSubject => 'Logs de depuração do Prism';

  @override
  String get accountAbout => 'Sobre';

  @override
  String get accountAboutPrism => 'Sobre o Prism';

  @override
  String get accountAccount => 'Conta';

  @override
  String get accountAccountDeletionSubscriptionWarning =>
      'A assinatura da loja não é cancelada quando você exclui sua conta. A cobrança continua até você cancelá-la na loja.';

  @override
  String get accountAdPrivacyChoices => 'Opções de privacidade dos anúncios';

  @override
  String get accountAddProfilePhoto => 'Adicionar foto do perfil';

  @override
  String get accountAddSocialLink => 'Adicionar link de rede social';

  @override
  String get accountAdmin => 'Administrador';

  @override
  String get accountAdminModeration => 'Moderação administrativa';

  @override
  String accountAndroidSharePitch(String url) {
    return 'Apaixone-se de novo pela personalização do Android! Conheça o Prism -\n$url';
  }

  @override
  String get accountAnyResolution => 'Qualquer';

  @override
  String get accountAppName => 'Prism Wallpapers';

  @override
  String get accountAppearance => 'Aparência';

  @override
  String get accountApply => 'Aplicar';

  @override
  String get accountAskEveryTime => 'Perguntar sempre';

  @override
  String get accountAudience => 'Público';

  @override
  String get accountAutoRotateWallpapers => 'Trocar papéis de parede automaticamente';

  @override
  String get accountBlock => 'Bloquear';

  @override
  String get accountBlockActionFailed => 'Não foi possível atualizar as contas bloqueadas';

  @override
  String get accountBlockActionPendingSync =>
      'Sua alteração foi salva neste dispositivo e será sincronizada assim que possível.';

  @override
  String get accountBlockConfirmationUserFallback => 'esta pessoa';

  @override
  String accountBlockThisUserTitle(String name) {
    return 'Bloquear $name?';
  }

  @override
  String get accountBlockUser => 'Bloquear usuário';

  @override
  String accountBlockUserMessage(String name) {
    return 'Você deixará de seguir $name, não verá mais os papéis de parede dessa pessoa no feed e não receberá notificações sobre as novas publicações dela.';
  }

  @override
  String get accountBlockedAccounts => 'Contas bloqueadas';

  @override
  String get accountBlockedAccountsEmptyBody =>
      'Bloquear alguém oculta as publicações dessa pessoa no seu feed. Ela ainda poderá ver seu perfil e seus papéis de parede públicos.';

  @override
  String get accountBlockedAccountsLoadError => 'Não foi possível carregar as contas bloqueadas';

  @override
  String get accountBlockedListUserFallback => 'Usuário bloqueado';

  @override
  String get accountBlockedProfileBody =>
      'Os papéis de parede dessa pessoa ficam ocultos no seu feed e nas notificações. Você pode desbloqueá-la quando quiser.';

  @override
  String get accountBringBackSubscription => 'Reativar uma assinatura anterior';

  @override
  String get accountBrowseByCategory => 'Explorar por categoria';

  @override
  String get accountBrowseByColour => 'Explorar por cor';

  @override
  String get accountBuyPremium => 'Comprar o Premium';

  @override
  String get accountCacheCleared => 'Cache limpo.';

  @override
  String accountCacheClearedBytes(String size) {
    return '$size removidos.';
  }

  @override
  String accountCachedImageSize(String size) {
    return '$size de imagens em cache';
  }

  @override
  String get accountCancel => 'Cancelar';

  @override
  String get accountCannotGiftThisAccount => 'Não é possível enviar um presente para esta conta.';

  @override
  String accountCategorySemanticLabel(String name) {
    return 'Categoria, $name';
  }

  @override
  String get accountChangeAutomatically => 'Alterar automaticamente';

  @override
  String get accountChangeCoverPhoto => 'Alterar foto da capa';

  @override
  String get accountChangeOrCancelStore => 'Alterar ou cancelar na loja';

  @override
  String get accountChangePhoto => 'Alterar foto';

  @override
  String get accountChangeWallpaperOnTimer => 'Trocar o papel de parede com um temporizador';

  @override
  String get accountCheckConnectionTryAgain => 'Verifique sua conexão e tente novamente.';

  @override
  String get accountClear => 'Limpar';

  @override
  String get accountClearAllDownloads => 'Excluir todos os downloads';

  @override
  String get accountClearAllFavouritesQuestion => 'Excluir todos os favoritos?';

  @override
  String get accountClearCache => 'Limpar cache';

  @override
  String get accountClearCacheConfirmMessage =>
      'As imagens em cache serão removidas. Elas serão carregadas novamente quando você precisar.';

  @override
  String accountClearCacheConfirmSizeMessage(String size) {
    return '$size de imagens em cache serão removidos. Elas serão carregadas novamente quando você precisar.';
  }

  @override
  String get accountClearCacheQuestion => 'Limpar o cache?';

  @override
  String get accountClearCacheTitle => 'Limpar cache';

  @override
  String get accountClearCachedImages => 'Limpar imagens salvas em cache neste dispositivo';

  @override
  String get accountClearColour => 'Limpar cor';

  @override
  String get accountClearDepthEffect => 'Remover efeito de profundidade';

  @override
  String get accountClearSpatialScene => 'Remover espacial';

  @override
  String get accountClearFavouriteWallpapers => 'Excluir papéis de parede favoritos';

  @override
  String get accountClearFavourites => 'Excluir favoritos';

  @override
  String accountClearFavouritesCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede favoritos serão removidos',
      one: '1 papel de parede favorito será removido',
      zero: '$countString papéis de parede favoritos serão removidos',
    );
    return '$_temp0 da sua conta. Não é possível desfazer essa ação.';
  }

  @override
  String get accountClearFavouritesMessage =>
      'Todos os seus papéis de parede favoritos serão removidos da sua conta. Não é possível desfazer essa ação.';

  @override
  String get accountClearLearnedTaste => 'Apagar preferências aprendidas';

  @override
  String accountClearLearnedTasteCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'os $countString itens',
      one: 'o único item',
      zero: 'os $countString itens',
    );
    return 'O Prism vai esquecer $_temp0 que aprendeu com o que você visualizou e salvou. Seu feed voltará a usar os interesses que você escolheu. Não é possível desfazer essa ação.';
  }

  @override
  String get accountClearLearnedTasteQuestion => 'Apagar preferências aprendidas?';

  @override
  String get accountClearSearch => 'Limpar pesquisa';

  @override
  String get accountColour => 'Cor';

  @override
  String accountCommitCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString commits',
      one: '1 commit',
      zero: 'Nenhum commit',
    );
    return '$_temp0';
  }

  @override
  String get accountCompleteProfile => 'Completar perfil';

  @override
  String get accountCompleteYourProfile => 'Complete seu perfil';

  @override
  String get accountConnectionTryAgain => 'Verifique sua conexão e tente novamente.';

  @override
  String get accountContent => 'Conteúdo';

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
      zero: 'nenhum commit',
    );
    return '$login, $_temp0';
  }

  @override
  String get accountCopy => 'Copiar';

  @override
  String get accountCopyLink => 'Copiar link';

  @override
  String get accountCouldNotBuildReport => 'Não foi possível gerar o relatório. Tente novamente.';

  @override
  String get accountCouldNotClearFavourites =>
      'Não foi possível excluir os papéis de parede favoritos. Tente novamente.';

  @override
  String get accountCouldNotClearLearnedTaste => 'Não foi possível apagar as preferências aprendidas. Tente novamente.';

  @override
  String get accountCouldNotCreateLink => 'Não foi possível criar o link. Tente novamente.';

  @override
  String get accountCouldNotDeleteDownloads => 'Não foi possível excluir os downloads. Tente novamente.';

  @override
  String accountCouldNotFollowPerson(String name) {
    return 'Não foi possível seguir $name. Tente novamente.';
  }

  @override
  String get accountCouldNotLoadFollowers => 'Não foi possível carregar os seguidores';

  @override
  String get accountCouldNotLoadFollowing => 'Não foi possível carregar quem você segue';

  @override
  String get accountCouldNotLoadTeam => 'Não foi possível carregar a equipe';

  @override
  String get accountCouldNotLoadThisProfile => 'Não foi possível carregar este perfil';

  @override
  String get accountCouldNotLoadTrending => 'Não foi possível carregar os destaques';

  @override
  String get accountCouldNotLoadWallpapers => 'Não foi possível carregar os papéis de parede';

  @override
  String accountCouldNotOpenAddress(String address) {
    return 'Não foi possível abrir $address';
  }

  @override
  String get accountCouldNotOpenLink => 'Não foi possível abrir o link. Tente novamente.';

  @override
  String get accountCouldNotOpenStore => 'Não foi possível abrir a loja. Tente novamente.';

  @override
  String get accountCouldNotOpenThisLink => 'Não foi possível abrir este link.';

  @override
  String get accountCouldNotRefreshSearch => 'Não foi possível atualizar. Puxe a tela para baixo e tente novamente.';

  @override
  String get accountCouldNotRemoveSavedOffline =>
      'Não foi possível remover os papéis de parede salvos para uso off-line. Tente novamente.';

  @override
  String get accountCouldNotRestorePurchases => 'Não foi possível restaurar as compras. Tente novamente.';

  @override
  String get accountCouldNotSearchCreators => 'Não foi possível pesquisar criadores';

  @override
  String get accountCouldNotSearchRightNow => 'Não foi possível pesquisar agora';

  @override
  String get accountCouldNotSendGift => 'Não foi possível enviar o presente. Tente novamente.';

  @override
  String get accountCouldNotShareReport => 'Não foi possível compartilhar o relatório. Tente novamente.';

  @override
  String accountCouldNotUnfollowPerson(String name) {
    return 'Não foi possível deixar de seguir $name. Tente novamente.';
  }

  @override
  String get accountCreatorFallback => 'Criador do Prism';

  @override
  String get accountCreatorSearchEmptyBody => 'Confira a ortografia ou tente outro nome.';

  @override
  String get accountCurrentSignedInAccountRequired => 'Selecione a conta em que você está conectado no momento.';

  @override
  String get accountDataSaver => 'Economia de dados';

  @override
  String get accountDataSaverDescription =>
      'Economiza dados móveis. Os papéis de parede abrem como miniaturas, os feeds não carregam conteúdo antecipadamente e os carrosséis não iniciam sozinhos.';

  @override
  String get accountDatabaseUsageStats => 'Uso e estatísticas do banco de dados';

  @override
  String get accountDebugPanel => 'Painel de depuração';

  @override
  String get accountDefaultActionForSet => 'Ação padrão para Definir';

  @override
  String get accountDeleteAccount => 'Excluir conta';

  @override
  String get accountDeleteAccountConfirmation =>
      'Sua conta será excluída permanentemente, seus dados pessoais serão removidos e sua sessão será encerrada.\n\nOs papéis de parede que você enviou continuarão visíveis como \"Conta excluída\".\n\nNão é possível desfazer essa ação.';

  @override
  String get accountDeleteAccountReauthNote =>
      'Na próxima etapa, você confirmará sua identidade com o Google ou a Apple.';

  @override
  String get accountDeleteAll => 'Excluir tudo';

  @override
  String get accountDeleteAllDownloadsQuestion => 'Excluir todos os downloads?';

  @override
  String accountDeleteDownloadsCountMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede baixados serão excluídos',
      one: '1 papel de parede baixado será excluído',
      zero: '$countString papéis de parede baixados serão excluídos',
    );
    return '$_temp0 da seção Downloads. As cópias salvas para uso off-line não serão afetadas. Não é possível desfazer essa ação.';
  }

  @override
  String get accountDeleteDownloadsMessage =>
      'Os papéis de parede baixados serão excluídos da seção Downloads. As cópias salvas para uso off-line não serão afetadas. Não é possível desfazer essa ação.';

  @override
  String get accountDeleteYourAccountQuestion => 'Excluir sua conta?';

  @override
  String get accountDeletingYourAccount => 'Excluindo sua conta';

  @override
  String get accountDepthEffect => 'Efeito de profundidade';

  @override
  String get accountDepthEffectClockSemanticLabel => 'Efeito de profundidade, elemento principal à frente do relógio';

  @override
  String get accountSpatialScene => 'Espacial';

  @override
  String get accountSpatialSceneSubtitle => 'Walls com profundidade 3D nítida';

  @override
  String get accountSpatialSceneSemanticLabel => 'Espacial, walls com profundidade 3D nítida';

  @override
  String accountDownloadedWallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede baixados; as cópias salvas para uso off-line serão mantidas',
      one: '1 papel de parede baixado; as cópias salvas para uso off-line serão mantidas',
      zero: 'Nenhum papel de parede baixado; as cópias salvas para uso off-line serão mantidas',
    );
    return '$_temp0';
  }

  @override
  String get accountDownloadsDeleted => 'Todos os downloads foram excluídos.';

  @override
  String get accountEarnCoins => 'Ganhe moedas';

  @override
  String accountEarnProfileCompletionCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Ganhe $coinsString moedas ao completar seu perfil';
  }

  @override
  String get accountEditCover => 'Editar capa';

  @override
  String get accountEditProfile => 'Editar perfil';

  @override
  String get accountExportFavourites => 'Exportar favoritos';

  @override
  String get accountFavouritesCleared => 'Todos os papéis de parede favoritos foram excluídos.';

  @override
  String get accountFeedback => 'OPINIÃO';

  @override
  String get accountFeedbackSubject => 'Opinião sobre o Prism';

  @override
  String get accountFields => 'Campos';

  @override
  String get accountFilters => 'Filtros';

  @override
  String get accountFindCreators => 'Encontrar criadores';

  @override
  String get accountFinishYourProfile => 'Conclua seu perfil';

  @override
  String get accountFirestoreTelemetry => 'Telemetria do Firestore';

  @override
  String get accountFollow => 'Seguir';

  @override
  String accountFollowPerson(String name) {
    return 'Seguir $name';
  }

  @override
  String accountFollowedPerson(String name) {
    return 'Você está seguindo $name!';
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
      zero: 'Nenhum seguidor',
    );
    return '$_temp0';
  }

  @override
  String accountFollowersCountLabel(String compactCount) {
    return '$compactCount seguidores';
  }

  @override
  String get accountFollowersEmptyMessage => 'As pessoas que seguem esta conta aparecerão aqui.';

  @override
  String get accountFollowing => 'Seguindo';

  @override
  String accountFollowingCountLabel(String compactCount) {
    return '$compactCount seguindo';
  }

  @override
  String get accountFollowingEmptyMessage => 'As contas que você segue aparecerão aqui.';

  @override
  String get accountForgetFeedLearned => 'Apagar o que o feed aprendeu sobre você';

  @override
  String get accountFromPrism => 'Do Prism';

  @override
  String get accountGiftLimitReached => 'Você atingiu o limite de presentes por enquanto. Tente novamente amanhã.';

  @override
  String accountGiftPassMessage(String recipientName, int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return '$recipientName terá acesso às coleções e aos papéis de parede Premium pelas próximas 24 horas. Custa $priceString moedas.';
  }

  @override
  String get accountGiftPassTitle => 'Presentear com um passe Pro de 24 horas';

  @override
  String get accountGiftPassTooltip => 'Presentear com um passe de 24 h';

  @override
  String get accountGiftsOpenAfterSevenDays => 'Você poderá enviar presentes quando sua conta tiver 7 dias.';

  @override
  String get accountHapticFeedback => 'Resposta tátil';

  @override
  String get accountHelp => 'Ajuda';

  @override
  String get accountHomeAndLockScreens => 'Tela inicial e tela de bloqueio';

  @override
  String get accountHomeScreen => 'Tela inicial';

  @override
  String get accountInviteFriends => 'Convidar amigos';

  @override
  String get accountInviteLinkCouldNotCreate => 'Não foi possível criar seu link de convite.';

  @override
  String accountInviteRewardHeadline(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Dê $coinsString, ganhe $coinsString';
  }

  @override
  String accountInviteRewardMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Seu amigo ganha $coinsString moedas ao entrar. Você também ganha $coinsString.';
  }

  @override
  String get accountInviteShareFailed => 'Não foi possível compartilhar o convite agora.';

  @override
  String accountIosSharePitch(String url) {
    return 'Apaixone-se de novo pela personalização do seu celular! Conheça o Prism -\n$url';
  }

  @override
  String get accountLater => 'Mais tarde';

  @override
  String get accountLatest => 'Mais recentes';

  @override
  String get accountLearnedTasteCleared => 'Preferências aprendidas apagadas.';

  @override
  String get accountLibrary => 'Biblioteca';

  @override
  String get accountLightDarkAccentColour => 'Cores clara, escura e de destaque';

  @override
  String get accountLink => 'Link';

  @override
  String get accountLinkCopied => 'Link copiado';

  @override
  String get accountLinkType => 'Tipo de link';

  @override
  String get accountLinkTypeBehance => 'Behance';

  @override
  String get accountLinkTypeBioLink => 'bio.link';

  @override
  String get accountLinkTypeBuyMeACoffee => 'Buy Me a Coffee';

  @override
  String get accountLinkTypeCustom => 'Link personalizado';

  @override
  String get accountLinkTypeDeviantArt => 'DeviantArt';

  @override
  String get accountLinkTypeDribbble => 'Dribbble';

  @override
  String get accountLinkTypeEmail => 'E-mail';

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
    return 'Tipo de link, $name';
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
  String get accountLiveWallpapers => 'Papéis de parede animados';

  @override
  String get accountLoadingTeam => 'Carregando a equipe';

  @override
  String get accountLockScreen => 'Tela de bloqueio';

  @override
  String get accountLogOut => 'Sair';

  @override
  String get accountLogOutOfPrismQuestion => 'Sair do Prism?';

  @override
  String get accountLogOutQuestion => 'Sair?';

  @override
  String get accountLogoutConfirmation =>
      'Ao sair, o histórico e as preferências aprendidas serão apagados deste dispositivo. Seus favoritos, moedas e perfil continuarão na sua conta.';

  @override
  String get accountLogoutFailed => 'Não foi possível sair. Tente novamente.';

  @override
  String get accountLogsNetworkToolsStorage => 'Registros, rede, ferramentas e armazenamento';

  @override
  String get accountMadeWithLoveInIndia => 'Feito com ❤ na Índia usando Flutter!';

  @override
  String get accountManageBlockedPeople => 'Gerenciar pessoas bloqueadas';

  @override
  String get accountManageSubscription => 'Gerenciar assinatura';

  @override
  String get accountMenu => 'Menu';

  @override
  String get accountMinResolution => 'Resolução mínima';

  @override
  String get accountMoreLinks => 'Mais links';

  @override
  String get accountMoreOptions => 'Mais opções';

  @override
  String get accountMovingGradientsMotionVideo => 'Gradientes em movimento, animações e vídeos';

  @override
  String get accountMyAccent => 'Meu destaque';

  @override
  String get accountNoBlockedAccounts => 'Nenhuma conta bloqueada';

  @override
  String get accountNoContributors => 'Ainda não há colaboradores para mostrar.';

  @override
  String get accountNoCreatorsFound => 'Nenhum criador encontrado';

  @override
  String get accountNoDownloadsToRemove => 'Você não tem downloads para remover.';

  @override
  String get accountNoFollowersYet => 'Ainda não há seguidores';

  @override
  String get accountNoPurchasesToRestore => 'Não há compras para restaurar nesta conta.';

  @override
  String get accountNoResults => 'Nenhum resultado';

  @override
  String accountNoWallpapersForFilters(String filters) {
    return 'Nenhum papel de parede encontrado para $filters';
  }

  @override
  String accountNoWallpapersForQueryWithFilters(String query) {
    return 'Nenhum papel de parede encontrado para $query com os filtros selecionados.';
  }

  @override
  String get accountNoWallpapersFound => 'Nenhum papel de parede encontrado';

  @override
  String accountNoWallpapersFoundForQuery(String query) {
    return 'Nenhum papel de parede encontrado para $query';
  }

  @override
  String get accountNoWallpapersYet => 'Ainda não há papéis de parede';

  @override
  String accountNobodyMatchesUsername(String query) {
    return 'Ninguém corresponde a \"$query\". Tente outro nome de usuário.';
  }

  @override
  String get accountNotEnoughCoinsEarnInRewards => 'Moedas insuficientes. Ganhe moedas em Recompensas.';

  @override
  String get accountNotFollowingAnyoneYet => 'Você ainda não segue ninguém';

  @override
  String get accountNotSynced => 'Não sincronizado';

  @override
  String get accountNothingLearnedYet => 'O Prism ainda não aprendeu nada.';

  @override
  String get accountNotificationPreferences => 'Preferências de notificações';

  @override
  String get accountNotificationTypes => 'Papel de parede do dia, seguidores, publicações e mais';

  @override
  String get accountNotifications => 'Notificações';

  @override
  String get accountOpenYourProfile => 'Abrir seu perfil';

  @override
  String get accountOpeningProfileEditor => 'Abrindo o editor de perfil';

  @override
  String get accountOpens => 'Aberturas';

  @override
  String get accountOtherContributors => 'Outros colaboradores';

  @override
  String accountPassSentToPerson(String name) {
    return 'Passe enviado para $name.';
  }

  @override
  String accountPersonAlreadyHasPro(String name) {
    return '$name já tem o Pro.';
  }

  @override
  String get accountPersonalise => 'Personalizar';

  @override
  String get accountPortraitOnly => 'Somente retrato';

  @override
  String get accountPremiumBenefitsActive =>
      'Você tem acesso a todos os papéis de parede premium, downloads e filtros gratuitos.';

  @override
  String get accountPremiumBenefitsInactive => 'Desbloqueie papéis de parede premium, downloads e filtros gratuitos.';

  @override
  String get accountPreview => 'Prévia';

  @override
  String get accountPrismListPrivacySubtitle => 'Como o Prism usa seus dados';

  @override
  String get accountPrismPro => 'Prism Pro';

  @override
  String get accountPrivacyAction => 'PRIVACIDADE';

  @override
  String get accountPrivacyAndData => 'Privacidade e dados';

  @override
  String get accountPrivacyPolicy => 'Política de privacidade';

  @override
  String get accountProBadge => 'Pro';

  @override
  String get accountProWallpaperSemantics => 'Papel de parede Pro';

  @override
  String get accountProblemReportSharePrompt => 'Descreva o que deu errado. Os detalhes estão no arquivo do relatório.';

  @override
  String get accountProblemReportShareSubject => 'Relatório de problema do Prism';

  @override
  String get accountProfile => 'Perfil';

  @override
  String get accountProfileNotAvailable => 'Perfil indisponível';

  @override
  String get accountProfileNotAvailableBody =>
      'Este usuário não está usando a versão mais recente do Prism, então não é possível exibir o perfil.';

  @override
  String accountProfileNudgeMessage(int percent, int coins) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Seu perfil está $percentString% completo. Complete-o para ganhar $coinsString moedas Prism.';
  }

  @override
  String accountProfilePercentComplete(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Perfil $percentString% completo';
  }

  @override
  String accountProfilePersonSemantics(String name, String username) {
    return '$name, @$username';
  }

  @override
  String get accountProfiles => 'perfis';

  @override
  String get accountPurchases => 'Compras';

  @override
  String get accountPurchasesRestored => 'Compras restauradas.';

  @override
  String get accountPurchasesRestoredPending => 'Compras restauradas. O Pro pode levar um minuto para ser ativado.';

  @override
  String get accountQuickTiles => 'Blocos rápidos';

  @override
  String get accountRateApp => 'AVALIAR';

  @override
  String get accountRecentSearches => 'Buscas recentes';

  @override
  String get accountRelevance => 'Relevância';

  @override
  String get accountRemoveAllFavouriteWallpapers => 'Remover todos os papéis de parede favoritos';

  @override
  String get accountRemoveCoverPhoto => 'Remover foto de capa';

  @override
  String get accountRemoveFilesDownloadsOfflineStay =>
      'Remover arquivos de Downloads; as cópias salvas off-line serão mantidas';

  @override
  String get accountRemoveLink => 'Remover link';

  @override
  String get accountRemovePhoto => 'Remover foto';

  @override
  String get accountRemoveSavedOffline => 'Remover itens salvos off-line';

  @override
  String accountRemoveSavedOfflineCountMessage(String size) {
    return '$size dos originais mantidos off-line serão removidos. Downloads, rascunhos e dados do catálogo não serão alterados.';
  }

  @override
  String get accountRemoveSavedOfflineMessage =>
      'Remover deste dispositivo os originais mantidos off-line. Downloads, rascunhos e dados do catálogo não serão alterados.';

  @override
  String get accountRemoveSavedOfflineQuestion => 'Remover papéis de parede salvos off-line?';

  @override
  String get accountReportAProblem => 'Relatar um problema';

  @override
  String get accountReportProblemSubtitle => 'Envie um relatório de bug para a equipe do Prism';

  @override
  String get accountReportUser => 'Denunciar usuário';

  @override
  String get accountReset => 'Redefinir';

  @override
  String get accountResetFilters => 'Redefinir filtros';

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
  String get accountRetry => 'Tentar novamente';

  @override
  String get accountReviewOrChangeAdConsent => 'Revisar ou alterar seu consentimento para anúncios';

  @override
  String get accountReviewStatus => 'Status da análise';

  @override
  String get accountReviewSubmittedContent => 'Revisar conteúdo enviado';

  @override
  String get accountSaveFavouritesAsFile => 'Salvar uma cópia dos favoritos como arquivo';

  @override
  String get accountSavedOffline => 'Salvo off-line';

  @override
  String get accountSavedOfflineRemoved => 'Papéis de parede salvos off-line removidos.';

  @override
  String accountSavedOfflineStorageUnavailable(int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'Armazenamento indisponível · limite de $limitString MiB';
  }

  @override
  String accountSavedOfflineStorageUsed(String size, int limit) {
    final intl.NumberFormat limitNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$size usados · limite de $limitString MiB';
  }

  @override
  String get accountSavedOnThisDevice => 'Salvo neste dispositivo';

  @override
  String get accountSearch => 'Buscar';

  @override
  String get accountSearchByUsername => 'Buscar por nome de usuário';

  @override
  String get accountSearchCreators => 'Buscar criadores';

  @override
  String get accountSearchCreatorsByName => 'Buscar criadores por nome';

  @override
  String get accountSearchFilters => 'Filtros';

  @override
  String get accountSearchPrismUsersByName => 'Buscar usuários do Prism por nome';

  @override
  String get accountSearchWallpapers => 'Buscar papéis de parede';

  @override
  String get accountSeeChangelog => 'Ver registro de alterações';

  @override
  String get accountSendGift => 'Enviar presente';

  @override
  String get accountSendProfileLink => 'Enviar um link para seu perfil do Prism';

  @override
  String get accountSetUpQuickTiles => 'Configurar os blocos das Configurações rápidas';

  @override
  String get accountSetUsername => 'Definir nome de usuário';

  @override
  String get accountSettings => 'Configurações';

  @override
  String get accountShareInvite => 'Compartilhar convite';

  @override
  String get accountSharePrism => 'Compartilhar o Prism';

  @override
  String get accountSharePrismFriendSubtitle => 'Enviar um link para um amigo';

  @override
  String get accountShareProfile => 'Compartilhar perfil';

  @override
  String get accountShareProfileLinkFailed => 'Não foi possível criar o link. Tente novamente.';

  @override
  String get accountShareYourProfile => 'Compartilhar seu perfil';

  @override
  String get accountShop => 'Loja';

  @override
  String get accountShowAnimeWallpapers => 'Mostrar papéis de parede de anime';

  @override
  String get accountShowSketchyWallpapers => 'Mostrar papéis de parede sugestivos';

  @override
  String get accountSignIn => 'Entrar';

  @override
  String get accountSignInAgainToDelete => 'Saia da conta e entre novamente. Depois, tente excluir sua conta.';

  @override
  String get accountSignInBenefits => 'Entre para manter seus favoritos, moedas e perfil';

  @override
  String get accountSignInForInviteLink => 'Entre para obter seu link de convite.';

  @override
  String get accountSignInToPrism => 'Entrar no Prism';

  @override
  String get accountSocialGithub => 'GITHUB';

  @override
  String get accountSocialInstagram => 'INSTAGRAM';

  @override
  String get accountSocialTelegram => 'TELEGRAM';

  @override
  String get accountSocialTwitter => 'TWITTER';

  @override
  String get accountSomethingWentWrongTryAgain => 'Algo deu errado. Tente novamente.';

  @override
  String get accountSort => 'Ordenar';

  @override
  String get accountStorage => 'Armazenamento';

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
  String get accountSubjectCanSitInFrontOfClock => 'O elemento pode ficar na frente do relógio';

  @override
  String get accountSubjectInFrontOfClock => 'Elemento na frente do relógio';

  @override
  String get accountTerms => 'Termos';

  @override
  String get accountTermsAction => 'TERMOS';

  @override
  String accountTermsAgreementSemanticLabel(String terms, String privacy) {
    return 'Ao continuar, você concorda com os $terms e a $privacy';
  }

  @override
  String get accountTermsOfUse => 'Termos de uso';

  @override
  String get accountTheTeam => 'A equipe';

  @override
  String get accountThemes => 'Temas';

  @override
  String get accountThemesIconsFrames => 'Temas, ícones e molduras';

  @override
  String get accountThisUser => 'este usuário';

  @override
  String get accountTop => 'Destaques';

  @override
  String get accountTrackSubmittedWallpapers => 'Acompanhar papéis de parede enviados';

  @override
  String get accountTrendingNow => 'Em alta agora';

  @override
  String get accountTryAgain => 'Tentar novamente';

  @override
  String get accountTryFewerFilters => 'Tente usar menos filtros.';

  @override
  String get accountTryShorterOrDifferentWord => 'Tente usar uma palavra mais curta ou diferente.';

  @override
  String get accountUnblock => 'Desbloquear';

  @override
  String get accountUnblockUserMessage => 'As publicações dessa pessoa voltarão a aparecer no seu feed.';

  @override
  String accountUnblockUserTitle(String name) {
    return 'Desbloquear $name?';
  }

  @override
  String get accountUnfollow => 'Deixar de seguir';

  @override
  String accountUnfollowPerson(String name) {
    return 'Deixar de seguir $name';
  }

  @override
  String accountUnfollowedPerson(String name) {
    return 'Você deixou de seguir $name!';
  }

  @override
  String get accountUnlimitedUploadsFilters => 'Uploads e filtros ilimitados';

  @override
  String get accountUploadFirstWallpaper => 'Envie seu primeiro papel de parede para começar sua galeria.';

  @override
  String get accountUseShortcutsAutomation => 'Usar uma automação do Atalhos';

  @override
  String accountUserBlocked(String name) {
    return 'Você bloqueou $name';
  }

  @override
  String get accountUserUnblocked => 'Usuário desbloqueado';

  @override
  String accountVersionLabel(String version) {
    return 'Versão $version';
  }

  @override
  String get accountVibrateOnTapsAndActions => 'Vibrar ao tocar e realizar ações';

  @override
  String get accountWaitingToSync => 'Aguardando sincronização';

  @override
  String get accountWallpaperHistory => 'Histórico de papéis de parede';

  @override
  String get accountWallpaperManagerTagline => 'Um gerenciador de papéis de parede completo.';

  @override
  String get accountWallpaperSourceNames => 'O Prism usa Wallhaven e Pexels para encontrar papéis de parede';

  @override
  String get accountWallpaperSources => 'Fontes de papéis de parede';

  @override
  String get accountWallpaperSourcesMessage => 'O Prism usa estes serviços para oferecer papéis de parede.';

  @override
  String get accountWallpapersSetBefore => 'Papéis de parede usados anteriormente';

  @override
  String get accountWhatsNew => 'Novidades';

  @override
  String get accountWhatsNewAction => 'NOVIDADES';

  @override
  String get accountWriteBio => 'Escrever biografia';

  @override
  String accountYouBlockedUser(String name) {
    return 'Você bloqueou $name';
  }

  @override
  String get accountYourContent => 'Seu conteúdo';

  @override
  String get accountYourProfile => 'seu perfil';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionClose => 'Fechar';

  @override
  String get actionDone => 'Concluído';

  @override
  String get actionRetry => 'Tentar novamente';

  @override
  String get adminAllCaughtUp => 'Tudo em dia';

  @override
  String get adminAllUsers => 'Todos os usuários';

  @override
  String get adminAnnouncementInbox => 'Anúncio (caixa de entrada)';

  @override
  String get adminAnonymous => 'Anônimo';

  @override
  String get adminApprovalFailed => 'Não foi possível aprovar. Verifique sua conexão e tente novamente.';

  @override
  String get adminApprove => 'Aprovar';

  @override
  String get adminApproved => 'Aprovado';

  @override
  String get adminBackToReviewList => 'Voltar à lista de análise';

  @override
  String get adminBatchActionFailed => 'Não foi possível concluir esta ação de análise. Tente novamente.';

  @override
  String get adminBatchComplete => 'Lote concluído';

  @override
  String get adminBodyLabel => 'Corpo';

  @override
  String get adminBodyRequired => 'O corpo é obrigatório';

  @override
  String get adminBy => 'Por';

  @override
  String get adminByCollection => 'Por coleção';

  @override
  String get adminByOperation => 'Por operação';

  @override
  String get adminBySourceTop15 => 'Por fonte (15 principais)';

  @override
  String get adminCancel => 'Cancelar';

  @override
  String get adminChangeDepthEffect => 'Alterar efeito de profundidade';

  @override
  String get adminCheckConnectionRetry => 'Verifique sua conexão e tente novamente.';

  @override
  String get adminClose => 'Fechar';

  @override
  String adminContentTypeReport(String type) {
    return 'Relatório de $type';
  }

  @override
  String get adminCopyAllData => 'Copiar todos os dados';

  @override
  String get adminCouldNotLoadWallpaper => 'Não foi possível carregar o papel de parede';

  @override
  String get adminCreatorWillSeeFeedback => 'O criador verá este comentário.';

  @override
  String get adminDepth => 'Profundidade';

  @override
  String adminDepthTier(String tier) {
    return 'Profundidade: $tier';
  }

  @override
  String get adminDepthTierAuto => 'Automático';

  @override
  String get adminDepthTierMenu => 'Menu';

  @override
  String get adminDepthTierNone => 'Nenhum';

  @override
  String get adminDepthTierNotChecked => 'Não verificado';

  @override
  String get adminDrop => 'Drop';

  @override
  String get adminEmail => 'E-mail';

  @override
  String get adminEmailExample => 'user@example.com';

  @override
  String get adminEmailRequired => 'O e-mail é obrigatório';

  @override
  String get adminEstimatedDocumentReads => 'Leituras estimadas de documentos';

  @override
  String get adminEstimatedDocumentWrites => 'Gravações estimadas de documentos';

  @override
  String adminFactLabel(String label, String value) {
    return '$label: $value';
  }

  @override
  String get adminFirestoreTelemetry => 'Telemetria do Firestore';

  @override
  String get adminFollowersScreen => 'Tela de seguidores';

  @override
  String get adminFreeUsers => 'Usuários gratuitos';

  @override
  String get adminGeneral => 'Geral';

  @override
  String get adminImageUrlOptional => 'URL da imagem (opcional)';

  @override
  String get adminKeepWallpaper => 'Manter papel de parede';

  @override
  String get adminLast14Days => 'Últimos 14 dias';

  @override
  String get adminList => 'Lista';

  @override
  String get adminLoadNextBatch => 'Carregar próximo lote';

  @override
  String get adminLoadingNotificationCounts => 'Carregando contagens de notificações.';

  @override
  String get adminMarkReviewed => 'Marcar como revisado';

  @override
  String get adminMarkReviewedFailed => 'Não foi possível marcar a denúncia como revisada. Tente novamente.';

  @override
  String get adminMarkedReviewed => 'Marcada como revisada';

  @override
  String adminModerationDuplicate(int percent) {
    return 'Parece ser um papel de parede do Prism · $percent%';
  }

  @override
  String get adminModerationHint => 'Estas são apenas indicações. Confira antes de rejeitar.';

  @override
  String adminModerationLogo(String logo) {
    return 'Logotipo: $logo';
  }

  @override
  String get adminModerationLogos => 'Logotipos';

  @override
  String get adminModerationOpenFailed => 'Não foi possível abrir a página.';

  @override
  String adminModerationOpenPage(String host) {
    return 'Abrir $host';
  }

  @override
  String get adminModerationSignals => 'Sinais para análise';

  @override
  String get adminModerationSimilarWall => 'Papel de parede semelhante do Prism';

  @override
  String adminModerationSimilarity(int percent) {
    return '$percent% semelhante';
  }

  @override
  String adminModerationText(String words) {
    return 'Texto: $words';
  }

  @override
  String get adminModerationTextInImage => 'Texto na imagem';

  @override
  String adminModerationUnsafe(String categories) {
    return 'Conteúdo impróprio: $categories';
  }

  @override
  String get adminModerationUnsafeCategories => 'Categorias de conteúdo impróprio';

  @override
  String adminModerationWeb(String host) {
    return 'Encontrado em $host';
  }

  @override
  String adminModerationWebMore(String host, int more) {
    return 'Encontrado em $host +$more';
  }

  @override
  String get adminModerationWebPages => 'Encontrado na web';

  @override
  String get adminNewWallpapersPending => 'Novos papéis de parede aparecerão aqui quando alguém enviar um.';

  @override
  String get adminNoNotificationCounts => 'Ainda não há contagens de notificações.';

  @override
  String get adminNoOpenReports => 'Não há denúncias abertas';

  @override
  String get adminNoReasonGiven => 'Nenhum motivo informado';

  @override
  String get adminNoTelemetryData => 'Não há dados de telemetria para copiar';

  @override
  String get adminNoTelemetryYet => 'Ainda não há telemetria';

  @override
  String get adminNoWallpapersPending => 'Não há papéis de parede aguardando revisão.';

  @override
  String get adminNothingToReview => 'Nada para revisar';

  @override
  String get adminNotificationCountExplanation =>
      'Aceita significa que o Firebase recebeu a notificação push. Uma notificação para o tópico da conta e outra para o token do dispositivo contam duas vezes. Isso não significa que ela foi visualizada.';

  @override
  String get adminNotificationCountsLoadError => 'Não foi possível carregar as contagens de notificações.';

  @override
  String get adminNotificationIrreversible =>
      'Esta notificação será enviada a todos neste grupo. Não é possível desfazer.';

  @override
  String get adminNotificationQueueFailed => 'Não foi possível colocar a notificação na fila. Tente novamente.';

  @override
  String get adminNotificationQueued => 'Notificação na fila. A Cloud Function vai enviá-la em instantes.';

  @override
  String get adminNotifications => 'Notificações';

  @override
  String get adminOpenReportsLoadError => 'Não foi possível carregar as denúncias abertas.';

  @override
  String get adminOpenWallpaper => 'Abrir papel de parede';

  @override
  String adminOperationCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString operações',
      one: '$countString operação',
      zero: '$countString operações',
    );
    return '$_temp0';
  }

  @override
  String get adminPendingWallsLoadError => 'Não foi possível carregar os papéis de parede pendentes.';

  @override
  String get adminPremiumUsers => 'Usuários Premium';

  @override
  String adminReadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString leituras',
      one: '$countString leitura',
      zero: '$countString leituras',
    );
    return '$_temp0';
  }

  @override
  String get adminReasonBlurry => 'Embaçado';

  @override
  String get adminReasonBlurryBody => 'A imagem está embaçada ou muito comprimida. Envie uma versão mais nítida.';

  @override
  String get adminReasonCopyright => 'Direitos autorais';

  @override
  String get adminReasonCopyrightBody =>
      'Esta imagem pode ser de outra pessoa. Envie apenas papéis de parede que você criou ou tem direito de usar.';

  @override
  String get adminReasonDuplicate => 'Duplicado';

  @override
  String get adminReasonDuplicateBody => 'Este papel de parede é igual a outro que já está no Prism.';

  @override
  String get adminReasonHint => 'Explique o que precisa mudar';

  @override
  String get adminReasonLabel => 'Motivo';

  @override
  String get adminReasonLowResolution => 'Baixa resolução';

  @override
  String get adminReasonLowResolutionBody =>
      'A resolução está muito baixa. Envie uma imagem com pelo menos 1080 px no lado menor.';

  @override
  String get adminReasonNotWallpaper => 'Não é um papel de parede';

  @override
  String get adminReasonNotWallpaperBody =>
      'Esta imagem não funciona como papel de parede para celular. Use uma imagem vertical que preencha a tela.';

  @override
  String get adminReasonOther => 'Outro';

  @override
  String get adminReasonWatermark => 'Marca-d\'água';

  @override
  String get adminReasonWatermarkBody => 'A imagem tem uma marca-d\'água. Envie uma versão sem ela.';

  @override
  String get adminRefresh => 'Atualizar';

  @override
  String get adminReject => 'Rejeitar';

  @override
  String get adminRejectReasonRequired => 'Informe um motivo antes de rejeitar este item.';

  @override
  String get adminRejectSaveFailed =>
      'Não foi possível salvar esta decisão. Seu motivo continua aqui. Tente novamente.';

  @override
  String get adminRejectWallpaper => 'Rejeitar papel de parede';

  @override
  String get adminRemove => 'Remover';

  @override
  String get adminRemoveWallpaper => 'Remover papel de parede';

  @override
  String get adminRemovedFromNextDrop => 'Removido do próximo Drop';

  @override
  String get adminReportDismissFailed => 'Não foi possível dispensar a denúncia. Tente novamente.';

  @override
  String get adminReportDismissedKept => 'Denúncia dispensada. Papel de parede mantido.';

  @override
  String get adminReported => 'Denunciado';

  @override
  String get adminReporter => 'Denunciante';

  @override
  String get adminReports => 'Denúncias';

  @override
  String get adminReserve => 'Reservar';

  @override
  String get adminReserveForDrop => 'Reservar para o Drop';

  @override
  String get adminReserveUpdateFailed => 'Não foi possível atualizar a reserva do Drop. Tente novamente.';

  @override
  String get adminReservedForNextDrop => 'Reservado para o próximo Drop';

  @override
  String get adminRetry => 'Tentar novamente';

  @override
  String adminReviewProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString/$totalString';
  }

  @override
  String get adminSendNotification => 'Enviar notificação';

  @override
  String adminSendToAudience(String audience) {
    return 'Enviar para $audience?';
  }

  @override
  String get adminSkip => 'Pular';

  @override
  String get adminSpecificUser => 'Usuário específico (e-mail)';

  @override
  String get adminSwipeInstructions => 'Deslize para a direita para aprovar ou para a esquerda para rejeitar';

  @override
  String get adminSwipeReview => 'Revisão por gesto';

  @override
  String get adminTarget => 'Destino';

  @override
  String get adminTelemetryCopied => 'Copiado para a área de transferência. Cole em outro lugar para analisar.';

  @override
  String get adminTelemetryReadError => 'Não foi possível ler a telemetria';

  @override
  String get adminTitle => 'Moderação administrativa';

  @override
  String get adminTitleLabel => 'Título';

  @override
  String get adminTitleRequired => 'O título é obrigatório';

  @override
  String get adminTotalEvents => 'Total de eventos';

  @override
  String get adminTryAgain => 'Tentar novamente';

  @override
  String get adminUndo => 'Desfazer';

  @override
  String get adminUndoSuccessful => 'Ação desfeita';

  @override
  String get adminUnknown => 'Desconhecido';

  @override
  String get adminUnreserve => 'Cancelar reserva';

  @override
  String get adminUntitled => 'Sem título';

  @override
  String get adminUploaded => 'Enviado';

  @override
  String get adminUseAppForEvents => 'Use o app para gerar eventos do Firestore.';

  @override
  String get adminUserEmail => 'E-mail do usuário';

  @override
  String get adminUserReportsShowHere => 'As denúncias dos usuários aparecerão aqui.';

  @override
  String get adminValidEmailRequired => 'Informe um e-mail válido';

  @override
  String get adminView => 'Ver';

  @override
  String get adminViewFullWallpaper => 'Ver papel de parede completo';

  @override
  String get adminWallId => 'ID';

  @override
  String get adminWallOfTheDay => 'Papel de parede do dia';

  @override
  String get adminWallOrUpload => 'Papel de parede ou envio';

  @override
  String get adminWallpaperAlreadyGone => 'O papel de parede já não estava disponível. Denúncia encerrada.';

  @override
  String get adminWallpaperApproved => 'Papel de parede aprovado';

  @override
  String get adminWallpaperFullScreen => 'Papel de parede em tela cheia';

  @override
  String get adminWallpaperRejected => 'Papel de parede rejeitado';

  @override
  String get adminWallpaperRemoved => 'Papel de parede removido';

  @override
  String get adminWallpaperReport => 'Denúncia de papel de parede';

  @override
  String get adminWallpaperToReview => 'Papel de parede para revisar';

  @override
  String adminWallpapersRemaining(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede restantes',
      one: '$countString papel de parede restante',
      zero: '$countString papéis de parede restantes',
    );
    return '$_temp0';
  }

  @override
  String get adminWalls => 'Papéis de parede';

  @override
  String adminWriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString gravações',
      one: '$countString gravação',
      zero: '$countString gravações',
    );
    return '$_temp0';
  }

  @override
  String get appLinkRetryWhenOnline => 'Sem conexão. Vamos abrir este link quando você voltar a ficar online.';

  @override
  String get appTitle => 'Prism';

  @override
  String get coreBack => 'Voltar';

  @override
  String get coreBio => 'Bio';

  @override
  String get coreBlockCreatorAfterReport => 'Bloquear também este criador';

  @override
  String get coreBothScreens => 'ambas as telas';

  @override
  String get coreCancel => 'Cancelar';

  @override
  String get coreCancelSelection => 'Cancelar seleção';

  @override
  String get coreCancelSignIn => 'Agora não';

  @override
  String get coreCategoryAbstract => 'Abstrato';

  @override
  String get coreCategoryAerial => 'Aéreo';

  @override
  String get coreCategoryAesthetic => 'Estético';

  @override
  String get coreCategoryAiArt => 'Arte com IA';

  @override
  String get coreCategoryAnimals => 'Animais';

  @override
  String get coreCategoryAnime => 'Anime';

  @override
  String get coreCategoryArchitecture => 'Arquitetura';

  @override
  String get coreCategoryArtistic => 'Artístico';

  @override
  String get coreCategoryBirds => 'Aves';

  @override
  String get coreCategoryCars => 'Carros';

  @override
  String get coreCategoryCity => 'Cidade';

  @override
  String get coreCategoryClouds => 'Nuvens';

  @override
  String get coreCategoryComic => 'Quadrinhos';

  @override
  String get coreCategoryCyberpunk => 'Cyberpunk';

  @override
  String get coreCategoryDark => 'Sombrio';

  @override
  String get coreCategoryDefault => 'Categoria';

  @override
  String get coreCategoryFantasy => 'Fantasia';

  @override
  String get coreCategoryFashion => 'Moda';

  @override
  String get coreCategoryFlowers => 'Flores';

  @override
  String get coreCategoryFood => 'Comida';

  @override
  String get coreCategoryForest => 'Floresta';

  @override
  String get coreCategoryGalaxy => 'Galáxia';

  @override
  String get coreCategoryGaming => 'Jogos';

  @override
  String get coreCategoryGradient => 'Degradê';

  @override
  String get coreCategoryIllustration => 'Ilustração';

  @override
  String get coreCategoryKawaii => 'Kawaii';

  @override
  String get coreCategoryLandscape => 'Paisagem';

  @override
  String get coreCategoryMinimal => 'Minimalista';

  @override
  String get coreCategoryMusic => 'Música';

  @override
  String get coreCategoryNature => 'Natureza';

  @override
  String get coreCategoryNeon => 'Neon';

  @override
  String get coreCategoryOcean => 'Oceano';

  @override
  String get coreCategoryPortraits => 'Retratos';

  @override
  String get coreCategoryQuotes => 'Frases';

  @override
  String get coreCategoryRender3d => 'Renderização 3D';

  @override
  String get coreCategoryRobots => 'Robôs';

  @override
  String get coreCategoryScenery => 'Cenários';

  @override
  String get coreCategorySpace => 'Espaço';

  @override
  String get coreCategorySpiritual => 'Espiritualidade';

  @override
  String get coreCategorySports => 'Esportes';

  @override
  String get coreCategoryTech => 'Tecnologia';

  @override
  String get coreCategoryTextures => 'Texturas';

  @override
  String get coreCategoryUnderTheSea => 'Fundo do mar';

  @override
  String get coreCategoryVehicles => 'Veículos';

  @override
  String get coreCategoryVintage => 'Retrô';

  @override
  String get coreCategoryWarriors => 'Guerreiros';

  @override
  String get coreChangeWallpaperTarget => 'Alterar onde o papel de parede será definido';

  @override
  String get coreChangelogLatest => 'Mais recentes';

  @override
  String get coreChooseReportReason => 'Escolha um motivo';

  @override
  String get coreChooseUsername => 'Escolha um nome de usuário disponível.';

  @override
  String get coreCoinAiWallpaper => 'Papel de parede com IA';

  @override
  String get coreCoinAutoRotatePass => 'Passe de rotação automática, 7 dias';

  @override
  String get coreCoinBadgeReward => 'Recompensa de selo';

  @override
  String coreCoinBalance(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '$coinsString moedas Prism';
  }

  @override
  String coreCoinBalanceChange(String balance, String change) {
    return '$balance, $change';
  }

  @override
  String get coreCoinBoost => 'Impulso';

  @override
  String get coreCoinCoins => 'Moedas';

  @override
  String get coreCoinCoinsReturned => 'Moedas devolvidas';

  @override
  String get coreCoinCollectionPreview => 'Prévia da coleção, 24 h';

  @override
  String get coreCoinDailyChest => 'Baú diário';

  @override
  String get coreCoinDailyStreak => 'Sequência diária';

  @override
  String coreCoinDailyStreakDay(String day) {
    return 'Sequência diária, dia $day';
  }

  @override
  String get coreCoinDay7Chest => 'Baú do 7º dia';

  @override
  String get coreCoinDrawTicket => 'Bilhete de sorteio';

  @override
  String get coreCoinDropPack => 'Pacote Drop';

  @override
  String get coreCoinDropWall => 'Papel de parede do Drop';

  @override
  String get coreCoinFirstUpload => 'Primeiro envio';

  @override
  String get coreCoinGiftPass => 'Presente: passe de 24 h';

  @override
  String get coreCoinInviteReward => 'Recompensa por convite';

  @override
  String get coreCoinLiveWallpaperStyle => 'Estilo de papel de parede animado';

  @override
  String get coreCoinPremiumFilter => 'Filtro Premium';

  @override
  String get coreCoinPremiumWallpaper => 'Papel de parede Premium';

  @override
  String get coreCoinProDailyBonus => 'Bônus diário Pro';

  @override
  String get coreCoinProSpin => 'Giro Pro';

  @override
  String get coreCoinProStreakBonus => 'Bônus de sequência Pro';

  @override
  String get coreCoinProfileComplete => 'Perfil completo';

  @override
  String get coreCoinQuest => 'Missão';

  @override
  String coreCoinRefund(String target) {
    return 'Reembolso: $target';
  }

  @override
  String get coreCoinShop => 'Loja';

  @override
  String get coreCoinSpinWheel => 'Girar a roleta';

  @override
  String get coreCoinStreakFreeze => 'Congelamento de sequência';

  @override
  String get coreCoinStreakRestore => 'Restaurar sequência';

  @override
  String get coreCoinWallpaperDownload => 'Download de papel de parede';

  @override
  String get coreCoinWatchedVideo => 'Vídeo assistido';

  @override
  String get coreCoinWeekBonus => 'Bônus semanal';

  @override
  String get coreColorBlack => 'Preto';

  @override
  String get coreColorBlue => 'Azul';

  @override
  String get coreColorBrown => 'Marrom';

  @override
  String get coreColorGreen => 'Verde';

  @override
  String get coreColorGrey => 'Cinza';

  @override
  String get coreColorOrange => 'Laranja';

  @override
  String get coreColorPink => 'Rosa';

  @override
  String get coreColorPurple => 'Roxo';

  @override
  String get coreColorRed => 'Vermelho';

  @override
  String get coreColorTeal => 'Verde-azulado';

  @override
  String get coreColorWhite => 'Branco';

  @override
  String get coreColorYellow => 'Amarelo';

  @override
  String get coreConfirmWallpaperPreview => 'Confirme o papel de parede na prévia do sistema.';

  @override
  String get coreContentNotAvailable => 'Este item não está mais disponível';

  @override
  String get coreContentReportUser => 'usuário';

  @override
  String get coreContentReportWallpaper => 'papel de parede';

  @override
  String coreContentReportWhy(String contentType) {
    return 'Por que você está denunciando este $contentType?';
  }

  @override
  String coreContentReportWhyWithDetails(String contentType, String details) {
    return 'Por que você está denunciando este $contentType ($details)?';
  }

  @override
  String get coreContinueWithApple => 'Continuar com a Apple';

  @override
  String get coreContinueWithGoogle => 'Continuar com o Google';

  @override
  String get coreContributorCouldNotLoad => 'Não foi possível carregar este perfil';

  @override
  String get coreContributorGithub => 'GitHub';

  @override
  String get coreContributorTwitter => 'Twitter';

  @override
  String get coreContributorWebsite => 'Site';

  @override
  String get coreCouldNotLoadChangelog => 'Não foi possível carregar o registro de alterações';

  @override
  String get coreCouldNotLoadWallpaperForEditing => 'Não foi possível carregar o papel de parede para edição';

  @override
  String get coreCouldNotUpdateFavourites => 'Não foi possível atualizar os favoritos. Tente novamente.';

  @override
  String get coreCreatorPreviewDescription => 'Confira o perfil deste criador no Prism.';

  @override
  String get coreDefaultBanner => 'Entre no nosso Telegram';

  @override
  String get coreDepthEffectAutoLongTip =>
      'O Efeito de Profundidade é ativado automaticamente. No iOS 18 ou anterior, deixe desativados os widgets no espaço abaixo do relógio.';

  @override
  String get coreDepthEffectAutoTip => 'O Efeito de Profundidade é ativado automaticamente.';

  @override
  String get coreDepthEffectBadge => 'Profundidade';

  @override
  String get coreDepthEffectBadgeSemantic => 'Compatível com o Efeito de Profundidade';

  @override
  String get coreDepthEffectMenuShortTip => 'Toque em ••• e depois em Efeito de Profundidade.';

  @override
  String get coreDepthEffectMenuTip =>
      'No editor da tela de bloqueio, toque em ••• e depois em Efeito de Profundidade.';

  @override
  String get coreSpatialBadge => 'Espacial';

  @override
  String get coreSpatialBadgeSemantic => 'Funciona como Cena espacial';

  @override
  String get coreSpatialSceneTip => 'No editor da tela de bloqueio, toque no botão Cena espacial.';

  @override
  String get coreDeviceCannotSetScreen => 'Este dispositivo não pode definir essa tela.';

  @override
  String get coreDone => 'Concluído';

  @override
  String coreDown(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'menos $coinsString';
  }

  @override
  String get coreDownloadNotFinishedCoinsReturned => 'O último download não foi concluído. As moedas foram devolvidas.';

  @override
  String get coreDownloadPrismPreviewDescription => 'Baixe o Prism para descobrir papéis de parede incríveis.';

  @override
  String get coreEdit => 'Editar';

  @override
  String get coreEditBioHint => 'Conte um pouco sobre você…';

  @override
  String get coreEditDiscardBody => 'Suas edições não foram salvas.';

  @override
  String get coreEditDiscardTitle => 'Descartar alterações?';

  @override
  String get coreEditEmailInvalid => 'Informe um endereço de e-mail válido.';

  @override
  String coreEditKindLinkInvalid(String kind) {
    return 'Informe um link de $kind válido.';
  }

  @override
  String get coreEditLinkInvalid => 'Informe um link válido.';

  @override
  String get coreEditProfile => 'Editar perfil';

  @override
  String coreEditProfileLink(String kind) {
    return 'Link de $kind';
  }

  @override
  String get coreEditRemoveBioTitle => 'Remover bio?';

  @override
  String get coreEditRemoveConfirm => 'Remover';

  @override
  String coreEditRemoveTitle(String item) {
    return 'Remover $item?';
  }

  @override
  String get coreEditUsernameAvailable => 'Nome de usuário disponível';

  @override
  String get coreEditUsernameChars => 'Use apenas letras, números e sublinhados.';

  @override
  String get coreEditUsernameAllCaps => 'Use pelo menos uma letra minúscula.';

  @override
  String coreEditUsernameMinLength(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Use pelo menos $lengthString caracteres.';
  }

  @override
  String coreEditUsernameRule(int length) {
    final intl.NumberFormat lengthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String lengthString = lengthNumberFormat.format(length);

    return 'Use pelo menos $lengthString letras, números ou sublinhados (_).';
  }

  @override
  String get coreEditUsernameTaken => 'Esse nome de usuário já está em uso.';

  @override
  String get coreEditUsernameTakenSemantic => 'Nome de usuário indisponível';

  @override
  String get coreFavourite => 'Favoritar';

  @override
  String coreFileSizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String get coreGenericSignInError => 'Algo deu errado. Tente novamente!';

  @override
  String get coreGoHome => 'Ir para o início';

  @override
  String get coreGooglePlayServicesSignInError =>
      'Não é possível fazer login pelos serviços do Google Play neste dispositivo.';

  @override
  String get coreGoogleSignInNetworkError =>
      'Não foi possível fazer login com o Google. Verifique sua conexão e tente novamente.';

  @override
  String get coreHomeScreen => 'tela inicial';

  @override
  String get coreHomeScreenSetupUnavailable => 'As configurações da tela inicial não estão mais disponíveis.';

  @override
  String get coreInvalidLinkBody => 'O link que você abriu é inválido ou não está mais disponível.';

  @override
  String coreInvitedToPrismTitle(String name) {
    return '$name convidou você para o Prism';
  }

  @override
  String get coreIosWallpaperGuideBody =>
      'O iOS não permite que apps alterem seu papel de parede. Conclua pelo app Fotos:';

  @override
  String get coreJoinPrismPreviewTitle => 'Entre no Prism';

  @override
  String get coreKeepPrismOpen => 'Mantenha o Prism aberto e tente novamente.';

  @override
  String get coreLoading => 'Carregando';

  @override
  String get coreLoadingMoreFailed => 'Não foi possível carregar mais. Toque para tentar novamente';

  @override
  String get coreLoadingWallpaper => 'Carregando papel de parede';

  @override
  String get coreLockScreen => 'tela de bloqueio';

  @override
  String get coreMatchAccent => 'Combinar com a cor de destaque';

  @override
  String get coreName => 'Nome';

  @override
  String get coreNoWallpaperUrl => 'Não há URL disponível para este papel de parede';

  @override
  String get coreNotNow => 'Agora não';

  @override
  String get coreOpenPhotos => 'Abrir Fotos';

  @override
  String get coreOpenSettings => 'Abrir ajustes';

  @override
  String get corePairPickerDownloads => 'Downloads';

  @override
  String get corePairPickerFavourites => 'Favoritos';

  @override
  String get corePairPickerHistory => 'Histórico';

  @override
  String get corePairPickerNoDownloads => 'Você ainda não fez downloads.';

  @override
  String get corePairPickerNoFavourites => 'Você ainda não tem favoritos.';

  @override
  String get corePairPickerNoHistory => 'Você ainda não tem histórico.';

  @override
  String get corePairPickerTitle => 'Escolha um papel de parede para a tela de bloqueio';

  @override
  String get corePairPickerUseWallpaper => 'Usar este papel de parede na tela de bloqueio';

  @override
  String get corePhotosPermissionMessage =>
      'Permita que o Prism adicione fotos nos Ajustes para salvar papéis de parede.';

  @override
  String get corePhotosStepOpen => 'Abra o app Fotos.';

  @override
  String get corePhotosStepShare => 'Toque em Compartilhar.';

  @override
  String get corePhotosStepUseAsWallpaper => 'Toque em Usar como Papel de Parede.';

  @override
  String corePopupAppVersion(String version) {
    return 'Você está usando a versão $version.';
  }

  @override
  String get corePopupCannotUndo => 'Não é possível desfazer esta ação.';

  @override
  String get corePopupCoverPhoto => 'foto de capa';

  @override
  String get corePopupDiscard => 'Descartar';

  @override
  String get corePopupProfilePhoto => 'foto do perfil';

  @override
  String get corePopupWhatsNew => 'Novidades';

  @override
  String get corePreviousWallpaperRestored => 'Papel de parede anterior restaurado';

  @override
  String get coreProfileSaveFailed => 'Não foi possível salvar seu perfil. Tente novamente.';

  @override
  String get coreProfileUpdated => 'Perfil atualizado';

  @override
  String coreReferralSaved(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Indicação salva. Entre na sua conta para resgatar +$coinsString moedas.';
  }

  @override
  String coreRelativeTimeDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $countString dias',
      one: 'há 1 dia',
      zero: 'há $countString dias',
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
      other: '$countString dias',
      one: '1 dia',
      zero: '$countString dias',
    );
    return 'daqui a $_temp0';
  }

  @override
  String coreRelativeTimeHoursAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $countString horas',
      one: 'há 1 hora',
      zero: 'há $countString horas',
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
      other: '$countString horas',
      one: '1 hora',
      zero: '$countString horas',
    );
    return 'daqui a $_temp0';
  }

  @override
  String get coreRelativeTimeJustNow => 'Agora mesmo';

  @override
  String coreRelativeTimeMinutesAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $countString minutos',
      one: 'há 1 minuto',
      zero: 'há $countString minutos',
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
      other: '$countString minutos',
      one: '1 minuto',
      zero: '$countString minutos',
    );
    return 'daqui a $_temp0';
  }

  @override
  String get coreRemoveBio => 'Remover bio';

  @override
  String get coreReport => 'Denunciar';

  @override
  String get coreReportCouldNotSubmit => 'Não foi possível enviar sua denúncia. Tente novamente.';

  @override
  String get coreReportDetailsHint => 'Quer contar mais alguma coisa?';

  @override
  String get coreReportDetailsOptional => 'Detalhes (opcional)';

  @override
  String get coreReportReasonCopyright => 'Direitos autorais / propriedade';

  @override
  String get coreReportReasonHarassment => 'Assédio ou discurso de ódio';

  @override
  String get coreReportReasonOther => 'Outro';

  @override
  String get coreReportReasonSexual => 'Conteúdo sexual ou adulto';

  @override
  String get coreReportReasonSpam => 'Spam ou conteúdo enganoso';

  @override
  String get coreReportSent => 'Denúncia enviada. Agradecemos.';

  @override
  String get coreRestorePreviousWallpaperFailed =>
      'Não foi possível restaurar o papel de parede anterior. Defina-o novamente pelo histórico de papéis de parede.';

  @override
  String get coreRetry => 'Tentar novamente';

  @override
  String get coreRetryImage => 'Tentar imagem novamente';

  @override
  String coreRetryOnScreen(String screen) {
    return 'Tentar novamente em $screen';
  }

  @override
  String get coreSaveChanges => 'Salvar alterações';

  @override
  String get coreSeeFullChangelog => 'Ver registro completo de alterações';

  @override
  String get coreSeeMore => 'Ver mais';

  @override
  String coreSelectCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString selecionados';
  }

  @override
  String get coreSendReport => 'Enviar denúncia';

  @override
  String get coreSet => 'Definir';

  @override
  String get coreSetItAsWallpaper => 'Definir como papel de parede';

  @override
  String get coreSetWallpaper => 'Definir papel de parede';

  @override
  String coreSetWallpaperOn(String screen) {
    return 'Definir papel de parede em $screen';
  }

  @override
  String get coreShare => 'Compartilhar';

  @override
  String coreShareCardClipboard(String link) {
    return '🔥 Confira ➜ $link';
  }

  @override
  String get coreShareFormatStory => 'Story';

  @override
  String get coreShareFormatPost => 'Publicação';

  @override
  String get coreShareFormatClean => 'Minimalista';

  @override
  String get coreShareTargetInstagram => 'Instagram';

  @override
  String get coreShareTargetCopyLink => 'Copiar link';

  @override
  String get coreShareTargetSaveImage => 'Salvar imagem';

  @override
  String get coreShareTargetMore => 'Mais';

  @override
  String coreShareCardBy(String creator) {
    return 'por $creator';
  }

  @override
  String get coreShareImageSaved => 'Imagem salva';

  @override
  String get coreShareImageFailed => 'Não foi possível salvar a imagem. Tente novamente.';

  @override
  String get coreShareInstagramFailed => 'Não foi possível abrir o Instagram. Tente novamente.';

  @override
  String get coreSharePreviewFailed => 'Não foi possível criar esta imagem. Use Mais para compartilhar o link.';

  @override
  String get coreShareLinkCopied => 'Link de compartilhamento copiado!';

  @override
  String coreShareProfileClipboard(String link) {
    return 'Oi! Confira meu perfil no Prism ➜ $link';
  }

  @override
  String coreShareWallpaperClipboard(String link) {
    return 'Oi! Confira este papel de parede ➜ $link';
  }

  @override
  String get coreShareWallpaperGeneric => 'Este papel de parede incluído está disponível no app Prism.';

  @override
  String get coreSignInFeatureBody => 'Sua conta reúne suas moedas, seus favoritos e seus envios.';

  @override
  String coreSignInFeatureTitle(String feature) {
    return 'Entre na sua conta para usar $feature';
  }

  @override
  String get coreSignInPopupBody => 'Tenha seus favoritos, envios e moedas em todos os dispositivos.';

  @override
  String get coreSignInPopupTitle => 'Entre no Prism';

  @override
  String get coreSignInPromptAction => 'Entrar';

  @override
  String get coreSignInToReportContent => 'Entre na sua conta para denunciar conteúdo';

  @override
  String get coreSignInToSyncFavourites => 'Entre na sua conta para acessar seus favoritos em todos os dispositivos';

  @override
  String get coreSigningIn => 'Entrando';

  @override
  String get coreSomethingWentWrong => 'Algo deu errado. Tente novamente.';

  @override
  String coreStreakNext(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Próxima: +$coinsString';
  }

  @override
  String coreStreakSemantics(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Sequência de $daysString dias, próxima recompensa: $coinsString moedas';
  }

  @override
  String get coreCustomAccent => 'Cor personalizada';

  @override
  String get coreCustomAccentHex => 'Código hexadecimal';

  @override
  String get coreCustomAccentHue => 'Matiz';

  @override
  String get coreCustomAccentSaturation => 'Saturação';

  @override
  String get coreCustomAccentLightness => 'Luminosidade';

  @override
  String get coreCustomAccentInvalidHex => 'Digite 6 dígitos hexadecimais, como #E57697.';

  @override
  String get coreCustomAccentLowContrast =>
      'Esta cor é difícil de ver neste tema. Escolha um tom mais claro ou mais escuro.';

  @override
  String get coreCustomAccentApply => 'Usar cor';

  @override
  String coreThemeAccentSemanticLabel(int index, int count) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Cor de destaque $indexString de $countString';
  }

  @override
  String get coreThemeAmoled => 'AMOLED';

  @override
  String get coreThemeCoffee => 'Café';

  @override
  String get coreThemeCottonBlue => 'Azul algodão';

  @override
  String get coreThemeCustom => 'Tema personalizado';

  @override
  String get coreThemeDeepOcean => 'Oceano profundo';

  @override
  String get coreThemeFrostWhite => 'Branco glacial';

  @override
  String get coreThemeJungle => 'Selva';

  @override
  String get coreThemeLocked => 'Bloqueado';

  @override
  String get coreThemeMaterialDark => 'Material escuro';

  @override
  String get coreThemeMaterialYou => 'Material You';

  @override
  String get coreThemeOlive => 'Oliva';

  @override
  String get coreThemePepper => 'Pimenta';

  @override
  String get coreThemeRose => 'Rosa';

  @override
  String get coreThemeSky => 'Céu';

  @override
  String get coreThemeSteel => 'Aço';

  @override
  String get coreThemeSpooky => 'Assustador';

  @override
  String get spookyBannerTitle => 'O tema Assustador chegou';

  @override
  String get spookyBannerSubtitle => 'Laranja, preto e algumas aranhas. Grátis. Toque para experimentar.';

  @override
  String get spookyAnnouncementTitle => 'Novo: o tema Assustador 🎃';

  @override
  String get spookyAnnouncementBody => 'Laranja, preto e algumas aranhas. É grátis. Toque para experimentar.';

  @override
  String get coreThemeDiwali => 'Diwali';

  @override
  String get diwaliBannerTitle => 'O tema Diwali chegou';

  @override
  String get diwaliBannerSubtitle => 'Diyas, fogos de artifício e ouro. Grátis. Toque para experimentar.';

  @override
  String get diwaliAnnouncementTitle => 'Novo: o tema Diwali 🪔';

  @override
  String get diwaliAnnouncementBody => 'Diyas, fogos de artifício e ouro. É grátis. Toque para experimentar.';

  @override
  String get coreThisPageDoesNotExist => 'Esta página não existe';

  @override
  String get coreTryAgain => 'Tentar novamente';

  @override
  String get coreUndo => 'Desfazer';

  @override
  String coreUp(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'mais $coinsString';
  }

  @override
  String get coreUploadFailureDailyLimit => 'Você atingiu o limite de envios de hoje. Tente novamente amanhã.';

  @override
  String get coreUploadFailureFileType =>
      'Este tipo de arquivo não é compatível. Use uma imagem JPG, PNG, WebP ou HEIC.';

  @override
  String get coreUploadFailureGeneric =>
      'O envio não foi concluído. Sua imagem continua aqui para você tentar novamente.';

  @override
  String get coreUploadFailureInProgress => 'Já há um envio em andamento. Aguarde um instante e tente novamente.';

  @override
  String get coreUploadFailureOversize => 'Esta imagem tem mais de 15 MB. Escolha uma menor.';

  @override
  String get coreUploadFailureSignIn => 'Entre novamente para enviar.';

  @override
  String get coreUploadFailureWeeklyLimit => 'Você atingiu o limite semanal de envios gratuitos.';

  @override
  String get coreUploadSubmittedSuccess => 'Seu papel de parede foi enviado e está em análise.';

  @override
  String get coreUsername => 'Nome de usuário';

  @override
  String get coreUsernameCheckFailed => 'Não foi possível verificar o nome de usuário. Tente novamente.';

  @override
  String get coreUsernameRequiredToShareProfile => 'Defina um nome de usuário para compartilhar seu perfil';

  @override
  String get coreWallpaperApplied => 'Papel de parede definido com sucesso!';

  @override
  String get coreWallpaperBothScreens => 'Ambas as telas';

  @override
  String coreWallpaperBySemanticLabel(String name) {
    return 'Papel de parede de $name';
  }

  @override
  String get coreWallpaperDownloadedPictures => 'Papel de parede baixado em Pictures/Prism!';

  @override
  String get coreWallpaperEditApplyColorFailed => 'Não foi possível aplicar a cor. Tente novamente.';

  @override
  String get coreWallpaperErrorGeneric => 'Não foi possível definir o papel de parede.';

  @override
  String get coreWallpaperErrorImageTooLarge => 'Esta imagem é grande demais para o seu dispositivo definir.';

  @override
  String get coreWallpaperErrorInvalidVideo =>
      'Não é possível reproduzir esse vídeo como papel de parede. Tente outro clipe.';

  @override
  String get coreWallpaperErrorLiveGeneric => 'Não foi possível definir o papel de parede animado. Tente novamente.';

  @override
  String get coreWallpaperErrorMemory => 'Memória insuficiente. Feche outros apps e tente novamente.';

  @override
  String get coreWallpaperErrorNotAllowed =>
      'Seu dispositivo ou perfil de trabalho não permite alterar o papel de parede.';

  @override
  String get coreWallpaperErrorPermission => 'O Prism não tem permissão para ler esse arquivo.';

  @override
  String get coreWallpaperErrorReadFile => 'Não foi possível ler o arquivo. Tente novamente.';

  @override
  String get coreWallpaperErrorSourceTooLarge => 'Esse arquivo é grande demais para um papel de parede animado.';

  @override
  String get coreWallpaperErrorStyle => 'Este dispositivo não conseguiu iniciar esse estilo. Tente outro.';

  @override
  String get coreWallpaperErrorSystemPreview => 'Não foi possível abrir a pré-visualização do sistema.';

  @override
  String get coreWallpaperErrorTextureDimensions => 'Essa imagem é grande demais para um papel de parede animado.';

  @override
  String get coreWallpaperErrorTimeout => 'Tempo esgotado. Verifique sua conexão e tente novamente.';

  @override
  String get coreWallpaperHomeScreen => 'Tela inicial';

  @override
  String get coreWallpaperHomeSetLockFailed => 'Tela inicial definida. Falha na tela de bloqueio.';

  @override
  String get coreWallpaperLinkCopyFailed => 'Não foi possível copiar o link. Tente novamente.';

  @override
  String get coreWallpaperLinkCreateFailed => 'Não foi possível criar o link de compartilhamento. Tente novamente.';

  @override
  String get coreWallpaperLoadTimedOut =>
      'Tempo esgotado ao carregar o papel de parede. Verifique sua conexão e tente novamente.';

  @override
  String get coreWallpaperLockScreen => 'Tela de bloqueio';

  @override
  String get coreWallpaperOfflineUnavailable =>
      'Este papel de parede não está salvo neste dispositivo. Conecte-se à internet e tente novamente.';

  @override
  String coreWallpaperPartialSet(String applied, String failed) {
    return '$applied definida. $failed falhou.';
  }

  @override
  String get coreWallpaperPreviewDescription => 'Veja este papel de parede incrível do Prism.';

  @override
  String get coreWallpaperPreviewTitle => 'Papel de parede no Prism';

  @override
  String get coreWallpaperSaveFailed => 'Não foi possível definir o papel de parede. Tente novamente.';

  @override
  String get coreWallpaperSavedPhotos => 'Salvo em Fotos.';

  @override
  String get coreWallpaperSavedToast => 'Sua recompensa do anúncio foi adicionada.';

  @override
  String coreWallpaperSavedWithTip(String saved, String tip) {
    return '$saved $tip';
  }

  @override
  String get coreWallpaperSemanticLabel => 'Papel de parede';

  @override
  String get coreWallpaperSet => 'Papel de parede definido';

  @override
  String get coreWallpaperShareFailed => 'Não foi possível compartilhar este papel de parede agora.';

  @override
  String get coreWallpaperShareRetryFailed => 'Não foi possível compartilhar este papel de parede. Tente novamente.';

  @override
  String get debugAdminReviewDescription => 'Ferramenta de moderação de conteúdo e notificações push';

  @override
  String get debugAdminShortcuts => 'Atalhos de admin';

  @override
  String get debugLiveActivityPreview => 'Pré-visualizar Live Activity';

  @override
  String get debugLiveActivityPreviewDescription => 'Executa uma atividade de exemplo: pronta após 8 segundos';

  @override
  String get debugLiveActivityUnavailable => 'Live Activities estão desativadas ou não são compatíveis';

  @override
  String get debugReviewActivityPreview => 'Pré-visualizar atividade da fila de revisão';

  @override
  String get debugReviewActivityPreviewDescription =>
      'Mostra os papéis de parede aguardando revisão na tela de bloqueio';

  @override
  String get debugAllTags => 'Todas as tags';

  @override
  String get debugAndroidVersion => 'Versão do Android';

  @override
  String get debugAnimationSpeed => 'Velocidade da animação';

  @override
  String get debugAppInfo => 'Informações do app';

  @override
  String get debugAppName => 'Nome do app';

  @override
  String get debugAppVersion => 'Versão do app';

  @override
  String get debugAutoScrollOff => 'Desativar rolagem automática';

  @override
  String get debugAutoScrollOn => 'Ativar rolagem automática';

  @override
  String debugBackendName(String backend) {
    return 'Backend: $backend';
  }

  @override
  String get debugBoard => 'Placa';

  @override
  String get debugBrand => 'Marca';

  @override
  String get debugBuildNumber => 'Número do build';

  @override
  String get debugBuildSignature => 'Assinatura do build';

  @override
  String get debugCacheCleared => 'Cache do app limpo';

  @override
  String get debugCancel => 'Cancelar';

  @override
  String get debugCheckLogsRetry => 'Verifique os logs e tente novamente.';

  @override
  String get debugClear => 'Limpar';

  @override
  String get debugClearAll => 'Limpar tudo';

  @override
  String get debugClearAllStorageBody =>
      'Isso exclui permanentemente todos os dados armazenados localmente. O app pode se comportar de forma inesperada até ser reiniciado.';

  @override
  String get debugClearAllStorageTitle => 'Limpar todo o armazenamento?';

  @override
  String get debugClearAppCache => 'Limpar cache do app';

  @override
  String get debugClearAppCacheDescription => 'Limpar cache de imagens, feed e notificações';

  @override
  String get debugClearImageCache => 'Limpar cache de imagens';

  @override
  String get debugClearImageCacheDescription => 'Remover o cache de imagens da memória';

  @override
  String get debugClearLogsBody => 'Isso remove todas as entradas de log mantidas na memória.';

  @override
  String get debugClearLogsTitle => 'Limpar logs?';

  @override
  String get debugClearSearch => 'Limpar busca';

  @override
  String get debugCoins => 'Moedas';

  @override
  String get debugCopied => 'Copiado';

  @override
  String get debugCopiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get debugCopy => 'Copiar';

  @override
  String get debugCopyDiagnosticReport => 'Copiar relatório de diagnóstico';

  @override
  String get debugCopyFiltered => 'Copiar tudo (filtrado)';

  @override
  String get debugCopyFullDetail => 'Copiar detalhes completos';

  @override
  String debugCopyTitle(String title) {
    return 'Copiar $title';
  }

  @override
  String get debugCopyValue => 'Copiar valor';

  @override
  String debugCouldNotClearCache(String error) {
    return 'Não foi possível limpar o cache do app: $error';
  }

  @override
  String get debugCouldNotSaveValue => 'Não foi possível salvar o valor';

  @override
  String get debugCrashApp => 'Fazer o app travar';

  @override
  String get debugDangerZone => 'Zona de perigo';

  @override
  String get debugDarkCard => 'Cartão escuro';

  @override
  String get debugDefaultValue => '(padrão)';

  @override
  String get debugDelete => 'Excluir';

  @override
  String get debugDeleteKey => 'Excluir chave';

  @override
  String debugDeleteKeyBody(String key) {
    return 'Excluir \"$key\" do armazenamento local.';
  }

  @override
  String get debugDeleteKeyTitle => 'Excluir chave?';

  @override
  String get debugDevice => 'Dispositivo';

  @override
  String get debugDeviceName => 'Dispositivo';

  @override
  String get debugDevicePixelRatio => 'Densidade de pixels do dispositivo';

  @override
  String get debugDiagnosticCopied => 'Relatório de diagnóstico copiado para a área de transferência';

  @override
  String get debugDiagnosticReportHeading => '=== Relatório de Diagnóstico de Depuração do Prism ===';

  @override
  String get debugEditValue => 'Editar valor';

  @override
  String get debugEmail => 'E-mail';

  @override
  String get debugEmptyList => 'Lista vazia';

  @override
  String get debugEnvironment => 'Ambiente';

  @override
  String get debugError => 'Erro';

  @override
  String get debugErrorCopied => 'Erro copiado';

  @override
  String get debugErrorStreakLost => 'Erro, sequência perdida';

  @override
  String get debugErrorValue => 'erro';

  @override
  String get debugExportFile => 'Exportar como arquivo';

  @override
  String get debugFavouriteAdded => 'Favorito adicionado';

  @override
  String get debugFilterByTag => 'Filtrar por tag';

  @override
  String get debugFilterKeys => 'Filtrar chaves';

  @override
  String get debugFingerprint => 'Impressão digital';

  @override
  String get debugFirestoreTelemetryDescription => 'Ver o perfil de leituras e gravações do Firestore';

  @override
  String get debugFlagsReset => 'Flags de depuração redefinidas';

  @override
  String get debugForceCrash => 'Forçar falha';

  @override
  String get debugForceCrashBody => 'Isso gera uma exceção para verificar se o Sentry reporta erros.';

  @override
  String get debugForceCrashDescription => 'Gerar uma exceção para testar os relatórios do Sentry';

  @override
  String get debugForceCrashTitle => 'Forçar falha?';

  @override
  String debugGeneratedAt(String date) {
    return 'Gerado em: $date';
  }

  @override
  String get debugHardware => 'Hardware';

  @override
  String get debugIdentifier => 'Identificador';

  @override
  String get debugImageCacheCleared => 'Cache de imagens limpo';

  @override
  String get debugIsAdmin => 'É admin';

  @override
  String get debugIsPremium => 'É Premium';

  @override
  String get debugLevel => 'Nível';

  @override
  String get debugLightCard => 'Cartão claro';

  @override
  String get debugLoadingSearch => 'Carregando, busca';

  @override
  String get debugLogDetail => 'Detalhes do log';

  @override
  String debugLogEntryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString entradas',
      one: '$countString entrada',
      zero: '$countString entradas',
    );
    return '$_temp0';
  }

  @override
  String get debugLoggedIn => 'Com login';

  @override
  String get debugLoggingAndNetwork => 'Logs e rede';

  @override
  String get debugLogicalSize => 'Tamanho lógico';

  @override
  String get debugLogs => 'Logs';

  @override
  String get debugLogsAppearHere => 'As linhas de log aparecem aqui enquanto o app roda.';

  @override
  String get debugMaintenance => 'Manutenção';

  @override
  String get debugManufacturer => 'Fabricante';

  @override
  String get debugMascot => 'Mascote';

  @override
  String get debugMessage => 'Mensagem';

  @override
  String get debugMixpanelEnabled => 'Mixpanel ativado';

  @override
  String get debugMixpanelTokenPresent => 'Token do Mixpanel presente';

  @override
  String get debugModel => 'Modelo';

  @override
  String get debugMoodCalm => 'Calmo';

  @override
  String get debugMoodCelebrate => 'Comemorando';

  @override
  String get debugMoodCurious => 'Curioso';

  @override
  String get debugMoodHappy => 'Feliz';

  @override
  String get debugMoodLove => 'Apaixonado';

  @override
  String get debugMoodProud => 'Orgulhoso';

  @override
  String get debugMoodSad => 'Triste';

  @override
  String get debugMoodSleepy => 'Sonolento';

  @override
  String get debugMoodSurprised => 'Surpreso';

  @override
  String get debugMoodWorried => 'Preocupado';

  @override
  String get debugName => 'Nome';

  @override
  String get debugNoKeysFound => 'Nenhuma chave encontrada';

  @override
  String get debugNoLogs => 'Nenhum log';

  @override
  String get debugNoMatchingLogs => 'Nenhuma linha de log corresponde aos filtros.';

  @override
  String get debugNotAvailable => 'N/D';

  @override
  String get debugNotSignedIn => 'Sem login';

  @override
  String get debugNothingNew => 'Nada novo';

  @override
  String get debugOfflineStreakRisk => 'Offline, sequência em risco';

  @override
  String get debugPackage => 'Pacote';

  @override
  String get debugPackageName => 'Nome do pacote';

  @override
  String get debugPaintBaselines => 'Pintar linhas de base';

  @override
  String get debugPaintBaselinesDescription => 'Mostrar guias de linha de base do texto';

  @override
  String get debugPaintSize => 'Pintar tamanho';

  @override
  String get debugPaintSizeDescription => 'Mostrar os limites do layout em todos os widgets';

  @override
  String get debugPaintSizeWarning =>
      'Pintar tamanho, arco-íris de repintura e linhas de base só funcionam em builds de depuração e de profile.';

  @override
  String get debugPerformanceOverlay => 'Overlay de desempenho';

  @override
  String get debugPerformanceOverlayDescription => 'Gráficos de uso de GPU e CPU';

  @override
  String get debugPersistenceBackend => 'Backend de persistência';

  @override
  String get debugPexelsKeyPresent => 'Chave do Pexels presente';

  @override
  String get debugPhysicalDevice => 'É dispositivo físico';

  @override
  String get debugPhysicalSize => 'Tamanho físico';

  @override
  String get debugPlatform => 'Plataforma';

  @override
  String get debugRcApiKeyPresent => 'Chave de API do RC presente';

  @override
  String get debugReduceMotionPose => 'Mostra a pose de movimento reduzido de cada humor';

  @override
  String get debugRefresh => 'Atualizar';

  @override
  String get debugRemoteConfig => 'Remote Config';

  @override
  String get debugRemoteConfigUnavailable => 'Remote Config indisponível';

  @override
  String get debugRendering => 'Renderização';

  @override
  String get debugRepaintRainbow => 'Arco-íris de repintura';

  @override
  String get debugRepaintRainbowDescription => 'Destacar áreas repintadas em cores alternadas';

  @override
  String get debugResetFlags => 'Redefinir todas as flags de depuração';

  @override
  String get debugResetFlagsDescription => 'Restaurar todas as opções para os valores padrão';

  @override
  String get debugSave => 'Salvar';

  @override
  String get debugSaveValueAsText => 'Ao salvar, o valor é gravado como texto.';

  @override
  String get debugScreen => 'Tela';

  @override
  String get debugSdkInt => 'Nível do SDK';

  @override
  String get debugSearchLogs => 'Buscar logs';

  @override
  String get debugSemanticsDebugger => 'Depurador de semântica';

  @override
  String get debugSemanticsDebuggerDescription => 'Sobrepor os rótulos da árvore de acessibilidade';

  @override
  String get debugSentryDsnPresent => 'DSN do Sentry presente';

  @override
  String get debugSentryEnabled => 'Sentry ativado';

  @override
  String get debugSentryEnv => 'Ambiente do Sentry';

  @override
  String get debugSequence => 'Sequência';

  @override
  String get debugShowLogToasts => 'Mostrar toasts de log';

  @override
  String get debugShowLogToastsDescription => 'Exibir entradas de log como toasts breves sobrepostos';

  @override
  String get debugSimulateNoInternet => 'Simular sem internet';

  @override
  String get debugSimulateNoInternetDescription => 'Substitui as verificações de conectividade para informar offline';

  @override
  String get debugSpeed => 'Velocidade';

  @override
  String get debugStackTrace => 'Rastreamento da pilha';

  @override
  String get debugStackTraceCopied => 'Rastreamento da pilha copiado';

  @override
  String get debugStillPoses => 'Poses estáticas';

  @override
  String get debugStorage => 'Armazenamento';

  @override
  String get debugStorageCleared => 'Todo o armazenamento foi limpo';

  @override
  String debugStorageKeyCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString chaves',
      one: '$countString chave',
      zero: '$countString chaves',
    );
    return '$_temp0';
  }

  @override
  String get debugStorageNotInitialized => 'Armazenamento não inicializado';

  @override
  String get debugStorageReadError => 'Não foi possível ler o armazenamento';

  @override
  String get debugStreakCoinsPurchase => 'Sequência, moedas, compra';

  @override
  String get debugStreakKeptToday => 'Sequência mantida hoje';

  @override
  String get debugSubscriptionTier => 'Nível da assinatura';

  @override
  String get debugSystemName => 'Nome do sistema';

  @override
  String get debugSystemVersion => 'Versão do sistema';

  @override
  String get debugTime => 'Hora';

  @override
  String get debugTitle => 'Depuração';

  @override
  String get debugTools => 'Ferramentas';

  @override
  String debugTypeName(String type) {
    return 'Tipo: $type';
  }

  @override
  String get debugUser => 'Usuário';

  @override
  String get debugUserId => 'ID do usuário';

  @override
  String get debugUsername => 'Nome de usuário';

  @override
  String get debugValue => 'Valor';

  @override
  String get debugVersion => 'Versão';

  @override
  String get debugWallpaperSetSaved => 'Papel de parede definido ou salvo';

  @override
  String get debugWotdNotification => 'Papel de parede do dia, notificação';

  @override
  String get deepLinkInputChooseImage => 'Escolher imagem';

  @override
  String get deepLinkInputChooseImageDescription => 'Escolha uma imagem da sua galeria para continuar.';

  @override
  String get deepLinkInputClockPreviewTitle => 'Prévia do relógio';

  @override
  String get deepLinkInputEditTitle => 'Editar um papel de parede';

  @override
  String get deepLinkInputFiltersTitle => 'Filtros de papel de parede';

  @override
  String get deepLinkInputGalleryError => 'Não foi possível abrir sua galeria. Tente novamente.';

  @override
  String get deepLinkInputLiveTitle => 'Papel de parede animado';

  @override
  String get deepLinkInputPhotoPreviewTitle => 'Prévia da foto';

  @override
  String get deepLinkInputPositionTitle => 'Posicionar um papel de parede';

  @override
  String get deepLinkInputUploadTitle => 'Enviar um papel de parede';

  @override
  String get deepLinkInputWallpaperPreviewTitle => 'Prévia do papel de parede';

  @override
  String get economyActivity => 'Atividade';

  @override
  String get economyActivityEmptyMessage =>
      'Assista a um vídeo ou mantenha sua sequência para ganhar suas primeiras moedas.';

  @override
  String get economyActivityLoadFailed => 'Não foi possível carregar a atividade.';

  @override
  String get economyAdCreditFailure => 'Não foi possível creditar as moedas agora.';

  @override
  String get economyAdDailyLimit => 'Limite diário atingido. Volte amanhã.';

  @override
  String get economyAdNotCompleted => 'O anúncio não foi concluído.';

  @override
  String get economyAdOffline => 'Você está offline. Verifique sua conexão e tente novamente.';

  @override
  String economyAdRewardDetails(int first, int reward, int maximum) {
    final intl.NumberFormat firstNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String firstString = firstNumberFormat.format(first);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'O primeiro do dia +$firstString, depois +$rewardString. Até $maximumString por dia.';
  }

  @override
  String get economyAdRewardPending =>
      'Ainda não foi possível confirmar sua recompensa. As moedas chegam quando você voltar a ficar online.';

  @override
  String get economyAdUnavailable => 'Nenhum anúncio disponível agora. Tente novamente mais tarde.';

  @override
  String get economyAddPhotoBio => 'Adicione uma foto e uma bio';

  @override
  String get economyAddedToBalance => 'Adicionado ao seu saldo';

  @override
  String get economyAddedToCollection => 'Adicionado à sua coleção';

  @override
  String get economyAddedToXp => 'Adicionado ao seu XP';

  @override
  String get economyAdsOffPrivacy => 'Os anúncios estão desativados. Altere isso em Configurações > Privacidade.';

  @override
  String get economyAiBusyRefunded =>
      'A IA está muito ocupada agora. Tente novamente mais tarde. Suas moedas foram devolvidas.';

  @override
  String get economyAiChargeUnconfirmed =>
      'Não foi possível confirmar a cobrança. Qualquer moeda debitada será devolvida.';

  @override
  String get economyAiCheckStatus => 'Verificar status';

  @override
  String economyAiCoinsNeeded(int cost, int balance) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Você precisa de $costString moedas. Você tem $balanceString.';
  }

  @override
  String get economyAiConnectToGenerate => 'Sem conexão. Conecte-se à internet e tente novamente.';

  @override
  String get economyAiCouldNotConfirmSubmission =>
      'Não foi possível confirmar o envio. Verifique o status da revisão antes de tentar novamente.';

  @override
  String get economyAiCropMayDiffer => 'O corte pode ser um pouco diferente no seu dispositivo.';

  @override
  String get aiLiveActivityGenerating => 'Criando seu papel de parede';

  @override
  String get aiLiveActivityReady => 'Seu papel de parede está pronto';

  @override
  String get aiLiveActivityFailed => 'Não foi possível criar';

  @override
  String get aiLiveActivityStale => 'Ainda trabalhando nisso';

  @override
  String get aiLiveActivityOpen => 'Abrir no Prism';

  @override
  String get aiResultApply => 'Aplicar';

  @override
  String get aiResultEditPrompt => 'Editar descrição';

  @override
  String get aiSessionStripLabel => 'Papéis de parede desta sessão';

  @override
  String aiSessionTake(int index, int count) {
    final intl.NumberFormat indexNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String indexString = indexNumberFormat.format(index);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Versão $indexString de $countString';
  }

  @override
  String get aiFollowUpWatercolour => 'Em aquarela';

  @override
  String get aiFollowUpNight => 'Versão noturna';

  @override
  String get aiFollowUpMinimal => 'Mais minimalista';

  @override
  String get aiFollowUpWarmer => 'Mais quente';

  @override
  String get aiFollowUpDepth => 'Adicionar profundidade';

  @override
  String aiFollowUpCostLabel(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Cada nova versão custa $costString moedas';
  }

  @override
  String get aiFollowUpConfirmTitle => 'Criar uma nova versão?';

  @override
  String aiFollowUpConfirmBody(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Uma nova versão cria outro papel de parede a partir deste. Cada uma custa $costString moedas.';
  }

  @override
  String get aiFollowUpConfirmAction => 'Criar';

  @override
  String get economyAiDailyLimit => 'Você atingiu o limite de IA de hoje.';

  @override
  String get economyAiDescribeChanges => 'Diga o que você quer diferente, como cores, clima ou detalhes.';

  @override
  String get economyAiDescribeScene => 'Descreva uma cena para gerar.';

  @override
  String get economyAiDownloadFailed => 'Não foi possível baixar! Tente novamente.';

  @override
  String economyAiFailureWithRefund(String message, String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'refunded': ' Moedas devolvidas.',
      'pending': ' Reembolso pendente.',
      'other': ' Não foi possível concluir o reembolso.',
    });
    return '$message$_temp0';
  }

  @override
  String get economyAiGenerate => 'Gerar';

  @override
  String get economyAiGenerateAnother => 'Gerar outro';

  @override
  String get economyAiGenerateFailed => 'Não foi possível gerar agora. Tente novamente.';

  @override
  String get economyAiGenerateGenericFailure => 'Algo deu errado. Tente novamente.';

  @override
  String get economyAiGeneratedWallpaper => 'Papel de parede gerado';

  @override
  String economyAiGenerationFrom(String date) {
    return 'Geração de $date';
  }

  @override
  String get economyAiGenerationRollingOut =>
      'A geração por IA está sendo liberada aos poucos. Tente novamente em breve.';

  @override
  String get economyAiGenerationTime => 'Isso leva cerca de 20 segundos';

  @override
  String get economyAiHistoryEmpty =>
      'Cada papel de parede que você gerar aparece aqui, para você comparar ou voltar a um anterior.';

  @override
  String get economyAiHistoryFailed => 'Não foi possível carregar o histórico. Puxe para atualizar.';

  @override
  String get economyAiMatchingScreenSize => 'Ajustando ao tamanho da sua tela…';

  @override
  String get economyAiApplyingStyle => 'Aplicando seu estilo…';

  @override
  String get economyAiFinalizingWallpaper => 'Finalizando seu papel de parede…';

  @override
  String get economyAiRemixHint => 'Céu mais escuro, cores mais quentes, contornos mais suaves…';

  @override
  String economyAiNeedCoinsToGenerate(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'São necessárias $costString moedas para gerar.';
  }

  @override
  String economyNeedMoreCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $countString moedas.',
      one: 'Falta $countString moeda.',
      zero: 'Faltam $countString moedas.',
    );
    return '$_temp0';
  }

  @override
  String get economyAiNoConnection => 'Sem conexão. Verifique sua rede e tente novamente.';

  @override
  String get economyAiNoConnectionRetry => 'Sem conexão. Tente novamente.';

  @override
  String get economyAiOfflineHistory => 'Você está offline ou a rede falhou. Puxe para atualizar quando voltar.';

  @override
  String get economyAiOfflineSavedHistory => 'Você está offline. O histórico salvo continua disponível.';

  @override
  String get economyAiPaymentCheckFailed => 'A verificação do pagamento falhou. Suas moedas serão devolvidas.';

  @override
  String get economyAiPreparingShare => 'Preparando o compartilhamento';

  @override
  String get economyAiPromptBlocked => 'Esse prompt não é permitido.';

  @override
  String economyAiPromptTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'A descrição é muito longa (máx. $maximumString caracteres).';
  }

  @override
  String get economyAiQuality => 'Qualidade';

  @override
  String get economyAiQualityBalanced => 'Equilibrada';

  @override
  String get economyAiQualityFast => 'Rápida';

  @override
  String get economyAiQualityHigh => 'Qualidade';

  @override
  String economyAiQualitySemantics(String quality, int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return '$quality, $costString moedas';
  }

  @override
  String get economyAiRecent => 'Recentes';

  @override
  String get economyAiRefineExplanation =>
      'Diga o que deve mudar. Isso cria um novo papel de parede a partir do mesmo prompt com uma nova semente, então ele pode ficar bem diferente.';

  @override
  String get economyAiResultBlocked => 'O resultado foi bloqueado. Tente outro prompt.';

  @override
  String economyAiRolloutBody(int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Está ativo para $percentString% das contas até agora. Tente novamente em breve.';
  }

  @override
  String get economyAiRolloutTitle => 'O papel de parede com IA está sendo liberado aos poucos';

  @override
  String get economyAiSave => 'Salvar';

  @override
  String get economyAiSaveFailed => 'Não foi possível salvar esse arquivo. Tente novamente.';

  @override
  String get economyAiSceneIdea => 'Ideia de cena';

  @override
  String get economyAiSceneIdeaMessage => 'Use esta cena na sua descrição (editável)';

  @override
  String get economyAiSetAsWallpaper => 'Definir como papel de parede';

  @override
  String get economyAiShare => 'Compartilhar';

  @override
  String get economyAiShareFailed => 'Não foi possível compartilhar. Tente novamente.';

  @override
  String get economyAiShareReviewNotice =>
      'Os moderadores revisam os envios antes de eles aparecerem no Prism. Compartilhe apenas trabalhos dos quais você tenha os direitos.';

  @override
  String get economyAiShareWithCommunity => 'Compartilhar com a comunidade?';

  @override
  String get economyAiShuffle => 'Misturar';

  @override
  String get economyAiShuffleMessage => 'Misturar uma nova descrição de exemplo';

  @override
  String get economyAiStillWorking => 'Ainda trabalhando na sua última imagem.';

  @override
  String get economyAiStyle => 'Estilo';

  @override
  String get economyAiStyleAbstract => 'Abstrato';

  @override
  String get economyAiStyleAnime => 'Anime';

  @override
  String get economyAiStyleCyberpunk => 'Cyberpunk';

  @override
  String get economyAiStyleMeshGradient => 'Gradiente de malha';

  @override
  String get economyAiStyleMinimal => 'Minimalista';

  @override
  String get economyAiStyleNature => 'Natureza';

  @override
  String economyAiStyleSemantics(String style) {
    return 'Estilo: $style';
  }

  @override
  String get economyAiStyleSheetTitle => 'Escolha um estilo';

  @override
  String get economyAiStyleSheetSubject => 'Cada prévia mostra a mesma cena: um farol em um penhasco ao entardecer.';

  @override
  String get economyAiStyleWatercolor => 'Aquarela';

  @override
  String get economyAiStyleSpace => 'Espaço';

  @override
  String get economyAiStyleSynthwave => 'Synthwave';

  @override
  String get economyAiStylePixelArt => 'Pixel art';

  @override
  String get economyAiStyleRender3d => 'Render 3D';

  @override
  String get economyAiStyleOilPainting => 'Pintura a óleo';

  @override
  String get economyAiStyleUkiyoE => 'Ukiyo-e';

  @override
  String get economyAiSubmissionUnconfirmed =>
      'O status do envio não foi confirmado. Verifique antes de tentar novamente.';

  @override
  String get economyAiSubmitDisabled => 'O envio de IA está desativado no momento.';

  @override
  String get economyAiSubmitFailed => 'Falha no envio. Tente novamente.';

  @override
  String get economyAiSubmitForReview => 'Enviar para revisão da comunidade';

  @override
  String get economyAiSubmitStatusUnconfirmed =>
      'O status do envio não foi confirmado. Verifique o status da revisão antes de tentar novamente.';

  @override
  String get economyAiSubmittedForReview => 'Enviado para revisão.';

  @override
  String get economyAiTryAgain => 'Tentar novamente';

  @override
  String get economyAiTryAnother => 'Tentar outro';

  @override
  String get economyAiTryAnotherVersion => 'Tentar outra versão';

  @override
  String get economyAiUnavailableBody => 'Desativamos por um curto período. Volte em breve.';

  @override
  String get economyAiUnavailableTitle => 'O papel de parede com IA está desativado por enquanto';

  @override
  String economyAiVariationTooLong(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Essa descrição é muito longa (máx. $maximumString caracteres).';
  }

  @override
  String get economyAiVariationUnavailable => 'Tentar outro não está disponível agora.';

  @override
  String get economyAiWallpaper => 'Papel de parede com IA';

  @override
  String get economyAiWatermarkNote => 'Imagens gratuitas têm a marca d\'água do Prism. O Pro a remove.';

  @override
  String get economyAllRankRewardsCollected => 'Todas as recompensas de nível coletadas';

  @override
  String get economyAllSpinsUsed => 'Todos os giros usados';

  @override
  String get economyBackTomorrow => 'Volte amanhã';

  @override
  String get economyBadge => 'Selo';

  @override
  String get economyBadgeAiArtist => 'Artista de IA';

  @override
  String get economyBadgeAiArtistDescription => 'Gere 10 papéis de parede com IA';

  @override
  String get economyBadgeArtCurator => 'Curador de Arte';

  @override
  String get economyBadgeArtCuratorDescription => 'Favorite 50 papéis de parede';

  @override
  String get economyBadgeCollector => 'Colecionador';

  @override
  String get economyBadgeCollectorDescription => 'Favorite 10 papéis de parede';

  @override
  String get economyBadgeCreator => 'Criador';

  @override
  String get economyBadgeCreatorDescription => 'Tenha um papel de parede aprovado';

  @override
  String get economyBadgeDescription => 'Um selo no Prism';

  @override
  String get economyBadgeEarned => 'Selo conquistado';

  @override
  String economyBadgeEarnedCount(int count, int total) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$countString de $totalString conquistados';
  }

  @override
  String economyBadgeName(String name) {
    return 'Selo $name';
  }

  @override
  String get economyBadgePrismVeteran => 'Veterano do Prism';

  @override
  String get economyBadgePrismVeteranDescription => 'Use o Prism por 30 dias e alcance uma sequência de 7 dias';

  @override
  String get economyBadgeProfileComplete => 'Perfil Completo';

  @override
  String get economyBadgeProfileCompleteDescription => 'Adicione uma foto, nome de usuário, bio e um link';

  @override
  String economyBadgeSemantics(String name, String status, String description) {
    return '$name, $status. $description';
  }

  @override
  String get economyBadgeSocialButterfly => 'Sociável';

  @override
  String get economyBadgeSocialButterflyDescription => 'Siga 10 criadores';

  @override
  String get economyBadgeStatusEarned => 'Conquistado';

  @override
  String get economyBadgeStatusLocked => 'Bloqueado';

  @override
  String get economyBadgeStreakMaster => 'Mestre da Sequência';

  @override
  String get economyBadgeStreakMasterDescription => 'Alcance uma sequência de 28 dias';

  @override
  String get economyBadgeWeekWarrior => 'Guerreiro da Semana';

  @override
  String get economyBadgeWeekWarriorDescription => 'Alcance uma sequência de 7 dias';

  @override
  String get economyBadges => 'Selos';

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

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString dias',
      one: '1 dia',
      zero: '$countString dias',
    );
    return 'Melhor: $_temp0';
  }

  @override
  String get economyBoost => 'Impulsionar';

  @override
  String economyBoostInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Coloque um dos seus papéis de parede aprovados no topo de Em alta. Um impulso custa $amountString moedas. Abra seu papel de parede e toque em Impulsionar.';
  }

  @override
  String get economyBuildStreakDaily => 'Abra o Prism todos os dias para criar uma sequência.';

  @override
  String get economyBuy => 'Comprar';

  @override
  String get economyBuyPremium => 'Comprar Premium';

  @override
  String get economyCancel => 'Cancelar';

  @override
  String get economyChestBonusDone => 'Missão bônus concluída: suas moedas foram dobradas.';

  @override
  String get economyChestBonusToDouble => 'Faça primeiro a missão bônus de hoje para dobrar suas moedas.';

  @override
  String economyChestBoosterSemantics(String title, String caption) {
    return '$title. $caption';
  }

  @override
  String economyChestCoinsPrize(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString moedas',
      one: '1 moeda',
      zero: '$coinsString moedas',
    );
    return '$_temp0';
  }

  @override
  String get economyChestDoFirst => 'Faça isto primeiro para dobrar seu baú';

  @override
  String get economyChestDoubled => 'Baú dobrado';

  @override
  String get economyChestDoubledByBonus => ' Dobrado pela sua missão bônus.';

  @override
  String get economyChestFreeToday => 'Grátis hoje';

  @override
  String economyChestNeedCoins(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'O baú custa $priceString moedas. Você tem $balanceString. Assista a um vídeo para ganhar mais.';
  }

  @override
  String economyChestNewCosmetic(String kind, String name) {
    return 'um novo $kind: $name';
  }

  @override
  String economyChestNewKind(String kind) {
    return 'Novo $kind';
  }

  @override
  String get economyChestOpenFailed => 'Não foi possível acessar o Prism. Tente novamente.';

  @override
  String economyChestOpenFor(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $countString missões',
      one: 'mais 1 missão',
      zero: 'mais $countString missões',
    );
    return 'Abra por $priceString moedas ou conclua $_temp0 para abrir de graça.';
  }

  @override
  String get economyChestOpened => 'Aberto';

  @override
  String get economyChestOpenedDoubledTomorrow => 'Aberto e dobrado. Um novo amanhã.';

  @override
  String economyChestOpenedReset(String time) {
    return 'Aberto. Um novo baú em $time.';
  }

  @override
  String get economyChestOpenedTomorrow => 'Aberto. Um novo amanhã.';

  @override
  String get economyChestOwnCosmeticCoins => 'Você tem todos os cosméticos, então ele paga em moedas';

  @override
  String get economyChestOwnEveryCosmetic => 'Você tem todos os cosméticos';

  @override
  String get economyChestPriceChanged => 'O preço mudou. Confira e abra novamente.';

  @override
  String economyChestPriceFreeAfter(int price, int count) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $countString missões',
      one: 'mais 1 missão',
      zero: 'mais $countString missões',
    );
    return '$priceString moedas, ou grátis após $_temp0';
  }

  @override
  String economyChestPrizeSemantics(String tier, String prize, String doubled, int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(doubled, {'true': ' Dobrado pela sua missão bônus.', 'other': ''});
    String _temp1 = intl.Intl.pluralLogic(
      xp,
      locale: localeName,
      other: ' Mais $xpString XP.',
      one: ' Mais 1 XP.',
      zero: '',
    );
    return '$tier. Você ganhou $prize.$_temp0$_temp1';
  }

  @override
  String get economyChestQuestsFree => 'Suas missões deixaram o baú grátis hoje.';

  @override
  String get economyChestReady => 'Pronto para abrir';

  @override
  String economyChestReadyPaid(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Pronto para abrir. $doneString de $totalString missões concluídas';
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

    return '${hoursString}h ${minutesString}min';
  }

  @override
  String economyChestResetMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return '${minutesString}min';
  }

  @override
  String get economyChestTierCommon => 'Comum';

  @override
  String get economyChestTierEpic => 'Épico';

  @override
  String get economyChestTierLegendary => 'Lendário';

  @override
  String get economyChestTierRare => 'Raro';

  @override
  String economyChestXpLine(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Abrir o baú dá $xpString XP.';
  }

  @override
  String get economyClaimedTodayDay7Chest =>
      'Sua recompensa de hoje já foi resgatada. Volte amanhã para receber seu baú do dia 7.';

  @override
  String economyClaimedTodayReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Sua recompensa de hoje já foi resgatada. Volte amanhã para ganhar +$coinsString moedas.';
  }

  @override
  String get economyClosePreview => 'Fechar prévia';

  @override
  String economyCoinActivitySemantics(String label, String date, String amount, int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'moedas', one: 'moeda', zero: 'moedas');
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
    return '$action. Não foi possível confirmar seu reembolso.';
  }

  @override
  String economyCoinGateRefunded(String action, int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString moedas reembolsadas.',
      one: '1 moeda reembolsada.',
      zero: '$coinsString moedas reembolsadas.',
    );
    return '$action. $_temp0';
  }

  @override
  String get economyCoinHistoryEarned => 'Ganhas';

  @override
  String get economyCoinHistoryEmpty => 'Nenhuma atividade de moedas ainda.';

  @override
  String get economyCoinHistoryLoadFailed => 'Não foi possível carregar seu histórico de moedas.';

  @override
  String get economyCoinHistoryNoLoadedRows => 'Nenhuma atividade nos registros carregados até agora.';

  @override
  String get economyCoinHistoryNothingHere => 'Nada aqui ainda.';

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
    String _temp1 = intl.Intl.pluralLogic(coins, locale: localeName, other: 'moedas', one: 'moeda', zero: 'moedas');
    return '$label$_temp0, $date, $amount $_temp1, $balance';
  }

  @override
  String get economyCoinHistorySpent => 'Gastas';

  @override
  String get economyCoinHistoryTitle => 'Histórico de moedas';

  @override
  String get economyCoinSpendFailed => 'Não foi possível processar as moedas agora.';

  @override
  String economyCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString moedas',
      one: '1 moeda',
      zero: '$countString moedas',
    );
    return '$_temp0';
  }

  @override
  String get economyCoinsAreYoursToSpend => 'As moedas são suas para gastar';

  @override
  String economyCoinsEarned(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString moedas',
      one: '1 moeda',
      zero: '$countString moedas',
    );
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
      'As moedas pagam papéis de parede, ferramentas e itens da Loja. XP é progresso, não um saldo que você gasta. Gastar moedas nunca diminui seu XP.';

  @override
  String get economyCoinsWhatYouCanDo => 'O que você pode fazer com elas';

  @override
  String get economyCoinsWord => 'moedas';

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
      'true': ', ou use $coinsString moedas para desbloqueá-lo agora',
      'other': '',
    });
    return 'Mantenha uma sequência de $daysString dias para desbloquear este papel de parede$_temp0.';
  }

  @override
  String get economyCollectionLoadFailed => 'Não foi possível carregar esta coleção';

  @override
  String economyCollectionNeedCoinsMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Você precisa de $coinsString moedas para desbloquear este papel de parede.';
  }

  @override
  String get economyCollectionRequirementsUnmet => 'Este papel de parede ainda não está disponível.';

  @override
  String get economyCollectionStillLocked => 'Ainda bloqueado';

  @override
  String economyCollectionUnlockedAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Desbloqueado com uma sequência de $daysString dias';
  }

  @override
  String get economyCollectionUnlockedWithCoins => 'Desbloqueado com moedas';

  @override
  String economyCollectionUnlocksAtCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Desbloqueia por $coinsString moedas';
  }

  @override
  String economyCollectionUnlocksAtDays(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Desbloqueia com uma sequência de $daysString dias';
  }

  @override
  String get economyCompleteProfile => 'Complete seu perfil';

  @override
  String get economyCosmetic => 'item visual';

  @override
  String get economyCosmeticAppIcon => 'ícone do app';

  @override
  String get economyCosmeticFrame => 'moldura';

  @override
  String get economyCosmeticNameGlow => 'brilho no nome';

  @override
  String get economyCosmeticTheme => 'tema';

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
  String get economyCreatorApprovedWalls => 'Papéis de parede aprovados';

  @override
  String get economyCreatorIntro =>
      'Ganhe XP quando seus papéis de parede forem aprovados e novos membros os favoritarem. O progresso aparece após sua primeira contribuição qualificada.';

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
    return 'Marco de $label';
  }

  @override
  String get economyCreatorMilestones => 'Marcos de criador';

  @override
  String economyCreatorMilestonesComplete(String label) {
    return 'Marcos de $label concluídos';
  }

  @override
  String economyCreatorNewMembersThisWeek(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString novos membros favoritaram seus papéis de parede esta semana';
  }

  @override
  String economyCreatorNextMilestone(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Próximo marco: +$xpString XP';
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
  String get economyCreatorQualifyingMembers => 'Membros qualificados';

  @override
  String get economyCreatorRefresh => 'Atualizar progresso';

  @override
  String get economyCreatorRefreshing => 'Atualizando o progresso do criador…';

  @override
  String get economyCreatorRules =>
      'Os papéis de parede aprovados devem ser envios seus e elegíveis. Envios mais antigos podem ser inelegíveis se o Prism não conseguir verificar o envio original. Cada outro membro conta uma vez em todo o seu trabalho elegível, no primeiro favorito qualificado. Ele precisa ter entrado na conta, ter um e-mail verificado e uma conta com pelo menos sete dias. Seus próprios favoritos não contam. As contagens são históricas, não o seu público atual. Remover favoritos não desfaz o XP. Os marcos de criador rendem XP extra. As semanas vão de segunda a domingo em UTC; atividades atrasadas podem aparecer em uma semana posterior.';

  @override
  String get economyCreatorSavedRefresh => 'Progresso salvo. Atualize para ver as mudanças.';

  @override
  String get economyCreatorSavedUnavailable => 'Progresso salvo. A atualização não está disponível.';

  @override
  String economyCreatorThisWeekSummary(int walls, int xp) {
    final intl.NumberFormat wallsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String wallsString = wallsNumberFormat.format(walls);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$wallsString papéis de parede elegíveis aprovados · $xpString XP de marcos';
  }

  @override
  String economyCreatorTrackingSince(String date) {
    return 'Acompanhando desde $date UTC';
  }

  @override
  String get economyCreatorUnavailable => 'O progresso do criador não está disponível.';

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

    return '$wallsString papéis de parede elegíveis aprovados · $membersString novos membros qualificados · $xpString XP de marcos';
  }

  @override
  String get economyCreatorWhatCounts => 'O que conta e histórico';

  @override
  String get economyDailyChest => 'Baú diário';

  @override
  String economyDailyChestSemantics(String state, String caption, String hasXp, String xpLine) {
    String _temp0 = intl.Intl.selectLogic(hasXp, {'true': '. $xpLine', 'other': ''});
    return 'Baú diário, $state. $caption$_temp0';
  }

  @override
  String get economyDailyChestTitle => 'Baú diário';

  @override
  String get economyDailyQuests => 'Missões diárias';

  @override
  String get economyDailyStreak => 'Sequência diária';

  @override
  String get economyDay7Chest => 'Baú do dia 7';

  @override
  String economyDayLabel(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Dia $dayString';
  }

  @override
  String economyDayStreakMilestone(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Sequência de $daysString dias!';
  }

  @override
  String economyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'dias', one: 'dia', zero: 'dias');
    return '$_temp0';
  }

  @override
  String economyDaysAgo(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $countString dias',
      one: 'há 1 dia',
      zero: 'há $countString dias',
    );
    return '$_temp0';
  }

  @override
  String get economyDownload => 'Baixar';

  @override
  String get economyDownloadAccountChanged => 'A conta mudou. Tente salvar novamente.';

  @override
  String get economyDownloadAgain => 'Baixar novamente';

  @override
  String economyDownloadAgainCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Baixar novamente (-$costString moedas)';
  }

  @override
  String get economyDownloadAlreadyInDownloads => 'Já está em Downloads';

  @override
  String economyDownloadCoinsNeeded(int missing, int reward, String watch, String adState) {
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(watch, {'true': ' Cada anúncio rende $rewardString.', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(adState, {
      'disabled': ' Os anúncios estão desativados. Mude isso em Configurações > Privacidade.',
      'limit': ' Limite diário atingido. Volte amanhã.',
      'other': '',
    });
    return 'Você precisa de mais $missingString moedas para salvar este papel de parede.$_temp0$_temp1';
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

    return '$label. Custa $costString moedas';
  }

  @override
  String get economyDownloadFailedLabel => 'Falha no download';

  @override
  String economyDownloadFreeDownloadsLeftSemantics(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString downloads grátis restantes',
      one: '1 download grátis restante',
      zero: '$countString downloads grátis restantes',
    );
    return '$label. Grátis, $_temp0';
  }

  @override
  String economyDownloadFreeFor(String label) {
    return '$label · Grátis';
  }

  @override
  String economyDownloadFreeLeftFor(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label · Grátis · $countString restantes';
  }

  @override
  String economyDownloadFreeOwnedSemantics(String label) {
    return '$label. Grátis, este papel de parede é seu';
  }

  @override
  String economyDownloadFreeWithPassSemantics(String label) {
    return '$label. Grátis com seu passe';
  }

  @override
  String get economyDownloadFreeWithPro => 'Grátis com o Pro';

  @override
  String economyDownloadFreeWithProSemantics(String label) {
    return '$label. Grátis com o Pro';
  }

  @override
  String get economyDownloadLinkUnavailable => 'Nenhum link de download disponível.';

  @override
  String get economyDownloadProGuestMessage =>
      'Entre para salvar este papel de parede com moedas ou assine o Prism Pro.';

  @override
  String get economyDownloadSaveLocalCopy => 'Salvar cópia local';

  @override
  String get economyDownloadSaved => 'Salvo';

  @override
  String get economyDownloadSavedBefore => 'Você já salvou este papel de parede antes.';

  @override
  String get economyDownloadSavedInDownloads => 'Salvo. Já está em Downloads';

  @override
  String get economyDownloadThisWallpaper => 'Baixar este papel de parede';

  @override
  String get economyDownloadWaitForCurrent => 'Aguarde o download terminar!';

  @override
  String get economyDownloadWatchAdMessage => 'Assista a um pequeno anúncio em vídeo para baixar este papel de parede.';

  @override
  String get economyDownloadWatchAdPrivacyMessage =>
      'Assista a um pequeno anúncio em vídeo para baixar este papel de parede. Os anúncios estão desativados. Mude isso em Configurações > Privacidade.';

  @override
  String get economyDownloads => 'Downloads';

  @override
  String economyDownloadsInfo(int amount, int freeCount, String hasFree) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat freeCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String freeCountString = freeCountNumberFormat.format(freeCount);

    String _temp0 = intl.Intl.selectLogic(hasFree, {'true': ' Os primeiros $freeCountString são grátis.', 'other': ''});
    return 'Cada download de papel de parede custa $amountString moedas.$_temp0 O Pro torna os downloads grátis.';
  }

  @override
  String economyDrawAllTicketsHeld(int maximum) {
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Você já tem todos os $maximumString bilhetes desta semana.';
  }

  @override
  String economyDrawBuyTicket(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Comprar um bilhete · $priceString';
  }

  @override
  String get economyDrawClosed => 'Este sorteio está encerrado. O próximo abre na segunda-feira.';

  @override
  String economyDrawClosesIn(String time) {
    return 'Encerra em $time';
  }

  @override
  String get economyDrawLastWinner => 'Último vencedor';

  @override
  String get economyDrawLoadFailed => 'Não foi possível carregar o Sorteio';

  @override
  String get economyDrawNotEnoughCoins => 'Moedas insuficientes para um bilhete.';

  @override
  String get economyDrawNotOpen => 'O Sorteio ainda não está aberto.';

  @override
  String get economyDrawOfficialRules => 'Regras oficiais';

  @override
  String economyDrawPrizeDescription(int months) {
    final intl.NumberFormat monthsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String monthsString = monthsNumberFormat.format(months);

    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$monthsString meses',
      one: '1 mês',
      zero: '$monthsString meses',
    );
    return '$_temp0 de Pro + a moldura Prism';
  }

  @override
  String get economyDrawProNotEligible => 'Membros Pro não são elegíveis.';

  @override
  String get economyDrawPurchaseFailed => 'Não foi possível comprar um bilhete. Tente novamente.';

  @override
  String get economyDrawThisWeeksPrize => 'PRÊMIO DESTA SEMANA';

  @override
  String economyDrawTicketBought(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Bilhete comprado. Você tem $ticketsString de $maximumString.';
  }

  @override
  String economyDrawTicketCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Os bilhetes custam $priceString moedas';
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
      other: '$ticketsString bilhetes',
      one: '1 bilhete',
      zero: '$ticketsString bilhetes',
    );
    String _temp1 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$peopleString pessoas',
      one: '1 pessoa',
      zero: '$peopleString pessoas',
    );
    return '$_temp0 de $_temp1';
  }

  @override
  String get economyDrawTitle => 'Sorteio Prism';

  @override
  String economyDrawYourChance(int mine, int pot) {
    final intl.NumberFormat mineNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String mineString = mineNumberFormat.format(mine);
    final intl.NumberFormat potNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String potString = potNumberFormat.format(pot);

    return 'Sua chance: $mineString/$potString';
  }

  @override
  String economyDrawYourTickets(int tickets, int maximum) {
    final intl.NumberFormat ticketsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ticketsString = ticketsNumberFormat.format(tickets);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Seus bilhetes: $ticketsString de $maximumString';
  }

  @override
  String get economyDropAlreadyUnlocked => 'Você já tem este.';

  @override
  String economyDropByCreator(String creator) {
    return 'por $creator';
  }

  @override
  String economyDropCardSemantics(String time, int unlocked, int total) {
    final intl.NumberFormat unlockedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String unlockedString = unlockedNumberFormat.format(unlocked);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Drop semanal, $time, $unlockedString de $totalString coletados';
  }

  @override
  String economyDropCarouselDetail(int count, String time) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede',
      one: '1 papel de parede',
      zero: '$countString papéis de parede',
    );
    return '$_temp0 · $time';
  }

  @override
  String economyDropCarouselSemantics(String title, String detail, String lastCall) {
    String _temp0 = intl.Intl.selectLogic(lastCall, {'true': ', última chamada', 'other': ''});
    return 'Drop semanal, $title, $detail$_temp0';
  }

  @override
  String economyDropCollected(int owned, int total) {
    final intl.NumberFormat ownedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String ownedString = ownedNumberFormat.format(owned);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$ownedString de $totalString coletados';
  }

  @override
  String economyDropDates(String start, String end) {
    return '$start a $end';
  }

  @override
  String get economyDropEnded => 'Encerrado';

  @override
  String get economyDropEndedHeadline => 'Este Drop terminou';

  @override
  String economyDropEndsInDaysHours(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '${daysString}d',
      one: '1d',
      zero: '${daysString}d',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '${hoursString}h',
      one: '1h',
      zero: '${hoursString}h',
    );
    return 'Termina em $_temp0 $_temp1';
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
      other: '${hoursString}h',
      one: '1h',
      zero: '${hoursString}h',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '${minutesString}m',
      one: '1m',
      zero: '${minutesString}m',
    );
    return 'Termina em $_temp0 $_temp1';
  }

  @override
  String economyDropEndsInMinutes(int minutes) {
    final intl.NumberFormat minutesNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minutesString = minutesNumberFormat.format(minutes);

    return 'Termina em ${minutesString}m';
  }

  @override
  String get economyDropGone => 'Este Drop acabou';

  @override
  String get economyDropLastCallLabel => 'Última chamada';

  @override
  String get economyDropLoadFailed => 'Não foi possível carregar o Drop';

  @override
  String get economyDropLocked => 'Bloqueado';

  @override
  String get economyDropMissed => 'Perdido';

  @override
  String get economyDropOver => 'Este Drop acabou.';

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
  String get economyDropPreviewTitle => 'Prévia do Drop';

  @override
  String get economyDropRename => 'Renomear Drop';

  @override
  String get economyDropRenameFailed => 'Não foi possível renomear o Drop. Tente novamente.';

  @override
  String get economyDropRenameHint => 'Nome do Drop';

  @override
  String get economyDropRenamed => 'Drop renomeado';

  @override
  String economyDropSave(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Economize $coinsString';
  }

  @override
  String economyDropStats(String walls, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString colecionadores',
      one: '1 colecionador',
      zero: '$countString colecionadores',
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

    return 'Desbloquear todos os $countString por $priceString';
  }

  @override
  String get economyDropUnlockFailed => 'Não foi possível desbloquear. Tente novamente.';

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

    return 'Desbloquear este papel de parede por $priceString';
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
      other: '$countString papéis de parede desbloqueados',
      one: 'Papel de parede desbloqueado',
      zero: '$countString papéis de parede desbloqueados',
    );
    return '$_temp0';
  }

  @override
  String get economyDropUnlockedWall => 'Papel de parede desbloqueado';

  @override
  String economyDropUnlockedWallBy(String creator) {
    return 'Papel de parede desbloqueado de $creator';
  }

  @override
  String economyDropWallBySemantics(String state, String serial, String creator) {
    return 'Papel de parede $serial de $creator, $state';
  }

  @override
  String economyDropWallCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede',
      one: '1 papel de parede',
      zero: '$countString papéis de parede',
    );
    return '$_temp0';
  }

  @override
  String economyDropWallSemantics(String state, String serial) {
    return 'Papel de parede $serial, $state';
  }

  @override
  String get economyDropWallpaperUnavailable => 'Este papel de parede não está disponível';

  @override
  String economyDropWeekOf(String date) {
    return 'Semana de $date';
  }

  @override
  String get economyDropYourVault => 'Seu cofre';

  @override
  String get economyDrops => 'Drops';

  @override
  String get economyEarnCoins => 'Ganhe moedas';

  @override
  String get economyEarnXpAsYouGo => 'Ganhe XP conforme você usa';

  @override
  String economyEarnedAtRank(String rank) {
    return 'Conquistado em $rank';
  }

  @override
  String get economyEquipped => 'Equipado';

  @override
  String get economyEveryChestPays => 'Todo baú dá alguma coisa.';

  @override
  String get economyEverySpinPays => 'Todo giro dá alguma coisa.';

  @override
  String economyFallbackCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Paga $countString moedas se você tiver todos';
  }

  @override
  String economyFinishDay7Chest(int minimum, int maximum) {
    final intl.NumberFormat minimumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String minimumString = minimumNumberFormat.format(minimum);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return 'Chegue ao dia 7 para um baú de +$minimumString a +$maximumString';
  }

  @override
  String get economyFinishStreakWeek => 'Complete uma semana de sequência.';

  @override
  String economyFirstDownloadsFree(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Primeiros $countString grátis';
  }

  @override
  String get economyFirstUpload => 'Primeiro envio';

  @override
  String get economyFreeDailySpin => 'Giro diário grátis';

  @override
  String economyFreeDownloadsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString grátis restantes';
  }

  @override
  String get economyFreeSpin => 'Giro grátis';

  @override
  String economyFreeSpinReady(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '. $countString giros pagos restantes hoje.',
      one: '. 1 giro pago restante hoje.',
      zero: '',
    );
    return 'Giro grátis pronto$_temp0';
  }

  @override
  String get economyFreezeAdded => 'Congelamento de sequência adicionado.';

  @override
  String economyFreezeAlreadyAtLimit(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString congelamentos',
      one: '1 congelamento',
      zero: '$countString congelamentos',
    );
    return 'Você já tem $_temp0.';
  }

  @override
  String economyFreezeBalanceAfter(int balance) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Saldo depois: $balanceString';
  }

  @override
  String economyFreezeBuyConfirm(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Comprar um congelamento de sequência por $costString moedas?';
  }

  @override
  String get economyFreezeBuyFailed => 'Não foi possível comprar um congelamento. Tente novamente.';

  @override
  String economyFreezeCount(int held, int total) {
    final intl.NumberFormat heldNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String heldString = heldNumberFormat.format(held);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$heldString de $totalString';
  }

  @override
  String get economyFreezeDescription => 'Salva sua sequência se você perder um dia. É aplicado automaticamente.';

  @override
  String get economyFreezeFull => 'Cheio';

  @override
  String economyFreezeGetOne(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Pegar um · $costString';
  }

  @override
  String get economyFreezeHeld => 'Congelamento guardado';

  @override
  String economyFreezeNeedCoins(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Você precisa de $costString moedas.';
  }

  @override
  String get economyFreezeSlotEmpty => 'Espaço de congelamento vazio';

  @override
  String get economyFreezeUnavailable =>
      'O congelamento de sequência não está disponível agora. Tente novamente mais tarde.';

  @override
  String get economyFreshLeaderboardDetails =>
      'O ranking usa o XP semanal, que reinicia toda segunda-feira às 00:00 UTC. Seu XP total, sua posição e os itens visuais conquistados permanecem.';

  @override
  String get economyFreshLeaderboardWeekly => 'Um ranking novo toda semana';

  @override
  String get economyGetCoins => 'Obter moedas';

  @override
  String economyGetCoinsChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Obter moedas. O baú custa $priceString moedas';
  }

  @override
  String economyGetCoinsForSpin(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Obter moedas. Um giro custa $priceString moedas';
  }

  @override
  String get economyGetFreezeNextTime => 'Pegue um congelamento para a próxima vez';

  @override
  String get economyGetPro => 'Assinar o Pro';

  @override
  String get economyGiftPass => 'Presentear um passe';

  @override
  String economyGiftPassInfo(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'Presenteie um amigo com 24 horas de conteúdo Pro por $amountString moedas. Abra o perfil dele e toque em Presentear passe de 24 h.';
  }

  @override
  String get economyGotIt => 'Entendi';

  @override
  String economyHighestRankReached(String rank) {
    return 'Maior nível alcançado: $rank';
  }

  @override
  String get economyHighestRankReachedShort => 'Maior nível alcançado';

  @override
  String get economyHomeScreen => 'Tela inicial';

  @override
  String get economyInviteFriend => 'Convidar um amigo';

  @override
  String get economyJackpotAddedToBalance => 'Prêmio máximo. Adicionado ao seu saldo';

  @override
  String get economyKeepStreakToday => 'Abra o Prism hoje para manter sua sequência.';

  @override
  String get economyLastWeek => 'Semana passada';

  @override
  String economyLeaderboardEntrySemantics(int position, String name, String isMe, int xp, String hasRank, String rank) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    String _temp0 = intl.Intl.selectLogic(isMe, {'true': ', você', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(hasRank, {'true': ', nível vitalício $rank', 'other': ''});
    return '$positionString, $name$_temp0, $xpString XP esta semana$_temp1';
  }

  @override
  String get economyLeaderboardFollowTip => 'Sua pontuação está incluída. Siga criadores para comparar o XP semanal.';

  @override
  String get economyLeaderboardFollowToSee => 'Siga criadores para vê-los aqui.';

  @override
  String get economyLeaderboardFollowing => 'Seguindo';

  @override
  String get economyLeaderboardFriendsCaption => 'Você e as pessoas que você segue · puxe para atualizar';

  @override
  String get economyLeaderboardFriendsDetails =>
      'Inclui sua pontuação e até as primeiras 90 contas que você segue. Contas excluídas ficam de fora; não há idade mínima de conta. As pontuações carregam quando você abre esta aba pela primeira vez. Puxe para atualizar. Sua pontuação reflete seu XP sincronizado mais recente.';

  @override
  String get economyLeaderboardGlobal => 'Global';

  @override
  String get economyLeaderboardGlobalCaption => 'Top 50 · atualizado a cada cerca de 3 horas';

  @override
  String get economyLeaderboardGlobalDetails =>
      'Mostra até 50 contas por XP semanal. As contas precisam ter pelo menos 7 dias; contas excluídas ficam de fora. O instantâneo é atualizado a cada cerca de 3 horas, então o XP novo pode demorar a aparecer. Puxar para atualizar carrega o instantâneo mais recente.';

  @override
  String get economyLeaderboardHowScoringWorks => 'Como funciona a pontuação do ranking';

  @override
  String get economyLeaderboardLoadFailed => 'Não foi possível carregar o ranking';

  @override
  String get economyLeaderboardNoRankings => 'Nenhuma classificação ainda';

  @override
  String get economyLeaderboardOffline => 'Se você estiver offline, podem ser exibidas pontuações salvas.';

  @override
  String get economyLeaderboardRankedByXp => 'Classificado pelo XP ganho nesta semana';

  @override
  String economyLeaderboardReset(int days, int hours) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '${daysString}d',
      one: '1d',
      zero: '${daysString}d',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '${hoursString}h',
      one: '1h',
      zero: '${hoursString}h',
    );
    return 'Reinicia segunda-feira às 00:00 UTC · $_temp0 $_temp1 restantes';
  }

  @override
  String get economyLeaderboardScoringIntro =>
      'As posições usam o XP ganho nesta semana. Os rótulos de nível, como Prata, usam o XP vitalício. O XP semanal é zerado na segunda-feira às 00:00 UTC; o XP vitalício e o nível permanecem.';

  @override
  String get economyLeaderboardTitle => 'Ranking';

  @override
  String get economyLifetimePermanentDetails =>
      'O XP vitalício define seu nível e nunca é zerado. Os itens de nível chegam automaticamente ao seu inventário, não custam moedas e ficam com você. Escolha quando equipá-los na Loja.';

  @override
  String get economyLifetimePermanentRewards => 'Progresso vitalício, recompensas permanentes';

  @override
  String economyLifetimeXp(String xp) {
    return '$xp XP vitalício';
  }

  @override
  String get economyLifetimeXpNeverResets => 'O XP vitalício nunca é zerado.';

  @override
  String get economyLoadingVideo => 'Carregando um vídeo';

  @override
  String get economyLockScreen => 'Tela de bloqueio';

  @override
  String get economyMystery => 'Mistério';

  @override
  String get economyMysteryCosmetic => 'Item cosmético misterioso';

  @override
  String get economyNewBadge => 'Novo selo';

  @override
  String economyNewCosmetic(String kind, String name) {
    return 'Novo $kind: $name';
  }

  @override
  String get economyNewUnknownCosmetic => 'Novo item cosmético';

  @override
  String get economyNextDropMonday => 'O próximo Drop chega na segunda-feira.';

  @override
  String economyNextReward(String reward) {
    return 'Próxima recompensa: $reward';
  }

  @override
  String get economyNice => 'Legal';

  @override
  String get economyNoDropNow => 'Nenhum Drop agora';

  @override
  String get economyNoSpinsLeft => 'Nenhum giro restante hoje.';

  @override
  String get economyNotEnoughCoins => 'Moedas insuficientes';

  @override
  String get economyNotNow => 'Agora não';

  @override
  String economyOddsTierSemantics(String tier, String odds) {
    return '$tier, $odds';
  }

  @override
  String get economyOddsTitle => 'As chances';

  @override
  String get economyOnceADay => 'Uma vez por dia';

  @override
  String get economyOpen => 'Abrir';

  @override
  String economyOpenChestCost(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Abrir o baú, $priceString moedas';
  }

  @override
  String get economyOpenChestFree => 'Abrir o baú, grátis';

  @override
  String get economyOpenChestLoading => 'Abrir o baú. Carregando';

  @override
  String get economyOpenDaily => 'Abra o Prism todos os dias.';

  @override
  String economyOpenDailyPro(String multiplier) {
    return 'Abra o Prism todos os dias. O Pro ganha x$multiplier.';
  }

  @override
  String get economyOpenFree => 'Abrir grátis';

  @override
  String get economyOpenShop => 'Abrir a Loja';

  @override
  String get economyOpening => 'Abrindo';

  @override
  String get economyOwned => 'Adquirido';

  @override
  String get economyPremiumCollection => 'Coleção premium';

  @override
  String economyPriceCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString moedas';
  }

  @override
  String economyPriceCoinsForHours(int amount, int hours) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    return '$amountString moedas por $hoursString horas';
  }

  @override
  String economyPriceCoinsPerWall(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString por papel de parede';
  }

  @override
  String economyPriceCoinsPerWallSemantics(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return '$amountString moedas por papel de parede';
  }

  @override
  String economyPriceCoinsWithNote(int amount, String note, String hasNote) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    String _temp0 = intl.Intl.selectLogic(hasNote, {'true': ', $note', 'other': ''});
    return '$amountString moedas$_temp0';
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

    return 'a partir de $amountString';
  }

  @override
  String economyPriceFromCoins(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'a partir de $amountString moedas';
  }

  @override
  String get economyPrizeWheel => 'Roleta de prêmios';

  @override
  String get economyPro => 'Pro';

  @override
  String get economyProDailyFreeSpin => 'Membros Pro ganham um giro grátis todo dia';

  @override
  String get economyProDownloadsFilters => 'Com o Pro, baixar e usar filtros é grátis.';

  @override
  String get economyProPrice => 'Preço do Pro';

  @override
  String get economyProWallpaper => 'Papel de parede Pro';

  @override
  String get economyQuestBrowse10 => 'Veja 10 papéis de parede';

  @override
  String get economyQuestColourSearch => 'Pesquise por cor';

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
      other: 'Missão cumprida: +$xpString XP',
      zero: 'Missão cumprida',
    );
    String _temp3 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: 'Missão cumprida: +$coinsString moedas$_temp0',
      one: 'Missão cumprida: +1 moeda$_temp1',
      zero: '$_temp2',
    );
    return '$_temp3';
  }

  @override
  String get economyQuestDownload2 => 'Baixe 2 papéis de parede';

  @override
  String get economyQuestFav3 => 'Favorite 3 papéis de parede';

  @override
  String economyQuestNewIn(String time) {
    return 'Novo em $time';
  }

  @override
  String get economyQuestProSpin => 'Use seu giro grátis';

  @override
  String get economyQuestSetWall => 'Defina ou salve um papel de parede';

  @override
  String get economyQuestShareWall => 'Compartilhe um papel de parede';

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

    String _temp0 = intl.Intl.selectLogic(isDone, {'true': 'concluída', 'other': '$progressString de $targetString'});
    String _temp1 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString moedas',
      one: '1 moeda',
      zero: '$coinsString moedas',
    );
    String _temp2 = intl.Intl.selectLogic(hasCoins, {'true': '. Rende $_temp1', 'other': ''});
    String _temp3 = intl.Intl.selectLogic(hasXp, {'true': '. Rende $xpString XP', 'other': ''});
    String _temp4 = intl.Intl.selectLogic(hasEnds, {'true': ', termina em $endsIn', 'other': ''});
    String _temp5 = intl.Intl.selectLogic(isWeekly, {'true': '. Missão semanal$_temp4', 'other': ''});
    return '$title, $_temp0$_temp2$_temp3$_temp5';
  }

  @override
  String get economyQuestTrending => 'Veja o que está em alta';

  @override
  String get economyQuestUnknown => 'Conclua uma missão';

  @override
  String get economyQuestWatchAd => 'Assista a um vídeo';

  @override
  String get economyQuestWeeklySet5 => 'Salve ou defina 5 papéis de parede';

  @override
  String get economyQuestWotd => 'Abra o Papel de Parede do Dia de hoje';

  @override
  String get economyRankBronze => 'Bronze';

  @override
  String get economyRankGold => 'Ouro';

  @override
  String get economyRankGrowsWithXp => 'Seu nível cresce com o XP vitalício.';

  @override
  String economyRankInfoSemantics(String rank) {
    return 'Nível $rank. Como funcionam o XP e as recompensas de nível';
  }

  @override
  String get economyRankPrism => 'Prism';

  @override
  String economyRankProgressSemantics(String rank) {
    return 'Progresso do nível $rank';
  }

  @override
  String economyRankRewardAtRank(String rank, String xp) {
    return 'Seu automaticamente no nível $rank · $xp XP';
  }

  @override
  String economyRankRewardMilestone(String rank, String xp, String reward) {
    return '$rank · $xp XP\n$reward';
  }

  @override
  String get economyRankRewardSyncing => 'Sincronizando com seu inventário. É seu para sempre.';

  @override
  String get economyRankRewardsHelp => 'Como funcionam o XP e as recompensas de nível';

  @override
  String get economyRankSilver => 'Prata';

  @override
  String economyRankTag(String rank) {
    return 'Nível $rank';
  }

  @override
  String get economyRankUnknown => 'Nível';

  @override
  String economyReferralBothGet(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString moedas',
      one: '1 moeda',
      zero: '$coinsString moedas',
    );
    return 'Vocês dois ganham $_temp0';
  }

  @override
  String get economyRestore => 'Restaurar';

  @override
  String economyRestoreStreak(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Restaurar sua sequência de $daysString dias · $coinsString moedas';
  }

  @override
  String economyRewardEarned(String reward) {
    return '$reward conquistado';
  }

  @override
  String get economyRewardsTitle => 'Recompensas';

  @override
  String get economySameActivitySameXp => 'A mesma atividade rende o mesmo XP';

  @override
  String get economySameActivityXpDetails =>
      'Anúncios, giros Pro, bônus diários Pro, indicações e reembolsos não rendem XP. Os multiplicadores Pro e de moedas não aumentam o XP. As recompensas em moedas são separadas.';

  @override
  String get economySeeAll => 'Ver tudo';

  @override
  String get economySeeBadges => 'Ver selos';

  @override
  String get economySeeItInShop => 'Ver na Loja';

  @override
  String get economySeeOdds => 'Ver as chances';

  @override
  String get economySeePro => 'Ver o Pro';

  @override
  String get economySeeRewards => 'Ver recompensas';

  @override
  String get economyShareWallpaper => 'Compartilhar um papel de parede';

  @override
  String get economyShopAlreadyOwned => 'Você já tem este item';

  @override
  String get economyShopAurora => 'Aurora';

  @override
  String economyShopBuyFor(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Comprar por $priceString';
  }

  @override
  String get economyShopChangeIconFailed => 'Não foi possível trocar o ícone';

  @override
  String economyShopCoinsShort(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Você precisa de mais $countString moedas.';
  }

  @override
  String get economyShopCottonBlue => 'Azul algodão';

  @override
  String get economyShopDeepOcean => 'Oceano profundo';

  @override
  String get economyShopDefaultIcon => 'Padrão';

  @override
  String get economyShopEarnXp => 'Ganhar XP';

  @override
  String economyShopEarnedAtLifetimeXp(String rank) {
    return 'Conquistado no nível $rank com XP vitalício.';
  }

  @override
  String get economyShopEmber => 'Brasa';

  @override
  String get economyShopEquip => 'Equipar';

  @override
  String get economyShopEquipFailed => 'Não foi possível alterar. Tente novamente.';

  @override
  String economyShopEquipped(String name) {
    return '$name equipado';
  }

  @override
  String get economyShopFounders => 'Fundadores';

  @override
  String get economyShopFrames => 'Molduras';

  @override
  String get economyShopGlass => 'Vidro';

  @override
  String get economyShopGlowPreviewName => 'Glint';

  @override
  String get economyShopGlows => 'Brilhos';

  @override
  String get economyShopGold => 'Ouro';

  @override
  String economyShopIconEnabled(String name) {
    return 'Ícone $name ativado';
  }

  @override
  String get economyShopIcons => 'Ícones';

  @override
  String economyShopItemSemantics(String name, String status) {
    return '$name, $status';
  }

  @override
  String get economyShopJungle => 'Selva';

  @override
  String get economyShopMono => 'Mono';

  @override
  String get economyShopNeedMoreCoins => 'Você precisa de mais moedas para isso';

  @override
  String get economyShopNoir => 'Noir';

  @override
  String get economyShopOcean => 'Oceano';

  @override
  String get economyShopOlive => 'Oliva';

  @override
  String get economyShopPepper => 'Pimenta';

  @override
  String get economyShopPrism => 'Prism';

  @override
  String get economyShopProOnly => 'Este item é para membros Pro';

  @override
  String get economyShopPurchaseFailed => 'Não foi possível comprar. Tente novamente.';

  @override
  String economyShopPurchased(String name) {
    return '$name é seu';
  }

  @override
  String economyShopRankLocked(String rank) {
    return 'Alcance o nível $rank para desbloquear';
  }

  @override
  String get economyShopRankReachedSyncing => 'Nível alcançado. Sua recompensa está sincronizando.';

  @override
  String economyShopRankRewardSynced(String name) {
    return 'Recompensa do nível $name sincronizada';
  }

  @override
  String economyShopReachRankToBuy(String rank) {
    return 'Alcance o nível $rank para comprar.';
  }

  @override
  String get economyShopRing => 'Anel';

  @override
  String get economyShopRose => 'Rosa';

  @override
  String economyShopSaleUntil(String date) {
    return 'Edição limitada. Em promoção até $date.';
  }

  @override
  String get economyShopSky => 'Céu';

  @override
  String get economyShopSoldOut => 'Este item limitado esgotou';

  @override
  String get economyShopSteel => 'Aço';

  @override
  String get economyShopSunset => 'Pôr do sol';

  @override
  String get economyShopSyncReward => 'Sincronizar recompensa';

  @override
  String get economyShopThemes => 'Temas';

  @override
  String get economyShopTitle => 'Loja';

  @override
  String get economyShopUnequip => 'Desequipar';

  @override
  String economyShopUnequipped(String name) {
    return '$name removido';
  }

  @override
  String get economyShopUseIcon => 'Usar ícone';

  @override
  String get economyShopUseTheme => 'Usar tema';

  @override
  String get economyShopWearingNeedsPro => 'Usar isto exige o Pro.';

  @override
  String get economyShowMore => 'Mostrar mais';

  @override
  String get economySignIn => 'Entrar';

  @override
  String get economySoldOut => 'Esgotado';

  @override
  String get economySoon => 'em breve';

  @override
  String economySpendItemSemantics(String label, String price) {
    return '$label, $price';
  }

  @override
  String get economySpin => 'GIRAR';

  @override
  String get economySpinAgain => 'Girar de novo';

  @override
  String get economySpinAgainFree => 'Girar de novo, giro grátis';

  @override
  String economySpinAgainPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Girar de novo, $priceString moedas';
  }

  @override
  String economySpinCardCaption(int price, int maximum) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat maximumNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String maximumString = maximumNumberFormat.format(maximum);

    return '$priceString moedas por giro. Ganhe até $maximumString moedas ou um item cosmético';
  }

  @override
  String economySpinCosts(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Um giro custa $priceString moedas';
  }

  @override
  String get economySpinFree => 'Girar, giro grátis';

  @override
  String economySpinPrice(int price) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);

    return 'Girar, $priceString moedas';
  }

  @override
  String get economySpinPriceChanged => 'O preço mudou. Confira e gire de novo.';

  @override
  String economySpinShortBalanceMessage(int price, int balance) {
    final intl.NumberFormat priceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String priceString = priceNumberFormat.format(price);
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);

    return 'Um giro custa $priceString moedas. Você tem $balanceString. Assista a um vídeo para ganhar mais.';
  }

  @override
  String get economySpinTheWheel => 'Girar a roleta';

  @override
  String economySpinWheelCardSemantics(String caption) {
    return 'Girar a roleta. $caption';
  }

  @override
  String get economySpinning => 'Girando';

  @override
  String economySpinsLeftToday(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString giros restantes',
      one: '1 giro restante',
      zero: '$countString giros restantes',
    );
    return '$_temp0 hoje.';
  }

  @override
  String get economyStreak => 'SEQUÊNCIA';

  @override
  String economyStreakChestReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString baú do dia 7';
  }

  @override
  String get economyStreakCollection => 'Coleção da sequência';

  @override
  String get economyStreakCollectionDescription =>
      'Desbloqueie papéis de parede mantendo sua sequência ou usando moedas.';

  @override
  String economyStreakCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sequência de $countString dias',
      one: 'Sequência de 1 dia',
      zero: 'Sequência de $countString dias',
    );
    return '$_temp0';
  }

  @override
  String economyStreakCycleSemantics(int day, String showReward, int reward, String state) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);
    final intl.NumberFormat rewardNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String rewardString = rewardNumberFormat.format(reward);

    String _temp0 = intl.Intl.selectLogic(showReward, {'true': ', mais $rewardString moedas', 'other': ''});
    String _temp1 = intl.Intl.selectLogic(state, {'done': ', concluído', 'today': ', hoje', 'other': ''});
    return 'Dia $dayString$_temp0$_temp1';
  }

  @override
  String economyStreakDailyReward(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '+$coinsString hoje';
  }

  @override
  String economyStreakDayNumber(int day) {
    final intl.NumberFormat dayNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String dayString = dayNumberFormat.format(day);

    return 'Dia $dayString da sua sequência';
  }

  @override
  String get economyStreakFreeze => 'Congelamento de sequência';

  @override
  String economyStreakFreezeSaved(int days) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);

    return 'Um congelamento salvou sua sequência de $daysString dias';
  }

  @override
  String economyStreakFreezesLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString congelamentos restantes',
      one: '1 congelamento restante',
      zero: '$countString congelamentos restantes',
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
  String get economyStreakRescueCooldown => 'Você pode restaurar uma sequência a cada 30 dias.';

  @override
  String get economyStreakRescueExpired => 'As 48 horas para restaurar esta sequência acabaram.';

  @override
  String get economyStreakRescueFailed => 'Não foi possível restaurar sua sequência. Tente novamente.';

  @override
  String get economyStreakRescueUnavailable => 'Esta sequência não pode ser restaurada agora.';

  @override
  String get economyStreakReset => 'Sua sequência foi reiniciada';

  @override
  String economyStreakResetMessage(int days, int coins) {
    final intl.NumberFormat daysNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String daysString = daysNumberFormat.format(days);
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Sua sequência era de $daysString dias. Recomece hoje e ganhe +$coinsString moedas.';
  }

  @override
  String economyStreakRestoreShort(int balance, int cost) {
    final intl.NumberFormat balanceNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String balanceString = balanceNumberFormat.format(balance);
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Seu saldo é $balanceString. Você precisa de $costString.';
  }

  @override
  String get economyStreakRestored => 'Sua sequência está de volta';

  @override
  String economyStreakRestoredCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Sua sequência voltou para $countString dias.';
  }

  @override
  String get economyToday => 'Hoje';

  @override
  String get economyUnknownCosmetic => 'Cosmético';

  @override
  String economyUntil(String date) {
    return 'Até $date';
  }

  @override
  String economyUpToCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Até +$countString';
  }

  @override
  String get economyUpgradeToPro => 'Assinar Pro';

  @override
  String economyUseReward(String reward) {
    return 'Usar $reward';
  }

  @override
  String get economyUseYourCoins => 'Use suas moedas';

  @override
  String get economyWatchAd => 'Assistir ao anúncio';

  @override
  String get economyWatchVideo => 'Assista a um vídeo';

  @override
  String economyWatchVideoRewardAdsLeft(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString anúncios',
      one: '1 anúncio',
      zero: '$countString anúncios',
    );
    return 'Assista a um vídeo · restam $_temp0 hoje';
  }

  @override
  String economyWatchVideoRewardCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Assista a um vídeo (+$coinsString)';
  }

  @override
  String get economyWeekComplete => 'Semana completa!';

  @override
  String get economyWeekly => 'SEMANAL';

  @override
  String get economyWeeklyDraw => 'Sorteio semanal';

  @override
  String get economyWeeklyDrop => 'Drop semanal';

  @override
  String economyWeeklyEndsIn(String time) {
    return 'SEMANAL · $time';
  }

  @override
  String get economyWeeklyXpFriendsEveryone => 'XP semanal, amigos e todos';

  @override
  String economyWonCoins(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coinsString moedas',
      one: '1 moeda',
      zero: '$coinsString moedas',
    );
    return 'Você ganhou $_temp0';
  }

  @override
  String economyWonCosmetic(String kind, String name) {
    return 'Você ganhou um novo $kind: $name';
  }

  @override
  String get economyWonUnknownCosmetic => 'Você ganhou um cosmético';

  @override
  String economyWonXp(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Você ganhou $xpString XP';
  }

  @override
  String economyXp(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '${countString}XP';
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

    return 'As sequências diárias rendem $dailyStreakString XP, além de $streakWeekString XP por completar um ciclo de sete dias. Baús de missões rendem $questChestString XP. Seu primeiro envio válido rende $uploadString XP; completar o perfil rende $profileString XP. Cada missão diária concede $dailyQuestString XP; a missão semanal concede $weeklyQuestString XP. Alguns selos e marcos de criador também rendem XP.';
  }

  @override
  String economyXpAwarded(int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '+${xpString}XP';
  }

  @override
  String get economyXpRanksRewards => 'XP, classificações e recompensas';

  @override
  String economyXpToRank(String xp, String rank) {
    return '$xp XP para $rank';
  }

  @override
  String get economyXpUnit => 'XP';

  @override
  String get economyYesterday => 'Ontem';

  @override
  String economyYouHaveCoins(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Você tem $countString moedas';
  }

  @override
  String get economyYourXp => 'SEU XP';

  @override
  String get errorGeneric => 'Algo deu errado. Por favor, tente novamente.';

  @override
  String get errorNetwork => 'Verifique sua conexão e tente novamente.';

  @override
  String get navigationBackOnline => 'De volta on-line';

  @override
  String get navigationNoInternetConnection => 'Sem conexão com a internet';

  @override
  String get navigationScrollToTop => 'Role para cima';

  @override
  String get notifActivateToCollapse => 'Ative para recolher.';

  @override
  String get notifActivateToExpand => 'Ative para expandir.';

  @override
  String get notifChannelDownloads => 'Downloads';

  @override
  String get notifChannelDownloadsDescription =>
      'Receba notificações sobre o andamento do download de papéis de parede.';

  @override
  String get notifChannelDraw => 'Sorteio do Prism';

  @override
  String get notifChannelDrawDescription => 'Sorteios, resultados e prêmios.';

  @override
  String get notifChannelDrops => 'Drops semanais';

  @override
  String get notifChannelDropsDescription => 'Quando um novo Drop estiver ativo e antes de terminar.';

  @override
  String get notifChannelFollowers => 'Seguidores';

  @override
  String get notifChannelFollowersDescription => 'Receba notificações quando ganhar novos seguidores.';

  @override
  String get notifChannelGifts => 'Presentes';

  @override
  String get notifChannelGiftsDescription => 'Um amigo lhe enviou um passe Pro.';

  @override
  String get notifChannelGroup => 'Notificações';

  @override
  String get notifChannelGroupDescription => 'Todas as notificações do Prism';

  @override
  String get notifChannelModeration => 'Moderação';

  @override
  String get notifChannelModerationDescription => 'Denúncias e solicitações de revisão para administradores do Prism.';

  @override
  String get notifChannelPosts => 'Postagens';

  @override
  String get notifChannelPostsDescription => 'Receba notificações de postagens de artistas que você segue.';

  @override
  String get notifChannelRecommendations => 'Recomendações';

  @override
  String get notifChannelRecommendationsDescription => 'Receba notificações de recomendações do Prism.';

  @override
  String get notifChannelStreaks => 'Lembretes de sequência';

  @override
  String get notifChannelStreaksDescription => 'Lembrete às 20h para manter sua sequência de acessos ativa.';

  @override
  String get notifChannelWotd => 'Papel de parede do dia';

  @override
  String get notifChannelWotdDescription => 'Notificação diária de papel de parede em destaque às 9h.';

  @override
  String get notifClearDeviceMessage => 'Isso os remove deste dispositivo.';

  @override
  String get notifClearInbox => 'Limpar caixa de entrada';

  @override
  String get notifClearInboxAction => 'Limpar caixa de entrada';

  @override
  String notifClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Limpar $countString notificações?';
  }

  @override
  String get notifClearOneTitle => 'Limpar esta notificação?';

  @override
  String get notifCollapsed => 'Recolhido';

  @override
  String notifDownloadedTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede baixados.',
      one: '1 papel de parede baixado.',
      zero: '$countString papéis de parede baixados.',
    );
    return '$_temp0';
  }

  @override
  String get notifDownloadingWallpaper => 'Baixando papel de parede';

  @override
  String get notifEmptyBody => 'Novos seguidores, aprovações e o papel de parede do dia aparecem aqui.';

  @override
  String get notifEmptyTitle => 'Sem notificações';

  @override
  String get notifExpanded => 'Expandido';

  @override
  String get notifGenericTitle => 'Notificação';

  @override
  String notifGroupAndMore(String message, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString itens.',
      one: '1 item.',
      zero: '$otherCountString itens.',
    );
    return '$message e mais $_temp0';
  }

  @override
  String notifGroupApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'aprovações',
      one: 'aprovação',
      zero: 'aprovações',
    );
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
      other: '$otherCountString criadores.',
      one: '1 criador.',
      zero: '$otherCountString criadores.',
    );
    return 'De $name e mais $_temp0';
  }

  @override
  String notifGroupDailyPicks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'escolhas do dia',
      one: 'escolha do dia',
      zero: 'escolhas do dia',
    );
    return '$_temp0';
  }

  @override
  String get notifGroupDayRows => 'Cada linha corresponde a um dia; os horários aparecem à direita.';

  @override
  String notifGroupFollowerSummary(String name, int otherCount) {
    final intl.NumberFormat otherCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String otherCountString = otherCountNumberFormat.format(otherCount);

    String _temp0 = intl.Intl.pluralLogic(
      otherCount,
      locale: localeName,
      other: '$otherCountString pessoas começaram',
      one: 'uma pessoa começou',
      zero: '$otherCountString pessoas começaram',
    );
    return '$name e mais $_temp0 a seguir você.';
  }

  @override
  String notifGroupFollowers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'novos seguidores',
      one: 'novo seguidor',
      zero: 'novos seguidores',
    );
    return '$_temp0';
  }

  @override
  String get notifGroupHide => 'Esconder';

  @override
  String notifGroupNotifications(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'notificações',
      one: 'notificação',
      zero: 'notificações',
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
      other: '$countString notificações removidas',
      one: '1 notificação removida',
      zero: '$countString notificações removidas',
    );
    return '$_temp0';
  }

  @override
  String notifGroupSameMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'A mesma mensagem foi enviada $countString vezes. Compare as datas e os horários para saber quando.';
  }

  @override
  String notifGroupSemantics(String title, String summary, String expandedState, String unreadStatus, String action) {
    return '$title. $summary. $expandedState. $unreadStatus $action';
  }

  @override
  String get notifGroupSeveralCreators => 'Vários criadores. Expanda para ver cada papel de parede.';

  @override
  String get notifGroupShowAll => 'Mostrar tudo';

  @override
  String notifGroupSummaryCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString notificações neste grupo.',
      one: '1 notificação neste grupo.',
      zero: '$countString notificações neste grupo.',
    );
    return '$_temp0';
  }

  @override
  String notifGroupWallLive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'papéis de parede publicados',
      one: 'papel de parede publicado',
      zero: 'papéis de parede publicados',
    );
    return '$_temp0';
  }

  @override
  String get notifHasUnread => 'Há notificações não lidas.';

  @override
  String get notifInboxCleared => 'Caixa de entrada limpa';

  @override
  String get notifLoadErrorTitle => 'Não foi possível carregar suas notificações';

  @override
  String get notifMarkAllRead => 'Marcar tudo como lido';

  @override
  String get notifOfflineSaved =>
      'Não foi possível carregar novas notificações. O que você vê abaixo está salvo neste dispositivo.';

  @override
  String get notifOpenSettings => 'Abrir configurações';

  @override
  String get notifPermissionOff => 'As notificações estão desativadas. Ative-as primeiro nas configurações do sistema.';

  @override
  String get notifPermissionOffForApp => 'As notificações estão desativadas para o Prism.';

  @override
  String get notifPreferences => 'Preferências de notificação';

  @override
  String get notifPushDrawWinnerBody => 'Um mês de Pro e a moldura Prism são seus.';

  @override
  String get notifPushDrawWinnerTitle => 'Você ganhou o sorteio do Prism';

  @override
  String notifPushDropLastCallBody(String dropTitle, int hours) {
    final intl.NumberFormat hoursNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String hoursString = hoursNumberFormat.format(hours);

    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursString horas',
      one: '1 hora',
      zero: '$hoursString horas',
    );
    return '$dropTitle termina em $_temp0. Depois, estes papéis de parede ficarão indisponíveis por um mês.';
  }

  @override
  String get notifPushDropLastCallTitle => 'Última chamada no Drop desta semana';

  @override
  String notifPushDropLiveBody(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede, só esta semana. Confira antes que saiam do ar.',
      one: '1 papel de parede, só esta semana. Confira antes que saia do ar.',
      zero: '$countString papéis de parede, só esta semana. Confira antes que saiam do ar.',
    );
    return '$_temp0';
  }

  @override
  String get notifPushDropLiveTitle => 'Um novo Drop está disponível';

  @override
  String notifPushFollowDigestTitleOne(String artistName) {
    return '$artistName publicou um novo papel de parede';
  }

  @override
  String notifPushFollowDigestTitleSolo(String artistName, int wallCount) {
    return '$artistName publicou $wallCount papéis de parede novos';
  }

  @override
  String notifPushFollowDigestTitlePair(String artistName, String secondArtistName, int wallCount) {
    return '$artistName e $secondArtistName publicaram $wallCount papéis de parede novos';
  }

  @override
  String notifPushFollowDigestTitleGroup(String artistName, int otherCount, int wallCount) {
    return '$artistName e mais $otherCount publicaram $wallCount papéis de parede novos';
  }

  @override
  String get notifPushFollowDigestBodyUntitled => 'Toque para ver todos.';

  @override
  String get notifPushGiftReceivedBody => 'As coleções e os papéis de parede premium ficarão disponíveis por 24 horas.';

  @override
  String notifPushGiftReceivedTitle(String senderName) {
    return '$senderName enviou a você um passe Pro de 24 horas';
  }

  @override
  String notifPushNewContentReportBody(String contentType, String reason, String targetId) {
    return '$contentType · $reason · doc. $targetId';
  }

  @override
  String get notifPushNewContentReportTitle => 'Nova denúncia de conteúdo';

  @override
  String notifPushNewFollowerBody(String followerName) {
    return '$followerName agora está seguindo você.';
  }

  @override
  String get notifPushNewFollowerTitle => 'Você tem um novo seguidor! 🎉';

  @override
  String notifPushReportReviewBody(String contentType, String reason) {
    return '$contentType · $reason · aberto por mais de 12 horas';
  }

  @override
  String get notifPushReportReviewTitle => 'Denúncia aguardando análise';

  @override
  String get notifPushStreakReminderBody => 'Abra o Prism agora para manter sua sequência de acessos ativa 🔥';

  @override
  String get notifPushStreakReminderTitle => 'Sua sequência está prestes a acabar!';

  @override
  String notifPushWallApprovedAdminBody(String wallTitle, String artistName) {
    return '\"$wallTitle\" de $artistName já está no ar.';
  }

  @override
  String get notifPushWallApprovedAdminTitle => 'Papel de parede aprovado ✅';

  @override
  String notifPushWallApprovedArtistBody(String wallTitle) {
    return '\"$wallTitle\" foi aprovado e agora está visível para todos.';
  }

  @override
  String get notifPushWallApprovedArtistBodyUntitled =>
      'Seu papel de parede foi aprovado e agora está visível para todos.';

  @override
  String get notifPushWallApprovedArtistTitle => 'Seu papel de parede está ativo! 🎉';

  @override
  String notifPushWallLiveFollowersBody(String wallTitle) {
    return '\"$wallTitle\" foi publicado no Prism.';
  }

  @override
  String notifPushWallLiveFollowersTitle(String artistName) {
    return 'Novo papel de parede de $artistName';
  }

  @override
  String notifPushWallSubmittedBody(String artistName, String artistEmail) {
    return 'Nova postagem de $artistName ($artistEmail) está em análise.';
  }

  @override
  String get notifPushWallSubmittedTitle => 'Novo papel de parede premium para revisão! 🎉';

  @override
  String get notifPushWinBack14Body => 'Venha ver o que os criadores adicionaram nesta quinzena.';

  @override
  String get notifPushWinBack14Title => 'Novos papéis de parede estão esperando';

  @override
  String get notifPushWinBack30Body => 'Faça um papel de parede que se pareça com você.';

  @override
  String get notifPushWinBack30Title => 'Novos estilos de IA para experimentar';

  @override
  String get notifPushWinBack60Body => 'Seu próximo papel de parede favorito está a um toque de distância.';

  @override
  String get notifPushWinBack60Title => 'O Prism sente sua falta';

  @override
  String get notifPushWinBack7Body => 'Novos papéis de parede chegaram enquanto você estava fora.';

  @override
  String get notifPushWinBack7Title => 'Seu feed tem novos papéis de parede';

  @override
  String notifPushWotdAudienceBody(String wallTitle) {
    return '$wallTitle';
  }

  @override
  String get notifPushWotdAudienceBodyUntitled => 'Abra o Prism para ver o papel de parede do dia.';

  @override
  String get notifPushWotdAudienceTitle => 'O papel de parede do dia chegou';

  @override
  String get notifPushWotdCreatorBody =>
      'O Prism escolheu seu papel de parede para todos hoje. Obrigado por compartilhá-lo.';

  @override
  String get notifPushWotdCreatorTitle => 'Seu papel de parede foi escolhido para hoje';

  @override
  String get notifRead => 'Já lida';

  @override
  String get notifRemoved => 'Notificação removida';

  @override
  String get notifReportUnknownContentType => 'conteúdo';

  @override
  String notifSemanticsRow(String message, String time, String readStatus) {
    return '$message. $time. $readStatus';
  }

  @override
  String get notifSettingDrops => 'Drops semanais';

  @override
  String get notifSettingDropsDescription => 'Alertas quando um novo Drop está ativo e antes de terminar.';

  @override
  String get notifSettingFollowers => 'Seguidores';

  @override
  String get notifSettingFollowersDescription => 'Alertas quando alguém novo segue você.';

  @override
  String get notifSettingPosts => 'Postagens';

  @override
  String get notifSettingPostsDescription => 'Alertas quando os criadores que você segue compartilham novos trabalhos.';

  @override
  String get notifSettingRecommendations => 'Recomendações';

  @override
  String get notifSettingRecommendationsDescription => 'Dicas, notícias e opções de papéis de parede do Prism.';

  @override
  String get notifSettingStreaks => 'Lembretes de sequência';

  @override
  String get notifSettingStreaksDescription =>
      'Alerta por volta das 20h caso sua sequência de acessos esteja prestes a acabar.';

  @override
  String get notifSettingWotd => 'Papel de parede do dia';

  @override
  String get notifSettingWotdDescription => 'Um papel de parede escolhido todos os dias.';

  @override
  String get notifSignInToChange => 'Faça login para alterar esta configuração.';

  @override
  String get notifSignInToTurnOn => 'Faça login para ativar';

  @override
  String get notifTapToOpenPrism => 'Toque para abrir o Prism.';

  @override
  String get notifTitle => 'Notificações';

  @override
  String get notifToday => 'Hoje';

  @override
  String get notifUndo => 'Desfazer';

  @override
  String get notifUnread => 'Ainda não lida';

  @override
  String get notifYesterday => 'Ontem';

  @override
  String notifYesterdayAt(String time) {
    return 'Ontem, $time';
  }

  @override
  String get onboardingAiGenerateError => 'Algo deu errado.\nToque em Gerar para tentar novamente.';

  @override
  String get onboardingAiGeneratePrompt => 'Toque em Gerar para criar\nseu papel de parede exclusivo';

  @override
  String get onboardingAiGenerating => 'Criando seu papel de parede…';

  @override
  String get onboardingBrowseGuest => 'Navegue sem uma conta';

  @override
  String get onboardingCategoriesUnavailable => 'não foi possível carregar categorias, você pode pular esta etapa';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingContinueApple => 'Continuar com a Apple';

  @override
  String get onboardingContinueGoogle => 'Continuar com o Google';

  @override
  String onboardingContinueSelected(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Continuar ($countString selecionados)';
  }

  @override
  String get onboardingCouldNotLogOut => 'Não foi possível sair. Por favor, tente novamente.';

  @override
  String get onboardingCreatorsUnavailable => 'não foi possível carregar os criadores, você pode pular esta etapa';

  @override
  String get onboardingFirstAiWallpaper => 'seu primeiro papel de parede, gerado por IA';

  @override
  String get onboardingFirstWallpaperSaveFailed =>
      'Não foi possível salvar seu papel de parede. Tente novamente ou pule.';

  @override
  String get onboardingFirstWallpaperSavedPhotos => 'Salvo no app Fotos!';

  @override
  String get onboardingFirstWallpaperSet => 'Papel de parede definido!';

  @override
  String get onboardingFirstWallpaperSetFailed =>
      'Não foi possível definir seu papel de parede. Tente novamente ou pule.';

  @override
  String get onboardingFirstWallpaperSetHome => 'Papel de parede definido na tela inicial.';

  @override
  String get onboardingFirstWallpaperSetHomeLock => 'Papel de parede definido nas telas inicial e de bloqueio.';

  @override
  String get onboardingFirstWallpaperSetLock => 'Papel de parede definido na tela de bloqueio.';

  @override
  String get onboardingFollow => 'Seguir';

  @override
  String onboardingFollowCreatorMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'sugerimos que você siga estes $countString criadores';
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
      zero: '$countString seguidores',
    );
    return '$_temp0';
  }

  @override
  String get onboardingFollowing => 'Seguindo';

  @override
  String get onboardingGenerateFailure => 'algo deu errado – toque em gerar para tentar novamente';

  @override
  String get onboardingGenerateSuccess => 'ficou ótimo! abrindo seu papel de parede';

  @override
  String get onboardingGenerateWallpaper => 'gerar meu papel de parede';

  @override
  String get onboardingHeadlineCreators => 'Encontre seu pessoal';

  @override
  String get onboardingHeadlineCustomize => 'Deixe do seu jeito';

  @override
  String get onboardingHeadlineGenerate => 'Crie o seu\nprimeiro papel de parede';

  @override
  String get onboardingHeadlineInterests => 'Escolha sua vibração';

  @override
  String get onboardingLoadCategoriesFailed => 'Não foi possível carregar categorias.';

  @override
  String get onboardingLoadCreatorsFailed => 'Não foi possível carregar os criadores.';

  @override
  String get onboardingPro => 'Pro';

  @override
  String get onboardingProFree => '→ grátis para você';

  @override
  String get onboardingRecoveryCreatorsFailed =>
      'Não foi possível carregar os criadores. Verifique sua conexão e toque em Recarregar.';

  @override
  String get onboardingRecoveryFollowFailed => 'Não foi possível seguir estes criadores. Tente novamente.';

  @override
  String get onboardingRecoveryFollowFailedHelper =>
      'não foi possível seguir esses criadores. verifique sua conexão e tente novamente';

  @override
  String get onboardingRecoveryReload => 'Recarregar';

  @override
  String get onboardingRecoveryRetry => 'Tente novamente';

  @override
  String get onboardingRecoverySaveInterestsFailed => 'Não foi possível salvar suas escolhas. Tente novamente.';

  @override
  String get onboardingRecoverySaveInterestsFailedHelper =>
      'não foi possível salvar suas escolhas. verifique sua conexão e tente novamente';

  @override
  String get onboardingRecoverySessionExpired => 'Sua sessão expirou. Faça login novamente.';

  @override
  String get onboardingRecoverySessionExpiredHelper => 'sua sessão expirou. faça login novamente para continuar';

  @override
  String get onboardingRecoverySetupFailed => 'Não foi possível concluir a configuração. Tente novamente.';

  @override
  String get onboardingRecoverySetupFailedHelper =>
      'não foi possível concluir a configuração. verifique sua conexão e tente novamente';

  @override
  String get onboardingRecoverySignIn => 'Faça login novamente';

  @override
  String get onboardingReloadLower => 'recarregar';

  @override
  String get onboardingSavePhotos => 'salvar em fotos';

  @override
  String onboardingSelectInterestMinimum(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'selecione pelo menos $countString categorias para personalizar seu feed';
  }

  @override
  String get onboardingSetWallpaper => 'definir como papel de parede';

  @override
  String get onboardingSignInAgainLower => 'faça login novamente';

  @override
  String get onboardingSkip => 'Pular';

  @override
  String get onboardingSkipLower => 'pular';

  @override
  String get onboardingTermsRequired => 'Concorde primeiro com os Termos e a Política de Privacidade.';

  @override
  String get onboardingTryAgainLower => 'tente novamente';

  @override
  String onboardingWallpaperForInterest(String category) {
    return 'escolhemos este papel de parede com base no seu interesse em $category';
  }

  @override
  String get onboardingWallpaperJustForYou => 'escolhemos este papel de parede só para você';

  @override
  String get onboardingWelcomeDescription => 'Milhões de papéis de parede premium de grandes artistas.';

  @override
  String get onboardingWelcomeHeadline => 'Sua tela, reimaginada.';

  @override
  String get premiumPageExplorePlans => 'Explore os planos Prism Premium.';

  @override
  String get premiumPagePlansUnavailable =>
      'Os planos não estão disponíveis no momento. Verifique sua conexão e tente novamente.';

  @override
  String get premiumPageTitle => 'Prism Premium';

  @override
  String get premiumPageTryAgain => 'Tente novamente';

  @override
  String get premiumPageViewPlans => 'Ver planos';

  @override
  String get premiumGuestStorePurchaseActive =>
      'Sua compra na loja está ativa neste dispositivo. Entre para usar os recursos Pro vinculados à conta.';

  @override
  String get premiumPurchasePending => 'Sua compra foi salva. O Pro pode levar um minuto para ser ativado.';

  @override
  String get premiumPurchaseUnconfirmed =>
      'Não foi possível confirmar sua compra. Tente usar Restaurar compras nas Configurações.';

  @override
  String get wallpaperAccentColor => 'Cor de destaque';

  @override
  String get wallpaperAccentColorsOriginal => 'Cores originais do papel de parede';

  @override
  String get wallpaperResetOriginal => 'Restaurar original';

  @override
  String get wallpaperAll => 'Todos';

  @override
  String get wallpaperApplyTo => 'Aplicar em';

  @override
  String get wallpaperAutoRotateApplyTo => 'Aplicar em';

  @override
  String get wallpaperAutoRotateBatterySteps =>
      'Abra Configurações > Apps > Prism > Bateria. Defina o uso da bateria como irrestrito.';

  @override
  String get wallpaperAutoRotateBatteryTip =>
      'Se os papéis de parede pararem de mudar, defina o uso da bateria do Prism como irrestrito. Abra Configurações > Apps > Prism > Bateria.';

  @override
  String get wallpaperAutoRotateBothScreens => 'Ambos';

  @override
  String get wallpaperAutoRotateChangeError => 'Não foi possível alterar o papel de parede.';

  @override
  String get wallpaperAutoRotateChangeLabel => 'Mudar';

  @override
  String get wallpaperAutoRotateChargingDescription => 'Mude quando conectado, no máximo uma vez por intervalo';

  @override
  String get wallpaperAutoRotateChargingOnly => 'Somente durante o carregamento';

  @override
  String get wallpaperAutoRotateCopySteps => 'Copiar etapas';

  @override
  String get wallpaperAutoRotateCouldNotStart => 'Não foi possível iniciar. Tente novamente.';

  @override
  String wallpaperAutoRotateDownloadedCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'papéis de parede',
      one: 'papel de parede',
      zero: 'papéis de parede',
    );
    return 'Baixados $cachedString de $totalString $_temp0';
  }

  @override
  String wallpaperAutoRotateEnabledUntil(String date) {
    return 'Passe ativo até $date';
  }

  @override
  String get wallpaperAutoRotateGotIt => 'Entendi';

  @override
  String get wallpaperAutoRotateHomeScreen => 'Tela inicial';

  @override
  String get wallpaperAutoRotateInterval12Hours => 'A cada 12 horas';

  @override
  String get wallpaperAutoRotateInterval15 => 'A cada 15 minutos (alto consumo de bateria)';

  @override
  String get wallpaperAutoRotateInterval30 => 'A cada 30 minutos';

  @override
  String get wallpaperAutoRotateInterval3Days => 'A cada 3 dias';

  @override
  String get wallpaperAutoRotateInterval3Hours => 'A cada 3 horas';

  @override
  String get wallpaperAutoRotateInterval6Hours => 'A cada 6 horas';

  @override
  String get wallpaperAutoRotateIntervalDay => 'Diariamente';

  @override
  String get wallpaperAutoRotateIntervalHour => 'A cada hora';

  @override
  String get wallpaperAutoRotateIntervalWeek => 'Toda semana';

  @override
  String get wallpaperAutoRotateKeepRunning => 'Continue funcionando';

  @override
  String get wallpaperAutoRotateLoadError => 'Não foi possível carregar as configurações de rotação automática.';

  @override
  String get wallpaperAutoRotateLoadingWalls => 'Carregando papéis de parede';

  @override
  String get wallpaperAutoRotateLockScreen => 'Tela de bloqueio';

  @override
  String wallpaperAutoRotateMix(int count, String source) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede de $source na seleção',
      one: '1 papel de parede de $source na seleção',
      zero: '$countString papéis de parede de $source na seleção',
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
      other: '$countString papéis de parede de $source na seleção. Usando os primeiros 100.',
      one: '1 papel de parede de $source na seleção. Usando os primeiros 100.',
      zero: '$countString papéis de parede de $source na seleção. Usando os primeiros 100.',
    );
    return '$_temp0';
  }

  @override
  String wallpaperAutoRotateNextChange(String time) {
    return 'Próxima mudança em torno de $time';
  }

  @override
  String wallpaperAutoRotateNounCategory(String category) {
    return '$category';
  }

  @override
  String get wallpaperAutoRotateNounDownloads => 'downloads';

  @override
  String get wallpaperAutoRotateNounFavourites => 'favoritos';

  @override
  String get wallpaperAutoRotateNounHistory => 'seu histórico';

  @override
  String get wallpaperAutoRotateNounWotd => 'papéis de parede do dia';

  @override
  String get wallpaperAutoRotateOff => 'Desligado';

  @override
  String get wallpaperAutoRotateOffEnded =>
      'A rotação automática está desativada porque seu plano ou passe do Prism Premium terminou.';

  @override
  String get wallpaperAutoRotateOpenDownloads => 'Abrir downloads';

  @override
  String get wallpaperAutoRotateOpenFavourites => 'Abrir favoritos';

  @override
  String get wallpaperAutoRotatePassEnabled => 'A rotação automática fica ativada por 7 dias.';

  @override
  String wallpaperAutoRotatePassPurchase(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Passe de 7 dias · $coinsString moedas';
  }

  @override
  String get wallpaperAutoRotatePickCategory => 'Escolha uma categoria';

  @override
  String wallpaperAutoRotatePreparing(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede',
      one: '1 papel de parede',
      zero: '$countString papéis de parede',
    );
    return 'Preparando $_temp0';
  }

  @override
  String get wallpaperAutoRotateProBody => 'Experimente por 7 dias com moedas ou adquira o Prism Pro.';

  @override
  String get wallpaperAutoRotateProTitle => 'A rotação automática é um recurso do Prism Pro.';

  @override
  String wallpaperAutoRotateReadyCount(int cached, int total) {
    final intl.NumberFormat cachedNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String cachedString = cachedNumberFormat.format(cached);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'papéis de parede prontos',
      one: 'papel de parede pronto',
      zero: 'papéis de parede prontos',
    );
    return '$cachedString de $totalString $_temp0';
  }

  @override
  String get wallpaperAutoRotateScheduled => 'Agendado';

  @override
  String get wallpaperAutoRotateShuffle => 'Embaralhar';

  @override
  String get wallpaperAutoRotateShuffleDescription => 'Ordem aleatória em vez de uma após a outra';

  @override
  String get wallpaperAutoRotateSourceCategory => 'Categoria';

  @override
  String get wallpaperAutoRotateSourceDownloads => 'Downloads';

  @override
  String get wallpaperAutoRotateSourceFavourites => 'Favoritos';

  @override
  String get wallpaperAutoRotateSourceHistory => 'Histórico';

  @override
  String get wallpaperAutoRotateSourceLabel => 'Fonte';

  @override
  String get wallpaperAutoRotateSourceLoadError =>
      'Não foi possível carregar os papéis de parede. Verifique sua conexão.';

  @override
  String get wallpaperAutoRotateSourceWotd => 'Papel de parede do dia';

  @override
  String get wallpaperAutoRotateStartError => 'Não foi possível iniciar a rotação do papel de parede.';

  @override
  String get wallpaperAutoRotateStarting => 'Começando';

  @override
  String get wallpaperAutoRotateStatusLabel => 'Status';

  @override
  String get wallpaperAutoRotateStepsCopied => 'Etapas copiadas.';

  @override
  String get wallpaperAutoRotateStopError => 'Não foi possível interromper a rotação do papel de parede.';

  @override
  String get wallpaperAutoRotateTitle => 'Rotação automática';

  @override
  String get wallpaperAutoRotateTooFewCategory => 'Esta categoria tem menos de 2 papéis de parede. Escolha outra.';

  @override
  String get wallpaperAutoRotateTooFewDownloads => 'Baixe pelo menos 2 papéis de parede para alternar entre eles.';

  @override
  String get wallpaperAutoRotateTooFewFavourites =>
      'Adicione pelo menos 2 papéis de parede aos favoritos para alternar entre eles.';

  @override
  String get wallpaperAutoRotateTooFewHistory =>
      'Defina pelo menos 2 papéis de parede no Prism para alternar entre eles.';

  @override
  String get wallpaperAutoRotateTooFewWotd => 'Ainda não há escolhas anteriores suficientes.';

  @override
  String get wallpaperAutoRotateUnlockError => 'Não foi possível desbloquear a rotação automática. Tente novamente.';

  @override
  String get wallpaperAutoRotateUpdateError => 'Não foi possível atualizar a rotação automática.';

  @override
  String get wallpaperBack => 'Voltar';

  @override
  String get wallpaperBlockCreator => 'Bloquear criador';

  @override
  String get wallpaperBlockCreatorNotFound => 'Não foi possível encontrar este criador. Tente novamente.';

  @override
  String get wallpaperBoostAlready => 'Já impulsionado.';

  @override
  String wallpaperBoostAlreadyUntil(String time) {
    return 'Já impulsionado até $time.';
  }

  @override
  String wallpaperBoostConfirmButton(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Impulsionar por $coinsString moedas';
  }

  @override
  String wallpaperBoostConfirmMessage(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Destaque este papel de parede no carrossel da tela inicial e no topo de Em alta por 24 horas, por $coinsString moedas.';
  }

  @override
  String wallpaperBoostDurationAndCost(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return '24 horas em destaque · $coinsString moedas';
  }

  @override
  String get wallpaperBoostFailed => 'Não foi possível impulsionar este papel de parede. Tente novamente.';

  @override
  String get wallpaperBoostOnlyApproved =>
      'Somente papéis de parede aprovados que você enviou podem ser impulsionados.';

  @override
  String get wallpaperBoostSlotsTaken =>
      'Todas as vagas de impulsionamento estão ocupadas. Tente novamente mais tarde.';

  @override
  String wallpaperBoostSlotsTakenUntil(String time) {
    return 'Todas as vagas de impulsionamento estão ocupadas. A próxima será liberada $time.';
  }

  @override
  String get wallpaperBoostTitle => 'Impulsione Em alta';

  @override
  String get wallpaperBoostedSuccess => 'Impulsionado. Já aparece na tela inicial e em Em alta.';

  @override
  String get wallpaperBoostedTag => 'Impulsionado';

  @override
  String wallpaperBoostedUntil(String time) {
    return 'Impulsionado até $time';
  }

  @override
  String get wallpaperBrowseWallpapers => 'Procure papéis de parede';

  @override
  String wallpaperByCreator(String name) {
    return 'Papel de parede de $name';
  }

  @override
  String get wallpaperByPrismCreator => 'Papel de parede do criador do Prism';

  @override
  String get wallpaperCategories => 'Categorias';

  @override
  String get wallpaperCategory => 'Categoria';

  @override
  String get wallpaperCategoryFeedEmptyBody => 'Novos papéis de parede chegam com frequência. Volte em breve.';

  @override
  String get wallpaperCategoryFeedEmptyTitle => 'Ainda não há papéis de parede aqui';

  @override
  String wallpaperCategoryNamed(String name) {
    return 'Categoria: $name';
  }

  @override
  String get wallpaperChangeNow => 'Mude agora';

  @override
  String get wallpaperCheckBackSoon => 'Volte em breve.';

  @override
  String get wallpaperCheckBackTomorrow => 'Volte amanhã.';

  @override
  String get wallpaperCheckConnection => 'Verifique sua conexão e tente novamente.';

  @override
  String get wallpaperClear => 'Limpar';

  @override
  String get wallpaperClearFilters => 'Limpar filtros';

  @override
  String get wallpaperClearHistoryAction => 'Limpar histórico';

  @override
  String get wallpaperClearHistoryBody =>
      'Isso remove a lista de papéis de parede que você definiu. Seus papéis de parede permanecem como estão.';

  @override
  String get wallpaperClearHistoryTitle => 'Limpar histórico?';

  @override
  String get wallpaperClearSearch => 'Limpar pesquisa';

  @override
  String get wallpaperClosePreview => 'Fechar visualização';

  @override
  String get wallpaperCollapseDetails => 'Recolher detalhes do papel de parede';

  @override
  String get wallpaperCollection => 'Coleção';

  @override
  String get wallpaperCollectionLoadError => 'Não foi possível carregar esta coleção';

  @override
  String wallpaperCollectionNamed(String name) {
    return 'Coleção: $name';
  }

  @override
  String wallpaperCollectionPreviewUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Prévia desbloqueada por 24 horas (-$coinsString moedas).';
  }

  @override
  String get wallpaperCollectionRefreshError => 'Não foi possível atualizar. Puxe para baixo para tentar novamente.';

  @override
  String get wallpaperCollectionsEmptyBody => 'Puxe para baixo para atualizar ou volte em breve.';

  @override
  String get wallpaperCollectionsEmptyTitle => 'Ainda não há coleções';

  @override
  String get wallpaperCopyAccentHexHint => 'Pressione e segure para copiar a cor hexadecimal';

  @override
  String wallpaperCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede',
      one: '1 papel de parede',
      zero: 'Nenhum papel de parede',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDelete => 'Excluir';

  @override
  String get wallpaperDeleteManyDownloadsBody =>
      'Eles são removidos deste dispositivo. Você pode baixá-los novamente mais tarde.';

  @override
  String wallpaperDeleteManyDownloadsTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Excluir $countString downloads?';
  }

  @override
  String get wallpaperDeleteOneDownloadBody =>
      'Ele é removido deste dispositivo. Você pode baixá-lo novamente mais tarde.';

  @override
  String get wallpaperDeleteOneDownloadTitle => 'Excluir este download?';

  @override
  String get wallpaperDepthEditorSubtitle =>
      'No editor da tela de bloqueio, toque em ••• e depois em Efeito de profundidade.';

  @override
  String get wallpaperDepthEffect => 'Efeito de profundidade';

  @override
  String get wallpaperDepthSubjectSubtitle => 'O elemento principal da imagem fica na frente do relógio.';

  @override
  String get wallpaperSpatialScene => 'Cena espacial';

  @override
  String get wallpaperSpatialGreatSubtitle => 'Profundidade nítida. Cria uma tela de bloqueio 3D forte.';

  @override
  String get wallpaperSpatialOkSubtitle => 'Alguma profundidade. O efeito 3D é suave.';

  @override
  String get wallpaperSpatialGuideTitle => 'Defina como Cena espacial';

  @override
  String get wallpaperSpatialGuideBody => 'No iPhone 12 ou posterior com iOS 26:';

  @override
  String get wallpaperSpatialStepSave => 'Salve este wallpaper em Fotos.';

  @override
  String get wallpaperSpatialStepPick =>
      'Na tela de bloqueio, toque e mantenha pressionada a tela. Toque no botão Adicionar, toque em Fotos e depois selecione a foto.';

  @override
  String get wallpaperSpatialStepButton =>
      'Toque no botão Cena espacial para ativar o efeito 3D e depois toque em Adicionar.';

  @override
  String get wallpaperSpatialPreviewLabel => '3D';

  @override
  String get wallpaperSpatialPreviewOn => 'Visualizar em 3D';

  @override
  String get wallpaperSpatialPreviewOff => 'Desativar a visualização 3D';

  @override
  String get wallpaperSpatialDragHint => 'Arraste para inclinar';

  @override
  String get wallpaperDetailColorCodeCopied => 'Código de cores copiado para a área de transferência';

  @override
  String get wallpaperDetailNotFound => 'Papel de parede não encontrado';

  @override
  String get wallpaperDiscard => 'Descartar';

  @override
  String get wallpaperDismiss => 'Dispensar';

  @override
  String get wallpaperDownload => 'Baixar';

  @override
  String wallpaperDownloadCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString downloads',
      one: '1 download',
      zero: '$countString downloads',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadSortName => 'Nome';

  @override
  String get wallpaperDownloadSortNewest => 'Mais recente';

  @override
  String get wallpaperDownloadSortOldest => 'Mais antigo';

  @override
  String get wallpaperDownloadWallpaper => 'Baixar papel de parede';

  @override
  String get wallpaperDownloadedWallpaper => 'Papel de parede baixado';

  @override
  String get wallpaperDownloadedWallpaperUnavailable => 'O papel de parede baixado não está disponível';

  @override
  String wallpaperDownloadsDeleteError(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Não foi possível excluir $countString downloads.',
      one: 'Não foi possível excluir 1 download.',
      zero: 'Não foi possível excluir $countString downloads.',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperDownloadsEmptyBody => 'Os papéis de parede que você baixa são mantidos aqui.';

  @override
  String get wallpaperDownloadsEmptyTitle => 'Ainda não há downloads';

  @override
  String get wallpaperDownloadsLoadError => 'Não foi possível carregar seus downloads';

  @override
  String get wallpaperDownloadsLoadHelp => 'Verifique seu acesso ao armazenamento e tente novamente.';

  @override
  String get wallpaperDownloadsRefreshError => 'Não foi possível atualizar os downloads. Tente novamente.';

  @override
  String get wallpaperDownloadsShareError => 'Não foi possível compartilhar. Tente novamente.';

  @override
  String get wallpaperDownloadsTitle => 'Downloads';

  @override
  String get wallpaperEdit => 'Editar';

  @override
  String get wallpaperEditTitle => 'Editar papel de parede';

  @override
  String get wallpaperExpandDetails => 'Expanda os detalhes do papel de parede';

  @override
  String get wallpaperFavourite => 'Favorito';

  @override
  String get wallpaperFavouriteAddedToast => 'Adicionado aos favoritos.';

  @override
  String get wallpaperFavouriteClearAccountMessage => 'Isso os remove da sua conta.';

  @override
  String get wallpaperFavouriteClearAll => 'Limpar todos os favoritos';

  @override
  String get wallpaperFavouriteClearDeviceMessage => 'Isso os remove deste dispositivo.';

  @override
  String get wallpaperFavouriteClearError => 'Não foi possível limpar os favoritos. Tente novamente.';

  @override
  String wallpaperFavouriteClearManyTitle(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Limpar $countString favoritos?';
  }

  @override
  String get wallpaperFavouriteClearOneTitle => 'Limpar 1 favorito?';

  @override
  String wallpaperFavouriteClearedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favoritos removidos',
      one: '1 favorito removido',
      zero: '$countString favoritos removidos',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteClearedOne => '1 favorito removido';

  @override
  String wallpaperFavouriteCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favoritos',
      one: '1 favorito',
      zero: 'Nenhum favorito',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteEmptyBody => 'Toque no coração em um papel de parede para mantê-lo aqui.';

  @override
  String get wallpaperFavouriteEmptyTitle => 'Ainda não há favoritos';

  @override
  String get wallpaperFavouriteExport => 'Exportar favoritos';

  @override
  String get wallpaperFavouriteExportEmpty => 'Ainda não há favoritos para exportar.';

  @override
  String get wallpaperFavouriteExportError => 'Não foi possível exportar favoritos. Tente novamente.';

  @override
  String get wallpaperFavouriteGuestPrompt => 'Faça login para mantê-los em todos os dispositivos';

  @override
  String get wallpaperFavouriteLoadError => 'Não foi possível carregar seus favoritos';

  @override
  String get wallpaperFavouriteMoreActions => 'Mais ações dos favoritos';

  @override
  String get wallpaperFavouriteNoMatch => 'Não há favoritos correspondentes';

  @override
  String get wallpaperFavouriteNotSynced => 'Não sincronizado';

  @override
  String get wallpaperFavouriteRefreshFallback => 'Não foi possível atualizar os favoritos. Mostrando sua lista salva.';

  @override
  String get wallpaperFavouriteRemove => 'Remover';

  @override
  String get wallpaperFavouriteRemoveAction => 'Remover dos favoritos';

  @override
  String get wallpaperFavouriteRemoveError => 'Não foi possível remover os favoritos. Tente novamente.';

  @override
  String wallpaperFavouriteRemovedMany(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString favoritos removidos',
      one: '1 favorito removido',
      zero: '$countString favoritos removidos',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperFavouriteRemovedOne => 'Removido dos favoritos';

  @override
  String get wallpaperFavouriteRemovedToast => 'Removido dos favoritos.';

  @override
  String get wallpaperFavouriteRestoreError => 'Não foi possível restaurar os favoritos.';

  @override
  String get wallpaperFavouriteSearchHint => 'Pesquise por criador ou categoria';

  @override
  String get wallpaperFavouriteSetUsesFirst => 'A opção Definir usa o primeiro favorito selecionado';

  @override
  String get wallpaperFavouriteShareError => 'Não foi possível compartilhar. Tente novamente.';

  @override
  String get wallpaperFavouriteSortOldest => 'Mais antigo';

  @override
  String get wallpaperFavouriteSortRecentlyAdded => 'Adicionado recentemente';

  @override
  String get wallpaperFavouriteSortSource => 'Fonte';

  @override
  String get wallpaperFavouriteStatus => 'Nos seus favoritos';

  @override
  String get wallpaperFavouriteTryDifferent => 'Tente uma pesquisa ou fonte diferente.';

  @override
  String get wallpaperFavouriteUnavailableLegacy =>
      'Este favorito é de uma versão mais antiga e não pode ser aberto. Pressione e segure para removê-lo.';

  @override
  String get wallpaperFavouriteWaitingSync => 'Aguardando sincronização';

  @override
  String get wallpaperFavouritesTitle => 'Favoritos';

  @override
  String get wallpaperFeedAnnouncement => 'Anúncio';

  @override
  String get wallpaperFeedCaughtUpBody => 'Puxe para baixo para atualizar. Novas escolhas chegarão aqui.';

  @override
  String get wallpaperFeedCaughtUpTitle => 'Você já viu tudo';

  @override
  String get wallpaperFeedClearHistoryError => 'Não foi possível limpar o histórico. Tente novamente.';

  @override
  String get wallpaperFeedDiscovery => 'Descoberta';

  @override
  String get wallpaperFeedEmptyBody =>
      'Siga os criadores ou escolha interesses para que possamos mostrar mais do que você gosta.';

  @override
  String get wallpaperFeedEmptyTitle => 'Dê forma a este feed';

  @override
  String get wallpaperFeedFollowingEmptyTitle => 'Siga os criadores para ver seus novos papéis de parede aqui';

  @override
  String get wallpaperFeedFollowingLoadError => 'Não foi possível carregar o feed de quem você segue';

  @override
  String get wallpaperFeedLatestLoadError => 'Não foi possível carregar os papéis de parede mais recentes';

  @override
  String get wallpaperFeedLearnedFromYou => 'Aprendi com você';

  @override
  String get wallpaperFeedLearningEmpty => 'Abra, salve e defina papéis de parede para personalizar seu feed.';

  @override
  String get wallpaperFeedLearningHistoryCleared => 'Histórico de aprendizagem apagado';

  @override
  String get wallpaperFeedLoadError => 'Não foi possível carregar seu feed';

  @override
  String get wallpaperFeedLoadMoreError => 'Não foi possível carregar mais. Tente novamente';

  @override
  String get wallpaperFeedMixAdventurous => 'Aventureiro';

  @override
  String get wallpaperFeedMixAdventurousDescription => 'Mais papéis de parede fora do seu perfil de interesses.';

  @override
  String get wallpaperFeedMixBalanced => 'Equilibrado';

  @override
  String get wallpaperFeedMixBalancedDescription => 'Ao seu gosto, com algumas surpresas.';

  @override
  String get wallpaperFeedMixFamiliar => 'Familiar';

  @override
  String get wallpaperFeedMixFamiliarDescription => 'Principalmente o que você já ama.';

  @override
  String wallpaperFeedPickAtLeast(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Escolha pelo menos $countString';
  }

  @override
  String wallpaperFeedPickedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString escolhido';
  }

  @override
  String get wallpaperFeedPopularEmptyTitle => 'Ainda não há papéis de parede populares';

  @override
  String get wallpaperFeedPopularLoadError => 'Não foi possível carregar papéis de parede populares';

  @override
  String get wallpaperFeedPullToRefresh => 'Puxe para baixo para atualizar.';

  @override
  String get wallpaperFeedRefreshError => 'Não foi possível atualizar seu feed.';

  @override
  String get wallpaperFeedSaveError => 'Não foi possível salvar as configurações do feed. Tente novamente.';

  @override
  String get wallpaperFeedSettingsHint => 'Toque duas vezes para abrir as configurações do feed';

  @override
  String get wallpaperFeedStartingPoints => 'Pontos de partida';

  @override
  String get wallpaperFeedTabFollowing => 'Seguindo';

  @override
  String get wallpaperFeedTabForYou => 'Para você';

  @override
  String get wallpaperFeedTabLatest => 'Mais recente';

  @override
  String get wallpaperFeedTabPopular => 'Popular';

  @override
  String get wallpaperFeedTabTrending => 'Em alta';

  @override
  String get wallpaperFeedTuneDescription => 'O Prism aprende com o que você abre, salva e configura.';

  @override
  String get wallpaperFeedTuneTitle => 'Ajuste seu feed';

  @override
  String get wallpaperFeedUpdating => 'Atualizando';

  @override
  String get wallpaperFeedWallsLoadError => 'Não foi possível carregar os papéis de parede';

  @override
  String get wallpaperFewerLikeThisConfirmation => 'Você verá menos papéis de parede como este.';

  @override
  String get wallpaperFewerLikeThisUndo => 'Desfazer';

  @override
  String get wallpaperFileMovedOrDeleted => 'O arquivo pode ter sido movido ou excluído.';

  @override
  String wallpaperFilterApplyCost(int coins, int missing) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'Aplicar este filtro custa $coinsString moedas. Você precisa de mais $missingString moedas.';
  }

  @override
  String get wallpaperFilterBlur => 'Desfoque';

  @override
  String get wallpaperFilterBrightness => 'Brilho';

  @override
  String get wallpaperFilterEffectEdge => 'Borda';

  @override
  String get wallpaperFilterEffectEmboss => 'Relevo';

  @override
  String get wallpaperFilterEffectHighPass => 'Realce de detalhes';

  @override
  String get wallpaperFilterEffectSharpen => 'Nitidez';

  @override
  String get wallpaperFilterHoldToCompare => 'Segure para comparar';

  @override
  String get wallpaperFilterHue => 'Matiz';

  @override
  String get wallpaperFilterLightness => 'Luminosidade';

  @override
  String get wallpaperFilterLightnessUnavailable => 'A luminosidade não está disponível neste dispositivo.';

  @override
  String get wallpaperFilterNeedCoins => 'Você precisa de moedas para usar este filtro premium';

  @override
  String get wallpaperFilterOriginal => 'Original';

  @override
  String get wallpaperFilterSaturation => 'Saturação';

  @override
  String get wallpaperFilterSaveError => 'Não foi possível salvar o papel de parede. Por favor, tente novamente!';

  @override
  String get wallpaperFilterTabAdjustments => 'Ajustar';

  @override
  String get wallpaperFilterTabFilters => 'Filtros';

  @override
  String wallpaperFilterUnlocked(int coins) {
    final intl.NumberFormat coinsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String coinsString = coinsNumberFormat.format(coins);

    return 'Filtro premium desbloqueado para esta edição (-$coinsString moedas).';
  }

  @override
  String get wallpaperFitBlur => 'Ajustar com desfoque';

  @override
  String get wallpaperFitColour => 'Combine com a cor';

  @override
  String get wallpaperFitFill => 'Preencher';

  @override
  String get wallpaperGenericError => 'Algo deu errado!';

  @override
  String get wallpaperGoBack => 'Volte';

  @override
  String get wallpaperGotItFewerLikeThis => 'Entendi. Você verá menos assim.';

  @override
  String get wallpaperHidePreviewControls => 'Ocultar controles';

  @override
  String get wallpaperHistoryBothScreens => 'Ambas as telas';

  @override
  String get wallpaperHistoryCurrent => 'Atual';

  @override
  String get wallpaperHistoryCurrentPrefix => 'Atual. ';

  @override
  String get wallpaperHistoryEmptyBody =>
      'Os papéis de parede que você definir aparecerão aqui, para que você possa configurá-los novamente.';

  @override
  String get wallpaperHistoryEmptyTitle => 'Ainda não há papéis de parede';

  @override
  String get wallpaperHistoryRemoveAction => 'Remover do histórico';

  @override
  String get wallpaperHomeAppName => 'Prism';

  @override
  String get wallpaperImageSemanticHint => 'Segure para favoritos, compartilhar e restaurar. Role para ver detalhes.';

  @override
  String get wallpaperPreviousInFeed => 'Papel de parede anterior';

  @override
  String get wallpaperNextInFeed => 'Próximo papel de parede';

  @override
  String get wallpaperImageSemanticLabel => 'Papel de parede';

  @override
  String get wallpaperImmersiveHint => 'Toque para ocultar os controles';

  @override
  String get wallpaperInsufficientCoins => 'Não há moedas suficientes. Ganhe moedas em recompensas.';

  @override
  String wallpaperInterestLearnedLabel(String label, int percent) {
    final intl.NumberFormat percentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String percentString = percentNumberFormat.format(percent);

    return 'Aprendido: $label, $percentString por cento';
  }

  @override
  String wallpaperInterestSelectedLabel(String name, String selection) {
    return 'Interesse: $name, $selection';
  }

  @override
  String get wallpaperLandscapeCrop => 'Papel de parede de paisagem: as laterais serão cortadas';

  @override
  String get wallpaperLibraryCollections => 'Coleções';

  @override
  String get wallpaperLibraryDownloads => 'Downloads';

  @override
  String get wallpaperLibraryFavourites => 'Favoritos';

  @override
  String get wallpaperLibraryHistory => 'Histórico';

  @override
  String get wallpaperLibraryTitle => 'Biblioteca';

  @override
  String get wallpaperLive => 'Animado';

  @override
  String get wallpaperLiveApplied => 'Papel de parede animado definido.';

  @override
  String wallpaperLiveApplyPhotoDescription(String style) {
    return 'Visualização do $style';
  }

  @override
  String get wallpaperLiveBatterySaver => 'Economizador de bateria';

  @override
  String get wallpaperLiveChooseAnotherVideo => 'Escolha outro vídeo';

  @override
  String get wallpaperLiveChooseVideo => 'Escolha um vídeo';

  @override
  String get wallpaperLiveConfirmPreview => 'Confirme na visualização do sistema.';

  @override
  String get wallpaperLiveDeviceUnavailable => 'Não disponível neste dispositivo';

  @override
  String get wallpaperLiveErrorGeneric => 'Não foi possível definir o papel de parede animado. Tente novamente.';

  @override
  String get wallpaperLiveErrorImageTooLarge => 'Essa imagem é muito grande para um papel de parede animado.';

  @override
  String get wallpaperLiveErrorMemory => 'Memória insuficiente. Feche outros aplicativos e tente novamente.';

  @override
  String get wallpaperLiveErrorNotAllowed =>
      'Seu dispositivo ou perfil de trabalho não permite alterações no papel de parede.';

  @override
  String get wallpaperLiveErrorPermission => 'O Prism não tem permissão para ler esse arquivo.';

  @override
  String get wallpaperLiveErrorPreview => 'Não foi possível abrir a visualização do sistema.';

  @override
  String get wallpaperLiveErrorReadFile => 'Não foi possível ler o arquivo. Tente novamente.';

  @override
  String get wallpaperLiveErrorStyle => 'Este dispositivo não pôde iniciar esse estilo. Tente outro.';

  @override
  String get wallpaperLiveErrorTimeout => 'Tempo limite esgotado. Verifique sua conexão e tente novamente.';

  @override
  String get wallpaperLiveErrorTooLarge => 'Esse arquivo é muito grande para um papel de parede animado.';

  @override
  String get wallpaperLiveErrorVideo =>
      'Esse vídeo não pode ser reproduzido como papel de parede. Experimente outro clipe.';

  @override
  String wallpaperLiveFps(int fps) {
    final intl.NumberFormat fpsNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String fpsString = fpsNumberFormat.format(fps);

    return '$fpsString quadros por segundo';
  }

  @override
  String wallpaperLiveGradientDescription(String style) {
    return 'Visualização do $style';
  }

  @override
  String wallpaperLiveGradientSwatch(String index, String count) {
    return 'Gradiente $index de $count';
  }

  @override
  String get wallpaperLiveKeepPrismOpen => 'Mantenha o Prism aberto e tente novamente.';

  @override
  String get wallpaperLiveModeGradients => 'Gradientes';

  @override
  String get wallpaperLiveModePhoto => 'Animar foto';

  @override
  String get wallpaperLiveModeVideo => 'Vídeo';

  @override
  String get wallpaperLiveNoVideo => 'Nenhum vídeo escolhido';

  @override
  String get wallpaperLivePreviewInstruction => 'O Android abre uma visualização. Toque em Definir papel de parede lá.';

  @override
  String get wallpaperLiveProStyleRequired => 'Este estilo faz parte do Prism Premium.';

  @override
  String get wallpaperLiveSetAction => 'Definir papel de parede animado';

  @override
  String get wallpaperLiveShaderUnsupported =>
      'Este dispositivo não pode executar papéis de parede animados de shader. Experimente o vídeo.';

  @override
  String get wallpaperLiveStyleAurora => 'aurora';

  @override
  String get wallpaperLiveStyleAuroraDescription => 'Faixas suaves de cor.';

  @override
  String get wallpaperLiveStyleBreathe => 'Respirar';

  @override
  String get wallpaperLiveStyleBreatheDescription => 'Um pulso suave, entrando e saindo.';

  @override
  String get wallpaperLiveStyleDrift => 'Deslizar';

  @override
  String get wallpaperLiveStyleDriftDescription => 'Movimento e zoom lentos. Acompanha os movimentos da tela inicial.';

  @override
  String get wallpaperLiveStyleMesh => 'Malha';

  @override
  String get wallpaperLiveStyleMeshDescription => 'Cor mesclada que muda lentamente.';

  @override
  String get wallpaperLiveStylePlasma => 'Plasma';

  @override
  String get wallpaperLiveStylePlasmaDescription => 'Cor suave e fluida.';

  @override
  String get wallpaperLiveStyleRipple => 'Ondulação';

  @override
  String get wallpaperLiveStyleRippleDescription => 'Anéis de água que se espalham com o seu toque.';

  @override
  String get wallpaperLiveStyleShimmer => 'Brilho';

  @override
  String get wallpaperLiveStyleShimmerDescription => 'Uma suave varredura de luz.';

  @override
  String get wallpaperLiveStyleDepth => '3D';

  @override
  String get wallpaperLiveStyleDepthDescription =>
      'A foto se move em profundidade quando você desliza entre as telas iniciais e inclina o celular.';

  @override
  String get wallpaperLiveStyleStarfield => 'Campo Estelar';

  @override
  String get wallpaperLiveStyleStarfieldDescription => 'Estrelas cintilantes em preto puro.';

  @override
  String wallpaperLiveStyleUnlocked(String style) {
    return '$style fica desbloqueado por 7 dias.';
  }

  @override
  String get wallpaperLiveStyleWaves => 'Ondas';

  @override
  String get wallpaperLiveStyleWavesDescription => 'Ondas em camadas que rolam.';

  @override
  String get wallpaperLiveTextureDownloadFailed =>
      'Não foi possível baixar o papel de parede. Verifique sua conexão e tente novamente.';

  @override
  String get wallpaperLiveTexturePrepareFailed => 'Não foi possível preparar o papel de parede.';

  @override
  String get wallpaperLiveTextureTooDetailed => 'Esse papel de parede é muito detalhado para ser animado.';

  @override
  String get wallpaperLiveTitle => 'Papéis de parede animados';

  @override
  String get wallpaperLiveUnavailableBody =>
      'É necessário um celular Android compatível com papéis de parede animados em OpenGL.';

  @override
  String get wallpaperLiveUnavailableTitle => 'Papéis de parede animados não estão disponíveis';

  @override
  String wallpaperLiveUnlockCoins(String coins) {
    return 'Desbloquear · $coins moedas';
  }

  @override
  String wallpaperLiveUnlockError(String style) {
    return 'Não foi possível desbloquear $style. Tente novamente.';
  }

  @override
  String wallpaperLiveUnlockStyleAction(String style, String coins) {
    return 'Desbloquear $style por 7 dias · $coins moedas';
  }

  @override
  String get wallpaperLiveUnlockStyleBody =>
      'Desbloqueie por 7 dias com moedas ou assine o Prism Premium para ter acesso a todos os estilos.';

  @override
  String wallpaperLiveUnlockStyleTitle(String style) {
    return '$style é um estilo pago';
  }

  @override
  String get wallpaperLiveUnsupported => 'Este dispositivo não pode mostrar papéis de parede animados.';

  @override
  String get wallpaperLiveVideoChosen => 'Vídeo escolhido';

  @override
  String get wallpaperLiveVideoDescription => 'Reproduz na tela inicial com o som desligado. Até 256 MB.';

  @override
  String get wallpaperLiveVideoReadFailed => 'Não foi possível ler esse vídeo. Escolha novamente.';

  @override
  String get wallpaperLiveVideoTooLarge => 'Esse vídeo tem mais de 256 MB. Escolha um clipe mais curto.';

  @override
  String get wallpaperLiveVideoUnsupported => 'Este dispositivo não pode reproduzir um vídeo como papel de parede.';

  @override
  String get wallpaperLoadingImage => 'Carregando imagem';

  @override
  String get wallpaperLoadingWallpaper => 'Carregando papel de parede';

  @override
  String get wallpaperLowResolutionScreen => 'Baixa resolução para sua tela';

  @override
  String get wallpaperMakeItLive => 'Animar papel de parede';

  @override
  String get wallpaperMatchSystemColour => 'Corresponder à cor do sistema';

  @override
  String get wallpaperMoreLikeThis => 'Mais como este';

  @override
  String get wallpaperNavCollections => 'Coleções';

  @override
  String get wallpaperNavHome => 'Início';

  @override
  String get wallpaperNavRewards => 'Recompensas';

  @override
  String get wallpaperNavSearch => 'Procurar';

  @override
  String get wallpaperNew => 'Novo';

  @override
  String get wallpaperNotNow => 'Agora não';

  @override
  String get wallpaperNotSelected => 'não selecionado';

  @override
  String get wallpaperNotificationPromptBody =>
      'Um papel de parede escolhido a dedo todas as manhãs, além de lembretes de sequências. Sem spam.';

  @override
  String get wallpaperNotificationPromptTitle => 'Receba o papel de parede do dia';

  @override
  String get wallpaperOffline => 'Off-line';

  @override
  String wallpaperOldVersionBody(String version) {
    return 'A versão $version não é mais suportada. Atualize o Prism para continuar usando-o.';
  }

  @override
  String get wallpaperOldVersionTitle => 'Hora de atualizar';

  @override
  String get wallpaperOnPrism => 'Papel de parede no Prism';

  @override
  String get wallpaperOpenError => 'Não foi possível carregar este papel de parede';

  @override
  String get wallpaperOpenFileError => 'Não foi possível abrir este papel de parede';

  @override
  String get wallpaperOpenNotifications => 'Abrir notificações';

  @override
  String get wallpaperOtherSource => 'Outro';

  @override
  String get wallpaperPastPicksEmpty => 'Nenhuma escolha anterior ainda';

  @override
  String get wallpaperPastPicksLoadError => 'Não foi possível carregar as escolhas anteriores';

  @override
  String get wallpaperPastPicksTitle => 'Escolhas anteriores';

  @override
  String get wallpaperPlacementDim => 'Escurecer';

  @override
  String get wallpaperPositionApproximate =>
      'A posição é aproximada. O app de tela inicial pode exibir o papel de parede de outra forma.';

  @override
  String get wallpaperPremium => 'Premium';

  @override
  String get wallpaperPremiumCollection => 'Coleção premium';

  @override
  String wallpaperPremiumCollectionNamed(String name) {
    return 'Coleção premium: $name';
  }

  @override
  String get wallpaperPreviewHome => 'Tela inicial';

  @override
  String get wallpaperPreviewIconClear => 'Transparente';

  @override
  String get wallpaperPreviewIconDark => 'Escuro';

  @override
  String get wallpaperPreviewIconDefault => 'Padrão';

  @override
  String get wallpaperPreviewIconStyle => 'Estilo dos ícones';

  @override
  String get wallpaperPreviewIconThemed => 'Temático';

  @override
  String get wallpaperPreviewIconTinted => 'Tonalizado';

  @override
  String get wallpaperPreviewLock => 'Tela de bloqueio';

  @override
  String get wallpaperPreviewOnScreen => 'Pré-visualizar na sua tela';

  @override
  String get wallpaperPreviewSetBoth => 'Definir nas duas telas';

  @override
  String get wallpaperPreviewSetHome => 'Definir na tela inicial';

  @override
  String get wallpaperPreviewSetLock => 'Definir na tela de bloqueio';

  @override
  String wallpaperPreviewUnlock24Hours(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'Desbloquear por 24 horas (-$costString)';
  }

  @override
  String wallpaperPreviewUnlockCost(int cost) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);

    return 'A prévia desta coleção premium por 24 horas custa $costString moedas.';
  }

  @override
  String wallpaperPreviewUnlockCostMissing(int cost, int missing) {
    final intl.NumberFormat costNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String costString = costNumberFormat.format(cost);
    final intl.NumberFormat missingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String missingString = missingNumberFormat.format(missing);

    return 'A prévia por 24 horas custa $costString moedas. Faltam $missingString.';
  }

  @override
  String wallpaperPreviewWatchAdUnlock(String adOption) {
    return '$adOption e desbloquear';
  }

  @override
  String get wallpaperProcessing => 'Processando papel de parede';

  @override
  String get wallpaperProfileOpenError => 'Não foi possível abrir o perfil';

  @override
  String get wallpaperQuickAddAction => 'Adicionar às configurações rápidas';

  @override
  String get wallpaperQuickFavouriteDescription =>
      'Aplica um papel de parede aleatório dos seus favoritos. Evita repetir o último. Adicione alguns aos favoritos primeiro.';

  @override
  String get wallpaperQuickFavouriteTitle => 'Bloco favorito aleatório';

  @override
  String get wallpaperQuickHowToTitle => 'Como adicionar um bloco';

  @override
  String get wallpaperQuickShuffleDescription =>
      'Toque no bloco para aplicar um papel de parede aleatório da categoria escolhida.';

  @override
  String get wallpaperQuickShuffleTitle => 'Alternar papéis de parede';

  @override
  String get wallpaperQuickStepEdit => 'Toque no lápis ou no ícone de edição.';

  @override
  String get wallpaperQuickStepFindPrism => 'Encontre os blocos do Prism e arraste-os para a área de blocos ativos.';

  @override
  String get wallpaperQuickStepShade => 'Deslize a tela de cima para baixo duas vezes para abrir as notificações.';

  @override
  String get wallpaperQuickTargetBoth => 'Ambos';

  @override
  String get wallpaperQuickTargetHome => 'Tela inicial';

  @override
  String get wallpaperQuickTargetLock => 'Tela de bloqueio';

  @override
  String get wallpaperQuickTileAddError =>
      'Não foi possível adicionar o bloco. Adicione-o manualmente na tela de edição de configurações rápidas.';

  @override
  String get wallpaperQuickTileAdded => 'Bloco adicionado às configurações rápidas.';

  @override
  String get wallpaperQuickTileAlreadyAdded => 'Este bloco já está nas configurações rápidas.';

  @override
  String get wallpaperQuickTileNotAdded => 'Bloco não adicionado. Você pode adicioná-lo a qualquer momento.';

  @override
  String get wallpaperQuickTileSaveError => 'Não foi possível salvar as configurações rápidas do bloco';

  @override
  String get wallpaperQuickTilesLoadError => 'Não foi possível carregar seus blocos rápidos';

  @override
  String get wallpaperQuickTilesTitle => 'Blocos rápidos';

  @override
  String get wallpaperQuickWotdDescription =>
      'Aplica o papel de parede do dia. Abra o Prism uma vez por dia para salvar a versão mais recente no dispositivo.';

  @override
  String get wallpaperQuickWotdTitle => 'Bloco do papel de parede do dia';

  @override
  String get wallpaperRefresh => 'Atualizar';

  @override
  String get wallpaperRemovedFromHistory => 'Removido do histórico';

  @override
  String get wallpaperReport => 'Denunciar';

  @override
  String get wallpaperReset => 'Reiniciar';

  @override
  String get wallpaperSave => 'Salvar';

  @override
  String get wallpaperSaveToPhotos => 'Salvar em fotos';

  @override
  String get wallpaperSavedOnDevice => 'Salvo neste dispositivo';

  @override
  String wallpaperSearchTag(String tag) {
    return 'Pesquisar $tag';
  }

  @override
  String get wallpaperSeePrismPro => 'Conheça o Prism Premium';

  @override
  String get wallpaperSelected => 'selecionado';

  @override
  String get wallpaperServerUnavailable => 'Não foi possível conectar aos servidores';

  @override
  String get wallpaperSessionEnded => 'Sua sessão terminou. Faça login novamente.';

  @override
  String get wallpaperSet => 'Definir';

  @override
  String get wallpaperSetAsWallpaper => 'Definir como papel de parede';

  @override
  String wallpaperSetCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Definido $countString vezes',
      one: 'Definido uma vez',
      zero: 'Definido $countString vezes',
    );
    return '$_temp0';
  }

  @override
  String get setScreenTargetHome => 'Tela inicial';

  @override
  String get setScreenTargetLock => 'Tela de bloqueio';

  @override
  String get setScreenTargetBoth => 'Ambas';

  @override
  String get setScreenTargetGroup => 'Onde definir';

  @override
  String get setScreenRemember => 'Lembrar esta escolha';

  @override
  String get setScreenRememberHint =>
      'Definir pula esta tela na próxima vez. Mantenha Definir pressionado para voltar.';

  @override
  String get setScreenAdjust => 'Ajustar';

  @override
  String get setScreenMore => 'Mais';

  @override
  String get setScreenPairLock => 'Usar outro papel de parede para a tela de bloqueio';

  @override
  String get setScreenOpenSystemEditor => 'Abrir editor do sistema';

  @override
  String get setScreenClose => 'Fechar';

  @override
  String get wallpaperShare => 'Compartilhar';

  @override
  String get wallpaperShareLink => 'Compartilhar link';

  @override
  String get wallpaperShortcutsChoosePrismData => 'Escolha o que o Prism envia';

  @override
  String get wallpaperShortcutsOpenAction => 'Abrir atalhos';

  @override
  String get wallpaperShortcutsOpenError => 'Não foi possível abrir os atalhos. Abra o aplicativo você mesmo.';

  @override
  String get wallpaperShortcutsSourceFavourite => 'Favorito aleatório';

  @override
  String get wallpaperShortcutsSourceWotd => 'Papel de parede do dia';

  @override
  String get wallpaperShortcutsSourceWotdDescription =>
      'A escolha de hoje do Prism. Baixe primeiro o original de hoje no Prism. Quando a escolha diária mudar, baixe o novo original antes de executar esta fonte.';

  @override
  String get wallpaperShortcutsTitle => 'Alterar automaticamente';

  @override
  String get wallpaperShowLessLikeThis => 'Mostrar menos assim';

  @override
  String get wallpaperShowPreviewControls => 'Mostrar controles';

  @override
  String get wallpaperSignIn => 'Entrar';

  @override
  String get wallpaperSignInForPremiumFilters => 'Faça login para usar filtros premium com moedas.';

  @override
  String get wallpaperSortDownloads => 'Classificar downloads';

  @override
  String get wallpaperStartupFailed => 'Não foi possível iniciar o Prism';

  @override
  String get wallpaperThemeDarkAccent => 'Cor de destaque escuro';

  @override
  String get wallpaperThemeDarkThemes => 'Temas escuros';

  @override
  String get wallpaperUseAsAppAccent => 'Usar como cor de destaque do app';

  @override
  String get wallpaperAppAccentUpdated => 'Cor de destaque do app atualizada';

  @override
  String get wallpaperThemeLightAccent => 'Cor de destaque clara';

  @override
  String get wallpaperThemeLightThemes => 'Temas claros';

  @override
  String get wallpaperThemeModeDark => 'Escuro';

  @override
  String get wallpaperThemeModeLight => 'Claro';

  @override
  String get wallpaperThemeModeSystem => 'Sistema (claro/escuro)';

  @override
  String get wallpaperThemePreference => 'Preferência de tema';

  @override
  String get wallpaperThemePreferenceDescription =>
      'Selecione seu modo de tema preferido. O modo do sistema alterna automaticamente entre claro e escuro dependendo do modo do seu dispositivo.';

  @override
  String get wallpaperThemeTitle => 'Temas';

  @override
  String get wallpaperTitle => 'Título';

  @override
  String get wallpaperTrendingEmptyTitle => 'Nada está em alta ainda';

  @override
  String get wallpaperTrendingLoadError => 'Não foi possível carregar os papéis de parede populares';

  @override
  String get wallpaperTryAgain => 'Tente novamente';

  @override
  String get wallpaperTurnOff => 'Desligar';

  @override
  String get wallpaperTurnOnNotifications => 'Ative as notificações';

  @override
  String get wallpaperUnavailable => 'Indisponível';

  @override
  String get wallpaperUnfavourite => 'Remover dos favoritos';

  @override
  String get wallpaperUnreadItems => 'Tem itens não lidos';

  @override
  String get wallpaperUpdatePrism => 'Atualizar o Prism';

  @override
  String get wallpaperUploadAction => 'Enviar';

  @override
  String get wallpaperUploadAddTag => 'Adicionar tag';

  @override
  String get wallpaperUploadAddTagHint => 'Adicione uma tag e toque em Concluído';

  @override
  String get wallpaperUploadAiSubtitle => 'Descreva uma cena e gere um papel de parede para telefone';

  @override
  String get wallpaperUploadApprovalInfo =>
      'Seu papel de parede aparece na comunidade após aprovação. Acompanhe-o em seus uploads.';

  @override
  String wallpaperUploadBatchPosition(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Papel de parede $positionString de $totalString';
  }

  @override
  String wallpaperUploadBatchSubmitted(String label, int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$label. $countString enviados.';
  }

  @override
  String wallpaperUploadBatchSummaryNotSent(String submitted, int notSent) {
    final intl.NumberFormat notSentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String notSentString = notSentNumberFormat.format(notSent);

    return '$submitted. $notSentString não enviados.';
  }

  @override
  String wallpaperUploadBatchSummarySubmitted(int submittedCount, int total) {
    final intl.NumberFormat submittedCountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String submittedCountString = submittedCountNumberFormat.format(submittedCount);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$submittedCountString de $totalString papéis de parede enviados';
  }

  @override
  String get wallpaperUploadBrightness => 'Brilho';

  @override
  String get wallpaperUploadCheckReviewStatus => 'Verifique o status da revisão';

  @override
  String get wallpaperUploadChooseAnotherImage => 'Escolha outra imagem';

  @override
  String get wallpaperUploadContinueDraft => 'Continue editando seu papel de parede salvo';

  @override
  String get wallpaperUploadContrast => 'Contraste';

  @override
  String get wallpaperUploadCreateTitle => 'Criar';

  @override
  String get wallpaperUploadDeleteConfirmTitle => 'Excluir este papel de parede?';

  @override
  String get wallpaperUploadDeleteError => 'Não foi possível excluir. Tente novamente.';

  @override
  String get wallpaperUploadDeletePermissionError =>
      'Não foi possível excluir. Entre na conta usada para enviar o papel de parede e tente novamente.';

  @override
  String get wallpaperUploadDeleteWallpaper => 'Excluir papel de parede';

  @override
  String get wallpaperUploadDeleted => 'Papel de parede excluído.';

  @override
  String get wallpaperUploadDetailsOptional => 'Detalhes (opcional)';

  @override
  String get wallpaperUploadDiscardBody =>
      'Os arquivos enviados serão removidos. A imagem selecionada permanecerá no seu dispositivo.';

  @override
  String get wallpaperUploadDiscardEditsBody => 'Suas alterações serão perdidas.';

  @override
  String get wallpaperUploadDiscardEditsTitle => 'Descartar suas edições?';

  @override
  String get wallpaperUploadDiscardError => 'Não foi possível descartar este envio. Tente novamente.';

  @override
  String get wallpaperUploadDiscardTitle => 'Descartar este envio?';

  @override
  String get wallpaperUploadDownloadError => 'Não foi possível fazer o download. Tente novamente.';

  @override
  String get wallpaperUploadDownloadStarting => 'Iniciando download';

  @override
  String get wallpaperUploadDraftSaveError => 'Não foi possível salvar este rascunho. Tente novamente.';

  @override
  String wallpaperUploadEditBatch(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Editar papel de parede $positionString de $totalString';
  }

  @override
  String get wallpaperUploadEditSaveError => 'Não foi possível salvar suas edições. Tente novamente.';

  @override
  String get wallpaperUploadFileSize => 'Tamanho';

  @override
  String get wallpaperUploadFilesCheckActive => 'Enviando o papel de parede e sua prévia';

  @override
  String get wallpaperUploadFilesCheckDone => 'Papel de parede e prévia enviados';

  @override
  String get wallpaperUploadFilesCheckPending => 'Envie o papel de parede e sua prévia';

  @override
  String get wallpaperUploadFilesRemoveError => 'Não foi possível remover os arquivos enviados. Tente novamente.';

  @override
  String get wallpaperUploadFlip => 'Virar';

  @override
  String wallpaperUploadFreeQuotaMessage(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Usuários do plano gratuito podem enviar $countString papéis de parede por semana.';
  }

  @override
  String get wallpaperUploadFromGallery => 'Da sua galeria';

  @override
  String get wallpaperUploadFullImageError => 'Não foi possível carregar a imagem completa.';

  @override
  String get wallpaperUploadInReview => 'Em revisão';

  @override
  String get wallpaperUploadKeepDraft => 'Manter rascunho';

  @override
  String get wallpaperUploadLeaveBody =>
      'Guarde seu rascunho para retomá-lo mais tarde ou descarte-o e remova os arquivos enviados.';

  @override
  String get wallpaperUploadLeaveTitle => 'Sair deste upload?';

  @override
  String wallpaperUploadMaxTagsReached(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Você adicionou $countString tags';
  }

  @override
  String get wallpaperUploadOriginalContentGuideline =>
      'Envie apenas papéis de parede originais e de alta qualidade. Não envie conteúdo de outros aplicativos.';

  @override
  String get wallpaperUploadPrepareCheckActive => 'Preparando sua imagem e uma visualização menor';

  @override
  String get wallpaperUploadPrepareCheckDone => 'A imagem e a visualização estão prontas';

  @override
  String get wallpaperUploadPrepareCheckPending => 'Prepare sua imagem e uma visualização menor';

  @override
  String get wallpaperUploadPrepareError =>
      'Não pudemos preparar esta imagem. Tente novamente ou escolha outra imagem.';

  @override
  String get wallpaperUploadQualityLandscape =>
      'Esta imagem é ampla. Os papéis de parede do telefone ficam melhores em retrato.';

  @override
  String wallpaperUploadQualityLowResolution(int width, int height, int recommendedShortSide) {
    final intl.NumberFormat widthNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String widthString = widthNumberFormat.format(width);
    final intl.NumberFormat recommendedShortSideNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String recommendedShortSideString = recommendedShortSideNumberFormat.format(recommendedShortSide);

    return 'Esta imagem tem $widthString × $height px e pode ficar pouco nítida no celular. O ideal é ter pelo menos $recommendedShortSideString px no lado menor.';
  }

  @override
  String get wallpaperUploadQuotaCleanupFailed =>
      'Você atingiu o limite de upload, mas não foi possível remover os arquivos enviados. Toque em Voltar para tentar removê-los novamente.';

  @override
  String get wallpaperUploadQuotaReached =>
      'Você atingiu o limite semanal de envio de papéis de parede do plano gratuito.';

  @override
  String wallpaperUploadQuotaRemaining(int remaining, int total) {
    final intl.NumberFormat remainingNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String remainingString = remainingNumberFormat.format(remaining);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Restam $remainingString de $totalString envios gratuitos nesta semana';
  }

  @override
  String get wallpaperUploadRejected => 'Reprovado';

  @override
  String get wallpaperUploadRejectedSectionError => 'Não foi possível carregar seus envios rejeitados.';

  @override
  String get wallpaperUploadRejectionFallback =>
      'Nenhum motivo específico foi informado. Confira os detalhes do papel de parede e envie-o novamente.';

  @override
  String get wallpaperUploadRejectionTitle => 'Por que foi rejeitado';

  @override
  String wallpaperUploadRemoveTag(String tag) {
    return 'Remover tag $tag';
  }

  @override
  String get wallpaperUploadResetAdjustments => 'Redefinir ajustes';

  @override
  String get wallpaperUploadResolution => 'Resolução';

  @override
  String get wallpaperUploadResumeDraft => 'Retomar envio salvo';

  @override
  String get wallpaperUploadRetrySubmit => 'Tentar enviar novamente';

  @override
  String get wallpaperUploadReviewCheckActive => 'Salvando seu envio para revisão';

  @override
  String get wallpaperUploadReviewCheckDone => 'Enviado para revisão';

  @override
  String get wallpaperUploadReviewCheckPending =>
      'Os moderadores analisam o papel de parede antes de ele aparecer no Prism';

  @override
  String get wallpaperUploadReviewEmptyBody => 'Os papéis de parede que você envia mostram seu status de revisão aqui.';

  @override
  String get wallpaperUploadReviewEmptyTitle => 'Nada aqui ainda';

  @override
  String get wallpaperUploadReviewLoadError => 'Não foi possível carregar seus uploads';

  @override
  String get wallpaperUploadReviewSectionError => 'Não foi possível carregar seus envios.';

  @override
  String get wallpaperUploadRotateLeft => 'Girar para a esquerda';

  @override
  String get wallpaperUploadRotateRight => 'Girar para a direita';

  @override
  String get wallpaperUploadSaturation => 'Saturação';

  @override
  String get wallpaperUploadSavedToPictures => 'Papel de parede salvo em Pictures/Prism';

  @override
  String get wallpaperUploadSkip => 'Ignorar este papel de parede';

  @override
  String get wallpaperUploadStagePrepareFailed => 'Não foi possível preparar a imagem';

  @override
  String get wallpaperUploadStagePreparing => 'Preparando papel de parede';

  @override
  String get wallpaperUploadStageQuotaReached => 'Limite de upload atingido';

  @override
  String get wallpaperUploadStageReady => 'Pronto para enviar';

  @override
  String get wallpaperUploadStageSubmissionFailed => 'O envio não terminou';

  @override
  String get wallpaperUploadStageSubmitting => 'Enviando papel de parede';

  @override
  String get wallpaperUploadStageUploadFailed => 'O envio não foi concluído';

  @override
  String get wallpaperUploadStageUploading => 'Enviando papel de parede';

  @override
  String get wallpaperUploadSubmissionUnconfirmed =>
      'Não foi possível confirmar o envio. Verifique o status da sua revisão antes de tentar novamente.';

  @override
  String get wallpaperUploadTags => 'Tags';

  @override
  String wallpaperUploadTagsHelp(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Adicione até $countString tags para ajudar as pessoas a encontrar seu papel de parede.';
  }

  @override
  String get wallpaperUploadTitle => 'Enviar papel de parede';

  @override
  String get wallpaperUploadTitleHint => 'Dê um nome ao seu papel de parede';

  @override
  String get wallpaperUploadViewWallpaper => 'Ver papel de parede';

  @override
  String get wallpaperUploadYourUploads => 'Seus envios';

  @override
  String get wallpaperUsePhoneAccent => 'Use a cor de destaque do seu telefone';

  @override
  String get wallpaperThemeMaterialYouNote => 'O Material You usa as cores do seu papel de parede.';

  @override
  String wallpaperViewCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString visualizações',
      one: '1 visualização',
      zero: '$countString visualizações',
    );
    return '$_temp0';
  }

  @override
  String get wallpaperViewCountUnavailable => 'Contagem de visualizações indisponível';

  @override
  String wallpaperWotdByPhotographer(String name) {
    return 'Papel de parede do dia, de $name';
  }

  @override
  String get economyAiPromptSceneAnime1 => 'um gato cochilando numa estação ensolarada';

  @override
  String get economyAiPromptSceneAnime2 => 'nuvens de verão gigantes sobre arrozais';

  @override
  String get economyAiPromptSceneAnime3 => 'uma barraca de lámen brilhando numa rua chuvosa';

  @override
  String get economyAiPromptSceneAnime4 => 'um portal torii numa colina sobre um mar de nuvens';

  @override
  String get economyAiPromptSceneAnime5 => 'fogos de artifício sobre um rio num festival';

  @override
  String get economyAiPromptSceneAnime6 => 'uma sala de aula calma com pétalas entrando';

  @override
  String get economyAiPromptSceneAnime7 => 'uma estrada à beira-mar com um ponto de ônibus';

  @override
  String get economyAiPromptSceneAnime8 => 'uma baleia do céu flutuando sobre uma vila';

  @override
  String get economyAiPromptSceneMinimal1 => 'um barquinho de papel sobre água pálida e parada';

  @override
  String get economyAiPromptSceneMinimal2 => 'um arco de luz sobre uma planície vazia';

  @override
  String get economyAiPromptSceneMinimal3 => 'uma árvore solitária numa suave encosta nevada';

  @override
  String get economyAiPromptSceneMinimal4 => 'dois círculos sobrepostos sobre granulação suave';

  @override
  String get economyAiPromptSceneMinimal5 => 'uma fina linha de horizonte entre mar e céu';

  @override
  String get economyAiPromptSceneMinimal6 => 'uma única pena caindo no espaço vazio';

  @override
  String get economyAiPromptSceneMinimal7 => 'seixos lisos empilhados sobre fundo claro';

  @override
  String get economyAiPromptSceneMinimal8 => 'uma sombra em meia-lua numa parede de gesso';

  @override
  String get economyAiPromptSceneCyberpunk1 => 'um bar de macarrão sob chuva e luzes de neon';

  @override
  String get economyAiPromptSceneCyberpunk2 => 'um trem flutuante entre megatorres';

  @override
  String get economyAiPromptSceneCyberpunk3 => 'um androide solitário num telhado sob a chuva';

  @override
  String get economyAiPromptSceneCyberpunk4 => 'uma estrada de dados rumo a uma cidade imensa';

  @override
  String get economyAiPromptSceneCyberpunk5 => 'um mercado noturno sob um emaranhado de cabos';

  @override
  String get economyAiPromptSceneCyberpunk6 => 'uma moto cromada estacionada num beco neon';

  @override
  String get economyAiPromptSceneCyberpunk7 => 'uma lua holográfica sobre torres da cidade';

  @override
  String get economyAiPromptSceneCyberpunk8 => 'uma rua alagada refletindo um muro de telas';

  @override
  String get economyAiPromptSceneWatercolor1 => 'um campo de lavanda entre a névoa da manhã';

  @override
  String get economyAiPromptSceneWatercolor2 => 'uma vila de pescadores junto a um porto calmo';

  @override
  String get economyAiPromptSceneWatercolor3 => 'papoulas silvestres ao lado de uma estrada rural';

  @override
  String get economyAiPromptSceneWatercolor4 => 'um balão de ar quente sobre colinas verdes';

  @override
  String get economyAiPromptSceneWatercolor5 => 'uma garça num lago cheio de juncos';

  @override
  String get economyAiPromptSceneWatercolor6 => 'uma rua chuvosa com postes desfocados';

  @override
  String get economyAiPromptSceneWatercolor7 => 'uma xícara fumegante ao lado de uma janela aberta';

  @override
  String get economyAiPromptSceneWatercolor8 => 'pinheiros nevados junto a um riacho gelado';

  @override
  String get economyAiPromptSceneMeshGradient1 => 'manchas de cor suaves se fundindo umas nas outras';

  @override
  String get economyAiPromptSceneMeshGradient2 => 'uma onda de gradiente sedoso se dobrando';

  @override
  String get economyAiPromptSceneMeshGradient3 => 'orbes brilhantes sobre um fundo aveludado';

  @override
  String get economyAiPromptSceneMeshGradient4 => 'um gradiente tipo aurora subindo em varredura';

  @override
  String get economyAiPromptSceneMeshGradient5 => 'poças de cor líquida com granulação fina';

  @override
  String get economyAiPromptSceneMeshGradient6 => 'um gradiente de quente a frio com ruído suave';

  @override
  String get economyAiPromptSceneMeshGradient7 => 'pétalas translúcidas de gradiente sobrepostas';

  @override
  String get economyAiPromptSceneMeshGradient8 => 'um pôr do sol desfocado de faixas de cor fluida';

  @override
  String get economyAiPromptSceneAbstract1 => 'cacos de vidro entrelaçados captando a luz';

  @override
  String get economyAiPromptSceneAbstract2 => 'nuvens de tinta fluindo suspensas na água';

  @override
  String get economyAiPromptSceneAbstract3 => 'uma espiral de fitas dobradas em movimento';

  @override
  String get economyAiPromptSceneAbstract4 => 'mármore estilhaçado com veios dourados';

  @override
  String get economyAiPromptSceneAbstract5 => 'curvas de nível ondulantes em camadas';

  @override
  String get economyAiPromptSceneAbstract6 => 'esferas flutuantes projetando longas sombras';

  @override
  String get economyAiPromptSceneAbstract7 => 'rastros de fumaça se enroscando num vórtice';

  @override
  String get economyAiPromptSceneAbstract8 => 'um campo de cubos suaves subindo em ondas';

  @override
  String get economyAiPromptSceneNature1 => 'uma cachoeira caindo num desfiladeiro de musgo';

  @override
  String get economyAiPromptSceneNature2 => 'um campo de girassóis sob um céu imenso';

  @override
  String get economyAiPromptSceneNature3 => 'um lago congelado com rachaduras de gelo azul';

  @override
  String get economyAiPromptSceneNature4 => 'cerejeiras ao longo de um caminho junto ao rio';

  @override
  String get economyAiPromptSceneNature5 => 'uma lagoa tropical vista de cima';

  @override
  String get economyAiPromptSceneNature6 => 'bordos de outono refletidos num lago parado';

  @override
  String get economyAiPromptSceneNature7 => 'uma raposa solitária na neve fresca ao amanhecer';

  @override
  String get economyAiPromptSceneNature8 => 'nuvens de tempestade sobre verdes planaltos';

  @override
  String get economyAiPromptSceneSpace1 => 'um planeta com anéis sobre o horizonte lunar';

  @override
  String get economyAiPromptSceneSpace2 => 'uma galáxia espiral brilhando no espaço profundo';

  @override
  String get economyAiPromptSceneSpace3 => 'um astronauta flutuando sobre um planeta azul';

  @override
  String get economyAiPromptSceneSpace4 => 'uma nebulosa em forma de flor desabrochando';

  @override
  String get economyAiPromptSceneSpace5 => 'dois sóis se pondo sobre um deserto alienígena';

  @override
  String get economyAiPromptSceneSpace6 => 'uma estação espacial orbitando um gigante gasoso';

  @override
  String get economyAiPromptSceneSpace7 => 'uma chuva de meteoros sobre um observatório';

  @override
  String get economyAiPromptSceneSpace8 => 'um eclipse com um brilhante anel de diamante';

  @override
  String get economyAiPromptSceneSynthwave1 => 'uma estrada de grade neon rumo ao pôr do sol';

  @override
  String get economyAiPromptSceneSynthwave2 => 'uma costa de palmeiras sob um sol listrado';

  @override
  String get economyAiPromptSceneSynthwave3 => 'um carro esportivo retrô numa estrada sem fim';

  @override
  String get economyAiPromptSceneSynthwave4 => 'montanhas de arame sob um céu magenta';

  @override
  String get economyAiPromptSceneSynthwave5 => 'um sol cromado afundando num mar brilhante';

  @override
  String get economyAiPromptSceneSynthwave6 => 'um fliperama retrô brilhando numa noite chuvosa';

  @override
  String get economyAiPromptSceneSynthwave7 => 'uma fita cassete flutuando num espaço neon';

  @override
  String get economyAiPromptSceneSynthwave8 => 'uma palmeira solitária num horizonte laser';

  @override
  String get economyAiPromptScenePixelArt1 => 'uma cabana aconchegante na floresta nevada';

  @override
  String get economyAiPromptScenePixelArt2 => 'um castelo num penhasco sobre o mar';

  @override
  String get economyAiPromptScenePixelArt3 => 'uma cidadezinha com janelas acesas';

  @override
  String get economyAiPromptScenePixelArt4 => 'uma nave sobre um mundo alienígena roxo';

  @override
  String get economyAiPromptScenePixelArt5 => 'uma cachoeira num vale de selva exuberante';

  @override
  String get economyAiPromptScenePixelArt6 => 'um píer de pesca sob a lua cheia';

  @override
  String get economyAiPromptScenePixelArt7 => 'um templo com cerejeiras em flor na primavera';

  @override
  String get economyAiPromptScenePixelArt8 => 'um trem cruzando uma ponte ao pôr do sol';

  @override
  String get economyAiPromptSceneRender3d1 => 'formas de argila brilhante em equilíbrio';

  @override
  String get economyAiPromptSceneRender3d2 => 'fitas de vidro fosco sobre um palco pastel';

  @override
  String get economyAiPromptSceneRender3d3 => 'uma ilhazinha flutuando sobre uma nuvem macia';

  @override
  String get economyAiPromptSceneRender3d4 => 'bolhas de cromo infladas sob luz suave';

  @override
  String get economyAiPromptSceneRender3d5 => 'um deserto em miniatura com um cacto solitário';

  @override
  String get economyAiPromptSceneRender3d6 => 'um diorama de sala aconchegante dentro de um cubo';

  @override
  String get economyAiPromptSceneRender3d7 => 'arcos de mármore flutuando sobre água parada';

  @override
  String get economyAiPromptSceneRender3d8 => 'ondas cor de bala congeladas em movimento';

  @override
  String get economyAiPromptSceneOilPainting1 => 'um mar tempestuoso batendo contra a costa rochosa';

  @override
  String get economyAiPromptSceneOilPainting2 => 'um campo de papoulas ao sol com uma fazenda';

  @override
  String get economyAiPromptSceneOilPainting3 => 'uma natureza-morta de limões e um vaso azul';

  @override
  String get economyAiPromptSceneOilPainting4 => 'um porto enevoado ao amanhecer com barcos antigos';

  @override
  String get economyAiPromptSceneOilPainting5 => 'um caminho na floresta em chamas de cores outonais';

  @override
  String get economyAiPromptSceneOilPainting6 => 'um canal ao luar com casas antigas';

  @override
  String get economyAiPromptSceneOilPainting7 => 'um campo de trigo ondulando antes da tempestade';

  @override
  String get economyAiPromptSceneOilPainting8 => 'uma rosa num copo sobre uma mesa escura';

  @override
  String get economyAiPromptSceneUkiyoE1 => 'uma grande onda se curvando sob uma lua pálida';

  @override
  String get economyAiPromptSceneUkiyoE2 => 'um pagode coberto de neve ao anoitecer';

  @override
  String get economyAiPromptSceneUkiyoE3 => 'garças voando sobre uma montanha nebulosa';

  @override
  String get economyAiPromptSceneUkiyoE4 => 'uma ponte de madeira sob pétalas de cerejeira';

  @override
  String get economyAiPromptSceneUkiyoE5 => 'barcos de pesca num mar índigo agitado';

  @override
  String get economyAiPromptSceneUkiyoE6 => 'um sol vermelho sobre um pico vulcânico';

  @override
  String get economyAiPromptSceneUkiyoE7 => 'um lago de carpas sob salgueiros-chorões';

  @override
  String get economyAiPromptSceneUkiyoE8 => 'chuva caindo sobre uma vila junto ao rio';

  @override
  String get economyAiPromptLightingMorningHaze => 'névoa matinal suave';

  @override
  String get economyAiPromptLightingGoldenHour => 'hora dourada suave';

  @override
  String get economyAiPromptLightingMoonlight => 'luz fria do luar';

  @override
  String get economyAiPromptLightingNeonRim => 'contraluz neon';

  @override
  String get economyAiPromptLightingBacklight => 'contraluz quente';

  @override
  String get economyAiPromptLightingGodRays => 'suaves raios de luz';

  @override
  String get economyAiPromptLightingStudio => 'luz de estúdio';

  @override
  String get economyAiPromptLightingTwilight => 'crepúsculo azul';

  @override
  String get economyAiPromptPaletteTealAmber => 'verde-azulado e âmbar';

  @override
  String get economyAiPromptPaletteIndigoRose => 'tons de índigo e rosa';

  @override
  String get economyAiPromptPaletteSageCream => 'verde-sálvia e creme';

  @override
  String get economyAiPromptPaletteBlackNeonPink => 'preto com rosa neon';

  @override
  String get economyAiPromptPalettePastelPeach => 'pêssego pastel suave';

  @override
  String get economyAiPromptPaletteEmeraldGold => 'esmeralda e dourado';

  @override
  String get economyAiPromptPaletteOceanBlue => 'tons de azul-oceano';

  @override
  String get economyAiPromptPaletteCrimsonCharcoal => 'carmim e grafite';

  @override
  String get economyAiPromptSuffix => 'papel de parede vertical para celular, sem texto';

  @override
  String economyAiPromptComposition(String scene, String lighting, String palette, String suffix) {
    return '$scene, $lighting, $palette. $suffix';
  }

  @override
  String economyAiPromptSceneOnly(String scene, String suffix) {
    return '$scene, $suffix';
  }

  @override
  String get economyAiMadeWithPrism => 'Feito com Prism AI';

  @override
  String get onboardingAiPromptFallback => 'um papel de parede incrível';

  @override
  String get onboardingAiPromptNature1 => 'um lago glacial ao amanhecer, água como espelho e picos rosados';

  @override
  String get onboardingAiPromptNature2 => 'um riacho de floresta musgosa com luz suave entre samambaias altas';

  @override
  String get onboardingAiPromptNature3 => 'um campo de flores silvestres sob um vasto céu de fim de tarde';

  @override
  String get onboardingAiPromptNature4 => 'uma praia de areia negra com ondas turquesa e rochedos ao anoitecer';

  @override
  String get onboardingAiPromptNature5 => 'auroras boreais sobre um pinheiral nevado junto a um lago gelado';

  @override
  String get onboardingAiPromptAbstract1 => 'fitas de vidro translúcido girando em luz suave com bordas iridescentes';

  @override
  String get onboardingAiPromptAbstract2 => 'nuvens de tinta na água em azul profundo e dourado, detalhes suaves';

  @override
  String get onboardingAiPromptAbstract3 => 'ondas de camadas de papel em tons quentes de pôr do sol, sombras suaves';

  @override
  String get onboardingAiPromptAbstract4 => 'um redemoinho de mármore esculpido com veios dourados sobre fundo grafite';

  @override
  String get onboardingAiPromptAbstract5 => 'esferas cromadas flutuando e refletindo um céu pastel em calma';

  @override
  String get onboardingAiPromptWatercolor1 => 'uma vila litorânea em aquarela com casas pastel e barcos ao amanhecer';

  @override
  String get onboardingAiPromptWatercolor2 =>
      'flores silvestres soltas em aquarela, rosa e sálvia, sobre papel texturizado';

  @override
  String get onboardingAiPromptWatercolor3 =>
      'um lago enevoado em aquarela com um deque de madeira e colinas distantes';

  @override
  String get onboardingAiPromptWatercolor4 => 'um céu noturno em aquarela com nuvens violeta e uma lua brilhante';

  @override
  String get onboardingAiPromptWatercolor5 =>
      'uma floresta de outono em aquarela com lavagens quentes de laranja e dourado';

  @override
  String get onboardingAiPromptMinimal1 => 'um sol se pondo sobre um mar calmo, cores chapadas e céu amplo e vazio';

  @override
  String get onboardingAiPromptMinimal2 => 'colinas suaves em camadas, tons de areia opacos e céu em degradê pálido';

  @override
  String get onboardingAiPromptMinimal3 => 'uma árvore sem folhas numa colina nevada com muito espaço vazio e calmo';

  @override
  String get onboardingAiPromptMinimal4 =>
      'um veleiro solitário num lago parado ao amanhecer, formas simples e tons suaves';

  @override
  String get onboardingAiPromptMinimal5 => 'arcos concêntricos suaves em terracota e creme com granulação fina';

  @override
  String get onboardingAiPromptAnime1 => 'um céu de verão estilo anime com nuvens enormes sobre uma ferrovia litorânea';

  @override
  String get onboardingAiPromptAnime2 => 'uma cidade noturna de anime vista de uma colina, luzes quentes e estrelas';

  @override
  String get onboardingAiPromptAnime3 => 'um santuário de floresta de anime com espíritos brilhando em luz verde suave';

  @override
  String get onboardingAiPromptAnime4 => 'uma rua de anime chuvosa ao anoitecer, luzes de lojas e reflexos em poças';

  @override
  String get onboardingAiPromptAnime5 => 'um campo de anime na hora dourada com o vento na grama alta';

  @override
  String get onboardingAiPromptMeshGradient1 =>
      'um gradiente em malha suave de tangerina, rosa e violeta com granulação fina';

  @override
  String get onboardingAiPromptMeshGradient2 =>
      'um gradiente em malha profundo de azul-marinho e verde-azulado com toque lima';

  @override
  String get onboardingAiPromptMeshGradient3 => 'um gradiente em malha suave de azul-céu, lavanda e creme quente';

  @override
  String get onboardingAiPromptMeshGradient4 => 'um gradiente em malha intenso de carmim e ouro, fluindo como seda';

  @override
  String get onboardingAiPromptMeshGradient5 => 'um gradiente em malha sereno de sálvia, menta e areia clara';

  @override
  String get onboardingAiPromptCyberpunk1 => 'uma rua cyberpunk à noite na chuva, com reflexos de neon e vapor';

  @override
  String get onboardingAiPromptCyberpunk2 => 'uma cidade neon vista de um terraço, com carros voadores cruzando';

  @override
  String get onboardingAiPromptCyberpunk3 => 'um canal cyberpunk tranquilo com lojas luminosas e lanternas flutuantes';

  @override
  String get onboardingAiPromptCyberpunk4 =>
      'um skyline cyberpunk ao amanhecer, torres de vidro e névoa rosa e turquesa';

  @override
  String get onboardingAiPromptCyberpunk5 => 'uma moto solitária numa ponte neon sobre uma cidade futurista enevoada';

  @override
  String get onboardingAiPromptSpace1 => 'um gigante gasoso com anéis sobre uma lua rochosa e céu cheio de estrelas';

  @override
  String get onboardingAiPromptSpace2 => 'uma nebulosa colorida em violeta e turquesa com jovens estrelas brilhantes';

  @override
  String get onboardingAiPromptSpace3 => 'uma galáxia espiral de frente, com núcleo brilhante e braços azuis de poeira';

  @override
  String get onboardingAiPromptSpace4 => 'um astronauta à deriva sobre a Terra ao nascer do sol, fina atmosfera azul';

  @override
  String get onboardingAiPromptSpace5 => 'um eclipse solar total sobre uma cordilheira silenciosa';

  @override
  String get onboardingAiPromptSynthwave1 => 'um pôr do sol synthwave com sol listrado sobre uma grade neon brilhante';

  @override
  String get onboardingAiPromptSynthwave2 => 'um carro retrô rumo a um sol magenta numa estrada costeira vazia';

  @override
  String get onboardingAiPromptSynthwave3 => 'montanhas de arame sob um céu roxo estrelado e um sol cromado';

  @override
  String get onboardingAiPromptSynthwave4 =>
      'uma praia synthwave com silhuetas de palmeiras e horizonte rosa brilhante';

  @override
  String get onboardingAiPromptSynthwave5 => 'um skyline retrô à noite em névoa de neon rosa e ciano';

  @override
  String get onboardingAiPromptPixelArt1 => 'uma cabana em pixel art numa floresta nevada, janelas quentes à noite';

  @override
  String get onboardingAiPromptPixelArt2 => 'uma cidade litorânea em pixel art ao pôr do sol com barcos no porto';

  @override
  String get onboardingAiPromptPixelArt3 => 'um castelo em pixel art numa ilha flutuante acima das nuvens';

  @override
  String get onboardingAiPromptPixelArt4 => 'um céu noturno em pixel art sobre um lago calmo com vaga-lumes';

  @override
  String get onboardingAiPromptPixelArt5 => 'um caminho de cerejeiras em flor em pixel art até um pequeno templo';

  @override
  String get onboardingAiPromptRender3d1 => 'um render 3D de formas de argila macias em pastéis com sombras suaves';

  @override
  String get onboardingAiPromptRender3d2 => 'um render 3D de uma ilha flutuante com cachoeira e árvores';

  @override
  String get onboardingAiPromptRender3d3 => 'um render 3D de ondas de vidro azul e violeta sob luz de estúdio';

  @override
  String get onboardingAiPromptRender3d4 => 'um render 3D de um quarto em miniatura dentro de um cubo brilhante';

  @override
  String get onboardingAiPromptRender3d5 => 'um render 3D de bolhas cromadas flutuando sobre um mar rosa calmo';

  @override
  String get onboardingAiPromptOilPainting1 =>
      'uma pintura a óleo de um mar tempestuoso com um barco sob um céu dramático';

  @override
  String get onboardingAiPromptOilPainting2 =>
      'uma pintura a óleo de um campo de papoulas ao sol com uma fazenda distante';

  @override
  String get onboardingAiPromptOilPainting3 =>
      'uma pintura a óleo de um porto enevoado ao amanhecer com barcos antigos';

  @override
  String get onboardingAiPromptOilPainting4 =>
      'uma pintura a óleo de um caminho outonal com pinceladas grossas e ricas';

  @override
  String get onboardingAiPromptOilPainting5 => 'uma pintura a óleo de uma cidade com canal ao luar e janelas quentes';

  @override
  String get onboardingAiPromptUkiyoE1 => 'uma grande onda ukiyo-e sob uma lua pálida e uma montanha nevada distante';

  @override
  String get onboardingAiPromptUkiyoE2 => 'uma vila nevada ukiyo-e à noite com lanternas de papel acesas';

  @override
  String get onboardingAiPromptUkiyoE3 => 'uma cena ukiyo-e de garças voando sobre montanhas nebulosas ao amanhecer';

  @override
  String get onboardingAiPromptUkiyoE4 => 'uma ponte de madeira ukiyo-e sob cerejeiras em flor num dia de primavera';

  @override
  String get onboardingAiPromptUkiyoE5 => 'um sol vermelho ukiyo-e sobre um mar índigo calmo com pequenos barcos';

  @override
  String wallpaperWotdByline(String name) {
    return 'por $name';
  }

  @override
  String get wallpaperWotdPastPicks => 'Escolhas anteriores';

  @override
  String wallpaperWotdPickedOn(String wallpaper, String date) {
    return '$wallpaper, escolhido em $date';
  }

  @override
  String get wallpaperWotdSeePast => 'Ver papéis de parede do dia anteriores';

  @override
  String get wallpaperWotdTitle => 'Papel de parede do dia';

  @override
  String get wallpaperYourProfile => 'Seu perfil';

  @override
  String get widgetsSettingsTitle => 'Widgets';

  @override
  String get widgetsSettingsSubtitle => 'Adicione o Prism à Tela de Início e à Tela Bloqueada';

  @override
  String get widgetsGuideTitle => 'Adicionar widgets do Prism';

  @override
  String get widgetsGuideHomeTab => 'Tela de Início';

  @override
  String get widgetsGuideLockTab => 'Tela Bloqueada';

  @override
  String get widgetsGuideHomeStep1 =>
      'Toque e mantenha pressionada uma área vazia da Tela de Início até os apps tremerem.';

  @override
  String get widgetsGuideHomeStep2 => 'Toque em Editar e depois em Adicionar Widget.';

  @override
  String get widgetsGuideHomeStep3 => 'Busque por Prism, escolha um tamanho e toque em Adicionar Widget.';

  @override
  String get widgetsGuideLockStep1 => 'Toque e mantenha pressionada a Tela Bloqueada e toque em Personalizar.';

  @override
  String get widgetsGuideLockStep2 => 'Toque em Tela Bloqueada e depois na área de widgets abaixo do relógio.';

  @override
  String get widgetsGuideLockStep3 => 'Escolha Prism e toque em um widget para adicioná-lo.';

  @override
  String get widgetsGuideHomeIllustration => 'Um celular com o widget Papel de parede do dia na Tela de Início';

  @override
  String get widgetsGuideLockIllustration => 'Um celular com widgets do Prism na Tela Bloqueada';

  @override
  String get widgetsGuideDone => 'OK';

  @override
  String get widgetsCardTitle => 'O papel de parede do dia na sua Tela de Início';

  @override
  String get widgetsCardBody => 'Adicione o widget e veja um papel de parede novo todo dia.';

  @override
  String get widgetsCardAction => 'Mostrar como';

  @override
  String get widgetsCardDismiss => 'Dispensar';

  @override
  String get foldersTitle => 'Pastas';

  @override
  String get foldersSaveToFolder => 'Salvar na pasta';

  @override
  String get foldersAddToFolder => 'Adicionar à pasta';

  @override
  String get foldersNewFolder => 'Nova pasta';

  @override
  String get foldersNameHint => 'Nome da pasta';

  @override
  String get foldersCreate => 'Criar';

  @override
  String get foldersCreateFolder => 'Criar pasta';

  @override
  String get foldersSuggested => 'Sugerida';

  @override
  String get foldersNewTag => 'Nova';

  @override
  String foldersItemCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString papéis de parede',
      one: '1 papel de parede',
      zero: 'Nenhum papel de parede',
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
      other: 'Salvo em $countString pastas.',
      one: 'Salvo em 1 pasta.',
    );
    return '$_temp0';
  }

  @override
  String get foldersUpdated => 'Pastas atualizadas.';

  @override
  String get foldersSaveFailed => 'Não foi possível salvar nas pastas. Tente novamente.';

  @override
  String get foldersUpdateFailed => 'Não foi possível atualizar a pasta. Tente novamente.';

  @override
  String get foldersRename => 'Renomear';

  @override
  String get foldersRenameTitle => 'Renomear pasta';

  @override
  String get foldersDelete => 'Excluir';

  @override
  String foldersDeleteTitle(String name) {
    return 'Excluir $name?';
  }

  @override
  String get foldersDeleteMessage => 'Os papéis de parede continuam nos seus favoritos.';

  @override
  String get foldersDeleteConfirm => 'Excluir pasta';

  @override
  String get foldersDeleted => 'Pasta excluída.';

  @override
  String get foldersRemoveTitle => 'Remover desta pasta?';

  @override
  String get foldersRemoveMessage => 'Continua nos seus favoritos.';

  @override
  String get foldersRemoveConfirm => 'Remover';

  @override
  String get foldersRemoved => 'Removido da pasta.';

  @override
  String get foldersEmptyTitle => 'Esta pasta está vazia';

  @override
  String get foldersEmptyBody => 'Segure o coração em um papel de parede para salvá-lo aqui.';

  @override
  String get foldersLoadError => 'Não foi possível carregar esta pasta.';

  @override
  String get foldersNotFoundTitle => 'Esta pasta não está disponível';

  @override
  String get foldersNotFoundBody => 'Talvez ela tenha sido excluída.';

  @override
  String get foldersSignInFeature => 'pastas';

  @override
  String get foldersMoreOptions => 'Mais opções';

  @override
  String get foldersSuggestionLockScreen => 'Tela de bloqueio';

  @override
  String get foldersSuggestionHomeScreen => 'Tela inicial';

  @override
  String get moodDreamyTitle => 'Sonhador';

  @override
  String get moodDreamyBody => 'Céus suaves e luz pastel.';

  @override
  String get moodDarkQuietTitle => 'Escuro e tranquilo';

  @override
  String get moodDarkQuietBody => 'Pouca luz, fácil para os olhos.';

  @override
  String get moodBrightBoldTitle => 'Vibrante e marcante';

  @override
  String get moodBrightBoldBody => 'Muita cor para acordar sua tela.';

  @override
  String get moodMinimalTitle => 'Minimalista';

  @override
  String get moodMinimalBody => 'Formas simples e espaço para respirar.';

  @override
  String get moodSpatialReadyTitle => 'Pronto para cena espacial';

  @override
  String get moodSpatialReadyBody => 'Feito para se destacar como cena espacial.';

  @override
  String get moodDepthReadyTitle => 'Pronto para efeito de profundidade';

  @override
  String get moodDepthReadyBody => 'O sujeito fica na frente do seu relógio.';

  @override
  String get moodChipRowLabel => 'Humores';

  @override
  String get moodSeeAll => 'Ver tudo';

  @override
  String moodSeeAllHint(String mood) {
    return 'Abre todos os papéis de parede de $mood';
  }

  @override
  String get moodLoadError => 'Não foi possível carregar estes papéis de parede';

  @override
  String get moodEmptyTitle => 'Ainda não há papéis de parede aqui';

  @override
  String get moodEmptyBody => 'Novos papéis de parede chegam todos os dias.';

  @override
  String wallpaperHistoryTileSemantic(String current, String target, String date) {
    return '${current}Defina novamente. $target, $date';
  }

  @override
  String get wallpaperHistoryTitle => 'Histórico do papel de parede';

  @override
  String get wallpaperLibraryHistoryBody =>
      'Os papéis de parede que você definir aparecerão aqui para que possa defini-los novamente.';

  @override
  String get wallpaperLibraryHistoryTitle => 'Histórico do papel de parede';

  @override
  String get wallpaperLibraryOpenHistory => 'Abrir histórico';

  @override
  String get wallpaperRecentlySet => 'Definido recentemente';

  @override
  String get wallpaperSetAgain => 'Defina este papel de parede novamente';

  @override
  String get wallpaperSort => 'Organizar';

  @override
  String get tasteQuizTitle => 'Escolha a que você mais gosta';

  @override
  String get tasteQuizWildCard => 'Coringa';

  @override
  String tasteQuizProgress(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$currentString de $totalString';
  }

  @override
  String tasteQuizProgressLabel(int current, int total) {
    final intl.NumberFormat currentNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String currentString = currentNumberFormat.format(current);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Rodada $currentString de $totalString';
  }

  @override
  String get tasteQuizSkip => 'Pular';

  @override
  String tasteQuizPickLabel(int position, int total) {
    final intl.NumberFormat positionNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String positionString = positionNumberFormat.format(position);
    final intl.NumberFormat totalNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'Escolher este papel de parede, $positionString de $totalString';
  }

  @override
  String get tasteQuizTuningTitle => 'Ajustando seu feed';

  @override
  String tasteQuizSummaryFull(String tone, String density, String tag) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Escuro', 'other': 'Claro'});
    String _temp1 = intl.Intl.selectLogic(density, {'minimal': 'minimalista', 'other': 'detalhado'});
    return '$_temp0, $_temp1, um toque de $tag';
  }

  @override
  String tasteQuizSummaryToneDensity(String tone, String density) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Escuro', 'other': 'Claro'});
    String _temp1 = intl.Intl.selectLogic(density, {'minimal': 'minimalista', 'other': 'detalhado'});
    return '$_temp0 e $_temp1';
  }

  @override
  String tasteQuizSummaryToneTag(String tone, String tag) {
    String _temp0 = intl.Intl.selectLogic(tone, {'dark': 'Escuro', 'other': 'Claro'});
    return '$_temp0, com um toque de $tag';
  }

  @override
  String tasteQuizSummaryDensityTag(String density, String tag) {
    String _temp0 = intl.Intl.selectLogic(density, {'minimal': 'Minimalista', 'other': 'Detalhado'});
    return '$_temp0, com um toque de $tag';
  }

  @override
  String tasteQuizSummaryTone(String tone) {
    String _temp0 = intl.Intl.selectLogic(tone, {
      'dark': 'Papéis de parede mais escuros',
      'other': 'Papéis de parede mais claros',
    });
    return '$_temp0';
  }

  @override
  String tasteQuizSummaryDensity(String density) {
    String _temp0 = intl.Intl.selectLogic(density, {
      'minimal': 'Papéis de parede mais minimalistas',
      'other': 'Papéis de parede mais detalhados',
    });
    return '$_temp0';
  }

  @override
  String tasteQuizSummaryTag(String tag) {
    return 'Mais papéis de parede de $tag';
  }

  @override
  String get tasteQuizSummaryReady => 'Seu feed está pronto';

  @override
  String get tasteQuizRetake => 'Refazer Isso ou aquilo';

  @override
  String get tasteQuizRetakeFailed =>
      'Não foi possível carregar os papéis de parede. Verifique sua conexão e tente novamente.';

  @override
  String get foldersPublic => 'Pública';

  @override
  String get foldersMakePublic => 'Tornar pública';

  @override
  String get foldersMakePrivate => 'Tornar privada';

  @override
  String get foldersMakePublicTitle => 'Tornar esta pasta pública?';

  @override
  String get foldersMakePublicMessage =>
      'Qualquer pessoa no Prism poderá ver o nome e os papéis de parede, seguir a pasta e abrir o link dela. Os links que você compartilhar mantêm a prévia mesmo se você tornar a pasta privada depois.';

  @override
  String get foldersMakePrivateTitle => 'Tornar esta pasta privada?';

  @override
  String get foldersMakePrivateMessage =>
      'Só você vai vê-la. O link deixa de funcionar e os seguidores perdem o acesso.';

  @override
  String get foldersMadePublic => 'Esta pasta agora é pública.';

  @override
  String get foldersMadePrivate => 'Esta pasta agora é privada.';

  @override
  String get foldersPublicNameRefused => 'Renomeie esta pasta para torná-la pública.';

  @override
  String get foldersHiddenRefused => 'Esta pasta foi ocultada após denúncias, por isso não pode ser pública.';

  @override
  String get foldersLimitRefused => 'Você mudou as pastas muitas vezes hoje. Tente novamente amanhã.';

  @override
  String get foldersFollow => 'Seguir';

  @override
  String get foldersFollowing => 'Seguindo';

  @override
  String foldersFollowerCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString seguidores',
      one: '1 seguidor',
      zero: 'Nenhum seguidor',
    );
    return '$_temp0';
  }

  @override
  String foldersByOwner(String name) {
    return 'Por $name';
  }

  @override
  String get foldersShare => 'Compartilhar pasta';

  @override
  String get foldersReport => 'Denunciar pasta';

  @override
  String get foldersUnavailableTitle => 'Esta pasta é privada ou não existe mais';

  @override
  String get foldersUnavailableBody => 'O dono pode ter tornado a pasta privada ou excluído.';

  @override
  String get foldersFollowFailed => 'Não foi possível atualizar o seguimento. Tente novamente.';

  @override
  String get foldersYouFollow => 'Pastas que você segue';

  @override
  String get foldersPublicEmptyTitle => 'Ainda não há papéis de parede aqui';

  @override
  String get foldersPublicEmptyBody => 'Os novos papéis de parede aparecem aqui quando o dono os adiciona.';

  @override
  String get notifSettingFolders => 'Pastas que você segue';

  @override
  String get notifSettingFoldersDescription => 'Novos papéis de parede nas pastas que você segue, uma vez por dia';

  @override
  String notifPushFolderDigestTitleOne(String folderName) {
    return 'Novidade em $folderName';
  }

  @override
  String notifPushFolderDigestTitleMore(String folderName, int count) {
    return 'Novidades em $folderName e mais $count';
  }

  @override
  String get historySetAndDownloaded => 'Definido e baixado';

  @override
  String get historyDownloaded => 'Baixado';

  @override
  String get historyRecentlyViewed => 'Vistos recentemente';

  @override
  String get historySyncedNote => 'Salvo na sua conta, então eles voltam em um celular novo.';

  @override
  String get historySyncedNoteGuest => 'Entre para manter esses itens em um celular novo.';

  @override
  String get historyActionSet => 'Definido';

  @override
  String get historyActionDownloaded => 'Baixado';

  @override
  String historySyncedTileLabel(String action, String time) {
    return '$action às $time';
  }

  @override
  String get historyClearSyncedBody =>
      'Isso remove a lista aqui e na sua conta. Seus papéis de parede e downloads continuam como estão.';

  @override
  String get historyClearViewedTitle => 'Limpar vistos recentemente?';

  @override
  String get historyClearViewedBody => 'Isso remove da lista e do Início os papéis de parede que você abriu.';

  @override
  String get historyClearViewedAction => 'Limpar vistos recentemente';

  @override
  String get historyEmptyBodyAndroid =>
      'Os papéis de parede que você define ou baixa aparecem aqui, para você encontrar de novo.';

  @override
  String get historyEmptyBodyIos => 'Os papéis de parede que você baixa aparecem aqui, para você encontrar de novo.';

  @override
  String get historyViewedEmptyTitle => 'Nada visto ainda';

  @override
  String get historyViewedEmptyBody => 'Os papéis de parede que você abre aparecem aqui, para você encontrar de novo.';

  @override
  String get historyViewedOffTitle => 'O histórico de visualização está desativado';

  @override
  String get historyViewedOffBody =>
      'Ative Salvar histórico de visualização para ver aqui os papéis de parede que você abrir.';

  @override
  String get historyViewedOffAction => 'Ativar';

  @override
  String historyViewedTileLabel(String time) {
    return 'Abrir papel de parede, visto às $time';
  }

  @override
  String get pickUpTitle => 'Continue de onde parou';

  @override
  String pickUpTileLabel(int index, int count) {
    return 'Abrir papel de parede $index de $count';
  }

  @override
  String get settingsSaveViewingHistory => 'Salvar histórico de visualização';

  @override
  String get settingsSaveViewingHistoryBody =>
      'Mostra os papéis de parede que você abre no Histórico e no Início. Desligar isso limpa a lista.';

  @override
  String get historyClearFailed => 'Não foi possível limpar o histórico. Verifique sua conexão e tente de novo.';

  @override
  String get wallpaperAutoRotateSourceFolder => 'Pasta';

  @override
  String wallpaperAutoRotateSourceFolderNamed(String folder) {
    return 'Pasta: $folder';
  }

  @override
  String wallpaperAutoRotateNounFolder(String folder) {
    return '$folder';
  }

  @override
  String get wallpaperAutoRotateTooFewFolder =>
      'Esta pasta precisa de pelo menos 2 papéis de parede que possam rotacionar. Os papéis de parede do Prism rotacionam depois que você os baixa.';

  @override
  String get wallpaperAutoRotateOpenFolder => 'Abrir pasta';

  @override
  String get wallpaperAutoRotatePickFolder => 'Escolha uma pasta';

  @override
  String get wallpaperAutoRotateNoFolders =>
      'Você ainda não tem pastas. Salve um papel de parede em uma pasta e depois escolha-a aqui.';

  @override
  String wallpaperAutoRotateConfirmFolderTitle(String folder) {
    return 'Rotacionar $folder?';
  }

  @override
  String get wallpaperAutoRotateConfirmFolderBody =>
      'Seu papel de parede muda para um desta pasta, de acordo com a programação abaixo.';

  @override
  String get wallpaperAutoRotateConfirmFolderAction => 'Rotacionar esta pasta';

  @override
  String wallpaperAutoRotateStoppedFolderDeleted(String folder) {
    return 'A rotação automática está desativada porque a pasta $folder foi excluída.';
  }

  @override
  String wallpaperAutoRotateStoppedFolderEmpty(String folder) {
    return 'A rotação automática está desativada porque a pasta $folder tem menos de 2 papéis de parede.';
  }

  @override
  String get foldersRotateThisFolder => 'Rotacionar esta pasta';

  @override
  String get foldersRotating => 'Rotacionando';

  @override
  String get foldersRotatingDescription => 'A rotação automática usa esta pasta';

  @override
  String get wallpaperAccentResetHint => 'Toque e segure para ações, incluindo Restaurar original';

  @override
  String get wallRequestsTitle => 'Pedidos de papel de parede';

  @override
  String get wallRequestsTabTop => 'Top';

  @override
  String get wallRequestsTabNew => 'Novos';

  @override
  String get wallRequestsTabFilled => 'Atendidos';

  @override
  String get wallRequestsAsk => 'Pedir um papel de parede';

  @override
  String get wallRequestsEmptyTopTitle => 'Nenhum pedido ainda';

  @override
  String get wallRequestsEmptyTopBody =>
      'Peça o papel de parede que você não encontra. Outras pessoas podem apoiar o pedido.';

  @override
  String get wallRequestsEmptyFilledTitle => 'Nada atendido ainda';

  @override
  String get wallRequestsEmptyFilledBody => 'Os pedidos atendidos aparecem aqui, com o papel de parede que os atendeu.';

  @override
  String get wallRequestsLoadFailed => 'Não foi possível carregar os pedidos';

  @override
  String get wallRequestsRetry => 'Tentar novamente';

  @override
  String wallRequestVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
      zero: 'Nenhum voto',
    );
    return '$_temp0';
  }

  @override
  String get wallRequestUpvote => 'Apoiar';

  @override
  String get wallRequestRemoveUpvote => 'Remover apoio';

  @override
  String get wallRequestMine => 'Seu pedido';

  @override
  String get wallRequestSomeone => 'Um usuário do Prism';

  @override
  String wallRequestFilledByCreator(String name) {
    return 'Atendido por $name';
  }

  @override
  String get wallRequestFilledByStudio => 'Feito pelo Prism Studio';

  @override
  String get wallRequestOpenWall => 'Abrir o papel de parede';

  @override
  String get wallRequestMoreActions => 'Mais ações';

  @override
  String get wallRequestReport => 'Denunciar pedido';

  @override
  String get wallRequestHide => 'Ocultar pedido';

  @override
  String get wallRequestUnhide => 'Mostrar pedido';

  @override
  String get wallRequestHiddenLabel => 'Oculto';

  @override
  String get wallRequestSheetTitle => 'Pedir um papel de parede';

  @override
  String get wallRequestSheetHint => 'Descreva, por exemplo: montanhas escuras e minimalistas';

  @override
  String get wallRequestSheetTags => 'Tags, até 3';

  @override
  String get wallRequestSheetSubmit => 'Enviar pedido';

  @override
  String get wallRequestSignIn => 'Entre para pedir papéis de parede e apoiá-los.';

  @override
  String get wallRequestDuplicateTitle => 'Alguém já pediu isso';

  @override
  String get wallRequestDuplicateBody => 'Apoie o pedido para que os criadores vejam mais rápido.';

  @override
  String get wallRequestUpvoteInstead => 'Apoiar este em vez disso';

  @override
  String get wallRequestCreateAnyway => 'Enviar o meu mesmo assim';

  @override
  String get wallRequestDuplicateMine => 'Você já pediu isso';

  @override
  String get wallRequestDuplicateVoted => 'Você já apoiou isso';

  @override
  String get wallRequestEditText => 'Editar meu pedido';

  @override
  String get wallRequestCreated => 'Pedido enviado. Avisamos quando for atendido.';

  @override
  String get wallRequestUpvoted => 'Apoiado. Avisamos quando for atendido.';

  @override
  String get wallRequestErrorText => 'Use de 3 a 80 caracteres e seja gentil.';

  @override
  String get wallRequestErrorLimit => 'Você pode fazer 3 pedidos por dia. Tente amanhã.';

  @override
  String get wallRequestErrorOwn => 'Você não pode apoiar o seu próprio pedido.';

  @override
  String get wallRequestErrorClosed => 'Este pedido já foi atendido.';

  @override
  String get wallRequestErrorGone => 'Este pedido não está mais disponível.';

  @override
  String get wallRequestErrorGeneric => 'Algo deu errado. Tente novamente.';

  @override
  String get searchRequestPrompt => 'Não encontrou?';

  @override
  String get searchRequestAction => 'Peça';

  @override
  String get discoverRequestsTitle => 'Pedidos de papel de parede';

  @override
  String get discoverRequestsSubtitle => 'Peça um papel de parede ou apoie um pedido';

  @override
  String get uploadFillsRequest => 'Atende a um pedido';

  @override
  String get uploadFillsRequestHint => 'Opcional. Escolha o pedido que este papel de parede atende.';

  @override
  String get uploadFillsRequestClear => 'Remover pedido';

  @override
  String get requestPickerTitle => 'Qual pedido ele atende?';

  @override
  String get requestPickerSearch => 'Pesquisar pedidos';

  @override
  String get requestPickerEmpty => 'Nenhum pedido aberto corresponde';

  @override
  String get notifPushWallRequestFilledTitle => 'Seu pedido chegou';

  @override
  String notifPushWallRequestFilledBody(String requestText) {
    return '$requestText';
  }

  @override
  String get wallRequestAgeNow => 'Agora mesmo';

  @override
  String wallRequestAgeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Há $count minutos', one: 'Há 1 minuto');
    return '$_temp0';
  }

  @override
  String wallRequestAgeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Há $count horas', one: 'Há 1 hora');
    return '$_temp0';
  }

  @override
  String wallRequestAgeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Há $count dias', one: 'Há 1 dia');
    return '$_temp0';
  }

  @override
  String wallRequestAgeWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Há $count semanas', one: 'Há 1 semana');
    return '$_temp0';
  }

  @override
  String get wallRequestErrorAccountAge => 'Sua conta poderá fazer pedidos e votar quando tiver 10 dias.';

  @override
  String get adminFillsRequest => 'Atende o pedido';

  @override
  String get wallRemixAction => 'Remixar';

  @override
  String get wallRemixActionTooltip => 'Remixar este papel de parede com IA';

  @override
  String wallRemixingChip(String title, String creator) {
    return 'Remixando $title de $creator';
  }

  @override
  String get wallRemixDropLinkTooltip => 'Remover vínculo de remix';

  @override
  String get wallRemixUntitled => 'Sem título';

  @override
  String get wallRemixUnknownCreator => 'um criador do Prism';

  @override
  String get wallRemixesTitle => 'Remixes';

  @override
  String wallRemixesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count remixes', one: '1 remix');
    return '$_temp0';
  }

  @override
  String wallRemixOpenRemixLabel(String creator) {
    return 'Abrir remix de $creator';
  }

  @override
  String wallRemixOfLabel(String title, String creator) {
    return 'Remix de $title de $creator';
  }

  @override
  String get wallRemixOfTooltip => 'Abrir o papel de parede original';

  @override
  String get economyAiSubmitPromptNotice => 'Qualquer pessoa pode ver seu prompt e remixar este papel de parede.';

  @override
  String get notifPushWallRemixedTitle => 'Seu papel de parede foi remixado';

  @override
  String notifPushWallRemixedBody(String remixerName, String wallTitle) {
    return '$remixerName remixou $wallTitle.';
  }

  @override
  String notifPushWallRemixedBodyUntitled(String remixerName) {
    return '$remixerName remixou seu papel de parede.';
  }

  @override
  String get wallMetadataDescription => 'Descrição';

  @override
  String get wallMetadataEdit => 'Editar detalhes';

  @override
  String get wallResubmitAction => 'Corrigir e reenviar';

  @override
  String get wallResubmitChooseImage => 'Escolher imagem';

  @override
  String get wallResubmitImageMissing =>
      'A imagem original não está mais disponível. Escolha-a novamente para continuar editando.';

  @override
  String get wallResubmitImageKept => 'Imagem original pronta';

  @override
  String get wallResubmitTitle => 'Corrija seu envio';

  @override
  String get wallUploadUseLastDetails => 'Usar últimos detalhes';

  @override
  String get wallUploadLastDetailsUnavailable => 'Não há detalhes anteriores neste dispositivo.';

  @override
  String get wallUploadWithdraw => 'Retirar envio';

  @override
  String get wallUploadWithdrawTitle => 'Retirar este envio?';

  @override
  String get wallUploadWithdrawBody => 'Isso remove o envio da análise e exclui os arquivos enviados.';

  @override
  String get wallUploadWithdrawn => 'Envio retirado';

  @override
  String get wallUploadDeleteHistory => 'Excluir do histórico';

  @override
  String get wallMetadataInvalid => 'Confira o texto e as tags e tente novamente.';

  @override
  String get wallUploadOwnerChanged => 'Sua conta mudou. Abra este envio novamente.';

  @override
  String get wallResubmitLimit => 'Este papel de parede atingiu os três reenvios vinculados.';

  @override
  String get wallResubmitUnsupported =>
      'Escolha novamente a imagem original. Os detalhes da origem de IA não podem ser reutilizados.';

  @override
  String get wallResubmitUnavailable => 'Não foi possível carregar este envio rejeitado. Tente novamente.';

  @override
  String get wallMetadataEditDetails => 'Editar detalhes';

  @override
  String get wallMetadataApprovedHelp =>
      'Altere o título, a descrição e as tags. A imagem e a categoria permanecem iguais.';

  @override
  String get wallMetadataPendingHelp => 'Atualize estes detalhes antes da análise do seu papel de parede.';

  @override
  String get wallMetadataSave => 'Salvar detalhes';

  @override
  String get wallMetadataSaved => 'Detalhes salvos';

  @override
  String get wallMetadataDiscardTitle => 'Descartar alterações?';

  @override
  String get wallMetadataDiscardBody => 'Seus detalhes não salvos serão perdidos.';

  @override
  String get wallMetadataDiscard => 'Descartar alterações';

  @override
  String get wallMetadataReload => 'Recarregar detalhes';

  @override
  String get wallMetadataReloadTitle => 'Recarregar os detalhes atuais?';

  @override
  String get wallMetadataReloadBody => 'Isso substitui seus detalhes não salvos pela versão atual.';

  @override
  String get wallMetadataConflict =>
      'Estes detalhes foram alterados em outro lugar. Suas edições continuam aqui. Recarregue os detalhes atuais antes de salvar.';

  @override
  String get wallMetadataStatusChanged =>
      'O status de análise deste papel de parede mudou. Suas edições não foram salvas.';

  @override
  String get wallMetadataMissing => 'Este papel de parede não está mais disponível. Suas edições não foram salvas.';

  @override
  String get wallMetadataDenied => 'Você não tem permissão para editar este papel de parede.';

  @override
  String get wallMetadataSignedOut => 'Entre novamente para editar este papel de parede.';

  @override
  String get wallMetadataDailyLimit => 'Você atingiu o limite de edições de hoje. Tente novamente amanhã.';

  @override
  String get wallMetadataUnavailable => 'Não foi possível salvar os detalhes. Verifique sua conexão e tente novamente.';

  @override
  String get wallMetadataLoadFailed => 'Não foi possível carregar os detalhes';

  @override
  String get wallMetadataHistory => 'Histórico de edições';

  @override
  String get wallMetadataHistoryEmpty => 'Nenhuma edição dos detalhes ainda';

  @override
  String get wallMetadataHistoryEmptyBody =>
      'As alterações no título, na descrição e nas tags aprovados aparecem aqui.';

  @override
  String get wallMetadataHistoryFailed => 'Não foi possível carregar o histórico de edições';

  @override
  String get wallMetadataBefore => 'Antes';

  @override
  String get wallMetadataAfter => 'Depois';

  @override
  String get wallMetadataRevert => 'Reverter edição';

  @override
  String get wallMetadataRevertTitle => 'Reverter esta edição?';

  @override
  String get wallMetadataRevertBody =>
      'Restaure apenas o título, a descrição e as tags anteriores mostrados aqui. A imagem e o status de análise não mudarão.';

  @override
  String get wallMetadataReverted => 'Edição revertida';

  @override
  String get wallMetadataLoadMore => 'Carregar mais edições';

  @override
  String get wallMetadataAbsent => 'Não definido';

  @override
  String wallMetadataResubmitted(int attempt) {
    return 'Reenviado · tentativa $attempt de 3';
  }

  @override
  String get wallMetadataPreviousReason => 'Motivo da rejeição anterior';

  @override
  String get wallMetadataContextUnavailable => 'Detalhes do reenvio indisponíveis';

  @override
  String get reportSheetMessage =>
      'Conte o que deu errado. O Prism nunca adiciona seu e-mail nem tokens de acesso. Confira as capturas de tela antes de enviar.';

  @override
  String get reportTopicCrashFreeze => 'Falha/travamento';

  @override
  String get reportTopicWallpaperWontSet => 'O papel de parede não é aplicado';

  @override
  String get reportTopicLooksBroken => 'Parece quebrado';

  @override
  String get reportTopicSlow => 'Lento';

  @override
  String get reportTopicOther => 'Outro';

  @override
  String get reportNoteHint => 'O que aconteceu? O que você esperava?';

  @override
  String get reportScreenshotTitle => 'Captura de tela';

  @override
  String get reportScreenshotEmpty => 'Mostre o que você está vendo.';

  @override
  String get reportScreenshotAttached => 'Toque para ver. Confira antes de enviar.';

  @override
  String get reportAddScreenshot => 'Adicionar captura de tela';

  @override
  String get reportRemoveScreenshot => 'Remover';

  @override
  String get reportViewScreenshot => 'Ver captura de tela';

  @override
  String get reportIncludeDiagnostics => 'Incluir informações do dispositivo e registros recentes';

  @override
  String get reportShowDiagnostics => 'Mostrar o que está incluído';

  @override
  String get reportHideDiagnostics => 'Ocultar detalhes';

  @override
  String get reportSend => 'Enviar relatório';

  @override
  String get reportShareAsFile => 'Compartilhar como arquivo';

  @override
  String reportSent(String reference) {
    return 'Obrigado, relatório enviado. Referência $reference';
  }

  @override
  String get reportCouldNotSend => 'Não foi possível enviar';

  @override
  String get reportCouldNotSendBody =>
      'Verifique sua conexão e tente novamente, ou compartilhe o relatório como arquivo.';

  @override
  String get reportShareInstead => 'Compartilhar em vez disso';

  @override
  String get reportShakeToReport => 'Agitar para relatar';

  @override
  String get reportShakeToReportSubtitle => 'Agite o celular em qualquer tela para relatar um problema';

  @override
  String get accountShowAiWallpapers => 'Mostrar papéis de parede gerados por IA';

  @override
  String get accountShowAiWallpapersSubtitle => 'Desative para ver só papéis de parede feitos por pessoas';

  @override
  String get accountShowAiWallpapersFootnote =>
      'Ocultar papéis de parede de IA nunca oculta seus próprios envios nem seus favoritos.';

  @override
  String get wallpaperFeedHideAi => 'Ocultar IA';

  @override
  String get wallpaperAiGenerated => 'Gerado por IA';

  @override
  String wallpaperAiMadeWith(String model) {
    return 'Feito com $model';
  }

  @override
  String get wallpaperAiMadeWithUnknown => 'Feito com IA';

  @override
  String get wallpaperAiReportWrongLabel => 'Denunciar rótulo errado';

  @override
  String get feedNoHumanWalls => 'Ainda não há papéis de parede feitos por pessoas aqui';

  @override
  String get feedShowAiWalls => 'Mostrar papéis de parede de IA';

  @override
  String get dailyMomentTitle => 'Momento diário';

  @override
  String get dailyMomentStreakTitle => 'Sequência diária';

  @override
  String get dailyMomentChestTitle => 'Baú diário';

  @override
  String get dailyMomentSpinTitle => 'Giro grátis';

  @override
  String get dailyMomentUnavailable => 'Esta recompensa não está mais disponível hoje.';

  @override
  String get dailyMomentError => 'Não foi possível carregar a recompensa. Tente novamente.';

  @override
  String dailyMomentStreakReceipt(int coins, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins moedas recebidas',
      one: '$coins moeda recebida',
    );
    String _temp1 = intl.Intl.pluralLogic(days, locale: localeName, other: '$days dias', one: '$days dia');
    return '$_temp0 · sequência de $_temp1';
  }

  @override
  String get challengeTitle => 'Desafio semanal';

  @override
  String get challengeRules => 'Até 3 criações, revisadas antes de aparecerem.';

  @override
  String challengeVotingRules(String date) {
    return 'Vote em outros criadores até $date UTC.';
  }

  @override
  String get challengeUpload => 'Enviar uma criação';

  @override
  String get challengeAi => 'Criar com IA';

  @override
  String get challengeTop => 'Destaques';

  @override
  String get challengeNew => 'Recentes';

  @override
  String get challengePast => 'Desafios anteriores';

  @override
  String get challengeEmpty => 'As criações aprovadas aparecerão aqui.';

  @override
  String get challengeWaiting => 'A votação terminou. Aguardamos as revisões antes de escolher o vencedor.';

  @override
  String get challengeClosed => 'Este desafio terminou.';

  @override
  String get challengeScheduled => 'Este desafio ainda não começou.';

  @override
  String get challengeNoWinner => 'Este desafio não tem vencedor.';

  @override
  String challengeWinner(String name) {
    return 'Vencedor · $name';
  }

  @override
  String get challengeVote => 'Votar';

  @override
  String get challengeUnvote => 'Remover voto';

  @override
  String challengeVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
      zero: '0 votos',
    );
    return '$_temp0';
  }

  @override
  String get dailyMomentCosmetic => 'Item cosmético adicionado à sua coleção';

  @override
  String dailyMomentReward(int coins) {
    String _temp0 = intl.Intl.pluralLogic(
      coins,
      locale: localeName,
      other: '$coins moedas recebidas',
      one: '$coins moeda recebida',
    );
    return '$_temp0';
  }

  @override
  String get dailyMomentChestBody => 'Abra o baú de hoje quando quiser.';

  @override
  String get dailyMomentSpinBody => 'Seu giro grátis está pronto.';

  @override
  String dailyMomentBalance(int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coins moedas', one: '$coins moeda');
    return 'Saldo: $_temp0';
  }

  @override
  String get dailyMomentDone => 'Concluído';

  @override
  String get dailyMomentRetry => 'Tentar novamente';

  @override
  String get dailyMomentContinue => 'Continuar';

  @override
  String get dailyMomentOpenFree => 'Abrir baú grátis';

  @override
  String dailyMomentOpenChest(int coins) {
    String _temp0 = intl.Intl.pluralLogic(coins, locale: localeName, other: '$coins moedas', one: '$coins moeda');
    return 'Abrir por $_temp0';
  }

  @override
  String get dailyMomentSpinAction => 'Girar grátis';

  @override
  String get dailyMomentClose => 'Fechar momento diário';

  @override
  String get dailyMomentToday => 'Hoje';

  @override
  String get dailyMomentReady => 'As recompensas diárias estão prontas';

  @override
  String get dailyMomentComplete => 'Hoje está concluído';

  @override
  String get dailyMomentResume => 'Continuar momento diário';

  @override
  String get dailyMomentMore => 'Mais';

  @override
  String get dailyMomentQuests => 'Missões';

  @override
  String get dailyMomentChestLeft => 'Baú diário disponível';

  @override
  String get dailyMomentSpinLeft => 'Giro grátis disponível';

  @override
  String get dailyMomentStreakLeft => 'Sequência diária disponível';

  @override
  String get challengeShare => 'Compartilhar desafio';

  @override
  String get challengeRemove => 'Remover desafio';

  @override
  String challengeContext(String theme) {
    return 'Desafio · $theme';
  }

  @override
  String get challengeError => 'Não foi possível carregar o desafio. Tente novamente.';

  @override
  String get challengeVoteError => 'Não foi possível salvar seu voto. Tente novamente.';

  @override
  String get challengeSignIn => 'Entre para participar ou votar.';

  @override
  String get challengeLimit => 'Você já enviou 3 wallpapers para este desafio.';

  @override
  String get challengeRetry => 'Tentar novamente';

  @override
  String get challengeOwnEntry => 'Você não pode votar na própria criação.';

  @override
  String get challengeDailyLimit => 'Você atingiu o limite diário de votos.';

  @override
  String get challengeMissing => 'Este desafio ou criação não está mais disponível.';

  @override
  String get challengeBadge => 'Vencedor do desafio';

  @override
  String get challengeBadgeDescription => 'Vença um desafio semanal';

  @override
  String get challengeWinnerNotificationTitle => 'Seu wallpaper venceu';

  @override
  String challengeWinnerNotificationBody(String theme) {
    return 'Sua criação venceu o desafio semanal: $theme.';
  }

  @override
  String get statsTitle => 'Suas estatísticas';

  @override
  String get statsEntry => 'Estatísticas';

  @override
  String get statsViews => 'Visualizações';

  @override
  String get statsSaves => 'Salvos';

  @override
  String get statsSets => 'Vezes aplicado';

  @override
  String get statsDownloads => 'Downloads';

  @override
  String get statsShares => 'Compartilhamentos';

  @override
  String get statsFolderAdds => 'Adições a pastas';

  @override
  String get statsRemixes => 'Remixes';

  @override
  String get statsLoading => 'Carregando suas estatísticas';

  @override
  String get statsError => 'Não foi possível carregar suas estatísticas. Tente novamente.';

  @override
  String get statsRetry => 'Tentar novamente';

  @override
  String get statsEmptyTitle => 'Seu primeiro fundo começa aqui';

  @override
  String get statsEmptyBody => 'Envie um fundo. As estatísticas aparecem após a aprovação.';

  @override
  String get statsUpload => 'Enviar um fundo';

  @override
  String get statsWeekNote =>
      'Esta semana até agora em comparação com a anterior. As semanas começam na segunda-feira, UTC.';

  @override
  String get statsHistoryNote =>
      'Oito semanas, da mais antiga à mais recente. Um traço indica dados indisponíveis. O acompanhamento pode começar no meio da semana, por isso os dados semanais podem ser parciais. A semana atual está incompleta.';

  @override
  String get statsTopWalls => 'Melhores fundos desta semana';

  @override
  String get statsUntitled => 'Fundo sem título';

  @override
  String get statsCountingNote =>
      'O total de salvos conta os favoritos atuais; o valor semanal conta adições. O total de remixes conta os créditos atuais; o valor semanal conta os primeiros créditos aceitos. As adições a pastas são registradas desde o início do acompanhamento.';

  @override
  String get statsUnavailable => 'Indisponível';

  @override
  String get statsWeeklyTitle => 'Seus fundos nesta semana';

  @override
  String statsWeeklyBody(String week) {
    return 'Veja os resultados dos seus fundos em $week.';
  }

  @override
  String statsWallValue(String metric, String value) {
    return '$metric: $value nesta semana';
  }

  @override
  String statsComparison(String current, String previous) {
    return '$current nesta semana · $previous na anterior';
  }

  @override
  String statsTotal(String value) {
    return 'Total: $value';
  }

  @override
  String statsChange(String value) {
    return '$value em comparação com a semana anterior';
  }

  @override
  String statsUpdated(String date) {
    return 'Atualizado em $date UTC';
  }

  @override
  String statsChartWeek(String date, String value) {
    return 'Semana de $date: $value';
  }

  @override
  String statsChartSummary(String metric, String summary) {
    return '$metric, oito semanas. $summary';
  }

  @override
  String get shortcutsGuideHeadline => 'Um papel de parede novo todo dia';

  @override
  String get shortcutsGuideBody =>
      'Configure os Atalhos uma vez. Todo dia, a automação define um papel de parede da sua pasta de rotação. Os 200 mais recentes aparecem uma vez cada antes de qualquer repetição.';

  @override
  String get shortcutsSourceRotation => 'Pasta de rotação';

  @override
  String get shortcutsSourceRotationDescription => 'Embaralha a pasta que você escolheu acima.';

  @override
  String get shortcutsSourceFolder => 'Pasta';

  @override
  String get shortcutsSourceFolderDescription => 'Embaralha uma pasta que você escolher nos Atalhos.';

  @override
  String get shortcutsSourceFavouriteDescription =>
      'Embaralha seus favoritos. Cada um aparece uma vez antes de qualquer um se repetir. Alguns papéis de parede protegidos podem não estar disponíveis.';

  @override
  String get shortcutsRotationNone => 'Nenhuma pasta escolhida';

  @override
  String get shortcutsRotationNoneBody => 'Escolha a pasta que o atalho embaralha.';

  @override
  String get shortcutsRotationPick => 'Escolher uma pasta';

  @override
  String get shortcutsRotationChange => 'Alterar';

  @override
  String get shortcutsRotationStop => 'Parar';

  @override
  String shortcutsStepLabel(int number, String title) {
    return 'Passo $number, $title';
  }

  @override
  String get shortcutsStepAddTitle => 'Adicione o atalho do Prism';

  @override
  String get shortcutsStepAddBody =>
      'Ele pega um papel de parede da sua pasta de rotação e o define como seu papel de parede.';

  @override
  String get shortcutsStepAddAction => 'Adicionar o atalho';

  @override
  String get shortcutsStepAddManualBody => 'Crie nos Atalhos com 2 ações.';

  @override
  String get shortcutsManualNew => 'Nos Atalhos, toque em + para criar um atalho novo.';

  @override
  String get shortcutsManualGet => 'Adicione \"Obter papel de parede do Prism\". Defina Origem como Pasta de rotação.';

  @override
  String get shortcutsManualSet =>
      'Adicione \"Definir Foto de Fundo\". Toque na seta nela e desative Mostrar Pré-Visualização.';

  @override
  String shortcutsManualName(String name) {
    return 'Dê o nome \"$name\" ao atalho.';
  }

  @override
  String get shortcutsStepAutomationTitle => 'Execute todos os dias';

  @override
  String get shortcutsAutomationOpen => 'Nos Atalhos, toque em Automação e depois em +.';

  @override
  String get shortcutsAutomationTime => 'Toque em Hora do Dia. Escolha um horário e depois Diariamente.';

  @override
  String get shortcutsAutomationRun => 'Escolha Executar Imediatamente e depois toque em Avançar.';

  @override
  String shortcutsAutomationPick(String name) {
    return 'Escolha \"$name\" para executar.';
  }

  @override
  String shortcutsAutomationNoTab(String name) {
    return 'Não encontrou a aba Automação? Abra \"$name\", toque em Editar e depois em Automação.';
  }

  @override
  String get shortcutsStepTestTitle => 'Teste agora';

  @override
  String shortcutsStepTestBody(String name) {
    return 'Executa \"$name\" uma vez, para você ver o novo papel de parede agora.';
  }

  @override
  String get shortcutsStepTestAction => 'Executar o atalho';

  @override
  String get foldersRotateDaily => 'Rotacionar esta pasta todo dia';

  @override
  String get autoRotateIosTitle => 'Troque os papéis de parede com os Atalhos';

  @override
  String get autoRotateIosBody =>
      'No iPhone, uma automação dos Atalhos define um papel de parede novo da sua pasta todo dia.';

  @override
  String get autoRotateIosAction => 'Configurar os Atalhos';

  @override
  String get shortcutsAutomationIos16 =>
      'No iOS 16 não existe \"Executar Imediatamente\". Desative \"Perguntar Antes de Executar\".';
}
