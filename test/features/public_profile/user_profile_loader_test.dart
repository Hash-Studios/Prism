import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_loader.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

void main() {
  testWidgets('uses square placeholders before the profile starts loading', (tester) async {
    final bloc = _MockPublicProfileBloc();
    when(() => bloc.state).thenReturn(PublicProfileState.initial());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<PublicProfileBloc>.value(
            value: bloc,
            child: const UserProfileLoader(email: 'profile@example.com'),
          ),
        ),
      ),
    );

    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration as BoxDecoration;
    expect(find.byType(LoadingCards), findsOneWidget);
    expect(decoration.borderRadius, BorderRadius.zero);
  });

  testWidgets('uses square placeholders while the profile is loading', (tester) async {
    final bloc = _MockPublicProfileBloc();
    when(
      () => bloc.state,
    ).thenReturn(PublicProfileState.initial().copyWith(email: 'profile@example.com', status: LoadStatus.loading));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<PublicProfileBloc>.value(
            value: bloc,
            child: const UserProfileLoader(email: 'profile@example.com'),
          ),
        ),
      ),
    );

    final BoxDecoration decoration =
        tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration as BoxDecoration;
    expect(find.byType(LoadingCards), findsOneWidget);
    expect(decoration.borderRadius, BorderRadius.zero);
  });
}
