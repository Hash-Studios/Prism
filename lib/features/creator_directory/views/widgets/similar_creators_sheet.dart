import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_directory/biz/creator_directory_cubit.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/views/widgets/creator_directory_card.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/follow_outcome_toast.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the "More like" sheet for [name]. Following a creator here does not close the sheet.
Future<void> showSimilarCreatorsSheet(
  BuildContext context, {
  required String name,
  required List<DirectoryCreator> creators,
}) {
  return showPrismSheet<void>(
    context,
    useRootNavigator: true,
    builder: (_) => _SimilarCreatorsSheet(name: name, creators: creators),
  );
}

class _SimilarCreatorsSheet extends StatelessWidget {
  const _SimilarCreatorsSheet({required this.name, required this.creators});

  final String name;
  final List<DirectoryCreator> creators;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<PublicProfileBloc>(create: (_) => getIt<PublicProfileBloc>()),
        BlocProvider<CreatorDirectoryCubit>(create: (_) => getIt<CreatorDirectoryCubit>()..show(creators)),
      ],
      child: BlocListener<PublicProfileBloc, PublicProfileState>(
        listenWhen: (prev, curr) => curr.followOutcome != null && prev.followOutcome != curr.followOutcome,
        listener: (context, state) => showFollowOutcomeToast(context, state.followOutcome!),
        child: PrismSheetBody(
          title: context.l10n.creatorsMoreLike(name),
          message: context.l10n.creatorsSimilarSubtitle,
          child: BlocBuilder<CreatorDirectoryCubit, CreatorDirectoryState>(
            builder: (context, state) => Column(
              children: <Widget>[
                for (final DirectoryCreator c in state.creators)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: PrismSpace.xs),
                    child: CreatorFollowRow(creator: c.entry, followed: false, source: 'similar', avatarSize: 44),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
