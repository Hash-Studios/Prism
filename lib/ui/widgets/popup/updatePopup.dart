import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdatePopup extends StatefulWidget {
  @override
  _UpdatePopupState createState() => _UpdatePopupState();
}

class _UpdatePopupState extends State<UpdatePopup> {
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Expanded(
            child: Container(
              width: width,
              height: height,
              color: Colors.transparent,
            ),
          ),
          Container(
            width: width * 0.7,
            height: height * 0.4,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).primaryColor),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Text(
                    "Prism is ready for update!",
                    style: TextStyle(
                        fontSize: 20, color: Theme.of(context).accentColor),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(width*0.1),
                  child: Column(
                    children: [
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "* Latest features",
                          style: TextStyle(
                              fontSize: 15, color: Theme.of(context).accentColor),
                        ),
                      ),Container(
                        alignment: Alignment.centerLeft,

                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "* Bug Fixes",
                          style: TextStyle(
                              fontSize: 15, color: Theme.of(context).accentColor),
                        ),
                      ),
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "* Prism is ready for update!",
                          style: TextStyle(
                              fontSize: 15, color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: ()async {
                        const url = 'https://play.google.com/store/apps/details?id=com.hash.prism';
                        if (await canLaunch(url)) {
                          await launch(url);
                        } else {
                          throw 'Could not launch $url';
                        }
                      },
                      child: Container(
                        width: 200,
                        height: 50,
                        child: Center(child: Text("Update",style: TextStyle(color: Theme.of(context).primaryColor,fontSize: 15),),),
                        decoration: BoxDecoration( color: Theme.of(context).accentColor,borderRadius: BorderRadius.circular(20)),
                      ),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
