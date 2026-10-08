import 'package:Prism/core/widgets/popup/edit_profile_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upload names carry the user id and a timestamp so two uploads never share a path', () {
    expect(uploadFileName('uid1', 'photo.jpg', epochMs: 1700000000000), 'uid1_1700000000000_photo.jpg');
    expect(uploadFileName('uid1', 'photo.jpg', epochMs: 1), isNot(uploadFileName('uid2', 'photo.jpg', epochMs: 1)));
    expect(uploadFileName('uid1', 'photo.jpg', epochMs: 1), isNot(uploadFileName('uid1', 'photo.jpg', epochMs: 2)));
  });
}
