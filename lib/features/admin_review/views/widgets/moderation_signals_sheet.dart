import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/wall_moderation.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_bits.dart' show ModerationThumb;
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

/// Every signal the server check found, with its detail. They are hints for the admin, not a verdict.
Future<void> showModerationSignalsSheet(BuildContext context, WallModeration moderation) {
  return showPrismSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ModerationSignalsSheet(moderation: moderation),
  );
}

class _ModerationSignalsSheet extends StatelessWidget {
  const _ModerationSignalsSheet({required this.moderation});

  final WallModeration moderation;

  Future<void> _openPage(BuildContext context, ModerationWebMatch match) async {
    final String failed = context.l10n.adminModerationOpenFailed;
    bool opened = false;
    try {
      opened = await openPrismLink(context, match.url, mode: LaunchMode.externalApplication);
    } catch (error, stackTrace) {
      logger.w('Opening a web match failed.', tag: 'AdminReview', error: error, stackTrace: stackTrace);
    }
    if (!opened) toasts.error(failed);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ModerationDuplicate? duplicate = moderation.duplicate;
    final List<Widget> sections = <Widget>[
      if (moderation.unsafe.isNotEmpty)
        _Section(title: l10n.adminModerationUnsafeCategories, child: _Words(moderation.unsafe.join(', '))),
      if (duplicate != null)
        _Section(
          title: l10n.adminModerationSimilarWall,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (duplicate.thumb.isNotEmpty) ...<Widget>[
                ModerationThumb(
                  url: duplicate.thumb,
                  width: 72,
                  height: 128,
                  semanticLabel: l10n.adminModerationSimilarWall,
                ),
                const SizedBox(width: PrismSpace.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Words(l10n.adminFactLabel(l10n.adminWallId, duplicate.wallId)),
                    _Words(l10n.adminModerationSimilarity(duplicate.percent)),
                  ],
                ),
              ),
            ],
          ),
        ),
      if (moderation.web.isNotEmpty)
        _Section(
          title: l10n.adminModerationWebPages,
          child: Column(
            children: <Widget>[
              for (final ModerationWebMatch match in moderation.web)
                Semantics(
                  button: true,
                  label: l10n.adminModerationOpenPage(match.host),
                  excludeSemantics: true,
                  child: PrismRow(
                    padding: const EdgeInsets.symmetric(vertical: PrismSpace.xs),
                    icon: Icons.language_rounded,
                    title: match.host,
                    subtitle: match.url,
                    trailing: Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                    onTap: () => _openPage(context, match),
                  ),
                ),
            ],
          ),
        ),
      if (moderation.logos.isNotEmpty)
        _Section(title: l10n.adminModerationLogos, child: _Words(moderation.logos.join(', '))),
      if (moderation.words.isNotEmpty)
        _Section(title: l10n.adminModerationTextInImage, child: _Words(moderation.words.join(' '))),
    ];
    return PrismSheetBody(
      title: l10n.adminModerationSignals,
      message: l10n.adminModerationHint,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < sections.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: PrismSpace.md),
            sections[i],
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(header: true, child: Text(title, style: PrismTextStyles.rowTitle(context))),
        const SizedBox(height: PrismSpace.xs),
        child,
      ],
    );
  }
}

class _Words extends StatelessWidget {
  const _Words(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: PrismTextStyles.body(context));
}
