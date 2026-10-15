// Copyright 2025 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package io.flutter.plugins.firebase.functions

import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.FirebaseFunctionsException
import com.google.firebase.functions.HttpsCallableOptions
import com.google.firebase.functions.HttpsCallableReference
import java.io.IOException
import java.io.InterruptedIOException
import java.net.URL
import java.util.Locale
import java.util.concurrent.TimeUnit

internal fun Map<*, *>.requiredString(key: String): String =
  (this[key] as? String)?.takeIf { it.isNotEmpty() }
    ?: throw IllegalArgumentException("$key must be a non-empty string")

private fun Map<*, *>.optionalString(key: String): String? =
  if (this[key] == null) null else requiredString(key)

private fun httpUrl(value: String, key: String): URL {
  val url = try {
    URL(value)
  } catch (error: java.net.MalformedURLException) {
    throw IllegalArgumentException("$key must be an HTTP URL", error)
  }
  require(url.protocol in listOf("http", "https") && url.host.isNotEmpty() &&
    url.userInfo == null && (url.port == -1 || url.port in 1..65535)) {
    "$key must be an HTTP URL"
  }
  return url
}

internal fun FirebaseFunctions.callable(arguments: Map<*, *>): HttpsCallableReference {
  val origin = arguments.optionalString("origin")?.let { httpUrl(it, "origin") }
  require(origin == null || origin.port in 1..65535) {
    "origin must include a valid port"
  }
  val limitedUse = arguments["limitedUseAppCheckToken"] as? Boolean
    ?: throw IllegalArgumentException("limitedUseAppCheckToken must be a boolean")
  val name = arguments.optionalString("functionName")
  val uri = arguments.optionalString("functionUri")
  val url = if (name == null && uri != null) httpUrl(uri, "functionUri") else null
  require(name != null || url != null) { "Either functionName or functionUri must be set" }
  val timeout = arguments["timeout"]?.let {
    val value = when (it) {
      is Int -> it.toLong()
      is Long -> it
      else -> throw IllegalArgumentException("timeout must be an integer")
    }
    require(value > 0) { "timeout must be positive" }
    value
  }

  origin?.let { useEmulator(it.host, it.port) }
  val options = HttpsCallableOptions.Builder().setLimitedUseAppCheckTokens(limitedUse).build()
  val callable = when {
    name != null -> getHttpsCallable(name, options)
    url != null -> getHttpsCallableFromUrl(url, options)
    else -> throw IllegalArgumentException("Either functionName or functionUri must be set")
  }
  timeout?.let { callable.setTimeout(it, TimeUnit.MILLISECONDS) }
  return callable
}

internal fun functionsError(error: Throwable): FlutterError {
  val functionsException = generateSequence(error) { it.cause }
    .filterIsInstance<FirebaseFunctionsException>().firstOrNull()
  var code = functionsException?.code?.name ?: if (error is IllegalArgumentException) {
    "INVALID_ARGUMENT"
  } else {
    "UNKNOWN"
  }
  var message = functionsException?.message ?: error.message ?: code
  val cause = functionsException?.cause
  if (cause is IOException) {
    code = if (cause.message == "Canceled" ||
      (cause is InterruptedIOException && cause.message == "timeout")) {
      "DEADLINE_EXCEEDED"
    } else {
      "UNAVAILABLE"
    }
    message = code
  }
  val details = mutableMapOf<String, Any?>(
    "code" to code.replace('_', '-').lowercase(Locale.ROOT),
    "message" to message
  )
  functionsException?.details?.let { details["additionalData"] = it }
  return FlutterError("firebase_functions", message, details)
}
