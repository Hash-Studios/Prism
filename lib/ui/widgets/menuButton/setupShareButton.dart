import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SetupShareButton extends StatelessWidget {
  const SetupShareButton({
    Key key,
    @required this.index,
  }) : super(key: key);

  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        createSetupDynamicLink(
            index.toString(),
            Provider.of<SetupProvider>(context, listen: false)
                .setups[index]["name"]
                .toString(),
            Provider.of<SetupProvider>(context, listen: false)
                .setups[index]["image"]
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
          JamIcons.share_alt,
          color: Theme.of(context).accentColor,
          size: 20,
        ),
      ),
    );
  }
}
