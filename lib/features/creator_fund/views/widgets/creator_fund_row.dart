import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_fund/biz/bloc/creator_fund_bloc.j.dart';
import 'package:Prism/features/creator_fund/domain/creator_fund_status.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class CreatorFundRow extends StatefulWidget {
  const CreatorFundRow({super.key});

  @override
  State<CreatorFundRow> createState() => _CreatorFundRowState();
}

class _CreatorFundRowState extends State<CreatorFundRow> {
  bool _viewed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return BlocBuilder<CreatorFundBloc, CreatorFundState>(
      builder: (context, state) {
        final status = state.status;
        if (!_viewed && status != null && !state.failed) {
          _viewed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted)
              analytics.track(CreatorFundViewedEvent(state: _stateName(status), reason: _reasonName(status)));
          });
        }
        final lines = _lines(l10n, state, locale);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label: [l10n.creatorFundTitle, ...lines, l10n.creatorFundAbout].join('. '),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.creatorFundTitle, style: PrismTextStyles.rowTitle(context)),
                    if (lines.isEmpty) const PrismBone(width: 160),
                    for (final line in lines) Text(line, style: PrismTextStyles.body(context)),
                    Text(l10n.creatorFundAbout, style: PrismTextStyles.caption(context)),
                  ],
                ),
              ),
            ),
            if (state.failed)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.read<CreatorFundBloc>().add(const CreatorFundEvent.load()),
                  child: Text(l10n.statsRetry),
                ),
              ),
          ],
        );
      },
    );
  }

  List<String> _lines(AppLocalizations l10n, CreatorFundState state, String locale) {
    if (state.failed) return [l10n.creatorFundError];
    final status = state.status;
    return switch (status) {
      null => const <String>[],
      CreatorFundOff() => [l10n.creatorFundOff],
      CreatorFundPending() => [l10n.creatorFundPending],
      CreatorFundPaid(:final coins, :final shareBps) => [
        l10n.creatorFundPaid(coins),
        l10n.creatorFundShare(
          NumberFormat.decimalPercentPattern(locale: locale, decimalDigits: 1).format(shareBps / 10000),
        ),
      ],
      CreatorFundNotQualified() => [_notQualifiedLine(l10n, status)],
    };
  }

  String _notQualifiedLine(AppLocalizations l10n, CreatorFundNotQualified status) => switch (status.reason) {
    CreatorFundReason.noActivity => l10n.creatorFundNoActivity,
    CreatorFundReason.fewUsers => l10n.creatorFundFewUsers(status.distinctUsers, status.minDistinctUsers),
    CreatorFundReason.smallShare => l10n.creatorFundSmallShare(status.minPayout),
    CreatorFundReason.moderation => l10n.creatorFundModeration,
    CreatorFundReason.team => l10n.creatorFundTeam,
  };

  String _stateName(CreatorFundStatus status) => switch (status) {
    CreatorFundOff() => 'off',
    CreatorFundPending() => 'pending',
    CreatorFundPaid() => 'paid',
    CreatorFundNotQualified() => 'not_qualified',
  };

  String? _reasonName(CreatorFundStatus status) => switch (status) {
    CreatorFundNotQualified(:final reason) => reason.name,
    _ => null,
  };
}
