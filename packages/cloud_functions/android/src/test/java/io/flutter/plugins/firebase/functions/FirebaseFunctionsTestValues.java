package io.flutter.plugins.firebase.functions;

import com.google.firebase.functions.FirebaseFunctionsException;
import com.google.firebase.functions.HttpsCallableResult;

// Firebase marks these JVM-public constructors internal in its Kotlin metadata.
final class FirebaseFunctionsTestValues {
  static FirebaseFunctionsException error(
      String message, FirebaseFunctionsException.Code code, Object details) {
    return new FirebaseFunctionsException(message, code, details);
  }

  static HttpsCallableResult result(Object data) {
    return new HttpsCallableResult(data);
  }
}
