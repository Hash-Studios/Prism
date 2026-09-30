import 'dart:io';

import 'package:Prism/core/platform/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      MethodCall call,
    ) async {
      calls.add(call);
      return 'shared';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  testWidgets('shares file and text from the exact caller bounds for iPad popover anchoring', (tester) async {
    late BuildContext shareContext;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 32, top: 48),
            child: SizedBox(
              width: 80,
              height: 40,
              child: Builder(
                builder: (BuildContext context) {
                  shareContext = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      final Directory directory = await Directory.systemTemp.createTemp('share_service_test');
      final File file = await File('${directory.path}/card.png').writeAsBytes(<int>[1, 2, 3]);
      try {
        await ShareService.shareFile(file: file, text: 'wall link', context: shareContext);

        expect(calls, hasLength(1));
        final Map<Object?, Object?> args = calls.single.arguments as Map<Object?, Object?>;
        expect(args['text'], 'wall link');
        expect(args['paths'], <String>[file.path]);
        expect(args['mimeTypes'], <String>['image/png']);
        expect(args['originX'], 32.0);
        expect(args['originY'], 48.0);
        expect(args['originWidth'], 80.0);
        expect(args['originHeight'], 40.0);
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  testWidgets('uses a valid fallback anchor when context is missing or has zero size', (tester) async {
    await ShareService.shareText(text: 'link');
    expect(_origin(calls.last), const <String, double>{
      'originX': 1,
      'originY': 1,
      'originWidth': 1,
      'originHeight': 1,
    });

    late BuildContext zeroSizeContext;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.shrink(
            child: Builder(
              builder: (BuildContext context) {
                zeroSizeContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    await ShareService.shareText(text: 'link', context: zeroSizeContext);
    expect(_origin(calls.last), const <String, double>{
      'originX': 1,
      'originY': 1,
      'originWidth': 1,
      'originHeight': 1,
    });
  });
}

Map<String, double> _origin(MethodCall call) {
  final Map<Object?, Object?> args = call.arguments as Map<Object?, Object?>;
  return <String, double>{
    'originX': (args['originX'] as num).toDouble(),
    'originY': (args['originY'] as num).toDouble(),
    'originWidth': (args['originWidth'] as num).toDouble(),
    'originHeight': (args['originHeight'] as num).toDouble(),
  };
}
