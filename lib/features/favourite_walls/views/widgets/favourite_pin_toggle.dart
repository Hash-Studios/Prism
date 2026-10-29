import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether the favourite [wallId] is pinned, from the loaded Favourites list. False when the list has not loaded it.
bool isFavouritePinned(BuildContext context, String wallId) =>
    context.read<FavouriteWallsBloc>().state.items.any((FavouriteWallEntity wall) => wall.id == wallId && wall.pinned);

/// Pins the favourite [wallId] to the top of Favourites, or unpins it, and tells the user how it went.
Future<void> toggleFavouritePin(
  BuildContext context,
  String wallId, {
  required bool pin,
  required FavouritePinSurfaceValue surface,
}) async {
  final AppLocalizations l10n = context.l10n;
  final FavouritePinOutcome outcome = await context.favouriteWallsAdapter(listen: false).setPinned(wallId, pinned: pin);
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
