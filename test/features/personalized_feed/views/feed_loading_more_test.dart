import 'package:Prism/core/widgets/prism_loader.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loading more shows the looping Prism mark, centred, with no spinner', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Column(children: <Widget>[FeedLoadingMore(columns: 3)])),
      ),
    );

    final Finder loader = find.byType(PrismLoader);
    expect(loader, findsOneWidget);
    expect(tester.widget<PrismLoader>(loader).progress, isNull);
    expect(tester.getCenter(loader).dx, 300);
    expect(tester.getSize(loader), const Size.square(28));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.hasRunningAnimations, isTrue);
  });
}
