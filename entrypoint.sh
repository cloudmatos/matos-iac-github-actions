#!/bin/bash
if [ ! -z $INPUT_USERNAME ];
then echo $INPUT_PASSWORD | docker login $INPUT_REGISTRY -u $INPUT_USERNAME --password-stdin
fi

if [ ! -z $INPUT_DOCKER_NETWORK ];
then INPUT_OPTIONS="$INPUT_OPTIONS --network $INPUT_DOCKER_NETWORK"
fi

if [ -z "$INPUT_API_KEY" ]; then
    echo "${DATETIME} - ERR input api key can't be empty"
    exit 1
fi

if [ -z "$INPUT_SCAN_DIR" ]; then
    echo "${DATETIME} - ERR input path can't be empty"
    exit 1
else
    INPUT_PARAM="-p $INPUT_SCAN_DIR"
fi

CP_PATH="./results.json"
OUTPUT_PATH_PARAM="-o ./"
cd $GITHUB_WORKSPACE
/app/bin/kics scan --no-progress $INPUT_PARAM $OUTPUT_PATH_PARAM

GIT_URL="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY"
cp -r "${CP_PATH}" "/app/"
cd /app

jq -nc --argfile results "./results.json" --arg git_url "$GIT_URL" \
    '{ data: $results, git_url: $git_url }' > payload.json

echo "GIT_URL = '$GIT_URL'"
echo "INPUT_API_KEY    = '${INPUT_API_KEY:0:4}…'"
echo "SERVER_URL      = '$INPUT_SERVER_URL'"

# ————— POST scan results with API Key ———————————————————————
STORE_ENDPOINT="$INPUT_SERVER_URL/cnapp/api/v1/workspaces/iac/findings"
echo "POST results to $STORE_ENDPOINT"

# Debug: Show payload structure (first 500 chars)
echo "=== PAYLOAD PREVIEW (first 500 chars) ==="
head -c 500 payload.json
echo ""
echo "=== END PAYLOAD PREVIEW ==="

# Debug: Show payload size
payload_size=$(wc -c < payload.json)
echo "Payload size: $payload_size bytes"

# Store response
echo "Sending POST request..."
post_response=$(curl -w "\nHTTP_STATUS:%{http_code}" -i \
  -H "Accept: application/json" \
  -H "X-API-Key: $INPUT_API_KEY" \
  -H "Content-Type: application/json" \
  -X POST \
  --data-binary @payload.json \
  "$STORE_ENDPOINT" 2>&1)

echo "=== POST RESPONSE ==="
echo "$post_response"
echo "=== END POST RESPONSE ==="

# Extract HTTP status
http_status=$(echo "$post_response" | grep "HTTP_STATUS:" | cut -d':' -f2)
echo "HTTP Status: $http_status"

if [[ "$http_status" != "200" && "$http_status" != "201" ]]; then
  echo "ERROR: POST request failed with status $http_status"
  exit 1
fi

echo "Scan results submitted successfully."