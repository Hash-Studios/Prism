import 'package:Prism/core/platform/app_icon_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_app_icon_api.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Object?> setCalls;
  late bool setResult;
  late bool supports;

  void mock(String method, Object? Function(List<Object?> args) answer) {
    messenger.setMockMessageHandler('dev.flutter.pigeon.Prism.PrismAppIconHostApi.$method', (ByteData? message) async {
      final List<Object?> args =
          (PrismAppIconHostApi.pigeonChannelCodec.decodeMessage(message) as List<Object?>?) ?? [];
      return PrismAppIconHostApi.pigeonChannelCodec.encodeMessage(<Object?>[answer(args)]);
    });
  }

  setUp(() {
    setCalls = <Object?>[];
    setResult = true;
    supports = true;
    AppIconChannel.api = PrismAppIconHostApi();
    mock('setAppIcon', (List<Object?> args) {
      setCalls.add(args.first);
      return setResult;
    });
    mock('supportsAlternateIcons', (_) => supports);
  });

  tearDown(() {
    for (final String method in <String>['setAppIcon', 'supportsAlternateIcons']) {
      messenger.setMockMessageHandler('dev.flutter.pigeon.Prism.PrismAppIconHostApi.$method', null);
    }
  });

  test('maps every catalog id to its native icon name', () async {
    const Map<String, String> expected = <String, String>{
      'icon_noir': 'AppIconNoir',
      'icon_glass': 'AppIconGlass',
      'icon_sunset': 'AppIconSunset',
      'icon_mono': 'AppIconMono',
    };
    for (final MapEntry<String, String> entry in expected.entries) {
      expect(await AppIconChannel.setIcon(entry.key), isTrue);
      expect(setCalls.last, entry.value);
    }
  });

  test('null restores the default icon', () async {
    expect(await AppIconChannel.setIcon(null), isTrue);
    expect(setCalls, <Object?>[null]);
  });

  test('an unknown id never reaches the platform', () async {
    expect(await AppIconChannel.setIcon('icon_missing'), isFalse);
    expect(setCalls, isEmpty);
  });

  test('returns false when the platform refuses', () async {
    setResult = false;
    expect(await AppIconChannel.setIcon('icon_noir'), isFalse);
  });

  test('supported follows the platform', () async {
    expect(await AppIconChannel.supported(), isTrue);
    supports = false;
    expect(await AppIconChannel.supported(), isFalse);
  });
}
