import 'package:Prism/features/streak/views/pages/streak_page.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class StreakTabPage extends StatelessWidget {
  const StreakTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StreakPage();
  }
}
