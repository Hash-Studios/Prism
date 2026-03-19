enum LocalStoreBackend { sharedPrefs }

extension LocalStoreBackendX on LocalStoreBackend {
  static LocalStoreBackend fromDefine(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'shared_prefs':
      case 'sharedprefs':
      case 'sharedpreferences':
      default:
        return LocalStoreBackend.sharedPrefs;
    }
  }
}
