import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

class _FakeShare {
  _FakeShare(this.file);

  final File file;
  Future<File>? pendingRender;
  Future<OperationResult>? pendingSave;
  final List<File> saved = <File>[];

  ShareSheetServices get services => ShareSheetServices(
    render: (_, _) => pendingRender ?? Future<File>.value(file),
    instagramAvailable: () async => false,
    saveImage: (File value) async {
      final OperationResult result =
          await (pendingSave ?? Future<OperationResult>.value(OperationResult(success: true)));
      saved.add(value);
      return result;
    },
    copyText: (_) async {},
    shareText: ({required text, required context}) async => const ShareResult('', ShareResultStatus.success),
    shareFile: ({required text, required file, required context}) async =>
        const ShareResult('', ShareResultStatus.success),
  );
}

Future<File> _writeCard(WidgetTester tester) async {
  final File? file = await tester.runAsync(() async {
    final Directory directory = await Directory.systemTemp.createTemp('wrapped_share_session_test_');
    addTearDown(() => directory.delete(recursive: true));
    return File('${directory.path}/story.png')..writeAsBytesSync(base64Decode(_pngBase64));
  });
  return file!;
}

void _mockChannels(WidgetTester tester) {
  final TestDefaultBinaryMessenger messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  addTearDown(() {
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

Future<void> _open(
  WidgetTester tester,
  _FakeShare share,
  Stream<String> ownerChanges, {
  ValueChanged<ShareTargetValue>? onTargetDone,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: prismLightThemes.first.theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showShareSheet(
              context,
              const ShareCardContent(
                imageUrl: 'file:///private/wall.png',
                link: 'https://prismwalls.com/wrapped',
                brandName: 'Prism',
              ),
              'wrapped',
              services: share.services,
              formats: const <ShareCardFormat>[ShareCardFormat.story],
              ownerUserId: 'user-a',
              ownerChanges: ownerChanges,
              onTargetDone: onTargetDone,
            ),
            child: const Text('Open share'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open share'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

PrismUsersV2 _user(String id) => app_constants.createGuestPrismUser()
  ..id = id
  ..loggedIn = true;

void main() {
  late StreamController<String> ownerChanges;

  setUp(() {
    ownerChanges = StreamController<String>.broadcast(sync: true);
    app_state.prismUser = _user('user-a');
  });

  tearDown(() async {
    await ownerChanges.close();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  testWidgets('a Wrapped share sheet opened for A does not share after switching to B', (tester) async {
    _mockChannels(tester);
    final _FakeShare share = _FakeShare(await _writeCard(tester));
    await _open(tester, share, ownerChanges.stream);

    app_state.prismUser = _user('user-b');
    ownerChanges.add('user-b');
    await tester.pump();

    expect(find.byKey(const ValueKey<ShareTargetValue>(ShareTargetValue.saveImage)), findsNothing);
    expect(share.saved, isEmpty);
  });

  testWidgets('switching accounts while the Wrapped image renders prevents saving it', (tester) async {
    _mockChannels(tester);
    final Completer<File> rendered = Completer<File>();
    final _FakeShare share = _FakeShare(await _writeCard(tester))..pendingRender = rendered.future;
    await _open(tester, share, ownerChanges.stream);

    await tester.tap(find.byKey(const ValueKey<ShareTargetValue>(ShareTargetValue.saveImage)));
    await tester.pump();
    app_state.prismUser = _user('user-b');
    ownerChanges.add('user-b');
    await tester.pump();
    rendered.complete(share.file);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(share.saved, isEmpty);
  });

  testWidgets('a save that finishes after switching accounts is not reported as a Wrapped share', (tester) async {
    _mockChannels(tester);
    final Completer<OperationResult> saving = Completer<OperationResult>();
    final _FakeShare share = _FakeShare(await _writeCard(tester))..pendingSave = saving.future;
    final List<ShareTargetValue> done = <ShareTargetValue>[];
    await _open(tester, share, ownerChanges.stream, onTargetDone: done.add);

    await tester.tap(find.byKey(const ValueKey<ShareTargetValue>(ShareTargetValue.saveImage)));
    await tester.pump();
    await tester.pump();
    app_state.prismUser = _user('user-b');
    ownerChanges.add('user-b');
    await tester.pump();
    saving.complete(OperationResult(success: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(share.saved, hasLength(1), reason: 'the save started under A and finished');
    expect(done, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });
}
