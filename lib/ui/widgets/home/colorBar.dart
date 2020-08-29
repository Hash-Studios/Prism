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
      flex: 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          colors == null ? 5 : colors.length,
          (color) {
            return GestureDetector(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors == null ? Color(0xFF000000) : colors[color],
                    borderRadius: BorderRadius.circular(500),
                  ),
                  height: MediaQuery.of(context).size.width / 8,
                  width: MediaQuery.of(context).size.width / 8,
                ),
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
                  SystemChrome.setEnabledSystemUIOverlays(
                      [SystemUiOverlay.top, SystemUiOverlay.bottom]);
                  Future.delayed(Duration(seconds: 0))
                      .then((value) => Navigator.pushNamed(
                            context,
                            ColorRoute,
                            arguments: [
                              colors[color]
                                  .toString()
                                  .replaceAll("Color(0xff", "")
                                  .replaceAll(")", ""),
                            ],
                          ));
                });
          },
        ),
      ),
    );
  }
}
