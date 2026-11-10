import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/profile_links.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/utils/side_safe_column.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/string_extensions.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/cosmetics/glow_text.dart';
import 'package:Prism/core/widgets/cosmetics/profile_frame.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_refresh.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/badges/views/widgets/profile_badge_row.dart';
import 'package:Prism/features/creator_directory/views/widgets/followed_by_line.dart';
import 'package:Prism/features/creator_tips/views/widgets/tip_sheet.dart';
import 'package:Prism/features/folders/views/widgets/profile_folders_row.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_card.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/creator_label.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/widgets/drawer_widget.dart';
import 'package:Prism/features/public_profile/views/widgets/follow_outcome_toast.dart';
import 'package:Prism/features/public_profile/views/widgets/gift_pass_sheet.dart';
import 'package:Prism/features/public_profile/views/widgets/pro_profile_badge.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_bio_text.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_cover.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_parts.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_loader.dart';
import 'package:Prism/features/rewards/views/widgets/rank_progress_card.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_blocks/user_block_actions.dart';
import 'package:Prism/features/user_blocks/views/blocked_user_profile_shell.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

@RoutePage()
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, @PathParam('identifier') this.profileIdentifier});

  final String? profileIdentifier;

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  late final String _profileIdentifier = widget.profileIdentifier ?? app_state.prismUser.id;
  late Stream<PublicProfileEntity?> _profileStream = _watchProfile();

  Stream<PublicProfileEntity?> _watchProfile() => getIt<PublicProfileRepository>().watchProfile(_profileIdentifier);

  bool get _isOwnProfile {
    final String identifier = _profileIdentifier.trim();
    if (identifier.isEmpty) {
      return true;
    }
    return identifier == app_state.prismUser.id || identifier == app_state.prismUser.username;
  }

  PublicProfileEntity _ownProfile({PublicProfileEntity? graphProfile, List<String>? badges}) => PublicProfileEntity(
    id: app_state.prismUser.id,
    name: app_state.prismUser.name,
    email: '',
    username: app_state.prismUser.username,
    profilePhoto: app_state.prismUser.profilePhoto,
    bio: app_state.prismUser.bio,
    links: app_state.prismUser.links,
    coverPhoto: app_state.prismUser.coverPhoto ?? '',
    badges: badges ?? app_state.prismUser.badges.map((b) => b.id).toList(growable: false),
    followerCount: graphProfile?.id == app_state.prismUser.id ? graphProfile!.followerCount : 0,
    followingCount: graphProfile?.id == app_state.prismUser.id ? graphProfile!.followingCount : 0,
    proBadge: graphProfile?.id == app_state.prismUser.id && graphProfile!.proBadge,
  );

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  @override
  Widget build(BuildContext context) {
    // A guest (iOS browse-without-account) has no profile of their own, so it asks them to sign in. Other users'
    // public profiles are readable without an account; their actions ask for sign-in.
    if (!app_state.prismUser.loggedIn && _isOwnProfile) {
      return PrismPage(
        title: context.l10n.accountProfile,
        actions: <Widget>[
          PrismIconButton(
            icon: Icons.settings_rounded,
            tooltip: context.l10n.accountSettings,
            onPressed: () {
              PrismHaptics.tap();
              context.router.push(const SettingsRoute());
            },
          ),
        ],
        body: SignInPrompt(feature: _isOwnProfile ? context.l10n.accountYourProfile : context.l10n.accountProfiles),
      );
    }
    if (_isOwnProfile) {
      _contentLoadTracker.success(
        itemCount: 1,
        onSuccess: ({required int loadTimeMs, int? itemCount}) async {
          await analytics.track(
            SurfaceContentLoadedEvent(
              surface: AnalyticsSurfaceValue.profileScreen,
              result: EventResultValue.success,
              loadTimeMs: loadTimeMs,
              sourceContext: 'profile_screen_own_profile',
              itemCount: itemCount,
            ),
          );
        },
      );
    }
    return BlocProvider<PublicProfileBloc>(
      create: (_) => getIt<PublicProfileBloc>(),
      child: _isOwnProfile
          ? StreamBuilder<PublicProfileEntity?>(
              stream: _profileStream,
              builder: (BuildContext context, AsyncSnapshot<PublicProfileEntity?> snapshot) => _ProfileChild(
                ownProfile: true,
                onProfileEdited: () => setState(() {}),
                profile: _ownProfile(graphProfile: snapshot.data),
              ),
            )
          : StreamBuilder<PublicProfileEntity?>(
              stream: _profileStream,
              builder: (BuildContext context, AsyncSnapshot<PublicProfileEntity?> snapshot) {
                if (snapshot.hasError) {
                  _contentLoadTracker.failure(
                    reason: AnalyticsReasonValue.error,
                    onFailure: ({required int loadTimeMs, AnalyticsReasonValue? reason, int? itemCount}) async {
                      await analytics.track(
                        SurfaceContentLoadedEvent(
                          surface: AnalyticsSurfaceValue.profileScreen,
                          result: EventResultValue.failure,
                          loadTimeMs: loadTimeMs,
                          sourceContext: 'profile_screen_stream',
                          reason: reason,
                        ),
                      );
                    },
                  );
                  return PrismPage(
                    title: context.l10n.accountProfile,
                    body: GlintState(
                      kind: GlintStateKind.error,
                      title: context.l10n.accountCouldNotLoadThisProfile,
                      body: context.l10n.accountConnectionTryAgain,
                      actionLabel: context.l10n.accountTryAgain,
                      onAction: () => setState(() => _profileStream = _watchProfile()),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ProfileSkeleton();
                }
                final PublicProfileEntity? profile = snapshot.data;
                _contentLoadTracker.success(
                  itemCount: profile == null ? 0 : 1,
                  onSuccess: ({required int loadTimeMs, int? itemCount}) async {
                    await analytics.track(
                      SurfaceContentLoadedEvent(
                        surface: AnalyticsSurfaceValue.profileScreen,
                        result: profile == null ? EventResultValue.empty : EventResultValue.success,
                        loadTimeMs: loadTimeMs,
                        sourceContext: 'profile_screen_stream',
                        itemCount: itemCount,
                      ),
                    );
                  },
                );
                if (profile == null) {
                  return PrismPage(
                    title: context.l10n.accountProfile,
                    body: GlintState(
                      kind: GlintStateKind.empty,
                      title: context.l10n.accountProfileNotAvailable,
                      body: context.l10n.accountProfileNotAvailableBody,
                    ),
                  );
                }
                final UserBlockRepository blocks = getIt<UserBlockRepository>();
                return StreamBuilder<BlockedCreators>(
                  initialData: blocks.blockedCreators,
                  stream: blocks.watchBlockedCreators(),
                  builder: (BuildContext context, AsyncSnapshot<BlockedCreators> snapshot) {
                    final BlockedCreators? blocked = snapshot.data;
                    if (blocked is! KnownBlockedCreators) return const ProfileSkeleton();
                    if (blocked.uids.contains(profile.id)) {
                      final String display = creatorLabel(
                        name: profile.name,
                        username: profile.username,
                        fallback: context.l10n.accountCreatorFallback,
                      );
                      return BlockedUserProfileShell(targetUserId: profile.id, displayName: display);
                    }
                    return _ProfileChild(ownProfile: false, profile: profile);
                  },
                );
              },
            ),
    );
  }
}

enum _ProfileMenuAction { tip, report, block }

class _ProfileChild extends StatefulWidget {
  const _ProfileChild({required this.profile, required this.ownProfile, this.onProfileEdited});

  final PublicProfileEntity profile;
  final bool ownProfile;

  /// Rebuilds the parent, which reads the edited fields from app_state.
  final VoidCallback? onProfileEdited;

  @override
  _ProfileChildState createState() => _ProfileChildState();
}

class _ProfileChildState extends State<_ProfileChild> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  PublicProfileEntity get _profile => widget.profile;

  /// Own profile reads what is equipped now, so equipping in the shop shows here at once.
  ({String? frame, String? glow, int xp, bool premium}) get _cosmetics {
    if (!widget.ownProfile) {
      return (frame: _profile.frameId, glow: _profile.nameGlowId, xp: _profile.xp, premium: _profile.premium);
    }
    final Inventory inventory = CoinsService.instance.inventoryNotifier.value;
    return (
      frame: inventory.frame,
      glow: inventory.nameGlow,
      xp: CoinsService.instance.xpNotifier.value.xp,
      premium: app_state.prismUser.premium,
    );
  }

  void _trackAction(AnalyticsActionValue action, {String sourceContext = 'profile_screen'}) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.profileScreen,
          action: action,
          sourceContext: sourceContext,
          itemType: ItemTypeValue.user,
          itemId: _profile.id,
        ),
      ),
    );
  }

  LinkDestinationValue _destinationForLinkKey(String key) {
    switch (key) {
      case 'github':
        return LinkDestinationValue.github;
      case 'twitter':
        return LinkDestinationValue.twitter;
      case 'instagram':
        return LinkDestinationValue.instagram;
      case 'telegram':
        return LinkDestinationValue.telegram;
      case 'email':
        return LinkDestinationValue.email;
      default:
        return LinkDestinationValue.external;
    }
  }

  /// Opens a profile link. A link with an unsafe scheme or no host is refused with a calm toast.
  Future<bool> _openProfileLink(String link) async {
    final AppLocalizations l10n = context.l10n;
    final Uri? uri = safeProfileLinkUri(link);
    try {
      if (uri != null && await launchUrl(uri)) return true;
    } catch (error, stackTrace) {
      logger.w('Could not open a profile link.', error: error, stackTrace: stackTrace);
    }
    toasts.info(l10n.accountCouldNotOpenThisLink);
    return false;
  }

  Future<void> _openLink(String key, String link) async {
    _trackAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_screen_link_chip');
    final bool launched = await _openProfileLink(link);
    unawaited(
      analytics.track(
        ExternalLinkOpenResultEvent(
          surface: AnalyticsSurfaceValue.profileScreen,
          destination: _destinationForLinkKey(key),
          result: launched ? EventResultValue.success : EventResultValue.failure,
          reason: launched ? null : AnalyticsReasonValue.error,
          sourceContext: 'profile_screen_link_chip',
        ),
      ),
    );
  }

  Future<void> _openBioLink(Uri uri) async {
    _trackAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_screen_bio_link');
    final bool launched = await _openProfileLink(uri.toString());
    unawaited(
      analytics.track(
        ExternalLinkOpenResultEvent(
          surface: AnalyticsSurfaceValue.profileScreen,
          destination: LinkDestinationValue.external,
          result: launched ? EventResultValue.success : EventResultValue.failure,
          reason: launched ? null : AnalyticsReasonValue.error,
          sourceContext: 'profile_screen_bio_link',
        ),
      ),
    );
  }

  Future<void> _openEditProfilePanel({required String sourceContext}) async {
    _trackAction(AnalyticsActionValue.editProfileTapped, sourceContext: sourceContext);
    // Push on root stack: ProfileScreen is often shown via root ProfileRoute
    // (/user/:id); nested /dashboard/profile/edit is not in that subtree.
    await context.router.root.push(const EditProfilePanelRoute());
    if (!mounted) {
      return;
    }
    widget.onProfileEdited?.call();
  }

  Future<void> _toggleFollow({required bool following}) async {
    if (!await requireSignedInAction(context) || !mounted) return;
    _trackAction(
      following ? AnalyticsActionValue.unfollowTapped : AnalyticsActionValue.followTapped,
      sourceContext: 'profile_screen_follow_action',
    );
    context.read<PublicProfileBloc>().add(
      PublicProfileEvent.followChangeRequested(
        follow: !following,
        currentUserId: app_state.prismUser.id,
        currentUserEmail: app_state.prismUser.email,
        targetUserId: _profile.id,
        targetUserEmail: '',
        targetName: creatorLabel(
          name: _profile.name,
          username: _profile.username,
          fallback: context.l10n.accountCreatorFallback,
        ),
      ),
    );
  }

  bool _isFollowing(PublicProfileState state) {
    return state.followOverrides[_profile.id] ?? _profile.isFollowedByCurrentUser;
  }

  void _openFollowingList() {
    PrismHaptics.tap();
    context.router.push(FollowingListRoute(userId: _profile.id));
  }

  void _openFollowersList() {
    PrismHaptics.tap();
    context.router.push(FollowersRoute(userId: _profile.id));
  }

  Future<void> _openGiftSheet() async {
    PrismHaptics.tap();
    if (!await requireSignedInAction(context) || !mounted) return;
    await showPrismSheet<void>(
      context,
      builder: (BuildContext sheetContext) => GiftPassSheet(
        recipientUid: _profile.id,
        recipientName: creatorLabel(
          name: _profile.name,
          username: _profile.username,
          fallback: context.l10n.accountCreatorFallback,
        ),
      ),
    );
  }

  Future<void> _onMenuSelected(_ProfileMenuAction action) async {
    final String uid = _profile.id.trim();
    switch (action) {
      case _ProfileMenuAction.tip:
        if (uid.isEmpty) {
          return;
        }
        await showTipSheet(
          context,
          creatorUid: uid,
          creatorName: creatorLabel(
            name: _profile.name,
            username: _profile.username,
            fallback: context.l10n.accountCreatorFallback,
          ),
          source: 'profile',
        );
      case _ProfileMenuAction.report:
        if (uid.isEmpty) {
          return;
        }
        await showContentReportSheet(context, contentType: 'user', targetFirestoreDocId: uid);
      case _ProfileMenuAction.block:
        if (uid.isEmpty || !await requireSignedInAction(context) || !mounted) {
          return;
        }
        await confirmAndBlockUser(
          context: context,
          targetUserId: uid,
          displayName: creatorLabel(
            name: _profile.name,
            username: _profile.username,
            fallback: context.l10n.accountCreatorFallback,
          ),
        );
    }
  }

  Future<void> _refresh() async {
    final PublicProfileBloc bloc = context.read<PublicProfileBloc>();
    bloc.add(const PublicProfileEvent.refreshRequested());
    // orElse: a closed bloc (screen left mid refresh) must not throw StateError out of the refresh.
    await bloc.stream.firstWhere((PublicProfileState s) => s.status != LoadStatus.loading, orElse: () => bloc.state);
  }

  /// The rest of the links, when the header shows only the first three.
  void _showMoreLinks() {
    _trackAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_screen_more_links');
    showPrismSheet<void>(
      context,
      builder: (BuildContext sheetContext) => PrismSheetBody(
        title: context.l10n.accountMoreLinks,
        child: Wrap(
          spacing: PrismSpace.xs,
          runSpacing: PrismSpace.xs,
          children: <Widget>[
            for (final String key in _profile.links.keys)
              PrismIconButton(
                icon: profileLinkIcon(key),
                tooltip: key.inCaps,
                filled: true,
                onPressed: () => _openLink(key, _profile.links[key].toString()),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ownProfile) return _buildProfile(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        CoinsService.instance.inventoryNotifier,
        CoinsService.instance.xpNotifier,
      ]),
      builder: (BuildContext context, _) => _buildProfile(context),
    );
  }

  Widget _buildProfile(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Size screen = MediaQuery.sizeOf(context);
    final cosmetics = _cosmetics;
    final String safeUserPhoto = _profile.profilePhoto.trim();
    final bool hasUserPhoto = safeUserPhoto.isNotEmpty;
    final bool ownProfile = widget.ownProfile;
    final List<String> linkKeys = _profile.links.keys.toList(growable: false);
    final double headerWidth = math.min(screen.width, PrismLayout.readableWidth);
    final double coverHeight = screen.height * 0.19;
    final double topInset = MediaQuery.paddingOf(context).top;
    final String displayName = creatorLabel(
      name: _profile.name,
      username: _profile.username,
      fallback: context.l10n.accountCreatorFallback,
    );
    // Own profile is pushed from the home avatar now, so it needs a way back like any other profile.
    final bool showBack = !ownProfile || Navigator.canPop(context);
    final Widget editButton = _HeaderButton(
      tooltip: context.l10n.accountEditProfile,
      icon: Icons.edit_rounded,
      onPressed: () {
        PrismHaptics.tap();
        unawaited(_openEditProfilePanel(sourceContext: 'profile_screen_header_edit'));
      },
    );
    final Widget? linkButtons = linkKeys.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: PrismSpace.xxs,
            children: <Widget>[
              for (final String key in linkKeys.take(3))
                PrismIconButton(
                  tooltip: key,
                  icon: profileLinkIcon(key),
                  iconSize: 20,
                  filled: true,
                  onPressed: () {
                    PrismHaptics.tap();
                    unawaited(_openLink(key, _profile.links[key].toString()));
                  },
                ),
              if (linkKeys.length > 3)
                PrismIconButton(
                  tooltip: context.l10n.accountMoreLinks,
                  icon: Icons.more_horiz_rounded,
                  iconSize: 20,
                  filled: true,
                  onPressed: () {
                    PrismHaptics.tap();
                    _showMoreLinks();
                  },
                ),
            ],
          );
    final ProfileCompletenessStatus profileCompletenessStatus = ProfileCompletenessEvaluator.evaluate(
      app_state.prismUser,
      defaultProfilePhotoUrl: app_state.defaultProfilePhotoUrl,
    );
    final bool showProfileCompletenessCard = ownProfile && !profileCompletenessStatus.isComplete;
    final Widget defaultPhoto = SizedBox(
      width: 78,
      height: 78,
      child: ColoredBox(
        color: cs.surface,
        child: Icon(Icons.person_rounded, color: cs.primary, size: 30),
      ),
    );
    final Widget photo = ClipOval(
      child: hasUserPhoto
          ? CachedNetworkImage(
              imageUrl: safeUserPhoto,
              width: 78,
              height: 78,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => defaultPhoto,
            )
          : defaultPhoto,
    );
    // 86 points across with the frame or the accent ring.
    final Widget headerAvatar = ProfileFrame.draws(cosmetics.frame, premium: cosmetics.premium)
        ? ProfileFrame(frameId: cosmetics.frame, premium: cosmetics.premium, size: _headerAvatarSize, child: photo)
        // The accent ring follows the theme, like the camera badge in the edit panel. It is drawn over a photo that
        // reaches the middle of the ring, so the photo edge does not blend with the ring edge.
        : Container(
            width: _headerAvatarSize,
            height: _headerAvatarSize,
            padding: const EdgeInsets.all(2),
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.primary, width: 4),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: cs.onSurface),
              child: photo,
            ),
          );
    // As the header collapses, the avatar shrinks and moves into the bar next to the name, so the page keeps its
    // identity. With reduce motion it stays in the header, and a small copy fades in with the name.
    final bool carryAvatar = !context.reduceMotion;
    final TextStyle titleStyle = PrismTextStyles.cardTitle(context).copyWith(fontSize: 17);
    // The collapsed bar: Back at the start; the menu (and Gift on a creator profile) at the end. The title gets the
    // same room on both sides, so the toolbar centres it on the screen and the carried avatar can find its slot.
    final double trailingWidth =
        (ownProfile ? 44 : 44 + PrismSpace.xxs + 44) + sideSafeColumnWidth(context) + PrismSpace.sm;
    final double titleMaxWidth = math.max(
      0,
      screen.width - 2 * (math.max(PrismSpace.sm + 44, trailingWidth) + NavigationToolbar.kMiddleSpacing),
    );
    final TextPainter namePainter = TextPainter(
      text: TextSpan(text: displayName, style: titleStyle),
      maxLines: 1,
      ellipsis: '\u2026',
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(0, titleMaxWidth - _titleAvatarSize - PrismSpace.xs));
    final double titleNameWidth = math.min(
      namePainter.width.ceilToDouble(),
      math.max(0, titleMaxWidth - _titleAvatarSize - PrismSpace.xs),
    );
    namePainter.dispose();
    final double titleRowWidth = _titleAvatarSize + PrismSpace.xs + titleNameWidth;
    final double slotOffset = titleRowWidth / 2 - _titleAvatarSize / 2;
    final double collapsedAvatarX =
        screen.width / 2 + (Directionality.of(context) == TextDirection.rtl ? slotOffset : -slotOffset);
    final double expandedAvatarY = coverHeight - 56 + _headerAvatarSize / 2;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: cs.surface,
      endDrawer: ownProfile ? const ProfileDrawer() : null,
      body: PrismRefresh(
        onRefresh: _refresh,
        edgeOffset: topInset + kToolbarHeight,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverAppBar(
              // Pinned: the back button and the name stay on screen while the gallery scrolls.
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
              title: Builder(
                builder: (BuildContext context) {
                  final double opacity = _collapsedTitleOpacity(context);
                  if (opacity == 0) return const SizedBox.shrink();
                  // The name is already read out in the header below, so this copy is visual only.
                  return ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // The carried header avatar lands on this slot.
                        SizedBox.square(
                          key: const ValueKey<String>('profile-title-avatar-slot'),
                          dimension: _titleAvatarSize,
                          child: carryAvatar
                              ? null
                              : Opacity(
                                  opacity: opacity,
                                  child: FittedBox(child: headerAvatar),
                                ),
                        ),
                        const SizedBox(width: PrismSpace.xs),
                        // Flexible: mid-collapse, the fading actions can still take some of the bar.
                        Flexible(
                          child: Opacity(
                            opacity: opacity,
                            child: SizedBox(
                              width: titleNameWidth,
                              child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              leadingWidth: PrismSpace.sm + 44,
              leading: Padding(
                padding: const EdgeInsetsDirectional.only(start: PrismSpace.sm),
                child: Center(
                  child: showBack
                      ? _HeaderButton(
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          icon: Icons.arrow_back_rounded,
                          onPressed: () {
                            _trackAction(AnalyticsActionValue.backTapped, sourceContext: 'profile_screen_header_back');
                            Navigator.pop(context);
                          },
                        )
                      : editButton,
                ),
              ),
              actions: <Widget>[
                if (ownProfile) ...<Widget>[
                  // Stats and Edit fade out and give up their width as the header collapses, so the name centres
                  // between Back and the menu.
                  _CollapsingActions(
                    children: <Widget>[
                      // StatsEntryButton has no glass look, so the header builds the same button here.
                      _HeaderButton(
                        icon: Icons.bar_chart_rounded,
                        tooltip: context.l10n.statsEntry,
                        onPressed: () => context.router.push(CreatorStatsRoute(source: 'profile')),
                      ),
                      if (showBack) ...<Widget>[const SizedBox(width: PrismSpace.xxs), editButton],
                      const SizedBox(width: PrismSpace.xxs),
                    ],
                  ),
                  _HeaderButton(
                    tooltip: context.l10n.accountMenu,
                    icon: Icons.menu_rounded,
                    onPressed: () {
                      _trackAction(AnalyticsActionValue.openDrawerTapped, sourceContext: 'profile_screen_header_menu');
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ] else ...<Widget>[
                  _HeaderButton(
                    tooltip: context.l10n.accountGiftPassTooltip,
                    icon: Icons.card_giftcard_rounded,
                    onPressed: () => unawaited(_openGiftSheet()),
                  ),
                  const SizedBox(width: PrismSpace.xxs),
                  // The same glass look as PrismIconButton(glass: true) while the cover shows: the shadow sits under
                  // the 44 point circle. Collapsed, it is a plain icon like the rest of the bar.
                  Builder(
                    builder: (BuildContext context) {
                      final bool glass = _collapsedTitleOpacity(context) < 1;
                      return Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          if (glass)
                            const SizedBox.square(
                              dimension: 44,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 1)),
                                  ],
                                ),
                              ),
                            ),
                          PopupMenuButton<_ProfileMenuAction>(
                            tooltip: context.l10n.accountMoreOptions,
                            icon: const Icon(Icons.more_vert_rounded, size: 22),
                            iconColor: cs.onSurface,
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: glass ? cs.surface.withValues(alpha: 0.92) : null,
                              minimumSize: const Size.square(44),
                              fixedSize: const Size.square(44),
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            onSelected: _onMenuSelected,
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<_ProfileMenuAction>>[
                              if (app_state.prismUser.loggedIn &&
                                  context.read<PublicProfileBloc>().state.walls.isNotEmpty)
                                PopupMenuItem<_ProfileMenuAction>(
                                  value: _ProfileMenuAction.tip,
                                  child: Text(context.l10n.tipMenuItem),
                                ),
                              PopupMenuItem<_ProfileMenuAction>(
                                value: _ProfileMenuAction.report,
                                child: Text(context.l10n.accountReportUser),
                              ),
                              PopupMenuItem<_ProfileMenuAction>(
                                value: _ProfileMenuAction.block,
                                child: Text(context.l10n.accountBlockUser),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
              backgroundColor: cs.surface,
              automaticallyImplyLeading: false,
              actionsPadding: EdgeInsetsDirectional.only(end: sideSafeColumnWidth(context) + PrismSpace.sm),
              // The status bar is added on top of this, so the full header stays cover + 37 tall.
              expandedHeight: math.max(kToolbarHeight, coverHeight + 37 - topInset),
              flexibleSpace: Stack(
                children: <Widget>[
                  FlexibleSpaceBar(
                    background: Stack(
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            SizedBox(
                              width: screen.width,
                              height: coverHeight,
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  // With no custom cover, the latest upload (once the gallery has loaded it) is the art.
                                  BlocSelector<PublicProfileBloc, PublicProfileState, String?>(
                                    selector: (PublicProfileState state) => state.walls.isEmpty
                                        ? null
                                        : state.walls.first.wallpaperThumb ?? state.walls.first.wallpaperUrl,
                                    builder: (BuildContext context, String? latestWall) =>
                                        ProfileCover(url: _profile.coverPhoto, seed: _profile.id, artUrl: latestWall),
                                  ),
                                  // The bottom 40% of the cover fades into the page, so it has no hard edge.
                                  IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          stops: const <double>[0.6, 1],
                                          colors: <Color>[cs.surface.withValues(alpha: 0), cs.surface],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: double.maxFinite, height: 37),
                          ],
                        ),
                        if (!carryAvatar)
                          Positioned(
                            top: coverHeight - 56,
                            child: SizedBox(
                              width: screen.width,
                              child: Center(child: headerAvatar),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Outside the fading background, so the avatar stays visible while scroll carries it into the bar.
                  if (carryAvatar)
                    Builder(
                      builder: (BuildContext context) {
                        final double t = _headerExpansion(context);
                        final double x = lerpDouble(collapsedAvatarX, screen.width / 2, t)!;
                        final double y = lerpDouble(topInset + kToolbarHeight / 2, expandedAvatarY, t)!;
                        return Positioned(
                          key: const ValueKey<String>('profile-carried-avatar'),
                          left: x - _headerAvatarSize / 2,
                          top: y - _headerAvatarSize / 2,
                          child: IgnorePointer(
                            child: Transform.scale(
                              scale: lerpDouble(_titleAvatarSize / _headerAvatarSize, 1, t),
                              child: headerAvatar,
                            ),
                          ),
                        );
                      },
                    ),
                  // A hairline under the pinned bar once the cover has scrolled away, as on every other page.
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    child: Builder(
                      builder: (BuildContext context) => Opacity(
                        opacity: _collapsedTitleOpacity(context),
                        child: Divider(height: 1, thickness: 1, color: cs.onSurface.withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(PrismSpace.sm, PrismSpace.xxs, PrismSpace.sm, PrismSpace.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: headerWidth * 0.7,
                      child: GlowText(
                        displayName,
                        glowId: cosmetics.glow,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // rowTitle is w600, which gives the name more presence over the muted username below.
                        style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: headerWidth * 0.7,
                      child: Text(
                        '@${_profile.username}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PrismTextStyles.caption(
                          context,
                        ).copyWith(fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: 0.2),
                      ),
                    ),
                    if (_profile.bio.isNotEmpty) ...<Widget>[
                      const SizedBox(height: PrismSpace.xs),
                      SizedBox(
                        width: headerWidth * 0.72,
                        child: ProfileBioText(
                          bio: _profile.bio,
                          style: PrismTextStyles.caption(context).copyWith(fontWeight: FontWeight.normal, height: 1.45),
                          onOpenLink: _openBioLink,
                        ),
                      ),
                    ],
                    // One meta row: the Pro pill, then the badges.
                    ProfileBadgeRow(
                      badgeIds: _profile.badges,
                      leading: _profile.proBadge ? const ProProfileBadge() : null,
                    ),
                    const SizedBox(height: PrismSpace.sm),
                    SizedBox(
                      width: headerWidth * 0.9,
                      child: _StatsLine(
                        gaps: const <double>[PrismSpace.md, PrismSpace.xs],
                        dividerColor: cs.onSurface.withValues(alpha: 0.2),
                        children: <Widget>[
                          Semantics(
                            excludeSemantics: true,
                            label: context.l10n.accountFollowingCountLabel(
                              _compactCount(context, _profile.followingCount),
                            ),
                            button: ownProfile,
                            onTap: ownProfile ? _openFollowingList : null,
                            child: GestureDetector(
                              excludeFromSemantics: true,
                              onTap: ownProfile ? _openFollowingList : null,
                              child: _StatPill(count: _profile.followingCount, label: context.l10n.accountFollowing),
                            ),
                          ),
                          Semantics(
                            excludeSemantics: true,
                            label: context.l10n.accountFollowersCountLabel(
                              _compactCount(context, _profile.followerCount),
                            ),
                            button: true,
                            onTap: _openFollowersList,
                            child: GestureDetector(
                              excludeFromSemantics: true,
                              onTap: _openFollowersList,
                              child: _StatPill(
                                count: _profile.followerCount,
                                label: context.l10n.accountFollowersLabel(_profile.followerCount),
                              ),
                            ),
                          ),
                          if (!ownProfile) RankInfoChip(xp: cosmetics.xp),
                        ],
                      ),
                    ),
                    if (!ownProfile) ...<Widget>[
                      // Shrink-wrapped so the line is centred like the rest of the header.
                      IntrinsicWidth(child: FollowedByLine(creatorUid: _profile.id)),
                      const SizedBox(height: PrismSpace.md),
                      BlocConsumer<PublicProfileBloc, PublicProfileState>(
                        listenWhen: (prev, curr) =>
                            curr.followOutcome != null && prev.followOutcome != curr.followOutcome,
                        listener: (context, state) => showFollowOutcomeToast(context, state.followOutcome!),
                        buildWhen: (prev, curr) => prev.followOverrides != curr.followOverrides,
                        builder: (context, state) {
                          final bool following = _isFollowing(state);
                          // Follow and the links share one row; the links wrap under Follow when they do not fit.
                          return Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: PrismSpace.xs,
                            runSpacing: PrismSpace.xs,
                            children: <Widget>[
                              SizedBox(
                                width: 200,
                                child: PrismButton(
                                  label: following ? context.l10n.accountFollowing : context.l10n.accountFollow,
                                  icon: following ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
                                  variant: following ? PrismButtonVariant.tonal : PrismButtonVariant.primary,
                                  size: PrismButtonSize.compact,
                                  expand: true,
                                  onPressed: () => unawaited(_toggleFollow(following: following)),
                                ),
                              ),
                              ?linkButtons,
                            ],
                          );
                        },
                      ),
                    ] else if (linkButtons != null) ...<Widget>[const SizedBox(height: PrismSpace.sm), linkButtons],
                  ],
                ),
              ),
            ),
            // Content first: folders and wallpapers (uploads, or favourites when there are none), then the cards.
            SliverToBoxAdapter(
              child: ProfileFoldersRow(ownerId: _profile.id, ownProfile: ownProfile),
            ),
            UserProfileLoader(userId: _profile.id, ownProfile: ownProfile),
            if (ownProfile)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.lg, PrismSpace.page, PrismSpace.xxs),
                  child: RankProgressCard(onOpenShop: () => context.router.root.push(const ShopRoute())),
                ),
              ),
            if (showProfileCompletenessCard)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.page, PrismSpace.xxs),
                  child: ProfileCompletenessCard(
                    status: profileCompletenessStatus,
                    onCompleteNow: () async {
                      await _openEditProfilePanel(sourceContext: 'profile_completeness_card');
                    },
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: PrismSpace.xxl + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }
}

/// A header icon button: glass (page-colour circle, soft shadow) while the cover shows, a plain icon once the header
/// has collapsed into a flat bar. Reads the enclosing app bar's settings.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      PrismIconButton(icon: icon, tooltip: tooltip, glass: _collapsedTitleOpacity(context) < 1, onPressed: onPressed);
}

/// Header actions that fade out and shrink to no width as the header collapses, in step with the collapsed title.
/// They take no taps while they fade.
class _CollapsingActions extends StatelessWidget {
  const _CollapsingActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final double visible = 1 - _collapsedTitleOpacity(context);
    return IgnorePointer(
      ignoring: visible < 1,
      child: ClipRect(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          widthFactor: visible,
          child: Opacity(
            opacity: visible,
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

/// Compact stat display used in the profile header (e.g. "9182 Followers").
///
/// Separates the bold count from the muted label using clear weight and color
/// contrast without changing their relative type sizes.
class _StatPill extends StatelessWidget {
  const _StatPill({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        // Bold count — larger optical weight draws the eye first.
        text: _compactCount(context, count),
        style: PrismTextStyles.cardTitle(context),
        children: <TextSpan>[
          TextSpan(
            text: ' $label',
            style: PrismTextStyles.caption(context).copyWith(fontWeight: FontWeight.normal),
          ),
        ],
      ),
    );
  }
}

/// The profile stats in one centred row, with a short divider in each gap. [gaps] is the space on each side of each
/// divider. When the row does not fit, as with large text on a narrow phone, the stats stack, centred and with no
/// dividers, so words that fit the available width do not break in half.
class _StatsLine extends MultiChildRenderObjectWidget {
  const _StatsLine({required this.gaps, required this.dividerColor, required super.children});

  final List<double> gaps;
  final Color dividerColor;

  @override
  _RenderStatsLine createRenderObject(BuildContext context) =>
      _RenderStatsLine(gaps, dividerColor, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderStatsLine renderObject) => renderObject
    ..gaps = gaps
    ..dividerColor = dividerColor
    ..textDirection = Directionality.of(context);
}

class _StatsLineParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderStatsLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _StatsLineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _StatsLineParentData> {
  _RenderStatsLine(this._gaps, this._dividerColor, this._textDirection);

  static const double _dividerHeight = 16;

  List<double> _gaps;
  List<double> get gaps => _gaps;
  set gaps(List<double> value) {
    if (listEquals(value, _gaps)) return;
    _gaps = value;
    markNeedsLayout();
  }

  Color _dividerColor;
  Color get dividerColor => _dividerColor;
  set dividerColor(Color value) {
    if (value == _dividerColor) return;
    _dividerColor = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// The divider rectangles of the last layout. Empty when the stats are stacked.
  final List<Rect> _dividers = <Rect>[];

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _StatsLineParentData) child.parentData = _StatsLineParentData();
  }

  @override
  void performLayout() {
    final List<RenderBox> items = getChildrenAsList();
    for (final RenderBox item in items) {
      item.layout(BoxConstraints(maxWidth: constraints.maxWidth), parentUsesSize: true);
    }
    double rowWidth = 0;
    double rowHeight = 0;
    for (int i = 0; i < items.length; i++) {
      rowWidth += items[i].size.width + (i == 0 ? 0 : 2 * _gaps[i - 1] + 1);
      rowHeight = math.max(rowHeight, items[i].size.height);
    }
    _dividers.clear();
    if (rowWidth <= constraints.maxWidth) {
      size = constraints.constrain(Size(rowWidth, rowHeight));
      final bool rtl = _textDirection == TextDirection.rtl;
      double start = (size.width - rowWidth) / 2;
      for (int i = 0; i < items.length; i++) {
        final Size item = items[i].size;
        final double left = rtl ? size.width - start - item.width : start;
        (items[i].parentData! as _StatsLineParentData).offset = Offset(left, (rowHeight - item.height) / 2);
        start += item.width;
        if (i == items.length - 1) break;
        start += _gaps[i];
        _dividers.add(
          Rect.fromLTWH(rtl ? size.width - start - 1 : start, (rowHeight - _dividerHeight) / 2, 1, _dividerHeight),
        );
        start += 1 + _gaps[i];
      }
      return;
    }
    final double width = items.fold<double>(0, (double widest, RenderBox item) => math.max(widest, item.size.width));
    size = constraints.constrain(Size(width, 0));
    double top = 0;
    for (final RenderBox item in items) {
      (item.parentData! as _StatsLineParentData).offset = Offset((size.width - item.size.width) / 2, top);
      top += item.size.height + PrismSpace.xxs;
    }
    size = constraints.constrain(Size(size.width, math.max(0, top - PrismSpace.xxs)));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Paint paint = Paint()..color = _dividerColor;
    for (final Rect divider in _dividers) {
      context.canvas.drawRect(divider.shift(offset), paint);
    }
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

const double _headerAvatarSize = 86;
const double _titleAvatarSize = 28;

/// How open the pinned header is: 1 while the whole cover shows, 0 once it has collapsed into the bar. Reads the
/// enclosing app bar's settings.
double _headerExpansion(BuildContext context) {
  final FlexibleSpaceBarSettings? settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
  if (settings == null) return 1;
  final double range = settings.maxExtent - settings.minExtent;
  if (range <= 0) return 0;
  return ((settings.currentExtent - settings.minExtent) / range).clamp(0.0, 1.0);
}

/// How far the pinned header has collapsed, as the opacity of what shows only when it is collapsed: 0 while the
/// cover shows, rising to 1 over the last quarter of the collapse.
double _collapsedTitleOpacity(BuildContext context) => (1 - _headerExpansion(context) / 0.25).clamp(0.0, 1.0);

String _compactCount(BuildContext context, int count) =>
    NumberFormat.compact(locale: Localizations.localeOf(context).toString()).format(count);
