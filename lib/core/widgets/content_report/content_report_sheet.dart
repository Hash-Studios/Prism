import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/content_reports/content_report_repository.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
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

  await showPrismSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return ContentReportSheetBody(
        contentType: contentType,
        targetFirestoreDocId: targetFirestoreDocId,
        subtitle: subtitle,
      );
    },
  );
}

/// The content of the report sheet. Exposed so tests can pump it without signing in.
@visibleForTesting
class ContentReportSheetBody extends StatefulWidget {
  const ContentReportSheetBody({required this.contentType, required this.targetFirestoreDocId, this.subtitle});

  final String contentType;
  final String targetFirestoreDocId;
  final String? subtitle;

  @override
  State<ContentReportSheetBody> createState() => ContentReportSheetBodyState();
}

String _contentTypeLabel(String contentType) {
  switch (contentType) {
    case 'user':
      return 'user';
    default:
      return 'wallpaper';
  }
}

@visibleForTesting
class ContentReportSheetBodyState extends State<ContentReportSheetBody> {
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
    final String label = _contentTypeLabel(widget.contentType);
    final String? subtitle = widget.subtitle;
    return PrismSheetBody(
      title: 'Report',
      message: subtitle == null || subtitle.isEmpty
          ? 'Why are you reporting this $label?'
          : 'Why are you reporting this $label ($subtitle)?',
      scrollable: true,
      actions: <Widget>[PrismButton(label: 'Send report', expand: true, loading: _submitting, onPressed: _submit)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PrismGroup(
            children: <Widget>[
              for (final (String wire, String reason) in kContentReportReasons)
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  selected: _selectedWire == wire,
                  child: PrismRow(
                    title: reason,
                    trailing: _ReasonTick(selected: _selectedWire == wire),
                    onTap: _submitting ? null : () => setState(() => _selectedWire = wire),
                  ),
                ),
            ],
          ),
          const SizedBox(height: PrismSpace.md),
          PrismTextField(
            controller: _details,
            enabled: !_submitting,
            label: 'Details (optional)',
            hint: 'Anything else we should know',
            minLines: 3,
            maxLines: 3,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}

/// The round tick at the end of a reason row.
class _ReasonTick extends StatelessWidget {
  const _ReasonTick({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: context.motion(PrismDurations.fast),
      curve: PrismCurves.enter,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.transparent,
        border: Border.all(color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.25), width: 1.5),
      ),
      child: AnimatedOpacity(
        duration: context.motion(PrismDurations.fast),
        opacity: selected ? 1 : 0,
        child: Icon(Icons.check_rounded, size: 16, color: cs.onPrimary),
      ),
    );
  }
}
