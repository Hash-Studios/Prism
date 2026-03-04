import 'package:Prism/core/wallpaper/wallpaper_source.dart';

abstract interface class FirestoreCodec<T> {
  T decode(JsonMap data, String docId);
  JsonMap encode(T value);
}
