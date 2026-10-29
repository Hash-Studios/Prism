import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/bloc/wall_resubmission_context_cubit.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/wall_metadata_actions.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A single bounded lookup for a queue snapshot, not one callable per card.
class WallResubmissionScope extends StatefulWidget {
  const WallResubmissionScope({super.key, required this.walls, required this.actions, required this.child});

  final List<FirestoreDocument> walls;
  final WallMetadataActions actions;
  final Widget child;

  @override
  State<WallResubmissionScope> createState() => _WallResubmissionScopeState();
}

class _WallResubmissionScopeState extends State<WallResubmissionScope> {
  late final WallResubmissionContextCubit _cubit = WallResubmissionContextCubit(widget.actions);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WallResubmissionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.walls, widget.walls)) _load();
  }

  void _load() => _cubit.load(widget.walls.map((wall) => wall.id).toList(growable: false));

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider<WallResubmissionContextCubit>.value(value: _cubit, child: widget.child);
}

class WallResubmissionNotice extends StatelessWidget {
  const WallResubmissionNotice({super.key, required this.wallDocId, this.onImage = false});

  final String wallDocId;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final WallResubmissionContextCubit? cubit = context.read<WallResubmissionContextCubit?>();
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<WallResubmissionContextCubit, WallResubmissionContextState>(
      bloc: cubit,
      builder: (context, state) {
        final WallResubmissionContext? receipt = state.contexts[wallDocId];
        if (receipt == null && !state.failed) return const SizedBox.shrink();
        final ColorScheme cs = Theme.of(context).colorScheme;
        final TextStyle style = PrismTextStyles.caption(
          context,
        ).copyWith(color: onImage ? PrismColors.onPrimary : cs.onSurface);
        return Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(top: PrismSpace.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  receipt == null
                      ? context.l10n.wallMetadataContextUnavailable
                      : context.l10n.wallMetadataResubmitted(receipt.attempt),
                  style: style,
                ),
                if (receipt != null && receipt.previousReason.isNotEmpty) ...<Widget>[
                  const SizedBox(height: PrismSpace.xxs),
                  Text(context.l10n.wallMetadataPreviousReason, style: style),
                  Text(receipt.previousReason, style: style),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
