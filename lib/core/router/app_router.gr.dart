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
      return AboutScreen();
    },
  );
}

/// generated route for
/// [AdminReviewScreen]
class AdminReviewRoute extends PageRouteInfo<void> {
  const AdminReviewRoute({List<PageRouteInfo>? children})
      : super(AdminReviewRoute.name, initialChildren: children);

  static const String name = 'AdminReviewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AdminReviewScreen();
    },
  );
}

/// generated route for
/// [AdsNotLoading]
class AdsNotLoadingRoute extends PageRouteInfo<void> {
  const AdsNotLoadingRoute({List<PageRouteInfo>? children})
      : super(AdsNotLoadingRoute.name, initialChildren: children);

  static const String name = 'AdsNotLoadingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AdsNotLoading();
    },
  );
}

/// generated route for
/// [CollectionViewScreen]
class CollectionViewRoute extends PageRouteInfo<CollectionViewRouteArgs> {
  CollectionViewRoute({
    Key? key,
    required List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          CollectionViewRoute.name,
          args: CollectionViewRouteArgs(key: key, arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'CollectionViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CollectionViewRouteArgs>();
      return CollectionViewScreen(key: args.key, arguments: args.arguments);
    },
  );
}

class CollectionViewRouteArgs {
  const CollectionViewRouteArgs({this.key, required this.arguments});

  final Key? key;

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'CollectionViewRouteArgs{key: $key, arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CollectionViewRouteArgs) return false;
    return key == other.key &&
        const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode =>
      key.hashCode ^ const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [ColorScreen]
class ColorRoute extends PageRouteInfo<ColorRouteArgs> {
  ColorRoute({
    Key? key,
    required List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          ColorRoute.name,
          args: ColorRouteArgs(key: key, arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'ColorRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ColorRouteArgs>();
      return ColorScreen(key: args.key, arguments: args.arguments);
    },
  );
}

class ColorRouteArgs {
  const ColorRouteArgs({this.key, required this.arguments});

  final Key? key;

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'ColorRouteArgs{key: $key, arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ColorRouteArgs) return false;
    return key == other.key &&
        const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode =>
      key.hashCode ^ const ListEquality<dynamic>().hash(arguments);
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
    required List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          DownloadWallpaperRoute.name,
          args: DownloadWallpaperRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'DownloadWallpaperRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DownloadWallpaperRouteArgs>();
      return DownloadWallpaperScreen(arguments: args.arguments);
    },
  );
}

class DownloadWallpaperRouteArgs {
  const DownloadWallpaperRouteArgs({required this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'DownloadWallpaperRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DownloadWallpaperRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [DraftSetupScreen]
class DraftSetupRoute extends PageRouteInfo<void> {
  const DraftSetupRoute({List<PageRouteInfo>? children})
      : super(DraftSetupRoute.name, initialChildren: children);

  static const String name = 'DraftSetupRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return DraftSetupScreen();
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
/// [EditSetupReviewScreen]
class EditSetupReviewRoute extends PageRouteInfo<EditSetupReviewRouteArgs> {
  EditSetupReviewRoute({
    List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          EditSetupReviewRoute.name,
          args: EditSetupReviewRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'EditSetupReviewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EditSetupReviewRouteArgs>(
        orElse: () => const EditSetupReviewRouteArgs(),
      );
      return EditSetupReviewScreen(arguments: args.arguments);
    },
  );
}

class EditSetupReviewRouteArgs {
  const EditSetupReviewRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'EditSetupReviewRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EditSetupReviewRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [EditWallScreen]
class EditWallRoute extends PageRouteInfo<EditWallRouteArgs> {
  EditWallRoute({List<dynamic>? arguments, List<PageRouteInfo>? children})
      : super(
          EditWallRoute.name,
          args: EditWallRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'EditWallRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EditWallRouteArgs>(
        orElse: () => const EditWallRouteArgs(),
      );
      return EditWallScreen(arguments: args.arguments);
    },
  );
}

class EditWallRouteArgs {
  const EditWallRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'EditWallRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EditWallRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [FavSetupViewScreen]
class FavSetupViewRoute extends PageRouteInfo<FavSetupViewRouteArgs> {
  FavSetupViewRoute({List<dynamic>? arguments, List<PageRouteInfo>? children})
      : super(
          FavSetupViewRoute.name,
          args: FavSetupViewRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'FavSetupViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FavSetupViewRouteArgs>(
        orElse: () => const FavSetupViewRouteArgs(),
      );
      return FavSetupViewScreen(arguments: args.arguments);
    },
  );
}

class FavSetupViewRouteArgs {
  const FavSetupViewRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'FavSetupViewRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FavSetupViewRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [FavWallpaperViewScreen]
class FavWallpaperViewRoute extends PageRouteInfo<FavWallpaperViewRouteArgs> {
  FavWallpaperViewRoute({
    List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          FavWallpaperViewRoute.name,
          args: FavWallpaperViewRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'FavWallpaperViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FavWallpaperViewRouteArgs>(
        orElse: () => const FavWallpaperViewRouteArgs(),
      );
      return FavWallpaperViewScreen(arguments: args.arguments);
    },
  );
}

class FavWallpaperViewRouteArgs {
  const FavWallpaperViewRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'FavWallpaperViewRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FavWallpaperViewRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [FavouriteSetupScreen]
class FavouriteSetupRoute extends PageRouteInfo<void> {
  const FavouriteSetupRoute({List<PageRouteInfo>? children})
      : super(FavouriteSetupRoute.name, initialChildren: children);

  static const String name = 'FavouriteSetupRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const FavouriteSetupScreen();
    },
  );
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
/// [FollowersScreen]
class FollowersRoute extends PageRouteInfo<FollowersRouteArgs> {
  FollowersRoute({
    required List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          FollowersRoute.name,
          args: FollowersRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'FollowersRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FollowersRouteArgs>();
      return FollowersScreen(arguments: args.arguments);
    },
  );
}

class FollowersRouteArgs {
  const FollowersRouteArgs({required this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'FollowersRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FollowersRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
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
/// [NotificationScreen]
class NotificationRoute extends PageRouteInfo<void> {
  const NotificationRoute({List<PageRouteInfo>? children})
      : super(NotificationRoute.name, initialChildren: children);

  static const String name = 'NotificationRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return NotificationScreen();
    },
  );
}

/// generated route for
/// [OnboardingScreen]
class OnboardingRoute extends PageRouteInfo<void> {
  const OnboardingRoute({List<PageRouteInfo>? children})
      : super(OnboardingRoute.name, initialChildren: children);

  static const String name = 'OnboardingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return OnboardingScreen();
    },
  );
}

/// generated route for
/// [ProfileScreen]
class ProfileRoute extends PageRouteInfo<ProfileRouteArgs> {
  ProfileRoute({List<dynamic>? arguments, List<PageRouteInfo>? children})
      : super(
          ProfileRoute.name,
          args: ProfileRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'ProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProfileRouteArgs>(
        orElse: () => const ProfileRouteArgs(),
      );
      return ProfileScreen(arguments: args.arguments);
    },
  );
}

class ProfileRouteArgs {
  const ProfileRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'ProfileRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProfileRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [ProfileSetupViewScreen]
class ProfileSetupViewRoute extends PageRouteInfo<ProfileSetupViewRouteArgs> {
  ProfileSetupViewRoute({
    List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          ProfileSetupViewRoute.name,
          args: ProfileSetupViewRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'ProfileSetupViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProfileSetupViewRouteArgs>(
        orElse: () => const ProfileSetupViewRouteArgs(),
      );
      return ProfileSetupViewScreen(arguments: args.arguments);
    },
  );
}

class ProfileSetupViewRouteArgs {
  const ProfileSetupViewRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'ProfileSetupViewRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProfileSetupViewRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [ProfileTabPage]
class ProfileTabRoute extends PageRouteInfo<void> {
  const ProfileTabRoute({List<PageRouteInfo>? children})
      : super(ProfileTabRoute.name, initialChildren: children);

  static const String name = 'ProfileTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfileTabPage();
    },
  );
}

/// generated route for
/// [ProfileWallViewScreen]
class ProfileWallViewRoute extends PageRouteInfo<ProfileWallViewRouteArgs> {
  ProfileWallViewRoute({
    List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          ProfileWallViewRoute.name,
          args: ProfileWallViewRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'ProfileWallViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProfileWallViewRouteArgs>(
        orElse: () => const ProfileWallViewRouteArgs(),
      );
      return ProfileWallViewScreen(arguments: args.arguments);
    },
  );
}

class ProfileWallViewRouteArgs {
  const ProfileWallViewRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'ProfileWallViewRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProfileWallViewRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
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
      return ReviewScreen();
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
      return SearchScreen();
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
/// [SearchWallpaperScreen]
class SearchWallpaperRoute extends PageRouteInfo<SearchWallpaperRouteArgs> {
  SearchWallpaperRoute({
    required List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          SearchWallpaperRoute.name,
          args: SearchWallpaperRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'SearchWallpaperRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SearchWallpaperRouteArgs>();
      return SearchWallpaperScreen(arguments: args.arguments);
    },
  );
}

class SearchWallpaperRouteArgs {
  const SearchWallpaperRouteArgs({required this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'SearchWallpaperRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchWallpaperRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
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
/// [SetupGuidelinesScreen]
class SetupGuidelinesRoute extends PageRouteInfo<void> {
  const SetupGuidelinesRoute({List<PageRouteInfo>? children})
      : super(SetupGuidelinesRoute.name, initialChildren: children);

  static const String name = 'SetupGuidelinesRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return SetupGuidelinesScreen();
    },
  );
}

/// generated route for
/// [SetupScreen]
class SetupRoute extends PageRouteInfo<void> {
  const SetupRoute({List<PageRouteInfo>? children})
      : super(SetupRoute.name, initialChildren: children);

  static const String name = 'SetupRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SetupScreen();
    },
  );
}

/// generated route for
/// [SetupViewScreen]
class SetupViewRoute extends PageRouteInfo<SetupViewRouteArgs> {
  SetupViewRoute({List<dynamic>? arguments, List<PageRouteInfo>? children})
      : super(
          SetupViewRoute.name,
          args: SetupViewRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'SetupViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SetupViewRouteArgs>(
        orElse: () => const SetupViewRouteArgs(),
      );
      return SetupViewScreen(arguments: args.arguments);
    },
  );
}

class SetupViewRouteArgs {
  const SetupViewRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'SetupViewRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SetupViewRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [SetupsTabPage]
class SetupsTabRoute extends PageRouteInfo<void> {
  const SetupsTabRoute({List<PageRouteInfo>? children})
      : super(SetupsTabRoute.name, initialChildren: children);

  static const String name = 'SetupsTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SetupsTabPage();
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
/// [ShareSetupViewScreen]
class ShareSetupViewRoute extends PageRouteInfo<ShareSetupViewRouteArgs> {
  ShareSetupViewRoute({List<dynamic>? arguments, List<PageRouteInfo>? children})
      : super(
          ShareSetupViewRoute.name,
          args: ShareSetupViewRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'ShareSetupViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ShareSetupViewRouteArgs>(
        orElse: () => const ShareSetupViewRouteArgs(),
      );
      return ShareSetupViewScreen(arguments: args.arguments);
    },
  );
}

class ShareSetupViewRouteArgs {
  const ShareSetupViewRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'ShareSetupViewRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ShareSetupViewRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [ShareWallpaperViewScreen]
class ShareWallpaperViewRoute
    extends PageRouteInfo<ShareWallpaperViewRouteArgs> {
  ShareWallpaperViewRoute({
    List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          ShareWallpaperViewRoute.name,
          args: ShareWallpaperViewRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'ShareWallpaperViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ShareWallpaperViewRouteArgs>(
        orElse: () => const ShareWallpaperViewRouteArgs(),
      );
      return ShareWallpaperViewScreen(arguments: args.arguments);
    },
  );
}

class ShareWallpaperViewRouteArgs {
  const ShareWallpaperViewRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'ShareWallpaperViewRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ShareWallpaperViewRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
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
/// [UpgradeScreen]
class UpgradeRoute extends PageRouteInfo<void> {
  const UpgradeRoute({List<PageRouteInfo>? children})
      : super(UpgradeRoute.name, initialChildren: children);

  static const String name = 'UpgradeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return UpgradeScreen();
    },
  );
}

/// generated route for
/// [UploadSetupScreen]
class UploadSetupRoute extends PageRouteInfo<UploadSetupRouteArgs> {
  UploadSetupRoute({List<dynamic>? arguments, List<PageRouteInfo>? children})
      : super(
          UploadSetupRoute.name,
          args: UploadSetupRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'UploadSetupRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<UploadSetupRouteArgs>(
        orElse: () => const UploadSetupRouteArgs(),
      );
      return UploadSetupScreen(arguments: args.arguments);
    },
  );
}

class UploadSetupRouteArgs {
  const UploadSetupRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'UploadSetupRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UploadSetupRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [UploadWallScreen]
class UploadWallRoute extends PageRouteInfo<UploadWallRouteArgs> {
  UploadWallRoute({List<dynamic>? arguments, List<PageRouteInfo>? children})
      : super(
          UploadWallRoute.name,
          args: UploadWallRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'UploadWallRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<UploadWallRouteArgs>(
        orElse: () => const UploadWallRouteArgs(),
      );
      return UploadWallScreen(arguments: args.arguments);
    },
  );
}

class UploadWallRouteArgs {
  const UploadWallRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'UploadWallRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UploadWallRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [UserProfileSetupViewScreen]
class UserProfileSetupViewRoute
    extends PageRouteInfo<UserProfileSetupViewRouteArgs> {
  UserProfileSetupViewRoute({
    List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          UserProfileSetupViewRoute.name,
          args: UserProfileSetupViewRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'UserProfileSetupViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<UserProfileSetupViewRouteArgs>(
        orElse: () => const UserProfileSetupViewRouteArgs(),
      );
      return UserProfileSetupViewScreen(arguments: args.arguments);
    },
  );
}

class UserProfileSetupViewRouteArgs {
  const UserProfileSetupViewRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'UserProfileSetupViewRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UserProfileSetupViewRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [UserProfileWallViewScreen]
class UserProfileWallViewRoute
    extends PageRouteInfo<UserProfileWallViewRouteArgs> {
  UserProfileWallViewRoute({
    List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          UserProfileWallViewRoute.name,
          args: UserProfileWallViewRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'UserProfileWallViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<UserProfileWallViewRouteArgs>(
        orElse: () => const UserProfileWallViewRouteArgs(),
      );
      return UserProfileWallViewScreen(arguments: args.arguments);
    },
  );
}

class UserProfileWallViewRouteArgs {
  const UserProfileWallViewRouteArgs({this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'UserProfileWallViewRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UserProfileWallViewRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
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
/// [WallpaperFilterScreen]
class WallpaperFilterRoute extends PageRouteInfo<WallpaperFilterRouteArgs> {
  WallpaperFilterRoute({
    Key? key,
    List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          WallpaperFilterRoute.name,
          args: WallpaperFilterRouteArgs(key: key, arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'WallpaperFilterRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WallpaperFilterRouteArgs>(
        orElse: () => const WallpaperFilterRouteArgs(),
      );
      return WallpaperFilterScreen(key: args.key, arguments: args.arguments);
    },
  );
}

class WallpaperFilterRouteArgs {
  const WallpaperFilterRouteArgs({this.key, this.arguments});

  final Key? key;

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'WallpaperFilterRouteArgs{key: $key, arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WallpaperFilterRouteArgs) return false;
    return key == other.key &&
        const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode =>
      key.hashCode ^ const ListEquality<dynamic>().hash(arguments);
}

/// generated route for
/// [WallpaperScreen]
class WallpaperRoute extends PageRouteInfo<WallpaperRouteArgs> {
  WallpaperRoute({
    required List<dynamic>? arguments,
    List<PageRouteInfo>? children,
  }) : super(
          WallpaperRoute.name,
          args: WallpaperRouteArgs(arguments: arguments),
          initialChildren: children,
        );

  static const String name = 'WallpaperRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WallpaperRouteArgs>();
      return WallpaperScreen(arguments: args.arguments);
    },
  );
}

class WallpaperRouteArgs {
  const WallpaperRouteArgs({required this.arguments});

  final List<dynamic>? arguments;

  @override
  String toString() {
    return 'WallpaperRouteArgs{arguments: $arguments}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WallpaperRouteArgs) return false;
    return const ListEquality<dynamic>().equals(arguments, other.arguments);
  }

  @override
  int get hashCode => const ListEquality<dynamic>().hash(arguments);
}
