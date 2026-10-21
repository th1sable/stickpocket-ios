#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -version
xcode_major="$(xcodebuild -version | awk '/^Xcode / {split($2,v,"."); print v[1]}')"
if [[ "$xcode_major" -lt 26 ]]; then
  echo "Per questa verifica serve Xcode 26 o successivo." >&2
  exit 1
fi
xcodebuild -project StickPocket.xcodeproj -scheme StickPocket \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/StickPocket-unsigned.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO archive
# This is a developer archive. It is not an installable IPA or TestFlight build.
ditto -c -k --keepParent build/StickPocket-unsigned.xcarchive build/StickPocket-unsigned.xcarchive.zip
