import 'dart:io';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_wallpaper_helpers.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_history_strip.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_preview_stage.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectivityService implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

class _FakeRepository extends Fake implements AiGenerationRepositoryImpl {
  _FakeRepository(this.history);

  final List<AiGenerationRecord> history;
  final Map<String, String> prompts = <String, String>{};

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async => history;

  @override
  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async =>
      const <AiGenerationRecord>[];

  @override
  Future<String?> loadPrompt({required String userId}) async => prompts[userId];

  @override
  Future<void> savePrompt({required String userId, required String prompt}) async {
    prompts[userId] = prompt;
  }

  @override
  Future<void> clearForUser(String userId) async {
    prompts.remove(userId);
  }
}

class _StatusLocalizations extends AppLocalizationsEn {
  @override
  String get economyAiMatchingScreenSize => 'Localized matching';

  @override
  String get economyAiApplyingStyle => 'Localized styling';

  @override
  String get economyAiFinalizingWallpaper => 'Localized finalizing';
}

class _StatusLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture<AppLocalizations>(_StatusLocalizations());

  @override
  bool shouldReload(_StatusLocalizationsDelegate old) => false;
}

AiGenerationRecord _record() => AiGenerationRecord(
  id: 'generation-1',
  userId: 'user-1',
  createdAt: DateTime.utc(2026),
  prompt: 'A quiet mountain lake',
  stylePreset: AiStylePreset.nature,
  qualityTier: AiQualityTier.fast,
  provider: 'test',
  model: 'test',
  seed: 1,
  width: 720,
  height: 1280,
  imageUrl: '',
  watermarkedImageUrl: '',
  chargeMode: AiChargeMode.freeTrial,
  coinsSpent: 0,
  status: 'success',
);

Future<void> openFirstRecent(WidgetTester tester) async {
  final Finder thumb = find.descendant(of: find.byType(AiHistoryStrip), matching: find.byType(AiGenerationThumb)).first;
  await tester.ensureVisible(thumb);
  await tester.tap(thumb);
  await tester.pumpAndSettle();
}

void main() {
  test('TLS handshake failures are classified as network errors', () {
    expect(isAiOfflineOrNetworkError(const HandshakeException('TLS handshake failed')), isTrue);
  });

  testWidgets('AI generation status cycles through localized copy', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          _StatusLocalizationsDelegate(),
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: AiPreviewStage(generating: true))),
      ),
    );

    expect(find.text('Localized matching'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Localized styling'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    List<AiGenerationRecord> history = const <AiGenerationRecord>[],
    bool premium = false,
    _FakeRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true
      ..premium = premium;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    CoinsService.instance.balanceNotifier.value = 100;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(repository: repository ?? _FakeRepository(history)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('compose state puts the prompt first, then style and quality', (tester) async {
    await pumpPage(tester);

    expect(find.text('AI wallpaper'), findsOneWidget);
    expect(find.text(AppLocalizationsEn().economyAiDescribeScene), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Anime'), findsOneWidget);
    expect(find.text('Quality'), findsWidgets);
    expect(find.text('Generate'), findsOneWidget);
    expect(find.byTooltip('Shuffle a new example description'), findsOneWidget);
    expect(find.byTooltip('Use this scene in your description (editable)'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Each wallpaper you generate appears here, so you can compare or switch back.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('generated examples are not saved and follow the active locale', (tester) async {
    final _FakeRepository repository = _FakeRepository(const <AiGenerationRecord>[]);
    await pumpPage(tester, repository: repository);
    final String englishPrompt = tester.widget<TextField>(find.byType(TextField)).controller!.text;

    expect(repository.prompts, isEmpty);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    final String spanishPrompt = tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(spanishPrompt, isNot(englishPrompt));
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.prompts, isEmpty);
  });

  testWidgets('restored and user-edited prompts survive locale changes', (tester) async {
    final _FakeRepository repository = _FakeRepository(const <AiGenerationRecord>[])
      ..prompts['user-1'] = 'A saved description';
    await pumpPage(tester, repository: repository);

    expect(find.text('A saved description'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A saved description'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'A new user description');
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.prompts['user-1'], 'A new user description');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A new user description'), findsOneWidget);
  });

  testWidgets('Generate is off with a reason while the description is empty', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(find.text(AppLocalizationsEn().economyAiDescribeScene), findsNWidgets(2));
    expect(tester.widget<PrismButton>(find.byType(PrismButton).last).onPressed, isNull);
  });

  testWidgets('picking a style keeps what the user typed', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'my own idea');
    await tester.pump();
    await tester.tap(find.text('Anime'));
    await tester.pump();

    expect(find.text('my own idea'), findsOneWidget);
  });

  testWidgets('picking a style replaces a prompt the app wrote', (tester) async {
    await pumpPage(tester);
    final String before = tester.widget<TextField>(find.byType(TextField)).controller!.text;

    await tester.tap(find.text('Anime'));
    await tester.pump();

    final String after = tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(after, isNot(before));
  });

  testWidgets('short on coins, the main button offers coins and says why', (tester) async {
    await pumpPage(tester);

    CoinsService.instance.balanceNotifier.value = 0;
    await tester.pump();

    expect(find.text(AppLocalizationsEn().economyEarnCoins), findsOneWidget);
    expect(find.text('Generate'), findsNothing);
    expect(find.text('You need ${AiQualityTier.fast.coinCost} coins. You have 0.'), findsOneWidget);
  });

  testWidgets('Pro users see and are gated on the half price', (tester) async {
    await pumpPage(tester, premium: true);
    final int half = AiQualityTier.fast.costFor(isPro: true);

    CoinsService.instance.balanceNotifier.value = half;
    await tester.pump();
    expect(find.text('Generate'), findsOneWidget);
    expect(find.text('${AiQualityTier.quality.costFor(isPro: true)}'), findsOneWidget);

    CoinsService.instance.balanceNotifier.value = half - 1;
    await tester.pump();
    expect(find.text('You need $half coins. You have ${half - 1}.'), findsOneWidget);
  });

  testWidgets('a result shows Apply as the one primary action', (tester) async {
    await pumpPage(tester, history: <AiGenerationRecord>[_record()]);
    await openFirstRecent(tester);

    final Finder primaryButtons = find.descendant(
      of: find.byType(AiResultView),
      matching: find.byWidgetPredicate(
        (Widget widget) => widget is PrismButton && widget.variant == PrismButtonVariant.primary,
      ),
    );
    expect(primaryButtons.hitTestable(), findsOneWidget);
    expect(tester.widget<PrismButton>(primaryButtons.hitTestable()).label, 'Apply');
  });

  testWidgets('a guest sees a sign-in prompt and no compose controls', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    addTearDown(getIt.reset);
    app_state.prismUser = app_constants.createGuestPrismUser();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: AiWallpaperTabPage(repository: _FakeRepository(const <AiGenerationRecord>[])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to use AI wallpaper'), findsOneWidget);
    expect(find.text('Generate'), findsNothing);
    expect(find.text('Describe a scene'), findsNothing);
  });
}
