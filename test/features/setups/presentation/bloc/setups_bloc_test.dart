import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/setups/biz/bloc/setups_bloc.j.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/domain/entities/setups_page.dart';
import 'package:Prism/features/setups/domain/usecases/setups_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/fake_user_block_repository.dart';

class _MockFetchSetupsUseCase extends Mock implements FetchSetupsUseCase {}

SetupEntity _setup(String id, {String email = ''}) {
  return SetupEntity(id: id, email: email, image: '', source: WallpaperSource.prism, review: true);
}

void main() {
  setUpAll(() {
    registerFallbackValue(const FetchSetupsParams(refresh: true));
  });

  late _MockFetchSetupsUseCase fetchUseCase;

  setUp(() {
    fetchUseCase = _MockFetchSetupsUseCase();

    when(() => fetchUseCase(any())).thenAnswer((invocation) async {
      final params = invocation.positionalArguments.first as FetchSetupsParams;
      if (params.refresh) {
        return Result.success(SetupsPage(items: <SetupEntity>[_setup('1')], hasMore: true, nextCursor: '1'));
      }
      return Result.success(
        SetupsPage(items: <SetupEntity>[_setup('1'), _setup('2')], hasMore: false, nextCursor: '2'),
      );
    });
  });

  blocTest<SetupsBloc, SetupsState>(
    'appends the next page and drops duplicate ids',
    build: () => SetupsBloc(fetchUseCase, FakeUserBlockRepository.pending()),
    act: (bloc) => bloc
      ..add(const SetupsEvent.started())
      ..add(const SetupsEvent.fetchMoreRequested()),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.items.map((e) => e.id), <String>['1', '2']);
    },
  );

  test('blocking a creator removes their setups from the emitted state without a refetch', () async {
    when(() => fetchUseCase(any())).thenAnswer(
      (_) async => Result.success(
        SetupsPage(
          items: <SetupEntity>[
            _setup('1', email: 'blocked@example.com'),
            _setup('2', email: 'kept@example.com'),
          ],
          hasMore: false,
        ),
      ),
    );
    final blockRepo = FakeUserBlockRepository.pending();
    final bloc = SetupsBloc(fetchUseCase, blockRepo);
    addTearDown(bloc.close);

    bloc.add(const SetupsEvent.started());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.items.map((e) => e.id), <String>['1', '2']);

    blockRepo.completeInitial(<String>{});
    await Future<void>.delayed(Duration.zero);
    blockRepo.completeInitial(<String>{'blocked@example.com'});
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.items.map((e) => e.id), <String>['2']);
    verify(() => fetchUseCase(any())).called(1);
  });
}
