import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore smoke test targets the root coin transaction ledger', () async {
    final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final List<String> paths = <String>[];
    final Map<String, int> counts = <String, int>{};
    Map<String, Object?>? ledgerPayload;
    final List<int> targetStatuses = <int>[200, 200, 200, 200, 403, 403, 403];
    final List<int> userStatuses = <int>[403, 403, 403, 403, 200];
    final Future<void> requests = () async {
      await for (final HttpRequest request in server) {
        final String path = request.uri.path.substring('/v1/projects/demo-prism/databases/(default)/documents'.length);
        paths.add(path);
        final String body = await utf8.decoder.bind(request).join();
        final int count = counts.update(path, (int value) => value + 1, ifAbsent: () => 1);
        int status = 200;
        if (path == '/usersv2/target') {
          status = targetStatuses[count - 1];
        } else if (path == '/usersv2/b') {
          status = count == 1 ? 200 : userStatuses[count - 2];
        } else if (path == '/coinTransactions/t1') {
          ledgerPayload = jsonDecode(body) as Map<String, Object?>;
          status = 403;
        } else if (path == '/usersv2/b/coinTransactions/t1') {
          status = 200;
        } else if (path == '/walls/w2') {
          status = 403;
        } else if (path == '/walls/w1' || path == '/walls/w3' || path == '/admin_users/admin@x.com') {
          status = 200;
        }
        request.response.statusCode = status;
        await request.response.close();
      }
    }();

    try {
      final ProcessResult result = await Process.run(
        'node',
        <String>['tool/firestore_rules_smoke.mjs'],
        environment: <String, String>{'FIRESTORE_EMULATOR_HOST': '127.0.0.1:${server.port}'},
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(paths, contains('/coinTransactions/t1'));
      expect(paths, isNot(contains('/usersv2/b/coinTransactions/t1')));
      expect(ledgerPayload, <String, Object?>{
        'fields': <String, Object?>{
          'userId': <String, String>{'stringValue': 'b'},
          'delta': <String, String>{'integerValue': '500'},
        },
      });
    } finally {
      await server.close(force: true);
      await requests;
    }
  });
}
