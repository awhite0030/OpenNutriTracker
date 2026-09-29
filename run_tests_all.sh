#!/usr/bin/env bash
set -euo pipefail
fvm flutter test > final_tests_output.log 2>&1
