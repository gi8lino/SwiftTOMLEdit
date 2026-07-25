// swift-tools-version: 5.10

import Foundation
import PackageDescription

let strictConcurrencySettings: [SwiftSetting] = [
  .enableUpcomingFeature("StrictConcurrency")
]

// During native development, `make artifact` creates the local XCFramework and
// SwiftPM uses it automatically. Release metadata is updated separately when
// switching the package to a newly published binary.
let releaseTag = "v0.0.1"
let releaseChecksum = "02b07f0326f86e9b0fd2a3df3d8c1df1ac2c9f996cf66510ff1d52311b855861"
let localArtifactPath = "Artifacts/CSwiftTOMLEdit.xcframework"
let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let localArtifactExists = FileManager.default.fileExists(
  atPath: packageRoot.appendingPathComponent(localArtifactPath).path
)

let nativeTarget: Target =
  localArtifactExists
  ? .binaryTarget(
    name: "CSwiftTOMLEdit",
    path: localArtifactPath
  )
  : .binaryTarget(
    name: "CSwiftTOMLEdit",
    url:
      "https://github.com/gi8lino/SwiftTOMLEdit/releases/download/\(releaseTag)/CSwiftTOMLEdit.xcframework.zip",
    checksum: releaseChecksum
  )

let package = Package(
  name: "SwiftTOMLEdit",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "SwiftTOMLEdit", targets: ["SwiftTOMLEdit"])
  ],
  targets: [
    nativeTarget,
    .target(
      name: "SwiftTOMLEdit",
      dependencies: ["CSwiftTOMLEdit"],
      path: "Sources/SwiftTOMLEdit",
      swiftSettings: strictConcurrencySettings
    ),
    .testTarget(
      name: "SwiftTOMLEditTests",
      dependencies: ["SwiftTOMLEdit"],
      path: "Tests/SwiftTOMLEditTests",
      swiftSettings: strictConcurrencySettings
    ),
  ]
)
