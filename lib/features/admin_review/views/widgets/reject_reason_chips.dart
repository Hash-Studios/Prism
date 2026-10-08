import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/admin_review/biz/reject_reasons.dart';
import 'package:flutter/material.dart';

/// Reason chips that fill [controller] with the creator-facing text. "Other" clears the text.
class RejectReasonChips extends StatelessWidget {
  const RejectReasonChips({super.key, required this.controller, this.enabled = true, this.onPicked});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final RejectReason reason in rejectReasons)
          ActionChip(
            label: Text(reason.label),
            onPressed: enabled
                ? () {
                    PrismHaptics.selection();
                    controller.text = reason.text;
                    controller.selection = TextSelection.collapsed(offset: controller.text.length);
                    onPicked?.call();
                  }
                : null,
          ),
      ],
    );
  }
}

/// Asks for a rejection reason. Returns the reason, or null when the admin cancels.
Future<String?> showRejectReasonSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => const _RejectReasonSheet(),
  );
}

class _RejectReasonSheet extends StatefulWidget {
  const _RejectReasonSheet();

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Pick a reason or write one.');
      return;
    }
    PrismHaptics.tap();
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Reject this wallpaper', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            RejectReasonChips(controller: _controller, onPicked: () => setState(() => _error = null)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Reason',
                helperText: 'The creator will see this feedback.',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _submit, child: const Text('Reject')),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}
