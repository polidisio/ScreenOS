#!/bin/bash
set -eou pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ScreenOS"
BUILD_DIR="$PROJECT_DIR/.build"
RELEASE_DIR="$BUILD_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

cd "$PROJECT_DIR"

# Remove stale Xcode-built app to avoid running wrong version
rm -rf "$PROJECT_DIR/build/Release/$APP_NAME.app" 2>/dev/null || true

# Build with SwiftPM
swift build -c release

BINARY_SRC="$RELEASE_DIR/$APP_NAME"
if [ ! -f "$BINARY_SRC" ]; then
    echo "❌ Binary not found at $BINARY_SRC"
    ls "$RELEASE_DIR/" 2>/dev/null || echo "  (release dir missing)"
    exit 1
fi

echo "✅ Build complete. Binary at $BINARY_SRC"

# Create .app bundle
echo "📦 Creating $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

# Copy executable
cp "$BINARY_SRC" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy asset catalog (AppIcon)
if [ -d "$PROJECT_DIR/Sources/ScreenOS/Resources/Assets.xcassets" ]; then
    cp -r "$PROJECT_DIR/Sources/ScreenOS/Resources/Assets.xcassets" "$APP_BUNDLE/Contents/Resources/"
fi

# Copy ScreenOSKit.framework if it exists
if [ -d "$RELEASE_DIR/ScreenOSKit.framework" ]; then
    cp -r "$RELEASE_DIR/ScreenOSKit.framework" "$APP_BUNDLE/Contents/Frameworks/"
elif [ -d "$RELEASE_DIR/ScreenOSKit.swiftmodule" ]; then
    echo "⚠️  ScreenOSKit.framework not found - checking for alternative..."
    ls "$RELEASE_DIR/" 2>/dev/null
fi

# Codesign with ad-hoc signature
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo ""
echo "✅ $APP_NAME.app created at:"
echo "   $APP_BUNDLE"
echo ""

# Kill any running instance (Xcode or previous SwiftPM build) before opening
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.4

echo "🚀 Abriendo $APP_NAME..."
open "$APP_BUNDLE"
echo ""
echo "⚠️  Si es la primera vez, concede el permiso de Accesibilidad cuando te lo pida."
echo "   La app se reiniciará automáticamente tras concederlo."
