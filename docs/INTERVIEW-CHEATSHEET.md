# GCP Technical Interview Cheat Sheet (20–40 Second Answers)

Use these concise, high-signal explanations in technical screens and system design interviews.

---

### 1. What is BigQuery?
"BigQuery is Google Cloud’s fully managed, serverless enterprise data warehouse designed for OLAP workloads. It separates compute from storage using Google's Colossus distributed file system and Capacitor columnar format, allowing users to query petabytes of data using standard SQL in seconds without managing servers."

### 2. BigQuery vs PostgreSQL?
"PostgreSQL is an OLTP row-oriented database optimized for high-concurrency, low-latency single-row transactions and point lookups using B-Tree indexes. BigQuery is an OLAP columnar data warehouse designed for scanning and aggregating billions of rows across distributed compute slots. You should never use BigQuery as a transactional CRUD database, nor use PostgreSQL for petabyte-scale analytics."

### 3. Partitioning vs Clustering?
"Partitioning physically divides a table into discrete daily, monthly, or integer chunks, allowing the query planner to skip entire date segments (partition pruning). Clustering organizes and sorts data within those partitions into contiguous storage blocks based on column values. Partitioning provides predictable cost savings at query planning time, while clustering provides runtime block pruning."

### 4. What is Partition Pruning?
"Partition pruning is a query optimization technique where BigQuery inspects partition metadata during query planning and only scans the storage blocks belonging to partitions referenced in the SQL `WHERE` clause. In our lab, filtering by the last 3 days reduced scanned bytes from 668 KB to 115 KB—an 82% cost reduction."

### 5. What are BigQuery Slots?
"A slot is BigQuery’s virtual unit of computational capacity, encompassing CPU cores, RAM, and network bandwidth. When a query executes, Google’s engine dynamically allocates hundreds or thousands of slots in parallel to run query stages. Total slot milliseconds measures the cumulative CPU time consumed by all worker slots."

### 6. What is a BigQuery Job?
"In BigQuery, any action that queries data, loads files, exports tables, or copies datasets is executed as an asynchronous, persistent Job with a unique `job_id`. Jobs store execution metadata including start/end timestamps, total bytes billed, total slot milliseconds, and cache hit status, queryable via `INFORMATION_SCHEMA.JOBS`."

### 7. How do you estimate query cost?
"In BigQuery on-demand pricing, you pay $6.25 per TiB of data scanned. You estimate cost before running the query by performing a dry run using `bq query --dry_run` or the Google Cloud Console Query Validator, which returns the exact number of bytes the query will process without incurring any compute charge."

### 8. What is Pub/Sub?
"Google Cloud Pub/Sub is an asynchronous, horizontally scalable, globally distributed messaging service that decouples message producers from consumers. It offers high throughput, automatic buffering, and at-least-once delivery semantics across multi-region availability zones."

### 9. Topic vs Subscription?
"A topic is an ingestion channel where producers publish messages. A subscription is an independent message stream attached to a topic where consumers read messages. Multiple subscriptions can attach to a single topic for fan-out architectures, and each subscription tracks its own unacknowledged message backlog independently."

### 10. Push vs Pull Subscription?
"In a Pull subscription, consumers actively make API calls to fetch messages and explicitly acknowledge them (ideal for batch workers or Kubernetes pods). In a Push subscription, Pub/Sub automatically initiates an HTTPS POST request delivering the message payload to a designated webhook or serverless endpoint like Cloud Run."

### 11. What happens when a consumer fails?
"If a consumer returns an HTTP error code (e.g. 500) or fails to acknowledge the message within the subscription’s acknowledgment deadline (e.g. 30 seconds), Pub/Sub marks the delivery as a NACK and automatically redelivers the message according to the subscription’s retry backoff policy."

### 12. Does Pub/Sub guarantee exactly-once?
"Standard Pub/Sub guarantees at-least-once delivery. In rare cases of network timeouts or worker crashes immediately following database writes, messages can be redelivered. While Pub/Sub offers an Exactly-Once Delivery flag for pull subscriptions within regional boundaries, distributed subscribers must always be designed to be idempotent."

### 13. Why must consumers be idempotent?
"Because network retries, crash loops, and distributed redeliveries can cause a consumer to receive the same event multiple times. If the consumer is not idempotent, processing the same message twice will create duplicate financial charges, duplicate orders, or corrupted analytics state."

### 14. How does Pub/Sub authenticate to private Cloud Run?
"Pub/Sub uses OpenID Connect (OIDC). The push subscription is configured with a dedicated service account having `roles/run.invoker`. Pub/Sub’s internal service agent mints a cryptographically signed Google identity token and attaches it as an `Authorization: Bearer <JWT>` header. The Cloud Run front-end proxy validates the signature, audience, and IAM role before traffic reaches the container."

### 15. What is a Service Account?
"A service account is a special Google Cloud identity used by applications and automated workloads rather than human users. It is identified by an email address (`...@<project>.iam.gserviceaccount.com`) and authenticates to other Google Cloud services using short-lived tokens generated via Application Default Credentials (ADC)."

### 16. Service Account vs IAM Role?
"A service account is the *identity* (the 'Who'). An IAM role is a *collection of permissions* (the 'What'). You grant a service account permission to do something by creating an IAM policy binding that attaches the role to the service account on a target resource."

### 17. Principal vs Role vs Resource?
"In Google Cloud IAM: Principal is the identity requesting access (`serviceAccount:worker@...`). Role is the permission package (`roles/bigquery.dataEditor`). Resource is the object being acted upon (`projects/my-project/datasets/analytics_lab`). IAM evaluates: *Can this Principal execute this Role on this Resource?*"

### 18. What is Cloud Logging?
"Cloud Logging is a fully managed, real-time log ingestion and storage system capable of indexing terabytes of logs per day. It natively parses structured JSON output from stdout, extracts severity levels, correlates logs with Cloud Trace IDs, and supports rich search filters via Logs Explorer."

### 19. Logs vs Metrics vs Traces?
"Logs are discrete, timestamped text or JSON events detailing *what happened* in an application. Metrics are aggregated, numeric time-series data measuring system health over time (e.g. CPU %, request rate, p95 latency). Traces follow a single request’s journey across distributed microservices, showing latency breakdowns across individual operations."

### 20. What is Cloud Monitoring?
"Cloud Monitoring is GCP’s observability platform that collects metrics, events, and metadata from GCP resources, application code, and log-based metrics. It provides real-time dashboards, threshold-based alerting policies, uptime checks, and incident response notifications."

### 21. What is Cloud Trace?
"Cloud Trace is Google Cloud’s distributed tracing system. It collects latency data from microservices, visualizes call hierarchies as waterfall span graphs, and helps engineers pinpoint which specific network call, database query, or internal function caused request latency bottlenecks."

### 22. What is OpenTelemetry?
"OpenTelemetry (OTel) is a vendor-neutral CNCF open-source observability framework providing standardized APIs, SDKs, and tooling to generate, collect, and export telemetry data (traces, metrics, and logs) to backends like Google Cloud Trace and Prometheus."

### 23. What is Distributed Tracing?
"Distributed tracing is a diagnostic method used in microservices architectures to track and visualize the end-to-end lifecycle of a single user request as it traverses across multiple network hops, queues, and serverless containers."

### 24. What is a Trace ID?
"A Trace ID is a globally unique 16-byte (32-character hexadecimal) string that identifies an entire end-to-end request journey across all participating microservices, message brokers, and background workers."

### 25. What is a Span?
"A span represents a single contiguous unit of work within a trace. It contains a name, start time, end time, span ID, optional parent span ID, and key-value attributes (e.g. `order.id`, `pubsub.message_id`). Multiple spans form a directed acyclic graph representing the complete trace."

### 26. What is P95/P99 latency?
"P95 latency means 95% of all requests were served faster than that threshold, while the slowest 5% took longer. Averages conceal long-tail outliers; monitoring P95 and P99 reveals the true degraded experience of impacted users during traffic spikes or cold starts."

### 27. How would you investigate a slow Cloud Run API?
"First, inspect Cloud Monitoring latency percentiles (p50, p95, p99) to determine if slowness is systemic or isolated. Second, open Cloud Trace to inspect the slowest waterfall spans and identify whether time was spent in cold starts, external HTTP calls, or Pub/Sub publishing. Third, click the correlated logs to inspect log output emitted during that exact request."

### 28. How would you investigate increasing 5xx responses?
"First, open Cloud Monitoring to check 5xx error rate spikes. Second, open Logs Explorer with filter `resource.type='cloud_run_revision' AND severity>=ERROR` to inspect stack traces. Third, trace the `trace_id` of a failed request to determine if the failure originated in application validation, dependency timeouts, or database connection exhaustion."

### 29. How would you check if Pub/Sub messages are backing up?
"Check Cloud Monitoring metric `pubsub.googleapis.com/subscription/num_undelivered_messages` (backlog count) and `oldest_unacked_message_age`. A growing backlog indicates consumer throughput is slower than publisher traffic, worker containers are failing and returning 500s, or the push endpoint is rejecting authentication."

### 30. How would you investigate an expensive BigQuery query?
"Query `INFORMATION_SCHEMA.JOBS_BY_PROJECT` ordered by `total_bytes_billed` or `total_slot_ms`. Inspect the query plan in Console Execution Details to see if a full table scan occurred due to missing partition filters (`WHERE created_at >= ...`), lack of clustering, or inefficient cartesian joins."

### 31. How do Cloud Run, Pub/Sub, and BigQuery fit together?
"Cloud Run provides scalable, serverless HTTP ingestion for operational client requests. Pub/Sub acts as an asynchronous shock absorber, buffering millions of events and isolating the customer experience from downstream processing speed. A private Cloud Run worker securely consumes events with OIDC authentication, validates payloads, and streams them into BigQuery for cost-effective, petabyte-scale analytical querying."
