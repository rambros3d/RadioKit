#!/bin/bash
# Move to the script's directory (project root)
cd "$(dirname "$0")"

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
    
    # Check for authorized ADB devices
    DEVICES=$(adb devices | grep -v "List of devices" | grep -w "device" | awk '{print $1}')
    
    if [ -n "$DEVICES" ]; then
        echo ""
        echo "📲 Authorized ADB device(s) found. Starting automatic sideload..."
        for DEVICE in $DEVICES; do
            echo "📦 Installing to $DEVICE..."
            adb -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk
        done
        echo "✨ Sideload process complete!"
    else
        echo ""
        echo "ℹ️ No authorized ADB devices found. Skipping sideload."
        echo "To install manually, run: adb install build/app/outputs/flutter-apk/app-debug.apk"
    fi
else
    echo "❌ Build Failed!"
    exit 1
fi
