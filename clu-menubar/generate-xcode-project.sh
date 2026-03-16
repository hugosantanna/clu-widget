#!/bin/bash
set -e
cd "$(dirname "$0")"

# Generate an Xcode project using xcodegen
# First check if xcodegen is available
if ! command -v xcodegen &> /dev/null; then
    echo "Installing xcodegen..."
    brew install xcodegen
fi

cat > project.yml << 'YML'
name: CLUMenuBar
options:
  bundleIdPrefix: com.clu
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"

targets:
  CLUMenuBar:
    type: application
    platform: macOS
    sources:
      - CLUMenuBar
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.clu.menubar
        INFOPLIST_FILE: ""
        GENERATE_INFOPLIST_FILE: true
        INFOPLIST_KEY_LSUIElement: true
        INFOPLIST_KEY_NSAppTransportSecurity_NSAllowsLocalNetworking: true
    info:
      path: CLUMenuBar/Info.plist
      properties:
        LSUIElement: true
        NSAppTransportSecurity:
          NSAllowsLocalNetworking: true
    dependencies:
      - target: CLUWidgetExtension

  CLUWidgetExtension:
    type: app-extension
    platform: macOS
    sources:
      - CLUWidgetExtension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.clu.menubar.widget
        GENERATE_INFOPLIST_FILE: true
        INFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier: com.apple.widgetkit-extension
    info:
      path: CLUWidgetExtension/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
YML

xcodegen generate
echo ""
echo "✓ Generated CLUMenuBar.xcodeproj"
echo ""
echo "To build:"
echo "  open CLUMenuBar.xcodeproj"
echo "  or: xcodebuild -scheme CLUMenuBar -configuration Release build"
