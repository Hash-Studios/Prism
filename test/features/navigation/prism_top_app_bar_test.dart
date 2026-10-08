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
    testWidgets('${option.label}: wordmark, caret, logo and bell read on the bar', (tester) async {
      final bloc = _MockNotificationsBloc();
      when(() => bloc.state).thenReturn(InAppNotificationsState.initial());
      await tester.pumpWidget(
        BlocProvider<InAppNotificationsBloc>.value(
          value: bloc,
          child: MaterialApp(
            theme: option.theme,
            home: Scaffold(appBar: PrismTopAppBar(onLogoTap: () {})),
          ),
        ),
      );
      final Color bar = option.theme.primaryColor;

      final Color wordmark = tester.widget<Text>(find.text('prism')).style!.color!;
      final Color caret = tester.widget<Icon>(find.byIcon(PrismIcons.dropdownCaret)).color!;
      final Color bell = tester.widget<Icon>(find.byIcon(PrismIcons.notificationBell)).color!;
      final ColorFilter logo = tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter!;

      expect(contrastRatio(wordmark, bar), greaterThanOrEqualTo(3), reason: 'wordmark');
      expect(contrastRatio(caret, bar), greaterThanOrEqualTo(3), reason: 'caret');
      expect(contrastRatio(Color.alphaBlend(bell, bar), bar), greaterThanOrEqualTo(3), reason: 'bell');
      expect(logo, ColorFilter.mode(onColor(bar), BlendMode.srcIn), reason: 'logo');
    });
  }
}
