import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationsBloc extends MockBloc<InAppNotificationsEvent, InAppNotificationsState>
    implements InAppNotificationsBloc {}

void main() {
  for (final PrismThemeOption option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
    testWidgets('${option.label}: wordmark and logo read on the bar', (tester) async {
      final bloc = _MockNotificationsBloc();
      when(() => bloc.state).thenReturn(InAppNotificationsState.initial());
      await tester.pumpWidget(
        BlocProvider<InAppNotificationsBloc>.value(
          value: bloc,
          child: MaterialApp(
            theme: option.theme,
            home: const Scaffold(body: PrismTopAppBar()),
          ),
        ),
      );
      final Color bar = option.theme.colorScheme.surface;
      final Color ink = option.theme.colorScheme.onSurface;

      final Color wordmark = tester.widget<Text>(find.text('prism')).style!.color!;
      final ColorFilter logo = tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter!;

      expect(contrastRatio(wordmark, bar), greaterThanOrEqualTo(3), reason: 'wordmark');
      expect(find.byIcon(PrismIcons.dropdownCaret), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(logo, ColorFilter.mode(ink, BlendMode.srcIn), reason: 'logo');
      expect(contrastRatio(ink, bar), greaterThanOrEqualTo(4.5), reason: 'bell and logo ink');
    });
  }
}
