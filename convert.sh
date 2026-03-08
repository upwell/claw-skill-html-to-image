#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <input_html_file> [output_image_file]"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-output.png}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

echo "Converting $INPUT_FILE to image..."
# Run the main OpenClaw skill and capture the JSON output
RESULT=$(bash src/main.sh --source_type file --source_content "$INPUT_FILE")

# Check if execution itself failed
if [ $? -ne 0 ]; then
    echo "❌ Failed to generate image. Skill error or crashed."
    echo "$RESULT"
    exit 1
fi

# Extract all generated image paths from the JSON response
IMG_PATHS=$(echo "$RESULT" | grep -o '/[^"]*\.png')

if [ -n "$IMG_PATHS" ]; then
    count=0
    for file in $IMG_PATHS; do
        if [ -f "$file" ]; then
            count=$((count+1))
            # Format filename to output_page1.png, output_page2.png etc if multiple
            if [ $(echo "$IMG_PATHS" | wc -w) -gt 1 ]; then
                BASENAME="${OUTPUT_FILE%.*}"
                EXT="${OUTPUT_FILE##*.}"
                DEST="${BASENAME}_page${count}.${EXT}"
            else
                DEST="$OUTPUT_FILE"
            fi
            
            cp "$file" "$DEST"
            echo "✅ Success! Image saved to: $DEST"
        fi
    done
else
    echo "❌ Failed to find exported images. Skill output was:"
    echo "$RESULT"
fi
