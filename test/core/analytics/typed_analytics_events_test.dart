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
  int flushCount = 0;

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

  @override
  Future<void> flush() async {
    flushCount += 1;
  }
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

    test('serialize canonical surface_action_tapped payload', () {
      const SurfaceActionTappedEvent event = SurfaceActionTappedEvent(
        surface: AnalyticsSurfaceValue.homeWallpaperGrid,
        action: AnalyticsActionValue.tileOpened,
        sourceContext: 'home_wallpaper_grid_tile',
        itemType: ItemTypeValue.wallpaper,
        itemId: 'wall_123',
        index: 3,
      );

      expect(event.eventName, 'surface_action_tapped');
      expect(event.toWireParameters(), <String, Object?>{
        'surface': 'home_wallpaper_grid',
        'action': 'tile_opened',
        'source_context': 'home_wallpaper_grid_tile',
        'item_type': 'wallpaper',
        'item_id': 'wall_123',
        'index': 3,
      });
    });

    test('serialize canonical scroll_milestone_reached payload', () {
      const ScrollMilestoneReachedEvent event = ScrollMilestoneReachedEvent(
        surface: AnalyticsSurfaceValue.favouriteWallsGrid,
        listName: ScrollListNameValue.favouriteWallsGrid,
        depth: ScrollDepthPercentValue.p75,
        sourceContext: 'favourite_walls_grid_scroll',
        itemCount: 42,
      );

      expect(event.eventName, 'scroll_milestone_reached');
      expect(event.toWireParameters(), <String, Object?>{
        'surface': 'favourite_walls_grid',
        'list_name': 'favourite_walls_grid',
        'depth': 'p75',
        'source_context': 'favourite_walls_grid_scroll',
        'item_count': 42,
      });
    });

    test('serialize canonical external_link_open_result payload', () {
      const ExternalLinkOpenResultEvent event = ExternalLinkOpenResultEvent(
        surface: AnalyticsSurfaceValue.aboutScreen,
        destination: LinkDestinationValue.github,
        result: EventResultValue.success,
        sourceContext: 'about_screen_action_chip_github',
      );

      expect(event.eventName, 'external_link_open_result');
      expect(event.toWireParameters(), <String, Object?>{
        'surface': 'about_screen',
        'destination': 'github',
        'result': 'success',
        'source_context': 'about_screen_action_chip_github',
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

    test('flush delegates to provider', () async {
      final _RecordingProvider provider = _RecordingProvider();
      final ProviderBackedAppAnalytics analytics = ProviderBackedAppAnalytics(provider: provider);

      await analytics.flush();

      expect(provider.flushCount, 1);
    });
  });
}
