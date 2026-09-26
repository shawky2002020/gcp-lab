#!/usr/bin/env bash
set -uo pipefail

PROJECT_ID="${1:-bq-observe-lab-840614}"
REGION="europe-west1"

echo "=========================================================="
echo "    GCP BigQuery & Observability Lab — Resource Cleanup   "
echo "    Project: $PROJECT_ID                                  "
echo "=========================================================="
echo "NOTE: This script removes all deployed resources inside the project."
echo "If this project was created specifically for this lab, the cleanest"
echo "and most complete cleanup is to delete the entire project:"
echo "    gcloud projects delete $PROJECT_ID"
echo "=========================================================="
read -p "Are you sure you want to clean up individual resources? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo "1. Deleting Cloud Monitoring Alert Policies..."
for policy in $(gcloud monitoring policies list --project="$PROJECT_ID" --uri 2>/dev/null); do
  echo "Deleting alert policy: $policy"
  gcloud monitoring policies delete "$policy" --quiet --project="$PROJECT_ID" || true
done

echo "2. Deleting Cloud Monitoring Dashboards..."
for dash in $(gcloud monitoring dashboards list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null); do
  echo "Deleting dashboard: $dash"
  gcloud monitoring dashboards delete "$dash" --quiet || true
done

echo "3. Deleting Log-based Metrics..."
gcloud logging metrics delete lab_error_count --quiet --project="$PROJECT_ID" || true

echo "4. Deleting Cloud Run services..."
gcloud run services delete order-api --region="$REGION" --quiet --project="$PROJECT_ID" || true
gcloud run services delete analytics-worker --region="$REGION" --quiet --project="$PROJECT_ID" || true

echo "5. Deleting Pub/Sub Subscription and Topic..."
gcloud pubsub subscriptions delete order-events-sub --quiet --project="$PROJECT_ID" || true
gcloud pubsub topics delete order-events --quiet --project="$PROJECT_ID" || true

echo "6. Deleting BigQuery Dataset and Tables..."
bq rm -r -f -d "${PROJECT_ID}:analytics_lab" || true

echo "7. Deleting Artifact Registry Repository..."
gcloud artifacts repositories delete gcp-lab-images --location="$REGION" --quiet --project="$PROJECT_ID" || true

echo "8. Deleting Service Accounts..."
gcloud iam service-accounts delete "order-api-sa@${PROJECT_ID}.iam.gserviceaccount.com" --quiet --project="$PROJECT_ID" || true
gcloud iam service-accounts delete "analytics-worker-sa@${PROJECT_ID}.iam.gserviceaccount.com" --quiet --project="$PROJECT_ID" || true
gcloud iam service-accounts delete "pubsub-run-invoker-sa@${PROJECT_ID}.iam.gserviceaccount.com" --quiet --project="$PROJECT_ID" || true

echo "=== Individual Resource Cleanup Complete ==="
echo "To delete the entire project and stop all billing immediately:"
echo "    gcloud projects delete $PROJECT_ID"
