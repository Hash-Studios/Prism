import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDocument {
  const FirestoreDocument(this.id, this.payload);

  final String id;
  final Map<String, dynamic> payload;

  String get by => _string('by');
  DateTime? get createdAt => _dateTime('created_at') ?? _dateTime('createdAt');
  String get desc => _string('desc');
  String get email => _string('email');
  String get userPhoto => _string('userPhoto');
  String get wallpaperProvider => _string('wallpaper_provider');
  String get wallpaperThumb => _string('wallpaper_thumb');
  String get wallpaperUrl => _string('wallpaper_url');
  bool get review => _bool('review');
  String get resolution => _string('resolution');
  String get size => _string('size');
  List<String> get collections => _stringList('collections');

  Map<String, dynamic> data() => payload;

  String _string(String key) => payload[key]?.toString() ?? '';

  bool _bool(String key) {
    final value = payload[key];
    if (value is bool) {
      return value;
    }
    return value?.toString().toLowerCase() == 'true';
  }

  DateTime? _dateTime(String key) {
    final value = payload[key];
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  List<String> _stringList(String key) {
    final value = payload[key];
    if (value is List) {
      return value.map((entry) => entry?.toString() ?? '').where((entry) => entry.isNotEmpty).toList(growable: false);
    }
    return const <String>[];
  }
}
