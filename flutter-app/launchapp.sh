#!/bin/bash

# Ensure flutter and chrome are accessible
export PATH="$PATH:/home/sun/sandbox/fedora/flutter/bin"
export CHROME_EXECUTABLE="/usr/bin/chromium-browser"

echo "Starting RadioKit Flutter app in debug mode..."
echo "Target: http://127.0.0.1:8080"

# Kill any existing process on port 8080
fuser -k 8080/tcp 2>/dev/null || true

# Run the app in Chrome on port 8080
# --no-pub: skip dependency check (already done)
# --web-hostname 127.0.0.1: avoid localhost resolution delays
# --web-browser-flag="--no-sandbox": often required in container/Toolbx environments
flutter run -d chrome \
  --web-port 8080 \
  --web-hostname 127.0.0.1 \
  --debug \
  --no-pub

