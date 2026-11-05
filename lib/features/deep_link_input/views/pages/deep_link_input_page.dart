import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/deep_link_input/biz/deep_link_input_service.dart';
import 'package:Prism/features/deep_link_input/domain/deep_link_input_workflow.dart';
import 'package:Prism/l10n/l10n.dart';
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
      if (mounted) setState(() => _error = context.l10n.deepLinkInputGalleryError);
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = switch (widget.workflow) {
      DeepLinkInputWorkflow.uploadWall => l10n.deepLinkInputUploadTitle,
      DeepLinkInputWorkflow.editWall => l10n.deepLinkInputEditTitle,
      DeepLinkInputWorkflow.wallpaperFilter => l10n.deepLinkInputFiltersTitle,
      DeepLinkInputWorkflow.downloadWallpaper => l10n.deepLinkInputWallpaperPreviewTitle,
      DeepLinkInputWorkflow.wallpaperPosition => l10n.deepLinkInputPositionTitle,
      DeepLinkInputWorkflow.liveWallpaper => l10n.deepLinkInputLiveTitle,
      DeepLinkInputWorkflow.clockPreview => l10n.deepLinkInputClockPreviewTitle,
      DeepLinkInputWorkflow.photoPreview => l10n.deepLinkInputPhotoPreviewTitle,
    };
    return PrismPage(
      title: title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.md, PrismSpace.page, PrismSpace.xl),
        children: <Widget>[
          Center(
            child: ExcludeSemantics(
              child: SizedBox(
                height: 260,
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PrismRadius.md),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Image.asset('assets/images/wallpaper.jpg', fit: BoxFit.cover, cacheHeight: 780),
                        if (widget.workflow == DeepLinkInputWorkflow.liveWallpaper)
                          PositionedDirectional(
                            top: PrismSpace.xs,
                            start: PrismSpace.xs,
                            child: PrismTag(label: l10n.wallpaperLive),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: PrismSpace.lg),
          Text(title, textAlign: TextAlign.center, style: PrismTextStyles.sectionTitle(context)),
          const SizedBox(height: PrismSpace.xs),
          Text(
            widget.workflow == DeepLinkInputWorkflow.liveWallpaper
                ? l10n.deepLinkInputLiveDescription
                : l10n.deepLinkInputChooseImageDescription,
            textAlign: TextAlign.center,
            style: PrismTextStyles.body(context),
          ),
          const SizedBox(height: PrismSpace.xl),
          PrismButton(label: l10n.deepLinkInputChooseImage, expand: true, loading: _choosing, onPressed: _chooseImage),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: PrismSpace.md),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.body(context).copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
