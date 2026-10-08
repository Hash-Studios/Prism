import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/glint_toast.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/upload_failure.dart';
import 'package:Prism/data/upload/upload_id.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:Prism/env/env.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_batch.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_quality.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/submission_metadata_form.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/upload_batch_stepper.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
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

class _UploadWallScreenState extends State<UploadWallScreen> {
  late final String id = randomUploadId(uploadIdLength);
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
        return;
      }
      final imgList = await widget.image.readAsBytes();
      if (imgList.length > maxUploadBytes) {
        if (!mounted) return;
        setState(() {
          _oversize = true;
          _stage = _UploadStage.failedProcessing;
          _errorMessage = oversizeUploadMessage;
        });
        _trackFailure('oversize');
        return;
      }
      final decodedImage = await decodeImageFromList(imgList);
      final resolution = '${decodedImage.width}x${decodedImage.height}';
      _imageWidth = decodedImage.width;
      _imageHeight = decodedImage.height;
      decodedImage.dispose();
      imageBytes = imgList;
      imageBytesThumb = await _compressFile(widget.image);
      final size = await widget.image.length();
      if (!mounted) {
        return;
      }
      setState(() {
        wallpaperResolution = resolution;
        wallpaperSize = '${(size / 1024 / 1024).toStringAsFixed(2)}MB';
      });
      if (mounted) setState(() => _stage = _UploadStage.ready);
      _trackStage('ready');
    } catch (error) {
      logger.w('Wallpaper preparation failed: $error');
      if (!mounted) return;
      setState(() {
        _stage = _UploadStage.failedProcessing;
        _errorMessage = 'We could not prepare this image. Try again or choose another image.';
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
        basename: path.basename(widget.image.path),
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
        _errorMessage = failure.message;
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
    PrismHaptics.tap();
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
    PrismHaptics.tap();
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
    PrismHaptics.tap();
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
          _errorMessage = 'We could not confirm the submission. Check your review status before trying again.';
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
              ? 'You have reached this week’s free wallpaper upload limit.'
              : 'You reached the upload limit, but uploaded files could not be removed. Try Back again to retry.';
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
        _errorMessage = 'We could not confirm the submission. Check your review status before trying again.';
      });
      _trackFailure('submission');
      return;
    }
    _submitted = true;
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
    if (batch != null && batch.isMulti) toasts.info(batch.summary);
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
    PrismHaptics.tap();
    final failed =
        _stage == _UploadStage.failedProcessing ||
        _stage == _UploadStage.failedUpload ||
        _stage == _UploadStage.failedSubmission;
    if (_hasStagedFiles && !_submissionAttempted && !await _deleteFile()) {
      if (mounted) toasts.error('Could not remove uploaded files. Try again.');
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

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this upload?'),
        content: const Text('Uploaded files will be removed. Your selected image will stay on your device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep editing')),
          FilledButton(
            onPressed: () {
              PrismHaptics.tap();
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Discard upload'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    if (_discarding) return;
    setState(() => _discarding = true);
    final deleted = await _deleteFile();
    if (!mounted) return;
    if (!deleted) {
      setState(() => _discarding = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not remove uploaded files. Try again.')));
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
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
    _UploadStage.processing => 'Preparing wallpaper',
    _UploadStage.uploading => 'Uploading wallpaper',
    _UploadStage.ready => 'Ready to submit',
    _UploadStage.saving => 'Submitting wallpaper',
    _UploadStage.failedProcessing => 'Image could not be prepared',
    _UploadStage.failedUpload => 'Upload did not finish',
    _UploadStage.failedSubmission => 'Submission did not finish',
    _UploadStage.quotaExceeded => 'Upload limit reached',
  };

  String get _stageDescription =>
      _errorMessage ??
      switch (_stage) {
        _UploadStage.processing => 'Preparing your image and a smaller preview.',
        _UploadStage.uploading => 'Uploading the wallpaper and its preview.',
        _UploadStage.ready => 'Your wallpaper appears in the community after approval. Track it in Review status.',
        _UploadStage.saving => 'Saving your submission for review.',
        _UploadStage.failedProcessing => '',
        _UploadStage.failedUpload => '',
        _UploadStage.failedSubmission => '',
        _UploadStage.quotaExceeded => '',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final failure =
        _stage == _UploadStage.failedProcessing ||
        _stage == _UploadStage.failedUpload ||
        _stage == _UploadStage.failedSubmission ||
        _stage == _UploadStage.quotaExceeded;
    return PopScope(
      canPop: !_isBusy && (!_hasStagedFiles || _submissionAttempted),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _onPop();
        if (!didPop && _hasStagedFiles && !_submissionAttempted && !_isBusy) {
          unawaited(_confirmDiscard());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Upload wallpaper')),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewHeight = (constraints.maxHeight * 0.56).clamp(220.0, 440.0);
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.batch case final batch? when batch.isMulti) ...[
                            UploadBatchStepper(batch: batch),
                            const SizedBox(height: 12),
                          ],
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: previewHeight, maxWidth: 480),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  widget.image,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                                    color: colors.surfaceContainerHighest,
                                    child: SizedBox(
                                      height: previewHeight,
                                      child: Center(
                                        child: Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedSwitcher(
                                duration: context.motion(PrismDurations.fast),
                                child: _isBusy
                                    ? SizedBox(
                                        key: const ValueKey<String>('busy'),
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                                      )
                                    : Icon(
                                        failure ? Icons.error_outline : Icons.check_circle_outline,
                                        key: ValueKey<bool>(failure),
                                        color: failure ? colors.error : colors.primary,
                                        size: 24,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _stageTitle,
                                      style: theme.textTheme.titleMedium?.copyWith(color: colors.onSurface),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _stageDescription,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: failure ? colors.error : colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (wallpaperResolution != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              '$wallpaperResolution  ·  ${wallpaperSize ?? ''}',
                              style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                          for (final warning in _qualityWarnings) ...[
                            const SizedBox(height: 8),
                            _QualityWarningRow(
                              text: uploadQualityWarningText(warning, width: _imageWidth!, height: _imageHeight!),
                            ),
                          ],
                          if (_showMetadataForm) ...[
                            const SizedBox(height: 24),
                            SubmissionMetadataForm(initial: _metadata, onChanged: (value) => _metadata = value),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: _stage == _UploadStage.failedProcessing
                              ? _oversize
                                    ? FilledButton(
                                        onPressed: () => Navigator.maybePop(context),
                                        child: const Text('Choose another image'),
                                      )
                                    : FilledButton.icon(
                                        onPressed: _retryUpload,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Try again'),
                                      )
                              : _stage == _UploadStage.quotaExceeded
                              ? FilledButton(onPressed: () => Navigator.maybePop(context), child: const Text('Back'))
                              : _stage == _UploadStage.failedSubmission
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: _retrySubmit,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry submit'),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => unawaited(context.router.push(const ReviewRoute())),
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('Check review status'),
                                    ),
                                  ],
                                )
                              : FilledButton.icon(
                                  onPressed:
                                      !_discarding &&
                                          (_stage == _UploadStage.ready || _stage == _UploadStage.failedUpload)
                                      ? _submit
                                      : null,
                                  icon: AnimatedSwitcher(
                                    duration: context.motion(PrismDurations.fast),
                                    child: _stage == _UploadStage.saving
                                        ? const SizedBox.square(
                                            key: ValueKey<bool>(true),
                                            dimension: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(JamIcons.check, key: ValueKey<bool>(false)),
                                  ),
                                  label: Text(
                                    _stage == _UploadStage.uploading
                                        ? 'Uploading…'
                                        : _stage == _UploadStage.saving
                                        ? 'Submitting…'
                                        : 'Submit for review',
                                  ),
                                ),
                        ),
                        if (_canSkip) TextButton(onPressed: _skip, child: const Text('Skip this wallpaper')),
                      ],
                    ),
                  ),
                ],
              );
            },
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: colors.tertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ),
      ],
    );
  }
}
