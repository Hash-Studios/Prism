import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/debug_panel/views/pages/app_info_page.dart';
import 'package:Prism/features/debug_panel/views/pages/debug_tools_page.dart';
import 'package:Prism/features/debug_panel/views/pages/log_viewer_page.dart';
import 'package:Prism/features/debug_panel/views/pages/mascot_gallery_page.dart';
import 'package:Prism/features/debug_panel/views/pages/storage_viewer_page.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DebugPanelPage extends StatelessWidget {
  const DebugPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 5,
      child: PrismPage(
        title: 'Debug',
        headerBottom: Padding(
          padding: EdgeInsets.symmetric(horizontal: PrismSpace.xs),
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Tab>[
              Tab(text: 'Logs'),
              Tab(text: 'Tools'),
              Tab(text: 'Storage'),
              Tab(text: 'App info'),
              Tab(text: 'Mascot'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            LogViewerPage(),
            DebugToolsPage(),
            StorageViewerPage(),
            AppInfoPage(),
            MascotGalleryPage(),
          ],
        ),
      ),
    );
  }
}
