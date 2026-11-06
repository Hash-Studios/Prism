import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
import 'package:Prism/features/moods/views/mood_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';

extension FollowedTopicCopy on FollowedTopic {
  String title(AppLocalizations l10n) => wallMood?.title(l10n) ?? categoryDisplayName(id, l10n);

  String kindLabel(AppLocalizations l10n) => switch (kind) {
    TopicKind.category => l10n.topicKindCategory,
    TopicKind.mood => l10n.topicKindMood,
  };

  /// The topic page. [source] tells mood analytics where the user came from.
  PageRouteInfo<Object?> route({required String source}) => switch (kind) {
    TopicKind.category => CollectionViewRoute(collectionName: 'category:${Uri.encodeComponent(id)}'),
    TopicKind.mood => MoodRoute(moodId: id, source: source),
  };
}
