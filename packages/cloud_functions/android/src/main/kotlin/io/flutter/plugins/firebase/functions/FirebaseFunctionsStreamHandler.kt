// Copyright 2025 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package io.flutter.plugins.firebase.functions

import com.google.firebase.functions.FirebaseFunctions
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

internal class FirebaseFunctionsStreamHandler(
  private val functions: FirebaseFunctions,
  private val onCancelled: (FirebaseFunctionsStreamHandler) -> Unit = {}
) : EventChannel.StreamHandler {
  private var subscriber: StreamResponseSubscriber? = null

  override fun onListen(arguments: Any?, events: EventSink) {
    cancel()
    try {
      val values = arguments as? Map<*, *>
        ?: throw IllegalArgumentException("Stream arguments must be a map")
      val listener = StreamResponseSubscriber(events)
      subscriber = listener
      functions.callable(values).stream(values["parameters"]).subscribe(listener)
    } catch (error: Exception) {
      cancel()
      val flutterError = functionsError(error)
      events.error(flutterError.code, flutterError.message, flutterError.details)
      events.endOfStream()
    }
  }

  override fun onCancel(arguments: Any?) {
    cancel()
    if (arguments != null) onCancelled(this)
  }

  internal fun cancel() {
    subscriber?.cancel()
    subscriber = null
  }
}
