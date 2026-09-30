import 'dart:math';

/// A random upload id of [length] characters: capital letters with one digit at a random position.
String randomUploadId(int length, {Random? random}) {
  final Random r = random ?? Random();
  final int digitAt = r.nextInt(length);
  return String.fromCharCodes(
    List<int>.generate(length, (int i) => i == digitAt ? 0x30 + r.nextInt(10) : 0x41 + r.nextInt(26)),
  );
}
