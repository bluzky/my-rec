#!/bin/bash
set -e

echo "🧪 Running tests..."

xcodebuild test \
  -project MyRec.xcodeproj \
  -scheme MyRec \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES

echo "✅ Tests complete!"
