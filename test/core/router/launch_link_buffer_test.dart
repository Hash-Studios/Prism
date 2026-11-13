import 'package:Prism/core/router/launch_link_buffer.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
    final LaunchLinkBuffer buffer = LaunchLinkBuffer.install();
    addTearDown(() => buffer.drain((_) {}));

    await pushFromPlatform(tester, 'prism://streak?widget=streak_android');
    await pushFromPlatform(tester, 'https://prismwalls.com/l/abc');

    final List<Uri> opened = <Uri>[];
    buffer.drain(opened.add);

    expect(opened, <Uri>[Uri.parse('prism://streak?widget=streak_android'), Uri.parse('https://prismwalls.com/l/abc')]);
  });

  testWidgets('after the app is ready, the buffer lets links go to the router', (tester) async {
    final LaunchLinkBuffer buffer = LaunchLinkBuffer.install();
    final List<Uri> opened = <Uri>[];
    buffer.drain(opened.add);

    final _RouterStandIn router = _RouterStandIn();
    tester.binding.addObserver(router);
    addTearDown(() => tester.binding.removeObserver(router));
    await pushFromPlatform(tester, 'prism://streak');

    expect(opened, isEmpty);
    expect(router.received, <Uri>[Uri.parse('prism://streak')]);
  });
}

class _RouterStandIn with WidgetsBindingObserver {
  final List<Uri> received = <Uri>[];

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    received.add(routeInformation.uri);
    return true;
  }
}
