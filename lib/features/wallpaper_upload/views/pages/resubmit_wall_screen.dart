import 'dart:io';

import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_upload/biz/resubmission_cubit.dart';
import 'package:Prism/features/wallpaper_upload/biz/resubmission_seed.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/data/resubmission_repository.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/rejection_feedback.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/submission_metadata_form.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class ResubmitWallScreen extends StatefulWidget {
  const ResubmitWallScreen({super.key, required this.rejectedDocId, this.cubit});
  final String rejectedDocId;
  final ResubmissionCubit? cubit;

  @override
  State<ResubmitWallScreen> createState() => _ResubmitWallScreenState();
}

class _ResubmitWallScreenState extends State<ResubmitWallScreen> {
  late final cubit =
      widget.cubit ??
      ResubmissionCubit(
        ResubmissionRepository(firestoreClient),
        uid: app_state.prismUser.id,
        email: app_state.prismUser.email,
      );
  final formKey = GlobalKey<SubmissionMetadataFormState>();
  SubmissionMetadata? metadata;
  bool picking = false;

  @override
  void initState() {
    super.initState();
    if (widget.cubit == null) cubit.load(widget.rejectedDocId);
  }

  @override
  void dispose() {
    if (widget.cubit == null) cubit.close();
    super.dispose();
  }

  Future<void> _choose() async {
    if (picking) return;
    setState(() => picking = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (mounted && picked != null && app_state.prismUser.id == cubit.uid) cubit.chooseImage(File(picked.path));
    } catch (_) {
      if (mounted) toasts.error(context.l10n.wallResubmitUnavailable);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void _continue(ResubmissionPreparation preparation) {
    if (app_state.prismUser.id != cubit.uid || preparation.original == null) return;
    if (formKey.currentState?.flush() == false) return;
    final seed = preparation.seed;
    context.router.push(
      UploadWallRoute(
        image: preparation.original!,
        resubmission: ResubmissionSeed(
          rejectedDocId: seed.rejectedDocId,
          metadata: metadata ?? seed.metadata,
          previousReason: seed.previousReason,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ResubmissionCubit, ResubmissionState>(
    bloc: cubit,
    builder: (context, state) {
      final preparation = state.preparation;
      return PrismPage(
        title: context.l10n.wallResubmitTitle,
        bottomBar: preparation?.original == null
            ? null
            : PrismButton(label: context.l10n.wallpaperSave, expand: true, onPressed: () => _continue(preparation!)),
        body: state.loading
            ? PrismSkeleton.rows()
            : state.failed || preparation == null
            ? GlintState(
                kind: GlintStateKind.error,
                title: context.l10n.wallResubmitUnavailable,
                actionLabel: context.l10n.wallpaperTryAgain,
                onAction: () => cubit.load(widget.rejectedDocId),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(PrismSpace.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    RejectionFeedback(reason: preparation.seed.previousReason),
                    const SizedBox(height: PrismSpace.md),
                    Text(
                      preparation.original != null
                          ? context.l10n.wallResubmitImageKept
                          : preparation.unsupportedSource
                          ? context.l10n.wallResubmitUnsupported
                          : context.l10n.wallResubmitImageMissing,
                      style: PrismTextStyles.body(context),
                    ),
                    PrismButton(
                      label: context.l10n.wallResubmitChooseImage,
                      variant: PrismButtonVariant.ghost,
                      loading: picking,
                      onPressed: picking ? null : _choose,
                    ),
                    const SizedBox(height: PrismSpace.lg),
                    SubmissionMetadataForm(
                      key: formKey,
                      initial: preparation.seed.metadata,
                      onChanged: (value) => metadata = value,
                    ),
                  ],
                ),
              ),
      );
    },
  );
}
