import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_grid.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class FavouriteWallpaperScreen extends StatelessWidget {
  const FavouriteWallpaperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Favourites',
      body: app_state.prismUser.loggedIn ? const FavouriteGrid() : const SignInPrompt(feature: 'favourites'),
    );
  }
}
