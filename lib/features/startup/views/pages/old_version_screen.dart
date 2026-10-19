import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Blocking screen for app builds below the minimum supported version.
class OldVersion extends StatelessWidget {
  const OldVersion({super.key});

  String get _storeLink => defaultTargetPlatform == TargetPlatform.iOS ? appStoreUrl : playStoreUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Glint(mood: GlintMood.worried, size: 120),
                        const SizedBox(height: PrismSpace.lg),
                        Text(
                          context.l10n.wallpaperOldVersionTitle,
                          textAlign: TextAlign.center,
                          style: PrismTextStyles.display(context),
                        ),
                        const SizedBox(height: PrismSpace.sm),
                        Text(
                          context.l10n.wallpaperOldVersionBody(
                            '${app_state.currentAppVersion}+${app_state.currentAppVersionCode}',
                          ),
                          textAlign: TextAlign.center,
                          style: PrismTextStyles.body(context).copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PrismButton(
                label: context.l10n.wallpaperUpdatePrism,
                expand: true,
                onPressed: () {
                  openPrismLink(context, _storeLink);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
