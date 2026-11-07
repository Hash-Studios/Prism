import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/desktop_submission/biz/desktop_upload_cubit.dart';
import 'package:Prism/features/desktop_submission/data/desktop_submission_repository.dart';
import 'package:Prism/features/desktop_submission/domain/desktop_image_check.dart';
import 'package:Prism/features/desktop_submission/domain/desktop_submit_failure.dart';
import 'package:Prism/features/desktop_submission/views/widgets/desktop_side_preview.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

const int _maxUploadBytes = 15 * 1024 * 1024;

Future<Uint8List?> _pickFromGallery() async {
  final XFile? picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 3840,
    maxHeight: 3840,
    imageQuality: 92,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}

/// Reads the pixel size from the image header only. Null when the bytes are not a decodable image.
Future<Size?> _measureImage(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  } on Object {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// Lets the creator pick a wide image for their approved wall, check it, see it beside the phone wallpaper, and send it.
class DesktopUploadScreen extends StatefulWidget {
  const DesktopUploadScreen({
    required this.wallDocId,
    required this.wallId,
    required this.phoneThumbUrl,
    required this.wallTitle,
    required this.replace,
    this.repository,
    this.pickImage,
    this.measure,
    super.key,
  });

  final String wallDocId;
  final String wallId;
  final String phoneThumbUrl;
  final String wallTitle;

  /// True when the wall already has a desktop version, which stays live until the new one is approved.
  final bool replace;

  /// Test seams. Null uses the app repository, the photo picker and the image header.
  final DesktopSubmissionRepository? repository;
  final Future<Uint8List?> Function()? pickImage;
  final Future<Size?> Function(Uint8List bytes)? measure;

  @override
  State<DesktopUploadScreen> createState() => _DesktopUploadScreenState();
}

class _DesktopUploadScreenState extends State<DesktopUploadScreen> {
  late final DesktopUploadCubit _upload;

  Uint8List? _bytes;
  Size? _size;

  /// Set when the picked image fails a check before upload. Null when it passes or nothing is picked.
  DesktopSubmitFailure? _pickFailure;

  /// Set only when the picked image passes every check.
  DesktopImageOk? _ok;

  bool _choosing = false;

  @override
  void initState() {
    super.initState();
    _upload = DesktopUploadCubit(widget.repository ?? getIt<DesktopSubmissionRepository>());
  }

  @override
  void dispose() {
    unawaited(_upload.close());
    super.dispose();
  }

  Future<void> _choose() async {
    if (_choosing || _upload.state.sending) return;
    setState(() => _choosing = true);
    final l10n = context.l10n;
    Uint8List? bytes;
    Size? size;
    try {
      bytes = await (widget.pickImage ?? _pickFromGallery)();
      if (bytes != null) size = await (widget.measure ?? _measureImage)(bytes);
    } catch (error, stackTrace) {
      logger.w('Desktop image could not be picked', error: error, stackTrace: stackTrace);
      if (mounted) toasts.error(l10n.coreSomethingWentWrong);
    }
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _choosing = false);
      return;
    }
    final DesktopImageCheck? check = size == null
        ? null
        : DesktopImageCheck.of(size.width.round(), size.height.round());
    _upload.clearFailure();
    setState(() {
      _choosing = false;
      _bytes = bytes;
      _size = size;
      _ok = null;
      _pickFailure = bytes!.lengthInBytes > _maxUploadBytes
          ? DesktopSubmitFailure.tooLarge
          : switch (check) {
              null => DesktopSubmitFailure.unreadable,
              DesktopImageOk() => null,
              DesktopImageNotLandscape() => DesktopSubmitFailure.notLandscape,
              DesktopImageWrongAspect() => DesktopSubmitFailure.wrongAspect,
              DesktopImageTooSmall() => DesktopSubmitFailure.tooSmall,
            };
      if (_pickFailure == null && check is DesktopImageOk) _ok = check;
    });
  }

  Future<void> _submit() async {
    final Uint8List? bytes = _bytes;
    final DesktopImageOk? ok = _ok;
    if (_upload.state.sending || bytes == null || ok == null) return;
    await _upload.submit(wallDocId: widget.wallDocId, bytes: bytes);
    if (!mounted) return;
    if (!_upload.state.sent) {
      if (_upload.state.failure != null) PrismHaptics.error();
      return;
    }
    unawaited(
      analytics.track(
        DesktopUploadSubmittedEvent(wallId: widget.wallId, aspect: ok.aspect.label, replace: widget.replace),
      ),
    );
    toasts.success(context.l10n.desktopUploadSubmitted);
    unawaited(Navigator.of(context).maybePop(true));
  }

  String _messageFor(BuildContext context, DesktopSubmitFailure failure) {
    final l10n = context.l10n;
    return switch (failure) {
      DesktopSubmitFailure.notLandscape => l10n.desktopUploadErrorPortrait,
      DesktopSubmitFailure.wrongAspect => l10n.desktopUploadErrorAspect,
      DesktopSubmitFailure.tooSmall => l10n.desktopUploadErrorTooSmall(_size?.width.round() ?? 0),
      DesktopSubmitFailure.unreadable => l10n.desktopUploadErrorUnreadable,
      DesktopSubmitFailure.tooLarge => l10n.desktopUploadErrorTooLarge,
      DesktopSubmitFailure.alreadyPending => l10n.desktopUploadErrorPending,
      DesktopSubmitFailure.notAllowed => l10n.desktopUploadErrorNotAllowed,
      DesktopSubmitFailure.rateLimited => l10n.desktopUploadErrorLimit,
      DesktopSubmitFailure.failed => l10n.desktopUploadErrorFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Uint8List? bytes = _bytes;
    final Size? size = _size;

    return BlocBuilder<DesktopUploadCubit, DesktopUploadState>(
      bloc: _upload,
      builder: (BuildContext context, DesktopUploadState upload) {
        final DesktopSubmitFailure? error = upload.failure ?? _pickFailure;

        final Widget? errorText = error == null
            ? null
            : Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
                    const SizedBox(width: PrismSpace.xs),
                    Expanded(
                      child: Text(
                        _messageFor(context, error),
                        style: PrismTextStyles.body(context).copyWith(color: cs.error),
                      ),
                    ),
                  ],
                ),
              );

        return PrismPage(
          title: widget.replace ? l10n.desktopUploadReplaceTitle : l10n.desktopUploadTitle,
          bottomBar: Padding(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (errorText != null) ...<Widget>[errorText, const SizedBox(height: PrismSpace.sm)],
                PrismButton(
                  maxLines: 2,
                  label: bytes == null ? l10n.desktopUploadChooseImage : l10n.desktopUploadChooseAnother,
                  variant: PrismButtonVariant.tonal,
                  expand: true,
                  onPressed: _choosing || upload.sending ? null : _choose,
                ),
                const SizedBox(height: PrismSpace.sm),
                PrismButton(
                  maxLines: 2,
                  label: l10n.desktopUploadSubmit,
                  haptic: false,
                  expand: true,
                  loading: upload.sending,
                  onPressed: _ok == null || upload.sending ? null : _submit,
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.desktopUploadIntro, style: PrismTextStyles.body(context)),
                if (widget.replace) ...<Widget>[
                  const SizedBox(height: PrismSpace.xs),
                  Text(l10n.desktopUploadReplaceNote, style: PrismTextStyles.body(context)),
                ],
                const SizedBox(height: PrismSpace.xl),
                DesktopSidePreview(
                  phoneThumbUrl: widget.phoneThumbUrl,
                  desktopImage: bytes == null ? null : MemoryImage(bytes),
                  desktopWidth: size?.width.round(),
                  desktopHeight: size?.height.round(),
                  aspectLabel: _ok?.aspect.label,
                ),
                const SizedBox(height: PrismSpace.lg),
                if (bytes == null) Text(l10n.desktopUploadRequirements, style: PrismTextStyles.body(context)),
              ],
            ),
          ),
        );
      },
    );
  }
}
