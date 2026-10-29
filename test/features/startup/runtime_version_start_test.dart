import 'dart:async';

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/main.dart' as app_main;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('mounts startup only after the runtime build number is ready', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Prism test',
      packageName: 'com.hash.prism.test',
      version: '3.14.0',
      buildNumber: '353',
      buildSignature: '',
    );
    final Completer<void> versionGate = Completer<void>();
    final Future<void> versionReady = versionGate.future.then((_) => app_state.initializeRuntimeAppVersion());
    final Future<void> starting = app_main.runAppWithRuntimeVersion(
      versionReady,
      MaterialApp(home: Builder(builder: (_) => Text(app_state.currentAppVersionCode))),
    );

    await tester.pump();
    expect(find.byType(MaterialApp), findsNothing);

    versionGate.complete();
    await starting;
    await tester.pumpAndSettle();

    expect(find.text('353'), findsOneWidget);
  });
}
