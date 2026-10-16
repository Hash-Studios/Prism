import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_blocks/views/blocked_accounts_screen.dart';
import 'package:Prism/features/user_blocks/views/blocked_user_profile_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_user_block_repository.dart';

class _RowsRepository extends FakeUserBlockRepository {
  _RowsRepository(this.result) : super.pending();

  Result<List<BlockedUserListRow>> result;
  final List<String> unblocked = <String>[];

  @override
  Future<Result<List<BlockedUserListRow>>> fetchBlockedUsersList() async => result;

  @override
  Future<Result<void>> unblockUser({required String targetUserId}) async {
    unblocked.add(targetUserId);
    result = Result.success(const <BlockedUserListRow>[]);
    return Result.success(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> toasts = <String>[];

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<_RowsRepository> pumpScreen(WidgetTester tester, Result<List<BlockedUserListRow>> result) async {
    final repo = _RowsRepository(result);
    getIt.registerSingleton<UserBlockRepository>(repo);
    await tester.pumpWidget(const MaterialApp(home: BlockedAccountsScreen()));
    return repo;
  }

  List<Object?> captureHaptics(WidgetTester tester) {
    final bool previousHapticsEnabled = PrismHaptics.enabled;
    PrismHaptics.enabled = true;
    addTearDown(() => PrismHaptics.enabled = previousHapticsEnabled);
    final List<Object?> played = <Object?>[];
    const MethodChannel haptics = MethodChannel('prism/haptics');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, (call) async {
      played.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(haptics, null));
    return played;
  }

  testWidgets('shows skeleton rows while loading', (tester) async {
    await pumpScreen(tester, Result.success(const <BlockedUserListRow>[]));

    expect(find.bySemanticsLabel('Loading'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('Loading'), findsNothing);
  });

  testWidgets('empty state explains what blocking does', (tester) async {
    await pumpScreen(tester, Result.success(const <BlockedUserListRow>[]));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Blocked accounts'), findsOneWidget);
    expect(find.text('No blocked accounts'), findsOneWidget);
    expect(find.textContaining('Blocking hides their posts from your feed.'), findsOneWidget);
  });

  testWidgets('retry loads rows after a failure with one tap haptic', (tester) async {
    final List<Object?> played = captureHaptics(tester);
    final repo = await pumpScreen(tester, Result.error(const ServerFailure('down')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load blocked accounts'), findsOneWidget);
    repo.result = Result.success(const <BlockedUserListRow>[
      BlockedUserListRow(blockedUid: 'u2', blockedEmail: 'ignored@example.com', blockedUsername: 'refreshed'),
    ]);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(played, <Object?>['tap']);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('@refreshed'), findsOneWidget);
  });

  testWidgets('unblocking asks first, then removes the row', (tester) async {
    final List<Object?> played = captureHaptics(tester);
    final repo = await pumpScreen(
      tester,
      Result.success(const <BlockedUserListRow>[
        BlockedUserListRow(blockedUid: 'u9', blockedEmail: 'sam@example.com', blockedUsername: 'sam_k'),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('@sam_k'), findsOneWidget);
    expect(find.text('sam@example.com'), findsNothing);
    await tester.tap(find.text('Unblock'));
    await tester.pump();
    expect(played, <Object?>['tap']);
    played.clear();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Unblock sam_k?'), findsOneWidget);
    expect(find.textContaining('Their posts will appear in your feed again.'), findsOneWidget);
    expect(repo.unblocked, isEmpty);

    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Unblock')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.unblocked, <String>['u9']);
    expect(played, <Object?>['tap', 'success']);
    expect(toasts, contains('Unblocked'));
    expect(find.text('No blocked accounts'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('rows show the username and never an email address', (tester) async {
    await pumpScreen(
      tester,
      Result.success(const <BlockedUserListRow>[
        BlockedUserListRow(blockedUid: 'u1', blockedEmail: 'secret@example.com', blockedUsername: 'maya'),
        BlockedUserListRow(blockedUid: 'u2', blockedEmail: 'hidden@example.com'),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('@maya'), findsOneWidget);
    expect(find.text('Blocked user'), findsOneWidget);
    expect(find.textContaining('example.com'), findsNothing);
  });

  testWidgets('unblock asks first and cancel keeps the account blocked', (tester) async {
    final repo = await pumpScreen(
      tester,
      Result.success(const <BlockedUserListRow>[
        BlockedUserListRow(blockedUid: 'u1', blockedEmail: 'secret@example.com', blockedUsername: 'maya'),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Unblock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Unblock maya?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.unblocked, isEmpty);
    expect(find.text('@maya'), findsOneWidget);
  });

  testWidgets('the blocked profile shell names the user and unblocks', (tester) async {
    final List<Object?> played = captureHaptics(tester);
    final repo = _RowsRepository(Result.success(const <BlockedUserListRow>[]));
    getIt.registerSingleton<UserBlockRepository>(repo);
    await tester.pumpWidget(
      const MaterialApp(
        home: BlockedUserProfileShell(targetUserId: 'u9', targetEmail: 'sam@example.com', displayName: 'Sam K'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('You blocked Sam K'), findsOneWidget);
    await tester.tap(find.text('Unblock'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(played, <Object?>['tap', 'success']);
    expect(repo.unblocked, <String>['u9']);
    expect(toasts, contains('Unblocked'));
    await tester.pump(const Duration(seconds: 2));
  });
}
