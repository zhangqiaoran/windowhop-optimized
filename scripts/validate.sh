#!/bin/bash
# Repository validation: invariants that must hold for every commit and release.
# Run from the repository root. Exits non-zero with an explanation on violation.
set -uo pipefail
cd "$(dirname "$0")/.."

failures=0
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }
pass() { echo "  ok: $1"; }

TRACKED=$(git ls-files)

# --- product identity -------------------------------------------------------
if grep -rn "com\.martonpss\|com\.lwouis\|lwouis\.alt-tab" $TRACKED 2>/dev/null | grep -v "^UPSTREAM.md\|^docs/"; then
    fail "obsolete bundle identifier found in tracked files"
else
    pass "no obsolete bundle identifiers"
fi
if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Support/Info.plist)" = "com.zhangqiaoran.myalttab" ]; then
    pass "bundle identifier is com.zhangqiaoran.myalttab"
else
    fail "Support/Info.plist bundle identifier is not com.zhangqiaoran.myalttab"
fi

# --- no private API, no capture outside the preview subsystem ----------------
if grep -rn "_silgen_name\|SLPSPostEvent\|_SLPSSetFront\|CGSSetSymbolicHotKey\|_AXUIElementGetWindow\|_AXUIElementCreateWithRemoteToken" Sources/ 2>/dev/null | grep -v "^\S*:[0-9]*: *///" | grep -v "^\S*:[0-9]*: *//"; then
    fail "private API reference found in Sources/"
else
    pass "no private APIs"
fi
# legacy capture APIs are banned everywhere; ScreenCaptureKit is sanctioned only
# inside the session-scoped preview subsystem
if grep -rn "CGWindowListCreateImage\|CGDisplayStream" Sources/ 2>/dev/null; then
    fail "legacy screen-capture API found in Sources/"
else
    pass "no legacy screen capture"
fi
if grep -rln "ScreenCaptureKit\|SCShareableContent\|SCScreenshotManager" Sources/ 2>/dev/null \
    | grep -v "Sources/WindowHopCore/Engine/PreviewProvider.swift"; then
    fail "ScreenCaptureKit used outside Engine/PreviewProvider.swift"
else
    pass "ScreenCaptureKit confined to the preview provider"
fi
if grep -rn "AppCenter\|analytics\|telemetry" Sources/ --include="*.swift" 2>/dev/null | grep -iv "no telemetry\|telemetry, no\|no analytics"; then
    fail "telemetry reference found in Sources/"
else
    pass "no telemetry"
fi

# --- updater configuration ---------------------------------------------------
# Community builds deliberately have no upstream Sparkle feed/key so they can
# never replace themselves with another project's release channel.
if /usr/libexec/PlistBuddy -c 'Print :WindowHopForkUpdatesDisabled' Support/Info.plist 2>/dev/null | grep -qx true; then
    pass "community auto-updates are disabled"
else
    fail "WindowHopForkUpdatesDisabled must be true"
fi
if /usr/libexec/PlistBuddy -c 'Print :SUEnableAutomaticChecks' Support/Info.plist 2>/dev/null | grep -qx false; then
    pass "automatic update checks are disabled"
else
    fail "SUEnableAutomaticChecks must be false"
fi
for key in SUFeedURL SUPublicEDKey; do
    if /usr/libexec/PlistBuddy -c "Print :$key" Support/Info.plist >/dev/null 2>&1; then
        fail "community Info.plist must not contain $key"
    else
        pass "community Info.plist omits $key"
    fi
done

# --- appcast/release metadata consistency ------------------------------------
# appcast.xml is retained only as upstream historical material. The community
# build intentionally has no active feed or Sparkle public key.

# --- documentation/release synchronization ----------------------------------
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)
README_ZIP_VERSIONS=$(grep -oE 'WindowHop-[0-9]+\.[0-9]+\.[0-9]+\.zip' README.md | sort -u)
if [ "$README_ZIP_VERSIONS" = "WindowHop-$VERSION.zip" ]; then
    pass "README artifact matches version $VERSION"
else
    fail "README artifact does not uniquely match version $VERSION: $README_ZIP_VERSIONS"
fi

MARKDOWN_FILES=$(git ls-files '*.md')
while IFS= read -r markdown; do
    [ -n "$markdown" ] || continue
    while IFS= read -r target; do
        case "$target" in
            https://*|http://*|mailto:*|'#'*|'') continue ;;
        esac
        if [ -e "$(dirname "$markdown")/$target" ]; then
            :
        else
            fail "$markdown references missing local file: $target"
        fi
    done < <(grep -oE '\]\([^)]+\)' "$markdown" 2>/dev/null | sed 's/^](//; s/)$//')
done <<< "$MARKDOWN_FILES"

while IFS= read -r screenshot; do
    [ -n "$screenshot" ] || continue
    if grep -qF "($screenshot)" $MARKDOWN_FILES; then
        :
    else
        fail "unreferenced screenshot is tracked: $screenshot"
    fi
done < <(find docs/screenshots -type f -print | sort)

if [ "$failures" -eq 0 ]; then
    pass "Markdown local links and tracked screenshots are synchronized"
fi

if scripts/validate-site.sh; then
    pass "GitHub Pages static site"
else
    fail "GitHub Pages static site validation failed"
fi

# --- secrets must never be committed -----------------------------------------
if git ls-files | grep -iE "private.?key|\.p12$|\.pem$"; then
    fail "potential secret file tracked in git"
else
    pass "no secret-looking files tracked"
fi

echo ""
if [ "$failures" -gt 0 ]; then
    echo "validation FAILED with $failures problem(s)"
    exit 1
fi
echo "validation passed"
