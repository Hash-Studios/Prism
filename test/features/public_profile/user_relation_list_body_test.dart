import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/views/widgets/user_relation_list_body.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPublicProfileBloc extends MockBloc<PublicProfileEvent, PublicProfileState> implements PublicProfileBloc {}

void main() {
  late _MockPublicProfileBloc bloc;

  setUp(() {
    bloc = _MockPublicProfileBloc();
    when(() => bloc.state).thenReturn(PublicProfileState.initial());
    when(bloc.close).thenAnswer((_) async {});
    getIt.registerFactory<PublicProfileBloc>(() => bloc);
  });

  tearDown(getIt.reset);

  testWidgets('the clear button in the search field has a tooltip and clears the text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserRelationListBody(kind: UserRelationKind.followers, emails: <String>[]),
      ),
    );
    expect(find.byTooltip('Clear search'), findsNothing);

    await tester.enterText(find.byType(TextField), 'ana');
    await tester.pump();
    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(find.byTooltip('Clear search'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await tester.pump(const Duration(seconds: 1));
  });
}
