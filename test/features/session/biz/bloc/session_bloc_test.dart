import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/session/domain/usecases/session_usecases.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSessionUseCase extends Mock implements GetSessionUseCase {}

class _MockSessionRepository extends Mock implements SessionRepository {}

void main() {
  late _MockGetSessionUseCase getSessionUseCase;
  late _MockSessionRepository sessionRepository;

  setUp(() {
    getSessionUseCase = _MockGetSessionUseCase();
    sessionRepository = _MockSessionRepository();

    when(() => sessionRepository.watchCurrentUser()).thenAnswer((_) => const Stream.empty());
    when(() => getSessionUseCase(const NoParams())).thenAnswer(
      (_) async =>
          Result.success(const SessionEntity(userId: 'u1', loggedIn: true, premium: true, subscriptionTier: 'pro')),
    );
  });

  blocTest<SessionBloc, SessionState>(
    'loads the session',
    build: () => SessionBloc(getSessionUseCase, sessionRepository: sessionRepository),
    act: (bloc) => bloc.add(const SessionEvent.started()),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.session.userId, 'u1');
      expect(bloc.state.session.loggedIn, isTrue);
      expect(bloc.state.session.premium, isTrue);
      expect(bloc.state.session.subscriptionTier, 'pro');
    },
  );
}
