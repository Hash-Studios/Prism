// Copyright 2025 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if canImport(FlutterMacOS)
  import FlutterMacOS
#else
  import Flutter
#endif
import FirebaseFunctions

final class FunctionsStreamHandler: NSObject, FlutterStreamHandler {
  private let functions: Functions
  private var streamTask: Task<Void, Never>?
  private let onCancelled: (FunctionsStreamHandler) -> Void

  init(functions: Functions, onCancelled: @escaping (FunctionsStreamHandler) -> Void = { _ in }) {
    self.functions = functions
    self.onCancelled = onCancelled
    super.init()
  }

  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard let arguments = arguments as? [String: Any] else {
      events(functionsArgumentError("Stream arguments must be a map"))
      events(FlutterEndOfEventStream)
      return nil
    }
    let values: CallableArguments
    do {
      values = try CallableArguments(arguments)
    } catch {
      events(error as? FlutterError ?? functionsFlutterError(error))
      events(FlutterEndOfEventStream)
      return nil
    }
    streamTask?.cancel()
    let functions = functions
    streamTask = Task { @MainActor in
      await Self.httpsStreamCall(functions: functions, arguments: values, events: events)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    cancel()
    if arguments != nil { onCancelled(self) }
    return nil
  }

  func cancel() {
    streamTask?.cancel()
    streamTask = nil
  }

  @MainActor
  private static func httpsStreamCall(functions: Functions, arguments: CallableArguments,
                                      events: @escaping FlutterEventSink) async {
    do {
      if let origin = arguments.origin, let host = origin.host, let port = origin.port {
        functions.useEmulator(withHost: host, port: port)
      }
      let options = HTTPSCallableOptions(
        requireLimitedUseAppCheckTokens: arguments.limitedUseAppCheckToken
      )
      if #available(iOS 15.0, macOS 12.0, *) {
        let function = streamingCallable(functions: functions, arguments: arguments, options: options)
        try Task.checkCancellation()
        let stream = try function.stream(AnyEncodable(arguments.parameters))
        for try await response in stream {
          try Task.checkCancellation()
          switch response {
          case let .message(message): events(["message": message.value ?? NSNull()])
          case let .result(result): events(["result": result.value ?? NSNull()])
          }
        }
        if !Task.isCancelled { events(FlutterEndOfEventStream) }
      } else {
        throw FlutterError(code: "unimplemented", message: "Streaming requires macOS 12+",
                           details: ["code": "unimplemented", "message": "Streaming requires macOS 12+"])
      }
    } catch {
      guard !Task.isCancelled else { return }
      events(error as? FlutterError ?? functionsFlutterError(error))
      events(FlutterEndOfEventStream)
    }
  }

  @available(iOS 15.0, macOS 12.0, *)
  private static func streamingCallable(functions: Functions, arguments: CallableArguments,
                                        options: HTTPSCallableOptions)
    -> Callable<AnyEncodable, StreamResponse<AnyDecodable, AnyDecodable>> {
    var function: Callable<AnyEncodable, StreamResponse<AnyDecodable, AnyDecodable>>
    switch arguments.target {
    case let .name(name): function = functions.httpsCallable(name, options: options)
    case let .url(url): function = functions.httpsCallable(url, options: options)
    }
    if let timeout = arguments.timeout { function.timeoutInterval = timeout }
    return function
  }
}
