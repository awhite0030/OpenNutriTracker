#!/usr/bin/env bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
set -euo pipefail
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter gen-l10n
fvm flutter analyze
fvm flutter test
