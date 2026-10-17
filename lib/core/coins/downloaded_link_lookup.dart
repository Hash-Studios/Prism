import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';

typedef DownloadedLinkCheck = bool Function(String link);
typedef VerifiedLegacyNativeDownloadCheck = Future<bool> Function(String link);

/// True when the Downloads index holds this link. False when the index is not ready.
bool isLinkInDownloadedIndex(String link) =>
    getIt.isRegistered<DownloadedWallIndex>() && getIt<DownloadedWallIndex>().has(link);

/// Confirms that legacy recovery metadata still points to a valid native image file.
Future<bool> hasVerifiedLegacyNativeDownload(String link) async =>
    getIt.isRegistered<DownloadedWallIndex>() && await getIt<DownloadedWallIndex>().hasVerifiedLegacyNativeFile(link);
