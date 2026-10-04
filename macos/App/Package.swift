// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-2.0-or-later

import PackageDescription

// The engine is a CMake-built static library (see ../Engine). Build it first
// with ../build.sh, which also passes the Qt location through the environment.
let root = Context.packageDirectory + "/../.."
let engineLib = Context.environment["SC_ENGINE_LIB_DIR"] ?? root + "/build/engine"
let qtLib = Context.environment["SC_QT_LIB_DIR"] ?? "/opt/homebrew/opt/qtbase/lib"

let package = Package(
    name: "SpeedCrunch",
    platforms: [.macOS(.v15)],
    targets: [
        .systemLibrary(name: "CSpeedCrunchEngine", path: "Sources/CSpeedCrunchEngine"),
        .executableTarget(
            name: "SpeedCrunch",
            dependencies: ["CSpeedCrunchEngine"],
            path: "Sources/SpeedCrunch",
            linkerSettings: [
                .unsafeFlags([
                    "-L", engineLib, "-lscengine",
                    "-F", qtLib, "-framework", "QtCore",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", qtLib,
                ]),
                .linkedLibrary("c++"),
            ]
        ),
    ]
)
