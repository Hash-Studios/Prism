import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wallfirestore;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockFirestoreClient extends Mock implements FirestoreClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late _MockFirestoreClient firestoreClient;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (_) async => true,
    );
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    firestoreClient = _MockFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestoreClient);
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'remix-test-user';
    when(() => firestoreClient.addDoc(any(), any(), sourceTag: any(named: 'sourceTag'))).thenAnswer((_) async => 'doc');
    when(
      () => firestoreClient.updateDoc(any(), any(), any(), sourceTag: any(named: 'sourceTag')),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<Map<String, dynamic>> submit({String? remixOf}) async {
    await wallfirestore.createRecord(
      'wall-id',
      'Prism',
      'thumb',
      'wallpaper',
      '1080x1920',
      'AI',
      'Title',
      'Nature',
      'Description',
      false,
      isAiGenerated: true,
      aiGenerationId: 'generation-1',
      remixOf: remixOf,
    );
    final List<dynamic> captured = verify(
      () => firestoreClient.addDoc(any(), captureAny(), sourceTag: any(named: 'sourceTag')),
    ).captured;
    return captured.single as Map<String, dynamic>;
  }

  test('a linked submission writes remixOf to the wall record', () async {
    final Map<String, dynamic> written = await submit(remixOf: 'orig_1');

    expect(written['remixOf'], 'orig_1');
  });

  test('an unlinked submission writes no remixOf key', () async {
    final Map<String, dynamic> written = await submit();

    expect(written.containsKey('remixOf'), isFalse);
  });

  test('a blank remixOf writes no remixOf key', () async {
    final Map<String, dynamic> written = await submit(remixOf: '  ');

    expect(written.containsKey('remixOf'), isFalse);
  });
}
