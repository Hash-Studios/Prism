import 'dart:io';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/features/wallpaper_upload/biz/resubmission_cubit.dart';
import 'package:Prism/features/wallpaper_upload/biz/resubmission_seed.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/data/resubmission_repository.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/resubmit_wall_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Firestore extends Mock implements FirestoreClient {
  _Firestore(this.data);
  final Map<String, dynamic>? data;
  String? collection;
  String? tag;

  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async {
    this.collection = collection;
    tag = sourceTag;
    return data == null ? null : map(data!, id);
  }
}

class _Cubit extends MockCubit<ResubmissionState> implements ResubmissionCubit {}

void main() {
  const seed = ResubmissionSeed(
    rejectedDocId: 'rejected-1',
    previousReason: 'Please remove the border',
    metadata: SubmissionMetadata(title: 'Dunes', description: 'At sunset', category: 'Nature', tags: ['sand']),
  );

  test('owner gets metadata and a missing-image fallback when original URL is empty', () async {
    final client = _Firestore({
      'creatorUid': 'owner',
      'email': 'other@example.com',
      'wallpaper_url': '',
      'title': 'Dunes',
      'desc': 'At sunset',
      'category': 'Nature',
      'tags': ['sand', 2],
      'rejectionReason': 'Please remove the border',
    });
    final result = await ResubmissionRepository(client).prepare('rejected-1', uid: 'owner', email: 'owner@example.com');
    expect(client.collection, FirebaseCollections.rejectedWalls);
    expect(client.tag, 'upload.resubmit.prepare');
    expect(result.original, isNull);
    expect(result.unsupportedSource, isFalse);
    expect(result.seed.previousReason, 'Please remove the border');
    expect(result.seed.metadata.title, 'Dunes');
    expect(result.seed.metadata.description, 'At sunset');
    expect(result.seed.metadata.category, 'Nature');
    expect(result.seed.metadata.tags, ['sand']);
  });

  for (final source in [
    <String, dynamic>{'isAiGenerated': true},
    <String, dynamic>{'origin': 'studio'},
  ]) {
    test('unsupported source $source asks for a replacement image', () async {
      final client = _Firestore({
        'email': 'owner@example.com',
        'wallpaper_url': 'https://example.test/image',
        ...source,
      });
      final result = await ResubmissionRepository(
        client,
      ).prepare('rejected-1', uid: 'owner', email: 'owner@example.com');
      expect(result.unsupportedSource, isTrue);
      expect(result.original, isNull);
    });
  }

  test('a different owner cannot prepare a rejected upload even with matching email', () async {
    final client = _Firestore({'creatorUid': 'someone-else', 'email': 'owner@example.com'});
    await expectLater(
      ResubmissionRepository(client).prepare('rejected-1', uid: 'owner', email: 'owner@example.com'),
      throwsStateError,
    );
  });

  for (final hasImage in [true, false]) {
    testWidgets('resubmit displays prior feedback and details with image ${hasImage ? 'kept' : 'missing'}', (
      tester,
    ) async {
      final cubit = _Cubit();
      when(() => cubit.state).thenReturn(
        ResubmissionState(
          loading: false,
          preparation: ResubmissionPreparation(seed: seed, original: hasImage ? File('/tmp/original.jpg') : null),
        ),
      );
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResubmitWallScreen(rejectedDocId: 'rejected-1', cubit: cubit),
        ),
      );
      expect(find.text('Please remove the border'), findsOneWidget);
      expect(
        find.text(
          hasImage
              ? 'Original image ready'
              : 'The original image is no longer available. Choose it again to keep editing.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Title')).controller!.text, 'Dunes');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Description')).controller!.text, 'At sunset');
      expect(find.widgetWithText(InputChip, 'sand'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Nature')).selected, isTrue);
      expect(find.text('Save'), hasImage ? findsOneWidget : findsNothing);
      expect(find.text('Choose image'), findsOneWidget);
    });
  }
}
