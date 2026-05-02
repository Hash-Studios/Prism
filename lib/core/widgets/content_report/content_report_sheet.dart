import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/content_reports/content_report_repository.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reason keys must match Cloud Function [ALLOWED_REASONS].
const List<(String wire, String label)> kContentReportReasons = <(String, String)>[
  ('copyright', 'Copyright / ownership'),
  ('harassment', 'Harassment or hate'),
  ('sexual', 'Sexual or adult content'),
  ('spam', 'Spam or misleading'),
  ('other', 'Other'),
];

Future<void> showContentReportSheet(
  BuildContext context, {
  required String contentType,
  required String targetFirestoreDocId,
  String? subtitle,
}) async {
  if (!context.mounted) {
    return;
  }
  if (FirebaseAuth.instance.currentUser == null) {
    toasts.error('Sign in to report content');
    googleSignInPopUp(context, () {});
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return _ContentReportSheetBody(
        contentType: contentType,
        targetFirestoreDocId: targetFirestoreDocId,
        subtitle: subtitle,
      );
    },
  );
}

class _ContentReportSheetBody extends StatefulWidget {
  const _ContentReportSheetBody({required this.contentType, required this.targetFirestoreDocId, this.subtitle});

  final String contentType;
  final String targetFirestoreDocId;
  final String? subtitle;

  @override
  State<_ContentReportSheetBody> createState() => _ContentReportSheetBodyState();
}

class _ContentReportSheetBodyState extends State<_ContentReportSheetBody> {
  String? _selectedWire;
  final TextEditingController _details = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String? reason = _selectedWire;
    if (reason == null || reason.isEmpty) {
      toasts.error('Choose a reason');
      return;
    }
    setState(() => _submitting = true);
    String appVersion = '';
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    final ContentReportRepository repo = getIt<ContentReportRepository>();
    final result = await repo.submitReport(
      contentType: widget.contentType,
      targetFirestoreDocId: widget.targetFirestoreDocId,
      reason: reason,
      details: _details.text,
      appVersion: appVersion,
    );

    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);

    result.fold(
      onFailure: (f) {
        analytics.track(
          ContentReportSubmitEvent(
            contentType: widget.contentType,
            result: BinaryResultValue.failure,
            reason: f.message,
          ),
        );
        toasts.error(f.message);
      },
      onSuccess: (_) {
        analytics.track(
          ContentReportSubmitEvent(contentType: widget.contentType, result: BinaryResultValue.success, reason: reason),
        );
        Navigator.of(context).pop();
        toasts.codeSend('Report sent. Thank you.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = EdgeInsets.only(
      left: 20,
      right: 20,
      top: 8,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    );
    return Padding(
      padding: pad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Report ${widget.contentType == 'setup' ? 'setup' : 'wallpaper'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(widget.subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          ...kContentReportReasons.map((pair) {
            final bool sel = _selectedWire == pair.$1;
            return RadioListTile<String>(
              value: pair.$1,
              groupValue: _selectedWire,
              title: Text(pair.$2),
              onChanged: _submitting ? null : (String? v) => setState(() => _selectedWire = v),
              selected: sel,
            );
          }),
          TextField(
            controller: _details,
            enabled: !_submitting,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Details (optional)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit report'),
          ),
        ],
      ),
    );
  }
}
