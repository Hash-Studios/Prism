import 'dart:convert';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/upload_id.dart';
import 'package:Prism/data/upload/wallpaper/setup_submission.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:Prism/env/env.dart';
import 'package:Prism/features/setups/views/widgets/setup_form.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:photo_view/photo_view.dart';

@RoutePage()
class UploadSetupScreen extends StatefulWidget {
  const UploadSetupScreen({super.key, required this.image});

  final File image;

  @override
  State<UploadSetupScreen> createState() => _UploadSetupScreenState();
}

class _UploadSetupScreenState extends State<UploadSetupScreen> {
  final String _id = randomUploadId(6);
  final bool _premiumBlocked = !app_state.prismUser.premium;
  bool _uploading = true;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    if (_premiumBlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await PaywallOrchestrator.instance.present(
          placement: PaywallPlacement.blockedSetupCreate,
          source: 'upload_setup_blocked_create',
        );
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return;
    }
    _uploadImage();
  }

  Future<void> _uploadImage() async {
    try {
      final value = await GitHubContentApi().putFile(
        repo: Env.normalize(Env.ghRepoSetups),
        message: path.basename(widget.image.path),
        contentBase64: base64Encode(await widget.image.readAsBytes()),
        path: path.basename(widget.image.path),
      );
      if (!mounted) return;
      setState(() {
        _imageUrl = value.downloadUrl;
        _uploading = false;
      });
    } catch (e) {
      logger.w('Setup image upload failed', error: e);
      if (!mounted) return;
      Navigator.pop(context);
      toasts.error("Some uploading issue, please try again.");
    }
  }

  SetupSubmission _submission(SetupDetails details) => SetupSubmission(
    id: _id,
    imageUrl: _imageUrl,
    wallpaperProvider: 'Prism',
    wallpaperThumb: '',
    review: false,
    details: details,
  );

  void _post(SetupDetails details) {
    Navigator.pop(context);
    analytics.track(UploadSetupEvent(setupId: _id, link: _imageUrl ?? ''));
    wall_store.createSetup(_submission(details));
    context.router.push(const ReviewRoute());
  }

  @override
  Widget build(BuildContext context) {
    if (_premiumBlocked) {
      return Scaffold(backgroundColor: Theme.of(context).primaryColor, body: const SizedBox.shrink());
    }
    return SetupForm(
      isEdit: false,
      busy: _uploading,
      preview: Image.file(widget.image, fit: BoxFit.contain),
      onPreviewTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => PhotoView(
              onTapUp: (context, details, controller) {
                Navigator.pop(context);
              },
              imageProvider: FileImage(widget.image),
            ),
            fullscreenDialog: true,
          ),
        );
      },
      onSaveDraft: (details) => wall_store.createDraftSetup(_submission(details)),
      onPost: _post,
    );
  }
}
