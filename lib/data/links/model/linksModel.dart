import 'package:flutter/material.dart';
import 'package:Prism/theme/jam_icons_icons.dart';

class LinksModel {
  String name;
  String link;
  IconData icon;
  String username;

  LinksModel({
    required this.username,
    required this.name,
    required this.link,
    required this.icon,
  });

  factory LinksModel.fromLinkAndKey(String names, String links) {
    if (names.toLowerCase() == "twitter") {
      RegExp twitterUser = RegExp(
          r"(?:(?:http|https):\/\/)?(?:www.)?(?:twitter.com)\/(?:@)?([A-Za-z0-9-_]+)");
      return LinksModel(
        username: twitterUser.firstMatch(links)!.group(1)!,
        name: "Twitter",
        link: links,
        icon: JamIcons.twitter,
      );
    } else if (names.toLowerCase() == "instagram") {
      RegExp instagramUser = RegExp(
          r"(?:(?:http|https):\/\/)?(?:www.)?(?:instagram.com|instagr.am)\/(?:@)?([A-Za-z0-9-_]+)");
      return LinksModel(
        username: instagramUser.stringMatch(links)!,
        name: "Instagram",
        link: links,
        icon: JamIcons.instagram,
      );
    } else if (names.toLowerCase() == "telegram") {
      RegExp telegramUser = RegExp(
          r"(?:(?:http|https):\/\/)?(?:www.)?(?:t.me)\/(?:@)?([A-Za-z0-9-_]+)");
      return LinksModel(
        username: telegramUser.stringMatch(links)!,
        name: "Telegram",
        link: links,
        icon: JamIcons.plane_f,
      );
    }
    return LinksModel(
        username: "", name: "", link: "", icon: Icons.link_rounded);
  }
}
