import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_upload/biz/bloc/wall_metadata_cubit.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/wall_metadata_editor.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Cubit extends MockCubit<WallMetadataState> implements WallMetadataCubit {}

void main() {
  const metadata = PendingWallMetadata(
    text: WallTextMetadata(title: 'Rain', description: 'Evening light'),
  );
  const snapshot = WallMetadataSnapshot(metadata: metadata, approved: true, revision: 'rev');
  const ready = WallMetadataState(
    status: WallMetadataStatus.ready,
    snapshot: snapshot,
    draft: metadata,
    formVersion: 1,
  );
  late _Cubit cubit;

  setUpAll(() => registerFallbackValue(metadata));

  setUp(() {
    cubit = _Cubit();
    when(() => cubit.load()).thenAnswer((_) async {});
    when(() => cubit.save()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, {WallMetadataState state = ready, bool approved = true}) async {
    whenListen(cubit, const Stream<WallMetadataState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: WallMetadataEditor(wall: const FirestoreDocument('doc', {}), approved: approved, cubit: cubit),
      ),
    );
    await tester.pump();
  }

  testWidgets('approved editor hides category and retains canonical description', (tester) async {
    await pump(tester);
    expect(find.text('Edit details'), findsOneWidget);
    expect(find.text('Evening light'), findsOneWidget);
    expect(find.text('Category'), findsNothing);
    expect(find.text('General'), findsNothing);
  });

  testWidgets('pending editor exposes category', (tester) async {
    await pump(tester, approved: false);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
  });

  testWidgets('Save flushes the tag that has not been submitted by the keyboard', (tester) async {
    await pump(tester);
    final tagField = find.byType(TextField).last;
    await tester.ensureVisible(tagField);
    await tester.enterText(tagField, 'blue');
    when(() => cubit.state).thenReturn(
      const WallMetadataState(
        status: WallMetadataStatus.ready,
        snapshot: snapshot,
        draft: PendingWallMetadata(
          text: WallTextMetadata(title: 'Rain', description: 'Evening light', tags: ['blue']),
        ),
        formVersion: 1,
      ),
    );
    await tester.tap(find.text('Save details'));
    await tester.pump();
    final changes = verify(() => cubit.change(captureAny())).captured.cast<PendingWallMetadata>();
    expect(changes.last.text.tags, ['blue']);
    verify(() => cubit.save()).called(1);
  });

  testWidgets('save failure preserves fields and exposes a reload action for conflict', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await pump(
        tester,
        state: const WallMetadataState(
          status: WallMetadataStatus.failure,
          snapshot: snapshot,
          draft: metadata,
          failure: WallMetadataFailure.conflict,
          formVersion: 1,
        ),
      );
      expect(find.text('Rain'), findsOneWidget);
      final reload = find.text('Reload details');
      await tester.scrollUntilVisible(reload, 200, scrollable: find.byType(Scrollable).first);
      expect(reload, findsOneWidget);
      expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Save details')).onPressed, isNull);
      expect(find.bySemanticsLabel(RegExp('These details changed elsewhere')), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('busy editor disables all fields and repeated saves', (tester) async {
    await pump(
      tester,
      state: const WallMetadataState(
        status: WallMetadataStatus.saving,
        snapshot: snapshot,
        draft: metadata,
        formVersion: 1,
      ),
    );
    expect(tester.widgetList<TextField>(find.byType(TextField)).every((field) => field.enabled == false), isTrue);
    final button = tester.widget<PrismButton>(find.byType(PrismButton).last);
    expect(button.loading, isTrue);
    expect(button.onPressed, isNull);
  });

  testWidgets('Back asks before discarding unsaved details', (tester) async {
    await pump(
      tester,
      state: const WallMetadataState(
        status: WallMetadataStatus.ready,
        snapshot: snapshot,
        draft: PendingWallMetadata(text: WallTextMetadata(title: 'Unsaved')),
        formVersion: 1,
      ),
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Discard changes'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved'), findsOneWidget);
    verifyNever(() => cubit.save());
  });
}
