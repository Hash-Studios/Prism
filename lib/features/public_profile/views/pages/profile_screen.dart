import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_card.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/widgets/drawer_widget.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_header.dart';
import 'package:Prism/features/public_profile/views/widgets/profile_parts.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_loader.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_blocks/user_block_actions.dart';
import 'package:Prism/features/user_blocks/views/blocked_user_profile_shell.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  late final String _profileIdentifier = widget.profileIdentifier ?? app_state.prismUser.email;
  late Stream<PublicProfileEntity?> _profileStream = _watchProfile();

  Stream<PublicProfileEntity?> _watchProfile() => getIt<PublicProfileRepository>().watchProfile(_profileIdentifier);

  bool get _isOwnProfile {
    final String identifier = _profileIdentifier.trim();
    if (identifier.isEmpty) {
      return true;
    }
    return identifier == app_state.prismUser.email || identifier == app_state.prismUser.username;
  }

  PublicProfileEntity get _ownProfile => PublicProfileEntity(
    id: app_state.prismUser.id,
    name: app_state.prismUser.name,
    email: app_state.prismUser.email,
    username: app_state.prismUser.username,
    profilePhoto: app_state.prismUser.profilePhoto,
    bio: app_state.prismUser.bio,
    followers: app_state.prismUser.followers,
    following: app_state.prismUser.following,
    links: app_state.prismUser.links,
    coverPhoto: app_state.prismUser.coverPhoto ?? '',
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
        title: 'Profile',
        body: SignInPrompt(feature: _isOwnProfile ? 'your profile' : 'profiles'),
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
          ? _ProfileChild(ownProfile: true, onProfileEdited: () => setState(() {}), profile: _ownProfile)
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
                    title: 'Profile',
                    body: GlintState(
                      kind: GlintStateKind.error,
                      title: 'Could not load this profile',
                      body: 'Check your connection and try again.',
                      actionLabel: 'Try again',
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
                  return const PrismPage(
                    title: 'Profile',
                    body: GlintState(
                      kind: GlintStateKind.empty,
                      title: 'Profile not available',
                      body: 'This user is inactive on the latest version of Prism, so their profile cannot be shown.',
                    ),
                  );
                }
                return StreamBuilder<Set<String>>(
                  stream: getIt<UserBlockRepository>().watchBlockedCreatorEmails(),
                  builder: (BuildContext context, AsyncSnapshot<Set<String>> blockSnap) {
                    if (BlockedCreatorsFilter.hidesCreatorEmail(profile.email, blockSnap.data ?? <String>{})) {
                      final String display = <String>[
                        profile.name.trim(),
                        profile.username.trim(),
                      ].firstWhere((String value) => value.isNotEmpty, orElse: () => profile.email);
                      return BlockedUserProfileShell(
                        targetUserId: profile.id,
                        targetEmail: profile.email,
                        displayName: display,
                      );
                    }
                    return _ProfileChild(ownProfile: false, profile: profile);
                  },
                );
              },
            ),
    );
  }
}

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
  bool _barScrolled = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _wallsKey = GlobalKey();

  PublicProfileEntity get _profile => widget.profile;

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

  Future<void> _openLink(String key, String link) async {
    _trackAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_screen_link_chip');
    final String trimmed = link.trim();
    final String target = trimmed.contains('@gmail.com') ? 'mailto:$trimmed' : trimmed;
    bool launched = false;
    try {
      launched = await launchUrl(Uri.parse(target));
    } catch (_) {
      toasts.error('Could not open this link.');
    }
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
        targetUserEmail: _profile.email,
      ),
    );
    toasts.success(following ? 'Unfollowed ${_profile.name}' : 'Following ${_profile.name}');
  }

  void _shareProfile() {
    _trackAction(AnalyticsActionValue.drawerSharePrismTapped, sourceContext: 'profile_screen_share');
    unawaited(
      createUserDynamicLink(
        app_state.prismUser.name,
        app_state.prismUser.username,
        app_state.prismUser.email,
        app_state.prismUser.bio,
        app_state.prismUser.profilePhoto,
        context: context,
      ),
    );
  }

  Future<void> _onMenuSelected(ProfileMenuAction action) async {
    final String uid = _profile.id.trim();
    switch (action) {
      case ProfileMenuAction.report:
        if (uid.isEmpty) {
          return;
        }
        await showContentReportSheet(context, contentType: 'user', targetFirestoreDocId: uid);
      case ProfileMenuAction.block:
        final String email = _profile.email.trim();
        if (uid.isEmpty || email.isEmpty) {
          return;
        }
        await confirmAndBlockUser(context: context, targetUserId: uid, targetEmail: email, displayName: _profile.name);
    }
  }

  Future<void> _refresh() async {
    final PublicProfileBloc bloc = context.read<PublicProfileBloc>();
    bloc.add(const PublicProfileEvent.refreshRequested());
    await bloc.stream.firstWhere((PublicProfileState s) => s.status != LoadStatus.loading);
  }

  void _scrollToWalls() {
    final BuildContext? target = _wallsKey.currentContext;
    if (target == null) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        duration: context.motion(PrismDurations.base),
        curve: PrismCurves.move,
        alignment: 0.02,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool ownProfile = widget.ownProfile;
    // Own profile is pushed from the home avatar now, so it needs a way back like any other profile.
    final bool showBack = !ownProfile || Navigator.canPop(context);
    final ProfileCompletenessStatus completeness = ProfileCompletenessEvaluator.evaluate(
      app_state.prismUser,
      defaultProfilePhotoUrl: app_state.defaultProfilePhotoUrl,
    );
    final bool showCompleteness = ownProfile && !completeness.isComplete;
    final bool following = _profile.followers.contains(app_state.prismUser.email);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: cs.surface,
      endDrawer: ownProfile ? const ProfileDrawer() : null,
      body: Stack(
        children: <Widget>[
          RefreshIndicator(
            onRefresh: _refresh,
            edgeOffset: MediaQuery.paddingOf(context).top + PrismSpace.xxxl,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
                final bool scrolled = n.metrics.pixels > 96;
                if (scrolled != _barScrolled) setState(() => _barScrolled = scrolled);
                return false;
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: ProfileHeader(
                      profile: _profile,
                      ownProfile: ownProfile,
                      following: following,
                      isPro: ownProfile && app_state.prismUser.premium,
                      onEdit: () => unawaited(_openEditProfilePanel(sourceContext: 'profile_screen_edit_button')),
                      onShare: _shareProfile,
                      onToggleFollow: () => _toggleFollow(following: following),
                      onOpenFollowers: () => context.router.push(FollowersRoute(followers: _profile.followers)),
                      onOpenFollowing: () => context.router.push(FollowingListRoute(following: _profile.following)),
                      onOpenPosts: _scrollToWalls,
                      onOpenLink: _openLink,
                    ),
                  ),
                  if (showCompleteness)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.lg, PrismSpace.page, 0),
                        child: ProfileCompletenessCard(
                          status: completeness,
                          onCompleteNow: () => _openEditProfilePanel(sourceContext: 'profile_completeness_card'),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    key: _wallsKey,
                    child: const PrismSectionHeader(
                      title: 'Wallpapers',
                      padding: EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xl, PrismSpace.page, PrismSpace.sm),
                    ),
                  ),
                  UserProfileLoader(email: _profile.email, ownProfile: ownProfile),
                  SliverToBoxAdapter(child: SizedBox(height: PrismSpace.xxl + MediaQuery.paddingOf(context).bottom)),
                ],
              ),
            ),
          ),
          // The action row floats over the cover, then gains the page colour once the cover scrolls away.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: context.motion(PrismDurations.fast),
              padding: EdgeInsets.fromLTRB(
                PrismSpace.xs,
                MediaQuery.paddingOf(context).top + PrismSpace.xxs,
                PrismSpace.xs,
                PrismSpace.xxs,
              ),
              decoration: BoxDecoration(
                color: _barScrolled ? cs.surface : cs.surface.withValues(alpha: 0),
                border: Border(
                  bottom: BorderSide(color: cs.onSurface.withValues(alpha: _barScrolled ? 0.08 : 0)),
                ),
              ),
              child: Row(
                children: <Widget>[
                  if (showBack)
                    PrismIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onImage: !_barScrolled,
                      onPressed: () {
                        _trackAction(AnalyticsActionValue.backTapped, sourceContext: 'profile_screen_header_back');
                        Navigator.pop(context);
                      },
                    ),
                  const Spacer(),
                  if (ownProfile) ...<Widget>[
                    PrismIconButton(
                      icon: Icons.edit_rounded,
                      tooltip: 'Edit profile',
                      onImage: !_barScrolled,
                      onPressed: () => unawaited(_openEditProfilePanel(sourceContext: 'profile_screen_header_edit')),
                    ),
                    const SizedBox(width: PrismSpace.xs),
                    PrismIconButton(
                      icon: Icons.menu_rounded,
                      tooltip: 'Menu',
                      onImage: !_barScrolled,
                      onPressed: () {
                        _trackAction(
                          AnalyticsActionValue.openDrawerTapped,
                          sourceContext: 'profile_screen_header_menu',
                        );
                        _scaffoldKey.currentState?.openEndDrawer();
                      },
                    ),
                  ] else
                    ProfileOverflowMenu(onSelected: _onMenuSelected),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
