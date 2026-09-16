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
#### 📊 Asset Universe Monitored

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
