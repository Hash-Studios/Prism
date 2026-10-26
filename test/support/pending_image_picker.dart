import 'dart:async';

import 'package:flutter/services.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Keeps each pick open until [finish] and rejects a second pick meanwhile, as the Android plugin does.
class PendingImagePicker extends ImagePickerPlatform {
  int calls = 0;
  Completer<List<XFile>>? _open;

  Future<List<XFile>> _pick() {
    calls++;
    if (_open != null) {
      return Future<List<XFile>>.error(
        PlatformException(code: 'already_active', message: 'Image picker is already active'),
      );
    }
    return (_open = Completer<List<XFile>>()).future;
  }

  void finish(List<String> paths) {
    final Completer<List<XFile>> open = _open!;
    _open = null;
    open.complete(paths.map(XFile.new).toList());
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({MultiImagePickerOptions options = const MultiImagePickerOptions()}) =>
      _pick();

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => (await _pick()).firstOrNull;
}
