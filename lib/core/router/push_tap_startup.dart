Future<bool> waitForPushTapStartup({required bool Function() isMounted, required bool Function() isReady}) async {
  // ponytail: polls every 100 ms and gives up after 30 s (for example on the obsolete-version screen).
  for (int i = 0; i < 300 && isMounted() && !isReady(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return isMounted() && isReady();
}
