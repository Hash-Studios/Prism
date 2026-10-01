package io.flutter.plugins.firebase.functions

import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.FirebaseApp
import com.google.firebase.functions.FirebaseFunctionsException
import com.google.firebase.functions.HttpsCallableOptions
import com.google.firebase.functions.HttpsCallableReference
import android.util.SparseArray
import android.text.TextUtils
import com.google.firebase.functions.StreamResponse
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import org.junit.Assert.*
import org.junit.Test
import org.junit.After
import org.mockito.Mockito
import org.reactivestreams.Publisher
import org.reactivestreams.Subscription
import java.net.URL
import java.util.Locale
import java.util.concurrent.TimeUnit

private fun <T : Any> eq(value: T): T = Mockito.eq(value) ?: value
private fun anyOptions(): HttpsCallableOptions =
  Mockito.any(HttpsCallableOptions::class.java) ?: HttpsCallableOptions.Builder().build()

private const val ERROR_DOMAIN = "firebase_functions"
private const val MESSAGE_KEY = "message"
private const val LIMITED_USE_TOKEN_KEY = "limitedUseAppCheckToken"

internal class FunctionsNativeTest {
  private val sparseArrays = Mockito.mockConstruction(SparseArray::class.java)
  private val textUtils = Mockito.mockStatic(TextUtils::class.java).apply {
    `when`<Boolean> { TextUtils.isEmpty(Mockito.any()) }.thenAnswer {
      it.getArgument<CharSequence?>(0).isNullOrEmpty()
    }
  }

  @After internal fun closeAndroidMocks() {
    textUtils.close()
    sparseArrays.close()
  }

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

  @Test internal fun firebaseErrorsKeepCodeAndDetailsAcrossLocales() {
    val previous = Locale.getDefault()
    try {
      Locale.setDefault(Locale.forLanguageTag("tr-TR"))
      val exception = FirebaseFunctionsTestValues.error(
        "Denied", FirebaseFunctionsException.Code.PERMISSION_DENIED, mapOf("reason" to "premium"))
      val error = functionsError(exception)
      assertEquals(ERROR_DOMAIN, error.code)
      assertEquals(mapOf(
        "code" to "permission-denied", MESSAGE_KEY to "Denied",
        "additionalData" to mapOf("reason" to "premium")
      ), error.details)
    } finally {
      Locale.setDefault(previous)
    }
  }

  @Test internal fun streamFailuresAreErrorsAndCloseExactlyOnce() {
    val sink = Sink()
    val subscriber = StreamResponseSubscriber(sink) { it() }
    val exception = FirebaseFunctionsTestValues.error(
      "Sign in", FirebaseFunctionsException.Code.UNAUTHENTICATED, null)
    subscriber.onError(exception)
    subscriber.onComplete()
    assertEquals(ERROR_DOMAIN, sink.errorCode)
    assertEquals(mapOf("code" to "unauthenticated", MESSAGE_KEY to "Sign in"), sink.errorDetails)
    assertEquals(1, sink.endings)
  }

  @Test internal fun successfulStreamsPreserveMessageResultAndCompletionOrder() {
    val sink = Sink()
    val pending = mutableListOf<() -> Unit>()
    val subscriber = StreamResponseSubscriber(sink) { pending += it }
    val message = FirebaseFunctionsTestValues.result(mapOf("text" to "hello"))
    val result = FirebaseFunctionsTestValues.result(null)
    subscriber.onNext(StreamResponse.Message(message))
    subscriber.onNext(StreamResponse.Result(result))
    subscriber.onComplete()
    pending.forEach { it() }
    assertEquals(listOf(mapOf(MESSAGE_KEY to mapOf("text" to "hello")), mapOf("result" to null)), sink.values)
    assertEquals(1, sink.endings)
    assertNull(sink.errorCode)
  }

  @Test internal fun cancellationDropsQueuedEventsAndCancelsLateSubscriptions() {
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

  @Test internal fun urlStreamsKeepParametersAndConfigureTimeoutBeforeStarting() {
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
        LIMITED_USE_TOKEN_KEY to false, "timeout" to 5_000_000_000L,
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

  @Test internal fun malformedTimeoutAndOptionsFailBeforeCallingFirebase() {
    val functions = Mockito.mock(FirebaseFunctions::class.java)
    val reference = Mockito.mock(HttpsCallableReference::class.java)
    Mockito.`when`(functions.getHttpsCallable(eq("wall"), anyOptions()))
      .thenReturn(reference)
    for (timeout in listOf<Any>(true, 1.5, Double.NaN, -1L, 0)) {
      assertThrows(IllegalArgumentException::class.java) {
        functions.callable(mapOf(
          "functionName" to "wall", LIMITED_USE_TOKEN_KEY to false, "timeout" to timeout
        ))
      }
    }
    assertThrows(IllegalArgumentException::class.java) {
      functions.callable(mapOf("functionName" to "wall", LIMITED_USE_TOKEN_KEY to 1))
    }
    Mockito.verify(reference, Mockito.never()).stream(Mockito.any())
  }

  @Test internal fun malformedUrlsReturnInvalidArgumentWithoutCallingFirebase() {
    val functions = Mockito.mock(FirebaseFunctions::class.java)
    for (url in listOf("not-a-url", "ftp://example.com/file", "https://user:pass@example.com/call",
      "http://example.com:0/call")) {
      val error = assertThrows(IllegalArgumentException::class.java) {
        functions.callable(mapOf("functionUri" to url, LIMITED_USE_TOKEN_KEY to false))
      }
      val details = functionsError(error).details as Map<*, *>
      assertEquals("invalid-argument", details["code"])
    }
    Mockito.verifyNoInteractions(functions)
  }

  @Test internal fun invalidStreamArgumentsReachTheErrorSinkAndClose() {
    val functions = Mockito.mock(FirebaseFunctions::class.java)
    val sink = Sink()
    val handler = FirebaseFunctionsStreamHandler(functions)
    handler.onListen(null, sink)
    assertEquals(ERROR_DOMAIN, sink.errorCode)
    assertEquals(mapOf("code" to "invalid-argument", MESSAGE_KEY to "Stream arguments must be a map"), sink.errorDetails)
    assertEquals(1, sink.endings)
    handler.onCancel(null)
    Mockito.verifyNoInteractions(functions)
  }

  @Test internal fun cancellingReplacedStreamKeepsTheCurrentChannel() {
    val functions = Mockito.mock(FirebaseFunctions::class.java)
    val app = Mockito.mock(FirebaseApp::class.java)
    FirebaseFunctionsTestValues.install(app, functions)
    val binding = Mockito.mock(FlutterPluginBinding::class.java)
    Mockito.`when`(binding.binaryMessenger).thenReturn(Mockito.mock(BinaryMessenger::class.java))
    Mockito.mockStatic(FirebaseApp::class.java).use { apps ->
      apps.`when`<FirebaseApp> { FirebaseApp.getInstance("app") }.thenReturn(app)
      Mockito.mockConstruction(EventChannel::class.java).use { channels ->
        val plugin = FlutterFirebaseFunctionsPlugin()
        plugin.onAttachedToEngine(binding)
        val arguments = mapOf("eventChannelId" to "same", "appName" to "app", "region" to "region")
        plugin.registerEventChannel(arguments) { assertTrue(it.isSuccess) }
        plugin.registerEventChannel(arguments) { assertTrue(it.isSuccess) }
        val previous = channels.constructed()[0]
        val current = channels.constructed()[1]
        val previousHandler = Mockito.mockingDetails(previous).invocations
          .first { it.method.name == "setStreamHandler" }.arguments[0] as FirebaseFunctionsStreamHandler
        val currentHandler = Mockito.mockingDetails(current).invocations
          .first { it.method.name == "setStreamHandler" }.arguments[0] as FirebaseFunctionsStreamHandler
        previousHandler.onCancel(arguments)
        Mockito.verify(current, Mockito.never()).setStreamHandler(null)
        currentHandler.onCancel(arguments)
        Mockito.verify(current).setStreamHandler(null)
        plugin.onDetachedFromEngine(binding)
      }
    }
  }

  @Test internal fun dispatcherRestartPreservesChannelUntilExplicitCancellation() {
    val functions = Mockito.mock(FirebaseFunctions::class.java)
    val reference = Mockito.mock(HttpsCallableReference::class.java)
    Mockito.`when`(functions.getHttpsCallable(eq("wall"), anyOptions())).thenReturn(reference)
    Mockito.`when`(reference.stream(Mockito.any())).thenReturn(Publisher<StreamResponse> { })
    val app = Mockito.mock(FirebaseApp::class.java)
    FirebaseFunctionsTestValues.install(app, functions)
    val messenger = Mockito.mock(BinaryMessenger::class.java)
    val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler>()
    Mockito.doAnswer {
      val name = it.getArgument<String>(0)
      val handler = it.getArgument<BinaryMessenger.BinaryMessageHandler?>(1)
      if (handler == null) handlers.remove(name) else handlers[name] = handler
      null
    }.`when`(messenger).setMessageHandler(Mockito.anyString(), Mockito.any())
    val binding = Mockito.mock(FlutterPluginBinding::class.java)
    Mockito.`when`(binding.binaryMessenger).thenReturn(messenger)
    val channelName = "plugins.flutter.io/firebase_functions/restart"
    val arguments = mapOf("functionName" to "wall", LIMITED_USE_TOKEN_KEY to false)
    fun send(method: String) {
      val message = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, arguments))
      message.flip()
      var replied = false
      checkNotNull(handlers[channelName]).onMessage(message) { reply ->
        checkNotNull(reply).flip()
        assertNull(StandardMethodCodec.INSTANCE.decodeEnvelope(reply))
        replied = true
      }
      assertTrue(replied)
    }
    Mockito.mockStatic(FirebaseApp::class.java).use { apps ->
      apps.`when`<FirebaseApp> { FirebaseApp.getInstance("app") }.thenReturn(app)
      Mockito.mockConstruction(StreamResponseSubscriber::class.java).use { subscribers ->
        val plugin = FlutterFirebaseFunctionsPlugin()
        plugin.onAttachedToEngine(binding)
        plugin.registerEventChannel(mapOf(
          "eventChannelId" to "restart", "appName" to "app", "region" to "region"
        )) { assertTrue(it.isSuccess) }
        send("listen")
        send("listen")
        assertEquals(2, subscribers.constructed().size)
        Mockito.verify(subscribers.constructed()[0]).cancel()
        Mockito.verify(subscribers.constructed()[1], Mockito.never()).cancel()
        assertNotNull(handlers[channelName])
        send("cancel")
        Mockito.verify(subscribers.constructed()[1]).cancel()
        assertNull(handlers[channelName])
        plugin.onDetachedFromEngine(binding)
      }
    }
  }
}
