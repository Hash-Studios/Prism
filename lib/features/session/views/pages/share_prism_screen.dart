import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@RoutePage()
class SharePrismScreen extends StatefulWidget {
  /// A static seam, not a constructor argument, so `const SharePrismRoute()` stays valid.
  @visibleForTesting
  static Future<String> Function(String userId)? createLinkForTesting;

  @override
  _SharePrismScreenState createState() => _SharePrismScreenState();
}

class _SharePrismScreenState extends State<SharePrismScreen> {
  String link = "";
  String? _linkOwner;
  bool _loading = false;
  bool _failed = false;
  bool _startedInitialLinkLoad = false;

  bool get _signedIn => app_state.prismUser.loggedIn && app_state.prismUser.id.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedInitialLinkLoad) return;
    _startedInitialLinkLoad = true;
    unawaited(_loadLink());
  }

  Future<void> _loadLink() async {
    if (!_signedIn) return;
    final String owner = app_state.prismUser.id;
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final value =
          await (SharePrismScreen.createLinkForTesting?.call(app_state.prismUser.id) ??
              createSharingPrismLink(
                app_state.prismUser.id,
                inviterName: app_state.prismUser.name,
                inviterPhoto: app_state.prismUser.profilePhoto,
                l10n: l10n,
              ));
      if (mounted && _signedIn && app_state.prismUser.id == owner) {
        setState(() {
          link = value;
          _linkOwner = owner;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    final AppLocalizations l10n = context.l10n;
    unawaited(analytics.track(const InviteShareTappedEvent(sourceContext: 'share_prism_screen')));
    if (!await _authorizeLink()) return;
    try {
      await ShareService.shareText(text: link, context: context);
      unawaited(
        analytics.track(
          const InviteShareResultEvent(
            channel: ShareChannelValue.shareSheet,
            result: EventResultValue.success,
            sourceContext: 'share_prism_screen',
          ),
        ),
      );
    } catch (_) {
      unawaited(
        analytics.track(
          const InviteShareResultEvent(
            channel: ShareChannelValue.shareSheet,
            result: EventResultValue.failure,
            reason: AnalyticsReasonValue.error,
            sourceContext: 'share_prism_screen',
          ),
        ),
      );
      toasts.error(l10n.accountInviteShareFailed);
    }
  }

  Future<void> _copy() async {
    if (!await _authorizeLink()) return;
    final AppLocalizations l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: link));
    toasts.success(l10n.accountLinkCopied);
  }

  Future<bool> _authorizeLink() async {
    if (!await requireSignedInAction(context) || !mounted) return false;
    if (_linkOwner != app_state.prismUser.id) await _loadLink();
    return mounted && _signedIn && _linkOwner == app_state.prismUser.id && link.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: context.l10n.accountInviteFriends,
      bottomBar: PrismButton(
        label: context.l10n.accountShareInvite,
        expand: true,
        loading: _loading,
        onPressed: _share,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Glint(mood: GlintMood.happy, size: 120),
                const SizedBox(height: PrismSpace.lg),
                Text(
                  context.l10n.accountInviteRewardHeadline(CoinPolicy.referral),
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.display(context),
                ),
                const SizedBox(height: PrismSpace.xs),
                Text(
                  context.l10n.accountInviteRewardMessage(CoinPolicy.referral),
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.body(context).copyWith(height: 1.4),
                ),
                const SizedBox(height: PrismSpace.xl),
                _LinkCard(
                  link: link,
                  loading: _loading,
                  failed: _failed,
                  signedIn: _signedIn,
                  onCopy: () => unawaited(_copy()),
                  onRetry: () => unawaited(_loadLink()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The invite link on one line with a copy button. It also stands in for the loading, failed and signed out cases.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.link,
    required this.loading,
    required this.failed,
    required this.signedIn,
    required this.onCopy,
    required this.onRetry,
  });

  final String link;
  final bool loading;
  final bool failed;
  final bool signedIn;
  final VoidCallback onCopy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (link.isNotEmpty) {
      content = Row(
        children: <Widget>[
          Expanded(
            child: Text(
              link,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          PrismIconButton(
            icon: Icons.copy_rounded,
            tooltip: context.l10n.accountCopyLink,
            iconSize: 20,
            onPressed: onCopy,
          ),
        ],
      );
    } else if (loading) {
      content = const PrismSkeleton(
        child: SizedBox(
          height: 44,
          child: Align(alignment: AlignmentDirectional.centerStart, child: PrismBone(width: 220, height: 16)),
        ),
      );
    } else {
      content = Row(
        children: <Widget>[
          Expanded(
            child: Text(
              signedIn && failed
                  ? context.l10n.accountInviteLinkCouldNotCreate
                  : context.l10n.accountSignInForInviteLink,
              style: PrismTextStyles.body(context),
            ),
          ),
          if (signedIn)
            PrismIconButton(
              icon: Icons.refresh_rounded,
              tooltip: context.l10n.accountTryAgain,
              iconSize: 20,
              onPressed: onRetry,
            ),
        ],
      );
    }
    return PrismCard(
      padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.xxs, PrismSpace.xxs, PrismSpace.xxs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(child: content),
      ),
    );
  }
}
