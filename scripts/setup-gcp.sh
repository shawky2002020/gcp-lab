#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-bq-observe-lab-840614}"
REGION="europe-west1"
BQ_LOCATION="europe-west1"

echo "=== Setting up GCP Infrastructure for Project: $PROJECT_ID ==="

# 1. Configure gcloud
gcloud config set project "$PROJECT_ID"
gcloud config set run/region "$REGION"

# 2. Enable Required APIs
echo "Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  pubsub.googleapis.com \
  bigquery.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  cloudtrace.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  telemetry.googleapis.com \
  --project="$PROJECT_ID"

# 3. Create Service Accounts
echo "Creating dedicated Service Accounts..."
gcloud iam service-accounts create order-api-sa \
  --display-name="Order API Service Account" \
  --project="$PROJECT_ID" || true

gcloud iam service-accounts create analytics-worker-sa \
  --display-name="Analytics Worker Service Account" \
  --project="$PROJECT_ID" || true

gcloud iam service-accounts create pubsub-run-invoker-sa \
  --display-name="PubSub Cloud Run Invoker Service Account" \
  --project="$PROJECT_ID" || true

ORDER_SA="order-api-sa@${PROJECT_ID}.iam.gserviceaccount.com"
WORKER_SA="analytics-worker-sa@${PROJECT_ID}.iam.gserviceaccount.com"
INVOKER_SA="pubsub-run-invoker-sa@${PROJECT_ID}.iam.gserviceaccount.com"
PROJ_NUM=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
PUBSUB_AGENT="service-${PROJ_NUM}@gcp-sa-pubsub.iam.gserviceaccount.com"

# 4. IAM Bindings
echo "Configuring IAM bindings..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${ORDER_SA}" --role="roles/pubsub.publisher"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${ORDER_SA}" --role="roles/cloudtrace.agent"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${WORKER_SA}" --role="roles/cloudtrace.agent"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${WORKER_SA}" --role="roles/bigquery.jobUser"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${WORKER_SA}" --role="roles/bigquery.dataEditor"

# Pub/Sub Agent Token Creator on pubsub-run-invoker-sa
gcloud iam service-accounts add-iam-policy-binding "$INVOKER_SA" \
  --member="serviceAccount:${PUBSUB_AGENT}" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="$PROJECT_ID"

# Cloud Build Artifact Registry Writer
CB_SA="${PROJ_NUM}@cloudbuild.gserviceaccount.com"
COMPUTE_SA="${PROJ_NUM}-compute@developer.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${CB_SA}" --role="roles/artifactregistry.writer"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${COMPUTE_SA}" --role="roles/artifactregistry.writer"

# 5. Create Artifact Registry
echo "Creating Artifact Registry repository..."
gcloud artifacts repositories create gcp-lab-images \
  --repository-format=docker \
  --location="$REGION" \
  --description="Docker repository for lab images" \
  --project="$PROJECT_ID" || true

# 6. Create BigQuery Dataset and Table
echo "Creating BigQuery Dataset and Table..."
bq --project_id="$PROJECT_ID" mk --location="$BQ_LOCATION" --dataset "${PROJECT_ID}:analytics_lab" || true

bq --project_id="$PROJECT_ID" mk --table \
  --time_partitioning_field=created_at \
  --time_partitioning_type=DAY \
  --clustering_fields=user_id,status \
  "${PROJECT_ID}:analytics_lab.order_events" \
  ./schema.json || true

# 7. Create Pub/Sub Topic
echo "Creating Pub/Sub topic..."
gcloud pubsub topics create order-events --project="$PROJECT_ID" || true

echo "=== GCP Infrastructure Setup Completed Successfully ==="
