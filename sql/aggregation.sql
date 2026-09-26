-- 2. Aggregation Query: Revenue and order count grouped by user
-- Purpose: Analytical rollup demonstrating column scan and aggregation.
SELECT
  user_id,
  COUNT(*) AS total_orders,
  ROUND(SUM(amount), 2) AS total_spent,
  ROUND(AVG(amount), 2) AS avg_order_value,
  COUNTIF(status = 'created') AS created_count,
  COUNTIF(status = 'completed') AS completed_count
FROM
  `bq-observe-lab-840614.analytics_lab.order_events`
GROUP BY
  user_id
ORDER BY
  total_spent DESC
LIMIT 15;
