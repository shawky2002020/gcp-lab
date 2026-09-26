-- 10. BigQuery Query Execution Analysis via INFORMATION_SCHEMA.JOBS_BY_PROJECT
-- Purpose: Inspect recent BigQuery query jobs, bytes scanned, slots used, and cache hit status.
-- Note the regional qualifier: `region-europe-west1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
SELECT
  creation_time,
  job_id,
  query,
  state,
  total_bytes_processed,
  total_bytes_billed,
  total_slot_ms,
  cache_hit,
  TIMESTAMP_DIFF(end_time, start_time, MILLISECOND) AS runtime_ms
FROM
  `region-europe-west1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE
  project_id = 'bq-observe-lab-840614'
  AND job_type = 'QUERY'
  AND statement_type = 'SELECT'
ORDER BY
  creation_time DESC
LIMIT 10;
