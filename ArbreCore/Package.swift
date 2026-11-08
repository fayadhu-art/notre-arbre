// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ArbreCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "ArbreCore", targets: ["ArbreCore"])],
    targets: [
        .target(name: "ArbreCore"),
        .testTarget(name: "ArbreCoreTests", dependencies: ["ArbreCore"])
    ]
)
