import 'package:Prism/features/startup/views/pages/splash_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a fresh, never-onboarded user always sees onboarding', () {
    expect(
      shouldShowOnboarding(isLoggedIn: false, isOnboarded: false, v2Enabled: true, guestBrowsingAllowed: true),
      isTrue,
    );
    expect(
      shouldShowOnboarding(isLoggedIn: false, isOnboarded: false, v2Enabled: true, guestBrowsingAllowed: false),
      isTrue,
    );
  });

  test('a signed-in, onboarded user goes to the dashboard on every platform', () {
    expect(
      shouldShowOnboarding(isLoggedIn: true, isOnboarded: true, v2Enabled: true, guestBrowsingAllowed: false),
      isFalse,
    );
    expect(
      shouldShowOnboarding(isLoggedIn: true, isOnboarded: true, v2Enabled: true, guestBrowsingAllowed: true),
      isFalse,
    );
  });

  test('an onboarded iOS guest (never signed in) goes straight to the dashboard', () {
    expect(
      shouldShowOnboarding(isLoggedIn: false, isOnboarded: true, v2Enabled: true, guestBrowsingAllowed: true),
      isFalse,
    );
  });

  test('an onboarded but signed-out Android user is forced back to onboarding', () {
    expect(
      shouldShowOnboarding(isLoggedIn: false, isOnboarded: true, v2Enabled: true, guestBrowsingAllowed: false),
      isTrue,
    );
  });

  test('a signed-in user who skipped onboarding sees it only when v2 is enabled', () {
    expect(
      shouldShowOnboarding(isLoggedIn: true, isOnboarded: false, v2Enabled: true, guestBrowsingAllowed: false),
      isTrue,
    );
    expect(
      shouldShowOnboarding(isLoggedIn: true, isOnboarded: false, v2Enabled: false, guestBrowsingAllowed: false),
      isFalse,
    );
  });
}
