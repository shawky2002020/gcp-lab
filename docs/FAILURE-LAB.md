# Failure & Retry Laboratory — Pub/Sub & Cloud Run Error Handling

## 1. The Controlled Failure Scenario

To observe how distributed asynchronous systems handle errors, retries, and alerting, we introduced an intentional failure scenario:

1. **Trigger**: An order is submitted with `userId = "fail-test"`:
   ```json
   {
     "userId": "fail-test",
     "amount": 50.00
   }
   ```
2. **Order API Behavior**:
   - `order-api` treats the request as a syntactically valid order, publishes the event to Pub/Sub, and returns `HTTP 202 Accepted` (`orderId: ord-a190ff28`, `eventId: evt-1f654043-bb81-4acd-8b9a-158f33c9d7f4`).
3. **Pub/Sub Push Delivery**:
   - Pub/Sub push subscription `order-events-sub` delivers the event via authenticated HTTP POST to `analytics-worker`.
4. **Worker Failure Logic**:
   - `analytics-worker` detects `event.userId === 'fail-test'`.
   - Logs an `ERROR`: *"Simulating worker processing failure for controlled retry lab"*.
   - Marks the OpenTelemetry span as `ERROR` (status code 2).
   - Returns `HTTP 500 Internal Server Error`.

---

## 2. What Happened in Google Cloud Services?

### A. Cloud Logging
When we queried `gcloud logging read ... severity>=ERROR`:

```
TIMESTAMP                    SEVERITY  MESSAGE                                                        EVENT_ID                                  REASON
2026-09-26T12:28:22.319307Z  ERROR     Simulating worker processing failure for controlled retry lab  evt-1f654043-bb81-4acd-8b9a-158f33c9d7f4  Intentional failure trigger detected in payload
2026-09-26T12:28:23.522736Z  ERROR     Simulating worker processing failure for controlled retry lab  evt-1f654043-bb81-4acd-8b9a-158f33c9d7f4  Intentional failure trigger detected in payload
2026-09-26T12:28:24.122635Z  ERROR     Simulating worker processing failure for controlled retry lab  evt-1f654043-bb81-4acd-8b9a-158f33c9d7f4  Intentional failure trigger detected in payload
```

#### Key Observation:
Pub/Sub attempted delivery **3 consecutive times** within 2 seconds because `analytics-worker` returned `HTTP 500`.
In Pub/Sub push subscriptions:
- `HTTP 200` or `HTTP 204` = **ACK** (Message successfully acknowledged and removed from subscription queue).
- Any other HTTP response (e.g. `500`, `503`, timeout) = **NACK** (Negative Acknowledgement; Pub/Sub retains message and initiates exponential backoff retries).

---

### B. Cloud Monitoring & Log-Based Metric
1. The log-based metric `lab_error_count` (filter: `severity>=ERROR` on Cloud Run services) matched the 3 ERROR log entries and incremented its delta counter.
2. In Cloud Monitoring, the metric fed directly into the alert condition:
   - Condition: `resource.type = "cloud_run_revision" AND metric.type = "logging.googleapis.com/user/lab_error_count" > 0`.
   - The alert policy `Lab High Application Error Rate` moved to an incident active state.

---

### C. BigQuery Integrity
Did the failed event get inserted into BigQuery?
```bash
bq query --use_legacy_sql=false "SELECT * FROM \`bq-observe-lab-840614.analytics_lab.order_events\` WHERE user_id = 'fail-test'"
```
**Result: 0 rows.**
Because the worker returned `500` before the `bigquery.table.insert` call, the database remained clean.

---

## 3. Restoring Normalcy — Purging the Subscription

To prevent the message from retrying indefinitely without modifying worker code, we used the `gcloud pubsub subscriptions seek` command:

```bash
gcloud pubsub subscriptions seek order-events-sub \
  --time="2026-09-26T12:28:35Z" \
  --project=bq-observe-lab-840614
```

### What `seek` Does:
1. Fast-forwards the subscription’s acknowledgment pointer to the specified timestamp.
2. Automatically acknowledges and discards any unacknowledged messages published prior to that timestamp.
3. Clears the subscription backlog to 0 undelivered messages.

---

## 4. Production Engineering Lessons

1. **Why Consumers MUST Be Idempotent**:
   - Pub/Sub guarantees **at-least-once delivery**.
   - If a worker writes to BigQuery but crashes *before* sending `HTTP 200` back to Pub/Sub, Pub/Sub will re-deliver the exact same message.
   - Without deduplication (e.g. checking existing `event_id` or using BigQuery insert IDs), duplicate rows will be written.
2. **Dead-Letter Queues (DLQ)**:
   - In production systems, push subscriptions should be configured with a Dead-Letter Topic (e.g. `--dead-letter-topic=order-events-dlq --max-delivery-attempts=5`).
   - If a message fails 5 times, Pub/Sub automatically routes it to the DLQ instead of looping indefinitely, and alerts the engineering team.
