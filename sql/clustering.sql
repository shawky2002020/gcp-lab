-- 6. Clustering-Related Filtering Query
-- Purpose: Filter on clustering columns (user_id and status).
-- Table order_events is clustered on `user_id, status`.
-- Within each partition, BigQuery automatically sorts and co-locates data with the same
-- user_id and status into contiguous storage blocks. BigQuery utilizes block metadata
-- (min/max values per block) to skip blocks that do not contain matching records.
SELECT
  order_id,
  user_id,
  status,
  amount,
  created_at
FROM
  `bq-observe-lab-840614.analytics_lab.order_events`
WHERE
  user_id = 'user-25'
  AND status = 'completed';
