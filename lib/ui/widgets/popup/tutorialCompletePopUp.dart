import 'package:Prism/ui/widgets/popup/changelogPopUp.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;

void showTutorialComplete(BuildContext context) {
  final Dialog tutPopUp = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 150,
            width: MediaQuery.of(context).size.width * .78,
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
                color: Theme.of(context).hintColor),
            child: const FlareActor(
              "assets/animations/Success.flr",
              animation: "trophy",
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                    child: Text(
                      '🏆Congratulations,',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Theme.of(context).accentColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Text(
                      "You have successfully completed the tutorial and are ready to revamp your home screen.\n\n🤟Thank you for your awesomeness.\nHash Studios",
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(
            height: 25,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              FlatButton(
                shape: const StadiumBorder(),
                color: config.Colors().mainAccentColor(1),
                onPressed: () {
                  Navigator.of(context).pop();
                  showChangelog(context, () {});
                },
                child: const Text(
                  'VIEW CHANGELOG',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                  ),
                ),
              ),
              FlatButton(
                shape: const StadiumBorder(),
                color: Theme.of(context).accentColor.withOpacity(0.3),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'CLOSE',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Theme.of(context).accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 15,
          ),
        ],
      ),
    ),
  );
  showDialog(context: context, builder: (BuildContext context) => tutPopUp);
}
