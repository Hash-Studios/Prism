import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:Prism/env/env.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

@RoutePage()
class UploadWallScreen extends StatefulWidget {
  const UploadWallScreen({
    super.key,
    required this.image,
    required this.fromSetupRoute,
    @visibleForTesting this.prepareImageForTesting,
    @visibleForTesting this.uploadFileForTesting,
    @visibleForTesting this.deleteFileForTesting,
    @visibleForTesting this.createRecordForTesting,
  });

  final File image;
  final bool fromSetupRoute;

  @visibleForTesting
  final Future<void> Function()? prepareImageForTesting;

  @visibleForTesting
  final Future<GitHubContent> Function({required bool isThumbnail})? uploadFileForTesting;

  @visibleForTesting
  final Future<void> Function({required String path, required String sha})? deleteFileForTesting;

  @visibleForTesting
  final Future<wall_store.WallSubmissionResult> Function()? createRecordForTesting;

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
  late final String? id;
  _UploadStage _stage = _UploadStage.processing;
  String? _errorMessage;
  String? wallpaperResolution;
  String? wallpaperProvider = 'Prism';
  String? wallpaperSize;
  String? wallpaperDesc = 'Community';
  String? wallpaperCategory = 'General';
  String? wallpaperThumb;
  String? wallpaperUrl;
  String? wallpaperSha;
  String? thumbSha;
  String? wallpaperPath;
  String? thumbPath;
  late List<int> imageBytes;
  late List<int> imageBytesThumb;
  bool _submitted = false;
  bool _submissionAttempted = false;
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
    id = _randomId();
    unawaited(_prepareImage());
  }

  String _randomId() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random();
    final digitIndex = random.nextInt(4);
    return List.generate(
      4,
      (index) => index == digitIndex ? random.nextInt(10).toString() : alphabet[random.nextInt(26)],
    ).join();
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
      _stage = _UploadStage.processing;
      _errorMessage = null;
    });
    try {
      if (widget.prepareImageForTesting case final prepareImageForTesting?) {
        await prepareImageForTesting();
        if (!mounted) return;
        imageBytes = <int>[];
        imageBytesThumb = <int>[];
        setState(() {
          wallpaperResolution = '1x1';
          wallpaperSize = '0.00MB';
          _stage = _UploadStage.ready;
        });
        return;
      }
      final imgList = await widget.image.readAsBytes();
      final decodedImage = await decodeImageFromList(imgList);
      final resolution = '${decodedImage.width}x${decodedImage.height}';
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
    } catch (error) {
      logger.w('Wallpaper preparation failed: $error');
      if (!mounted) return;
      setState(() {
        _stage = _UploadStage.failedProcessing;
        _errorMessage = 'We could not prepare this image. Try again or choose another image.';
      });
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
      final baseName = path.basename(widget.image.path);
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
                message: 'thumb_$baseName',
                contentBase64: base64Encode(imageBytesThumb),
                path: 'thumb_$baseName',
              );
        wallpaperThumb = thumbValue.downloadUrl;
        thumbPath = thumbValue.path ?? 'thumb_$baseName';
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
      setState(() {
        _stage = _UploadStage.failedUpload;
        _errorMessage = 'The upload did not finish. Your image is still here, so you can try again.';
      });
      return false;
    }
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
    if (!await _uploadFiles() || !mounted || _leaving) return;
    setState(() => _stage = _UploadStage.saving);
    _submissionAttempted = true;
    try {
      final result = widget.createRecordForTesting != null
          ? await widget.createRecordForTesting!()
          : await wall_store.createRecord(
              id,
              wallpaperProvider,
              wallpaperThumb,
              wallpaperUrl,
              wallpaperResolution,
              wallpaperSize,
              null,
              wallpaperCategory,
              wallpaperDesc,
              widget.fromSetupRoute ? 'setup' : false,
            );
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
        return;
      }
    } catch (error) {
      logger.w('Wallpaper submission failed: $error');
      if (!mounted) return;
      setState(() {
        _stage = _UploadStage.failedSubmission;
        _errorMessage = 'We could not confirm the submission. Check your review status before trying again.';
      });
      return;
    }
    if (!mounted) return;
    _submitted = true;
    analytics.track(UploadWallpaperEvent(assetId: id ?? '', link: wallpaperUrl ?? ''));
    if (_leaving) return;
    final router = widget.fromSetupRoute ? null : context.router;
    Navigator.pop(context, [wallpaperUrl, id]);
    if (router != null) unawaited(router.push(const ReviewRoute()));
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
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Discard upload')),
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
        _UploadStage.ready =>
          widget.fromSetupRoute
              ? 'Add this wallpaper to your setup. You will return to the setup editor after upload.'
              : 'Your wallpaper appears in the community after approval. Track it in Review status.',
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
                              if (_isBusy)
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.primary),
                                )
                              else
                                Icon(
                                  failure ? Icons.error_outline : Icons.check_circle_outline,
                                  color: failure ? colors.error : colors.primary,
                                  size: 24,
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_stageTitle, style: theme.textTheme.titleMedium),
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
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: _stage == _UploadStage.failedProcessing
                          ? FilledButton.icon(
                              onPressed: _retryUpload,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again'),
                            )
                          : _stage == _UploadStage.quotaExceeded
                          ? FilledButton(onPressed: () => Navigator.maybePop(context), child: const Text('Back'))
                          : _stage == _UploadStage.failedSubmission
                          ? FilledButton.icon(
                              onPressed: () => unawaited(context.router.push(const ReviewRoute())),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Check review status'),
                            )
                          : FilledButton.icon(
                              onPressed:
                                  !_discarding && (_stage == _UploadStage.ready || _stage == _UploadStage.failedUpload)
                                  ? _submit
                                  : null,
                              icon: _stage == _UploadStage.saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(JamIcons.check),
                              label: Text(
                                _stage == _UploadStage.uploading
                                    ? 'Uploading…'
                                    : _stage == _UploadStage.saving
                                    ? 'Submitting…'
                                    : widget.fromSetupRoute
                                    ? 'Use this wallpaper'
                                    : 'Submit for review',
                              ),
                            ),
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
