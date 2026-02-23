#!/bin/bash
# scripts/test-vllm-api.sh
# Test vLLM inference through the API gateway
#
# Usage:
#   bash test-vllm-api.sh                    # Test via API gateway (port 8000)
#   bash test-vllm-api.sh --direct           # Test vLLM directly (port 8001)
#   bash test-vllm-api.sh --api-key KEY      # Test with API key auth

set -euo pipefail

# Defaults
API_PORT=8000
API_KEY=""
DIRECT=false
HOST="localhost"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --direct)
            DIRECT=true
            API_PORT=8001
            shift
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --port)
            API_PORT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--direct] [--api-key KEY] [--host HOST] [--port PORT]"
            exit 1
            ;;
    esac
done

BASE_URL="http://${HOST}:${API_PORT}"

# Build auth header
AUTH_HEADER=""
if [ -n "$API_KEY" ]; then
    AUTH_HEADER="-H \"Authorization: Bearer ${API_KEY}\""
fi

echo "=== Vault AI Inference Test ==="
echo "Target: ${BASE_URL}"
echo "Mode: $([ "$DIRECT" = true ] && echo 'Direct vLLM' || echo 'API Gateway')"
echo ""

# Test 1: List models
echo "--- Test 1: List Models ---"
MODELS_RESPONSE=$(eval curl -s ${AUTH_HEADER} "${BASE_URL}/v1/models")
echo "$MODELS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$MODELS_RESPONSE"
echo ""

# Extract first model ID
MODEL_ID=$(echo "$MODELS_RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
models = data.get('data', data.get('models', []))
if models:
    print(models[0].get('id', ''))
" 2>/dev/null || echo "")

if [ -z "$MODEL_ID" ]; then
    echo "ERROR: No models found"
    exit 1
fi
echo "Using model: ${MODEL_ID}"
echo ""

# Test 2: Chat completion (non-streaming)
echo "--- Test 2: Chat Completion ---"
START_TIME=$(date +%s%N)

CHAT_RESPONSE=$(eval curl -s ${AUTH_HEADER} \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"${MODEL_ID}\",
        \"messages\": [{\"role\": \"user\", \"content\": \"What is 2+2? Answer in one word.\"}],
        \"max_tokens\": 50,
        \"stream\": false
    }" \
    "${BASE_URL}/v1/chat/completions")

END_TIME=$(date +%s%N)
ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))

echo "$CHAT_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$CHAT_RESPONSE"
echo ""
echo "Latency: ${ELAPSED_MS}ms"

# Extract token counts
python3 -c "
import json, sys
data = json.loads('''${CHAT_RESPONSE}''')
usage = data.get('usage', {})
if usage:
    prompt = usage.get('prompt_tokens', 0)
    completion = usage.get('completion_tokens', 0)
    total = usage.get('total_tokens', 0)
    print(f'Tokens — prompt: {prompt}, completion: {completion}, total: {total}')
    if ${ELAPSED_MS} > 0:
        tps = completion / (${ELAPSED_MS} / 1000)
        print(f'Throughput: {tps:.1f} tokens/sec')
" 2>/dev/null || true
echo ""

# Test 3: Streaming chat completion
echo "--- Test 3: Streaming Chat Completion ---"
START_TIME=$(date +%s%N)

STREAM_RESPONSE=$(eval curl -s ${AUTH_HEADER} \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"${MODEL_ID}\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Count from 1 to 5.\"}],
        \"max_tokens\": 100,
        \"stream\": true
    }" \
    "${BASE_URL}/v1/chat/completions")

END_TIME=$(date +%s%N)
ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))

# Count chunks
CHUNK_COUNT=$(echo "$STREAM_RESPONSE" | grep -c "^data: {" || true)
echo "Received ${CHUNK_COUNT} streaming chunks in ${ELAPSED_MS}ms"

# Extract streamed text
STREAMED_TEXT=$(echo "$STREAM_RESPONSE" | grep "^data: {" | python3 -c "
import json, sys
text = ''
for line in sys.stdin:
    line = line.strip()
    if line.startswith('data: '):
        try:
            data = json.loads(line[6:])
            delta = data.get('choices', [{}])[0].get('delta', {})
            content = delta.get('content', '')
            text += content
        except json.JSONDecodeError:
            pass
print(text)
" 2>/dev/null || echo "(could not parse)")

echo "Streamed text: ${STREAMED_TEXT}"
echo ""

# Summary
echo "=== Test Summary ==="
echo "Models available: yes"
echo "Chat completion: $([ -n "$CHAT_RESPONSE" ] && echo 'pass' || echo 'FAIL')"
echo "Streaming: $([ "$CHUNK_COUNT" -gt 0 ] && echo 'pass' || echo 'FAIL')"
echo ""

if [ -n "$CHAT_RESPONSE" ] && [ "$CHUNK_COUNT" -gt 0 ]; then
    echo "All tests passed"
    exit 0
else
    echo "Some tests failed"
    exit 1
fi
