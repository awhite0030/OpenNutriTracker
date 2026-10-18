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
fvm flutter test
