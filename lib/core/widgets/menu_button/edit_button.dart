import 'dart:async';
import 'dart:io';

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/original_access_prompt.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class EditButton extends StatefulWidget {
  final String? url;
  final String? wallpaperId;
  final WallpaperSource? wallpaperSource;

  /// Makes the image to edit, such as a colour variation, and returns its local path. The editor opens on that path
  /// and [url] is not fetched. If it throws, the user is told and the editor does not open.
  final Future<String> Function()? prepareSource;
  final Future<String> Function(String source)? prepareAuthorized;

  /// Shows a caption under the round button.
  final bool labelled;
  const EditButton({
    required this.url,
    this.wallpaperId,
    this.wallpaperSource,
    this.prepareSource,
    this.prepareAuthorized,
    this.labelled = false,
    super.key,
  });

  @override
  _EditButtonState createState() => _EditButtonState();
}

class _EditButtonState extends State<EditButton> {
  late bool isLoading;

  @override
  void initState() {
    isLoading = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CircularMenuButton(
      label: context.l10n.coreEdit,
      caption: widget.labelled ? context.l10n.coreEdit : null,
      onTap: () {
        if (!isLoading) {
          onEdit(widget.url);
        }
      },
      isLoading: isLoading,
      child: const Icon(JamIcons.pencil),
    );
  }

  Future<void> onEdit(String? url) async {
    if (!await signInForOriginal(
          context,
          url: url ?? '',
          wallpaperId: widget.wallpaperId,
          wallpaperSource: widget.wallpaperSource,
        ) ||
        !mounted) {
      return;
    }
    final String owner = app_state.prismUser.id;
    final AppLocalizations l10n = context.l10n;
    if (url == null) {
      toasts.error(l10n.coreNoWallpaperUrl);
      return;
    }
    PrismHaptics.tap();
    setState(() {
      isLoading = true;
    });
    toasts.success(l10n.coreLoadingWallpaper, haptic: false);
    try {
      url = await resolveOriginalWithConsent(
        context,
        url: url,
        wallpaperId: widget.wallpaperId,
        wallpaperSource: widget.wallpaperSource,
        action: OriginalAccessAction.edit,
        label: l10n.coreEdit,
      );
      if (url == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
      toasts.error(l10n.coreCouldNotLoadWallpaperForEditing);
      return;
    }
    final String authorizedUrl = url;
    final Future<String> Function()? prepare = widget.prepareAuthorized == null
        ? widget.prepareSource
        : () => widget.prepareAuthorized!(authorizedUrl);
    if (prepare != null) {
      final String? prepared = await runPrepareSource(prepare, l10n: l10n);
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      if (prepared != null && app_state.prismUser.id == owner) {
        await context.router.push(WallpaperFilterRoute(filePath: prepared));
      }
      return;
    }
    Directory? sessionDirectory;
    try {
      final File source = await WallpaperService.resolveToLocalFile(
        url,
        wallpaperId: widget.wallpaperId,
        wallpaperSource: widget.wallpaperSource,
      ).timeout(const Duration(seconds: 30));
      final List<int> bytes = await source.readAsBytes();
      if (bytes.isEmpty) {
        toasts.error(l10n.coreCouldNotLoadWallpaperForEditing);
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }
      if (!mounted) return;
      final editDir = Directory('${(await getTemporaryDirectory()).path}/prism_edit');
      await editDir.create(recursive: true);
      sessionDirectory = await editDir.createTemp('source_');
      final file = File('${sessionDirectory.path}/source.img');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      if (app_state.prismUser.id == owner) await context.router.push(WallpaperFilterRoute(filePath: file.path));
    } on TimeoutException {
      if (mounted) {
        toasts.error(l10n.coreWallpaperLoadTimedOut);
      }
    } catch (_) {
      if (mounted) {
        toasts.error(l10n.coreCouldNotLoadWallpaperForEditing);
      }
    } finally {
      try {
        await sessionDirectory?.delete(recursive: true);
      } catch (_) {}
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
