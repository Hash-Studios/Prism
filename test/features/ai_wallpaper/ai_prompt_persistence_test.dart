import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _FakeConnectivityService implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

class _PromptRepository extends Fake implements AiGenerationRepositoryImpl {
  final Map<String, Completer<String?>> pendingLoads = <String, Completer<String?>>{};
  final Map<String, String?> loadedPrompts = <String, String?>{};
  final List<String> loadRequests = <String>[];
  final List<({String userId, String prompt})> saves = <({String userId, String prompt})>[];

  @override
  Future<String?> loadPrompt({required String userId}) {
    loadRequests.add(userId);
    return pendingLoads[userId]?.future ?? Future<String?>.value(loadedPrompts[userId]);
  }

  @override
  Future<void> savePrompt({required String userId, required String prompt}) async {
    saves.add((userId: userId, prompt: prompt));
  }

  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async =>
      const <AiGenerationRecord>[];

  @override
  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async =>
      const <AiGenerationRecord>[];
}

void main() {
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    getIt.registerSingleton<ConnectivityService>(_FakeConnectivityService());
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user-1'
      ..loggedIn = true;
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> pumpPage(WidgetTester tester, _PromptRepository repository) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finishPromptSave(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
  }

  testWidgets('automatic seed is not saved', (tester) async {
    final _PromptRepository repository = _PromptRepository();
    await pumpPage(tester, repository);

    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isNotEmpty);
    await finishPromptSave(tester);

    expect(repository.saves, isEmpty);
  });

  testWidgets('selection-only editing of the automatic seed is not saved', (tester) async {
    final _PromptRepository repository = _PromptRepository();
    await pumpPage(tester, repository);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await finishPromptSave(tester);

    expect(repository.saves, isEmpty);
  });

  testWidgets('restored draft is not saved again', (tester) async {
    final _PromptRepository repository = _PromptRepository()..loadedPrompts['user-1'] = 'A stored prompt from before';
    await pumpPage(tester, repository);
    await finishPromptSave(tester);

    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'A stored prompt from before');
    expect(repository.saves, isEmpty);
  });

  testWidgets('shuffle selection is saved', (tester) async {
    final _PromptRepository repository = _PromptRepository();
    await pumpPage(tester, repository);
    final Finder shuffle = find.byTooltip('Shuffle a new example description');
    await tester.ensureVisible(shuffle);
    await tester.tap(shuffle);
    await tester.pump();
    final String selectedPrompt = tester.widget<TextField>(find.byType(TextField).first).controller!.text;
    await finishPromptSave(tester);

    expect(repository.saves.map((save) => save.prompt), contains(selectedPrompt));
    expect(selectedPrompt, isNotEmpty);
  });

  testWidgets('scene idea selection is saved', (tester) async {
    final _PromptRepository repository = _PromptRepository();
    await pumpPage(tester, repository);
    final Finder sceneIdea = find.byTooltip('Use this scene in your description (editable)');
    await tester.ensureVisible(sceneIdea);
    await tester.tap(sceneIdea);
    await tester.pump();
    final String selectedPrompt = tester.widget<TextField>(find.byType(TextField).first).controller!.text;
    await finishPromptSave(tester);

    expect(repository.saves.map((save) => save.prompt), contains(selectedPrompt));
    expect(selectedPrompt, isNotEmpty);
  });

  testWidgets('successive style choices replace the generated prompt and save the latest', (tester) async {
    final _PromptRepository repository = _PromptRepository();
    await pumpPage(tester, repository);
    final Finder anime = find.text('Anime');
    await tester.ensureVisible(anime);
    await tester.tap(anime);
    await tester.pump();
    final String firstStylePrompt = tester.widget<TextField>(find.byType(TextField).first).controller!.text;

    final Finder watercolor = find.text('Watercolor');
    await tester.ensureVisible(watercolor);
    await tester.tap(watercolor);
    await tester.pump();
    final String secondStylePrompt = tester.widget<TextField>(find.byType(TextField).first).controller!.text;
    await finishPromptSave(tester);

    expect(secondStylePrompt, isNot(firstStylePrompt));
    expect(repository.saves.map((save) => save.prompt), contains(secondStylePrompt));
  });

  testWidgets('explicit scene choice survives a locale change', (tester) async {
    final _PromptRepository repository = _PromptRepository();
    await pumpPage(tester, repository);
    final Finder sceneIdea = find.byTooltip('Use this scene in your description (editable)');
    await tester.ensureVisible(sceneIdea);
    await tester.tap(sceneIdea);
    await tester.pump();
    final String selectedPrompt = tester.widget<TextField>(find.byType(TextField).first).controller!.text;

    final Locale selectedLocale = AppLocalizations.supportedLocales.firstWhere((locale) => locale.languageCode != 'en');
    tester.platformDispatcher.localesTestValue = <Locale>[selectedLocale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(Localizations.localeOf(tester.element(find.byType(AiWallpaperTabPage))), selectedLocale);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, selectedPrompt);
  });

  testWidgets('explicit scene selection survives deferred hydration and is saved', (tester) async {
    final _PromptRepository repository = _PromptRepository()..pendingLoads['user-1'] = Completer<String?>();
    await pumpPage(tester, repository);
    final Finder sceneIdea = find.byTooltip('Use this scene in your description (editable)');
    await tester.ensureVisible(sceneIdea);
    await tester.tap(sceneIdea);
    await tester.pump();
    final String actualSelection = tester.widget<TextField>(find.byType(TextField).first).controller!.text;

    repository.pendingLoads['user-1']!.complete('A stored prompt from before');
    await tester.pump();
    await finishPromptSave(tester);

    expect(actualSelection, isNotEmpty);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, actualSelection);
    expect(repository.saves.map((save) => save.prompt), contains(actualSelection));
  });

  testWidgets('typed input during deferred hydration survives and is saved', (tester) async {
    final _PromptRepository repository = _PromptRepository()..pendingLoads['user-1'] = Completer<String?>();
    await pumpPage(tester, repository);
    const String typedPrompt = 'A glass greenhouse under a violet moon';
    await tester.enterText(find.byType(TextField).first, typedPrompt);

    repository.pendingLoads['user-1']!.complete('A stored prompt from before');
    await tester.pump();
    await finishPromptSave(tester);

    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, typedPrompt);
    expect(repository.saves.map((save) => save.prompt), contains(typedPrompt));
  });

  testWidgets('owner change prevents old hydration from writing', (tester) async {
    final _PromptRepository repository = _PromptRepository()
      ..pendingLoads['user-1'] = Completer<String?>()
      ..pendingLoads['user-2'] = Completer<String?>();
    await pumpPage(tester, repository);
    const String oldOwnerPrompt = 'A quiet cabin beneath northern lights';
    await tester.enterText(find.byType(TextField).first, oldOwnerPrompt);
    app_state.prismUser.id = 'user-2';
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(repository.loadRequests, contains('user-2'));
    repository.pendingLoads['user-1']!.complete('An old account prompt');
    repository.pendingLoads['user-2']!.complete(null);
    await tester.pump();
    await finishPromptSave(tester);

    expect(repository.saves.where((save) => save.userId == 'user-1'), isEmpty);
    expect(
      repository.saves.where((save) => save.userId == 'user-2').map((save) => save.prompt),
      isNot(contains(oldOwnerPrompt)),
    );
  });

  testWidgets('owner change cancels the pending debounce and new owner can save', (tester) async {
    final _PromptRepository repository = _PromptRepository()..loadedPrompts['user-1'] = null;
    await pumpPage(tester, repository);
    const String oldOwnerPrompt = 'A quiet cabin beneath northern lights';
    await tester.enterText(find.byType(TextField).first, oldOwnerPrompt);

    app_state.prismUser.id = 'user-2';
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(repository.loadRequests.where((userId) => userId == 'user-2'), hasLength(1));
    expect(repository.saves.where((save) => save.userId == 'user-1'), isEmpty);
    expect(
      repository.saves.where((save) => save.userId == 'user-2').map((save) => save.prompt),
      isNot(contains(oldOwnerPrompt)),
    );

    const String newOwnerPrompt = 'A city floating above a silver sea';
    await tester.enterText(find.byType(TextField).first, newOwnerPrompt);
    await finishPromptSave(tester);

    expect(repository.saves, contains((userId: 'user-2', prompt: newOwnerPrompt)));
  });
}
