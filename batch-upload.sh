#!/bin/bash
# Batch upload script - commits files in ~100MB batches

set -e

SOURCE_DIR="$1"
DEST_DIR="$2"
BATCH_SIZE_MB="${3:-100}"
FILE_EXT="${4:-*}"

if [ -z "$SOURCE_DIR" ] || [ -z "$DEST_DIR" ]; then
    echo "Usage: $0 <source_dir> <dest_dir> [batch_size_mb] [file_extension]"
    echo "Example: $0 ../mp4 mp4 100 mp4"
    exit 1
fi

BATCH_SIZE_BYTES=$((BATCH_SIZE_MB * 1024 * 1024))
CURRENT_BATCH_SIZE=0
BATCH_NUM=1
FILES_IN_BATCH=0
TOTAL_FILES=0

# Get list of files sorted numerically
if [ "$FILE_EXT" = "*" ]; then
    FILES=$(find "$SOURCE_DIR" -type f -name "*" | sort -V)
else
    FILES=$(find "$SOURCE_DIR" -type f -name "*.$FILE_EXT" | sort -V)
fi

TOTAL=$(echo "$FILES" | wc -l | tr -d ' ')
echo "Found $TOTAL files to process"

for FILE in $FILES; do
    FILENAME=$(basename "$FILE")
    FILESIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null)

    # Check if adding this file exceeds batch size
    if [ $((CURRENT_BATCH_SIZE + FILESIZE)) -gt $BATCH_SIZE_BYTES ] && [ $FILES_IN_BATCH -gt 0 ]; then
        # Commit current batch
        echo "📦 Committing batch $BATCH_NUM ($FILES_IN_BATCH files, $((CURRENT_BATCH_SIZE / 1024 / 1024))MB)"
        git add "$DEST_DIR/"
        git commit -m "Add $DEST_DIR batch $BATCH_NUM ($FILES_IN_BATCH files)"

        BATCH_NUM=$((BATCH_NUM + 1))
        CURRENT_BATCH_SIZE=0
        FILES_IN_BATCH=0
    fi

    # Copy file
    cp "$FILE" "$DEST_DIR/$FILENAME"
    CURRENT_BATCH_SIZE=$((CURRENT_BATCH_SIZE + FILESIZE))
    FILES_IN_BATCH=$((FILES_IN_BATCH + 1))
    TOTAL_FILES=$((TOTAL_FILES + 1))

    # Progress indicator
    if [ $((TOTAL_FILES % 50)) -eq 0 ]; then
        PERCENT=$((TOTAL_FILES * 100 / TOTAL))
        echo "Progress: $TOTAL_FILES/$TOTAL ($PERCENT%)"
    fi
done

# Commit remaining files
if [ $FILES_IN_BATCH -gt 0 ]; then
    echo "📦 Committing final batch $BATCH_NUM ($FILES_IN_BATCH files, $((CURRENT_BATCH_SIZE / 1024 / 1024))MB)"
    git add "$DEST_DIR/"
    git commit -m "Add $DEST_DIR batch $BATCH_NUM ($FILES_IN_BATCH files)"
fi

echo "✅ Done! Created $BATCH_NUM batches with $TOTAL_FILES total files"
