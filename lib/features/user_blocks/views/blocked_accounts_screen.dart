import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
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
  final Set<String> _unblocking = <String>{};

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

  Future<void> _unblock(BlockedUserListRow row, String name) async {
    final bool confirmed = await showPrismConfirm(
      context,
      title: 'Unblock $name?',
      message: 'They will be able to see your profile and wallpapers again.',
      confirmLabel: 'Unblock',
    );
    if (!confirmed || !mounted) return;
    setState(() => _unblocking.add(row.blockedUid));
    final bool done = await unblockUserWithFeedback(context, row.blockedUid);
    if (!mounted) return;
    if (done) await _refresh();
    if (mounted) setState(() => _unblocking.remove(row.blockedUid));
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Blocked accounts',
      body: FutureBuilder<Result<List<BlockedUserListRow>>>(
        future: _loadFuture,
        builder: (BuildContext context, AsyncSnapshot<Result<List<BlockedUserListRow>>> snapshot) {
          final Result<List<BlockedUserListRow>>? result = snapshot.data;
          if (result == null) {
            return PrismSkeleton.rows();
          }
          if (result.isFailure) {
            return _Message(
              onRefresh: _refresh,
              child: GlintState(
                kind: GlintStateKind.error,
                title: 'Could not load blocked accounts',
                body: 'Check your connection and try again.',
                actionLabel: 'Retry',
                onAction: _refresh,
              ),
            );
          }
          final List<BlockedUserListRow> rows = result.data ?? <BlockedUserListRow>[];
          if (rows.isEmpty) {
            return _Message(
              onRefresh: _refresh,
              child: const GlintState(
                kind: GlintStateKind.empty,
                title: 'No blocked accounts',
                body: 'People you block cannot see your profile or wallpapers.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                PrismSpace.page,
                PrismSpace.xs,
                PrismSpace.page,
                PrismSpace.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: rows.length,
              separatorBuilder: (BuildContext context, int index) => const SizedBox(height: PrismSpace.xxs),
              itemBuilder: (BuildContext context, int i) {
                final BlockedUserListRow row = rows[i];
                final bool hasUsername = row.blockedUsername != null && row.blockedUsername!.isNotEmpty;
                final String name = hasUsername ? row.blockedUsername! : row.blockedEmail;
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    children: <Widget>[
                      PrismAvatar(name: name),
                      const SizedBox(width: PrismSpace.sm),
                      Expanded(
                        child: Text(
                          hasUsername ? '@$name' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PrismTextStyles.rowTitle(context),
                        ),
                      ),
                      const SizedBox(width: PrismSpace.sm),
                      PrismButton(
                        label: 'Unblock',
                        variant: PrismButtonVariant.tonal,
                        size: PrismButtonSize.compact,
                        loading: _unblocking.contains(row.blockedUid),
                        onPressed: () => unawaited(_unblock(row, name)),
                      ),
                    ],
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

/// Puts a centred state in a list that still supports pull to refresh.
class _Message extends StatelessWidget {
  const _Message({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: constraints.maxHeight, child: child),
        ),
      ),
    );
  }
}
