import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
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
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/badges/domain/badge_catalog.dart';
import 'package:Prism/features/badges/views/widgets/profile_badge_row.dart';
import 'package:Prism/features/creator_stats/views/widgets/stats_entry_button.dart';
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
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
  );

  @override
  void initState() {
    super.initState();
    _contentLoadTracker.start();
  }

  @override
  Widget build(BuildContext context) {
    // usersV2 reads require auth per firestore.rules; guests (iOS browse-without-account)
    // must sign in first, for both their own profile and other users' profiles.
    if (!app_state.prismUser.loggedIn) {
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

  void _toggleFollow({required bool following}) {
    PrismHaptics.tap();
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

  void _openGiftSheet() {
    PrismHaptics.tap();
    showPrismSheet<void>(
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
        if (uid.isEmpty) {
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
    await bloc.stream.firstWhere((PublicProfileState s) => s.status != LoadStatus.loading);
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
    final int badgeCount = _profile.badges.toSet().where((String id) => badgeInfo(id) != null).length;
    final int badgesPerRow = math.max(1, ((screen.width - 24 + 8) / 40).floor());
    final int badgeRows = (badgeCount / badgesPerRow).ceil();
    final double badgeHeight = badgeRows == 0 ? 0 : 10 + badgeRows * 32 + (badgeRows - 1) * 8;
    final double minimumInfoHeight =
        (linkKeys.isEmpty ? screen.height * 0.21 : screen.height * 0.27) - 37 + badgeHeight;
    // Own profile is pushed from the home avatar now, so it needs a way back like any other profile.
    final bool showBack = !ownProfile || Navigator.canPop(context);
    final Widget editButton = Padding(
      padding: const EdgeInsets.all(8.0),
      child: _HeaderButton(
        tooltip: context.l10n.accountEditProfile,
        icon: JamIcons.pencil,
        onPressed: () {
          PrismHaptics.tap();
          unawaited(_openEditProfilePanel(sourceContext: 'profile_screen_header_edit'));
        },
      ),
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
        child: Icon(JamIcons.user, color: cs.primary, size: 30),
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: cs.surface,
      endDrawer: ownProfile ? const ProfileDrawer() : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: MediaQuery.paddingOf(context).top + PrismSpace.xxxl,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverAppBar(
              toolbarHeight: MediaQuery.paddingOf(context).top + kToolbarHeight + 32,
              primary: false,
              floating: true,
              elevation: 0,
              leading: showBack
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _HeaderButton(
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        icon: JamIcons.chevron_left,
                        onPressed: () {
                          _trackAction(AnalyticsActionValue.backTapped, sourceContext: 'profile_screen_header_back');
                          Navigator.pop(context);
                        },
                      ),
                    )
                  : editButton,
              actions: <Widget>[
                StatsEntryButton(source: 'profile', visible: ownProfile),
                if (!ownProfile)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _HeaderButton(
                          tooltip: context.l10n.accountGiftPassTooltip,
                          icon: JamIcons.gift,
                          onPressed: _openGiftSheet,
                        ),
                        BlocConsumer<PublicProfileBloc, PublicProfileState>(
                          listenWhen: (prev, curr) =>
                              curr.followOutcome != null && prev.followOutcome != curr.followOutcome,
                          listener: (context, state) => showFollowOutcomeToast(context, state.followOutcome!),
                          buildWhen: (prev, curr) => prev.followOverrides != curr.followOverrides,
                          builder: (context, state) {
                            final bool following = _isFollowing(state);
                            return _HeaderButton(
                              tooltip: following ? context.l10n.accountUnfollow : context.l10n.accountFollow,
                              icon: following ? JamIcons.user_remove : JamIcons.user_plus,
                              alignment: AlignmentDirectional.centerEnd,
                              onPressed: () => _toggleFollow(following: following),
                            );
                          },
                        ),
                        PopupMenuButton<_ProfileMenuAction>(
                          tooltip: context.l10n.accountMoreOptions,
                          icon: const _CircleIcon(icon: JamIcons.more_vertical),
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
                    ),
                  ),
                if (ownProfile && showBack) editButton,
                if (ownProfile)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _HeaderButton(
                      tooltip: context.l10n.accountMenu,
                      icon: JamIcons.menu,
                      alignment: AlignmentDirectional.centerEnd,
                      onPressed: () {
                        _trackAction(
                          AnalyticsActionValue.openDrawerTapped,
                          sourceContext: 'profile_screen_header_menu',
                        );
                        _scaffoldKey.currentState?.openEndDrawer();
                      },
                    ),
                  ),
              ],
              backgroundColor: cs.surface,
              automaticallyImplyLeading: false,
              actionsPadding: EdgeInsets.only(right: sideSafeColumnWidth(context)),
              expandedHeight: coverHeight + 37,
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
                              child: ProfileCover(url: _profile.coverPhoto),
                            ),
                            const SizedBox(width: double.maxFinite, height: 37),
                          ],
                        ),
                        Positioned(
                          top: coverHeight - 56,
                          child: SizedBox(
                            width: screen.width,
                            child: Center(
                              child: ProfileFrame.draws(cosmetics.frame, premium: cosmetics.premium)
                                  ? ProfileFrame(
                                      frameId: cosmetics.frame,
                                      premium: cosmetics.premium,
                                      size: 86,
                                      child: photo,
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        // The accent ring follows the theme, like the camera badge in the edit panel.
                                        border: Border.all(color: cs.primary, width: 4),
                                        color: cs.onSurface,
                                      ),
                                      child: photo,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.maxFinite,
                    height: MediaQuery.paddingOf(context).top,
                    color: cs.surface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumInfoHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: headerWidth * 0.7,
                        child: GlowText(
                          creatorLabel(
                            name: _profile.name,
                            username: _profile.username,
                            fallback: context.l10n.accountCreatorFallback,
                          ),
                          glowId: cosmetics.glow,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: PrismFonts.proximaNova,
                            color: cs.onSurface,
                            fontSize: 22,
                            // w600 gives the name more presence over the muted username below.
                            fontWeight: FontWeight.w600,
                          ),
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
                          style: TextStyle(
                            fontFamily: PrismFonts.proximaNova,
                            color: cs.onSurface.withValues(alpha: 0.55),
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_profile.bio.isNotEmpty) ...<Widget>[
                        SizedBox(
                          width: headerWidth * 0.72,
                          child: ProfileBioText(
                            bio: _profile.bio,
                            style: TextStyle(
                              fontFamily: PrismFonts.proximaNova,
                              color: cs.onSurface.withValues(alpha: 0.65),
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                              height: 1.45,
                            ),
                            onOpenLink: _openBioLink,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      ProfileBadgeRow(badgeIds: _profile.badges),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: headerWidth * 0.9,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Flexible(
                              child: Semantics(
                                excludeSemantics: true,
                                label: context.l10n.accountFollowingCountLabel(
                                  _compactCount(context, _profile.followingCount),
                                ),
                                button: ownProfile,
                                onTap: ownProfile ? _openFollowingList : null,
                                child: GestureDetector(
                                  excludeFromSemantics: true,
                                  onTap: ownProfile ? _openFollowingList : null,
                                  child: _StatPill(
                                    count: _profile.followingCount,
                                    label: context.l10n.accountFollowing,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 16,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              color: cs.onSurface.withValues(alpha: 0.2),
                            ),
                            Flexible(
                              child: Semantics(
                                excludeSemantics: true,
                                label: context.l10n.accountFollowersCountLabel(
                                  _compactCount(context, _profile.followerCount),
                                ),
                                button: true,
                                onTap: _openFollowersList,
                                child: GestureDetector(
                                  excludeFromSemantics: true,
                                  onTap: _openFollowersList,
                                  child: _StatPill(count: _profile.followerCount, label: context.l10n.accountFollowers),
                                ),
                              ),
                            ),
                            if (!ownProfile) ...<Widget>[
                              Container(
                                width: 1,
                                height: 16,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                color: cs.onSurface.withValues(alpha: 0.2),
                              ),
                              Flexible(child: RankInfoChip(xp: cosmetics.xp)),
                            ],
                          ],
                        ),
                      ),
                      if (linkKeys.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: screen.width,
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              for (final String key in linkKeys.take(3))
                                _LinkButton(
                                  tooltip: key,
                                  icon: profileLinkIcon(key),
                                  onPressed: () => _openLink(key, _profile.links[key].toString()),
                                ),
                              if (linkKeys.length > 3)
                                _LinkButton(
                                  tooltip: context.l10n.accountMoreLinks,
                                  icon: JamIcons.more_horizontal,
                                  onPressed: _showMoreLinks,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (ownProfile)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: RankProgressCard(onOpenShop: () => context.router.root.push(const ShopRoute())),
                ),
              ),
            if (showProfileCompletenessCard)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: ProfileCompletenessCard(
                    status: profileCompletenessStatus,
                    onCompleteNow: () async {
                      await _openEditProfilePanel(sourceContext: 'profile_completeness_card');
                    },
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: ProfileFoldersRow(ownerId: _profile.id, ownProfile: ownProfile),
            ),
            UserProfileLoader(userId: _profile.id, ownProfile: ownProfile),
            SliverToBoxAdapter(child: SizedBox(height: PrismSpace.xxl + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }
}

/// Translucent circular icon used by the profile header buttons. It sits on the cover, so it is white on a scrim.
class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.38)),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onPressed, this.tooltip, this.alignment = Alignment.center});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      alignment: alignment,
      padding: const EdgeInsets.all(2),
      icon: _CircleIcon(icon: icon),
      onPressed: onPressed,
    );
  }
}

/// Outlined circular icon button for one profile link.
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return IconButton(
      tooltip: tooltip,
      padding: const EdgeInsets.all(4),
      icon: Container(
        padding: const EdgeInsets.all(7.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ink.withValues(alpha: 0.1),
          border: Border.all(color: ink.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: 18, color: ink.withValues(alpha: 0.85)),
      ),
      onPressed: () {
        PrismHaptics.tap();
        onPressed();
      },
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
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return RichText(
      textAlign: TextAlign.center,
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        // Bold count — larger optical weight draws the eye first.
        text: _compactCount(context, count),
        style: TextStyle(fontFamily: PrismFonts.proximaNova, color: ink, fontSize: 16, fontWeight: FontWeight.w700),
        children: <TextSpan>[
          TextSpan(
            text: ' $label',
            style: TextStyle(
              fontFamily: PrismFonts.proximaNova,
              color: ink.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

String _compactCount(BuildContext context, int count) =>
    NumberFormat.compact(locale: Localizations.localeOf(context).toString()).format(count);
