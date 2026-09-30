import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

final RegExp _trailingEmoji = RegExp(r'[\s\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}‍️]+$', unicode: true);

/// [title] without the emoji the server appends ("Wall approved ✅" becomes "Wall approved").
String cleanNotificationTitle(String title) {
  final String cleaned = title.replaceAll(_trailingEmoji, '');
  return cleaned.isEmpty ? title : cleaned;
}

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
  const NotificationIconTile({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ({IconData icon, PrismTone tone}) v = notificationVisual(title, body);
    final Color base = switch (v.tone) {
      PrismTone.neutral => cs.onSurface,
      PrismTone.accent => cs.primary,
      PrismTone.success => PrismColors.success,
      PrismTone.warning => PrismColors.warning,
      PrismTone.danger => cs.error,
    };
    final Color fg = v.tone == PrismTone.neutral
        ? cs.onSurface.withValues(alpha: 0.8)
        : Color.lerp(base, cs.onSurface, 0.25)!;
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: base.withValues(alpha: v.tone == PrismTone.neutral ? 0.08 : 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(v.icon, size: 20, color: fg),
      ),
    );
  }
}

/// A 6 point dot that marks an unread notification.
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
    );
  }
}
