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
import 'package:Prism/features/category_feed/views/pages/collection_screen.dart';
import 'package:Prism/features/category_feed/views/widgets/categories_bar.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/personalized_feed/views/pages/personalized_feed_screen.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:quick_actions/quick_actions.dart';

TabController? tabController;

@RoutePage()
class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> with SingleTickerProviderStateMixin {
  final FavoritesLocalDataSource _favoritesLocal = getIt<FavoritesLocalDataSource>();
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  int page = 0;
  bool result = true;
  String shortcut = "No Action Set";
  bool _hasHandledQuickActionInvocation = false;
  bool _isChangelogCheckPending = true;
  int _personalizedFeedVersion = 0;

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
      case 'Setups':
        action = AnalyticsActionValue.quickActionSetups;
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
    tabController = TabController(length: 2, vsync: this);
    context.read<AdsBloc>().add(const AdsEvent.started());
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      _trackQuickActionInvocation(shortcutType);
      setState(() {
        shortcut = shortcutType;
      });
      if (shortcutType == 'Personalized_Feed') {
        logger.d('Personalized_Feed');
        tabController!.animateTo(0);
      } else if (shortcutType == 'Collections') {
        logger.d('Collections');
        tabController!.animateTo(1);
      } else if (shortcutType == 'Setups') {
        logger.d('Setups');
        final tabsRouter = AutoTabsRouter.of(context);
        tabsRouter.setActiveIndex(2);
      } else if (shortcutType == 'Downloads') {
        logger.d('Downloads');
        context.router.push(const DownloadRoute());
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'Personalized_Feed', localizedTitle: 'For You', icon: '@drawable/ic_feed'),
      const ShortcutItem(type: 'Collections', localizedTitle: 'Collections', icon: '@drawable/ic_collections'),
      const ShortcutItem(type: 'Setups', localizedTitle: 'Setups', icon: '@drawable/ic_setups'),
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

    return PopScope(
      canPop: tabController?.index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (tabController?.index != 0) {
          tabController?.animateTo(0);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: const PreferredSize(preferredSize: Size(double.infinity, 55), child: CategoriesBar()),
          bottom: TabBar(
            controller: tabController,
            indicatorColor: Theme.of(context).colorScheme.secondary,
            indicatorSize: TabBarIndicatorSize.label,
            onTap: (index) {
              if (index == 0 && tabController?.index == 0 && !(tabController?.indexIsChanging ?? false)) {
                unawaited(_openForYouMenu());
              }
            },
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(JamIcons.users, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 3),
                    Icon(
                      JamIcons.chevron_down,
                      size: 14,
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
              Tab(icon: Icon(JamIcons.pictures, color: Theme.of(context).colorScheme.secondary)),
            ],
          ),
        ),
        body: Stack(
          children: <Widget>[
            TabBarView(
              controller: tabController,
              children: <Widget>[
                PersonalizedFeedScreen(key: ValueKey<int>(_personalizedFeedVersion)),
                const CollectionScreen(),
              ],
            ),
            if (!result) ConnectivityWidget() else Container(),
          ],
        ),
      ),
    );
  }

  Future<void> _openForYouMenu() async {
    final action = await showModalBottomSheet<_ForYouMenuAction>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Edit interests'),
                onTap: () => Navigator.pop(context, _ForYouMenuAction.editInterests),
              ),
              ListTile(
                leading: const Icon(JamIcons.filter),
                title: const Text('Feed mix'),
                onTap: () => Navigator.pop(context, _ForYouMenuAction.feedMix),
              ),
              ListTile(
                leading: const Icon(JamIcons.backward),
                title: const Text('Reset personalization'),
                onTap: () => Navigator.pop(context, _ForYouMenuAction.reset),
              ),
            ],
          ),
        );
      },
    );

    switch (action) {
      case _ForYouMenuAction.editInterests:
        await _openEditInterestsSheet();
      case _ForYouMenuAction.feedMix:
        await _openFeedMixSheet();
      case _ForYouMenuAction.reset:
        await _resetPersonalization();
      case null:
        return;
    }
  }

  Future<void> _openEditInterestsSheet() async {
    final catalog = await PersonalizedInterestsCatalog.load(
      remoteConfig: FirebaseRemoteConfig.instance,
      settingsLocal: _settingsLocal,
    );
    if (catalog.isEmpty) {
      return;
    }
    final selected = PersonalizedInterestsCatalog.selectedFromLocal(_settingsLocal).toSet();
    if (selected.isEmpty) {
      selected.addAll(PersonalizedInterestsCatalog.defaultSelection(catalog));
    }
    if (!mounted) {
      return;
    }

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final temp = {...selected};
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Text('Your interests', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in catalog)
                              FilterChip(
                                label: Text(entry.name),
                                selected: temp.contains(entry.name),
                                avatar: CircleAvatar(backgroundImage: NetworkImage(entry.imageUrl)),
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      temp.add(entry.name);
                                    } else {
                                      temp.remove(entry.name);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: temp.length < 3
                              ? null
                              : () => Navigator.pop(context, temp.toList(growable: false)),
                          child: const Text('Save interests'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty || !mounted) {
      return;
    }

    final persisted = await _persistInterests(result);
    if (!persisted) {
      return;
    }
    setState(() {
      _personalizedFeedVersion += 1;
    });
  }

  Future<void> _openFeedMixSheet() async {
    final current = _settingsLocal.get<String>(personalizedFeedMixLocalKey, defaultValue: 'balanced');
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'balanced',
                groupValue: current,
                title: const Text('Balanced'),
                subtitle: const Text('Creators + discovery in equal balance'),
                onChanged: (value) => Navigator.pop(context, value),
              ),
              RadioListTile<String>(
                value: 'creators',
                groupValue: current,
                title: const Text('More creators'),
                subtitle: const Text('Prefer people you follow and Prism walls'),
                onChanged: (value) => Navigator.pop(context, value),
              ),
              RadioListTile<String>(
                value: 'discovery',
                groupValue: current,
                title: const Text('More discovery'),
                subtitle: const Text('Prefer Wallhaven and Pexels exploration'),
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == current) {
      return;
    }
    await _settingsLocal.set(personalizedFeedMixLocalKey, selected);
    setState(() {
      _personalizedFeedVersion += 1;
    });
  }

  Future<void> _resetPersonalization() async {
    final catalog = await PersonalizedInterestsCatalog.load(
      remoteConfig: FirebaseRemoteConfig.instance,
      settingsLocal: _settingsLocal,
    );
    final defaults = PersonalizedInterestsCatalog.defaultSelection(catalog);
    final persisted = await _persistInterests(defaults);
    if (!persisted) {
      return;
    }
    await _settingsLocal.set(personalizedFeedMixLocalKey, 'balanced');
    setState(() {
      _personalizedFeedVersion += 1;
    });
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

enum _ForYouMenuAction { editInterests, feedMix, reset }
