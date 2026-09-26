-- 9. Duplicate Events Query & Deduplication
-- Purpose: Demonstrate how distributed streaming systems deal with at-least-once delivery.
-- Pub/Sub guarantees at-least-once delivery, which means a consumer may receive
-- the same message more than once (e.g. if an ACK is delayed or worker crashes after write).
-- BigQuery tables do not enforce UNIQUE primary key constraints upon streaming insert.
--
-- Query A: Detect duplicate event_ids
SELECT
  event_id,
  COUNT(*) AS occurrences,
  ARRAY_AGG(order_id LIMIT 2) AS order_ids,
  MIN(processed_at) AS first_processed,
  MAX(processed_at) AS last_processed
FROM
  `bq-observe-lab-840614.analytics_lab.order_events`
GROUP BY
  event_id
HAVING
  COUNT(*) > 1;

-- Query B: Analytical Deduplication Pattern using ROW_NUMBER() window function
-- This produces an exact, deduplicated view of all events, keeping the latest processed row.
WITH RankedEvents AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY event_id 
      ORDER BY processed_at DESC
    ) AS row_num
  FROM
    `bq-observe-lab-840614.analytics_lab.order_events`
)
SELECT
  event_id,
  event_type,
  order_id,
  user_id,
  amount,
  status,
  source,
  created_at,
  processed_at,
  trace_id
FROM
  RankedEvents
WHERE
  row_num = 1
LIMIT 20;
