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
/// [AiTabPage]
class AiTabRoute extends PageRouteInfo<void> {
  const AiTabRoute({List<PageRouteInfo>? children})
    : super(AiTabRoute.name, initialChildren: children);

  static const String name = 'AiTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AiTabPage();
    },
  );
}

/// generated route for
/// [CoinTransactionsScreen]
class CoinTransactionsRoute extends PageRouteInfo<void> {
  const CoinTransactionsRoute({List<PageRouteInfo>? children})
    : super(CoinTransactionsRoute.name, initialChildren: children);

  static const String name = 'CoinTransactionsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const CoinTransactionsScreen();
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
    List<PageRouteInfo>? children,
  }) : super(
         ColorRoute.name,
         args: ColorRouteArgs(key: key, hexColor: hexColor),
         initialChildren: children,
       );

  static const String name = 'ColorRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ColorRouteArgs>();
      return ColorScreen(key: args.key, hexColor: args.hexColor);
    },
  );
}

class ColorRouteArgs {
  const ColorRouteArgs({this.key, required this.hexColor});

  final Key? key;

  final String hexColor;

  @override
  String toString() {
    return 'ColorRouteArgs{key: $key, hexColor: $hexColor}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ColorRouteArgs) return false;
    return key == other.key && hexColor == other.hexColor;
  }

  @override
  int get hashCode => key.hashCode ^ hexColor.hashCode;
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
    Key? key,
    required FirestoreDocument setupDoc,
    List<PageRouteInfo>? children,
  }) : super(
         EditSetupReviewRoute.name,
         args: EditSetupReviewRouteArgs(key: key, setupDoc: setupDoc),
         initialChildren: children,
       );

  static const String name = 'EditSetupReviewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EditSetupReviewRouteArgs>();
      return EditSetupReviewScreen(key: args.key, setupDoc: args.setupDoc);
    },
  );
}

class EditSetupReviewRouteArgs {
  const EditSetupReviewRouteArgs({this.key, required this.setupDoc});

  final Key? key;

  final FirestoreDocument setupDoc;

  @override
  String toString() {
    return 'EditSetupReviewRouteArgs{key: $key, setupDoc: $setupDoc}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EditSetupReviewRouteArgs) return false;
    return key == other.key && setupDoc == other.setupDoc;
  }

  @override
  int get hashCode => key.hashCode ^ setupDoc.hashCode;
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
/// [FavSetupViewScreen]
class FavSetupViewRoute extends PageRouteInfo<FavSetupViewRouteArgs> {
  FavSetupViewRoute({
    Key? key,
    required int setupIndex,
    List<PageRouteInfo>? children,
  }) : super(
         FavSetupViewRoute.name,
         args: FavSetupViewRouteArgs(key: key, setupIndex: setupIndex),
         initialChildren: children,
       );

  static const String name = 'FavSetupViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FavSetupViewRouteArgs>();
      return FavSetupViewScreen(key: args.key, setupIndex: args.setupIndex);
    },
  );
}

class FavSetupViewRouteArgs {
  const FavSetupViewRouteArgs({this.key, required this.setupIndex});

  final Key? key;

  final int setupIndex;

  @override
  String toString() {
    return 'FavSetupViewRouteArgs{key: $key, setupIndex: $setupIndex}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FavSetupViewRouteArgs) return false;
    return key == other.key && setupIndex == other.setupIndex;
  }

  @override
  int get hashCode => key.hashCode ^ setupIndex.hashCode;
}

/// generated route for
/// [FavWallpaperViewScreen]
class FavWallpaperViewRoute extends PageRouteInfo<FavWallpaperViewRouteArgs> {
  FavWallpaperViewRoute({
    Key? key,
    required int wallIndex,
    required String thumbnailUrl,
    List<PageRouteInfo>? children,
  }) : super(
         FavWallpaperViewRoute.name,
         args: FavWallpaperViewRouteArgs(
           key: key,
           wallIndex: wallIndex,
           thumbnailUrl: thumbnailUrl,
         ),
         initialChildren: children,
       );

  static const String name = 'FavWallpaperViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FavWallpaperViewRouteArgs>();
      return FavWallpaperViewScreen(
        key: args.key,
        wallIndex: args.wallIndex,
        thumbnailUrl: args.thumbnailUrl,
      );
    },
  );
}

class FavWallpaperViewRouteArgs {
  const FavWallpaperViewRouteArgs({
    this.key,
    required this.wallIndex,
    required this.thumbnailUrl,
  });

  final Key? key;

  final int wallIndex;

  final String thumbnailUrl;

  @override
  String toString() {
    return 'FavWallpaperViewRouteArgs{key: $key, wallIndex: $wallIndex, thumbnailUrl: $thumbnailUrl}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FavWallpaperViewRouteArgs) return false;
    return key == other.key &&
        wallIndex == other.wallIndex &&
        thumbnailUrl == other.thumbnailUrl;
  }

  @override
  int get hashCode => key.hashCode ^ wallIndex.hashCode ^ thumbnailUrl.hashCode;
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
/// [OptionalInfo3]
class OptionalInfo3Route extends PageRouteInfo<OptionalInfo3RouteArgs> {
  OptionalInfo3Route({
    required String heading,
    required String subheading,
    required bool showSkip,
    String? skipText,
    required String? doneText,
    List<PageRouteInfo>? children,
  }) : super(
         OptionalInfo3Route.name,
         args: OptionalInfo3RouteArgs(
           heading: heading,
           subheading: subheading,
           showSkip: showSkip,
           skipText: skipText,
           doneText: doneText,
         ),
         initialChildren: children,
       );

  static const String name = 'OptionalInfo3Route';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<OptionalInfo3RouteArgs>();
      return OptionalInfo3(
        heading: args.heading,
        subheading: args.subheading,
        showSkip: args.showSkip,
        skipText: args.skipText,
        doneText: args.doneText,
      );
    },
  );
}

class OptionalInfo3RouteArgs {
  const OptionalInfo3RouteArgs({
    required this.heading,
    required this.subheading,
    required this.showSkip,
    this.skipText,
    required this.doneText,
  });

  final String heading;

  final String subheading;

  final bool showSkip;

  final String? skipText;

  final String? doneText;

  @override
  String toString() {
    return 'OptionalInfo3RouteArgs{heading: $heading, subheading: $subheading, showSkip: $showSkip, skipText: $skipText, doneText: $doneText}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OptionalInfo3RouteArgs) return false;
    return heading == other.heading &&
        subheading == other.subheading &&
        showSkip == other.showSkip &&
        skipText == other.skipText &&
        doneText == other.doneText;
  }

  @override
  int get hashCode =>
      heading.hashCode ^
      subheading.hashCode ^
      showSkip.hashCode ^
      skipText.hashCode ^
      doneText.hashCode;
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
/// [ProfileSetupViewScreen]
class ProfileSetupViewRoute extends PageRouteInfo<ProfileSetupViewRouteArgs> {
  ProfileSetupViewRoute({
    Key? key,
    required int setupIndex,
    List<PageRouteInfo>? children,
  }) : super(
         ProfileSetupViewRoute.name,
         args: ProfileSetupViewRouteArgs(key: key, setupIndex: setupIndex),
         initialChildren: children,
       );

  static const String name = 'ProfileSetupViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProfileSetupViewRouteArgs>();
      return ProfileSetupViewScreen(key: args.key, setupIndex: args.setupIndex);
    },
  );
}

class ProfileSetupViewRouteArgs {
  const ProfileSetupViewRouteArgs({this.key, required this.setupIndex});

  final Key? key;

  final int setupIndex;

  @override
  String toString() {
    return 'ProfileSetupViewRouteArgs{key: $key, setupIndex: $setupIndex}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProfileSetupViewRouteArgs) return false;
    return key == other.key && setupIndex == other.setupIndex;
  }

  @override
  int get hashCode => key.hashCode ^ setupIndex.hashCode;
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
    Key? key,
    required int wallIndex,
    required String thumbnailUrl,
    List<PageRouteInfo>? children,
  }) : super(
         ProfileWallViewRoute.name,
         args: ProfileWallViewRouteArgs(
           key: key,
           wallIndex: wallIndex,
           thumbnailUrl: thumbnailUrl,
         ),
         initialChildren: children,
       );

  static const String name = 'ProfileWallViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProfileWallViewRouteArgs>();
      return ProfileWallViewScreen(
        key: args.key,
        wallIndex: args.wallIndex,
        thumbnailUrl: args.thumbnailUrl,
      );
    },
  );
}

class ProfileWallViewRouteArgs {
  const ProfileWallViewRouteArgs({
    this.key,
    required this.wallIndex,
    required this.thumbnailUrl,
  });

  final Key? key;

  final int wallIndex;

  final String thumbnailUrl;

  @override
  String toString() {
    return 'ProfileWallViewRouteArgs{key: $key, wallIndex: $wallIndex, thumbnailUrl: $thumbnailUrl}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProfileWallViewRouteArgs) return false;
    return key == other.key &&
        wallIndex == other.wallIndex &&
        thumbnailUrl == other.thumbnailUrl;
  }

  @override
  int get hashCode => key.hashCode ^ wallIndex.hashCode ^ thumbnailUrl.hashCode;
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
    Key? key,
    required WallpaperSource source,
    required String query,
    required int index,
    required String link,
    List<PageRouteInfo>? children,
  }) : super(
         SearchWallpaperRoute.name,
         args: SearchWallpaperRouteArgs(
           key: key,
           source: source,
           query: query,
           index: index,
           link: link,
         ),
         initialChildren: children,
       );

  static const String name = 'SearchWallpaperRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SearchWallpaperRouteArgs>();
      return SearchWallpaperScreen(
        key: args.key,
        source: args.source,
        query: args.query,
        index: args.index,
        link: args.link,
      );
    },
  );
}

class SearchWallpaperRouteArgs {
  const SearchWallpaperRouteArgs({
    this.key,
    required this.source,
    required this.query,
    required this.index,
    required this.link,
  });

  final Key? key;

  final WallpaperSource source;

  final String query;

  final int index;

  final String link;

  @override
  String toString() {
    return 'SearchWallpaperRouteArgs{key: $key, source: $source, query: $query, index: $index, link: $link}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchWallpaperRouteArgs) return false;
    return key == other.key &&
        source == other.source &&
        query == other.query &&
        index == other.index &&
        link == other.link;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      source.hashCode ^
      query.hashCode ^
      index.hashCode ^
      link.hashCode;
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
  SetupViewRoute({
    Key? key,
    required int setupIndex,
    List<PageRouteInfo>? children,
  }) : super(
         SetupViewRoute.name,
         args: SetupViewRouteArgs(key: key, setupIndex: setupIndex),
         initialChildren: children,
       );

  static const String name = 'SetupViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SetupViewRouteArgs>();
      return SetupViewScreen(key: args.key, setupIndex: args.setupIndex);
    },
  );
}

class SetupViewRouteArgs {
  const SetupViewRouteArgs({this.key, required this.setupIndex});

  final Key? key;

  final int setupIndex;

  @override
  String toString() {
    return 'SetupViewRouteArgs{key: $key, setupIndex: $setupIndex}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SetupViewRouteArgs) return false;
    return key == other.key && setupIndex == other.setupIndex;
  }

  @override
  int get hashCode => key.hashCode ^ setupIndex.hashCode;
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
  ShareSetupViewRoute({
    Key? key,
    required String setupName,
    String thumbnailUrl = '',
    List<PageRouteInfo>? children,
  }) : super(
         ShareSetupViewRoute.name,
         args: ShareSetupViewRouteArgs(
           key: key,
           setupName: setupName,
           thumbnailUrl: thumbnailUrl,
         ),
         rawPathParams: {'setupName': setupName},
         initialChildren: children,
       );

  static const String name = 'ShareSetupViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ShareSetupViewRouteArgs>(
        orElse: () => ShareSetupViewRouteArgs(
          setupName: pathParams.getString('setupName'),
        ),
      );
      return ShareSetupViewScreen(
        key: args.key,
        setupName: args.setupName,
        thumbnailUrl: args.thumbnailUrl,
      );
    },
  );
}

class ShareSetupViewRouteArgs {
  const ShareSetupViewRouteArgs({
    this.key,
    required this.setupName,
    this.thumbnailUrl = '',
  });

  final Key? key;

  final String setupName;

  final String thumbnailUrl;

  @override
  String toString() {
    return 'ShareSetupViewRouteArgs{key: $key, setupName: $setupName, thumbnailUrl: $thumbnailUrl}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ShareSetupViewRouteArgs) return false;
    return key == other.key &&
        setupName == other.setupName &&
        thumbnailUrl == other.thumbnailUrl;
  }

  @override
  int get hashCode => key.hashCode ^ setupName.hashCode ^ thumbnailUrl.hashCode;
}

/// generated route for
/// [ShareWallpaperViewScreen]
class ShareWallpaperViewRoute
    extends PageRouteInfo<ShareWallpaperViewRouteArgs> {
  ShareWallpaperViewRoute({
    Key? key,
    required String wallId,
    required WallpaperSource source,
    required String wallpaperUrl,
    required String thumbnailUrl,
    List<PageRouteInfo>? children,
  }) : super(
         ShareWallpaperViewRoute.name,
         args: ShareWallpaperViewRouteArgs(
           key: key,
           wallId: wallId,
           source: source,
           wallpaperUrl: wallpaperUrl,
           thumbnailUrl: thumbnailUrl,
         ),
         initialChildren: children,
       );

  static const String name = 'ShareWallpaperViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ShareWallpaperViewRouteArgs>();
      return ShareWallpaperViewScreen(
        key: args.key,
        wallId: args.wallId,
        source: args.source,
        wallpaperUrl: args.wallpaperUrl,
        thumbnailUrl: args.thumbnailUrl,
      );
    },
  );
}

class ShareWallpaperViewRouteArgs {
  const ShareWallpaperViewRouteArgs({
    this.key,
    required this.wallId,
    required this.source,
    required this.wallpaperUrl,
    required this.thumbnailUrl,
  });

  final Key? key;

  final String wallId;

  final WallpaperSource source;

  final String wallpaperUrl;

  final String thumbnailUrl;

  @override
  String toString() {
    return 'ShareWallpaperViewRouteArgs{key: $key, wallId: $wallId, source: $source, wallpaperUrl: $wallpaperUrl, thumbnailUrl: $thumbnailUrl}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ShareWallpaperViewRouteArgs) return false;
    return key == other.key &&
        wallId == other.wallId &&
        source == other.source &&
        wallpaperUrl == other.wallpaperUrl &&
        thumbnailUrl == other.thumbnailUrl;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      wallId.hashCode ^
      source.hashCode ^
      wallpaperUrl.hashCode ^
      thumbnailUrl.hashCode;
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
      return const UpgradeScreen();
    },
  );
}

/// generated route for
/// [UploadSetupScreen]
class UploadSetupRoute extends PageRouteInfo<UploadSetupRouteArgs> {
  UploadSetupRoute({
    Key? key,
    required File image,
    List<PageRouteInfo>? children,
  }) : super(
         UploadSetupRoute.name,
         args: UploadSetupRouteArgs(key: key, image: image),
         initialChildren: children,
       );

  static const String name = 'UploadSetupRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<UploadSetupRouteArgs>();
      return UploadSetupScreen(key: args.key, image: args.image);
    },
  );
}

class UploadSetupRouteArgs {
  const UploadSetupRouteArgs({this.key, required this.image});

  final Key? key;

  final File image;

  @override
  String toString() {
    return 'UploadSetupRouteArgs{key: $key, image: $image}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UploadSetupRouteArgs) return false;
    return key == other.key && image == other.image;
  }

  @override
  int get hashCode => key.hashCode ^ image.hashCode;
}

/// generated route for
/// [UploadWallScreen]
class UploadWallRoute extends PageRouteInfo<UploadWallRouteArgs> {
  UploadWallRoute({
    Key? key,
    required File image,
    required bool fromSetupRoute,
    List<PageRouteInfo>? children,
  }) : super(
         UploadWallRoute.name,
         args: UploadWallRouteArgs(
           key: key,
           image: image,
           fromSetupRoute: fromSetupRoute,
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
        fromSetupRoute: args.fromSetupRoute,
      );
    },
  );
}

class UploadWallRouteArgs {
  const UploadWallRouteArgs({
    this.key,
    required this.image,
    required this.fromSetupRoute,
  });

  final Key? key;

  final File image;

  final bool fromSetupRoute;

  @override
  String toString() {
    return 'UploadWallRouteArgs{key: $key, image: $image, fromSetupRoute: $fromSetupRoute}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UploadWallRouteArgs) return false;
    return key == other.key &&
        image == other.image &&
        fromSetupRoute == other.fromSetupRoute;
  }

  @override
  int get hashCode => key.hashCode ^ image.hashCode ^ fromSetupRoute.hashCode;
}

/// generated route for
/// [UserProfileSetupViewScreen]
class UserProfileSetupViewRoute
    extends PageRouteInfo<UserProfileSetupViewRouteArgs> {
  UserProfileSetupViewRoute({
    Key? key,
    required int setupIndex,
    List<PageRouteInfo>? children,
  }) : super(
         UserProfileSetupViewRoute.name,
         args: UserProfileSetupViewRouteArgs(key: key, setupIndex: setupIndex),
         initialChildren: children,
       );

  static const String name = 'UserProfileSetupViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<UserProfileSetupViewRouteArgs>();
      return UserProfileSetupViewScreen(
        key: args.key,
        setupIndex: args.setupIndex,
      );
    },
  );
}

class UserProfileSetupViewRouteArgs {
  const UserProfileSetupViewRouteArgs({this.key, required this.setupIndex});

  final Key? key;

  final int setupIndex;

  @override
  String toString() {
    return 'UserProfileSetupViewRouteArgs{key: $key, setupIndex: $setupIndex}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UserProfileSetupViewRouteArgs) return false;
    return key == other.key && setupIndex == other.setupIndex;
  }

  @override
  int get hashCode => key.hashCode ^ setupIndex.hashCode;
}

/// generated route for
/// [UserProfileWallViewScreen]
class UserProfileWallViewRoute
    extends PageRouteInfo<UserProfileWallViewRouteArgs> {
  UserProfileWallViewRoute({
    Key? key,
    required int wallIndex,
    required String thumbnailUrl,
    List<PageRouteInfo>? children,
  }) : super(
         UserProfileWallViewRoute.name,
         args: UserProfileWallViewRouteArgs(
           key: key,
           wallIndex: wallIndex,
           thumbnailUrl: thumbnailUrl,
         ),
         initialChildren: children,
       );

  static const String name = 'UserProfileWallViewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<UserProfileWallViewRouteArgs>();
      return UserProfileWallViewScreen(
        key: args.key,
        wallIndex: args.wallIndex,
        thumbnailUrl: args.thumbnailUrl,
      );
    },
  );
}

class UserProfileWallViewRouteArgs {
  const UserProfileWallViewRouteArgs({
    this.key,
    required this.wallIndex,
    required this.thumbnailUrl,
  });

  final Key? key;

  final int wallIndex;

  final String thumbnailUrl;

  @override
  String toString() {
    return 'UserProfileWallViewRouteArgs{key: $key, wallIndex: $wallIndex, thumbnailUrl: $thumbnailUrl}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UserProfileWallViewRouteArgs) return false;
    return key == other.key &&
        wallIndex == other.wallIndex &&
        thumbnailUrl == other.thumbnailUrl;
  }

  @override
  int get hashCode => key.hashCode ^ wallIndex.hashCode ^ thumbnailUrl.hashCode;
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
    Image? image,
    Image? finalImage,
    String? filename,
    String? finalFilename,
    List<PageRouteInfo>? children,
  }) : super(
         WallpaperFilterRoute.name,
         args: WallpaperFilterRouteArgs(
           key: key,
           image: image,
           finalImage: finalImage,
           filename: filename,
           finalFilename: finalFilename,
         ),
         initialChildren: children,
       );

  static const String name = 'WallpaperFilterRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WallpaperFilterRouteArgs>(
        orElse: () => const WallpaperFilterRouteArgs(),
      );
      return WallpaperFilterScreen(
        key: args.key,
        image: args.image,
        finalImage: args.finalImage,
        filename: args.filename,
        finalFilename: args.finalFilename,
      );
    },
  );
}

class WallpaperFilterRouteArgs {
  const WallpaperFilterRouteArgs({
    this.key,
    this.image,
    this.finalImage,
    this.filename,
    this.finalFilename,
  });

  final Key? key;

  final Image? image;

  final Image? finalImage;

  final String? filename;

  final String? finalFilename;

  @override
  String toString() {
    return 'WallpaperFilterRouteArgs{key: $key, image: $image, finalImage: $finalImage, filename: $filename, finalFilename: $finalFilename}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WallpaperFilterRouteArgs) return false;
    return key == other.key &&
        image == other.image &&
        finalImage == other.finalImage &&
        filename == other.filename &&
        finalFilename == other.finalFilename;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      image.hashCode ^
      finalImage.hashCode ^
      filename.hashCode ^
      finalFilename.hashCode;
}

/// generated route for
/// [WallpaperScreen]
class WallpaperRoute extends PageRouteInfo<WallpaperRouteArgs> {
  WallpaperRoute({
    Key? key,
    required WallpaperSource source,
    required String link,
    int? index,
    FeedItemEntity? item,
    WallOfTheDayEntity? wotdWall,
    List<PageRouteInfo>? children,
  }) : super(
         WallpaperRoute.name,
         args: WallpaperRouteArgs(
           key: key,
           source: source,
           link: link,
           index: index,
           item: item,
           wotdWall: wotdWall,
         ),
         initialChildren: children,
       );

  static const String name = 'WallpaperRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WallpaperRouteArgs>();
      return WallpaperScreen(
        key: args.key,
        source: args.source,
        link: args.link,
        index: args.index,
        item: args.item,
        wotdWall: args.wotdWall,
      );
    },
  );
}

class WallpaperRouteArgs {
  const WallpaperRouteArgs({
    this.key,
    required this.source,
    required this.link,
    this.index,
    this.item,
    this.wotdWall,
  });

  final Key? key;

  final WallpaperSource source;

  final String link;

  final int? index;

  final FeedItemEntity? item;

  final WallOfTheDayEntity? wotdWall;

  @override
  String toString() {
    return 'WallpaperRouteArgs{key: $key, source: $source, link: $link, index: $index, item: $item, wotdWall: $wotdWall}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WallpaperRouteArgs) return false;
    return key == other.key &&
        source == other.source &&
        link == other.link &&
        index == other.index &&
        item == other.item &&
        wotdWall == other.wotdWall;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      source.hashCode ^
      link.hashCode ^
      index.hashCode ^
      item.hashCode ^
      wotdWall.hashCode;
}
