-- 1. Basic Query: Count all events and inspect total rows
-- Purpose: Baseline full table scan count.
SELECT
  COUNT(*) AS total_events,
  COUNT(DISTINCT order_id) AS distinct_orders,
  MIN(created_at) AS earliest_event,
  MAX(created_at) AS latest_event
FROM
  `bq-observe-lab-840614.analytics_lab.order_events`;
