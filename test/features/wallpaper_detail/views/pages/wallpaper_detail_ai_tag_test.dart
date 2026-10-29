import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/recommendation_state.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/ai_generated_tag.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/favourite_test_scope.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/offline_asset_fixture.dart';
import '../../../../support/profile_user_fixture.dart';

class _MockWallpaperDetailBloc extends MockBloc<WallpaperDetailEvent, WallpaperDetailState>
    implements WallpaperDetailBloc {}

PrismWallpaper _wall({bool isAiGenerated = false, String? aiModel, Map<String, Object?>? aiMetadata}) => PrismWallpaper(
  core: const WallpaperCore(
    id: 'prism-1',
    source: WallpaperSource.prism,
    fullUrl: 'https://img.test/full.jpg',
    thumbnailUrl: 'https://img.test/thumb.jpg',
    authorName: 'Akshay',
    authorUid: 'creator-uid',
  ),
  firestoreDocumentId: 'doc-1',
  isAiGenerated: isAiGenerated,
  aiModel: aiModel,
  aiMetadata: aiMetadata,
);

void main() {
  setUpFavouriteCounts();
  late _MockWallpaperDetailBloc bloc;
  late OfflineAssetFixture offlineAssets;

  setUpAll(() => registerFallbackValue(const FetchViews()));

  setUp(() async {
    offlineAssets = await OfflineAssetFixture.create(cacheMissByDefault: true);
    offlineAssets.install();
    getIt.registerSingleton<FavoritesLocalDataSource>(FavoritesLocalDataSource(InMemoryLocalStore()));
    app_state.prismUser = profileUser(loggedIn: false);
    bloc = _MockWallpaperDetailBloc();
  });

  tearDown(() async {
    await offlineAssets.dispose();
    await getIt.reset();
  });

  Future<void> pumpScreen(WidgetTester tester, PrismWallpaper wall) async {
    final entity = FeedItemEntity.prism(id: 'prism-1', wallpaper: wall);
    whenListen(
      bloc,
      const Stream<WallpaperDetailState>.empty(),
      initialState: WallpaperDetailLoaded(
        recommendations: const RecommendationState.exhausted(),
        entity: entity,
        paletteLoading: false,
        panelCollapsed: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WallpaperDetailBloc>.value(
          value: bloc,
          child: WallpaperDetailScreen(entity: entity, source: WallpaperSource.prism),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('detail screen', () {
    testWidgets('an AI wall shows the AI-generated tag', (tester) async {
      await pumpScreen(tester, _wall(isAiGenerated: true, aiModel: 'Seedream 5 Lite'));

      expect(find.text('AI-generated'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('a human wall shows no tag', (tester) async {
      await pumpScreen(tester, _wall());

      expect(find.text('AI-generated'), findsNothing);
    });

    testWidgets('a wall with only AI metadata shows the tag', (tester) async {
      await pumpScreen(tester, _wall(aiMetadata: const {'prompt': 'a neon city'}));

      expect(find.text('AI-generated'), findsOneWidget);
    });
  });

  group('AiGeneratedTag', () {
    Future<void> pumpTag(WidgetTester tester, PrismWallpaper wall, {String? docId = 'doc-1'}) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: AiGeneratedTag(wallpaper: wall, reportDocId: docId, reportSubtitle: 'prism-1'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('the tap target is at least 48 by 48', (tester) async {
      await pumpTag(tester, _wall(isAiGenerated: true));
      final SemanticsHandle semantics = tester.ensureSemantics();

      final Size size = tester.getSize(find.byType(AiGeneratedTag));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      final SemanticsNode node = tester.getSemantics(find.byType(AiGeneratedTag));
      final SemanticsData data = node.getSemanticsData();
      expect(node.label, 'AI-generated');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });

    testWidgets('tapping names the model and offers Report wrong label', (tester) async {
      await pumpTag(tester, _wall(isAiGenerated: true, aiModel: 'fal-ai/bytedance/seedream/v5/lite/text-to-image'));

      await tester.tap(find.text('AI-generated'));
      await tester.pumpAndSettle();

      expect(find.text('Made with Seedream 5 Lite'), findsOneWidget);
      expect(find.text('Report wrong label'), findsOneWidget);
    });

    testWidgets('a missing or unknown model reads Made with AI, never a raw provider id', (tester) async {
      await pumpTag(tester, _wall(isAiGenerated: true, aiModel: 'acme/new-model/v9'));

      await tester.tap(find.text('AI-generated'));
      await tester.pumpAndSettle();

      expect(find.text('Made with AI'), findsOneWidget);
      expect(find.textContaining('acme'), findsNothing);
    });

    testWidgets('a wall with no model reads Made with AI', (tester) async {
      await pumpTag(tester, _wall(isAiGenerated: true));

      await tester.tap(find.text('AI-generated'));
      await tester.pumpAndSettle();

      expect(find.text('Made with AI'), findsOneWidget);
    });

    testWidgets('a wall with no report doc id has no report row', (tester) async {
      await pumpTag(tester, _wall(isAiGenerated: true), docId: null);

      await tester.tap(find.text('AI-generated'));
      await tester.pumpAndSettle();

      expect(find.text('Made with AI'), findsOneWidget);
      expect(find.text('Report wrong label'), findsNothing);
    });
  });

  test('live model ids map to readable names', () {
    expect(aiModelDisplayName('openai/gpt-image-2.5/sunburst/text-to-image'), 'GPT Image 2.5');
    expect(aiModelDisplayName('fal-ai/bytedance/seedream/v4.5/text-to-image'), 'Seedream 4.5');
    expect(aiModelDisplayName('fal-ai/z-image/turbo'), 'Z-Image Turbo');
    expect(aiModelDisplayName('fal-ai/flux/schnell'), 'FLUX.1 schnell');
    expect(aiModelDisplayName('gemini-2.5-flash-image'), 'Gemini 2.5 Flash Image');
    expect(aiModelDisplayName('acme/new-model'), isNull);
    expect(aiModelDisplayName('fal-ai/flux/schnell-v2'), isNull, reason: 'a longer id is a different model');
    expect(aiModelDisplayName(null), isNull);
  });
}
