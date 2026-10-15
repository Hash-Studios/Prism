import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class OldVersion extends StatelessWidget {
  String get _storeLink => defaultTargetPlatform == TargetPlatform.iOS ? appStoreUrl : playStoreUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        centerTitle: true,
        title: Text("Update", style: PrismTextStyles.sectionTitle(context)),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Spacer(),
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: Text(
                "The version ${app_state.currentAppVersion}+${app_state.currentAppVersionCode} is obsolete and no longer supported. Please update the app to the latest version, to use it.",
                textAlign: TextAlign.center,
                style: PrismTextStyles.body(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              PrismHaptics.tap();
              openPrismLink(context, _storeLink);
            },
            child: const Text('Update'),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
