-- 7. Combined Query: Partition Pruning + Cluster Block Pruning
-- Purpose: The gold standard for high-performance BigQuery querying.
-- Step 1 (Partition Pruning): BigQuery inspects partition metadata and limits scan to
--        only partitions within the bounded date range (e.g., last 7 days).
-- Step 2 (Cluster Pruning): Inside those specific partitions, BigQuery inspects cluster block
--        summaries and only reads storage blocks containing user_id = 'user-5'.
-- Result: Maximum cost reduction and fastest execution time.
SELECT
  order_id,
  user_id,
  status,
  amount,
  created_at
FROM
  `bq-observe-lab-840614.analytics_lab.order_events`
WHERE
  created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND user_id = 'user-5';
