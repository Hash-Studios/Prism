import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// The moods that Home shows on this device. Empty while they load, and when there are none or the read fails.
@lazySingleton
class MoodsCubit extends Cubit<List<MoodList>> {
  MoodsCubit(this._repository, {@ignoreParam Future<int?> Function()? iosMajor})
    : _iosMajor = iosMajor ?? deviceIosMajor,
      super(const <MoodList>[]);

  final MoodRepository _repository;
  final Future<int?> Function() _iosMajor;

  /// A failed read keeps the moods that are on screen.
  Future<void> load() async {
    try {
      final List<MoodList> moods = await _repository.fetchMoods();
      final int? iosMajor = await _iosMajor();
      if (isClosed) return;
      emit(<MoodList>[
        for (final MoodList list in moods)
          if (list.mood.shownOn(iosMajor: iosMajor)) list,
      ]);
    } catch (error, stackTrace) {
      logger.w('[MoodsCubit] load failed', error: error, stackTrace: stackTrace);
    }
  }
}

/// Up to two moods for the rows in the For you grid. They move on one place each day, so Home changes daily.
List<MoodList> rowMoodsFor(List<MoodList> moods, DateTime now) {
  if (moods.length <= 2) return moods;
  final int day = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(2026)).inDays;
  final int start = day % moods.length;
  return <MoodList>[moods[start], moods[(start + 1) % moods.length]];
}

/// Null on Android and the web. 0 on iOS when the version cannot be read.
Future<int?> deviceIosMajor() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  return await iosMajor() ?? 0;
}
