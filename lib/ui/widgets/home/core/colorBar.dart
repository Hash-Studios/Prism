import 'package:Prism/routes/routing_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

class ColorBar extends StatelessWidget {
  const ColorBar({
    Key key,
    @required this.colors,
  }) : super(key: key);

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          colors == null ? 5 : colors.length,
          (color) {
            return GestureDetector(
              onLongPress: () {
                HapticFeedback.vibrate();
                Clipboard.setData(ClipboardData(
                  text: colors[color]
                      .toString()
                      .replaceAll("Color(0xff", "")
                      .replaceAll(")", ""),
                )).then((result) {
                  toasts.color(colors[color]);
                });
              },
              onTap: () {
                Future.delayed(const Duration())
                    .then((value) => Navigator.pushNamed(
                          context,
                          colorRoute,
                          arguments: [
                            colors[color]
                                .toString()
                                .replaceAll("Color(0xff", "")
                                .replaceAll(")", ""),
                          ],
                        ));
              },
              child: Container(
                decoration: BoxDecoration(
                  color: colors == null
                      ? Theme.of(context).accentColor.withOpacity(0.1)
                      : colors[color],
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
