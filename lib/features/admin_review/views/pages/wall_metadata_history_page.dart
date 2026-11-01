import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/bloc/wall_metadata_history_cubit.dart';
import 'package:Prism/features/wallpaper_upload/data/repositories/wall_metadata_repository.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/wall_metadata_actions.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/wall_metadata_editor.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WallMetadataHistoryPage extends StatefulWidget {
  const WallMetadataHistoryPage({super.key, required this.wallDocId, this.cubit});

  final String wallDocId;
  final WallMetadataHistoryCubit? cubit;

  @override
  State<WallMetadataHistoryPage> createState() => _WallMetadataHistoryPageState();
}

class _WallMetadataHistoryPageState extends State<WallMetadataHistoryPage> {
  late final WallMetadataHistoryCubit _cubit =
      widget.cubit ??
      WallMetadataHistoryCubit(
        WallMetadataActions(WallMetadataRepositoryImpl.fromGetIt()),
        wallDocId: widget.wallDocId,
      );
  bool _leaving = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _cubit.load();
  }

  @override
  void dispose() {
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  void _leave() {
    if (_cubit.state.busy || _confirming || _leaving) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(_cubit.state.revertedCount > 0);
    });
  }

  Future<void> _revert(WallMetadataAudit audit) async {
    if (_cubit.state.busy || _confirming) return;
    _confirming = true;
    final bool confirmed = await showPrismConfirm(
      context,
      title: context.l10n.wallMetadataRevertTitle,
      message: context.l10n.wallMetadataRevertBody,
      confirmLabel: context.l10n.wallMetadataRevert,
    );
    _confirming = false;
    if (confirmed && mounted) await _cubit.revert(audit);
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<WallMetadataHistoryCubit, WallMetadataHistoryState>(
    bloc: _cubit,
    listenWhen: (before, after) => after.revertedCount > before.revertedCount,
    listener: (context, state) => toasts.success(context.l10n.wallMetadataReverted),
    builder: (context, state) => PopScope<bool>(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: PrismPage(
        title: context.l10n.wallMetadataHistory,
        onBack: _leave,
        actions: <Widget>[
          PrismIconButton(
            icon: Icons.refresh_rounded,
            tooltip: context.l10n.wallMetadataReload,
            onPressed: state.busy ? null : () => _cubit.load(),
          ),
        ],
        body: state.loading
            ? PrismSkeleton.rows(rows: 5, avatar: false)
            : state.edits.isEmpty
            ? GlintState(
                kind: state.failure == null ? GlintStateKind.empty : GlintStateKind.error,
                title: state.failure == null
                    ? context.l10n.wallMetadataHistoryEmpty
                    : context.l10n.wallMetadataHistoryFailed,
                body: state.failure == null
                    ? context.l10n.wallMetadataHistoryEmptyBody
                    : wallMetadataFailureMessage(context.l10n, state.failure),
                actionLabel: state.failure == null ? null : context.l10n.adminRetry,
                onAction: state.failure == null ? null : () => _cubit.load(),
              )
            : ListView(
                padding: const EdgeInsets.all(PrismSpace.page),
                children: <Widget>[
                  if (state.failure != null) ...<Widget>[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        wallMetadataFailureMessage(context.l10n, state.failure),
                        style: PrismTextStyles.body(context).copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                    const SizedBox(height: PrismSpace.lg),
                  ],
                  for (final WallMetadataAudit audit in state.edits) ...<Widget>[
                    Text(audit.actorUid, style: PrismTextStyles.rowTitle(context)),
                    if (audit.createdAt != null)
                      Text(
                        MaterialLocalizations.of(context).formatFullDate(audit.createdAt!.toLocal()),
                        style: PrismTextStyles.caption(context),
                      ),
                    const SizedBox(height: PrismSpace.sm),
                    _textTuple(context, context.l10n.wallMetadataBefore, audit.before),
                    const SizedBox(height: PrismSpace.md),
                    _textTuple(context, context.l10n.wallMetadataAfter, audit.after),
                    if (audit.canRevert)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: PrismButton(
                          label: context.l10n.wallMetadataRevert,
                          variant: PrismButtonVariant.tonal,
                          loading: state.busy,
                          onPressed: state.busy || state.failure != null ? null : () => _revert(audit),
                        ),
                      ),
                    const SizedBox(height: PrismSpace.lg),
                    const Divider(),
                    const SizedBox(height: PrismSpace.lg),
                  ],
                  if (state.cursor != null)
                    PrismButton(
                      label: context.l10n.wallMetadataLoadMore,
                      variant: PrismButtonVariant.ghost,
                      loading: state.busy,
                      onPressed: state.busy ? null : () => _cubit.load(more: true),
                    ),
                ],
              ),
      ),
    ),
  );

  Widget _textTuple(BuildContext context, String heading, Map<String, dynamic> tuple) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(heading, style: PrismTextStyles.cardTitle(context)),
      const SizedBox(height: PrismSpace.xs),
      for (final (String key, String label) in <(String, String)>[
        ('title', context.l10n.wallpaperTitle),
        ('desc', context.l10n.wallMetadataDescription),
        ('tags', context.l10n.wallpaperUploadTags),
      ]) ...<Widget>[
        Text(label, style: PrismTextStyles.caption(context)),
        SelectableText(
          !tuple.containsKey(key)
              ? context.l10n.wallMetadataAbsent
              : tuple[key] is List
              ? (tuple[key] as List).join(', ')
              : tuple[key]?.toString() ?? '',
          style: PrismTextStyles.body(context).copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: PrismSpace.xs),
      ],
    ],
  );
}
