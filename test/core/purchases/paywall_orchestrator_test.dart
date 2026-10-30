import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  const purchasesChannel = MethodChannel('purchases_flutter');
  const paywallChannel = MethodChannel('purchases_ui_flutter');
  final orchestrator = PaywallOrchestrator.instance;
  late FakeAppAnalytics fakeAnalytics;
  late SettingsLocalDataSource settings;
  late List<String> toasts;

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    fakeAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = fakeAnalytics;
    app_state.prismUser = profileUser();
    toasts = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map)['msg'] as String);
      return true;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(purchasesChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(paywallChannel, null);
    await getIt.reset();
    AnalyticsRuntime.reset();
  });

  group('present', () {
    Future<CoinsTestBackend> installPaywall({
      required Future<String> Function() present,
      bool paid = true,
      bool confirmed = true,
      bool emitPurchase = false,
      bool loginFails = false,
      bool includeV3 = true,
      bool offeringsFail = false,
      void Function(MethodCall)? onPaywallCall,
      String legacyOffering = 'v3_default',
    }) async {
      final backend = CoinsTestBackend();
      await backend.install();
      backend.onCall = (_, _) async => confirmed
          ? <String, Object?>{'premium': paid, 'subscriptionTier': paid ? 'pro' : 'free'}
          : <String, Object?>{};
      final entitlement = <String, Object?>{
        'identifier': 'prism_v3_pro_access',
        'isActive': true,
        'willRenew': true,
        'latestPurchaseDate': '2026-10-01T00:00:00Z',
        'originalPurchaseDate': '2026-10-01T00:00:00Z',
        'productIdentifier': 'prism_pro_yearly',
        'isSandbox': false,
        'expirationDate': '2027-10-01T00:00:00Z',
      };
      final customer = <String, Object?>{
        'entitlements': <String, Object?>{
          'all': <String, Object?>{if (paid) 'prism_v3_pro_access': entitlement},
          'active': <String, Object?>{if (paid) 'prism_v3_pro_access': entitlement},
        },
        'allPurchaseDates': <String, Object?>{},
        'activeSubscriptions': <String>[],
        'allPurchasedProductIdentifiers': <String>[],
        'nonSubscriptionTransactions': <Object?>[],
        'firstSeen': '',
        'originalAppUserId': backend.userId,
        'allExpirationDates': <String, Object?>{},
        'requestDate': '',
      };
      final offering = <String, Object?>{
        'identifier': legacyOffering,
        'serverDescription': '',
        'metadata': <String, Object?>{},
        'availablePackages': <Object?>[],
      };
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockDecodedMessageHandler<Object?>(
        const BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
          StandardMessageCodec(),
        ),
        (message) async {
          final arguments = (message! as List<Object?>).first! as Map<Object?, Object?>;
          return <Object?>[await backend.onCall(arguments['functionName']! as String, <String, dynamic>{})];
        },
      );
      messenger.setMockMethodCallHandler(purchasesChannel, (call) async {
        switch (call.method) {
          case 'logIn':
            if (loginFails) throw PlatformException(code: 'login_failed');
            return <String, Object?>{'customerInfo': customer, 'created': false};
          case 'getCurrentOfferingForPlacement':
            return offering;
          case 'getOfferings':
            if (offeringsFail) throw PlatformException(code: 'offerings_failed');
            return <String, Object?>{
              'all': <String, Object?>{
                legacyOffering: offering,
                if (includeV3) 'v3_default': <String, Object?>{...offering, 'identifier': 'v3_default'},
              },
              'current': offering,
            };
          case 'getCustomerInfo':
            return customer;
          default:
            return null;
        }
      });
      messenger.setMockMethodCallHandler(paywallChannel, (call) async {
        onPaywallCall?.call(call);
        if (emitPurchase) {
          final id = (call.arguments as Map<Object?, Object?>)['presentationId'];
          final channel = 'com.revenuecat.purchasesui/PresentedPaywall/$id';
          const codec = StandardMethodCodec();
          Future<void> emit(String method, Object? arguments) {
            final completed = Completer<void>();
            ServicesBinding.instance.channelBuffers.push(
              channel,
              codec.encodeMethodCall(MethodCall(method, arguments)),
              (_) => completed.complete(),
            );
            return completed.future;
          }

          await emit('onPurchaseStarted', <String, Object?>{
            'identifier': 'annual',
            'packageType': 'ANNUAL',
            'presentedOfferingContext': <String, Object?>{'offeringIdentifier': 'v3_default'},
            'product': <String, Object?>{
              'identifier': 'prism_pro_yearly',
              'description': '',
              'title': '',
              'price': 499,
              'priceString': '499',
              'currencyCode': 'INR',
            },
          });
          for (var duplicate = 0; duplicate < 2; duplicate++) {
            await emit('onPurchaseCompleted', <String, Object?>{
              'customerInfo': customer,
              'storeTransaction': <String, Object?>{
                'transactionIdentifier': 'tx-one',
                'productIdentifier': 'prism_pro_yearly',
                'purchaseDate': '2026-10-19T00:00:00Z',
              },
            });
          }
        }
        return present();
      });
      return backend;
    }

    for (final sdkResult in <String>['PURCHASED', 'RESTORED']) {
      test('a guest $sdkResult acknowledges local access without server confirmation', () async {
        final backend = await installPaywall(present: () async => sdkResult);
        app_state.prismUser = profileUser(id: '', loggedIn: false);
        var syncs = 0;
        backend.onCall = (_, _) {
          syncs++;
          throw StateError('Guests cannot sync paid server access.');
        };

        final result = await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');
        await AnalyticsRuntime.instance.flush();

        expect(result, PaywallResultValue.guestSignInRequired);
        expect(result.indicatesPurchase, isFalse);
        expect(app_state.prismUser.premium, isTrue);
        expect(syncs, 0);
        expect(toasts, <String>[
          'Your store purchase is active on this device. Sign in to use account-based Pro features.',
        ]);
        expect(fakeAnalytics.events.whereType<PaywallResultEvent>().single.entitlementSynced, 0);
      });
    }

    for (final sdkResult in <String>['PURCHASED', 'RESTORED']) {
      test('an unconfirmed $sdkResult does not report completion and keeps the receipt result once', () async {
        await installPaywall(present: () async => sdkResult, confirmed: false);

        final result = await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');
        await AnalyticsRuntime.instance.flush();

        expect(result, PaywallResultValue.error);
        expect(toasts, <String>['Your purchase is saved. Pro can take a minute to unlock.']);
        final events = fakeAnalytics.events.whereType<PaywallResultEvent>().toList();
        expect(events, hasLength(1));
        expect(
          events.single.result,
          sdkResult == 'PURCHASED' ? PaywallResultValue.purchased : PaywallResultValue.restored,
        );
        expect(events.single.entitlementSynced, 0);
      });
    }

    test('uses the preferred Spanish locale for an unconfirmed purchase toast', () async {
      final TestPlatformDispatcher dispatcher = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
      dispatcher.localesTestValue = const <Locale>[Locale('fr'), Locale('es', 'MX')];
      addTearDown(dispatcher.clearLocalesTestValue);
      await installPaywall(present: () async => 'PURCHASED', confirmed: false);

      final result = await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');

      expect(result, PaywallResultValue.error);
      expect(toasts, <String>['Tu compra está guardada. Pro puede tardar un minuto en activarse.']);
    });

    test('a confirmed purchase reports completion and clears the upsell counter', () async {
      await installPaywall(present: () async => 'PURCHASED');
      await settings.set('paywall_ad_watch_count', 3);

      expect(
        await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test'),
        PaywallResultValue.purchased,
      );
      await AnalyticsRuntime.instance.flush();
      expect(settings.get<int>('paywall_ad_watch_count', defaultValue: -1), 0);
      expect(fakeAnalytics.events.whereType<PaywallResultEvent>().single.entitlementSynced, 1);
      expect(toasts, isEmpty);
    });

    test('receipt and conversion are recorded once while server confirmation retries', () async {
      final backend = await installPaywall(present: () async => 'PURCHASED', emitPurchase: true);
      var syncs = 0;
      backend.onCall = (_, _) async => <String, Object?>{
        'premium': ++syncs > 1,
        'subscriptionTier': syncs > 1 ? 'pro' : 'free',
      };

      expect(
        await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test'),
        PaywallResultValue.purchased,
      );
      await AnalyticsRuntime.instance.flush();

      expect(syncs, 2);
      expect(fakeAnalytics.events.whereType<PurchaseVerifiedEvent>(), hasLength(1));
      expect(fakeAnalytics.events.whereType<SubscriptionConversionEvent>(), hasLength(1));
      expect(fakeAnalytics.events.whereType<RevenueRecordedEvent>(), isEmpty);
      expect(fakeAnalytics.events.whereType<PaywallResultEvent>(), hasLength(1));
    });

    test('a cancelled paywall does not wait for paid entitlement confirmation', () async {
      final backend = await installPaywall(present: () async => 'CANCELLED');
      var syncs = 0;
      backend.onCall = (_, _) async {
        syncs++;
        return <String, Object?>{'premium': false, 'subscriptionTier': 'free'};
      };

      expect(
        await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test'),
        PaywallResultValue.cancelled,
      );
      expect(syncs, 0);
      expect(toasts, isEmpty);
    });

    test('a failed account login never presents the paywall', () async {
      var presented = false;
      await installPaywall(
        loginFails: true,
        present: () async {
          presented = true;
          return 'PURCHASED';
        },
      );

      expect(
        await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test'),
        PaywallResultValue.rcError,
      );
      expect(presented, isFalse);
    });

    test('a purchase of the previous account cannot sync or complete as the new account', () async {
      final presented = Completer<void>();
      final dismissed = Completer<String>();
      final backend = await installPaywall(
        present: () {
          presented.complete();
          return dismissed.future;
        },
      );
      var syncs = 0;
      backend.onCall = (_, _) async {
        syncs++;
        return <String, Object?>{'premium': true, 'subscriptionTier': 'pro'};
      };
      final result = orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');
      await presented.future;
      app_state.prismUser = profileUser(premium: true)..id = 'different-user';
      dismissed.complete('PURCHASED');

      expect(await result, PaywallResultValue.error);
      await AnalyticsRuntime.instance.flush();
      expect(syncs, 0);
      expect(toasts, isEmpty);
      expect(fakeAnalytics.events.whereType<PaywallResultEvent>().single.entitlementSynced, 0);
    });

    test('a failed paywall of the previous account is silent after changing accounts', () async {
      final presented = Completer<void>();
      final dismissed = Completer<String>();
      await installPaywall(
        present: () {
          presented.complete();
          return dismissed.future;
        },
      );
      final result = orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');
      await presented.future;
      app_state.prismUser = profileUser()..id = 'different-user';
      dismissed.completeError(PlatformException(code: 'paywall_failed'));

      expect(await result, PaywallResultValue.error);
      expect(toasts, isEmpty);
    });

    for (final sdkResult in <String>['NOT_PRESENTED', 'ERROR']) {
      test('a stale $sdkResult result does not show an unavailable toast', () async {
        final presented = Completer<void>();
        final dismissed = Completer<String>();
        await installPaywall(
          present: () {
            presented.complete();
            return dismissed.future;
          },
        );
        final result = orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');
        await presented.future;
        app_state.prismUser = profileUser()..id = 'different-user';
        dismissed.complete(sdkResult);

        expect(await result, PaywallResultValue.error);
        await AnalyticsRuntime.instance.flush();
        expect(fakeAnalytics.events.whereType<PaywallResultEvent>(), hasLength(1));
        expect(toasts, isEmpty);
      });
    }

    test('v3 overrides the legacy placement and current offering', () async {
      String? selectedOffering;
      await installPaywall(
        legacyOffering: 'default',
        onPaywallCall: (call) {
          selectedOffering = (call.arguments as Map)['offeringIdentifier'] as String?;
        },
        present: () async => 'CANCELLED',
      );

      expect(
        await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test'),
        PaywallResultValue.cancelled,
      );
      expect(selectedOffering, 'v3_default');
    });

    test('an offerings fetch failure never uses the legacy placement offering', () async {
      var presented = false;
      await installPaywall(
        offeringsFail: true,
        legacyOffering: 'default',
        present: () async {
          presented = true;
          return 'PURCHASED';
        },
      );

      expect(
        await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test'),
        PaywallResultValue.noOffering,
      );
      expect(presented, isFalse);
    });

    for (final legacyOffering in <String>['default', 'ultra', 'other-offering']) {
      test('missing v3 never presents $legacyOffering from placement or current offering', () async {
        var presented = false;
        await installPaywall(
          includeV3: false,
          legacyOffering: legacyOffering,
          present: () async {
            presented = true;
            return 'PURCHASED';
          },
        );

        final result = await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');
        await AnalyticsRuntime.instance.flush();

        expect(result, PaywallResultValue.noOffering);
        expect(presented, isFalse);
        expect(toasts, hasLength(1));
        expect(fakeAnalytics.events.whereType<PaywallResultEvent>().single.result, PaywallResultValue.noOffering);
      });
    }

    test('tells the user when no paywall can be shown', () async {
      final result = await orchestrator.present(placement: PaywallPlacement.lowBalance, source: 'test');
      final AppLocalizations messages = await loadAppLocalizations(WidgetsBinding.instance.platformDispatcher.locale);

      expect(const <PaywallResultValue>{
        PaywallResultValue.notPresented,
        PaywallResultValue.noOffering,
        PaywallResultValue.rcError,
      }, contains(result));
      expect(toasts, <String>[messages.premiumPagePlansUnavailable]);
    });
  });

  group('rewarded ad upsell', () {
    const promptedAtKey = 'paywall_ad_watch_prompted_at';

    Future<void> watch(int times) async {
      for (int i = 0; i < times; i++) {
        await orchestrator.recordRewardedAdWatchAndMaybeUpsell(source: 'test');
      }
    }

    int impressions() => fakeAnalytics.events.whereType<PaywallImpressionEvent>().length;

    test('the third watched ad opens the paywall once', () async {
      await watch(2);
      expect(impressions(), 0);

      await watch(1);
      expect(impressions(), 1);
      expect(settings.get<int>(promptedAtKey, defaultValue: 0), greaterThan(0));

      await watch(2);
      expect(impressions(), 1);
    });

    test('the paywall opens again after 24 hours', () async {
      await watch(3);
      final yesterday = DateTime.now().subtract(const Duration(hours: 25)).millisecondsSinceEpoch;
      await settings.set(promptedAtKey, yesterday);

      await watch(1);

      expect(impressions(), 2);
      expect(settings.get<int>(promptedAtKey, defaultValue: 0), greaterThan(yesterday));
    });

    test('a Pro user resets the counter and is never asked', () async {
      await watch(3);
      app_state.prismUser = profileUser(premium: true);

      await watch(1);

      expect(impressions(), 1);
      expect(settings.get<int>(promptedAtKey, defaultValue: 0), 0);
    });
  });
}
