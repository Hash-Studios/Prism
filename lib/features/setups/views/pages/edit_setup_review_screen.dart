import 'dart:convert';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/wallpaper/setup_submission.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:Prism/env/env.dart';
import 'package:Prism/features/setups/views/widgets/setup_form.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

@RoutePage()
class EditSetupReviewScreen extends StatefulWidget {
  const EditSetupReviewScreen({super.key, required this.setupDoc});

  final FirestoreDocument setupDoc;

  @override
  State<EditSetupReviewScreen> createState() => _EditSetupReviewScreenState();
}

class _EditSetupReviewScreenState extends State<EditSetupReviewScreen> {
  late String _imageUrl = widget.setupDoc.image;
  bool _uploading = false;

  SetupDetails _initialDetails() {
    final FirestoreDocument doc = widget.setupDoc;
    final wallpaper = doc.setupWallpaperValue;
    return SetupDetails(
      setupName: doc.name,
      setupDesc: doc.desc,
      iconName: doc.icon,
      iconUrl: doc.iconUrl,
      widgetName: doc.widget,
      widgetUrl: doc.widgetUrl,
      widgetName2: doc.widget2,
      widgetUrl2: doc.widgetUrl2,
      wallpaper: wallpaper.isEncoded
          ? AppWallpaper(
              appName: wallpaper.title ?? '',
              link: wallpaper.deepLinkUrl ?? '',
              wallName: wallpaper.subtitle ?? '',
            )
          : doc.wallId.isNotEmpty && wallpaper.raw.isNotEmpty
          ? UploadedWallpaper(url: wallpaper.primaryUrl, id: doc.wallId)
          : LinkWallpaper(wallpaper.primaryUrl),
    );
  }

  Future<void> _pickImage() async {
    final XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final File image = File(picked.path);
    setState(() => _uploading = true);
    try {
      final value = await GitHubContentApi().putFile(
        repo: Env.normalize(Env.ghRepoSetups),
        message: path.basename(image.path),
        contentBase64: base64Encode(await image.readAsBytes()),
        path: path.basename(image.path),
      );
      final String? url = value.downloadUrl;
      if (url == null) throw StateError('Setup image upload returned no download url');
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _uploading = false;
      });
    } catch (e) {
      logger.w('Setup image upload failed', error: e);
      if (!mounted) return;
      Navigator.pop(context);
      toasts.error("Some uploading issue, please try again.");
    }
  }

  void _post(SetupDetails details) {
    final FirestoreDocument doc = widget.setupDoc;
    Navigator.pop(context);
    analytics.track(EditSetupEvent(setupId: doc.id, link: _imageUrl));
    wall_store.updateSetup(
      doc.id,
      SetupSubmission(
        id: doc.id,
        imageUrl: _imageUrl,
        wallpaperProvider: doc.wallpaperProvider,
        wallpaperThumb: doc.wallpaperThumb,
        review: doc.review,
        details: details,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SetupForm(
      isEdit: true,
      busy: _uploading,
      initial: _initialDetails(),
      preview: CachedNetworkImage(imageUrl: _imageUrl, fit: BoxFit.contain),
      onPreviewTap: _pickImage,
      onPost: _post,
    );
  }
}
