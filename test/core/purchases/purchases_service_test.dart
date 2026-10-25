import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
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

const Map<String, dynamic> _freeCustomerJson = <String, dynamic>{
  'entitlements': <String, dynamic>{'all': <String, dynamic>{}, 'active': <String, dynamic>{}},
  'allPurchaseDates': <String, dynamic>{},
  'activeSubscriptions': <String>[],
  'allPurchasedProductIdentifiers': <String>[],
  'nonSubscriptionTransactions': <Map<String, dynamic>>[],
  'firstSeen': '',
  'originalAppUserId': 'u1',
  'allExpirationDates': <String, dynamic>{},
  'requestDate': '',
};

const Map<String, dynamic> _proEntitlementJson = <String, dynamic>{
  'identifier': PurchaseConstants.entitlementV3ProAccess,
  'isActive': true,
  'willRenew': true,
  'latestPurchaseDate': '2026-01-01T00:00:00Z',
  'originalPurchaseDate': '2026-01-01T00:00:00Z',
  'productIdentifier': 'prism_pro_yearly',
  'isSandbox': false,
  'expirationDate': '2027-01-01T00:00:00Z',
};

const Map<String, dynamic> _proCustomerJson = <String, dynamic>{
  'entitlements': <String, dynamic>{
    'all': <String, dynamic>{PurchaseConstants.entitlementV3ProAccess: _proEntitlementJson},
    'active': <String, dynamic>{PurchaseConstants.entitlementV3ProAccess: _proEntitlementJson},
  },
  'allPurchaseDates': <String, dynamic>{},
  'activeSubscriptions': <String>['prism_pro_yearly'],
  'allPurchasedProductIdentifiers': <String>['prism_pro_yearly'],
  'nonSubscriptionTransactions': <Map<String, dynamic>>[],
  'firstSeen': '',
  'originalAppUserId': 'u1',
  'allExpirationDates': <String, dynamic>{},
  'requestDate': '',
};

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
      return <String, dynamic>{
        'premium': app_state.prismUser.premium,
        'subscriptionTier': app_state.prismUser.subscriptionTier,
      };
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

  group('logout identity transition', () {
    late Future<Object?> Function() logout;
    late Future<Object?> Function() restore;

    setUp(() {
      logout = () async => _freeCustomerJson;
      restore = () async => _proCustomerJson;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('purchases_flutter'),
        (call) async {
          if (call.method == 'setLogLevel') return null;
          if (call.method == 'logOut') return logout();
          if (call.method == 'restorePurchases') return restore();
          throw StateError('Unexpected RevenueCat call: ${call.method}');
        },
      );
    });

    for (final bool alreadyAnonymous in <bool>[false, true]) {
      test('signed-in logout permits guest restore when already anonymous is $alreadyAnonymous', () async {
        if (alreadyAnonymous) {
          logout = () async => throw PlatformException(code: '22');
        }
        final service = buildService(getCustomerInfo: () async => _proCustomer);
        await service.ensureConfigured('u1');
        app_state.prismUser = profileUser(id: '', loggedIn: false);

        await service.logOut();

        expect(await service.restore(), PurchaseEntitlementStatus.guestSignInRequired);
        expect(app_state.prismUser.subscriptionTier, 'pro');
        expect(await service.checkPurchaseEntitlement(), PurchaseEntitlementStatus.guestSignInRequired);
        expect(await service.checkAndPersistPremium(forceSync: true), isFalse);
        expect(syncCalls, 0);
      });
    }

    test('logout waits for in-flight first configuration before ending the account session', () async {
      final configuration = Completer<void>();
      final service = buildService(configurePurchases: (_) => configuration.future);
      final setup = service.ensureConfigured('u1');
      await pumpEventQueue();
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      final signOut = service.logOut();
      configuration.complete();
      await Future.wait(<Future<void>>[setup, signOut]);

      expect(await service.restore(), PurchaseEntitlementStatus.guestSignInRequired);
      expect(app_state.prismUser.premium, isTrue);
      expect(syncCalls, 0);
    });

    test('logout waits for an older login and leaves the SDK ready for guest restore', () async {
      final login = Completer<void>();
      final service = buildService(logIn: (_) => login.future);
      await service.ensureConfigured('u1');
      app_state.prismUser = profileUser(id: 'other-user');
      final setup = service.ensureConfigured('other-user');
      await pumpEventQueue();
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      final signOut = service.logOut();
      login.complete();
      await Future.wait(<Future<void>>[setup, signOut]);

      expect(await service.restore(), PurchaseEntitlementStatus.guestSignInRequired);
      expect(app_state.prismUser.subscriptionTier, 'pro');
      expect(syncCalls, 0);
    });

    for (final String nextUserId in <String>['u1', 'other-user']) {
      test('a newer login as $nextUserId waits for logout and reads that account from the SDK', () async {
        final logoutReply = Completer<Object?>();
        String sdkUserId = '';
        logout = () async {
          final result = await logoutReply.future;
          sdkUserId = '';
          return result;
        };
        final service = buildService(
          configurePurchases: (configuration) async => sdkUserId = configuration.appUserID ?? '',
          logIn: (userId) async => sdkUserId = userId,
          getCustomerInfo: () async => sdkUserId == nextUserId ? _proCustomer : _freeCustomer,
        );
        await service.ensureConfigured('u1');
        app_state.prismUser = profileUser(id: '', loggedIn: false);
        final signOut = service.logOut();
        await pumpEventQueue();
        app_state.prismUser = profileUser(id: nextUserId);
        final setup = service.ensureConfigured(nextUserId);
        await pumpEventQueue();
        logoutReply.complete(_freeCustomerJson);
        await Future.wait(<Future<void>>[signOut, setup]);

        expect(await service.checkPurchaseEntitlement(), PurchaseEntitlementStatus.serverConfirmed);
        expect(sdkUserId, nextUserId);
        expect(app_state.prismUser.subscriptionTier, 'pro');
        expect(syncCalls, 1);
      });
    }

    test('customer-info reads and callbacks cannot apply while logout is pending', () async {
      final logoutReply = Completer<Object?>();
      final customerInfo = Completer<CustomerInfo>();
      logout = () => logoutReply.future;
      app_state.prismUser = profileUser();
      final service = buildService(getCustomerInfo: () => customerInfo.future);
      final pending = service.checkPurchaseEntitlement();
      await pumpEventQueue();
      final signOut = service.logOut();
      await pumpEventQueue();
      listeners.single(_proCustomer);
      customerInfo.complete(_proCustomer);

      expect(await pending, PurchaseEntitlementStatus.none);
      await pumpEventQueue();
      expect(app_state.prismUser.premium, isFalse);
      expect(syncCalls, 0);
      logoutReply.complete(_freeCustomerJson);
      await signOut;
    });

    test('a failed logout invalidates older customer info without claiming a guest SDK identity', () async {
      final customerInfo = Completer<CustomerInfo>();
      logout = () async => throw PlatformException(code: 'offline');
      app_state.prismUser = profileUser();
      final service = buildService(getCustomerInfo: () => customerInfo.future);
      final pending = service.checkPurchaseEntitlement();
      await pumpEventQueue();
      await expectLater(service.logOut(), throwsA(isA<PlatformException>()));
      customerInfo.complete(_proCustomer);

      expect(await pending, PurchaseEntitlementStatus.none);
      expect(app_state.prismUser.premium, isFalse);
      expect(syncCalls, 0);
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      expect(await service.restore(), PurchaseEntitlementStatus.none);
      expect(app_state.prismUser.premium, isFalse);
    });

    test('a guest restore after logout cannot grant the account that signs in during restore', () async {
      final restoreReply = Completer<Object?>();
      restore = () => restoreReply.future;
      final service = buildService(getCustomerInfo: () async => _proCustomer);
      await service.ensureConfigured('u1');
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      await service.logOut();
      final pending = service.restore();
      await pumpEventQueue();
      app_state.prismUser = profileUser(id: 'other-user');
      await service.ensureConfigured('other-user');
      restoreReply.complete(_proCustomerJson);

      expect(await pending, PurchaseEntitlementStatus.none);
      expect(app_state.prismUser.premium, isFalse);
      expect(syncCalls, 0);
      expect(await service.checkPurchaseEntitlement(), PurchaseEntitlementStatus.serverConfirmed);
      expect(syncCalls, 1);
    });
  });

  test('a failed RevenueCat account switch is propagated to the caller', () async {
    final PurchasesService service = buildService(
      logIn: (String userId) async {
        if (userId == 'user-2') throw PlatformException(code: 'login_failed');
      },
    );
    await service.ensureConfigured('user-1');

    await expectLater(service.ensureConfigured('user-2'), throwsA(isA<PlatformException>()));
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

  test('a forced check does not report cached premium when the customer-info request fails', () async {
    app_state.prismUser = profileUser(premium: true);
    final PurchasesService service = buildService(
      getCustomerInfo: () async => throw PlatformException(code: 'offline'),
    );

    expect(await service.checkAndPersistPremium(forceSync: true), isFalse);
    expect(app_state.prismUser.premium, isTrue);
    expect(syncCalls, 0);
  });

  test('a forced check does not report cached premium for a guest without server acknowledgment', () async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    final PurchasesService service = buildService(getCustomerInfo: () async => _proCustomer);

    expect(await service.checkAndPersistPremium(forceSync: true), isFalse);
    expect(app_state.prismUser.premium, isTrue);
    expect(syncCalls, 0);
  });

  test('a background guest refresh still applies the local RevenueCat entitlement', () async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    final PurchasesService service = buildService(getCustomerInfo: () async => _proCustomer);

    expect(await service.checkAndPersistPremium(), isTrue);
    expect(app_state.prismUser.premium, isTrue);
    expect(syncCalls, 0);
  });

  test('fresh guest purchase status is local-only and the forced bool remains server-only', () async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    final PurchasesService service = buildService(getCustomerInfo: () async => _proCustomer);

    expect(await service.checkPurchaseEntitlement(), PurchaseEntitlementStatus.guestSignInRequired);
    expect(await service.checkAndPersistPremium(forceSync: true), isFalse);
    expect(app_state.prismUser.premium, isTrue);
    expect(syncCalls, 0);
  });

  test('cached guest premium is not store success when the fresh customer-info request fails', () async {
    app_state.prismUser = profileUser(id: '', loggedIn: false, premium: true);
    final PurchasesService service = buildService(
      getCustomerInfo: () async => throw PlatformException(code: 'offline'),
    );

    expect(await service.checkPurchaseEntitlement(), PurchaseEntitlementStatus.none);
    expect(app_state.prismUser.premium, isTrue);
    expect(syncCalls, 0);
  });

  test('a guest without a paid store entitlement is not reported as local success', () async {
    app_state.prismUser = profileUser(id: '', loggedIn: false, premium: true);
    final PurchasesService service = buildService(getCustomerInfo: () async => _freeCustomer);

    expect(await service.checkPurchaseEntitlement(), PurchaseEntitlementStatus.none);
    expect(app_state.prismUser.premium, isFalse);
    expect(syncCalls, 0);
  });

  test('guest purchase status is discarded if the account changes during the store check', () async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    final customerInfo = Completer<CustomerInfo>();
    final PurchasesService service = buildService(getCustomerInfo: () => customerInfo.future);
    final pending = service.checkPurchaseEntitlement();
    await pumpEventQueue();
    app_state.prismUser = profileUser(premium: true);
    customerInfo.complete(_proCustomer);

    expect(await pending, PurchaseEntitlementStatus.none);
    expect(syncCalls, 0);
  });

  test('a forced check aborted by an identity change does not return the new account cached premium', () async {
    final Completer<CustomerInfo> customerInfo = Completer<CustomerInfo>();
    final PurchasesService service = buildService(getCustomerInfo: () => customerInfo.future);

    final Future<bool> pending = service.checkAndPersistPremium(forceSync: true);
    await pumpEventQueue();
    app_state.prismUser = profileUser(premium: true)..id = 'other-user';
    customerInfo.complete(_proCustomer);

    expect(await pending, isFalse);
    expect(syncCalls, 0);
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

  test('a malformed syncSubscription reply is retried once and then given up on', () async {
    final PurchasesService service = PurchasesService.forTesting(
      addCustomerInfoListener: listeners.add,
      syncSubscription: () async {
        syncCalls += 1;
        return <String, dynamic>{'premium': 'yes'};
      },
      configurePurchases: (_) async {},
      logIn: (_) async {},
    );
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

  group('subscription sync skip', () {
    late SettingsLocalDataSource settings;

    setUp(() async {
      await getIt.reset();
      settings = SettingsLocalDataSource(InMemoryLocalStore());
      getIt.registerSingleton<SettingsLocalDataSource>(settings);
    });
    tearDown(() => getIt.reset());

    Future<void> storeUpdate(PurchasesService service, CustomerInfo info) async {
      await service.ensureConfigured('u1');
      service.registerCustomerInfoListener();
      listeners.single(info);
      await pumpEventQueue();
    }

    test('an unchanged tier synced under 24 hours ago is not synced again', () async {
      await settings.set('lastSyncedSubscription.u1', 'free|${DateTime.now().millisecondsSinceEpoch}');
      await storeUpdate(buildService(), _freeCustomer);
      expect(syncCalls, 0);
    });

    test('an unchanged tier synced over 24 hours ago is synced again and remembered', () async {
      final int old = DateTime.now().subtract(const Duration(hours: 25)).millisecondsSinceEpoch;
      await settings.set('lastSyncedSubscription.u1', 'free|$old');
      await storeUpdate(buildService(), _freeCustomer);
      expect(syncCalls, 1);
      final String saved = settings.get<String>('lastSyncedSubscription.u1', defaultValue: '');
      expect(saved.split('|').first, 'free');
      expect(int.parse(saved.split('|').last), greaterThan(old));
    });

    test('a changed tier is synced even when the last sync was recent', () async {
      await settings.set('lastSyncedSubscription.u1', 'pro|${DateTime.now().millisecondsSinceEpoch}');
      await storeUpdate(buildService(), _freeCustomer);
      expect(syncCalls, 1);
    });

    test('a failed sync is not remembered', () async {
      failuresLeft = 5;
      await storeUpdate(buildService(), _freeCustomer);
      expect(settings.get<String>('lastSyncedSubscription.u1', defaultValue: ''), isEmpty);
    });

    test('a server cooldown returning Free does not cache an unconfirmed Pro tier', () async {
      final CoinsTestBackend backend = CoinsTestBackend();
      await backend.install();
      app_state.prismUser = profileUser();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        const BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
          StandardMessageCodec(),
        ),
        (_) async {
          syncCalls++;
          return <Object?>[
            <String, Object?>{'premium': false, 'subscriptionTier': 'free'},
          ];
        },
      );
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        getCustomerInfo: () async => _proCustomer,
      );

      expect(await service.checkAndPersistPremium(forceSync: true), isFalse);
      await pumpEventQueue();
      await service.checkAndPersistPremium();

      expect(syncCalls, 4);
      expect(settings.get<String>('lastSyncedSubscription.u1', defaultValue: '').split('|').first, 'free');
    });

    test('a forced sync asks again until the server holds the paid tier', () async {
      final List<String> replies = <String>['free', 'free', 'pro'];
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        logIn: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () async {
          final String tier = replies[syncCalls++];
          return <String, dynamic>{'premium': tier != 'free', 'subscriptionTier': tier};
        },
      );

      expect(await service.checkAndPersistPremium(forceSync: true), isTrue);
      expect(syncCalls, 3);
      expect(settings.get<String>('lastSyncedSubscription.u1', defaultValue: '').split('|').first, 'pro');
    });

    test('a forced sync stops after three answers without the paid tier and reports it unconfirmed', () async {
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        logIn: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () async {
          syncCalls++;
          return <String, dynamic>{'premium': false, 'subscriptionTier': 'free'};
        },
      );

      expect(await service.checkAndPersistPremium(forceSync: true), isFalse);
      expect(syncCalls, 3);
      expect(app_state.prismUser.premium, isTrue);
    });

    test('an inconsistent premium flag does not confirm a paid tier', () async {
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        logIn: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () async => <String, dynamic>{'premium': false, 'subscriptionTier': 'pro'},
      );

      expect(await service.checkAndPersistPremium(forceSync: true), isFalse);
    });

    test('a background sync does not ask again when the server answers with another tier', () async {
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        logIn: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () async {
          syncCalls++;
          return <String, dynamic>{'premium': false, 'subscriptionTier': 'free'};
        },
      );

      expect(await service.checkAndPersistPremium(), isTrue);
      expect(syncCalls, 1);
    });

    test('a server cooldown returning Pro does not cache an unconfirmed revocation', () async {
      final CoinsTestBackend backend = CoinsTestBackend();
      await backend.install();
      app_state.prismUser = profileUser(premium: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        const BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
          StandardMessageCodec(),
        ),
        (_) async {
          syncCalls++;
          return <Object?>[
            <String, Object?>{'premium': true, 'subscriptionTier': 'pro'},
          ];
        },
      );
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        getCustomerInfo: () async => _freeCustomer,
      );

      expect(await service.checkAndPersistPremium(forceSync: true), isFalse);
      expect(syncCalls, 1);
      await pumpEventQueue();
      await service.checkAndPersistPremium();

      expect(syncCalls, 2);
      expect(settings.get<String>('lastSyncedSubscription.u1', defaultValue: '').split('|').first, 'pro');
    });

    test('a forced sync waits for server confirmation before allowing premium actions', () async {
      await settings.set('lastSyncedSubscription.u1', 'pro|${DateTime.now().millisecondsSinceEpoch}');
      final Completer<void> release = Completer<void>();
      int forcedCalls = 0;
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        syncSubscription: () {
          forcedCalls++;
          return release.future.then((_) => <String, dynamic>{'premium': true, 'subscriptionTier': 'pro'});
        },
        configurePurchases: (_) async {},
        logIn: (_) async {},
        getCustomerInfo: () async => _proCustomer,
      );

      bool returned = false;
      final Future<bool> premium = service.checkAndPersistPremium(forceSync: true).then((value) {
        returned = true;
        return value;
      });
      await pumpEventQueue();

      expect(forcedCalls, 1);
      expect(release.isCompleted, isFalse);
      expect(returned, isFalse);
      release.complete();
      expect(await premium, isTrue);
    });

    test('a forced sync does not retry as a different account after the owner switches', () async {
      final Completer<Map<String, dynamic>> response = Completer<Map<String, dynamic>>();
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () {
          syncCalls++;
          if (syncCalls == 1) return response.future;
          return Future<Map<String, dynamic>>.value(<String, dynamic>{'premium': true, 'subscriptionTier': 'pro'});
        },
      );

      final Future<bool> premium = service.checkAndPersistPremium(forceSync: true);
      await pumpEventQueue();
      app_state.prismUser = profileUser()..id = 'other-user';
      response.completeError(StateError('offline'));
      await pumpEventQueue();
      await premium;

      expect(syncCalls, 1);
      expect(settings.get<String>('lastSyncedSubscription.u1', defaultValue: ''), isEmpty);
    });

    test('a successful old-account response cannot confirm a forced sync after an identity switch', () async {
      final Completer<Map<String, dynamic>> response = Completer<Map<String, dynamic>>();
      int calls = 0;
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () {
          calls++;
          return response.future;
        },
      );

      final Future<bool> pending = service.checkAndPersistPremium(forceSync: true);
      await pumpEventQueue();
      app_state.prismUser = profileUser(id: 'other-user');
      response.complete(<String, dynamic>{'premium': true, 'subscriptionTier': 'pro'});

      expect(await pending, isFalse);
      expect(calls, 1);
      expect(settings.get<String>('lastSyncedSubscription.u1', defaultValue: ''), isEmpty);
      expect(app_state.prismUser.premium, isFalse);
    });

    test('an account switch away and back invalidates a pending paid-tier retry', () async {
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        confirmRetryDelay: const Duration(seconds: 1),
        configurePurchases: (_) async {},
        logIn: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () async {
          syncCalls++;
          return <String, dynamic>{'premium': false, 'subscriptionTier': 'free'};
        },
      );

      final Future<bool> pending = service.checkAndPersistPremium(forceSync: true);
      await pumpEventQueue();
      await service.ensureConfigured('other-user');
      await service.ensureConfigured('u1');

      expect(await pending, isFalse);
      expect(syncCalls, 1);
    });

    testWidgets('paid-tier mismatch waits past the server cooldown while Free mismatch waits six seconds', (
      WidgetTester tester,
    ) async {
      final List<String> replies = <String>['free', 'lifetime', 'pro'];
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        confirmRetryDelay: const Duration(seconds: 6),
        configurePurchases: (_) async {},
        logIn: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () async {
          final String tier = replies[syncCalls++];
          return <String, dynamic>{'premium': tier != 'free', 'subscriptionTier': tier};
        },
      );
      bool? result;
      unawaited(service.checkAndPersistPremium(forceSync: true).then((value) => result = value));

      await tester.pump();
      expect(syncCalls, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(syncCalls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(syncCalls, 2);
      await tester.pump(const Duration(seconds: 30));
      expect(syncCalls, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(syncCalls, 3);
      expect(result, isTrue);
    });

    test('a newer store revocation invalidates a pending forced paid-tier acknowledgment', () async {
      final Completer<Map<String, dynamic>> forcedResponse = Completer<Map<String, dynamic>>();
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () {
          syncCalls++;
          if (syncCalls == 1) return forcedResponse.future;
          return Future<Map<String, dynamic>>.value(<String, dynamic>{'premium': false, 'subscriptionTier': 'free'});
        },
      );
      await service.ensureConfigured('u1');
      service.registerCustomerInfoListener();

      final Future<bool> pending = service.checkAndPersistPremium(forceSync: true);
      await pumpEventQueue();
      listeners.single(_freeCustomer);
      await pumpEventQueue();
      forcedResponse.complete(<String, dynamic>{'premium': true, 'subscriptionTier': 'pro'});

      expect(await pending, isFalse);
      expect(app_state.prismUser.premium, isFalse);
    });

    test('mixed sync errors and cooldown mismatches remain bounded', () async {
      final List<Object?> replies = <Object?>[
        <String, dynamic>{'premium': false, 'subscriptionTier': 'free'},
        StateError('offline'),
        <String, dynamic>{'premium': false, 'subscriptionTier': 'free'},
        StateError('offline'),
      ];
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        logIn: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () async {
          final Object? reply = replies[syncCalls++];
          if (reply is Error) throw reply;
          return reply! as Map<String, dynamic>;
        },
      );

      expect(await service.checkAndPersistPremium(forceSync: true), isFalse);
      expect(syncCalls, 4);
    });

    test('a forced check aborted by a sync error after an identity switch does not report success', () async {
      final Completer<Map<String, dynamic>> response = Completer<Map<String, dynamic>>();
      int calls = 0;
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        getCustomerInfo: () async => _proCustomer,
        syncSubscription: () {
          calls++;
          return response.future;
        },
      );

      final Future<bool> pending = service.checkAndPersistPremium(forceSync: true);
      await pumpEventQueue();
      app_state.prismUser = profileUser(premium: true)..id = 'other-user';
      response.completeError(StateError('offline'));

      expect(await pending, isFalse);
      expect(calls, 1);
      expect(settings.get<String>('lastSyncedSubscription.u1', defaultValue: ''), isEmpty);
    });

    test('restore does not sync or apply restored info to a different account', () async {
      final Completer<Object?> restoreResult = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('purchases_flutter'),
        (call) async {
          if (call.method == 'setLogLevel') return null;
          if (call.method == 'restorePurchases') return restoreResult.future;
          throw StateError('Unexpected RevenueCat call: ${call.method}');
        },
      );
      final PurchasesService service = buildService(
        getCustomerInfo: () async => _freeCustomer,
        apiKey: () => 'test-key',
      );

      final Future<PurchaseEntitlementStatus> pending = service.restore();
      await pumpEventQueue();
      app_state.prismUser = profileUser(id: 'other-user');
      restoreResult.complete(_freeCustomerJson);

      expect(await pending, PurchaseEntitlementStatus.none);
      expect(syncCalls, 0);
      expect(app_state.prismUser.premium, isFalse);
    });

    test('restore applies the returned customer info without making a second store read', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('purchases_flutter'),
        (call) async {
          if (call.method == 'setLogLevel') return null;
          if (call.method == 'restorePurchases') return _freeCustomerJson;
          throw StateError('Unexpected RevenueCat call: ${call.method}');
        },
      );
      int customerInfoReads = 0;
      final PurchasesService service = PurchasesService.forTesting(
        addCustomerInfoListener: listeners.add,
        configurePurchases: (_) async {},
        logIn: (_) async {},
        getCustomerInfo: () async {
          customerInfoReads++;
          return _proCustomer;
        },
        syncSubscription: () async {
          syncCalls++;
          return <String, dynamic>{'premium': false, 'subscriptionTier': 'free'};
        },
      );

      expect(await service.restore(), PurchaseEntitlementStatus.none);
      expect(customerInfoReads, 0);
      expect(syncCalls, 1);
      expect(app_state.prismUser.subscriptionTier, 'free');
    });

    test('a paid notification from the restore itself does not reject the restore', () async {
      final Completer<Object?> restoreResult = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('purchases_flutter'),
        (call) async {
          if (call.method == 'setLogLevel') return null;
          if (call.method == 'restorePurchases') return restoreResult.future;
          throw StateError('Unexpected RevenueCat call: ${call.method}');
        },
      );
      final PurchasesService service = buildService(
        getCustomerInfo: () async => _proCustomer,
        apiKey: () => 'test-key',
      );

      final Future<PurchaseEntitlementStatus> pending = service.restore();
      await pumpEventQueue();
      for (final CustomerInfoUpdateListener listener in listeners) {
        listener(_proCustomer);
      }
      await pumpEventQueue();
      restoreResult.complete(_proCustomerJson);

      expect(await pending, PurchaseEntitlementStatus.serverConfirmed);
      expect(app_state.prismUser.premium, isTrue);
    });
  });

  test('store offering failures return no offering and blank placements never reach the SDK', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('purchases_flutter'),
      (call) {
        calls.add(call);
        return Future<Object?>.error(PlatformException(code: 'offline', message: 'Store unavailable'));
      },
    );
    final service = buildService();

    expect(await service.getCurrentOfferingForPlacement('   '), isNull);
    expect(calls, isEmpty);
    expect(await service.getOfferings(), isNull);
    expect(await service.getCurrentOfferingForPlacement('  main_upsell  '), isNull);
    expect(calls.map((call) => call.method), <String>['getOfferings', 'getCurrentOfferingForPlacement']);
    expect(calls.last.arguments, <String, Object?>{'placementIdentifier': 'main_upsell'});
  });

  test('logout avoids the native SDK before setup, tolerates anonymous users and propagates store failures', () async {
    final calls = <String>[];
    var anonymous = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('purchases_flutter'),
      (call) async {
        calls.add(call.method);
        if (call.method == 'setLogLevel') return null;
        throw PlatformException(code: anonymous ? '22' : 'offline', message: 'Store error');
      },
    );
    final service = buildService();

    await service.logOut();
    expect(calls, isEmpty);
    await service.ensureConfigured('u1');
    await service.logOut();
    anonymous = false;
    await expectLater(service.logOut(), throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'offline')));
    expect(calls.where((method) => method == 'logOut'), hasLength(2));
  });

  test('restore propagates store failure rather than reporting no purchases', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('purchases_flutter'),
      (call) async {
        if (call.method == 'setLogLevel') return null;
        throw PlatformException(code: 'offline', message: 'Store unavailable');
      },
    );
    final service = buildService();

    await expectLater(service.restore(), throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'offline')));
    expect(syncCalls, 0);
    expect(app_state.prismUser.premium, isTrue);
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

    test('a failed forced sync emits one failed refresh event', () async {
      failuresLeft = 5;
      app_state.prismUser = profileUser(premium: true);
      final PurchasesService service = buildService(getCustomerInfo: () async => _proCustomer);

      expect(await service.checkAndPersistPremium(forceSync: true), isFalse);

      await AnalyticsRuntime.instance.flush();
      final List<SubscriptionEntitlementRefreshEvent> events = fakeAnalytics.events
          .whereType<SubscriptionEntitlementRefreshEvent>()
          .toList();
      expect(events, hasLength(1));
      expect(events.single.result, SubscriptionEntitlementRefreshResultValue.failure);
    });
  });
}
