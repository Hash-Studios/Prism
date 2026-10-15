import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/profile_user_fixture.dart';

const CustomerInfo _freeCustomer = CustomerInfo(
  EntitlementInfos(<String, EntitlementInfo>{}, <String, EntitlementInfo>{}),
  <String, String?>{},
  <String>[],
  <String>[],
  <StoreTransaction>[],
  '',
  'u1',
  <String, String?>{},
  '',
);

const CustomerInfo _proCustomer = CustomerInfo(
  EntitlementInfos(<String, EntitlementInfo>{
    PurchaseConstants.entitlementV3ProAccess: EntitlementInfo(
      PurchaseConstants.entitlementV3ProAccess,
      true,
      true,
      '2026-01-01T00:00:00Z',
      '2026-01-01T00:00:00Z',
      'prism_pro_yearly',
      false,
      expirationDate: '2027-01-01T00:00:00Z',
    ),
  }, <String, EntitlementInfo>{}),
  <String, String?>{},
  <String>[],
  <String>[],
  <StoreTransaction>[],
  '',
  'u1',
  <String, String?>{},
  '',
);

void main() {
  late List<CustomerInfoUpdateListener> listeners;
  late int syncCalls;
  late int failuresLeft;

  PurchasesService buildService() => PurchasesService.forTesting(
    addCustomerInfoListener: listeners.add,
    syncSubscription: () async {
      syncCalls += 1;
      if (failuresLeft > 0) {
        failuresLeft -= 1;
        throw StateError('offline');
      }
    },
  );

  setUp(() {
    listeners = <CustomerInfoUpdateListener>[];
    syncCalls = 0;
    failuresLeft = 0;
    app_state.prismUser = profileUser(premium: true);
  });

  test('registers one customer info listener, however often it is asked', () {
    final service = buildService();

    service.registerCustomerInfoListener();
    service.registerCustomerInfoListener();

    expect(listeners, hasLength(1));
  });

  test('a customer info update from the store re-derives premium and syncs it', () async {
    buildService().registerCustomerInfoListener();

    listeners.single(_freeCustomer);
    await pumpEventQueue();

    expect(app_state.prismUser.premium, isFalse);
    expect(app_state.prismUser.subscriptionTier, 'free');
    expect(syncCalls, 1);
  });

  test('syncSubscription is retried once after a failure', () async {
    failuresLeft = 1;
    buildService().registerCustomerInfoListener();

    listeners.single(_freeCustomer);
    await pumpEventQueue();

    expect(syncCalls, 2);
  });

  test('a second failure is given up on without throwing', () async {
    failuresLeft = 5;
    buildService().registerCustomerInfoListener();

    listeners.single(_freeCustomer);
    await pumpEventQueue();

    expect(syncCalls, 2);
    expect(app_state.prismUser.premium, isFalse);
  });

  group('subscription conversion event', () {
    late FakeAppAnalytics fakeAnalytics;

    setUp(() {
      fakeAnalytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = fakeAnalytics;
      app_state.prismUser = profileUser();
    });
    tearDown(AnalyticsRuntime.reset);

    int conversions() => fakeAnalytics.events.whereType<SubscriptionConversionEvent>().length;

    test('is not logged when premium is found by an entitlement refresh', () async {
      buildService().registerCustomerInfoListener();

      listeners.single(_proCustomer);
      await pumpEventQueue();

      expect(app_state.prismUser.premium, isTrue);
      expect(conversions(), 0);
    });
  });
}
