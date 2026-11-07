import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/photo_wallpaper_repository.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/photo_job.dart';
import 'package:Prism/features/share_in/data/shared_inbox.dart';
import 'package:Prism/features/share_in/domain/shared_item.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum ShareInAction { set, fit, upload }

/// The action the user picked, with the image it applies to. [photo] is set for [ShareInAction.fit].
typedef ShareInChoice = ({ShareInAction action, String path, PhotoSource? photo});

sealed class _SheetState {
  const _SheetState();
}

final class _Looking extends _SheetState {
  const _Looking();
}

final class _Ready extends _SheetState {
  const _Ready(this.path, this.photo);

  final String path;
  final PhotoSource photo;
}

final class _Failed extends _SheetState {
  const _Failed();
}

/// The sheet for a shared image or web link: Set as wallpaper, Make it fit and Upload to Prism. Nothing leaves the
/// device until the user picks Make it fit or Upload. Pops with a [ShareInChoice], or null when closed.
class ShareInSheet extends StatefulWidget {
  const ShareInSheet({
    super.key,
    required this.item,
    required this.findLinkImage,
    this.kind,
    this.onPathChanged,
    this.discardPath,
    this.readPhoto,
    this.signIn,
    this.isGuest,
    this.isPro,
    this.screenSize,
  });

  /// A [SharedImage] or a [SharedUrl]. Null shows the failed state.
  final SharedItem? item;
  final SharedItemKind? kind;

  /// The local path of a web page's image, or null when it has none.
  final Future<String?> Function(Uri page) findLinkImage;

  /// Called when the sheet gets a new local image, so its owner can delete it later.
  final ValueChanged<String>? onPathChanged;
  final Future<void> Function(String path)? discardPath;

  /// Test seams. Null reads the file and measures it, asks the signed-in check, and reads the user and screen.
  final Future<PhotoSource> Function(String path)? readPhoto;
  final Future<bool> Function(BuildContext context)? signIn;
  final bool? isGuest;
  final bool? isPro;
  final PhotoSize? screenSize;

  @override
  State<ShareInSheet> createState() => _ShareInSheetState();
}

class _ShareInSheetState extends State<ShareInSheet> {
  _SheetState _state = const _Looking();
  bool _busy = false;

  bool get _isGuest => widget.isGuest ?? !app_state.prismUser.loggedIn;
  bool get _isPro => widget.isPro ?? app_state.prismUser.premium;
  SharedItemKind get _kind => widget.item?.kind ?? widget.kind ?? SharedItemKind.url;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final SharedItem? item = widget.item;
      String? path = switch (item) {
        SharedImage(:final String path) => path,
        _ => null,
      };
      if (item is SharedUrl) {
        path = await widget.findLinkImage(item.uri);
        if (path != null && !mounted) {
          await (widget.discardPath ?? SharedInbox().discard)(path);
          return;
        }
        if (path != null) widget.onPathChanged?.call(path);
      }
      if (!mounted) return;
      if (path == null) return _fail();
      final PhotoSource photo = await (widget.readPhoto ?? _readPhoto)(path);
      if (mounted) setState(() => _state = _Ready(path!, photo));
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (!mounted) return;
    analytics.track(ShareActionEvent(action: ShareActionValue.failed, kind: _kind.analytics));
    setState(() => _state = const _Failed());
  }

  static Future<PhotoSource> _readPhoto(String path) async {
    final Uint8List bytes = await File(path).readAsBytes();
    return PhotoWallpaperRepository().source(bytes);
  }

  PhotoSize _phone(BuildContext context) {
    if (widget.screenSize case final PhotoSize size?) return size;
    final Size logical = MediaQuery.sizeOf(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return phoneTargetSize(width: logical.width * dpr, height: logical.height * dpr);
  }

  Future<void> _pick(_Ready ready, ShareInAction action) async {
    if (_busy) return;
    if (action != ShareInAction.set && _isGuest) {
      setState(() => _busy = true);
      final bool signedIn = await (widget.signIn ?? requireSignedInAction)(context);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!signedIn) return;
    }
    Navigator.of(
      context,
    ).pop<ShareInChoice>((action: action, path: ready.path, photo: action == ShareInAction.fit ? ready.photo : null));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return switch (_state) {
      _Looking() => PrismSheetBody(
        title: l10n.shareInLooking,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: PrismSpace.xl),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
      _Failed() => PrismSheetBody(
        child: GlintState(
          kind: GlintStateKind.error,
          title: _kind == SharedItemKind.image ? l10n.shareInImageUnreadable : l10n.shareInLinkUnusable,
          body: _kind == SharedItemKind.image ? l10n.shareInImageUnreadableDetail : l10n.shareInLinkUnusableDetail,
        ),
      ),
      final _Ready ready => _ready(context, ready),
    };
  }

  Widget _ready(BuildContext context, _Ready ready) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final PhotoJobMode? plan = planPhotoJob(ready.photo.size, _phone(context));
    final double previewHeight = MediaQuery.sizeOf(context).height * 0.3;
    final String? guestNote = _isGuest ? l10n.shareInSignInDetail : null;
    return PrismSheetBody(
      title: l10n.shareInImageTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            image: true,
            label: l10n.shareInPreviewSemantics,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: previewHeight),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PrismRadius.md),
                child: Image.memory(
                  ready.photo.bytes,
                  fit: BoxFit.contain,
                  cacheHeight: (previewHeight * MediaQuery.devicePixelRatioOf(context)).round(),
                  excludeFromSemantics: true,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: PrismSpace.lg),
          PrismCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                PrismRow(
                  icon: Icons.wallpaper_rounded,
                  title: l10n.shareInSet,
                  subtitle: l10n.shareInSetDetail,
                  onTap: _busy ? null : () => _pick(ready, ShareInAction.set),
                ),
                Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
                PrismRow(
                  icon: Icons.auto_awesome_rounded,
                  title: plan == null ? l10n.shareInFitTitle : l10n.shareInFit(photoJobCost(plan, isPro: _isPro)),
                  subtitle: plan == null ? l10n.shareInFitNotNeeded : guestNote ?? l10n.shareInFitDetail,
                  onTap: _busy || plan == null ? null : () => _pick(ready, ShareInAction.fit),
                ),
                Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
                PrismRow(
                  icon: Icons.upload_rounded,
                  title: l10n.shareInUpload,
                  subtitle: guestNote ?? l10n.shareInUploadDetail,
                  onTap: _busy ? null : () => _pick(ready, ShareInAction.upload),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
