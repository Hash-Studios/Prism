import 'dart:io';

import 'package:Prism/core/debug/local_qa_adapters.dart';
import 'package:Prism/core/debug/local_qa_runtime.dart';
import 'package:Prism/env/env.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QA stores isolate identities and never clear ordinary preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'session': 'ordinary session'});
    final viewer = LocalQaStore('viewer');
    final creator = LocalQaStore('creator');
    await viewer.init();
    await creator.init();
    expect(viewer.get('session'), isNull);
    await viewer.set('session', 'local viewer');
    await creator.set('session', 'local creator');
    expect(await viewer.keys(), <String>['session']);
    await viewer.clearAll();
    expect(viewer.get('session'), isNull);
    expect(creator.get('session'), 'local creator');
    expect((await SharedPreferences.getInstance()).getString('session'), 'ordinary session');
  });

  test('QA requires explicit activation and blocks external hosts and undeclared ports', () async {
    final previous = HttpOverrides.current;
    addTearDown(() => HttpOverrides.global = previous);
    if (!Env.localQa) {
      expect(LocalQaRuntime.installNetworkPolicy, throwsStateError);
      expect(HttpOverrides.current, same(previous));
      return;
    }
    LocalQaRuntime.installNetworkPolicy();
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    for (final url in <String>['https://example.com/', 'http://127.0.0.1:8080/', 'http://169.254.169.254/']) {
      await expectLater(() => client.getUrl(Uri.parse(url)), throwsStateError);
    }
  });
}
