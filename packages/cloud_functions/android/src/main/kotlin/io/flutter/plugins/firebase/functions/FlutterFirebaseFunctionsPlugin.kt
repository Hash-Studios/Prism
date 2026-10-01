// Copyright 2025 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package io.flutter.plugins.firebase.functions

import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.functions.FirebaseFunctions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugins.firebase.core.FlutterFirebasePlugin

class FlutterFirebaseFunctionsPlugin : FlutterPlugin, FlutterFirebasePlugin, CloudFunctionsHostApi {
  private var messenger: BinaryMessenger? = null
  private val streams = mutableMapOf<String, Pair<EventChannel, FirebaseFunctionsStreamHandler>>()

  override fun onAttachedToEngine(binding: FlutterPluginBinding) {
    messenger = binding.binaryMessenger
    CloudFunctionsHostApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
    CloudFunctionsHostApi.setUp(binding.binaryMessenger, null)
    streams.values.toList().forEach { (channel, handler) ->
      handler.cancel()
      channel.setStreamHandler(null)
    }
    streams.clear()
    messenger = null
  }

  private fun getFunctions(arguments: Map<*, *>): FirebaseFunctions =
    FirebaseFunctions.getInstance(
      FirebaseApp.getInstance(arguments.requiredString("appName")),
      arguments.requiredString("region")
    )

  override fun getPluginConstantsForFirebaseApp(firebaseApp: FirebaseApp): Task<Map<String, Any>> =
    Tasks.forResult(emptyMap())

  override fun didReinitializeFirebaseCore(): Task<Void> = Tasks.forResult(null)

  override fun call(arguments: Map<String, Any?>, callback: (Result<Any?>) -> Unit) {
    try {
      getFunctions(arguments).callable(arguments).call(arguments["parameters"])
        .addOnCompleteListener { task ->
          if (task.isSuccessful) {
            callback(Result.success(task.result.data))
          } else {
            callback(Result.failure(functionsError(task.exception ?: IllegalStateException("Call cancelled"))))
          }
        }
    } catch (error: Exception) {
      callback(Result.failure(functionsError(error)))
    }
  }

  override fun registerEventChannel(arguments: Map<String, Any>, callback: (Result<Unit>) -> Unit) {
    try {
      val eventId = arguments.requiredString("eventChannelId")
      val binaryMessenger = checkNotNull(messenger) { "Plugin is detached" }
      val functions = getFunctions(arguments)
      streams.remove(eventId)?.let { (channel, handler) ->
        handler.cancel()
        channel.setStreamHandler(null)
      }
      val channel = EventChannel(binaryMessenger, "$METHOD_CHANNEL_NAME/$eventId")
      val handler = FirebaseFunctionsStreamHandler(functions) {
        streams.remove(eventId)?.first?.setStreamHandler(null)
      }
      streams[eventId] = channel to handler
      channel.setStreamHandler(handler)
      callback(Result.success(Unit))
    } catch (error: Exception) {
      callback(Result.failure(functionsError(error)))
    }
  }

  companion object {
    private const val METHOD_CHANNEL_NAME = "plugins.flutter.io/firebase_functions"
  }
}
