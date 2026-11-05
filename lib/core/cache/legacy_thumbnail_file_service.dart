import 'package:Prism/env/env.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class LegacyThumbnailFileService extends HttpFileService {
  LegacyThumbnailFileService({super.httpClient, String? owner, String? repo})
    : _owner = owner ?? Env.normalize(Env.ghUsername),
      _repo = repo ?? Env.normalize(Env.ghRepoWalls);

  final String _owner;
  final String _repo;

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) {
    final String? proxy = _proxyUrl(url);
    return super.get(proxy ?? url, headers: proxy == null ? headers : null);
  }

  String? _proxyUrl(String url) {
    if (_owner.isEmpty || _repo.isEmpty) return null;
    final RegExpMatch? match = RegExp(r'^https://raw\.githubusercontent\.com/([^?#]+)$').firstMatch(url);
    if (match == null) return null;
    final List<String> encoded = match.group(1)!.split('/');
    try {
      final List<String> parts = encoded.map(Uri.decodeComponent).toList();
      if (parts.length < 4 ||
          parts[0].toLowerCase() != _owner.toLowerCase() ||
          parts[1] != _repo ||
          !RegExp(r'^[A-Za-z0-9._-]{1,255}$').hasMatch(parts[2]) ||
          parts.any(
            (part) => part.isEmpty || part == '.' || part == '..' || RegExp(r'[/\\%?#\x00-\x1f\x7f]').hasMatch(part),
          ) ||
          !parts.last.startsWith('thumb_') ||
          parts.last == 'thumb_') {
        return null;
      }
      final String path = encoded.skip(2).join('/');
      if (path.length > 1024) return null;
      return 'https://prismwalls.com/api/legacy-thumbs/$path';
    } on FormatException {
      return null;
    }
  }
}
