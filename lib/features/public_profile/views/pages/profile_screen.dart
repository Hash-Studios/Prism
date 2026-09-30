import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/constants/profile_links.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/utils/format_utils.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/popup/no_load_link_pop_up.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_card.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/features/public_profile/views/widgets/drawer_widget.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_loader.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_blocks/user_block_actions.dart';
import 'package:Prism/features/user_blocks/views/blocked_user_profile_shell.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

@RoutePage()
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, @PathParam('identifier') this.profileIdentifier});

  final String? profileIdentifier;

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  late final String _profileIdentifier = widget.profileIdentifier ?? app_state.prismUser.email;
  late final Stream<PublicProfileEntity?> _profileStream = getIt<PublicProfileRepository>().watchProfile(
    _profileIdentifier,
  );

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
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        // The app bar gives guests a Back button out of this screen.
        appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.surface),
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
          ? Scaffold(
              key: _scaffoldKey,
              body: _ProfileChild(
                ownProfile: true,
                parentScaffoldKey: _scaffoldKey,
                onProfileEdited: () => setState(() {}),
                profile: _ownProfile,
              ),
              endDrawer: SizedBox(width: MediaQuery.of(context).size.width * 0.68, child: const ProfileDrawer()),
            )
          : Scaffold(
              key: _scaffoldKey,
              body: StreamBuilder<PublicProfileEntity?>(
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
                  }
                  if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
                    return ColoredBox(
                      color: Theme.of(context).primaryColor,
                      child: Center(child: Loader()),
                    );
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
                    return ColoredBox(
                      color: Theme.of(context).primaryColor,
                      child: Center(
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.8,
                          child: const Text(
                            'Sorry! This user is inactive on the latest version, and hence they are not currently viewable.',
                            textAlign: TextAlign.center,
                          ),
                        ),
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
            ),
    );
  }
}

enum _ProfileMenuAction { report, block }

class _ProfileChild extends StatefulWidget {
  const _ProfileChild({required this.profile, required this.ownProfile, this.parentScaffoldKey, this.onProfileEdited});

  final PublicProfileEntity profile;
  final bool ownProfile;
  final GlobalKey<ScaffoldState>? parentScaffoldKey;

  /// Rebuilds the parent, which reads the edited fields from app_state.
  final VoidCallback? onProfileEdited;

  @override
  _ProfileChildState createState() => _ProfileChildState();
}

class _ProfileChildState extends State<_ProfileChild> {
  final ScrollController scrollController = ScrollController();

  PublicProfileEntity get _profile => widget.profile;

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
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
    if (following) {
      toasts.error('Unfollowed ${_profile.name}!');
    } else {
      toasts.success('Followed ${_profile.name}!');
    }
  }

  Future<void> _onMenuSelected(_ProfileMenuAction action) async {
    final String uid = _profile.id.trim();
    switch (action) {
      case _ProfileMenuAction.report:
        if (uid.isEmpty) {
          return;
        }
        await showContentReportSheet(context, contentType: 'user', targetFirestoreDocId: uid);
      case _ProfileMenuAction.block:
        final String email = _profile.email.trim();
        if (uid.isEmpty || email.isEmpty) {
          return;
        }
        await confirmAndBlockUser(context: context, targetUserId: uid, targetEmail: email, displayName: _profile.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String safeCoverPhoto = _profile.coverPhoto.trim();
    final String safeUserPhoto = _profile.profilePhoto.trim();
    final bool hasCoverPhoto = safeCoverPhoto.isNotEmpty;
    final bool hasUserPhoto = safeUserPhoto.isNotEmpty;
    final bool ownProfile = widget.ownProfile;
    final ScrollController? controller = ownProfile ? scrollController : null;
    final List<String> linkKeys = _profile.links.keys.toList(growable: false);
    // Own profile is pushed from the home avatar now, so it needs a way back like any other profile.
    final bool showBack = !ownProfile || Navigator.canPop(context);
    final Widget editButton = Padding(
      padding: const EdgeInsets.all(8.0),
      child: _HeaderButton(
        tooltip: 'Edit profile',
        icon: JamIcons.pencil,
        onPressed: () {
          unawaited(_openEditProfilePanel(sourceContext: 'profile_screen_header_edit'));
        },
      ),
    );
    final ProfileCompletenessStatus profileCompletenessStatus = ProfileCompletenessEvaluator.evaluate(
      app_state.prismUser,
      defaultProfilePhotoUrl: app_state.defaultProfilePhotoUrl,
    );
    final bool showProfileCompletenessCard = ownProfile && !profileCompletenessStatus.isComplete;
    final bool following = _profile.followers.contains(app_state.prismUser.email);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.primaryColor,
          body: NestedScrollView(
            controller: controller,
            headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
              SliverAppBar(
                toolbarHeight: MediaQuery.of(context).padding.top + kToolbarHeight + 32,
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
                actions: [
                  if (!ownProfile)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _HeaderButton(
                            icon: following ? JamIcons.user_remove : JamIcons.user_plus,
                            alignment: Alignment.centerRight,
                            onPressed: () => _toggleFollow(following: following),
                          ),
                          PopupMenuButton<_ProfileMenuAction>(
                            icon: const _CircleIcon(icon: JamIcons.more_vertical),
                            onSelected: _onMenuSelected,
                            itemBuilder: (BuildContext context) => const <PopupMenuEntry<_ProfileMenuAction>>[
                              PopupMenuItem<_ProfileMenuAction>(
                                value: _ProfileMenuAction.report,
                                child: Text('Report user'),
                              ),
                              PopupMenuItem<_ProfileMenuAction>(
                                value: _ProfileMenuAction.block,
                                child: Text('Block user'),
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
                        tooltip: 'Menu',
                        icon: JamIcons.menu,
                        alignment: Alignment.centerRight,
                        onPressed: () {
                          _trackAction(
                            AnalyticsActionValue.openDrawerTapped,
                            sourceContext: 'profile_screen_header_menu',
                          );
                          widget.parentScaffoldKey?.currentState?.openEndDrawer();
                        },
                      ),
                    ),
                ],
                backgroundColor: theme.primaryColor,
                automaticallyImplyLeading: false,
                expandedHeight: linkKeys.isEmpty
                    ? MediaQuery.of(context).size.height * 0.4
                    : MediaQuery.of(context).size.height * 0.46,
                flexibleSpace: Stack(
                  children: [
                    FlexibleSpaceBar(
                      background: Stack(
                        children: [
                          Column(
                            children: [
                              if (!hasCoverPhoto)
                                SvgPicture.string(
                                  defaultHeader
                                      .replaceAll('#181818', '#${theme.primaryColor.rgbHex}')
                                      .replaceAll('#E77597', '#${theme.colorScheme.error.rgbHex}'),
                                  fit: BoxFit.cover,
                                  width: MediaQuery.of(context).size.width,
                                  height: MediaQuery.of(context).size.height * 0.19,
                                )
                              else
                                CachedNetworkImage(
                                  imageUrl: safeCoverPhoto,
                                  fit: BoxFit.cover,
                                  width: MediaQuery.of(context).size.width,
                                  height: MediaQuery.of(context).size.height * 0.19,
                                ),
                              const SizedBox(width: double.maxFinite, height: 37),
                              Container(
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                                width: double.maxFinite,
                                height: linkKeys.isEmpty
                                    ? MediaQuery.of(context).size.height * 0.21 - 37
                                    : MediaQuery.of(context).size.height * 0.27 - 37,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.7,
                                      child: Text(
                                        _profile.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: PrismFonts.proximaNova,
                                          color: theme.colorScheme.secondary,
                                          fontSize: 22,
                                          // w600 gives the name more presence over the muted username below.
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.7,
                                      child: Text(
                                        '@${_profile.username}',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: PrismFonts.proximaNova,
                                          color: theme.colorScheme.secondary.withValues(alpha: 0.55),
                                          fontSize: 14,
                                          fontWeight: FontWeight.normal,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_profile.bio.isNotEmpty) ...[
                                      SizedBox(
                                        width: MediaQuery.of(context).size.width * 0.72,
                                        child: Text(
                                          _profile.bio,
                                          textAlign: TextAlign.center,
                                          // 2 lines: bios up to 150 chars deserve more space.
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: PrismFonts.proximaNova,
                                            color: theme.colorScheme.secondary.withValues(alpha: 0.65),
                                            fontSize: 13,
                                            fontWeight: FontWeight.normal,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.7,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Following count is tappable on own profile only.
                                          GestureDetector(
                                            onTap: ownProfile
                                                ? () => context.router.push(
                                                    FollowingListRoute(following: _profile.following),
                                                  )
                                                : null,
                                            child: _StatPill(count: _profile.following.length, label: 'Following'),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 16,
                                            margin: const EdgeInsets.symmetric(horizontal: 16),
                                            color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                                          ),
                                          // Followers count is tappable on both own and other profiles.
                                          GestureDetector(
                                            onTap: () =>
                                                context.router.push(FollowersRoute(followers: _profile.followers)),
                                            child: _StatPill(count: _profile.followers.length, label: 'Followers'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (linkKeys.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: MediaQuery.of(context).size.width,
                                        height: 48,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            for (final String key in linkKeys.take(3))
                                              _LinkButton(
                                                tooltip: key,
                                                icon: profileLinkIcon(key),
                                                onPressed: () async {
                                                  _trackAction(
                                                    AnalyticsActionValue.actionChipTapped,
                                                    sourceContext: 'profile_screen_link_chip',
                                                  );
                                                  final String link = _profile.links[key].toString();
                                                  final String targetLink = link.contains('@gmail.com')
                                                      ? 'mailto:$link'
                                                      : link;
                                                  final bool launched = await launchUrl(Uri.parse(targetLink));
                                                  unawaited(
                                                    analytics.track(
                                                      ExternalLinkOpenResultEvent(
                                                        surface: AnalyticsSurfaceValue.profileScreen,
                                                        destination: _destinationForLinkKey(key),
                                                        result: launched
                                                            ? EventResultValue.success
                                                            : EventResultValue.failure,
                                                        reason: launched ? null : AnalyticsReasonValue.error,
                                                        sourceContext: 'profile_screen_link_chip',
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            if (linkKeys.length > 3)
                                              _LinkButton(
                                                icon: JamIcons.more_horizontal,
                                                onPressed: () {
                                                  _trackAction(
                                                    AnalyticsActionValue.actionChipTapped,
                                                    sourceContext: 'profile_screen_more_links',
                                                  );
                                                  showNoLoadLinksPopUp(context, _profile.links);
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: MediaQuery.of(context).size.height * 0.19 - 56,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width,
                              child: Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    // Brand-locked pink ring — consistent with the
                                    // camera badge in the edit panel.
                                    border: Border.all(color: PrismColors.brandPink, width: 4),
                                    color: theme.colorScheme.secondary,
                                  ),
                                  child: ClipOval(
                                    child: hasUserPhoto
                                        ? CachedNetworkImage(
                                            imageUrl: safeUserPhoto,
                                            width: 78,
                                            height: 78,
                                            fit: BoxFit.cover,
                                          )
                                        : SizedBox(
                                            width: 78,
                                            height: 78,
                                            child: ColoredBox(
                                              color: theme.primaryColor,
                                              child: const Icon(JamIcons.user, color: PrismColors.brandPink, size: 30),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.maxFinite,
                      height: MediaQuery.of(context).padding.top,
                      color: theme.primaryColor.withValues(alpha: 0.5),
                    ),
                  ],
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
            ],
            body: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: UserProfileLoader(email: _profile.email),
            ),
          ),
        ),
      ],
    );
  }
}

/// Translucent circular icon used by the profile header buttons.
class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
      child: Icon(icon, color: Theme.of(context).colorScheme.secondary),
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
    final Color secondary = Theme.of(context).colorScheme.secondary;
    return IconButton(
      tooltip: tooltip,
      padding: const EdgeInsets.all(4),
      icon: Container(
        padding: const EdgeInsets.all(7.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: secondary.withValues(alpha: 0.1),
          border: Border.all(color: secondary.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: 18, color: secondary.withValues(alpha: 0.85)),
      ),
      onPressed: onPressed,
    );
  }
}

/// Compact stat display used in the profile header (e.g. "9182 Followers").
///
/// Separates the bold count from the muted label using clear weight and color
/// contrast — no size difference needed since both are on one line.
class _StatPill extends StatelessWidget {
  const _StatPill({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    return RichText(
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        // Bold count — larger optical weight draws the eye first.
        text: formatCompactCount(count),
        style: TextStyle(
          fontFamily: PrismFonts.proximaNova,
          color: secondary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(
            text: ' $label',
            style: TextStyle(
              fontFamily: PrismFonts.proximaNova,
              color: secondary.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
