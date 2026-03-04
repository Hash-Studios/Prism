class Env {
  const Env._();

  /// Strips surrounding single or double quotes that Doppler can inject into
  /// dart-define values (e.g. `"https://..."` → `https://...`).
  static String normalize(String raw) {
    String value = raw.trim();
    while (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1).trim();
    }
    return value;
  }

  // GitHub
  static const String ghToken = String.fromEnvironment('GH_TOKEN');
  static const String ghUserName = String.fromEnvironment('GH_USERNAME');
  static const String ghRepoWalls = String.fromEnvironment('GH_REPO_WALLS');
  static const String ghRepoSetups = String.fromEnvironment('GH_REPO_SETUPS');
  static const String ghRepoData = String.fromEnvironment('GH_REPO_DATA');

  // RevenueCat
  static const String rcApiKey = String.fromEnvironment('RC_API_KEY');
  static const String rcAndroidApiKey = String.fromEnvironment('RC_ANDROID_API_KEY');
  static const String rcIosApiKey = String.fromEnvironment('RC_IOS_API_KEY');

  // Pexels
  static const String pexelsApiKey = String.fromEnvironment('PEXELS_API_KEY');

  // Sentry
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String sentryEnvironment = String.fromEnvironment('SENTRY_ENV');
  static const String sentryRelease = String.fromEnvironment('SENTRY_RELEASE');
  static const String sentryDist = String.fromEnvironment('SENTRY_DIST');
  static const String sentryEnabled = String.fromEnvironment('SENTRY_ENABLED', defaultValue: 'auto');

  // Mixpanel
  static const String mixpanelToken = String.fromEnvironment('MIXPANEL_TOKEN');
  static const String mixpanelEnabled = String.fromEnvironment('MIXPANEL_ENABLED', defaultValue: 'auto');

  // Persistence
  static const String localPersistenceBackend = String.fromEnvironment('LOCAL_PERSISTENCE_BACKEND', defaultValue: 'shared_prefs');

  // User profile images (used in follow suggestions)
  static const String user1Image1 = String.fromEnvironment('USER1_IMAGE1');
  static const String user1Image2 = String.fromEnvironment('USER1_IMAGE2');
  static const String user1Image3 = String.fromEnvironment('USER1_IMAGE3');
  static const String user2Image1 = String.fromEnvironment('USER2_IMAGE1');
  static const String user2Image2 = String.fromEnvironment('USER2_IMAGE2');
  static const String user2Image3 = String.fromEnvironment('USER2_IMAGE3');
  static const String user3Image1 = String.fromEnvironment('USER3_IMAGE1');
  static const String user3Image2 = String.fromEnvironment('USER3_IMAGE2');
  static const String user3Image3 = String.fromEnvironment('USER3_IMAGE3');
  static const String user4Image1 = String.fromEnvironment('USER4_IMAGE1');
  static const String user4Image2 = String.fromEnvironment('USER4_IMAGE2');
  static const String user4Image3 = String.fromEnvironment('USER4_IMAGE3');
  static const String user5Image1 = String.fromEnvironment('USER5_IMAGE1');
  static const String user5Image2 = String.fromEnvironment('USER5_IMAGE2');
  static const String user5Image3 = String.fromEnvironment('USER5_IMAGE3');
  static const String user6Image1 = String.fromEnvironment('USER6_IMAGE1');
  static const String user6Image2 = String.fromEnvironment('USER6_IMAGE2');
  static const String user6Image3 = String.fromEnvironment('USER6_IMAGE3');
}
