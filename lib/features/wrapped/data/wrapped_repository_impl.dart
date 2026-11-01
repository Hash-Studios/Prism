import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: WrappedRepository)
class WrappedRepositoryImpl implements WrappedRepository {
  WrappedRepositoryImpl(this._client);

  final FirestoreClient _client;

  @override
  Future<WrappedYear?> fetch(String uid, int year) async {
    final Map<String, dynamic>? data = await _client.getById<Map<String, dynamic>>(
      'wrapped/$uid/years',
      '$year',
      (data, _) => data,
      sourceTag: 'wrapped.fetch',
    );
    return data == null ? null : parseWrappedYear(data, year: year);
  }
}
