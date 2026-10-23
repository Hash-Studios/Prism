import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_page.dart';
import 'package:equatable/equatable.dart';

enum RecommendationStatus { initial, loading, ready, failure, exhausted }

final class RecommendationState extends Equatable {
  RecommendationState({
    List<FeedItemEntity> items = const [],
    this.cursor,
    this.kind = RecommendationKind.discovery,
    required this.status,
  }) : items = List.unmodifiable(items);

  const RecommendationState.exhausted()
    : items = const [],
      cursor = null,
      kind = RecommendationKind.discovery,
      status = RecommendationStatus.exhausted;

  const RecommendationState.initial()
    : items = const [],
      cursor = null,
      kind = RecommendationKind.discovery,
      status = RecommendationStatus.initial;

  final List<FeedItemEntity> items;
  final RecommendationCursor? cursor;
  final RecommendationKind kind;
  final RecommendationStatus status;
  bool get started => status != RecommendationStatus.initial;
  bool get loading => status == RecommendationStatus.loading;
  bool get hasMore => status != RecommendationStatus.exhausted;
  bool get failed => status == RecommendationStatus.failure;

  RecommendationState loadingPage() =>
      RecommendationState(items: items, cursor: cursor, kind: kind, status: RecommendationStatus.loading);

  RecommendationState append(RecommendationPage page, FeedItemEntity current) {
    final seen = {(current.source, current.id), for (final item in items) (item.source, item.id)};
    return RecommendationState(
      items: [...items, ...page.items.where((item) => seen.add((item.source, item.id)))],
      cursor: page.nextCursor,
      kind: page.kind,
      status: page.nextCursor == null ? RecommendationStatus.exhausted : RecommendationStatus.ready,
    );
  }

  RecommendationState failure() =>
      RecommendationState(items: items, cursor: cursor, kind: kind, status: RecommendationStatus.failure);

  @override
  List<Object?> get props => [items, cursor, kind, status];
}
