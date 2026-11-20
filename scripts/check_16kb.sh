#!/usr/bin/env bash
# Hakiki kuwa maktaba zote za native (.so) za arm64-v8a na x86_64 ndani ya APK
# zina alignment ya 16 KB (Google Play inahitaji kwa apps zinazolenga Android 15+).
# Matumizi: scripts/check_16kb.sh [path/to/app-release.apk]
set -euo pipefail
APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
[ -f "$APK" ] || { echo "ERROR: APK haipo: $APK"; exit 2; }
command -v readelf >/dev/null || { echo "ERROR: readelf (binutils) haipo."; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
unzip -q "$APK" 'lib/*' -d "$TMP" || { echo "ERROR: APK haina lib/"; exit 2; }
fail=0; count=0
while IFS= read -r so; do
  count=$((count+1))
  for a in $(readelf -lW "$so" | awk '$1=="LOAD"{print $NF}'); do
    if [ $((a)) -lt 16384 ]; then
      echo "FAIL: $(echo "$so" | sed "s#$TMP/##") ina LOAD alignment $a (< 0x4000)"; fail=1; break
    fi
  done
done < <(find "$TMP/lib/arm64-v8a" "$TMP/lib/x86_64" -name '*.so' 2>/dev/null)
[ "$count" -gt 0 ] || { echo "ERROR: hakuna .so zilizopatikana"; exit 2; }
ZA="$(ls "${ANDROID_HOME:-/nonexistent}"/build-tools/*/zipalign 2>/dev/null | tail -1 || true)"
if [ -n "$ZA" ]; then
  "$ZA" -c -P 16 4 "$APK" && echo "zipalign 16 KB: OK" || { echo "FAIL: zipalign -P 16 imeshindwa"; fail=1; }
else
  echo "NOTICE: zipalign haipo; ukaguzi wa zip-alignment umerukwa."
fi
[ "$fail" -eq 0 ] && echo "16 KB alignment: OK ($count maktaba)" || { echo "16 KB alignment: FAILED"; exit 1; }
