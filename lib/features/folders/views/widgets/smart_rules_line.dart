import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/domain/entities/smart_rule.dart';
import 'package:Prism/features/folders/views/widgets/smart_folder_sheet.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The rules of a smart folder under its title. The owner gets "Edit rules".
class SmartRulesLine extends StatefulWidget {
  const SmartRulesLine({super.key, required this.rules, this.onEdit, this.loadCreatorNames});

  final List<SmartRule> rules;

  /// Null for anyone but the owner.
  final VoidCallback? onEdit;

  /// Creator uid to display name. Defaults to the public profiles.
  final Future<Map<String, String>> Function(List<String> uids)? loadCreatorNames;

  @override
  State<SmartRulesLine> createState() => _SmartRulesLineState();
}

class _SmartRulesLineState extends State<SmartRulesLine> {
  Map<String, String> _names = const <String, String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadNames());
  }

  @override
  void didUpdateWidget(SmartRulesLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rules != widget.rules) unawaited(_loadNames());
  }

  static Future<Map<String, String>> _profileNames(List<String> uids) async {
    final result = await getIt<PublicProfileRepository>().fetchUserSummariesPage(userIds: uids, page: 0);
    return <String, String>{
      for (final UserSummaryEntity user in result.data?.items ?? const <UserSummaryEntity>[])
        user.id: smartCreatorName(user),
    };
  }

  Future<void> _loadNames() async {
    final List<String> uids = <String>[
      for (final SmartRule rule in widget.rules)
        if (rule.kind == SmartRuleKind.creator && !_names.containsKey(rule.value)) rule.value,
    ];
    if (uids.isEmpty) return;
    try {
      final Map<String, String> names = await (widget.loadCreatorNames ?? _profileNames)(uids);
      if (mounted) setState(() => _names = <String, String>{..._names, ...names});
    } catch (_) {
      // The line keeps the generic "Creator" label.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String summary = smartRuleSummary(widget.rules, l10n, creatorNames: _names).join(' · ');
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            label: l10n.foldersSmartRulesLabel(summary),
            excludeSemantics: true,
            child: Row(
              key: const ValueKey<String>('smart-rules-line'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.auto_awesome_rounded, size: 16, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: PrismSpace.xs),
                Expanded(child: Text(summary, style: PrismTextStyles.body(context))),
              ],
            ),
          ),
          if (widget.onEdit != null) ...<Widget>[
            const SizedBox(height: PrismSpace.xs),
            PrismButton(
              key: const ValueKey<String>('smart-rules-edit'),
              label: l10n.foldersSmartEditRules,
              icon: Icons.tune_rounded,
              variant: PrismButtonVariant.tonal,
              size: PrismButtonSize.compact,
              onPressed: widget.onEdit,
            ),
          ],
        ],
      ),
    );
  }
}
