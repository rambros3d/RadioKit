#!/bin/bash

# Ensure flutter and chrome are accessible
export PATH="$PATH:/home/sun/sandbox/fedora/flutter/bin"
export CHROME_EXECUTABLE="/usr/bin/chromium-browser"

# Navigate to the app directory
cd "$(dirname "$0")/app"

echo "Starting RadioKit Flutter app in debug mode..."
echo "Target: http://localhost:8080"

# Kill any existing process on port 8080 to prevent "Address already in use" errors
fuser -k 8080/tcp 2>/dev/null || true

# Run the app in Chrome on port 8080
# Supports hot reload (r) and hot restart (R) in the terminal
flutter run -d chrome --web-port 8080 --web-hostname localhost --debug
