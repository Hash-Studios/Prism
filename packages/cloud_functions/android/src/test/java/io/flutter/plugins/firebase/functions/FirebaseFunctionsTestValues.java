package io.flutter.plugins.firebase.functions;

import com.google.firebase.functions.FirebaseFunctionsException;
import com.google.firebase.functions.HttpsCallableResult;
import com.google.firebase.FirebaseApp;
import com.google.firebase.functions.FirebaseFunctions;
import com.google.firebase.functions.FunctionsMultiResourceComponent;
import org.mockito.Mockito;

// Firebase marks these JVM-public constructors internal in its Kotlin metadata.
final class FirebaseFunctionsTestValues {
  static FirebaseFunctionsException error(
      String message, FirebaseFunctionsException.Code code, Object details) {
    return new FirebaseFunctionsException(message, code, details);
  }

  static HttpsCallableResult result(Object data) {
    return new HttpsCallableResult(data);
  }

  static void install(FirebaseApp app, FirebaseFunctions functions) {
    FunctionsMultiResourceComponent component = Mockito.mock(FunctionsMultiResourceComponent.class);
    Mockito.when(component.get("region")).thenReturn(functions);
    Mockito.when(app.get(FunctionsMultiResourceComponent.class)).thenReturn(component);
  }
}
