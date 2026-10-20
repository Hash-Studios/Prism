import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/review_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';

class _RecordingFirestoreClient extends Fake implements FirestoreClient {
  final List<String> deleted = <String>[];

  @override
  Future<void> deleteDoc(String collection, String id, {required String sourceTag}) async =>
      deleted.add('$collection/$id');
}

Future<void> _pumpTile(WidgetTester tester, Map<String, dynamic> payload, {bool rejected = false}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      home: Scaffold(
        body: SingleChildScrollView(child: WallTile(FirestoreDocument('S1', payload), rejected: rejected)),
      ),
    ),
  );
  tester.takeException();
}

void main() {
  const Map<String, dynamic> base = <String, dynamic>{
    'size': '2 MB',
    'resolution': '1440x3200',
    'wallpaper_url': 'https://example.com/w.jpg',
  };

  testWidgets('pads the minutes of the submission time', (tester) async {
    await _pumpTile(tester, <String, dynamic>{...base, 'createdAt': DateTime(2026, 3, 4, 17, 7)});

    expect(find.text('Mar 4, 2026 5:07 PM'), findsOneWidget);
  });

  testWidgets('shows no date when the submission time is missing', (tester) async {
    await _pumpTile(tester, base);

    expect(find.textContaining(RegExp(r'\d{4}, \d')), findsNothing);
    expect(find.text('1440 x 3200 · 2 MB'), findsOneWidget);
  });

  testWidgets(
    'shows the in review tag for a pending wallpaper and the rejected tag with its reason for a rejected one',
    (tester) async {
      await _pumpTile(tester, base);
      expect(find.text('In review'), findsOneWidget);
      expect(find.text('Why it was rejected'), findsNothing);

      await _pumpTile(tester, base, rejected: true);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Why it was rejected'), findsOneWidget);
    },
  );

  testWidgets('does not show the internal upload id', (tester) async {
    await _pumpTile(tester, base);

    expect(find.text('S1'), findsNothing);
  });

  testWidgets('labels download and delete actions for screen reader users', (tester) async {
    await _pumpTile(tester, base);

    final Iterable<String?> tooltips = find
        .byType(IconButton)
        .evaluate()
        .map((Element element) => (element.widget as IconButton).tooltip);
    expect(tooltips, containsAll(<String?>['Download wallpaper', 'Delete wallpaper']));
  });

  testWidgets('cleanup failure retains the pending row and retry deletes metadata only after both files', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final backend = CoinsTestBackend();
    await backend.install();
    addTearDown(getIt.reset);
    final firestore = _RecordingFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    addTearDown(() => messenger.setMockMethodCallHandler(toastChannel, null));
    final roles = <String>[];
    final requests = <({String name, Map<String, dynamic> data, bool metadataPresent})>[];
    var failOriginal = true;
    backend.onCall = (name, parameters) async {
      requests.add((name: name, data: parameters, metadataPresent: firestore.deleted.isEmpty));
      final role = parameters['assetRole'] as String;
      roles.add(role);
      if (role == 'wallpaper' && failOriginal) {
        throw FirebaseFunctionsException(code: 'unavailable', message: 'storage unavailable');
      }
      return <String, dynamic>{'ok': true};
    };
    await _pumpTile(tester, <String, dynamic>{
      ...base,
      'id': 'wall',
      'wallpaper_url': '',
      'originalProtected': true,
      'originalObjectId': '17',
      'wallpaper_path': '',
      'wallpaper_sha': '',
      'thumb_path': '',
      'thumb_sha': '',
    });
    Future<void> confirmDelete() async {
      await tester.tap(find.byTooltip('Delete wallpaper'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete wallpaper'));
      await tester.pumpAndSettle();
    }

    await confirmDelete();
    expect(roles, <String>['wallpaper', 'thumb']);
    expect(firestore.deleted, isEmpty);
    failOriginal = false;
    await confirmDelete();
    expect(roles, <String>['wallpaper', 'thumb', 'wallpaper', 'thumb']);
    expect(firestore.deleted, <String>['walls/S1']);
    await tester.pump(const Duration(seconds: 2));
    expect(
      requests.every(
        (request) =>
            request.name == 'githubDeleteFile' &&
            request.data['wallId'] == 'wall' &&
            request.data['originalObjectId'] == '17' &&
            request.metadataPresent,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
