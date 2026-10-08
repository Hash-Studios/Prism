import 'package:Prism/core/account/delete_account_service.dart';
import 'package:Prism/core/account/reauth_cancelled.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../support/profile_user_fixture.dart';

void main() {
  late List<String> calls;

  DeleteAccountService build({Future<void> Function()? reauthenticate, Future<void> Function()? deleteOnServer}) {
    return DeleteAccountService(
      reauthenticate: reauthenticate ?? () async => calls.add('reauth'),
      deleteOnServer: deleteOnServer ?? () async => calls.add('server'),
      signOut: () async {
        calls.add('signOut');
        return true;
      },
      clearLocalData: (String userId) async => calls.add('clear:$userId'),
    );
  }

  setUp(() {
    calls = <String>[];
    app_state.prismUser = profileUser(id: 'user-1');
  });

  test('re-authenticates, deletes on the server, signs out, then clears this device', () async {
    await build().deleteAccount();

    expect(calls, <String>['reauth', 'server', 'signOut', 'clear:user-1']);
  });

  test('a cancelled re-authentication stops before the server and leaves local data alone', () async {
    final service = build(
      reauthenticate: () async => throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    );

    await expectLater(service.deleteAccount(), throwsA(isA<GoogleSignInException>()));

    expect(calls, isEmpty);
  });

  test('a server failure keeps the local data', () async {
    final service = build(deleteOnServer: () async => throw StateError('server down'));

    await expectLater(service.deleteAccount(), throwsStateError);

    expect(calls, <String>['reauth']);
  });

  test('the server call may run as long as a batch delete needs', () {
    expect(DeleteAccountService.serverTimeout, const Duration(seconds: 300));
  });

  group('isReauthCancelled', () {
    test('is true for a closed Google or Apple prompt', () {
      expect(isReauthCancelled(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled)), isTrue);
      expect(
        isReauthCancelled(
          const SignInWithAppleAuthorizationException(code: AuthorizationErrorCode.canceled, message: ''),
        ),
        isTrue,
      );
    });

    test('is false for real failures', () {
      expect(isReauthCancelled(const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError)), isFalse);
      expect(
        isReauthCancelled(
          const SignInWithAppleAuthorizationException(code: AuthorizationErrorCode.failed, message: ''),
        ),
        isFalse,
      );
      expect(isReauthCancelled(StateError('no token')), isFalse);
    });
  });
}
