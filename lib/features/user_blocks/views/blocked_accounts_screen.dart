import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_blocks/user_block_actions.dart';
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
  late Future<Result<List<BlockedUserListRow>>> _loadFuture;

  @override
  void initState() {
    super.initState();
    unawaited(analytics.track(const UserBlockActionEvent(action: 'open_blocked_list')));
    _loadFuture = _repo.fetchBlockedUsersList();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadFuture = _repo.fetchBlockedUsersList();
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
      body: FutureBuilder<Result<List<BlockedUserListRow>>>(
        future: _loadFuture,
        builder: (BuildContext context, AsyncSnapshot<Result<List<BlockedUserListRow>>> snapshot) {
          final Result<List<BlockedUserListRow>>? result = snapshot.data;
          if (result == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (result.isFailure) {
            return _Message(
              text: 'Could not load blocked accounts.',
              onRefresh: _refresh,
              action: TextButton(onPressed: _refresh, child: const Text('Retry')),
            );
          }
          final List<BlockedUserListRow> rows = result.data ?? <BlockedUserListRow>[];
          if (rows.isEmpty) {
            return _Message(text: 'No blocked accounts.', onRefresh: _refresh);
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
                      if (await unblockUserWithFeedback(context, row.blockedUid)) {
                        await _refresh();
                      }
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

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onRefresh, this.action});

  final String text;
  final Future<void> Function() onRefresh;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8), fontSize: 15),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
