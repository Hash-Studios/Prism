import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_member.dart';
import 'package:Prism/features/folders/views/widgets/folder_members_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFoldersBloc extends MockBloc<FoldersEvent, FoldersState> implements FoldersBloc {}

final DateTime _at = DateTime.utc(2026, 10);

FolderMember _editor(String uid) => FolderMember(uid: uid, role: FolderRole.editor, addedBy: 'owner', addedAt: _at);

FolderEntity _folder({int editorCount = 1}) => FolderEntity(
  id: 'f1',
  ownerId: 'owner',
  name: 'Trip',
  createdAt: _at,
  updatedAt: _at,
  itemCount: 3,
  covers: const <String>[],
  editors: <FolderMember>[for (int i = 1; i <= editorCount; i++) _editor('e$i')],
);

Widget _host(FolderEntity folder, String userId, {double textScale = 1}) {
  final _MockFoldersBloc bloc = _MockFoldersBloc();
  when(() => bloc.state).thenReturn(FoldersState.initial().copyWith(userId: userId));
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: kLightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: BlocProvider<FoldersBloc>.value(
        value: bloc,
        child: FolderMembersRow(folder: folder, userId: userId),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the owner sees the people count and an Invite button', (tester) async {
    await tester.pumpWidget(_host(_folder(), 'owner'));
    await _settle(tester);

    expect(find.text('2 people'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
  });

  testWidgets('an editor sees the people count and no Invite button', (tester) async {
    await tester.pumpWidget(_host(_folder(), 'e1'));
    await _settle(tester);

    expect(find.text('2 people'), findsOneWidget);
    expect(find.text('Invite'), findsNothing);
  });

  testWidgets('the people area is a button labelled with the count', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_folder(), 'owner'));
    await _settle(tester);

    final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('2 people in this folder. Show people'));
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('six members show four avatars and a +2 chip', (tester) async {
    await tester.pumpWidget(_host(_folder(editorCount: 5), 'owner'));
    await _settle(tester);

    expect(find.text('6 people'), findsOneWidget);
    expect(find.byType(PrismAvatar), findsNWidgets(4));
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('the owner opens the People sheet and can remove an editor', (tester) async {
    await tester.pumpWidget(_host(_folder(), 'owner'));
    await _settle(tester);

    await tester.tap(find.text('2 people'));
    await _settle(tester);

    expect(find.text('People'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Leave folder'), findsNothing);
  });

  testWidgets('an editor opens the People sheet with Leave folder and no Remove', (tester) async {
    await tester.pumpWidget(_host(_folder(), 'e1'));
    await _settle(tester);

    await tester.tap(find.text('2 people'));
    await _settle(tester);

    expect(find.text('People'), findsOneWidget);
    expect(find.text('Leave folder'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('the row lays out at 2x text on a 375 point wide screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(_folder(editorCount: 5), 'owner', textScale: 2));
    await _settle(tester);

    expect(find.text('Invite'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
