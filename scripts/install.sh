#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
source_bundle="${project_dir:h}/Stillday.app"
installed_bundle="/Applications/Stillday.app"

if pgrep -x Stillday >/dev/null; then
    echo "Quit Stillday from its menu-bar power button, then run this installer again."
    exit 1
fi
if [[ ! -w /Applications ]]; then
    echo "Applications is not writable. Run scripts/build.sh, then drag Stillday.app into Applications in Finder."
    exit 1
fi
if [[ -e "$installed_bundle" ]]; then
    installed_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$installed_bundle/Contents/Info.plist" 2>/dev/null || true)
    if [[ "$installed_id" != "day.stillday.mac" ]]; then
        echo "Applications already contains a different app named Stillday. Move it before installing."
        exit 1
    fi
fi
"$project_dir/scripts/build.sh"
ditto "$source_bundle" "$installed_bundle"
registration_tool="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
# Unregistering a build that has never been registered can fail.
if ! "$registration_tool" -u "$source_bundle"; then
    echo "Could not unregister the build copy; continuing with installed app registration."
fi
"$registration_tool" -f "$installed_bundle"
open "$installed_bundle"
echo "Installed: $installed_bundle"
