import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

final RegExp _trailingEmoji = RegExp(r'[\s\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}‍️]+$', unicode: true);

/// [title] without the emoji the server appends ("Wall approved ✅" becomes "Wall approved").
String cleanNotificationTitle(String title) {
  final String cleaned = title.replaceAll(_trailingEmoji, '');
  return cleaned.isEmpty ? title : cleaned;
}

final RegExp _gapBeforeEmoji = RegExp(
  r'\s+([\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}]\uFE0F?)$',
  unicode: true,
);

/// [text] with a no-break space before a trailing emoji, so the emoji never wraps onto a line of its own.
String glueTrailingEmoji(String text) => text.replaceFirstMapped(_gapBeforeEmoji, (Match m) => '\u00A0${m[1]}');

/// Icon and tone that show what kind of notification [title] and [body] are.
({IconData icon, PrismTone tone}) notificationVisual(String title, String body) {
  final String t = title.toLowerCase();
  if (t.contains('reject')) return (icon: Icons.cancel_rounded, tone: PrismTone.danger);
  if (t.contains('streak')) return (icon: Icons.local_fire_department_rounded, tone: PrismTone.warning);
  if (t.contains('report')) return (icon: Icons.flag_rounded, tone: PrismTone.neutral);
  final String b = body.toLowerCase();
  if (t.contains('follow') || b.contains('following you') || b.contains('followed you')) {
    return (icon: Icons.person_add_rounded, tone: PrismTone.accent);
  }
  if (t.contains('wall') && t.contains('approv')) return (icon: Icons.check_circle_rounded, tone: PrismTone.success);
  if (b.contains('is now live') && b.contains(' by ')) {
    return (icon: Icons.photo_library_rounded, tone: PrismTone.neutral);
  }
  if (t.contains('wall of the day')) return (icon: Icons.wb_sunny_rounded, tone: PrismTone.accent);
  return (icon: Icons.notifications_rounded, tone: PrismTone.neutral);
}

/// The round 40 point tile at the start of a notification row. Its icon shows the type.
class NotificationIconTile extends StatelessWidget {
  const NotificationIconTile({super.key, required this.title, required this.body, this.unread = false});

  final String title;
  final String body;

  /// Draws the unread dot on the top end of the tile.
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ({IconData icon, PrismTone tone}) v = notificationVisual(title, body);
    // A generic bell has no type of its own, so it takes the accent. Other neutral icons (report, gallery) stay grey.
    final bool genericBell = v.icon == Icons.notifications_rounded;
    final Color base = switch (v.tone) {
      PrismTone.neutral => genericBell ? cs.primary : cs.onSurface,
      PrismTone.accent => cs.primary,
      PrismTone.success => PrismColors.success,
      PrismTone.warning => PrismColors.warning,
      PrismTone.danger => cs.error,
    };
    final bool grey = v.tone == PrismTone.neutral && !genericBell;
    final Color fg = grey ? cs.onSurface.withValues(alpha: 0.8) : Color.lerp(base, cs.onSurface, 0.25)!;
    return ExcludeSemantics(
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: base.withValues(alpha: grey ? 0.08 : 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(v.icon, size: 20, color: fg),
            ),
            if (unread) const PositionedDirectional(top: -2, end: -2, child: UnreadDot(size: 10, ring: true)),
          ],
        ),
      ),
    );
  }
}

/// A dot that marks an unread notification. With [ring] it has a 2 point ring in the page colour, to sit on an icon.
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key, this.size = 6, this.ring = false});

  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary,
        shape: BoxShape.circle,
        border: ring ? Border.all(color: cs.surface, width: 2) : null,
      ),
    );
  }
}

/// Wallpaper previews at the end of a notification row. One url gives a 44x78 phone-ratio thumbnail. Two or three
/// (a gallery or a group) give a strip of smaller thumbnails with the same ratio.
class NotificationThumbs extends StatelessWidget {
  const NotificationThumbs({super.key, required this.urls});

  final List<String> urls;

  static const double thumbWidth = 44;
  static const double thumbHeight = 78;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<String> shown = urls.take(3).toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();
    final bool strip = shown.length > 1;
    final double w = strip ? 30 : thumbWidth;
    final double h = strip ? 54 : thumbHeight;
    final int cacheWidth = (w * MediaQuery.devicePixelRatioOf(context)).round();
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < shown.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(strip ? PrismRadius.sm : PrismRadius.md),
              child: SizedBox(
                width: w,
                height: h,
                child: CachedNetworkImage(
                  imageUrl: shown[i],
                  fit: BoxFit.cover,
                  memCacheWidth: cacheWidth,
                  placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHigh),
                  errorWidget: (_, _, _) => ColoredBox(
                    color: cs.surfaceContainerHigh,
                    child: Center(child: Icon(JamIcons.picture, color: cs.onSurfaceVariant, size: 16)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
