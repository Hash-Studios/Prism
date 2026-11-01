// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/edit_profile_panel.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/profile_user_fixture.dart';

class _DelayedFirebaseCore extends MockFirebaseApp {
  final Completer<void> ready = Completer<void>();

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => <CoreInitializeResponse>[];

  @override
  Future<CoreInitializeResponse> initializeApp(String name, CoreFirebaseOptions options) async {
    await ready.future;
    return CoreInitializeResponse(name: name, options: options, pluginConstants: <String, Object?>{});
  }
}

class _NoMultiFactor extends MultiFactorPlatform {
  _NoMultiFactor(super.auth);
}

class _GoogleUser extends UserPlatform {
  _GoogleUser(FirebaseAuthPlatform auth)
    : super(
        auth,
        _NoMultiFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'me',
            email: 'me@example.com',
            photoUrl: _googlePhoto,
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: const <Map<Object?, Object?>?>[
            <String, Object?>{'providerId': 'google.com', 'uid': 'me'},
          ],
        ),
      );
}

class _GoogleAuth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({InternalUserDetails? currentUser, String? languageCode}) => this;

  @override
  UserPlatform get currentUser => _GoogleUser(this);
}

class _ReadinessFirestore extends Fake implements FirestoreClient {
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> writeCompleted = Completer<void>();
  Map<String, dynamic>? write;

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) async {
    writeStarted.complete();
    await FirebaseInit.readyFuture;
    write = Map<String, dynamic>.of(data);
    writeCompleted.complete();
  }
}

const String _googlePhoto = 'https://lh3.googleusercontent.com/a/me=s96-c';
const String _customPhoto = 'https://raw.githubusercontent.com/Hash-Studios/walls/main/me_1_me.jpg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  testWidgets('restores the Google photo when Firebase becomes ready during the removal write', (tester) async {
    final FirebaseAuthPlatform previousAuth = FirebaseAuthPlatform.instance;
    final _DelayedFirebaseCore core = _DelayedFirebaseCore();
    final _ReadinessFirestore firestore = _ReadinessFirestore();
    TestFirebaseCoreHostApi.setUp(core);
    FirebaseAuthPlatform.instance = _GoogleAuth();
    await getIt.reset();
    getIt.registerSingleton<FirestoreClient>(firestore);
    app_state.prismUser = profileUser(id: 'me', profilePhoto: _customPhoto);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (_) async => true,
    );
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
      FirebaseAuthPlatform.instance = previousAuth;
      TestFirebaseCoreHostApi.setUp(null);
      await getIt.reset();
      app_state.prismUser = profileUser(id: '', loggedIn: false);
    });

    final Future<FirebaseApp> initialization = Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-key',
        appId: 'test-app',
        messagingSenderId: 'test-sender',
        projectId: 'demo-prism',
      ),
    );
    FirebaseInit.setFuture(initialization.then((_) => true));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EditProfilePanel()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(Firebase.apps, isEmpty);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pump();

    core.ready.complete();
    await initialization;
    await firestore.writeStarted.future;
    await firestore.writeCompleted.future;
    await tester.pump();

    expect(firestore.write?['profilePhoto'], _googlePhoto);
    expect(app_state.prismUser.profilePhoto, _googlePhoto);
  });
}
