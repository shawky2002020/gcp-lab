-- 11. Inspect Partition Metadata via INFORMATION_SCHEMA.PARTITIONS
-- Purpose: Inspect row counts, active/long-term storage, and partition IDs directly.
SELECT
  table_name,
  partition_id,
  total_rows,
  ROUND(total_logical_bytes / 1024, 2) AS logical_kb,
  last_modified_time
FROM
  `bq-observe-lab-840614.analytics_lab.INFORMATION_SCHEMA.PARTITIONS`
WHERE
  table_name = 'order_events'
ORDER BY
  partition_id DESC
LIMIT 15;
