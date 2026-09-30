import 'package:Prism/core/constants/profile_links.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile link kinds are unique and sorted by name', () {
    final List<String> names = profileLinkKinds.map((kind) => kind.name).toList();
    expect(names.toSet().length, names.length);
    expect(names, [...names]..sort());
  });

  test('custom link kind exists and accepts any value', () {
    final ProfileLinkKind custom = profileLinkKinds.firstWhere((kind) => kind.name == customLinkName);
    expect(custom.validator, isEmpty);
  });

  test('profileLinkIcon falls back to the link icon for unknown names', () {
    expect(profileLinkIcon('github'), JamIcons.github);
    expect(profileLinkIcon('not-a-network'), JamIcons.link);
  });
}
