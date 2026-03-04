import 'dart:async';

import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/popup/changelogPopUp.dart';
import 'package:Prism/features/category_feed/category_feed.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final FirebaseMessaging f = FirebaseMessaging.instance;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  LoadStatus? _lastLoggedStatus;
  int _lastLoggedItemCount = -1;

  bool get _isOnFirstCategory => context.categorySelectedChoice(listen: false).name == categoryChoices[0].name;

  late bool isNew;

  Future<void> _ensureDefaultTopicSubscriptions() async {
    if (!_settingsLocal.get<bool>('subscribedToRecommendations', defaultValue: false)) {
      final bool recommendationsSubscribed = await subscribeToTopicSafely(
        f,
        'recommendations',
        sourceTag: 'home.init.recommendations',
      );
      final bool postsSubscribed = await subscribeToTopicSafely(f, 'posts', sourceTag: 'home.init.posts');
      if (recommendationsSubscribed && postsSubscribed) {
        _settingsLocal.set('subscribedToRecommendations', true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_ensureDefaultTopicSubscriptions());
    isNew = true;
  }

  void showChangelogCheck() {
    final lastSeen = _settingsLocal.get<Object?>("lastSeenVersion") as String?;
    if (lastSeen != currentAppVersion) {
      showChangelog(context, () {
        setState(() {
          isNew = false;
        });
      });
      _settingsLocal.set("lastSeenVersion", currentAppVersion);
    } else {
      setState(() {
        isNew = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isNew) {
      Future.delayed(Duration.zero).then((_) {
        if (!mounted) {
          return;
        }
        showChangelogCheck();
      });
    }
    return PopScope(
      canPop: _isOnFirstCategory,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.categoryChangeWallpaperFuture(categoryChoices[0], "r");
        } else {
          logger.d("Bye! Have a good day!");
        }
      },
      child: BlocBuilder<CategoryFeedBloc, CategoryFeedState>(
        builder: (context, state) {
          if (_lastLoggedStatus != state.status || _lastLoggedItemCount != state.items.length) {
            _lastLoggedStatus = state.status;
            _lastLoggedItemCount = state.items.length;
            logger.d(
              '[HomeScreen] feed state',
              fields: <String, Object?>{
                'status': state.status.name,
                'items': state.items.length,
                'hasMore': state.hasMore,
                'category': state.selectedCategory?.name,
                'provider': state.selectedCategory?.source.legacyProviderString,
              },
            );
          }
          if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
            return const LoadingCards();
          }
          if (state.status == LoadStatus.failure) {
            return RefreshIndicator(
              onRefresh: () async {
                final choice = context.categorySelectedChoice(listen: false);
                await context.categoryChangeWallpaperFuture(choice, "r");
              },
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Spacer(),
                  Center(child: Text("Can't connect to the Servers!")),
                  Spacer(),
                ],
              ),
            );
          }
          final source = state.selectedCategory?.source ?? WallpaperSource.prism;
          switch (source) {
            case WallpaperSource.wallhaven:
              return const WallHavenGrid();
            case WallpaperSource.pexels:
              return const PexelsGrid();
            case WallpaperSource.prism:
              return const WallpaperGrid();
            case WallpaperSource.wallOfTheDay:
            case WallpaperSource.downloaded:
            case WallpaperSource.unknown:
              return const WallpaperGrid();
          }
        },
      ),
    );
  }
}
