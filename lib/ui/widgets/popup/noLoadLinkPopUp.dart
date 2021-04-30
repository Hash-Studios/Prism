import 'package:Prism/data/links/model/linksModel.dart';
import 'package:Prism/ui/pages/profile/aboutScreen.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

void showNoLoadLinksPopUp(BuildContext context, Map link) {
  List<LinksModel> links = [];
  void getLinks(Map link) {
    links = linksToModel(link);
  }

  getLinks(link);
  final AlertDialog linkPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.center,
            children: links
                .map(
                  (e) => ActionButton(
                    icon: e.icon,
                    link: e.link,
                    text: "@${e.username}",
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
    backgroundColor: Theme.of(context).primaryColor,
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
  );
  showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (BuildContext context) => linkPopUp);
}
