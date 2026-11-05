import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/folders/views/widgets/folder_members_sheet.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPublicProfileRepository extends Mock implements PublicProfileRepository {}

const PublicProfileEntity _ana = PublicProfileEntity(
  id: 'ana',
  name: 'Ana',
  email: '',
  username: 'ana',
  profilePhoto: '',
  bio: '',
  links: <String, String>{},
  coverPhoto: '',
);

const PublicProfileEntity _bea = PublicProfileEntity(
  id: 'bea',
  name: 'Bea',
  email: '',
  username: 'bea',
  profilePhoto: '',
  bio: '',
  links: <String, String>{},
  coverPhoto: '',
);

Widget _host({String uid = 'ana'}) => MaterialApp(
  home: FolderMemberProfile(
    uid: uid,
    placeholder: const Text('Loading profile'),
    builder: (_, profile) => Text(profile?.name ?? 'Unavailable profile'),
  ),
);

void main() {
  late _MockPublicProfileRepository profiles;

  setUp(() {
    profiles = _MockPublicProfileRepository();
    getIt.registerSingleton<PublicProfileRepository>(profiles);
  });

  tearDown(() => getIt.reset());

  testWidgets('parent rebuilds keep the active profile subscription', (tester) async {
    int listens = 0;
    int cancellations = 0;
    when(() => profiles.watchProfile('ana')).thenAnswer(
      (_) => Stream<PublicProfileEntity?>.multi((controller) {
        listens++;
        controller.add(_ana);
        controller.onCancel = () => cancellations++;
      }),
    );

    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.text('Ana'), findsOneWidget);

    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('Ana'), findsOneWidget);
    expect(listens, 1);
    expect(cancellations, 0);
    verify(() => profiles.watchProfile('ana')).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(cancellations, 1);
  });

  testWidgets('changing uid clears the old profile until the new profile arrives', (tester) async {
    int oldCancellations = 0;
    when(() => profiles.watchProfile('ana')).thenAnswer(
      (_) => Stream<PublicProfileEntity?>.multi((controller) {
        controller.add(_ana);
        controller.onCancel = () => oldCancellations++;
      }),
    );
    final StreamController<PublicProfileEntity?> next = StreamController<PublicProfileEntity?>();
    addTearDown(next.close);
    when(() => profiles.watchProfile('bea')).thenAnswer((_) => next.stream);

    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.text('Ana'), findsOneWidget);

    await tester.pumpWidget(_host(uid: 'bea'));

    expect(find.text('Ana'), findsNothing);
    expect(find.text('Loading profile'), findsOneWidget);
    expect(oldCancellations, 1);
    next.add(_bea);
    await tester.pump();
    await tester.pump();
    expect(find.text('Bea'), findsOneWidget);
    expect(find.text('Loading profile'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(next.hasListener, isFalse);
  });

  testWidgets('a missing profile leaves the placeholder and renders the fallback', (tester) async {
    when(() => profiles.watchProfile('ana')).thenAnswer((_) => Stream<PublicProfileEntity?>.value(null));

    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('Unavailable profile'), findsOneWidget);
    expect(find.text('Loading profile'), findsNothing);
  });

  testWidgets('a profile error leaves the placeholder and renders the fallback', (tester) async {
    when(() => profiles.watchProfile('ana')).thenAnswer(
      (_) => Stream<PublicProfileEntity?>.error(StateError('profile read failed')),
    );

    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('Unavailable profile'), findsOneWidget);
    expect(find.text('Loading profile'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a profile stream that closes without data renders the fallback', (tester) async {
    when(() => profiles.watchProfile('ana')).thenAnswer((_) => const Stream<PublicProfileEntity?>.empty());

    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('Unavailable profile'), findsOneWidget);
    expect(find.text('Loading profile'), findsNothing);
  });

  testWidgets('an open profile stream without events stays loading until disposal', (tester) async {
    final StreamController<PublicProfileEntity?> pending = StreamController<PublicProfileEntity?>();
    addTearDown(pending.close);
    when(() => profiles.watchProfile('ana')).thenAnswer((_) => pending.stream);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(minutes: 1));

    expect(find.text('Loading profile'), findsOneWidget);
    expect(find.text('Unavailable profile'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(pending.hasListener, isFalse);
  });
}
