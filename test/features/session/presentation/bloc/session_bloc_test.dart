import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/usecases/session_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSessionUseCase extends Mock implements GetSessionUseCase {}

class _MockRefreshPremiumUseCase extends Mock implements RefreshPremiumUseCase {}

class _MockSignOutUseCase extends Mock implements SignOutUseCase {}

void main() {
  late _MockGetSessionUseCase getSessionUseCase;
  late _MockRefreshPremiumUseCase refreshPremiumUseCase;
  late _MockSignOutUseCase signOutUseCase;

  setUp(() {
    getSessionUseCase = _MockGetSessionUseCase();
    refreshPremiumUseCase = _MockRefreshPremiumUseCase();
    signOutUseCase = _MockSignOutUseCase();

    when(() => getSessionUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(
        const SessionEntity(
          userId: 'u1',
          email: 'user@test.com',
          name: 'User',
          profilePhoto: '',
          loggedIn: true,
          premium: false,
        ),
      ),
    );

    when(() => refreshPremiumUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(
        const SessionEntity(
          userId: 'u1',
          email: 'user@test.com',
          name: 'User',
          profilePhoto: '',
          loggedIn: true,
          premium: true,
        ),
      ),
    );

    when(() => signOutUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(SessionEntity.guest),
    );
  });

  blocTest<SessionBloc, SessionState>(
    'loads session and refreshes premium flag',
    build: () => SessionBloc(getSessionUseCase, refreshPremiumUseCase, signOutUseCase),
    act: (bloc) => bloc
      ..add(const SessionEvent.started())
      ..add(const SessionEvent.premiumRefreshRequested()),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.session.premium, isTrue);
    },
  );
}
