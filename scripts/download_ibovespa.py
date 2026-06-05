#!/usr/bin/env python3
"""
US-07 / US-08 — Download Ibovespa (yfinance) e upload particionado no S3.

Baixa historico diario (OHLCV), salva CSV local e opcionalmente envia ao S3
com particao Hive (ticker=...) para o Glue Crawler.
"""

from __future__ import annotations

import argparse
import io
from pathlib import Path

import boto3
import pandas as pd
import yfinance as yf

# Tickers B3 — sufixo .SA exigido pelo yfinance
DEFAULT_TICKERS = ["PETR4", "VALE3", "ITUB4", "BBDC4"]
YFINANCE_SUFFIX = ".SA"

DEFAULT_START = "2018-01-01"
DEFAULT_OUTPUT = Path("data/local/ibovespa_stocks.csv")
S3_PREFIX = "raw/ibovespa"

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

    df = df[OUTPUT_COLUMNS]
    df["volume"] = pd.to_numeric(df["volume"], errors="coerce")
    zero_volume = int((df["volume"] <= 0).sum())
    if zero_volume:
        print(f"  Removendo {zero_volume} linha(s) com volume <= 0 para {ticker}")
        df = df[df["volume"] > 0]

    return df.reset_index(drop=True)


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


def s3_partition_key(ticker: str) -> str:
    """Chave S3 no padrao Hive: raw/ibovespa/ticker=PETR4/PETR4.csv"""
    ticker = ticker.upper().strip()
    return f"{S3_PREFIX}/ticker={ticker}/{ticker}.csv"


def upload_to_s3(df: pd.DataFrame, bucket: str) -> list[dict[str, str | int]]:
    """
    Envia um CSV por ticker ao S3 com particao Hive (ticker=...).

    Usa put_object + StringIO (UTF-8) sem arquivo temporario em disco.
    """
    client = boto3.client("s3")
    uploads: list[dict[str, str | int]] = []

    for ticker, group in df.groupby("ticker", sort=True):
        buffer = io.StringIO()
        group.to_csv(buffer, index=False)
        body = buffer.getvalue().encode("utf-8")
        key = s3_partition_key(str(ticker))
        line_count = len(group)

        client.put_object(
            Bucket=bucket,
            Key=key,
            Body=body,
            ContentType="text/csv",
        )

        print(
            f"Upload OK | bucket={bucket} | key={key} | linhas_enviadas={line_count:,}"
        )
        uploads.append(
            {
                "bucket": bucket,
                "key": key,
                "lines": line_count,
            }
        )

    return uploads


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Download de dados Ibovespa (B3) via yfinance. "
            "Salva CSV local e opcionalmente envia ao S3 com particao Hive."
        )
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
    parser.add_argument(
        "--bucket",
        default=None,
        help=(
            "Nome do bucket S3 raw. Se informado, faz upload particionado "
            f"em {S3_PREFIX}/ticker=<TICKER>/<TICKER>.csv"
        ),
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

    if args.bucket:
        print(f"Enviando para s3://{args.bucket}/{S3_PREFIX}/ ...")
        upload_to_s3(df, bucket=args.bucket)


if __name__ == "__main__":
    main()
