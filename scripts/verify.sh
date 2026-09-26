#!/usr/bin/env bash
set -uo pipefail

PROJECT_ID="${1:-bq-observe-lab-840614}"
REGION="europe-west1"

echo "=========================================================="
echo "    GCP BigQuery & Observability Lab — Verification       "
echo "    Project: $PROJECT_ID                                  "
echo "=========================================================="

PASSED=0
FAILED=0

check() {
  local desc="$1"
  local cmd="$2"
  echo -n "[CHECK] $desc ... "
  if eval "$cmd" > /dev/null 2>&1; then
    echo "PASS"
    ((PASSED++))
  else
    echo "FAIL"
    ((FAILED++))
  fi
}

# 1. Project exists and active
check "GCP Project active" "gcloud projects describe $PROJECT_ID"

# 2. Required APIs enabled
check "Cloud Run API enabled" "gcloud services list --enabled --project=$PROJECT_ID | grep -q run.googleapis.com"
check "Pub/Sub API enabled" "gcloud services list --enabled --project=$PROJECT_ID | grep -q pubsub.googleapis.com"
check "BigQuery API enabled" "gcloud services list --enabled --project=$PROJECT_ID | grep -q bigquery.googleapis.com"
check "Cloud Trace API enabled" "gcloud services list --enabled --project=$PROJECT_ID | grep -q cloudtrace.googleapis.com"

# 3. Service Accounts exist
check "order-api-sa exists" "gcloud iam service-accounts describe order-api-sa@${PROJECT_ID}.iam.gserviceaccount.com --project=$PROJECT_ID"
check "analytics-worker-sa exists" "gcloud iam service-accounts describe analytics-worker-sa@${PROJECT_ID}.iam.gserviceaccount.com --project=$PROJECT_ID"
check "pubsub-run-invoker-sa exists" "gcloud iam service-accounts describe pubsub-run-invoker-sa@${PROJECT_ID}.iam.gserviceaccount.com --project=$PROJECT_ID"

# 4. Artifact Registry repository exists
check "Artifact Registry gcp-lab-images exists" "gcloud artifacts repositories describe gcp-lab-images --location=$REGION --project=$PROJECT_ID"

# 5. Cloud Run services exist
check "order-api Cloud Run service exists" "gcloud run services describe order-api --region=$REGION --project=$PROJECT_ID"
check "analytics-worker Cloud Run service exists" "gcloud run services describe analytics-worker --region=$REGION --project=$PROJECT_ID"

# 6. Pub/Sub Topic and Subscription exist
check "Pub/Sub topic order-events exists" "gcloud pubsub topics describe order-events --project=$PROJECT_ID"
check "Pub/Sub push subscription order-events-sub exists" "gcloud pubsub subscriptions describe order-events-sub --project=$PROJECT_ID"

# 7. BigQuery Dataset and Table exist
check "BigQuery dataset analytics_lab exists" "bq show ${PROJECT_ID}:analytics_lab"
check "BigQuery table order_events exists" "bq show ${PROJECT_ID}:analytics_lab.order_events"

# 8. BigQuery rows populated
check "BigQuery rows exist in order_events" "bq query --use_legacy_sql=false --project_id=$PROJECT_ID 'SELECT count(*) FROM \`${PROJECT_ID}.analytics_lab.order_events\`' | grep -v 'count' | grep -E '[1-9]'"

# 9. Observability: Metric & Alert Policy & Dashboard
check "Log-based metric lab_error_count exists" "gcloud logging metrics describe lab_error_count --project=$PROJECT_ID"
check "Cloud Monitoring Alert Policy exists" "gcloud monitoring policies list --project=$PROJECT_ID | grep -q 'Lab High Application Error Rate'"
check "Cloud Monitoring Dashboard exists" "gcloud monitoring dashboards list --project=$PROJECT_ID | grep -q 'BigQuery Observability Lab'"

echo "=========================================================="
echo "    Verification Summary: $PASSED PASSED, $FAILED FAILED "
echo "=========================================================="

if [ $FAILED -eq 0 ]; then
  exit 0
else
  exit 1
fi
