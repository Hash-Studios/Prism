import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/services.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<CustomerInfoUpdateListener> listeners;
  late int syncCalls;
  late int failuresLeft;
  late int configureCalls;
  late List<String> loginCalls;

  PurchasesService buildService({
    Future<void> Function(PurchasesConfiguration configuration)? configurePurchases,
    Future<void> Function(String userId)? logIn,
    Future<CustomerInfo> Function()? getCustomerInfo,
    String Function()? apiKey,
  }) => PurchasesService.forTesting(
    addCustomerInfoListener: listeners.add,
    syncSubscription: () async {
      syncCalls += 1;
      if (failuresLeft > 0) {
        failuresLeft -= 1;
        throw StateError('offline');
      }
    },
    configurePurchases:
        configurePurchases ??
        (_) async {
          configureCalls++;
        },
    logIn:
        logIn ??
        (String userId) async {
          loginCalls.add(userId);
        },
    getCustomerInfo: getCustomerInfo,
    apiKey: apiKey,
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('purchases_flutter'),
      (call) async {
        if (call.method == 'setLogLevel') return null;
        throw StateError('Unexpected RevenueCat call: ${call.method}');
      },
    );
    listeners = <CustomerInfoUpdateListener>[];
    syncCalls = 0;
    failuresLeft = 0;
    configureCalls = 0;
    loginCalls = <String>[];
    app_state.prismUser = profileUser(premium: true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('purchases_flutter'),
      null,
    );
  });

  test('early anonymous setup and signed-in setup share one configuration and settle on the account', () async {
    final Completer<void> configureGate = Completer<void>();
    String? configuredApiKey;
    final PurchasesService service = buildService(
      configurePurchases: (PurchasesConfiguration configuration) async {
        configureCalls++;
        configuredApiKey = configuration.apiKey;
        await configureGate.future;
      },
      apiKey: () => 'test-key',
    );

    final Future<void> earlySetup = service.configureEarly();
    final Future<void> accountSetup = service.ensureConfigured('user-1');
    await Future<void>.delayed(Duration.zero);
    configureGate.complete();
    await Future.wait(<Future<void>>[earlySetup, accountSetup]);

    expect(configureCalls, 1);
    expect(configuredApiKey, 'test-key');
    expect(loginCalls, <String>['user-1']);
  });

  test('ignores an anonymous customer-info callback while signing in', () async {
    final Completer<void> loginGate = Completer<void>();
    final PurchasesService service = buildService(
      logIn: (String userId) async {
        loginCalls.add(userId);
        await loginGate.future;
      },
      apiKey: () => 'test-key',
    );

    await service.configureEarly();
    app_state.prismUser.subscriptionTier = 'pro';
    final Future<void> login = service.ensureConfigured('u1');
    await Future<void>.delayed(Duration.zero);

    listeners.single(_freeCustomer);
    await pumpEventQueue();

    expect(app_state.prismUser.premium, isTrue);
    expect(app_state.prismUser.subscriptionTier, 'pro');

    loginGate.complete();
    await login;
  });

  test('an anonymous customer-info response cannot replace the signed-in account state', () async {
    final Completer<CustomerInfo> customerInfoGate = Completer<CustomerInfo>();
    final PurchasesService service = buildService(getCustomerInfo: () => customerInfoGate.future);
    app_state.prismUser
      ..id = ''
      ..premium = false;

    final Future<bool> pendingCheck = service.checkAndPersistPremium();
    await Future<void>.delayed(Duration.zero);
    app_state.prismUser
      ..id = 'user-1'
      ..premium = true
      ..subscriptionTier = 'pro';
    await service.ensureConfigured('user-1');
    customerInfoGate.complete(_freeCustomer);

    expect(await pendingCheck, isTrue);
    expect(app_state.prismUser.premium, isTrue);
    expect(app_state.prismUser.subscriptionTier, 'pro');
  });

  test('registers one customer info listener, however often it is asked', () {
    final service = buildService();

    service.registerCustomerInfoListener();
    service.registerCustomerInfoListener();

    expect(listeners, hasLength(1));
  });

  test('a customer info update from the store re-derives premium and syncs it', () async {
    final PurchasesService service = buildService();
    await service.ensureConfigured('u1');
    service.registerCustomerInfoListener();

    listeners.single(_freeCustomer);
    await pumpEventQueue();

    expect(app_state.prismUser.premium, isFalse);
    expect(app_state.prismUser.subscriptionTier, 'free');
    expect(syncCalls, 1);
  });

  test('syncSubscription is retried once after a failure', () async {
    failuresLeft = 1;
    final PurchasesService service = buildService();
    await service.ensureConfigured('u1');
    service.registerCustomerInfoListener();

    listeners.single(_freeCustomer);
    await pumpEventQueue();

    expect(syncCalls, 2);
  });

  test('a second failure is given up on without throwing', () async {
    failuresLeft = 5;
    final PurchasesService service = buildService();
    await service.ensureConfigured('u1');
    service.registerCustomerInfoListener();

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
      final PurchasesService service = buildService();
      await service.ensureConfigured('u1');
      service.registerCustomerInfoListener();

      listeners.single(_proCustomer);
      await pumpEventQueue();

      expect(app_state.prismUser.premium, isTrue);
      expect(conversions(), 0);
    });

    test('repeated entitlement refreshes cannot fabricate a purchase or revenue', () async {
      final PurchasesService service = buildService(getCustomerInfo: () async => _proCustomer);
      await service.checkAndPersistPremium();
      await service.checkAndPersistPremium();

      expect(app_state.prismUser.premium, isTrue);
      expect(fakeAnalytics.events.whereType<SubscriptionConversionEvent>(), isEmpty);
      expect(fakeAnalytics.events.whereType<PurchaseVerifiedEvent>(), isEmpty);
      expect(fakeAnalytics.events.whereType<RevenueRecordedEvent>(), isEmpty);
    });
  });
}
