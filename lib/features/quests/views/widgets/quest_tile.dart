import 'dart:math' as math;

import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/quests/domain/quest_board.dart';
import 'package:Prism/features/quests/views/widgets/quest_palette.dart';
import 'package:flutter/material.dart';

const double _lip = 4;
const double _stickerSize = 56;
const double _stickerOverhang = 4;

const double _stickerTilt = -6 * math.pi / 180;
final double _stickerTiltSpill = _stickerSize * (math.cos(_stickerTilt) + math.sin(-_stickerTilt) - 1) / 2;
const double _ribbonOverhang = 8;
const double _barHeight = 20;
const double _chipHeight = 22;

/// One quest as a raised game panel. [endsIn] is the weekly ribbon's countdown, such as "4d 2h".
class QuestTile extends StatelessWidget {
  const QuestTile({super.key, required this.quest, this.endsIn});

  final QuestTileModel quest;
  final String? endsIn;

  bool get _weekly => quest.scope == QuestScope.weekly;

  String get _semanticsLabel {
    final QuestReward reward = quest.reward;
    final List<String> pays = <String>[
      if (reward.coins > 0) '${reward.coins} ${reward.coins == 1 ? 'coin' : 'coins'}',
      if (reward.xp > 0) '${reward.xp} XP',
    ];
    return <String>[
      '${quest.info.title}, ${quest.done ? 'done' : '${quest.progress} of ${quest.target}'}',
      if (pays.isNotEmpty) 'Pays ${pays.join(' and ')}',
      if (_weekly) 'This week${endsIn == null ? '' : ', ends in $endsIn'}',
    ].join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final QuestPalette palette = QuestPalette.of(Theme.of(context).colorScheme);
    final PanelColors panel = palette.panelFor(quest);
    return Semantics(
      container: true,
      label: _semanticsLabel,
      excludeSemantics: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.5,
        child: Padding(
          padding: EdgeInsets.only(left: _stickerOverhang + _stickerTiltSpill, top: _weekly ? _ribbonOverhang : 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              CustomPaint(
                painter: _PanelPainter(colors: panel, gloss: palette.gloss),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, PrismSpace.sm, PrismSpace.sm, PrismSpace.sm + _lip),
                  child: Row(
                    children: <Widget>[
                      Transform.translate(
                        offset: const Offset(-_stickerOverhang, 0),
                        child: _Sticker(icon: quest.info.icon, ink: panel.ink, done: quest.done),
                      ),
                      const SizedBox(width: PrismSpace.sm),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _OutlinedText(
                              quest.info.title.toUpperCase(),
                              style: PrismTextStyles.rowTitle(context).copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                height: 1.1,
                                color: palette.title,
                              ),
                              ink: panel.ink,
                              stroke: 3,
                              drop: 2,
                              maxLines: 2,
                            ),
                            const SizedBox(height: PrismSpace.xs),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _ProgressBar(quest: quest, palette: palette, ink: panel.ink),
                                ),
                                const SizedBox(width: PrismSpace.xs),
                                _Badges(reward: quest.reward, ink: panel.ink, textColor: palette.title),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_weekly)
                Positioned(
                  top: -_ribbonOverhang,
                  right: PrismSpace.sm,
                  child: _Ribbon(
                    label: endsIn == null ? 'WEEKLY' : 'WEEKLY · $endsIn',
                    fill: palette.ribbon,
                    ink: panel.ink,
                    textColor: palette.title,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelPainter extends CustomPainter {
  const _PanelPainter({required this.colors, required this.gloss});

  final PanelColors colors;
  final Color gloss;

  static const double _slant = 4;
  static const double _radius = 14;
  static const double _outline = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final double height = size.height - _lip;
    final double skew = _slant / height;
    const double inset = _outline / 2;
    final Path upright = Path()
      ..addRRect(
        RRect.fromLTRBR(inset, inset, size.width - _slant - inset, height - inset, const Radius.circular(_radius)),
      );
    final Path panel = upright.transform(
      (Matrix4.identity()
            ..setEntry(0, 1, -skew)
            ..setEntry(0, 3, skew * height))
          .storage,
    );
    final Path slab = panel.shift(const Offset(0, _lip));
    final Paint outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _outline
      ..strokeJoin = StrokeJoin.round
      ..color = colors.ink;
    final Rect body = Rect.fromLTWH(0, 0, size.width, height);

    canvas
      ..drawPath(slab, Paint()..color = colors.lip)
      ..drawPath(slab, outline)
      ..drawPath(
        panel,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[colors.top, colors.bottom],
          ).createShader(body),
      )
      ..save()
      ..clipPath(panel)
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, height * 0.4),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[gloss, gloss.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, height * 0.4)),
      )
      ..restore()
      ..drawPath(panel, outline);
  }

  @override
  bool shouldRepaint(_PanelPainter old) => old.colors != colors || old.gloss != gloss;
}

class _Sticker extends StatelessWidget {
  const _Sticker({required this.icon, required this.ink, required this.done});

  final IconData icon;
  final Color ink;
  final bool done;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _stickerSize,
    height: _stickerSize,
    child: Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Transform.rotate(
          angle: _stickerTilt,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.white, Color.lerp(Colors.white, ink, 0.16)!],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ink, width: 2),
              boxShadow: <BoxShadow>[BoxShadow(color: ink, offset: const Offset(0, 3))],
            ),
            child: SizedBox.expand(child: Icon(icon, size: 30, color: ink)),
          ),
        ),
        Positioned(
          right: -8,
          bottom: -6,
          child: _DoneStamp(done: done, ink: ink),
        ),
      ],
    ),
  );
}

class _DoneStamp extends StatelessWidget {
  const _DoneStamp({required this.done, required this.ink});

  final bool done;
  final Color ink;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: done ? 1 : 0,
    duration: context.motion(PrismDurations.base),
    curve: PrismCurves.enter,
    child: AnimatedScale(
      scale: done ? 1 : 0.8,
      duration: context.motion(PrismDurations.base),
      curve: PrismCurves.pop,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PrismColors.success,
          shape: BoxShape.circle,
          border: Border.all(color: ink, width: 2),
        ),
        child: const SizedBox(width: 26, height: 26, child: Icon(Icons.check_rounded, size: 16, color: Colors.white)),
      ),
    ),
  );
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.label, required this.fill, required this.ink, required this.textColor});

  final String label;
  final Color fill;
  final Color ink;
  final Color textColor;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.15,
    child: Transform.rotate(
      angle: 3 * math.pi / 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ink, width: 2),
          boxShadow: <BoxShadow>[BoxShadow(color: ink, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: 2),
          child: _OutlinedText(
            label,
            style: PrismTextStyles.rowTitle(
              context,
            ).copyWith(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4, height: 1.1, color: textColor),
            ink: ink,
            stroke: 2.5,
            maxLines: 1,
          ),
        ),
      ),
    ),
  );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.quest, required this.palette, required this.ink});

  final QuestTileModel quest;
  final QuestPalette palette;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = PrismTextStyles.rowTitle(
      context,
    ).copyWith(fontSize: 12, fontWeight: FontWeight.w700, height: 1.1, color: palette.title);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _barHeight),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: quest.fraction),
        duration: context.motion(PrismDurations.base),
        curve: PrismCurves.enter,
        builder: (BuildContext context, double fraction, Widget? count) => CustomPaint(
          painter: _BarPainter(
            fraction: fraction,
            ink: ink,
            fillTop: palette.fillTop,
            fillBottom: palette.fillBottom,
            gloss: palette.gloss,
          ),
          child: count,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: quest.done
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: palette.title,
                        shadows: <Shadow>[
                          for (final Offset side in const <Offset>[
                            Offset(-1, 0),
                            Offset(1, 0),
                            Offset(0, -1),
                            Offset(0, 1),
                          ])
                            Shadow(color: ink, offset: side),
                        ],
                      ),
                      const SizedBox(width: PrismSpace.xxs / 2),
                      _OutlinedText('DONE', style: style, ink: ink, stroke: 3, maxLines: 1),
                    ],
                  )
                : _OutlinedText('${quest.progress}/${quest.target}', style: style, ink: ink, stroke: 3, maxLines: 1),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.fraction,
    required this.ink,
    required this.fillTop,
    required this.fillBottom,
    required this.gloss,
  });

  final double fraction;
  final Color ink;
  final Color fillTop;
  final Color fillBottom;
  final Color gloss;

  static const double _inset = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect track = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    final Rect shade = Rect.fromLTWH(0, 0, size.width, 6);
    canvas
      ..drawRRect(track, Paint()..color = ink)
      ..save()
      ..clipRRect(track)
      ..drawRect(
        shade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.black.withValues(alpha: 0.4), Colors.black.withValues(alpha: 0)],
          ).createShader(shade),
      )
      ..restore();
    if (fraction <= 0) return;
    final Rect inner = Rect.fromLTWH(_inset, _inset, (size.width - 2 * _inset) * fraction, size.height - 2 * _inset);
    final RRect fill = RRect.fromRectAndRadius(inner, const Radius.circular(4));
    final RRect stripe = RRect.fromLTRBR(
      inner.left + 3,
      inner.top + 1.5,
      math.max(inner.left + 3, inner.right - 3),
      inner.top + inner.height / 2,
      const Radius.circular(2),
    );
    canvas
      ..drawRRect(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[fillTop, fillBottom],
          ).createShader(inner),
      )
      ..drawRRect(stripe, Paint()..color = gloss);
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fraction != fraction ||
      old.ink != ink ||
      old.fillTop != fillTop ||
      old.fillBottom != fillBottom ||
      old.gloss != gloss;
}

class _Badges extends StatelessWidget {
  const _Badges({required this.reward, required this.ink, required this.textColor});

  final QuestReward reward;
  final Color ink;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle number = PrismTextStyles.rowTitle(
      context,
    ).copyWith(fontSize: 13, fontWeight: FontWeight.w700, height: 1.1, color: textColor);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (reward.coins > 0)
          _Chip(ink: ink, label: '${reward.coins}', style: number, badge: const PrismCoinIcon(size: 16)),
        if (reward.coins > 0 && reward.xp > 0) const SizedBox(width: PrismSpace.xxs),
        if (reward.xp > 0)
          _Chip(
            ink: ink,
            label: '${reward.xp}',
            style: number,
            badge: _XpTag(ink: ink),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.ink, required this.label, required this.style, required this.badge});

  final Color ink;
  final String label;
  final TextStyle style;
  final Widget badge;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: _chipHeight),
    child: DecoratedBox(
      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(7)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            badge,
            const SizedBox(width: PrismSpace.xxs),
            Text(label, style: style, maxLines: 1),
          ],
        ),
      ),
    ),
  );
}

class _XpTag extends StatelessWidget {
  const _XpTag({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.skewX(-0.2),
    child: DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Text(
          'XP',
          style: PrismTextStyles.rowTitle(
            context,
          ).copyWith(fontSize: 9, fontWeight: FontWeight.w800, height: 1.1, color: ink),
        ),
      ),
    ),
  );
}

class _OutlinedText extends StatelessWidget {
  const _OutlinedText(
    this.text, {
    required this.style,
    required this.ink,
    required this.stroke,
    this.drop = 0,
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final Color ink;
  final double stroke;
  final double drop;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeJoin = StrokeJoin.round
            ..color = ink,
          shadows: drop == 0 ? null : <Shadow>[Shadow(color: ink, offset: Offset(0, drop))],
        ),
      ),
      Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style),
    ],
  );
}
