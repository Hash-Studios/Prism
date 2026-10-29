// Device QA entry point: remix screens on fake data, a fake signed-in user, no Firebase, no network writes.
// Run: fvm flutter run -t test/qa_render/remix_device_main.dart -d emulator-5580
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/wallpaper/wall_ai_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/upload/wallpaper/wall_submission.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_row.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/wall_remix/biz/remix_credit_cubit.dart';
import 'package:Prism/features/wall_remix/biz/remixes_cubit.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/features/wall_remix/views/widgets/remix_credit_row.dart';
import 'package:Prism/features/wall_remix/views/widgets/remixes_section.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/fake_app_analytics.dart';

const String _urlA =
    'https://img.prismwalls.com/previews/4f2935aee606c4a151ce2a5cd20570e729bfbf38b0b40fbeea65bb1b193c1730.img';
const String _urlB =
    'https://img.prismwalls.com/previews/a76857c0fbcfd6dd01b76e7b50996edc2dfe4200cf4fa421d4f86eb8818fd351.img';
const String _urlC =
    'https://img.prismwalls.com/previews/17178b61fa1febf9269a5ebab8fbffd627e0ba2211edc7262516d990e60f089a.img';
const String _urlD =
    'https://img.prismwalls.com/previews/f3787f4b42f85a23fd26667110414d54d1ccbb20661fdbd33c6e0eeed7d3328e.img';
const String _originalDocId = '1JMSVHNOLV';
const String _originalTitle = 'Rose Arch · Sunrise';
const String _prompt = 'a garden arch covered in climbing roses, warm sunrise light, soft mist, quiet path';
const String _model = 'openai/gpt-image-2.5/sunburst/text-to-image';
final WallViewer _viewer = WallViewer(
  isPremium: false,
  premiumCollections: <String>[],
  blockedCreators: KnownBlockedCreators(<String>{}),
);

class _QaRouter extends Mock implements StackRouter {}

class _QaConnectivity implements ConnectivityService {
  @override
  Future<bool> hasConnection() async => true;

  @override
  Stream<bool> get onConnectionChange => const Stream<bool>.empty();
}

class _QaAnalytics extends FakeAppAnalytics {}

class _NoFirestore extends Fake implements FirestoreClient {}

class _NoUserBlocks extends Fake implements UserBlockRepository {}

class _QaRemixRepository extends WallRemixRepository {
  _QaRemixRepository({required this.remixes, required this.original}) : super(_NoFirestore(), _NoUserBlocks());

  final List<PrismWallpaper> remixes;
  final PrismWallpaper original;

  @override
  Future<List<PrismWallpaper>> fetchRemixes(String originalDocId, {String? startAfterDocId}) async => remixes;

  @override
  Future<PrismWallpaper?> fetchApprovedWall(String docId) async => original;

  @override
  Future<BlockedCreators> loadBlockedCreators() async => KnownBlockedCreators(const <String>{});
}

class _QaAiRepository extends Fake implements AiGenerationRepositoryImpl {
  @override
  Future<List<AiGenerationRecord>> fetchHistory({required String userId, int limit = 50}) async =>
      const <AiGenerationRecord>[];

  @override
  Future<List<AiGenerationRecord>> fetchLocalHistory({required String userId, int limit = 50}) async =>
      const <AiGenerationRecord>[];

  @override
  Future<String?> loadPrompt({required String userId}) async => null;

  @override
  Future<void> savePrompt({required String userId, required String prompt}) async {}

  @override
  Future<AiGenerationRecord> generate({
    required String prompt,
    required AiStylePreset stylePreset,
    required AiQualityTier qualityTier,
    required String targetSize,
    required AiChargeMode chargeMode,
    required int coinsSpent,
    int? seed,
    String? chargeTxId,
    String? remixOf,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return AiGenerationRecord(
      id: 'qa-generation-1',
      userId: 'qa-user',
      createdAt: DateTime.now(),
      prompt: prompt,
      stylePreset: stylePreset,
      qualityTier: qualityTier,
      provider: 'qa',
      model: _model,
      seed: 1,
      width: 720,
      height: 1280,
      imageUrl: _urlB,
      watermarkedImageUrl: _urlB,
      chargeMode: chargeMode,
      coinsSpent: coinsSpent,
      status: 'success',
      remixOf: remixOf,
    );
  }
}

PrismWallpaper _wall({
  required String docId,
  required String title,
  required String author,
  required String authorUid,
  required String thumb,
  String? authorEmail,
  bool studio = false,
  String? remixOf,
  int remixCount = 0,
}) => PrismWallpaper(
  core: WallpaperCore(
    id: docId,
    source: WallpaperSource.prism,
    fullUrl: thumb,
    thumbnailUrl: thumb,
    authorName: author,
    authorEmail: authorEmail,
    authorUid: authorUid,
  ),
  title: title,
  review: true,
  firestoreDocumentId: docId,
  aiSource: WallAiSource(prompt: _prompt, stylePreset: studio ? null : 'watercolor', model: _model, isStudio: studio),
  remixOf: remixOf,
  remixCount: remixCount,
);

final PrismWallpaper _original = _wall(
  docId: _originalDocId,
  title: _originalTitle,
  author: 'Prism Studio',
  authorUid: 'qa-prism-studio',
  thumb: _urlA,
  studio: true,
  remixCount: 3,
);

final List<PrismWallpaper> _remixes = <PrismWallpaper>[
  _wall(
    docId: 'qa-remix-asha',
    title: _originalTitle,
    author: 'Asha',
    authorUid: 'qa-asha',
    authorEmail: 'asha@example.com',
    thumb: _urlB,
    remixOf: _originalDocId,
  ),
  _wall(
    docId: 'qa-remix-jahan',
    title: _originalTitle,
    author: 'Jahan',
    authorUid: 'qa-jahan',
    authorEmail: 'jahan@example.com',
    thumb: _urlC,
    remixOf: _originalDocId,
  ),
  _wall(
    docId: 'qa-remix-qamar',
    title: _originalTitle,
    author: 'qamar',
    authorUid: 'qa-qamar',
    authorEmail: 'qamar@example.com',
    thumb: _urlD,
    remixOf: _originalDocId,
  ),
];

const AiRemixSeed _seed = AiRemixSeed(
  wallDocId: _originalDocId,
  title: _originalTitle,
  creatorName: 'Prism Studio',
  thumbnailUrl: _urlA,
  prompt: _prompt,
  sourceType: RemixSourceType.studio,
  model: _model,
);

final InAppNotificationEntity _notification = InAppNotificationEntity(
  id: 'qa-notification-remix',
  title: 'Wallpaper remixed',
  pageName: 'wall',
  body: '',
  imageUrl: _urlB,
  arguments: const <Object>[],
  url: '',
  createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
  read: false,
  route: 'wall',
  wallId: 'remix-asha',
  kind: InAppNotificationKind.generic,
  copyKind: 'wallRemixed',
  copyArgs: const <String, Object?>{'remixerName': 'Asha', 'wallTitle': _originalTitle},
);

void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => page));

class _QaButton extends StatelessWidget {
  const _QaButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: FilledButton.tonal(onPressed: onPressed, child: Text(label)),
  );
}

class _QaLauncher extends StatelessWidget {
  const _QaLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remix QA')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _QaButton(
              label: 'AI tab remix',
              onPressed: () => _open(
                context,
                AiWallpaperTabPage(
                  repository: _QaAiRepository(),
                  remixSeed: _seed,
                  submitForTesting: () async => WallSubmissionResult.submitted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _QaButton(
              label: 'Original with remixes',
              onPressed: () => _open(
                context,
                Scaffold(
                  appBar: AppBar(title: const Text(_originalTitle)),
                  body: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: <Widget>[
                      Center(
                        child: SizedBox(
                          height: 420,
                          width: 420 * 9 / 16,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(PrismRadius.md),
                            child: CachedNetworkImage(imageUrl: _urlA, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      RemixesSection(
                        original: _original,
                        cubit: RemixesCubit(_QaRemixRepository(remixes: _remixes, original: _original)),
                        viewer: _viewer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _QaButton(
              label: 'Remix with credit',
              onPressed: () => _open(
                context,
                Scaffold(
                  appBar: AppBar(title: const Text('Rose Arch at dusk')),
                  body: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            AspectRatio(
                              aspectRatio: 9 / 16,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(PrismRadius.md),
                                child: CachedNetworkImage(imageUrl: _urlB, fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(height: 12),
                            RemixCreditRow(
                              remixOfDocId: _originalDocId,
                              cubit: RemixCreditCubit(
                                _QaRemixRepository(remixes: const <PrismWallpaper>[], original: _original),
                              ),
                              viewer: _viewer,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _QaButton(
              label: 'Inbox item',
              onPressed: () => _open(
                context,
                Scaffold(
                  appBar: AppBar(title: const Text('Notifications')),
                  body: ListView(children: <Widget>[NotificationRow(notification: _notification)]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QaApp extends StatelessWidget {
  const _QaApp({required this.router});

  final StackRouter router;

  @override
  Widget build(BuildContext context) {
    return StackRouterScope(
      controller: router,
      stateHash: 0,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: kLightTheme,
        home: const _QaLauncher(),
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!getIt.isRegistered<ConnectivityService>()) {
    getIt.registerSingleton<ConnectivityService>(_QaConnectivity());
  }
  AnalyticsRuntime.instance = _QaAnalytics();
  app_state.prismUser = app_constants.createGuestPrismUser()
    ..id = 'qa-user'
    ..name = 'Mira'
    ..premium = false
    ..loggedIn = true;
  CoinsService.instance.balanceNotifier.value = 340;

  final _QaRouter router = _QaRouter();
  registerFallbackValue(AiTabRoute());
  when(() => router.push(any())).thenAnswer((_) async => null);
  when(() => router.pushPath(any())).thenAnswer((_) async => null);

  runApp(_QaApp(router: router));
}
