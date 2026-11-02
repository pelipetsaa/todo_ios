// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TodoKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TodoDomain", targets: ["TodoDomain"]),
        .library(name: "TodoApplication", targets: ["TodoApplication"]),
        .library(name: "TodoData", targets: ["TodoData"]),
        .library(name: "TodoPresentation", targets: ["TodoPresentation"])
    ],
    targets: [
        .target(name: "TodoDomain"),
        .target(name: "TodoApplication", dependencies: ["TodoDomain"]),
        .target(name: "TodoData", dependencies: ["TodoDomain"]),
        .target(name: "TodoPresentation", dependencies: ["TodoApplication", "TodoDomain"],
                resources: [.process("Resources")]),
        .testTarget(name: "TodoDomainTests", dependencies: ["TodoDomain"]),
        .target(name: "TodoTestSupport", dependencies: ["TodoApplication", "TodoDomain"], path: "Tests/Support"),
        .testTarget(name: "TodoApplicationTests", dependencies: ["TodoApplication", "TodoDomain", "TodoTestSupport"]),
        .testTarget(name: "TodoDataTests", dependencies: ["TodoData", "TodoDomain"]),
        .testTarget(name: "TodoPresentationTests", dependencies: ["TodoPresentation", "TodoApplication", "TodoDomain", "TodoTestSupport"])
    ]
)
