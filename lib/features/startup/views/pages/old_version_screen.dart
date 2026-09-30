import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
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
                        Text('Time to update', textAlign: TextAlign.center, style: PrismTextStyles.display(context)),
                        const SizedBox(height: PrismSpace.sm),
                        Text(
                          'Version ${app_state.currentAppVersion}+${app_state.currentAppVersionCode} is no longer '
                          'supported. Update Prism to keep using it.',
                          textAlign: TextAlign.center,
                          style: PrismTextStyles.body(context).copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PrismButton(label: 'Update Prism', expand: true, onPressed: () => openPrismLink(context, _storeLink)),
            ],
          ),
        ),
      ),
    );
  }
}
