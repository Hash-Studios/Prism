import 'dart:async';

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
      super(const <MoodList>[]) {
    _visibility = _repository.watchVisibilityChanges().listen((_) => unawaited(load()));
  }

  late final StreamSubscription<void> _visibility;

  @override
  Future<void> close() async {
    await _visibility.cancel();
    return super.close();
  }

  final MoodRepository _repository;
  final Future<int?> Function() _iosMajor;
  int _loadVersion = 0;

  /// A failed read keeps the moods that are on screen.
  Future<void> load() async {
    final int loadVersion = ++_loadVersion;
    try {
      final List<MoodList> moods = await _repository.fetchMoods();
      final int? iosMajor = await _iosMajor();
      if (isClosed || loadVersion != _loadVersion) return;
      emit(<MoodList>[
        for (final MoodList list in moods)
          if (list.wallIds.isNotEmpty && list.mood.shownOn(iosMajor: iosMajor)) list,
      ]);
    } catch (error, stackTrace) {
      if (loadVersion != _loadVersion) return;
      logger.w('[MoodsCubit] load failed', error: error, stackTrace: stackTrace);
    }
  }
}

/// Duo owns the first available row. Other moods rotate daily through the remaining slots, up to two rows total.
List<MoodList> rowMoodsFor(List<MoodList> moods, DateTime now) {
  final List<MoodList> visible = moods.where((list) => list.wallIds.isNotEmpty).toList();
  final List<MoodList> duo = visible.where((list) => list.mood == WallMood.duoReveal).take(1).toList();
  final List<MoodList> rotating = visible.where((list) => list.mood != WallMood.duoReveal).toList();
  final int slots = 2 - duo.length;
  if (rotating.length <= slots) return <MoodList>[...duo, ...rotating];
  final int day = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(2026)).inDays;
  final int start = day % rotating.length;
  return <MoodList>[...duo, for (int i = 0; i < slots; i++) rotating[(start + i) % rotating.length]];
}

/// Null on Android and the web. 0 on iOS when the version cannot be read.
Future<int?> deviceIosMajor() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  return await iosMajor() ?? 0;
}
