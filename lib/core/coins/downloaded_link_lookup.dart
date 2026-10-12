import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';

typedef DownloadedLinkCheck = bool Function(String link);
typedef DownloadedSinceCheck = bool Function(String link, int sinceMs);

/// True when the Downloads index holds this link. False when the index is not ready.
bool isLinkInDownloadedIndex(String link) =>
    getIt.isRegistered<DownloadedWallIndex>() && getIt<DownloadedWallIndex>().has(link);

/// True when the Downloads index saved this link at or after [sinceMs]. False when the index is not ready.
bool isLinkInDownloadedIndexSince(String link, int sinceMs) =>
    getIt.isRegistered<DownloadedWallIndex>() && getIt<DownloadedWallIndex>().savedSince(link, sinceMs);
