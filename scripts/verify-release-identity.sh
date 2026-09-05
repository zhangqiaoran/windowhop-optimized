#!/bin/bash
# Validates the zhangqiaoran my-alt-tab release identity without depending on
# another project's certificate or Team ID. Optional EXPECTED_TEAM_ID can be
# supplied for a future Developer ID release.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-build/my-alt-tab.app}"
EXPECTED_IDENTIFIER=com.zhangqiaoran.myalttab

[ -d "$APP" ] || { echo "Identity validation failed: app not found: $APP" >&2; exit 1; }
codesign --verify --deep --strict --verbose=2 "$APP"

SIGNATURE=$(codesign -dvvv "$APP" 2>&1)
grep -qx "Identifier=$EXPECTED_IDENTIFIER" <<< "$SIGNATURE" || {
    echo "Identity validation failed: signing identifier is not $EXPECTED_IDENTIFIER." >&2
    exit 1
}

if [ -n "${EXPECTED_TEAM_ID:-}" ]; then
    grep -qx "TeamIdentifier=$EXPECTED_TEAM_ID" <<< "$SIGNATURE" || {
        echo "Identity validation failed: TeamIdentifier is not $EXPECTED_TEAM_ID." >&2
        exit 1
    }
fi

# Developer-ID releases should have Hardened Runtime. Ad-hoc builds may not.
if ! grep -q 'Signature=adhoc' <<< "$SIGNATURE"; then
    grep -q 'flags=.*runtime' <<< "$SIGNATURE" || {
        echo "Identity validation failed: non-ad-hoc build is missing Hardened Runtime." >&2
        exit 1
    }
fi

echo "release identity: ok ($EXPECTED_IDENTIFIER${EXPECTED_TEAM_ID:+, team $EXPECTED_TEAM_ID})"
