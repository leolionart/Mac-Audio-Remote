# Sparkle Auto-Update Framework

## Swift Package Manager Setup
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
],
targets: [
    .executableTarget(
        name: "MyApp",
        dependencies: [.product(name: "Sparkle", package: "Sparkle")]
    )
]
```

## Info.plist Configuration
```xml
<key>SUFeedURL</key>
<string>https://example.com/appcast.xml</string>

<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_EDDSA_KEY</string>
```

## UpdateManager Implementation
```swift
import Sparkle

class UpdateManager: ObservableObject {
    @Published var canCheckForUpdates = true
    private var updaterController: SPUStandardUpdaterController?

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    func checkForUpdatesInBackground() {
        updaterController?.updater.checkForUpdatesInBackground()
    }
}
```

## SwiftUI Integration
```swift
@main
struct MyApp: App {
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup { ContentView() }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}
```

## appcast.xml Structure
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>App Updates</title>
    <item>
      <title>Version 2.1.0</title>
      <sparkle:shortVersionString>2.1.0</sparkle:shortVersionString>
      <sparkle:version>21</sparkle:version>
      <pubDate>Fri, 03 Jan 2026 12:00:00 +0000</pubDate>
      <description><![CDATA[
        <ul>
          <li>New feature</li>
          <li>Bug fix</li>
        </ul>
      ]]></description>
      <enclosure
        url="https://github.com/user/repo/releases/download/v2.1.0/App-2.1.0.zip"
        sparkle:edSignature="BASE64_EDDSA_SIGNATURE"
        length="12345678"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

## EdDSA Key Generation
```bash
# One-time setup - generates key pair
./bin/generate_keys

# Output: Public key (add to Info.plist as SUPublicEDKey)
# Private key stored in Keychain
```

## Signing Updates
```bash
# Sign your app archive
./bin/sign_update /path/to/MyApp.zip

# Output: EdDSA signature for appcast.xml
```

## Release Workflow Script
```bash
#!/bin/bash
VERSION="2.1.0"
ZIP_FILE="MyApp-${VERSION}.zip"

# 1. Build release
swift build -c release

# 2. Create app bundle (custom script)
./build_app_bundle.sh

# 3. Create ZIP
ditto -c -k --keepParent .build/release/MyApp.app "$ZIP_FILE"

# 4. Sign and get signature
SIGNATURE=$(./bin/sign_update "$ZIP_FILE" 2>&1)
FILE_SIZE=$(stat -f%z "$ZIP_FILE")

# 5. Update appcast.xml with new version, signature, size

# 6. Create GitHub release
gh release create "v${VERSION}" "$ZIP_FILE" --title "v${VERSION}"
```

## Best Practices
1. **HTTPS Only**: Host appcast.xml and ZIPs over HTTPS
2. **Secure Keys**: Never commit private EdDSA key
3. **Test Updates**: Verify update flow from older version
4. **Automate**: Script the entire release process
5. **Version Format**:
   - `sparkle:shortVersionString` = user-facing (e.g., "2.1.0")
   - `sparkle:version` = build number (e.g., "21")

## Troubleshooting
- **No updates found**: Check SUFeedURL is accessible
- **Signature mismatch**: Verify SUPublicEDKey matches signing key
- **Download fails**: Ensure ZIP URL is correct and accessible
