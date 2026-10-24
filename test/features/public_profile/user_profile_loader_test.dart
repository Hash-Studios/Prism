import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_loader.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
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
    ).thenReturn(PublicProfileState.initial().copyWith(profileId: 'a@x.com', status: LoadStatus.failure));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: BlocProvider<PublicProfileBloc>.value(
            value: bloc,
            child: const CustomScrollView(slivers: <Widget>[UserProfileLoader(userId: 'a@x.com')]),
          ),
        ),
      ),
    );

    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text(AppLocalizationsEn().accountCouldNotLoadWallpapers), findsOneWidget);

    await tester.tap(find.text(AppLocalizationsEn().accountTryAgain));

    verify(() => bloc.add(const PublicProfileEvent.refreshRequested())).called(1);
  });
}
