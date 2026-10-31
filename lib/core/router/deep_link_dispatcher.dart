import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/auth_navigation_continuation.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_navigation.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/router/push_tap_startup.dart';
import 'package:Prism/features/daily_flow/daily_moment_presentation_gate.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';

enum DeepLinkDispatchResult { navigated, failure, blocked, cancelled, deferred }

/// One entry point for platform links, push targets, and links tapped inside the app.
class DeepLinkDispatcher {
  DeepLinkDispatcher({
    required StackRouter router,
    required Future<bool> Function() whenReady,
    Future<bool> Function()? whenBootstrapped,
    this.navigation = const DeepLinkNavigation(),
    this.onRetryNeeded,
    Future<void> Function(AnalyticsEvent event)? track,
  }) : _router = router.root,
       _whenReady = whenReady,
       _whenBootstrapped = whenBootstrapped ?? whenReady,
       _track = track ?? analytics.track {
    _instances[_router] = this;
    _router.addListener(_onRouterChanged);
    _router.navigationHistory.addListener(_onRouterChanged);
  }

  static final Expando<DeepLinkDispatcher> _instances = Expando<DeepLinkDispatcher>();

  static DeepLinkDispatcher? maybeOf(StackRouter router) => _instances[router.root];

  final StackRouter _router;
  final Future<bool> Function() _whenReady;
  final Future<bool> Function() _whenBootstrapped;
  final DeepLinkNavigation navigation;
  final void Function(ShortCodeIntent action, DeepLinkSourceValue source)? onRetryNeeded;
  final Future<void> Function(AnalyticsEvent event) _track;
  final Completer<void> _disposed = Completer<void>();
  Completer<void> _cancelled = Completer<void>();
  final List<(ShortCodeIntent, DeepLinkSourceValue)> _deferred = <(ShortCodeIntent, DeepLinkSourceValue)>[];
  Future<void> _tail = Future<void>.value();
  int _pendingDispatches = 0;
  PageRouteInfo? _dailyMomentTarget;

  void _onRouterChanged() => scheduleMicrotask(_updateDailyMomentGate);

  void _updateDailyMomentGate() {
    if (!identical(_instances[_router], this) || _disposed.isCompleted) return;
    if (_pendingDispatches == 0 && _dailyMomentTarget != null && !_isVisible(_dailyMomentTarget!)) {
      _dailyMomentTarget = null;
    }
    DailyMomentPresentationGate.instance.deepLinkActive =
        _pendingDispatches > 0 || _dailyMomentTarget != null || _deferred.isNotEmpty;
  }

  Future<DeepLinkDispatchResult> openUri(Uri uri, {required DeepLinkSourceValue source}) {
    DeepLinkActionEntity action = navigation.isPrismDeepLink(uri) || !uri.hasScheme
        ? navigation.parser.parse(uri)
        : UnknownIntent(rawUri: uri.toString());
    if (source == DeepLinkSourceValue.appLinks) {
      final WidgetKindValue? widget = _widgetKind(uri, action);
      if (widget != null) {
        _record(WidgetTappedEvent(kind: widget));
        if (_isStreakWidgetUri(uri)) {
          action = navigation.parser.parse(uri.replace(queryParameters: const <String, String>{}));
        }
      }
    }
    return openAction(action, source: source);
  }

  Future<DeepLinkDispatchResult> openAction(
    DeepLinkActionEntity action, {
    required DeepLinkSourceValue source,
    bool isRetry = false,
  }) => _enqueue(action, source: source, isRetry: isRetry);

  Future<DeepLinkDispatchResult> openActionLoader(
    Future<DeepLinkActionEntity?> Function() loadAction, {
    required String rawUri,
    required DeepLinkSourceValue source,
    TargetTypeValue targetType = TargetTypeValue.unknown,
    bool hasPayload = true,
  }) => _enqueue(
    UnknownIntent(rawUri: rawUri),
    source: source,
    loadAction: loadAction,
    receivedTargetType: targetType,
    hasPayload: hasPayload,
  );

  Future<DeepLinkDispatchResult> openPush(
    Map<String, dynamic> data, {
    NotificationRouteMapper mapper = const NotificationRouteMapper(),
  }) {
    mapper.trackPushOpened(data);
    if (data['route']?.toString() == 'wall_of_the_day') {
      _record(WotdOpenedFromPushEvent(wallId: (data['wall_id']?.toString() ?? '').trim()));
    }
    if (data['notification_kind']?.toString() == 'folder_digest') {
      _record(FolderPushOpenedEvent(folderCount: int.tryParse(data['folder_count']?.toString() ?? '') ?? 1));
    }
    // A gallery push still carries the lead wall's link for builds without the gallery page.
    final Uri? gallery = NotificationRouteMapper.galleryLinkFor(data);
    if (gallery != null) {
      final action = navigation.parser.parse(gallery);
      if (action is! UnknownIntent) return openAction(action, source: DeepLinkSourceValue.push);
    }
    final String rawUrl = (data['url']?.toString() ?? '').trim();
    final Uri? uri = Uri.tryParse(rawUrl);
    if (uri != null && navigation.isPrismDeepLink(uri)) {
      final action = navigation.parser.parse(uri);
      if (action is! UnknownIntent) return openAction(action, source: DeepLinkSourceValue.push);
    }
    return openActionLoader(
      () => mapper.actionFromPayload(data, sourceTag: 'push.route_mapper', fallbackToInbox: false),
      rawUri: data['route']?.toString() ?? rawUrl,
      source: DeepLinkSourceValue.push,
      targetType: NotificationRouteMapper.targetTypeForRoute(data['route']?.toString() ?? ''),
      hasPayload: data.isNotEmpty,
    );
  }

  Future<DeepLinkDispatchResult> _enqueue(
    DeepLinkActionEntity action, {
    required DeepLinkSourceValue source,
    bool isRetry = false,
    Future<DeepLinkActionEntity?> Function()? loadAction,
    TargetTypeValue? receivedTargetType,
    bool? hasPayload,
  }) {
    final TargetTypeValue targetType = receivedTargetType ?? DeepLinkNavigation.targetType(action);
    _pendingDispatches++;
    _updateDailyMomentGate();
    final Completer<void> cancellation = _cancelled;
    if (isRetry) {
      final int index = _deferred.indexWhere((request) => identical(request.$1, action) && request.$2 == source);
      if (index >= 0) _deferred.removeAt(index);
    }
    if (!isRetry) {
      _record(
        DeepLinkReceivedEvent(
          source: source,
          targetType: targetType,
          hasPayload: hasPayload ?? action is! UnknownIntent,
        ),
      );
    }
    // Save a referral before sign-in can claim it, even if another target is waiting on onboarding.
    final Future<DeepLinkRouteResolution>? referral = action is ReferLinkIntent
        ? _saveReferral(action, cancellation)
        : null;
    final Future<DeepLinkDispatchResult> result = _tail
        .then(
          (_) => _dispatch(
            action,
            source: source,
            isRetry: isRetry,
            resolved: referral,
            cancellation: cancellation,
            loadAction: loadAction,
            receivedTargetType: targetType,
          ),
        )
        .whenComplete(() {
          _pendingDispatches--;
          _updateDailyMomentGate();
        });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<DeepLinkRouteResolution> _saveReferral(ReferLinkIntent action, Completer<void> cancellation) async {
    if (await _untilDisposed(_whenBootstrapped(), cancelled: cancellation) != true) {
      return const DeepLinkRouteResolution.failure(AnalyticsReasonValue.userCancelled);
    }
    try {
      return await navigation.resolveAction(action);
    } catch (_) {
      return const DeepLinkRouteResolution.failure(AnalyticsReasonValue.error);
    }
  }

  void cancel() {
    for (final request in _deferred) {
      _record(
        DeepLinkNavigationResultEvent(
          targetType: TargetTypeValue.shortCode,
          source: request.$2,
          result: EventResultValue.cancelled,
          reason: AnalyticsReasonValue.userCancelled,
        ),
      );
    }
    _deferred.clear();
    _dailyMomentTarget = null;
    _cancelled.complete();
    _cancelled = Completer<void>();
    _updateDailyMomentGate();
  }

  void dispose() {
    if (_disposed.isCompleted) return;
    cancel();
    _router.removeListener(_onRouterChanged);
    _router.navigationHistory.removeListener(_onRouterChanged);
    if (identical(_instances[_router], this)) {
      _instances[_router] = null;
      DailyMomentPresentationGate.instance.deepLinkActive = false;
    }
    _disposed.complete();
  }

  Future<DeepLinkDispatchResult> _dispatch(
    DeepLinkActionEntity action, {
    required DeepLinkSourceValue source,
    required bool isRetry,
    required Completer<void> cancellation,
    Future<DeepLinkRouteResolution>? resolved,
    Future<DeepLinkActionEntity?> Function()? loadAction,
    required TargetTypeValue receivedTargetType,
  }) async {
    TargetTypeValue targetType = receivedTargetType;
    DeepLinkDispatchResult finish(DeepLinkDispatchResult result, {AnalyticsReasonValue? reason}) {
      if (result != DeepLinkDispatchResult.deferred) {
        _record(
          DeepLinkNavigationResultEvent(
            targetType: targetType,
            source: source,
            result: switch (result) {
              DeepLinkDispatchResult.navigated => EventResultValue.navigated,
              DeepLinkDispatchResult.blocked => EventResultValue.blocked,
              DeepLinkDispatchResult.cancelled => EventResultValue.cancelled,
              _ => EventResultValue.failure,
            },
            reason: reason,
          ),
        );
      }
      return result;
    }

    try {
      if (_disposed.isCompleted || cancellation.isCompleted) return finish(DeepLinkDispatchResult.cancelled);
      if (await _untilDisposed(_whenBootstrapped(), cancelled: cancellation) != true) {
        return finish(DeepLinkDispatchResult.cancelled);
      }
      if (loadAction != null) {
        final DeepLinkActionEntity? loaded = await _untilDisposed<DeepLinkActionEntity?>(
          loadAction(),
          cancelled: cancellation,
        );
        if (_disposed.isCompleted || cancellation.isCompleted) return finish(DeepLinkDispatchResult.cancelled);
        if (loaded != null) action = loaded;
        if (loaded != null) targetType = DeepLinkNavigation.targetType(action);
      }
      final bool opensOnboarding = action is PageLinkIntent && Uri.parse(action.path).path == '/onboarding/v2';
      final bool? ready = await _untilDisposed(
        opensOnboarding ? _whenOnboardingOrReady(cancellation) : _whenReady(),
        cancelled: cancellation,
      );
      if (ready != true) return finish(DeepLinkDispatchResult.cancelled);
      final DeepLinkRouteResolution? resolution = await _untilDisposed(
        resolved ?? navigation.resolveAction(action),
        cancelled: cancellation,
      );
      if (resolution == null) return finish(DeepLinkDispatchResult.cancelled);
      final PageRouteInfo? route = resolution.route;
      _record(
        DeepLinkResolvedEvent(
          targetType: targetType,
          source: source,
          result: route == null ? EventResultValue.failure : EventResultValue.success,
          reason: resolution.reason,
        ),
      );
      if (route == null && resolution.isNetwork && action is ShortCodeIntent && !isRetry && onRetryNeeded != null) {
        _deferred.add((action, source));
        onRetryNeeded!(action, source);
        final l10n = await loadDeviceAppLocalizations();
        toasts.info(l10n.appLinkRetryWhenOnline);
        return DeepLinkDispatchResult.deferred;
      }
      if (route == null) {
        if (source == DeepLinkSourceValue.push && action.rawUri.trim().isNotEmpty) {
          final l10n = await loadDeviceAppLocalizations();
          toasts.error(l10n.coreContentNotAvailable);
        }
        await _navigate(
          source == DeepLinkSourceValue.push ? const NotificationRoute() : const NotFoundRoute(),
          cancellation,
        );
        return finish(DeepLinkDispatchResult.failure, reason: resolution.reason);
      }
      if (opensOnboarding && _isVisible(route)) {
        _dailyMomentTarget = route;
        return finish(DeepLinkDispatchResult.navigated);
      }
      final DeepLinkDispatchResult result = await _navigate(route, cancellation);
      return finish(
        result,
        reason: result == DeepLinkDispatchResult.blocked ? AnalyticsReasonValue.notAuthorized : null,
      );
    } catch (_) {
      return finish(DeepLinkDispatchResult.failure, reason: AnalyticsReasonValue.error);
    }
  }

  Future<bool> _whenOnboardingOrReady(Completer<void> cancellation) async {
    bool ready() =>
        _router.stackData.any((route) => route.name == OnboardingV2ShellRoute.name) || !isStartingUp(_router);
    if (ready()) return true;
    final Completer<bool> done = Completer<bool>();
    void check() {
      if (ready() && !done.isCompleted) done.complete(true);
    }

    _router.addListener(check);
    try {
      return await _untilDisposed(done.future, cancelled: cancellation) ?? false;
    } finally {
      _router.removeListener(check);
    }
  }

  Future<DeepLinkDispatchResult> _navigate(PageRouteInfo route, Completer<void> cancellation) async {
    if (_disposed.isCompleted || cancellation.isCompleted) return DeepLinkDispatchResult.cancelled;
    NavigationFailure? failure;
    Future<bool>? continuation;
    // navigate completes after guard evaluation and insertion. push completes only when the page is popped.
    final bool? completed = await _untilDisposed(
      _router
          .navigate(
            route,
            onFailure: (error) {
              failure = error;
              continuation = AuthNavigationContinuation.of(_router).pendingNavigation;
            },
          )
          .then((_) => true),
      cancelled: cancellation,
    );
    if (completed != true) return DeepLinkDispatchResult.cancelled;
    if (continuation != null) {
      if (await _untilDisposed(continuation!, cancelled: cancellation) != true) {
        return AuthNavigationContinuation.of(_router).lastNavigationFailure is RejectedByGuardFailure
            ? DeepLinkDispatchResult.blocked
            : DeepLinkDispatchResult.cancelled;
      }
    } else if (failure != null) {
      return failure is RejectedByGuardFailure ? DeepLinkDispatchResult.blocked : DeepLinkDispatchResult.failure;
    }
    if (!_isVisible(route)) return DeepLinkDispatchResult.failure;
    _dailyMomentTarget = route;
    return DeepLinkDispatchResult.navigated;
  }

  bool _isVisible(PageRouteInfo route) {
    if (!_router.hasEntries) return false;
    final RouteData top = _router.topRoute;
    PageRouteInfo target = route;
    while (target.initialChildren?.isNotEmpty == true) {
      target = target.initialChildren!.last;
    }
    if (target.initialChildren == null &&
        target.args == null &&
        target.rawPathParams.isEmpty &&
        target.rawQueryParams.isEmpty &&
        _router.currentSegments.any((segment) => segment.name == target.routeName)) {
      return true;
    }
    return top.name == target.routeName &&
        (target.args == null || top.args == target.args) &&
        target.rawPathParams.entries.every(
          (entry) => top.params.rawMap[entry.key]?.toString() == entry.value.toString(),
        ) &&
        target.rawQueryParams.entries.every(
          (entry) => top.queryParams.rawMap[entry.key]?.toString() == entry.value.toString(),
        );
  }

  Future<T?> _untilDisposed<T>(Future<T> work, {Completer<void>? cancelled}) => Future.any<T?>(<Future<T?>>[
    work,
    _disposed.future.then<T?>((_) => null),
    if (cancelled != null) cancelled.future.then<T?>((_) => null),
  ]);

  void _record(AnalyticsEvent event) => unawaited(_track(event).catchError((Object _) {}));

  static WidgetKindValue? _widgetKind(Uri uri, DeepLinkActionEntity action) {
    if (uri.scheme.toLowerCase() != 'prism' || uri.userInfo.isNotEmpty || uri.hasFragment) return null;

    final Map<String, List<String>> query;
    try {
      query = uri.queryParametersAll;
    } on FormatException {
      return null;
    }

    final List<String>? values = query['widget'];
    if (values == null || values.length != 1) return null;
    final WidgetKindValue? kind = WidgetKindValue.values.where((value) => value.wireValue == values.single).firstOrNull;
    if (kind == null) return null;

    final String host = uri.host.toLowerCase();
    final bool shareLink = (host == 'share' && uri.path.isEmpty) || (host.isEmpty && uri.path == '/share');
    if (shareLink &&
        action is ShareLinkIntent &&
        const <WidgetKindValue>{
          WidgetKindValue.wotdSmall,
          WidgetKindValue.wotdMedium,
          WidgetKindValue.wotdLarge,
          WidgetKindValue.wotdLock,
        }.contains(kind) &&
        query['source']?.singleOrNull == 'prism' &&
        query['id']?.singleOrNull == action.wallId) {
      return kind;
    }

    if (_isStreakWidgetUri(uri) && query.keys.length == 1) {
      return kind;
    }

    return null;
  }

  static bool _isStreakWidgetUri(Uri uri) {
    final String host = uri.host.toLowerCase();
    return (host == 'streak' && uri.path.isEmpty) || (host.isEmpty && uri.path == '/streak');
  }
}
