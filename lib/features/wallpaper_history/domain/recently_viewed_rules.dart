import 'dart:async';

import 'package:Prism/features/wallpaper_history/domain/entities/history_wall.dart';

/// How long a wall's detail must stay on screen before it counts as viewed.
const Duration viewDwell = Duration(seconds: 2);

/// Decides when one detail visit counts as a view: after [dwell] on screen, or at once when the user acts on the
/// wall (zoom, set, save, download). A swipe past the wall before [dwell] does not count. Fires at most once.
class ViewRecorder {
  ViewRecorder(this._onView, {this.dwell = viewDwell});

  final void Function() _onView;
  final Duration dwell;
  Timer? _timer;
  bool _recorded = false;

  /// The wall is on screen and loaded.
  void shown() {
    if (_recorded) return;
    _timer ??= Timer(dwell, _record);
  }

  /// The wall left the screen, as on a swipe to the next wall. The dwell starts again when it comes back.
  void hidden() {
    _timer?.cancel();
    _timer = null;
  }

  /// The user zoomed, set, saved or downloaded the wall.
  void acted() => _record();

  void dispose() => hidden();

  void _record() {
    if (_recorded) return;
    _recorded = true;
    hidden();
    _onView();
  }
}

const Duration pickUpWindow = Duration(days: 7);
const int pickUpMin = 4;
const int pickUpMax = 10;

/// The walls for "Pick up where you left off": viewed in the last [pickUpWindow] before [sessionStart], and not yet
/// saved, set or downloaded. Empty on the first session, or when fewer than [pickUpMin] walls qualify.
List<HistoryWall> pickUpWalls({
  required List<HistoryWall> viewedNewestFirst,
  required DateTime sessionStart,
  required bool returningSession,
  required bool Function(HistoryWall wall) kept,
}) {
  if (!returningSession) return const <HistoryWall>[];
  final DateTime since = sessionStart.subtract(pickUpWindow);
  final List<HistoryWall> walls = viewedNewestFirst
      .where((wall) => wall.at.isBefore(sessionStart) && wall.at.isAfter(since) && !kept(wall))
      .take(pickUpMax)
      .toList(growable: false);
  return walls.length < pickUpMin ? const <HistoryWall>[] : walls;
}
