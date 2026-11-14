#!/usr/bin/env bash
set -euo pipefail

version=2026.1114.2
kit_sha=28a55b85e0adb54d532d5f63558535cf1d57d023f70c8cbe81717d3769bb4bee
wda_commit=02cb92f0e93c8b021443bcbb8eeb80932c113220
wda_tree=05f62a92a9136fcf7a0e00538d5acd47d4bdd43f375e14260fc2c718eeb2e3cf
work=$(mktemp -d)
dist="$(pwd)/dist"
mkdir -p "$dist" "$work/wda" "$work/kit" "$work/Payload"
export DEVELOPER_DIR=/Applications/Xcode_27.2.app/Contents/Developer
xcodebuild -version | tee "$dist/xcode-version.txt"

curl --fail --silent --show-error --location --retry 3 \
  "https://github.com/DIYgod/pinky/releases/download/v$version/pinky-iphone-$version.tar.gz" -o "$work/kit.tar.gz"
printf '%s  %s\n' "$kit_sha" "$work/kit.tar.gz" | shasum -a 256 -c -
curl --fail --silent --show-error --location --retry 3 \
  "https://github.com/appium/WebDriverAgent/archive/$wda_commit.tar.gz" -o "$work/wda.tar.gz"
python3 - "$work/wda.tar.gz" "$wda_tree" <<'PY'
import hashlib, pathlib, sys, tarfile
rows = []
with tarfile.open(sys.argv[1], "r:gz") as archive:
    for entry in archive:
        p = pathlib.PurePosixPath(entry.name)
        assert not p.is_absolute() and ".." not in p.parts and (entry.isdir() or entry.isfile()), entry.name
        if entry.isfile():
            path = "/".join(p.parts[1:])
            assert path
            mode = "755" if entry.mode & 0o111 else "644"
            rows.append((path, f"{mode} {hashlib.sha256(archive.extractfile(entry).read()).hexdigest()} {path}\n"))
assert hashlib.sha256("".join(row for _, row in sorted(rows)).encode()).hexdigest() == sys.argv[2]
print("Verified WebDriverAgent file tree against Pinky's source pin.")
PY
tar -xzf "$work/kit.tar.gz" -C "$work/kit" --strip-components 1
tar -xzf "$work/wda.tar.gz" -C "$work/wda" --strip-components 1

xcodebuild build-for-testing -project "$work/wda/WebDriverAgent.xcodeproj" \
  -scheme WebDriverAgentRunner -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath "$work/wda-dd" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO
xcodebuild build -project "$work/kit/Pinky.xcodeproj" -scheme PinkyLite \
  -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath "$work/pinky-dd" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO PINKY_BUNDLE_ID=cc.diygod.pinky.standalone
source_app="$work/pinky-dd/Build/Products/Debug-iphoneos/PinkyLite.app"
test_bundle=$(find "$work/wda-dd/Build/Products" -path '*/WebDriverAgentRunner-Runner.app/PlugIns/WebDriverAgentRunner.xctest' -type d -print -quit)
test -d "$source_app" && test -d "$test_bundle"
app="$work/Payload/PinkyLite.app"
ditto "$source_app" "$app"
mkdir -p "$app/PlugIns"
ditto "$test_bundle" "$app/PlugIns/WebDriverAgentRunner.xctest"
plutil -replace PinkyWebDriverAgentHost -bool YES "$app/Info.plist" \
  || plutil -insert PinkyWebDriverAgentHost -bool YES "$app/Info.plist"
plutil -insert UIBackgroundModes -string continuous -append "$app/Info.plist"
main=$(plutil -extract CFBundleExecutable raw "$app/Info.plist")
testexec=$(plutil -extract CFBundleExecutable raw "$app/PlugIns/WebDriverAgentRunner.xctest/Info.plist")
lipo -verify_arch arm64 "$app/$main"
lipo -verify_arch arm64 "$app/PlugIns/WebDriverAgentRunner.xctest/$testexec"
min=$(plutil -extract MinimumOSVersion raw "$app/Info.plist")
python3 - "$min" <<'PY'
import sys
assert tuple(map(int, sys.argv[1].split("."))) <= (26, 0, 1), sys.argv[1]
PY
test ! -e "$app/embedded.mobileprovision"
ipa="$dist/PinkyLite-$version-unsigned.ipa"
ditto -c -k --keepParent "$work/Payload" "$ipa"
(cd "$dist" && shasum -a 256 "$(basename "$ipa")" > SHA256SUMS)
