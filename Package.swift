// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "TildeDesktop", platforms: [.macOS(.v13)],
    products: [.executable(name: "Tilde", targets: ["TildeDesktop"]),
               .library(name: "SwiftTerm", targets: ["SwiftTerm"])],
    targets: [
        .target(name: "SwiftTerm", path: "third_party/SwiftTerm/Sources",
                exclude: ["iOS", "Mac/README.md"], resources: [.copy("Apple/Metal/Shaders.metal")]),
        .executableTarget(name: "TildeDesktop", dependencies: ["SwiftTerm"], path: "Tilde",
            exclude: ["Assets.xcassets", "Info.plist", "Tilde.pkgproj"], sources: ["TildeApp.swift", "ContentView.swift"])
    ])
