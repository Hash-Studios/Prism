import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/badge_entity.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/entities/transaction_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/session/domain/usecases/session_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSessionUseCase extends Mock implements GetSessionUseCase {}

class _MockRefreshPremiumUseCase extends Mock implements RefreshPremiumUseCase {}

class _MockSignOutUseCase extends Mock implements SignOutUseCase {}

class _MockSessionRepository extends Mock implements SessionRepository {}

void main() {
  late _MockGetSessionUseCase getSessionUseCase;
  late _MockRefreshPremiumUseCase refreshPremiumUseCase;
  late _MockSignOutUseCase signOutUseCase;
  late _MockSessionRepository sessionRepository;

  setUp(() {
    getSessionUseCase = _MockGetSessionUseCase();
    refreshPremiumUseCase = _MockRefreshPremiumUseCase();
    signOutUseCase = _MockSignOutUseCase();
    sessionRepository = _MockSessionRepository();

    when(() => sessionRepository.watchCurrentUser()).thenAnswer((_) => const Stream.empty());

    when(() => getSessionUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(
        const SessionEntity(
          userId: 'u1',
          email: 'user@test.com',
          name: 'User',
          username: 'User',
          profilePhoto: '',
          coverPhoto: '',
          bio: '',
          loggedIn: true,
          premium: false,
          subscriptionTier: 'free',
          coins: 0,
          links: <String, String>{},
          followers: <String>[],
          following: <String>[],
          badges: <BadgeEntity>[],
          transactions: <TransactionEntity>[],
          subPrisms: <String>[],
          uploadsWeekStart: '',
          uploadsThisWeek: 0,
        ),
      ),
    );

    when(() => refreshPremiumUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(
        const SessionEntity(
          userId: 'u1',
          email: 'user@test.com',
          name: 'User',
          username: 'User',
          profilePhoto: '',
          coverPhoto: '',
          bio: '',
          loggedIn: true,
          premium: true,
          subscriptionTier: 'pro',
          coins: 100,
          links: <String, String>{},
          followers: <String>[],
          following: <String>[],
          badges: <BadgeEntity>[],
          transactions: <TransactionEntity>[],
          subPrisms: <String>[],
          uploadsWeekStart: '',
          uploadsThisWeek: 0,
        ),
      ),
    );

    when(() => signOutUseCase(const NoParams())).thenAnswer((_) async => Result.success(SessionEntity.guest));
  });

  blocTest<SessionBloc, SessionState>(
    'loads session and refreshes premium flag',
    build: () =>
        SessionBloc(getSessionUseCase, refreshPremiumUseCase, signOutUseCase, sessionRepository: sessionRepository),
    act: (bloc) => bloc
      ..add(const SessionEvent.started())
      ..add(const SessionEvent.premiumRefreshRequested()),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.session.premium, isTrue);
    },
  );
}
