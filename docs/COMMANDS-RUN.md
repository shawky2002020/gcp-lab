# Complete GCP Command Audit Trail

This document details every significant Google Cloud CLI (`gcloud`), BigQuery (`bq`), and PowerShell command executed to build, configure, test, debug, and verify this laboratory.

---

## Command 1 — Initial Environment Inspection
**Command:**
```bash
gcloud --version
gcloud auth list
gcloud config list
gcloud billing accounts list
```
- **Purpose:** Inspect existing CLI tooling, active authenticated Google account, active project configuration, and discover available billing accounts before provisioning.
- **Resource Affected:** Local client environment & configuration.
- **Result:** Authenticated as `shawkyelsayed2002@gmail.com`; detected open billing account `017F59-43040C-2E1313` ("My Billing Account").
- **Interview Lesson:** Always inspect billing accounts and credential context *before* executing provisioning commands to avoid deploying resources into unintended projects or incurring surprise personal billing charges.

---

## Command 2 — Create Disposable GCP Project
**Command:**
```powershell
$suffix = Get-Random -Minimum 100000 -Maximum 999999
$proj = "bq-observe-lab-$suffix" # Evaluated to bq-observe-lab-840614
gcloud projects create $proj --name="BigQuery Observability Lab"
```
- **Purpose:** Provision an isolated, clean GCP project specifically for the lab.
- **Resource Affected:** GCP Project `projects/bq-observe-lab-840614` (Project Number: `769996365752`).
- **Result:** Project created successfully in ~8 seconds.
- **Verify Using:** `gcloud projects describe bq-observe-lab-840614`
- **Console:** Cloud Resource Manager -> Projects.

---

## Command 3 — Link Billing Account to Project
**Command:**
```bash
gcloud billing projects link bq-observe-lab-840614 --billing-account=017F59-43040C-2E1313
```
- **Purpose:** Enable billing on the new project so serverless APIs and Cloud Run containers can execute.
- **Resource Affected:** `projects/bq-observe-lab-840614/billingInfo`
- **Result:** `billingEnabled: true`.
- **Verify Using:** `gcloud billing projects describe bq-observe-lab-840614`
- **Console:** Billing -> My Projects.

---

## Command 4 — Configure CLI Active Project and Default Region
**Command:**
```bash
gcloud config set project bq-observe-lab-840614
gcloud config set run/region europe-west1
```
- **Purpose:** Set active working context for subsequent `gcloud` and `bq` commands.
- **Resource Affected:** Local `~/.config/gcloud/configurations/config_default`.
- **Result:** Properties updated.

---

## Command 5 — Enable Required GCP Service APIs
**Command:**
```bash
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
  --project=bq-observe-lab-840614
```
- **Purpose:** Activate the control plane endpoints for each GCP product used in this architecture.
- **Resource Affected:** Service Usage state for project `bq-observe-lab-840614`.
- **Result:** Operation finished successfully.
- **Verify Using:** `gcloud services list --enabled --project=bq-observe-lab-840614`
- **Interview Lesson:** Enabling an API allows the project to interact with that Google service’s API gateway and provisions Google internal Service Agents (e.g. `service-<NUM>@gcp-sa-pubsub...`). Enabling an API does *not* grant user IAM permissions; IAM permissions control *who* can call those enabled APIs.

---

## Command 6 — Create Dedicated Service Accounts
**Command:**
```bash
gcloud iam service-accounts create order-api-sa \
    --display-name="Order API Service Account" \
    --project=bq-observe-lab-840614

gcloud iam service-accounts create analytics-worker-sa \
    --display-name="Analytics Worker Service Account" \
    --project=bq-observe-lab-840614

gcloud iam service-accounts create pubsub-run-invoker-sa \
    --display-name="PubSub Cloud Run Invoker Service Account" \
    --project=bq-observe-lab-840614
```
- **Purpose:** Provision three distinct identities according to Least Privilege.
- **Resources Affected:**
  - `order-api-sa@bq-observe-lab-840614.iam.gserviceaccount.com`
  - `analytics-worker-sa@bq-observe-lab-840614.iam.gserviceaccount.com`
  - `pubsub-run-invoker-sa@bq-observe-lab-840614.iam.gserviceaccount.com`
- **Verify Using:** `gcloud iam service-accounts list --project=bq-observe-lab-840614`
- **Console:** IAM & Admin -> Service Accounts.

---

## Command 7 — Configure Service Account IAM Roles
**Command:**
```bash
# Order API Permissions
gcloud projects add-iam-policy-binding bq-observe-lab-840614 \
    --member="serviceAccount:order-api-sa@bq-observe-lab-840614.iam.gserviceaccount.com" \
    --role="roles/pubsub.publisher"

gcloud projects add-iam-policy-binding bq-observe-lab-840614 \
    --member="serviceAccount:order-api-sa@bq-observe-lab-840614.iam.gserviceaccount.com" \
    --role="roles/cloudtrace.agent"

# Worker Permissions
gcloud projects add-iam-policy-binding bq-observe-lab-840614 \
    --member="serviceAccount:analytics-worker-sa@bq-observe-lab-840614.iam.gserviceaccount.com" \
    --role="roles/cloudtrace.agent"

gcloud projects add-iam-policy-binding bq-observe-lab-840614 \
    --member="serviceAccount:analytics-worker-sa@bq-observe-lab-840614.iam.gserviceaccount.com" \
    --role="roles/bigquery.jobUser"

gcloud projects add-iam-policy-binding bq-observe-lab-840614 \
    --member="serviceAccount:analytics-worker-sa@bq-observe-lab-840614.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor"
```
- **Purpose:** Grant publishing rights and trace export rights to `order-api-sa`, and BigQuery write rights and trace export rights to `analytics-worker-sa`.
- **Verify Using:** `gcloud projects get-iam-policy bq-observe-lab-840614`

---

## Command 8 — Authorize Pub/Sub Service Agent to Mint Tokens
**Command:**
```bash
gcloud iam service-accounts add-iam-policy-binding \
    pubsub-run-invoker-sa@bq-observe-lab-840614.iam.gserviceaccount.com \
    --member="serviceAccount:service-769996365752@gcp-sa-pubsub.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountTokenCreator" \
    --project=bq-observe-lab-840614
```
- **Purpose:** Allow the Google-managed Pub/Sub service agent to create signed OIDC identity tokens impersonating `pubsub-run-invoker-sa`.
- **Verify Using:** `gcloud iam service-accounts get-iam-policy pubsub-run-invoker-sa@...`
- **Interview Lesson:** Pub/Sub push authentication to Cloud Run requires this step. Without `serviceAccountTokenCreator`, Pub/Sub push attempts fail with internal authentication errors because Pub/Sub cannot mint the JWT token.

---

## Command 9 — Create Artifact Registry Docker Repository
**Command:**
```bash
gcloud artifacts repositories create gcp-lab-images \
    --repository-format=docker \
    --location=europe-west1 \
    --description="Docker repository for lab images" \
    --project=bq-observe-lab-840614
```
- **Purpose:** Provision a private OCI/Docker container registry in `europe-west1`.
- **Resource Affected:** `projects/bq-observe-lab-840614/locations/europe-west1/repositories/gcp-lab-images`.
- **Verify Using:** `gcloud artifacts repositories list --location=europe-west1`
- **Console:** Artifact Registry -> Repositories.

---

## Command 10 — Create BigQuery Dataset
**Command:**
```bash
bq --project_id=bq-observe-lab-840614 mk --location=europe-west1 --dataset bq-observe-lab-840614:analytics_lab
```
- **Purpose:** Create top-level BigQuery container for analytical tables.
- **Resource Affected:** Dataset `bq-observe-lab-840614:analytics_lab`.
- **Verify Using:** `bq show bq-observe-lab-840614:analytics_lab`
- **Console:** BigQuery -> Studio -> Explorer.

---

## Command 11 — Create Partitioned and Clustered BigQuery Table
**Command:**
```bash
bq --project_id=bq-observe-lab-840614 mk --table \
    --time_partitioning_field=created_at \
    --time_partitioning_type=DAY \
    --clustering_fields=user_id,status \
    bq-observe-lab-840614:analytics_lab.order_events \
    ./schema.json
```
- **Purpose:** Create table `order_events` with DAY partitioning on `created_at` and clustering on `user_id, status`.
- **Resource Affected:** Table `bq-observe-lab-840614:analytics_lab.order_events`.
- **Verify Using:** `bq show --format=prettyjson bq-observe-lab-840614:analytics_lab.order_events`

### Debugging Note / Command Failure Documented:
- *Failed Attempt:* `bq add-iam-policy-binding --member="serviceAccount:..." --role="roles/bigquery.dataEditor" bq-observe-lab-840614:analytics_lab`
- *Error:* `BigQuery error in add-iam-policy-binding operation: This feature requires allowlisting.`
- *Cause:* The `bq add-iam-policy-binding` CLI command invokes a preview API endpoint that requires specific organization allowlisting.
- *Corrected Command:* `gcloud projects add-iam-policy-binding bq-observe-lab-840614 --member="serviceAccount:analytics-worker-sa@..." --role="roles/bigquery.dataEditor"`
- *Lesson Learned:* When dataset-level IAM command variants are restricted by organization policy or preview flags, project-level standard IAM policy bindings reliably provide data editing rights without blockers.

---

## Command 12 — Create Pub/Sub Topic
**Command:**
```bash
gcloud pubsub topics create order-events --project=bq-observe-lab-840614
```
- **Purpose:** Provision the asynchronous event topic.
- **Resource Affected:** `projects/bq-observe-lab-840614/topics/order-events`.
- **Verify Using:** `gcloud pubsub topics describe order-events`
- **Console:** Pub/Sub -> Topics.

---

## Command 13 — Build Container Images with Cloud Build
**Commands:**
```bash
gcloud builds submit ./services/analytics-worker \
    --tag europe-west1-docker.pkg.dev/bq-observe-lab-840614/gcp-lab-images/analytics-worker:v1 \
    --project=bq-observe-lab-840614

gcloud builds submit ./services/order-api \
    --tag europe-west1-docker.pkg.dev/bq-observe-lab-840614/gcp-lab-images/order-api:v1 \
    --project=bq-observe-lab-840614
```
- **Purpose:** Compile TypeScript source code into container images in the cloud using Google Cloud Build.
- **Verify Using:** `gcloud artifacts docker images list europe-west1-docker.pkg.dev/bq-observe-lab-840614/gcp-lab-images`
- **Console:** Cloud Build -> History.

---

## Command 14 — Deploy Private Analytics Worker to Cloud Run
**Command:**
```bash
gcloud run deploy analytics-worker \
    --image="europe-west1-docker.pkg.dev/bq-observe-lab-840614/gcp-lab-images/analytics-worker:v1" \
    --region=europe-west1 \
    --service-account="analytics-worker-sa@bq-observe-lab-840614.iam.gserviceaccount.com" \
    --no-allow-unauthenticated \
    --set-env-vars="PROJECT_ID=bq-observe-lab-840614,DATASET_ID=analytics_lab,TABLE_ID=order_events,SERVICE_NAME=analytics-worker" \
    --project=bq-observe-lab-840614
```
- **Purpose:** Launch private background consumer service on Cloud Run.
- **Resource Affected:** Cloud Run Service `analytics-worker` (URL: `https://analytics-worker-769996365752.europe-west1.run.app`).
- **Result:** Successfully deployed revision `analytics-worker-00001-ntj`.

---

## Command 15 — Authorize Pub/Sub Invoker SA on Private Worker
**Command:**
```bash
gcloud run services add-iam-policy-binding analytics-worker \
    --region=europe-west1 \
    --member="serviceAccount:pubsub-run-invoker-sa@bq-observe-lab-840614.iam.gserviceaccount.com" \
    --role="roles/run.invoker" \
    --project=bq-observe-lab-840614
```
- **Purpose:** Authorize identity `pubsub-run-invoker-sa` to invoke the private Cloud Run service.
- **Verify Using:** `gcloud run services get-iam-policy analytics-worker --region=europe-west1`

---

## Command 16 — Create Authenticated Pub/Sub Push Subscription
**Command:**
```bash
gcloud pubsub subscriptions create order-events-sub \
    --topic=order-events \
    --push-endpoint="https://analytics-worker-769996365752.europe-west1.run.app" \
    --push-auth-service-account="pubsub-run-invoker-sa@bq-observe-lab-840614.iam.gserviceaccount.com" \
    --ack-deadline=30 \
    --project=bq-observe-lab-840614
```
- **Purpose:** Wire topic to private worker using OIDC token authentication.
- **Verify Using:** `gcloud pubsub subscriptions describe order-events-sub`

---

## Command 17 — Deploy Public Order API to Cloud Run
**Command:**
```bash
gcloud run deploy order-api \
    --image="europe-west1-docker.pkg.dev/bq-observe-lab-840614/gcp-lab-images/order-api:v1" \
    --region=europe-west1 \
    --service-account="order-api-sa@bq-observe-lab-840614.iam.gserviceaccount.com" \
    --allow-unauthenticated \
    --set-env-vars="PROJECT_ID=bq-observe-lab-840614,TOPIC_NAME=order-events,SERVICE_NAME=order-api" \
    --project=bq-observe-lab-840614
```
- **Purpose:** Launch public-facing HTTP API on Cloud Run.
- **Resource Affected:** Cloud Run Service `order-api` (URL: `https://order-api-769996365752.europe-west1.run.app`).

---

## Command 18 — Create Log-Based Metric
**Command:**
```bash
gcloud logging metrics create lab_error_count \
    --description="Count of ERROR logs from order-api and analytics-worker" \
    --log-filter='resource.type="cloud_run_revision" AND (resource.labels.service_name="order-api" OR resource.labels.service_name="analytics-worker") AND severity>=ERROR' \
    --project=bq-observe-lab-840614
```
- **Purpose:** Bridge Cloud Logging into Cloud Monitoring by counting application error log entries.
- **Verify Using:** `gcloud logging metrics describe lab_error_count`

---

## Command 19 — Create Cloud Monitoring Alert Policy
**Command:**
```bash
gcloud monitoring policies create \
    --policy-from-file="./monitoring/alert-policy.json" \
    --project=bq-observe-lab-840614
```
- **Purpose:** Configure automated incident creation when `lab_error_count > 0`.
- **Verify Using:** `gcloud monitoring policies list`

---

## Command 20 — Create Custom Cloud Monitoring Dashboard
**Command:**
```bash
gcloud monitoring dashboards create \
    --config-from-file="./monitoring/dashboard.json" \
    --project=bq-observe-lab-840614
```
- **Purpose:** Create custom dashboard `BigQuery Observability Lab` with 6 live widgets.
- **Verify Using:** `gcloud monitoring dashboards list`

---

## Command 21 — Dry Run Query (Partition Pruning Analysis)
**Command:**
```bash
# Query A (Full scan)
"SELECT count(*), sum(amount) FROM \`bq-observe-lab-840614.analytics_lab.order_events\` WHERE status = 'completed'" | bq query --use_legacy_sql=false --dry_run

# Query B (3-day partition pruned scan)
"SELECT count(*), sum(amount) FROM \`bq-observe-lab-840614.analytics_lab.order_events\` WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 DAY) AND status = 'completed'" | bq query --use_legacy_sql=false --dry_run
```
- **Result:**
  - Query A estimated bytes: **668,750 bytes**
  - Query B estimated bytes: **115,893 bytes** (82.7% reduction)
- **Interview Lesson:** `bq query --dry_run` estimates bytes scanned at query planning time using partition metadata. It charges $0.

---

## Command 22 — Subscription Seek (Backlog Clearing)
**Command:**
```bash
gcloud pubsub subscriptions seek order-events-sub \
    --time="2026-09-26T12:28:35Z" \
    --project=bq-observe-lab-840614
```
- **Purpose:** Acknowledge and purge unacknowledged failure retry messages after testing the failure scenario.
- **Result:** Backlog cleared to 0.
