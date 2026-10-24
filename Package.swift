// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Stillday",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Stillday", targets: ["Stillday"])],
    targets: [
        .target(name: "StilldayCore"),
        .executableTarget(name: "Stillday", dependencies: ["StilldayCore"]),
        .executableTarget(name: "StilldayChecks", dependencies: ["StilldayCore"], path: "Tests/StilldayCoreTests")
    ]
)
