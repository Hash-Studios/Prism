import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@RoutePage()
class SharePrismScreen extends StatefulWidget {
  @override
  _SharePrismScreenState createState() => _SharePrismScreenState();
}

class _SharePrismScreenState extends State<SharePrismScreen> {
  String link = "";
  bool _loading = false;
  bool _failed = false;

  bool get _signedIn => app_state.prismUser.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLink());
  }

  Future<void> _loadLink() async {
    if (!_signedIn) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final value = await createSharingPrismLink(app_state.prismUser.id);
      if (mounted) setState(() => link = value);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share() async {
    unawaited(analytics.track(const InviteShareTappedEvent(sourceContext: 'share_prism_screen')));
    if (link.isEmpty) {
      if (_signedIn) {
        unawaited(_loadLink());
        return;
      }
      unawaited(
        analytics.track(
          const InviteShareResultEvent(
            channel: ShareChannelValue.link,
            result: EventResultValue.blocked,
            reason: AnalyticsReasonValue.notSignedIn,
            sourceContext: 'share_prism_screen',
          ),
        ),
      );
      toasts.error("Sign in to get your invite link.");
      return;
    }
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
      toasts.error("Unable to share invite right now.");
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: link));
    toasts.success('Link copied');
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Invite friends',
      bottomBar: PrismButton(label: 'Share invite', expand: true, loading: _loading, onPressed: _share),
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
                  'Give ${CoinPolicy.referral}, get ${CoinPolicy.referral}',
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.display(context),
                ),
                const SizedBox(height: PrismSpace.xs),
                Text(
                  'Your friend gets ${CoinPolicy.referral} coins when they join. You get ${CoinPolicy.referral} too.',
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
          PrismIconButton(icon: Icons.copy_rounded, tooltip: 'Copy link', iconSize: 20, onPressed: onCopy),
        ],
      );
    } else if (loading) {
      content = const PrismSkeleton(
        child: SizedBox(
          height: 44,
          child: Align(alignment: Alignment.centerLeft, child: PrismBone(width: 220, height: 16)),
        ),
      );
    } else {
      content = Row(
        children: <Widget>[
          Expanded(
            child: Text(
              signedIn && failed ? 'Could not create your invite link.' : 'Sign in to get your invite link.',
              style: PrismTextStyles.body(context),
            ),
          ),
          if (signedIn)
            PrismIconButton(icon: Icons.refresh_rounded, tooltip: 'Try again', iconSize: 20, onPressed: onRetry),
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
