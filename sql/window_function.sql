-- 8. Window Function Query: Rank users by total order revenue
-- Purpose: Demonstrate analytical SQL window functions (DENSE_RANK() OVER (...)).
WITH UserTotals AS (
  SELECT
    user_id,
    COUNT(*) AS order_count,
    ROUND(SUM(amount), 2) AS total_revenue,
    ROUND(AVG(amount), 2) AS avg_ticket
  FROM
    `bq-observe-lab-840614.analytics_lab.order_events`
  GROUP BY
    user_id
)
SELECT
  user_id,
  order_count,
  total_revenue,
  avg_ticket,
  DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
  PERCENT_RANK() OVER (ORDER BY total_revenue DESC) AS percentile_rank
FROM
  UserTotals
ORDER BY
  revenue_rank ASC
LIMIT 10;
