import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_blocks/user_block_actions.dart';
import 'package:Prism/l10n/l10n.dart';
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

  /// The list never shows an email address, only the username.
  static String _displayName(BuildContext context, BlockedUserListRow row) {
    final String? username = row.blockedUsername?.trim();
    return username == null || username.isEmpty ? context.l10n.accountBlockedListUserFallback : username;
  }

  Future<void> _unblock(BlockedUserListRow row, String name) async {
    final bool confirmed = await showPrismConfirm(
      context,
      title: context.l10n.accountUnblockUserTitle(name),
      message: context.l10n.accountUnblockUserMessage,
      confirmLabel: context.l10n.accountUnblock,
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
      title: context.l10n.accountBlockedAccounts,
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
                title: context.l10n.accountBlockedAccountsLoadError,
                body: context.l10n.accountCheckConnectionTryAgain,
                actionLabel: context.l10n.accountRetry,
                onAction: _refresh,
              ),
            );
          }
          final List<BlockedUserListRow> rows = result.data ?? <BlockedUserListRow>[];
          if (rows.isEmpty) {
            return _Message(
              onRefresh: _refresh,
              child: GlintState(
                kind: GlintStateKind.empty,
                title: context.l10n.accountNoBlockedAccounts,
                body: context.l10n.accountBlockedAccountsEmptyBody,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () {
              PrismHaptics.impact();
              return _refresh();
            },
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
                final String name = _displayName(context, row);
                final bool hasUsername = row.blockedUsername?.trim().isNotEmpty ?? false;
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    children: <Widget>[
                      PrismAvatar(name: name),
                      const SizedBox(width: PrismSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              hasUsername ? '@$name' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PrismTextStyles.rowTitle(context),
                            ),
                            if (row.syncStatus == 'pending' || row.syncStatus == 'rejected')
                              Text(
                                row.syncStatus == 'pending'
                                    ? context.l10n.accountWaitingToSync
                                    : context.l10n.accountNotSynced,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: PrismSpace.sm),
                      PrismButton(
                        label: context.l10n.accountUnblock,
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
      onRefresh: () {
        PrismHaptics.impact();
        return onRefresh();
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(height: constraints.maxHeight, child: child),
        ),
      ),
    );
  }
}
