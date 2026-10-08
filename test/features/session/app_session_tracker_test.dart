import 'package:Prism/features/session/data/app_session_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, Object?> store = <String, Object?>{};
  late DateTime now;

  AppSessionTracker newTracker() => AppSessionTracker(
    read: <T>(String key, T defaultValue) => (store[key] as T?) ?? defaultValue,
    write: (String key, Object? value) async => store[key] = value,
    clock: () => now,
  );

  setUp(() {
    store.clear();
    now = DateTime.utc(2026, 3, 1, 9);
  });

  test('the first session is 1 and the number stays the same inside one process', () {
    final tracker = newTracker();

    expect(tracker.sessionNumber, 1);
    expect(tracker.sessionNumber, 1);
    expect(store[AppSessionTracker.sessionCountKey], 1);
  });

  test('each new process counts one more session', () {
    expect(newTracker().sessionNumber, 1);
    expect(newTracker().sessionNumber, 2);
    expect(newTracker().sessionNumber, 3);
  });

  test('remembers the first launch and does not move it', () {
    final first = newTracker();
    expect(first.firstLaunchAt, DateTime.utc(2026, 3, 1, 9));

    now = DateTime.utc(2026, 3, 9);
    final later = newTracker();

    expect(later.firstLaunchAt, DateTime.utc(2026, 3, 1, 9));
    expect(later.sessionNumber, 2);
  });
}
