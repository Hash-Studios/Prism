// Device QA entry point for followed topics. A fake signed-in user opens the real Pastel category page and follows it;
// Dreamy is already followed from another device and has new walls. "Deliver today's push" shows the push that
// tool/qa_topic_digest.mjs captured from the real sendTopicDigests job on the Firestore emulator, as a system
// notification with the job's gallery image. A tap resolves it through NotificationRouteMapper and routeForPageLink,
// the code a real push tap uses, and opens the page.
// Run: fvm flutter run -t test/qa_render/followed_topics_device_main.dart -d <device>
// Options: --dart-define=QA_DARK=true, --dart-define=QA_TEXT_SCALE=2
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/persistence/data_sources/feed_cache_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_catalog_resolver.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/category_feed/domain/entities/category_entity.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/pages/collection_view_screen.dart';
import 'package:Prism/features/followed_topics/data/followed_topics_store.dart';
import 'package:Prism/features/followed_topics/views/widgets/followed_topics_sheet.dart';
import 'package:Prism/features/followed_topics/views/widgets/following_topics_row.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_copy.dart';
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/features/moods/biz/mood_walls_cubit.dart';
import 'package:Prism/features/moods/views/pages/mood_screen.dart';
import 'package:Prism/features/moods/views/widgets/wall_ids_grid.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../support/fake_app_analytics.dart';
import '../support/fake_feed_cache_local_data_source.dart';
import '../support/fake_firestore_client.dart';
import '../support/fake_user_block_repository.dart';
import '../support/in_memory_local_store.dart';

const bool _dark = bool.fromEnvironment('QA_DARK');
const String _textScale = String.fromEnvironment('QA_TEXT_SCALE', defaultValue: '1');

/// The `data` of the FCM message that sendTopicDigests sent on the emulator (tool/qa_topic_digest.mjs, 2026-11-05).
const Map<String, String> _jobPushData = <String, String>{
  'route': 'topic',
  'topic_kind': 'category',
  'topic_id': 'Pastel',
  'topic_count': '2',
  'url': 'https://prismwalls.com/category/Pastel',
  'notification_kind': 'topic_digest',
  'push_kind': 'post',
  'notification_copy_kind': 'topicDigest',
  'notification_args':
      '{"topicKey":"category:Pastel","topicName":"Pastel","secondTopicKey":"mood:dreamy","secondTopicName":"Dreamy",'
      '"topicCount":2,"wallCount":2,"tags":"Dreamy · Pastel · Flower"}',
  'channel_id': 'posts',
  'gallery': '1',
  'gallery_count': '2',
  'gallery_thumb_index': '0',
};

/// The gallery JPEG the job rendered with buildPushGallery, kept on the qa/screenshots branch.
const String _galleryUrl =
    'https://raw.githubusercontent.com/Hash-Studios/Prism/qa/screenshots/followed-topics-2026-11-05/job-gallery.jpg';

const List<String> _thumbs = <String>[
  'https://img.prismwalls.com/previews/4f2935aee606c4a151ce2a5cd20570e729bfbf38b0b40fbeea65bb1b193c1730.img',
  'https://img.prismwalls.com/previews/17178b61fa1febf9269a5ebab8fbffd627e0ba2211edc7262516d990e60f089a.img',
  'https://img.prismwalls.com/previews/a6326f164677dc5bca6ebe4fe591e693fb5f003846900d3d67301a85f59addbb.img',
  'https://img.prismwalls.com/previews/ac4378738163dfd1996c692784bb4328496ee46b2844459a43762cbda544e375.img',
  'https://img.prismwalls.com/previews/30f5e0ce83b14cccbcb6a753697f1a27a5e91093a31c4c971432c8848d0008eb.img',
  'https://img.prismwalls.com/previews/f482b9743d67080d70e72a897f17821a9a5f39b3f99978d51c2ea46728684f5c.img',
  'https://img.prismwalls.com/previews/b92c80d6e5c72333077d89e99f8f15cb12fa082fa25e3fa7457f31c684f3c3c6.img',
  'https://img.prismwalls.com/previews/6e96a5e48dc7c4edc979d0e0f006353088115ceaf4dedc22b2be8d2f8ccb69b9.img',
];

PrismWallpaper _wall(int i, String category) => PrismWallpaper(
  core: WallpaperCore(
    id: 'qa${category.toLowerCase()}$i',
    source: WallpaperSource.prism,
    fullUrl: _thumbs[i % _thumbs.length],
    thumbnailUrl: _thumbs[i % _thumbs.length],
    authorName: 'Creator $i',
    authorEmail: 'creator$i@example.com',
    category: category,
    width: 1080,
    height: 2160,
    favourites: 12 + i,
  ),
  title: 'Wall $i',
);

class _QaCategoryBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _QaMoodWalls extends MockCubit<MoodWallsState> implements MoodWallsCubit {}

class _QaRouter extends Mock implements StackRouter {}

final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

Widget _pageFor(PageRouteInfo<Object?> route) => switch (route) {
  CollectionViewRoute(:final CollectionViewRouteArgs? args) => CollectionViewScreen(
    collectionName: args!.collectionName,
  ),
  MoodRoute(:final MoodRouteArgs? args) => MoodScreen(moodId: args!.moodId, source: args.source),
  _ => Scaffold(body: Center(child: Text('QA: no page for ${route.routeName}'))),
};

void _open(PageRouteInfo<Object?> route) =>
    unawaited(_navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => _pageFor(route))));

/// A push tap: the same mapping a real tap uses, from the payload to a page route.
Future<void> _openPush(Map<String, dynamic> data) async {
  final DeepLinkActionEntity? action = await const NotificationRouteMapper().actionFromPayload(
    data,
    sourceTag: 'qa.topic_push',
    fallbackToInbox: false,
  );
  final PageRouteInfo<Object?>? route = action is PageLinkIntent ? await routeForPageLink(action) : null;
  if (route != null) _open(route);
}

Future<void> _deliverJobPush(BuildContext context) async {
  final l10n = context.l10n;
  final Map<String, Object?> args = jsonDecode(_jobPushData['notification_args']!) as Map<String, Object?>;
  final ({String title, String body}) copy = localizedNotificationCopyData(
    _jobPushData['notification_copy_kind'],
    args,
    fallbackTitle: '',
    fallbackBody: '',
    l10n: l10n,
  );
  final String image = '${(await getTemporaryDirectory()).path}/topic-gallery.jpg';
  final HttpClientResponse response = await (await HttpClient().getUrl(Uri.parse(_galleryUrl))).close();
  await response.pipe(File(image).openWrite());
  await _notifications.show(
    id: 7,
    title: copy.title,
    body: copy.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'posts',
        'Posts',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(image),
          largeIcon: FilePathAndroidBitmap(image),
        ),
      ),
      iOS: DarwinNotificationDetails(attachments: <DarwinNotificationAttachment>[DarwinNotificationAttachment(image)]),
    ),
    payload: jsonEncode(_jobPushData),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AnalyticsRuntime.instance = FakeAppAnalytics();
  app_state.prismUser = app_constants.createGuestPrismUser()
    ..id = 'qa-user'
    ..name = 'Mira'
    ..email = 'qa@prismwalls.com'
    ..loggedIn = true;
  final int now = DateTime.now().millisecondsSinceEpoch;
  final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
  // Dreamy was followed on another device and seen an hour ago; a Dreamy wall landed after that, so it has a dot.
  await settings.set('followed_topics.seen.mood:dreamy', now - 3600000);
  final FakeFirestoreClient firestore = FakeFirestoreClient(
    docs: <String, Map<String, Map<String, dynamic>>>{
      'usersv2/qa-user/private': <String, Map<String, dynamic>>{
        'session': <String, dynamic>{
          'followedTopics': <String>['mood:dreamy'],
          'followedTopicsOffset': 330,
        },
      },
      'topicNews': <String, Map<String, dynamic>>{
        'current': <String, dynamic>{
          'latest': <String, int>{'mood:dreamy': now - 600000},
        },
      },
    },
  );
  getIt
    ..registerSingleton<FirestoreClient>(firestore)
    ..registerSingleton<SettingsLocalDataSource>(settings)
    ..registerSingleton<FeedCacheLocalDataSource>(FakeFeedCacheLocalDataSource())
    ..registerSingleton<UserBlockRepository>(FakeUserBlockRepository.pending()..completeInitial(<String>{}))
    ..registerSingleton<LayoutPrefsStore>(LayoutPrefsStore(settings, firestore))
    ..registerSingleton<FollowedTopicsStore>(FollowedTopicsStore(settings, firestore))
    ..registerFactory<MoodWallsCubit>(() {
      final _QaMoodWalls cubit = _QaMoodWalls();
      whenListen(
        cubit,
        const Stream<MoodWallsState>.empty(),
        initialState: MoodWallsLoaded(<PrismWallpaper>[for (int i = 0; i < 8; i++) _wall(i, 'Dreamy')]),
      );
      when(() => cubit.load(any())).thenAnswer((_) async {});
      return cubit;
    });

  const CategoryEntity pastel = CategoryEntity(
    name: 'Pastel',
    source: WallpaperSource.pexels,
    searchType: CategorySearchType.search,
    image: '',
    image2: '',
  );
  final _QaCategoryBloc categories = _QaCategoryBloc();
  whenListen(
    categories,
    const Stream<CategoryFeedState>.empty(),
    initialState: CategoryFeedState.initial().copyWith(
      status: LoadStatus.success,
      categories: const <CategoryEntity>[pastel],
      selectedCategory: pastel,
      items: <FeedItemEntity>[
        for (int i = 0; i < 8; i++) PrismFeedItem(id: 'qapastel$i', wallpaper: _wall(i + 2, 'Pastel')),
      ],
    ),
  );
  registerFallbackValue(const CategoryFeedEvent.started());
  registerFallbackValue(MoodRoute(moodId: 'dreamy'));

  final _QaRouter router = _QaRouter();
  when(() => router.push<Object?>(any())).thenAnswer((Invocation invocation) async {
    _open(invocation.positionalArguments.single as PageRouteInfo<Object?>);
    return null;
  });
  toasts.overlayResolver = () => _navigator.currentState?.overlay;

  await _notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse response) =>
        unawaited(_openPush(jsonDecode(response.payload ?? '{}') as Map<String, dynamic>)),
  );
  await _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  runApp(
    StackRouterScope(
      controller: router,
      stateHash: 0,
      child: BlocProvider<CategoryFeedBloc>.value(
        value: categories,
        child: MaterialApp(
          navigatorKey: _navigator,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: kLightTheme,
          darkTheme: kDarkTheme,
          themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(double.parse(_textScale))),
            child: child!,
          ),
          home: const _QaHome(),
        ),
      ),
    ),
  );
}

/// A stand-in for Home and Settings that hosts the real followed-topics widgets. The QA buttons are not app UI.
class _QaHome extends StatelessWidget {
  const _QaHome();

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Home',
      showBack: false,
      body: ListView(
        children: <Widget>[
          const FollowingTopicsRow(),
          Padding(
            padding: const EdgeInsets.all(PrismSpace.md),
            child: Wrap(
              spacing: PrismSpace.xs,
              runSpacing: PrismSpace.xs,
              children: <Widget>[
                PrismButton(
                  label: 'QA: open Pastel',
                  size: PrismButtonSize.compact,
                  variant: PrismButtonVariant.tonal,
                  onPressed: () => _open(CollectionViewRoute(collectionName: 'category:Pastel')),
                ),
                PrismButton(
                  label: 'QA: open AMOLED',
                  size: PrismButtonSize.compact,
                  variant: PrismButtonVariant.tonal,
                  onPressed: () => _open(CollectionViewRoute(collectionName: 'category:AMOLED')),
                ),
                PrismButton(
                  label: "QA: deliver today's push",
                  size: PrismButtonSize.compact,
                  variant: PrismButtonVariant.tonal,
                  onPressed: () => unawaited(_deliverJobPush(context)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: PrismSpace.md),
            child: PrismGroup(children: <Widget>[FollowedTopicsSettingsRow()]),
          ),
          SizedBox(
            height: 900,
            child: WallIdsGrid(walls: <PrismWallpaper>[for (int i = 0; i < 6; i++) _wall(i + 4, 'Nature')]),
          ),
        ],
      ),
    );
  }
}
