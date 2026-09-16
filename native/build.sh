#!/bin/zsh
set -euo pipefail
setopt null_glob

native_dir="${0:A:h}"
cd "$native_dir"

app_name="GoOutside.app"
app_bundle="$native_dir/$app_name"
app_binary="$app_bundle/Contents/MacOS/GoOutside"
helper_bundle="$app_bundle/Contents/Library/LoginItems/GoOutsideLoginHelper.app"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/go-outside-build.XXXXXX")"
module_cache="${TMPDIR:-/tmp}/go-outside-swift-module-cache"
trap 'rm -rf "$build_dir"' EXIT

source_files=(Sources/*.swift Tests/*.swift)
if (( ${#source_files[@]} == 0 )); then
  print -u2 "go/outside: native/Sources/*.swift is not present yet"
  exit 1
fi

architectures=(arm64 x86_64)

# This is a local build artifact. The explicit target path keeps a failed build
# from removing anything outside the app this script owns.
rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS" \
  "$app_bundle/Contents/Resources" \
  "$helper_bundle/Contents/MacOS" \
  "$helper_bundle/Contents/Resources"

if [[ ! -f Resources/GoOutside.icns ]]; then
  icon_generator="Resources/make-icon.swift"
  if [[ ! -f "$icon_generator" ]]; then
    print -u2 "go/outside: missing Resources/GoOutside.icns and icon generator"
    exit 1
  fi
  xcrun swiftc -swift-version 5 -framework AppKit "$icon_generator" \
    -o "$build_dir/make-go-outside-icon"
  "$build_dir/make-go-outside-icon" "$native_dir/Resources/GoOutside.icns"
fi

for architecture in "${architectures[@]}"; do
  xcrun swiftc -swift-version 5 \
    -target "$architecture-apple-macos12.0" \
    -module-cache-path "$module_cache" \
    "${source_files[@]}" \
    -framework AppKit \
    -framework CoreGraphics \
    -framework CoreLocation \
    -framework ServiceManagement \
    -o "$build_dir/GoOutside-$architecture"

  xcrun swiftc -swift-version 5 \
    -target "$architecture-apple-macos12.0" \
    -module-cache-path "$module_cache" \
    LoginHelper/main.swift \
    -framework AppKit \
    -framework ServiceManagement \
    -o "$build_dir/GoOutsideLoginHelper-$architecture"
done

lipo -create \
  "$build_dir/GoOutside-arm64" \
  "$build_dir/GoOutside-x86_64" \
  -output "$app_binary"
lipo -create \
  "$build_dir/GoOutsideLoginHelper-arm64" \
  "$build_dir/GoOutsideLoginHelper-x86_64" \
  -output "$helper_bundle/Contents/MacOS/GoOutsideLoginHelper"

cp Resources/Info.plist "$app_bundle/Contents/Info.plist"
cp Resources/LoginHelper-Info.plist "$helper_bundle/Contents/Info.plist"
cp Resources/GoOutside.icns "$app_bundle/Contents/Resources/GoOutside.icns"

# Verify both executable slices retain the advertised deployment target.
python3 - "$app_binary" "$helper_bundle/Contents/MacOS/GoOutsideLoginHelper" <<'CHECK'
import re
import subprocess
import sys

for binary in sys.argv[1:]:
    architectures = set(subprocess.check_output(["lipo", "-archs", binary], text=True).split())
    if architectures != {"arm64", "x86_64"}:
        raise SystemExit(f"{binary}: expected arm64 and x86_64, got {sorted(architectures)}")
    build = subprocess.check_output(["xcrun", "vtool", "-show-build", binary], text=True)
    minimums = re.findall(r"minos ([0-9.]+)", build)
    if not minimums or any(value != "12.0" for value in minimums):
        raise SystemExit(f"{binary}: expected macOS 12.0 deployment target, got {minimums}")
CHECK

# The ad-hoc signature is useful for local launch testing. Distribution needs
# a separate Developer ID signature, hardened runtime, and notarization step.
codesign --force --deep --sign - "$app_bundle"

# The app owns the self-test entry point. This keeps tests deterministic and
# makes every successful build exercise the accounting and solar fixtures.
"$app_binary" --self-test
print "Built $app_bundle"
