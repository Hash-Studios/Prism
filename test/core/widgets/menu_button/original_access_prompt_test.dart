import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/original_access_prompt.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/profile_user_fixture.dart';

void main() {
  setUp(() => app_state.prismUser = profileUser());
  tearDown(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
    CoinsService.instance.balanceNotifier.value = 0;
  });

  Future<void> mount(WidgetTester tester, VoidCallback Function(BuildContext) action) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: action(context), child: const Text('open')),
        ),
      ),
    ),
  );

  testWidgets('a priced original requires consent and returns the exact quote after confirmation', (tester) async {
    OriginalAccessQuote? result;
    await mount(
      tester,
      (context) => () async {
        result = await quoteOriginalWithConsent(
          context,
          url: 'https://original.test/w1',
          wallpaperId: 'w1',
          wallpaperSource: WallpaperSource.prism,
          action: OriginalAccessAction.download,
          label: 'Save original',
          quoteProvider: () async => const OriginalAccessQuote(5, 20),
        );
      },
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(result, isNull);
    expect(CoinsService.instance.balanceNotifier.value, 20);
    expect(find.text('Save original'), findsNWidgets(2));
    await tester.tap(find.text('Save original').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(result?.requiredCoins, 5);
    expect(result?.currentBalance, 20);
  });

  testWidgets('an account change during the quote cannot update balance or show the old owners consent', (
    tester,
  ) async {
    final reply = Completer<OriginalAccessQuote>();
    var completed = false;
    OriginalAccessQuote? result;
    CoinsService.instance.balanceNotifier.value = 99;
    await mount(
      tester,
      (context) => () async {
        result = await quoteOriginalWithConsent(
          context,
          url: 'https://original.test/w1',
          wallpaperId: 'w1',
          wallpaperSource: WallpaperSource.prism,
          action: OriginalAccessAction.download,
          label: 'Save original',
          quoteProvider: () => reply.future,
        );
        completed = true;
      },
    );
    await tester.tap(find.text('open'));
    app_state.prismUser = profileUser(id: 'other-user');
    reply.complete(const OriginalAccessQuote(5, 20));
    await tester.pump();

    expect(completed, isTrue);
    expect(result, isNull);
    expect(CoinsService.instance.balanceNotifier.value, 99);
    expect(find.text('Save original'), findsNothing);
  });

  testWidgets('dismissing consent returns no quote and leaves the balance unspent', (tester) async {
    var completed = false;
    OriginalAccessQuote? result;
    await mount(
      tester,
      (context) => () async {
        result = await quoteOriginalWithConsent(
          context,
          url: 'https://original.test/w1',
          wallpaperId: 'w1',
          wallpaperSource: WallpaperSource.prism,
          action: OriginalAccessAction.download,
          label: 'Save original',
          quoteProvider: () async => const OriginalAccessQuote(5, 20),
        );
        completed = true;
      },
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(completed, isTrue);
    expect(result, isNull);
    expect(CoinsService.instance.balanceNotifier.value, 20);
  });
}
