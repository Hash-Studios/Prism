import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_directory/biz/creator_directory_opt_out_cubit.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Settings switch that lists the signed-in viewer in the creator directory. Off writes `creatorDirectoryOptOut`.
class CreatorDirectoryOptOutRow extends StatelessWidget {
  const CreatorDirectoryOptOutRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CreatorDirectoryOptOutCubit>(
      create: (_) => getIt<CreatorDirectoryOptOutCubit>()..load(),
      child: BlocBuilder<CreatorDirectoryOptOutCubit, OptOutState>(
        builder: (context, state) => PrismSwitchRow(
          icon: Icons.person_search_rounded,
          title: context.l10n.creatorsShowMeTitle,
          subtitle: context.l10n.creatorsShowMeBody,
          value: !state.optOut,
          onChanged: state.loaded ? (bool show) => _set(context, show) : null,
        ),
      ),
    );
  }

  Future<void> _set(BuildContext context, bool show) async {
    final String failed = context.l10n.coreSomethingWentWrong;
    if (!await context.read<CreatorDirectoryOptOutCubit>().setOptedOut(!show)) toasts.error(failed);
  }
}
