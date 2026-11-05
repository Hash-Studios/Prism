import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Favourites and views for a wallpaper. A zero count is noise: views hide at 0, and the heart shows without a number
/// until someone favourites the wall. Screen readers still hear the favourite count.
///
/// With [onFavouriteTap] the heart is a 44 point toggle whose 20 point glyph sits on the leading edge, so it lines up
/// with the tile above it.
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
    this.favouriteIconColor,
  });

  final int? favourites;
  final int? views;
  final VoidCallback? onFavouriteTap;
  final bool favouriteEnabled;
  final String? favouriteActionLabel;
  final bool favouriteSaved;
  final IconData? favouriteIcon;
  final Color? favouriteIconColor;

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
    final Widget favourite = onFavouriteTap == null
        ? Semantics(
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
          )
        : Tooltip(
            message: favouriteActionLabel ?? '',
            child: Semantics(
              container: true,
              button: true,
              enabled: favouriteEnabled,
              toggled: favouriteSaved,
              label: <String?>[favouriteActionLabel, favouriteLabel].whereType<String>().join(', '),
              onTap: favouriteEnabled ? onFavouriteTap : null,
              child: ExcludeSemantics(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: favouriteEnabled ? onFavouriteTap : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: 1,
                      heightFactor: 1,
                      child: _Stat(
                        icon: favouriteIcon ?? Icons.favorite_rounded,
                        count: favouriteCount,
                        iconColor: favouriteIconColor ?? scheme.onSurfaceVariant,
                        iconSize: 20,
                        gap: 5,
                        style: style,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

    return Row(
      children: [
        if (safeFavourites != null || onFavouriteTap != null) Flexible(child: favourite),
        if ((safeFavourites != null || onFavouriteTap != null) && safeViews != null) const SizedBox(width: 4),
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
  const _Stat({
    required this.icon,
    required this.count,
    required this.iconColor,
    required this.style,
    this.iconSize = 17,
    this.gap = 4,
  });

  final IconData? icon;
  final String? count;
  final Color iconColor;
  final TextStyle style;
  final double iconSize;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: iconSize, color: iconColor), if (count != null) SizedBox(width: gap)],
      if (count != null)
        Flexible(
          child: Text(count!, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
    ],
  );
}
