// swift-tools-version: 5.9

import Foundation
import PackageDescription

/// Centralized strict-concurrency checking - applied to every target so the
/// examples (which a host developer reads as authoritative idiom) and tests
/// (which a regression must not silently bypass) can't drift from the
/// concurrency rules the library targets enforce.
let strictConcurrency: [SwiftSetting] = [.enableUpcomingFeature("StrictConcurrency")]

var package = Package(
    name: "Nook",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        // SPM executable. Backed by a tiny trampoline target so the underlying
        // `NookApp` module can also be consumed as a library by the Xcode app
        // target (see `project.yml`). `swift run Nook` keeps working for the
        // headless dev loop.
        .executable(name: "Nook", targets: ["NookExecutable"]),
        // Library product so the Xcode app target can `import NookApp` and
        // call `NookApp.main()` from `App/main.swift`. Same module the SPM
        // trampoline links against - behavior cannot drift between the two
        // launch surfaces.
        .library(name: "NookApp", targets: ["NookApp"]),
        // Optional Tier 3 add-on components (file shelf, ...). A consumer adds this
        // product to their target's dependencies only when they want it; it is not
        // pulled in by `NookApp`.
        .library(name: "NookComponents", targets: ["NookComponents"]),
        // Example apps under `Examples/` - each a single `main.swift` showing one
        // way to build on OpenNook through public API only. Run with `swift run
        // HelloNook` (or `ClockNook` / `ThemedNook` / `ChromeNook` / `LayoutNook` /
        // `ShelfNook` / `ActivityNook` / `VolumeNook` / `MultiNook`).
        .executable(name: "HelloNook", targets: ["HelloNook"]),
        .executable(name: "ClockNook", targets: ["ClockNook"]),
        .executable(name: "ThemedNook", targets: ["ThemedNook"]),
        .executable(name: "ChromeNook", targets: ["ChromeNook"]),
        .executable(name: "LayoutNook", targets: ["LayoutNook"]),
        .executable(name: "ShelfNook", targets: ["ShelfNook"]),
        .executable(name: "ActivityNook", targets: ["ActivityNook"]),
        .executable(name: "VolumeNook", targets: ["VolumeNook"]),
        .executable(name: "MultiNook", targets: ["MultiNook"])
    ],
    targets: [
        .target(
            name: "NookSurface",
            path: "Sources/NookSurface",
            // Strict-concurrency checking is opted in via an upcoming feature so the
            // `@MainActor`/`Sendable` correctness is compiler-enforced. Kept as an
            // upcoming feature (not a tools-version bump to 6.0) so this stays a
            // non-breaking change for consumers - deliberate architecture decision.
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "NookKit",
            dependencies: ["NookSurface"],
            path: "Sources/NookKit",
            swiftSettings: strictConcurrency
        ),
        .target(
            // Library, not executable, so both the SPM trampoline and the Xcode app
            // target can consume the same module. The `@main` annotation is gone from
            // `NookApp.swift`; entry points call `NookApp.main()` explicitly.
            name: "NookApp",
            dependencies: ["NookKit"],
            path: "Sources/NookApp",
            swiftSettings: strictConcurrency
        ),
        .executableTarget(
            // SPM trampoline. Three-line `main.swift` that imports `NookApp` and calls
            // `NookApp.main()`. The product name `Nook` (above) is preserved so
            // `swift run Nook` is unchanged. The Xcode app target has its own
            // identical trampoline at `App/main.swift`.
            name: "NookExecutable",
            dependencies: ["NookApp"],
            path: "Sources/NookExecutable",
            swiftSettings: strictConcurrency
        ),
        .target(
            // Optional Tier 3 add-on components. Apache-2.0. Depends on NookKit
            // (for the resolved-theme environment); not part of the default app.
            name: "NookComponents",
            dependencies: ["NookKit"],
            path: "Sources/NookComponents",
            swiftSettings: strictConcurrency
        ),
        .executableTarget(
            name: "HelloNook",
            dependencies: ["NookApp"],
            path: "Examples/HelloNook",
            swiftSettings: strictConcurrency
        ),
        .executableTarget(
            name: "ClockNook",
            dependencies: ["NookApp"],
            path: "Examples/ClockNook",
            swiftSettings: strictConcurrency
        ),
        .executableTarget(
            name: "ThemedNook",
            dependencies: ["NookApp"],
            path: "Examples/ThemedNook",
            swiftSettings: strictConcurrency
        ),
        .executableTarget(
            name: "ChromeNook",
            dependencies: ["NookApp"],
            path: "Examples/ChromeNook",
            swiftSettings: strictConcurrency
        ),
        .executableTarget(
            name: "LayoutNook",
            dependencies: ["NookApp"],
            path: "Examples/LayoutNook",
            swiftSettings: strictConcurrency
        ),
        .executableTarget(
            name: "ShelfNook",
            dependencies: ["NookApp", "NookComponents"],
            path: "Examples/ShelfNook",
            swiftSettings: strictConcurrency
        ),
        .executableTarget(
            name: "ActivityNook",
            dependencies: ["NookApp", "NookComponents"],
            path: "Examples/ActivityNook",
            swiftSettings: strictConcurrency
        ),
        .executableTarget(
            name: "VolumeNook",
            dependencies: ["NookApp", "NookComponents"],
            path: "Examples/VolumeNook",
            swiftSettings: strictConcurrency
        ),
        .executableTarget(
            name: "MultiNook",
            dependencies: ["NookApp"],
            path: "Examples/MultiNook",
            swiftSettings: strictConcurrency
        ),
        .testTarget(
            name: "NookKitTests",
            dependencies: ["NookKit", "NookSurface"],
            path: "Tests/NookKitTests",
            swiftSettings: strictConcurrency
        ),
        .testTarget(
            name: "NookComponentsTests",
            dependencies: ["NookComponents"],
            path: "Tests/NookComponentsTests",
            swiftSettings: strictConcurrency
        )
    ]
)

// DocC is a docs-only, opt-in dependency: the swift-docc-plugin is added to the manifest
// only when OPENNOOK_BUILD_DOCS is set, so consumers of OpenNook never resolve or fetch it
// and the framework keeps its zero-runtime-dependency promise. Generate the API reference
// with Scripts/generate-docs.sh (which sets the variable).
if ProcessInfo.processInfo.environment["OPENNOOK_BUILD_DOCS"] != nil {
    package.dependencies.append(
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    )
}
