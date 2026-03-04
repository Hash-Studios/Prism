import 'package:Prism/features/debug_panel/views/pages/app_info_page.dart';
import 'package:Prism/features/debug_panel/views/pages/debug_tools_page.dart';
import 'package:Prism/features/debug_panel/views/pages/log_viewer_page.dart';
import 'package:Prism/features/debug_panel/views/pages/network_log_page.dart';
import 'package:Prism/features/debug_panel/views/pages/storage_viewer_page.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DebugPanelPage extends StatelessWidget {
  const DebugPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          title: Row(
            children: [
              const Icon(Icons.bug_report, size: 20),
              const SizedBox(width: 8),
              Text(
                'Debug Panel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: Theme.of(context).colorScheme.secondary,
            labelColor: Theme.of(context).colorScheme.secondary,
            unselectedLabelColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Logs'),
              Tab(icon: Icon(Icons.wifi, size: 18), text: 'Network'),
              Tab(icon: Icon(Icons.build, size: 18), text: 'Tools'),
              Tab(icon: Icon(Icons.storage, size: 18), text: 'Storage'),
              Tab(icon: Icon(Icons.info_outline, size: 18), text: 'App Info'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [LogViewerPage(), NetworkLogPage(), DebugToolsPage(), StorageViewerPage(), AppInfoPage()],
        ),
      ),
    );
  }
}
