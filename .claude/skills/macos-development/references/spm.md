# Swift Package Manager for macOS Apps

## Package.swift Structure
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MyApp", targets: ["MyApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/MyApp",
            resources: [.copy("Resources")]
        )
    ]
)
```

## Build Commands
```bash
# Debug build
swift build

# Release build
swift build -c release

# Clean and rebuild
swift package clean && swift build

# Update dependencies
swift package update

# Resolve dependencies
swift package resolve
```

## Resource Bundles
```swift
// Package.swift
resources: [
    .copy("Resources"),           // Copy entire folder
    .process("Assets.xcassets"),  // Process assets
]

// Access in code
Bundle.module.path(forResource: "config", ofType: "json")
```

## Creating App Bundle from SPM
```bash
#!/bin/bash
APP_NAME="MyApp"
BUILD_DIR=".build/release"

# Build release
swift build -c release

# Create app structure
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Frameworks"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/"

# Copy Info.plist
cp "Info.plist" "$BUILD_DIR/$APP_NAME.app/Contents/"

# Copy resources
cp -r "Resources/" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/"

# Copy frameworks (e.g., Sparkle)
cp -r ".build/artifacts/sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" \
    "$BUILD_DIR/$APP_NAME.app/Contents/Frameworks/"
```

## Info.plist Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MyApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.myapp</string>
    <key>CFBundleName</key>
    <string>MyApp</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

## Conditional Compilation
```swift
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

#if DEBUG
print("Debug mode")
#endif

#if canImport(Sparkle)
import Sparkle
#endif
```

## Common Issues & Solutions

### Binary not found
```bash
# Check build artifacts
ls -la .build/release/

# Verify product name matches
swift package describe
```

### Framework linking issues
```bash
# Set rpath for frameworks
install_name_tool -add_rpath @executable_path/../Frameworks \
    ".build/release/MyApp.app/Contents/MacOS/MyApp"
```

### Resource access fails
```swift
// Use Bundle.module for SPM resources
let url = Bundle.module.url(forResource: "data", withExtension: "json")

// Not Bundle.main (that's for traditional Xcode projects)
```

### Xcode integration
```bash
# Open in Xcode
open Package.swift

# Generate Xcode project (deprecated but sometimes useful)
swift package generate-xcodeproj
```

## Dependency Tips
- Use `from: "X.Y.Z"` for semantic versioning
- Use `.exact("X.Y.Z")` for pinned versions
- Use `.branch("main")` for development
- Use `.revision("commit-hash")` for specific commits

## Build Configurations
```swift
// Custom swift flags
swiftSettings: [
    .define("CUSTOM_FLAG", .when(configuration: .debug)),
    .unsafeFlags(["-O"], .when(configuration: .release))
]
```
