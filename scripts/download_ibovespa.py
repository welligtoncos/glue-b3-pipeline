#!/usr/bin/env python3
"""
US-07 — Download de cotacoes Ibovespa via yfinance.

Baixa historico diario (OHLCV) e salva CSV local com schema padrao do pipeline.
"""

from __future__ import annotations

import argparse
from datetime import date
from pathlib import Path

import pandas as pd
import yfinance as yf

# Tickers B3 — sufixo .SA exigido pelo yfinance
DEFAULT_TICKERS = ["PETR4", "VALE3", "ITUB4", "BBDC4"]
YFINANCE_SUFFIX = ".SA"

DEFAULT_START = "2018-01-01"
DEFAULT_OUTPUT = Path("data/local/ibovespa_stocks.csv")

OUTPUT_COLUMNS = ["ticker", "date", "open", "high", "low", "close", "volume"]


def to_yfinance_symbol(ticker: str) -> str:
    ticker = ticker.upper().strip()
    if ticker.endswith(YFINANCE_SUFFIX):
        return ticker
    return f"{ticker}{YFINANCE_SUFFIX}"


def download_ticker(ticker: str, start: str, end: str | None) -> pd.DataFrame:
    symbol = to_yfinance_symbol(ticker)
    df = yf.download(
        symbol,
        start=start,
        end=end,
        auto_adjust=False,
        progress=False,
    )

    if df.empty:
        raise ValueError(f"Nenhum dado retornado para {ticker} ({symbol})")

    # yfinance >= 0.2 pode retornar MultiIndex nas colunas
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = df.columns.get_level_values(0)

    df = df.reset_index()

    rename_map = {
        "Date": "date",
        "Datetime": "date",
        "Open": "open",
        "High": "high",
        "Low": "low",
        "Close": "close",
        "Volume": "volume",
    }
    df = df.rename(columns=rename_map)

    df["ticker"] = ticker.upper().replace(YFINANCE_SUFFIX, "")
    df["date"] = pd.to_datetime(df["date"]).dt.strftime("%Y-%m-%d")

    missing = [col for col in OUTPUT_COLUMNS if col not in df.columns]
    if missing:
        raise ValueError(f"Colunas ausentes para {ticker}: {missing}")

    return df[OUTPUT_COLUMNS]


def download_ibovespa(
    tickers: list[str],
    start: str = DEFAULT_START,
    end: str | None = None,
) -> pd.DataFrame:
    frames: list[pd.DataFrame] = []

    for ticker in tickers:
        print(f"Baixando {ticker} desde {start}...")
        frames.append(download_ticker(ticker, start=start, end=end))

    combined = pd.concat(frames, ignore_index=True)
    combined = combined.sort_values(["ticker", "date"]).reset_index(drop=True)
    return combined


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download de dados Ibovespa (B3) via yfinance para CSV local."
    )
    parser.add_argument(
        "--tickers",
        nargs="+",
        default=DEFAULT_TICKERS,
        help=f"Tickers B3 sem sufixo (default: {' '.join(DEFAULT_TICKERS)})",
    )
    parser.add_argument(
        "--start",
        default=DEFAULT_START,
        help=f"Data inicial YYYY-MM-DD (default: {DEFAULT_START})",
    )
    parser.add_argument(
        "--end",
        default=None,
        help="Data final YYYY-MM-DD (default: hoje)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Caminho do CSV de saida (default: {DEFAULT_OUTPUT})",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    start_year = pd.to_datetime(args.start).year
    if start_year > 2018:
        raise SystemExit("Erro: periodo deve ser >= 2018 (use --start 2018-01-01 ou anterior)")

    df = download_ibovespa(tickers=args.tickers, start=args.start, end=args.end)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.output, index=False)

    min_date = df["date"].min()
    max_date = df["date"].max()
    print(f"CSV salvo: {args.output}")
    print(f"Registros: {len(df):,} | Tickers: {df['ticker'].nunique()} | Periodo: {min_date} a {max_date}")


if __name__ == "__main__":
    main()
