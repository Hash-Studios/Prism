import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/upload_failure.dart';
import 'package:Prism/data/upload/upload_id.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:Prism/env/env.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_batch.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_quality.dart';
import 'package:Prism/features/wallpaper_upload/data/upload_draft_store.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/submission_metadata_form.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/upload_batch_stepper.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/upload_checks_card.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/upload_preview_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

// The generated routes name these types in their arguments.
export 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart' show SubmissionMetadata;
export 'package:Prism/features/wallpaper_upload/biz/upload_batch.dart' show UploadBatch;

@RoutePage()
class UploadWallScreen extends StatefulWidget {
  const UploadWallScreen({
    super.key,
    required this.image,
    this.batch,
    @visibleForTesting this.imageSizeForTesting,
    @visibleForTesting this.prepareImageForTesting,
    @visibleForTesting this.uploadFileForTesting,
    @visibleForTesting this.deleteFileForTesting,
    @visibleForTesting this.createRecordForTesting,
    @visibleForTesting this.createRecordWithMetadataForTesting,
    @visibleForTesting this.presentPaywallForTesting,
    @visibleForTesting this.nowForTesting,
    @visibleForTesting this.draftStoreForTesting,
  });

  final File image;

  /// Set when this image is one of several picked together. All screens of the batch share this object.
  final UploadBatch? batch;

  @visibleForTesting
  final Size? imageSizeForTesting;

  @visibleForTesting
  final Future<void> Function()? prepareImageForTesting;

  @visibleForTesting
  final Future<GitHubContent> Function({required bool isThumbnail})? uploadFileForTesting;

  @visibleForTesting
  final Future<void> Function({required String path, required String sha})? deleteFileForTesting;

  @visibleForTesting
  final Future<wall_store.WallSubmissionResult> Function()? createRecordForTesting;

  @visibleForTesting
  final Future<wall_store.WallSubmissionResult> Function({required String id, required SubmissionMetadata metadata})?
  createRecordWithMetadataForTesting;

  @visibleForTesting
  final Future<void> Function()? presentPaywallForTesting;

  @visibleForTesting
  final DateTime Function()? nowForTesting;

  @visibleForTesting
  final UploadDraftStore? draftStoreForTesting;

  @override
  State<UploadWallScreen> createState() => _UploadWallScreenState();
}

enum _UploadStage {
  processing,
  ready,
  uploading,
  saving,
  failedProcessing,
  failedUpload,
  failedSubmission,
  quotaExceeded,
}

enum _UploadExitChoice { keepDraft, discard, cancel }

class _UploadWallScreenState extends State<UploadWallScreen> {
  late final String id = randomUploadId(uploadIdLength);
  late final UploadDraftStore _draftStore = widget.draftStoreForTesting ?? UploadDraftStore();
  late final String _draftOwner;
  File? _draftImage;
  String? _draftId;
  int _draftSaveGeneration = 0;
  _UploadStage _stage = _UploadStage.processing;
  String? _errorMessage;
  String? wallpaperResolution;
  String? wallpaperProvider = 'Prism';
  String? wallpaperSize;
  String? wallpaperDesc = 'Community';
  String? wallpaperThumb;
  String? wallpaperUrl;
  String? wallpaperSha;
  String? thumbSha;
  String? wallpaperPath;
  String? thumbPath;
  String? _fileName;
  String? _wallDocId;
  bool _oversize = false;
  int? _imageWidth;
  int? _imageHeight;
  SubmissionMetadata _metadata = const SubmissionMetadata();
  late List<int> imageBytes;
  late List<int> imageBytesThumb;
  bool _submitted = false;
  bool _submissionAttempted = false;
  bool _submissionUnresolved = false;
  bool _discarding = false;
  bool _leaving = false;

  bool get _isBusy =>
      _stage == _UploadStage.processing ||
      _stage == _UploadStage.uploading ||
      _stage == _UploadStage.saving ||
      _discarding;
  bool get _hasStagedFiles => wallpaperSha != null || thumbSha != null;
  File get _selectedImage => _draftImage ?? widget.image;
  String get _activeDraftOwner => app_state.prismUser.loggedIn && app_state.prismUser.id.trim().isNotEmpty
      ? app_state.prismUser.id
      : UploadDraftStore.guestOwner;

  @override
  void dispose() {
    if (!_leaving && !_submitted && !_submissionAttempted && !_isBusy && _hasStagedFiles) {
      unawaited(_deleteFile());
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _draftOwner = _activeDraftOwner;
    unawaited(_prepareImage());
  }

  Future<Uint8List> _compressFile(File file) async {
    final result = await FlutterImageCompress.compressWithFile(file.absolute.path, minWidth: 400, quality: 85);
    if (result == null || result.isEmpty) {
      throw StateError('Could not create a wallpaper preview.');
    }
    return result;
  }

  Future<void> _prepareImage() async {
    setState(() {
      _oversize = false;
      _stage = _UploadStage.processing;
      _errorMessage = null;
    });
    try {
      if (widget.prepareImageForTesting case final prepareImageForTesting?) {
        await prepareImageForTesting();
        if (!mounted) return;
        if (widget.draftStoreForTesting != null && await widget.image.exists()) {
          final Uint8List bytes = await widget.image.readAsBytes();
          _draftId ??= UploadDraftStore.idForBytes(bytes);
          final UploadDraft? restoredDraft = await _draftStore.read(owner: _draftOwner, draftId: _draftId!);
          if (restoredDraft != null) {
            _draftImage = restoredDraft.file;
            _metadata = restoredDraft.metadata;
          }
        }
        imageBytes = <int>[];
        imageBytesThumb = <int>[];
        final Size testSize = widget.imageSizeForTesting ?? const Size(1, 1);
        setState(() {
          _imageWidth = testSize.width.round();
          _imageHeight = testSize.height.round();
          wallpaperResolution = '${_imageWidth}x$_imageHeight';
          wallpaperSize = '0.00MB';
          _stage = _UploadStage.ready;
        });
        _trackStage('ready');
        if (widget.draftStoreForTesting != null && _draftId != null) {
          unawaited(_persistDraft().then<void>((_) {}));
        }
        return;
      }
      final Uint8List imgList = await widget.image.readAsBytes();
      if (imgList.length > maxUploadBytes) {
        if (!mounted) return;
        setState(() {
          _oversize = true;
          _stage = _UploadStage.failedProcessing;
          _errorMessage = UploadFailure.oversize.message(context.l10n);
        });
        _trackFailure('oversize');
        return;
      }
      _draftId ??= UploadDraftStore.idForBytes(imgList);
      final UploadDraft? restoredDraft = await _draftStore.read(owner: _draftOwner, draftId: _draftId!);
      if (restoredDraft != null) {
        _draftImage = restoredDraft.file;
        _metadata = restoredDraft.metadata;
      }
      final File selectedImage = _selectedImage;
      final decodedImage = await decodeImageFromList(imgList);
      final resolution = '${decodedImage.width}x${decodedImage.height}';
      _imageWidth = decodedImage.width;
      _imageHeight = decodedImage.height;
      decodedImage.dispose();
      imageBytes = imgList;
      imageBytesThumb = await _compressFile(selectedImage);
      final size = await selectedImage.length();
      if (!mounted) {
        return;
      }
      setState(() {
        wallpaperResolution = resolution;
        wallpaperSize = '${(size / 1024 / 1024).toStringAsFixed(2)}MB';
      });
      if (mounted) setState(() => _stage = _UploadStage.ready);
      _trackStage('ready');
      unawaited(_persistDraft().then<void>((_) {}));
    } catch (error) {
      logger.w('Wallpaper preparation failed: $error');
      if (!mounted) return;
      setState(() {
        _stage = _UploadStage.failedProcessing;
        _errorMessage = context.l10n.wallpaperUploadPrepareError;
      });
      _trackFailure('processing');
    }
  }

  Future<bool> _deleteFile() async {
    final github = GitHubContentApi();
    try {
      if (wallpaperPath != null && wallpaperSha != null) {
        if (widget.deleteFileForTesting case final deleteFileForTesting?) {
          await deleteFileForTesting(path: wallpaperPath!, sha: wallpaperSha!);
        } else {
          await github.deleteFile(
            repo: Env.normalize(Env.ghRepoWalls),
            path: wallpaperPath!,
            sha: wallpaperSha!,
            message: wallpaperPath!,
          );
        }
        wallpaperPath = null;
        wallpaperSha = null;
        wallpaperUrl = null;
      }
      if (thumbPath != null && thumbSha != null) {
        if (widget.deleteFileForTesting case final deleteFileForTesting?) {
          await deleteFileForTesting(path: thumbPath!, sha: thumbSha!);
        } else {
          await github.deleteFile(
            repo: Env.normalize(Env.ghRepoWalls),
            path: thumbPath!,
            sha: thumbSha!,
            message: thumbPath!,
          );
        }
        thumbPath = null;
        thumbSha = null;
        wallpaperThumb = null;
      }
      logger.d('Unsubmitted wallpaper files deleted');
      return true;
    } catch (error) {
      logger.w('Could not delete unsubmitted upload: $error');
      return false;
    }
  }

  Future<bool> _uploadFiles() async {
    if (!mounted || _leaving) return false;
    setState(() {
      _stage = _UploadStage.uploading;
      _errorMessage = null;
    });
    try {
      final hasIncompleteFile =
          (wallpaperPath != null && wallpaperSha != null && wallpaperUrl == null) ||
          (thumbPath != null && thumbSha != null && wallpaperThumb == null);
      if (hasIncompleteFile && !await _deleteFile()) {
        throw StateError('Could not remove an incomplete upload before retrying.');
      }
      if (!mounted || _leaving) return false;
      final github = GitHubContentApi();
      final baseName = _fileName ??= uploadFileName(
        uid: app_state.prismUser.id,
        epochMs: (widget.nowForTesting ?? DateTime.now)().millisecondsSinceEpoch,
        basename: path.basename(_selectedImage.path),
      );
      final thumbName = uploadThumbName(baseName);
      if (wallpaperUrl == null || wallpaperPath == null || wallpaperSha == null) {
        final value = widget.uploadFileForTesting != null
            ? await widget.uploadFileForTesting!(isThumbnail: false)
            : await github.putFile(
                repo: Env.normalize(Env.ghRepoWalls),
                message: baseName,
                contentBase64: base64Encode(imageBytes),
                path: baseName,
              );
        wallpaperUrl = value.downloadUrl;
        wallpaperPath = value.path ?? baseName;
        wallpaperSha = value.sha;
        if (wallpaperUrl == null || wallpaperPath == null || wallpaperSha == null) {
          throw StateError('The wallpaper upload returned incomplete file details.');
        }
      }
      if (!mounted || _leaving) {
        await _deleteFile();
        return false;
      }
      if (wallpaperThumb == null || thumbPath == null || thumbSha == null) {
        final thumbValue = widget.uploadFileForTesting != null
            ? await widget.uploadFileForTesting!(isThumbnail: true)
            : await github.putFile(
                repo: Env.normalize(Env.ghRepoWalls),
                message: thumbName,
                contentBase64: base64Encode(imageBytesThumb),
                path: thumbName,
              );
        wallpaperThumb = thumbValue.downloadUrl;
        thumbPath = thumbValue.path ?? thumbName;
        thumbSha = thumbValue.sha;
        if (wallpaperThumb == null || thumbPath == null || thumbSha == null) {
          throw StateError('The preview upload returned incomplete file details.');
        }
      }
      if (!mounted || _leaving) {
        await _deleteFile();
        return false;
      }
      return true;
    } catch (error) {
      logger.w('Wallpaper upload failed: $error');
      if (!mounted || _leaving) {
        await _deleteFile();
        return false;
      }
      final failure = UploadFailure.from(error);
      setState(() {
        _stage = _UploadStage.failedUpload;
        _errorMessage = failure.message(context.l10n);
      });
      _trackFailure(failure.weeklyLimit ? 'weekly_limit' : 'upload');
      if (failure.weeklyLimit) unawaited(_presentUploadLimitPaywall());
      return false;
    }
  }

  void _trackStage(String stage) => unawaited(analytics.track(UploadStageEvent(stage: stage)));

  void _trackFailure(String reason) => unawaited(analytics.track(UploadFailedEvent(reason: reason)));

  Future<void> _presentUploadLimitPaywall() async {
    if (widget.presentPaywallForTesting case final presentPaywallForTesting?) {
      await presentPaywallForTesting();
      return;
    }
    await PaywallOrchestrator.instance.present(
      placement: PaywallPlacement.uploadLimitReached,
      source: 'upload_wallpaper_limit_reached',
    );
  }

  Future<void> _retryUpload() async {
    if (_stage == _UploadStage.failedProcessing) {
      await _prepareImage();
    }
  }

  Future<void> _submit() async {
    if ((_stage != _UploadStage.ready && _stage != _UploadStage.failedUpload) ||
        _submitted ||
        _discarding ||
        _leaving) {
      return;
    }
    setState(() {
      _stage = _UploadStage.uploading;
      _errorMessage = null;
    });
    _trackStage('uploading');
    if (!await _uploadFiles() || !mounted || _leaving) return;
    await _saveRecord();
  }

  Future<void> _retrySubmit() async {
    if (_stage != _UploadStage.failedSubmission || _submitted || _leaving) return;
    await _saveRecord();
  }

  Future<void> _saveRecord() async {
    setState(() {
      _stage = _UploadStage.saving;
      _errorMessage = null;
    });
    _trackStage('saving');
    _submissionAttempted = true;
    try {
      final result = widget.createRecordWithMetadataForTesting != null
          ? await widget.createRecordWithMetadataForTesting!(id: id, metadata: _metadata)
          : widget.createRecordForTesting != null
          ? await widget.createRecordForTesting!()
          : await wall_store.createRecord(
              id,
              wallpaperProvider,
              wallpaperThumb,
              wallpaperUrl,
              wallpaperResolution,
              wallpaperSize,
              _metadata.title,
              _metadata.category,
              wallpaperDesc,
              false,
              wallpaperTags: _metadata.tags,
              wallpaperPath: wallpaperPath,
              wallpaperSha: wallpaperSha,
              thumbPath: thumbPath,
              thumbSha: thumbSha,
              docId: _wallDocId ??= 'wall_${_fileName ?? id}',
            );
      if (result == wall_store.WallSubmissionResult.quotaExceeded && _submissionUnresolved) {
        setState(() {
          _stage = _UploadStage.failedSubmission;
          _errorMessage = context.l10n.wallpaperUploadSubmissionUnconfirmed;
        });
        _trackFailure('submission_unconfirmed');
        return;
      }
      _submissionUnresolved = false;
      if (result == wall_store.WallSubmissionResult.quotaExceeded) {
        _submissionAttempted = false;
        final deleted = await _deleteFile();
        if (!mounted) return;
        setState(() {
          _stage = _UploadStage.quotaExceeded;
          _errorMessage = deleted
              ? context.l10n.wallpaperUploadQuotaReached
              : context.l10n.wallpaperUploadQuotaCleanupFailed;
        });
        _trackFailure('quota_exceeded');
        return;
      }
    } catch (error) {
      logger.w('Wallpaper submission failed: $error');
      _submissionUnresolved = true;
      if (!mounted) return;
      setState(() {
        _stage = _UploadStage.failedSubmission;
        _errorMessage = context.l10n.wallpaperUploadSubmissionUnconfirmed;
      });
      _trackFailure('submission');
      return;
    }
    _submitted = true;
    if (_draftId case final draftId?) {
      try {
        await _draftStore.discard(owner: _draftOwner, draftId: draftId);
      } catch (error, stackTrace) {
        logger.w('Submitted upload draft could not be cleared', error: error, stackTrace: stackTrace);
      }
    }
    analytics.track(UploadWallpaperEvent(assetId: id, link: wallpaperUrl!));
    analytics.track(
      UploadMetadataSubmittedEvent(
        hasTitle: _metadata.hasTitle,
        tagCount: _metadata.tags.length,
        category: _metadata.category,
      ),
    );
    _trackStage('submitted');
    if (!mounted || _leaving) return;
    widget.batch?.finishCurrent(UploadItemOutcome.submitted);
    await _goToNextOrFinish();
  }

  /// Opens the next image of a batch, or ends the flow on Review status.
  Future<void> _goToNextOrFinish() async {
    final batch = widget.batch;
    final router = context.router;
    if (batch != null && batch.hasNext) {
      batch.advance();
      unawaited(router.replace(EditWallRoute(image: batch.current, batch: batch)));
      return;
    }
    if (batch != null && batch.isMulti) toasts.info(batch.summary(context.l10n));
    if (batch == null || batch.submittedCount > 0) {
      showGlintToast(context);
      Navigator.pop(context);
      unawaited(router.push(const ReviewRoute()));
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _skip() async {
    final batch = widget.batch;
    if (batch == null || _isBusy || _submitted || _leaving) return;
    final failed =
        _stage == _UploadStage.failedProcessing ||
        _stage == _UploadStage.failedUpload ||
        _stage == _UploadStage.failedSubmission;
    if (_hasStagedFiles && !_submissionAttempted && !await _deleteFile()) {
      if (mounted) toasts.error(context.l10n.wallpaperUploadFilesRemoveError);
      return;
    }
    if (!mounted) return;
    batch.finishCurrent(failed ? UploadItemOutcome.failed : UploadItemOutcome.skipped);
    await _goToNextOrFinish();
  }

  void _onPop() {
    _leaving = true;
    if (!_submitted && !_submissionAttempted && !_isBusy) unawaited(_deleteFile());
  }

  Future<void> _confirmExit() async {
    final AppLocalizations l10n = context.l10n;
    final String? draftId = _draftId;
    if (draftId != null) {
      final _UploadExitChoice? choice = await showPrismSheet<_UploadExitChoice>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => PrismSheetBody(
          title: context.l10n.wallpaperUploadLeaveTitle,
          message: context.l10n.wallpaperUploadLeaveBody,
          actions: <Widget>[
            PrismButton(
              label: context.l10n.wallpaperUploadKeepDraft,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(_UploadExitChoice.keepDraft),
            ),
            PrismButton(
              label: context.l10n.wallpaperDiscard,
              expand: true,
              variant: PrismButtonVariant.danger,
              onPressed: () => Navigator.of(sheetContext).pop(_UploadExitChoice.discard),
            ),
            PrismButton(
              label: context.l10n.actionCancel,
              expand: true,
              variant: PrismButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext).pop(_UploadExitChoice.cancel),
            ),
          ],
        ),
      );
      if (!mounted || choice == null || choice == _UploadExitChoice.cancel) return;
      if (choice == _UploadExitChoice.keepDraft) {
        if (_discarding) return;
        setState(() => _discarding = true);
        final bool saved = await _persistDraft();
        if (!mounted) return;
        setState(() => _discarding = false);
        if (!saved) {
          toasts.error(context.l10n.wallpaperUploadDraftSaveError);
          return;
        }
        Navigator.pop(context);
        return;
      }
    } else {
      final bool discard = await showPrismConfirm(
        context,
        title: context.l10n.wallpaperUploadDiscardTitle,
        message: context.l10n.wallpaperUploadDiscardBody,
        confirmLabel: context.l10n.wallpaperDiscard,
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    if (_discarding) return;
    setState(() => _discarding = true);
    final deleted = await _deleteFile();
    if (!mounted) return;
    if (!deleted) {
      setState(() => _discarding = false);
      toasts.error(context.l10n.wallpaperUploadFilesRemoveError);
      return;
    }
    if (_draftId case final draftId?) {
      try {
        await _draftStore.discard(owner: _draftOwner, draftId: draftId);
      } catch (error, stackTrace) {
        logger.w('Upload draft could not be discarded', error: error, stackTrace: stackTrace);
        setState(() => _discarding = false);
        toasts.error(l10n.wallpaperUploadDiscardError);
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<bool> _persistDraft() async {
    final String? draftId = _draftId;
    if (draftId == null || _submitted || _activeDraftOwner != _draftOwner) return false;
    final int generation = ++_draftSaveGeneration;
    final String owner = _draftOwner;
    try {
      final UploadDraft draft = await _draftStore.save(
        owner: owner,
        draftId: draftId,
        selectedFile: _selectedImage,
        metadata: _metadata,
      );
      if (mounted && generation == _draftSaveGeneration && owner == _draftOwner && owner == _activeDraftOwner) {
        setState(() {
          _draftImage = draft.file;
        });
        return true;
      }
      return false;
    } catch (error, stackTrace) {
      logger.w('Upload draft could not be saved', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  List<UploadQualityWarning> get _qualityWarnings {
    final width = _imageWidth;
    final height = _imageHeight;
    if (width == null || height == null || _stage == _UploadStage.processing) return const <UploadQualityWarning>[];
    return uploadQualityWarnings(width: width, height: height);
  }

  bool get _showMetadataForm => _stage == _UploadStage.ready || _stage == _UploadStage.failedUpload;

  bool get _canSkip =>
      widget.batch != null &&
      !_discarding &&
      (_stage == _UploadStage.ready ||
          _stage == _UploadStage.failedProcessing ||
          _stage == _UploadStage.failedUpload ||
          _stage == _UploadStage.failedSubmission);

  String get _stageTitle => switch (_stage) {
    _UploadStage.processing => context.l10n.wallpaperUploadStagePreparing,
    _UploadStage.uploading => context.l10n.wallpaperUploadStageUploading,
    _UploadStage.ready => context.l10n.wallpaperUploadStageReady,
    _UploadStage.saving => context.l10n.wallpaperUploadStageSubmitting,
    _UploadStage.failedProcessing => context.l10n.wallpaperUploadStagePrepareFailed,
    _UploadStage.failedUpload => context.l10n.wallpaperUploadStageUploadFailed,
    _UploadStage.failedSubmission => context.l10n.wallpaperUploadStageSubmissionFailed,
    _UploadStage.quotaExceeded => context.l10n.wallpaperUploadStageQuotaReached,
  };

  bool get _failed =>
      _stage == _UploadStage.failedProcessing ||
      _stage == _UploadStage.failedUpload ||
      _stage == _UploadStage.failedSubmission ||
      _stage == _UploadStage.quotaExceeded;

  List<UploadCheck> get _checks {
    final (int current, bool working) = switch (_stage) {
      _UploadStage.processing => (0, true),
      _UploadStage.uploading => (1, true),
      _UploadStage.saving => (2, true),
      _ => (1, false),
    };
    UploadCheckState stateOf(int step) => step < current
        ? UploadCheckState.done
        : step == current && working
        ? UploadCheckState.active
        : UploadCheckState.pending;
    String text(int step, {required String pending, required String active, required String done}) =>
        switch (stateOf(step)) {
          UploadCheckState.done => done,
          UploadCheckState.active => active,
          UploadCheckState.pending => pending,
        };
    return <UploadCheck>[
      UploadCheck(
        stateOf(0),
        text(
          0,
          pending: context.l10n.wallpaperUploadPrepareCheckPending,
          active: context.l10n.wallpaperUploadPrepareCheckActive,
          done: context.l10n.wallpaperUploadPrepareCheckDone,
        ),
      ),
      UploadCheck(
        stateOf(1),
        text(
          1,
          pending: context.l10n.wallpaperUploadFilesCheckPending,
          active: context.l10n.wallpaperUploadFilesCheckActive,
          done: context.l10n.wallpaperUploadFilesCheckDone,
        ),
      ),
      UploadCheck(
        stateOf(2),
        text(
          2,
          pending: context.l10n.wallpaperUploadReviewCheckPending,
          active: context.l10n.wallpaperUploadReviewCheckActive,
          done: context.l10n.wallpaperUploadReviewCheckDone,
        ),
      ),
    ];
  }

  VoidCallback? get _failureAction => switch (_stage) {
    _UploadStage.failedProcessing => _oversize ? () => Navigator.maybePop(context) : _retryUpload,
    _UploadStage.failedUpload => () => unawaited(_submit()),
    _UploadStage.failedSubmission => () => unawaited(_retrySubmit()),
    _UploadStage.quotaExceeded => () => Navigator.maybePop(context),
    _ => null,
  };

  String get _failureActionLabel => switch (_stage) {
    _UploadStage.failedProcessing when _oversize => context.l10n.wallpaperUploadChooseAnotherImage,
    _UploadStage.failedSubmission => context.l10n.wallpaperUploadRetrySubmit,
    _UploadStage.quotaExceeded => context.l10n.wallpaperBack,
    _ => context.l10n.wallpaperTryAgain,
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool busy =
        _stage == _UploadStage.processing || _stage == _UploadStage.uploading || _stage == _UploadStage.saving;
    final List<Widget> bottomActions = <Widget>[
      if (!_failed)
        PrismButton(
          label: context.l10n.wallpaperUploadAction,
          expand: true,
          loading: busy,
          onPressed: !_discarding && _stage == _UploadStage.ready ? _submit : null,
        ),
      if (_canSkip)
        PrismButton(
          label: context.l10n.wallpaperUploadSkip,
          variant: PrismButtonVariant.ghost,
          expand: true,
          onPressed: _skip,
        ),
    ];
    return PopScope(
      canPop: !_isBusy && (!_hasStagedFiles || _submissionAttempted) && (_draftId == null || _submissionAttempted),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _onPop();
        if (!didPop && (_hasStagedFiles || _draftId != null) && !_submissionAttempted && !_isBusy) {
          unawaited(_confirmExit());
        }
      },
      child: PrismPage(
        title: context.l10n.wallpaperUploadTitle,
        onBack: () => Navigator.maybePop(context),
        bottomBar: bottomActions.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: bottomActions,
              ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.batch case final batch? when batch.isMulti) ...<Widget>[
                UploadBatchStepper(batch: batch),
                const SizedBox(height: PrismSpace.md),
              ],
              UploadPreviewRow(
                image: _selectedImage,
                resolution: wallpaperResolution,
                size: wallpaperSize,
                loading: _stage == _UploadStage.processing,
              ),
              for (final UploadQualityWarning warning in _qualityWarnings) ...<Widget>[
                const SizedBox(height: PrismSpace.sm),
                _QualityWarningRow(
                  text: uploadQualityWarningText(
                    context.l10n,
                    warning: warning,
                    width: _imageWidth!,
                    height: _imageHeight!,
                  ),
                ),
              ],
              const SizedBox(height: PrismSpace.xl),
              if (_failed) ...<Widget>[
                GlintState(
                  kind: GlintStateKind.error,
                  title: _stageTitle,
                  body: _errorMessage,
                  actionLabel: _failureActionLabel,
                  onAction: _failureAction,
                  padding: EdgeInsets.zero,
                ),
                if (_stage == _UploadStage.failedSubmission)
                  Center(
                    child: PrismButton(
                      label: context.l10n.wallpaperUploadCheckReviewStatus,
                      variant: PrismButtonVariant.ghost,
                      size: PrismButtonSize.compact,
                      onPressed: () => unawaited(context.router.push(const ReviewRoute())),
                    ),
                  ),
              ] else ...<Widget>[
                Text(_stageTitle, style: PrismTextStyles.cardTitle(context).copyWith(color: cs.onSurface)),
                if (_stage == _UploadStage.ready) ...<Widget>[
                  const SizedBox(height: PrismSpace.xxs),
                  Text(context.l10n.wallpaperUploadApprovalInfo, style: PrismTextStyles.body(context)),
                ],
                const SizedBox(height: PrismSpace.md),
                UploadChecksCard(checks: _checks),
              ],
              if (_showMetadataForm) ...<Widget>[
                const SizedBox(height: PrismSpace.xl),
                SubmissionMetadataForm(
                  initial: _metadata,
                  onChanged: (SubmissionMetadata value) {
                    _metadata = value;
                    unawaited(_persistDraft().then<void>((_) {}));
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityWarningRow extends StatelessWidget {
  const _QualityWarningRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline_rounded, size: 18, color: cs.tertiary),
        const SizedBox(width: PrismSpace.xs),
        Expanded(child: Text(text, style: PrismTextStyles.caption(context))),
      ],
    );
  }
}
