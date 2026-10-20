import 'package:Prism/features/admin_review/biz/wall_moderation.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_signals.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _RecordingUrlLauncher extends UrlLauncherPlatform {
  final List<String> urls = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    return options.mode == PreferredLaunchMode.externalApplication;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const WallModeration _full = WallModeration(
  flags: <ModerationFlag>[
    ModerationFlag.unsafe,
    ModerationFlag.duplicate,
    ModerationFlag.webMatch,
    ModerationFlag.logo,
    ModerationFlag.text,
  ],
  duplicate: ModerationDuplicate(wallId: 'w9', similarity: 0.964, thumb: ''),
  web: <ModerationWebMatch>[
    ModerationWebMatch(url: 'https://backdrops.app/a', host: 'backdrops.app'),
    ModerationWebMatch(url: 'https://example.org/b', host: 'example.org'),
    ModerationWebMatch(url: 'https://example.net/c', host: 'example.net'),
  ],
  words: <String>['@someone', 'backdrops', 'hd'],
  logos: <String>['Nike', 'Adidas'],
  unsafe: <String>['adult', 'violence'],
);

void main() {
  Future<void> pump(WidgetTester tester, WallModeration? moderation, {bool onImage = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ModerationSignals(moderation: moderation, onImage: onImage),
          ),
        ),
      ),
    );
  }

  testWidgets('one pill per flag, most serious first, with the planned copy', (tester) async {
    await pump(tester, _full);

    final List<String> shown = <String>[
      'Unsafe: adult, violence',
      'Looks like a Prism wall · 96%',
      'Found on backdrops.app +2',
      'Logo: Nike',
      'Text: @someone backdrops',
    ];
    for (final String text in shown) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final List<double> tops = <double>[for (final String text in shown) tester.getTopLeft(find.text(text)).dy];
    expect(tops, orderedEquals(<double>[...tops]..sort()));
  });

  testWidgets('a single web match has no count', (tester) async {
    await pump(
      tester,
      const WallModeration(
        flags: <ModerationFlag>[ModerationFlag.webMatch],
        web: <ModerationWebMatch>[ModerationWebMatch(url: 'https://backdrops.app/a', host: 'backdrops.app')],
      ),
    );

    expect(find.text('Found on backdrops.app'), findsOneWidget);
  });

  testWidgets('only flagged signals get a pill', (tester) async {
    await pump(
      tester,
      const WallModeration(flags: <ModerationFlag>[ModerationFlag.logo], logos: <String>['Nike'], words: <String>['x']),
    );

    expect(find.text('Logo: Nike'), findsOneWidget);
    expect(find.textContaining('Text:'), findsNothing);
  });

  testWidgets('nothing renders when the wall was not checked or is clear', (tester) async {
    await pump(tester, null);
    expect(find.byType(Text), findsNothing);

    await pump(tester, const WallModeration(flags: <ModerationFlag>[]));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a pill is a button for screen readers', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pump(tester, _full);

    expect(
      tester.getSemantics(find.text('Logo: Nike')),
      matchesSemantics(label: 'Logo: Nike', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('a tap opens the sheet with every signal and the guidance', (tester) async {
    await pump(tester, _full);

    await tester.tap(find.text('Logo: Nike'));
    await tester.pumpAndSettle();

    expect(find.text('Review signals'), findsOneWidget);
    expect(find.text('These are hints. Check before you reject.'), findsOneWidget);
    expect(find.text('Unsafe categories'), findsOneWidget);
    expect(find.text('adult, violence'), findsOneWidget);
    expect(find.text('Similar Prism wall'), findsOneWidget);
    expect(find.text('ID: w9'), findsOneWidget);
    expect(find.text('96% similar'), findsOneWidget);
    expect(find.text('Found on the web'), findsOneWidget);
    for (final String host in <String>['backdrops.app', 'example.org', 'example.net']) {
      expect(find.text(host), findsOneWidget, reason: host);
    }
    expect(find.text('https://backdrops.app/a'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Text in the image'), 200);
    expect(find.text('Logos'), findsOneWidget);
    expect(find.text('Nike, Adidas'), findsOneWidget);
    expect(find.text('@someone backdrops hd'), findsOneWidget);
  });

  testWidgets('a web page row opens the url in the external browser', (tester) async {
    final _RecordingUrlLauncher launcher = _RecordingUrlLauncher();
    final UrlLauncherPlatform previous = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    await pump(tester, _full);

    await tester.tap(find.text('Logo: Nike'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('example.org'));
    await tester.pump();

    expect(launcher.urls, <String>['https://example.org/b']);
  });

  testWidgets('the sheet shows only what was found', (tester) async {
    await pump(tester, const WallModeration(flags: <ModerationFlag>[ModerationFlag.logo], logos: <String>['Nike']));

    await tester.tap(find.text('Logo: Nike'));
    await tester.pumpAndSettle();

    expect(find.text('Logos'), findsOneWidget);
    expect(find.text('Found on the web'), findsNothing);
    expect(find.text('Similar Prism wall'), findsNothing);
    expect(find.text('Text in the image'), findsNothing);
  });
}
