# GCP Masterclass: Microservices, Event-Driven Architecture & Observability

Welcome to the hands-on lesson modules. Each lesson is self-contained with architectural theory, code references from this repository, console inspection paths in Google Cloud Platform, and technical interview questions.

---

## End-to-End GCP System Architecture

```mermaid
flowchart TD
    subgraph ClientLayer["1. Client Ingress"]
        Client["Client / Load Generator<br/>(HTTP POST /orders)"]
    end

    subgraph IngestionLayer["2. Public Ingestion Layer (Cloud Run)"]
        OrderAPI["order-api<br/>(Public Ingress / Port 8080)<br/>Identity: order-api-sa"]
    end

    subgraph MessagingLayer["3. Asynchronous Decoupling (Cloud Pub/Sub)"]
        Topic["Topic: order-events"]
        Sub["Push Subscription: order-events-sub<br/>(OIDC Token Authentication)"]
        InvokerIdentity["Identity Token Signer<br/>pubsub-run-invoker-sa"]
    end

    subgraph ProcessingLayer["4. Private Consumer Layer (Cloud Run)"]
        Worker["analytics-worker<br/>(Private Ingress / No Unauth Access)<br/>Identity: analytics-worker-sa"]
    end

    subgraph StorageLayer["5. Analytical Storage (Google BigQuery)"]
        Dataset["Dataset: analytics_lab (europe-west1)"]
        Table[("Table: order_events<br/>Partition: created_at DAY<br/>Cluster: user_id, status")]
        Dataset --- Table
    end

    subgraph ObservabilityLayer["6. GCP Observability Plane"]
        CloudTrace["Google Cloud Trace<br/>(OpenTelemetry Distributed Spans)"]
        CloudLogging["Google Cloud Logging<br/>(Trace-Correlated JSON Logs)"]
        LogMetric["Log-Based Metric<br/>lab_error_count (severity >= ERROR)"]
        CloudMonitoring["Cloud Monitoring Dashboard<br/>BigQuery Observability Lab"]
        AlertPolicy["Alert Policy<br/>Lab High Application Error Rate"]
    end

    %% Data Pipeline Connections
    Client -->|"1. POST /orders {userId, amount}"| OrderAPI
    OrderAPI -->|"2. Publish event + W3C traceparent"| Topic
    OrderAPI -->>|"3. Immediate 202 Accepted"| Client
    Topic -->|"4. Buffer event"| Sub
    InvokerIdentity -.->|"Mints signed OIDC JWT"| Sub
    Sub -->|"5. Authenticated HTTP POST (roles/run.invoker)"| Worker
    Worker -->|"6. BigQuery Streaming Insert"| Table

    %% Observability Connections
    OrderAPI -.->|"Export API Spans"| CloudTrace
    Worker -.->|"Export Worker Spans"| CloudTrace
    OrderAPI -.->|"JSON stdout (with traceId)"| CloudLogging
    Worker -.->|"JSON stdout (with traceId)"| CloudLogging
    CloudLogging -->|"Filter error logs"| LogMetric
    LogMetric -->|"Feed error count"| CloudMonitoring
    LogMetric -->|"Trigger incident on errors"| AlertPolicy
```

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
