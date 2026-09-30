import 'dart:io';

import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

@RoutePage()
class SetupGuidelinesScreen extends StatefulWidget {
  const SetupGuidelinesScreen();

  @override
  _SetupGuidelinesScreenState createState() => _SetupGuidelinesScreenState();
}

class _SetupGuidelinesScreenState extends State<SetupGuidelinesScreen> {
  final _picker = ImagePicker();

  Future getSetup() async {
    if (!app_state.prismUser.premium) {
      await PaywallOrchestrator.instance.present(
        placement: PaywallPlacement.blockedSetupCreate,
        source: 'setup_guidelines_blocked_create',
      );
      return;
    }
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted) {
      return;
    }
    if (pickedFile != null) {
      await context.router.replace(UploadSetupRoute(image: File(pickedFile.path)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text("Upload Setup", style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
        actions: [
          TextButton(
            onPressed: () {
              context.router.push(const DraftSetupRoute());
            },
            child: Text(
              "Drafts",
              style: TextStyle(
                color: Theme.of(context).colorScheme.error == Colors.black
                    ? Colors.white
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          if (MediaQuery.of(context).size.height <= 650)
            TextButton(
              onPressed: () => getSetup(),
              child: Text(
                "Continue",
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.normal),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const Spacer(),
          SizedBox(
            width: MediaQuery.of(context).size.width,
            child: SvgPicture.string(themedIllustration(context, dark: setupDark, light: setupLight)),
          ),
          const Spacer(),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Text(
              """
Guidelines for uploading setups -""",
              textAlign: TextAlign.left,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Text(
              """
- Keep a screenshot of your homescreen setup ready.
- After you press the continue button below, you will be prompted to select this screenshot.
- Keep the name of wallpaper app / wallpaper link ready.
- You’ll also need a name, and description for the setup.
- Make sure you have connected your account to Twitter or Instagram, so that your audience on Prism can follow you there.""",
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.height > 650
          ? Padding(
              padding: const EdgeInsets.only(bottom: 50.0),
              child: FloatingActionButton.extended(
                backgroundColor: Theme.of(context).colorScheme.error,
                onPressed: () => getSetup(),
                label: Text(
                  "Continue",
                  style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.normal),
                ),
                icon: Icon(JamIcons.arrow_right, color: Theme.of(context).colorScheme.secondary),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
