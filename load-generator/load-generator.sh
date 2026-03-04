#!/bin/sh

BASE_URL="${TARGET_URL:-http://observability-demo:8080}"
RPS="${REQUESTS_PER_SECOND:-3}"
SLEEP_TIME=$(awk "BEGIN {printf \"%.2f\", 1/$RPS}")

TYPES="CPF CPF CPF RG RG RG CNH CNH PROOF_OF_ADDRESS PROOF_OF_ADDRESS SELFIE"

get_random_type() {
    echo $TYPES | tr ' ' '\n' | shuf -n 1
}

echo "Load generator started: ~${RPS} req/s targeting ${BASE_URL}"
echo "Waiting 30s for app to be ready..."
sleep 30

while true; do
    TYPE=$(get_random_type)

    SUBMIT=$(curl -s -X POST "${BASE_URL}/api/documents?type=${TYPE}" 2>/dev/null)
    ID=$(echo "$SUBMIT" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

    if [ -n "$ID" ]; then
        RESULT=$(curl -s -X POST "${BASE_URL}/api/documents/${ID}/validate" 2>/dev/null)
        STATUS=$(echo "$RESULT" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')
        QUEUE=$(echo "$RESULT" | sed -n 's/.*"targetQueue":"\([^"]*\)".*/\1/p')

        if [ -n "$STATUS" ]; then
            echo "[$(date '+%H:%M:%S')] ${TYPE} -> ${STATUS} -> ${QUEUE}"
        else
            ERROR=$(echo "$RESULT" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p')
            echo "[$(date '+%H:%M:%S')] ${TYPE} -> ERROR: ${ERROR}"
        fi
    else
        echo "[$(date '+%H:%M:%S')] ${TYPE} -> SUBMIT FAILED"
    fi

    sleep "$SLEEP_TIME"
done