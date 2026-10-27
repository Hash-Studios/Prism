// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AboutScreen]
class AboutRoute extends PageRouteInfo<AboutRouteArgs> {
  AboutRoute({
    Key? key,
    Future<List<Contributor>> Function()? loadContributors,
    List<PageRouteInfo>? children,
  }) : super(
         AboutRoute.name,
         args: AboutRouteArgs(key: key, loadContributors: loadContributors),
         initialChildren: children,
       );

  static const String name = 'AboutRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AboutRouteArgs>(
        orElse: () => const AboutRouteArgs(),
      );
      return AboutScreen(
        key: args.key,
        loadContributors: args.loadContributors,
      );
    },
  );
}

class AboutRouteArgs {
  const AboutRouteArgs({this.key, this.loadContributors});

  final Key? key;

  final Future<List<Contributor>> Function()? loadContributors;

  @override
  String toString() {
    return 'AboutRouteArgs{key: $key, loadContributors: $loadContributors}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AboutRouteArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [AdminReviewScreen]
class AdminReviewRoute extends PageRouteInfo<AdminReviewRouteArgs> {
  AdminReviewRoute({
    Key? key,
    AdminModerationRepository? repository,
    List<PageRouteInfo>? children,
  }) : super(
         AdminReviewRoute.name,
         args: AdminReviewRouteArgs(key: key, repository: repository),
         initialChildren: children,
       );

  static const String name = 'AdminReviewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AdminReviewRouteArgs>(
        orElse: () => const AdminReviewRouteArgs(),
      );
      return AdminReviewScreen(key: args.key, repository: args.repository);
    },
  );
}

class AdminReviewRouteArgs {
  const AdminReviewRouteArgs({this.key, this.repository});

  final Key? key;

  final AdminModerationRepository? repository;

  @override
  String toString() {
    return 'AdminReviewRouteArgs{key: $key, repository: $repository}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AdminReviewRouteArgs) return false;
    return key == other.key && repository == other.repository;
  }

  @override
  int get hashCode => key.hashCode ^ repository.hashCode;
}

/// generated route for
/// [AiWallpaperTabPage]
class AiTabRoute extends PageRouteInfo<AiTabRouteArgs> {
  AiTabRoute({
    Key? key,
    AiGenerationRepositoryImpl? repository,
    Future<WallSubmissionResult> Function()? submitForTesting,
    ShareSheetOpen? shareSheet,
    List<PageRouteInfo>? children,
  }) : super(
         AiTabRoute.name,
         args: AiTabRouteArgs(
           key: key,
           repository: repository,
           submitForTesting: submitForTesting,
           shareSheet: shareSheet,
         ),
         initialChildren: children,
       );

  static const String name = 'AiTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AiTabRouteArgs>(
        orElse: () => const AiTabRouteArgs(),
      );
      return AiWallpaperTabPage(
        key: args.key,
        repository: args.repository,
        submitForTesting: args.submitForTesting,
        shareSheet: args.shareSheet,
      );
    },
  );
}

class AiTabRouteArgs {
  const AiTabRouteArgs({
    this.key,
    this.repository,
    this.submitForTesting,
    this.shareSheet,
  });

  final Key? key;

  final AiGenerationRepositoryImpl? repository;

  final Future<WallSubmissionResult> Function()? submitForTesting;

  final ShareSheetOpen? shareSheet;

  @override
  String toString() {
    return 'AiTabRouteArgs{key: $key, repository: $repository, submitForTesting: $submitForTesting, shareSheet: $shareSheet}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiTabRouteArgs) return false;
    return key == other.key &&
        repository == other.repository &&
        shareSheet == other.shareSheet;
  }

  @override
  int get hashCode => key.hashCode ^ repository.hashCode ^ shareSheet.hashCode;
}

/// generated route for
/// [AutoRotateScreen]
class AutoRotateRoute extends PageRouteInfo<void> {
  const AutoRotateRoute({List<PageRouteInfo>? children})
    : super(AutoRotateRoute.name, initialChildren: children);

  static const String name = 'AutoRotateRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AutoRotateScreen();
    },
  );
}

/// generated route for
/// [BlockedAccountsScreen]
class BlockedAccountsRoute extends PageRouteInfo<void> {
  const BlockedAccountsRoute({List<PageRouteInfo>? children})
    : super(BlockedAccountsRoute.name, initialChildren: children);

  static const String name = 'BlockedAccountsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const BlockedAccountsScreen();
    },
  );
}

/// generated route for
/// [ClockOverlay]
class ClockPreviewRoute extends PageRouteInfo<ClockPreviewRouteArgs> {
  ClockPreviewRoute({
    Key? key,
    required String link,
    required bool file,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
    String? thumbnailUrl,
    Color? tint,
    List<PageRouteInfo>? children,
  }) : super(
         ClockPreviewRoute.name,
         args: ClockPreviewRouteArgs(
           key: key,
           link: link,
           file: file,
           wallpaperId: wallpaperId,
           wallpaperSource: wallpaperSource,
           thumbnailUrl: thumbnailUrl,
           tint: tint,
         ),
         initialChildren: children,
       );

  static const String name = 'ClockPreviewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ClockPreviewRouteArgs>();
      return ClockOverlay(
        key: args.key,
        link: args.link,
        file: args.file,
        wallpaperId: args.wallpaperId,
        wallpaperSource: args.wallpaperSource,
        thumbnailUrl: args.thumbnailUrl,
        tint: args.tint,
      );
    },
  );
}

class ClockPreviewRouteArgs {
  const ClockPreviewRouteArgs({
    this.key,
    required this.link,
    required this.file,
    this.wallpaperId,
    this.wallpaperSource,
    this.thumbnailUrl,
    this.tint,
  });

  final Key? key;

  final String link;

  final bool file;

  final String? wallpaperId;

  final WallpaperSource? wallpaperSource;

  final String? thumbnailUrl;

  final Color? tint;

  @override
  String toString() {
    return 'ClockPreviewRouteArgs{key: $key, link: $link, file: $file, wallpaperId: $wallpaperId, wallpaperSource: $wallpaperSource, thumbnailUrl: $thumbnailUrl, tint: $tint}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ClockPreviewRouteArgs) return false;
    return key == other.key &&
        link == other.link &&
        file == other.file &&
        wallpaperId == other.wallpaperId &&
        wallpaperSource == other.wallpaperSource &&
        thumbnailUrl == other.thumbnailUrl &&
        tint == other.tint;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      link.hashCode ^
      file.hashCode ^
      wallpaperId.hashCode ^
      wallpaperSource.hashCode ^
      thumbnailUrl.hashCode ^
      tint.hashCode;
}

/// generated route for
/// [CoinHistoryPage]
class CoinHistoryRoute extends PageRouteInfo<void> {
  const CoinHistoryRoute({List<PageRouteInfo>? children})
    : super(CoinHistoryRoute.name, initialChildren: children);

  static const String name = 'CoinHistoryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const CoinHistoryPage();
    },
  );
}

/// generated route for
/// [CollectionTabPage]
class CollectionTabRoute extends PageRouteInfo<void> {
  const CollectionTabRoute({List<PageRouteInfo>? children})
    : super(CollectionTabRoute.name, initialChildren: children);

  static const String name = 'CollectionTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const CollectionTabPage();
    },
  );
}

/// generated route for
/// [CollectionViewScreen]
class CollectionViewRoute extends PageRouteInfo<CollectionViewRouteArgs> {
  CollectionViewRoute({
    Key? key,
    required String collectionName,
    List<PageRouteInfo>? children,
  }) : super(
         CollectionViewRoute.name,
         args: CollectionViewRouteArgs(
           key: key,
           collectionName: collectionName,
         ),
         initialChildren: children,
       );

  static const String name = 'CollectionViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CollectionViewRouteArgs>();
      return CollectionViewScreen(
        key: args.key,
        collectionName: args.collectionName,
      );
    },
  );
}

class CollectionViewRouteArgs {
  const CollectionViewRouteArgs({this.key, required this.collectionName});

  final Key? key;

  final String collectionName;

  @override
  String toString() {
    return 'CollectionViewRouteArgs{key: $key, collectionName: $collectionName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CollectionViewRouteArgs) return false;
    return key == other.key && collectionName == other.collectionName;
  }

  @override
  int get hashCode => key.hashCode ^ collectionName.hashCode;
}

/// generated route for
/// [DailyChestPage]
class DailyChestRoute extends PageRouteInfo<DailyChestRouteArgs> {
  DailyChestRoute({
    Key? key,
    OpenChestFunction? open,
    ValueListenable<QuestState?>? quests,
    ValueListenable<int>? balance,
    Future<void> Function()? refresh,
    DateTime Function()? now,
    VoidCallback? onOpenShop,
    List<PageRouteInfo>? children,
  }) : super(
         DailyChestRoute.name,
         args: DailyChestRouteArgs(
           key: key,
           open: open,
           quests: quests,
           balance: balance,
           refresh: refresh,
           now: now,
           onOpenShop: onOpenShop,
         ),
         initialChildren: children,
       );

  static const String name = 'DailyChestRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DailyChestRouteArgs>(
        orElse: () => const DailyChestRouteArgs(),
      );
      return DailyChestPage(
        key: args.key,
        open: args.open,
        quests: args.quests,
        balance: args.balance,
        refresh: args.refresh,
        now: args.now,
        onOpenShop: args.onOpenShop,
      );
    },
  );
}

class DailyChestRouteArgs {
  const DailyChestRouteArgs({
    this.key,
    this.open,
    this.quests,
    this.balance,
    this.refresh,
    this.now,
    this.onOpenShop,
  });

  final Key? key;

  final OpenChestFunction? open;

  final ValueListenable<QuestState?>? quests;

  final ValueListenable<int>? balance;

  final Future<void> Function()? refresh;

  final DateTime Function()? now;

  final VoidCallback? onOpenShop;

  @override
  String toString() {
    return 'DailyChestRouteArgs{key: $key, open: $open, quests: $quests, balance: $balance, refresh: $refresh, now: $now, onOpenShop: $onOpenShop}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DailyChestRouteArgs) return false;
    return key == other.key &&
        open == other.open &&
        quests == other.quests &&
        balance == other.balance &&
        onOpenShop == other.onOpenShop;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      open.hashCode ^
      quests.hashCode ^
      balance.hashCode ^
      onOpenShop.hashCode;
}

/// generated route for
/// [DashboardPage]
class DashboardRoute extends PageRouteInfo<void> {
  const DashboardRoute({List<PageRouteInfo>? children})
    : super(DashboardRoute.name, initialChildren: children);

  static const String name = 'DashboardRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DashboardPage();
    },
  );
}

/// generated route for
/// [DebugPanelPage]
class DebugPanelRoute extends PageRouteInfo<DebugPanelRouteArgs> {
  DebugPanelRoute({
    Key? key,
    String tab = 'logs',
    List<PageRouteInfo>? children,
  }) : super(
         DebugPanelRoute.name,
         args: DebugPanelRouteArgs(key: key, tab: tab),
         rawQueryParams: {'tab': tab},
         initialChildren: children,
       );

  static const String name = 'DebugPanelRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<DebugPanelRouteArgs>(
        orElse: () =>
            DebugPanelRouteArgs(tab: queryParams.getString('tab', 'logs')),
      );
      return DebugPanelPage(key: args.key, tab: args.tab);
    },
  );
}

class DebugPanelRouteArgs {
  const DebugPanelRouteArgs({this.key, this.tab = 'logs'});

  final Key? key;

  final String tab;

  @override
  String toString() {
    return 'DebugPanelRouteArgs{key: $key, tab: $tab}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DebugPanelRouteArgs) return false;
    return key == other.key && tab == other.tab;
  }

  @override
  int get hashCode => key.hashCode ^ tab.hashCode;
}

/// generated route for
/// [DeepLinkInputPage]
class DeepLinkInputRoute extends PageRouteInfo<DeepLinkInputRouteArgs> {
  DeepLinkInputRoute({
    Key? key,
    required DeepLinkInputWorkflow workflow,
    List<PageRouteInfo>? children,
  }) : super(
         DeepLinkInputRoute.name,
         args: DeepLinkInputRouteArgs(key: key, workflow: workflow),
         initialChildren: children,
       );

  static const String name = 'DeepLinkInputRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DeepLinkInputRouteArgs>();
      return DeepLinkInputPage(key: args.key, workflow: args.workflow);
    },
  );
}

class DeepLinkInputRouteArgs {
  const DeepLinkInputRouteArgs({this.key, required this.workflow});

  final Key? key;

  final DeepLinkInputWorkflow workflow;

  @override
  String toString() {
    return 'DeepLinkInputRouteArgs{key: $key, workflow: $workflow}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DeepLinkInputRouteArgs) return false;
    return key == other.key && workflow == other.workflow;
  }

  @override
  int get hashCode => key.hashCode ^ workflow.hashCode;
}

/// generated route for
/// [DownloadScreen]
class DownloadRoute extends PageRouteInfo<void> {
  const DownloadRoute({List<PageRouteInfo>? children})
    : super(DownloadRoute.name, initialChildren: children);

  static const String name = 'DownloadRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return DownloadScreen();
    },
  );
}

/// generated route for
/// [DownloadWallpaperScreen]
class DownloadWallpaperRoute extends PageRouteInfo<DownloadWallpaperRouteArgs> {
  DownloadWallpaperRoute({
    Key? key,
    required WallpaperSource source,
    required File file,
    List<PageRouteInfo>? children,
  }) : super(
         DownloadWallpaperRoute.name,
         args: DownloadWallpaperRouteArgs(key: key, source: source, file: file),
         initialChildren: children,
       );

  static const String name = 'DownloadWallpaperRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DownloadWallpaperRouteArgs>();
      return DownloadWallpaperScreen(
        key: args.key,
        source: args.source,
        file: args.file,
      );
    },
  );
}

class DownloadWallpaperRouteArgs {
  const DownloadWallpaperRouteArgs({
    this.key,
    required this.source,
    required this.file,
  });

  final Key? key;

  final WallpaperSource source;

  final File file;

  @override
  String toString() {
    return 'DownloadWallpaperRouteArgs{key: $key, source: $source, file: $file}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DownloadWallpaperRouteArgs) return false;
    return key == other.key && source == other.source && file == other.file;
  }

  @override
  int get hashCode => key.hashCode ^ source.hashCode ^ file.hashCode;
}

/// generated route for
/// [DrawPage]
class DrawRoute extends PageRouteInfo<void> {
  const DrawRoute({List<PageRouteInfo>? children})
    : super(DrawRoute.name, initialChildren: children);

  static const String name = 'DrawRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const DrawPage());
    },
  );
}

/// generated route for
/// [DropDetailPage]
class DropDetailRoute extends PageRouteInfo<DropDetailRouteArgs> {
  DropDetailRoute({
    Key? key,
    required String weekKey,
    List<PageRouteInfo>? children,
  }) : super(
         DropDetailRoute.name,
         args: DropDetailRouteArgs(key: key, weekKey: weekKey),
         rawPathParams: {'weekKey': weekKey},
         initialChildren: children,
       );

  static const String name = 'DropDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<DropDetailRouteArgs>(
        orElse: () =>
            DropDetailRouteArgs(weekKey: pathParams.getString('weekKey')),
      );
      return DropDetailPage(key: args.key, weekKey: args.weekKey);
    },
  );
}

class DropDetailRouteArgs {
  const DropDetailRouteArgs({this.key, required this.weekKey});

  final Key? key;

  final String weekKey;

  @override
  String toString() {
    return 'DropDetailRouteArgs{key: $key, weekKey: $weekKey}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DropDetailRouteArgs) return false;
    return key == other.key && weekKey == other.weekKey;
  }

  @override
  int get hashCode => key.hashCode ^ weekKey.hashCode;
}

/// generated route for
/// [DropPreviewRoutePage]
class DropPreviewRoute extends PageRouteInfo<DropPreviewRouteArgs> {
  DropPreviewRoute({
    Key? key,
    required String weekKey,
    required String wallId,
    DropsBloc? bloc,
    List<PageRouteInfo>? children,
  }) : super(
         DropPreviewRoute.name,
         args: DropPreviewRouteArgs(
           key: key,
           weekKey: weekKey,
           wallId: wallId,
           bloc: bloc,
         ),
         rawPathParams: {'weekKey': weekKey, 'wallId': wallId},
         initialChildren: children,
       );

  static const String name = 'DropPreviewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<DropPreviewRouteArgs>(
        orElse: () => DropPreviewRouteArgs(
          weekKey: pathParams.getString('weekKey'),
          wallId: pathParams.getString('wallId'),
        ),
      );
      return DropPreviewRoutePage(
        key: args.key,
        weekKey: args.weekKey,
        wallId: args.wallId,
        bloc: args.bloc,
      );
    },
  );
}

class DropPreviewRouteArgs {
  const DropPreviewRouteArgs({
    this.key,
    required this.weekKey,
    required this.wallId,
    this.bloc,
  });

  final Key? key;

  final String weekKey;

  final String wallId;

  final DropsBloc? bloc;

  @override
  String toString() {
    return 'DropPreviewRouteArgs{key: $key, weekKey: $weekKey, wallId: $wallId, bloc: $bloc}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DropPreviewRouteArgs) return false;
    return key == other.key &&
        weekKey == other.weekKey &&
        wallId == other.wallId &&
        bloc == other.bloc;
  }

  @override
  int get hashCode =>
      key.hashCode ^ weekKey.hashCode ^ wallId.hashCode ^ bloc.hashCode;
}

/// generated route for
/// [DropsPage]
class DropsRoute extends PageRouteInfo<void> {
  const DropsRoute({List<PageRouteInfo>? children})
    : super(DropsRoute.name, initialChildren: children);

  static const String name = 'DropsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DropsPage();
    },
  );
}

/// generated route for
/// [EditProfilePanel]
class EditProfilePanelRoute extends PageRouteInfo<void> {
  const EditProfilePanelRoute({List<PageRouteInfo>? children})
    : super(EditProfilePanelRoute.name, initialChildren: children);

  static const String name = 'EditProfilePanelRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const EditProfilePanel();
    },
  );
}

/// generated route for
/// [EditWallScreen]
class EditWallRoute extends PageRouteInfo<EditWallRouteArgs> {
  EditWallRoute({
    Key? key,
    required File image,
    UploadBatch? batch,
    List<PageRouteInfo>? children,
  }) : super(
         EditWallRoute.name,
         args: EditWallRouteArgs(key: key, image: image, batch: batch),
         initialChildren: children,
       );

  static const String name = 'EditWallRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EditWallRouteArgs>();
      return EditWallScreen(
        key: args.key,
        image: args.image,
        batch: args.batch,
      );
    },
  );
}

class EditWallRouteArgs {
  const EditWallRouteArgs({this.key, required this.image, this.batch});

  final Key? key;

  final File image;

  final UploadBatch? batch;

  @override
  String toString() {
    return 'EditWallRouteArgs{key: $key, image: $image, batch: $batch}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EditWallRouteArgs) return false;
    return key == other.key && image == other.image && batch == other.batch;
  }

  @override
  int get hashCode => key.hashCode ^ image.hashCode ^ batch.hashCode;
}

/// generated route for
/// [FavouriteWallpaperScreen]
class FavouriteWallpaperRoute extends PageRouteInfo<void> {
  const FavouriteWallpaperRoute({List<PageRouteInfo>? children})
    : super(FavouriteWallpaperRoute.name, initialChildren: children);

  static const String name = 'FavouriteWallpaperRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const FavouriteWallpaperScreen();
    },
  );
}

/// generated route for
/// [FirestoreTelemetryScreen]
class FirestoreTelemetryRoute extends PageRouteInfo<void> {
  const FirestoreTelemetryRoute({List<PageRouteInfo>? children})
    : super(FirestoreTelemetryRoute.name, initialChildren: children);

  static const String name = 'FirestoreTelemetryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const FirestoreTelemetryScreen();
    },
  );
}

/// generated route for
/// [FollowersScreen]
class FollowersRoute extends PageRouteInfo<FollowersRouteArgs> {
  FollowersRoute({
    Key? key,
    required String userId,
    List<PageRouteInfo>? children,
  }) : super(
         FollowersRoute.name,
         args: FollowersRouteArgs(key: key, userId: userId),
         initialChildren: children,
       );

  static const String name = 'FollowersRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FollowersRouteArgs>();
      return FollowersScreen(key: args.key, userId: args.userId);
    },
  );
}

class FollowersRouteArgs {
  const FollowersRouteArgs({this.key, required this.userId});

  final Key? key;

  final String userId;

  @override
  String toString() {
    return 'FollowersRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FollowersRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [FollowingListScreen]
class FollowingListRoute extends PageRouteInfo<FollowingListRouteArgs> {
  FollowingListRoute({
    Key? key,
    required String userId,
    List<PageRouteInfo>? children,
  }) : super(
         FollowingListRoute.name,
         args: FollowingListRouteArgs(key: key, userId: userId),
         initialChildren: children,
       );

  static const String name = 'FollowingListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FollowingListRouteArgs>();
      return FollowingListScreen(key: args.key, userId: args.userId);
    },
  );
}

class FollowingListRouteArgs {
  const FollowingListRouteArgs({this.key, required this.userId});

  final Key? key;

  final String userId;

  @override
  String toString() {
    return 'FollowingListRouteArgs{key: $key, userId: $userId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FollowingListRouteArgs) return false;
    return key == other.key && userId == other.userId;
  }

  @override
  int get hashCode => key.hashCode ^ userId.hashCode;
}

/// generated route for
/// [FullScreenImageView]
class FullScreenImageRoute extends PageRouteInfo<FullScreenImageRouteArgs> {
  FullScreenImageRoute({
    Key? key,
    required String imageUrl,
    List<PageRouteInfo>? children,
  }) : super(
         FullScreenImageRoute.name,
         args: FullScreenImageRouteArgs(key: key, imageUrl: imageUrl),
         initialChildren: children,
       );

  static const String name = 'FullScreenImageRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FullScreenImageRouteArgs>();
      return FullScreenImageView(key: args.key, imageUrl: args.imageUrl);
    },
  );
}

class FullScreenImageRouteArgs {
  const FullScreenImageRouteArgs({this.key, required this.imageUrl});

  final Key? key;

  final String imageUrl;

  @override
  String toString() {
    return 'FullScreenImageRouteArgs{key: $key, imageUrl: $imageUrl}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FullScreenImageRouteArgs) return false;
    return key == other.key && imageUrl == other.imageUrl;
  }

  @override
  int get hashCode => key.hashCode ^ imageUrl.hashCode;
}

/// generated route for
/// [HomeTabPage]
class HomeTabRoute extends PageRouteInfo<void> {
  const HomeTabRoute({List<PageRouteInfo>? children})
    : super(HomeTabRoute.name, initialChildren: children);

  static const String name = 'HomeTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HomeTabPage();
    },
  );
}

/// generated route for
/// [IosShortcutsGuideScreen]
class IosShortcutsGuideRoute extends PageRouteInfo<void> {
  const IosShortcutsGuideRoute({List<PageRouteInfo>? children})
    : super(IosShortcutsGuideRoute.name, initialChildren: children);

  static const String name = 'IosShortcutsGuideRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const IosShortcutsGuideScreen();
    },
  );
}

/// generated route for
/// [LeaderboardPage]
class LeaderboardRoute extends PageRouteInfo<void> {
  const LeaderboardRoute({List<PageRouteInfo>? children})
    : super(LeaderboardRoute.name, initialChildren: children);

  static const String name = 'LeaderboardRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const LeaderboardPage());
    },
  );
}

/// generated route for
/// [LibraryScreen]
class LibraryRoute extends PageRouteInfo<LibraryRouteArgs> {
  LibraryRoute({
    Key? key,
    LibraryTab initialTab = LibraryTab.favourites,
    List<PageRouteInfo>? children,
  }) : super(
         LibraryRoute.name,
         args: LibraryRouteArgs(key: key, initialTab: initialTab),
         initialChildren: children,
       );

  static const String name = 'LibraryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LibraryRouteArgs>(
        orElse: () => const LibraryRouteArgs(),
      );
      return LibraryScreen(key: args.key, initialTab: args.initialTab);
    },
  );
}

class LibraryRouteArgs {
  const LibraryRouteArgs({this.key, this.initialTab = LibraryTab.favourites});

  final Key? key;

  final LibraryTab initialTab;

  @override
  String toString() {
    return 'LibraryRouteArgs{key: $key, initialTab: $initialTab}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LibraryRouteArgs) return false;
    return key == other.key && initialTab == other.initialTab;
  }

  @override
  int get hashCode => key.hashCode ^ initialTab.hashCode;
}

/// generated route for
/// [LiveWallpaperScreen]
class LiveWallpaperRoute extends PageRouteInfo<LiveWallpaperRouteArgs> {
  LiveWallpaperRoute({
    Key? key,
    String? imageUrl,
    Color? accentSeed,
    List<PageRouteInfo>? children,
  }) : super(
         LiveWallpaperRoute.name,
         args: LiveWallpaperRouteArgs(
           key: key,
           imageUrl: imageUrl,
           accentSeed: accentSeed,
         ),
         initialChildren: children,
       );

  static const String name = 'LiveWallpaperRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LiveWallpaperRouteArgs>(
        orElse: () => const LiveWallpaperRouteArgs(),
      );
      return LiveWallpaperScreen(
        key: args.key,
        imageUrl: args.imageUrl,
        accentSeed: args.accentSeed,
      );
    },
  );
}

class LiveWallpaperRouteArgs {
  const LiveWallpaperRouteArgs({this.key, this.imageUrl, this.accentSeed});

  final Key? key;

  final String? imageUrl;

  final Color? accentSeed;

  @override
  String toString() {
    return 'LiveWallpaperRouteArgs{key: $key, imageUrl: $imageUrl, accentSeed: $accentSeed}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LiveWallpaperRouteArgs) return false;
    return key == other.key &&
        imageUrl == other.imageUrl &&
        accentSeed == other.accentSeed;
  }

  @override
  int get hashCode => key.hashCode ^ imageUrl.hashCode ^ accentSeed.hashCode;
}

/// generated route for
/// [NotFoundPage]
class NotFoundRoute extends PageRouteInfo<void> {
  const NotFoundRoute({List<PageRouteInfo>? children})
    : super(NotFoundRoute.name, initialChildren: children);

  static const String name = 'NotFoundRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NotFoundPage();
    },
  );
}

/// generated route for
/// [NotificationScreen]
class NotificationRoute extends PageRouteInfo<void> {
  const NotificationRoute({List<PageRouteInfo>? children})
    : super(NotificationRoute.name, initialChildren: children);

  static const String name = 'NotificationRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NotificationScreen();
    },
  );
}

/// generated route for
/// [OnboardingV2Shell]
class OnboardingV2ShellRoute extends PageRouteInfo<OnboardingV2ShellRouteArgs> {
  OnboardingV2ShellRoute({
    Key? key,
    Future<bool> Function()? signOutForRecovery,
    List<PageRouteInfo>? children,
  }) : super(
         OnboardingV2ShellRoute.name,
         args: OnboardingV2ShellRouteArgs(
           key: key,
           signOutForRecovery: signOutForRecovery,
         ),
         initialChildren: children,
       );

  static const String name = 'OnboardingV2ShellRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<OnboardingV2ShellRouteArgs>(
        orElse: () => const OnboardingV2ShellRouteArgs(),
      );
      return OnboardingV2Shell(
        key: args.key,
        signOutForRecovery: args.signOutForRecovery,
      );
    },
  );
}

class OnboardingV2ShellRouteArgs {
  const OnboardingV2ShellRouteArgs({this.key, this.signOutForRecovery});

  final Key? key;

  final Future<bool> Function()? signOutForRecovery;

  @override
  String toString() {
    return 'OnboardingV2ShellRouteArgs{key: $key, signOutForRecovery: $signOutForRecovery}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OnboardingV2ShellRouteArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [PremiumPage]
class PremiumRoute extends PageRouteInfo<void> {
  const PremiumRoute({List<PageRouteInfo>? children})
    : super(PremiumRoute.name, initialChildren: children);

  static const String name = 'PremiumRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const PremiumPage();
    },
  );
}

/// generated route for
/// [ProfileScreen]
class ProfileRoute extends PageRouteInfo<ProfileRouteArgs> {
  ProfileRoute({
    Key? key,
    String? profileIdentifier,
    List<PageRouteInfo>? children,
  }) : super(
         ProfileRoute.name,
         args: ProfileRouteArgs(key: key, profileIdentifier: profileIdentifier),
         rawPathParams: {'identifier': profileIdentifier},
         initialChildren: children,
       );

  static const String name = 'ProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ProfileRouteArgs>(
        orElse: () => ProfileRouteArgs(
          profileIdentifier: pathParams.optString('identifier'),
        ),
      );
      return ProfileScreen(
        key: args.key,
        profileIdentifier: args.profileIdentifier,
      );
    },
  );
}

class ProfileRouteArgs {
  const ProfileRouteArgs({this.key, this.profileIdentifier});

  final Key? key;

  final String? profileIdentifier;

  @override
  String toString() {
    return 'ProfileRouteArgs{key: $key, profileIdentifier: $profileIdentifier}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProfileRouteArgs) return false;
    return key == other.key && profileIdentifier == other.profileIdentifier;
  }

  @override
  int get hashCode => key.hashCode ^ profileIdentifier.hashCode;
}

/// generated route for
/// [QuickTileSettingsScreen]
class QuickTileSettingsRoute extends PageRouteInfo<void> {
  const QuickTileSettingsRoute({List<PageRouteInfo>? children})
    : super(QuickTileSettingsRoute.name, initialChildren: children);

  static const String name = 'QuickTileSettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const QuickTileSettingsScreen();
    },
  );
}

/// generated route for
/// [ReviewPhotoPreview]
class ReviewPhotoPreviewRoute
    extends PageRouteInfo<ReviewPhotoPreviewRouteArgs> {
  ReviewPhotoPreviewRoute({
    Key? key,
    required String url,
    required String thumbUrl,
    bool file = false,
    List<PageRouteInfo>? children,
  }) : super(
         ReviewPhotoPreviewRoute.name,
         args: ReviewPhotoPreviewRouteArgs(
           key: key,
           url: url,
           thumbUrl: thumbUrl,
           file: file,
         ),
         initialChildren: children,
       );

  static const String name = 'ReviewPhotoPreviewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReviewPhotoPreviewRouteArgs>();
      return ReviewPhotoPreview(
        key: args.key,
        url: args.url,
        thumbUrl: args.thumbUrl,
        file: args.file,
      );
    },
  );
}

class ReviewPhotoPreviewRouteArgs {
  const ReviewPhotoPreviewRouteArgs({
    this.key,
    required this.url,
    required this.thumbUrl,
    this.file = false,
  });

  final Key? key;

  final String url;

  final String thumbUrl;

  final bool file;

  @override
  String toString() {
    return 'ReviewPhotoPreviewRouteArgs{key: $key, url: $url, thumbUrl: $thumbUrl, file: $file}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ReviewPhotoPreviewRouteArgs) return false;
    return key == other.key &&
        url == other.url &&
        thumbUrl == other.thumbUrl &&
        file == other.file;
  }

  @override
  int get hashCode =>
      key.hashCode ^ url.hashCode ^ thumbUrl.hashCode ^ file.hashCode;
}

/// generated route for
/// [ReviewScreen]
class ReviewRoute extends PageRouteInfo<void> {
  const ReviewRoute({List<PageRouteInfo>? children})
    : super(ReviewRoute.name, initialChildren: children);

  static const String name = 'ReviewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ReviewScreen();
    },
  );
}

/// generated route for
/// [RewardsPage]
class RewardsRoute extends PageRouteInfo<RewardsRouteArgs> {
  RewardsRoute({
    Key? key,
    bool showBack = true,
    bool scrollToEarn = false,
    List<PageRouteInfo>? children,
  }) : super(
         RewardsRoute.name,
         args: RewardsRouteArgs(
           key: key,
           showBack: showBack,
           scrollToEarn: scrollToEarn,
         ),
         initialChildren: children,
       );

  static const String name = 'RewardsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<RewardsRouteArgs>(
        orElse: () => const RewardsRouteArgs(),
      );
      return RewardsPage(
        key: args.key,
        showBack: args.showBack,
        scrollToEarn: args.scrollToEarn,
      );
    },
  );
}

class RewardsRouteArgs {
  const RewardsRouteArgs({
    this.key,
    this.showBack = true,
    this.scrollToEarn = false,
  });

  final Key? key;

  final bool showBack;

  final bool scrollToEarn;

  @override
  String toString() {
    return 'RewardsRouteArgs{key: $key, showBack: $showBack, scrollToEarn: $scrollToEarn}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RewardsRouteArgs) return false;
    return key == other.key &&
        showBack == other.showBack &&
        scrollToEarn == other.scrollToEarn;
  }

  @override
  int get hashCode => key.hashCode ^ showBack.hashCode ^ scrollToEarn.hashCode;
}

/// generated route for
/// [RewardsTabPage]
class RewardsTabRoute extends PageRouteInfo<void> {
  const RewardsTabRoute({List<PageRouteInfo>? children})
    : super(RewardsTabRoute.name, initialChildren: children);

  static const String name = 'RewardsTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RewardsTabPage();
    },
  );
}

/// generated route for
/// [SearchScreen]
class SearchRoute extends PageRouteInfo<void> {
  const SearchRoute({List<PageRouteInfo>? children})
    : super(SearchRoute.name, initialChildren: children);

  static const String name = 'SearchRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SearchScreen();
    },
  );
}

/// generated route for
/// [SearchTabPage]
class SearchTabRoute extends PageRouteInfo<void> {
  const SearchTabRoute({List<PageRouteInfo>? children})
    : super(SearchTabRoute.name, initialChildren: children);

  static const String name = 'SearchTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SearchTabPage();
    },
  );
}

/// generated route for
/// [SettingsScreen]
class SettingsRoute extends PageRouteInfo<void> {
  const SettingsRoute({List<PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SettingsScreen();
    },
  );
}

/// generated route for
/// [SharePrismScreen]
class SharePrismRoute extends PageRouteInfo<void> {
  const SharePrismRoute({List<PageRouteInfo>? children})
    : super(SharePrismRoute.name, initialChildren: children);

  static const String name = 'SharePrismRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return SharePrismScreen();
    },
  );
}

/// generated route for
/// [ShopPage]
class ShopRoute extends PageRouteInfo<void> {
  const ShopRoute({List<PageRouteInfo>? children})
    : super(ShopRoute.name, initialChildren: children);

  static const String name = 'ShopRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ShopPage();
    },
  );
}

/// generated route for
/// [SpinWheelPage]
class SpinWheelRoute extends PageRouteInfo<SpinWheelRouteArgs> {
  SpinWheelRoute({
    Key? key,
    SpinFunction? spin,
    ValueListenable<SpinWheelStatus>? status,
    ValueListenable<int>? balance,
    List<PageRouteInfo>? children,
  }) : super(
         SpinWheelRoute.name,
         args: SpinWheelRouteArgs(
           key: key,
           spin: spin,
           status: status,
           balance: balance,
         ),
         initialChildren: children,
       );

  static const String name = 'SpinWheelRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SpinWheelRouteArgs>(
        orElse: () => const SpinWheelRouteArgs(),
      );
      return SpinWheelPage(
        key: args.key,
        spin: args.spin,
        status: args.status,
        balance: args.balance,
      );
    },
  );
}

class SpinWheelRouteArgs {
  const SpinWheelRouteArgs({this.key, this.spin, this.status, this.balance});

  final Key? key;

  final SpinFunction? spin;

  final ValueListenable<SpinWheelStatus>? status;

  final ValueListenable<int>? balance;

  @override
  String toString() {
    return 'SpinWheelRouteArgs{key: $key, spin: $spin, status: $status, balance: $balance}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SpinWheelRouteArgs) return false;
    return key == other.key &&
        spin == other.spin &&
        status == other.status &&
        balance == other.balance;
  }

  @override
  int get hashCode =>
      key.hashCode ^ spin.hashCode ^ status.hashCode ^ balance.hashCode;
}

/// generated route for
/// [SplashWidget]
class SplashWidgetRoute extends PageRouteInfo<void> {
  const SplashWidgetRoute({List<PageRouteInfo>? children})
    : super(SplashWidgetRoute.name, initialChildren: children);

  static const String name = 'SplashWidgetRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SplashWidget();
    },
  );
}

/// generated route for
/// [SwipeReviewScreen]
class SwipeReviewRoute extends PageRouteInfo<void> {
  const SwipeReviewRoute({List<PageRouteInfo>? children})
    : super(SwipeReviewRoute.name, initialChildren: children);

  static const String name = 'SwipeReviewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SwipeReviewScreen();
    },
  );
}

/// generated route for
/// [ThemeView]
class ThemeViewRoute extends PageRouteInfo<void> {
  const ThemeViewRoute({List<PageRouteInfo>? children})
    : super(ThemeViewRoute.name, initialChildren: children);

  static const String name = 'ThemeViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return ThemeView();
    },
  );
}

/// generated route for
/// [UploadWallScreen]
class UploadWallRoute extends PageRouteInfo<UploadWallRouteArgs> {
  UploadWallRoute({
    Key? key,
    required File image,
    UploadBatch? batch,
    Size? imageSizeForTesting,
    Future<void> Function()? prepareImageForTesting,
    Future<GitHubContent> Function({required bool isThumbnail})?
    uploadFileForTesting,
    Future<void> Function({required String path, required String sha})?
    deleteFileForTesting,
    Future<WallSubmissionResult> Function()? createRecordForTesting,
    Future<WallSubmissionResult> Function({
      required String id,
      required SubmissionMetadata metadata,
    })?
    createRecordWithMetadataForTesting,
    Future<void> Function()? presentPaywallForTesting,
    DateTime Function()? nowForTesting,
    UploadDraftStore? draftStoreForTesting,
    List<PageRouteInfo>? children,
  }) : super(
         UploadWallRoute.name,
         args: UploadWallRouteArgs(
           key: key,
           image: image,
           batch: batch,
           imageSizeForTesting: imageSizeForTesting,
           prepareImageForTesting: prepareImageForTesting,
           uploadFileForTesting: uploadFileForTesting,
           deleteFileForTesting: deleteFileForTesting,
           createRecordForTesting: createRecordForTesting,
           createRecordWithMetadataForTesting:
               createRecordWithMetadataForTesting,
           presentPaywallForTesting: presentPaywallForTesting,
           nowForTesting: nowForTesting,
           draftStoreForTesting: draftStoreForTesting,
         ),
         initialChildren: children,
       );

  static const String name = 'UploadWallRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<UploadWallRouteArgs>();
      return UploadWallScreen(
        key: args.key,
        image: args.image,
        batch: args.batch,
        imageSizeForTesting: args.imageSizeForTesting,
        prepareImageForTesting: args.prepareImageForTesting,
        uploadFileForTesting: args.uploadFileForTesting,
        deleteFileForTesting: args.deleteFileForTesting,
        createRecordForTesting: args.createRecordForTesting,
        createRecordWithMetadataForTesting:
            args.createRecordWithMetadataForTesting,
        presentPaywallForTesting: args.presentPaywallForTesting,
        nowForTesting: args.nowForTesting,
        draftStoreForTesting: args.draftStoreForTesting,
      );
    },
  );
}

class UploadWallRouteArgs {
  const UploadWallRouteArgs({
    this.key,
    required this.image,
    this.batch,
    this.imageSizeForTesting,
    this.prepareImageForTesting,
    this.uploadFileForTesting,
    this.deleteFileForTesting,
    this.createRecordForTesting,
    this.createRecordWithMetadataForTesting,
    this.presentPaywallForTesting,
    this.nowForTesting,
    this.draftStoreForTesting,
  });

  final Key? key;

  final File image;

  final UploadBatch? batch;

  final Size? imageSizeForTesting;

  final Future<void> Function()? prepareImageForTesting;

  final Future<GitHubContent> Function({required bool isThumbnail})?
  uploadFileForTesting;

  final Future<void> Function({required String path, required String sha})?
  deleteFileForTesting;

  final Future<WallSubmissionResult> Function()? createRecordForTesting;

  final Future<WallSubmissionResult> Function({
    required String id,
    required SubmissionMetadata metadata,
  })?
  createRecordWithMetadataForTesting;

  final Future<void> Function()? presentPaywallForTesting;

  final DateTime Function()? nowForTesting;

  final UploadDraftStore? draftStoreForTesting;

  @override
  String toString() {
    return 'UploadWallRouteArgs{key: $key, image: $image, batch: $batch, imageSizeForTesting: $imageSizeForTesting, prepareImageForTesting: $prepareImageForTesting, uploadFileForTesting: $uploadFileForTesting, deleteFileForTesting: $deleteFileForTesting, createRecordForTesting: $createRecordForTesting, createRecordWithMetadataForTesting: $createRecordWithMetadataForTesting, presentPaywallForTesting: $presentPaywallForTesting, nowForTesting: $nowForTesting, draftStoreForTesting: $draftStoreForTesting}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UploadWallRouteArgs) return false;
    return key == other.key &&
        image == other.image &&
        batch == other.batch &&
        imageSizeForTesting == other.imageSizeForTesting &&
        draftStoreForTesting == other.draftStoreForTesting;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      image.hashCode ^
      batch.hashCode ^
      imageSizeForTesting.hashCode ^
      draftStoreForTesting.hashCode;
}

/// generated route for
/// [UserSearch]
class UserSearchRoute extends PageRouteInfo<void> {
  const UserSearchRoute({List<PageRouteInfo>? children})
    : super(UserSearchRoute.name, initialChildren: children);

  static const String name = 'UserSearchRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const UserSearch();
    },
  );
}

/// generated route for
/// [WallpaperDetailScreen]
class WallpaperDetailRoute extends PageRouteInfo<WallpaperDetailRouteArgs> {
  WallpaperDetailRoute({
    Key? key,
    FeedItemEntity? entity,
    String? wallId,
    WallpaperSource? source,
    String? thumbnailUrl,
    AnalyticsSurfaceValue analyticsSurface =
        AnalyticsSurfaceValue.wallpaperScreen,
    String? heroTag,
    File? localFile,
    String? requestId,
    WallpaperFeed? feed,
    List<PageRouteInfo>? children,
  }) : super(
         WallpaperDetailRoute.name,
         args: WallpaperDetailRouteArgs(
           key: key,
           entity: entity,
           wallId: wallId,
           source: source,
           thumbnailUrl: thumbnailUrl,
           analyticsSurface: analyticsSurface,
           heroTag: heroTag,
           localFile: localFile,
           requestId: requestId,
           feed: feed,
         ),
         initialChildren: children,
       );

  static const String name = 'WallpaperDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WallpaperDetailRouteArgs>(
        orElse: () => const WallpaperDetailRouteArgs(),
      );
      return WrappedRoute(
        child: WallpaperDetailScreen(
          key: args.key,
          entity: args.entity,
          wallId: args.wallId,
          source: args.source,
          thumbnailUrl: args.thumbnailUrl,
          analyticsSurface: args.analyticsSurface,
          heroTag: args.heroTag,
          localFile: args.localFile,
          requestId: args.requestId,
          feed: args.feed,
        ),
      );
    },
  );
}

class WallpaperDetailRouteArgs {
  const WallpaperDetailRouteArgs({
    this.key,
    this.entity,
    this.wallId,
    this.source,
    this.thumbnailUrl,
    this.analyticsSurface = AnalyticsSurfaceValue.wallpaperScreen,
    this.heroTag,
    this.localFile,
    this.requestId,
    this.feed,
  });

  final Key? key;

  final FeedItemEntity? entity;

  final String? wallId;

  final WallpaperSource? source;

  final String? thumbnailUrl;

  final AnalyticsSurfaceValue analyticsSurface;

  final String? heroTag;

  final File? localFile;

  final String? requestId;

  final WallpaperFeed? feed;

  @override
  String toString() {
    return 'WallpaperDetailRouteArgs{key: $key, entity: $entity, wallId: $wallId, source: $source, thumbnailUrl: $thumbnailUrl, analyticsSurface: $analyticsSurface, heroTag: $heroTag, localFile: $localFile, requestId: $requestId, feed: $feed}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WallpaperDetailRouteArgs) return false;
    return key == other.key &&
        entity == other.entity &&
        wallId == other.wallId &&
        source == other.source &&
        thumbnailUrl == other.thumbnailUrl &&
        analyticsSurface == other.analyticsSurface &&
        heroTag == other.heroTag &&
        localFile == other.localFile &&
        requestId == other.requestId &&
        feed == other.feed;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      entity.hashCode ^
      wallId.hashCode ^
      source.hashCode ^
      thumbnailUrl.hashCode ^
      analyticsSurface.hashCode ^
      heroTag.hashCode ^
      localFile.hashCode ^
      requestId.hashCode ^
      feed.hashCode;
}

/// generated route for
/// [WallpaperFilterScreen]
class WallpaperFilterRoute extends PageRouteInfo<WallpaperFilterRouteArgs> {
  WallpaperFilterRoute({
    required String filePath,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         WallpaperFilterRoute.name,
         args: WallpaperFilterRouteArgs(filePath: filePath, key: key),
         initialChildren: children,
       );

  static const String name = 'WallpaperFilterRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WallpaperFilterRouteArgs>();
      return WallpaperFilterScreen(filePath: args.filePath, key: args.key);
    },
  );
}

class WallpaperFilterRouteArgs {
  const WallpaperFilterRouteArgs({required this.filePath, this.key});

  final String filePath;

  final Key? key;

  @override
  String toString() {
    return 'WallpaperFilterRouteArgs{filePath: $filePath, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WallpaperFilterRouteArgs) return false;
    return filePath == other.filePath && key == other.key;
  }

  @override
  int get hashCode => filePath.hashCode ^ key.hashCode;
}

/// generated route for
/// [WallpaperHistoryScreen]
class WallpaperHistoryRoute extends PageRouteInfo<void> {
  const WallpaperHistoryRoute({List<PageRouteInfo>? children})
    : super(WallpaperHistoryRoute.name, initialChildren: children);

  static const String name = 'WallpaperHistoryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const WallpaperHistoryScreen();
    },
  );
}

/// generated route for
/// [WallpaperPositionScreen]
class WallpaperPositionRoute extends PageRouteInfo<WallpaperPositionRouteArgs> {
  WallpaperPositionRoute({
    Key? key,
    required String imageUrl,
    String? thumbnailUrl,
    String? entryPoint,
    String? requestId,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
    List<PageRouteInfo>? children,
  }) : super(
         WallpaperPositionRoute.name,
         args: WallpaperPositionRouteArgs(
           key: key,
           imageUrl: imageUrl,
           thumbnailUrl: thumbnailUrl,
           entryPoint: entryPoint,
           requestId: requestId,
           wallpaperId: wallpaperId,
           wallpaperSource: wallpaperSource,
         ),
         initialChildren: children,
       );

  static const String name = 'WallpaperPositionRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WallpaperPositionRouteArgs>();
      return WallpaperPositionScreen(
        key: args.key,
        imageUrl: args.imageUrl,
        thumbnailUrl: args.thumbnailUrl,
        entryPoint: args.entryPoint,
        requestId: args.requestId,
        wallpaperId: args.wallpaperId,
        wallpaperSource: args.wallpaperSource,
      );
    },
  );
}

class WallpaperPositionRouteArgs {
  const WallpaperPositionRouteArgs({
    this.key,
    required this.imageUrl,
    this.thumbnailUrl,
    this.entryPoint,
    this.requestId,
    this.wallpaperId,
    this.wallpaperSource,
  });

  final Key? key;

  final String imageUrl;

  final String? thumbnailUrl;

  final String? entryPoint;

  final String? requestId;

  final String? wallpaperId;

  final WallpaperSource? wallpaperSource;

  @override
  String toString() {
    return 'WallpaperPositionRouteArgs{key: $key, imageUrl: $imageUrl, thumbnailUrl: $thumbnailUrl, entryPoint: $entryPoint, requestId: $requestId, wallpaperId: $wallpaperId, wallpaperSource: $wallpaperSource}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WallpaperPositionRouteArgs) return false;
    return key == other.key &&
        imageUrl == other.imageUrl &&
        thumbnailUrl == other.thumbnailUrl &&
        entryPoint == other.entryPoint &&
        requestId == other.requestId &&
        wallpaperId == other.wallpaperId &&
        wallpaperSource == other.wallpaperSource;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      imageUrl.hashCode ^
      thumbnailUrl.hashCode ^
      entryPoint.hashCode ^
      requestId.hashCode ^
      wallpaperId.hashCode ^
      wallpaperSource.hashCode;
}

/// generated route for
/// [WotdArchivePage]
class WotdArchiveRoute extends PageRouteInfo<void> {
  const WotdArchiveRoute({List<PageRouteInfo>? children})
    : super(WotdArchiveRoute.name, initialChildren: children);

  static const String name = 'WotdArchiveRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const WotdArchivePage());
    },
  );
}
