import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockNotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

void main() {
  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser()..profilePhoto = '';
  });
  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
  });

  Future<void> pumpBar(WidgetTester tester, {int unread = 0, VoidCallback? onLogoTap}) async {
    final bloc = _MockNotificationsBloc();
    when(() => bloc.state).thenReturn(InAppNotificationsState.initial().copyWith(unreadCount: unread));
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<InAppNotificationsBloc>.value(
          value: bloc,
          child: Scaffold(appBar: PrismTopAppBar(onLogoTap: onLogoTap ?? () {})),
        ),
      ),
    );
  }

  testWidgets('the top bar is 56 high with the wordmark in the text colour', (tester) async {
    await pumpBar(tester);

    expect(
      tester.getSize(find.byType(PrismTopAppBar)).height,
      56 + tester.view.padding.top / tester.view.devicePixelRatio,
    );
    final Text wordmark = tester.widget(find.text('prism'));
    expect(wordmark.style?.color, Theme.of(tester.element(find.text('prism'))).colorScheme.onSurface);
  });

  testWidgets('the bell, wordmark and avatar keep their screen reader labels', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester);

    for (final label in ['Open notifications', 'Feed settings', 'Your profile']) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
      );
    }
    handle.dispose();
  });

  testWidgets('an unread notification draws the accent dot and says so', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBar(tester, unread: 2);

    expect(tester.getSemantics(find.bySemanticsLabel('Open notifications')).hint, 'Has unread items');
    final dots = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color ==
                  Theme.of(tester.element(find.text('prism'))).colorScheme.primary,
        );
    expect(dots, hasLength(1));
    handle.dispose();
  });

  testWidgets('tapping the wordmark opens the feed settings', (tester) async {
    var taps = 0;
    await pumpBar(tester, onLogoTap: () => taps++);

    await tester.tap(find.text('prism'));
    expect(taps, 1);
  });

  group('create sheet', () {
    Future<void> pumpSheet(WidgetTester tester, {required bool premium}) async {
      getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
      app_state.prismUser = app_constants.createGuestPrismUser()..premium = premium;
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UploadBottomPanel())));
    }

    testWidgets('offers an upload and an AI wallpaper, and shows the weekly quota to free users', (tester) async {
      await pumpSheet(tester, premium: false);

      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Upload a wallpaper'), findsOneWidget);
      expect(find.text('AI wallpaper'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('3 of 3 free uploads left this week'), findsOneWidget);
      expect(find.textContaining('original, high-quality wallpapers'), findsOneWidget);
    });

    testWidgets('premium users do not see the quota line', (tester) async {
      await pumpSheet(tester, premium: true);

      expect(find.textContaining('free uploads left'), findsNothing);
      expect(find.text('Upload a wallpaper'), findsOneWidget);
    });
  });
}
