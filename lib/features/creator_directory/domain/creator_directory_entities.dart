import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

/// One `creatorDirectory/{uid}` doc. The server job writes it from the public profile and the creator's public walls.
class CreatorDirectoryEntry {
  const CreatorDirectoryEntry({
    required this.uid,
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.followerCount,
    required this.wallIds,
    required this.categories,
    required this.similar,
    required this.rank,
  });

  factory CreatorDirectoryEntry.fromMap(Map<String, Object?> data, String docId) {
    List<String> strings(Object? raw) =>
        raw is List ? raw.whereType<String>().toList(growable: false) : const <String>[];
    final Object? walls = data['walls'];
    final Object? followers = data['followerCount'];
    final Object? rank = data['rank'];
    return CreatorDirectoryEntry(
      uid: docId,
      name: data['name'] is String ? data['name']! as String : '',
      username: data['username'] is String ? data['username']! as String : '',
      photoUrl: data['profilePhoto'] is String ? data['profilePhoto']! as String : '',
      followerCount: followers is num ? followers.toInt() : 0,
      wallIds: walls is List
          ? walls.whereType<Map<Object?, Object?>>().map((w) => w['id']).whereType<String>().toList(growable: false)
          : const <String>[],
      categories: strings(data['categories']),
      similar: strings(data['similar']),
      rank: rank is num ? rank.toInt() : 0,
    );
  }

  final String uid;
  final String name;
  final String username;
  final String photoUrl;
  final int followerCount;
  final List<String> wallIds;
  final List<String> categories;
  final List<String> similar;
  final int rank;

  String get displayName => name.isNotEmpty ? name : username;
}

/// A directory entry with its top walls loaded, so a tap opens the wallpaper and swipes through the rest.
class DirectoryCreator {
  const DirectoryCreator({required this.entry, required this.walls});

  final CreatorDirectoryEntry entry;
  final List<PrismWallpaper> walls;

  String get uid => entry.uid;
}

class CreatorPage {
  const CreatorPage({required this.creators, required this.nextRank});

  final List<DirectoryCreator> creators;

  /// The rank to continue after, or null at the end of the directory.
  final int? nextRank;
}

typedef FollowedByPerson = ({String name, String photoUrl});

/// People the viewer follows who also follow a creator. [people] holds up to 3 of the [count].
class FollowedBy {
  const FollowedBy({required this.count, required this.people});

  static const FollowedBy none = FollowedBy(count: 0, people: <FollowedByPerson>[]);

  final int count;
  final List<FollowedByPerson> people;
}
