import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';

class PrefsFacade {
  PrefsFacade(this._settings);

  final SettingsLocalDataSource _settings;

  bool get isOpen => _settings.isOpen;

  T get<T>(String key, {T? defaultValue}) {
    return _settings.get<T>(key, defaultValue: defaultValue);
  }

  Future<void> put(String key, Object? value) {
    return _settings.set(key, value);
  }

  Future<void> delete(String key) {
    return _settings.delete(key);
  }
}
