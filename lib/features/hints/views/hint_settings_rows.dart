import 'dart:async';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/hints/data/feature_hints.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// The Show tips switch in Settings.
class ShowTipsRow extends StatefulWidget {
  const ShowTipsRow({super.key});

  @override
  State<ShowTipsRow> createState() => _ShowTipsRowState();
}

class _ShowTipsRowState extends State<ShowTipsRow> {
  late bool _on = FeatureHints.instance.enabled;

  void _set(bool value) {
    setState(() => _on = value);
    unawaited(FeatureHints.instance.setEnabled(value));
  }

  @override
  Widget build(BuildContext context) => PrismSwitchRow(
    icon: Icons.lightbulb_outline_rounded,
    title: context.l10n.settingsShowTipsTitle,
    subtitle: context.l10n.settingsShowTipsBody,
    value: _on,
    onChanged: _set,
  );
}

/// Lets every tip show again.
class ResetTipsRow extends StatelessWidget {
  const ResetTipsRow({super.key});

  @override
  Widget build(BuildContext context) => PrismRow(
    icon: Icons.restart_alt_rounded,
    title: context.l10n.settingsResetTipsTitle,
    subtitle: context.l10n.settingsResetTipsBody,
    onTap: () async {
      final String done = context.l10n.settingsResetTipsDone;
      await FeatureHints.instance.reset();
      toasts.success(done);
    },
  );
}
