import 'package:freezed_annotation/freezed_annotation.dart';

part 'draw_entity.freezed.dart';

@freezed
abstract class DrawEntity with _$DrawEntity {
  const factory DrawEntity({
    required String weekKey,
    required String status,
    required DateTime closesAt,
    required int tickets,
    required int participants,
    required int prizeProMonths,
    required String prizeItemId,
    String? winnerName,
  }) = _DrawEntity;
}
