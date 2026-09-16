# Multi-asset-risk-simulator
An end-to-end quantitative data pipeline designed to monitor cross-asset market stress across Equities (^GSPC), Interest Rates (^TNX), Energy (BZ=F), and Gold (GC=F).

The system automates market data extraction via Python, stores relational historical price feeds in MySQL, and leverages dynamic SQL Views to compute 30-day annualized rolling volatility (252 scaling) and flag extreme 3σ tail-risk shocks in real time.

## 🛠️ Tech Stack & Architecture

* **Language:** Python (`yfinance`, `pandas`, `mysql-connector-python`)
* **Database Management:** MySQL Server & MySQL Workbench (Relational Engine)
* **Key SQL Features:** Composite Primary Keys, Views, Window Functions (`LAG()`, `STDDEV_SAMP()`, `AVG()`)
* **Quantitative Metrics:** Time-additive Log Returns, 252-Day Volatility Annualization ($\sqrt{252}$), 90-Day Sliding Z-Scores, $3\sigma$ Shock Triggers

### System Architecture Pipeline
```text
Yahoo Finance API (yfinance)
       │
       ▼
Python Ingestion Script (01_data_ingestion.py)
       │
       ▼
MySQL Relational Database (global_markets.asset_prices)
       │
       ▼
SQL Analytics Views (daily_returns ➔ rolling_volatility ➔ market_shocks)
       │
       ▼
Automated Risk Alerts & Visualization Engine (03_plot_volatility.py)
```
## 📊 Asset Universe Monitored

1. **S&P 500 (`^GSPC`):** US Equity Market Benchmark
2. **10-Year US Treasury Yield (`^TNX`):** Benchmark Risk-Free Rate & Borrowing Cost
3. **Brent Crude Oil (`BZ=F`):** Global Energy & Supply-Chain Commodity Vector
4. **Gold (`GC=F`):** Inflation Safe-Haven Asset

---

## 💻 Step-by-Step Implementation

### Step 1: Automated Data Ingestion (`scripts/01_data_ingestion.py`)

Python fetches 5 years of daily adjusted closing prices via `yfinance`, standardizes the data using `pandas`, and writes directly into the local MySQL database.

```python
import mysql.connector
import numpy as np
import pandas as pd
import yfinance as yf

# 1. Connect to MySQL Database
db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="YOUR_PASSWORD",
    database="global_markets",
)
cursor = db.cursor()

# 2. Ingest Historical Daily Market Prices
tickers = ["^GSPC", "^TNX", "BZ=F", "GC=F"]
raw_data = yf.download(tickers, start="2021-01-01")["Close"]

# 3. Clean and Insert into MySQL Table
for ticker in tickers:
    df_asset = raw_data[[ticker]].dropna().reset_index()
    for _, row in df_asset.iterrows():
        trade_date = row["Date"].strftime("%Y-%m-%d")
        close_price = float(row[ticker])

        query = """
        INSERT INTO asset_prices (trade_date, ticker, close_price)
        VALUES (%s, %s, %s)
        ON DUPLICATE KEY UPDATE close_price = VALUES(close_price);
        """
        cursor.execute(query, (trade_date, ticker, close_price))

db.commit()
cursor.close()
db.close()
```
### Step 2: MySQL Database Schema Design
Create the target database and relational table with a composite primary key (trade_date, ticker) to prevent record duplication and enforce data integrity.
```sql
CREATE DATABASE IF NOT EXISTS global_markets;
USE global_markets;

CREATE TABLE IF NOT EXISTS asset_prices (
    trade_date DATE NOT NULL,
    ticker VARCHAR(10) NOT NULL,
    close_price DECIMAL(12, 4) NOT NULL,
    PRIMARY KEY (trade_date, ticker)
);
```

---

### Step 3: Dynamic SQL Analytics Views

```sql
-- Daily Returns View
Calculates time-additive daily logarithmic returns using LAG() window functions partitioned by ticker.$$\text{Log Return}_t = \ln\left(\frac{P_t}{P_{t-1}}\right)$$
CREATE OR REPLACE VIEW daily_returns AS
SELECT 
    trade_date,
    ticker,
    close_price,
    LAG(close_price, 1) OVER (PARTITION BY ticker ORDER BY trade_date) AS prev_close_price,
    ROUND(LN(close_price / LAG(close_price, 1) OVER (PARTITION BY ticker ORDER BY trade_date)), 6) AS log_return
FROM asset_prices;

--30-Day Annualized Rolling Volatility View
Calculates rolling 30-day standard deviation scaled by $\sqrt{252}$ trading days to compute annualized asset risk.$$\sigma_{\text{Annualized}} = \sigma_{30\text{d}} \times \sqrt{252}$$
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

--$3\sigma$ Market Shock Detection View
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
```
### Step 4: Visual Reporting Engine
Python connects directly to the MySQL database view (rolling_volatility) to extract pre-processed metrics and output an automated trend plot.
```
import matplotlib.pyplot as plt
import mysql.connector
import pandas as pd
import seaborn as sns

# 1. Connect to MySQL View
db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="YOUR_PASSWORD",
    database="global_markets",
)

query = "SELECT trade_date, ticker, vol_30d_annualized FROM rolling_volatility WHERE vol_30d_annualized IS NOT NULL;"
df = pd.read_sql(query, con=db)
db.close()

# 2. Pivot & Plot
df_pivot = df.pivot(
    index="trade_date", columns="ticker", values="vol_30d_annualized"
)

sns.set_theme(style="whitegrid")
plt.figure(figsize=(12, 6), dpi=300)

for ticker in df_pivot.columns:
    plt.plot(df_pivot.index, df_pivot[ticker], label=ticker, linewidth=1.8)

plt.title(
    "30-Day Rolling Annualized Volatility (MySQL Views Pipeline)",
    fontsize=14,
    fontweight="bold",
)
plt.ylabel("Annualized Volatility (σ)")
plt.gca().yaxis.set_major_formatter(
    plt.FuncFormatter(lambda y, _: "{:.0%}".format(y))
)
plt.legend(title="Asset Class", loc="upper right")
plt.tight_layout()

# Save image for documentation
plt.savefig("docs/rolling_volatility_chart.png", dpi=300)
plt.show()
```

