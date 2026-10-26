import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/account/username_service.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/popup/edit_profile_panel.dart';
import 'package:Prism/features/public_profile/views/widgets/edit_profile_header.dart';
import 'package:Prism/features/session/domain/entities/session_entity.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/pending_image_picker.dart';
import '../../../support/profile_user_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late FakeFirestoreClient firestore;
  late List<Map<String, Object?>> claims;
  late Future<Object?> Function(Map<String, Object?>) claimResponse;

  setUp(() async {
    await getIt.reset();
    firestore = FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
    claims = <Map<String, Object?>>[];
    claimResponse = (data) async => <String, Object?>{'username': data['username']};
    UsernameService.instance = UsernameService(
      request: (data) {
        claims.add(data);
        return claimResponse(data);
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (_) async => true,
    );
    app_state.prismUser = profileUser(
      id: 'me',
      username: 'creator_01',
      bio: 'Hello',
      profilePhoto: '',
      links: const <String, String>{'custom link': 'https://example.com'},
    )..name = 'Me Myself';
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    await getIt.reset();
    UsernameService.instance = UsernameService();
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    // A tall surface keeps every field on screen.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditProfilePanel())),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save changes')).onPressed != null;

  testWidgets('shows the current profile in fields, with Save disabled until something changes', (tester) async {
    await pumpPanel(tester);

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Me Myself'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'creator_01'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Hello'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'https://example.com'), findsOneWidget);
    expect(find.text('Use 3 or more letters, numbers or underscores (_).'), findsOneWidget);
    expect(find.text('Edit cover'), findsOneWidget);
    expect(find.byTooltip('Remove cover photo'), findsNothing);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('change cover photo has a hit target of at least 44 pixels', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpPanel(tester);

      expect(tester.getRect(find.bySemanticsLabel('Change cover photo')).height, greaterThanOrEqualTo(44));
    } finally {
      semantics.dispose();
    }
  });

  group('photo picker', () {
    late ImagePickerPlatform previousPicker;
    late PendingImagePicker picker;

    setUp(() {
      previousPicker = ImagePickerPlatform.instance;
      picker = PendingImagePicker();
      ImagePickerPlatform.instance = picker;
    });

    tearDown(() => ImagePickerPlatform.instance = previousPicker);

    testWidgets('a second tap while the gallery is open does not open it again', (tester) async {
      await pumpPanel(tester);

      await tester.tap(find.byKey(EditProfileHeader.changeCoverKey));
      await tester.pump();
      await tester.tap(find.byKey(EditProfileHeader.changeCoverKey));
      await tester.pump();

      expect(picker.calls, 1);
      picker.finish(const <String>[]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EditProfileHeader.changeCoverKey));
      await tester.pump();
      expect(picker.calls, 2);
      picker.finish(const <String>[]);
    });

    testWidgets('a gallery another screen holds open is not an error', (tester) async {
      await pumpPanel(tester);
      unawaited(picker.getImageFromSource(source: ImageSource.gallery));

      await tester.tap(find.byKey(EditProfileHeader.changeCoverKey));
      await tester.pumpAndSettle();

      expect(picker.calls, 2);
      expect(saveEnabled(tester), isFalse);
    });
  });

  testWidgets('editing the name enables Save', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Me Myself'), 'Me Again');
    await tester.pump();

    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('dirty name still asks before leaving when username is invalid', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Me Myself'), 'Me Again');
    await tester.enterText(find.widgetWithText(TextField, 'creator_01'), 'ab');
    await tester.pumpAndSettle();

    expect(saveEnabled(tester), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  group('username', () {
    Finder usernameField() => find.widgetWithText(TextField, 'creator_01');

    testWidgets('two characters show an inline error and cannot be saved', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'ab');
      await tester.pump();

      expect(find.text('Use at least 3 characters.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('three characters are accepted and saved once they are free', (tester) async {
      firestore.onQuery = (_) => const <FakeDocRow>[];
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'abc');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Use at least 3 characters.'), findsNothing);
      expect(find.text('That username is taken.'), findsNothing);
      expect(saveEnabled(tester), isTrue);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(firestore.writes, isEmpty, reason: 'Canonical usernames are written only by the server.');
      expect(app_state.prismUser.username, 'abc');
      expect(claims, <Map<String, Object?>>[
        <String, Object?>{'username': 'abc'},
      ]);
    });

    testWidgets('a rejected server claim leaves the name unchanged and the editor open', (tester) async {
      claimResponse = (_) async => throw StateError('already-exists');
      await pumpPanel(tester);
      await tester.enterText(usernameField(), 'racing_name');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(app_state.prismUser.username, 'creator_01');
      expect(firestore.writes, isEmpty);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a claim completed after account switch cannot mutate the new session', (tester) async {
      final Completer<Object?> pending = Completer<Object?>();
      claimResponse = (_) => pending.future;
      await pumpPanel(tester);
      await tester.enterText(usernameField(), 'claimed_name');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      final previousUser = app_state.prismUser;
      app_state.prismUser = profileUser(id: 'other', username: 'other_name');
      pending.complete(<String, Object?>{'username': 'claimed_name'});
      await tester.pumpAndSettle();
      expect(app_state.prismUser.username, 'other_name');
      expect(previousUser.username, 'creator_01');
      expect(firestore.writes, isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('an account switch during persistence stops the rest of the profile save', (tester) async {
      final original = app_state.prismUser;
      final session = _DelayedSession(original);
      getIt.registerSingleton<SessionRepository>(session);
      await pumpPanel(tester);
      await tester.enterText(usernameField(), 'claimed_name');
      await tester.enterText(find.widgetWithText(TextField, 'Me Myself'), 'Changed Name');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(session.started.isCompleted, isTrue);
      session.currentUser = profileUser(id: 'other', username: 'other_name');
      session.gate.complete();
      await tester.pumpAndSettle();
      expect(firestore.writes, isEmpty);
      expect(original.name, 'Me Myself');
      expect(app_state.prismUser.username, 'other_name');
      expect(session.replacements, hasLength(1));
      expect(find.text('Edit profile'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a name another user holds shows an inline error', (tester) async {
      firestore.docs[FirebaseCollections.usernames] = <String, Map<String, dynamic>>{
        'taken_name': <String, dynamic>{'uid': 'someone-else'},
      };
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'taken_name');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('That username is taken.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('spaces and symbols show an inline error', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'bad name!');
      await tester.pump();

      expect(find.text('Use letters, numbers and underscores only.'), findsOneWidget);
    });

    testWidgets('an all-caps name shows an inline error and no availability check runs', (tester) async {
      final _LookupRecordingFirestore recording = await _useRecordingFirestore();
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'SHOUTY');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Use at least one lowercase letter.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      expect(recording.lookups, isEmpty);
    });

    testWidgets('a name with a lowercase letter is checked and shows no all-caps error', (tester) async {
      final _LookupRecordingFirestore recording = await _useRecordingFirestore();
      await pumpPanel(tester);

      await tester.enterText(usernameField(), 'Shouty');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Use at least one lowercase letter.'), findsNothing);
      expect(recording.lookups, <String>['shouty']);
      expect(saveEnabled(tester), isTrue);
    });
  });

  testWidgets('clearing the bio by hand enables Save and saves an empty bio', (tester) async {
    app_state.prismUser.bio = 'old bio';
    await pumpPanel(tester);

    await tester.enterText(find.widgetWithText(TextField, 'old bio'), '');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(firestore.writes.single.data, <String, Object?>{'bio': ''});
    expect(app_state.prismUser.bio, '');
  });

  group('links', () {
    Finder linkField() => find.widgetWithText(TextField, 'https://example.com');

    Future<void> selectCoffee(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Link type, Custom link'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Buy Me a Coffee'));
      await tester.tap(find.text('Buy Me a Coffee'));
      await tester.pumpAndSettle();
    }

    for (final String host in <String>['buymeacoffee.com', 'buymeacoff.ee']) {
      testWidgets('a $host link enables Save and is persisted under the stable coffee key', (tester) async {
        await pumpPanel(tester);
        await selectCoffee(tester);

        await tester.enterText(find.widgetWithText(TextField, ''), 'https://$host/prism');
        await tester.pump();

        expect(find.text('Enter a valid Buy Me a Coffee link.'), findsNothing);
        expect(saveEnabled(tester), isTrue);
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        expect((firestore.writes.single.data!['links'] as Map)['buymeacoffee'], 'https://$host/prism');
      });
    }

    testWidgets('a coffee domain in an unrelated URL shows an error and blocks Save', (tester) async {
      await pumpPanel(tester);
      await selectCoffee(tester);

      await tester.enterText(find.widgetWithText(TextField, ''), 'https://example.com/buymeacoff.ee');
      await tester.pump();

      expect(find.text('Enter a valid Buy Me a Coffee link.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
      expect(firestore.writes, isEmpty);
    });

    testWidgets('a link with an unsafe scheme shows an inline error and blocks saving', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(linkField(), 'javascript:alert(1)');
      await tester.pump();

      expect(find.text('Enter a valid link.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('an https link clears the error and is saved as typed', (tester) async {
      await pumpPanel(tester);

      await tester.enterText(linkField(), 'javascript:alert(1)');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'javascript:alert(1)'), 'https://example.com/me');
      await tester.pump();

      expect(find.text('Enter a valid link.'), findsNothing);
      expect(saveEnabled(tester), isTrue);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect((firestore.writes.single.data!['links'] as Map)['custom link'], 'https://example.com/me');
    });
  });

  testWidgets('bio and link can be removed, and each asks first', (tester) async {
    await pumpPanel(tester);

    expect(find.byTooltip('Remove bio'), findsOneWidget);
    expect(find.byTooltip('Remove link'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove bio'));
    await tester.pumpAndSettle();

    expect(find.text('Remove bio?'), findsOneWidget);
    expect(find.text("This can't be undone."), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Hello'), findsOneWidget);
  });

  group('Remove photo', () {
    const String googlePhoto = 'https://lh3.googleusercontent.com/a/me=s96-c';
    const String customPhoto = 'https://raw.githubusercontent.com/Hash-Studios/walls/main/me_1_me.jpg';

    tearDown(() => signedInAccountPhoto = () => null);

    for (final String photo in <String>[defaultProfilePhotoUrl, googlePhoto]) {
      testWidgets('is not offered for ${photo == googlePhoto ? 'the Google photo' : 'no photo'}', (tester) async {
        app_state.prismUser.profilePhoto = photo;
        await pumpPanel(tester);

        expect(find.text('Remove photo'), findsNothing);
      });
    }

    for (final String? accountPhoto in <String?>[googlePhoto, null]) {
      testWidgets('asks first, then puts back ${accountPhoto == null ? 'no photo' : 'the Google photo'}', (
        tester,
      ) async {
        signedInAccountPhoto = () => accountPhoto;
        app_state.prismUser.profilePhoto = customPhoto;
        await pumpPanel(tester);

        await tester.tap(find.text('Remove photo'));
        await tester.pumpAndSettle();
        expect(find.text('Remove profile photo?'), findsOneWidget);
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        final String expected = accountPhoto ?? defaultProfilePhotoUrl;
        expect(app_state.prismUser.profilePhoto, expected);
        expect(firestore.docs[FirebaseCollections.usersV2]!['me']!['profilePhoto'], expected);
        expect(find.text('Remove photo'), findsNothing);
      });
    }

    testWidgets('keeps the custom photo when the write fails', (tester) async {
      await getIt.reset();
      getIt.registerSingleton<FirestoreClient>(_FailingWriteFirestore());
      signedInAccountPhoto = () => googlePhoto;
      app_state.prismUser.profilePhoto = customPhoto;
      await pumpPanel(tester);

      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(app_state.prismUser.profilePhoto, customPhoto);
      expect(find.text('Remove photo'), findsOneWidget);
      // The error toast runs a timer.
      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('the link type opens a sheet that marks the current type', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.bySemanticsLabel('Link type, Custom link'));
    await tester.pumpAndSettle();

    expect(find.text('Link type'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Link type, GitHub'), findsOneWidget);
  });

  testWidgets('leaving with unsaved changes asks before discarding', (tester) async {
    await pumpPanel(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Me Myself'), 'Me Again');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsNothing);
  });

  testWidgets('leaving without changes does not ask', (tester) async {
    await pumpPanel(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit profile'), findsNothing);
  });
}

Future<_LookupRecordingFirestore> _useRecordingFirestore() async {
  await getIt.reset();
  final _LookupRecordingFirestore recording = _LookupRecordingFirestore();
  getIt.registerSingleton<FirestoreClient>(recording);
  return recording;
}

class _LookupRecordingFirestore extends FakeFirestoreClient {
  final List<String> lookups = <String>[];

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic> data, String docId) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) {
    if (collection == FirebaseCollections.usernames) lookups.add(id);
    return super.getById(collection, id, map, sourceTag: sourceTag, preferCacheFirst: preferCacheFirst);
  }
}

class _FailingWriteFirestore extends FakeFirestoreClient {
  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) =>
      Future<void>.error(StateError('offline'));
}

class _DelayedSession extends Fake implements SessionRepository {
  _DelayedSession(this.currentUser);

  @override
  PrismUsersV2 currentUser;
  final Completer<void> started = Completer<void>();
  final Completer<void> gate = Completer<void>();
  final List<PrismUsersV2> replacements = <PrismUsersV2>[];

  @override
  Future<Result<SessionEntity>> replaceCurrentUser(PrismUsersV2 user) async {
    replacements.add(user);
    if (!started.isCompleted) started.complete();
    await gate.future;
    return Result.success(SessionEntity.guest);
  }
}
