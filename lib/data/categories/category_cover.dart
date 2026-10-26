import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Pexels photo ids of the stock category and interest covers that ship in `assets/images/covers/`. Pexels can time
/// out or drop a photo, so these covers never wait on the network. Remote Config lists that reuse a stock URL get the
/// bundled copy too.
const Set<String> _bundledCoverIds = <String>{
  // Personalized interests (defaultPersonalizedInterestsJson).
  '586059', '572897', '358070', '247502', '3075993', '998641', '3244513', '1458457', '7130560', '1004409', '1269968', //
  '7415261', '844297', '129731', '931177', '466685', '326900', '3657154', '1633798', '323780', '1516680', //
  '10017673', '6980830', '3861969', '3560044', '3165335', '1536619', '1643457', '34563722', '7809122', '2582937', //
  '1640777', '167636',
  // Built-in categories (categoryDefinitions).
  '1616403', '2888331', '4355348', '1624496', '1493226', '301614', '1714208', '807598', '747964', '1169754', //
  '1049622', '2917442', '3169299', '220634', '355288', '247431', '4048093', '531756', '3311574', '3052361',
};

final RegExp _pexelsPhotoId = RegExp(r'^https://images\.pexels\.com/photos/(\d+)/');

/// The bundled asset for a stock cover [url], or null when the cover only exists online.
String? bundledCoverAsset(String url) {
  final String? id = _pexelsPhotoId.firstMatch(url.trim())?.group(1);
  return id != null && _bundledCoverIds.contains(id) ? 'assets/images/covers/$id.webp' : null;
}

/// The bundled copy of a stock cover, else the network image from the shared thumbnail cache.
ImageProvider coverImageProvider(String url) {
  final String? asset = bundledCoverAsset(url);
  return asset != null ? AssetImage(asset) : CachedNetworkImageProvider(url, cacheManager: PrismImageCache.instance);
}

/// Warms a cover before its tile shows. A failed load only leaves the tile on its placeholder, so it is not reported.
Future<void> precacheCover(String url, BuildContext context) =>
    precacheImage(coverImageProvider(url), context, onError: (_, _) {});
