#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building CLUMenuBar..."
swift build -c release 2>&1

APP_DIR="CLUMenuBar.app/Contents"
mkdir -p "$APP_DIR/MacOS"

# Copy binary
cp .build/release/CLUMenuBar "$APP_DIR/MacOS/CLUMenuBar"

# Create Info.plist with ATS exception for local HTTP
cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CLUMenuBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.clu.menubar</string>
    <key>CFBundleName</key>
    <string>CLU</string>
    <key>CFBundleVersion</key>
    <string>2.5.0</string>
    <key>CFBundleShortVersionString</key>
    <string>2.5.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

echo ""
echo "✓ Built: CLUMenuBar.app"
echo ""
echo "Usage:"
echo "  1. Start the server:  clu --serve"
echo "  2. Launch the app:    open CLUMenuBar.app"
echo ""
echo "To install to Applications:"
echo "  cp -r CLUMenuBar.app /Applications/"
