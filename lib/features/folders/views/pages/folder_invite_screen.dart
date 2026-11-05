import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_invite.dart';
import 'package:Prism/features/folders/domain/repositories/shared_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/features/folders/views/widgets/folder_members_sheet.dart';
import 'package:Prism/features/folders/views/widgets/public_folder_view.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The page behind a folder invite link. A guest can read the preview; joining asks them to sign in.
@RoutePage()
class FolderInviteScreen extends StatefulWidget {
  const FolderInviteScreen({super.key, @PathParam('code') required this.code});

  final String code;

  @override
  State<FolderInviteScreen> createState() => _FolderInviteScreenState();
}

class _FolderInviteScreenState extends State<FolderInviteScreen> {
  /// Null while the preview loads.
  Result<FolderInvitePreview>? _preview;
  bool _joining = false;

  /// Tests replace this through getIt. A constructor parameter would leak into the generated router.
  SharedFoldersRepository get _repository => getIt<SharedFoldersRepository>();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _preview = null);
    final Result<FolderInvitePreview> result = await _repository.previewInvite(widget.code);
    if (!mounted) return;
    if (result.data case FolderInviteRefused(:final refusal)) {
      unawaited(analytics.track(FolderJoinRefusedEvent(reason: refusal.wireValue)));
    }
    setState(() => _preview = result);
  }

  Future<void> _signIn() async {
    await requireSignedInAction(context);
    if (!mounted) return;
    await _load();
  }

  Future<void> _join() async {
    final FolderInvitePreview? open = _preview?.data;
    if (open is! FolderInviteOpen) return;
    setState(() => _joining = true);
    final Result<String> result = await _repository.join(widget.code);
    if (!mounted) return;
    final String? folderId = result.data;
    if (folderId != null) {
      unawaited(analytics.track(const FolderJoinedEvent(source: 'invite_link')));
      context.read<FoldersBloc?>()?.add(FoldersEvent.started(userId: app_state.prismUser.id));
      toasts.success(context.l10n.foldersJoined(open.name));
      unawaited(context.router.replace(FolderRoute(folderId: folderId)));
      return;
    }
    final Failure? failure = result.failure;
    final FolderJoinRefusal? refusal = failure is SharedFolderFailure ? failure.refusal : null;
    if (refusal != null) {
      unawaited(analytics.track(FolderJoinRefusedEvent(reason: refusal.wireValue)));
      setState(() {
        _preview = Result.success(FolderInviteRefused(refusal));
        _joining = false;
      });
      return;
    }
    unawaited(analytics.track(const FolderJoinRefusedEvent(reason: 'error')));
    toasts.error(context.l10n.foldersJoinFailed);
    setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: context.l10n.foldersJoinTitle,
      body: SingleChildScrollView(
        padding: PrismSpace.pageInsets,
        child: switch (_preview) {
          null => _loading(),
          Result(data: final FolderInviteOpen open) => _openView(context, open),
          Result(data: FolderInviteRefused(:final refusal)) => _refusedView(context, refusal),
          _ => GlintState(
            kind: GlintStateKind.error,
            title: context.l10n.foldersJoinLoadFailed,
            actionLabel: context.l10n.wallpaperTryAgain,
            onAction: () => unawaited(_load()),
          ),
        },
      ),
    );
  }

  Widget _loading() {
    return const PrismSkeleton(
      child: Column(
        children: <Widget>[
          Center(child: PrismBone(width: 200, height: 200, radius: PrismRadius.md)),
          SizedBox(height: PrismSpace.lg),
          PrismBone(width: 180),
          SizedBox(height: PrismSpace.xs),
          PrismBone(width: 120),
        ],
      ),
    );
  }

  Widget _openView(BuildContext context, FolderInviteOpen open) {
    final bool isGuest = !app_state.prismUser.loggedIn || app_state.prismUser.id.isEmpty;
    final l10n = context.l10n;
    final TextStyle caption = PrismTextStyles.caption(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: FolderCover(covers: open.covers, size: 200, radius: PrismRadius.md),
        ),
        const SizedBox(height: PrismSpace.lg),
        Text(
          l10n.foldersJoinHeadline(open.name),
          textAlign: TextAlign.center,
          softWrap: true,
          style: PrismTextStyles.sectionTitle(context),
        ),
        const SizedBox(height: PrismSpace.xs),
        FolderOwnerLink(
          ownerId: open.ownerId,
          builder: (BuildContext context, PublicProfileEntity? owner) => Text(
            l10n.foldersJoinInvitedBy(folderMemberName(owner, l10n)),
            textAlign: TextAlign.center,
            softWrap: true,
            style: PrismTextStyles.body(context),
          ),
        ),
        const SizedBox(height: PrismSpace.xs),
        Text(
          '${l10n.foldersItemCount(open.itemCount)} · ${l10n.foldersPeopleCount(open.memberCount)}',
          textAlign: TextAlign.center,
          softWrap: true,
          style: caption,
        ),
        const SizedBox(height: PrismSpace.xl),
        if (open.isMember) ...<Widget>[
          Text(l10n.foldersJoinAlreadyIn, textAlign: TextAlign.center, softWrap: true, style: caption),
          const SizedBox(height: PrismSpace.sm),
        ],
        if (isGuest)
          PrismButton(label: l10n.foldersJoinSignIn, expand: true, loading: _joining, onPressed: _signIn)
        else if (open.isMember)
          PrismButton(
            label: l10n.foldersJoinOpen,
            expand: true,
            loading: _joining,
            onPressed: () => unawaited(context.router.replace(FolderRoute(folderId: open.folderId))),
          )
        else
          PrismButton(label: l10n.foldersJoin, expand: true, loading: _joining, onPressed: _join),
      ],
    );
  }

  Widget _refusedView(BuildContext context, FolderJoinRefusal refusal) {
    final l10n = context.l10n;
    final (String title, String body) = switch (refusal) {
      FolderJoinRefusal.expired => (l10n.foldersJoinExpiredTitle, l10n.foldersJoinExpiredBody),
      FolderJoinRefusal.used => (l10n.foldersJoinUsedTitle, l10n.foldersJoinUsedBody),
      FolderJoinRefusal.full => (l10n.foldersJoinFullTitle, l10n.foldersJoinFullBody),
      FolderJoinRefusal.notFound ||
      FolderJoinRefusal.blocked ||
      FolderJoinRefusal.account => (l10n.foldersJoinUnavailableTitle, l10n.foldersJoinUnavailableBody),
    };
    return GlintState(kind: GlintStateKind.empty, title: title, body: body);
  }
}
