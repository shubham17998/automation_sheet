#!/bin/bash

set -e

# Constants
TODAY=$(date +"%Y-%m-%d")

# Define MinIO instances
MINIO_INSTANCES=(
  "alias1|${MINIO_1_URL}|${MINIO_1_ACCESS_KEY}|${MINIO_1_SECRET_KEY}"
)

# Configure MinIO aliases and process reports
for INSTANCE in "${MINIO_INSTANCES[@]}"; do
  IFS="|" read -r ALIAS URL ACCESS_KEY SECRET_KEY <<< "$INSTANCE"

  echo "Setting up MinIO alias: $ALIAS"
  mc alias set "$ALIAS" "$URL" "$ACCESS_KEY" "$SECRET_KEY"

  # Fetch files from buckets
  BUCKETS=$(mc ls "$ALIAS" | awk '{print $5}')

  for BUCKET in $BUCKETS; do
    echo "Processing bucket: $BUCKET"

    # List files in bucket
    FILES=$(mc ls "$ALIAS/$BUCKET" --recursive | awk '{print $5}')

    for FILE in $FILES; do
      # Extract required data using regex
      if [[ $FILE =~ (T-[0-9]+_P-[0-9]+_S-[0-9]+_F-[0-9]+) ]]; then
        EXTRACTED="${BASH_REMATCH[1]}"
        echo "Extracted data: $EXTRACTED"

        # Prepare payload for Google Sheets
        JSON_PAYLOAD=$(cat <<EOF
{
  "values": [
    ["$EXTRACTED", "$TODAY", "$BUCKET"]
  ]
}
EOF
        )

        # Send data to Google Sheets
        curl -X POST \
          -H "Authorization: Bearer $GOOGLE_SHEET_TOKEN" \
          -H "Content-Type: application/json" \
          -d "$JSON_PAYLOAD" \
          "https://sheets.googleapis.com/v4/spreadsheets/$GOOGLE_SHEET_ID/values/Sheet1!A:C:append?valueInputOption=RAW"

        echo "Updated Google Sheet with $EXTRACTED for bucket $BUCKET"
      else
        echo "No matching pattern in $FILE"
      fi
    done
  done
done
