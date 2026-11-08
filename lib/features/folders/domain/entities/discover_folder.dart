import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/features/folders/domain/section_suggester.dart';

/// The tabs of the discover page. [wire] is the analytics value.
enum FolderDiscoverTab {
  trending('trending'),
  fresh('new'),
  likeYourSaves('like_your_saves');

  const FolderDiscoverTab(this.wire);

  final String wire;
}

/// What the app reports to the discover ranking. The server decides if it counts.
enum FolderSignal { open, save }

/// One entry of `folderTrending/current`: a public folder, ready for a card. The server writes it once a day.
class DiscoverFolder {
  const DiscoverFolder({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.itemCount,
    this.ownerName = '',
    this.ownerPhoto = '',
    this.covers = const <String>[],
    this.followerCount = 0,
    this.moods = const <String>[],
    this.categories = const <String>[],
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerPhoto;
  final String name;
  final int itemCount;

  /// Up to 4 thumbnail URLs, newest first.
  final List<String> covers;
  final int followerCount;

  /// The top mood ids and categories of the folder's newest walls. "Like your saves" ranks on them.
  final List<String> moods;
  final List<String> categories;
}

/// The two lists the server writes. "Like your saves" is ranked on the device from both.
class FolderDiscoverLists {
  const FolderDiscoverLists({this.trending = const <DiscoverFolder>[], this.fresh = const <DiscoverFolder>[]});

  static const FolderDiscoverLists empty = FolderDiscoverLists();

  final List<DiscoverFolder> trending;
  final List<DiscoverFolder> fresh;

  bool get isEmpty => trending.isEmpty && fresh.isEmpty;

  /// Leaves out the viewer's own folders and folders of creators the viewer blocked.
  FolderDiscoverLists visibleTo(String viewerId, BlockedCreators blocked) {
    bool shows(DiscoverFolder f) => f.ownerId != viewerId && !BlockedCreatorsFilter.hidesCreatorUid(f.ownerId, blocked);
    return FolderDiscoverLists(
      trending: trending.where(shows).toList(growable: false),
      fresh: fresh.where(shows).toList(growable: false),
    );
  }

  /// Both lists, trending first, each folder once.
  List<DiscoverFolder> get candidates {
    final Set<String> seen = <String>{};
    return <DiscoverFolder>[...trending, ...fresh].where((f) => seen.add(f.id)).toList(growable: false);
  }
}

/// "Like your saves": the [candidates] that share moods or categories with the user's recent saves.
///
/// [saves] are the traits of the user's saves, newest first. Only the newest [maxSaves] count, and each older save
/// counts a little less. A folder scores the weight of each mood and category it shares. Folders that share nothing
/// are left out. Ties keep the candidate order, and an owner shows at most twice, as on the server lists.
List<DiscoverFolder> rankLikeYourSaves(List<DiscoverFolder> candidates, List<WallTraits> saves) {
  const int maxSaves = 30;
  const double decay = 0.95;
  const int perOwner = 2;
  final Map<String, double> moods = <String, double>{};
  final Map<String, double> categories = <String, double>{};
  double weight = 1;
  for (final WallTraits save in saves.take(maxSaves)) {
    for (final mood in save.moods) {
      moods[mood.id] = (moods[mood.id] ?? 0) + weight;
    }
    if (save.category.isNotEmpty && save.category != 'General') {
      categories[save.category] = (categories[save.category] ?? 0) + weight;
    }
    weight *= decay;
  }
  final List<(DiscoverFolder, double, int)> scored = <(DiscoverFolder, double, int)>[
    for (final (int i, DiscoverFolder folder) in candidates.indexed)
      (
        folder,
        folder.moods.fold<double>(0, (sum, m) => sum + (moods[m] ?? 0)) +
            folder.categories.fold<double>(0, (sum, c) => sum + (categories[c] ?? 0)),
        i,
      ),
  ]..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$3.compareTo(b.$3));
  final Map<String, int> owners = <String, int>{};
  final List<DiscoverFolder> ranked = <DiscoverFolder>[];
  for (final (DiscoverFolder folder, double score, _) in scored) {
    final int shown = owners[folder.ownerId] ?? 0;
    if (score <= 0 || shown >= perOwner) continue;
    owners[folder.ownerId] = shown + 1;
    ranked.add(folder);
  }
  return ranked;
}
