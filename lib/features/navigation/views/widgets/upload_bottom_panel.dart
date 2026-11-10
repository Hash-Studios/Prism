import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/session/session.dart';
import 'package:Prism/features/wallpaper_upload/biz/live_upload_limits.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_batch.dart';
import 'package:Prism/features/wallpaper_upload/data/live_video_preparer.dart';
import 'package:Prism/features/wallpaper_upload/data/upload_draft_store.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class UploadBottomPanel extends StatefulWidget {
  const UploadBottomPanel({super.key, @visibleForTesting this.draftStoreForTesting});

  @visibleForTesting
  final UploadDraftStore? draftStoreForTesting;

  @override
  State<UploadBottomPanel> createState() => _UploadBottomPanelState();
}

class _UploadBottomPanelState extends State<UploadBottomPanel> {
  final ImagePicker _picker = ImagePicker();
  late final UploadDraftStore _draftStore = widget.draftStoreForTesting ?? UploadDraftStore();
  UploadDraft? _latestDraft;
  late String _latestDraftOwner = _draftOwner;
  int _draftLookupGeneration = 0;
  bool _picking = false;

  String get _draftOwner => app_state.prismUser.loggedIn && app_state.prismUser.id.trim().isNotEmpty
      ? app_state.prismUser.id
      : UploadDraftStore.guestOwner;
  UploadDraft? get _visibleDraft => _latestDraftOwner == _draftOwner ? _latestDraft : null;

  @override
  void initState() {
    super.initState();
    _loadLatestDraft();
  }

  Future<void> _loadLatestDraft({String? ownerOverride}) async {
    final String owner = ownerOverride ?? _draftOwner;
    final int generation = ++_draftLookupGeneration;
    try {
      final UploadDraft? draft = await _draftStore.latestForOwner(owner);
      if (!mounted || generation != _draftLookupGeneration || owner != _draftOwner) return;
      setState(() {
        _latestDraftOwner = owner;
        _latestDraft = draft?.owner == owner ? draft : null;
      });
    } catch (error, stackTrace) {
      logger.w('Could not restore upload draft entry', error: error, stackTrace: stackTrace);
    }
  }

  void _resumeLatestDraft() {
    final UploadDraft? draft = _latestDraftOwner == _draftOwner ? _latestDraft : null;
    if (draft == null || draft.owner != _draftOwner) {
      setState(() => _latestDraft = null);
      _loadLatestDraft();
      return;
    }
    final router = context.router;
    Navigator.pop(context);
    router.push(UploadWallRoute(image: draft.file, resumedDraft: draft));
  }

  Future<void> _pickWallpaperImage() async {
    final int limit = uploadPickLimit(
      isPremium: app_state.prismUser.premium,
      remainingFree: UploadQuota.remainingFreeUploadsThisWeek(),
    );
    final List<XFile> picked = await _picker.pickMultiImage(limit: limit);
    if (!mounted || picked.isEmpty) {
      return;
    }
    final List<File> wallpapers = picked.take(limit).map((file) => File(file.path)).toList();
    final router = context.router;
    Navigator.pop(context);
    router.push(EditWallRoute(image: wallpapers.first, batch: wallpapers.length > 1 ? UploadBatch(wallpapers) : null));
  }

  Future<void> _pickLiveVideo() async {
    analytics.track(const LiveWallUploadStartedEvent());
    final XFile? picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 15),
    );
    if (!mounted || picked == null) return;
    final NavigatorState navigator = Navigator.of(context);
    final router = context.router;
    unawaited(
      showPrismSheet<void>(
        context,
        detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
        barrierDismissible: false,
        swipeDismissible: false,
        builder: (_) => PrismSheetBody(
          title: context.l10n.liveUploadChecking,
          showHandle: false,
          showCloseButton: false,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: PrismSpace.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
    final LivePrepResult result = await _checkLiveVideo(File(picked.path));
    navigator.pop();
    if (!mounted) return;
    switch (result) {
      case LivePrepReady(:final poster, :final input):
        Navigator.pop(context);
        router.push(UploadWallRoute(image: poster, live: input));
      case LivePrepRefused(:final error):
        if (await _showLiveRefusal(error)) await _pickLiveVideo();
    }
  }

  Future<LivePrepResult> _checkLiveVideo(File video) async {
    try {
      return await prepareLiveVideo(video);
    } catch (error, stackTrace) {
      logger.w('Live video check failed', error: error, stackTrace: stackTrace);
      return const LivePrepRefused(LiveVideoError.malformed);
    }
  }

  /// Returns true when the user picks another video.
  Future<bool> _showLiveRefusal(LiveVideoError error) async {
    final AppLocalizations l10n = context.l10n;
    final bool? pickAnother = await showPrismSheet<bool>(
      context,
      detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
      builder: (sheetContext) => PrismSheetBody(
        title: l10n.uploadKindLive,
        message: liveVideoErrorMessage(l10n, error),
        actions: <Widget>[
          PrismButton(
            label: l10n.liveUploadPickAnother,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          PrismButton(
            label: l10n.actionCancel,
            expand: true,
            variant: PrismButtonVariant.ghost,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    return pickAnother ?? false;
  }

  Future<void> _onWallpaperTap(WallKind kind) async {
    if (_picking) return;
    if (!await requireSignedInAction(context) || !mounted) return;
    analytics.track(
      const UploadActionSelectedEvent(
        action: AnalyticsActionValue.uploadWallpaperSelected,
        entrypoint: EntryPointValue.bottomNav,
      ),
    );
    if (!app_state.prismUser.premium && !UploadQuota.hasFreeUploadQuotaRemaining()) {
      toasts.error(context.l10n.wallpaperUploadFreeQuotaMessage(UploadQuota.freeUploadsPerWeek));
      if (mounted) {
        Navigator.of(context).pop();
        await PaywallOrchestrator.instance.present(
          placement: PaywallPlacement.uploadLimitReached,
          source: 'upload_wallpaper_limit_reached',
        );
      }
      return;
    }
    PrismHaptics.tap();
    _picking = true;
    try {
      if (kind == WallKind.live) {
        await _pickLiveVideo();
      } else {
        await _pickWallpaperImage();
      }
    } on PlatformException catch (error) {
      // already_active means another screen has the gallery open, and the user is choosing there.
      if (error.code != 'already_active') rethrow;
    } finally {
      _picking = false;
    }
  }

  void _onAiTap() {
    PrismHaptics.tap();
    analytics.track(
      const UploadActionSelectedEvent(
        action: AnalyticsActionValue.uploadAiSelected,
        entrypoint: EntryPointValue.bottomNav,
      ),
    );
    final router = context.router;
    Navigator.pop(context);
    router.push(AiTabRoute());
  }

  @override
  Widget build(BuildContext context) {
    final bool isPremium = app_state.prismUser.premium;
    final TextStyle caption = PrismTextStyles.caption(context);
    final Color chevron = Theme.of(context).colorScheme.onSurface.withValues(alpha: PrismInk.iconAlpha);

    final Widget content = PrismSheetBody(
      title: context.l10n.wallpaperUploadCreateTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrismGroup(
            children: <Widget>[
              PrismRow(
                icon: Icons.photo_library_rounded,
                title: context.l10n.uploadKindPhoto,
                subtitle: context.l10n.uploadKindPhotoBody,
                onTap: () => _onWallpaperTap(WallKind.still),
              ),
              PrismRow(
                icon: Icons.motion_photos_on_rounded,
                title: context.l10n.uploadKindLive,
                subtitle: context.l10n.uploadKindLiveBody,
                onTap: () => _onWallpaperTap(WallKind.live),
              ),
              if (_visibleDraft case final draft?)
                PrismRow(
                  icon: Icons.drafts_rounded,
                  title: context.l10n.wallpaperUploadResumeDraft,
                  subtitle: draft.metadata.title.isEmpty
                      ? context.l10n.wallpaperUploadContinueDraft
                      : draft.metadata.title,
                  onTap: _resumeLatestDraft,
                ),
              PrismRow(
                icon: Icons.auto_awesome_rounded,
                title: context.l10n.economyAiWallpaper,
                subtitle: context.l10n.wallpaperUploadAiSubtitle,
                onTap: _onAiTap,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PrismTag(label: context.l10n.wallpaperNew, tone: PrismTone.accent),
                    const SizedBox(width: PrismSpace.xxs),
                    Icon(Icons.chevron_right_rounded, size: 20, color: chevron),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.md),
          if (!isPremium) ...<Widget>[
            Text(
              context.l10n.wallpaperUploadQuotaRemaining(
                UploadQuota.remainingFreeUploadsThisWeek(),
                UploadQuota.freeUploadsPerWeek,
              ),
              style: PrismTextStyles.body(context).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: PrismSpace.xxs),
          ],
          Text(context.l10n.wallpaperUploadOriginalContentGuideline, style: caption),
        ],
      ),
    );
    final SessionBloc? sessionBloc = context.read<SessionBloc?>();
    if (sessionBloc == null) return content;
    return BlocListener<SessionBloc, SessionState>(
      bloc: sessionBloc,
      listenWhen: (previous, current) => _ownerForSession(previous) != _ownerForSession(current),
      listener: (_, state) {
        final String owner = _ownerForSession(state);
        _draftLookupGeneration++;
        setState(() {
          _latestDraftOwner = owner;
          _latestDraft = null;
        });
        if (owner == _draftOwner) _loadLatestDraft(ownerOverride: owner);
      },
      child: content,
    );
  }

  String _ownerForSession(SessionState state) => state.session.loggedIn && state.session.userId.trim().isNotEmpty
      ? state.session.userId
      : UploadDraftStore.guestOwner;
}
