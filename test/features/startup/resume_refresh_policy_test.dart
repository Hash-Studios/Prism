import 'package:Prism/features/startup/services/resume_refresh_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final noon = DateTime(2026, 5, 10, 12);

  test('a resume soon after a refresh on the same day skips the refetch', () {
    expect(shouldRefreshWotdOnResume(lastRefresh: noon, now: noon.add(const Duration(minutes: 29))), isFalse);
  });

  test('a resume after 30 minutes refetches', () {
    expect(shouldRefreshWotdOnResume(lastRefresh: noon, now: noon.add(const Duration(minutes: 30))), isTrue);
  });

  test('a resume on a new calendar day refetches even within 30 minutes', () {
    final late = DateTime(2026, 5, 10, 23, 50);

    expect(shouldRefreshWotdOnResume(lastRefresh: late, now: DateTime(2026, 5, 11, 0, 5)), isTrue);
  });

  test('a first resume with no earlier refresh refetches', () {
    expect(shouldRefreshWotdOnResume(lastRefresh: null, now: noon), isTrue);
  });
}
