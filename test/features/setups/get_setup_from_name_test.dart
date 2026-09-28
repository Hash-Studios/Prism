import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/setups/views/setups_bloc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingClient implements FirestoreClient {
  FirestoreQuerySpec? spec;

  @override
  Future<List<T>> query<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic> data, String docId) map) async {
    this.spec = spec;
    return <T>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('setup link lookup only asks for reviewed setups, which the rules allow', () async {
    final client = _RecordingClient();

    await getSetupFromName('BLOODLAND', client: client);

    final filters = client.spec!.filters.map((f) => '${f.field} ${f.op.name} ${f.value}').toList();
    expect(filters, containsAll(<String>['name isEqualTo BLOODLAND', 'review isEqualTo true']));
  });
}
