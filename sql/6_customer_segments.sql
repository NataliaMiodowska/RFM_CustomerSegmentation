DROP TABLE IF EXISTS SEGMENTS;

CREATE TABLE SEGMENTS AS
SELECT
    CUSTOMER_ID,
    RECENCY_SCORE,
    FREQUENCY_SCORE,
    MONETARY_SCORE,
    (FREQUENCY_SCORE + MONETARY_SCORE) AS FREQUENCY_MONETARY_SCORE,
    CASE
        -- Top Customers: recency 4–5 and frequency_monetary 9–10
        WHEN RECENCY_SCORE IN (4, 5) 
         AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 9 AND 10 
            THEN 'Top Customers'

        -- Loyal: (recency 4 and frequency_monetary 5–8) or (recency 5 and frequency_monetary 8) or (recency 3 and frequency_monetary 8–10)
        WHEN (RECENCY_SCORE = 4 AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 5 AND 8)
          OR (RECENCY_SCORE = 5 AND (FREQUENCY_SCORE + MONETARY_SCORE) = 8)
          OR (RECENCY_SCORE = 3 AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 8 AND 10) 
            THEN 'Loyal'

        -- Recent Occasional / Promising: (recency 5 and frequency_monetary 5–7) or (recency 4 and frequency_monetary 2–4)
        WHEN (RECENCY_SCORE = 5 AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 5 AND 7)
          OR (RECENCY_SCORE = 4 AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 2 AND 4) 
            THEN 'Promising'

        -- Recent Occasional: recency 5 and frequency_monetary 2–4
        WHEN RECENCY_SCORE = 5 
         AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 2 AND 4 
            THEN 'Recent Occasional'

        -- Need Attention: (recency 3 and frequency_monetary 2–7) or (recency 2 and frequency_monetary 5–7)
        WHEN (RECENCY_SCORE = 3 AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 2 AND 7)
          OR (RECENCY_SCORE = 2 AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 5 AND 7) 
            THEN 'Need Attention'

        -- Immediate Attention: recency 1–2 and frequency_monetary 8–10
        WHEN RECENCY_SCORE IN (1, 2) 
         AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 8 AND 10 
            THEN 'Immediate Attention'

        -- Lost: (recency 1–2 and frequency_monetary 2–4) or (recency 1 and frequency_monetary 5–7)
        WHEN (RECENCY_SCORE IN (1, 2) AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 2 AND 4)
          OR (RECENCY_SCORE = 1 AND (FREQUENCY_SCORE + MONETARY_SCORE) BETWEEN 5 AND 7) 
            THEN 'Lost'

        ELSE 'Unassigned'
    END AS SEGMENT
FROM SCORING;


/* segments averages */
SELECT
	SEGMENT,
	round(AVG(RECENCY),2) AS AVG_RECENCY,
	round(AVG(FREQUENCY),2) AS AVG_FREQUENCY,
	round(AVG(MONETARY),2) AS AVG_MONETARY
FROM
	SEGMENTS S
	JOIN RFM_METRICS USING (CUSTOMER_ID)
GROUP BY
	SEGMENT;


/* Business summary per segment */
WITH
	RETAIL_CLEAN_SEGMENT AS (
		SELECT
			RC.*,
			SEGMENT
		FROM
			RETAIL_CLEAN RC
			JOIN SEGMENTS USING (CUSTOMER_ID)
	)
SELECT
	SEGMENT,
	COUNT(DISTINCT CUSTOMER_ID) AS NUMBER_OF_CUSTOMERS,
	ROUND(
		(
			COUNT(DISTINCT CUSTOMER_ID)::NUMERIC / (
				SELECT
					COUNT(DISTINCT CUSTOMER_ID)
				FROM
					RETAIL_CLEAN_SEGMENT
			)
		) * 100,
		2
	) AS PCT_OF_CUSTOMERS,
	SUM(QUANTITY * UNIT_PRICE) AS REVENUE,
	ROUND(
		(
			SUM(QUANTITY * UNIT_PRICE) / (
				SELECT
					SUM(QUANTITY * UNIT_PRICE)
				FROM
					RETAIL_CLEAN_SEGMENT
			)
		) * 100,
		2
	) AS PCT_OF_REVENUE,
	ROUND(
		SUM(QUANTITY * UNIT_PRICE) / 
				COUNT(DISTINCT INVOICE_NO) FILTER (
					WHERE
						INVOICE_NO NOT ILIKE 'C%'
				)
		,
		2
	) AS AVG_ORDER_VALUE
FROM
	RETAIL_CLEAN_SEGMENT
GROUP BY
	SEGMENT
ORDER BY
	PCT_OF_REVENUE DESC