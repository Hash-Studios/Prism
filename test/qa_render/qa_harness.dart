import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/coins_test_backend.dart';
import 'qa_images.dart';

const bool qaRender = bool.fromEnvironment('QA_RENDER') || int.fromEnvironment('QA_RENDER') == 1;

/// A rich signed-in user: 340 coins, 1240 XP, a 12-day streak, two quests done, frame_ring worn, two drop unlocks.
void seedUser({required bool pro}) {
  final CoinsService coins = CoinsService.instance;
  app_state.prismUser
    ..premium = pro
    ..loggedIn = true;
  coins.balanceNotifier.value = 340;
  coins.xpNotifier.value = XpStatus.fromUserData(<String, dynamic>{
    'xp': 1240,
    'xpWeek': <String, dynamic>{'weekKey': economyWeekKey(DateTime.now()), 'xp': 180},
  });
  coins.streakNotifier.value = StreakStatus.empty.copyWith(
    count: 12,
    best: 14,
    streakDay: 5,
    freezes: 1,
    active: true,
    claimedToday: true,
  );
  coins.inventoryNotifier.value = const Inventory(
    owned: <String>{'frame_ring', 'theme_rose', 'glow_aurora'},
    frame: 'frame_ring',
  );
}

void resetUser() {
  final CoinsService coins = CoinsService.instance;
  coins.inventoryNotifier.value = Inventory.empty;
  coins.xpNotifier.value = XpStatus.empty();
  coins.streakNotifier.value = StreakStatus.empty;
  coins.questsNotifier.value = null;
  coins.dropsUnlockedNotifier.value = const <String, DropUnlock>{};
  coins.passesNotifier.value = Passes.empty;
  EconomyConfig.resetForTest();
  app_state.prismUser = app_constants.createGuestPrismUser();
}

Future<void> loadFonts() async {
  await (FontLoader('Proxima Nova')
        ..addFont(rootBundle.load('assets/fonts/ProximaNova-Regular.otf'))
        ..addFont(rootBundle.load('assets/fonts/Proxima Nova Bold.otf'))
        ..addFont(rootBundle.load('assets/fonts/Proxima Nova Extrabold.otf')))
      .load();
  await (FontLoader('Fraunces')..addFont(rootBundle.load('assets/fonts/Fraunces-Variable.ttf'))).load();
  await (FontLoader('JamIcons')..addFont(rootBundle.load('assets/fonts/JamIcons.ttf'))).load();
  final String flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/fvm/versions/3.47.8';
  final Uint8List materialIcons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final FontLoader roboto = FontLoader('Roboto');
  for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
    final Uint8List data = File('$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf').readAsBytesSync();
    roboto.addFont(Future<ByteData>.value(ByteData.sublistView(data)));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(Future<ByteData>.value(ByteData.sublistView(materialIcons)))).load();
}

class MockStackRouter extends Mock implements StackRouter {}

class QaShot {
  QaShot(this.tester, this.brightness, this.theme, this.backend);

  final WidgetTester tester;
  final CoinsTestBackend backend;
  final MockStackRouter router = MockStackRouter();
  final Brightness brightness;
  final ThemeData theme;
  final GlobalKey boundary = GlobalKey();

  String get mode => brightness == Brightness.light ? 'light' : 'dark';

  /// Mounts [home] in a real-theme app inside the capture boundary.
  Future<void> pump(Widget home, {NavigatorObserver? observer}) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          debugShowCheckedModeBanner: false,
          theme: theme,
          home: StackRouterScope(controller: router, stateHash: 0, child: home),
        ),
      ),
    );
    await settle();
  }

  /// Bounded pumps: Glint and the coin shimmer animate forever, so `pumpAndSettle` would time out.
  Future<void> settle({int frames = 6}) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      // Image files load on real IO, which fake time never advances.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    }
  }

  Future<void> save(String name) async {
    final RenderRepaintBoundary render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final File file = File('build/qa_render/${name}_$mode.png');
    await tester.runAsync(() async {
      final ui.Image image = await render.toImage(pixelRatio: 3);
      final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }
}

typedef QaBody = Future<void> Function(QaShot shot);

/// Registers one test per theme (Frost White light, Material Dark) at 390x844 logical px, DPR 3.
void qaScreen(
  String description,
  QaBody body, {
  bool pro = false,
  double height = 844,
  FutureOr<void> Function()? setUpExtra,
}) {
  for (final (Brightness brightness, ThemeData theme) in <(Brightness, ThemeData)>[
    (Brightness.light, kLightTheme),
    (Brightness.dark, kDarkTheme),
  ]) {
    testWidgets('$description (${brightness.name})', skip: !qaRender, (WidgetTester tester) async {
      tester.view.physicalSize = Size(1170, height * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final CoinsTestBackend backend = CoinsTestBackend();
      await backend.install();
      seedUser(pro: pro);
      await QaImages.install(tester);
      addTearDown(() async {
        QaImages.uninstall();
        resetUser();
        await getIt.reset();
      });
      await setUpExtra?.call();
      final QaShot shot = QaShot(tester, brightness, theme, backend);
      when(() => shot.router.push(any())).thenAnswer((_) async => null);
      when(() => shot.router.pushPath(any())).thenAnswer((_) async => null);
      await body(shot);
      expect(tester.takeException(), isNull);
    });
  }
}
