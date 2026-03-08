#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Parse arguments
SOURCE_TYPE=""
SOURCE_CONTENT=""
FORMAT="png"
WIDTH="794" # A4 Web Print Standard Width
HEIGHT="1123" # A4 Web Print Standard Height
FULL_PAGE="false"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --source_type) SOURCE_TYPE="$2"; shift ;;
        --source_content) SOURCE_CONTENT="$2"; shift ;;
        --format) FORMAT="$2"; shift ;;
        --width) WIDTH="$2"; shift ;;
        --height) HEIGHT="$2"; shift ;;
        --full_page) FULL_PAGE="true"; ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Validate required inputs
if [ -z "$SOURCE_TYPE" ] || [ -z "$SOURCE_CONTENT" ]; then
    echo '{"status": "error", "message": "Missing required arguments: --source_type and --source_content"}'
    exit 1
fi

# Prepare output directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="$(pwd)/output"
mkdir -p "$OUTPUT_DIR"
OUTPUT_PATH="${OUTPUT_DIR}/rendered_${TIMESTAMP}.${FORMAT}"

# Determine target URL
TARGET_URL=""
TMP_HTML=""

if [ "$SOURCE_TYPE" = "url" ]; then
    TARGET_URL="$SOURCE_CONTENT"
elif [ "$SOURCE_TYPE" = "file" ]; then
    # Ensure it's an absolute path for file://
    if [[ "$SOURCE_CONTENT" = /* ]]; then
         TARGET_URL="file://${SOURCE_CONTENT}"
    else
         TARGET_URL="file://$(pwd)/${SOURCE_CONTENT}"
    fi
elif [ "$SOURCE_TYPE" = "code" ]; then
    TMP_HTML=$(mktemp /tmp/html_to_image_XXXXXX.html)
    cat > "$TMP_HTML" <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body, html {
            margin: 0;
            padding: 0;
            background: white;
            /* Hide overflow to prevent scrollbars from generating whitespace */
            overflow: hidden;
            width: fit-content;
            height: fit-content;
        }
    </style>
</head>
<body>
$SOURCE_CONTENT
</body>
</html>
EOF
    TARGET_URL="file://${TMP_HTML}"
else
    echo '{"status": "error", "message": "Invalid source_type. Must be url, file, or code."}'
    exit 1
fi

# Construct base agent-browser command chain
CMD="npx --yes agent-browser set device \"Desktop Chrome HiDPI\""
CMD="$CMD && npx --yes agent-browser set viewport \"$WIDTH\" \"$HEIGHT\""
CMD="$CMD && npx --yes agent-browser open \"$TARGET_URL\""
CMD="$CMD && npx --yes agent-browser wait --load networkidle"

# Execute loading
eval "$CMD" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo '{"status": "error", "message": "Failed to load page."}'
    exit 1
fi

# Get body height to calculate pagination
BOX_JSON=$(npx --yes agent-browser get box "body" --json 2>/dev/null)
BODY_HEIGHT=$(echo "$BOX_JSON" | grep -o '"height":[0-9]*' | awk -F':' '{print $2}')

# Fallback if height parsing fails
if [ -z "$BODY_HEIGHT" ]; then
    BODY_HEIGHT=$HEIGHT
fi

# Calculate number of pages based on viewport height (ceiling division)
PAGES=$(( (BODY_HEIGHT + HEIGHT - 1) / HEIGHT ))
if [ "$PAGES" -lt 1 ]; then PAGES=1; fi

# Override to 1 page if user explicitly requested a unified full_page screenshot
if [ "$FULL_PAGE" = "true" ]; then
    PAGES=1
fi

if [ "$PAGES" -eq 1 ]; then
    # Single page output logic
    SCREENSHOT_CMD="npx --yes agent-browser screenshot"
    if [ "$FULL_PAGE" = "true" ]; then SCREENSHOT_CMD="$SCREENSHOT_CMD --full"; fi
    eval "$SCREENSHOT_CMD \"$OUTPUT_PATH\"" > /dev/null 2>&1
    
    if [ $? -eq 0 ] && [ -f "$OUTPUT_PATH" ]; then
        SIZE=$(wc -c < "$OUTPUT_PATH" | tr -d ' ')
        echo "{\"status\": \"success\", \"message\": \"Image generated successfully via agent-browser.\", \"data\": {\"output_path\": \"$OUTPUT_PATH\", \"size_bytes\": $SIZE, \"format\": \"$FORMAT\", \"source_type\": \"$SOURCE_TYPE\", \"pages\": 1}}"
    else
        echo '{"status": "error", "message": "Failed to generate image."}'
    fi
else
    # Multi-page output logic
    GENERATED_FILES=()
    BASENAME=$(basename "$OUTPUT_PATH")
    DIRNAME=$(dirname "$OUTPUT_PATH")
    EXT="${BASENAME##*.}"
    NAME="${BASENAME%.*}"
    
    for ((i=1; i<=PAGES; i++)); do
        PAGE_OUTPUT="${DIRNAME}/${NAME}_page${i}.${EXT}"
        
        # Scroll down by exact viewport height before taking screenshots after page 1
        if [ $i -gt 1 ]; then
             npx --yes agent-browser scroll down $HEIGHT > /dev/null 2>&1
        fi
        
        npx --yes agent-browser screenshot "$PAGE_OUTPUT" > /dev/null 2>&1
        
        if [ -f "$PAGE_OUTPUT" ]; then
            GENERATED_FILES+=("\"$PAGE_OUTPUT\"")
        fi
    done
    
    FILES_JSON=$(IFS=,; echo "[${GENERATED_FILES[*]}]")
    echo "{\"status\": \"success\", \"message\": \"Generated $PAGES images via agent-browser.\", \"data\": {\"output_paths\": $FILES_JSON, \"format\": \"$FORMAT\", \"source_type\": \"$SOURCE_TYPE\", \"pages\": $PAGES}}"
fi

[ -n "$TMP_HTML" ] && rm -f "$TMP_HTML" || true

