# US-07 — Download Ibovespa (yfinance)

**Status:** ✅ Implementado

## Objetivo

Baixar historico diario de acoes do Ibovespa via `yfinance` e salvar CSV local para ingestao futura no S3 raw.

## Requisitos

```powershell
pip install -r requirements.txt
```

## Uso

```powershell
cd c:\welligton-aws\project-glue-2

# Download padrao (PETR4, VALE3, ITUB4, BBDC4 desde 2018)
python scripts/download_ibovespa.py

# Customizado
python scripts/download_ibovespa.py `
  --tickers PETR4 VALE3 `
  --start 2018-01-01 `
  --output data/local/ibovespa_stocks.csv
```

## Saida

Arquivo default: `data/local/ibovespa_stocks.csv`

| Coluna | Tipo | Descricao |
|--------|------|-----------|
| `ticker` | string | Codigo B3 (sem `.SA`) |
| `date` | string | Data YYYY-MM-DD |
| `open` | float | Preco abertura |
| `high` | float | Preco maximo |
| `low` | float | Preco minimo |
| `close` | float | Preco fechamento |
| `volume` | int | Volume negociado |

## Tickers padrao

| Ticker | yfinance |
|--------|----------|
| PETR4 | PETR4.SA |
| VALE3 | VALE3.SA |
| ITUB4 | ITUB4.SA |
| BBDC4 | BBDC4.SA |

> B3 exige sufixo `.SA` no yfinance.

Linhas com `volume <= 0` (artefato ocasional do yfinance) sao removidas automaticamente antes de salvar/enviar ao S3, alinhado a validacao US-09 (`volume > 0`).

## Criterios de aceite — US-07

- [x] Script `download_ibovespa.py` funcional
- [x] Tickers: PETR4, VALE3, ITUB4, BBDC4
- [x] Colunas: ticker, date, open, high, low, close, volume
- [x] Periodo >= 2018

## Verificacao

```powershell
python scripts/download_ibovespa.py

# Conferir colunas e periodo
Import-Csv data/local/ibovespa_stocks.csv | Select-Object -First 5
(Import-Csv data/local/ibovespa_stocks.csv | Measure-Object).Count
(Import-Csv data/local/ibovespa_stocks.csv | Select-Object -ExpandProperty ticker -Unique)
(Import-Csv data/local/ibovespa_stocks.csv | Measure-Object -Property date -Minimum -Maximum)
```

## Proximo passo

- Upload particionado no S3: [US-08 — Upload S3](us-08-upload-s3.md)
