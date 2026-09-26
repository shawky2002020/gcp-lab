#!/usr/bin/env bash
set -euo pipefail

ORDER_API_URL="${1:-https://order-api-769996365752.europe-west1.run.app}"

echo "=== Starting Traffic Generation against $ORDER_API_URL ==="

USERS=("alice" "bob" "charlie" "dana" "elena" "fahad" "george" "hannah")
ORDERS_COUNT=25

echo "Sending $ORDERS_COUNT domain order events..."
for i in $(seq 1 $ORDERS_COUNT); do
  USER_INDEX=$((i % ${#USERS[@]}))
  USER="${USERS[$USER_INDEX]}"
  AMOUNT=$((RANDOM % 400 + 20)).$((RANDOM % 99))

  RESP=$(curl -s -X POST "$ORDER_API_URL/orders" \
    -H "Content-Type: application/json" \
    -d "{\"userId\": \"$USER\", \"amount\": $AMOUNT}")

  ORDER_ID=$(echo "$RESP" | grep -o '"orderId":"[^"]*' | cut -d'"' -f4 || echo "unknown")
  echo "[$i/$ORDERS_COUNT] Created order: $ORDER_ID for user: $USER (\$$AMOUNT)"
  sleep 0.2
done

echo ""
echo "Sending slow requests for latency metrics and tracing..."
for s in 400 800 1200; do
  curl -s "$ORDER_API_URL/slow?ms=$s" > /dev/null
  echo "[Slow] Simulated ${s}ms latency request completed."
done

echo ""
echo "Sending controlled test error..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ORDER_API_URL/test-error" || true)
echo "Controlled test-error endpoint returned HTTP $HTTP_CODE (expected 500)"

echo ""
echo "=== Traffic Generation Completed ==="
