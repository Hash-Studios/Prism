import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_upload/biz/wall_release.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _ReleaseMode { whenApproved, atTime }

/// When an approved wall goes live: on approval, or at a time the creator picks in their own time zone.
/// [releaseAt] is UTC. [allowWhenApproved] is false for a wall that is already approved and scheduled.
class ReleaseTimeRow extends StatelessWidget {
  const ReleaseTimeRow({
    super.key,
    required this.releaseAt,
    required this.onChanged,
    this.enabled = true,
    this.allowWhenApproved = true,
    this.now = DateTime.now,
  });

  final DateTime? releaseAt;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  final bool allowWhenApproved;
  final DateTime Function() now;

  /// The first pick: the next whole hour that is at least [pickerReleaseLead] away.
  DateTime _defaultPick() {
    final DateTime earliest = earliestReleasePick(now());
    return earliest.minute == 0 ? earliest : DateTime(earliest.year, earliest.month, earliest.day, earliest.hour + 1);
  }

  Future<void> _pickDate(BuildContext context, DateTime local) async {
    final DateTime today = now();
    final DateTime firstDate = DateUtils.dateOnly(today);
    final DateTime lastDate = DateUtils.dateOnly(today.add(maxReleaseLead));
    final DateTime initialDate = local.isBefore(firstDate)
        ? firstDate
        : local.isAfter(lastDate)
        ? lastDate
        : local;
    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (day == null) return;
    onChanged(DateTime(day.year, day.month, day.day, local.hour, local.minute).toUtc());
  }

  Future<void> _pickTime(BuildContext context, DateTime local) async {
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(local));
    if (time == null) return;
    onChanged(DateTime(local.year, local.month, local.day, time.hour, time.minute).toUtc());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final bool use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final DateTime? value = releaseAt;
    final DateTime? local = value?.toLocal();
    final ReleaseTimeProblem? problem = value == null ? null : releaseTimeProblem(value, now());
    final String? dateText = local == null ? null : DateFormat.MMMEd(locale).format(local);
    final String? timeText = local == null
        ? null
        : (use24h ? DateFormat.Hm(locale) : DateFormat.jm(locale)).format(local);
    final TextStyle help = PrismTextStyles.caption(context).copyWith(color: cs.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(l10n.wallReleaseTitle, style: PrismTextStyles.rowTitle(context).copyWith(color: cs.onSurface)),
        ),
        const SizedBox(height: PrismSpace.sm),
        if (allowWhenApproved)
          PrismSegmented<_ReleaseMode>(
            values: _ReleaseMode.values,
            selected: value == null ? _ReleaseMode.whenApproved : _ReleaseMode.atTime,
            labelOf: (mode) => switch (mode) {
              _ReleaseMode.whenApproved => l10n.wallReleaseWhenApproved,
              _ReleaseMode.atTime => l10n.wallReleaseAtTime,
            },
            onChanged: !enabled
                ? null
                : (mode) => onChanged(switch (mode) {
                    _ReleaseMode.whenApproved => null,
                    _ReleaseMode.atTime => value ?? _defaultPick().toUtc(),
                  }),
          ),
        const SizedBox(height: PrismSpace.sm),
        Text(value == null ? l10n.wallReleaseWhenApprovedHelp : l10n.wallReleaseAtTimeHelp, style: help),
        if (local != null && dateText != null && timeText != null) ...<Widget>[
          const SizedBox(height: PrismSpace.md),
          Wrap(
            spacing: PrismSpace.sm,
            runSpacing: PrismSpace.sm,
            children: <Widget>[
              Semantics(
                button: true,
                label: l10n.wallReleaseDateLabel(dateText),
                onTap: enabled ? () => _pickDate(context, local) : null,
                excludeSemantics: true,
                child: PrismButton(
                  label: dateText,
                  icon: Icons.calendar_today_outlined,
                  variant: PrismButtonVariant.tonal,
                  size: PrismButtonSize.compact,
                  onPressed: enabled ? () => _pickDate(context, local) : null,
                ),
              ),
              Semantics(
                button: true,
                label: l10n.wallReleaseTimeLabel(timeText),
                onTap: enabled ? () => _pickTime(context, local) : null,
                excludeSemantics: true,
                child: PrismButton(
                  label: timeText,
                  icon: Icons.schedule,
                  variant: PrismButtonVariant.tonal,
                  size: PrismButtonSize.compact,
                  onPressed: enabled ? () => _pickTime(context, local) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.sm),
          Text(l10n.wallReleaseTimeZone(timeZoneText(local)), style: help),
          if (problem != null) ...<Widget>[
            const SizedBox(height: PrismSpace.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                problem == ReleaseTimeProblem.tooSoon ? l10n.wallReleaseTooSoon : l10n.wallReleaseTooLate,
                style: PrismTextStyles.body(context).copyWith(color: cs.error),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// "IST, UTC+05:30", or only the offset when the platform name is itself an offset.
String timeZoneText(DateTime local) {
  final String offset = utcOffsetText(local);
  final String name = local.timeZoneName.trim();
  return name.isEmpty || RegExp(r'^(GMT|UTC)?[+-]?\d').hasMatch(name) || name == 'UTC' || name == 'GMT'
      ? offset
      : '$name, $offset';
}
