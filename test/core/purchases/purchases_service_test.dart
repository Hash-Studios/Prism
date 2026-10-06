import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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
}
