// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/palette/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/theme_dark/theme_dark.dart';
import 'package:Prism/features/theme_light/theme_light.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/fake_app_analytics.dart';

const String _functionsChannel = 'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call';
const String _mediaChannel = 'dev.flutter.pigeon.Prism.PrismMediaHostApi.saveMedia';
const MethodChannel _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
const MethodChannel _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
const StandardMessageCodec _codec = StandardMessageCodec();

class _MockThemeModeBloc extends MockBloc<ThemeModeEvent, ThemeModeState> implements ThemeModeBloc {}

class _MockThemeLightBloc extends MockBloc<ThemeLightEvent, ThemeLightState> implements ThemeLightBloc {}

class _MockThemeDarkBloc extends MockBloc<ThemeDarkEvent, ThemeDarkState> implements ThemeDarkBloc {}

Finder _iconButton(String tooltip) => find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton));

Widget _screenHost(String sourcePath) {
  final _MockThemeModeBloc themeModeBloc = _MockThemeModeBloc();
  final _MockThemeLightBloc themeLightBloc = _MockThemeLightBloc();
  final _MockThemeDarkBloc themeDarkBloc = _MockThemeDarkBloc();
  when(() => themeModeBloc.state).thenReturn(ThemeModeState.initial());
  when(() => themeLightBloc.state).thenReturn(ThemeLightState.initial());
  when(() => themeDarkBloc.state).thenReturn(ThemeDarkState.initial());
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeModeBloc>.value(value: themeModeBloc),
      BlocProvider<ThemeLightBloc>.value(value: themeLightBloc),
      BlocProvider<ThemeDarkBloc>.value(value: themeDarkBloc),
    ],
    child: MaterialApp(home: WallpaperFilterScreen(filePath: sourcePath)),
  );
}

Future<Uint8List> _smallPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = const Color(0xFFFF0000));
  final ui.Picture picture = recorder.endRecording();
  try {
    final ui.Image image = await picture.toImage(8, 8);
    try {
      final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'test'
      ..loggedIn = true
      ..coins = 0;
    CoinsService.instance.balanceNotifier.value = 0;
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_functionsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_mediaChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      null,
    );
  });

  testWidgets('spends before saving an edited download and ignores same-frame duplicate actions', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_gate_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);

    final Completer<void> allowSpend = Completer<void>();
    final Completer<void> spendStarted = Completer<void>();
    final Completer<void> mediaSaved = Completer<void>();
    var spendCalls = 0;
    var saveCalls = 0;
    SaveMediaRequest? savedRequest;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _toastChannel,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (_) async => directory.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_functionsChannel, (
      message,
    ) async {
      final List<Object?> arguments = _codec.decodeMessage(message)! as List<Object?>;
      final Map<Object?, Object?> call = arguments.single! as Map<Object?, Object?>;
      if (call['functionName'] == 'spendCoins') {
        spendCalls++;
        if (!spendStarted.isCompleted) spendStarted.complete();
        await allowSpend.future;
        return _codec.encodeMessage(<Object?>[
          <String, Object?>{'success': true, 'changed': false, 'previousBalance': 0, 'currentBalance': 0, 'delta': 0},
        ]);
      }
      fail('Unexpected callable: ${call['functionName']}');
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_mediaChannel, (
      message,
    ) async {
      saveCalls++;
      final List<Object?> arguments = PrismMediaHostApi.pigeonChannelCodec.decodeMessage(message)! as List<Object?>;
      savedRequest = arguments.single! as SaveMediaRequest;
      mediaSaved.complete();
      return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: true)]);
    });

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForEditorReady(tester);
    await _tapInvert(tester);
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();

    final IconButton download = tester.widget<IconButton>(_iconButton('Download'));
    final IconButton set = tester.widget<IconButton>(_iconButton('Set as wallpaper'));
    download.onPressed!();
    download.onPressed!();
    set.onPressed!();
    set.onPressed!();
    await tester.pump();
    await _waitForSignal(tester, spendStarted, 'coin spend request');

    expect(spendCalls, 1);
    expect(saveCalls, 0);
    expect(tester.widget<IconButton>(_iconButton('Reset')).onPressed, isNull);
    expect(tester.widget<IconButton>(_iconButton('Set as wallpaper')).onPressed, isNull);
    final Finder firstSlider = find.byType(Slider).first;
    final double sliderBefore = tester.widget<Slider>(firstSlider).value;
    await tester.drag(firstSlider, const Offset(80, 0), warnIfMissed: false);
    await tester.pump();
    expect(tester.widget<Slider>(firstSlider).value, sliderBefore);

    allowSpend.complete();
    await _waitForSignal(tester, mediaSaved, 'native media save');
    expect(savedRequest?.kind, SaveMediaKind.wallpaper);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(spendCalls, 1);
    expect(saveCalls, 1);
  });

  testWidgets('does not save an edited image when the screen is disposed during the spend', (tester) async {
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_gate_dispose_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);

    final Completer<void> allowSpend = Completer<void>();
    final Completer<void> spendStarted = Completer<void>();
    var saveCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _toastChannel,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_functionsChannel, (
      message,
    ) async {
      final List<Object?> arguments = _codec.decodeMessage(message)! as List<Object?>;
      final Map<Object?, Object?> call = arguments.single! as Map<Object?, Object?>;
      if (call['functionName'] == 'spendCoins') {
        spendStarted.complete();
        await allowSpend.future;
        return _codec.encodeMessage(<Object?>[
          <String, Object?>{'success': true, 'changed': false, 'previousBalance': 0, 'currentBalance': 0, 'delta': 0},
        ]);
      }
      fail('Unexpected callable: ${call['functionName']}');
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(_mediaChannel, (_) async {
      saveCalls++;
      return PrismMediaHostApi.pigeonChannelCodec.encodeMessage(<Object?>[OperationResult(success: true)]);
    });

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForEditorReady(tester);
    await _tapInvert(tester);
    await tester.tap(_iconButton('Download'));
    await tester.pump();
    await _waitForSignal(tester, spendStarted, 'coin spend request');

    await tester.pumpWidget(const SizedBox());
    allowSpend.complete();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(saveCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the edited export while set options are open and deletes it when canceled', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Directory directory = Directory.systemTemp.createTempSync('wallpaper_filter_set_cancel_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final File source = File('${directory.path}/source.png');
    source.writeAsBytesSync((await tester.runAsync(_smallPng))!);
    app_state.prismUser.premium = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _toastChannel,
      (_) async => true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (_) async => directory.path,
    );

    await tester.pumpWidget(_screenHost(source.path));
    await _waitForEditorReady(tester);
    await _tapInvert(tester);
    await tester.tap(_iconButton('Set as wallpaper'));

    final Finder optionsTitle = find.text('Set Wallpaper as');
    for (var attempt = 0; attempt < 40 && optionsTitle.evaluate().isEmpty; attempt++) {
      await tester.pump(const Duration(milliseconds: 25));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    }
    expect(optionsTitle, findsOneWidget);

    final List<File> editedFiles = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('/edited.png'))
        .toList();
    expect(editedFiles, hasLength(1));
    final File editedFile = editedFiles.single;
    expect(editedFile.existsSync(), isTrue);
    expect(tester.widget<IconButton>(_iconButton('Reset')).onPressed, isNull);
    expect(tester.widget<IconButton>(_iconButton('Set as wallpaper')).onPressed, isNull);

    await tester.tapAt(const Offset(1, 1));
    await tester.pump(const Duration(milliseconds: 300));
    final Finder resetButton = _iconButton('Reset');
    for (
      var attempt = 0;
      attempt < 40 && (editedFile.existsSync() || tester.widget<IconButton>(resetButton).onPressed == null);
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 25));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    }

    expect(editedFile.existsSync(), isFalse);
    expect(Directory(editedFile.parent.path).existsSync(), isFalse);
    expect(tester.widget<IconButton>(resetButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _waitForEditorReady(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump();
    final Finder preview = find.descendant(of: find.byType(AspectRatio).first, matching: find.byType(RawImage));
    if (tester.widget<IconButton>(_iconButton('Download')).onPressed != null &&
        preview.evaluate().isNotEmpty &&
        tester.widget<RawImage>(preview).image != null) {
      return;
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
  }
  fail('Wallpaper editor preview did not decode');
}

Future<void> _tapInvert(WidgetTester tester) async {
  final Finder filters = find.byType(ListView).first;
  for (var attempt = 0; attempt < 6 && find.text('Invert').evaluate().isEmpty; attempt++) {
    await tester.drag(filters, const Offset(-600, 0));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Invert'));
  await tester.pump();
}

Future<void> _waitForSignal(WidgetTester tester, Completer<void> signal, String description) async {
  for (var attempt = 0; attempt < 40 && !signal.isCompleted; attempt++) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
  }
  expect(signal.isCompleted, isTrue, reason: 'Timed out waiting for $description');
  await signal.future;
}
