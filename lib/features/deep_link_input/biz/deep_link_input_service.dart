import 'dart:io';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/deep_link_input/domain/deep_link_input_workflow.dart';
import 'package:auto_route/auto_route.dart';
import 'package:image_picker/image_picker.dart';

class DeepLinkInputService {
  final ImagePicker _picker = ImagePicker();

  Future<PageRouteInfo?> chooseDestination(DeepLinkInputWorkflow workflow) async {
    final XFile? selected = await _picker.pickImage(source: ImageSource.gallery);
    if (selected == null) return null;
    if (selected.path.trim().isEmpty) throw StateError('The selected image is unavailable.');
    final File image = File(selected.path);
    return switch (workflow) {
      DeepLinkInputWorkflow.uploadWall => UploadWallRoute(image: image),
      DeepLinkInputWorkflow.editWall => EditWallRoute(image: image),
      DeepLinkInputWorkflow.wallpaperFilter => WallpaperFilterRoute(filePath: image.path),
      DeepLinkInputWorkflow.downloadWallpaper => DownloadWallpaperRoute(
        source: WallpaperSource.downloaded,
        file: image,
      ),
      DeepLinkInputWorkflow.wallpaperPosition => WallpaperPositionRoute(imageUrl: image.path, entryPoint: 'deep_link'),
      DeepLinkInputWorkflow.liveWallpaper => LiveWallpaperRoute(imageUrl: image.path),
      DeepLinkInputWorkflow.clockPreview => ClockPreviewRoute(link: image.path, file: true),
      DeepLinkInputWorkflow.photoPreview => ReviewPhotoPreviewRoute(url: image.path, thumbUrl: image.path, file: true),
    };
  }
}
