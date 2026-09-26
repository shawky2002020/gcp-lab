$proj = "bq-observe-lab-840614"
$region = "europe-west1"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    GCP BigQuery & Observability Lab - Verification       " -ForegroundColor Cyan
Write-Host "    Project: $proj                                        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$passed = 0
$failed = 0

function Run-Check([string]$desc, [scriptblock]$action) {
    Write-Host -NoNewline "[CHECK] $desc ... "
    try {
        $null = & $action
        if ($LASTEXITCODE -eq 0 -or $?) {
            Write-Host "PASS" -ForegroundColor Green
            $script:passed++
        } else {
            Write-Host "FAIL" -ForegroundColor Red
            $script:failed++
        }
    } catch {
        Write-Host "FAIL" -ForegroundColor Red
        $script:failed++
    }
}

Run-Check "GCP Project active" { gcloud projects describe $proj }
Run-Check "Cloud Run API enabled" { gcloud services list --enabled --project=$proj | Select-String "run.googleapis.com" }
Run-Check "Pub/Sub API enabled" { gcloud services list --enabled --project=$proj | Select-String "pubsub.googleapis.com" }
Run-Check "BigQuery API enabled" { gcloud services list --enabled --project=$proj | Select-String "bigquery.googleapis.com" }
Run-Check "Cloud Trace API enabled" { gcloud services list --enabled --project=$proj | Select-String "cloudtrace.googleapis.com" }
Run-Check "order-api-sa exists" { gcloud iam service-accounts describe "order-api-sa@$proj.iam.gserviceaccount.com" --project=$proj }
Run-Check "analytics-worker-sa exists" { gcloud iam service-accounts describe "analytics-worker-sa@$proj.iam.gserviceaccount.com" --project=$proj }
Run-Check "pubsub-run-invoker-sa exists" { gcloud iam service-accounts describe "pubsub-run-invoker-sa@$proj.iam.gserviceaccount.com" --project=$proj }
Run-Check "Artifact Registry repo exists" { gcloud artifacts repositories describe gcp-lab-images --location=$region --project=$proj }
Run-Check "order-api Cloud Run service exists" { gcloud run services describe order-api --region=$region --project=$proj }
Run-Check "analytics-worker Cloud Run service exists" { gcloud run services describe analytics-worker --region=$region --project=$proj }
Run-Check "Pub/Sub topic order-events exists" { gcloud pubsub topics describe order-events --project=$proj }
Run-Check "Pub/Sub subscription order-events-sub exists" { gcloud pubsub subscriptions describe order-events-sub --project=$proj }
Run-Check "BigQuery dataset analytics_lab exists" { bq show "$proj:analytics_lab" }
Run-Check "BigQuery table order_events exists" { bq show "$proj:analytics_lab.order_events" }
Run-Check "Rows exist in BigQuery" { "SELECT count(*) FROM ``$proj.analytics_lab.order_events``" | bq query --use_legacy_sql=false }
Run-Check "Log-based metric lab_error_count exists" { gcloud logging metrics describe lab_error_count --project=$proj }
Run-Check "Cloud Monitoring Alert Policy exists" { gcloud monitoring policies list --project=$proj | Select-String "Lab High Application Error Rate" }
Run-Check "Cloud Monitoring Dashboard exists" { gcloud monitoring dashboards list --project=$proj | Select-String "BigQuery Observability Lab" }

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "    Verification Summary: $passed PASSED, $failed FAILED  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
