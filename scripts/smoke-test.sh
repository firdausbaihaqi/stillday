#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
source_bundle="${project_dir:h}/Stillday.app"
fixture_bundle="$project_dir/.build/native-smoke/Stillday Checks.app"
registration_tool="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ ! -x "$source_bundle/Contents/MacOS/Stillday" ]]; then
    echo "Build Stillday with scripts/build.sh before running native checks."
    exit 1
fi
mkdir -p "${fixture_bundle:h}"
ditto "$source_bundle" "$fixture_bundle"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier day.stillday.checks' "$fixture_bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Stillday Checks' "$fixture_bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Stillday Checks' "$fixture_bundle/Contents/Info.plist"
codesign --force --sign - "$fixture_bundle"
trap '"$registration_tool" -u "$fixture_bundle" >/dev/null 2>&1 || true' EXIT
"$fixture_bundle/Contents/MacOS/Stillday" --smoke-test "$@"
