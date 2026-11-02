import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/domain/repositories/drops_repository.dart';
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/features/personalized_feed/domain/repositories/personalized_feed_repository.dart';
import 'package:Prism/features/personalized_feed/domain/usecases/personalized_feed_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_app_analytics.dart';
import '../../../../support/fake_firestore_client.dart';
import '../../../../support/fake_user_block_repository.dart';
import '../../../../support/in_memory_local_store.dart';
import '../../../../support/profile_user_fixture.dart';

class _MockFetchPersonalizedFeedUseCase extends Mock implements FetchPersonalizedFeedUseCase {}

class _MockPersonalizedFeedRepository extends Mock implements PersonalizedFeedRepository {}

class _MockDropsRepository extends Mock implements DropsRepository {}

FakeUserBlockRepository _knownEmptyBlocks() => FakeUserBlockRepository.pending()..completeInitial(<String>{});

LayoutPrefsStore _store(InMemoryLocalStore local) =>
    LayoutPrefsStore(SettingsLocalDataSource(local), FakeFirestoreClient());

void main() {
  late _MockFetchPersonalizedFeedUseCase fetchUseCase;
  late _MockPersonalizedFeedRepository repository;
  late _MockDropsRepository dropsRepository;
  late InMemoryLocalStore local;
  late LayoutPrefsStore store;

  setUp(() {
    AnalyticsRuntime.reset();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    EconomyConfig.current = EconomyConfig.defaults;
    fetchUseCase = _MockFetchPersonalizedFeedUseCase();
    repository = _MockPersonalizedFeedRepository();
    dropsRepository = _MockDropsRepository();
    when(() => dropsRepository.fetchLive(any())).thenAnswer((_) async => Result.success<DropEntity?>(null));
    when(() => repository.readCached()).thenAnswer((_) async => null);
    when(() => repository.recordShown(any())).thenAnswer((_) async {});
    local = InMemoryLocalStore();
    store = _store(local);
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  tearDown(() {
    AnalyticsRuntime.reset();
    EconomyConfig.current = EconomyConfig.defaults;
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  PersonalizedFeedBloc build([LayoutPrefsStore? layout]) {
    final bloc = layout == null
        ? PersonalizedFeedBloc(fetchUseCase, repository, _knownEmptyBlocks(), dropsRepository)
        : PersonalizedFeedBloc(fetchUseCase, repository, _knownEmptyBlocks(), dropsRepository, layout);
    addTearDown(bloc.close);
    return bloc;
  }

  test('cold start restores the remembered tab', () async {
    await store.setFeedTab(HomeFeedChip.latest);

    final bloc = build(store);

    expect(bloc.state.chip, HomeFeedChip.latest);
  });

  test('a guest with a remembered following tab opens on forYou; a signed-in user opens on following', () async {
    await store.setFeedTab(HomeFeedChip.following);

    final guest = build(store);
    expect(guest.state.chip, HomeFeedChip.forYou);

    app_state.prismUser = profileUser();
    final signedIn = build(store);
    expect(signedIn.state.chip, HomeFeedChip.following);
  });

  test('selecting a chip persists it, and a new store on the same local data reads it', () async {
    final bloc = build(store);

    bloc.add(const PersonalizedFeedEvent.chipSelected(HomeFeedChip.popular));
    await Future<void>.delayed(Duration.zero);

    expect(store.value.feedTab, HomeFeedChip.popular);
    expect(_store(local).value.feedTab, HomeFeedChip.popular);
  });

  test('a push or link that sets the tab wins over the remembered tab', () async {
    await store.setFeedTab(HomeFeedChip.popular);
    final bloc = build(store);
    expect(bloc.state.chip, HomeFeedChip.popular);

    await store.setFeedTab(HomeFeedChip.latest);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.chip, HomeFeedChip.latest);
  });

  test('a push that lands before the feed exists wins over the remembered tab', () async {
    await store.setFeedTab(HomeFeedChip.popular);
    await store.setFeedTab(HomeFeedChip.latest);

    final bloc = build(store);

    expect(bloc.state.chip, HomeFeedChip.latest);
  });

  test('an unrelated layout change does not move the feed', () async {
    await store.setFeedTab(HomeFeedChip.following);
    final bloc = build(store);
    expect(bloc.state.chip, HomeFeedChip.forYou);

    await store.update(store.value.copyWith(density: WallGridDensity.large));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.chip, HomeFeedChip.forYou);
  });

  test('without a layout store the feed opens on forYou', () {
    final bloc = build();

    expect(bloc.state.chip, HomeFeedChip.forYou);
  });
}
