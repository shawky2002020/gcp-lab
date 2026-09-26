# GCP Masterclass: Microservices, Event-Driven Architecture & Observability

Welcome to the hands-on lesson modules. Each lesson is self-contained with architectural theory, code references from this repository, console inspection paths in Google Cloud Platform, and technical interview questions.

---

## Curriculum Table of Contents

| Lesson | Title | Core Technologies | Primary Focus |
| :--- | :--- | :--- | :--- |
| [**Lesson 1**](./01-serverless-containers-and-artifact-registry.md) | **Serverless Containers & Artifact Registry** | Cloud Run, Artifact Registry, Docker | Ingestion vs Processing, scale-to-zero, public vs private ingress. |
| [**Lesson 2**](./02-iam-service-accounts-and-oidc-auth.md) | **IAM & Zero-Trust OIDC Authentication** | Cloud IAM, Service Accounts, OIDC JWT | Least privilege, short-lived tokens, service-to-service auth without secrets. |
| [**Lesson 3**](./03-pubsub-asynchronous-decoupling-and-retries.md) | **Pub/Sub Decoupling & Fault Handling** | Cloud Pub/Sub, Push Subscriptions | Asynchronous decoupling, ACK vs NACK, exponential backoff, DLQs, idempotency. |
| [**Lesson 4**](./04-bigquery-partitioning-clustering-and-jobs.md) | **BigQuery Internals: Partitioning & Clustering** | BigQuery, Capacitor, Jobs API | OLTP vs OLAP, partition pruning, clustering block pruning, dry runs, query cache. |
| [**Lesson 5**](./05-distributed-tracing-opentelemetry-and-cloud-trace.md) | **Distributed Tracing with OpenTelemetry** | OpenTelemetry, Cloud Trace, W3C Context | Traces, Spans, waterfall timelines, cross-queue context propagation. |
| [**Lesson 6**](./06-structured-logging-and-trace-correlation.md) | **Structured Logging & Trace Correlation** | Cloud Logging, JSON Logs | Structured logs, native GCP fields, bi-directional trace-log navigation. |
| [**Lesson 7**](./07-cloud-monitoring-log-based-metrics-and-alerts.md) | **Cloud Monitoring, Log Metrics & Alerting** | Cloud Monitoring, Log-Based Metrics | Three pillars of observability, p95/p99 latency, custom dashboards, alert policies. |

---

## Active Environment Details

- **GCP Project ID:** `bq-observe-lab-840614`
- **Region:** `europe-west1`
- **Order API URL:** `https://order-api-769996365752.europe-west1.run.app`
- **Analytics Worker URL:** `https://analytics-worker-769996365752.europe-west1.run.app` (Private)
- **Pub/Sub Topic:** `projects/bq-observe-lab-840614/topics/order-events`
- **BigQuery Table:** `bq-observe-lab-840614.analytics_lab.order_events`
- **Dashboard:** `BigQuery Observability Lab` (`projects/769996365752/dashboards/1d2333c3-7a51-48cc-b628-167a9bfe691d`)
