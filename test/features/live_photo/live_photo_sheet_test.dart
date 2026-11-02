import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/features/live_photo/biz/bloc/live_photo_bloc.j.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_photo/views/live_photo_sheet.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';
import 'fake_live_photo_repository.dart';

const String _saveLabel = 'Save Live Photo';
const String _sourceUrl = 'https://example.com/source.jpg';

final PrismThemeOption _frost = prismLightThemes.first;
final ThemeData _theme = withPrismAccent(_frost.theme, _frost.defaultAccentValue);

Widget _host(void Function(BuildContext context) open, {TextScaler? textScaler}) => MaterialApp(
  theme: _theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: textScaler == null
      ? null
      : (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(onPressed: () => open(context), child: const Text('open')),
    ),
  ),
);

void main() {
  late FakeLivePhotoRepository repository;
  late FakeAppAnalytics analytics;

  setUp(() {
    PrismDeviceCornerRadius.setValueForTesting(48);
    repository = FakeLivePhotoRepository();
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(AnalyticsRuntime.reset);

  LivePhotoBloc bloc({bool isPro = true}) {
    final LivePhotoBloc created = LivePhotoBloc(
      repository,
      wallId: 'wall-1',
      resolveSource: () async => _sourceUrl,
      isPro: isPro,
    );
    addTearDown(created.close);
    return created;
  }

  void Function(BuildContext context) sheetOf(LivePhotoBloc livePhotoBloc) =>
      (context) => showPrismSheet<void>(
        context,
        builder: (_) => BlocProvider<LivePhotoBloc>.value(value: livePhotoBloc, child: const LivePhotoSheet()),
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> startExport(WidgetTester tester) async {
    await tester.tap(find.text(_saveLabel));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.exports, hasLength(1));
  }

  testWidgets('picking shows the three styles, Save, and a lock on Breathe for a free user', (tester) async {
    await tester.pumpWidget(_host(sheetOf(bloc(isPro: false))));
    await openSheet(tester);

    expect(find.text('Drift'), findsOneWidget);
    expect(find.text('Breathe'), findsOneWidget);
    expect(find.text('Shimmer'), findsOneWidget);
    expect(find.text(_saveLabel), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('live-photo-style-breathe')),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('live-photo-style-drift')),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets('a Pro user sees no lock on Breathe', (tester) async {
    await tester.pumpWidget(_host(sheetOf(bloc())));
    await openSheet(tester);

    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('progress shows the status, the percent and Cancel, and Cancel stops the export', (tester) async {
    await tester.pumpWidget(_host(sheetOf(bloc())));
    await openSheet(tester);

    await startExport(tester);
    expect(find.text('Making your Live Photo'), findsOneWidget);

    repository.lastOnProgress!(0.4);
    await tester.pump();
    expect(find.text('40% done'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repository.cancelCount, 1);
    expect(find.text(_saveLabel), findsOneWidget);
  });

  testWidgets('a refusal from Photos shows the access message with Open settings and Not now', (tester) async {
    await tester.pumpWidget(_host(sheetOf(bloc())));
    await openSheet(tester);
    await startExport(tester);

    repository.complete(const LiveExportRefused(restricted: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text("Prism can't add to Photos"), findsOneWidget);
    expect(find.textContaining('To save a Live Photo, allow Prism to add photos.'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('a restricted refusal shows the Screen Time message', (tester) async {
    await tester.pumpWidget(_host(sheetOf(bloc())));
    await openSheet(tester);
    await startExport(tester);

    repository.complete(const LiveExportRefused(restricted: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Photos access is blocked on this iPhone'), findsOneWidget);
  });

  testWidgets('a timeout shows the retry message with Try again', (tester) async {
    await tester.pumpWidget(_host(sheetOf(bloc())));
    await openSheet(tester);
    await startExport(tester);

    repository.complete(const LiveExportTimedOut());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('This took too long. Try again, or pick another style.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the progress area exposes its status as a label and the percent as a value', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(sheetOf(bloc())));
    await openSheet(tester);
    await startExport(tester);

    repository.lastOnProgress!(0.4);
    await tester.pump();

    final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Making your Live Photo'));
    expect(node.value, '40%');
    repository.complete(const LiveExportCancelled());
    await tester.pump();
    semantics.dispose();
  });

  testWidgets('the picking sheet lays out at large text on a phone-sized surface', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(sheetOf(bloc()), textScaler: const TextScaler.linear(2.0)));
    await openSheet(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing an unlock after its export bloc closes does not add an event', (tester) async {
    app_state.prismUser = profileUser();
    final LivePhotoBloc livePhotoBloc = bloc(isPro: false);
    await tester.pumpWidget(_host(sheetOf(livePhotoBloc)));
    await openSheet(tester);
    await tester.tap(find.text('Breathe'));
    await tester.pump();
    await tester.tap(find.text(_saveLabel));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Breathe is a paid style'), findsOneWidget);

    await tester.runAsync(livePhotoBloc.close);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });

  group('LivePhotoGuideSheet', () {
    void guideSheet(BuildContext context) => showPrismSheet<void>(context, builder: (_) => const LivePhotoGuideSheet());

    testWidgets('shows the three steps, the four notes and the buttons', (tester) async {
      await tester.pumpWidget(_host(guideSheet));
      await openSheet(tester);

      expect(find.text('Set it as your Lock Screen'), findsOneWidget);
      expect(find.text('Open Photos. The new photo has a LIVE badge.'), findsOneWidget);
      expect(find.text('Tap Share, then Use as Wallpaper.'), findsOneWidget);
      expect(find.text('Make sure the Live Photo button at the bottom is on, then tap Add.'), findsOneWidget);
      expect(find.text('Good to know'), findsOneWidget);
      expect(
        find.text('Motion plays on the Lock Screen when you wake your iPhone. The Home Screen shows the still photo.'),
        findsOneWidget,
      );
      expect(find.text('Low Power Mode turns off Lock Screen motion.'), findsOneWidget);
      expect(
        find.text('If iOS says Motion not available, use it as a still wallpaper or try another style.'),
        findsOneWidget,
      );
      expect(find.text('Lock Screen motion needs iOS 17 or later.'), findsOneWidget);
      expect(find.text('Open Photos'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('lays out at large text on a phone-sized surface', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(guideSheet, textScaler: const TextScaler.linear(2.0)));
      await openSheet(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
