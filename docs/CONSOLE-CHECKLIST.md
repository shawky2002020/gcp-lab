# Google Cloud Console Exploration Checklist

Open the [Google Cloud Console](https://console.cloud.google.com/) and ensure your project is selected:
**`bq-observe-lab-840614`**.

Follow this step-by-step checklist to inspect every resource created in this lab.

---

## 1. IAM & Service Accounts
Navigate to **IAM & Admin -> Service Accounts**:
- [ ] Verify 3 dedicated service accounts exist:
  - `order-api-sa@...`
  - `analytics-worker-sa@...`
  - `pubsub-run-invoker-sa@...`
- [ ] Click on `pubsub-run-invoker-sa` -> **Permissions**:
  - Notice the `roles/iam.serviceAccountTokenCreator` permission granted to the Google-managed Pub/Sub service agent (`service-769996365752@gcp-sa-pubsub.iam.gserviceaccount.com`).

Navigate to **IAM & Admin -> IAM**:
- [ ] Locate `order-api-sa`: verify roles `roles/pubsub.publisher` and `roles/cloudtrace.agent`.
- [ ] Locate `analytics-worker-sa`: verify roles `roles/bigquery.dataEditor`, `roles/bigquery.jobUser`, and `roles/cloudtrace.agent`.

---

## 2. Cloud Run Services
Navigate to **Cloud Run**:
- [ ] **`order-api` (Public Service)**:
  - Security status shows: **"Allow unauthenticated invocations"** (accessible to public internet).
  - Open service -> **Revisions** tab: verify image source points to Artifact Registry `gcp-lab-images/order-api:v1`.
  - Check **Security** tab: verify Service Account is `order-api-sa`.
  - Check **Metrics** tab: observe charts for Request Count, Request Latencies, and Container Instance Count.
  - Check **Logs** tab: inspect incoming HTTP POST logs and JSON payloads.
- [ ] **`analytics-worker` (Private Service)**:
  - Security status shows: **"Require authentication"** (shield icon).
  - Open service -> **Permissions** tab:
    - Notice that `allUsers` is **NOT** present.
    - Notice that `pubsub-run-invoker-sa` is granted the **Cloud Run Invoker** (`roles/run.invoker`) role.
  - Check **Security** tab: verify Service Account is `analytics-worker-sa`.

---

## 3. Cloud Pub/Sub
Navigate to **Pub/Sub -> Topics**:
- [ ] Click topic `order-events`:
  - Observe topic metrics (Publish Message Operations).
- [ ] Click **Subscriptions** tab under the topic:
  - Click `order-events-sub`:
    - Delivery type: **Push**.
    - Endpoint URL: `https://analytics-worker-769996365752.europe-west1.run.app`.
    - Authentication: **Enable authentication** is checked.
    - Service Account: `pubsub-run-invoker-sa@...`.
    - Ack Deadline: `30 seconds`.
    - Message backlog chart: observe backlog dropped to 0 after processing and seek.

---

## 4. BigQuery Data Warehouse
Navigate to **BigQuery -> Studio**:
- [ ] Expand project `bq-observe-lab-840614` -> dataset `analytics_lab` -> table `order_events`:
  - **Schema tab**: verify 10 columns (`event_id`, `event_type`, `order_id`, `user_id`, `amount`, `status`, `source`, `created_at`, `processed_at`, `trace_id`).
  - **Details tab**:
    - **Partitioned by**: `DAY` on column `created_at`.
    - **Clustered by**: `user_id, status`.
    - **Number of rows**: `25,026+`.
    - **Data location**: `europe-west1`.
  - **Preview tab**: inspect real rows inserted by `analytics-worker` showing generated UUIDs and valid timestamps.
- [ ] **Query Execution & Details**:
  - Run query from `sql/partitioning.sql`:
    - Click **Execution Details**: inspect Stages (S00: Input, S01: Output), records read, and slot time.
    - Click **Job History**: inspect job ID, bytes processed, and billing calculation.

---

## 5. Cloud Logging
Navigate to **Logging -> Logs Explorer**:
- [ ] Paste this query into the query box:
  ```sql
  resource.type="cloud_run_revision"
  jsonPayload.userId="shawky-demo"
  ```
- [ ] Click **Run query**:
  - Expand the log entry.
  - Notice the `logging.googleapis.com/trace` field.
  - Look for the small **Trace** icon next to the trace ID. Click it to jump straight into Google Cloud Trace!

---

## 6. Cloud Trace
Navigate to **Trace -> Trace Explorer**:
- [ ] Set time range to **Last 1 hour**.
- [ ] Inspect the scatter plot and trace table.
- [ ] Click on any trace for `order-api.process-order`:
  - View the waterfall chart:
    1. `order-api.process-order` (Root span).
    2. `order-api.pubsub-publish` (Child span publishing to Pub/Sub).
    3. `analytics-worker.process-order` (Worker receiving Pub/Sub push).
    4. `analytics-worker.bigquery-insert` (Worker writing to BigQuery).
  - Click on any span to inspect custom attributes (`pubsub.message_id`, `order.id`, `order.user_id`, `bigquery.table`).

---

## 7. Cloud Monitoring & Dashboard
Navigate to **Monitoring -> Dashboards**:
- [ ] Click on **`BigQuery Observability Lab`**:
  - Inspect 6 live charts:
    1. Order API Request Count
    2. Order API Request Latency (p95)
    3. Analytics Worker Invocations
    4. Application Error Count (Log-Based Metric)
    5. Pub/Sub Undelivered Messages Backlog
    6. Cloud Run Active Instance Count

Navigate to **Monitoring -> Alerting**:
- [ ] Locate alert policy **`Lab High Application Error Rate`**:
  - Inspect condition: `Application ERROR log count > 0`.
  - View incident history triggered during the intentional failure test.

---

## 8. Artifact Registry
Navigate to **Artifact Registry -> Repositories**:
- [ ] Click `gcp-lab-images`:
  - Format: Docker.
  - Location: `europe-west1`.
  - Inspect images:
    - `analytics-worker` (tag `v1`).
    - `order-api` (tag `v1`).
