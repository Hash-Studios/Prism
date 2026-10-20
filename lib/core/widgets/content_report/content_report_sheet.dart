import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/content_reports/content_report_repository.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reason keys must match Cloud Function [ALLOWED_REASONS].
const List<String> kContentReportReasons = <String>['copyright', 'harassment', 'sexual', 'spam', 'other'];

String _contentReportReasonLabel(String wire, AppLocalizations l10n) => switch (wire) {
  'copyright' => l10n.coreReportReasonCopyright,
  'harassment' => l10n.coreReportReasonHarassment,
  'sexual' => l10n.coreReportReasonSexual,
  'spam' => l10n.coreReportReasonSpam,
  _ => l10n.coreReportReasonOther,
};

/// Opens the report sheet. A guest gets the sign-in sheet first, and the report sheet opens again after sign-in.
///
/// [onBlockCreator] adds "Also block this creator" to the "Report sent" snackbar.
Future<void> showContentReportSheet(
  BuildContext context, {
  required String contentType,
  required String targetFirestoreDocId,
  String? subtitle,
  VoidCallback? onBlockCreator,
}) async {
  if (!context.mounted) {
    return;
  }
  if (FirebaseAuth.instance.currentUser == null) {
    toasts.error(context.l10n.coreSignInToReportContent);
    googleSignInPopUp(context, () {
      if (!context.mounted) return;
      unawaited(
        showContentReportSheet(
          context,
          contentType: contentType,
          targetFirestoreDocId: targetFirestoreDocId,
          subtitle: subtitle,
          onBlockCreator: onBlockCreator,
        ),
      );
    });
    return;
  }

  PrismHaptics.tap();
  await showPrismSheet<void>(
    context,
    dismissKeyboardOnDrag: true,
    builder: (BuildContext sheetContext) {
      return ContentReportSheetBody(
        contentType: contentType,
        targetFirestoreDocId: targetFirestoreDocId,
        subtitle: subtitle,
        onBlockCreator: onBlockCreator,
      );
    },
  );
}

/// The content of the report sheet. Exposed so tests can pump it without signing in.
@visibleForTesting
class ContentReportSheetBody extends StatefulWidget {
  const ContentReportSheetBody({
    required this.contentType,
    required this.targetFirestoreDocId,
    this.subtitle,
    this.onBlockCreator,
  });

  final String contentType;
  final String targetFirestoreDocId;
  final String? subtitle;
  final VoidCallback? onBlockCreator;

  @override
  State<ContentReportSheetBody> createState() => ContentReportSheetBodyState();
}

String _contentTypeLabel(String contentType, AppLocalizations l10n) {
  switch (contentType) {
    case 'user':
      return l10n.coreContentReportUser;
    default:
      return l10n.coreContentReportWallpaper;
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
    final AppLocalizations l10n = context.l10n;
    final String? reason = _selectedWire;
    if (reason == null || reason.isEmpty) {
      toasts.error(l10n.coreChooseReportReason);
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
        toasts.error(l10n.coreReportCouldNotSubmit);
      },
      onSuccess: (_) {
        analytics.track(
          ContentReportSubmitEvent(contentType: widget.contentType, result: BinaryResultValue.success, reason: reason),
        );
        final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
        final VoidCallback? blockCreator = widget.onBlockCreator;
        Navigator.of(context).pop();
        if (messenger == null || blockCreator == null) {
          toasts.success(l10n.coreReportSent);
          return;
        }
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.coreReportSent),
              action: SnackBarAction(label: l10n.coreBlockCreatorAfterReport, onPressed: blockCreator),
            ),
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String label = _contentTypeLabel(widget.contentType, l10n);
    final String? subtitle = widget.subtitle;
    return PrismSheetBody(
      title: l10n.coreReport,
      message: subtitle == null || subtitle.isEmpty
          ? l10n.coreContentReportWhy(label)
          : l10n.coreContentReportWhyWithDetails(label, subtitle),
      actions: <Widget>[
        PrismButton(label: l10n.coreSendReport, expand: true, loading: _submitting, onPressed: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PrismGroup(
            children: <Widget>[
              for (final String wire in kContentReportReasons)
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  selected: _selectedWire == wire,
                  child: PrismRow(
                    title: _contentReportReasonLabel(wire, l10n),
                    trailing: _ReasonTick(selected: _selectedWire == wire),
                    onTap: _submitting
                        ? null
                        : () {
                            PrismHaptics.selection();
                            setState(() => _selectedWire = wire);
                          },
                  ),
                ),
            ],
          ),
          const SizedBox(height: PrismSpace.md),
          PrismTextField(
            controller: _details,
            enabled: !_submitting,
            label: l10n.coreReportDetailsOptional,
            hint: l10n.coreReportDetailsHint,
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
