// swift-tools-version: 6.0
import PackageDescription

// The app's logic, free of UIKit/SwiftUI so `swift test` runs it on the Mac.
let package = Package(
    name: "ElisaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ElisaKit", targets: ["ElisaKit"])],
    targets: [
        .target(name: "ElisaKit"),
        .testTarget(name: "ElisaKitTests", dependencies: ["ElisaKit"]),
    ]
)
