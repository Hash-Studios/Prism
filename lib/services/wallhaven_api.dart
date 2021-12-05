import 'dart:io';

import 'package:dio/dio.dart';
import 'package:prism/model/wallhaven/wallhaven_search_response_model.dart';
import 'package:prism/model/wallhaven/wallhaven_wall_model.dart';
import 'package:prism/services/logger.dart';

class WallHavenAPI {
  final _dio = Dio(
    BaseOptions(
      baseUrl: 'https://wallhaven.cc/api/v1',
      connectTimeout: 8000,
      receiveTimeout: 3000,
    ),
  );

  void dispose() {
    _dio.close();
  }

  Future<Response?> _get({
    required uri,
    Map<String, String>? headers,
    Map<String, String?>? body,
  }) async {
    final String time = DateTime.now().toString();
    logger.d("GET:: $time : ${uri.toString()}");
    try {
      final Stopwatch stopwatch = Stopwatch()..start();
      final Map<String, dynamic> query = {};
      query.addAll(body ?? {});
      final Response response = await _dio.get(uri,
          queryParameters: query, options: Options(headers: headers));
      stopwatch.stop();
      logger.d("Last request took : ${stopwatch.elapsedMilliseconds} ms.");
      logger.d("Request : ${response.realUri}");
      if (response.statusCode != 200) {
        throw HttpException(response.statusCode.toString());
      }
      return response;
    } catch (e, st) {
      logger.e("Get Request Failed.", e, st);
      return null;
    }
  }

  Future<Response?> _post({
    required uri,
    Map<String, String>? headers,
    Map<String, String?>? body,
  }) async {
    final String time = DateTime.now().toString();
    logger.d("POST:: $time : ${uri.toString()}");
    try {
      final Stopwatch stopwatch = Stopwatch()..start();
      final Map<String, dynamic> query = {};
      query.addAll(body ?? {});
      final Response response = await _dio.post(uri,
          queryParameters: query, options: Options(headers: headers));
      stopwatch.stop();
      logger.d("Last request took : ${stopwatch.elapsedMilliseconds} ms.");
      logger.d("Request : ${response.realUri}");
      if (response.statusCode != 200) {
        throw HttpException(response.statusCode.toString());
      }
      return response;
    } catch (e, st) {
      logger.e("Post Request Failed.", e, st);
      return null;
    }
  }

  Future<WallHavenSearchResponse?> getSearchResults({
    String? query,
    int page = 1,
    String categories = '111',
    String purity = '100',
    String sorting = 'random',
    String order = 'desc',
  }) async {
    final Response? res = await _get(
      uri: '/search',
      body: {
        'q': query,
        'page': '$page',
        'categories': categories,
        'purity': purity,
        'sorting': sorting,
        'order': order,
      },
    );
    if (res == null) {
      return null;
    }
    return WallHavenSearchResponse.fromJson(res.data);
  }

  Future<WallHavenWall?> getWallById({
    required String id,
  }) async {
    final Response? res = await _get(
      uri: '/w/$id',
    );
    if (res == null) {
      return null;
    }
    return WallHavenWall.fromJson(res.data['data']);
  }
}
