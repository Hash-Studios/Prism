import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/layout_prefs/views/layout_prefs_scope.dart';
import 'package:Prism/features/navigation/views/widgets/account_controls.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Home tab's top bar, in the style of X: the profile on the left, the prism wordmark in the centre and the
/// notifications on the right. The feed screen puts it in the floating header. With one-handed controls on, the profile
/// and the notifications move to the bottom bar and only the wordmark stays.
class PrismTopAppBar extends StatelessWidget {
  const PrismTopAppBar({super.key});

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final bool oneHanded = LayoutPrefsScope.oneHandedOf(context);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (!oneHanded) const Align(alignment: AlignmentDirectional.centerStart, child: ProfileAvatarButton()),
            const _Wordmark(),
            if (!oneHanded)
              const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: NotificationBell(source: NotificationsEntrySourceValue.top),
              ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      header: true,
      label: context.l10n.wallpaperHomeAppName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SvgPicture.string(prismVector, width: 11, height: 13, colorFilter: ColorFilter.mode(ink, BlendMode.srcIn)),
          const SizedBox(width: 6),
          Text(
            context.l10n.appTitle.toLowerCase(),
            style: PrismTextStyles.brandName.copyWith(fontSize: 18, color: ink),
          ),
        ],
      ),
    );
  }
}
