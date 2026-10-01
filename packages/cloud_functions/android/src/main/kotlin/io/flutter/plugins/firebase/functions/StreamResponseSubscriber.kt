// Copyright 2025 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package io.flutter.plugins.firebase.functions

import android.os.Handler
import android.os.Looper
import com.google.firebase.functions.StreamResponse
import io.flutter.plugin.common.EventChannel.EventSink
import org.reactivestreams.Subscriber
import org.reactivestreams.Subscription
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class StreamResponseSubscriber(
  private val eventSink: EventSink,
  private val dispatch: (() -> Unit) -> Unit = Handler(Looper.getMainLooper()).let { handler ->
    { action -> handler.post(action); Unit }
  }
) : Subscriber<StreamResponse> {
  private val subscription = AtomicReference<Subscription?>()
  private val cancelled = AtomicBoolean(false)
  private val finished = AtomicBoolean(false)

  override fun onSubscribe(value: Subscription) {
    if (!subscription.compareAndSet(null, value) || cancelled.get()) {
      value.cancel()
      return
    }
    value.request(Long.MAX_VALUE)
  }

  override fun onNext(response: StreamResponse) {
    if (finished.get() || cancelled.get()) return
    val data = when (response) {
      is StreamResponse.Message -> mapOf("message" to response.message.data)
      is StreamResponse.Result -> mapOf("result" to response.result.data)
      else -> {
        onError(IllegalStateException("Unsupported streaming response"))
        return
      }
    }
    dispatch { if (!cancelled.get()) eventSink.success(data) }
  }

  override fun onError(error: Throwable) {
    if (!finished.compareAndSet(false, true)) return
    val flutterError = functionsError(error)
    dispatch {
      if (!cancelled.get()) {
        eventSink.error(flutterError.code, flutterError.message, flutterError.details)
        eventSink.endOfStream()
      }
    }
  }

  override fun onComplete() {
    if (!finished.compareAndSet(false, true)) return
    dispatch { if (!cancelled.get()) eventSink.endOfStream() }
  }

  fun cancel() {
    cancelled.set(true)
    subscription.getAndSet(null)?.cancel()
  }
}
