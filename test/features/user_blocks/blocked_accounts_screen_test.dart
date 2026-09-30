import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
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
      toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
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
    expect(find.text('People you block cannot see your profile or wallpapers.'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that loads again', (tester) async {
    final repo = await pumpScreen(tester, Result.error(const ServerFailure('down')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load blocked accounts'), findsOneWidget);
    repo.result = Result.success(const <BlockedUserListRow>[]);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('No blocked accounts'), findsOneWidget);
  });

  testWidgets('unblocking asks first, then removes the row', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Unblock sam_k?'), findsOneWidget);
    expect(repo.unblocked, isEmpty);

    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Unblock')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.unblocked, <String>['u9']);
    expect(toasts, contains('Unblocked'));
    expect(find.text('No blocked accounts'), findsOneWidget);
  });

  testWidgets('the blocked profile shell names the user and unblocks', (tester) async {
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

    expect(repo.unblocked, <String>['u9']);
  });
}
