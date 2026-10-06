import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart';
import 'package:Prism/features/live_wallpaper/data/repositories/live_wallpaper_repository_impl.dart';
import 'package:Prism/features/live_wallpaper/views/widgets/live_wallpaper_view.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class LiveWallpaperScreen extends StatelessWidget {
  const LiveWallpaperScreen({super.key, this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LiveWallpaperBloc>(
      create: (_) =>
          LiveWallpaperBloc(const LiveWallpaperRepositoryImpl(), imageUrl: imageUrl)
            ..add(LiveWallpaperEvent.started(isPro: app_state.prismUser.premium)),
      child: LiveWallpaperView(imageUrl: imageUrl),
    );
  }
}
