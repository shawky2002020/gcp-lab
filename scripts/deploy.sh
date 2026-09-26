#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-bq-observe-lab-840614}"
REGION="europe-west1"
REPO="europe-west1-docker.pkg.dev/${PROJECT_ID}/gcp-lab-images"

echo "=== Building and Deploying Services to Cloud Run ==="

# 1. Build and Submit Analytics Worker
echo "Building analytics-worker image..."
gcloud builds submit ./services/analytics-worker \
  --tag "${REPO}/analytics-worker:v1" \
  --project="$PROJECT_ID"

# 2. Deploy Analytics Worker (Private)
echo "Deploying analytics-worker (private)..."
gcloud run deploy analytics-worker \
  --image="${REPO}/analytics-worker:v1" \
  --region="$REGION" \
  --service-account="analytics-worker-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --no-allow-unauthenticated \
  --set-env-vars="PROJECT_ID=${PROJECT_ID},DATASET_ID=analytics_lab,TABLE_ID=order_events,SERVICE_NAME=analytics-worker" \
  --project="$PROJECT_ID"

WORKER_URL=$(gcloud run services describe analytics-worker --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)")
INVOKER_SA="pubsub-run-invoker-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# 3. Grant run.invoker to pubsub-run-invoker-sa on analytics-worker
echo "Granting roles/run.invoker to ${INVOKER_SA} on analytics-worker..."
gcloud run services add-iam-policy-binding analytics-worker \
  --region="$REGION" \
  --member="serviceAccount:${INVOKER_SA}" \
  --role="roles/run.invoker" \
  --project="$PROJECT_ID"

# 4. Create Pub/Sub Push Subscription with OIDC Authentication
echo "Creating authenticated Pub/Sub push subscription..."
gcloud pubsub subscriptions create order-events-sub \
  --topic=order-events \
  --push-endpoint="$WORKER_URL" \
  --push-auth-service-account="$INVOKER_SA" \
  --ack-deadline=30 \
  --project="$PROJECT_ID" || true

# 5. Build and Submit Order API
echo "Building order-api image..."
gcloud builds submit ./services/order-api \
  --tag "${REPO}/order-api:v1" \
  --project="$PROJECT_ID"

# 6. Deploy Order API (Public)
echo "Deploying order-api (public)..."
gcloud run deploy order-api \
  --image="${REPO}/order-api:v1" \
  --region="$REGION" \
  --service-account="order-api-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --allow-unauthenticated \
  --set-env-vars="PROJECT_ID=${PROJECT_ID},TOPIC_NAME=order-events,SERVICE_NAME=order-api" \
  --project="$PROJECT_ID"

ORDER_API_URL=$(gcloud run services describe order-api --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)")

echo "=== Deployment Completed Successfully ==="
echo "Order API URL: $ORDER_API_URL"
echo "Analytics Worker URL: $WORKER_URL (Private)"
