import 'package:Prism/env/env.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

class LegacyThumbnailFileService extends HttpFileService {
  LegacyThumbnailFileService({http.Client? httpClient, String? owner, String? repo})
    : _owner = owner ?? Env.normalize(Env.ghUsername),
      _repo = repo ?? Env.normalize(Env.ghRepoWalls),
      super(httpClient: httpClient);

  final String _owner;
  final String _repo;

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) => super.get(url, headers: headers);
}
