import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/trial_reminder.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/daily_flow/daily_moment_presentation_gate.dart';
import 'package:Prism/features/premium/views/pages/trial_timeline_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const messagingChannel = MethodChannel('plugins.flutter.io/firebase_messaging');
  final orchestrator = PaywallOrchestrator.instance;
  late FakeAppAnalytics fakeAnalytics;
  late SettingsLocalDataSource settings;
  late List<String> toasts;
  late Future<bool> Function(BuildContext) originalSignIn;

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    fakeAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = fakeAnalytics;
    app_state.prismUser = profileUser();
    originalSignIn = signedInActionSignIn;
    toasts = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map)['msg'] as String);
      return true;
    });
  });

  tearDown(() async {
    final gate = DailyMomentPresentationGate.instance;
    gate.bootstrapReady = false;
    gate.launchIntentsReady = false;
    gate.deepLinkActive = false;
    gate.purchaseActive = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(purchasesChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(paywallChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(messagingChannel, null);
    await getIt.reset();
    AnalyticsRuntime.reset();
    signedInActionSignIn = originalSignIn;
    orchestrator.navigatorContext = null;
    app_state.prismUser = profileUser(id: '', loggedIn: false);
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
      Future<void> Function()? beforePlacementReply,
      Future<Object?> Function(Map<String, Object?> offers)? offeringsReply,
      void Function(MethodCall)? onPaywallCall,
      void Function(MethodCall)? onPurchaseCall,
      void Function()? onCustomerInfoCall,
      Future<Object?> Function(Map<String, Object?> customer)? purchaseReply,
      bool purchaseSucceeds = false,
      bool purchaseThrows = false,
      String legacyOffering = 'v3_default',
      Map<String, Object?>? annualProduct,
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
      final Map<String, Object?>? annualPackage = annualProduct == null
          ? null
          : <String, Object?>{
              'identifier': 'annual',
              'packageType': 'ANNUAL',
              'product': annualProduct,
              'presentedOfferingContext': <String, Object?>{'offeringIdentifier': 'v3_default'},
            };
      final Map<String, Object?> v3Offering = <String, Object?>{
        ...offering,
        'identifier': 'v3_default',
        'availablePackages': annualPackage == null ? <Object?>[] : <Object?>[annualPackage],
        'annual': annualPackage,
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
            await beforePlacementReply?.call();
            return offering;
          case 'getOfferings':
            if (offeringsFail) throw PlatformException(code: 'offerings_failed');
            final Map<String, Object?> offers = <String, Object?>{
              'all': <String, Object?>{legacyOffering: offering, if (includeV3) 'v3_default': v3Offering},
              'current': offering,
            };
            return offeringsReply == null ? offers : offeringsReply(offers);
          case 'getCustomerInfo':
            onCustomerInfoCall?.call();
            return customer;
          case 'purchasePackage':
            onPurchaseCall?.call(call);
            if (purchaseThrows) throw StateError('native purchase bridge failed');
            if (purchaseReply != null) return purchaseReply(customer);
            if (!purchaseSucceeds) return null;
            return <String, Object?>{
              'customerInfo': customer,
              'transaction': <String, Object?>{
                'transactionIdentifier': 'trial-tx',
                'productIdentifier': 'prism_pro_yearly',
                'purchaseDate': '2026-10-19T00:00:00Z',
              },
            };
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

    test('loads the catalog while the placement offering is pending', () async {
      final gate = Completer<void>();
      var catalogStarted = false;
      await installPaywall(
        present: () async => 'CANCELLED',
        beforePlacementReply: () => gate.future,
        offeringsReply: (offers) async {
          catalogStarted = true;
          return offers;
        },
      );
      final pending = orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');
      await pumpEventQueue();
      final overlapped = catalogStarted;
      gate.complete();
      await pending;
      expect(overlapped, isTrue);
    });

    test('daily moment waits until a presented purchase is dismissed', () async {
      final gate = DailyMomentPresentationGate.instance;
      gate.bootstrapReady = true;
      gate.launchIntentsReady = true;
      gate.deepLinkActive = false;
      final entered = Completer<void>();
      final dismissed = Completer<String>();
      await installPaywall(
        present: () {
          entered.complete();
          return dismissed.future;
        },
      );
      final result = orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');
      await entered.future;
      expect(gate.canShow, isFalse);
      dismissed.complete('CANCELLED');
      await result;
      expect(gate.canShow, isTrue);
      gate.bootstrapReady = false;
    });

    test('context-free present cannot bypass sign-in or change existing guest access', () async {
      var presented = 0;
      final backend = await installPaywall(
        present: () async {
          presented++;
          return 'PURCHASED';
        },
      );
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      app_state.prismUser.premium = true;
      var syncs = 0;
      backend.onCall = (_, _) {
        syncs++;
        throw StateError('Guests cannot sync paid server access.');
      };
      final storeCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(purchasesChannel, (
        call,
      ) async {
        storeCalls.add(call.method);
        return null;
      });

      final result = await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');
      await AnalyticsRuntime.instance.flush();

      expect(result, PaywallResultValue.guestSignInRequired);
      expect(result.indicatesPurchase, isFalse);
      expect(app_state.prismUser.premium, isTrue);
      expect(syncs, 0);
      expect(presented, 0);
      expect(storeCalls, isEmpty);
      expect(toasts, isEmpty);
      expect(fakeAnalytics.events.whereType<PaywallImpressionEvent>(), isEmpty);
    });

    for (final direct in [false, true]) {
      testWidgets(
        '${direct ? 'present with context' : 'presentOrRequireSignIn'} cancellation never touches the store',
        (tester) async {
          app_state.prismUser = profileUser(id: '', loggedIn: false);
          final storeCalls = <String>[];
          final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(purchasesChannel, (call) async {
            storeCalls.add(call.method);
            return null;
          });
          messenger.setMockMethodCallHandler(paywallChannel, (call) async {
            storeCalls.add(call.method);
            return null;
          });
          late BuildContext context;
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (value) {
                  context = value;
                  return const SizedBox();
                },
              ),
            ),
          );
          final result = direct
              ? orchestrator.present(context: context, placement: PaywallPlacement.mainUpsell, source: 'test')
              : orchestrator.presentOrRequireSignIn(context, placement: PaywallPlacement.mainUpsell, source: 'test');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('Continue with Google'), findsOneWidget);
          expect(orchestrator.presenting.value, isTrue);
          expect(DailyMomentPresentationGate.instance.purchaseActive, isTrue);
          expect(storeCalls, isEmpty);
          await tester.tap(find.text('Not now'));
          await tester.pumpAndSettle();
          expect(await result, direct ? PaywallResultValue.guestSignInRequired : null);
          expect(orchestrator.presenting.value, isFalse);
          expect(DailyMomentPresentationGate.instance.purchaseActive, isFalse);
          expect(storeCalls, isEmpty);
          expect(fakeAnalytics.events.whereType<PaywallImpressionEvent>(), isEmpty);
        },
      );
    }

    testWidgets('overlapping sign-in refusals and errors release both presentation gates', (tester) async {
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      final firstSignIn = Completer<bool>();
      final secondSignIn = Completer<bool>();
      var attempts = 0;
      signedInActionSignIn = (_) => ++attempts == 1 ? firstSignIn.future : secondSignIn.future;
      final first = orchestrator.present(context: context, placement: PaywallPlacement.mainUpsell, source: 'test');
      final second = orchestrator.presentOrRequireSignIn(
        context,
        placement: PaywallPlacement.mainUpsell,
        source: 'test',
      );
      expect(orchestrator.presenting.value, isTrue);
      expect(DailyMomentPresentationGate.instance.purchaseActive, isTrue);
      firstSignIn.complete(false);
      expect(await first, PaywallResultValue.guestSignInRequired);
      expect(orchestrator.presenting.value, isTrue);
      expect(DailyMomentPresentationGate.instance.purchaseActive, isTrue);
      secondSignIn.complete(false);
      expect(await second, isNull);
      expect(orchestrator.presenting.value, isFalse);
      expect(DailyMomentPresentationGate.instance.purchaseActive, isFalse);

      signedInActionSignIn = (_) async => throw StateError('sign-in failed');
      await expectLater(
        orchestrator.presentOrRequireSignIn(context, placement: PaywallPlacement.mainUpsell, source: 'test'),
        throwsStateError,
      );
      expect(orchestrator.presenting.value, isFalse);
      expect(DailyMomentPresentationGate.instance.purchaseActive, isFalse);
    });

    testWidgets('completed sign-in presents against the signed-in account', (tester) async {
      var presented = 0;
      await installPaywall(
        present: () async {
          presented++;
          return 'CANCELLED';
        },
      );
      final account = app_state.prismUser;
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      signedInActionSignIn = (_) async {
        app_state.prismUser = account;
        return true;
      };
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );

      final result = await tester.runAsync(
        () => orchestrator.presentOrRequireSignIn(context, placement: PaywallPlacement.mainUpsell, source: 'test'),
      );

      expect(result, PaywallResultValue.cancelled);
      expect(presented, 1);
      expect(app_state.prismUser.id, account.id);
    });

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

    group('annual trial', () {
      final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

      Map<String, Object?> annualProductJson({int? trialDays}) => <String, Object?>{
        'identifier': 'prism_pro_yearly',
        'description': '',
        'title': '',
        'price': 499,
        'priceString': 'INR 499.00',
        'currencyCode': 'INR',
        if (trialDays != null)
          'defaultOption': <String, Object?>{
            'id': 'annual-base',
            'storeProductId': 'prism_pro_yearly',
            'productId': 'prism_pro_yearly',
            'pricingPhases': <Object?>[],
            'tags': <Object?>[],
            'isBasePlan': true,
            'billingPeriod': <String, Object?>{'unit': 'YEAR', 'value': 1, 'iso8601': 'P1Y'},
            'isPrepaid': false,
            'freePhase': <String, Object?>{
              'billingPeriod': <String, Object?>{'unit': 'DAY', 'value': trialDays, 'iso8601': 'P${trialDays}D'},
              'recurrenceMode': 3,
              'billingCycleCount': 1,
              'price': <String, Object?>{'formatted': 'INR 0.00', 'amountMicros': 0, 'currencyCode': 'INR'},
              'offerPaymentMode': 'FREE_TRIAL',
            },
          },
      };

      Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Text('home'),
        ),
      );

      /// Pumps real time and fake frames until [condition] holds or 10 seconds pass.
      Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
        final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      test('eligible with no navigator context: the RevenueCat paywall shows and no timeline', () async {
        var paywallCalls = 0;
        await installPaywall(
          annualProduct: annualProductJson(trialDays: 7),
          onPaywallCall: (_) => paywallCalls++,
          present: () async => 'CANCELLED',
        );
        orchestrator.navigatorContext = null;

        final result = await orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test');

        expect(result, PaywallResultValue.cancelled);
        expect(paywallCalls, 1);
        await AnalyticsRuntime.instance.flush();
        expect(fakeAnalytics.events.whereType<TrialTimelineShownEvent>(), isEmpty);
      });

      // One widget test: PurchasesService is a singleton, and its setup queue does not survive between fake-async tests.
      testWidgets('the timeline shows only to eligible users, and close or See all plans decides the paywall', (
        tester,
      ) async {
        var paywallCalls = 0;
        await pumpApp(tester);
        orchestrator.navigatorContext = () => navigatorKey.currentContext;

        await installPaywall(
          annualProduct: annualProductJson(),
          onPaywallCall: (_) => paywallCalls++,
          present: () async => 'CANCELLED',
        );
        PaywallResultValue? result;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => result != null);
        expect(result, PaywallResultValue.cancelled);
        expect(paywallCalls, 1);
        expect(find.byType(TrialTimelinePage), findsNothing);
        expect(
          find.byWidgetPredicate((w) => w is Text && (w.data ?? '').toLowerCase().contains('free trial')),
          findsNothing,
        );
        await AnalyticsRuntime.instance.flush();
        expect(fakeAnalytics.events.whereType<TrialNotEligibleShownEvent>().single.reason, 'noTrialOffer');
        expect(fakeAnalytics.events.whereType<TrialTimelineShownEvent>(), isEmpty);

        paywallCalls = 0;
        await installPaywall(
          annualProduct: annualProductJson(trialDays: 7),
          onPaywallCall: (_) => paywallCalls++,
          present: () async => 'CANCELLED',
        );
        result = null;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        expect(find.text('Start 7-day free trial'), findsOneWidget);
        expect(fakeAnalytics.events.whereType<TrialTimelineShownEvent>().single.trialDays, 7);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await pumpUntil(tester, () => result != null);
        expect(result, PaywallResultValue.cancelled);
        expect(paywallCalls, 0);

        result = null;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        await tester.scrollUntilVisible(find.text('See all plans'), 200, scrollable: find.byType(Scrollable).last);
        await tester.tap(find.text('See all plans'));
        await pumpUntil(tester, () => result != null);
        await tester.pumpAndSettle();
        expect(result, PaywallResultValue.cancelled);
        expect(paywallCalls, 1);
        expect(find.byType(TrialTimelinePage), findsNothing);

        orchestrator.navigatorContext = null;
        await installPaywall(annualProduct: annualProductJson(trialDays: 7), present: () async => 'CANCELLED');
        result = null;
        unawaited(
          orchestrator
              .present(context: navigatorKey.currentContext, placement: PaywallPlacement.mainUpsell, source: 'test')
              .then((v) => result = v),
        );
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        expect(find.text('Start 7-day free trial'), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await pumpUntil(tester, () => result != null);
        expect(result, PaywallResultValue.cancelled);

        paywallCalls = 0;
        orchestrator.navigatorContext = () => navigatorKey.currentContext;
        result = null;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        app_state.prismUser = profileUser()..id = 'different-user';
        await tester.scrollUntilVisible(find.text('See all plans'), 200, scrollable: find.byType(Scrollable).last);
        await tester.tap(find.text('See all plans'));
        await pumpUntil(tester, () => result != null);
        await tester.pumpAndSettle();
        expect(result, PaywallResultValue.error);
        expect(paywallCalls, 0);
        app_state.prismUser = profileUser();

        final Map<String, Object?> cachedEligibleProduct = annualProductJson(trialDays: 7);
        var purchaseCalls = 0;
        paywallCalls = 0;
        await installPaywall(
          annualProduct: cachedEligibleProduct,
          onPaywallCall: (_) => paywallCalls++,
          onPurchaseCall: (_) => purchaseCalls++,
          present: () async => 'CANCELLED',
        );
        result = null;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        cachedEligibleProduct.remove('defaultOption');
        await tester.tap(find.text('Start 7-day free trial'));
        await pumpUntil(tester, () => paywallCalls == 1);
        expect(purchaseCalls, 0);
        await pumpUntil(tester, () => result != null);
        await tester.pumpAndSettle();
        expect(result, PaywallResultValue.cancelled);
        expect(find.byType(TrialTimelinePage), findsNothing);

        paywallCalls = 0;
        purchaseCalls = 0;
        var timeoutFetches = 0;
        await installPaywall(
          annualProduct: annualProductJson(trialDays: 7),
          offeringsReply: (Map<String, Object?> offers) =>
              ++timeoutFetches == 2 ? Completer<Object?>().future : Future<Object?>.value(offers),
          onPaywallCall: (_) => paywallCalls++,
          onPurchaseCall: (_) => purchaseCalls++,
          present: () async => 'CANCELLED',
        );
        result = null;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        await tester.tap(find.text('Start 7-day free trial'));
        await pumpUntil(tester, () => paywallCalls == 1);
        await tester.pumpAndSettle();
        await pumpUntil(tester, () => result != null);
        expect(result, PaywallResultValue.cancelled);
        expect(purchaseCalls, 0);
        expect(find.byType(TrialTimelinePage), findsNothing);

        toasts.clear();
        await installPaywall(
          annualProduct: annualProductJson(trialDays: 7),
          purchaseThrows: true,
          present: () async => 'CANCELLED',
        );
        result = null;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        await tester.tap(find.text('Start 7-day free trial'));
        await pumpUntil(tester, () => toasts.isNotEmpty);
        expect(toasts, <String>['Could not start the free trial. Try again.']);
        await tester.pump(const Duration(seconds: 5));
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await pumpUntil(tester, () => result != null);
        expect(result, PaywallResultValue.cancelled);

        purchaseCalls = 0;
        await installPaywall(
          annualProduct: annualProductJson(trialDays: 7),
          onPurchaseCall: (_) => purchaseCalls++,
          present: () async => 'CANCELLED',
        );
        result = null;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        app_state.prismUser = profileUser()..id = 'different-user';
        await tester.tap(find.text('Start 7-day free trial'));
        await tester.pump();
        expect(purchaseCalls, 0);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await pumpUntil(tester, () => result != null);
        expect(result, PaywallResultValue.error);
        app_state.prismUser = profileUser();

        for (final bool confirmed in <bool>[true, false]) {
          final Completer<Object?>? delayedPermission = confirmed ? Completer<Object?>() : null;
          if (confirmed) {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
              messagingChannel,
              (_) => delayedPermission!.future,
            );
          }
          var customerInfoCalls = 0;
          await installPaywall(
            annualProduct: annualProductJson(trialDays: 7),
            purchaseSucceeds: true,
            confirmed: confirmed,
            onCustomerInfoCall: () => customerInfoCalls++,
            present: () async => 'CANCELLED',
          );
          result = null;
          unawaited(
            orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v),
          );
          await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
          final Finder reminderToggle = find.byType(SwitchListTile);
          if (reminderToggle.evaluate().isNotEmpty) {
            await tester.tap(reminderToggle);
            await tester.pump();
          }
          await tester.tap(find.text('Start 7-day free trial'));
          await pumpUntil(tester, () => result != null);
          await tester.pumpAndSettle();

          expect(result, confirmed ? PaywallResultValue.purchased : PaywallResultValue.error);
          await AnalyticsRuntime.instance.flush();
          final PaywallResultEvent event = fakeAnalytics.events.whereType<PaywallResultEvent>().last;
          expect(event.entitlementSynced, confirmed ? 1 : 0);
          if (confirmed) {
            final int beforePermissionResult = customerInfoCalls;
            delayedPermission!.complete(<String, int>{
              'authorizationStatus': 1,
              'timeSensitive': 1,
              'criticalAlert': 1,
              'alert': 1,
              'announcement': 1,
              'badge': 1,
              'carPlay': 1,
              'lockScreen': 1,
              'notificationCenter': 1,
              'showPreviews': 1,
              'sound': 1,
              'providesAppNotificationSettings': 1,
            });
            await pumpUntil(tester, () => customerInfoCalls > beforePermissionResult);
            expect(customerInfoCalls, greaterThan(beforePermissionResult));
          }
          await tester.pump(const Duration(seconds: 5));
          if (confirmed) {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
              messagingChannel,
              null,
            );
          }
        }

        await settings.set(TrialReminder.optInKey, true);
        bool? reminderOptInAtPurchase;
        await installPaywall(
          annualProduct: annualProductJson(trialDays: 2),
          purchaseSucceeds: true,
          onPurchaseCall: (_) {
            reminderOptInAtPurchase = settings.get<bool>(TrialReminder.optInKey, defaultValue: true);
          },
          present: () async => 'CANCELLED',
        );
        result = null;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        expect(find.text('Start 2-day free trial'), findsOneWidget);
        await tester.tap(find.text('Start 2-day free trial'));
        await pumpUntil(tester, () => result != null);
        expect(result, PaywallResultValue.purchased);
        expect(reminderOptInAtPurchase, isFalse);
        expect(settings.get<bool>(TrialReminder.optInKey, defaultValue: true), isFalse);
        await tester.pumpAndSettle();

        final Completer<void> purchaseEntered = Completer<void>();
        final Completer<void> finishPurchase = Completer<void>();
        await installPaywall(
          annualProduct: annualProductJson(trialDays: 7),
          purchaseReply: (Map<String, Object?> customer) async {
            purchaseEntered.complete();
            await finishPurchase.future;
            return <String, Object?>{
              'customerInfo': customer,
              'transaction': <String, Object?>{
                'transactionIdentifier': 'late-trial-tx',
                'productIdentifier': 'prism_pro_yearly',
                'purchaseDate': '2026-10-19T00:00:00Z',
              },
            };
          },
          present: () async => 'CANCELLED',
        );
        result = null;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        await tester.tap(find.text('Start 7-day free trial'));
        await pumpUntil(tester, () => purchaseEntered.isCompleted);
        await tester.pump();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        finishPurchase.complete();
        await pumpUntil(tester, () => result != null);
        expect(result, PaywallResultValue.purchased);
        await AnalyticsRuntime.instance.flush();
        expect(fakeAnalytics.events.whereType<PaywallResultEvent>().last.entitlementSynced, 1);

        final Completer<void> refreshStarted = Completer<void>();
        final Completer<void> finishRefresh = Completer<void>();
        var offeringFetches = 0;
        var purchaseAfterCloseCalls = 0;
        await installPaywall(
          annualProduct: annualProductJson(trialDays: 7),
          offeringsReply: (Map<String, Object?> offers) async {
            if (++offeringFetches == 2) {
              refreshStarted.complete();
              await finishRefresh.future;
            }
            return offers;
          },
          onPurchaseCall: (_) => purchaseAfterCloseCalls++,
          present: () async => 'CANCELLED',
        );
        result = null;
        unawaited(orchestrator.present(placement: PaywallPlacement.mainUpsell, source: 'test').then((v) => result = v));
        await pumpUntil(tester, () => find.byType(TrialTimelinePage).evaluate().isNotEmpty);
        await tester.tap(find.text('Start 7-day free trial'));
        await pumpUntil(tester, () => refreshStarted.isCompleted);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        finishRefresh.complete();
        await pumpUntil(tester, () => result != null);
        expect(result, PaywallResultValue.cancelled);
        expect(purchaseAfterCloseCalls, 0);
        expect(find.text('home'), findsOneWidget);
      });
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
