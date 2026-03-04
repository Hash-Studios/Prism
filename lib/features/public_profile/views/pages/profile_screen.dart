import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/coins/coin_balance_chip.dart';
import 'package:Prism/core/widgets/coins/streak_pill.dart';
import 'package:Prism/core/widgets/common/safe_rive_asset.dart';
import 'package:Prism/core/widgets/popup/noLoadLinkPopUp.dart';
import 'package:Prism/data/profile/wallpaper/public_profile_data.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_card.dart';
import 'package:Prism/features/public_profile/views/widgets/about_list.dart';
import 'package:Prism/features/public_profile/views/widgets/download_list.dart';
import 'package:Prism/features/public_profile/views/widgets/drawer_widget.dart';
import 'package:Prism/features/public_profile/views/widgets/general_list.dart';
import 'package:Prism/features/public_profile/views/widgets/premium_list.dart';
import 'package:Prism/features/public_profile/views/widgets/user_list.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_loader.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_setup_loader.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  String? profileIdentifier;

  Object? _mapValue(Map<String, dynamic> data, String key) => data[key];
  String _mapString(Map<String, dynamic> data, String key) => _mapValue(data, key)?.toString() ?? '';
  bool _mapBool(Map<String, dynamic> data, String key) {
    final value = _mapValue(data, key);
    return value is bool && value;
  }

  List<Object?> _mapList(Map<String, dynamic> data, String key) {
    final value = _mapValue(data, key);
    if (value is List) {
      return value.whereType<Object?>().toList(growable: false);
    }
    return const <Object?>[];
  }

  Map<String, dynamic> _mapObject(Map<String, dynamic> data, String key) {
    final value = _mapValue(data, key);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  bool get _isOwnProfile {
    final String identifier = (profileIdentifier ?? '').trim();
    if (identifier.isEmpty) {
      return true;
    }
    return identifier == app_state.prismUser.email || identifier == app_state.prismUser.username;
  }

  @override
  void initState() {
    profileIdentifier = widget.profileIdentifier ?? app_state.prismUser.email;
    _contentLoadTracker.start();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {}
      },
      child: _isOwnProfile
          ? Scaffold(
              key: _scaffoldKey,
              body: _ProfileChild(
                ownProfile: true,
                parentScaffoldKey: _scaffoldKey,
                id: app_state.prismUser.id,
                bio: app_state.prismUser.bio,
                coverPhoto: app_state.prismUser.coverPhoto,
                email: app_state.prismUser.email,
                links: app_state.prismUser.links,
                name: app_state.prismUser.name,
                premium: app_state.prismUser.premium,
                userPhoto: app_state.prismUser.profilePhoto,
                username: app_state.prismUser.username,
                followers: app_state.prismUser.followers,
                following: app_state.prismUser.following,
              ),
              endDrawer: app_state.prismUser.loggedIn
                  ? SizedBox(width: MediaQuery.of(context).size.width * 0.68, child: ProfileDrawer())
                  : null,
            )
          : Scaffold(
              key: _scaffoldKey,
              body: StreamBuilder<List<Map<String, dynamic>>>(
                stream: getUserProfile(profileIdentifier!),
                builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
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
                  if (snapshot.hasData && snapshot.data != null) {
                    if (snapshot.data!.isEmpty) {
                      _contentLoadTracker.success(
                        itemCount: 0,
                        onSuccess: ({required int loadTimeMs, int? itemCount}) async {
                          await analytics.track(
                            SurfaceContentLoadedEvent(
                              surface: AnalyticsSurfaceValue.profileScreen,
                              result: EventResultValue.empty,
                              loadTimeMs: loadTimeMs,
                              sourceContext: 'profile_screen_stream',
                              itemCount: itemCount,
                            ),
                          );
                        },
                      );
                      return ColoredBox(
                        color: Theme.of(context).primaryColor,
                        child: Center(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.8,
                            child: const Text(
                              "Sorry! This user is inactive on the latest version, and hence they are not currently viewable.",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }
                    final data = snapshot.data!.first;
                    _contentLoadTracker.success(
                      itemCount: 1,
                      onSuccess: ({required int loadTimeMs, int? itemCount}) async {
                        await analytics.track(
                          SurfaceContentLoadedEvent(
                            surface: AnalyticsSurfaceValue.profileScreen,
                            result: EventResultValue.success,
                            loadTimeMs: loadTimeMs,
                            sourceContext: 'profile_screen_stream',
                            itemCount: itemCount,
                          ),
                        );
                      },
                    );
                    final Map<String, dynamic> links = _mapObject(data, 'links');
                    final bool premium = _mapBool(data, 'premium');
                    final List<Object?> followers = _mapList(data, 'followers');
                    final List<Object?> following = _mapList(data, 'following');
                    return _ProfileChild(
                      ownProfile: false,
                      id: _mapString(data, '__docId'),
                      bio: _mapString(data, 'bio'),
                      coverPhoto: _mapString(data, 'coverPhoto'),
                      email: _mapString(data, 'email'),
                      links: links,
                      name: _mapString(data, 'name'),
                      premium: premium,
                      userPhoto: _mapString(data, 'profilePhoto'),
                      username: _mapString(data, 'username'),
                      followers: followers,
                      following: following,
                    );
                  }
                  return ColoredBox(
                    color: Theme.of(context).primaryColor,
                    child: Center(child: Loader()),
                  );
                },
              ),
            ),
    );
  }
}

class _ProfileChild extends StatefulWidget {
  final String? name;
  final String? username;
  final String? id;
  final String? email;
  final String? userPhoto;
  final String? coverPhoto;
  final bool? premium;
  final bool? ownProfile;
  final Map? links;
  final String? bio;
  final List? followers;
  final List? following;
  final GlobalKey<ScaffoldState>? parentScaffoldKey;
  const _ProfileChild({
    required this.name,
    required this.username,
    required this.id,
    required this.email,
    required this.userPhoto,
    required this.coverPhoto,
    required this.premium,
    required this.ownProfile,
    required this.links,
    required this.bio,
    required this.followers,
    required this.following,
    this.parentScaffoldKey,
  });
  @override
  _ProfileChildState createState() => _ProfileChildState();
}

class _ProfileChildState extends State<_ProfileChild> {
  // int favCount = main.prefs.get('userFavs') as int? ?? 0;
  // int profileCount = ((main.prefs.get('userPosts') as int?) ?? 0) +
  //     ((main.prefs.get('userSetups') as int?) ?? 0);
  final ScrollController scrollController = ScrollController();
  // int count = 0;
  @override
  void initState() {
    // count = main.prefs.get('easterCount', defaultValue: 0) as int;
    // checkFav();
    super.initState();
  }

  void _trackAction(AnalyticsActionValue action, {String sourceContext = 'profile_screen'}) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.profileScreen,
          action: action,
          sourceContext: sourceContext,
          itemType: ItemTypeValue.user,
          itemId: widget.id,
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
    await context.router.push(const EditProfilePanelRoute());
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final String safeCoverPhoto = (widget.coverPhoto ?? "").trim();
    final String safeUserPhoto = (widget.userPhoto ?? "").trim();
    final bool hasCoverPhoto = safeCoverPhoto.isNotEmpty;
    final bool hasUserPhoto = safeUserPhoto.isNotEmpty;
    final ScrollController? controller = widget.ownProfile!
        ? InheritedDataProvider.of(context)!.scrollController
        : ScrollController();
    final ProfileCompletenessStatus profileCompletenessStatus = ProfileCompletenessEvaluator.evaluate(
      app_state.prismUser,
      defaultProfilePhotoUrl: app_state.defaultProfilePhotoUrl,
    );
    final bool showProfileCompletenessCard =
        widget.ownProfile! && app_state.prismUser.loggedIn && !profileCompletenessStatus.isComplete;

    return !widget.ownProfile! || app_state.prismUser.loggedIn
        ? DefaultTabController(
            length: 2,
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: Theme.of(context).primaryColor,
                  body: NestedScrollView(
                    controller: controller,
                    headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
                      SliverAppBar(
                        toolbarHeight: MediaQuery.of(context).padding.top + kToolbarHeight + 32,
                        primary: false,
                        floating: true,
                        elevation: 0,
                        leading: !widget.ownProfile! || app_state.prismUser.loggedIn == false
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: IconButton(
                                  padding: const EdgeInsets.all(2),
                                  icon: Container(
                                    padding: const EdgeInsets.all(6.0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                    ),
                                    child: Icon(JamIcons.chevron_left, color: Theme.of(context).colorScheme.secondary),
                                  ),
                                  onPressed: () {
                                    _trackAction(
                                      AnalyticsActionValue.backTapped,
                                      sourceContext: 'profile_screen_header_back',
                                    );
                                    Navigator.pop(context);
                                  },
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: IconButton(
                                  padding: const EdgeInsets.all(2),
                                  icon: Container(
                                    padding: const EdgeInsets.all(6.0),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                    ),
                                    child: Icon(JamIcons.pencil, color: Theme.of(context).colorScheme.secondary),
                                  ),
                                  onPressed: () {
                                    unawaited(_openEditProfilePanel(sourceContext: 'profile_screen_header_edit'));
                                  },
                                ),
                              ),
                        actions: [
                          if (app_state.prismUser.loggedIn)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                              child: StreakPill(),
                            ),
                          if (app_state.prismUser.loggedIn)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: CoinBalanceChip(sourceTag: 'coins.chip.profile_screen', showStreak: false),
                            ),
                          if (!widget.ownProfile! || app_state.prismUser.loggedIn == false)
                            if (app_state.prismUser.loggedIn)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ((widget.followers ?? []).contains(app_state.prismUser.email))
                                    ? IconButton(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.all(2),
                                        icon: Container(
                                          padding: const EdgeInsets.all(6.0),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                          ),
                                          child: Icon(
                                            JamIcons.user_remove,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                        ),
                                        onPressed: () {
                                          _trackAction(
                                            AnalyticsActionValue.unfollowTapped,
                                            sourceContext: 'profile_screen_follow_action',
                                          );
                                          unfollow(widget.email!, widget.id!);
                                          toasts.error("Unfollowed ${widget.name}!");
                                        },
                                      )
                                    : IconButton(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.all(2),
                                        icon: Container(
                                          padding: const EdgeInsets.all(6.0),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                          ),
                                          child: Icon(
                                            JamIcons.user_plus,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                        ),
                                        onPressed: () {
                                          _trackAction(
                                            AnalyticsActionValue.followTapped,
                                            sourceContext: 'profile_screen_follow_action',
                                          );
                                          follow(widget.email!, widget.id!);
                                          toasts.codeSend("Followed ${widget.name}!");
                                        },
                                      ),
                              ),
                          if (widget.ownProfile! && app_state.prismUser.loggedIn)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: IconButton(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.all(2),
                                icon: Container(
                                  padding: const EdgeInsets.all(6.0),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                  ),
                                  child: Icon(JamIcons.menu, color: Theme.of(context).colorScheme.secondary),
                                ),
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
                        backgroundColor: Theme.of(context).primaryColor,
                        automaticallyImplyLeading: false,
                        expandedHeight: (widget.links ?? {}).keys.toList().isEmpty
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
                                              .replaceAll(
                                                "#181818",
                                                "#${Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2)}",
                                              )
                                              .replaceAll(
                                                "#E77597",
                                                "#${Theme.of(context).colorScheme.error.toARGB32().toRadixString(16).substring(2)}",
                                              ),
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
                                        height: (widget.links ?? {}).keys.toList().isEmpty
                                            ? MediaQuery.of(context).size.height * 0.21 - 37
                                            : MediaQuery.of(context).size.height * 0.27 - 37,
                                        child: Column(
                                          children: [
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width * 0.7,
                                              child: Text(
                                                widget.name!,
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: "Proxima Nova",
                                                  color: Theme.of(context).colorScheme.secondary,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width * 0.7,
                                              child: Text(
                                                "@${widget.username}",
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: "Proxima Nova",
                                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width * 0.7,
                                              child: Text(
                                                widget.bio ?? "",
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily: "Proxima Nova",
                                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width * 0.7,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  RichText(
                                                    text: TextSpan(
                                                      text: "${(widget.following ?? []).length}",
                                                      style: TextStyle(
                                                        fontFamily: "Proxima Nova",
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.secondary.withValues(alpha: 1),
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      children: [
                                                        TextSpan(
                                                          text: " Following",
                                                          style: TextStyle(
                                                            color: Theme.of(
                                                              context,
                                                            ).colorScheme.secondary.withValues(alpha: 0.6),
                                                            fontWeight: FontWeight.normal,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(width: 24),
                                                  RichText(
                                                    text: TextSpan(
                                                      text: "${(widget.followers ?? []).length}",
                                                      style: TextStyle(
                                                        fontFamily: "Proxima Nova",
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.secondary.withValues(alpha: 1),
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      children: [
                                                        TextSpan(
                                                          text: " Followers",
                                                          style: TextStyle(
                                                            color: Theme.of(
                                                              context,
                                                            ).colorScheme.secondary.withValues(alpha: 0.6),
                                                            fontWeight: FontWeight.normal,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if ((widget.links ?? {}).keys.toList().isNotEmpty)
                                              const SizedBox(height: 8),
                                            if ((widget.links ?? {}).keys.toList().isNotEmpty)
                                              SizedBox(
                                                width: MediaQuery.of(context).size.width,
                                                height: 48,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    ...(widget.links ?? {}).keys
                                                        .toList()
                                                        .map(
                                                          (e) => IconButton(
                                                            padding: const EdgeInsets.all(2),
                                                            icon: Container(
                                                              padding: const EdgeInsets.all(6.0),
                                                              decoration: BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.secondary.withValues(alpha: 0.1),
                                                              ),
                                                              child: Icon(
                                                                linksIconData[e.toString()] ?? JamIcons.link,
                                                                size: 20,
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.secondary.withValues(alpha: 0.8),
                                                              ),
                                                            ),
                                                            onPressed: () async {
                                                              _trackAction(
                                                                AnalyticsActionValue.actionChipTapped,
                                                                sourceContext: 'profile_screen_link_chip',
                                                              );
                                                              final String link = widget.links![e].toString();
                                                              final String targetLink = link.contains("@gmail.com")
                                                                  ? "mailto:$link"
                                                                  : link;
                                                              final bool launched = await launchUrl(
                                                                Uri.parse(targetLink),
                                                              );
                                                              unawaited(
                                                                analytics.track(
                                                                  ExternalLinkOpenResultEvent(
                                                                    surface: AnalyticsSurfaceValue.profileScreen,
                                                                    destination: _destinationForLinkKey(e.toString()),
                                                                    result: launched
                                                                        ? EventResultValue.success
                                                                        : EventResultValue.failure,
                                                                    reason: launched
                                                                        ? null
                                                                        : AnalyticsReasonValue.error,
                                                                    sourceContext: 'profile_screen_link_chip',
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        )
                                                        .toList()
                                                        .sublist(
                                                          0,
                                                          (widget.links ?? {}).keys.toList().length > 3
                                                              ? 3
                                                              : (widget.links ?? {}).keys.toList().length,
                                                        ),
                                                    if ((widget.links ?? {}).keys.toList().length > 3)
                                                      IconButton(
                                                        padding: const EdgeInsets.all(2),
                                                        icon: Container(
                                                          padding: const EdgeInsets.all(6.0),
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: Theme.of(
                                                              context,
                                                            ).colorScheme.secondary.withValues(alpha: 0.1),
                                                          ),
                                                          child: Icon(
                                                            JamIcons.more_horizontal,
                                                            size: 20,
                                                            color: Theme.of(
                                                              context,
                                                            ).colorScheme.secondary.withValues(alpha: 0.8),
                                                          ),
                                                        ),
                                                        onPressed: () {
                                                          _trackAction(
                                                            AnalyticsActionValue.actionChipTapped,
                                                            sourceContext: 'profile_screen_more_links',
                                                          );
                                                          showNoLoadLinksPopUp(context, widget.links ?? {});
                                                        },
                                                      ),
                                                  ],
                                                ),
                                              ),
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
                                            border: Border.all(color: Theme.of(context).colorScheme.error, width: 4),
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                          child: ClipOval(
                                            child: hasUserPhoto
                                                ? CachedNetworkImage(
                                                    imageUrl: safeUserPhoto,
                                                    width: 78,
                                                    height: 78,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Container(
                                                    width: 78,
                                                    height: 78,
                                                    color: Theme.of(context).primaryColor,
                                                    alignment: Alignment.center,
                                                    child: Icon(
                                                      JamIcons.user,
                                                      color: Theme.of(context).colorScheme.error,
                                                      size: 30,
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
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
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
                      SliverAppBar(
                        backgroundColor: Theme.of(context).primaryColor,
                        automaticallyImplyLeading: false,
                        pinned: true,
                        titleSpacing: 0,
                        expandedHeight: !widget.ownProfile! || app_state.prismUser.loggedIn ? 50 : 0,
                        title: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: 57,
                          child: ColoredBox(
                            color: Theme.of(context).primaryColor,
                            child: SizedBox.expand(
                              child: TabBar(
                                indicatorColor: Theme.of(context).colorScheme.secondary,
                                indicatorSize: TabBarIndicatorSize.label,
                                unselectedLabelColor: const Color(0xFFFFFFFF).withValues(alpha: 0.5),
                                labelColor: const Color(0xFFFFFFFF),
                                tabs: [
                                  Text(
                                    "Wallpapers",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                  ),
                                  Text(
                                    "Setups",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: UserProfileLoader(email: widget.email),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: UserProfileSetupLoader(email: widget.email),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : Scaffold(
            backgroundColor: Theme.of(context).primaryColor,
            body: CustomScrollView(
              controller: controller,
              slivers: <Widget>[
                SliverAppBar(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  automaticallyImplyLeading: false,
                  expandedHeight: 280.0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Stack(
                          children: <Widget>[
                            Container(color: Theme.of(context).colorScheme.error),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                              child: Center(
                                child: SizedBox(
                                  width: MediaQuery.of(context).size.width / 2,
                                  child: const SafeRiveAsset(
                                    assetName: "assets/animations/Text.flr",
                                    animations: <String>["Untitled"],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    Padding(padding: const EdgeInsets.only(top: 10), child: PremiumList()),
                    DownloadList(),
                    const GeneralList(expanded: false),
                    const UserList(expanded: false),
                    AboutList(),
                    const SizedBox(height: 300),
                  ]),
                ),
              ],
            ),
          );
  }
}

Map<String, IconData> linksIconData = {
  'github': JamIcons.github,
  'twitter': JamIcons.twitter,
  'instagram': JamIcons.instagram,
  'email': JamIcons.inbox,
  'telegram': JamIcons.paper_plane,
  'dribbble': JamIcons.basketball,
  'linkedin': JamIcons.linkedin,
  'bio.link': JamIcons.world,
  'patreon': JamIcons.patreon,
  'trello': JamIcons.trello,
  'reddit': JamIcons.reddit,
  'behance': JamIcons.behance,
  'deviantart': JamIcons.deviantart,
  'gitlab': JamIcons.gitlab,
  'medium': JamIcons.medium,
  'paypal': JamIcons.paypal,
  'spotify': JamIcons.spotify,
  'twitch': JamIcons.twitch,
  'unsplash': JamIcons.unsplash,
  'youtube': JamIcons.youtube,
  'linktree': JamIcons.tree_alt,
  'buymeacoffee': JamIcons.coffee,
  'custom link': JamIcons.link,
};
