import 'package:Prism/theme/jam_icons_icons.dart';
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Image.asset(
                'assets/images/appIcon.png',
                fit: BoxFit.scaleDown,
              ),
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
          FlatButton(
            shape: StadiumBorder(),
            color: Color(0xFFE57697),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'CLOSE',
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.white,
              ),
            ),
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
