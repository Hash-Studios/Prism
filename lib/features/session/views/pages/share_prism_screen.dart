import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/global/globals.dart' as globals;
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
    getLink();
  }

  Future<void> getLink() async {
    if (globals.prismUser.id == "") {
    } else {
      await createSharingPrismLink(globals.prismUser.id).then(
        (value) => setState(() {
          link = value;
        }),
      );
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
            //TODO Replace the animation with Share animation
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
                "Get 100 coins when your friend signs up from the link!",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: Text(
                "They also get 100 coins for joining Prism.",
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
              color: link == ""
                  ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.error,
              onPressed: link == ""
                  ? () {
                      toasts.error("Sign in to generate unique referral link!");
                    }
                  : () async {
                      await ShareService.shareText(text: link, context: context);
                    },
              child: const Text('SHARE INVITE', style: TextStyle(fontSize: 16.0, color: Colors.white)),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
