import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Favourites and views for a wallpaper. A zero count is noise: views hide at 0, and the heart shows without a number
/// until someone favourites the wall. Screen readers still hear the favourite count.
///
/// With [onFavouriteTap] it is only the heart toggle for a wallpaper tile: a white 18 point glyph on a 32 point black
/// circle in a 44 point target, drawn on the image. Tiles show no counts.
class WallpaperStatsRow extends StatelessWidget {
  const WallpaperStatsRow({
    super.key,
    this.favourites,
    this.views,
    this.onFavouriteTap,
    this.favouriteEnabled = true,
    this.favouriteActionLabel,
    this.favouriteSaved = false,
    this.favouriteIcon,
  });

  final int? favourites;
  final int? views;
  final VoidCallback? onFavouriteTap;
  final bool favouriteEnabled;
  final String? favouriteActionLabel;
  final bool favouriteSaved;
  final IconData? favouriteIcon;

  @override
  Widget build(BuildContext context) {
    final int? safeFavourites = favourites != null && favourites! >= 0 ? favourites : null;
    final int? safeViews = views != null && views! > 0 ? views : null;
    if (safeFavourites == null && safeViews == null && onFavouriteTap == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final TextStyle style = PrismTextStyles.caption(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600);
    final formatter = NumberFormat.compact(locale: l10n.localeName)..maximumFractionDigits = 1;
    final favouriteLabel = safeFavourites == null ? null : l10n.wallpaperFavouriteCount(safeFavourites);
    final viewLabel = safeViews == null ? null : l10n.wallpaperViewCount(safeViews);
    final String? favouriteCount = safeFavourites == null || safeFavourites == 0
        ? null
        : formatter.format(safeFavourites);
    if (onFavouriteTap != null) {
      return Tooltip(
        message: favouriteActionLabel ?? '',
        child: Semantics(
          container: true,
          button: true,
          enabled: favouriteEnabled,
          toggled: favouriteSaved,
          label: <String?>[favouriteActionLabel, favouriteLabel].whereType<String>().join(', '),
          onTap: favouriteEnabled ? onFavouriteTap : null,
          child: ExcludeSemantics(
            // Its own transparent Material, so the ink shows over the image, not on the page under it.
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: favouriteEnabled ? onFavouriteTap : null,
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                      child: Icon(favouriteIcon ?? Icons.favorite_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final Widget favourite = Semantics(
      container: true,
      label: favouriteLabel,
      child: ExcludeSemantics(
        child: _Stat(
          icon: favouriteIcon ?? Icons.favorite_rounded,
          count: favouriteCount,
          iconColor: scheme.onSurfaceVariant,
          style: style,
        ),
      ),
    );

    return Row(
      children: [
        if (safeFavourites != null) Flexible(child: favourite),
        if (safeFavourites != null && safeViews != null) const SizedBox(width: 4),
        if (safeViews != null)
          Flexible(
            child: Semantics(
              container: true,
              label: viewLabel,
              child: ExcludeSemantics(
                child: _Stat(
                  icon: Icons.bar_chart_rounded,
                  count: formatter.format(safeViews),
                  iconColor: scheme.onSurfaceVariant,
                  style: style,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.count, required this.iconColor, required this.style});

  final IconData? icon;
  final String? count;
  final Color iconColor;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 17, color: iconColor), if (count != null) const SizedBox(width: 4)],
      if (count != null)
        Flexible(
          child: Text(count!, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
    ],
  );
}
