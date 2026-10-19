import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/painters/foil_sheen_painter.dart';
import 'package:Prism/features/drops/views/painters/guilloche_painter.dart';
import 'package:Prism/features/drops/views/painters/lock_seal_painter.dart';
import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// "01 / 08": the place of a wall in its Drop, like the serial of a numbered print.
String dropSerial(int index, int count) =>
    '${(index + 1).toString().padLeft(2, '0')} / ${count.toString().padLeft(2, '0')}';

/// "W42" from "2026-W42".
String dropWeekLabel(String weekKey) => weekKey.contains('-') ? weekKey.split('-').last : weekKey;

/// Coins saved by the pack against buying each wall left one by one. Zero when the pack is not cheaper.
int packSaving(DropEntity drop, {required int remaining, required bool isPro}) {
  if (remaining <= 1) return 0;
  final int saving = remaining * drop.wallPrice(isPro: isPro) - drop.packPrice(remaining: remaining, isPro: isPro);
  return saving > 0 ? saving : 0;
}

/// The gold for a heading that sits on the page, not on obsidian: deep gold on a light page keeps its contrast.
Color dropEyebrowColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? DropPalette.gold : DropPalette.goldOnLight;

/// Small tracked gold caps, used for eyebrows and serials on obsidian.
TextStyle dropCapsStyle({double size = 11, Color color = DropPalette.gold, double spacing = 2.2}) => TextStyle(
  fontFamily: PrismFonts.proximaNova,
  fontSize: size,
  fontWeight: FontWeight.w700,
  letterSpacing: spacing,
  color: color,
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

/// Near-black obsidian with guilloche engraving, a hairline gold edge and a slow sheen of light.
class DropSurface extends StatelessWidget {
  const DropSurface({super.key, required this.child, this.radius = PrismRadius.lg, this.sheen = true});

  final Widget child;
  final double radius;
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    final BorderRadius corners = BorderRadius.circular(radius);
    Widget body = RepaintBoundary(
      child: CustomPaint(
        painter: const GuillochePainter(color: DropPalette.engraving),
        child: child,
      ),
    );
    if (sheen) body = FoilSheen(color: DropPalette.sheen, child: body);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: corners,
        border: Border.all(color: DropPalette.hairlineStrong, width: 0.8),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: corners,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[DropPalette.obsidianRaised, DropPalette.obsidian, DropPalette.obsidianDeep],
          ),
        ),
        child: ClipRRect(borderRadius: corners, child: body),
      ),
    );
  }
}

/// The engraved round seal that stands in for a "Locked" chip. [struck] is for a missed wall.
class DropSeal extends StatelessWidget {
  const DropSeal({super.key, this.size = 44, this.struck = false});

  final double size;
  final bool struck;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: LockSealPainter(
            color: struck ? DropPalette.inkMuted : DropPalette.gold,
            fill: DropPalette.obsidian.withValues(alpha: 0.72),
            struck: struck,
          ),
        ),
      ),
    );
  }
}

/// Time left as tabular "06d 17h 23m". [DropPhase.lastCall] turns it [DropPalette.urgent] and adds "Last call".
class DropCountdown extends StatelessWidget {
  const DropCountdown({super.key, required this.drop, required this.now, this.digitSize = 26});

  final DropEntity drop;
  final DateTime now;
  final double digitSize;

  static String parts(AppLocalizations l10n, DropEntity drop, DateTime now, String locale) {
    final Duration left = drop.endsAt.difference(now);
    final NumberFormat twoDigits = NumberFormat('00', locale);
    if (left <= Duration.zero) return l10n.economyDropCountdownHoursMinutes('00', '00');
    final String hours = twoDigits.format(left.inHours % 24);
    final String minutes = twoDigits.format(left.inMinutes % 60);
    final String hm = l10n.economyDropCountdownHoursMinutes(hours, minutes);
    return left.inDays > 0 ? l10n.economyDropCountdownDaysHours(twoDigits.format(left.inDays), hm) : hm;
  }

  @override
  Widget build(BuildContext context) {
    final bool urgent = drop.phaseAt(now) == DropPhase.lastCall;
    final Color color = urgent ? DropPalette.urgent : DropPalette.ink;
    final TextStyle digits = TextStyle(
      fontFamily: PrismFonts.fraunces,
      fontSize: digitSize,
      fontWeight: FontWeight.w600,
      height: 1,
      color: color,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final String countdown = parts(context.l10n, drop, now, Localizations.localeOf(context).toLanguageTag());
    return Semantics(
      label: urgent
          ? context.l10n.economyDropLastCall(drop.endsInLabel(context.l10n, now))
          : drop.endsInLabel(context.l10n, now),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              urgent ? context.l10n.economyDropLastCallLabel : context.l10n.economyDropEndsInLabel,
              style: dropCapsStyle(size: 10, spacing: 1.8, color: urgent ? DropPalette.urgent : DropPalette.inkMuted),
            ),
            const SizedBox(height: 6),
            Text(countdown, key: const ValueKey<String>('drop.countdown'), style: digits),
          ],
        ),
      ),
    );
  }
}

/// A serial in the top corner of a tile, with a shadow so it reads on any image.
class DropSerialTag extends StatelessWidget {
  const DropSerialTag({required this.serial});

  final String serial;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: const EdgeInsets.all(PrismSpace.sm),
        child: Text(
          serial,
          style: dropCapsStyle(
            size: 10,
            spacing: 1.2,
            color: DropPalette.goldLight,
          ).copyWith(shadows: const <Shadow>[Shadow(color: DropPalette.obsidian, blurRadius: 6)]),
        ),
      ),
    );
  }
}
