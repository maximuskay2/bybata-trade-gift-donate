#!/usr/bin/env bash
# Encode Firebase service account JSON for Railway FIREBASE_SERVICE_ACCOUNT_JSON.
# Usage:
#   ./scripts/encode-firebase-service-account.sh path/to/service-account.json
# Paste the single-line output as the variable VALUE (no quotes, no FIREBASE_= prefix in value).

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-firebase-adminsdk.json>" >&2
  exit 1
fi

JSON_FILE="$1"
if [[ ! -f "$JSON_FILE" ]]; then
  echo "File not found: $JSON_FILE" >&2
  exit 1
fi

# Validate JSON before encoding
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$JSON_FILE" 2>/dev/null || {
  echo "Not valid JSON: $JSON_FILE" >&2
  exit 1
}

B64=$(base64 < "$JSON_FILE" | tr -d '\n')
LEN=${#B64}

echo ""
echo "=== Railway variable ==="
echo "Name:  FIREBASE_SERVICE_ACCOUNT_JSON"
echo "Value: (copy everything on the next line — ${LEN} characters)"
echo ""
echo "$B64"
echo ""
echo "=== Tips ==="
echo "- In Railway: Project → API service → Variables → RAW Editor"
echo "- Paste ONLY the base64 line above (no quotes, no FIREBASE_SERVICE_ACCOUNT_JSON= prefix)"
echo "- Redeploy after saving"
echo "- Optional minified JSON instead: jq -c . \"$JSON_FILE\""
