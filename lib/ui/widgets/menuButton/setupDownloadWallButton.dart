import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ModifiedDownloadButton extends StatelessWidget {
  final int index;
  const ModifiedDownloadButton({@required this.index});
  @override
  Widget build(BuildContext context) {
    return Provider.of<SetupProvider>(context, listen: false)
                .setups[index]["wallpaper_url"]
                .toString()[0] !=
            "["
        ? DownloadButton(
            link: Provider.of<SetupProvider>(context, listen: false)
                .setups[index]["wallpaper_url"]
                .toString(),
            colorChanged: false,
          )
        : GestureDetector(
            onTap: () async {
              launch(Provider.of<SetupProvider>(context, listen: false)
                  .setups[index]["wallpaper_url"][1]
                  .toString());
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(.25),
                      blurRadius: 4,
                      offset: const Offset(0, 4))
                ],
                borderRadius: BorderRadius.circular(500),
              ),
              padding: const EdgeInsets.all(17),
              child: Icon(
                JamIcons.download,
                color: Theme.of(context).accentColor,
                size: 20,
              ),
            ),
          );
  }
}
