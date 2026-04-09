#!/bin/bash
# Usage: ./get_proof.sh <address> <output_file>
ADDRESS=$1
OUT_FILE=$2
URL="http://127.0.0.1:8081/proof/${ADDRESS}"

# Fetch and extract hook_data
# -s: silent
# tr: lowercase for API
# grep/cut: extract hex
RESULT=$(curl -s "$URL" | tr '[:upper:]' '[:lower:]' | grep -o '"hook_data":"0x[0-9a-f]*"' | cut -d':' -f2 | tr -d '"')

if [ -z "$RESULT" ]; then
    echo "ERROR: Could not fetch proof" >&2
    exit 1
fi

echo -n "$RESULT" > "$OUT_FILE"
echo "SUCCESS"
