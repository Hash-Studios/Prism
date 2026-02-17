import 'package:auto_route/auto_route.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ColorBar extends StatelessWidget {
  const ColorBar({
    super.key,
    required this.colors,
  });

  final List<Color?>? colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          colors == null ? 5 : colors!.length,
          (color) {
            return GestureDetector(
              onLongPress: () {
                HapticFeedback.vibrate();
                Clipboard.setData(ClipboardData(
                  text: colors![color].toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                )).then((result) {
                  toasts.color(colors![color]!);
                });
              },
              onTap: () {
                Future.delayed(Duration.zero).then((value) => context.router.push(ColorRoute(arguments: [
                      colors![color].toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                    ])));
              },
              child: Container(
                decoration: BoxDecoration(
                  color:
                      colors == null ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : colors![color],
                  shape: BoxShape.circle,
                ),
                height: MediaQuery.of(context).size.width / 8,
                width: MediaQuery.of(context).size.width / 8,
              ),
            );
          },
        ),
      ),
    );
  }
}
