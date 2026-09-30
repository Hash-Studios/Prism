import 'dart:async';
import 'dart:io';

import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

bool isAiOfflineOrNetworkError(Object error) {
  if (error is SocketException || error is TimeoutException || error is http.ClientException) {
    return true;
  }
  if (error is FirebaseException && (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return true;
  }
  if (error is FirestoreError) {
    final Object? original = error.original;
    if (original is FirebaseException && (original.code == 'unavailable' || original.code == 'deadline-exceeded')) {
      return true;
    }
  }
  return false;
}

String aiHistoryFailureMessage(Object error) => isAiOfflineOrNetworkError(error)
    ? "You're offline or the network failed. Pull to refresh when you're back."
    : "Couldn't load history. Pull to refresh.";

String aiGenerateFailureMessage(Object error) {
  if (error is AiGenerationApiException) return error.message;
  if (isAiOfflineOrNetworkError(error)) return 'No connection. Check your network and try again.';
  return 'Something went wrong. Try again.';
}

String aiDownloadFailureMessage(Object error) => isAiOfflineOrNetworkError(error)
    ? 'No connection. Check your network and try again.'
    : "Couldn't save that file. Try again.";

/// True when [generated] is shaped differently enough from [targetSize] ("1080x2400") that the crop will show.
bool isAiAspectRatioMismatch({required AiGenerationRecord generated, required String targetSize}) {
  final List<String> parts = targetSize.split('x');
  if (parts.length != 2) return false;
  final int? tw = int.tryParse(parts[0]);
  final int? th = int.tryParse(parts[1]);
  if (tw == null || th == null || tw == 0 || th == 0 || generated.width <= 0 || generated.height <= 0) {
    return false;
  }
  return (generated.width / generated.height - tw / th).abs() > 0.08;
}

String aiCommunityId(String generationId) {
  final String sanitized = generationId.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
  final String suffix = sanitized.isEmpty
      ? 'GEN'
      : sanitized.substring(0, sanitized.length < 10 ? sanitized.length : 10);
  return 'AI$suffix';
}

Future<File> aiDownloadToTempFile(String url) async {
  final http.Response response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException('download_failed', uri: Uri.parse(url));
  }
  final Directory directory = await getTemporaryDirectory();
  final File file = File('${directory.path}/ai_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(response.bodyBytes, flush: true);
  return file;
}
