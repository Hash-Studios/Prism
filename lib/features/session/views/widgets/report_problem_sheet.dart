import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/session/data/report_problem_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// Shows the report that Prism would send, so the user can read it before they share it.
Future<void> showReportProblemSheet(BuildContext context, {required String source, ReportProblemService? service}) {
  unawaited(analytics.track(ReportProblemOpenedEvent(source: source)));
  final ReportProblemService reports = service ?? ReportProblemService.instance;
  return showPrismSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
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
    setState(() => _sharing = true);
    String result = 'shared';
    try {
      await widget.service.share(report);
    } catch (error, stackTrace) {
      result = 'failed';
      logger.w('Could not share the problem report.', error: error, stackTrace: stackTrace);
      toasts.error("Couldn't share the report. Try again.");
    }
    unawaited(analytics.track(ReportProblemSharedEvent(result: result)));
    if (!mounted) return;
    setState(() => _sharing = false);
    if (result == 'shared') Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Report a problem', style: PrismTextStyles.cardTitle(context)),
          const SizedBox(height: 8),
          Text(
            'This report has your app version, device and recent logs. It has no email address or sign-in tokens. '
            'Read it, then share it with $supportEmail.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: FutureBuilder<String>(
              future: _report,
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                if (snapshot.hasError) {
                  return Text("Couldn't build the report. Try again.", style: theme.textTheme.bodyMedium);
                }
                final String? report = snapshot.data;
                if (report == null) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Flexible(
                      child: DecoratedBox(
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
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _sharing ? null : () => unawaited(_share(report)),
                            child: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
