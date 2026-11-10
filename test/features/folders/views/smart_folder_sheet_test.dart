import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/biz/smart_folder_builder_cubit.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/smart_rule.dart';
import 'package:Prism/features/folders/domain/repositories/smart_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/smart_folder_sheet.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';

const SmartRule _blue = SmartRule(SmartRuleKind.colour, 'blue');
const SmartRule _teal = SmartRule(SmartRuleKind.colour, 'teal');
final DateTime _at = DateTime.utc(2026, 10);

const String _thumb = 'https://img.prismwalls.com/previews/a.img';

List<SmartPreviewWall> _walls(int count) =>
    List<SmartPreviewWall>.generate(count, (i) => SmartPreviewWall(id: 'w$i', docId: 'd$i', thumb: _thumb));

class _FakeSmartRepo implements SmartFoldersRepository {
  int count = 3;
  bool more = false;
  List<SmartPreviewWall> walls = const <SmartPreviewWall>[];
  bool failPreview = false;
  int creates = 0;

  /// One entry per preview call, with the rules it got.
  final List<List<SmartRule>> previewCalls = <List<SmartRule>>[];

  /// One entry per updateRules call.
  final List<({String folderId, List<SmartRule> rules})> updates = <({String folderId, List<SmartRule> rules})>[];

  @override
  Future<Result<SmartPreview>> preview(List<SmartRule> rules) async {
    previewCalls.add(List<SmartRule>.of(rules));
    if (failPreview) return Result.error<SmartPreview>(const NetworkFailure('offline'));
    return Result.success<SmartPreview>(SmartPreview(count: count, more: more, walls: walls));
  }

  @override
  Future<Result<({String folderId, int count})>> create({required String name, required List<SmartRule> rules}) async {
    creates++;
    return Result.success<({String folderId, int count})>((folderId: 'new', count: count));
  }

  @override
  Future<Result<int>> updateRules(String folderId, List<SmartRule> rules) async {
    updates.add((folderId: folderId, rules: List<SmartRule>.of(rules)));
    return Result.success<int>(count);
  }
}

SmartFolderBuilderCubit _cubit(_FakeSmartRepo repo, {List<SmartRule> initial = const <SmartRule>[]}) {
  final SmartFolderBuilderCubit cubit = SmartFolderBuilderCubit(
    repo,
    initialRules: initial,
    debounce: Duration.zero,
    loadCreators: () async => const <UserSummaryEntity>[],
  );
  addTearDown(cubit.close);
  return cubit;
}

/// Fixed pumps, not pumpAndSettle: the skeleton and the switchers keep the frame busy.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapChip(WidgetTester tester, String key) async {
  final Finder chip = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(chip);
  await tester.pump();
  await tester.tap(chip);
}

/// The rule builder and the preview, in one scroll view, under the cubit.
Future<void> _pumpBody(WidgetTester tester, SmartFolderBuilderCubit cubit, {TextScaler? textScaler}) =>
    tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: BlocProvider<SmartFolderBuilderCubit>.value(
          value: cubit,
          child: Scaffold(
            body: SingleChildScrollView(
              child: BlocBuilder<SmartFolderBuilderCubit, SmartFolderBuilderState>(
                builder: (context, state) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SmartRuleBuilder(state: state),
                    SmartPreviewSection(state: state),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'me';
  });
  tearDown(() => app_state.prismUser = app_constants.createGuestPrismUser());
  tearDown(AnalyticsRuntime.reset);

  testWidgets('a sheet opened by another account cannot create a folder', (tester) async {
    final _FakeSmartRepo repo = _FakeSmartRepo();
    final SmartFolderBuilderCubit cubit = _cubit(repo, initial: const <SmartRule>[_blue]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => unawaited(
                  showPrismSheet<void>(
                    context,
                    builder: (_) =>
                        BlocProvider<SmartFolderBuilderCubit>.value(value: cubit, child: const SmartFolderSheet()),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, 'My smart folder');
    await tester.pump();
    app_state.prismUser = app_constants.createGuestPrismUser()..id = 'someoneElse';
    await tester.tap(find.byKey(const ValueKey<String>('smart-folder-save')));
    await _settle(tester);

    expect(repo.creates, 0);
  });

  testWidgets('the name field reads its label once', (tester) async {
    final SmartFolderBuilderCubit cubit = _cubit(_FakeSmartRepo());
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => unawaited(
                  showPrismSheet<void>(
                    context,
                    builder: (_) =>
                        BlocProvider<SmartFolderBuilderCubit>.value(value: cubit, child: const SmartFolderSheet()),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);

    final SemanticsNode field = tester.getSemantics(find.byType(TextField).first);
    final String spoken = '${field.label} ${field.hint}';
    expect(RegExp('Folder name').allMatches(spoken), hasLength(1));
    semantics.dispose();
  });

  testWidgets('an iOS-only mood picked on iOS stays as a removable chip on Android', (tester) async {
    final SmartFolderBuilderCubit cubit = _cubit(
      _FakeSmartRepo(),
      initial: const <SmartRule>[SmartRule(SmartRuleKind.mood, 'spatial_ready')],
    );
    await _pumpBody(tester, cubit);
    await _settle(tester);

    final Finder picked = find.byKey(const ValueKey<String>('smart-rule-mood-spatial_ready'));
    expect(tester.widget<PrismChip>(picked).selected, isTrue);
    expect(find.byKey(const ValueKey<String>('smart-rule-mood-depth_ready')), findsNothing);
    await tester.ensureVisible(picked);
    await tester.tap(picked);
    await _settle(tester);
    expect(cubit.state.rules, isEmpty);
  });

  testWidgets('on or off rule chips pass their icon to the chip, so a selected chip tints it', (tester) async {
    final SmartFolderBuilderCubit cubit = _cubit(
      _FakeSmartRepo(),
      initial: const <SmartRule>[SmartRule(SmartRuleKind.followed)],
    );
    await _pumpBody(tester, cubit);
    await _settle(tester);

    final PrismChip followed = tester.widget<PrismChip>(find.byKey(const ValueKey<String>('smart-rule-followed-')));
    expect(followed.selected, isTrue);
    expect(followed.icon, Icons.people_alt_rounded);
    expect(followed.leading, isNull);
  });

  testWidgets('a selected creator without a profile still has a removable rule chip', (tester) async {
    final SmartFolderBuilderCubit cubit = _cubit(
      _FakeSmartRepo(),
      initial: const <SmartRule>[SmartRule(SmartRuleKind.creator, 'missingCreator')],
    );
    await _pumpBody(tester, cubit);
    await _settle(tester);

    final Finder chip = find.byKey(const ValueKey<String>('smart-rule-creator-missingCreator'));
    expect(chip, findsOneWidget);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await _settle(tester);

    expect(cubit.state.rules, isEmpty);
  });

  testWidgets('tapping a colour chip selects it and shows its count, and tapping it again deselects it', (
    tester,
  ) async {
    final _FakeSmartRepo repo = _FakeSmartRepo()..count = 3;
    final SmartFolderBuilderCubit cubit = _cubit(repo);
    await _pumpBody(tester, cubit);
    await _settle(tester);

    expect(find.text('Pick a rule to see the wallpapers that match.'), findsOneWidget);

    await _tapChip(tester, 'smart-rule-colour-blue');
    await _settle(tester);

    expect(tester.widget<PrismChip>(find.byKey(const ValueKey<String>('smart-rule-colour-blue'))).selected, isTrue);
    expect(find.text('3 matches'), findsOneWidget);

    await _tapChip(tester, 'smart-rule-colour-blue');
    await _settle(tester);

    expect(tester.widget<PrismChip>(find.byKey(const ValueKey<String>('smart-rule-colour-blue'))).selected, isFalse);
    expect(find.text('Pick a rule to see the wallpapers that match.'), findsOneWidget);
  });

  testWidgets('a preview with walls shows the grid with one tile per wall, up to 12', (tester) async {
    final _FakeSmartRepo repo = _FakeSmartRepo()
      ..count = 12
      ..walls = _walls(12);
    await _pumpBody(tester, _cubit(repo, initial: const <SmartRule>[_blue]));
    await _settle(tester);

    final Finder grid = find.byKey(const ValueKey<String>('smart-preview-grid'));
    expect(grid, findsOneWidget);
    expect(find.descendant(of: grid, matching: find.byType(PrismWallTile)), findsNWidgets(12));
    expect(find.text('12 matches'), findsOneWidget);
  });

  testWidgets('more than the fill size shows the count with a plus', (tester) async {
    final _FakeSmartRepo repo = _FakeSmartRepo()
      ..count = 100
      ..more = true
      ..walls = _walls(12);
    await _pumpBody(tester, _cubit(repo, initial: const <SmartRule>[_blue]));
    await _settle(tester);

    expect(find.text('100+ matches'), findsOneWidget);
  });

  testWidgets('zero matches shows 0 matches and the hint to remove a rule or save anyway', (tester) async {
    final _FakeSmartRepo repo = _FakeSmartRepo()..count = 0;
    await _pumpBody(tester, _cubit(repo, initial: const <SmartRule>[_blue]));
    await _settle(tester);

    expect(find.text('0 matches'), findsOneWidget);
    expect(find.textContaining('No wallpaper matches all these rules yet.', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('smart-preview-empty')), findsOneWidget);
  });

  testWidgets('a failed preview shows the error, and Try again asks the repository again', (tester) async {
    final _FakeSmartRepo repo = _FakeSmartRepo()..failPreview = true;
    await _pumpBody(tester, _cubit(repo, initial: const <SmartRule>[_blue]));
    await _settle(tester);

    expect(find.text('Could not load the preview.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(repo.previewCalls, hasLength(1));

    await tester.ensureVisible(find.text('Try again'));
    await tester.pump();
    await tester.tap(find.text('Try again'));
    await _settle(tester);

    expect(repo.previewCalls, hasLength(2));
  });

  testWidgets('a fourth kind of rule shows the kind limit note', (tester) async {
    final _FakeSmartRepo repo = _FakeSmartRepo();
    final SmartFolderBuilderCubit cubit = _cubit(repo);
    await _pumpBody(tester, cubit);
    await _settle(tester);

    await _tapChip(tester, 'smart-rule-colour-blue');
    await _tapChip(tester, 'smart-rule-category-Nature');
    await _tapChip(tester, 'smart-rule-followed-');
    await _settle(tester);
    expect(find.text('You can use up to 3 kinds of rule.'), findsNothing);

    await _tapChip(tester, 'smart-rule-desktop-');
    await _settle(tester);

    expect(find.text('You can use up to 3 kinds of rule.'), findsOneWidget);
    expect(cubit.state.rules, hasLength(3));
  });

  testWidgets('the rule builder and preview keep their chips and do not overflow at 2x text on a 390 by 844 screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _FakeSmartRepo repo = _FakeSmartRepo()
      ..count = 3
      ..walls = _walls(3);
    await _pumpBody(tester, _cubit(repo, initial: const <SmartRule>[_blue]), textScaler: const TextScaler.linear(2.0));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey<String>('smart-rule-colour-blue')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('smart-rule-followed-')), findsOneWidget);
    expect(find.text('3 matches'), findsOneWidget);
  });

  testWidgets('edit rules keeps Save disabled until a rule changes, then saves the new rules', (tester) async {
    final _FakeSmartRepo repo = _FakeSmartRepo()..count = 3;
    final SmartFolderBuilderCubit cubit = _cubit(repo, initial: const <SmartRule>[_blue]);
    final FolderEntity folder = FolderEntity(
      id: 'f1',
      ownerId: 'me',
      name: 'Smart',
      createdAt: _at,
      updatedAt: _at,
      itemCount: 3,
      covers: const <String>[],
      smartRules: const <SmartRule>[_blue],
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kLightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => unawaited(
                  showPrismSheet<void>(
                    context,
                    builder: (_) => BlocProvider<SmartFolderBuilderCubit>.value(
                      value: cubit,
                      child: SmartFolderSheet(folder: folder),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);

    final Finder save = find.byKey(const ValueKey<String>('smart-folder-save'));
    expect(tester.widget<PrismButton>(save).onPressed, isNull);

    await _tapChip(tester, 'smart-rule-colour-teal');
    await _settle(tester);
    expect(tester.widget<PrismButton>(save).onPressed, isNotNull);

    await tester.ensureVisible(save);
    await tester.tap(save);
    await _settle(tester);

    expect(repo.updates, hasLength(1));
    expect(repo.updates.single.folderId, 'f1');
    expect(repo.updates.single.rules, <SmartRule>[_blue, _teal]);
  });
}
