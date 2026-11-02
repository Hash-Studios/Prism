import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:Prism/features/wall_comments/views/wall_comments_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// The comments button in the wall detail action bar, with the visible-comment count beside it.
class CommentsButton extends StatefulWidget {
  const CommentsButton({super.key, required this.wall});

  final CommentsWall wall;

  @override
  State<CommentsButton> createState() => _CommentsButtonState();
}

class _CommentsButtonState extends State<CommentsButton> {
  @override
  void initState() {
    super.initState();
    getIt<FavouriteCountsCubit>().request(widget.wall.statsId);
  }

  @override
  void didUpdateWidget(CommentsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wall.statsId != widget.wall.statsId) getIt<FavouriteCountsCubit>().request(widget.wall.statsId);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircularMenuButton(
          label: l10n.commentsAction,
          isLoading: false,
          onTap: () => showWallCommentsSheet(context, widget.wall),
          child: const Icon(Icons.chat_bubble_outline_rounded),
        ),
        BlocSelector<FavouriteCountsCubit, Map<String, PrismWallpaperStats>, int>(
          bloc: getIt<FavouriteCountsCubit>(),
          selector: (Map<String, PrismWallpaperStats> stats) => stats[prismStatsId(widget.wall.statsId)]?.comments ?? 0,
          builder: (BuildContext context, int count) => count <= 0
              ? const SizedBox.shrink()
              : Semantics(
                  container: true,
                  label: l10n.commentsCountLabel(count),
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: PrismSpace.xxs),
                      child: Text(
                        (NumberFormat.compact(locale: l10n.localeName)..maximumFractionDigits = 1).format(count),
                        style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
