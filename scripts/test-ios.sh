#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then
  echo "Serve un Mac con Xcode per compilare e provare l’app iOS." >&2
  exit 1
fi
node --test Tests/scanner.test.cjs
xcodebuild -version
sdk_major="$(xcrun --sdk iphonesimulator --show-sdk-version | cut -d. -f1)"
device_id="$(xcrun simctl list devices available -j | python3 -c '
import json,re,sys
devices=json.load(sys.stdin)["devices"]
runtime_keys=sorted(devices, key=lambda r: tuple(map(int,re.findall(r"\d+",r))), reverse=True)
matches=[d["udid"] for runtime in runtime_keys if "iOS-" + sys.argv[1] + "-" in runtime
         for items in [devices[runtime]]
         for d in items if d.get("isAvailable") and "iPhone" in d.get("name","")]
if not matches: sys.exit("Nessun simulatore iPhone disponibile")
print(matches[0])
' "$sdk_major")"
xcodebuild -project StickPocket.xcodeproj -scheme StickPocket \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath build/DerivedData -resultBundlePath "build/Tests-$(date -u +%Y%m%dT%H%M%S).xcresult" \
  -parallel-testing-enabled NO ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO test

# Keep a real simulator screenshot for visual review after the tests pass.
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" build/DerivedData/Build/Products/Debug-iphonesimulator/StickPocket.app
xcrun simctl launch "$device_id" com.luigi.stickpocket
sleep 3
xcrun simctl io "$device_id" screenshot build/StickPocket-iPhone.png
