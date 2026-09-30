import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class SharePrismScreen extends StatefulWidget {
  @override
  _SharePrismScreenState createState() => _SharePrismScreenState();
}

class _SharePrismScreenState extends State<SharePrismScreen> {
  String link = "";

  @override
  void initState() {
    super.initState();
    unawaited(_loadLink());
  }

  Future<void> _loadLink() async {
    if (app_state.prismUser.id.isEmpty) return;
    final value = await createSharingPrismLink(app_state.prismUser.id);
    if (mounted) setState(() => link = value);
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
            MaterialButton(
              disabledColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
              shape: const StadiumBorder(),
              color: link.isEmpty
                  ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.error,
              onPressed: link.isEmpty
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
              child: const Text('SHARE INVITE', style: TextStyle(fontSize: 16.0, color: Colors.white)),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}
