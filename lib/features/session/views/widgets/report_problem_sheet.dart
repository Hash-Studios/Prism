import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/session/data/report_problem_service.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

typedef ScreenshotPicker = Future<Uint8List?> Function();

Future<Uint8List?> _pickFromGallery() async {
  final XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
  return file?.readAsBytes();
}

/// Opens the report form. A shake passes the [screenshot] it took; other entry points let the user pick one.
Future<void> showReportProblemSheet(
  BuildContext context, {
  required String source,
  required ReportTrigger trigger,
  Uint8List? screenshot,
  ReportProblemService? service,
  ScreenshotPicker? pickScreenshot,
}) {
  unawaited(analytics.track(ReportProblemOpenedEvent(source: source, trigger: trigger.name)));
  final ReportProblemService reports = service ?? ReportProblemService.instance;
  return showPrismSheet<void>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.large],
    dismissKeyboardOnDrag: true,
    builder: (BuildContext sheetContext) => _ReportProblemBody(
      service: reports,
      theme: Theme.of(sheetContext).brightness.name,
      trigger: trigger,
      screenshot: screenshot,
      pickScreenshot: pickScreenshot ?? _pickFromGallery,
    ),
  );
}

const int _noteMaxLength = 1000;

enum _Phase { loading, ready, sending, failed }

String _topicLabel(AppLocalizations l10n, ReportTopic topic) => switch (topic) {
  ReportTopic.crashFreeze => l10n.reportTopicCrashFreeze,
  ReportTopic.wallpaperWontSet => l10n.reportTopicWallpaperWontSet,
  ReportTopic.looksBroken => l10n.reportTopicLooksBroken,
  ReportTopic.slow => l10n.reportTopicSlow,
  ReportTopic.other => l10n.reportTopicOther,
};

class _ReportProblemBody extends StatefulWidget {
  const _ReportProblemBody({
    required this.service,
    required this.theme,
    required this.trigger,
    required this.screenshot,
    required this.pickScreenshot,
  });

  final ReportProblemService service;
  final String theme;
  final ReportTrigger trigger;
  final Uint8List? screenshot;
  final ScreenshotPicker pickScreenshot;

  @override
  State<_ReportProblemBody> createState() => _ReportProblemBodyState();
}

class _ReportProblemBodyState extends State<_ReportProblemBody> {
  final TextEditingController _note = TextEditingController();
  final FocusNode _noteFocus = FocusNode();
  _Phase _phase = _Phase.loading;
  String? _report;
  ReportTopic? _topic;
  late Uint8List? _screenshot = widget.screenshot;
  bool _includeDiagnostics = true;
  bool _showDiagnostics = false;
  bool _sharing = false;
  bool _pickingScreenshot = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    String? report;
    try {
      report = await widget.service.buildReport(theme: widget.theme);
    } catch (error, stackTrace) {
      logger.w('Could not build the problem report.', error: error, stackTrace: stackTrace);
    }
    if (!mounted) return;
    setState(() {
      _report = report;
      _phase = _Phase.ready;
    });
  }

  ProblemReportDraft _draft(ReportTopic topic) => ProblemReportDraft(
    topic: topic,
    trigger: widget.trigger,
    note: _note.text,
    screenshot: _screenshot,
    diagnostics: _includeDiagnostics ? _report : null,
  );

  Future<void> _send(ReportTopic topic) async {
    final AppLocalizations l10n = context.l10n;
    final ProblemReportDraft draft = _draft(topic);
    _noteFocus.unfocus();
    setState(() => _phase = _Phase.sending);
    String? reference;
    try {
      reference = await widget.service.send(draft);
    } catch (error, stackTrace) {
      logger.w('Could not send the problem report.', error: error, stackTrace: stackTrace);
    }
    unawaited(
      analytics.track(
        ReportProblemSentEvent(
          result: reference == null ? 'failed' : 'sent',
          topic: draft.topic.wire,
          hasScreenshot: draft.screenshot != null,
          trigger: widget.trigger.name,
        ),
      ),
    );
    if (!mounted) return;
    if (reference == null) {
      setState(() => _phase = _Phase.failed);
      return;
    }
    toasts.success(l10n.reportSent(reference));
    Navigator.of(context).pop();
  }

  Future<void> _share() async {
    final AppLocalizations l10n = context.l10n;
    final String text = _shareText();
    final String? topic = _topic?.wire;
    final bool hasScreenshot = _screenshot != null;
    _noteFocus.unfocus();
    setState(() => _sharing = true);
    String result = 'shared';
    try {
      await widget.service.share(
        text,
        subject: l10n.accountProblemReportShareSubject,
        shareText: l10n.accountProblemReportSharePrompt,
      );
    } catch (error, stackTrace) {
      result = 'failed';
      logger.w('Could not share the problem report.', error: error, stackTrace: stackTrace);
    }
    unawaited(
      analytics.track(
        ReportProblemSharedEvent(
          result: result,
          topic: topic,
          hasScreenshot: hasScreenshot,
          trigger: widget.trigger.name,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'failed') toasts.error(l10n.accountCouldNotShareReport);
    setState(() => _sharing = false);
    if (result == 'shared') Navigator.of(context).pop();
  }

  /// The file keeps the old report and adds what the user typed on top, scrubbed like the logs.
  String _shareText() {
    final String note = scrubSensitive(_note.text.trim());
    final StringBuffer out = StringBuffer();
    if (_topic != null) out.writeln('Topic: ${_topic!.wire}');
    if (note.isNotEmpty) out.writeln('Note: $note');
    if (out.isNotEmpty) out.writeln();
    if (_includeDiagnostics && _report != null) out.write(_report);
    return out.toString();
  }

  Future<void> _pickScreenshot() async {
    if (_pickingScreenshot) return;
    setState(() => _pickingScreenshot = true);
    try {
      final Uint8List? bytes = await widget.pickScreenshot();
      if (bytes != null && mounted) setState(() => _screenshot = bytes);
    } catch (error, stackTrace) {
      logger.w('Could not pick a screenshot.', error: error, stackTrace: stackTrace);
    } finally {
      if (mounted) setState(() => _pickingScreenshot = false);
    }
  }

  void _previewScreenshot(Uint8List bytes) {
    final AppLocalizations l10n = context.l10n;
    unawaited(
      showPrismSheet<void>(
        context,
        detents: const <PrismSheetDetent>[PrismSheetDetent.large],
        builder: (BuildContext sheetContext) => PrismSheetBody(
          title: l10n.reportViewScreenshot,
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Center(
              child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ReportTopic? topic = _topic;
    final bool busy = _phase == _Phase.sending || _sharing || _pickingScreenshot;
    return PrismSheetBody(
      title: l10n.accountReportAProblem,
      message: l10n.reportSheetMessage,
      actions: <Widget>[
        // Pinned with the actions: at the end of the scrolling form it sat below the fold.
        if (_phase == _Phase.failed)
          PrismInlineState(
            icon: Icons.cloud_off_rounded,
            title: l10n.reportCouldNotSend,
            body: l10n.reportCouldNotSendBody,
            actionLabel: l10n.reportShareInstead,
            onAction: _sharing ? null : () => unawaited(_share()),
          ),
        PrismButton(
          key: const Key('report_problem_send'),
          label: l10n.reportSend,
          expand: true,
          loading: _phase == _Phase.sending,
          onPressed: topic == null || busy || _phase == _Phase.loading ? null : () => unawaited(_send(topic)),
        ),
        PrismButton(
          label: l10n.reportShareAsFile,
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: busy || _phase == _Phase.loading || _shareText().trim().isEmpty ? null : () => unawaited(_share()),
        ),
        PrismButton(
          label: l10n.accountCancel,
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: _phase == _Phase.loading ? const _ReportSkeleton() : IgnorePointer(ignoring: busy, child: _form(l10n)),
    );
  }

  Widget _form(AppLocalizations l10n) {
    final Uint8List? screenshot = _screenshot;
    final String? report = _report;
    final bool busy = _phase == _Phase.sending || _sharing || _pickingScreenshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: PrismSpace.xs,
          runSpacing: PrismSpace.xs,
          children: <Widget>[
            for (final ReportTopic topic in ReportTopic.values)
              PrismChip(
                label: _topicLabel(l10n, topic),
                selected: _topic == topic,
                onTap: () => setState(() => _topic = topic),
              ),
          ],
        ),
        const SizedBox(height: PrismSpace.md),
        PrismTextField(
          controller: _note,
          focusNode: _noteFocus,
          hint: l10n.reportNoteHint,
          minLines: 3,
          maxLines: 6,
          maxLength: _noteMaxLength,
          enabled: !busy,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: PrismSpace.md),
        _ScreenshotCard(
          screenshot: screenshot,
          onAdd: () => unawaited(_pickScreenshot()),
          onPreview: screenshot == null ? null : () => _previewScreenshot(screenshot),
          onRemove: () => setState(() => _screenshot = null),
        ),
        const SizedBox(height: PrismSpace.xs),
        PrismSwitchRow(
          icon: Icons.description_outlined,
          title: l10n.reportIncludeDiagnostics,
          value: _includeDiagnostics && report != null,
          onChanged: report == null ? null : (bool value) => setState(() => _includeDiagnostics = value),
          subtitle: report == null ? l10n.accountCouldNotBuildReport : null,
        ),
        if (report != null && _includeDiagnostics) ...<Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: PrismButton(
              label: _showDiagnostics ? l10n.reportHideDiagnostics : l10n.reportShowDiagnostics,
              variant: PrismButtonVariant.ghost,
              size: PrismButtonSize.compact,
              onPressed: () => setState(() => _showDiagnostics = !_showDiagnostics),
            ),
          ),
          if (_showDiagnostics) _DiagnosticsPreview(report: report),
        ],
      ],
    );
  }
}

class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return const PrismSkeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              PrismBone(width: 108, height: 36, radius: PrismRadius.pill),
              PrismBone(width: 156, height: 36, radius: PrismRadius.pill),
              PrismBone(width: 116, height: 36, radius: PrismRadius.pill),
              PrismBone(width: 64, height: 36, radius: PrismRadius.pill),
            ],
          ),
          SizedBox(height: PrismSpace.md),
          PrismBone(height: 96, radius: PrismRadius.md),
          SizedBox(height: PrismSpace.md),
          PrismBone(height: 96, radius: PrismRadius.md),
        ],
      ),
    );
  }
}

class _ScreenshotCard extends StatelessWidget {
  const _ScreenshotCard({
    required this.screenshot,
    required this.onAdd,
    required this.onPreview,
    required this.onRemove,
  });

  final Uint8List? screenshot;
  final VoidCallback onAdd;
  final VoidCallback? onPreview;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Uint8List? bytes = screenshot;
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(PrismRadius.md)),
      child: Padding(
        padding: const EdgeInsets.all(PrismSpace.sm),
        child: Row(
          children: <Widget>[
            Semantics(
              key: const Key('report_problem_screenshot_thumbnail'),
              button: true,
              label: bytes == null ? l10n.reportAddScreenshot : l10n.reportViewScreenshot,
              child: GestureDetector(
                onTap: bytes == null ? onAdd : onPreview,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(PrismRadius.xs),
                  child: SizedBox(
                    width: 72,
                    height: 144,
                    child: bytes == null
                        ? ColoredBox(
                            color: cs.surfaceContainer,
                            child: Icon(Icons.add_photo_alternate_outlined, color: cs.onSurfaceVariant),
                          )
                        : Image.memory(bytes, key: const Key('report_problem_screenshot'), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            const SizedBox(width: PrismSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.reportScreenshotTitle, style: PrismTextStyles.rowTitle(context)),
                  const SizedBox(height: PrismSpace.xxs),
                  Text(
                    bytes == null ? l10n.reportScreenshotEmpty : l10n.reportScreenshotAttached,
                    style: PrismTextStyles.body(context),
                  ),
                  const SizedBox(height: PrismSpace.xs),
                  PrismButton(
                    label: bytes == null ? l10n.reportAddScreenshot : l10n.reportRemoveScreenshot,
                    variant: bytes == null ? PrismButtonVariant.tonal : PrismButtonVariant.ghost,
                    size: PrismButtonSize.compact,
                    onPressed: bytes == null ? onAdd : onRemove,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsPreview extends StatelessWidget {
  const _DiagnosticsPreview({required this.report});

  final String report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(PrismRadius.sm),
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PrismSpace.sm),
            child: SelectableText(
              report,
              key: const Key('report_problem_preview'),
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}
