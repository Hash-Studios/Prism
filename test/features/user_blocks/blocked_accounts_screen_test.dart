import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_blocks/views/blocked_accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_user_block_repository.dart';

class _BlockedRepository extends FakeUserBlockRepository {
  _BlockedRepository(this.rows) : super.pending();

  List<BlockedUserListRow> rows;
  final List<String> unblocked = <String>[];

  @override
  Future<Result<List<BlockedUserListRow>>> fetchBlockedUsersList() async => Result.success(rows);

  @override
  Future<Result<void>> unblockUser({required String targetUserId}) async {
    unblocked.add(targetUserId);
    rows = rows.where((row) => row.blockedUid != targetUserId).toList();
    return Result.success(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _BlockedRepository repository;

  setUp(() async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (call) async => true);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    repository = _BlockedRepository(const <BlockedUserListRow>[
      BlockedUserListRow(blockedUid: 'u1', blockedEmail: 'secret@example.com', blockedUsername: 'maya'),
      BlockedUserListRow(blockedUid: 'u2', blockedEmail: 'hidden@example.com'),
    ]);
    await getIt.reset();
    getIt.registerSingleton<UserBlockRepository>(repository);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  testWidgets('rows show the username and never an email address', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BlockedAccountsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('maya'), findsOneWidget);
    expect(find.text('Blocked user'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('unblock asks first and cancel keeps the account blocked', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BlockedAccountsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unblock').first);
    await tester.pumpAndSettle();
    expect(find.text('Unblock maya?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.unblocked, isEmpty);
    expect(find.text('maya'), findsOneWidget);
  });

  testWidgets('confirming unblock removes the account and refreshes the list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BlockedAccountsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unblock').first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Unblock')));
    await tester.pumpAndSettle();

    expect(repository.unblocked, <String>['u1']);
    expect(find.text('maya'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });
}
