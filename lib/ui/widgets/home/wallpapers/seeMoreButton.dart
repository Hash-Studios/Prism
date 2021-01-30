import 'package:Prism/theme/themeModeProvider.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SeeMoreButton extends StatelessWidget {
  const SeeMoreButton({
    Key key,
    @required this.seeMoreLoader,
    @required this.func,
  }) : super(key: key);

  final bool seeMoreLoader;
  final Function func;

  @override
  Widget build(BuildContext context) {
    return FlatButton(
      color: Provider.of<ThemeModeExtended>(context).getCurrentModeStyle(
                  MediaQuery.of(context).platformBrightness) ==
              "Dark"
          ? Colors.white10
          : Colors.black.withOpacity(.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        func();
      },
      child: !seeMoreLoader ? const Text("See more") : Loader(),
    );
  }
}
