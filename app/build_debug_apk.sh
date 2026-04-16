#!/bin/bash
# RadioKit Fedora Build Script
# This script applies the necessary fixes for JDK cgroup warnings that can corrupt the build.

# Fix for cgroup warning corruption in jmod (Found on Fedora/Cgroup v2 systems)
export _JAVA_OPTIONS="-Xlog:disable"

# Ensure Chromium is found for web targets
export CHROME_EXECUTABLE=$(which chromium-browser || which chromium)

echo "🚀 Starting RadioKit Debug APK Build..."
/home/sun/sandbox/fedora/flutter/bin/flutter build apk --debug

if [ $? -eq 0 ]; then
    echo "✅ Build Successful!"
    echo "APK located at: build/app/outputs/flutter-apk/app-debug.apk"
    echo ""
    echo "To install to your connected device, run:"
    echo "adb install build/app/outputs/flutter-apk/app-debug.apk"
else
    echo "❌ Build Failed!"
    exit 1
fi
