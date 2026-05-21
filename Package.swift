// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Nook",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // SPM executable. Backed by a tiny trampoline target so the underlying
        // `NookApp` module can also be consumed as a library by the Xcode app
        // target (see `project.yml`). `swift run Nook` keeps working for the
        // headless dev loop.
        .executable(name: "Nook", targets: ["NookExecutable"]),
        // Library product so the Xcode app target can `import NookApp` and
        // call `NookApp.main()` from `App/main.swift`. Same module the SPM
        // trampoline links against — behavior cannot drift between the two
        // launch surfaces.
        .library(name: "NookApp", targets: ["NookApp"]),
        // Optional Tier 3 add-on components (file shelf, …). A consumer adds this
        // product to their target's dependencies only when they want it; it is not
        // pulled in by `NookApp`.
        .library(name: "NookComponents", targets: ["NookComponents"]),
        // Example apps under `Examples/` — each a single `main.swift` showing one
        // way to build on OpenNook through public API only. Run with `swift run
        // HelloNook` (or `ClockNook` / `ThemedNook` / `ShelfNook`).
        .executable(name: "HelloNook", targets: ["HelloNook"]),
        .executable(name: "ClockNook", targets: ["ClockNook"]),
        .executable(name: "ThemedNook", targets: ["ThemedNook"]),
        .executable(name: "ShelfNook", targets: ["ShelfNook"]),
        .executable(name: "ActivityNook", targets: ["ActivityNook"]),
        .executable(name: "VolumeNook", targets: ["VolumeNook"])
    ],
    targets: [
        .target(
            name: "NookSurface",
            path: "Sources/NookSurface"
        ),
        .target(
            name: "NookKit",
            dependencies: ["NookSurface"],
            path: "Sources/NookKit"
        ),
        .target(
            // Library, not executable, so both the SPM trampoline and the Xcode app
            // target can consume the same module. The `@main` annotation is gone from
            // `NookApp.swift`; entry points call `NookApp.main()` explicitly.
            name: "NookApp",
            dependencies: ["NookKit"],
            path: "Sources/NookApp"
        ),
        .executableTarget(
            // SPM trampoline. Three-line `main.swift` that imports `NookApp` and calls
            // `NookApp.main()`. The product name `Nook` (above) is preserved so
            // `swift run Nook` is unchanged. The Xcode app target has its own
            // identical trampoline at `App/main.swift`.
            name: "NookExecutable",
            dependencies: ["NookApp"],
            path: "Sources/NookExecutable"
        ),
        .target(
            // Optional Tier 3 add-on components. Apache-2.0. Depends on NookKit
            // (for the resolved-theme environment); not part of the default app.
            name: "NookComponents",
            dependencies: ["NookKit"],
            path: "Sources/NookComponents"
        ),
        .executableTarget(
            name: "HelloNook",
            dependencies: ["NookApp"],
            path: "Examples/HelloNook"
        ),
        .executableTarget(
            name: "ClockNook",
            dependencies: ["NookApp"],
            path: "Examples/ClockNook"
        ),
        .executableTarget(
            name: "ThemedNook",
            dependencies: ["NookApp"],
            path: "Examples/ThemedNook"
        ),
        .executableTarget(
            name: "ShelfNook",
            dependencies: ["NookApp", "NookComponents"],
            path: "Examples/ShelfNook"
        ),
        .executableTarget(
            name: "ActivityNook",
            dependencies: ["NookApp", "NookComponents"],
            path: "Examples/ActivityNook"
        ),
        .executableTarget(
            name: "VolumeNook",
            dependencies: ["NookApp", "NookComponents"],
            path: "Examples/VolumeNook"
        ),
        .testTarget(
            name: "NookKitTests",
            dependencies: ["NookKit", "NookSurface"],
            path: "Tests/NookKitTests"
        ),
        .testTarget(
            name: "NookComponentsTests",
            dependencies: ["NookComponents"],
            path: "Tests/NookComponentsTests"
        )
    ]
)
