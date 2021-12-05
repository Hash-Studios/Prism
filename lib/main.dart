import 'package:auto_route/auto_route.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:prism/const/app_color.dart';
import 'package:prism/const/app_data.dart';
import 'package:prism/controllers/theme_controller.dart';
import 'package:prism/controllers/wallhaven_controller.dart';
import 'package:prism/router/app_router.dart';
import 'package:prism/router/route_observer.dart';
import 'package:prism/services/locator.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  final ThemeController themeController = ThemeController();
  await themeController.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => themeController,
        ),
        ChangeNotifierProvider(
          create: (_) => WallHavenController(),
        ),
      ],
      child: Phoenix(
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final _appRouter = locator<AppRouter>();
    return MaterialApp.router(
      routerDelegate: AutoRouterDelegate(
        _appRouter,
        navigatorObservers: () => [AppRouteObserver()],
      ),
      routeInformationParser: _appRouter.defaultRouteParser(),
      title: 'Prism',
      theme: themeController.useFlexColorScheme
          ? FlexThemeData.light(
              colors: AppColor.scheme(themeController).light,
              surfaceMode: themeController.surfaceMode,
              blendLevel: themeController.blendLevel,
              appBarStyle: themeController.lightAppBarStyle,
              appBarOpacity: themeController.appBarOpacity,
              appBarElevation: themeController.appBarElevation,
              transparentStatusBar: themeController.transparentStatusBar,
              tabBarStyle: themeController.tabBarStyle,
              tooltipsMatchBackground: themeController.tooltipsMatchBackground,
              swapColors: themeController.swapLightColors,
              lightIsWhite: themeController.lightIsWhite,
              useSubThemes: themeController.useSubThemes,
              visualDensity: AppData.visualDensity,
              fontFamily: AppData.font,
              platform: themeController.platform,
              subThemesData: FlexSubThemesData(
                useTextTheme: themeController.useTextTheme,
                defaultRadius: themeController.useDefaultRadius
                    ? null
                    : themeController.cornerRadius,
                fabUseShape: themeController.fabUseShape,
                interactionEffects: themeController.interactionEffects,
                bottomNavigationBarOpacity:
                    themeController.bottomNavigationBarOpacity,
                bottomNavigationBarElevation:
                    themeController.bottomNavigationBarElevation,
                inputDecoratorIsFilled: themeController.inputDecoratorIsFilled,
                inputDecoratorBorderType:
                    themeController.inputDecoratorBorderType,
                inputDecoratorUnfocusedHasBorder:
                    themeController.inputDecoratorUnfocusedHasBorder,
                blendOnColors: themeController.blendLightOnColors,
                blendTextTheme: themeController.blendLightTextTheme,
                popupMenuOpacity: 0.96,
              ),
            )
          : ThemeData.from(
              textTheme: ThemeData(
                brightness: Brightness.light,
              ).textTheme,
              colorScheme: FlexColorScheme.light(
                colors: AppColor.scheme(themeController).light,
                surfaceMode: themeController.surfaceMode,
                blendLevel: themeController.blendLevel,
                swapColors: themeController.swapLightColors,
                lightIsWhite: themeController.lightIsWhite,
              ).toScheme,
            ).copyWith(
              visualDensity: AppData.visualDensity,
              typography: Typography.material2018(
                platform: themeController.platform,
              ),
            ),
      darkTheme: themeController.useFlexColorScheme
          ? FlexThemeData.dark(
              colors: AppColor.scheme(themeController).dark,
              surfaceMode: themeController.surfaceMode,
              blendLevel: themeController.blendLevel,
              appBarStyle: themeController.darkAppBarStyle,
              appBarOpacity: themeController.appBarOpacity,
              appBarElevation: themeController.appBarElevation,
              transparentStatusBar: themeController.transparentStatusBar,
              tabBarStyle: themeController.tabBarStyle,
              tooltipsMatchBackground: themeController.tooltipsMatchBackground,
              swapColors: themeController.swapDarkColors,
              darkIsTrueBlack: themeController.darkIsTrueBlack,
              useSubThemes: themeController.useSubThemes,
              visualDensity: AppData.visualDensity,
              fontFamily: AppData.font,
              platform: themeController.platform,
              subThemesData: FlexSubThemesData(
                useTextTheme: themeController.useTextTheme,
                defaultRadius: themeController.useDefaultRadius
                    ? null
                    : themeController.cornerRadius,
                fabUseShape: themeController.fabUseShape,
                interactionEffects: themeController.interactionEffects,
                bottomNavigationBarOpacity:
                    themeController.bottomNavigationBarOpacity,
                bottomNavigationBarElevation:
                    themeController.bottomNavigationBarElevation,
                inputDecoratorIsFilled: themeController.inputDecoratorIsFilled,
                inputDecoratorBorderType:
                    themeController.inputDecoratorBorderType,
                inputDecoratorUnfocusedHasBorder:
                    themeController.inputDecoratorUnfocusedHasBorder,
                blendOnColors: themeController.blendDarkOnColors,
                blendTextTheme: themeController.blendDarkTextTheme,
                popupMenuOpacity: 0.95,
              ),
            )
          : ThemeData.from(
              textTheme: ThemeData(
                brightness: Brightness.dark,
              ).textTheme,
              colorScheme: FlexColorScheme.dark(
                colors: AppColor.scheme(themeController).dark,
                surfaceMode: themeController.surfaceMode,
                blendLevel: themeController.blendLevel,
                swapColors: themeController.swapDarkColors,
                darkIsTrueBlack: themeController.darkIsTrueBlack,
              ).toScheme,
            ).copyWith(
              visualDensity: AppData.visualDensity,
              typography: Typography.material2018(
                platform: themeController.platform,
              ),
            ),
      themeMode: themeController.themeMode,
    );
  }
}
