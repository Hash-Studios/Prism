import 'package:Prism/core/persistence/store_adapters/shared_prefs_store_adapter.dart';
import 'package:Prism/core/persistence/store_value_codec.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  late SharedPrefsStoreAdapter store;
  late Map<String, Object> disk;
  late bool writesSucceed;

  setUp(() async {
    SharedPreferences.resetStatic();
    disk = <String, Object>{'flutter.saved': StoreValueCodec.encode('old')};
    writesSucceed = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') return Map<String, Object>.from(disk);
      if (!writesSucceed) return false;
      final args = Map<String, Object?>.from(call.arguments as Map);
      if (call.method == 'setString') disk[args['key']! as String] = args['value']!;
      if (call.method == 'remove') disk.remove(args['key']);
      if (call.method == 'clear') disk.clear();
      return true;
    });
    store = SharedPrefsStoreAdapter();
    await store.init();
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('a rejected platform write throws and restores the persisted value', () async {
    await expectLater(store.set('saved', 'new'), throwsStateError);
    expect(store.get('saved'), 'old');
    final reopened = SharedPrefsStoreAdapter();
    SharedPreferences.resetStatic();
    await reopened.init();
    expect(reopened.get('saved'), 'old');
  });

  test('a rejected removal does not report success or hide saved data', () async {
    await expectLater(store.delete('saved'), throwsStateError);
    expect(store.get('saved'), 'old');
    await expectLater(store.clearPrefix('sav'), throwsStateError);
    expect(store.get('saved'), 'old');
    await expectLater(store.clearAll(), throwsStateError);
    expect(store.get('saved'), 'old');
  });

  test('a failed write does not prevent a later successful write', () async {
    await expectLater(store.set('saved', 'new'), throwsStateError);
    writesSucceed = true;
    await store.set('saved', 'confirmed');
    expect(store.get('saved'), 'confirmed');
    SharedPreferences.resetStatic();
    final reopened = SharedPrefsStoreAdapter();
    await reopened.init();
    expect(reopened.get('saved'), 'confirmed');
    await store.delete('saved');
    expect(store.get('saved'), isNull);
  });

  test('a value saved without the codec reads back as it is', () async {
    disk.addAll(<String, Object>{'flutter.legacyFlag': true, 'flutter.legacyCount': 3});
    SharedPreferences.resetStatic();
    final reopened = SharedPrefsStoreAdapter();
    await reopened.init();
    expect(reopened.get('legacyFlag'), isTrue);
    expect(reopened.get('legacyCount'), 3);
    expect(reopened.get('saved'), 'old');
  });
}
