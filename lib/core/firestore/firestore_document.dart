class FirestoreDocument {
  const FirestoreDocument(this.id, this.payload);

  final String id;
  final Map<String, dynamic> payload;

  Map<String, dynamic> data() => payload;
  dynamic operator [](String key) => payload[key];
}
