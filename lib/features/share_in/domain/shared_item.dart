import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_parser.dart';

enum SharedItemKind {
  prismLink,
  image,
  url;

  SharedItemKindValue get analytics => switch (this) {
    SharedItemKind.prismLink => SharedItemKindValue.prismLink,
    SharedItemKind.image => SharedItemKindValue.image,
    SharedItemKind.url => SharedItemKindValue.url,
  };
}

/// One thing another app shared to Prism.
sealed class SharedItem {
  const SharedItem();

  SharedItemKind get kind;
}

/// A link that Prism opens itself: a short link, a wall page or a folder page.
final class SharedPrismLink extends SharedItem {
  const SharedPrismLink(this.uri, this.action);

  final Uri uri;
  final DeepLinkActionEntity action;

  @override
  SharedItemKind get kind => SharedItemKind.prismLink;
}

/// An image file in the shared inbox. Prism deletes it after use or after 24 hours.
final class SharedImage extends SharedItem {
  const SharedImage(this.path);

  final String path;

  @override
  SharedItemKind get kind => SharedItemKind.image;
}

/// Any other web link. Prism looks for the page's image.
final class SharedUrl extends SharedItem {
  const SharedUrl(this.uri);

  final Uri uri;

  @override
  SharedItemKind get kind => SharedItemKind.url;
}

final RegExp _link = RegExp(r'(?:https?|prism)://[^\s<>"]+', caseSensitive: false);
final RegExp _trailingPunctuation = RegExp(r'''[.,;:!?)\]}'"]+$''');

/// The first usable link in [text], or null when it has none. Apps often share a title with the link.
SharedItem? sharedItemFromText(String text, {DeepLinkParser parser = const DeepLinkParser()}) {
  for (final RegExpMatch match in _link.allMatches(text)) {
    final Uri? uri = Uri.tryParse(match[0]!.replaceFirst(_trailingPunctuation, ''));
    if (uri == null || uri.host.isEmpty && uri.scheme.toLowerCase() != 'prism') continue;
    final String scheme = uri.scheme.toLowerCase();
    final bool prismHost = const <String>{'prismwalls.com', 'www.prismwalls.com'}.contains(uri.host.toLowerCase());
    if (scheme == 'prism' || prismHost) {
      final DeepLinkActionEntity action = parser.parse(uri);
      if (action is! UnknownIntent && action is! ShareInIntent) return SharedPrismLink(uri, action);
      if (scheme == 'prism') continue;
    }
    return SharedUrl(uri);
  }
  return null;
}
