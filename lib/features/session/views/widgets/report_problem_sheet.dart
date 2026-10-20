import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/session/data/report_problem_service.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// Shows the report that Prism would send, so the user can read it before they share it.
Future<void> showReportProblemSheet(BuildContext context, {required String source, ReportProblemService? service}) {
  unawaited(analytics.track(ReportProblemOpenedEvent(source: source)));
  final ReportProblemService reports = service ?? ReportProblemService.instance;
  return showPrismSheet<void>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.large],
    builder: (BuildContext sheetContext) => _ReportProblemBody(service: reports, theme: _themeLabel(sheetContext)),
  );
}

String _themeLabel(BuildContext context) => Theme.of(context).brightness.name;

class _ReportProblemBody extends StatefulWidget {
  const _ReportProblemBody({required this.service, required this.theme});

  final ReportProblemService service;
  final String theme;

  @override
  State<_ReportProblemBody> createState() => _ReportProblemBodyState();
}

class _ReportProblemBodyState extends State<_ReportProblemBody> {
  late final Future<String> _report = widget.service.buildReport(theme: widget.theme);
  bool _sharing = false;

  Future<void> _share(String report) async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _sharing = true);
    String result = 'shared';
    try {
      await widget.service.share(
        report,
        subject: l10n.accountProblemReportShareSubject,
        shareText: l10n.accountProblemReportSharePrompt,
      );
    } catch (error, stackTrace) {
      result = 'failed';
      logger.w('Could not share the problem report.', error: error, stackTrace: stackTrace);
      toasts.error(l10n.accountCouldNotShareReport);
    }
    unawaited(analytics.track(ReportProblemSharedEvent(result: result)));
    if (!mounted) return;
    setState(() => _sharing = false);
    if (result == 'shared') Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return FutureBuilder<String>(
      future: _report,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String? report = snapshot.data;
        final Widget preview;
        if (snapshot.hasError) {
          preview = Text(context.l10n.accountCouldNotBuildReport, style: theme.textTheme.bodyMedium);
        } else if (report == null) {
          preview = const Center(child: CircularProgressIndicator());
        } else {
          preview = DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  report,
                  key: const Key('report_problem_preview'),
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          );
        }
        return PrismSheetBody(
          title: context.l10n.accountReportAProblem,
          message: context.l10n.accountReportPreviewNotice(supportEmail),
          childScrolls: true,
          actions: <Widget>[
            if (report != null) ...<Widget>[
              PrismButton(
                label: context.l10n.accountShare,
                expand: true,
                onPressed: _sharing ? null : () => unawaited(_share(report)),
              ),
              PrismButton(
                label: context.l10n.accountCancel,
                expand: true,
                variant: PrismButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xl),
            child: preview,
          ),
        );
      },
    );
  }
}
