import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/shop/biz/bloc/shop_bloc.j.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/theme_mode/data/legacy_themes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/coins_test_backend.dart';
import '../../../support/fake_app_analytics.dart';

Map<String, Object?> _reply({
  bool success = true,
  int after = 0,
  String reason = 'ok',
  bool insufficient = false,
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'success': success,
  'changed': success,
  'previousBalance': 300,
  'currentBalance': after,
  'delta': success ? after - 300 : 0,
  'reason': reason,
  if (insufficient) 'insufficientBalance': true,
  ...extra,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final CoinsTestBackend backend = CoinsTestBackend();
  final CoinsService coins = CoinsService.instance;
  late List<(String, Map<String, dynamic>)> calls;
  late ShopBloc bloc;
  late FakeAppAnalytics analytics;

  setUp(() async {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    calls = <(String, Map<String, dynamic>)>[];
    await backend.install();
    backend.onCall = (String name, Map<String, dynamic> params) async {
      calls.add((name, params));
      return _reply();
    };
    coins.balanceNotifier.value = 300;
    coins.inventoryNotifier.value = Inventory.empty;
    bloc = ShopBloc(getIt<SettingsLocalDataSource>());
  });

  tearDown(() async {
    await bloc.close();
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    coins.inventoryNotifier.value = Inventory.empty;
    await getIt.reset();
  });

  /// The state that carries the notice this event produces, not one left over from an earlier event.
  Future<ShopState> settled(ShopEvent event) {
    final ShopNotice? before = bloc.state.notice;
    bloc.add(event);
    return bloc.stream.firstWhere((ShopState s) => s.notice != null && !identical(s.notice, before));
  }

  test('started reads the balance, the inventory, the legacy themes and Pro', () async {
    await getIt<SettingsLocalDataSource>().set(legacyThemesSettingsKey, 'kLRose,kDOlive');
    app_state.prismUser.premium = true;
    coins.inventoryNotifier.value = const Inventory(owned: <String>{'frame_ring'}, frame: 'frame_ring');

    bloc.add(const ShopEvent.started());
    final ShopState state = await bloc.stream.first;

    expect(state.balance, 300);
    expect(state.owned, <String>{'frame_ring'});
    expect(state.equippedFrame, 'frame_ring');
    expect(state.legacyThemes, <String>{'kLRose', 'kDOlive'});
    expect(state.premium, isTrue);
    expect(state.isOwned(shopItem('frame_ring')!), isTrue);
    expect(state.isOwned(shopItem('theme_rose')!), isTrue);
    expect(state.isOwned(shopItem('theme_sky')!), isFalse);
    expect(state.isEquipped(shopItem('frame_ring')!), isTrue);
    expect(state.isEquipped(shopItem('glow_ember')!), isFalse);
  });

  test('later balance and inventory changes reach the state', () async {
    bloc.add(const ShopEvent.started());
    await bloc.stream.first;

    coins.balanceNotifier.value = 42;
    final ShopState state = await bloc.stream.firstWhere((ShopState s) => s.balance == 42);

    expect(state.balance, 42);
  });

  test('kindChanged filters the items', () async {
    bloc.add(const ShopEvent.kindChanged(ShopItemKind.frame));
    final ShopState state = await bloc.stream.first;

    expect(state.items.map((ShopItem i) => i.kind).toSet(), <ShopItemKind>{ShopItemKind.frame});
    expect(state.items, hasLength(5));
  });

  test('a purchase calls the server, stores the item and says so', () async {
    backend.onCall = (String name, Map<String, dynamic> params) async {
      calls.add((name, params));
      return _reply(
        after: 180,
        extra: <String, Object?>{
          'owned': <String>['frame_ring'],
        },
      );
    };
    bloc.add(const ShopEvent.started());
    await bloc.stream.first;

    final ShopState state = await settled(const ShopEvent.purchaseRequested('frame_ring'));

    expect(calls.single.$1, 'purchaseShopItem');
    expect(calls.single.$2['itemId'], 'frame_ring');
    expect(state.owned, contains('frame_ring'));
    expect(state.notice!.success, isTrue);
    expect(state.notice!.message, 'Ring is yours');
    expect(state.loadingItemId, isNull);
    expect(analytics.events.whereType<ShopItemPurchasedEvent>(), hasLength(1));
  });

  test('a rank reward sync confirms ownership without recording a paid purchase', () async {
    backend.onCall = (_, _) async => _reply(
      success: false,
      reason: 'shop_item_owned',
      after: 300,
      extra: <String, Object?>{
        'rev': 8,
        'inventoryChanged': true,
        'owned': <String>['frame_gold'],
      },
    );
    bloc.add(const ShopEvent.started());
    await bloc.stream.first;

    final ShopState state = await settled(const ShopEvent.purchaseRequested('frame_gold'));

    expect(state.owned, contains('frame_gold'));
    expect(state.notice!.message, 'Gold rank reward synced');
    expect(state.notice!.success, isTrue);
    expect(analytics.events.whereType<ShopItemPurchasedEvent>(), isEmpty);
  });

  test('a failed rank reward sync offers to retry syncing', () async {
    backend.onCall = (_, _) async => throw Exception('offline');

    final ShopState state = await settled(const ShopEvent.purchaseRequested('frame_gold'));

    expect(state.notice!.message, 'Could not sync this reward. Try again.');
    expect(state.notice!.success, isFalse);
    expect(analytics.events.whereType<ShopItemPurchasedEvent>(), isEmpty);
  });

  test('a successful rank reward reply does not record a paid purchase', () async {
    final ShopState state = await settled(const ShopEvent.purchaseRequested('frame_gold'));

    expect(state.notice!.message, 'Gold rank reward synced');
    expect(state.notice!.success, isTrue);
    expect(analytics.events.whereType<ShopItemPurchasedEvent>(), isEmpty);
  });

  test('a purchase marks the item as loading while it runs', () async {
    bloc.add(const ShopEvent.started());
    await bloc.stream.first;

    bloc.add(const ShopEvent.purchaseRequested('frame_ring'));
    final ShopState loading = await bloc.stream.first;

    expect(loading.loadingItemId, 'frame_ring');
  });

  test('every refusal becomes a message', () async {
    final Map<String, String> cases = <String, String>{
      'shop_item_owned': 'Gold rank reward synced',
      'shop_item_pro_only': 'This item is for Pro members',
      'shop_item_rank_locked': 'Reach Gold rank to unlock this',
      'shop_item_expired': 'This limited item is sold out',
    };
    bloc.add(const ShopEvent.started());
    await bloc.stream.first;
    for (final MapEntry<String, String> c in cases.entries) {
      backend.onCall = (_, _) async => _reply(success: false, reason: c.key, after: 300);
      final ShopState state = await settled(const ShopEvent.purchaseRequested('frame_gold'));
      expect(state.notice!.message, c.value, reason: c.key);
    }
  });

  test('too few coins says so and keeps the item unowned', () async {
    backend.onCall = (_, _) async =>
        _reply(success: false, reason: 'shopItem_insufficient_balance', insufficient: true, after: 300);
    bloc.add(const ShopEvent.started());
    await bloc.stream.first;

    final ShopState state = await settled(const ShopEvent.purchaseRequested('theme_rose'));

    expect(state.notice!.success, isFalse);
    expect(state.notice!.message, 'You need more coins for this');
    expect(state.owned, isEmpty);
  });

  test('an unknown item is ignored', () async {
    bloc.add(const ShopEvent.purchaseRequested('nope'));
    await Future<void>.delayed(Duration.zero);

    expect(calls, isEmpty);
  });

  test('equip sends the slot and the item, unequip sends null', () async {
    backend.onCall = (String name, Map<String, dynamic> params) async {
      calls.add((name, params));
      return <String, Object?>{
        'success': true,
        'cosmetics': <String, Object?>{'frame': params['itemId'], 'nameGlow': null},
      };
    };
    coins.inventoryNotifier.value = const Inventory(owned: <String>{'frame_ring'});
    bloc.add(const ShopEvent.started());
    await bloc.stream.first;

    final ShopState equipped = await settled(const ShopEvent.equipRequested(itemId: 'frame_ring', equip: true));
    expect(calls.last.$2['slot'], 'frame');
    expect(calls.last.$2['itemId'], 'frame_ring');
    expect(equipped.equippedFrame, 'frame_ring');
    expect(equipped.notice!.message, 'Ring equipped');

    final ShopState removed = await settled(const ShopEvent.equipRequested(itemId: 'frame_ring', equip: false));
    expect(calls.last.$2['itemId'], isNull);
    expect(removed.equippedFrame, isNull);
    expect(removed.notice!.message, 'Ring removed');
  });

  test('a refused equip tells the user and changes nothing', () async {
    backend.onCall = (_, _) async => throw Exception('refused');
    coins.inventoryNotifier.value = const Inventory(owned: <String>{'frame_prism'});
    bloc.add(const ShopEvent.started());
    await bloc.stream.first;

    final ShopState state = await settled(const ShopEvent.equipRequested(itemId: 'frame_prism', equip: true));

    expect(state.notice!.success, isFalse);
    expect(state.equippedFrame, isNull);
  });

  test('themes and icons have no equip slot', () async {
    bloc.add(const ShopEvent.equipRequested(itemId: 'theme_rose', equip: true));
    await Future<void>.delayed(Duration.zero);

    expect(calls, isEmpty);
  });
}
