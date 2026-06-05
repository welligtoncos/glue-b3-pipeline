# US-09 — Validacao de schema e qualidade no S3

**Status:** ✅ Implementado

## Objetivo

Garantir integridade dos CSVs em `raw/ibovespa/` antes de executar o Glue Crawler.

## Uso

```powershell
cd c:\welligton-aws\project-glue-2
$bucket = terraform output -raw s3_bucket_raw_name

python scripts/validate_data.py --bucket $bucket
```

Opcional — copia local do relatorio:

```powershell
python scripts/validate_data.py --bucket $bucket --local-report data/local/validacao.csv
```

## Validacoes por arquivo

| Regra | Contador |
|-------|----------|
| Colunas `ticker, date, open, high, low, close, volume` | `erros_schema` |
| Valores nulos em colunas obrigatorias | `erros_schema` |
| `close > 0` | `erros_close` |
| `date` YYYY-MM-DD sem nulos | `erros_data` |
| `volume > 0` | `erros_data` |
| Sem duplicatas (`ticker` + `date`) | `erros_data` |

## Relatorio

Colunas: `ticker | total_linhas | erros_schema | erros_close | erros_data | status`

Salvo em: `s3://{bucket}/reports/validacao_{timestamp}.csv`

## Exemplo de saida (dados atuais)

```
--- Relatorio de validacao ---
ticker  total_linhas  erros_schema  erros_close  erros_data  status
 BBDC4          2092             0            0           0      OK
 ITUB4          2092             0            0           0      OK
 PETR4          2092             0            0           0      OK
 VALE3          2092             0            0           0      OK

Resumo: 4 arquivos | erros_totais=0 | geral=OK
Relatorio S3: s3://glue-b3-dev-s3-raw-.../reports/validacao_20260605_020000.csv
```

## Criterios de aceite — US-09

- [x] Lista CSVs em `raw/ibovespa/`
- [x] Valida colunas, datas, close, volume e duplicatas
- [x] Relatorio tabular com colunas exigidas
- [x] Salva relatorio em `reports/validacao_{timestamp}.csv`

## Verificacao

```powershell
python scripts/validate_data.py --bucket $bucket
aws s3 ls "s3://$bucket/reports/"
```

## Dados no S3 com volume zero

Se a validacao falhar por `erros_data` apos exigir `volume > 0`, reenvie os CSVs:

```powershell
python scripts/download_ibovespa.py --bucket $bucket
python scripts/validate_data.py --bucket $bucket
```

O download remove linhas com `volume <= 0` automaticamente (US-07).

## Proximo passo

- **Glue Crawler** — catalogar `raw/ibovespa/` apos validacao OK
