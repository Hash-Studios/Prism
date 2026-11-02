import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/wall_moderation.dart';
import 'package:Prism/features/admin_review/views/widgets/full_screen_image_view.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_bits.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_signals.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// A pending wallpaper: its thumbnail, who sent it, and Approve or Reject. Studio walls can also go to the Drop.
class ModerationCard extends StatefulWidget {
  const ModerationCard({
    super.key,
    required this.previewUrl,
    required this.fullUrl,
    required this.facts,
    required this.onApprove,
    this.onApproveAndPick,
    required this.onReject,
    this.onToggleReserve,
    this.reserved = false,
    this.moderation,
    this.details,
  });

  final String previewUrl;
  final String fullUrl;

  /// Label and value pairs shown beside the thumbnail.
  final List<(String, String)> facts;
  final Future<void> Function() onApprove;

  /// Approves the wall and sets it as an Editors' Choice pick. Null hides the button.
  final Future<void> Function()? onApproveAndPick;
  final Future<void> Function() onReject;

  /// Reserves the wall for the next weekly Drop, or undoes it. Null hides the button.
  final Future<void> Function()? onToggleReserve;
  final bool reserved;

  /// The server check. Null when the wall was not checked yet.
  final WallModeration? moderation;
  final Widget? details;

  @override
  State<ModerationCard> createState() => _ModerationCardState();
}

class _ModerationCardState extends State<ModerationCard> {
  bool _isApproving = false;
  bool _isApproved = false;
  String? _approvalError;
  Future<void> Function()? _approvalAction;
  bool _isReserving = false;

  Future<void> _toggleReserve() async {
    if (_isReserving) return;
    final AppLocalizations l10n = context.l10n;
    setState(() => _isReserving = true);
    try {
      await widget.onToggleReserve!();
    } catch (error, stackTrace) {
      logger.e('Admin drop reserve failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      toasts.error(l10n.adminReserveUpdateFailed);
    } finally {
      if (mounted) setState(() => _isReserving = false);
    }
  }

  Future<void> _approve() => _runApproval(widget.onApprove);

  Future<void> _approveAndPick() => _runApproval(widget.onApproveAndPick!);

  Future<void> _runApproval(Future<void> Function() action) async {
    if (_isApproving || _isApproved) return;
    _approvalAction = action;
    setState(() {
      _isApproving = true;
      _approvalError = null;
    });
    try {
      await action();
      if (mounted) setState(() => _isApproved = true);
    } catch (error, stackTrace) {
      logger.e('Admin approval failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _approvalError = context.l10n.adminApprovalFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final VoidCallback? openFull = widget.fullUrl.isEmpty
        ? null
        : () => FullScreenImageView.show(context, widget.fullUrl);
    final bool locked = _isApproving || _isApproved;
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.previewUrl.isNotEmpty) ...<Widget>[
                ModerationThumb(
                  url: widget.previewUrl,
                  width: 96,
                  height: 170,
                  semanticLabel: context.l10n.adminViewFullWallpaper,
                  onTap: openFull,
                ),
                const SizedBox(width: PrismSpace.sm),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: PrismSpace.xxs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final (String label, String value) in widget.facts)
                        ModerationFact(label: label, value: value),
                      ModerationSignals(moderation: widget.moderation, onImage: false),
                      if (widget.details != null) widget.details!,
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_approvalError != null) ...<Widget>[
            const SizedBox(height: PrismSpace.sm),
            Row(
              children: <Widget>[
                Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
                const SizedBox(width: PrismSpace.xs),
                Expanded(
                  child: Text(_approvalError!, style: PrismTextStyles.body(context).copyWith(color: cs.error)),
                ),
                PrismButton(
                  label: context.l10n.adminRetry,
                  variant: PrismButtonVariant.ghost,
                  size: PrismButtonSize.compact,
                  onPressed: _isApproving ? null : () => _approvalAction?.call(),
                ),
              ],
            ),
          ],
          const SizedBox(height: PrismSpace.sm),
          Row(
            children: <Widget>[
              PrismIconButton(
                icon: Icons.open_in_full_rounded,
                tooltip: context.l10n.adminViewFullWallpaper,
                filled: true,
                onPressed: openFull,
              ),
              const SizedBox(width: PrismSpace.xs),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: PrismSpace.xs,
                  runSpacing: PrismSpace.xs,
                  children: <Widget>[
                    ModerationDangerButton(label: context.l10n.adminReject, onPressed: locked ? null : widget.onReject),
                    if (widget.onToggleReserve != null)
                      PrismButton(
                        label: widget.reserved ? context.l10n.adminUnreserve : context.l10n.adminReserve,
                        variant: PrismButtonVariant.tonal,
                        size: PrismButtonSize.compact,
                        loading: _isReserving,
                        onPressed: locked ? null : _toggleReserve,
                      ),
                    if (widget.onApproveAndPick != null)
                      PrismButton(
                        label: context.l10n.adminApproveAndPick,
                        size: PrismButtonSize.compact,
                        variant: PrismButtonVariant.tonal,
                        icon: Icons.auto_awesome_rounded,
                        loading: _isApproving,
                        onPressed: locked ? null : _approveAndPick,
                      ),
                    PrismButton(
                      label: _isApproved ? context.l10n.adminApproved : context.l10n.adminApprove,
                      size: PrismButtonSize.compact,
                      loading: _isApproving,
                      onPressed: locked ? null : _approve,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
