// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

class TestFirebaseAuth extends FirebaseAuthPlatform {
  static final TestFirebaseAuth instance = TestFirebaseAuth();
  final StreamController<UserPlatform?> _changes = StreamController<UserPlatform?>.broadcast(sync: true);
  String? uid;
  bool anonymous = false;

  Future<void> install(String? userId) async {
    FirebaseAuthPlatform.instance = this;
    if (Firebase.apps.isEmpty) {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    }
    uid = userId;
    anonymous = false;
  }

  void emit(String? userId) {
    uid = userId;
    _changes.add(currentUser);
  }

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({InternalUserDetails? currentUser, String? languageCode}) => this;

  @override
  UserPlatform? get currentUser => uid == null
      ? null
      : _TestUser(
          this,
          _TestMultiFactor(this),
          InternalUserDetails(
            userInfo: InternalUserInfo(uid: uid!, isAnonymous: anonymous, isEmailVerified: true),
            providerData: const <Map<Object?, Object?>?>[],
          ),
        );

  @override
  Stream<UserPlatform?> authStateChanges() async* {
    yield currentUser;
    yield* _changes.stream;
  }
}

class _TestMultiFactor extends MultiFactorPlatform {
  _TestMultiFactor(super.auth);
}

class _TestUser extends UserPlatform {
  _TestUser(super.auth, super.multiFactor, super.userData);
}
