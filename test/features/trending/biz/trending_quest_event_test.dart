import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/trending/biz/bloc/trending_bloc.j.dart';
import 'package:Prism/features/trending/domain/usecases/fetch_trending_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../support/coins_test_backend.dart';
import '../../../support/fake_user_block_repository.dart';

class _MockFetchTrending extends Mock implements FetchTrendingUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  late List<String> events;

  setUpAll(() => registerFallbackValue(const NoParams()));

  setUp(() async {
    events = <String>[];
    await backend.install();
    backend.onCall = (String name, Map<String, dynamic> params) async {
      if (name == 'progressQuest') events.add(params['event'] as String);
      return <String, Object?>{'success': true, 'rev': 1};
    };
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  test('the bloc only loads data: starting and refreshing it report no quest event', () async {
    final _MockFetchTrending fetch = _MockFetchTrending();
    when(() => fetch(any())).thenAnswer((_) async => TrendingFetch.success(<PrismWallpaper>[]));
    final TrendingBloc bloc = TrendingBloc(fetch, FakeUserBlockRepository.pending()..completeInitial(<String>{}));
    addTearDown(bloc.close);

    bloc.add(const TrendingEvent.started());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(const TrendingEvent.refreshRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    verify(() => fetch(any())).called(2);
    expect(events, isEmpty);
  });
}
