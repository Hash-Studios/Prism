import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/upload_id.dart';
import 'package:Prism/data/upload/wallpaper/setup_submission.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:Prism/env/env.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:photo_view/photo_view.dart';

@RoutePage()
class UploadWallScreen extends StatefulWidget {
  const UploadWallScreen({super.key, required this.image, required this.fromSetupRoute});

  final File image;
  final bool fromSetupRoute;

  @override
  _UploadWallScreenState createState() => _UploadWallScreenState();
}

class _UploadWallScreenState extends State<UploadWallScreen> {
  late final String id = randomUploadId(4);
  bool isUploading = false;
  bool isProcessing = true;
  String? wallpaperUrl;
  String? wallpaperResolution;
  String? wallpaperSize;
  String? wallpaperThumb;
  // Set once each file reaches GitHub; null means there is nothing to delete.
  String? wallpaperSha;
  String? thumbSha;
  String? wallpaperPath;
  String? thumbPath;
  late List<int> imageBytes;
  late List<int> imageBytesThumb;
  bool _submitted = false;

  File get image => widget.image;

  @override
  void initState() {
    super.initState();
    processImage();
  }

  Future<Uint8List> compressFile(File file) async {
    final result = await FlutterImageCompress.compressWithFile(file.absolute.path, minWidth: 400, quality: 85);
    return result!;
  }

  Future processImage() async {
    final imgList = image.readAsBytesSync();
    final decodedImage = await decodeImageFromList(imgList);

    final res = "${decodedImage.width}x${decodedImage.height}";

    setState(() {
      wallpaperResolution = res;
    });

    image.length().then((value) => {wallpaperSize = "${(value / 1024 / 1024).toStringAsFixed(2)}MB"});

    imageBytes = await image.readAsBytes();
    imageBytesThumb = await compressFile(image);

    uploadFile();
  }

  Future deleteFile() async {
    final github = GitHubContentApi();
    try {
      if (wallpaperPath != null && wallpaperSha != null) {
        await github.deleteFile(
          repo: Env.normalize(Env.ghRepoWalls),
          path: wallpaperPath!,
          sha: wallpaperSha!,
          message: wallpaperPath!,
        );
      }
      if (thumbPath != null && thumbSha != null) {
        await github.deleteFile(
          repo: Env.normalize(Env.ghRepoWalls),
          path: thumbPath!,
          sha: thumbSha!,
          message: thumbPath!,
        );
      }
    } catch (e) {
      logger.w("Could not delete unsubmitted upload: $e");
    }
  }

  Future uploadFile() async {
    setState(() {
      isUploading = true;
      isProcessing = false;
    });
    try {
      final String base64Image = base64Encode(imageBytes);
      final String base64ImageThumb = base64Encode(imageBytesThumb);
      final github = GitHubContentApi();
      final value = await github.putFile(
        repo: Env.normalize(Env.ghRepoWalls),
        message: path.basename(image.path),
        contentBase64: base64Image,
        path: path.basename(image.path),
      );
      wallpaperUrl = value.downloadUrl;
      wallpaperPath = value.path;
      wallpaperSha = value.sha;
      // Left the screen while uploading: _onPop found nothing to delete, so clean up here.
      if (!mounted) return deleteFile();
      final thumbValue = await github.putFile(
        repo: Env.normalize(Env.ghRepoWalls),
        message: "thumb_${path.basename(image.path)}",
        contentBase64: base64ImageThumb,
        path: 'thumb_${path.basename(image.path)}',
      );
      wallpaperThumb = thumbValue.downloadUrl;
      thumbPath = thumbValue.path;
      thumbSha = thumbValue.sha;
      if (!mounted) return deleteFile();
      setState(() {
        isUploading = false;
      });
    } catch (e) {
      logger.w('Wall upload failed', error: e);
      if (!mounted) return;
      Navigator.pop(context);
      toasts.error("Some uploading issue, please try again.");
    }
  }

  void _onPop() {
    if (!_submitted) deleteFile();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _onPop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          title: Text("Upload Wallpaper", style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
        ),
        body: Column(
          children: <Widget>[
            ClipRRect(
              child: Container(
                color: Theme.of(context).hintColor,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.width,
                child: PhotoView(
                  imageProvider: FileImage(image),
                  backgroundDecoration: BoxDecoration(color: Theme.of(context).hintColor),
                ),
              ),
            ),
            if (isProcessing || isUploading)
              SizedBox(
                width: MediaQuery.of(context).size.width / 2.4,
                height: MediaQuery.of(context).size.width / 2.4,
                child: const Center(child: CircularProgressIndicator()),
              ),
            if (isUploading)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  "Uploading...",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.secondary),
                ),
              ),
            if (isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  "Processing...",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.secondary),
                ),
              ),
            if (isProcessing || isUploading)
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(500),
                  child: LinearProgressIndicator(
                    backgroundColor: Theme.of(context).hintColor,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2,
                    child: Center(
                      child: Icon(JamIcons.info, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6)),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                        child: Text(
                          app_state.prismUser.premium
                              ? "Note - We have a strong review policy, and submitting irrelevant images will lead to ban. Your photo will be visible in the profile/community section."
                              : "Note - We have a strong review policy, and submitting irrelevant images will lead to ban. We take about 24 hours to review the submissions, and after a successful review, your photo will be visible in the profile/community section.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: !isProcessing && !isUploading
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).hintColor,
          disabledElevation: 0,
          onPressed: !isProcessing && !isUploading
              ? () {
                  _submitted = true;
                  Navigator.pop(context, UploadedWallpaper(url: wallpaperUrl!, id: id));
                  analytics.track(UploadWallpaperEvent(assetId: id, link: wallpaperUrl!));
                  wall_store.createRecord(
                    id,
                    'Prism',
                    wallpaperThumb,
                    wallpaperUrl,
                    wallpaperResolution,
                    wallpaperSize,
                    null,
                    'General',
                    'Community',
                    widget.fromSetupRoute ? 'setup' : false,
                  );
                  context.router.push(const ReviewRoute());
                }
              : null,
          child: const Icon(JamIcons.check, size: 40, color: Colors.white),
        ),
      ),
    );
  }
}
