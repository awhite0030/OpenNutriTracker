#!/usr/bin/env bash
set -euo pipefail
tree="${1:-.}"
cd "$tree"

fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter gen-l10n
fvm flutter analyze
fvm flutter test
