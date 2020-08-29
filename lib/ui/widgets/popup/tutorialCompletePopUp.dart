import 'package:Prism/ui/widgets/popup/changelogPopUp.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';

void showTutorialComplete(BuildContext context) {
  Dialog tutPopUp = Dialog(
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
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
                color: Theme.of(context).hintColor),
            child: FlareActor(
              "assets/animations/Success.flr",
              fit: BoxFit.contain,
              isPaused: false,
              alignment: Alignment.center,
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
              SizedBox(
                height: 20,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
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
          SizedBox(
            height: 25,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              FlatButton(
                shape: StadiumBorder(),
                color: Color(0xFFE57697),
                onPressed: () {
                  Navigator.of(context).pop();
                  showChangelog(context, () {});
                },
                child: Text(
                  'VIEW CHANGELOG',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                  ),
                ),
              ),
              FlatButton(
                shape: StadiumBorder(),
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
          SizedBox(
            height: 15,
          ),
        ],
      ),
    ),
  );
  showDialog(context: context, builder: (BuildContext context) => tutPopUp);
}
