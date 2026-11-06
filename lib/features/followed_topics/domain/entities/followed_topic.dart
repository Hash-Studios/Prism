import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:flutter/foundation.dart';

enum TopicKind { category, mood }

/// A category or Home mood that a signed-in user follows, to get one daily push when new Prism walls land in it.
///
/// Only topics that get new Prism walls exist: a category the upload classifier writes, or a mood. A stock-only
/// category (Pexels or Wallhaven) has no topic. `functions/src/topicDigest.ts` keeps the same list as `TOPICS`.
@immutable
final class FollowedTopic {
  const FollowedTopic._(this.kind, this.id);

  /// The server and the Firestore rules refuse more.
  static const int maxFollowed = 20;

  final TopicKind kind;

  /// The category name, or the mood id.
  final String id;

  /// The value stored in `usersv2/{uid}/private/session.followedTopics`.
  String get key => '${kind.name}:$id';

  /// Null for a category that gets no Prism walls. [name] matches in any letter case; the topic keeps the
  /// classifier's spelling.
  static FollowedTopic? category(String name) {
    final String wanted = name.trim().toLowerCase();
    for (final String known in prismClassifierCategories) {
      if (known.toLowerCase() == wanted) return FollowedTopic._(TopicKind.category, known);
    }
    return null;
  }

  factory FollowedTopic.mood(WallMood mood) => FollowedTopic._(TopicKind.mood, mood.id);

  /// Null for a key that is not a known topic, for example one that a newer app version added.
  static FollowedTopic? parse(Object? key) {
    if (key is! String) return null;
    final int colon = key.indexOf(':');
    if (colon < 0) return null;
    final String id = key.substring(colon + 1);
    return switch (key.substring(0, colon)) {
      'category' => prismClassifierCategories.contains(id) ? FollowedTopic._(TopicKind.category, id) : null,
      'mood' => switch (WallMood.parse(id)) {
        final WallMood mood => FollowedTopic.mood(mood),
        null => null,
      },
      _ => null,
    };
  }

  WallMood? get wallMood => kind == TopicKind.mood ? WallMood.parse(id) : null;

  @override
  bool operator ==(Object other) => other is FollowedTopic && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => key;
}
