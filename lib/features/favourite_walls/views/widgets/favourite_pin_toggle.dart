import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reads the pin state when the current user's Favourites list is loaded. Null means unknown or not a favourite.
bool? currentFavouritePinState(BuildContext context, String key) {
  final FavouriteWallsState? state = context.read<FavouriteWallsBloc?>()?.state;
  if (state == null || state.status != LoadStatus.success || state.userId != app_state.prismUser.id) return null;
  return state.items.where((wall) => wall.key == key).firstOrNull?.pinned;
}

/// Whether the loaded favourite with [key] (see [favouriteKey]) is pinned.
bool isFavouritePinned(BuildContext context, String key) =>
    context.read<FavouriteWallsBloc>().state.items.any((FavouriteWallEntity wall) => wall.key == key && wall.pinned);

/// Pins the favourite with [key] to the top of Favourites, or unpins it, and tells the user how it went.
Future<void> toggleFavouritePin(
  BuildContext context,
  String key, {
  required bool pin,
  required FavouritePinSurfaceValue surface,
}) async {
  if (!await requireSignedInAction(context) || !context.mounted) return;
  final AppLocalizations l10n = context.l10n;
  final FavouritePinOutcome outcome = await context.favouriteWallsAdapter(listen: false).setPinned(key, pinned: pin);
  switch (outcome) {
    case FavouritePinOutcome.done:
      PrismHaptics.selection();
      unawaited(analytics.track(FavouritePinChangedEvent(pinned: pin, surface: surface)));
      toasts.success(pin ? l10n.favouritePinnedToast : l10n.favouriteUnpinnedToast, haptic: false);
    case FavouritePinOutcome.limit:
      unawaited(analytics.track(FavouritePinLimitHitEvent(surface: surface)));
      toasts.error(l10n.favouritePinLimit(maxPinnedFavourites));
    case FavouritePinOutcome.failed:
      toasts.error(l10n.favouritePinFailed);
  }
}
