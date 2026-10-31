import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_prompt_field.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_remix_chip.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/features/weekly_challenges/views/widgets/challenge_context_chip.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_app_analytics.dart';

class Repo extends Fake implements AiGenerationRepositoryImpl {
  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async => [];
  @override
  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async => [];
  @override
  Future<String?> loadPrompt({required String userId}) async => 'old saved prompt';
  @override
  Future<void> savePrompt({required String userId, required String prompt}) async {}
}

class Connectivity implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;
  @override
  Stream<bool> get onConnectionChange => const Stream.empty();
}

void main() {
  testWidgets('challenge seeds prompt without generating, and removing it preserves remix', (tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    getIt.registerSingleton<ConnectivityService>(Connectivity());
    addTearDown(getIt.reset);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    addTearDown(AnalyticsRuntime.reset);
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user'
      ..loggedIn = true;
    addTearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiWallpaperTabPage(
          repository: Repo(),
          challengeSeed: const ChallengeSeed(id: '2026-10-26', theme: 'Quiet oceans'),
          remixSeed: const AiRemixSeed(
            wallDocId: 'original',
            title: 'Ocean',
            creatorName: 'Maya',
            thumbnailUrl: '',
            prompt: 'Original prompt',
            sourceType: RemixSourceType.user,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final field = find.descendant(of: find.byType(AiPromptField), matching: find.byType(TextField));
    expect(tester.widget<TextField>(field).controller!.text, 'Quiet oceans');
    expect(find.byType(ChallengeContextChip), findsOneWidget);
    expect(find.byType(AiRemixChip), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(ChallengeContextChip), matching: find.byType(Icon)).last);
    await tester.pump();
    expect(find.byType(ChallengeContextChip), findsNothing);
    expect(find.byType(AiRemixChip), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, 'Quiet oceans');
    await tester.pumpWidget(const SizedBox());
  });
}
