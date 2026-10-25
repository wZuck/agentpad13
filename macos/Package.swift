// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentPadStudio",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "AgentPadStudio", targets: ["AgentPadStudio"])],
    targets: [
        .target(name: "AgentPadCore"),
        .executableTarget(name: "AgentPadStudio", dependencies: ["AgentPadCore"],
                          resources: [.copy("Resources/Models")],
                          linkerSettings: [.linkedFramework("IOKit")]),
        .testTarget(name: "AgentPadCoreTests", dependencies: ["AgentPadCore"])
    ]
)
