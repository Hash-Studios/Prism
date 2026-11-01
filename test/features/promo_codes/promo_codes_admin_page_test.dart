import 'package:Prism/features/promo_codes/data/promo_code_repository.dart';
import 'package:Prism/features/promo_codes/views/promo_codes_admin_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCallable {
  _FakeCallable({List<Map<String, Object?>>? codes, this.failFirstList = false})
    : codes = codes ?? <Map<String, Object?>>[];

  final List<Map<String, Object?>> codes;
  final bool failFirstList;
  final List<(String, Map<String, Object?>)> calls = <(String, Map<String, Object?>)>[];
  int listCalls = 0;

  Future<Object?> call(String name, Map<String, Object?> data) async {
    calls.add((name, data));
    switch (name) {
      case 'listPromoCodes':
        listCalls++;
        if (failFirstList && listCalls == 1) throw StateError('offline');
        return <String, Object?>{'codes': codes};
      case 'createPromoCode':
        return <String, Object?>{'code': 'NEWCODE234'};
      case 'setPromoCodeDisabled':
        return <String, Object?>{'ok': true};
    }
    throw StateError('Unexpected callable $name');
  }

  Map<String, Object?> dataFor(String name) => calls.lastWhere((c) => c.$1 == name).$2;
}

Map<String, Object?> _code({String code = 'ABCDEFGH23', bool disabled = false}) => <String, Object?>{
  'code': code,
  'label': '',
  'reward': <String, Object?>{'type': 'coins', 'coins': 100},
  'maxRedemptions': 10,
  'redemptionCount': 3,
  'expiresAtMs': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
  'minAccountAgeDays': 0,
  'newUsersOnlyDays': null,
  'disabled': disabled,
};

void main() {
  Widget app(PromoCodeRepository repository) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (BuildContext context, Widget? child) =>
        MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
    home: PromoCodesAdminPage(repository: repository),
  );

  Future<void> pumpPage(WidgetTester tester, _FakeCallable fake) async {
    // Tall enough that the create form and the first code rows are all built and hit-testable.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(app(PromoCodeRepository(call: fake.call)));
    await tester.pumpAndSettle();
    toasts.overlayResolver = () => tester.state<OverlayState>(find.byType(Overlay).first);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, int index, String value) async {
    await tester.enterText(find.byType(TextField).at(index), value);
    await tester.pumpAndSettle();
  }

  // Field order in the create form: amount, max redemptions, expires, minimum age, custom code, note.
  const int amountField = 0;
  const int maxField = 1;

  tearDown(() => toasts.overlayResolver = null);

  testWidgets('shows loaded codes with their usage', (WidgetTester tester) async {
    final _FakeCallable fake = _FakeCallable(codes: <Map<String, Object?>>[_code()]);
    await pumpPage(tester, fake);

    expect(find.text('ABCDEFGH23'), findsOneWidget);
    expect(find.textContaining('3 of 10 used'), findsOneWidget);
    expect(find.textContaining('100 Coins'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no codes', (WidgetTester tester) async {
    await pumpPage(tester, _FakeCallable());

    expect(find.text('No codes yet.'), findsOneWidget);
  });

  testWidgets('shows the error state and retries the load', (WidgetTester tester) async {
    final _FakeCallable fake = _FakeCallable(codes: <Map<String, Object?>>[_code()], failFirstList: true);
    await pumpPage(tester, fake);

    expect(find.text("Couldn't load codes. Pull to try again."), findsOneWidget);
    expect(find.text('ABCDEFGH23'), findsNothing);

    await tapText(tester, 'Try again');

    expect(fake.listCalls, 2);
    expect(find.text('ABCDEFGH23'), findsOneWidget);
  });

  testWidgets('creates a coin code with the entered values', (WidgetTester tester) async {
    final _FakeCallable fake = _FakeCallable();
    await pumpPage(tester, fake);

    await enter(tester, amountField, '100');
    await enter(tester, maxField, '10');
    await tapText(tester, 'Create code');

    final Map<String, Object?> data = fake.dataFor('createPromoCode');
    expect(data['type'], 'coins');
    expect(data['amount'], 100);
    expect(data['maxRedemptions'], 10);
    expect(data.containsKey('code'), isFalse);
    final int expiresAtMs = data['expiresAtMs']! as int;
    final int sevenDaysAhead = DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
    expect((expiresAtMs - sevenDaysAhead).abs(), lessThan(60000));
  });

  testWidgets('Create code stays disabled until the amount is filled', (WidgetTester tester) async {
    final _FakeCallable fake = _FakeCallable();
    await pumpPage(tester, fake);

    await tapText(tester, 'Create code');
    expect(fake.calls.where((c) => c.$1 == 'createPromoCode'), isEmpty);

    await enter(tester, amountField, '0');
    await tapText(tester, 'Create code');
    expect(fake.calls.where((c) => c.$1 == 'createPromoCode'), isEmpty);
  });

  testWidgets('switching to Pro days sends premiumDays', (WidgetTester tester) async {
    final _FakeCallable fake = _FakeCallable();
    await pumpPage(tester, fake);

    await tapText(tester, 'Pro days');
    await enter(tester, amountField, '7');
    await tapText(tester, 'Create code');

    expect(fake.dataFor('createPromoCode')['type'], 'premiumDays');
    expect(fake.dataFor('createPromoCode')['amount'], 7);
  });

  testWidgets('New accounts only sends newUsersOnlyDays', (WidgetTester tester) async {
    final _FakeCallable fake = _FakeCallable();
    await pumpPage(tester, fake);

    await enter(tester, amountField, '50');
    await tester.ensureVisible(find.text('New accounts only'));
    await tester.tap(find.text('New accounts only'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Create code');

    expect(fake.dataFor('createPromoCode')['newUsersOnlyDays'], 7);
  });

  testWidgets('Turn off disables the code and reloads the list', (WidgetTester tester) async {
    final _FakeCallable fake = _FakeCallable(codes: <Map<String, Object?>>[_code()]);
    await pumpPage(tester, fake);

    await tapText(tester, 'Turn off');

    expect(fake.calls.where((c) => c.$1 == 'setPromoCodeDisabled').length, 1);
    expect(fake.dataFor('setPromoCodeDisabled'), <String, Object?>{'code': 'ABCDEFGH23', 'disabled': true});
    expect(fake.listCalls, 2);
  });
}
