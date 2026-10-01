import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/content_reports/content_report_repository.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/logger/logger.dart';
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

  PrismHaptics.tap();
  await showPrismSheet<void>(
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

String _contentTypeLabel(String contentType) {
  switch (contentType) {
    case 'user':
      return 'user';
    default:
      return 'wallpaper';
  }
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
    PrismHaptics.tap();
    setState(() => _submitting = true);
    String appVersion = '';
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (error, stackTrace) {
      logger.w('Could not read app version for content report', error: error, stackTrace: stackTrace);
    }

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
        toasts.success('Report sent. Thank you.');
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
    // Scrolls so the keyboard never pushes Submit off the sheet.
    return SingleChildScrollView(
      padding: pad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Report ${_contentTypeLabel(widget.contentType)}', style: Theme.of(context).textTheme.titleLarge),
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(widget.subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          RadioGroup<String>(
            groupValue: _selectedWire,
            onChanged: (String? v) {
              if (_submitting) {
                return;
              }
              PrismHaptics.selection();
              setState(() => _selectedWire = v);
            },
            child: Column(
              children: kContentReportReasons.map((pair) {
                final bool sel = _selectedWire == pair.$1;
                return RadioListTile<String>(value: pair.$1, title: Text(pair.$2), selected: sel);
              }).toList(),
            ),
          ),
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
            child: AnimatedSwitcher(
              duration: context.motion(PrismDurations.fast),
              child: _submitting
                  ? const SizedBox.square(
                      key: ValueKey('loading'),
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit report', key: ValueKey('label')),
            ),
          ),
        ],
      ),
    );
  }
}
