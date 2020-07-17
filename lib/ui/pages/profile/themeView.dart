import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/profile/animatedThemeSwitch.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ThemeView extends StatefulWidget {
  @override
  _ThemeViewState createState() => _ThemeViewState();
}

class _ThemeViewState extends State<ThemeView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            "Pick a Theme",
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
          Center(
            child: Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).hintColor,
                      blurRadius: 40,
                      offset: Offset(0, 2),
                    )
                  ]),
              width: MediaQuery.of(context).size.height * 0.3,
              height: MediaQuery.of(context).size.height * 0.6,
            ),
          ),
          AnimatedToggle(
            values: ['Light', 'Dark'],
            textColor: Theme.of(context).accentColor,
            backgroundColor: Theme.of(context).hintColor,
            buttonColor: Theme.of(context).primaryColor,
            shadows: [
              BoxShadow(
                color: Theme.of(context).hintColor,
                blurRadius: 40,
                offset: Offset(0, 2),
              )
            ],
            onToggleCallback: (index) {
              Provider.of<ThemeModel>(context, listen: false).toggleTheme();
              print("Theme Changed");
            },
          ),
        ],
      ),
    );
  }
}
