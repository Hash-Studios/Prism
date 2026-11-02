import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/wall_comments/biz/wall_comments_cubit.dart';
import 'package:Prism/features/wall_comments/data/wall_comments_repository.dart';
import 'package:Prism/features/wall_comments/domain/wall_comment.dart';
import 'package:Prism/features/wall_comments/views/wall_comments_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';
import 'fake_wall_comments_repository.dart';

const CommentsWall _wall = (wallId: 'w1', statsId: 'NEON', creatorUid: 'maker');

const CommentViewer _me = (uid: 'me', name: 'Me', photo: '');

late AppLocalizations l10n;

Widget _app({required WallCommentsCubit cubit, TextScaler scaler = TextScaler.noScaling}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: scaler),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (BuildContext context) => TextButton(
        onPressed: () => showWallCommentsSheet(context, _wall, cubit: cubit),
        child: const Text('open'),
      ),
    ),
  ),
);

/// A phone-sized view, so the sheet has room. Reset after each test.
void _phoneView(WidgetTester tester) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps frames by hand. The sheet can show a spinner that never settles, so pumpAndSettle would hang.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<WallCommentsCubit> _openSheet(
  WidgetTester tester,
  FakeWallCommentsRepository repo, {
  CommentViewer? viewer = _me,
  BlockedCreators? blocked,
  TextScaler scaler = TextScaler.noScaling,
}) async {
  _phoneView(tester);
  final WallCommentsCubit cubit = WallCommentsCubit(
    wallId: _wall.wallId,
    repository: repo,
    viewer: viewer,
    initialBlocked: blocked ?? KnownBlockedCreators(const <String>{}),
    newRequestId: () => 'req-1',
  );
  await tester.pumpWidget(_app(cubit: cubit, scaler: scaler));
  await tester.tap(find.text('open'));
  await _settle(tester);
  return cubit;
}

Finder _sendButton() => find.ancestor(of: find.byTooltip(l10n.commentSend), matching: find.byType(PrismIconButton));

bool _sendEnabled(WidgetTester tester) => tester.widget<PrismIconButton>(_sendButton()).onPressed != null;

void main() {
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    PrismDeviceCornerRadius.setValueForTesting(48);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = profileUser(id: 'me');
    getIt.registerSingleton<FavouriteCountsCubit>(
      FavouriteCountsCubit(FakeFavouriteCountsRepository()),
      dispose: (FavouriteCountsCubit cubit) => cubit.close(),
    );
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  group('states', () {
    testWidgets('an empty wall shows the empty state', (tester) async {
      await _openSheet(tester, FakeWallCommentsRepository());

      expect(find.text(l10n.commentsEmptyTitle), findsOneWidget);
    });

    testWidgets('loaded comments show names and texts, and the creator label only on the creator comment', (
      tester,
    ) async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(<WallComment>[
          commentFor('c1', uid: 'maker', name: 'Mia', text: 'Love the grain'),
          commentFor('c2', text: 'Dark one'),
        ]);
      await _openSheet(tester, repo);

      expect(find.text('Mia'), findsOneWidget);
      expect(find.text('Love the grain'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Dark one'), findsOneWidget);
      expect(find.text(l10n.commentCreatorLabel), findsOneWidget);
      final Finder creatorRow = find.ancestor(
        of: find.text(l10n.commentCreatorLabel),
        matching: find.byType(CommentRow),
      );
      expect(find.descendant(of: creatorRow, matching: find.text('Mia')), findsOneWidget);
    });

    testWidgets('a failed load shows the error and retry calls fetchPage again', (tester) async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository();
      int calls = 0;
      repo.onFetch = (String wallId, String? afterId) async {
        calls++;
        if (calls == 1) throw StateError('offline');
        return pageOf(<WallComment>[commentFor('c1', name: 'Ana', text: 'Back again')]);
      };
      await _openSheet(tester, repo);

      expect(find.text(l10n.commentsLoadFailed), findsOneWidget);
      // At the medium detent the retry button sits below the screen edge, so the user expands the sheet first.
      await tester.drag(find.text(l10n.commentsTitle), const Offset(0, -400));
      await _settle(tester);
      expect(tester.getRect(find.text(l10n.commentsRetry)).bottom, lessThanOrEqualTo(844));
      await tester.tap(find.text(l10n.commentsRetry));
      await _settle(tester);

      expect(repo.fetchAfterIds, hasLength(2));
      expect(find.text('Back again'), findsOneWidget);
    });

    testWidgets('scrolling to the end of a full page requests the next page after the last id', (tester) async {
      final List<WallComment> first = List<WallComment>.generate(
        WallCommentsRepository.pageSize,
        (int i) => commentFor('c${i + 1}', text: 'Text ${i + 1}'),
      );
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async =>
            afterId == null ? pageOf(first) : pageOf(<WallComment>[commentFor('c21', text: 'Next page')]);
      await _openSheet(tester, repo);

      await tester.drag(find.text('Text 1'), const Offset(0, -5000));
      await _settle(tester);

      expect(repo.fetchAfterIds, <String?>[null, 'c20']);
      expect(find.text('Next page'), findsOneWidget);
    });

    testWidgets('a comment by a blocked user is not rendered', (tester) async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(<WallComment>[
          commentFor('c1', uid: 'bad', text: 'Blocked text'),
          commentFor('c2', text: 'Visible text'),
        ]);
      await _openSheet(tester, repo, blocked: KnownBlockedCreators(const <String>{'bad'}));

      expect(find.text('Blocked text'), findsNothing);
      expect(find.text('Visible text'), findsOneWidget);
    });
  });

  group('composer', () {
    testWidgets('Send is disabled for empty text', (tester) async {
      await _openSheet(tester, FakeWallCommentsRepository());

      expect(_sendEnabled(tester), isFalse);
    });

    testWidgets('451 characters shows 49 left and Send is enabled', (tester) async {
      await _openSheet(tester, FakeWallCommentsRepository());

      await tester.enterText(find.byType(TextField), 'a' * 451);
      await _settle(tester);

      expect(find.text(l10n.commentCharactersLeft(49)), findsOneWidget);
      expect(_sendEnabled(tester), isTrue);
    });

    testWidgets('501 characters shows 1 too many and Send is disabled', (tester) async {
      await _openSheet(tester, FakeWallCommentsRepository());

      await tester.enterText(find.byType(TextField), 'a' * 501);
      await _settle(tester);

      expect(find.text(l10n.commentCharactersOver(1)), findsOneWidget);
      expect(_sendEnabled(tester), isFalse);
    });

    testWidgets('Send is disabled while a send is in flight', (tester) async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository();
      await _openSheet(tester, repo);

      await tester.enterText(find.byType(TextField), 'First');
      await _settle(tester);
      await tester.tap(_sendButton());
      await _settle(tester);
      expect(repo.adds, hasLength(1));

      await tester.enterText(find.byType(TextField), 'Second');
      await _settle(tester);
      expect(_sendEnabled(tester), isFalse);

      repo.adds.single.result.complete(commentFor('srv1', uid: 'me', name: 'Me', text: 'First'));
      await _settle(tester);
      expect(_sendEnabled(tester), isTrue);
    });

    testWidgets('a send shows the comment before the server answers', (tester) async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository();
      await _openSheet(tester, repo);

      await tester.enterText(find.byType(TextField), 'Nice wall');
      await _settle(tester);
      await tester.tap(_sendButton());
      await _settle(tester);

      expect(repo.adds, hasLength(1));
      expect(find.text('Nice wall'), findsOneWidget);
    });

    testWidgets('a too-fast refusal removes the row, keeps the text and shows the reason', (tester) async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository();
      await _openSheet(tester, repo);

      await tester.enterText(find.byType(TextField), 'Nice wall');
      await _settle(tester);
      await tester.tap(_sendButton());
      await _settle(tester);
      expect(find.text('Nice wall'), findsOneWidget);

      repo.adds.single.result.completeError(const CommentRefusedException(CommentRefusal.tooFast));
      await _settle(tester);

      expect(find.byType(CommentRow), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Nice wall');
      expect(find.text(l10n.commentErrorTooFast), findsOneWidget);
    });

    test('each refusal maps to its own non-empty message', () {
      final List<String> messages = CommentRefusal.values
          .map((CommentRefusal r) => commentRefusalMessage(r, l10n))
          .toList();

      expect(messages.every((String m) => m.trim().isNotEmpty), isTrue);
      expect(messages.toSet(), hasLength(CommentRefusal.values.length));
    });

    testWidgets('a guest reads the comments and sees a sign-in button, not a text field', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async =>
            pageOf(<WallComment>[commentFor('c1', text: 'Guest can read')]);
      await _openSheet(tester, repo, viewer: null);

      expect(find.text('Guest can read'), findsOneWidget);
      expect(find.text(l10n.commentSignInToComment), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  testWidgets('signing in in the open sheet can post a comment', (tester) async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    final previous = signedInActionSignIn;
    addTearDown(() => signedInActionSignIn = previous);
    signedInActionSignIn = (_) async {
      app_state.prismUser = profileUser(id: 'me');
      return true;
    };
    final FakeWallCommentsRepository repo = FakeWallCommentsRepository();
    await _openSheet(tester, repo, viewer: null);
    await tester.tap(find.text(l10n.commentSignInToComment));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'After sign in');
    await _settle(tester);
    await tester.tap(_sendButton());
    await _settle(tester);
    expect(repo.adds, hasLength(1));
    expect(find.text('After sign in'), findsOneWidget);
  });

  testWidgets('a fully blocked first page still exposes paging', (tester) async {
    final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
      ..onFetch = (_, String? afterId) async => afterId == null
          ? pageOf(List<WallComment>.generate(20, (i) => commentFor('bad$i', uid: 'bad')))
          : pageOf(<WallComment>[commentFor('good', text: 'Beyond blocked page')]);
    await _openSheet(tester, repo, blocked: KnownBlockedCreators(const <String>{'bad'}));
    expect(find.text(l10n.commentsRetry), findsOneWidget);
    await tester.drag(find.text(l10n.commentsTitle), const Offset(0, -400));
    await _settle(tester);
    await tester.tap(find.text(l10n.commentsRetry));
    await _settle(tester);
    expect(find.text('Beyond blocked page'), findsOneWidget);
  });

  group('long-press menu', () {
    Future<void> longPressComment(WidgetTester tester, String text) async {
      await tester.longPress(find.text(text));
      await _settle(tester);
    }

    testWidgets('a stranger can report and block but not delete', (tester) async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(<WallComment>[commentFor('c1', text: 'Bob text')]);
      await _openSheet(tester, repo);

      await longPressComment(tester, 'Bob text');

      expect(find.text(l10n.commentReport), findsOneWidget);
      expect(find.text(l10n.commentBlockUser('Bob')), findsOneWidget);
      expect(find.text(l10n.commentDelete), findsNothing);
    });

    testWidgets('the author can delete but not report or block', (tester) async {
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async =>
            pageOf(<WallComment>[commentFor('c1', uid: 'me', name: 'Me', text: 'My text')]);
      await _openSheet(tester, repo);

      await longPressComment(tester, 'My text');

      expect(find.text(l10n.commentDelete), findsOneWidget);
      expect(find.text(l10n.commentReport), findsNothing);
      expect(find.text(l10n.commentBlockUser('Me')), findsNothing);
    });

    testWidgets('the wall creator can report, block and delete', (tester) async {
      app_state.prismUser = profileUser(id: 'maker');
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(<WallComment>[commentFor('c1', text: 'Bob text')]);
      await _openSheet(tester, repo, viewer: (uid: 'maker', name: 'Maker', photo: ''));

      await longPressComment(tester, 'Bob text');

      expect(find.text(l10n.commentReport), findsOneWidget);
      expect(find.text(l10n.commentBlockUser('Bob')), findsOneWidget);
      expect(find.text(l10n.commentDelete), findsOneWidget);
    });

    testWidgets('an admin sees delete on someone else comment', (tester) async {
      app_state.prismUser = profileUser(id: 'admin');
      app_state.prismUser.email = app_constants.adminEmails.first;
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(<WallComment>[commentFor('c1', text: 'Bob text')]);
      await _openSheet(tester, repo, viewer: (uid: 'admin', name: 'Admin', photo: ''));

      await longPressComment(tester, 'Bob text');

      expect(find.text(l10n.commentDelete), findsOneWidget);
    });

    testWidgets('a guest long-pressing sees only report', (tester) async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
        ..onFetch = (String wallId, String? afterId) async => pageOf(<WallComment>[commentFor('c1', text: 'Bob text')]);
      await _openSheet(tester, repo, viewer: null);

      await longPressComment(tester, 'Bob text');

      expect(find.text(l10n.commentReport), findsOneWidget);
      expect(find.text(l10n.commentBlockUser('Bob')), findsNothing);
      expect(find.text(l10n.commentDelete), findsNothing);
    });
  });

  testWidgets('large text with long names and comments renders without an exception', (tester) async {
    final FakeWallCommentsRepository repo = FakeWallCommentsRepository()
      ..onFetch = (String wallId, String? afterId) async => pageOf(<WallComment>[
        commentFor('c1', name: 'Alexandra Montgomery-Featherstonehaugh of Wallingford-upon-Thames', text: 'word ' * 80),
      ]);
    await _openSheet(tester, repo, scaler: const TextScaler.linear(2.0));

    expect(tester.takeException(), isNull);
    expect(find.byType(CommentRow), findsOneWidget);
  });

  testWidgets('the composer stays above the keyboard', (tester) async {
    addTearDown(tester.view.resetViewInsets);
    await _openSheet(tester, FakeWallCommentsRepository());

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.tap(find.byType(TextField));
    await _settle(tester);

    final double screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final double insetHeight = 300 / tester.view.devicePixelRatio;
    final Rect field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(screenHeight - insetHeight));
    expect(tester.takeException(), isNull);
  });
}
