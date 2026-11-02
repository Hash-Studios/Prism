import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/widgets/report_cards.dart';
import 'package:Prism/features/wall_comments/data/wall_comments_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';

class _Client extends FakeFirestoreClient {
  @override
  Future<T?> getById<T>(
    String collection,
    String id,
    T Function(Map<String, dynamic>, String) map, {
    required String sourceTag,
    bool preferCacheFirst = false,
  }) async => map(<String, dynamic>{'authorName': 'Author', 'text': 'Comment $id'}, id);
}

class _Moderation extends AdminModerationRepository {
  _Moderation(super.client);
  final List<String> reviewed = <String>[];
  @override
  Future<void> markContentReportReviewed(String id, {String? resolution}) async => reviewed.add(id);
}

void main() {
  testWidgets('an in-flight moderation action reviews its original report after a card replacement', (tester) async {
    final _Client client = _Client();
    final Completer<Object?> result = Completer<Object?>();
    final _Moderation repo = _Moderation(client);
    getIt.registerSingleton<FirestoreClient>(client);
    getIt.registerSingleton<WallCommentsRepository>(WallCommentsRepository.withCaller(client, (_, _) => result.future));
    addTearDown(getIt.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (_) async => true,
    );
    Widget app(String id) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CommentReportCard(
          report: FirestoreDocument(id, const <String, dynamic>{}),
          wallId: 'wall',
          commentId: id,
          reason: '',
          reporterUid: 'reporter',
          timeStr: '',
          repository: repo,
        ),
      ),
    );
    await tester.pumpWidget(app('first'));
    await tester.pumpAndSettle();
    final AppLocalizations l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.adminKeepComment));
    await tester.pump();
    await tester.pumpWidget(app('second'));
    result.complete(<String, Object?>{'ok': true});
    await tester.pumpAndSettle();
    expect(repo.reviewed, <String>['first']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a reused report card loads the new target instead of showing the previous comment', (tester) async {
    final _Client client = _Client();
    getIt.registerSingleton<FirestoreClient>(client);
    addTearDown(getIt.reset);
    final AdminModerationRepository repo = AdminModerationRepository(client);
    Widget app(String id) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CommentReportCard(
          report: FirestoreDocument(id, const <String, dynamic>{}),
          wallId: 'wall',
          commentId: id,
          reason: '',
          reporterUid: 'reporter',
          timeStr: '',
          repository: repo,
        ),
      ),
    );
    await tester.pumpWidget(app('first'));
    await tester.pumpAndSettle();
    expect(find.text('Author: Comment first'), findsOneWidget);
    await tester.pumpWidget(app('second'));
    await tester.pumpAndSettle();
    expect(find.text('Author: Comment first'), findsNothing);
    expect(find.text('Author: Comment second'), findsOneWidget);
  });
}
