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
