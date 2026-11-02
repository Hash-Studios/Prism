import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/bloc/wall_metadata_history_cubit.dart';
import 'package:Prism/features/admin_review/views/pages/wall_metadata_history_page.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Cubit extends MockCubit<WallMetadataHistoryState> implements WallMetadataHistoryCubit {}

void main() {
  const audit = WallMetadataAudit(
    id: 'audit',
    before: {'title': 'Before title'},
    after: {
      'title': 'After title',
      'desc': '',
      'tags': ['blue'],
    },
    actorUid: 'creator',
    canRevert: true,
  );
  const ready = WallMetadataHistoryState(edits: [audit], loading: false);
  late _Cubit cubit;

  setUpAll(() => registerFallbackValue(audit));
  setUp(() {
    cubit = _Cubit();
    when(() => cubit.load(more: any(named: 'more'))).thenAnswer((_) async {});
    when(() => cubit.revert(any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, {WallMetadataHistoryState state = ready}) async {
    whenListen(cubit, const Stream<WallMetadataHistoryState>.empty(), initialState: state);
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallMetadataHistoryPage(wallDocId: 'doc', cubit: cubit),
      ),
    );
    await tester.pump();
  }

  testWidgets('history shows exact before and after values and only eligible revert controls', (tester) async {
    await pump(tester);
    expect(find.text('Before title'), findsOneWidget);
    expect(find.text('After title'), findsOneWidget);
    expect(find.text('blue'), findsOneWidget);
    final absent = AppLocalizations.of(tester.element(find.byType(WallMetadataHistoryPage))).wallMetadataAbsent;
    expect(find.text(absent), findsNWidgets(2));
    expect(find.byType(PrismButton), findsOneWidget);
  });

  testWidgets('revert requires confirmation and Cancel never calls the Cubit', (tester) async {
    await pump(tester);
    final button = find.byType(PrismButton);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
    verifyNever(() => cubit.revert(any()));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => cubit.revert(any()));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrismButton, 'Revert edit').last);
    await tester.pumpAndSettle();
    verify(() => cubit.revert(audit)).called(1);
  });

  testWidgets('conflict preserves diff and disables revert until an explicit reload', (tester) async {
    await pump(
      tester,
      state: const WallMetadataHistoryState(edits: [audit], loading: false, failure: WallMetadataFailure.conflict),
    );
    expect(find.text('Before title'), findsOneWidget);
    expect(tester.widget<PrismButton>(find.byType(PrismButton)).onPressed, isNull);
    await tester.tap(find.byTooltip('Reload details'));
    await tester.pump();
    verify(() => cubit.load()).called(2);
    verifyNever(() => cubit.revert(any()));
  });

  testWidgets('older audit has no revert control and next page uses the cursor action', (tester) async {
    await pump(
      tester,
      state: const WallMetadataHistoryState(
        edits: [WallMetadataAudit(id: 'old', before: {}, after: {}, actorUid: 'creator')],
        loading: false,
        cursor: 'next',
      ),
    );
    final button = find.byType(PrismButton);
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    verify(() => cubit.load(more: true)).called(1);
    verifyNever(() => cubit.revert(any()));
  });
}
