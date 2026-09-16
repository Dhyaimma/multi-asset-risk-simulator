# Multi-asset-risk-simulator
An end-to-end quantitative data pipeline designed to monitor cross-asset market stress across Equities (^GSPC), Interest Rates (^TNX), Energy (BZ=F), and Gold (GC=F).

The system automates market data extraction via Python, stores relational historical price feeds in MySQL, and leverages dynamic SQL Views to compute 30-day annualized rolling volatility (252 scaling) and flag extreme 3σ tail-risk shocks in real time.
