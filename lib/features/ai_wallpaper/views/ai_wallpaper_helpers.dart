import 'dart:async';
import 'dart:io';

import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_error_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const Duration aiAssetTransferTimeout = Duration(seconds: 30);

String aiStyleLabel(AppLocalizations l10n, AiStylePreset style) => switch (style) {
  AiStylePreset.anime => l10n.economyAiStyleAnime,
  AiStylePreset.minimal => l10n.economyAiStyleMinimal,
  AiStylePreset.cyberpunk => l10n.economyAiStyleCyberpunk,
  AiStylePreset.watercolor => l10n.economyAiStyleWatercolor,
  AiStylePreset.meshGradient => l10n.economyAiStyleMeshGradient,
  AiStylePreset.abstract => l10n.economyAiStyleAbstract,
  AiStylePreset.nature => l10n.economyAiStyleNature,
};

String aiQualityLabel(AppLocalizations l10n, AiQualityTier tier) => switch (tier) {
  AiQualityTier.fast => l10n.economyAiQualityFast,
  AiQualityTier.balanced => l10n.economyAiQualityBalanced,
  AiQualityTier.quality => l10n.economyAiQualityHigh,
};

bool isAiOfflineOrNetworkError(Object error) {
  if (error is SocketException ||
      error is HandshakeException ||
      error is TimeoutException ||
      error is http.ClientException) {
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

String aiHistoryFailureMessage(AppLocalizations l10n, Object error) =>
    isAiOfflineOrNetworkError(error) ? l10n.economyAiOfflineHistory : l10n.economyAiHistoryFailed;

String aiGenerateFailureMessage(AppLocalizations l10n, Object error) {
  if (error is AiGenerationApiException) return aiGenerationErrorCopy(l10n, error);
  if (isAiOfflineOrNetworkError(error)) return l10n.economyAiNoConnection;
  return l10n.economyAiGenerateGenericFailure;
}

String aiDownloadFailureMessage(AppLocalizations l10n, Object error) =>
    isAiOfflineOrNetworkError(error) ? l10n.economyAiNoConnection : l10n.economyAiSaveFailed;

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
  final File source = await OfflineAssetStore.instance.resolve(url).timeout(aiAssetTransferTimeout);
  final Directory directory = await getTemporaryDirectory();
  final String extension = source.path.contains('.') ? source.path.substring(source.path.lastIndexOf('.')) : '.image';
  final File file = File('${directory.path}/ai_${DateTime.now().millisecondsSinceEpoch}$extension');
  await source.copy(file.path);
  return file;
}
