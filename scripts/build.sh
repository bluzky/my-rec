#!/bin/bash
set -e

echo "🔨 Building MyRec..."

CONFIGURATION=${1:-Debug}

echo "🧹 Cleaning..."
xcodebuild clean \
  -project MyRec.xcodeproj \
  -scheme MyRec \
  -configuration $CONFIGURATION

echo "⚙️  Building $CONFIGURATION..."
xcodebuild build \
  -project MyRec.xcodeproj \
  -scheme MyRec \
  -configuration $CONFIGURATION \
  -arch arm64 \
  -arch x86_64 \
  ONLY_ACTIVE_ARCH=NO

echo "✅ Build complete!"
