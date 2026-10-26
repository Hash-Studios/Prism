import 'package:Prism/core/constants/profile_links.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A comma or semicolon right before another scheme starts the next link, as in `https://a.com,https://b.com`.
final RegExp _linkPattern = RegExp(r'https?://(?:(?![,;]https?://)\S)+', caseSensitive: false);

/// Sentence punctuation that usually ends a sentence, not the link, so it stays in the plain text.
const String _trailingPunctuation = '.,!?;:)]}\'"';

class BioSegment {
  const BioSegment(this.text, [this.uri]);

  final String text;

  /// Null for plain text.
  final Uri? uri;

  @override
  bool operator ==(Object other) => other is BioSegment && other.text == text && other.uri == uri;

  @override
  int get hashCode => Object.hash(text, uri);

  @override
  String toString() => 'BioSegment($text, $uri)';
}

/// Splits [bio] into plain text and explicit http or https links. Anything else stays plain text.
List<BioSegment> splitBioLinks(String bio) {
  final List<BioSegment> segments = <BioSegment>[];
  int cursor = 0;
  for (final RegExpMatch match in _linkPattern.allMatches(bio)) {
    String link = match.group(0)!;
    while (link.isNotEmpty && _trailingPunctuation.contains(link[link.length - 1])) {
      if (link.endsWith(')') && '('.allMatches(link).length >= ')'.allMatches(link).length) break;
      link = link.substring(0, link.length - 1);
    }
    final Uri? uri = safeProfileLinkUri(link);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) continue;
    if (match.start > cursor) segments.add(BioSegment(bio.substring(cursor, match.start)));
    segments.add(BioSegment(link, uri));
    cursor = match.start + link.length;
  }
  if (cursor < bio.length) segments.add(BioSegment(bio.substring(cursor)));
  return segments;
}

/// Two lines at most: bios up to 150 chars deserve more space than one.
class ProfileBioText extends StatefulWidget {
  const ProfileBioText({super.key, required this.bio, required this.style, required this.onOpenLink});

  final String bio;
  final TextStyle style;
  final ValueChanged<Uri> onOpenLink;

  @override
  State<ProfileBioText> createState() => _ProfileBioTextState();
}

class _ProfileBioTextState extends State<ProfileBioText> {
  List<BioSegment> _segments = const <BioSegment>[];

  /// One entry per segment, aligned by index. Null for plain text.
  List<TapGestureRecognizer?> _recognizers = const <TapGestureRecognizer?>[];

  @override
  void initState() {
    super.initState();
    _parseBio();
  }

  @override
  void didUpdateWidget(ProfileBioText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bio != widget.bio) {
      _disposeRecognizers();
      _parseBio();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _parseBio() {
    _segments = splitBioLinks(widget.bio);
    _recognizers = <TapGestureRecognizer?>[
      for (final BioSegment segment in _segments)
        if (segment.uri case final Uri uri) TapGestureRecognizer()..onTap = () => widget.onOpenLink(uri) else null,
    ];
  }

  void _disposeRecognizers() {
    for (final TapGestureRecognizer? recognizer in _recognizers) {
      recognizer?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recognizers.every((TapGestureRecognizer? recognizer) => recognizer == null)) {
      return Text(
        widget.bio,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: widget.style,
      );
    }
    final TextStyle linkStyle = widget.style.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: <InlineSpan>[
          for (final (int index, BioSegment segment) in _segments.indexed)
            TextSpan(
              text: segment.text,
              style: segment.uri == null ? null : linkStyle,
              recognizer: _recognizers[index],
            ),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
