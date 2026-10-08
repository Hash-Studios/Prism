// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/persistence/store_adapters/lazy_file_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lazy_file_cache_test');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('many writes started together all land in the file and leave no temp file', () async {
    final cache = LazyFileCache('burst');

    await Future.wait(<Future<void>>[for (var i = 0; i < 25; i++) cache.set('key$i', i)]);
    await cache.delete('key3');
    await cache.flush();

    final Map<String, Object?> onDisk = (jsonDecode(File('${dir.path}/burst.json').readAsStringSync()) as Map)
        .cast<String, Object?>();
    expect(onDisk.length, 24);
    expect(onDisk.containsKey('key3'), isFalse);
    expect(onDisk['key24'], 24);
    expect(File('${dir.path}/burst.json.tmp').existsSync(), isFalse);
  });

  test('a second cache reads what the first one wrote', () async {
    final first = LazyFileCache('reload');
    await first.set('a', 'b');
    await first.flush();

    expect(await LazyFileCache('reload').get('a'), 'b');
  });
}
