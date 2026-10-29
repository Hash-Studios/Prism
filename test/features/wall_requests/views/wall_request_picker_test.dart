import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/domain/repositories/wall_requests_repository.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_picker_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements WallRequestsRepository {
  _FakeRepository({required this.top, required this.newest});

  final List<WallRequest> top;
  final List<WallRequest> newest;

  @override
  Future<List<WallRequest>> list(WallRequestTab tab) async => switch (tab) {
    WallRequestTab.top => top,
    WallRequestTab.newest => newest,
    WallRequestTab.filled => const <WallRequest>[],
  };

  @override
  Future<CreateWallRequestResult> create({required String text, required List<String> tags, bool force = false}) =>
      throw UnimplementedError();

  @override
  Future<int> setVote(String requestId, {required bool vote}) => throw UnimplementedError();

  @override
  Future<void> setHidden(String requestId, {required bool hidden}) => throw UnimplementedError();
}

WallRequest _request(
  String id,
  String text, {
  int votes = 1,
  WallRequestStatus status = WallRequestStatus.open,
  bool hidden = false,
}) => WallRequest(
  id: id,
  text: text,
  tags: const <String>[],
  voteCount: votes,
  status: status,
  createdAt: DateTime(2026, 10, 28),
  requesterName: '',
  requesterPhoto: '',
  mine: false,
  voted: false,
  hidden: hidden,
);

void main() {
  final WallRequest mountains = _request('a', 'dark minimal mountains', votes: 9);
  final WallRequest shared = _request('b', 'neon city rain', votes: 3);
  final WallRequest forest = _request('c', 'quiet forest lake');

  late _FakeRepository repository;

  setUp(() {
    repository = _FakeRepository(top: <WallRequest>[mountains, shared], newest: <WallRequest>[shared, forest]);
    getIt.registerSingleton<WallRequestsRepository>(repository);
  });

  tearDown(() async {
    await getIt.reset();
  });

  /// Opens the picker from a button, as the upload flow does. [picked] receives what the sheet returns.
  Future<void> openPicker(
    WidgetTester tester,
    void Function(WallRequest?) picked, {
    GlobalKey<NavigatorState>? nestedNavigator,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Widget launcher = Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () {
              showWallRequestPicker(context).then(picked);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: nestedNavigator == null
            ? launcher
            : Navigator(
                key: nestedNavigator,
                onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => launcher),
              ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('lists the Top and New requests once each, Top first', (tester) async {
    await openPicker(tester, (_) {});

    expect(find.byType(PrismRow), findsNWidgets(3));
    expect(find.text('neon city rain'), findsOneWidget);
    expect(find.text('dark minimal mountains'), findsOneWidget);
    expect(find.text('quiet forest lake'), findsOneWidget);
  });

  testWidgets('the search field filters by text, ignoring case', (tester) async {
    await openPicker(tester, (_) {});

    await tester.enterText(find.byType(TextField), 'FOREST');
    await tester.pump();

    expect(find.byType(PrismRow), findsOneWidget);
    expect(find.text('quiet forest lake'), findsOneWidget);
    expect(find.text('neon city rain'), findsNothing);
  });

  testWidgets('does not offer hidden or filled requests to uploaders', (tester) async {
    repository = _FakeRepository(
      top: <WallRequest>[
        mountains,
        _request('hidden', 'hidden wall', hidden: true),
        _request('filled', 'filled wall', status: WallRequestStatus.filled),
      ],
      newest: const <WallRequest>[],
    );
    await getIt.reset();
    getIt.registerSingleton<WallRequestsRepository>(repository);
    await openPicker(tester, (_) {});

    expect(find.text('dark minimal mountains'), findsOneWidget);
    expect(find.text('hidden wall'), findsNothing);
    expect(find.text('filled wall'), findsNothing);
  });

  testWidgets('tapping a row pops with that request', (tester) async {
    final GlobalKey<NavigatorState> nested = GlobalKey<NavigatorState>();
    WallRequest? picked;
    await openPicker(tester, (WallRequest? value) => picked = value, nestedNavigator: nested);
    final NavigatorState root = Navigator.of(tester.element(find.byType(WallRequestPickerBody)), rootNavigator: true);
    expect(root.canPop(), isTrue);
    expect(nested.currentState!.canPop(), isFalse);

    await tester.tap(find.text('quiet forest lake'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(picked?.id, 'c');
    expect(root.canPop(), isFalse);
    expect(nested.currentState!.canPop(), isFalse);
    expect(find.text('open'), findsOneWidget);
  });
}
