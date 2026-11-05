// Device QA entry point for Open on computer: the real share sheet and its sheet, with light/dark and text-size toggles.
// Run: fvm flutter run -t test/qa_render/open_on_computer_device_main.dart -d <simulator>
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

import '../support/fake_app_analytics.dart';

const String _thumb =
    'https://img.prismwalls.com/previews/da265bf3de2423c0ed2dd15e26ad7c830aa1ffaf32111c47580ab445b1b139ad.img';
const String _shortLink = 'https://prismwalls.com/l/cPefbCBh';

class _QaAnalytics extends FakeAppAnalytics {}

final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AnalyticsRuntime.instance = _QaAnalytics();
  app_state.prismUser = app_constants.createGuestPrismUser()
    ..id = 'qa-user'
    ..name = 'Mira'
    ..loggedIn = true;
  toasts.overlayResolver = () => _navigator.currentState?.overlay;
  runApp(const _QaApp());
}

class _QaApp extends StatefulWidget {
  const _QaApp();

  @override
  State<_QaApp> createState() => _QaAppState();
}

class _QaAppState extends State<_QaApp> {
  ThemeMode _mode = ThemeMode.light;
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: kLightTheme,
      darkTheme: kDarkTheme,
      themeMode: _mode,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_scale)),
        child: child!,
      ),
      home: _QaHome(
        onMode: (ThemeMode mode) => setState(() => _mode = mode),
        onScale: (double scale) => setState(() => _scale = scale),
      ),
    );
  }
}

class _QaHome extends StatelessWidget {
  const _QaHome({required this.onMode, required this.onScale});

  final ValueChanged<ThemeMode> onMode;
  final ValueChanged<double> onScale;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.network(_thumb, fit: BoxFit.cover),
          SafeArea(
            child: Column(
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    FilledButton.tonal(onPressed: () => onMode(ThemeMode.light), child: const Text('QA light')),
                    FilledButton.tonal(onPressed: () => onMode(ThemeMode.dark), child: const Text('QA dark')),
                    FilledButton.tonal(onPressed: () => onScale(1), child: const Text('QA 1x')),
                    FilledButton.tonal(onPressed: () => onScale(2), child: const Text('QA 2x')),
                  ],
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => showShareSheet(
                    context,
                    ShareCardContent(
                      imageUrl: _thumb,
                      link: _shortLink,
                      brandName: 'Prism',
                      creator: '@prismstudio',
                      creatorLine: 'by @prismstudio',
                      computerLink: Uri.parse('$_shortLink?d=1'),
                    ),
                    'wallpaper_screen',
                  ),
                  child: const Text('QA share'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
