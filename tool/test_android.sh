#!/bin/sh
set -eu

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# Prebuild the isolated APK so Flutter discovers the test package before launch.
# --no-uninstall also disables the test runner's destructive cleanup default.
export ORG_GRADLE_PROJECT_bloomIntegrationTest=true
# Set BLOOM_TEST_TARGET to run another isolated integration suite.
target="${BLOOM_TEST_TARGET:-integration_test/light_placement_test.dart}"
flutter build apk --debug --target "$target"
# Grant permission only to the separate test package, never the normal app.
# Accept the same explicit device as Flutter's -d option.
device="${BLOOM_TEST_DEVICE:-emulator-5554}"
previous=""
for argument in "$@"; do
    if [ "$previous" = "-d" ]; then device="$argument"; fi
    previous="$argument"
done
adb -s "$device" install -r -g build/app/outputs/flutter-apk/app-debug.apk
flutter test "$target" "$@" --no-uninstall
