#!/usr/bin/env bash
# Zabalí zostavený Runner.app do nepodpísanej IPA pre Sideloadly.
# Spúšťa sa po `flutter build ios --no-codesign`:
#
#   bash scripts/ios/package_unsigned_ipa.sh Rejnox-unsigned.ipa
#   bash scripts/ios/package_unsigned_ipa.sh Rejnox-bez.ipa bez-hodiniek
#
# Druhý parameter "bez-hodiniek" vynechá appku pre Apple Watch.
# Skončí chybou, ak Runner.app chýba alebo je prázdny (žiadna 166 B IPA).
set -euo pipefail

NAME="${1:?Zadaj názov IPA, napr. Rejnox-unsigned.ipa}"
VARIANT="${2:-}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Flutter kopíruje appku do build/ios/iphoneos, Xcode ju necháva
# v build/ios/Release-iphoneos. Appka hodiniek (Runner.app/Watch/…) sa nepočíta.
APP=""
for dir in build/ios/iphoneos build/ios/Release-iphoneos; do
  if [ -f "$dir/Runner.app/Runner" ]; then
    APP="$dir/Runner.app"
    break
  fi
done
if [ -z "$APP" ]; then
  echo "Runner.app sa nenašiel. Obsah build/ios:" >&2
  find build/ios -maxdepth 3 -type d -name '*.app' >&2 || true
  exit 1
fi

WORK="$(mktemp -d)"
mkdir -p "$WORK/Payload" build/ios/ipa
cp -R "$APP" "$WORK/Payload/"
if [ "$VARIANT" = "bez-hodiniek" ]; then
  rm -rf "$WORK/Payload/Runner.app/Watch"
fi
rm -f "build/ios/ipa/$NAME"
(cd "$WORK" && zip -qry "$ROOT/build/ios/ipa/$NAME" Payload)
rm -rf "$WORK"

if [ "$VARIANT" != "bez-hodiniek" ] && [ -d "$APP/Watch" ]; then
  echo "Appka pre Apple Watch: $(ls "$APP/Watch")"
fi
ls -lh "build/ios/ipa/$NAME"

# Skutočná IPA má desiatky MB; menšia znamená, že niečo chýba.
SIZE=$(wc -c < "build/ios/ipa/$NAME")
if [ "$SIZE" -lt 1000000 ]; then
  echo "IPA má len $SIZE B, niečo je zle." >&2
  exit 1
fi
