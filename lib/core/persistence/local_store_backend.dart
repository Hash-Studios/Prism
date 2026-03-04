enum LocalStoreBackend { hive, sharedPrefs }

extension LocalStoreBackendX on LocalStoreBackend {
  static LocalStoreBackend fromDefine(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'shared_prefs':
      case 'sharedprefs':
      case 'sharedpreferences':
        return LocalStoreBackend.sharedPrefs;
      case 'hive':
      default:
        return LocalStoreBackend.hive;
    }
  }
}
