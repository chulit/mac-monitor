// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "UltimateMacMonitor",
  platforms: [.macOS(.v13)],
  targets: [
    .target(name: "MonitoringEngine"),
    .executableTarget(name: "UltimateMacMonitorApp", dependencies: ["MonitoringEngine"]),
    .executableTarget(name: "CPUProbe", dependencies: []),
    .testTarget(
      name: "MonitoringEngineTests",
      dependencies: ["MonitoringEngine"]
    ),
  ]
)
