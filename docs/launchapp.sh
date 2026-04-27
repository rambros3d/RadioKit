#!/bin/bash

# Check if npx is available
if ! command -v npx &> /dev/null
then
    echo "Error: npx is not installed. Please install Node.js and npm."
    exit 1
fi

echo "🚀 Starting RadioKit Documentation Preview..."
echo "Open http://localhost:3000 in your browser"

# Use npx to run docsify-cli serve without needing global installation
npx docsify-cli serve .
