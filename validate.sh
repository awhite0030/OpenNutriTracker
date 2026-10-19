#!/usr/bin/env bash
# Validate an OpenNutriTracker PR. Requires Flutter (3.44.x). $1 = PR tree.
set -euo pipefail
tree="${1:?}"
cd "$tree"

export PATH="$PATH":"$HOME/.pub-cache/bin"
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter gen-l10n
fvm flutter analyze
fvm flutter test test/unit_test/onboarding_save_race_test.dart test/unit_test/daily_reminder_scheduler_test.dart test/unit_test/notification_service_test.dart
