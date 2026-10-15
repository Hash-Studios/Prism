import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

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
      final value =
          await (SharePrismScreen.createLinkForTesting?.call(app_state.prismUser.id) ??
              createSharingPrismLink(
                app_state.prismUser.id,
                inviterName: app_state.prismUser.name,
                inviterPhoto: app_state.prismUser.profilePhoto,
              ));
      if (mounted) setState(() => link = value);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Share", style: Theme.of(context).textTheme.displaySmall)),
      backgroundColor: Theme.of(context).primaryColor,
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width / 2,
                  height: 70,
                  child: Icon(JamIcons.share, size: 46, color: Theme.of(context).colorScheme.secondary),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width / 2,
                  height: 70,
                  child: Icon(JamIcons.link, size: 46, color: Theme.of(context).colorScheme.secondary),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Share Prism with friends",
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(fontSize: 18, color: Theme.of(context).colorScheme.secondary),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: Text(
                "Get ${CoinPolicy.referral} coins when your friend signs up from the link!",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: Text(
                "They also get ${CoinPolicy.referral} coins for joining Prism.",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: 10),
            if (_failed) ...[
              Text(
                "Couldn't create the link.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadLink, child: const Text('Try again')),
            ] else
              MaterialButton(
                disabledColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                shape: const StadiumBorder(),
                color: link.isEmpty
                    ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.error,
                onPressed: _loading
                    ? null
                    : link.isEmpty
                    ? () {
                        unawaited(analytics.track(const InviteShareTappedEvent(sourceContext: 'share_prism_screen')));
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
                        toasts.error("Sign in to generate unique referral link!");
                      }
                    : () async {
                        PrismHaptics.tap();
                        unawaited(analytics.track(const InviteShareTappedEvent(sourceContext: 'share_prism_screen')));
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
                      },
                child: Text(
                  _loading ? 'Creating link…' : 'Share invite',
                  style: TextStyle(fontSize: 16.0, color: Theme.of(context).colorScheme.onError),
                ),
              ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}
