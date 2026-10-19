import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/shop/biz/bloc/shop_bloc.j.dart';
import 'package:Prism/features/theme_mode/data/legacy_themes.dart';
import 'package:Prism/features/theme_mode/domain/entities/theme_preferences.dart';
import 'package:Prism/features/theme_mode/theme_mode.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockThemeBloc extends MockBloc<ThemeEvent, ThemeState> implements ThemeBloc {}

void main() {
  late _MockThemeBloc themeBloc;
  late SettingsLocalDataSource settings;
  final CoinsService coins = CoinsService.instance;

  setUpAll(() => registerFallbackValue(const ThemeEvent.started()));

  setUp(() async {
    themeBloc = _MockThemeBloc();
    when(() => themeBloc.state).thenReturn(ThemeState.initial());
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerFactory<ShopBloc>(() => ShopBloc(settings));
    coins.inventoryNotifier.value = Inventory.empty;
    coins.balanceNotifier.value = 0;
  });

  tearDown(() async {
    coins.inventoryNotifier.value = Inventory.empty;
    await getIt.reset();
  });

  Future<void> pumpPicker(WidgetTester tester, {ThemeState? state}) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => themeBloc.state).thenReturn((state ?? ThemeState.initial()).copyWith(mode: ThemeMode.system));
    await tester.pumpWidget(
      BlocProvider<ThemeBloc>.value(
        value: themeBloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.light(),
          home: const ThemeView(),
        ),
      ),
    );
    await tester.pump();
  }

  Finder lockedIn(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(MaterialButton)),
    matching: find.text('Locked'),
  );

  testWidgets('shop themes are locked and free themes are not', (tester) async {
    await pumpPicker(tester);

    expect(lockedIn('Rose'), findsOneWidget);
    expect(lockedIn('Cotton Blue'), findsOneWidget);
    expect(lockedIn('Coffee'), findsNothing);
    expect(lockedIn('Frost White'), findsNothing);
    expect(lockedIn('Olive'), findsOneWidget);
    expect(lockedIn('AMOLED'), findsNothing);
  });

  testWidgets('tapping a locked theme opens the shop sheet and does not select it', (tester) async {
    await pumpPicker(tester);

    await tester.tap(find.text('Rose'));
    await tester.pumpAndSettle();

    verifyNever(
      () => themeBloc.add(any(that: isA<ThemeEvent>().having((e) => e.toString(), 'text', contains('kLRose')))),
    );
    expect(find.text('Rose'), findsWidgets);
    expect(find.text('You need 150 more coins.'), findsOneWidget);
  });

  testWidgets('a bought theme selects normally', (tester) async {
    coins.inventoryNotifier.value = const Inventory(owned: <String>{'theme_rose'});
    await pumpPicker(tester);

    expect(lockedIn('Rose'), findsNothing);
    await tester.tap(find.text('Rose'));

    verify(() => themeBloc.add(const ThemeEvent.lightThemeChanged(themeId: 'kLRose'))).called(1);
  });

  testWidgets('a theme grandfathered on this device is never locked', (tester) async {
    await settings.set(legacyThemesSettingsKey, 'kLCotton Blue,kDOlive');
    await pumpPicker(tester);

    expect(lockedIn('Cotton Blue'), findsNothing);
    expect(lockedIn('Olive'), findsNothing);
    expect(lockedIn('Rose'), findsOneWidget);
  });

  testWidgets('the selected theme stays selected and is not re-locked', (tester) async {
    final ThemeState initial = ThemeState.initial();
    await pumpPicker(
      tester,
      state: initial.copyWith(
        light: ThemeSelection(themeId: 'kLRose', accentColorValue: initial.light.accentColorValue),
      ),
    );

    expect(lockedIn('Rose'), findsNothing);
    expect(lockedIn('Cotton Blue'), findsOneWidget);
  });
}
