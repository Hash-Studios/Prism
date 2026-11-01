import 'dart:async';

import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_user_fixture.dart';

void main() {
  final signIn = signedInActionSignIn;
  setUp(() => app_state.prismUser = app_constants.createGuestPrismUser());
  tearDown(() {
    signedInActionSignIn = signIn;
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<BuildContext> mount(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    return context;
  }

  testWidgets('a signed-in action does not open sign-in', (tester) async {
    final context = await mount(tester);
    app_state.prismUser = profileUser();
    signedInActionSignIn = (_) => throw StateError('Unexpected sign-in');
    expect(await requireSignedInAction(context), isTrue);
  });

  for (final bool premium in <bool>[false, true]) {
    for (final bool sheetResult in <bool>[false, true]) {
      for (final bool loggedIn in <bool>[false, true]) {
        testWidgets('guest premium=$premium sheet=$sheetResult session=$loggedIn requires both proofs', (tester) async {
          final context = await mount(tester);
          app_state.prismUser.premium = premium;
          var prompts = 0;
          signedInActionSignIn = (_) async {
            prompts++;
            app_state.prismUser = profileUser(loggedIn: loggedIn, premium: premium);
            return sheetResult;
          };
          expect(await requireSignedInAction(context), sheetResult && loggedIn);
          expect(prompts, 1);
        });
      }
    }
  }

  testWidgets('unmounting while sign-in is pending cannot authorize an action', (tester) async {
    final context = await mount(tester);
    final reply = Completer<bool>();
    signedInActionSignIn = (_) => reply.future;
    final action = requireSignedInAction(context);
    await tester.pumpWidget(const SizedBox());
    app_state.prismUser = profileUser();
    reply.complete(true);
    expect(await action, isFalse);
  });
}
