import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:prism/controllers/theme_controller.dart';
import 'package:provider/provider.dart';

class WallsPage extends StatelessWidget {
  const WallsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Current theme index:',
              ),
              Text(
                '${context.read<ThemeController>().schemeIndex}',
                style: Theme.of(context).textTheme.headline4,
              ),
              SwitchListTile(
                title: const Text('True Black'),
                value: context.read<ThemeController>().darkIsTrueBlack,
                onChanged: (value) {
                  context.read<ThemeController>().setDarkIsTrueBlack(value);
                },
              ),
              SwitchListTile(
                title: const Text('True White'),
                value: context.read<ThemeController>().lightIsWhite,
                onChanged: (value) {
                  context.read<ThemeController>().setLightIsWhite(value);
                },
              ),
              SwitchListTile(
                title: const Text('Level Surfaces'),
                value: context.read<ThemeController>().surfaceMode ==
                    FlexSurfaceMode.levelSurfacesLowScaffold,
                onChanged: (value) {
                  context.read<ThemeController>().setSurfaceMode(value
                      ? FlexSurfaceMode.levelSurfacesLowScaffold
                      : FlexSurfaceMode.highScaffoldLowSurface);
                  value
                      ? context.read<ThemeController>().setBlendLevel(30)
                      : context.read<ThemeController>().setBlendLevel(18);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
