import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/biz/show_pro_badge_cubit.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Settings switch that shows or hides the Pro badge on the viewer's profile. Off writes `showProBadge`.
class ShowProBadgeRow extends StatelessWidget {
  const ShowProBadgeRow({super.key, this.cubit});

  /// Injected by tests. When null, the row creates its own cubit.
  final ShowProBadgeCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final ShowProBadgeCubit? provided = cubit;
    if (provided != null) {
      return BlocProvider<ShowProBadgeCubit>.value(value: provided, child: _body());
    }
    return BlocProvider<ShowProBadgeCubit>(
      create: (_) => ShowProBadgeCubit(getIt<FirestoreClient>(), () => app_state.prismUser.id)..load(),
      child: _body(),
    );
  }

  Widget _body() {
    return BlocBuilder<ShowProBadgeCubit, ShowProBadgeState>(
      builder: (context, state) => PrismSwitchRow(
        icon: Icons.workspace_premium_rounded,
        title: context.l10n.settingsShowProBadgeTitle,
        subtitle: context.l10n.settingsShowProBadgeBody,
        value: state.shown,
        onChanged: state.loaded ? (bool show) => _set(context, show) : null,
      ),
    );
  }

  Future<void> _set(BuildContext context, bool show) async {
    final String failed = context.l10n.coreSomethingWentWrong;
    unawaited(analytics.track(ProBadgeToggledEvent(shown: show)));
    if (!await context.read<ShowProBadgeCubit>().setShown(show)) toasts.error(failed);
  }
}
