import 'package:Prism/core/debug/local_qa_adapters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = LocalQaMessenger(binding.defaultBinaryMessenger);
  const codec = StandardMethodCodec();
  for (final channel in <String>[
    'plugins.flutter.io/firebase_messaging',
    'plugins.flutter.io/firebase_analytics',
    'plugins.flutter.io/firebase_remote_config',
    'dev.flutter.pigeon.firebase_analytics_platform_interface.FirebaseAnalyticsHostApi.logEvent',
    'dev.flutter.pigeon.firebase_remote_config_platform_interface.FirebaseRemoteConfigHostApi.fetch.fixture',
  ]) {
    test('QA denies $channel before native dispatch', () async {
      final reply = await messenger.send(channel, null);
      expect(reply, isNotNull);
      expect(
        () => codec.decodeEnvelope(reply!),
        throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'local-qa-disabled')),
      );
    });
  }
  for (final channel in <String>[
    'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.signInAnonymously',
    'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
    'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
    'plugins.flutter.io/firebase_functions',
  ]) {
    test('QA forwards $channel to the native messenger', () async {
      final calls = <String>[];
      binding.defaultBinaryMessenger.setMockMessageHandler(channel, (data) async {
        calls.add(channel);
        return codec.encodeSuccessEnvelope('forwarded');
      });
      addTearDown(() => binding.defaultBinaryMessenger.setMockMessageHandler(channel, null));
      final reply = await messenger.send(channel, null);
      expect(codec.decodeEnvelope(reply!), 'forwarded');
      expect(calls, <String>[channel]);
    });
  }
}
