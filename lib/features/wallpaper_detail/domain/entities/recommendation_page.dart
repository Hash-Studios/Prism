import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:equatable/equatable.dart';

enum RecommendationKind { related, discovery, offline }

enum RecommendationProvider { wallhaven, pexels }

sealed class RecommendationCursor extends Equatable {
  const RecommendationCursor();
}

final class PrismRecommendationCursor extends RecommendationCursor {
  const PrismRecommendationCursor(this.documentId);
  final String documentId;
  @override
  List<Object?> get props => [documentId];
}

final class ExternalRecommendationCursor extends RecommendationCursor {
  const ExternalRecommendationCursor(this.page, {this.provider = RecommendationProvider.wallhaven});
  final int page;
  final RecommendationProvider provider;
  @override
  List<Object?> get props => [page, provider];
}

final class RecommendationPage {
  RecommendationPage({required List<FeedItemEntity> items, required this.kind, this.nextCursor})
    : items = List.unmodifiable(items);

  final List<FeedItemEntity> items;
  final RecommendationCursor? nextCursor;
  final RecommendationKind kind;
}
