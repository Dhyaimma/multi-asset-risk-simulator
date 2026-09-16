CREATE DATABASE IF NOT EXISTS global_markets;
USE global_markets;

-- Raw Market Data Storage Table
CREATE TABLE IF NOT EXISTS asset_prices (
    trade_date DATE NOT NULL,
    ticker VARCHAR(10) NOT NULL,
    close_price DECIMAL(12, 4) NOT NULL,
    PRIMARY KEY (trade_date, ticker)
);

-- 1. Daily Log Returns View
CREATE OR REPLACE VIEW daily_returns AS
SELECT 
    trade_date,
    ticker,
    close_price,
    LAG(close_price, 1) OVER (PARTITION BY ticker ORDER BY trade_date) AS prev_close_price,
    ROUND(LN(close_price / LAG(close_price, 1) OVER (PARTITION BY ticker ORDER BY trade_date)), 6) AS log_return
FROM asset_prices;

-- 2. 30-Day Annualized Rolling Volatility View
CREATE OR REPLACE VIEW rolling_volatility AS
SELECT 
    trade_date,
    ticker,
    log_return,
    ROUND(
        STDDEV_SAMP(log_return) OVER (
            PARTITION BY ticker 
            ORDER BY trade_date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) * SQRT(252), 4
    ) AS vol_30d_annualized
FROM daily_returns
WHERE log_return IS NOT NULL;

-- 3. 3-Sigma Market Shock Detection View
CREATE OR REPLACE VIEW market_shocks AS
WITH rolling_stats AS (
    SELECT 
        trade_date,
        ticker,
        log_return,
        AVG(log_return) OVER (
            PARTITION BY ticker 
            ORDER BY trade_date 
            ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
        ) AS mean_90d,
        STDDEV_SAMP(log_return) OVER (
            PARTITION BY ticker 
            ORDER BY trade_date 
            ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
        ) AS std_90d
    FROM daily_returns
    WHERE log_return IS NOT NULL
)
SELECT 
    trade_date,
    ticker,
    log_return,
    ROUND((log_return - mean_90d) / NULLIF(std_90d, 0), 2) AS z_score,
    CASE 
        WHEN ABS((log_return - mean_90d) / NULLIF(std_90d, 0)) >= 3.0 THEN 1 
        ELSE 0 
    END AS is_shock_day
FROM rolling_stats;
