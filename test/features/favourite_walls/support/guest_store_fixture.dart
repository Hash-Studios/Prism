// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:Prism/core/persistence/store_adapters/lazy_file_cache.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

/// A guest favourites store that writes to a temp directory. The directory goes away after the test.
GuestFavouritesStore tempGuestStore() {
  final Directory dir = Directory.systemTemp.createTempSync('guest_favourites_test');
  PathProviderPlatform.instance = _FakePathProvider(dir.path);
  addTearDown(() => dir.deleteSync(recursive: true));
  return GuestFavouritesStore.withCache(LazyFileCache('guest_favourites'));
}

/// A store that never touches the disk, for tests that do not use guests.
GuestFavouritesStore unusedGuestStore() => GuestFavouritesStore.withCache(LazyFileCache('unused'));

class _MemoryCache extends LazyFileCache {
  _MemoryCache() : super('memory');

  final Map<String, Object?> _data = <String, Object?>{};

  @override
  Future<Object?> get(String key) async => _data[key];

  @override
  Future<void> set(String key, Object? value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// A guest favourites store that lives in memory. Widget tests use it, because real file IO never finishes
/// inside the fake-async zone of `testWidgets`.
GuestFavouritesStore memoryGuestStore() => GuestFavouritesStore.withCache(_MemoryCache());
