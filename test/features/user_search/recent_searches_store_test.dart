import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/features/user_search/views/recent_searches_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late RecentSearchesStore recents;

  setUp(() {
    store = InMemoryLocalStore();
    recents = RecentSearchesStore(SettingsLocalDataSource(store));
  });

  test('starts empty', () {
    expect(recents.read(), isEmpty);
  });

  test('keeps newest first and ignores blank queries', () async {
    await recents.add('forest');
    await recents.add('  ');
    await recents.add('  ocean ');

    expect(recents.read(), <String>['ocean', 'forest']);
  });

  test('a repeat, ignoring case, moves to the front instead of duplicating', () async {
    await recents.add('Forest');
    await recents.add('ocean');
    await recents.add('forest');

    expect(recents.read(), <String>['forest', 'ocean']);
  });

  test('keeps only the last 10', () async {
    for (var i = 0; i < 12; i++) {
      await recents.add('query $i');
    }

    final List<String> items = recents.read();
    expect(items, hasLength(10));
    expect(items.first, 'query 11');
    expect(items.last, 'query 2');
  });

  test('clear removes everything', () async {
    await recents.add('forest');
    await recents.clear();

    expect(recents.read(), isEmpty);
  });

  test('a corrupt stored value reads as empty', () {
    store.data[PersistenceKeys.settings(PersistenceKeys.recentSearches)] = 'not json';

    expect(recents.read(), isEmpty);
  });
}
