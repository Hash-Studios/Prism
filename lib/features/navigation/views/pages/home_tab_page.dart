import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/changelogPopUp.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:quick_actions/quick_actions.dart';

@RoutePage()
class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  final FavoritesLocalDataSource _favoritesLocal = getIt<FavoritesLocalDataSource>();
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  late final InAppNotificationsBloc _notificationsBloc;
  int page = 0;
  bool result = true;
  String shortcut = "No Action Set";
  bool _hasHandledQuickActionInvocation = false;
  bool _isChangelogCheckPending = true;
  int _personalizedFeedVersion = 0;

  @override
  void dispose() {
    _notificationsBloc.close();
    super.dispose();
  }

  Future<void> _ensureDefaultTopicSubscriptions() async {
    if (!_settingsLocal.get<bool>('subscribedToRecommendations', defaultValue: false)) {
      final messaging = FirebaseMessaging.instance;
      final bool recommendationsSubscribed = await subscribeToTopicSafely(
        messaging,
        'recommendations',
        sourceTag: 'home_tab.init.recommendations',
      );
      final bool postsSubscribed = await subscribeToTopicSafely(messaging, 'posts', sourceTag: 'home_tab.init.posts');
      if (recommendationsSubscribed && postsSubscribed) {
        _settingsLocal.set('subscribedToRecommendations', true);
      }
    }
  }

  void _showChangelogCheck() {
    final String? lastSeen = _settingsLocal.get<Object?>('lastSeenVersion') as String?;
    if (lastSeen != currentAppVersion) {
      showChangelog(context, () {
        if (mounted) {
          setState(() {
            _isChangelogCheckPending = false;
          });
        }
      });
      _settingsLocal.set('lastSeenVersion', currentAppVersion);
      return;
    }
    setState(() {
      _isChangelogCheckPending = false;
    });
  }

  void _trackQuickActionInvocation(String shortcutType) {
    final AnalyticsActionValue action;
    switch (shortcutType) {
      case 'Personalized_Feed':
        action = AnalyticsActionValue.quickActionFollowFeed;
      case 'Collections':
        action = AnalyticsActionValue.quickActionCollections;
      case 'AI_Wallpapers':
        action = AnalyticsActionValue.quickActionAiWallpapers;
      case 'Downloads':
        action = AnalyticsActionValue.quickActionDownloads;
      default:
        action = AnalyticsActionValue.quickActionUnknown;
    }
    analytics.track(
      QuickActionInvokedEvent(
        action: action,
        launchState: _hasHandledQuickActionInvocation ? LaunchStateValue.foreground : LaunchStateValue.initialLaunch,
      ),
    );
    _hasHandledQuickActionInvocation = true;
  }

  Future<void> checkConnection() async {
    result = await InternetConnectionChecker.instance.hasConnection;
    if (result) {
      logger.d("Internet working as expected!");
      setState(() {});
    } else {
      logger.d("Not connected to Internet!");
      setState(() {});
    }
  }

  Future<void> saveFavToLocal() async {
    if (app_state.prismUser.loggedIn) {
      final String userId = app_state.prismUser.id;
      if (_favoritesLocal.isSeeded(userId)) {
        return;
      }
      final value = await context.favouriteWallsAdapter(listen: false).getDataBase();
      if (value != null && value.isNotEmpty) {
        for (final element in value) {
          await _favoritesLocal.setWallFavourite(userId, element.id, true);
        }
      }
      await _favoritesLocal.setSeeded(userId, true);
    }
  }

  @override
  void initState() {
    super.initState();
    _notificationsBloc = getIt<InAppNotificationsBloc>()..add(const InAppNotificationsEvent.started(syncRemote: false));
    context.read<AdsBloc>().add(const AdsEvent.started());
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      _trackQuickActionInvocation(shortcutType);
      setState(() {
        shortcut = shortcutType;
      });
      if (shortcutType == 'Downloads') {
        logger.d('Downloads');
        context.router.push(const DownloadRoute());
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'Personalized_Feed', localizedTitle: 'For You', icon: '@drawable/ic_feed'),
      const ShortcutItem(type: 'Collections', localizedTitle: 'Collections', icon: '@drawable/ic_collections'),
      const ShortcutItem(type: 'Downloads', localizedTitle: 'Downloads', icon: '@drawable/ic_downloads'),
    ]);
    saveFavToLocal();
    checkConnection();
    unawaited(_ensureDefaultTopicSubscriptions());
  }

  @override
  Widget build(BuildContext context) {
    if (_isChangelogCheckPending) {
      Future<void>.delayed(Duration.zero).then((_) {
        if (!mounted) {
          return;
        }
        _showChangelogCheck();
      });
    }

    return BlocProvider<InAppNotificationsBloc>.value(
      value: _notificationsBloc,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: _HomeAppBar(onLogoTap: _openFeedSettingsSheet),
        body: Stack(
          children: <Widget>[
            PersonalizedFeedScreen(key: ValueKey<int>(_personalizedFeedVersion)),
            if (!result) ConnectivityWidget() else Container(),
          ],
        ),
      ),
    );
  }

  Future<void> _openFeedSettingsSheet() async {
    final catalog = await PersonalizedInterestsCatalog.load(
      remoteConfig: FirebaseRemoteConfig.instance,
      settingsLocal: _settingsLocal,
    );
    if (catalog.isEmpty || !mounted) return;

    final selected = PersonalizedInterestsCatalog.selectedFromLocal(_settingsLocal).toSet();
    if (selected.isEmpty) selected.addAll(PersonalizedInterestsCatalog.defaultSelection(catalog));
    final currentMix = _settingsLocal.get<String>(personalizedFeedMixLocalKey, defaultValue: 'balanced');

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FeedSettingsSheet(
        catalog: catalog,
        initialInterests: selected,
        initialFeedMix: currentMix,
        onSave: (interests, feedMix) async {
          final persisted = await _persistInterests(interests);
          if (!persisted) return;
          await _settingsLocal.set(personalizedFeedMixLocalKey, feedMix);
          if (mounted) setState(() => _personalizedFeedVersion += 1);
        },
      ),
    );
  }

  Future<bool> _persistInterests(List<String> interests) async {
    await _settingsLocal.set('onboarding_v2_interests', interests.join(','));
    if (!app_state.prismUser.loggedIn) {
      return true;
    }
    final saveInterests = getIt<SaveInterestsUseCase>();
    final saveResult = await saveInterests(SaveInterestsParams(interests: interests));
    return saveResult.isSuccess;
  }
}

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.onLogoTap});

  final VoidCallback onLogoTap;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).primaryColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                // Notification button
                BlocBuilder<InAppNotificationsBloc, InAppNotificationsState>(
                  builder: (context, state) => _NotificationButton(hasUnread: state.unreadCount > 0),
                ),
                // Centered logo
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: onLogoTap,
                      behavior: HitTestBehavior.opaque,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PrismLogo(),
                          SizedBox(width: 4),
                          Text(
                            'prism',
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                              fontVariations: [FontVariation('WONK', 1)],
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.expand_more_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                // Profile avatar
                _ProfileAvatar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrismLogo extends StatelessWidget {
  const _PrismLogo();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      prismVector,
      width: 10,
      height: 12,
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({this.hasUnread = false});

  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.router.push(const NotificationRoute()),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          children: [
            // Bell icon with inner shadow approximation
            const Positioned(left: 12, top: 12, child: Icon(JamIcons.bell_f, color: Color(0xFFDEDEDE), size: 16)),
            // Pink nudge dot
            if (hasUnread)
              Positioned(
                top: 11,
                left: 22,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF69A9),
                    boxShadow: [BoxShadow(color: Color(0x80E57697), blurRadius: 4, spreadRadius: 1)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final photoUrl = app_state.prismUser.profilePhoto;
    return GestureDetector(
      onTap: () => context.router.push(ProfileRoute(profileIdentifier: app_state.prismUser.email)),
      child: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(8),
        child: ClipOval(
          child: CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _FeedSettingsSheet extends StatefulWidget {
  const _FeedSettingsSheet({
    required this.catalog,
    required this.initialInterests,
    required this.initialFeedMix,
    required this.onSave,
  });

  final List<PersonalizedInterest> catalog;
  final Set<String> initialInterests;
  final String initialFeedMix;
  final Future<void> Function(List<String> interests, String feedMix) onSave;

  @override
  State<_FeedSettingsSheet> createState() => _FeedSettingsSheetState();
}

class _FeedSettingsSheetState extends State<_FeedSettingsSheet> {
  late Set<String> _selectedInterests;
  late String _feedMix;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedInterests = {...widget.initialInterests};
    _feedMix = widget.initialFeedMix;
  }

  bool get _canSave => !_saving && _selectedInterests.length >= OnboardingV2Config.minInterests;

  void _resetToDefaults() {
    final defaults = PersonalizedInterestsCatalog.defaultSelection(widget.catalog);
    setState(() {
      _selectedInterests = defaults.toSet();
      _feedMix = 'balanced';
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    await widget.onSave(_selectedInterests.toList(growable: false), _feedMix);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = _selectedInterests.length;
    final belowMin = count < OnboardingV2Config.minInterests;
    final keyboardPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const _DragHandle(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Your feed', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$count selected', style: tt.bodySmall?.copyWith(color: belowMin ? cs.error : cs.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 4),
          child: Text('Interests', style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in widget.catalog)
                  FilterChip(
                    label: Text(entry.name),
                    selected: _selectedInterests.contains(entry.name),
                    avatar: CircleAvatar(backgroundImage: CachedNetworkImageProvider(entry.imageUrl)),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedInterests.add(entry.name);
                        } else {
                          _selectedInterests.remove(entry.name);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 4),
          child: Text('Feed mix', style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
          child: _FeedMixSelector(value: _feedMix, onChanged: (v) => setState(() => _feedMix = v)),
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              TextButton(onPressed: _saving ? null : _resetToDefaults, child: const Text('Reset to defaults')),
              const Spacer(),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ),
        SizedBox(height: keyboardPadding + 8),
      ],
    );
  }
}

class _FeedMixSelector extends StatelessWidget {
  const _FeedMixSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'balanced', label: Text('Balanced')),
        ButtonSegment(value: 'creators', label: Text('Creators')),
        ButtonSegment(value: 'discovery', label: Text('Discovery')),
      ],
      selected: {value},
      onSelectionChanged: (Set<String> s) {
        if (s.isNotEmpty) onChanged(s.first);
      },
      expandedInsets: EdgeInsets.zero,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? cs.primary : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? cs.onPrimary : cs.onSurface,
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 4,
        width: 32,
        decoration: BoxDecoration(color: Theme.of(context).hintColor, borderRadius: BorderRadius.circular(99)),
      ),
    );
  }
}
