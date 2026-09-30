import 'dart:math';

import 'package:Prism/data/upload/upload_id.dart';
import 'package:Prism/data/upload/wallpaper/setup_submission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('randomUploadId', () {
    test('is capital letters with exactly one digit', () {
      final Random random = Random(7);
      for (final int length in <int>[4, 6]) {
        for (int i = 0; i < 50; i++) {
          final String id = randomUploadId(length, random: random);
          expect(id, hasLength(length));
          expect(id, matches(RegExp(r'^[A-Z0-9]+$')));
          expect(RegExp('[0-9]').allMatches(id), hasLength(1));
        }
      }
    });
  });

  group('SetupWallpaperInput', () {
    test('link stores the raw url and no wall id', () {
      const LinkWallpaper input = LinkWallpaper('https://example.com/w.jpg');
      expect(input.firestoreValue, 'https://example.com/w.jpg');
      expect(input.wallId, isEmpty);
      expect(input.isFilled, isTrue);
      expect(const LinkWallpaper('').isFilled, isFalse);
    });

    test('uploaded stores the url and the wall id', () {
      const UploadedWallpaper input = UploadedWallpaper(url: 'https://example.com/w.jpg', id: 'AB1C');
      expect(input.firestoreValue, 'https://example.com/w.jpg');
      expect(input.wallId, 'AB1C');
      expect(input.isFilled, isTrue);
    });

    test('app stores name, link and wall name and needs name and link', () {
      const AppWallpaper input = AppWallpaper(appName: 'Walli', link: 'https://walli.app', wallName: 'Dusk');
      expect(input.firestoreValue, <String>['Walli', 'https://walli.app', 'Dusk']);
      expect(input.isFilled, isTrue);
      expect(const AppWallpaper(appName: 'Walli', link: '', wallName: '').isFilled, isFalse);
      expect(const AppWallpaper(appName: '', link: 'https://walli.app', wallName: '').isFilled, isFalse);
    });
  });

  group('SetupDetails.hasRequiredFields', () {
    SetupDetails details({
      String name = 'Dusk',
      String desc = 'Warm and calm',
      String icon = 'Lawnicons',
      String iconUrl = 'https://icons.app',
      SetupWallpaperInput wallpaper = const LinkWallpaper('https://example.com/w.jpg'),
    }) => SetupDetails(setupName: name, setupDesc: desc, iconName: icon, iconUrl: iconUrl, wallpaper: wallpaper);

    test('accepts a complete setup', () => expect(details().hasRequiredFields, isTrue));

    test('rejects a missing name, description, icon name, icon link or wallpaper', () {
      expect(const SetupDetails().hasRequiredFields, isFalse);
      expect(details(name: '').hasRequiredFields, isFalse);
      expect(details(desc: '').hasRequiredFields, isFalse);
      expect(details(icon: '').hasRequiredFields, isFalse);
      expect(details(iconUrl: '').hasRequiredFields, isFalse);
      expect(details(wallpaper: const LinkWallpaper('')).hasRequiredFields, isFalse);
    });
  });

  group('SetupSubmission.toFirestore', () {
    const SetupDetails details = SetupDetails(
      setupName: 'Dusk',
      setupDesc: 'Warm and calm',
      iconName: 'Lawnicons',
      iconUrl: 'https://icons.app',
      widgetName: 'KWGT',
      widgetUrl: 'https://kwgt.app',
      wallpaper: UploadedWallpaper(url: 'https://example.com/w.jpg', id: 'AB1C'),
    );

    test('maps the submission to the setup document fields', () {
      final Map<String, dynamic> payload = const SetupSubmission(
        id: 'ABC1DE',
        imageUrl: 'https://example.com/setup.jpg',
        wallpaperProvider: 'Prism',
        wallpaperThumb: '',
        review: false,
        details: details,
      ).toFirestore();
      expect(payload, containsPair('id', 'ABC1DE'));
      expect(payload, containsPair('image', 'https://example.com/setup.jpg'));
      expect(payload, containsPair('wallpaper_provider', 'Prism'));
      expect(payload, containsPair('wallpaper_url', 'https://example.com/w.jpg'));
      expect(payload, containsPair('wall_id', 'AB1C'));
      expect(payload, containsPair('icon', 'Lawnicons'));
      expect(payload, containsPair('icon_url', 'https://icons.app'));
      expect(payload, containsPair('widget', 'KWGT'));
      expect(payload, containsPair('widget_url', 'https://kwgt.app'));
      expect(payload, containsPair('widget2', ''));
      expect(payload, containsPair('name', 'Dusk'));
      expect(payload, containsPair('desc', 'Warm and calm'));
      expect(payload, containsPair('review', false));
    });

    test('writes an app wallpaper as a three item list with no wall id', () {
      final Map<String, dynamic> payload = const SetupSubmission(
        id: 'ABC1DE',
        imageUrl: null,
        wallpaperProvider: 'Prism',
        wallpaperThumb: '',
        review: true,
        details: SetupDetails(
          wallpaper: AppWallpaper(appName: 'Walli', link: 'https://walli.app', wallName: 'Dusk'),
        ),
      ).toFirestore();
      expect(payload['wallpaper_url'], <String>['Walli', 'https://walli.app', 'Dusk']);
      expect(payload['wall_id'], isEmpty);
      expect(payload['review'], isTrue);
    });
  });
}
