import 'package:Prism/core/analytics/app_analytics.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/providers/analytics_provider.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingProvider implements AnalyticsProvider {
  String? lastEventName;
  Map<String, Object>? lastEventParams;
  String? lastShareContentType;
  String? lastShareItemId;
  String? lastShareMethod;
  String? lastLoginMethod;
  String? lastScreenName;
  String? lastScreenClass;
  Map<String, Object>? lastScreenParams;

  @override
  Future<void> logEvent({required String name, Map<String, Object> parameters = const <String, Object>{}}) async {
    lastEventName = name;
    lastEventParams = parameters;
  }

  @override
  Future<void> logLogin({String? loginMethod}) async {
    lastLoginMethod = loginMethod;
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object> parameters = const <String, Object>{},
  }) async {
    lastScreenName = screenName;
    lastScreenClass = screenClass;
    lastScreenParams = parameters;
  }

  @override
  Future<void> logShare({required String contentType, required String itemId, required String method}) async {
    lastShareContentType = contentType;
    lastShareItemId = itemId;
    lastShareMethod = method;
  }

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({required String name, String? value}) async {}
}

void main() {
  group('typed analytics events', () {
    test('serialize canonical set_wall payload', () {
      const SetWallEvent event = SetWallEvent(
        wallpaperTarget: WallpaperTargetValue.lock,
        result: BinaryResultValue.success,
      );

      expect(event.eventName, 'set_wall');
      expect(event.toWireParameters(), <String, Object?>{'wallpaper_target': 'lock', 'result': 'success'});
    });

    test('serialize canonical coin_earned payload', () {
      final CoinEarnedEvent event = CoinEarnedEvent(
        action: coinEarnActionValueFromDomain(CoinEarnAction.rewardedAd),
        amount: 10,
        balance: 20,
        sourceTag: 'coins.rewarded_ad',
      );

      expect(event.toWireParameters(), <String, Object?>{
        'action': 'rewarded_ad',
        'amount': 10,
        'balance': 20,
        'source_tag': 'coins.rewarded_ad',
      });
    });

    test('serialize canonical search_submitted payload', () {
      const SearchSubmittedEvent event = SearchSubmittedEvent(
        provider: SearchProviderValue.wallhaven,
        queryLength: 10,
        queryWordCount: 2,
        sourceContext: 'search_textfield',
        fromSuggestion: false,
      );

      expect(event.eventName, 'search_submitted');
      expect(event.toWireParameters(), <String, Object?>{
        'provider': 'wallhaven',
        'query_length': 10,
        'query_word_count': 2,
        'source_context': 'search_textfield',
        'from_suggestion': false,
      });
    });

    test('serialize canonical deep_link_navigation_result payload', () {
      const DeepLinkNavigationResultEvent event = DeepLinkNavigationResultEvent(
        targetType: TargetTypeValue.shortCode,
        result: EventResultValue.failure,
        reason: AnalyticsReasonValue.missingData,
      );

      expect(event.eventName, 'deep_link_navigation_result');
      expect(event.toWireParameters(), <String, Object?>{
        'target_type': 'short_code',
        'result': 'failure',
        'reason': 'missing_data',
      });
    });
  });

  group('provider-backed track dispatch', () {
    test('dispatches typed event via provider.logEvent', () async {
      final _RecordingProvider provider = _RecordingProvider();
      final ProviderBackedAppAnalytics analytics = ProviderBackedAppAnalytics(provider: provider);

      await analytics.track(const ReportSetupEvent());

      expect(provider.lastEventName, 'report_setup');
      expect(provider.lastEventParams, <String, Object>{});
    });

    test('dispatches share/login/screen wrappers via dedicated provider methods', () async {
      final _RecordingProvider provider = _RecordingProvider();
      final ProviderBackedAppAnalytics analytics = ProviderBackedAppAnalytics(provider: provider);

      await analytics.logShare(contentType: 'setup', itemId: 'id_1', method: 'link');
      await analytics.logLogin(loginMethod: 'google');
      await analytics.logScreenView(screenName: '/HomeFeed', screenClass: 'HomeRoute');

      expect(provider.lastShareContentType, 'setup');
      expect(provider.lastShareItemId, 'id_1');
      expect(provider.lastShareMethod, 'link');
      expect(provider.lastLoginMethod, 'google');
      expect(provider.lastScreenName, 'home_feed');
      expect(provider.lastScreenClass, 'HomeRoute');
    });
  });
}
