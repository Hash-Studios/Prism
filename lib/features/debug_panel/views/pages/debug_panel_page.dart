import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/debug_panel/views/pages/app_info_page.dart';
import 'package:Prism/features/debug_panel/views/pages/debug_tools_page.dart';
import 'package:Prism/features/debug_panel/views/pages/log_viewer_page.dart';
import 'package:Prism/features/debug_panel/views/pages/mascot_gallery_page.dart';
import 'package:Prism/features/debug_panel/views/pages/storage_viewer_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DebugPanelPage extends StatelessWidget {
  const DebugPanelPage({super.key, @QueryParam('tab') this.tab = 'logs'});

  final String tab;

  static const List<String> tabs = <String>['logs', 'tools', 'storage', 'app-info', 'mascot'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      initialIndex: tabs.contains(tab) ? tabs.indexOf(tab) : 0,
      child: PrismPage(
        title: context.l10n.debugTitle,
        headerBottom: Padding(
          padding: EdgeInsets.symmetric(horizontal: PrismSpace.xs),
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Tab>[
              Tab(text: context.l10n.debugLogs),
              Tab(text: context.l10n.debugTools),
              Tab(text: context.l10n.debugStorage),
              Tab(text: context.l10n.debugAppInfo),
              Tab(text: context.l10n.debugMascot),
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
