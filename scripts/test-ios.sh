#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then
  echo "Serve un Mac con Xcode per compilare e provare l’app iOS." >&2
  exit 1
fi
node --test Tests/scanner.test.cjs
device_id="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
devices=json.load(sys.stdin)["devices"]
matches=[d["udid"] for runtime,items in devices.items() if "iOS" in runtime
         for d in items if d.get("isAvailable") and "iPhone" in d.get("name","")]
if not matches: sys.exit("Nessun simulatore iPhone disponibile")
print(matches[0])
')"
xcodebuild -project StickPocket.xcodeproj -scheme StickPocket \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath build/DerivedData -resultBundlePath "build/Tests-$(date -u +%Y%m%dT%H%M%S).xcresult" \
  CODE_SIGNING_ALLOWED=NO test

# Keep a real simulator screenshot for visual review after the tests pass.
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" build/DerivedData/Build/Products/Debug-iphonesimulator/StickPocket.app
xcrun simctl launch "$device_id" com.luigi.stickpocket
sleep 3
xcrun simctl io "$device_id" screenshot build/StickPocket-iPhone.png
