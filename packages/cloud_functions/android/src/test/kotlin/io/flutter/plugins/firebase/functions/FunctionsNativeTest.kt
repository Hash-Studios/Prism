package io.flutter.plugins.firebase.functions

import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.FirebaseFunctionsException
import com.google.firebase.functions.HttpsCallableOptions
import com.google.firebase.functions.HttpsCallableReference
import android.util.SparseArray
import android.text.TextUtils
import com.google.firebase.functions.StreamResponse
import io.flutter.plugin.common.EventChannel.EventSink
import org.junit.Assert.*
import org.junit.Test
import org.junit.After
import org.mockito.Mockito
import org.reactivestreams.Publisher
import org.reactivestreams.Subscription
import java.net.URL
import java.util.Locale
import java.util.concurrent.TimeUnit

class FunctionsNativeTest {
  private val sparseArrays = Mockito.mockConstruction(SparseArray::class.java)
  private val textUtils = Mockito.mockStatic(TextUtils::class.java).apply {
    `when`<Boolean> { TextUtils.isEmpty(Mockito.any()) }.thenAnswer {
      it.getArgument<CharSequence?>(0).isNullOrEmpty()
    }
  }

  @After fun closeAndroidMocks() {
    textUtils.close()
    sparseArrays.close()
  }

  private fun <T : Any> eq(value: T): T = Mockito.eq(value) ?: value
  private fun anyOptions(): HttpsCallableOptions =
    Mockito.any(HttpsCallableOptions::class.java) ?: HttpsCallableOptions.Builder().build()
  private class Sink : EventSink {
    val values = mutableListOf<Any?>()
    var errorCode: String? = null
    var errorDetails: Any? = null
    var endings = 0
    override fun success(event: Any?) { values += event }
    override fun error(code: String, message: String?, details: Any?) {
      errorCode = code
      errorDetails = details
    }
    override fun endOfStream() { endings++ }
  }

  @Test fun firebaseErrorsKeepCodeAndDetailsAcrossLocales() {
    val previous = Locale.getDefault()
    try {
      Locale.setDefault(Locale.forLanguageTag("tr-TR"))
      val exception = FirebaseFunctionsTestValues.error(
        "Denied", FirebaseFunctionsException.Code.PERMISSION_DENIED, mapOf("reason" to "premium"))
      val error = functionsError(exception)
      assertEquals("firebase_functions", error.code)
      assertEquals(mapOf(
        "code" to "permission-denied", "message" to "Denied",
        "additionalData" to mapOf("reason" to "premium")
      ), error.details)
    } finally {
      Locale.setDefault(previous)
    }
  }

  @Test fun streamFailuresAreErrorsAndCloseExactlyOnce() {
    val sink = Sink()
    val subscriber = StreamResponseSubscriber(sink) { it() }
    val exception = FirebaseFunctionsTestValues.error(
      "Sign in", FirebaseFunctionsException.Code.UNAUTHENTICATED, null)
    subscriber.onError(exception)
    subscriber.onComplete()
    assertEquals("firebase_functions", sink.errorCode)
    assertEquals(mapOf("code" to "unauthenticated", "message" to "Sign in"), sink.errorDetails)
    assertEquals(1, sink.endings)
  }

  @Test fun successfulStreamsPreserveMessageResultAndCompletionOrder() {
    val sink = Sink()
    val pending = mutableListOf<() -> Unit>()
    val subscriber = StreamResponseSubscriber(sink) { pending += it }
    val message = FirebaseFunctionsTestValues.result(mapOf("text" to "hello"))
    val result = FirebaseFunctionsTestValues.result(null)
    subscriber.onNext(StreamResponse.Message(message))
    subscriber.onNext(StreamResponse.Result(result))
    subscriber.onComplete()
    pending.forEach { it() }
    assertEquals(listOf(mapOf("message" to mapOf("text" to "hello")), mapOf("result" to null)), sink.values)
    assertEquals(1, sink.endings)
    assertNull(sink.errorCode)
  }

  @Test fun cancellationDropsQueuedEventsAndCancelsLateSubscriptions() {
    val sink = Sink()
    val pending = mutableListOf<() -> Unit>()
    val subscriber = StreamResponseSubscriber(sink) { pending += it }
    subscriber.onError(IllegalStateException("network"))
    subscriber.cancel()
    pending.forEach { it() }
    val subscription = Mockito.mock(Subscription::class.java)
    subscriber.onSubscribe(subscription)
    Mockito.verify(subscription).cancel()
    Mockito.verify(subscription, Mockito.never()).request(Mockito.anyLong())
    assertNull(sink.errorCode)
    assertEquals(0, sink.endings)
  }

  @Test fun urlStreamsKeepParametersAndConfigureTimeoutBeforeStarting() {
    val functions = Mockito.mock(FirebaseFunctions::class.java)
    val reference = Mockito.mock(HttpsCallableReference::class.java)
    Mockito.`when`(functions.getHttpsCallableFromUrl(
      eq(URL("https://example.com/call")), anyOptions()))
      .thenReturn(reference)
    val publisher = Publisher<StreamResponse> { }
    val parameters = mapOf("prompt" to "mountains")
    Mockito.`when`(reference.stream(parameters)).thenReturn(publisher)
    Mockito.mockConstruction(StreamResponseSubscriber::class.java).use { mocked ->
      val handler = FirebaseFunctionsStreamHandler(functions)
      handler.onListen(mapOf(
        "functionUri" to "https://example.com/call",
        "limitedUseAppCheckToken" to false, "timeout" to 5_000_000_000L,
        "parameters" to parameters
      ), Sink())
      val ordered = Mockito.inOrder(reference)
      ordered.verify(reference).setTimeout(5_000_000_000L, TimeUnit.MILLISECONDS)
      ordered.verify(reference).stream(parameters)
      handler.onCancel(null)
      handler.onCancel(null)
      assertEquals(1, mocked.constructed().size)
      Mockito.verify(mocked.constructed().single()).cancel()
    }
  }

  @Test fun malformedTimeoutAndOptionsFailBeforeCallingFirebase() {
    val functions = Mockito.mock(FirebaseFunctions::class.java)
    val reference = Mockito.mock(HttpsCallableReference::class.java)
    Mockito.`when`(functions.getHttpsCallable(eq("wall"), anyOptions()))
      .thenReturn(reference)
    for (timeout in listOf<Any>(true, 1.5, Double.NaN, -1L, 0)) {
      assertThrows(IllegalArgumentException::class.java) {
        functions.callable(mapOf(
          "functionName" to "wall", "limitedUseAppCheckToken" to false, "timeout" to timeout
        ))
      }
    }
    assertThrows(IllegalArgumentException::class.java) {
      functions.callable(mapOf("functionName" to "wall", "limitedUseAppCheckToken" to 1))
    }
    Mockito.verify(reference, Mockito.never()).stream(Mockito.any())
  }

  @Test fun malformedUrlsReturnInvalidArgumentWithoutCallingFirebase() {
    val functions = Mockito.mock(FirebaseFunctions::class.java)
    for (url in listOf("not-a-url", "ftp://example.com/file", "https://user:pass@example.com/call",
      "http://example.com:0/call")) {
      val error = assertThrows(IllegalArgumentException::class.java) {
        functions.callable(mapOf("functionUri" to url, "limitedUseAppCheckToken" to false))
      }
      val details = functionsError(error).details as Map<*, *>
      assertEquals("invalid-argument", details["code"])
    }
    Mockito.verifyNoInteractions(functions)
  }

  @Test fun invalidStreamArgumentsReachTheErrorSinkAndClose() {
    val functions = Mockito.mock(FirebaseFunctions::class.java)
    val sink = Sink()
    val handler = FirebaseFunctionsStreamHandler(functions)
    handler.onListen(null, sink)
    assertEquals("firebase_functions", sink.errorCode)
    assertEquals(mapOf("code" to "invalid-argument", "message" to "Stream arguments must be a map"), sink.errorDetails)
    assertEquals(1, sink.endings)
    handler.onCancel(null)
    Mockito.verifyNoInteractions(functions)
  }
}
