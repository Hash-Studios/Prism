import 'package:Prism/core/purchases/annual_trial.dart';
import 'package:Prism/core/purchases/manage_subscription.dart';
import 'package:Prism/core/purchases/trial_reminder.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

enum TrialTimelineChoice { started, seeAllPlans, closed }

const String _termsUrl = 'https://prismwalls.com/terms';
const String _privacyUrl = 'https://prismwalls.com/privacy';

DateTime _dateAfterDays(DateTime date, int days) => DateTime(date.year, date.month, date.day + days);

/// Shows what happens on each day of the annual free trial before the user starts it. The close button stays visible.
class TrialTimelinePage extends StatefulWidget {
  const TrialTimelinePage({
    super.key,
    required this.offer,
    required this.onStartTrial,
    required this.onReminderToggled,
    this.storeName,
    this.now,
  });

  final TrialOffer offer;

  /// Buys the annual package. It returns true once the store confirms the purchase.
  final Future<bool> Function({required bool remind}) onStartTrial;
  final ValueChanged<bool> onReminderToggled;
  final String? storeName;
  final DateTime? now;

  @override
  State<TrialTimelinePage> createState() => _TrialTimelinePageState();
}

class _TrialTimelinePageState extends State<TrialTimelinePage> {
  bool _remind = true;
  bool _starting = false;
  late final DateTime _today = (widget.now ?? DateTime.now()).toLocal();

  int? get _reminderDay {
    final int day = widget.offer.days - TrialReminder.lead.inDays;
    return day >= 1 ? day : null;
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final bool started = await widget.onStartTrial(remind: _reminderDay != null && _remind);
      if (started && mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(TrialTimelineChoice.started);
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _close(TrialTimelineChoice choice) => Navigator.of(context).pop(choice);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final DateFormat date = DateFormat.MMMd(l10n.localeName);
    final String store = widget.storeName ?? storeNameForPlatform();
    final String price = widget.offer.priceString;
    final int days = widget.offer.days;
    final int? reminderDay = _reminderDay;
    return PrismPage(
      title: l10n.trialTimelineTitle,
      showBack: false,
      actions: <Widget>[
        PrismIconButton(
          icon: Icons.close_rounded,
          tooltip: l10n.trialTimelineClose,
          onPressed: () => _close(TrialTimelineChoice.closed),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xl),
        children: <Widget>[
          Text(l10n.trialTimelinePlanSummary(days, price), style: PrismTextStyles.body(context)),
          const SizedBox(height: PrismSpace.xl),
          _TimelineStep(
            icon: Icons.lock_open_rounded,
            label: l10n.trialTimelineToday,
            date: date.format(_today),
            body: l10n.trialTimelineTodayBody,
            showLine: true,
          ),
          if (reminderDay != null)
            _TimelineStep(
              icon: _remind ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              label: l10n.trialTimelineDay(reminderDay),
              date: date.format(_dateAfterDays(_today, reminderDay)),
              body: _remind ? l10n.trialTimelineReminderBody : l10n.trialTimelineNoReminderBody,
              showLine: true,
            ),
          _TimelineStep(
            icon: Icons.workspace_premium_rounded,
            label: l10n.trialTimelineDay(days),
            date: date.format(_dateAfterDays(_today, days)),
            body: l10n.trialTimelineChargeBody(price),
            showLine: false,
          ),
          if (reminderDay != null) ...<Widget>[
            const SizedBox(height: PrismSpace.lg),
            PrismGroup(
              children: <Widget>[
                PrismSwitchRow(
                  icon: Icons.notifications_rounded,
                  title: l10n.trialTimelineRemindToggle,
                  value: _remind,
                  onChanged: (bool value) {
                    setState(() => _remind = value);
                    widget.onReminderToggled(value);
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: PrismSpace.xxl),
          Text(l10n.trialTimelineRenewalTerms(price, store), style: PrismTextStyles.caption(context)),
          const SizedBox(height: PrismSpace.xs),
          Wrap(
            spacing: PrismSpace.xs,
            children: <Widget>[
              PrismButton(
                label: l10n.trialTimelineCancelLink(store),
                variant: PrismButtonVariant.ghost,
                size: PrismButtonSize.compact,
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                maxLines: 2,
                onPressed: () => openManageSubscription(l10n),
              ),
              PrismButton(
                label: l10n.accountTermsOfUse,
                variant: PrismButtonVariant.ghost,
                size: PrismButtonSize.compact,
                onPressed: () => launchUrl(Uri.parse(_termsUrl), mode: LaunchMode.externalApplication),
              ),
              PrismButton(
                label: l10n.accountPrivacyPolicy,
                variant: PrismButtonVariant.ghost,
                size: PrismButtonSize.compact,
                onPressed: () => launchUrl(Uri.parse(_privacyUrl), mode: LaunchMode.externalApplication),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.md),
          Divider(color: cs.onSurface.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: PrismSpace.xs),
          PrismButton(
            label: l10n.trialTimelineSeeAllPlans,
            variant: PrismButtonVariant.ghost,
            onPressed: _starting ? null : () => _close(TrialTimelineChoice.seeAllPlans),
          ),
        ],
      ),
      bottomBar: PrismButton(
        label: l10n.trialTimelineStart(days),
        loading: _starting,
        expand: true,
        maxLines: 2,
        onPressed: _start,
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.icon,
    required this.label,
    required this.date,
    required this.body,
    required this.showLine,
  });

  final IconData icon;
  final String label;
  final String date;
  final String body;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Column(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: cs.primary),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: PrismSpace.xxs),
                      color: cs.primary.withValues(alpha: 0.24),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: PrismSpace.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: PrismSpace.xs, bottom: showLine ? PrismSpace.xl : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: PrismSpace.xs,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: <Widget>[
                        Text(label, style: PrismTextStyles.rowTitle(context)),
                        Text(date, style: PrismTextStyles.caption(context)),
                      ],
                    ),
                    const SizedBox(height: PrismSpace.xxs),
                    Text(body, style: PrismTextStyles.body(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
