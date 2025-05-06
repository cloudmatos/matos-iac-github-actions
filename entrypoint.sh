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

UNIFY_URL="https://unify-api-srv-nginx-ingress-dev-789054540782.asia-southeast1.run.app"
CNAPP_URL="https://cnapp-api-srv-nginx-ingress-dev-789054540782.asia-southeast1.run.app"
# -- 1) Authenticate to get Bearer token --
LOGIN_ENDPOINT="$UNIFY_URL/api/v1/access-keys/signin"
COOKIE_JAR="$(mktemp)"

# fetch cookies
curl -s -I \
     -H "x-matos-tid: $INPUT_TENANT_ID" \
     -H "x-matos-aky: $INPUT_API_KEY" \
     "$LOGIN_ENDPOINT" \
     -c "$COOKIE_JAR" >/dev/null

# POST to actually sign in & extract token
resp="$(curl -s -X POST "$LOGIN_ENDPOINT" \
    -b "$COOKIE_JAR" \
    -H "x-matos-tid: $INPUT_TENANT_ID" \
    -H "x-matos-aky: $INPUT_API_KEY" \
    -c "$COOKIE_JAR" )"

user_token="$(printf '%s' "$resp" | jq -r '.token')"
if [ -z "$user_token" ] || [ "$user_token" = "null" ]; then
  echo "ERR failed to retrieve user token from $LOGIN_ENDPOINT"
  echo "RESPONSE: $resp"
  exit 1
fi

# -- 2) POST the scan results using Bearer auth --
STORE_ENDPOINT="$CNAPP_URL/cnapp/api/v1/workspaces/iac/findings"
curl -i \
     -H "Accept: application/json" \
     -H "Authorization: Bearer $user_token" \
     -H "Content-Type: application/json" \
     -X POST \
     --data-binary @payload.json \
     "$STORE_ENDPOINT"