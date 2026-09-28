import 'package:Prism/auth/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sign-up usernames follow the edit profile rule: no spaces or punctuation', () {
    expect(sanitizeUsername('Test Akshay'), 'TestAkshay');
    expect(sanitizeUsername("Sam O'Neil-Smith"), 'SamONeilSmith');
    expect(sanitizeUsername('already_ok_99'), 'already_ok_99');
  });
}
