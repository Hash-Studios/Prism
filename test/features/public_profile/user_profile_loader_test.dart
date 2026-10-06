import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_loader.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

void main() {
  setUpAll(() => registerFallbackValue(const PublicProfileEvent.refreshRequested()));

  testWidgets('a failed load with no walls shows an error with a Retry that refreshes', (tester) async {
    final bloc = _MockPublicProfileBloc();
    when(
      () => bloc.state,
    ).thenReturn(PublicProfileState.initial().copyWith(email: 'a@x.com', status: LoadStatus.failure));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<PublicProfileBloc>.value(
            value: bloc,
            child: const UserProfileLoader(email: 'a@x.com'),
          ),
        ),
      ),
    );

    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text("Couldn't load wallpapers"), findsOneWidget);

    await tester.tap(find.text('Retry'));

    verify(() => bloc.add(const PublicProfileEvent.refreshRequested())).called(1);
  });
}
