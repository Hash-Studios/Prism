import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:Prism/features/ios_shortcuts/views/pages/ios_shortcuts_guide_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../support/profile_user_fixture.dart';

class _MockFoldersBloc extends MockBloc<FoldersEvent, FoldersState> implements FoldersBloc {}

class _RecordingUrlLauncher extends UrlLauncherPlatform {
  _RecordingUrlLauncher({required this.opens});

  final bool opens;
  final List<String> urls = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    return opens;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FolderEntity _folder(String id, String name, {int itemCount = 0}) {
  final DateTime at = DateTime.utc(2026, 10);
  return FolderEntity(
    id: id,
    ownerId: 'u1',
    name: name,
    createdAt: at,
    updatedAt: at,
    itemCount: itemCount,
    covers: const <String>[],
  );
}

FoldersState _foldersState({List<FolderEntity> folders = const <FolderEntity>[]}) =>
    FoldersState(status: LoadStatus.success, userId: 'u1', folders: folders);

Future<void> _pump(
  WidgetTester tester, {
  required FoldersState folders,
  Size size = const Size(800, 1800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _MockFoldersBloc foldersBloc = _MockFoldersBloc();
  when(() => foldersBloc.state).thenReturn(folders);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: kLightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: BlocProvider<FoldersBloc>.value(value: foldersBloc, child: const IosShortcutsGuideScreen()),
    ),
  );
  // The rotation folder is read from SharedPreferences, which resolves outside the fake clock.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

AppLocalizations _l10n(WidgetTester tester) => tester.element(find.byType(IosShortcutsGuideScreen)).l10n;

void main() {
  late UrlLauncherPlatform original;

  setUp(() {
    original = UrlLauncherPlatform.instance;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    app_state.prismUser = profileUser();
  });

  tearDown(() {
    UrlLauncherPlatform.instance = original;
    iosShortcutLinkOverride = null;
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  testWidgets('with a Remote Config link, step 1 opens that link and hides the manual steps', (tester) async {
    iosShortcutLinkOverride = 'https://www.icloud.com/shortcuts/abc';
    final launcher = _RecordingUrlLauncher(opens: true);
    UrlLauncherPlatform.instance = launcher;
    await _pump(tester, folders: _foldersState());
    final AppLocalizations l10n = _l10n(tester);

    expect(find.text(l10n.shortcutsStepAddAction), findsOneWidget);
    for (final String line in shortcutsManualSteps(l10n)) {
      expect(find.text(line), findsNothing);
    }

    await tester.tap(find.text(l10n.shortcutsStepAddAction));
    await tester.pump();

    expect(launcher.urls, <String>['https://www.icloud.com/shortcuts/abc']);
  });

  testWidgets('without a Remote Config link, step 1 lists the manual steps and opens Shortcuts', (tester) async {
    iosShortcutLinkOverride = '';
    final launcher = _RecordingUrlLauncher(opens: true);
    UrlLauncherPlatform.instance = launcher;
    await _pump(tester, folders: _foldersState());
    final AppLocalizations l10n = _l10n(tester);

    expect(find.text(l10n.shortcutsStepAddAction), findsNothing);
    for (final String line in shortcutsManualSteps(l10n)) {
      expect(find.text(line), findsOneWidget);
    }
    expect(find.text(l10n.wallpaperShortcutsOpenAction), findsOneWidget);

    await tester.tap(find.text(l10n.wallpaperShortcutsOpenAction));
    await tester.pump();

    expect(launcher.urls, <String>['shortcuts://']);
  });

  testWidgets('without a rotation folder, the card asks for one and offers no Stop', (tester) async {
    await _pump(tester, folders: _foldersState());
    final AppLocalizations l10n = _l10n(tester);

    expect(find.text(l10n.shortcutsRotationNone), findsOneWidget);
    expect(find.text(l10n.shortcutsRotationNoneBody), findsOneWidget);
    expect(find.text(l10n.shortcutsRotationPick), findsOneWidget);
    expect(find.text(l10n.shortcutsRotationStop), findsNothing);
  });

  testWidgets('with a rotation folder, the card shows it and Stop clears it', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'flutter.shortcuts.rotation_folder': 'f1'});
    await _pump(tester, folders: _foldersState(folders: <FolderEntity>[_folder('f1', 'Calm', itemCount: 3)]));
    final AppLocalizations l10n = _l10n(tester);

    expect(find.text('Calm'), findsOneWidget);
    expect(find.text(l10n.foldersItemCount(3)), findsOneWidget);
    expect(find.text(l10n.shortcutsRotationChange), findsOneWidget);
    expect(find.text(l10n.shortcutsRotationStop), findsOneWidget);

    await tester.tap(find.text(l10n.shortcutsRotationStop));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(l10n.shortcutsRotationNone), findsOneWidget);
    expect(find.text(l10n.shortcutsRotationStop), findsNothing);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('shortcuts.rotation_folder'), isNull);
  });

  testWidgets('the test step opens the run-shortcut URL for Prism Wallpaper', (tester) async {
    final launcher = _RecordingUrlLauncher(opens: true);
    UrlLauncherPlatform.instance = launcher;
    await _pump(tester, folders: _foldersState());
    final AppLocalizations l10n = _l10n(tester);

    await tester.tap(find.text(l10n.shortcutsStepTestAction));
    await tester.pump();

    expect(launcher.urls, <String>[iosRunShortcutUri().toString()]);
    expect(launcher.urls, <String>['shortcuts://run-shortcut?name=Prism%20Wallpaper']);
  });

  testWidgets('all three step titles and the automation lines show', (tester) async {
    await _pump(tester, folders: _foldersState());
    final AppLocalizations l10n = _l10n(tester);

    expect(find.text(l10n.shortcutsStepAddTitle), findsOneWidget);
    expect(find.text(l10n.shortcutsStepAutomationTitle), findsOneWidget);
    expect(find.text(l10n.shortcutsStepTestTitle), findsOneWidget);
    for (final String line in shortcutsAutomationSteps(l10n)) {
      expect(find.text(line), findsOneWidget);
    }
  });
}
