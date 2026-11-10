import 'dart:io';

import 'package:Prism/features/wallpaper_upload/biz/live_upload_limits.dart';

/// A checked live wall video, ready to upload. [framePaths] holds exactly 3 JPEG paths: start, middle and end.
final class LiveUploadInput {
  const LiveUploadInput({required this.video, required this.info, required this.framePaths});

  final File video;
  final LiveVideoInfo info;
  final List<String> framePaths;
}
