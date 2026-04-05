import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  final UserBlockRepository _repo = getIt<UserBlockRepository>();
  Future<List<BlockedUserListRow>>? _loadFuture;

  @override
  void initState() {
    super.initState();
    unawaited(analytics.track(const UserBlockActionEvent(action: 'open_blocked_list')));
    _loadFuture = _load();
  }

  Future<List<BlockedUserListRow>> _load() async {
    final result = await _repo.fetchBlockedUsersList();
    if (result.isFailure || result.data == null) {
      return <BlockedUserListRow>[];
    }
    return result.data!;
  }

  Future<void> _refresh() async {
    setState(() {
      _loadFuture = _load();
    });
    await _loadFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: 'Blocked accounts'),
      ),
      body: FutureBuilder<List<BlockedUserListRow>>(
        future: _loadFuture,
        builder: (BuildContext context, AsyncSnapshot<List<BlockedUserListRow>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<BlockedUserListRow> rows = snapshot.data ?? <BlockedUserListRow>[];
          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'No blocked accounts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rows.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (BuildContext context, int i) {
                final BlockedUserListRow row = rows[i];
                final String title = (row.blockedUsername != null && row.blockedUsername!.isNotEmpty)
                    ? row.blockedUsername!
                    : row.blockedEmail;
                return ListTile(
                  title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                  subtitle: Text(
                    row.blockedEmail,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final result = await _repo.unblockUser(targetUserId: row.blockedUid);
                      if (!context.mounted) {
                        return;
                      }
                      if (result.isFailure) {
                        toasts.error(result.failure?.toString() ?? 'Could not unblock');
                        unawaited(analytics.track(const UserBlockActionEvent(action: 'unblock', result: 'failure')));
                        return;
                      }
                      unawaited(analytics.track(const UserBlockActionEvent(action: 'unblock', result: 'success')));
                      toasts.codeSend('Unblocked');
                      await _refresh();
                    },
                    child: const Text('Unblock'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
