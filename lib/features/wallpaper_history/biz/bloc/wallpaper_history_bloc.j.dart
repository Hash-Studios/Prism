import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_history/data/history_wall_stores.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';
import 'package:Prism/logger/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'wallpaper_history_event.j.dart';
part 'wallpaper_history_state.j.dart';
part 'wallpaper_history_bloc.j.freezed.dart';

const String _syncedPrefix = 'synced:';

/// The synced key of a set on this device, or null for a wall with no catalogue identity.
String? _keyOf(AppliedWallpaper item) {
  final WallpaperSource source = WallpaperSourceX.fromWire(item.source);
  final String id = item.wallpaperId ?? '';
  return id.isEmpty || !HistoryWall.catalogSources.contains(source) ? null : HistoryWall.keyOf(source, id);
}

/// A synced wall shown as a history row. It has no file or full link, so it opens the detail screen.
AppliedWallpaper _row(HistoryWall wall) => AppliedWallpaper(
  id: '$_syncedPrefix${wall.key}',
  source: wall.source.wireValue,
  thumbnailUrl: wall.thumbnailUrl,
  fullUrl: '',
  target: wall.action.name,
  appliedAt: wall.at,
  wallpaperId: wall.id,
);

/// True for a row that came from the account and not from a set on this device.
bool isSyncedHistoryRow(AppliedWallpaper item) => item.id.startsWith(_syncedPrefix);

/// The sets on this device, plus each synced wall that no set here already shows. Newest first.
List<AppliedWallpaper> mergeHistoryRows(List<AppliedWallpaper> applied, List<HistoryWall> synced) {
  final Set<String> shown = applied.map(_keyOf).nonNulls.toSet();
  return <AppliedWallpaper>[...applied, ...synced.where((wall) => !shown.contains(wall.key)).map(_row)]
    ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
}

@injectable
class WallpaperHistoryBloc extends Bloc<WallpaperHistoryEvent, WallpaperHistoryState> {
  WallpaperHistoryBloc(this._store, this._synced, this._viewed) : super(WallpaperHistoryState.initial()) {
    on<_Started>((event, emit) => emit(_read()));
    on<_Cleared>(_onCleared);
    on<_ViewedCleared>(_onViewedCleared);
    on<_ViewingTurnedOn>((event, emit) async {
      await _viewed.setEnabled(true);
      emit(_read());
    });
    on<_Removed>(_onRemoved);
    on<_Restored>(_onRestored);
  }

  final WallpaperHistoryStore _store;
  final SyncedHistoryStore _synced;
  final RecentlyViewedStore _viewed;

  /// Synced walls a remove took away, by row id, so Undo can put them back.
  final Map<String, HistoryWall> _removedSynced = <String, HistoryWall>{};
  final Map<String, (String, int)> _removedSessions = <String, (String, int)>{};
  Future<bool>? _clearInFlight;

  WallpaperHistoryState _read() => WallpaperHistoryState(
    items: mergeHistoryRows(_store.items(), _synced.items()),
    viewed: _viewed.items(),
    viewingHistoryOn: _viewed.enabled,
  );

  /// Restores [item], even when the history page's bloc has already been disposed.
  Future<void> restore(AppliedWallpaper item) async {
    if (!isClosed) {
      add(WallpaperHistoryEvent.restored(item));
      return;
    }
    await _restore(item);
  }

  Future<void> _onCleared(_Cleared event, Emitter<WallpaperHistoryState> emit) async {
    await clearSetAndDownloaded();
    emit(_read());
  }

  /// Clears the account history first, then the sets on this device. False when the account could not be reached;
  /// both lists stay as they were.
  Future<bool> clearSetAndDownloaded() {
    final Future<bool>? pending = _clearInFlight;
    if (pending != null) return pending;
    final Future<bool> clearing = _clearSetAndDownloaded();
    _clearInFlight = clearing;
    return clearing.whenComplete(() {
      if (identical(_clearInFlight, clearing)) _clearInFlight = null;
    });
  }

  Future<bool> _clearSetAndDownloaded() async {
    final (String, int) recordingSession = _synced.recordingSession;
    try {
      await _synced.clear();
    } catch (error, stackTrace) {
      logger.w('Account history clear did not reach the server.', error: error, stackTrace: stackTrace);
      return false;
    }
    if (_synced.recordingSession != recordingSession) return false;
    _removedSynced.clear();
    _removedSessions.clear();
    await _store.clear();
    if (!isClosed) add(const WallpaperHistoryEvent.started());
    return true;
  }

  Future<void> _onViewedCleared(_ViewedCleared event, Emitter<WallpaperHistoryState> emit) async {
    await _viewed.clear();
    emit(_read());
  }

  Future<void> _onRemoved(_Removed event, Emitter<WallpaperHistoryState> emit) async {
    final AppliedWallpaper? item = state.items.where((row) => row.id == event.id).firstOrNull;
    if (item == null) return;
    _removedSessions[event.id] = _synced.recordingSession;
    final String? key = isSyncedHistoryRow(item) ? item.id.substring(_syncedPrefix.length) : _keyOf(item);
    if (!isSyncedHistoryRow(item)) await _store.remove(item.id);
    final bool stillShown = key != null && _store.items().any((row) => _keyOf(row) == key);
    final HistoryWall? synced = key == null || stillShown
        ? null
        : _synced.items().where((wall) => wall.key == key).firstOrNull;
    if (synced != null) {
      _removedSynced[event.id] = synced;
      await _guard(() => _synced.remove(synced.key));
    }
    emit(_read());
  }

  Future<void> _onRestored(_Restored event, Emitter<WallpaperHistoryState> emit) async {
    await _restore(event.item);
    emit(_read());
  }

  Future<void> _restore(AppliedWallpaper item) async {
    final (String, int)? removedSession = _removedSessions.remove(item.id);
    if (removedSession == null || removedSession != _synced.recordingSession) {
      _removedSynced.remove(item.id);
      return;
    }
    if (!isSyncedHistoryRow(item)) await _store.record(item);
    final Future<bool>? clearing = _clearInFlight;
    if (clearing != null && await clearing) return;
    if (removedSession != _synced.recordingSession) {
      _removedSynced.remove(item.id);
      return;
    }
    final HistoryWall? synced = _removedSynced.remove(item.id);
    if (synced != null) await _guard(() => _synced.record(synced));
  }

  static Future<void> _guard(Future<void> Function() write) async {
    try {
      await write();
    } catch (error, stackTrace) {
      logger.w('Account history write failed.', error: error, stackTrace: stackTrace);
    }
  }
}
