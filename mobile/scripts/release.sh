#!/usr/bin/env bash
# builds the android apks and publishes them as a github release, which is where the app looks
# for updates. run from anywhere:
#
#   mobile/scripts/release.sh "catatan rilis dalam bahasa indonesia"   build, check, publish
#   mobile/scripts/release.sh --dry-run                              build and check only
#   mobile/scripts/release.sh --verify path/to/app.apk               check one apk
#
# v2.1.0 went out built without --dart-define=API_BASE, so it talked to the emulator's
# http://10.0.2.2:8787 and loaded forever on every real phone. this script passes the address
# itself and refuses to publish any apk that does not carry it, so that cannot happen twice.
set -euo pipefail

API_BASE="https://sales-presenter-backend.iblameraihan.workers.dev"
EMULATOR_URL="10.0.2.2"
# every release so far is signed with this key. an apk signed with any other key cannot install
# over the app people already have, so they would have to uninstall and lose unsynced closings
RELEASE_CERT="ce61e2b8da51add9bbc4c34685939bd72665cba2f2bc7c8315bf007593e4cf02"
REPO="raihanadf/sales-presenter-calculator"
# the app installs the first .apk in the release, so arm64 (what every current phone runs) leads
ABIS=(arm64-v8a armeabi-v7a x86_64)

MOBILE="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_TOOLS="$(ls -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/build-tools/* | sort -V | tail -1)"
APKSIGNER="$BUILD_TOOLS/apksigner"

# the one apk check. fails loudly on the first thing that would break a phone
verify_apk() {
  local apk="$1" abi="$2" tmp lib cert
  tmp="$(mktemp -d)"
  unzip -q -o "$apk" "lib/$abi/libapp.so" -d "$tmp"
  lib="$tmp/lib/$abi/libapp.so"
  # written to a file and grepped there, never `strings | grep -q`: under pipefail grep -q
  # exiting early kills strings with sigpipe, the pipeline reads as failed, and a match turns
  # into a miss. that would let exactly the apk this check exists for through
  strings "$lib" > "$tmp/strings"

  if grep -qF "$EMULATOR_URL" "$tmp/strings"; then
    echo "FAIL $apk: talks to the emulator ($EMULATOR_URL), it would load forever on a phone" >&2
    rm -rf "$tmp"; return 1
  fi
  if ! grep -qF "$API_BASE" "$tmp/strings"; then
    echo "FAIL $apk: does not contain the backend address $API_BASE" >&2
    rm -rf "$tmp"; return 1
  fi
  rm -rf "$tmp"

  local certs
  certs="$("$APKSIGNER" verify --print-certs "$apk")"
  cert="$(awk '/SHA-256 digest/ {print $NF; exit}' <<< "$certs")"
  if [ "$cert" != "$RELEASE_CERT" ]; then
    echo "FAIL $apk: signed with $cert, not the release key, so it cannot install over the app" >&2
    return 1
  fi
  echo "ok   $(basename "$apk"): backend address present, no emulator address, release key"
}

if [ "${1:-}" = "--verify" ]; then
  apk="$2"
  listing="$(unzip -l "$apk")"
  abi="$(grep -oE 'lib/[^/]+/libapp.so' <<< "$listing" | awk -F/ '{print $2; exit}')"
  verify_apk "$apk" "$abi"
  exit 0
fi

dry_run=false
notes=""
if [ "${1:-}" = "--dry-run" ]; then
  dry_run=true
else
  notes="${1:-}"
  # agents.md: every release carries a short human message users will read in the update dialog
  [ -n "$notes" ] || { echo "release notes are required, in indonesian" >&2; exit 1; }
fi

version="$(grep -m1 '^version:' "$MOBILE/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
tag="v$version"

if ! $dry_run; then
  cd "$MOBILE/.."
  [ -z "$(git status --porcelain)" ] || { echo "commit your changes first: the release is cut from HEAD" >&2; exit 1; }
  git fetch -q origin
  [ "$(git rev-parse HEAD)" = "$(git rev-parse '@{u}')" ] || { echo "push first: HEAD is not on origin" >&2; exit 1; }
  if gh release view "$tag" --repo "$REPO" >/dev/null 2>&1; then
    echo "$tag is already released: bump the version in pubspec.yaml" >&2; exit 1
  fi
  latest="$(gh release view --repo "$REPO" --json tagName --jq .tagName)"
  if [ "$(printf '%s\n%s\n' "$latest" "$tag" | sort -V | tail -1)" != "$tag" ]; then
    echo "$tag is not newer than the live $latest" >&2; exit 1
  fi
fi

echo "building $tag against $API_BASE"
cd "$MOBILE"
flutter build apk --release --split-per-abi --dart-define=API_BASE="$API_BASE"

out="$MOBILE/build/app/outputs/flutter-apk"
apks=()
for abi in "${ABIS[@]}"; do
  verify_apk "$out/app-$abi-release.apk" "$abi"
  apks+=("$out/app-$abi-release.apk")
done

if $dry_run; then
  echo "dry run: $tag built and checked, nothing published"
  exit 0
fi

gh release create "$tag" --repo "$REPO" --target "$(git rev-parse HEAD)" \
  --title "$tag" --notes "$notes" "${apks[@]}"

# what the app itself will see: the new tag as latest, and the apk it downloads still passes
[ "$(gh release view --repo "$REPO" --json tagName --jq .tagName)" = "$tag" ] || {
  echo "published, but $tag is not showing as the latest release" >&2; exit 1; }
check="$(mktemp -d)"
gh release download "$tag" --repo "$REPO" --pattern "app-${ABIS[0]}-release.apk" --dir "$check"
verify_apk "$check/app-${ABIS[0]}-release.apk" "${ABIS[0]}"
rm -rf "$check"
echo "released $tag"
