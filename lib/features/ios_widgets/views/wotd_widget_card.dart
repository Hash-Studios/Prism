import 'dart:async';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ios_widgets/views/widget_guide_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

/// A one-time card on Wall of the Day that points to the iOS Home Screen widget.
class WotdWidgetCard extends StatefulWidget {
  const WotdWidgetCard({super.key});

  @override
  State<WotdWidgetCard> createState() => _WotdWidgetCardState();
}

class _WotdWidgetCardState extends State<WotdWidgetCard> {
  // Off iOS the card never shows, so the stored flag is only read on iOS.
  late bool _dismissed =
      defaultTargetPlatform != TargetPlatform.iOS ||
      getIt<SettingsLocalDataSource>().get<bool>(PersistenceKeys.wotdWidgetCardDismissed, defaultValue: false);
  bool _supported = false;

  @override
  void initState() {
    super.initState();
    if (!_dismissed) unawaited(_checkSupport());
  }

  Future<void> _checkSupport() async {
    final bool supported = await iosSupportsWidgets();
    if (mounted && supported) setState(() => _supported = true);
  }

  void _dismiss() {
    unawaited(getIt<SettingsLocalDataSource>().set(PersistenceKeys.wotdWidgetCardDismissed, true));
    setState(() => _dismissed = true);
  }

  void _showGuide() {
    // The card stays mounted under the sheet, so the context stays valid for the hide that follows.
    unawaited(showWidgetGuideSheet(context, source: WidgetGuideSourceValue.wallOfTheDay));
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: context.motion(PrismDurations.fast),
      alignment: Alignment.topCenter,
      child: _dismissed || !_supported ? const SizedBox.shrink() : _card(context),
    );
  }

  Widget _card(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.widgets_rounded, color: cs.primary),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.widgetsCardTitle, style: PrismTextStyles.rowTitle(context)),
                    const SizedBox(height: PrismSpace.xxs),
                    Text(l10n.widgetsCardBody, style: PrismTextStyles.body(context)),
                  ],
                ),
              ),
              PrismIconButton(icon: Icons.close_rounded, tooltip: l10n.widgetsCardDismiss, onPressed: _dismiss),
            ],
          ),
          const SizedBox(height: PrismSpace.sm),
          PrismButton(label: l10n.widgetsCardAction, onPressed: _showGuide),
        ],
      ),
    );
  }
}
