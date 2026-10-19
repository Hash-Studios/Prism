import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/deep_link_input/biz/deep_link_input_service.dart';
import 'package:Prism/features/deep_link_input/domain/deep_link_input_workflow.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DeepLinkInputPage extends StatefulWidget {
  const DeepLinkInputPage({super.key, required this.workflow});

  final DeepLinkInputWorkflow workflow;

  @override
  State<DeepLinkInputPage> createState() => _DeepLinkInputPageState();
}

class _DeepLinkInputPageState extends State<DeepLinkInputPage> {
  final DeepLinkInputService _service = DeepLinkInputService();
  bool _choosing = false;
  String? _error;

  Future<void> _chooseImage() async {
    if (_choosing) return;
    setState(() {
      _choosing = true;
      _error = null;
    });
    try {
      final PageRouteInfo? destination = await _service.chooseDestination(widget.workflow);
      if (!mounted) return;
      if (destination != null) await context.router.replace<void>(destination);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open your gallery. Please try again.');
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = switch (widget.workflow) {
      DeepLinkInputWorkflow.uploadWall => 'Upload a wallpaper',
      DeepLinkInputWorkflow.editWall => 'Edit a wallpaper',
      DeepLinkInputWorkflow.wallpaperFilter => 'Wallpaper filters',
      DeepLinkInputWorkflow.downloadWallpaper => 'Wallpaper preview',
      DeepLinkInputWorkflow.wallpaperPosition => 'Position a wallpaper',
      DeepLinkInputWorkflow.liveWallpaper => 'Live wallpaper',
      DeepLinkInputWorkflow.clockPreview => 'Clock preview',
      DeepLinkInputWorkflow.photoPreview => 'Photo preview',
    };
    return PrismPage(
      title: title,
      body: Center(
        child: SingleChildScrollView(
          padding: PrismSpace.pageInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.photo_library_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: PrismSpace.lg),
              Text(
                'Choose an image from your gallery to continue.',
                textAlign: TextAlign.center,
                style: PrismTextStyles.body(context),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: PrismSpace.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: PrismTextStyles.body(context).copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: PrismSpace.xl),
              PrismButton(label: 'Choose image', onPressed: _chooseImage, loading: _choosing),
            ],
          ),
        ),
      ),
    );
  }
}
