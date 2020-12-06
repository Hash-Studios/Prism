import 'dart:convert';

import 'package:Prism/gitkey.dart';
import 'package:github/github.dart';

String jsonFile = 'dummy.json';

Future<Map> getMapFromGitHub() async {
  final Codec<String, String> stringToBase64 = utf8.fuse(base64);
  final github = GitHub(auth: Authentication.withToken(token));
  Map jsonMap;
  await github.repositories
      .getContents(RepositorySlug(gitUserName, repoName3), jsonFile)
      .then((value) => jsonMap = json.decode(
              stringToBase64.decode(value.file.content.replaceAll("\n", "")))
          as Map);
  return jsonMap;
}

Future<void> updateViews(String id) async {
  final Codec<String, String> stringToBase64 = utf8.fuse(base64);
  final github = GitHub(auth: Authentication.withToken(token));
  RepositoryContents repoContents;
  Map jsonMap;
  await github.repositories
      .getContents(RepositorySlug(gitUserName, repoName3), jsonFile)
      .then((value) => repoContents = value);
  jsonMap = json.decode(
          stringToBase64.decode(repoContents.file.content.replaceAll("\n", "")))
      as Map;
  jsonMap["wallpapers"][id] = {
    "views": jsonMap["wallpapers"][id] != null
        ? (int.parse(jsonMap["wallpapers"][id]["views"].toString()) + 1)
            .toString()
        : "1"
  };
  await github.repositories.updateFile(
      RepositorySlug(gitUserName, repoName3),
      jsonFile,
      "Updated views for $id",
      stringToBase64.encode(json.encode(jsonMap)),
      repoContents.file.sha);
}

Future<void> updateDownloads(String id) async {
  final Codec<String, String> stringToBase64 = utf8.fuse(base64);
  final github = GitHub(auth: Authentication.withToken(token));
  RepositoryContents repoContents;
  Map jsonMap;
  await github.repositories
      .getContents(RepositorySlug(gitUserName, repoName3), jsonFile)
      .then((value) => repoContents = value);
  jsonMap = json.decode(
          stringToBase64.decode(repoContents.file.content.replaceAll("\n", "")))
      as Map;
  jsonMap["wallpapers"][id] = {
    "downloads": jsonMap["wallpapers"][id] != null
        ? (int.parse(jsonMap["wallpapers"][id]["downloads"].toString()) + 1)
            .toString()
        : "1"
  };
  await github.repositories.updateFile(
      RepositorySlug(gitUserName, repoName3),
      jsonFile,
      "Updated downloads for $id",
      stringToBase64.encode(json.encode(jsonMap)),
      repoContents.file.sha);
}

Future<void> updateFavorites(String id) async {
  final Codec<String, String> stringToBase64 = utf8.fuse(base64);
  final github = GitHub(auth: Authentication.withToken(token));
  RepositoryContents repoContents;
  Map jsonMap;
  await github.repositories
      .getContents(RepositorySlug(gitUserName, repoName3), jsonFile)
      .then((value) => repoContents = value);
  jsonMap = json.decode(
          stringToBase64.decode(repoContents.file.content.replaceAll("\n", "")))
      as Map;
  jsonMap["wallpapers"][id] = {
    "favorites": jsonMap["wallpapers"][id] != null
        ? (int.parse(jsonMap["wallpapers"][id]["favorites"].toString()) + 1)
            .toString()
        : "1"
  };
  await github.repositories.updateFile(
      RepositorySlug(gitUserName, repoName3),
      jsonFile,
      "Updated favorites for $id",
      stringToBase64.encode(json.encode(jsonMap)),
      repoContents.file.sha);
}

Future<void> updateViewsSetup(String id) async {
  final Codec<String, String> stringToBase64 = utf8.fuse(base64);
  final github = GitHub(auth: Authentication.withToken(token));
  RepositoryContents repoContents;
  Map jsonMap;
  await github.repositories
      .getContents(RepositorySlug(gitUserName, repoName3), jsonFile)
      .then((value) => repoContents = value);
  jsonMap = json.decode(
          stringToBase64.decode(repoContents.file.content.replaceAll("\n", "")))
      as Map;
  jsonMap["setups"][id] = {
    "views": jsonMap["setups"][id] != null
        ? (int.parse(jsonMap["setups"][id]["views"].toString()) + 1).toString()
        : "1"
  };
  await github.repositories.updateFile(
      RepositorySlug(gitUserName, repoName3),
      jsonFile,
      "Updated views for $id",
      stringToBase64.encode(json.encode(jsonMap)),
      repoContents.file.sha);
}

Future<void> updateDownloadsSetup(String id) async {
  final Codec<String, String> stringToBase64 = utf8.fuse(base64);
  final github = GitHub(auth: Authentication.withToken(token));
  RepositoryContents repoContents;
  Map jsonMap;
  await github.repositories
      .getContents(RepositorySlug(gitUserName, repoName3), jsonFile)
      .then((value) => repoContents = value);
  jsonMap = json.decode(
          stringToBase64.decode(repoContents.file.content.replaceAll("\n", "")))
      as Map;
  jsonMap["setups"][id] = {
    "downloads": jsonMap["setups"][id] != null
        ? (int.parse(jsonMap["setups"][id]["downloads"].toString()) + 1)
            .toString()
        : "1"
  };
  await github.repositories.updateFile(
      RepositorySlug(gitUserName, repoName3),
      jsonFile,
      "Updated downloads for $id",
      stringToBase64.encode(json.encode(jsonMap)),
      repoContents.file.sha);
}

Future<void> updateFavsSetup(String id) async {
  final Codec<String, String> stringToBase64 = utf8.fuse(base64);
  final github = GitHub(auth: Authentication.withToken(token));
  RepositoryContents repoContents;
  Map jsonMap;
  await github.repositories
      .getContents(RepositorySlug(gitUserName, repoName3), jsonFile)
      .then((value) => repoContents = value);
  jsonMap = json.decode(
          stringToBase64.decode(repoContents.file.content.replaceAll("\n", "")))
      as Map;
  jsonMap["setups"][id] = {
    "favorites": jsonMap["setups"][id] != null
        ? (int.parse(jsonMap["setups"][id]["favorites"].toString()) + 1)
            .toString()
        : "1"
  };
  await github.repositories.updateFile(
      RepositorySlug(gitUserName, repoName3),
      jsonFile,
      "Updated favorites for $id",
      stringToBase64.encode(json.encode(jsonMap)),
      repoContents.file.sha);
}
