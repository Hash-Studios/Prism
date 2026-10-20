import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/reject_reasons.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';

/// Asks for a reason, then runs [onSubmit] with it. The sheet stays open, with the reason kept, when saving fails.
Future<void> showRejectReasonSheet(
  BuildContext context, {
  required Future<void> Function(String reason) onSubmit,
  String? title,
  String? confirmLabel,
}) {
  return showPrismSheet<void>(
    context,
    swipeDismissible: false,
    dismissKeyboardOnDrag: true,
    builder: (_) => _RejectReasonSheet(
      title: title ?? context.l10n.adminRejectWallpaper,
      confirmLabel: confirmLabel ?? context.l10n.adminRejectWallpaper,
      onSubmit: onSubmit,
    ),
  );
}

class _RejectReasonSheet extends StatefulWidget {
  const _RejectReasonSheet({required this.title, required this.confirmLabel, required this.onSubmit});

  final String title;
  final String confirmLabel;
  final Future<void> Function(String reason) onSubmit;

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;
  RejectReason? _picked;

  String _reasonLabel(RejectReason reason) => switch (reason) {
    RejectReason.lowResolution => context.l10n.adminReasonLowResolution,
    RejectReason.watermark => context.l10n.adminReasonWatermark,
    RejectReason.blurry => context.l10n.adminReasonBlurry,
    RejectReason.copyright => context.l10n.adminReasonCopyright,
    RejectReason.duplicate => context.l10n.adminReasonDuplicate,
    RejectReason.notWallpaper => context.l10n.adminReasonNotWallpaper,
    RejectReason.other => context.l10n.adminReasonOther,
  };

  String _reasonText(RejectReason reason) => switch (reason) {
    RejectReason.lowResolution => context.l10n.adminReasonLowResolutionBody,
    RejectReason.watermark => context.l10n.adminReasonWatermarkBody,
    RejectReason.blurry => context.l10n.adminReasonBlurryBody,
    RejectReason.copyright => context.l10n.adminReasonCopyrightBody,
    RejectReason.duplicate => context.l10n.adminReasonDuplicateBody,
    RejectReason.notWallpaper => context.l10n.adminReasonNotWallpaperBody,
    RejectReason.other => '',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A preset fills the creator-facing text. "Other" clears it.
  void _pick(RejectReason reason) {
    PrismHaptics.selection();
    setState(() {
      _picked = reason;
      _controller.text = _reasonText(reason);
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final String reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = context.l10n.adminRejectReasonRequired);
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(reason);
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      logger.e('Admin reject failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = context.l10n.adminRejectSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: PrismSheetBody(
        title: widget.title,
        message: context.l10n.adminCreatorWillSeeFeedback,
        actions: <Widget>[
          PrismButton(label: widget.confirmLabel, expand: true, loading: _isSaving, onPressed: _submit),
          PrismButton(
            label: context.l10n.adminCancel,
            expand: true,
            variant: PrismButtonVariant.ghost,
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: PrismSpace.xs,
              runSpacing: PrismSpace.xs,
              children: <Widget>[
                for (final RejectReason reason in rejectReasons)
                  PrismChip(
                    label: _reasonLabel(reason),
                    selected: _picked == reason,
                    onTap: _isSaving ? null : () => _pick(reason),
                  ),
              ],
            ),
            const SizedBox(height: PrismSpace.md),
            PrismTextField(
              controller: _controller,
              label: context.l10n.adminReasonLabel,
              hint: context.l10n.adminReasonHint,
              error: _errorMessage,
              enabled: !_isSaving,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {
                _picked = null;
                _errorMessage = null;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
