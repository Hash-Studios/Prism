// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PrismNative",
  platforms: [.macOS(.v12), .iOS(.v15)],
  targets: [
    .target(name: "PrismMediaStorage", path: "Runner/Media"),
    .testTarget(
      name: "PrismMediaStorageTests",
      dependencies: ["PrismMediaStorage"],
      path: "RunnerTests",
      exclude: ["RunnerTests.swift"]
    )
  ]
)
