import 'dart:async';

import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/admin_review/biz/bloc/wall_resubmission_context_cubit.dart';
import 'package:Prism/features/admin_review/views/widgets/wall_resubmission_notice.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/wall_metadata_actions.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Actions extends Mock implements WallMetadataActions {}

void main() {
  late _Actions actions;
  setUp(() => actions = _Actions());

  testWidgets('queue renders verified attempt and private prior reason from one lookup', (tester) async {
    when(
      () => actions.contexts(any()),
    ).thenAnswer((_) async => {'doc': const WallResubmissionContext(attempt: 2, previousReason: 'Wrong crop')});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WallResubmissionScope(
            walls: const [
              FirestoreDocument('doc', {'resubmitOf': 'raw-parent'}),
              FirestoreDocument('other', {}),
            ],
            actions: actions,
            child: const WallResubmissionNotice(wallDocId: 'doc'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Resubmitted · attempt 2 of 3'), findsOneWidget);
    expect(find.text('Wrong crop'), findsOneWidget);
    verify(() => actions.contexts(['doc', 'other'])).called(1);
  });

  testWidgets('a forged pointer and failed lookup never render a verified badge or raw reason', (tester) async {
    when(() => actions.contexts(any())).thenThrow(StateError('offline'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: WallResubmissionScope(
            walls: const [
              FirestoreDocument('doc', {'resubmitOf': 'forged', 'previousReason': 'Client reason'}),
            ],
            actions: actions,
            child: const WallResubmissionNotice(wallDocId: 'doc'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Resubmission details unavailable'), findsOneWidget);
    expect(find.textContaining('attempt'), findsNothing);
    expect(find.text('Client reason'), findsNothing);
  });

  test('an older context response cannot restore a badge for a refreshed queue', () async {
    final first = Completer<Map<String, WallResubmissionContext>>();
    var calls = 0;
    when(() => actions.contexts(any())).thenAnswer((_) async {
      calls++;
      if (calls == 1) return first.future;
      return {};
    });
    final cubit = WallResubmissionContextCubit(actions);
    addTearDown(cubit.close);
    final old = cubit.load(['old']);
    await cubit.load(['new']);
    first.complete({'old': const WallResubmissionContext(attempt: 1, previousReason: 'Old')});
    await old;
    expect(cubit.state.contexts, isEmpty);
    expect(cubit.state.failed, isFalse);
  });
}
