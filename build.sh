#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Change to the script's directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

PACKAGE_NAME="html_to_image_skill.zip"

echo "🧹 Cleaning up old builds..."
rm -f "$PACKAGE_NAME"
rm -rf output/
rm -f screenshot.png

echo "📦 Creating release package ($PACKAGE_NAME)..."
zip -r "$PACKAGE_NAME" \
    SKILL.md \
    src/ \
    -x "*/.DS_Store"

echo "✅ Build completed successfully!"
echo "📄 The package '$PACKAGE_NAME' is ready to be published or uploaded to OpenClaw."
