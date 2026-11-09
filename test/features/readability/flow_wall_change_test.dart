import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/features/readability/data/readability_tips.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

final String _wall = File('assets/images/prism.webp').absolute.path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  int analyses = 0;
  late SettingsLocalDataSource settings;

  setUp(() async {
    await getIt.reset();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    debugDefaultTargetPlatformOverride = null;
    ReadabilityTips.instance.reset();
    ReadabilityTips.useIsolate = false;
    ReadabilityTips.budget = const Duration(minutes: 1);
    analyses = 0;
    ReadabilityTips.analyzer =
        (
          ReadabilityFrame _, {
          required TargetPlatform platform,
          Map<ReadabilityZone, Color> textColors = const <ReadabilityZone, Color>{},
        }) {
          analyses++;
          return <ReadabilityZone, ReadabilityResult>{
            ReadabilityZone.clock: const ReadabilityResult(
              zone: ReadabilityZone.clock,
              lowContrastShare: 0.9,
              edgeShare: 0,
              fix: ReadabilityFixKind.dim,
            ),
            ReadabilityZone.icons: const ReadabilityResult(
              zone: ReadabilityZone.icons,
              lowContrastShare: 0.9,
              edgeShare: 0,
              fix: ReadabilityFixKind.dim,
            ),
          };
        };
  });

  tearDown(() async {
    await getIt.reset();
    debugDefaultTargetPlatformOverride = null;
    ReadabilityTips.instance.reset();
    ReadabilityTips.analyzer = analyzeReadability;
    ReadabilityTips.useIsolate = true;
    ReadabilityTips.budget = const Duration(seconds: 2);
  });

  testWidgets('changing the wall rechecks whether its tip has shown this session', (tester) async {
    await settings.set(ReadabilityTips.enabledKey, false);
    expect(ReadabilityTips.instance.enabled, isFalse);
    int renders = 0;
    Widget preview(String id) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ClockOverlay(
        key: const ValueKey<String>('preview'),
        link: _wall,
        file: true,
        wallpaperId: id,
        request: SetScreenRequest(
          url: _wall,
          onApplyFixes: (_, _) async {
            renders++;
            return null;
          },
        ),
      ),
    );

    await tester.pumpWidget(preview('first'));
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Icons may be hard to read'), findsNothing);
    await settings.set(ReadabilityTips.enabledKey, true);
    await tester.pumpWidget(preview('second'));
    for (int i = 0; i < 30 && find.text('Icons may be hard to read').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(analyses, 1);
    expect(find.text('Icons may be hard to read'), findsOneWidget);

    await tester.tap(find.text('Icons may be hard to read'));
    await tester.pumpAndSettle();
    for (
      int i = 0;
      i < 30 && tester.widget<PrismButton>(find.byKey(const ValueKey<String>('readability-apply'))).onPressed == null;
      i++
    ) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpWidget(preview('third'));
    await tester.tap(find.byKey(const ValueKey<String>('readability-apply')));
    await tester.pumpAndSettle();
    expect(renders, 0);
  });

  testWidgets('iOS full-size fix preview renders no larger than 4096 pixels', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    List<ReadabilityFix> savedFixes = const <ReadabilityFix>[];
    Widget preview(String id) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: const Size(200, 500), devicePixelRatio: 10),
        child: child!,
      ),
      home: ClockOverlay(
        link: _wall,
        file: true,
        wallpaperId: id,
        saveAction: (label, fixes) => ElevatedButton(
          key: const ValueKey<String>('save'),
          onPressed: () => savedFixes = fixes,
          child: Text(label),
        ),
      ),
    );
    await tester.pumpWidget(preview('large-preview'));

    for (int i = 0; i < 30 && find.text('Clock may be hard to read').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Clock may be hard to read'), findsOneWidget);
    await tester.tap(find.text('Clock may be hard to read'));
    await tester.pumpAndSettle();
    for (
      int i = 0;
      i < 30 && tester.widget<PrismButton>(find.byKey(const ValueKey<String>('readability-apply'))).onPressed == null;
      i++
    ) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey<String>('readability-apply')));
    await tester.pumpAndSettle();
    for (int i = 0; i < 30 && find.byKey(const ValueKey<String>('readability-fixed-preview')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    final RawImage image = tester.widget<RawImage>(find.byKey(const ValueKey<String>('readability-fixed-preview')));
    expect(image.image!.width, 1638);
    expect(image.image!.height, 4096);
    await tester.tap(find.byKey(const ValueKey<String>('save')));
    expect(savedFixes, hasLength(1));

    await tester.pumpWidget(preview('new-wall'));
    await tester.tap(find.byKey(const ValueKey<String>('save')));
    expect(savedFixes, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });
}
