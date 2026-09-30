import 'dart:async';

import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/purchases/subscription_tier.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/session/biz/bloc/session_bloc.j.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class AutoRotateSessionListener extends StatefulWidget {
  const AutoRotateSessionListener({required this.child, this.refreshTier, super.key});

  final Widget child;
  final Future<SubscriptionTier> Function()? refreshTier;

  @override
  State<AutoRotateSessionListener> createState() => _AutoRotateSessionListenerState();
}

class _AutoRotateSessionListenerState extends State<AutoRotateSessionListener> with WidgetsBindingObserver {
  bool _refreshInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncSession(context, context.read<SessionBloc>().state);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSession(context, context.read<SessionBloc>().state);
      unawaited(_refreshEntitlement());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SessionBloc, SessionState>(
          listenWhen: (previous, current) =>
              current.status == LoadStatus.success &&
              (previous.status != LoadStatus.success ||
                  previous.session.userId != current.session.userId ||
                  previous.session.loggedIn != current.session.loggedIn ||
                  previous.session.premium != current.session.premium),
          listener: (context, state) => _syncSession(context, state),
        ),
        BlocListener<FavouriteWallsBloc, FavouriteWallsState>(
          listenWhen: (previous, current) =>
              current.status == LoadStatus.success &&
              (previous.status != LoadStatus.success ||
                  previous.userId != current.userId ||
                  previous.items != current.items),
          listener: (context, state) {
            final SessionState session = context.read<SessionBloc>().state;
            if (kIsWeb ||
                defaultTargetPlatform != TargetPlatform.android ||
                session.status != LoadStatus.success ||
                !session.session.loggedIn ||
                session.session.userId != state.userId) {
              return;
            }
            context.read<AutoRotateBloc>().add(
              AutoRotateEvent.favouritesChanged(
                state.items.map((wallpaper) => wallpaper.fullUrl).toList(growable: false),
              ),
            );
          },
        ),
      ],
      child: widget.child,
    );
  }

  void _syncSession(BuildContext context, SessionState state) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || state.status != LoadStatus.success) {
      return;
    }
    context.read<AutoRotateBloc>().add(
      AutoRotateEvent.entitlementChanged(
        isPro: state.session.loggedIn && state.session.premium,
        userId: state.session.userId,
      ),
    );
    final FavouriteWallsState favourites = context.read<FavouriteWallsBloc>().state;
    if (state.session.loggedIn &&
        favourites.status == LoadStatus.success &&
        favourites.userId == state.session.userId) {
      context.read<AutoRotateBloc>().add(
        AutoRotateEvent.favouritesChanged(
          favourites.items.map((wallpaper) => wallpaper.fullUrl).toList(growable: false),
        ),
      );
    }
  }

  Future<void> _refreshEntitlement() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || _refreshInFlight) {
      return;
    }
    final AutoRotateState rotation = context.read<AutoRotateBloc>().state;
    if (!rotation.config.enabled && !rotation.status.isRunning) return;
    final SessionBloc sessionBloc = context.read<SessionBloc>();
    final SessionState before = sessionBloc.state;
    if (before.status != LoadStatus.success || !before.session.loggedIn) return;
    final String beforeUserId = app_state.prismUser.id;
    final bool beforeLoggedIn = app_state.prismUser.loggedIn;
    _refreshInFlight = true;
    try {
      final SubscriptionTier tier = await (widget.refreshTier ?? () => _fetchCurrentTier(before.session.userId))();
      if (!mounted) return;
      final SessionState current = sessionBloc.state;
      final user = app_state.prismUser;
      if (current.session.userId != before.session.userId ||
          current.session.loggedIn != before.session.loggedIn ||
          user.id != beforeUserId ||
          user.loggedIn != beforeLoggedIn ||
          user.id != before.session.userId ||
          user.loggedIn != before.session.loggedIn) {
        return;
      }
      user
        ..premium = tier.isPaid
        ..subscriptionTier = tier.name;
      await app_state.persistPrismUser();
      if (!mounted) return;
      final SessionState afterPersist = sessionBloc.state;
      final persistedUser = app_state.prismUser;
      if (afterPersist.session.userId != before.session.userId ||
          afterPersist.session.loggedIn != before.session.loggedIn ||
          persistedUser.id != beforeUserId ||
          persistedUser.loggedIn != beforeLoggedIn) {
        return;
      }
      sessionBloc.add(const SessionEvent.started());
    } catch (error, stackTrace) {
      logger.w(
        'Unable to refresh auto-rotate entitlement on resume.',
        tag: 'AutoRotate',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<SubscriptionTier> _fetchCurrentTier(String expectedUserId) async {
    if (await Purchases.appUserID != expectedUserId) {
      throw StateError('RevenueCat identity does not match the active session.');
    }
    await Purchases.invalidateCustomerInfoCache();
    final info = await Purchases.getCustomerInfo();
    if (await Purchases.appUserID != expectedUserId) {
      throw StateError('RevenueCat identity changed during entitlement refresh.');
    }
    return PurchasesService.instance.tierFromCustomerInfo(info);
  }
}
