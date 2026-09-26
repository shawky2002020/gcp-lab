-- 4. Filtering Query: Filter by specific user
-- Purpose: Filter by a clustered column without date bounds.
SELECT
  event_id,
  order_id,
  user_id,
  amount,
  status,
  created_at,
  trace_id
FROM
  `bq-observe-lab-840614.analytics_lab.order_events`
WHERE
  user_id = 'user-10'
ORDER BY
  created_at DESC;
