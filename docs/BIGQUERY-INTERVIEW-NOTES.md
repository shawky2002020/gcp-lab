# BigQuery Architecture & Technical Interview Notes

## 1. PostgreSQL vs Google BigQuery — Comprehensive Comparison

In technical system design and cloud architecture interviews, confusing transactional databases (OLTP) with analytical data warehouses (OLAP) is one of the most common red flags.

| Dimension | PostgreSQL (OLTP) | Google BigQuery (OLAP) |
| :--- | :--- | :--- |
| **Primary Workload** | **OLTP**: Online Transaction Processing. Low latency, thousands of concurrent small CRUD queries. | **OLAP**: Online Analytical Processing. Scanning billions of rows to aggregate, filter, and report. |
| **Storage Architecture** | **Row-Oriented**: Entire rows stored contiguously on disk pages. Fast single-row reads and updates. | **Columnar (Capacitor)**: Each column stored separately in compressed physical blocks. Scans only queried columns. |
| **Transaction Model** | Full ACID with fine-grained row-level locking, MVCC, and instantaneous commits. | Append-optimized / Snapshot Isolation. Mutations (UPDATE/DELETE) rewrite columnar files. |
| **Point Lookups** | Microsecond response (`SELECT * FROM orders WHERE id = 123` via B-Tree index). | Milliseconds to seconds. Not designed for single-row key-value lookups; incurs minimum 10MB billing scan. |
| **Aggregations / Scans** | Slow on large tables (requires sequential scans or multi-index bitmap scans). | Hyper-fast on billions of rows using distributed MPP (Massively Parallel Processing) slot engines. |
| **Indexing** | B-Tree, Hash, GIN, GiST indexes explicitly maintained on disk. | **No traditional indexes**. Performance is achieved via **Partitioning** and **Clustering**. |
| **Concurrency Model** | Hundreds to low thousands of concurrent connections; throttled by connection poolers (PgBouncer). | Hundreds of concurrent queries managed by Google’s shared Borg cluster and slot queues. |
| **Cost Model** | Billed per provisioned VM compute instance + disk storage capacity (flat monthly cost). | **Storage**: ~$0.02/GB/mo. **Compute**: On-Demand ($6.25/TiB scanned) or Capacity Slots ($/slot-hour). |

> **Interview Summary Sentence**:
> *"Never treat BigQuery like PostgreSQL. PostgreSQL is built for operational CRUD with instant point lookups and ACID row locking. BigQuery is a serverless, columnar data warehouse built to scan and aggregate terabytes of data across distributed slots."*

---

## 2. Partitioning vs Clustering

### Partitioning
- **What it is**: Divides a table into physical chunks based on a specific column (e.g. `DATE(created_at)`, integer range, or ingestion time).
- **Mechanism**: Each partition is an isolated partition segment with its own metadata.
- **Partition Pruning**: When a query has a `WHERE created_at >= '2026-09-20'` filter, BigQuery checks partition metadata and **completely skips reading all unreferenced partitions**.
- **Impact**: Dramatically cuts both execution latency and monetary cost in on-demand pricing. In our lab:
  - Query without partition filter: **668,750 bytes** scanned.
  - Query with 3-day partition filter: **115,893 bytes** scanned (**82.7% reduction**).

### Clustering
- **What it is**: Organizes and sorts rows **within** each partition (or within the unpartitioned table) based on up to 4 columns (e.g. `user_id, status`).
- **Mechanism**: BigQuery groups rows with identical or similar values into contiguous physical storage blocks (typically 10MB–100MB per block). It maintains block metadata recording the `min` and `max` values for clustered columns in every block.
- **Block Pruning**: When a query filters by `user_id = 'user-5'`, BigQuery evaluates block metadata and skips blocks whose min/max range does not include `'user-5'`.

### Why Clustering Does NOT Replace Partitioning
1. **Cost Predictability**: Partition pruning works at **query planning time**. The `bq query --dry_run` command can calculate the exact bytes and cost *before* the query executes. Clustering pruning happens dynamically at **runtime execution**, so its savings cannot be guaranteed prior to execution.
2. **Data Management**: Partitioning allows setting partition expiration policies (e.g. drop data older than 90 days automatically at zero cost). Clustering does not support partition-level TTLs.
3. **Synergy (The Sweet Spot)**: Partition by time (`created_at`) + Cluster by high-cardinality search attributes (`user_id, status`). This guarantees partition pruning first, followed by fine-grained block pruning within the remaining partitions.

---

## 3. BigQuery Execution Engine: Jobs, Slots, and Bytes

### What is a BigQuery Job?
Every query, table copy, export, or load executed in BigQuery is a persistent asynchronous **Job** with a unique `job_id` (e.g. `bqjob_r42c701b9b5ea1170_...`).
Jobs record:
- Total bytes processed (data read from Capacitor storage).
- Total bytes billed (rounded to 10MB minimum on-demand).
- Total slot milliseconds (cumulative CPU processing time).
- Cache hit boolean.
- Query plan execution timeline (Input -> Repartition -> Output).

You can query all jobs in your region using:
```sql
SELECT * FROM `region-europe-west1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
ORDER BY creation_time DESC;
```

### What are BigQuery Slots?
A **slot** is BigQuery’s unit of computational capacity (CPU cores + RAM + network throughput).
When a query executes, Google’s query coordinator decomposes the SQL into execution stages and assigns work to hundreds or thousands of worker slots in parallel.
- **Total Slot Milliseconds**: The sum of active compute time across all slots used by the query. A query that runs in 1 second using 100 slots consumes 100,000 slot milliseconds.

### The BigQuery Query Cache
BigQuery automatically caches query results in memory for 24 hours at zero cost.
A query hits the cache if:
1. The SQL text is identical.
2. The underlying tables have not changed.
3. The query does not use non-deterministic functions (like `CURRENT_TIMESTAMP()`, `RAND()`, or `UUID()`).

> **Lab Finding**: Identical queries executed immediately after streaming inserts did *not* hit the cache. Why? Because the table's **streaming buffer** was actively mutating. BigQuery prevents serving stale results while records reside in the in-memory write buffer!

---

## 4. BigQuery Ingestion Mechanisms

| Ingestion Method | Latency | Pricing | Best Use Case |
| :--- | :--- | :--- | :--- |
| **Batch Load Jobs** (`bq load` / Cloud Storage) | Minutes to hours | Free compute (standard storage costs) | Bulk ETL, daily or hourly batch logs, database snapshots. |
| **Legacy Streaming API** (`tabledata.insertAll`) | Seconds | ~$0.01 per 200MB inserted | Simple low-volume streaming from legacy apps. |
| **Storage Write API** (`bigquery.storage.v1`) | Sub-second | Free up to 2 TiB/mo, then $0.025/GiB | Modern high-throughput streaming, exactly-once semantics, column projection. |
| **Pub/Sub Direct BigQuery Subscription** | Sub-second | Standard Pub/Sub + BQ streaming rates | Pure pass-through ingestion when no transformation or enrichment is needed. |

### Why This Lab Uses an Explicit Cloud Run Worker
Google Cloud Pub/Sub offers direct BigQuery subscriptions that write messages straight into BigQuery tables without compute code.
However, enterprise systems frequently require:
1. **Domain Validation & Schema Evolution**: Rejecting malformed messages before polluting the data warehouse.
2. **Business Enrichment**: Calling external APIs, caching lookups, or decorating events with metadata.
3. **Controlled Retries and Dead-Letter Queues (DLQ)**: Granular error handling and idempotency checking.
4. **End-to-End Tracing & Structured Logging**: Propagating W3C OpenTelemetry trace contexts across service boundaries.
In this lab, having `analytics-worker` teaches private Cloud Run, OIDC authentication, Pub/Sub retry loops, and distributed tracing.
