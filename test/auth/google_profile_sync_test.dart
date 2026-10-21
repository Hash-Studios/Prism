import 'package:Prism/auth/google_profile_sync.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_user_fixture.dart';

const String _oldGooglePhoto = 'https://lh3.googleusercontent.com/a/old=s96-c';
const String _newGooglePhoto = 'https://lh3.googleusercontent.com/a/new=s1337';
const String _customPhoto = 'https://raw.githubusercontent.com/Hash-Studios/walls/main/u1_1_me.jpg';

void main() {
  group('isCustomProfilePhoto', () {
    test('a photo uploaded in Prism is custom', () {
      expect(isCustomProfilePhoto(_customPhoto), isTrue);
    });

    for (final String photo in <String>['', ' ', defaultProfilePhotoUrl, _oldGooglePhoto]) {
      test('"$photo" is not custom', () {
        expect(isCustomProfilePhoto(photo), isFalse);
      });
    }
  });

  test('one Google photo at two sizes is the same photo; another photo is not', () {
    expect(
      isSamePhoto('https://lh3.googleusercontent.com/a/old=s96-c', 'https://lh3.googleusercontent.com/a/old=s1337'),
      isTrue,
    );
    expect(isSamePhoto(_oldGooglePhoto, _newGooglePhoto), isFalse);
    expect(isSamePhoto(null, ''), isTrue);
  });

  test('a Google photo is asked for at 400 px', () {
    expect(
      sizedGooglePhoto('https://lh3.googleusercontent.com/a/me=s1337'),
      'https://lh3.googleusercontent.com/a/me=s400-c',
    );
    expect(
      sizedGooglePhoto(' https://lh3.googleusercontent.com/a/me=s96-c'),
      'https://lh3.googleusercontent.com/a/me=s400-c',
    );
    expect(sizedGooglePhoto(null), isNull);
    expect(sizedGooglePhoto(''), isNull);
  });

  test('a blank photo is the placeholder', () {
    expect(photoOrPlaceholder(null), defaultProfilePhotoUrl);
    expect(photoOrPlaceholder(' '), defaultProfilePhotoUrl);
    expect(photoOrPlaceholder(_newGooglePhoto), _newGooglePhoto);
  });

  group('googleProfileUpdates', () {
    Map<String, String> updates({
      required String name,
      required String photo,
      String? lastGoogleName = 'Old Name',
      String googleName = 'New Name',
      String googlePhoto = _newGooglePhoto,
    }) => googleProfileUpdates(
      profileUser(profilePhoto: photo)..name = name,
      lastGoogleName: lastGoogleName,
      googleName: googleName,
      googlePhotoUrl: googlePhoto,
    );

    test('a name and photo that came from Google follow Google', () {
      expect(updates(name: 'Old Name', photo: _oldGooglePhoto), <String, String>{
        'name': 'New Name',
        'profilePhoto': _newGooglePhoto,
      });
    });

    test('a name and photo that the user set in Prism stay', () {
      expect(updates(name: 'My Prism Name', photo: _customPhoto), isEmpty);
    });

    test('a name stays when no Google name was saved', () {
      expect(updates(name: 'Old Name', photo: _newGooglePhoto, lastGoogleName: null), isEmpty);
    });

    test('a profile with no photo takes the Google photo', () {
      expect(updates(name: 'New Name', photo: defaultProfilePhotoUrl), <String, String>{
        'profilePhoto': _newGooglePhoto,
      });
    });

    test('a Google photo goes back to no photo when Google has none', () {
      expect(updates(name: 'New Name', photo: _oldGooglePhoto, googlePhoto: defaultProfilePhotoUrl), <String, String>{
        'profilePhoto': defaultProfilePhotoUrl,
      });
    });

    test('nothing changes when Google gives the same photo at another size', () {
      expect(
        updates(name: 'New Name', photo: 'https://lh3.googleusercontent.com/a/new=s96-c', lastGoogleName: 'New Name'),
        isEmpty,
      );
    });
  });
}
