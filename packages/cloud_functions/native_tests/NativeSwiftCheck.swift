import CoreFoundation
import Foundation

struct ArgumentError: Error {}
func functionsArgumentError(_ message: String) -> ArgumentError { ArgumentError() }

@main
enum NativeSwiftCheck {
  static func main() throws {
    try checkCodec()
    try checkArguments()
    print("Native Swift codec and boundary checks passed")
  }

  private static func checkCodec() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let values: [String: Any] = [
      "zero": NSNumber(value: 0), "one": NSNumber(value: 1),
      "boolean": true, "false": false, "fraction": 1.5,
      "large": Int64.max,
      "array": [NSNull(), "hello", 1, true]
    ]
    let data = try encoder.encode(AnyEncodable(values))
    let expected = #"{"array":[null,"hello",1,true],"boolean":true,"false":false,"fraction":1.5,"# +
      #""large":9223372036854775807,"one":1,"zero":0}"#
    precondition(String(data: data, encoding: .utf8) == expected)
    let decoded = try JSONDecoder().decode(AnyDecodable.self, from: data)
    let roundTrip = try encoder.encode(AnyEncodable(decoded.value))
    precondition(roundTrip == data)
    let unsigned = try JSONDecoder().decode(AnyDecodable.self, from: Data("18446744073709551615".utf8))
    guard let floatingPoint = unsigned.value as? Double else {
      preconditionFailure("Out-of-range integer must use Flutter's double wire representation")
    }
    precondition(floatingPoint > 0 && floatingPoint == Double(UInt64.max))
    precondition(String(cString: NSNumber(value: floatingPoint).objCType) == "d")
    let nullData = try encoder.encode(AnyEncodable(nil))
    precondition(nullData == Data("null".utf8))
    do {
      _ = try encoder.encode(AnyEncodable(Date()))
      preconditionFailure("Unsupported callable parameter must fail")
    } catch is EncodingError {}
  }

  private static func checkArguments() throws {
    let valid: [String: Any?] = [
      "functionName": "wall", "functionUri": nil, "origin": NSNull(),
      "timeout": Int64(5_000_000_000), "parameters": NSNull(), "limitedUseAppCheckToken": false
    ]
    let parsed = try CallableArguments(valid)
    precondition(parsed.timeout == 5_000_000)
    precondition(parsed.parameters == nil)
    precondition(!parsed.limitedUseAppCheckToken)
    for badTimeout in [true, NSNumber(value: 1.5), NSNumber(value: 0), NSNumber(value: Double.nan),
                       NSNumber(value: UInt64.max)] {
      var invalid = valid
      invalid["timeout"] = badTimeout
      do {
        _ = try CallableArguments(invalid)
        preconditionFailure("Invalid timeout must fail")
      } catch is ArgumentError {}
    }
    for badOrigin in [42, "localhost", "http://user:pass@localhost:5001", "http://localhost:0"] {
      var invalid = valid
      invalid["origin"] = badOrigin
      do {
        _ = try CallableArguments(invalid)
        preconditionFailure("Invalid origin must fail")
      } catch is ArgumentError {}
    }
  }
}
