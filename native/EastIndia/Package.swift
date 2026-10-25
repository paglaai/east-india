// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EastIndia",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "EastIndia", targets: ["EastIndia"])
    ],
    targets: [
        .executableTarget(name: "EastIndia")
    ]
)
