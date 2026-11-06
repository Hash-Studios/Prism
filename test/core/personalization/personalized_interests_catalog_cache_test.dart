import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  test('a catalog cached before the cover fix is ignored, so the corrected default covers show', () async {
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    await settings.set(
      'personalized_interests_catalog_v1',
      '[{"name":"Fantasy","query":"fantasy","imageUrl":"https://images.pexels.com/photos/3075993/old.jpeg",'
          '"sources":["pexels"]}]',
    );

    final List<PersonalizedInterest> catalog = await PersonalizedInterestsCatalog.load(
      remoteConfig: null,
      settingsLocal: settings,
    );

    expect(
      catalog.singleWhere((interest) => interest.name == 'Fantasy').imageUrl,
      'https://images.pexels.com/photos/8415664/pexels-photo-8415664.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940',
    );
  });
}
