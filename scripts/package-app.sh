#!/bin/bash
# Builds a Release my-alt-tab.app and packages it as a zip.
#
# Local default:
#   - Full Xcode available: build Universal 2 (arm64 + x86_64)
#   - Command Line Tools only: automatically fall back to the current CPU arch
#
# Override:
#   MY_ALT_TAB_UNIVERSAL=1  require Universal 2 (full Xcode / xcbuild required)
#   MY_ALT_TAB_UNIVERSAL=0  build current architecture only
#   MY_ALT_TAB_UNIVERSAL=auto  auto-detect (default)
#
# Signing:
#   - With DEVELOPER_ID_IDENTITY set: Developer ID + hardened runtime.
#   - Otherwise: ad-hoc signing for local/community distribution.
#
# Usage: scripts/package-app.sh [version] [build-number]
# Output: build/my-alt-tab.app and artifacts/my-alt-tab-<version>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

DEFAULT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
DEFAULT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Support/Info.plist)
VERSION="${1:-$DEFAULT_VERSION}"
BUILD_NUMBER="${2:-$DEFAULT_BUILD}"
IDENTITY="${DEVELOPER_ID_IDENTITY:--}"
UNIVERSAL_MODE="${MY_ALT_TAB_UNIVERSAL:-auto}"

case "$UNIVERSAL_MODE" in
    1)
        # Official CI/release builds intentionally fail if SwiftPM cannot use
        # its Swift Build backend; that keeps Universal 2 a hard release rule.
        UNIVERSAL=1
        ;;
    0)
        UNIVERSAL=0
        ;;
    auto)
        # Do not guess Xcode's internal XCBuild path: it moves between Xcode /
        # Command Line Tools layouts. Ask SwiftPM directly. --show-bin-path is
        # a cheap capability probe and avoids compiling anything twice.
        if swift build -c release --build-system swiftbuild --show-bin-path >/dev/null 2>&1; then
            UNIVERSAL=1
        else
            UNIVERSAL=0
            echo "Swift Build/XCBuild is unavailable; using local native-architecture build."
            echo "This still produces build/my-alt-tab.app."
            echo "Official GitHub releases continue to require Universal 2."
        fi
        ;;
    *)
        echo "MY_ALT_TAB_UNIVERSAL must be auto, 0, or 1" >&2
        exit 2
        ;;
esac

if [ "$UNIVERSAL" = "1" ]; then
    BUILD_ARGS=(-c release --build-system swiftbuild --arch arm64 --arch x86_64)
else
    BUILD_ARGS=(-c release)
fi

swift build "${BUILD_ARGS[@]}"
BIN_DIR=$(swift build "${BUILD_ARGS[@]}" --show-bin-path)
EXECUTABLE="$BIN_DIR/WindowHop"

if [ ! -x "$EXECUTABLE" ]; then
    echo "missing built executable: $EXECUTABLE" >&2
    exit 1
fi

# Sparkle is a binary framework. Resolve it instead of assuming one SwiftPM
# output layout; the swiftbuild backend uses a different artifact directory.
SPARKLE_FRAMEWORK=$(find "$BIN_DIR" .build -type d -name Sparkle.framework -print 2>/dev/null | head -n 1)
if [ -z "$SPARKLE_FRAMEWORK" ]; then
    echo "unable to locate Sparkle.framework" >&2
    exit 1
fi

APP=build/my-alt-tab.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$EXECUTABLE" "$APP/Contents/MacOS/my-alt-tab"
cp Support/Info.plist "$APP/Contents/Info.plist"

# App icon is generated from the single committed source image so the official
# package, README branding, and future regenerations cannot drift apart.
ICON_BUILD="build/generated-icon"
rm -rf "$ICON_BUILD"
swift scripts/make-icon.swift "$ICON_BUILD" Support/AppIconSource.png
iconutil -c icns "$ICON_BUILD/AppIcon.iconset" -o "$ICON_BUILD/AppIcon.icns"
cp "$ICON_BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"

APP_ARCHS=$(lipo -archs "$APP/Contents/MacOS/my-alt-tab")
echo "my-alt-tab architectures: $APP_ARCHS"

if [ "$UNIVERSAL" = "1" ]; then
    [[ " $APP_ARCHS " == *" arm64 "* ]] || { echo "arm64 slice missing" >&2; exit 1; }
    [[ " $APP_ARCHS " == *" x86_64 "* ]] || { echo "x86_64 slice missing" >&2; exit 1; }

    SPARKLE_BINARY="$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle"
    if [ -f "$SPARKLE_BINARY" ]; then
        SPARKLE_ARCHS=$(lipo -archs "$SPARKLE_BINARY")
        echo "Sparkle architectures: $SPARKLE_ARCHS"
        [[ " $SPARKLE_ARCHS " == *" arm64 "* ]] || { echo "Sparkle arm64 slice missing" >&2; exit 1; }
        [[ " $SPARKLE_ARCHS " == *" x86_64 "* ]] || { echo "Sparkle x86_64 slice missing" >&2; exit 1; }
    fi
fi

# Sign nested code first, then the framework, then the app.
SIGN_FLAGS=(--force --sign "$IDENTITY")
if [ "$IDENTITY" != "-" ]; then
    SIGN_FLAGS+=(--timestamp --options runtime)
fi
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
codesign "${SIGN_FLAGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
if [ "$IDENTITY" != "-" ]; then
    scripts/verify-release-identity.sh "$APP"
fi

mkdir -p artifacts
ZIP="artifacts/my-alt-tab-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "built $APP (version $VERSION, build $BUILD_NUMBER, identity: $IDENTITY)"
echo "zipped $ZIP"
