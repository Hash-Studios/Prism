import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/photo_wallpaper_repository.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/photo_wallpaper_page.dart';
import 'package:Prism/features/share_in/data/share_link_image_repository.dart';
import 'package:Prism/features/share_in/data/shared_inbox.dart';
import 'package:Prism/features/share_in/domain/shared_item.dart';
import 'package:Prism/features/share_in/views/widgets/share_in_sheet.dart';
import 'package:Prism/logger/logger.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// A see-through page that shows the share sheet over the current screen and owns the shared file: the file moves
/// to the picked flow, or is deleted when the user closes the sheet.
@RoutePage()
class ShareInPage extends StatefulWidget {
  const ShareInPage({super.key, required this.kind, this.item});

  final SharedItemKind kind;

  /// A [SharedImage] or a [SharedUrl]. Null when Prism could not read the share.
  final SharedItem? item;

  @override
  State<ShareInPage> createState() => _ShareInPageState();
}

class _ShareInPageState extends State<ShareInPage> {
  final SharedInbox _inbox = SharedInbox();
  final Set<String> _paths = <String>{};
  ModalRoute<ShareInChoice>? _sheetRoute;

  @override
  void initState() {
    super.initState();
    if (widget.item case SharedImage(:final String path)) _paths.add(path);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_show()));
  }

  @override
  void dispose() {
    _discardAll();
    final ModalRoute<ShareInChoice>? sheet = _sheetRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sheet?.isActive ?? false) sheet!.navigator?.removeRoute(sheet);
    });
    super.dispose();
  }

  void _trackPath(String path) {
    if (mounted) {
      _paths.add(path);
    } else {
      unawaited(_inbox.discard(path).catchError((Object _) {}));
    }
  }

  void _discardAll() {
    for (final String path in _paths) {
      unawaited(_inbox.discard(path).catchError((Object _) {}));
    }
    _paths.clear();
  }

  Future<void> _show() async {
    if (!mounted) return;
    final ShareInChoice? choice = await showPrismSheet<ShareInChoice>(
      context,
      builder: (BuildContext sheetContext) {
        _sheetRoute = ModalRoute.of<ShareInChoice>(sheetContext);
        return ShareInSheet(
          item: widget.item,
          kind: widget.kind,
          findLinkImage: ShareLinkImageRepository(inbox: _inbox).imageFor,
          onPathChanged: _trackPath,
          discardPath: _inbox.discard,
        );
      },
    );
    if (!mounted) return;
    if (choice == null) {
      _discardAll();
      await context.router.maybePop();
      return;
    }
    analytics.track(
      ShareActionEvent(
        action: switch (choice.action) {
          ShareInAction.set => ShareActionValue.set,
          ShareInAction.fit => ShareActionValue.fit,
          ShareInAction.upload => ShareActionValue.upload,
        },
        kind: widget.kind.analytics,
      ),
    );
    try {
      await _open(choice);
    } catch (error) {
      logger.w('[ShareIn] could not open the picked flow (${error.runtimeType})');
      if (mounted) await context.router.maybePop();
    }
  }

  Future<void> _open(ShareInChoice choice) async {
    final StackRouter router = context.router;
    switch (choice.action) {
      case ShareInAction.set:
        final File file = await _handOff(choice.path);
        try {
          await router.replace(WallpaperFilterRoute(filePath: file.path, sharedImage: true));
        } finally {
          await _inbox.discard(file.path);
        }
      case ShareInAction.upload:
        final File file = await _handOff(choice.path);
        // Edit replaces itself with Upload, so the replace future never completes. Wait for the stack instead.
        final Future<void> released = _untilReleased(router, file.path);
        unawaited(router.replace(EditWallRoute(image: file)));
        try {
          await released;
        } finally {
          await _inbox.discard(file.path);
        }
      case ShareInAction.fit:
        // The photo is in memory now, so the shared copy can go.
        _discardAll();
        final NavigatorState navigator = Navigator.of(context);
        await router.maybePop();
        unawaited(
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => PhotoWallpaperPage(repository: PhotoWallpaperRepository(), initialSource: choice.photo),
            ),
          ),
        );
    }
  }

  /// Completes once Edit or Upload held [path] and no route on [router] holds it now.
  static Future<void> _untilReleased(StackRouter router, String path) {
    bool holds() => router.stackData.any(
      (RouteData route) => switch (route.args) {
        EditWallRouteArgs(:final File image) || UploadWallRouteArgs(:final File image) => image.path == path,
        _ => false,
      },
    );
    final Completer<void> released = Completer<void>();
    bool held = false;
    void check() {
      final bool now = holds();
      held = held || now;
      if (held && !now && !released.isCompleted) released.complete();
    }

    router.addListener(check);
    router.navigationHistory.addListener(check);
    return released.future.whenComplete(() {
      router.removeListener(check);
      router.navigationHistory.removeListener(check);
    });
  }

  Future<File> _handOff(String path) async {
    final File file = await _inbox.handOff(path);
    if (!mounted) {
      await _inbox.discard(file.path);
      throw StateError('The share was closed before hand-off completed.');
    }
    _paths.remove(path);
    _discardAll();
    return file;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
