import 'dart:io';

import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/svgAssets.dart';
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
  final picker2 = ImagePicker();

  Future getSetup() async {
    if (!app_state.prismUser.premium) {
      await PaywallOrchestrator.instance.present(
        context,
        placement: PaywallPlacement.blockedSetupCreate,
        source: 'setup_guidelines_blocked_create',
      );
      return;
    }
    final StackRouter router = context.router;
    final pickedFile = await picker2.pickImage(source: ImageSource.gallery);
    if (!mounted) {
      return;
    }
    if (pickedFile != null) {
      Navigator.pop(context);
      Future<void>.delayed(Duration.zero).then((_) => router.push(UploadSetupRoute(image: File(pickedFile.path))));
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
          if (MediaQuery.of(context).size.height > 650)
            Container()
          else
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
            child: context.prismModeStyleForContext() == "Dark"
                ? SvgPicture.string(
                    setupDark
                        .replaceAll("181818", Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2))
                        .replaceAll(
                          "E57697",
                          Theme.of(
                            context,
                          ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                        )
                        .replaceAll(
                          "F0F0F0",
                          Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                        )
                        .replaceAll(
                          "2F2E41",
                          Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                        )
                        .replaceAll(
                          "3F3D56",
                          Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                        )
                        .replaceAll("2F2F2F", Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2)),
                  )
                : SvgPicture.string(
                    setupLight
                        .replaceAll("181818", Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2))
                        .replaceAll(
                          "E57697",
                          Theme.of(
                            context,
                          ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                        )
                        .replaceAll(
                          "F0F0F0",
                          Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                        )
                        .replaceAll(
                          "2F2E41",
                          Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                        )
                        .replaceAll(
                          "3F3D56",
                          Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                        )
                        .replaceAll("2F2F2F", Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2)),
                  ),
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
          : Container(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
