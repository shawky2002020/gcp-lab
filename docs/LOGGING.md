# Cloud Logging & Trace Correlation Guide

## 1. Google Cloud Structured Logging Specification

In Google Cloud Run, applications write single JSON strings followed by a newline (`\n`) directly to `stdout` or `stderr`. The Cloud Run infrastructure and Google Cloud Logging agent automatically parse the JSON and populate the first-class `LogEntry` attributes.

### Structured JSON Format Used in the Lab:
```json
{
  "severity": "INFO",
  "message": "Order event created and published to Pub/Sub",
  "service": "order-api",
  "timestamp": "2026-09-26T12:29:07.658Z",
  "eventId": "evt-eccbee1b-dfd8-4438-aaeb-1217f70351a8",
  "orderId": "ord-12df23c8",
  "userId": "shawky-demo",
  "amount": 250,
  "logging.googleapis.com/trace": "projects/bq-observe-lab-840614/traces/9a0e4a10e10e1df50a3914e296b4fcfb",
  "logging.googleapis.com/spanId": "13dbb36f81a065c2",
  "logging.googleapis.com/trace_sampled": true
}
```

### Special Fields Recognized by Cloud Logging:
| Field Name | Description |
| :--- | :--- |
| `severity` | Sets the native log level (`DEFAULT`, `DEBUG`, `INFO`, `NOTICE`, `WARNING`, `ERROR`, `CRITICAL`). |
| `message` | Becomes the primary log entry display text in Logs Explorer. |
| `logging.googleapis.com/trace` | Format: `projects/{PROJECT_ID}/traces/{TRACE_ID}`. Directly links the log entry to Google Cloud Trace. |
| `logging.googleapis.com/spanId` | 16-character hexadecimal span ID linking the log entry to a specific sub-operation span in the trace. |
| `logging.googleapis.com/trace_sampled` | Boolean indicating whether this trace was sampled for export. |

---

## 2. Logs Explorer Query Cheatsheet

Open **Google Cloud Console -> Logging -> Logs Explorer** and use the following queries:

### Query 1: All Order API Logs
```sql
resource.type="cloud_run_revision"
resource.labels.service_name="order-api"
logName="projects/bq-observe-lab-840614/logs/run.googleapis.com%2Fstdout"
```

### Query 2: All Analytics Worker Logs
```sql
resource.type="cloud_run_revision"
resource.labels.service_name="analytics-worker"
logName="projects/bq-observe-lab-840614/logs/run.googleapis.com%2Fstdout"
```

### Query 3: All Application Errors (Severity >= ERROR)
```sql
resource.type="cloud_run_revision"
severity >= ERROR
```

### Query 4: Filter by Specific Order ID (e.g. `ord-12df23c8`)
```sql
resource.type="cloud_run_revision"
jsonPayload.orderId="ord-12df23c8"
```
*Notice: This returns both the `order-api` publishing log AND the `analytics-worker` insertion log.*

### Query 5: Filter by Specific Event ID (e.g. `evt-eccbee1b-dfd8-4438-aaeb-1217f70351a8`)
```sql
resource.type="cloud_run_revision"
jsonPayload.eventId="evt-eccbee1b-dfd8-4438-aaeb-1217f70351a8"
```

### Query 6: Correlated Trace Query
```sql
trace="projects/bq-observe-lab-840614/traces/9a0e4a10e10e1df50a3914e296b4fcfb"
```
*Notice: In the Cloud Console Logs Explorer, clicking the small trace icon next to any log line automatically opens Cloud Trace with that exact trace and highlights all correlated logs along the trace timeline.*

---

## 3. Real Observability Output Observed in Lab

When querying `jsonPayload.orderId="ord-12df23c8"`:

```
TIMESTAMP                    SERVICE_NAME      SEVERITY  MESSAGE                                          TRACE                                                                   SPAN_ID
2026-09-26T12:29:07.759585Z  analytics-worker  INFO      Order event successfully inserted into BigQuery  projects/bq-observe-lab-840614/traces/9a0e4a10e10e1df50a3914e296b4fcfb  5cca42edffe7e366
2026-09-26T12:29:07.685275Z  analytics-worker  INFO      Received and decoded Pub/Sub message             projects/bq-observe-lab-840614/traces/9a0e4a10e10e1df50a3914e296b4fcfb  5cca42edffe7e366
2026-09-26T12:29:07.658383Z  order-api         INFO      Order event created and published to Pub/Sub     projects/bq-observe-lab-840614/traces/9a0e4a10e10e1df50a3914e296b4fcfb  13dbb36f81a065c2
```
