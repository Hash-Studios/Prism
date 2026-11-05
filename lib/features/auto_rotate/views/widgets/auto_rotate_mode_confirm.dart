import 'package:Prism/core/widgets/prism_sheet/prism_sheet_body.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_mode.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Call before [mode] turns on. When the other mode runs, asks the user and turns the other mode off.
/// Returns false when the user keeps the other mode, so [mode] must stay off.
Future<bool> confirmAutoRotateMode(BuildContext context, AutoRotateMode mode) async {
  final AutoRotateState playlist = context.read<AutoRotateBloc>().state;
  final bool otherOn = switch (mode) {
    AutoRotateMode.dayNight => playlist.config.enabled || playlist.status.isRunning,
    AutoRotateMode.playlist => context.read<DayNightBloc>().state.pair.enabled,
  };
  if (!otherOn) return true;
  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await showPrismConfirm(
    context,
    title: mode == AutoRotateMode.dayNight ? l10n.dayNightTurnOffAutoRotateTitle : l10n.dayNightTurnOffDayNightTitle,
    message: l10n.dayNightOneModeAtATime,
    confirmLabel: mode == AutoRotateMode.dayNight
        ? l10n.dayNightTurnOffAutoRotateAction
        : l10n.dayNightTurnOffDayNightAction,
  );
  if (!confirmed || !context.mounted) return false;
  switch (mode) {
    case AutoRotateMode.dayNight:
      final AutoRotateBloc bloc = context.read<AutoRotateBloc>();
      if (!bloc.state.config.enabled && !bloc.state.status.isRunning) return true;
      final Future<AutoRotateState> stopped = bloc.stream.firstWhere(
        (AutoRotateState state) => !state.config.enabled && !state.starting,
      );
      bloc.add(const AutoRotateEvent.toggled(false));
      final AutoRotateState state = await stopped;
      if (state.status.isRunning) return false;
    case AutoRotateMode.playlist:
      final DayNightBloc bloc = context.read<DayNightBloc>();
      if (!bloc.state.pair.enabled && !bloc.state.preparing) return true;
      final Future<DayNightState> stopped = bloc.stream.firstWhere(
        (DayNightState state) => !state.preparing && (!state.pair.enabled || state.issue != null),
      );
      bloc.add(const DayNightEvent.toggled(false));
      final DayNightState state = await stopped;
      if (state.pair.enabled) return false;
  }
  if (!context.mounted) return false;
  return true;
}
