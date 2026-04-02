import 'dart:async';

import 'package:Prism/features/category_feed/views/pages/collection_screen.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/navigation/views/widgets/prism_top_app_bar.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class CollectionTabPage extends StatelessWidget {
  const CollectionTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: PrismTopAppBar(
        onLogoTap: () =>
            unawaited(openPersonalizedFeedSettingsBottomSheet(context)),
      ),
      body: const CollectionScreen(),
    );
  }
}
