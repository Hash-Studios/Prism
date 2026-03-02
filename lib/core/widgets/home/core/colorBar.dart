import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ColorBar extends StatelessWidget {
  const ColorBar({super.key, required this.colors, this.fixedHeight});

  final List<Color?>? colors;

  /// When set, the color bar uses this height instead of expanding with flex.
  /// Use in bottom sheets so the scrollable content can take remaining space.
  final double? fixedHeight;

  @override
  Widget build(BuildContext context) {
    final circleSize = fixedHeight != null
        ? (fixedHeight! * 0.7).clamp(32.0, 56.0)
        : MediaQuery.of(context).size.width / 8;
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(colors == null ? 5 : colors!.length, (color) {
        return GestureDetector(
          onLongPress: () {
            HapticFeedback.vibrate();
            Clipboard.setData(
              ClipboardData(text: colors![color].toString().replaceAll("Color(0xff", "").replaceAll(")", "")),
            ).then((result) {
              toasts.color(colors![color]!);
            });
          },
          onTap: () {
            Future.delayed(Duration.zero).then(
              (value) => context.router.push(
                ColorRoute(hexColor: colors![color].toString().replaceAll("Color(0xff", "").replaceAll(")", "")),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: colors == null ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : colors![color],
              shape: BoxShape.circle,
            ),
            height: circleSize,
            width: circleSize,
          ),
        );
      }),
    );
    if (fixedHeight != null) {
      return SizedBox(height: fixedHeight, child: row);
    }
    return Expanded(flex: 3, child: row);
  }
}
