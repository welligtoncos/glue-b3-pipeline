#!/usr/bin/env python3
"""
US-09 — Validacao de schema e qualidade dos CSVs Ibovespa no S3.

Lista arquivos em raw/ibovespa/, valida integridade e gera relatorio no S3.
"""

from __future__ import annotations

import argparse
import io
import re
from datetime import datetime, timezone

import boto3
import pandas as pd

S3_RAW_PREFIX = "raw/ibovespa/"
S3_REPORTS_PREFIX = "reports/"

# CSV no S3: sem ticker (coluna de particao Hive vem do path ticker=...)
S3_FILE_COLUMNS = ["date", "open", "high", "low", "close", "volume"]
LEGACY_FILE_COLUMNS = ["ticker", "date", "open", "high", "low", "close", "volume"]
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")

REPORT_COLUMNS = [
    "ticker",
    "total_linhas",
    "erros_schema",
    "erros_close",
    "erros_data",
    "status",
]


def list_csv_keys(s3_client, bucket: str, prefix: str = S3_RAW_PREFIX) -> list[str]:
    """Lista chaves .csv sob o prefixo raw/ibovespa/."""
    keys: list[str] = []
    paginator = s3_client.get_paginator("list_objects_v2")

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key.lower().endswith(".csv"):
                keys.append(key)

    return sorted(keys)


def ticker_from_key(key: str) -> str:
    """Extrai ticker de raw/ibovespa/ticker=PETR4/PETR4.csv"""
    for segment in key.split("/"):
        if segment.startswith("ticker="):
            return segment.split("=", 1)[1]
    stem = key.rsplit("/", 1)[-1]
    return stem.removesuffix(".csv").upper()


def read_csv_from_s3(s3_client, bucket: str, key: str) -> pd.DataFrame:
    response = s3_client.get_object(Bucket=bucket, Key=key)
    body = response["Body"].read().decode("utf-8")
    return pd.read_csv(io.StringIO(body))


def count_invalid_dates(series: pd.Series) -> int:
    nulls = series.isna() | (series.astype(str).str.strip() == "")
    non_null = series[~nulls].astype(str)
    invalid_format = ~non_null.str.match(DATE_PATTERN)
    parsed = pd.to_datetime(non_null, format="%Y-%m-%d", errors="coerce")
    invalid_parse = parsed.isna()
    return int(nulls.sum() + (invalid_format | invalid_parse).sum())


def validate_dataframe(df: pd.DataFrame, partition_ticker: str) -> dict[str, int | str]:
    total = len(df)
    columns = list(df.columns)

    if columns == LEGACY_FILE_COLUMNS:
        return {
            "total_linhas": total,
            "erros_schema": total if total else 1,
            "erros_close": 0,
            "erros_data": 0,
            "status": "FAIL (coluna ticker no CSV duplica particao Hive; reenvie com download_ibovespa.py --bucket)",
        }

    if columns != S3_FILE_COLUMNS:
        missing = set(S3_FILE_COLUMNS) - set(columns)
        extra = set(columns) - set(S3_FILE_COLUMNS)
        detail = []
        if missing:
            detail.append(f"faltando={sorted(missing)}")
        if extra:
            detail.append(f"extras={sorted(extra)}")
        return {
            "total_linhas": total,
            "erros_schema": total if total else 1,
            "erros_close": 0,
            "erros_data": 0,
            "status": f"FAIL ({'; '.join(detail) or 'colunas invalidas'})",
        }

    erros_schema = int(df[S3_FILE_COLUMNS].isna().any(axis=1).sum())

    close_numeric = pd.to_numeric(df["close"], errors="coerce")
    erros_close = int((close_numeric.isna() | (close_numeric <= 0)).sum())

    erros_data = count_invalid_dates(df["date"])
    volume_numeric = pd.to_numeric(df["volume"], errors="coerce")
    erros_data += int((volume_numeric.isna() | (volume_numeric <= 0)).sum())

    dup_mask = df.duplicated(subset=["date"], keep=False)
    erros_data += int(dup_mask.sum())

    status = "OK" if (erros_schema + erros_close + erros_data) == 0 else "FAIL"

    return {
        "total_linhas": total,
        "erros_schema": erros_schema,
        "erros_close": erros_close,
        "erros_data": erros_data,
        "status": status,
    }


def validate_s3_data(bucket: str, prefix: str = S3_RAW_PREFIX) -> pd.DataFrame:
    s3_client = boto3.client("s3")
    keys = list_csv_keys(s3_client, bucket, prefix=prefix)

    if not keys:
        raise SystemExit(f"Nenhum CSV encontrado em s3://{bucket}/{prefix}")

    rows: list[dict[str, str | int]] = []

    for key in keys:
        ticker = ticker_from_key(key)
        print(f"Validando s3://{bucket}/{key} ...")
        df = read_csv_from_s3(s3_client, bucket, key)
        result = validate_dataframe(df, partition_ticker=ticker)
        rows.append({"ticker": ticker, **result})

    return pd.DataFrame(rows, columns=REPORT_COLUMNS)


def save_report_s3(
    report: pd.DataFrame,
    bucket: str,
    s3_client=None,
    timestamp: str | None = None,
) -> str:
    s3_client = s3_client or boto3.client("s3")
    ts = timestamp or datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    key = f"{S3_REPORTS_PREFIX}validacao_{ts}.csv"

    buffer = io.StringIO()
    report.to_csv(buffer, index=False)
    body = buffer.getvalue().encode("utf-8")

    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=body,
        ContentType="text/csv",
    )
    return key


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Valida schema e qualidade dos CSVs Ibovespa no S3 (US-09)."
    )
    parser.add_argument(
        "--bucket",
        required=True,
        help="Nome do bucket S3 raw",
    )
    parser.add_argument(
        "--prefix",
        default=S3_RAW_PREFIX,
        help=f"Prefixo dos CSVs no S3 (default: {S3_RAW_PREFIX})",
    )
    parser.add_argument(
        "--local-report",
        type=str,
        default=None,
        help="Salva copia local do relatorio (opcional)",
    )
    parser.add_argument(
        "--no-upload",
        action="store_true",
        help="Apenas exibe relatorio, sem salvar no S3",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    report = validate_s3_data(bucket=args.bucket, prefix=args.prefix)

    print("\n--- Relatorio de validacao ---")
    print(report.to_string(index=False))

    all_ok = (report["status"] == "OK").all()
    total_errors = (
        report["erros_schema"].sum()
        + report["erros_close"].sum()
        + report["erros_data"].sum()
    )
    print(f"\nResumo: {len(report)} arquivos | erros_totais={total_errors} | geral={'OK' if all_ok else 'FAIL'}")

    if args.local_report:
        report.to_csv(args.local_report, index=False)
        print(f"Relatorio local: {args.local_report}")

    if not args.no_upload:
        key = save_report_s3(report, bucket=args.bucket)
        print(f"Relatorio S3: s3://{args.bucket}/{key}")

    if not all_ok:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
