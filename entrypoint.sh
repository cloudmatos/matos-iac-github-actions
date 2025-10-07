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

if [ -z "$INPUT_TENANT_ID" ]; then
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

UNIFY_URL="https://app-dev-api.cloudmatos.ai"
CNAPP_URL="https://app-dev-api-cnapp.cloudmatos.ai"
# -- 1) Authenticate to get Bearer token --
LOGIN_ENDPOINT="$UNIFY_URL/api/v1/access-keys/signin"
COOKIE_JAR="$(mktemp)"

cleanup() {
  rm -f "$COOKIE_JAR"
}
trap cleanup EXIT

echo "INPUT_TENANT_ID = '$INPUT_TENANT_ID'"
echo "GIT_URL = '$GIT_URL'"
echo "INPUT_API_KEY    = '${INPUT_API_KEY:0:4}…'"
echo "LOGIN_ENDPOINT  = '$LOGIN_ENDPOINT'"
echo "COOKIE_JAR      = '$COOKIE_JAR'"

echo "HEAD $LOGIN_ENDPOINT"
head_status=$(curl -sSI \
  -H "x-matos-tid: $INPUT_TENANT_ID" \
  -H "x-matos-aky: $INPUT_API_KEY" \
  -c "$COOKIE_JAR" \
  "$LOGIN_ENDPOINT" \
  | awk 'NR==1 {print $2}')
echo "HEAD HTTP status: $head_status"
if [[ "$head_status" != "200" ]]; then
  echo "HEAD request failed with status $head_status"
  exit 1
fi

echo "POST $LOGIN_ENDPOINT"
resp="$(curl -sSL \
  -X POST "$LOGIN_ENDPOINT" \
  -b "$COOKIE_JAR" \
  -H "x-matos-tid: $INPUT_TENANT_ID" \
  -H "x-matos-aky: $INPUT_API_KEY" \
  -c "$COOKIE_JAR")"
echo "   ↳ Response payload: $resp"

user_token="$(jq -r '.token // empty' <<<"$resp")"
if [[ -z "$user_token" ]]; then
  echo "Failed to retrieve user token from $LOGIN_ENDPOINT"
  echo "   Response was: $resp"
  exit 1
fi
echo "Retrieved token: $user_token"

# ————— 3) POST scan results with Bearer auth ———————————————————————
STORE_ENDPOINT="$CNAPP_URL/cnapp/api/v1/workspaces/iac/findings"
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
  -H "Authorization: Bearer $user_token" \
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