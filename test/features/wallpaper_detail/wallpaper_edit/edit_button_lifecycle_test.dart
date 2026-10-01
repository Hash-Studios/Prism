import 'dart:async';
import 'dart:io';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _RealHttpOverrides extends HttpOverrides {}

class _ObservedHttpClient extends Mock implements HttpClient {
  _ObservedHttpClient(this.client);

  final HttpClient client;
  final Completer<void> closed = Completer<void>();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => client.openUrl(method, url);

  @override
  void close({bool force = false}) {
    client.close(force: force);
    closed.complete();
  }
}

Widget _host(StackRouter router, String? url) => MaterialApp(
  home: StackRouterScope(
    controller: router,
    stateHash: 0,
    child: Scaffold(body: EditButton(url: url)),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(WallpaperFilterRoute(filePath: 'unused')));

  late Directory directory;
  const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('edit_button_test_');
    messenger.setMockMethodCallHandler(pathChannel, (_) async => directory.path);
    messenger.setMockMethodCallHandler(toastChannel, (_) async => true);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(pathChannel, null);
    messenger.setMockMethodCallHandler(toastChannel, null);
    directory.deleteSync(recursive: true);
  });

  testWidgets('keeps another editor source and removes only its own session after the route closes', (tester) async {
    final Directory editDirectory = Directory('${directory.path}/prism_edit')..createSync();
    final File activeSource = File('${editDirectory.path}/source_active.img')..writeAsBytesSync(<int>[9, 8, 7]);
    final _MockStackRouter router = _MockStackRouter();
    final List<Object?> hapticTypes = <Object?>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final Completer<WallpaperFilterRoute> pushed = Completer<WallpaperFilterRoute>();
    final Completer<Object?> routeResult = Completer<Object?>();
    when(() => router.push(any())).thenAnswer((invocation) {
      pushed.complete(invocation.positionalArguments.single as WallpaperFilterRoute);
      return routeResult.future;
    });
    final HttpServer server = (await tester.runAsync(() => HttpServer.bind(InternetAddress.loopbackIPv4, 0)))!;
    addTearDown(() => tester.runAsync(() => server.close(force: true)));
    await tester.runAsync(() async {
      server.listen((request) {
        request.response.add(<int>[1, 2, 3]);
        unawaited(request.response.close());
      });
    });

    await tester.pumpWidget(_host(router, 'http://127.0.0.1:${server.port}/wallpaper'));
    await tester.runAsync(
      () => HttpOverrides.runZoned(() async {
        await tester.tap(find.byType(EditButton));
      }, createHttpClient: _RealHttpOverrides().createHttpClient),
    );
    for (int attempt = 0; attempt < 100 && !pushed.isCompleted; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(pushed.isCompleted, isTrue);
    final WallpaperFilterRoute route = await pushed.future;
    final File source = File(route.args!.filePath);
    expect(activeSource.readAsBytesSync(), <int>[9, 8, 7]);
    expect(hapticTypes.where((type) => type == 'HapticFeedbackType.lightImpact'), hasLength(1));
    expect(source.readAsBytesSync(), <int>[1, 2, 3]);
    expect(source.parent.path, isNot(editDirectory.path));

    await tester.runAsync(() async {
      routeResult.complete();
      for (int attempt = 0; attempt < 100 && source.parent.existsSync(); attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(source.parent.existsSync(), isFalse);
    expect(activeSource.readAsBytesSync(), <int>[9, 8, 7]);
    expect(tester.takeException(), isNull);
    expect(hapticTypes, <Object?>['HapticFeedbackType.lightImpact']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('missing wallpaper URL only plays the error haptic', (tester) async {
    final _MockStackRouter router = _MockStackRouter();
    final List<Object?> hapticTypes = <Object?>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') hapticTypes.add(call.arguments);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_host(router, null));
    await tester.tap(find.byType(EditButton));
    await tester.pump();

    expect(hapticTypes, <Object?>['HapticFeedbackType.errorNotification']);
    expect(hapticTypes.where((type) => type == 'HapticFeedbackType.lightImpact'), isEmpty);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('does not create a source or route after disposal while the download is pending', (tester) async {
    final _MockStackRouter router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    final Completer<HttpRequest> received = Completer<HttpRequest>();
    final HttpServer server = (await tester.runAsync(() => HttpServer.bind(InternetAddress.loopbackIPv4, 0)))!;
    addTearDown(() => tester.runAsync(() => server.close(force: true)));
    await tester.runAsync(() async => server.listen(received.complete));
    late _ObservedHttpClient client;

    await tester.pumpWidget(_host(router, 'http://127.0.0.1:${server.port}/wallpaper'));
    await tester.runAsync(
      () => HttpOverrides.runZoned(() async {
        await tester.tap(find.byType(EditButton));
      }, createHttpClient: (context) => client = _ObservedHttpClient(_RealHttpOverrides().createHttpClient(context))),
    );
    for (int attempt = 0; attempt < 100 && !received.isCompleted; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(received.isCompleted, isTrue);
    final HttpRequest request = await received.future;
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      request.response.add(<int>[1, 2, 3]);
      await request.response.close();
      await client.closed.future.timeout(const Duration(seconds: 5));
    });
    for (int attempt = 0; attempt < 10; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }

    expect(directory.listSync(), isEmpty);
    verifyNever(() => router.push(any()));
    expect(tester.takeException(), isNull);
  });
}
