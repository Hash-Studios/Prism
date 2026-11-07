import 'dart:typed_data';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/desktop_submission/data/desktop_submission_repository.dart';
import 'package:Prism/features/desktop_submission/domain/desktop_submit_failure.dart';
import 'package:Prism/features/desktop_submission/views/pages/desktop_upload_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements DesktopSubmissionRepository {
  final List<Uint8List> submitted = <Uint8List>[];
  Object? submitError;

  @override
  Future<String> submit({required String wallDocId, required Uint8List bytes}) async {
    submitted.add(bytes);
    final Object? error = submitError;
    if (error != null) throw error;
    return 'sub_1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final Uint8List _bytes = Uint8List.fromList(List<int>.filled(64, 7));

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required _FakeRepo repo,
    Size? measured,
    Uint8List? bytes,
    bool replace = false,
    double textScale = 1,
  }) async {
    Widget screen = DesktopUploadScreen(
      wallDocId: 'wall_1',
      wallId: 'wall_1',
      phoneThumbUrl: '',
      wallTitle: 'Harbour',
      replace: replace,
      repository: repo,
      pickImage: () async => measured == null ? null : bytes ?? _bytes,
      measure: (_) async => measured,
    );
    if (textScale != 1) {
      screen = MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(textScaler: TextScaler.linear(textScale)),
        child: screen,
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    );
    await tester.pump();
  }

  Future<void> pick(WidgetTester tester) async {
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
  }

  PrismButton submitButton(WidgetTester tester) =>
      tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Submit for review'));

  testWidgets('before a pick it shows the requirements and a disabled submit', (tester) async {
    await pumpScreen(tester, repo: _FakeRepo());

    expect(find.text('Use a landscape image in 16:10 or 16:9, at least 1920 px wide.'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('a portrait image shows the portrait error and keeps submit disabled', (tester) async {
    await pumpScreen(tester, repo: _FakeRepo(), measured: const Size(1080, 1920));
    await pick(tester);

    expect(find.text('Choose a landscape image. It must be wider than it is tall.'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('a wrong aspect ratio shows the aspect error', (tester) async {
    await pumpScreen(tester, repo: _FakeRepo(), measured: const Size(2000, 1500));
    await pick(tester);

    expect(find.text('Choose an image in 16:10 or 16:9. Crop it on your computer, then try again.'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('an image narrower than 1920 px shows the size error', (tester) async {
    await pumpScreen(tester, repo: _FakeRepo(), measured: const Size(1600, 1000));
    await pick(tester);

    expect(find.text('Choose an image at least 1920 px wide. This one is 1600 px wide.'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('an image over 15 MB cannot be submitted even when its dimensions are valid', (tester) async {
    final _FakeRepo repo = _FakeRepo();
    final Uint8List largeBytes = Uint8List(15 * 1024 * 1024 + 1);
    await pumpScreen(tester, repo: repo, measured: const Size(2560, 1600), bytes: largeBytes);
    await pick(tester);

    expect(find.text('This file is too large. Choose an image under 15 MB.'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
    expect(repo.submitted, isEmpty);
  });

  testWidgets('a valid image shows the side by side preview and enables submit', (tester) async {
    await pumpScreen(tester, repo: _FakeRepo(), measured: const Size(2560, 1600));
    await pick(tester);

    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Desktop'), findsOneWidget);
    expect(find.bySemanticsLabel('Desktop version, 2560 × 1600'), findsOneWidget);
    expect(find.text('2560 × 1600, 16:10'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('submit sends the picked bytes to the repository', (tester) async {
    final _FakeRepo repo = _FakeRepo();
    await pumpScreen(tester, repo: repo, measured: const Size(2560, 1600));
    await pick(tester);

    await tester.tap(find.text('Submit for review'));
    // The page pops on success and the spinner keeps running here, so pumpAndSettle would never return.
    await tester.pump();
    await tester.pump();

    expect(repo.submitted, <Uint8List>[_bytes]);
  });

  testWidgets('replace shows the replace title and note', (tester) async {
    await pumpScreen(tester, repo: _FakeRepo(), replace: true);

    expect(find.text('Replace desktop version'), findsOneWidget);
    expect(find.text('The current desktop version stays live until the new one is approved.'), findsOneWidget);
  });

  testWidgets('a server pending error shows the pending message inline', (tester) async {
    final _FakeRepo repo = _FakeRepo()..submitError = const DesktopSubmitException(DesktopSubmitFailure.alreadyPending);
    await pumpScreen(tester, repo: repo, measured: const Size(2560, 1600));
    await pick(tester);

    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(find.text('A desktop version of this wallpaper is already in review.'), findsOneWidget);
  });

  testWidgets('unexpected submit errors show a retryable error and play only the outcome', (tester) async {
    final _FakeRepo repo = _FakeRepo()..submitError = StateError('offline');
    final List<Object?> haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpScreen(tester, repo: repo, measured: const Size(2560, 1600));
    await pick(tester);
    haptics.clear();

    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to submit. Check your connection and try again.'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
    expect(submitButton(tester).loading, isFalse);
    expect(haptics, <String>['HapticFeedbackType.errorNotification']);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(repo.submitted, hasLength(2));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('large text keeps both labels visible without an exception', (tester) async {
    await pumpScreen(tester, repo: _FakeRepo(), measured: const Size(2560, 1600), textScale: 2);
    await pick(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Desktop'), findsOneWidget);
  });
}
