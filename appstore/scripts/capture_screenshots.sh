#!/bin/bash
# Mağaza ham ekran görüntülerini kendi simülatörlerinde üretir ve PNG olarak dışa aktarır.
# Kullanım: appstore/scripts/capture_screenshots.sh <iphone|ipad> <simülatör UDID> <çıktı klasörü>
# Önkoşul: `xcodegen generate` yapılmış olmalı (ios/). Başka oturumların simülatörlerini KULLANMA.
set -euo pipefail
KIND="${1:?iphone|ipad}"; UDID="${2:?udid}"; OUT="${3:?çıktı klasörü}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT/ios"
RESULT="build/shots-$KIND.xcresult"
rm -rf "$RESULT" "$OUT"; mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
# Temiz durum çubuğu (9:41, dolu pil, tam sinyal).
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 --operatorName ""

TEST_RUNNER_FOKUS_STORE_SHOTS=1 xcodebuild test -project Fokus.xcodeproj -scheme Fokus \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build/DerivedDataShots \
  -only-testing:FokusUITests/StoreScreenshotsUITests -resultBundlePath "$RESULT" CODE_SIGNING_ALLOWED=NO

xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/raw"
python3 - "$OUT" <<'PY'
import json, shutil, sys
from pathlib import Path
out = Path(sys.argv[1]); raw = out / "raw"
manifest = json.loads((raw / "manifest.json").read_text())
count = 0
for test in manifest:
    for att in test.get("attachments", []):
        name = att.get("suggestedHumanReadableName", "")
        stem = name.split("_")[0]  # "<ad>_0_<UUID>.png" biçimi
        src = raw / att["exportedFileName"]
        if stem and src.exists():
            shutil.copy(src, out / f"{stem}.png"); count += 1
print(f"{count} görsel -> {out}")
PY
xcrun simctl status_bar "$UDID" clear
