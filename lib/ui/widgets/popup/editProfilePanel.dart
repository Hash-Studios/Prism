import 'package:Prism/auth/google_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/main.dart' as main;

class EditProfilePanel extends StatefulWidget {
  const EditProfilePanel({
    Key? key,
  }) : super(key: key);

  @override
  _EditProfilePanelState createState() => _EditProfilePanelState();
}

class _EditProfilePanelState extends State<EditProfilePanel> {
  final TextEditingController codeController = TextEditingController();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = false;
  bool enabled = false;
  bool? available;
  bool isCheckingUsername = false;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
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
              "Edit username",
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
                        contentPadding:
                            const EdgeInsets.only(left: 30, top: 15),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.white, width: 2)),
                        labelText: "username",
                        labelStyle: Theme.of(context)
                            .textTheme
                            .headline5!
                            .copyWith(fontSize: 14, color: Colors.white),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "@",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        suffixIcon: isCheckingUsername
                            ? Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).errorColor,
                                  ),
                                ),
                              )
                            : Padding(
                                padding: EdgeInsets.all(
                                    available == null ? 16.0 : 8),
                                child: available == null
                                    ? const Text(
                                        "",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : Icon(
                                        available!
                                            ? JamIcons.check
                                            : JamIcons.close,
                                        color: available!
                                            ? Colors.green
                                            : Colors.red,
                                        size: 24,
                                      ),
                              ),
                      ),
                      onChanged: (value) async {
                        if (value != "" &&
                            value.length >= 8 &&
                            !value.contains(RegExp(r"(?: |[^\w\s])+"))) {
                          setState(() {
                            enabled = true;
                          });
                        } else {
                          setState(() {
                            enabled = false;
                          });
                        }
                        if (enabled) {
                          setState(() {
                            isCheckingUsername = true;
                          });
                          await FirebaseFirestore.instance
                              .collection(USER_NEW_COLLECTION)
                              .where("username", isEqualTo: value)
                              .get()
                              .then((snapshot) {
                            if (snapshot.size == 0) {
                              setState(() {
                                available = true;
                              });
                            } else {
                              setState(() {
                                available = false;
                              });
                            }
                          });
                          setState(() {
                            isCheckingUsername = false;
                          });
                        } else {
                          setState(() {
                            available = null;
                          });
                        }
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
                              globals.prismUser.username = codeController.text;
                              main.prefs.put("prismUserV2", globals.prismUser);
                              await firestore
                                  .collection(USER_NEW_COLLECTION)
                                  .doc(globals.prismUser.id)
                                  .update({
                                "username": codeController.text,
                              });
                              toasts.codeSend("Username updated!");
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
                                  ? Theme.of(context)
                                      .accentColor
                                      .withOpacity(0.5)
                                  : Theme.of(context).errorColor,
                              width: 3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: isLoading
                              ? const CircularProgressIndicator()
                              : Text(
                                  "Continue",
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
                  "Usernames are unique names through which fans can view your profile/search for you. They should be greater than 8 characters, and cannot contain any symbol except for underscore (_).",
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
      ),
    );
  }
}
