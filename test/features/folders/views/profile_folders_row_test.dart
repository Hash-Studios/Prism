import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/profile_folders_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePublicFoldersRepository implements PublicFoldersRepository {
  List<PublicFolderEntity> ownerFolders = const <PublicFolderEntity>[];
  Result<List<PublicFolderEntity>>? ownerFoldersResult;
  Future<Result<List<PublicFolderEntity>>> Function(String ownerId)? ownerFoldersHandler;

  @override
  Future<Result<List<PublicFolderEntity>>> fetchOwnerFolders(String ownerId) async =>
      ownerFoldersHandler?.call(ownerId) ?? ownerFoldersResult ?? Result.success(ownerFolders);

  @override
  Future<Result<PublicFolderEntity?>> fetchFolder(String folderId) async => Result.success(null);

  @override
  Future<Result<List<String>>> fetchWallIds(String folderId) async => Result.success(const <String>[]);

  @override
  Future<Result<List<PublicFolderEntity>>> fetchFollowedFolders(String userId) async =>
      Result.success(const <PublicFolderEntity>[]);

  @override
  Future<Result<bool>> isFollowing(String folderId, String userId) async => Result.success(false);

  @override
  Future<Result<void>> setFollowing(String folderId, {required bool following}) async => Result.success<void>(null);

  @override
  Future<Result<bool>> setPublic(String folderId, {required bool isPublic}) async => Result.success(isPublic);
}

PublicFolderEntity _folder(String id, String name, {int itemCount = 2}) => PublicFolderEntity(
  id: id,
  ownerId: 'owner',
  name: name,
  itemCount: itemCount,
  covers: const <String>[],
  followerCount: 0,
);

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme ?? kLightTheme,
  home: Scaffold(body: child),
);

// The row loads from the fake repository; pump a fixed time rather than settle.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _FakePublicFoldersRepository repo;

  setUp(() {
    repo = _FakePublicFoldersRepository();
    getIt.registerSingleton<PublicFoldersRepository>(repo);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('two public folders show under a Folders header, marked public on your own profile', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    repo.ownerFolders = <PublicFolderEntity>[_folder('a', 'Night Owl'), _folder('b', 'Trail Mix')];
    await tester.pumpWidget(_host(const ProfileFoldersRow(ownerId: 'owner', ownProfile: true)));
    await _settle(tester);

    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Night Owl'), findsOneWidget);
    expect(find.text('Trail Mix'), findsOneWidget);
    for (final String name in <String>['Night Owl', 'Trail Mix']) {
      final String value = tester.getSemantics(find.bySemanticsLabel(name)).getSemanticsData().value;
      expect(value, contains('Public'));
    }
    handle.dispose();

    // The same row in dark theme.
    await tester.pumpWidget(_host(const ProfileFoldersRow(ownerId: 'owner', ownProfile: true), theme: kDarkTheme));
    await _settle(tester);
    expect(find.text('Night Owl'), findsOneWidget);
    expect(find.text('Trail Mix'), findsOneWidget);
  });

  testWidgets('a visitor sees the folders without the public marker', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    repo.ownerFolders = <PublicFolderEntity>[_folder('a', 'Night Owl'), _folder('b', 'Trail Mix')];
    await tester.pumpWidget(_host(const ProfileFoldersRow(ownerId: 'owner', ownProfile: false)));
    await _settle(tester);

    expect(find.text('Night Owl'), findsOneWidget);
    for (final String name in <String>['Night Owl', 'Trail Mix']) {
      final String value = tester.getSemantics(find.bySemanticsLabel(name)).getSemanticsData().value;
      expect(value, isNot(contains('Public')));
    }
    handle.dispose();
  });

  testWidgets('no public folders hide the Folders header', (tester) async {
    repo.ownerFolders = const <PublicFolderEntity>[];
    await tester.pumpWidget(_host(const ProfileFoldersRow(ownerId: 'owner', ownProfile: true)));
    await _settle(tester);

    expect(find.text('Folders'), findsNothing);
  });

  testWidgets('a failed folder read hides the Folders header', (tester) async {
    repo.ownerFoldersResult = Result.error(const NetworkFailure('offline'));
    await tester.pumpWidget(_host(const ProfileFoldersRow(ownerId: 'owner', ownProfile: true)));
    await _settle(tester);

    expect(find.text('Folders'), findsNothing);
  });

  testWidgets('changing profiles hides the old folders until the new profile read completes', (tester) async {
    final Completer<Result<List<PublicFolderEntity>>> pending = Completer<Result<List<PublicFolderEntity>>>();
    repo.ownerFolders = <PublicFolderEntity>[_folder('old', 'Old profile folder')];
    await tester.pumpWidget(_host(const ProfileFoldersRow(ownerId: 'owner-a', ownProfile: false)));
    await _settle(tester);
    expect(find.text('Old profile folder'), findsOneWidget);

    repo.ownerFoldersHandler = (_) => pending.future;
    await tester.pumpWidget(_host(const ProfileFoldersRow(ownerId: 'owner-b', ownProfile: false)));
    await tester.pump();
    expect(find.text('Old profile folder'), findsNothing);

    pending.complete(Result.success(<PublicFolderEntity>[_folder('new', 'New profile folder')]));
    await _settle(tester);
    expect(find.text('New profile folder'), findsOneWidget);
  });
}
