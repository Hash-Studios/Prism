import 'dart:async';

import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/launch_link_buffer.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pushFromPlatform(WidgetTester tester, String location) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        MethodCall('pushRouteInformation', <String, Object?>{'location': location}),
      ),
      (_) {},
    );
  }

  testWidgets('a link pushed before the app router exists is opened when the app is ready', (tester) async {
    final LaunchLinkBuffer buffer = LaunchLinkBuffer()..install();
    addTearDown(() => buffer.drain((_) {}));

    await pushFromPlatform(tester, 'prism://streak?widget=streak_android');
    await pushFromPlatform(tester, 'https://prismwalls.com/l/abc');

    final List<Uri> opened = <Uri>[];
    buffer.drain(opened.add);

    expect(opened, <Uri>[Uri.parse('prism://streak?widget=streak_android'), Uri.parse('https://prismwalls.com/l/abc')]);
  });

  testWidgets('after the app is ready, the buffer lets links go to the router', (tester) async {
    final LaunchLinkBuffer buffer = LaunchLinkBuffer()..install();
    final List<Uri> opened = <Uri>[];
    buffer.drain(opened.add);

    final _RouterStandIn router = _RouterStandIn();
    tester.binding.addObserver(router);
    addTearDown(() => tester.binding.removeObserver(router));
    await pushFromPlatform(tester, 'prism://streak');

    expect(opened, isEmpty);
    expect(router.received, <Uri>[Uri.parse('prism://streak')]);
  });

  for (final String initial in <String>['prism://streak?widget=streak_android', 'prism://downloads']) {
    testWidgets('a buffered intent supersedes the task initial route $initial', (tester) async {
      final LaunchLinkBuffer buffer = LaunchLinkBuffer()..install();
      addTearDown(() => buffer.drain((_) {}));
      final List<Uri> opened = <Uri>[];
      tester.platformDispatcher.defaultRouteNameTestValue = initial;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      await pushFromPlatform(tester, 'prism://streak?widget=streak_android');
      await tester.pumpWidget(_LaunchApp(buffer: buffer, opened: opened));
      await tester.pumpAndSettle();

      expect(opened, <Uri>[Uri.parse('prism://streak?widget=streak_android')]);
    });
  }

  testWidgets('a cold launch initial route is handled once without entering the buffer', (tester) async {
    final LaunchLinkBuffer buffer = LaunchLinkBuffer()..install();
    addTearDown(() => buffer.drain((_) {}));
    final List<Uri> opened = <Uri>[];
    final Uri initial = Uri.parse('prism://share-in?text=hello&src=com.android.chrome');
    tester.platformDispatcher.defaultRouteNameTestValue = initial.toString();
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(_LaunchApp(buffer: buffer, opened: opened));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_LaunchApp(buffer: buffer, opened: opened));
    await tester.pumpAndSettle();

    expect(opened, <Uri>[initial]);
  });

  testWidgets('restarting after a buffered share does not replay either launch delivery', (tester) async {
    final LaunchLinkBuffer buffer = LaunchLinkBuffer()..install();
    addTearDown(() => buffer.drain((_) {}));
    final List<Uri> opened = <Uri>[];
    const String share = 'prism://share-in?text=hello&src=com.android.chrome';
    tester.platformDispatcher.defaultRouteNameTestValue = 'prism://share-in?text=old&src=com.android.chrome';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    await pushFromPlatform(tester, share);
    await tester.pumpWidget(_LaunchApp(buffer: buffer, opened: opened));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_LaunchApp(buffer: buffer, opened: opened));
    await tester.pumpAndSettle();

    expect(opened, <Uri>[Uri.parse(share)]);

    await pushFromPlatform(tester, share);
    await tester.pumpAndSettle();

    expect(opened, <Uri>[Uri.parse(share), Uri.parse(share)]);
  });

  testWidgets('a push scheduled during initState reaches the router after drain', (tester) async {
    final LaunchLinkBuffer buffer = LaunchLinkBuffer()..install();
    addTearDown(() => buffer.drain((_) {}));
    final List<Uri> opened = <Uri>[];
    final Completer<void> pushed = Completer<void>();

    await tester.pumpWidget(
      _LaunchApp(
        buffer: buffer,
        opened: opened,
        onInit: () => scheduleMicrotask(() async {
          await pushFromPlatform(tester, 'prism://streak');
          pushed.complete();
        }),
      ),
    );
    await pushed.future;
    await tester.pumpAndSettle();

    expect(opened, <Uri>[Uri.parse('prism://streak')]);
  });

  testWidgets('a default initial route does not consume a later launch link', (tester) async {
    final LaunchLinkBuffer buffer = LaunchLinkBuffer();
    final List<Uri> opened = <Uri>[];
    final Uri initial = Uri.parse('prism:///streak');

    if (buffer.claimInitialLink(Uri.parse('/'))) opened.add(Uri.parse('/'));
    if (buffer.claimInitialLink(initial)) opened.add(initial);
    if (buffer.claimInitialLink(initial)) opened.add(initial);

    expect(opened, <Uri>[initial]);
  });
}

class _LaunchApp extends StatefulWidget {
  const _LaunchApp({required this.buffer, required this.opened, this.onInit});

  final LaunchLinkBuffer buffer;
  final List<Uri> opened;
  final VoidCallback? onInit;

  @override
  State<_LaunchApp> createState() => _LaunchAppState();
}

class _LaunchAppState extends State<_LaunchApp> {
  late final _LaunchRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _LaunchRouter();
    widget.buffer.drain(widget.opened.add);
    widget.onInit?.call();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: _router.config(
      deepLinkTransformer: (uri) async => const DeepLinkParser().transform(uri),
      deepLinkBuilder: (link) {
        if (link.initial && !widget.buffer.claimInitialLink(link.uri)) return DeepLink.defaultPath;
        widget.opened.add(link.uri);
        return link.initial ? DeepLink.defaultPath : DeepLink.none;
      },
    ),
  );
}

class _LaunchRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('Home', builder: (_) => const SizedBox.shrink()),
    ),
    AutoRoute(
      path: '*',
      page: PageInfo('Link', builder: (_) => const SizedBox.shrink()),
    ),
  ];
}

class _RouterStandIn with WidgetsBindingObserver {
  final List<Uri> received = <Uri>[];

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    received.add(routeInformation.uri);
    return true;
  }
}
