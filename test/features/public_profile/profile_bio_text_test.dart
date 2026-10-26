import 'package:Prism/features/public_profile/views/widgets/profile_bio_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitBioLinks', () {
    test('returns no links for plain text', () {
      expect(splitBioLinks('Just photos'), <BioSegment>[const BioSegment('Just photos')]);
    });

    test('splits a https link in the middle of a sentence', () {
      expect(splitBioLinks('Shots at https://example.com/a now'), <BioSegment>[
        const BioSegment('Shots at '),
        BioSegment('https://example.com/a', Uri.parse('https://example.com/a')),
        const BioSegment(' now'),
      ]);
    });

    test('keeps a trailing full stop out of the link', () {
      expect(splitBioLinks('See https://example.com/a.'), <BioSegment>[
        const BioSegment('See '),
        BioSegment('https://example.com/a', Uri.parse('https://example.com/a')),
        const BioSegment('.'),
      ]);
    });

    test('keeps a closing parenthesis out of the link', () {
      expect(splitBioLinks('(https://example.com/a)'), <BioSegment>[
        const BioSegment('('),
        BioSegment('https://example.com/a', Uri.parse('https://example.com/a')),
        const BioSegment(')'),
      ]);
    });

    test('splits two links with the text between them', () {
      expect(splitBioLinks('https://a.com and https://b.com/x!'), <BioSegment>[
        BioSegment('https://a.com', Uri.parse('https://a.com')),
        const BioSegment(' and '),
        BioSegment('https://b.com/x', Uri.parse('https://b.com/x')),
        const BioSegment('!'),
      ]);
    });

    test('accepts an http link', () {
      expect(splitBioLinks('http://example.com'), <BioSegment>[
        BioSegment('http://example.com', Uri.parse('http://example.com')),
      ]);
    });

    test('keeps javascript and bare domains as plain text', () {
      expect(splitBioLinks('javascript:alert(1) or example.com'), <BioSegment>[
        const BioSegment('javascript:alert(1) or example.com'),
      ]);
    });

    test('matches an uppercase scheme and host', () {
      expect(splitBioLinks('HTTPS://Example.com/x'), <BioSegment>[
        BioSegment('HTTPS://Example.com/x', Uri.parse('https://example.com/x')),
      ]);
    });
  });

  group('ProfileBioText', () {
    testWidgets('calls onOpenLink with the uri when the link is tapped', (WidgetTester tester) async {
      final List<Uri> opened = <Uri>[];
      await tester.pumpWidget(_host('Shots at https://example.com/a now', opened.add));

      await tester.tapOnText(find.textRange.ofSubstring('https://example.com/a'));

      expect(opened, <Uri>[Uri.parse('https://example.com/a')]);
    });

    testWidgets('does not call onOpenLink when plain words are tapped', (WidgetTester tester) async {
      final List<Uri> opened = <Uri>[];
      await tester.pumpWidget(_host('Shots at https://example.com/a now', opened.add));

      await tester.tapOnText(find.textRange.ofSubstring('Shots'));

      expect(opened, isEmpty);
    });

    testWidgets('opens the new link after the bio changes', (WidgetTester tester) async {
      final List<Uri> opened = <Uri>[];
      await tester.pumpWidget(_host('First https://example.com/a', opened.add));
      await tester.pumpWidget(_host('Now https://example.com/b', opened.add));

      await tester.tapOnText(find.textRange.ofSubstring('https://example.com/b'));

      expect(opened, <Uri>[Uri.parse('https://example.com/b')]);
    });
  });
}

Widget _host(String bio, ValueChanged<Uri> onOpenLink) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: ProfileBioText(bio: bio, style: const TextStyle(fontSize: 13), onOpenLink: onOpenLink),
      ),
    ),
  );
}
