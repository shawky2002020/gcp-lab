# System Architecture — GCP BigQuery & Observability Lab

## 1. High-Level Architecture Diagram

The lab implements an asynchronous, decoupled event-driven architecture designed for cloud scalability, strict IAM boundary isolation, and end-to-end distributed observability.

```mermaid
flowchart TD
    subgraph Clients["External Traffic"]
        Client["Client / Load Generator<br/>(HTTP POST /orders)"]
    end

    subgraph Ingestion["Ingestion Layer (Public Cloud Run)"]
        OrderAPI["Cloud Run: order-api<br/>(Public, Node.js + Express)<br/>Identity: order-api-sa"]
    end

    subgraph Messaging["Asynchronous Decoupling Layer (Cloud Pub/Sub)"]
        Topic["Pub/Sub Topic<br/>order-events"]
        Sub["Push Subscription<br/>order-events-sub<br/>(OIDC Token Authentication)"]
        InvokerSA["Identity Token Generator<br/>pubsub-run-invoker-sa"]
    end

    subgraph Processing["Processing Layer (Private Cloud Run)"]
        Worker["Cloud Run: analytics-worker<br/>(Private / No Unauth Access)<br/>Identity: analytics-worker-sa"]
    end

    subgraph Storage["Analytical Storage Layer (Google BigQuery)"]
        BQDataset["Dataset: analytics_lab (europe-west1)"]
        BQTable["Table: order_events<br/>Partition: created_at (DAY)<br/>Cluster: user_id, status"]
    end

    subgraph Observability["Unified GCP Observability Plane"]
        Trace["Google Cloud Trace<br/>(OpenTelemetry Distributed Spans)"]
        Logging["Google Cloud Logging<br/>(JSON Structured Logs + Trace Correlation)"]
        Monitoring["Google Cloud Monitoring<br/>(Metrics & Custom Dashboard)"]
        LogMetric["Log-Based Metric<br/>lab_error_count"]
        Alert["Alert Policy<br/>Lab High Application Error Rate"]
    end

    %% Data Flow
    Client -->|"HTTP POST /orders"| OrderAPI
    OrderAPI -->|"Publishes domain event (W3C trace context)"| Topic
    Topic -->|"Buffers message"| Sub
    InvokerSA -.->|"Generates signed OIDC JWT"| Sub
    Sub -->|"Authenticated POST (Bearer JWT)<br/>roles/run.invoker"| Worker
    Worker -->|"Decodes & validates event"| Worker
    Worker -->|"Streaming Insert API"| BQTable
    BQDataset --- BQTable

    %% Telemetry Flow
    OrderAPI -.->|"Exports Root & Publish Spans"| Trace
    OrderAPI -.->|"Stdout JSON (trace-correlated)"| Logging
    Worker -.->|"Exports Worker & BQ Insert Spans"| Trace
    Worker -.->|"Stdout JSON (trace-correlated)"| Logging

    OrderAPI -.->|"Request count, Latency (p95)"| Monitoring
    Worker -.->|"Invocations, Container instances"| Monitoring
    Sub -.->|"Undelivered messages backlog"| Monitoring

    Logging -->|"Extracts error logs (severity &gt;= ERROR)"| LogMetric
    LogMetric -->|"Feeds time-series count"| Monitoring
    LogMetric -->|"Triggers incident when count > 0"| Alert
```

---

## 2. Component Breakdown

### A. Client Ingestion: `order-api`
- **Platform**: Cloud Run (Serverless Container).
- **Access Model**: Public (`--allow-unauthenticated`).
- **Identity**: Dedicated Service Account `order-api-sa@bq-observe-lab-840614.iam.gserviceaccount.com`.
- **Responsibilities**:
  1. Validates input schema (`userId`, `amount`).
  2. Generates unique domain identifiers (`orderId`, `eventId`).
  3. Initializes OpenTelemetry span `order-api.process-order` and child span `order-api.pubsub-publish`.
  4. Injects W3C distributed trace context (`traceparent`) into Pub/Sub message attributes.
  5. Publishes message buffer asynchronously to Pub/Sub topic `order-events`.
  6. Emits single-line structured JSON logs with `logging.googleapis.com/trace` correlation.
  7. Returns synchronous `HTTP 202 Accepted` to client immediately without waiting for database writes.

### B. Message Decoupling: Cloud Pub/Sub
- **Topic**: `order-events` receives events published by `order-api`.
- **Subscription**: `order-events-sub` (Push Subscription).
- **Authentication**: OIDC Identity Token minted via `pubsub-run-invoker-sa`.
- **Decoupling Value**: Isolates client-facing operational availability from downstream analytical processing speed or BigQuery ingestion rate spikes.

### C. Analytical Worker: `analytics-worker`
- **Platform**: Cloud Run (Serverless Container).
- **Access Model**: Strictly Private (`--no-allow-unauthenticated`).
- **Identity**: Dedicated Service Account `analytics-worker-sa@bq-observe-lab-840614.iam.gserviceaccount.com`.
- **Responsibilities**:
  1. Receives push messages authenticated with OIDC Bearer tokens.
  2. Extracts incoming W3C trace context from Pub/Sub attributes, continuing the distributed trace seamlessly.
  3. Decodes Base64 message envelope and validates event payload.
  4. Writes rows to BigQuery table `analytics_lab.order_events` via the BigQuery Node.js client SDK.
  5. Emits structured JSON logs containing trace ID, span ID, order ID, and user ID.
  6. Acknowledges delivery to Pub/Sub by returning `HTTP 200 OK`.

### D. Analytical Storage: BigQuery
- **Dataset**: `analytics_lab` (Location: `europe-west1`).
- **Table**: `order_events`.
- **Partitioning**: Partitioned by `created_at` (`DAY` granularity). Limits byte scans by pruning irrelevant date partitions.
- **Clustering**: Clustered on `user_id, status`. Organizes rows within each partition into co-located blocks to allow block-level pruning for user-specific queries.

---

## 3. End-to-End Distributed Telemetry Flow

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant OrderAPI as Cloud Run: order-api
    participant PubSub as Cloud Pub/Sub
    participant Worker as Cloud Run: analytics-worker
    participant BigQuery as BigQuery: order_events
    participant Trace as Cloud Trace
    participant Logging as Cloud Logging

    Client->>OrderAPI: POST /orders {userId, amount}
    activate OrderAPI
    Note over OrderAPI: Start Span: order-api.process-order<br/>Generate traceId (e.g. 9a0e4a10e1...)
    OrderAPI->>OrderAPI: Start Child Span: order-api.pubsub-publish
    Note over OrderAPI: Inject W3C Traceparent into attributes
    OrderAPI->>PubSub: publishMessage(data, attributes)
    OrderAPI->>Trace: Export Spans (process-order, pubsub-publish)
    OrderAPI->>Logging: Log JSON (severity=INFO, trace=9a0e4a10e1...)
    OrderAPI-->>Client: HTTP 202 Accepted {orderId, eventId, status: accepted}
    deactivate OrderAPI

    activate PubSub
    PubSub->>PubSub: Mint OIDC Token (pubsub-run-invoker-sa)
    PubSub->>Worker: Authenticated HTTP POST / (Bearer OIDC Token)
    deactivate PubSub

    activate Worker
    Note over Worker: Cloud Run verifies roles/run.invoker<br/>Worker extracts W3C Traceparent
    Note over Worker: Start Span: analytics-worker.process-order<br/>Linked to same traceId (9a0e4a10e1...)
    Worker->>Worker: Start Child Span: analytics-worker.bigquery-insert
    Worker->>BigQuery: table.insert([row])
    activate BigQuery
    BigQuery-->>Worker: Insert Confirmed
    deactivate BigQuery
    Worker->>Trace: Export Spans (process-order, bigquery-insert)
    Worker->>Logging: Log JSON (severity=INFO, trace=9a0e4a10e1...)
    Worker-->>PubSub: HTTP 200 OK (Message Acknowledged)
    deactivate Worker
```

---

## 4. Key Design Decisions

1. **Synchronous 202 vs Synchronous 200**:
   - `order-api` acknowledges receipt and durability into Pub/Sub immediately with HTTP 202. The client is not blocked on BigQuery ingestion latency or analytical buffering.
2. **Private Cloud Run Ingress**:
   - The worker is completely shielded from public internet traffic. Only identities possessing `roles/run.invoker` can call the endpoint.
3. **W3C Distributed Trace Context**:
   - Rather than creating isolated trace islands, standard OpenTelemetry propagation (`traceparent` header) travels inside Pub/Sub message metadata, enabling full end-to-end visualization in Cloud Trace.
