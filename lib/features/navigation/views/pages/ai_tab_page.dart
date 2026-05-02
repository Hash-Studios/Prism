import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class AiTabPage extends StatelessWidget {
  const AiTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AiWallpaperTabPage();
  }
}
