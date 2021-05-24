import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:Prism/theme/jam_icons_icons.dart';

class EnterCodePanel extends StatefulWidget {
  const EnterCodePanel({
    Key? key,
  }) : super(key: key);

  @override
  _EnterCodePanelState createState() => _EnterCodePanelState();
}

class _EnterCodePanelState extends State<EnterCodePanel> {
  final TextEditingController codeController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = false;
  bool enabled = false;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Container(
      height: MediaQuery.of(context).size.height / 2 > 400
          ? MediaQuery.of(context).size.height / 2
          : 400,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  height: 5,
                  width: 30,
                  decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(500)),
                ),
              )
            ],
          ),
          const Spacer(),
          Text(
            "Enter Code",
            style: Theme.of(context).textTheme.headline2,
          ),
          const Spacer(flex: 2),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                height: 80,
                width: width - 24,
                child: Center(
                  child: TextField(
                    cursorColor: const Color(0xFFE57697),
                    style: Theme.of(context)
                        .textTheme
                        .headline5!
                        .copyWith(color: Colors.white),
                    controller: codeController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 30, top: 15),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 2)),
                      disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 2)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 2)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Colors.white, width: 2)),
                      labelText: "Enter Code",
                      labelStyle: Theme.of(context)
                          .textTheme
                          .headline5!
                          .copyWith(fontSize: 14, color: Colors.white),
                      prefixIcon: const Icon(
                        JamIcons.coin,
                        color: Colors.white,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value != "" && value.length >= 8) {
                          enabled = true;
                        } else {
                          enabled = false;
                        }
                      });
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: enabled
                      ? () async {
                          if (codeController.text != "" &&
                              codeController.text.length >= 8) {
                            setState(() {
                              isLoading = true;
                            });
                            await firestore
                                .collection('codes')
                                .where('code',
                                    isEqualTo:
                                        codeController.text.toLowerCase())
                                .limit(1)
                                .get()
                                .then((value) {
                              if (value.docs.isNotEmpty) {
                                if (value.docs[0].data()["redeemed"] == false) {
                                  firestore
                                      .collection('codes')
                                      .doc(value.docs[0].id)
                                      .update({
                                    "redeemed": true,
                                    "winner": globals.prismUser.toJson(),
                                    "when": DateTime.now()
                                  });
                                  toasts.codeSend(
                                      "Congratulations, we will contact you!");
                                } else {
                                  toasts.error(
                                      "Sorry, this code has already been redeemed!");
                                }
                              } else {
                                toasts.error("Invalid code!");
                              }
                            });
                            setState(() {
                              isLoading = false;
                            });
                          }
                        }
                      : null,
                  child: SizedBox(
                    width: width - 20,
                    height: 60,
                    child: Container(
                      width: width - 14,
                      height: 60,
                      decoration: BoxDecoration(
                        color: !enabled
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).errorColor.withOpacity(0.2),
                        border: Border.all(
                            color: !enabled
                                ? Theme.of(context).accentColor.withOpacity(0.5)
                                : Theme.of(context).errorColor,
                            width: 3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                "Redeem Code",
                                style: TextStyle(
                                    fontSize: 16,
                                    color: !enabled
                                        ? Theme.of(context)
                                            .accentColor
                                            .withOpacity(0.5)
                                        : Theme.of(context).accentColor,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Text(
                "We regularly give these codes on our Twitter/ Telegram @PrismWallpapers. Enter the code here, and if you are the first to redeem it, you get Prism Premium or any other reward for free!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
