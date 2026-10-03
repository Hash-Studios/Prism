// Copyright 2025 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import CoreFoundation
import Foundation

public struct AnyEncodable: Encodable {
  private let value: Any

  public init(_ value: Any?) {
    self.value = value ?? NSNull()
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch value {
    case is NSNull:
      try container.encodeNil()
    case let string as String:
      try container.encode(string)
    case let number as NSNumber:
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        try container.encode(number.boolValue)
      } else {
        switch String(cString: number.objCType) {
        case "f", "d": try container.encode(number.doubleValue)
        case "C", "S", "I", "L", "Q": try container.encode(number.uint64Value)
        default: try container.encode(number.int64Value)
        }
      }
    case let array as [Any]:
      try container.encode(array.map(AnyEncodable.init))
    case let dictionary as [String: Any]:
      try container.encode(dictionary.mapValues(AnyEncodable.init))
    default:
      throw EncodingError.invalidValue(value, .init(
        codingPath: encoder.codingPath,
        debugDescription: "Unsupported callable parameter type: \(type(of: value))"
      ))
    }
  }
}

public struct AnyDecodable: Decodable {
  public let value: Any?

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      value = NSNull()
    } else if let boolean = try? container.decode(Bool.self) {
      value = boolean
    } else if let string = try? container.decode(String.self) {
      value = string
    } else if let integer = try? container.decode(Int64.self) {
      value = integer
    } else if let number = try? container.decode(Double.self) {
      value = number
    } else if let array = try? container.decode([AnyDecodable].self) {
      value = array.map(\.value)
    } else if let dictionary = try? container.decode([String: AnyDecodable].self) {
      value = dictionary.mapValues(\.value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Unsupported callable response"
      )
    }
  }

  public init(_ value: Any?) {
    self.value = value
  }
}
