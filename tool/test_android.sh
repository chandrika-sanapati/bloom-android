#!/bin/sh
set -eu

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# Prebuild the isolated APK so Flutter discovers the test package before launch.
# --no-uninstall also disables the test runner's destructive cleanup default.
export ORG_GRADLE_PROJECT_bloomIntegrationTest=true
flutter build apk --debug --target integration_test/light_placement_test.dart
flutter test integration_test/light_placement_test.dart "$@" --no-uninstall
