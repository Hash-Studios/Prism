import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/views/widgets/full_screen_image_view.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_bits.dart';
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
    required this.onReject,
    this.onToggleReserve,
    this.reserved = false,
  });

  final String previewUrl;
  final String fullUrl;

  /// Label and value pairs shown beside the thumbnail.
  final List<(String, String)> facts;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  /// Reserves the wall for the next weekly Drop, or undoes it. Null hides the button.
  final Future<void> Function()? onToggleReserve;
  final bool reserved;

  @override
  State<ModerationCard> createState() => _ModerationCardState();
}

class _ModerationCardState extends State<ModerationCard> {
  bool _isApproving = false;
  bool _isApproved = false;
  String? _approvalError;
  bool _isReserving = false;

  Future<void> _toggleReserve() async {
    if (_isReserving) return;
    setState(() => _isReserving = true);
    try {
      await widget.onToggleReserve!();
    } catch (error, stackTrace) {
      logger.e('Admin drop reserve failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      toasts.error('Could not update the Drop reserve. Try again.');
    } finally {
      if (mounted) setState(() => _isReserving = false);
    }
  }

  Future<void> _approve() async {
    if (_isApproving || _isApproved) return;
    setState(() {
      _isApproving = true;
      _approvalError = null;
    });
    try {
      await widget.onApprove();
      if (mounted) setState(() => _isApproved = true);
    } catch (error, stackTrace) {
      logger.e('Admin approval failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _approvalError = 'Approval failed. Check your connection, then try again.');
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
                  semanticLabel: 'View full wallpaper',
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
                  label: 'Retry',
                  variant: PrismButtonVariant.ghost,
                  size: PrismButtonSize.compact,
                  onPressed: _isApproving ? null : _approve,
                ),
              ],
            ),
          ],
          const SizedBox(height: PrismSpace.sm),
          Row(
            children: <Widget>[
              PrismIconButton(
                icon: Icons.open_in_full_rounded,
                tooltip: 'View full wallpaper',
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
                    ModerationDangerButton(label: 'Reject', onPressed: locked ? null : widget.onReject),
                    if (widget.onToggleReserve != null)
                      PrismButton(
                        label: widget.reserved ? 'Unreserve' : 'Reserve',
                        variant: PrismButtonVariant.tonal,
                        size: PrismButtonSize.compact,
                        loading: _isReserving,
                        onPressed: locked ? null : _toggleReserve,
                      ),
                    PrismButton(
                      label: _isApproved ? 'Approved' : 'Approve',
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
