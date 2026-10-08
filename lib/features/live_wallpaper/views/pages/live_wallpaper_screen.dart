import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/live_wallpaper/biz/bloc/live_wallpaper_bloc.j.dart';
import 'package:Prism/features/live_wallpaper/domain/repositories/live_wallpaper_repository.dart';
import 'package:Prism/features/live_wallpaper/views/widgets/live_wallpaper_view.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class LiveWallpaperScreen extends StatelessWidget {
  const LiveWallpaperScreen({super.key, this.imageUrl, this.accentSeed});

  final String? imageUrl;

  /// The dominant colour of the wallpaper the user came from. The gradients start from it.
  final Color? accentSeed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LiveWallpaperBloc>(
      create: (_) =>
          LiveWallpaperBloc(getIt<LiveWallpaperRepository>(), imageUrl: imageUrl)
            ..add(LiveWallpaperEvent.started(isPro: app_state.prismUser.premium)),
      child: LiveWallpaperView(imageUrl: imageUrl, accentSeed: accentSeed),
    );
  }
}
