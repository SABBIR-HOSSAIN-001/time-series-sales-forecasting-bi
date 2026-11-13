
create table daily_sales ( 
date date primary key,
totale_sales numeric(18, 2) not null,
total_onpromotion integer not null,
day_name varchar(15),
year smallint,
month smallint,
quarter smallint,
dat_of_week smallint,
is_weekend smallint);


select * from daily_sales limit 5;



ALTER TABLE daily_sales
RENAME COLUMN totale_sales TO total_sales;

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'daily_sales'
ORDER BY ordinal_position;

ALTER TABLE daily_sales
RENAME COLUMN dat_of_week TO day_of_week;


SELECT
    COUNT(*) AS total_records,
    MIN(date) AS first_date,
    MAX(date) AS last_date,
    ROUND(SUM(total_sales), 2) AS total_sales
FROM daily_sales;


---data quality check

SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE total_sales IS NULL) AS missing_sales,
    COUNT(*) FILTER (WHERE total_onpromotion IS NULL) AS missing_promotions,
    COUNT(*) FILTER (WHERE date IS NULL) AS missing_dates,
    COUNT(*) FILTER (WHERE total_sales < 0) AS negative_sales,
    COUNT(*) FILTER (WHERE total_onpromotion < 0) AS negative_promotions
FROM daily_sales;


--Monthly Sales Analysis 

SELECT
    year,
    month,
    ROUND(SUM(total_sales), 2) AS monthly_sales,
    SUM(total_onpromotion) AS total_promotions
FROM daily_sales
GROUP BY year, month
ORDER BY year, month;

--Month-over-Month (MoM) Sales Growth

WITH monthly_sales AS (
    SELECT
        year,
        month,
        SUM(total_sales) AS sales
    FROM daily_sales
    GROUP BY year, month
),
sales_growth AS (
    SELECT
        year,
        month,
        sales,
        LAG(sales) OVER (
            ORDER BY year, month
        ) AS previous_month_sales
    FROM monthly_sales
)
SELECT
    year,
    month,
    ROUND(sales, 2) AS current_sales,
    ROUND(previous_month_sales, 2) AS previous_sales,
    ROUND(
        ((sales - previous_month_sales)
        / NULLIF(previous_month_sales, 0)) * 100,
        2
    ) AS mom_growth_percentage
FROM sales_growth
ORDER BY year, month;

--Year-over-Year (YoY) Sales Growth

WITH monthly_sales AS (
    SELECT
        year,
        month,
        SUM(total_sales) AS sales
    FROM daily_sales
    GROUP BY year, month
),
yearly_comparison AS (
    SELECT
        year,
        month,
        sales,
        LAG(sales, 12) OVER (
            ORDER BY year, month
        ) AS previous_year_sales
    FROM monthly_sales
)
SELECT
    year,
    month,
    ROUND(sales, 2) AS current_sales,
    ROUND(previous_year_sales, 2) AS previous_year_sales,
    ROUND(
        ((sales - previous_year_sales)
        / NULLIF(previous_year_sales, 0)) * 100,
        2
    ) AS yoy_growth_percentage
FROM yearly_comparison
ORDER BY year, month;

--Quarterly Sales Performance

WITH quarterly_sales AS (
    SELECT
        year,
        quarter,
        SUM(total_sales) AS sales
    FROM daily_sales
    GROUP BY year, quarter
),
quarter_ranking AS (
    SELECT
        year,
        quarter,
        sales,
        RANK() OVER (
            PARTITION BY year
            ORDER BY sales DESC
        ) AS sales_rank
    FROM quarterly_sales
)
SELECT
    year,
    quarter,
    ROUND(sales, 2) AS quarterly_sales,
    sales_rank
FROM quarter_ranking
ORDER BY year, quarter;

--Business View

CREATE OR REPLACE VIEW vw_monthly_sales_performance AS
WITH monthly_sales AS (
    SELECT
        year,
        month,
        SUM(total_sales) AS monthly_sales,
        SUM(total_onpromotion) AS total_promotions
    FROM daily_sales
    GROUP BY year, month
),
sales_comparison AS (
    SELECT
        year,
        month,
        monthly_sales,
        total_promotions,
        LAG(monthly_sales) OVER (
            ORDER BY year, month
        ) AS previous_month_sales
    FROM monthly_sales
)
SELECT
    year,
    month,
    ROUND(monthly_sales, 2) AS monthly_sales,
    total_promotions,
    ROUND(
        ((monthly_sales - previous_month_sales)
        / NULLIF(previous_month_sales, 0)) * 100,
        2
    ) AS mom_growth_percentage
FROM sales_comparison;

--View ta dekhbo

SELECT *
FROM vw_monthly_sales_performance
ORDER BY year, month;

--Annual Sales Performance View

CREATE OR REPLACE VIEW vw_annual_sales_performance AS
SELECT
    year,
    ROUND(SUM(total_sales), 2) AS annual_sales,
    SUM(total_onpromotion) AS total_promotions,
    COUNT(*) AS total_days,
    ROUND(AVG(total_sales), 2) AS avg_daily_sales
FROM daily_sales
GROUP BY year
ORDER BY year;

--Annual View Verify

SELECT *
FROM vw_annual_sales_performance
ORDER BY year;

--Forecast Results Table Create

CREATE TABLE forecast_validation (
    date DATE PRIMARY KEY,
    actual_sales NUMERIC(18, 2) NOT NULL,
    lightgbm_prediction NUMERIC(18, 2),
    xgboost_prediction NUMERIC(18, 2),
    seasonal_naive_prediction NUMERIC(18, 2),
    naive_prediction NUMERIC(18, 2)
);

--Forecast Data Verify

SELECT
    COUNT(*) AS total_records,
    MIN(date) AS first_date,
    MAX(date) AS last_date,
    ROUND(AVG(actual_sales), 2) AS avg_actual_sales,
    ROUND(AVG(lightgbm_prediction), 2) AS avg_lightgbm_prediction
FROM forecast_validation;


--Model Performance Table Create

CREATE TABLE model_performance (
    model_name VARCHAR(50) PRIMARY KEY,
    mae NUMERIC(18, 2),
    rmse NUMERIC(18, 2),
    mape NUMERIC(10, 2)
);

--Model Performance Data Insert

INSERT INTO model_performance
    (model_name, mae, rmse, mape)
VALUES
    ('LightGBM', 68126.91, 91268.85, 7.89),
    ('Seasonal Naive', 93467.95, 130808.95, 10.06),
    ('XGBoost', 98647.41, 118135.31, 12.14),
    ('Naive', 129317.64, 164712.49, 14.72);

--Model Performance Verify

SELECT *
FROM model_performance
ORDER BY mae ASC;

--Business Summary View

CREATE OR REPLACE VIEW vw_sales_business_summary AS
SELECT
    d.year,
    ROUND(SUM(d.total_sales), 2) AS annual_sales,
    SUM(d.total_onpromotion) AS total_promotions,
    COUNT(*) AS total_days,
    ROUND(AVG(d.total_sales), 2) AS avg_daily_sales,
    ROUND(AVG(f.actual_sales), 2) AS avg_validation_actual,
    ROUND(AVG(f.lightgbm_prediction), 2) AS avg_lightgbm_prediction
FROM daily_sales d
LEFT JOIN forecast_validation f
    ON d.date = f.date
GROUP BY d.year
ORDER BY d.year;

--Business Summary View Verify

SELECT *
FROM vw_sales_business_summary
ORDER BY year;

--Final Database Check

SELECT 'daily_sales' AS object_name, COUNT(*) AS total_records
FROM daily_sales

UNION ALL

SELECT 'forecast_validation', COUNT(*)
FROM forecast_validation

UNION ALL

SELECT 'model_performance', COUNT(*)
FROM model_performance;





