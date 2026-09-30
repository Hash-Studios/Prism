import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';

const List<String> _quickReasons = <String>[
  'Low quality',
  'Not original',
  'Inappropriate content',
  'Wrong category',
  'Watermark or logo',
];

/// Asks for a reason, then runs [onSubmit] with it. The sheet stays open, with the reason kept, when saving fails.
Future<void> showRejectReasonSheet(
  BuildContext context, {
  required Future<void> Function(String reason) onSubmit,
  String title = 'Reject wallpaper',
  String confirmLabel = 'Reject wallpaper',
}) {
  return showPrismSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    builder: (_) => _RejectReasonSheet(title: title, confirmLabel: confirmLabel, onSubmit: onSubmit),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(String reason) {
    setState(() {
      _controller.text = reason;
      _controller.selection = TextSelection.collapsed(offset: reason.length);
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final String reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'Enter a reason before rejecting this item.');
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
          _errorMessage = 'Could not save this decision. Your reason is still here. Try again.';
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
        message: 'The creator will see this feedback.',
        scrollable: true,
        actions: <Widget>[
          PrismButton(label: widget.confirmLabel, expand: true, loading: _isSaving, onPressed: _submit),
          PrismButton(
            label: 'Cancel',
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
                for (final String reason in _quickReasons)
                  PrismChip(
                    label: reason,
                    selected: _controller.text == reason,
                    onTap: _isSaving ? null : () => _pick(reason),
                  ),
              ],
            ),
            const SizedBox(height: PrismSpace.md),
            PrismTextField(
              controller: _controller,
              label: 'Reason',
              hint: 'Explain what needs to change',
              error: _errorMessage,
              enabled: !_isSaving,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => _errorMessage = null),
            ),
          ],
        ),
      ),
    );
  }
}
