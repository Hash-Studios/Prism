import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/domain/entities/setups_page.dart';
import 'package:Prism/features/setups/domain/usecases/setups_usecases.dart';
import 'package:Prism/features/setups/presentation/bloc/setups_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFetchSetupsUseCase extends Mock implements FetchSetupsUseCase {}

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
        return Result.success(
          const SetupsPage(
            items: <SetupEntity>[SetupEntity(id: '1', payload: <String, dynamic>{})],
            hasMore: true,
            nextCursor: '1',
          ),
        );
      }
      return Result.success(
        const SetupsPage(
          items: <SetupEntity>[SetupEntity(id: '2', payload: <String, dynamic>{})],
          hasMore: false,
          nextCursor: '2',
        ),
      );
    });
  });

  blocTest<SetupsBloc, SetupsState>(
    'paginates and appends unique setups',
    build: () => SetupsBloc(fetchUseCase),
    act: (bloc) => bloc
      ..add(const SetupsEvent.started())
      ..add(const SetupsEvent.fetchMoreRequested()),
    skip: 0,
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items.length, 2);
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.items.map((e) => e.id), containsAll(<String>['1', '2']));
    },
  );
}
