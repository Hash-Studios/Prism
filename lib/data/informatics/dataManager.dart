import 'dart:convert';

import 'package:Prism/env/env.dart';
import 'package:Prism/logger/logger.dart';
import 'package:github/github.dart';

String jsonFile = 'dummy.json';

final Codec<String, String> _stringToBase64 = utf8.fuse(base64);

class _RepoSnapshot {
  _RepoSnapshot({required this.repoContents, required this.jsonMap});

  final RepositoryContents repoContents;
  final Map<String, dynamic> jsonMap;
}

GitHub _buildGitHubClient() {
  final String trimmedToken = Env.ghToken.trim();
  if (trimmedToken.isEmpty) {
    return GitHub();
  }
  return GitHub(auth: Authentication.withToken(trimmedToken));
}

bool _isBadCredentials(Object error) {
  return error.toString().contains('Bad credentials');
}

void _logGitHubError({required String action, required Object error, required StackTrace stackTrace}) {
  if (_isBadCredentials(error)) {
    logger.w(
      'GitHub credentials are invalid while $action. Skipping informatics sync.',
      tag: 'Informatics',
      error: error,
      stackTrace: stackTrace,
    );
    return;
  }
  logger.w('GitHub request failed while $action.', tag: 'Informatics', error: error, stackTrace: stackTrace);
}

Future<_RepoSnapshot?> _loadRepoSnapshot(GitHub github, {required String action}) async {
  try {
    final RepositoryContents repoContents = await github.repositories.getContents(
      RepositorySlug(Env.ghUserName, Env.ghRepoData),
      jsonFile,
    );
    final String? encodedContent = repoContents.file?.content;
    if (encodedContent == null) {
      logger.w('GitHub content was empty while $action.', tag: 'Informatics');
      return null;
    }
    final dynamic decodedJson = json.decode(_stringToBase64.decode(encodedContent.replaceAll('\n', '')));
    if (decodedJson is! Map) {
      logger.w('GitHub content had unexpected shape while $action.', tag: 'Informatics');
      return null;
    }
    return _RepoSnapshot(repoContents: repoContents, jsonMap: decodedJson.cast<String, dynamic>());
  } catch (e, st) {
    _logGitHubError(action: action, error: e, stackTrace: st);
    return null;
  }
}

String _counterValue(
  Map<String, dynamic> jsonMap, {
  required String section,
  required String id,
  required String field,
}) {
  final dynamic sectionValue = jsonMap[section];
  if (sectionValue is! Map) {
    return '0';
  }
  final dynamic itemValue = sectionValue[id];
  if (itemValue is! Map) {
    return '0';
  }
  final dynamic value = itemValue[field];
  return value?.toString() ?? '0';
}

Future<void> _incrementCounter(String section, String field, String id) async {
  final GitHub github = _buildGitHubClient();
  try {
    final _RepoSnapshot? snapshot = await _loadRepoSnapshot(github, action: 'loading $section/$field for $id');
    if (snapshot == null) {
      return;
    }

    final dynamic sectionValue = snapshot.jsonMap[section];
    final Map<String, dynamic> sectionMap =
        sectionValue is Map ? sectionValue.cast<String, dynamic>() : <String, dynamic>{};

    final dynamic itemValue = sectionMap[id];
    final Map<String, dynamic> itemMap = itemValue is Map ? itemValue.cast<String, dynamic>() : <String, dynamic>{};

    final int currentCount = int.tryParse(itemMap[field]?.toString() ?? '0') ?? 0;
    itemMap[field] = (currentCount + 1).toString();
    sectionMap[id] = itemMap;
    snapshot.jsonMap[section] = sectionMap;

    final String? sha = snapshot.repoContents.file?.sha;
    if (sha == null) {
      logger.w('GitHub content SHA missing while updating $section/$field for $id.', tag: 'Informatics');
      return;
    }

    await github.repositories.updateFile(
      RepositorySlug(Env.ghUserName, Env.ghRepoData),
      jsonFile,
      'Updated $field for $id',
      _stringToBase64.encode(json.encode(snapshot.jsonMap)),
      sha,
      branch: 'main',
    );
  } catch (e, st) {
    _logGitHubError(action: 'updating $section/$field for $id', error: e, stackTrace: st);
  } finally {
    github.dispose();
  }
}

Future<Map?> getMapFromGitHub() async {
  final GitHub github = _buildGitHubClient();
  try {
    final _RepoSnapshot? snapshot = await _loadRepoSnapshot(github, action: 'reading map');
    return snapshot?.jsonMap;
  } finally {
    github.dispose();
  }
}

Future<String> getViews(String id) async {
  final GitHub github = _buildGitHubClient();
  try {
    final _RepoSnapshot? snapshot = await _loadRepoSnapshot(github, action: 'reading wallpaper views for $id');
    if (snapshot == null) {
      return '0';
    }
    return _counterValue(snapshot.jsonMap, section: 'wallpapers', id: id, field: 'views');
  } finally {
    github.dispose();
  }
}

Future<void> updateViews(String id) async {
  await _incrementCounter('wallpapers', 'views', id);
}

Future<void> updateDownloads(String id) async {
  await _incrementCounter('wallpapers', 'downloads', id);
}

Future<void> updateFavorites(String id) async {
  await _incrementCounter('wallpapers', 'favorites', id);
}

Future<String> getViewsSetup(String id) async {
  final GitHub github = _buildGitHubClient();
  try {
    final _RepoSnapshot? snapshot = await _loadRepoSnapshot(github, action: 'reading setup views for $id');
    if (snapshot == null) {
      return '0';
    }
    return _counterValue(snapshot.jsonMap, section: 'setups', id: id, field: 'views');
  } finally {
    github.dispose();
  }
}

Future<void> updateViewsSetup(String id) async {
  await _incrementCounter('setups', 'views', id);
}

Future<void> updateDownloadsSetup(String id) async {
  await _incrementCounter('setups', 'downloads', id);
}

Future<void> updateFavsSetup(String id) async {
  await _incrementCounter('setups', 'favorites', id);
}
