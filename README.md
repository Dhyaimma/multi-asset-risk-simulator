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

