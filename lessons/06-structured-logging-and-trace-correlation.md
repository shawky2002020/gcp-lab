# Lesson 6: Structured Logging & Cross-Service Trace Correlation

---

## 1. Architectural Concept

In legacy systems, applications print unstructured text lines to log files:
```text
[2026-09-26 12:29:07] [INFO] Order ord-12df23c8 created by user shawky-demo with amount 250
```
This forces engineers to write complex regular expressions to search logs, and makes it impossible to jump directly from a log entry to its corresponding distributed trace.

### The Cloud-Native Solution: Structured JSON Logging
On Google Cloud Run, any single JSON string printed to standard output (`stdout`) or standard error (`stderr`) is automatically parsed into a structured `LogEntry`:

```json
{
  "severity": "INFO",
  "message": "Order event created and published to Pub/Sub",
  "service": "order-api",
  "timestamp": "2026-09-26T12:29:07.658Z",
  "orderId": "ord-12df23c8",
  "userId": "shawky-demo",
  "amount": 250,
  "logging.googleapis.com/trace": "projects/bq-observe-lab-840614/traces/9a0e4a10e10e1df50a3914e296b4fcfb",
  "logging.googleapis.com/spanId": "13dbb36f81a065c2",
  "logging.googleapis.com/trace_sampled": true
}
```

---

## 2. Google Cloud Special Log Attributes

When Google Cloud Logging reads stdout from Cloud Run containers, it looks for special top-level keys:

| Field | Purpose | Result in Cloud Console |
| :--- | :--- | :--- |
| `severity` | Sets log level | Shows colored badges (`INFO`, `WARNING`, `ERROR`) and enables level filtering. |
| `message` | Primary summary text | Becomes the main readable title of the log entry. |
| `logging.googleapis.com/trace` | Format: `projects/${PROJECT_ID}/traces/${TRACE_ID}` | **Links the log entry directly to Cloud Trace**. |
| `logging.googleapis.com/spanId` | 16-hex character Span ID | Correlates the log line with an individual sub-span in the trace waterfall. |

---

## 3. Codebase Tour

Inspect [`services/order-api/src/tracer.ts`](../services/order-api/src/tracer.ts#L40-L64):

```typescript
export function logStructured(
  severity: 'DEFAULT' | 'DEBUG' | 'INFO' | 'NOTICE' | 'WARNING' | 'ERROR' | 'CRITICAL',
  message: string,
  extra: Record<string, any> = {}
) {
  // 1. Grab the currently active OpenTelemetry span
  const { traceId, spanId, isSampled } = getTraceContext();

  const entry: Record<string, any> = {
    severity,
    message,
    timestamp: new Date().toISOString(),
    service: serviceName,
    ...extra,
  };

  // 2. Correlate with Cloud Trace if active span exists
  if (traceId && projectId) {
    entry['logging.googleapis.com/trace'] = `projects/${projectId}/traces/${traceId}`;
    if (spanId) {
      entry['logging.googleapis.com/spanId'] = spanId;
    }
    entry['logging.googleapis.com/trace_sampled'] = isSampled ?? true;
  }

  // 3. Write a single JSON line to stdout
  process.stdout.write(JSON.stringify(entry) + '\n');
}
```

Notice how clean this is: developers simply call `logStructured('INFO', 'Message', { orderId })`, and the logger automatically binds the active OpenTelemetry trace context!

---

## 4. What to Check in Google Cloud Console

1. Open [Cloud Logs Explorer](https://console.cloud.google.com/logs/query?project=bq-observe-lab-840614).
2. Paste this exact query to see cross-service correlation for our demo order:
   ```sql
   resource.type="cloud_run_revision"
   jsonPayload.orderId="ord-12df23c8"
   ```
3. Click **Run Query**.
4. **Notice**:
   - Both `order-api` and `analytics-worker` logs appear together chronologically.
   - Look at the `trace` column on the right: notice the small **View in Trace** link icon.
   - Click that icon: Cloud Console instantly opens Cloud Trace with that exact trace and highlights this log entry on the trace timeline!

---

## 5. CLI Verification Commands

```powershell
# Read logs for a specific orderId across all services
gcloud logging read 'jsonPayload.orderId="ord-12df23c8"' --format="table(timestamp,resource.labels.service_name,severity,jsonPayload.message,trace)"

# Read all ERROR logs from both services
gcloud logging read 'resource.type="cloud_run_revision" AND severity>=ERROR' --limit=5 --format="table(timestamp,resource.labels.service_name,severity,jsonPayload.message)"
```

---

## 6. Interview Preparation

> **Interview Question:** *"How do you connect logs with distributed traces in microservice architectures?"*  
> **Strong Answer:**  
> *"When generating structured JSON logs, we extract the active trace ID and span ID from the OpenTelemetry context and attach them to the log record under Google's standard attributes `logging.googleapis.com/trace` and `logging.googleapis.com/spanId`. Cloud Logging automatically recognizes these fields, enabling seamless bi-directional navigation between logs and traces in the console."*

> **Interview Question:** *"Why should you never write multi-line logs directly to stdout in Cloud Run?"*  
> **Strong Answer:**  
> *"The Cloud Run logging agent treats each newline character (`\n`) as a separate log entry. If an application outputs an unhandled stack trace over 15 lines of plain text, Cloud Logging will create 15 individual, disconnected log entries. By formatting logs as single-line JSON, entire stack traces are encapsulated inside a single `jsonPayload.stack` field, preserving atomic log structure."*
