import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_upload/biz/bloc/wall_metadata_cubit.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/data/repositories/wall_metadata_repository.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/domain/usecases/wall_metadata_actions.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/submission_metadata_form.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The shared submitted-wall editor. The selected authority never changes after a failed save.
/// Returns the canonical saved metadata, or null when cancelled.
class WallMetadataEditor extends StatefulWidget {
  const WallMetadataEditor({super.key, required this.wall, required this.approved, this.cubit});

  final FirestoreDocument wall;
  final bool approved;
  final WallMetadataCubit? cubit;

  @override
  State<WallMetadataEditor> createState() => _WallMetadataEditorState();
}

class _WallMetadataEditorState extends State<WallMetadataEditor> {
  late final WallMetadataCubit _cubit =
      widget.cubit ??
      WallMetadataCubit(
        WallMetadataActions(WallMetadataRepositoryImpl.fromGetIt()),
        wallDocId: widget.wall.id,
        approved: widget.approved,
      );
  GlobalKey<SubmissionMetadataFormState> _formKey = GlobalKey<SubmissionMetadataFormState>();
  int _formVersion = -1;
  bool _leaving = false;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    if (_cubit.state.snapshot == null) _cubit.load();
  }

  @override
  void dispose() {
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  bool _flush() => _formKey.currentState?.flush() ?? true;

  Future<void> _leave() async {
    if (_cubit.state.busy || _confirming || _leaving) return;
    _flush();
    if (_cubit.state.dirty) {
      _confirming = true;
      final bool discard = await showPrismConfirm(
        context,
        title: context.l10n.wallMetadataDiscardTitle,
        message: context.l10n.wallMetadataDiscardBody,
        confirmLabel: context.l10n.wallMetadataDiscard,
        destructive: true,
      );
      _confirming = false;
      if (!discard || !mounted) return;
    }
    _pop();
  }

  void _pop([WallMetadataSnapshot? result]) {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _reload() async {
    if (_cubit.state.busy || _confirming) return;
    _flush();
    if (_cubit.state.dirty) {
      _confirming = true;
      final bool reload = await showPrismConfirm(
        context,
        title: context.l10n.wallMetadataReloadTitle,
        message: context.l10n.wallMetadataReloadBody,
        confirmLabel: context.l10n.wallMetadataReload,
      );
      _confirming = false;
      if (!reload || !mounted) return;
    }
    await _cubit.load();
  }

  void _save() {
    if (_cubit.state.busy || _cubit.state.needsReload) return;
    if (!_flush()) return;
    FocusScope.of(context).unfocus();
    if (!_cubit.state.dirty) {
      _pop();
      return;
    }
    _cubit.save();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<WallMetadataCubit, WallMetadataState>(
    bloc: _cubit,
    listener: (context, state) {
      if (state.status == WallMetadataStatus.saved) {
        toasts.success(context.l10n.wallMetadataSaved);
        _pop(state.snapshot);
      }
    },
    builder: (context, state) {
      final PendingWallMetadata? draft = state.draft;
      if (state.formVersion != _formVersion) {
        _formVersion = state.formVersion;
        _formKey = GlobalKey<SubmissionMetadataFormState>();
      }
      return PopScope<WallMetadataSnapshot>(
        canPop: _leaving,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: PrismPage(
          title: context.l10n.wallMetadataEditDetails,
          onBack: _leave,
          body: state.status == WallMetadataStatus.loading && draft == null
              ? PrismSkeleton.rows(rows: 5, avatar: false)
              : draft == null
              ? GlintState(
                  kind: GlintStateKind.error,
                  title: context.l10n.wallMetadataLoadFailed,
                  body: wallMetadataFailureMessage(context.l10n, state.failure),
                  actionLabel: context.l10n.adminRetry,
                  onAction: _cubit.load,
                )
              : ListView(
                  padding: const EdgeInsets.all(PrismSpace.page),
                  children: <Widget>[
                    Text(
                      widget.approved ? context.l10n.wallMetadataApprovedHelp : context.l10n.wallMetadataPendingHelp,
                      style: PrismTextStyles.body(context),
                    ),
                    const SizedBox(height: PrismSpace.xl),
                    SubmissionMetadataForm(
                      key: _formKey,
                      initial: SubmissionMetadata(
                        title: draft.text.title,
                        description: draft.text.description,
                        tags: draft.text.tags,
                        category: draft.category,
                      ),
                      showCategory: !widget.approved,
                      enabled: !state.busy,
                      onChanged: (value) => _cubit.change(
                        PendingWallMetadata(
                          text: WallTextMetadata(title: value.title, description: value.description, tags: value.tags),
                          category: value.category,
                        ),
                      ),
                    ),
                    if (state.failure != null) ...<Widget>[
                      const SizedBox(height: PrismSpace.lg),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          wallMetadataFailureMessage(context.l10n, state.failure),
                          style: PrismTextStyles.body(context).copyWith(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                      if (state.needsReload)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: PrismButton(
                            label: context.l10n.wallMetadataReload,
                            variant: PrismButtonVariant.ghost,
                            onPressed: state.busy ? null : _reload,
                          ),
                        ),
                    ],
                  ],
                ),
          bottomBar: draft == null
              ? null
              : PrismButton(
                  label: context.l10n.wallMetadataSave,
                  loading: state.status == WallMetadataStatus.saving,
                  expand: true,
                  onPressed: state.busy || state.needsReload ? null : _save,
                ),
        ),
      );
    },
  );
}

String wallMetadataFailureMessage(AppLocalizations l10n, WallMetadataFailure? failure) => switch (failure) {
  WallMetadataFailure.conflict => l10n.wallMetadataConflict,
  WallMetadataFailure.statusChanged => l10n.wallMetadataStatusChanged,
  WallMetadataFailure.missing => l10n.wallMetadataMissing,
  WallMetadataFailure.denied => l10n.wallMetadataDenied,
  WallMetadataFailure.signedOut => l10n.wallMetadataSignedOut,
  WallMetadataFailure.invalid => l10n.wallMetadataInvalid,
  WallMetadataFailure.dailyLimit => l10n.wallMetadataDailyLimit,
  _ => l10n.wallMetadataUnavailable,
};
