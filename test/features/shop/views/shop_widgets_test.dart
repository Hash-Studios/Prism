import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/app_icon_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_app_icon_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/shop/biz/bloc/shop_bloc.j.dart';
import 'package:Prism/features/shop/shop.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_preview.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_tile.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/coins_test_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService coins = CoinsService.instance;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late List<String> calls;
  late List<MethodCall> toastCalls;

  setUp(() async {
    calls = <String>[];
    toastCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      toastCalls.add(call);
      return true;
    });
    await backend.install();
    backend.onCall = (String name, Map<String, dynamic> params) async {
      calls.add(name);
      return <String, Object?>{'success': true};
    };
    getIt.registerFactory<ShopBloc>(() => ShopBloc(getIt<SettingsLocalDataSource>()));
    coins.balanceNotifier.value = 500;
    coins.inventoryNotifier.value = Inventory.empty;
  });

  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    coins.xpNotifier.value = XpStatus.empty();
    coins.inventoryNotifier.value = Inventory.empty;
    EconomyConfig.resetForTest();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,

    theme: ThemeData.light(),
    home: Scaffold(body: child),
  );

  bool Function(Widget) isIconArt(String asset) => (Widget w) {
    if (w is! Image) return false;
    final ImageProvider<Object> provider = w.image is ResizeImage ? (w.image as ResizeImage).imageProvider : w.image;
    return provider is AssetImage && provider.assetName == asset;
  };

  group('ShopItemTile', () {
    Future<void> pumpTile(
      WidgetTester tester,
      String id, {
      bool owned = false,
      bool equipped = false,
      ShopAvailability availability = ShopAvailability.available,
    }) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 180,
            height: 210,
            child: ShopItemTile(
              item: shopItem(id)!,
              owned: owned,
              equipped: equipped,
              availability: availability,
              onTap: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('an unowned item shows its price and no tag', (tester) async {
      await pumpTile(tester, 'theme_rose');

      expect(find.text('Rose'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('Owned'), findsNothing);
    });

    testWidgets('owned and equipped items say so and hide the price', (tester) async {
      await pumpTile(tester, 'frame_ring', owned: true);
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('120'), findsNothing);

      await pumpTile(tester, 'frame_ring', owned: true, equipped: true);
      expect(find.text('Equipped'), findsOneWidget);
    });

    testWidgets('locks are labelled', (tester) async {
      await pumpTile(tester, 'frame_prism', availability: ShopAvailability.proOnly);
      expect(find.text('Pro'), findsOneWidget);

      await pumpTile(tester, 'frame_gold', availability: ShopAvailability.rankLocked);
      expect(find.text('Earned at Gold'), findsOneWidget);
      expect(find.text('250'), findsNothing);

      await pumpTile(tester, 'frame_founders', availability: ShopAvailability.soldOut);
      expect(find.text('Sold out'), findsOneWidget);
      expect(find.text('1000'), findsNothing);
    });

    testWidgets('an app icon tile draws the real icon art', (tester) async {
      await pumpTile(tester, 'icon_noir');

      expect(find.byWidgetPredicate(isIconArt('assets/app_icons/icon_noir.jpg')), findsOneWidget);
    });

    testWidgets('an app icon tile with no room still builds', (tester) async {
      await tester.pumpWidget(host(ShopItemPreview(item: shopItem('icon_noir')!, size: 0)));

      expect(tester.takeException(), isNull);
      expect(find.byWidgetPredicate(isIconArt('assets/app_icons/icon_noir.jpg')), findsOneWidget);
    });

    testWidgets('a limited item shows when it ends', (tester) async {
      await pumpTile(tester, 'frame_founders');

      expect(find.text('Until Nov 30'), findsOneWidget);
      expect(find.text(formatLocalizedNumber(1000, AppLocalizationsEn())), findsOneWidget);
    });
  });

  group('ShopItemSheet', () {
    Future<void> openSheet(WidgetTester tester, String id) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showShopItemSheet(context, id == defaultAppIcon.id ? defaultAppIcon : shopItem(id)!),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('with enough coins the primary button buys', (tester) async {
      await openSheet(tester, 'theme_rose');

      expect(find.text('Buy for 150'), findsOneWidget);
      expect(find.textContaining('Watch a video'), findsNothing);
      expect(find.text('Earn coins'), findsNothing);

      await tester.tap(find.text('Buy for 150'));
      await tester.pump();
      await tester.pump();

      expect(calls, contains('purchaseShopItem'));
    });

    testWidgets('with too few coins it offers a video and Earn coins instead of Buy', (tester) async {
      coins.balanceNotifier.value = 100;
      await openSheet(tester, 'theme_rose');

      expect(find.text('Buy for 150'), findsNothing);
      expect(find.text('Watch a video (+${coins.adsRewardNow})'), findsOneWidget);
      expect(find.text('Earn coins'), findsOneWidget);
      expect(find.text('You need 50 more coins.'), findsOneWidget);
    });

    testWidgets('an owned frame can be equipped and an equipped one unequipped', (tester) async {
      coins.inventoryNotifier.value = const Inventory(owned: <String>{'frame_ring'});
      await openSheet(tester, 'frame_ring');
      expect(find.text('Equip'), findsOneWidget);
      expect(find.textContaining('Buy for'), findsNothing);

      coins.inventoryNotifier.value = const Inventory(owned: <String>{'frame_ring'}, frame: 'frame_ring');
      await tester.pump();
      await tester.pump();
      expect(find.text('Unequip'), findsOneWidget);
    });

    testWidgets('an owned Pro frame cannot be worn without Pro', (tester) async {
      coins.inventoryNotifier.value = const Inventory(owned: <String>{'frame_prism'});
      await openSheet(tester, 'frame_prism');

      expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Equip')).onPressed, isNull);
      expect(find.text('Wearing this needs Pro.'), findsOneWidget);
    });

    testWidgets('owned themes and icons offer to use them', (tester) async {
      coins.inventoryNotifier.value = const Inventory(owned: <String>{'theme_rose', 'icon_noir'});
      await openSheet(tester, 'theme_rose');
      expect(find.text('Use theme'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await openSheet(tester, 'icon_noir');
      expect(find.text('Use icon'), findsOneWidget);
    });

    testWidgets('the default icon is free and owned, and Use icon resets the launcher icon', (tester) async {
      final List<Object?> setCalls = <Object?>[];
      final PrismAppIconHostApi previousApi = AppIconChannel.api;
      const String channel = 'dev.flutter.pigeon.Prism.PrismAppIconHostApi.setAppIcon';
      final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(channel, (ByteData? message) async {
        setCalls.add((PrismAppIconHostApi.pigeonChannelCodec.decodeMessage(message)! as List<Object?>).first);
        return PrismAppIconHostApi.pigeonChannelCodec.encodeMessage(<Object?>[true]);
      });
      addTearDown(() => messenger.setMockMessageHandler(channel, null));
      addTearDown(() => AppIconChannel.api = previousApi);
      AppIconChannel.api = PrismAppIconHostApi();
      coins.balanceNotifier.value = 0;

      expect(shopItemsOf(ShopItemKind.appIcon).first, defaultAppIcon);
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) =>
                TextButton(onPressed: () => showShopItemSheet(context, defaultAppIcon), child: const Text('open')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Default'), findsOneWidget);
      expect(find.textContaining('Buy for'), findsNothing);
      expect(find.byWidgetPredicate(isIconArt('assets/app_icons/icon_default.jpg')), findsOneWidget);

      await tester.tap(find.text('Use icon'));
      await tester.pumpAndSettle();
      expect(setCalls, <Object?>[null]);
      expect(calls, isEmpty);
      expect(coins.balanceNotifier.value, 0);
      expect(coins.inventoryNotifier.value, Inventory.empty);
      expect(find.byType(ShopItemSheet), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a failed default icon reset keeps the sheet open and can be retried', (tester) async {
      final List<Object?> setCalls = <Object?>[];
      final PrismAppIconHostApi previousApi = AppIconChannel.api;
      const String channel = 'dev.flutter.pigeon.Prism.PrismAppIconHostApi.setAppIcon';
      final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(channel, (ByteData? message) async {
        setCalls.add((PrismAppIconHostApi.pigeonChannelCodec.decodeMessage(message)! as List<Object?>).first);
        return PrismAppIconHostApi.pigeonChannelCodec.encodeMessage(<Object?>[setCalls.length > 1]);
      });
      addTearDown(() => messenger.setMockMessageHandler(channel, null));
      addTearDown(() => AppIconChannel.api = previousApi);
      AppIconChannel.api = PrismAppIconHostApi();
      coins.balanceNotifier.value = 0;

      await openSheet(tester, 'icon_default');

      await tester.tap(find.text('Use icon'));
      await tester.pumpAndSettle();
      expect(find.byType(ShopItemSheet), findsOneWidget);
      expect(
        toastCalls
            .where((call) => call.method == 'showToast')
            .map((call) => (call.arguments as Map<Object?, Object?>)['msg']),
        <String>[AppLocalizationsEn().economyShopChangeIconFailed],
      );

      // Fluttertoast clears its Dart-side showing flag one second after the platform reply.
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Use icon'));
      await tester.pumpAndSettle();

      expect(setCalls, <Object?>[null, null]);
      expect(find.byType(ShopItemSheet), findsNothing);
      expect(
        toastCalls
            .where((call) => call.method == 'showToast')
            .map((call) => (call.arguments as Map<Object?, Object?>)['msg']),
        <String>[
          AppLocalizationsEn().economyShopChangeIconFailed,
          AppLocalizationsEn().economyShopIconEnabled('Default'),
        ],
      );
      expect(calls, isEmpty);
      expect(coins.balanceNotifier.value, 0);
      expect(coins.inventoryNotifier.value, Inventory.empty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('an app icon sheet shows the real art and settles', (tester) async {
      await openSheet(tester, 'icon_noir');

      expect(find.text('Use icon'), findsNothing);
      expect(find.text('Buy for 200'), findsOneWidget);
      expect(find.byWidgetPredicate(isIconArt('assets/app_icons/icon_noir.jpg')), findsOneWidget);
    });

    testWidgets('an app icon sheet skips the sweep when animations are off', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await openSheet(tester, 'icon_noir');

      expect(find.text('Buy for 200'), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('a grandfathered theme counts as owned', (tester) async {
      await getIt<SettingsLocalDataSource>().set('theme.legacy_themes', 'kLRose,kDOlive');
      await openSheet(tester, 'theme_rose');

      expect(find.text('Use theme'), findsOneWidget);
      expect(find.textContaining('Buy for'), findsNothing);
    });

    testWidgets('a Pro item without Pro offers Get Pro and no price in coins to pay', (tester) async {
      await openSheet(tester, 'frame_prism');

      expect(find.text('Get Pro'), findsOneWidget);
      expect(find.textContaining('Buy for'), findsNothing);
      expect(find.text(AppLocalizationsEn().economyShopProOnly), findsOneWidget);
    });

    testWidgets('a rank reward below its rank points to XP without selling it', (tester) async {
      await openSheet(tester, 'frame_gold');

      expect(find.text('Earned at Gold rank with lifetime XP.'), findsOneWidget);
      expect(find.text('Earn XP'), findsOneWidget);
      expect(find.text('250'), findsNothing);
      expect(find.textContaining('Buy for'), findsNothing);
    });

    testWidgets('an eligible unconfirmed reward stays syncing until ownership is confirmed', (tester) async {
      coins.xpNotifier.value = XpStatus.fromUserData(<String, dynamic>{'xp': 2500});
      await openSheet(tester, 'frame_gold');

      expect(find.text('Rank reached. Your reward is syncing.'), findsOneWidget);
      expect(find.text('Equip'), findsNothing);
      expect(find.textContaining('Buy for'), findsNothing);

      backend.onCall = (String name, Map<String, dynamic> params) async {
        calls.add(name);
        expect(name, 'purchaseShopItem');
        expect(params['itemId'], 'frame_gold');
        return <String, Object?>{
          'success': false,
          'reason': 'shop_item_owned',
          'rev': 8,
          'inventoryChanged': true,
          'owned': <String>['frame_gold'],
        };
      };
      final ShopBloc bloc = tester.element(find.byType(ShopItemSheet)).read<ShopBloc>();
      final Future<ShopState> confirmed = bloc.stream.firstWhere(
        (state) => state.owned.contains('frame_gold') && state.loadingItemId == null,
      );
      await tester.tap(find.text('Sync reward'));
      // The platform reply and the serialized in-memory write cross the test clock's async boundary.
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(bloc.state.owned, contains('frame_gold'), reason: 'calls=$calls state=${bloc.state}');
      await confirmed;
      await tester.pump();
      expect(find.text('Equip'), findsOneWidget);
      expect(calls, contains('purchaseShopItem'));
      expect(find.text('Sync reward'), findsNothing);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(toastCalls.map((call) => call.method), <String>['cancel', 'showToast']);
      expect((toastCalls.last.arguments as Map<Object?, Object?>)['msg'], 'Gold rank reward synced');
      // Fluttertoast clears its Dart-side showing flag one second after the platform reply.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a sold out limited item has no action', (tester) async {
      EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
        'flags': <String, dynamic>{'foundersUntil': '2026-01-01T00:00:00Z'},
      });
      await openSheet(tester, 'frame_founders');

      expect(find.text(AppLocalizationsEn().economyShopSoldOut), findsOneWidget);
      expect(find.byType(PrismButton), findsNothing);
    });
  });

  group('ShopPage', () {
    testWidgets('the default icon stays owned while paid icon ownership changes and tabs switch', (tester) async {
      Finder itemTile(String name) => find.ancestor(of: find.text(name), matching: find.byType(ShopItemTile));

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      coins.balanceNotifier.value = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.light(),
          home: const ShopPage(),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Icons'));
      await tester.pumpAndSettle();
      expect(find.text('Default'), findsOneWidget);
      expect(find.descendant(of: itemTile('Default'), matching: find.text('Owned')), findsOneWidget);
      expect(find.text('Noir'), findsOneWidget);
      expect(find.descendant(of: itemTile('Noir'), matching: find.text('200')), findsOneWidget);

      coins.inventoryNotifier.value = const Inventory(owned: <String>{'icon_noir'});
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Themes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Icons'));
      await tester.pumpAndSettle();
      expect(find.text('Default'), findsOneWidget);
      expect(find.descendant(of: itemTile('Default'), matching: find.text('Owned')), findsOneWidget);
      expect(find.descendant(of: itemTile('Noir'), matching: find.text('Owned')), findsOneWidget);

      coins.inventoryNotifier.value = Inventory.empty;
      await tester.pump();
      await tester.pump();
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Noir'), findsOneWidget);
      expect(find.descendant(of: itemTile('Default'), matching: find.text('Owned')), findsOneWidget);
      expect(find.descendant(of: itemTile('Noir'), matching: find.text('Owned')), findsNothing);
      expect(find.descendant(of: itemTile('Noir'), matching: find.text('200')), findsOneWidget);

      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();
      expect(find.text('Use icon'), findsOneWidget);
      expect(find.textContaining('Buy for'), findsNothing);
      expect(find.textContaining('Watch a video'), findsNothing);
      expect(find.text('Sync reward'), findsNothing);
      expect(calls, isEmpty);
    });

    testWidgets('shows the themes first and switches kind with the segmented control', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      coins.inventoryNotifier.value = const Inventory(owned: <String>{'theme_rose'});
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.light(),
          home: const ShopPage(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Rose'), findsOneWidget);
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('Ring'), findsNothing);

      await tester.tap(find.text('Frames'));
      await tester.pumpAndSettle();

      expect(find.text('Ring'), findsOneWidget);
      expect(find.text('Rose'), findsNothing);
    });

    testWidgets('tapping a tile opens the item sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.light(),
          home: const ShopPage(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Rose'));
      await tester.pumpAndSettle();

      expect(find.text('Buy for 150'), findsOneWidget);
    });
  });
}
