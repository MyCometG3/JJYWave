#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

echo "Running strict-concurrency diagnostics check..."

xcodebuild \
  -project "JJYWave.xcodeproj" \
  -scheme "JJYWave" \
  -destination "platform=macOS" \
  -configuration Debug \
  SWIFT_STRICT_CONCURRENCY=complete \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

echo "Strict-concurrency diagnostics check passed."
