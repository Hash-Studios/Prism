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
class AboutRoute extends PageRouteInfo<void> {
  const AboutRoute({List<PageRouteInfo>? children})
    : super(AboutRoute.name, initialChildren: children);

  static const String name = 'AboutRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AboutScreen();
    },
  );
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
    Future<({bool dismissed, ShareFormatValue format})> Function(
      BuildContext, {
      required String imageUrl,
      required String link,
      String? contextLine,
    })?
    shareCard,
    List<PageRouteInfo>? children,
  }) : super(
         AiTabRoute.name,
         args: AiTabRouteArgs(
           key: key,
           repository: repository,
           submitForTesting: submitForTesting,
           shareCard: shareCard,
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
        shareCard: args.shareCard,
      );
    },
  );
}

class AiTabRouteArgs {
  const AiTabRouteArgs({
    this.key,
    this.repository,
    this.submitForTesting,
    this.shareCard,
  });

  final Key? key;

  final AiGenerationRepositoryImpl? repository;

  final Future<WallSubmissionResult> Function()? submitForTesting;

  final Future<({bool dismissed, ShareFormatValue format})> Function(
    BuildContext, {
    required String imageUrl,
    required String link,
    String? contextLine,
  })?
  shareCard;

  @override
  String toString() {
    return 'AiTabRouteArgs{key: $key, repository: $repository, submitForTesting: $submitForTesting, shareCard: $shareCard}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiTabRouteArgs) return false;
    return key == other.key && repository == other.repository;
  }

  @override
  int get hashCode => key.hashCode ^ repository.hashCode;
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
/// [ColorScreen]
class ColorRoute extends PageRouteInfo<ColorRouteArgs> {
  ColorRoute({
    Key? key,
    required String hexColor,
    required String name,
    List<PageRouteInfo>? children,
  }) : super(
         ColorRoute.name,
         args: ColorRouteArgs(key: key, hexColor: hexColor, name: name),
         initialChildren: children,
       );

  static const String name = 'ColorRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ColorRouteArgs>();
      return ColorScreen(
        key: args.key,
        hexColor: args.hexColor,
        name: args.name,
      );
    },
  );
}

class ColorRouteArgs {
  const ColorRouteArgs({this.key, required this.hexColor, required this.name});

  final Key? key;

  final String hexColor;

  final String name;

  @override
  String toString() {
    return 'ColorRouteArgs{key: $key, hexColor: $hexColor, name: $name}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ColorRouteArgs) return false;
    return key == other.key && hexColor == other.hexColor && name == other.name;
  }

  @override
  int get hashCode => key.hashCode ^ hexColor.hashCode ^ name.hashCode;
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
class DebugPanelRoute extends PageRouteInfo<void> {
  const DebugPanelRoute({List<PageRouteInfo>? children})
    : super(DebugPanelRoute.name, initialChildren: children);

  static const String name = 'DebugPanelRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DebugPanelPage();
    },
  );
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
  EditWallRoute({Key? key, required File image, List<PageRouteInfo>? children})
    : super(
        EditWallRoute.name,
        args: EditWallRouteArgs(key: key, image: image),
        initialChildren: children,
      );

  static const String name = 'EditWallRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EditWallRouteArgs>();
      return EditWallScreen(key: args.key, image: args.image);
    },
  );
}

class EditWallRouteArgs {
  const EditWallRouteArgs({this.key, required this.image});

  final Key? key;

  final File image;

  @override
  String toString() {
    return 'EditWallRouteArgs{key: $key, image: $image}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EditWallRouteArgs) return false;
    return key == other.key && image == other.image;
  }

  @override
  int get hashCode => key.hashCode ^ image.hashCode;
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
    required List<String> followers,
    List<PageRouteInfo>? children,
  }) : super(
         FollowersRoute.name,
         args: FollowersRouteArgs(key: key, followers: followers),
         initialChildren: children,
       );

  static const String name = 'FollowersRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FollowersRouteArgs>();
      return FollowersScreen(key: args.key, followers: args.followers);
    },
  );
}

class FollowersRouteArgs {
  const FollowersRouteArgs({this.key, required this.followers});

  final Key? key;

  final List<String> followers;

  @override
  String toString() {
    return 'FollowersRouteArgs{key: $key, followers: $followers}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FollowersRouteArgs) return false;
    return key == other.key &&
        const ListEquality<String>().equals(followers, other.followers);
  }

  @override
  int get hashCode =>
      key.hashCode ^ const ListEquality<String>().hash(followers);
}

/// generated route for
/// [FollowingListScreen]
class FollowingListRoute extends PageRouteInfo<FollowingListRouteArgs> {
  FollowingListRoute({
    Key? key,
    required List<String> following,
    List<PageRouteInfo>? children,
  }) : super(
         FollowingListRoute.name,
         args: FollowingListRouteArgs(key: key, following: following),
         initialChildren: children,
       );

  static const String name = 'FollowingListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FollowingListRouteArgs>();
      return FollowingListScreen(key: args.key, following: args.following);
    },
  );
}

class FollowingListRouteArgs {
  const FollowingListRouteArgs({this.key, required this.following});

  final Key? key;

  final List<String> following;

  @override
  String toString() {
    return 'FollowingListRouteArgs{key: $key, following: $following}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FollowingListRouteArgs) return false;
    return key == other.key &&
        const ListEquality<String>().equals(following, other.following);
  }

  @override
  int get hashCode =>
      key.hashCode ^ const ListEquality<String>().hash(following);
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
class OnboardingV2ShellRoute extends PageRouteInfo<void> {
  const OnboardingV2ShellRoute({List<PageRouteInfo>? children})
    : super(OnboardingV2ShellRoute.name, initialChildren: children);

  static const String name = 'OnboardingV2ShellRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const OnboardingV2Shell();
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
  RewardsRoute({Key? key, bool showBack = true, List<PageRouteInfo>? children})
    : super(
        RewardsRoute.name,
        args: RewardsRouteArgs(key: key, showBack: showBack),
        initialChildren: children,
      );

  static const String name = 'RewardsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<RewardsRouteArgs>(
        orElse: () => const RewardsRouteArgs(),
      );
      return RewardsPage(key: args.key, showBack: args.showBack);
    },
  );
}

class RewardsRouteArgs {
  const RewardsRouteArgs({this.key, this.showBack = true});

  final Key? key;

  final bool showBack;

  @override
  String toString() {
    return 'RewardsRouteArgs{key: $key, showBack: $showBack}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RewardsRouteArgs) return false;
    return key == other.key && showBack == other.showBack;
  }

  @override
  int get hashCode => key.hashCode ^ showBack.hashCode;
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
    Future<void> Function()? prepareImageForTesting,
    Future<GitHubContent> Function({required bool isThumbnail})?
    uploadFileForTesting,
    Future<void> Function({required String path, required String sha})?
    deleteFileForTesting,
    Future<WallSubmissionResult> Function()? createRecordForTesting,
    List<PageRouteInfo>? children,
  }) : super(
         UploadWallRoute.name,
         args: UploadWallRouteArgs(
           key: key,
           image: image,
           prepareImageForTesting: prepareImageForTesting,
           uploadFileForTesting: uploadFileForTesting,
           deleteFileForTesting: deleteFileForTesting,
           createRecordForTesting: createRecordForTesting,
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
        prepareImageForTesting: args.prepareImageForTesting,
        uploadFileForTesting: args.uploadFileForTesting,
        deleteFileForTesting: args.deleteFileForTesting,
        createRecordForTesting: args.createRecordForTesting,
      );
    },
  );
}

class UploadWallRouteArgs {
  const UploadWallRouteArgs({
    this.key,
    required this.image,
    this.prepareImageForTesting,
    this.uploadFileForTesting,
    this.deleteFileForTesting,
    this.createRecordForTesting,
  });

  final Key? key;

  final File image;

  final Future<void> Function()? prepareImageForTesting;

  final Future<GitHubContent> Function({required bool isThumbnail})?
  uploadFileForTesting;

  final Future<void> Function({required String path, required String sha})?
  deleteFileForTesting;

  final Future<WallSubmissionResult> Function()? createRecordForTesting;

  @override
  String toString() {
    return 'UploadWallRouteArgs{key: $key, image: $image, prepareImageForTesting: $prepareImageForTesting, uploadFileForTesting: $uploadFileForTesting, deleteFileForTesting: $deleteFileForTesting, createRecordForTesting: $createRecordForTesting}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UploadWallRouteArgs) return false;
    return key == other.key && image == other.image;
  }

  @override
  int get hashCode => key.hashCode ^ image.hashCode;
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
  });

  final Key? key;

  final FeedItemEntity? entity;

  final String? wallId;

  final WallpaperSource? source;

  final String? thumbnailUrl;

  final AnalyticsSurfaceValue analyticsSurface;

  final String? heroTag;

  final File? localFile;

  @override
  String toString() {
    return 'WallpaperDetailRouteArgs{key: $key, entity: $entity, wallId: $wallId, source: $source, thumbnailUrl: $thumbnailUrl, analyticsSurface: $analyticsSurface, heroTag: $heroTag, localFile: $localFile}';
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
        localFile == other.localFile;
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
      localFile.hashCode;
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
