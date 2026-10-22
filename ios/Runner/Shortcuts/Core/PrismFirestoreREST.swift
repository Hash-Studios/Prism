import Foundation

enum PrismFirestoreREST {
  private static let unreserved = CharacterSet(
    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~"
  )

  static func documentURL(projectID: String, apiKey: String, collection: String, documentID: String) -> URL? {
    guard !projectID.isEmpty, !apiKey.isEmpty, !collection.isEmpty, !documentID.isEmpty,
      let project = projectID.addingPercentEncoding(withAllowedCharacters: unreserved),
      let collectionPath = collection.addingPercentEncoding(withAllowedCharacters: unreserved),
      let document = documentID.addingPercentEncoding(withAllowedCharacters: unreserved)
    else {
      return nil
    }
    var components = URLComponents()
    components.scheme = "https"
    components.host = "firestore.googleapis.com"
    let documents = "/databases/(default)/documents"
    components.percentEncodedPath = "/v1/projects/\(project)\(documents)/\(collectionPath)/\(document)"
    components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
    return components.url
  }

  static func stringField(_ name: String, in data: Data) -> String? {
    valueField(name, kind: "stringValue", in: data)
  }

  static func timestampField(_ name: String, in data: Data) -> String? {
    valueField(name, kind: "timestampValue", in: data)
  }

  private static func valueField(_ name: String, kind: String, in data: Data) -> String? {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let fields = root["fields"] as? [String: Any],
      let field = fields[name] as? [String: Any],
      let value = field[kind] as? String, !value.isEmpty
    else {
      return nil
    }
    return value
  }
}
