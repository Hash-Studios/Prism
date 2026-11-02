import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism/prism_page.dart';
import 'package:Prism/features/editors_choice/biz/editors_choice_cubit.dart';
import 'package:Prism/features/moods/views/widgets/wall_ids_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Every Editors' Choice pick, newest first.
@RoutePage()
class EditorsChoiceScreen extends StatefulWidget {
  const EditorsChoiceScreen({super.key, @QueryParam('source') this.source = 'link'});

  /// Where the user opened the page: 'row' or 'link'. For analytics.
  final String source;

  @override
  State<EditorsChoiceScreen> createState() => _EditorsChoiceScreenState();
}

class _EditorsChoiceScreenState extends State<EditorsChoiceScreen> {
  static const int _loadLimit = 60;

  late final EditorsChoiceCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<EditorsChoiceCubit>();
    unawaited(_cubit.load(limit: _loadLimit));
    unawaited(analytics.track(EditorsChoiceOpenedEvent(source: widget.source)));
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: context.l10n.editorsChoiceTitle,
      body: BlocBuilder<EditorsChoiceCubit, EditorsChoiceState>(
        bloc: _cubit,
        builder: (context, state) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, EditorsChoiceState state) {
    final l10n = context.l10n;
    switch (state) {
      case EditorsChoiceLoading():
        return const LoadingCards(useFeedLayout: true);
      case EditorsChoiceFailed():
        return GlintState(
          kind: GlintStateKind.error,
          title: l10n.editorsChoiceLoadError,
          body: l10n.wallpaperCheckConnection,
          actionLabel: l10n.wallpaperTryAgain,
          onAction: () => unawaited(_cubit.load(limit: _loadLimit)),
        );
      case EditorsChoiceLoaded(:final walls) when walls.isEmpty:
        return GlintState(
          kind: GlintStateKind.empty,
          title: l10n.editorsChoiceEmptyTitle,
          body: l10n.editorsChoiceEmptyBody,
        );
      case EditorsChoiceLoaded(:final walls):
        return WallIdsGrid(walls: walls, header: l10n.editorsChoiceRowBody);
    }
  }
}
