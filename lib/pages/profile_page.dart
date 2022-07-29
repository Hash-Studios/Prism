import 'package:firebase_auth/firebase_auth.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:logger_flutter/logger_flutter.dart';
import 'package:flutter/material.dart';
import 'package:prism/const/app_color.dart';
import 'package:prism/controllers/theme_controller.dart';
import 'package:prism/controllers/toast_controller.dart';
import 'package:prism/services/authentication_service.dart';
import 'package:prism/services/locator.dart';
import 'package:prism/services/wallhaven_service.dart';
import 'package:prism/widgets/app_bar_style_buttons.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  String explainAppBarStyle(final FlexAppBarStyle style, final bool isLight) {
    switch (style) {
      case FlexAppBarStyle.primary:
        return isLight ? 'Primary color - Default' : 'Primary color';
      case FlexAppBarStyle.material:
        return isLight
            ? 'White background'
            : 'Dark background (#121212) - Default';
      case FlexAppBarStyle.surface:
        return 'Surface, with primary color blend';
      case FlexAppBarStyle.background:
        return 'Background, with primary color blend';
      case FlexAppBarStyle.custom:
        return 'Built-in schemes use secondary variant color, '
            'but you can use any color';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StreamBuilder<User?>(
                stream: locator<AuthService>().authStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title:
                          Text(locator<AuthService>().prismUsersV2?.name ?? ''),
                      subtitle: Text(
                          locator<AuthService>().prismUsersV2?.email ?? ''),
                      onTap: () {
                        locator<AuthService>().signOutWithGoogle();
                      },
                    );
                  } else {
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text("Login to see your profile"),
                      onTap: () {
                        locator<AuthService>().signInWithGoogle();
                      },
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text("Launch debugger"),
                onTap: () {
                  LogConsole.openLogConsole(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text("Show toast"),
                onTap: () {
                  locator<ToastController>()
                      .messageToast("Happy if you read this!");
                  locator<ToastController>()
                      .errorToast("Sad if you read this!");
                },
              ),
              const Text(
                'Current theme index:',
              ),
              Text(
                '${context.read<ThemeController>().schemeIndex}',
                style: Theme.of(context).textTheme.headline4,
              ),
              SwitchListTile.adaptive(
                title: const Text('True Black'),
                value: context.read<ThemeController>().darkIsTrueBlack,
                onChanged: (value) {
                  context.read<ThemeController>().setDarkIsTrueBlack(value);
                },
              ),
              SwitchListTile.adaptive(
                title: const Text('True White'),
                value: context.read<ThemeController>().lightIsWhite,
                onChanged: (value) {
                  context.read<ThemeController>().setLightIsWhite(value);
                },
              ),
              SwitchListTile.adaptive(
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
              SwitchListTile.adaptive(
                title: const Text('Transparent Status bar'),
                value: context.read<ThemeController>().transparentStatusBar,
                onChanged:
                    context.read<ThemeController>().setTransparentStatusBar,
              ),
              SwitchListTile.adaptive(
                title: const Text('Transparent Bottom bar'),
                value: context
                        .read<ThemeController>()
                        .bottomNavigationBarOpacity ==
                    0.95,
                onChanged: (val) {
                  context
                      .read<ThemeController>()
                      .setBottomNavigationBarOpacity(val ? 0.95 : 1);
                },
              ),
              SwitchListTile.adaptive(
                  title: const Text('forBackground TabBar'),
                  value: context.read<ThemeController>().tabBarStyle ==
                      FlexTabBarStyle.forBackground,
                  onChanged: (value) {
                    value
                        ? context
                            .read<ThemeController>()
                            .setTabBarStyle(FlexTabBarStyle.forBackground)
                        : context
                            .read<ThemeController>()
                            .setTabBarStyle(FlexTabBarStyle.forAppBar);
                  }),
              if (isLight)
                ListTile(
                  title: const Text('Light mode color'),
                  subtitle: Text(
                    explainAppBarStyle(
                        context.read<ThemeController>().lightAppBarStyle,
                        isLight),
                  ),
                ),
              if (isLight)
                ListTile(
                  trailing: AppBarStyleButtons(
                      style: context.read<ThemeController>().lightAppBarStyle,
                      onChanged:
                          context.read<ThemeController>().setLightAppBarStyle,
                      // To access the custom color we defined for app bar, in this
                      // toggle buttons widget, we have to pass it in. It is not
                      // carried with the theme so we cannot get it from there in
                      // the widget. FlexColorScheme knows the color when
                      // you switch to it. This is just to be able to show the
                      // correct color on the 'custom' toggle button option. In our
                      // example we only actually only have a custom app bar color
                      // in the 1st custom color example, and we wanted to be
                      // able to show it on the toggle button.
                      customAppBarColor:
                          AppColor.scheme(context.read<ThemeController>())
                              .light
                              .appBarColor),
                ),
              ElevatedButton(
                  onPressed: () {
                    WallHavenService().getSearchResults();
                  },
                  child: const Text('Search'))
            ],
          ),
        ),
      ),
    );
  }
}
