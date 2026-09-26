-- 3. Time Analytics Query: Daily orders and revenue
-- Purpose: Aggregate metrics by partition date (DATE(created_at)).
SELECT
  DATE(created_at) AS order_date,
  COUNT(*) AS daily_orders,
  ROUND(SUM(amount), 2) AS daily_revenue,
  ROUND(AVG(amount), 2) AS daily_avg_ticket
FROM
  `bq-observe-lab-840614.analytics_lab.order_events`
GROUP BY
  order_date
ORDER BY
  order_date DESC;
