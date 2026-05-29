#!/bin/bash
set -eou pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ScreenOS"
BUILD_DIR="$PROJECT_DIR/.build"
RELEASE_DIR="$BUILD_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
BINARY="$BUILD_DIR/$(swift build -c release --show-bin-path 2>/dev/null || echo "$BUILD_DIR/release")/$APP_NAME"

echo "🔨 Building $APP_NAME..."

cd "$PROJECT_DIR"

# Build with SwiftPM
swift build -c release

# Determine actual binary path
BINARY_SRC="$BUILD_DIR/release/$APP_NAME"
if [ ! -f "$BINARY_SRC" ]; then
    echo "❌ Binary not found at $BINARY_SRC"
    ls "$BUILD_DIR/release/" 2>/dev/null || echo "  (release dir missing)"
    exit 1
fi

echo "✅ Build complete. Binary at $BINARY_SRC"

# Create .app bundle
echo "📦 Creating $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_SRC" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Make executable
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Codesign with ad-hoc signature (required for Accessibility API on macOS 14+)
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo ""
echo "✅ $APP_NAME.app created at:"
echo "   $APP_BUNDLE"
echo ""
echo "🚀 Para abrirlo: open \"$APP_BUNDLE\""
echo ""
echo "⚠️  IMPORTANTE: La primera vez necesitarás conceder permisos:"
echo "   1. Privacidad → Accesibilidad → Añadir ScreenOS"
echo "   2. Privacidad → Grabación de Pantalla → Añadir ScreenOS (para el Switcher)"
