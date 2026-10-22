import 'package:Prism/features/ai_wallpaper/views/ai_wallpaper_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI2 identity retains the random suffix and adjacent milliseconds and is stable on replay', () {
    const String generation = 'gen_mlt7o22q_7a9688a037a47de6';
    expect(aiCommunityId(generation), 'AI2B83C297CF7C420FF33FA03823705EA95');
    expect(aiCommunityId('gen_mlt7o22q_7a9688a037a47de7'), 'AI22E20D7B46808AF6BEAD11C9F882793C6');
    expect(aiCommunityId('gen_mlt7o22r_7a9688a037a47de6'), 'AI24018382BFB4145D280FAE86BEE02B71A');
    expect(aiCommunityId(generation), 'AI2B83C297CF7C420FF33FA03823705EA95');
  });
}
