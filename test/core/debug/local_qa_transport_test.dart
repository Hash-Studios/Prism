import 'dart:io';

import 'package:Prism/core/debug/local_qa_adapters.dart';
import 'package:Prism/core/debug/local_qa_runtime.dart';
import 'package:Prism/env/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('local fixture HTTPS performs TLS and returns actual image bytes', () async {
    final previous = HttpOverrides.current;
    addTearDown(() => HttpOverrides.global = previous);
    LocalQaRuntime.installNetworkPolicy();
    expect(await LocalQaConnectivity().hasConnection(), isTrue);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.getUrl(Uri.parse('https://localhost:19375/wallpaper.jpg'));
    final response = await request.close();
    final bytes = await response.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
    expect(response.statusCode, 200);
    expect(bytes.take(3).toList(), <int>[0xff, 0xd8, 0xff]);
  }, skip: !Env.localQa);
}
