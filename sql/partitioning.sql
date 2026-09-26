-- 5. Partition-Aware Filtering Query
-- Purpose: Filter strictly by the partition column (created_at).
-- BigQuery executes "Partition Pruning": it consults partition metadata and ONLY
-- reads storage blocks corresponding to the specified date partitions (e.g. last 3 days).
-- All other partitions are completely skipped without scanning their bytes.
SELECT
  order_id,
  user_id,
  amount,
  status,
  created_at
FROM
  `bq-observe-lab-840614.analytics_lab.order_events`
WHERE
  created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 3 DAY)
ORDER BY
  created_at DESC;
