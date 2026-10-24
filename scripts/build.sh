#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
bundle_dir="${project_dir:h}/Stillday.app"
cd "$project_dir"
swift scripts/make-icon.swift Resources/AppIcon.icns
swift build -c release --product Stillday
mkdir -p "$bundle_dir/Contents/MacOS" "$bundle_dir/Contents/Resources"
cp .build/release/Stillday "$bundle_dir/Contents/MacOS/Stillday"
cp Resources/Info.plist "$bundle_dir/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$bundle_dir/Contents/Resources/AppIcon.icns"; fi
codesign --force --sign - "$bundle_dir"
echo "Built: $bundle_dir"
