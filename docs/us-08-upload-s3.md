# US-08 — Upload CSV particionado no S3

**Status:** ✅ Implementado

## Objetivo

Persistir os dados Ibovespa no bucket S3 raw com estrutura de particao Hive (`ticker=...`) para o Glue Crawler inferir particoes automaticamente.

## Requisitos

```powershell
pip install -r requirements.txt
```

Credenciais AWS configuradas (`aws configure` ou variaveis de ambiente) com permissao `s3:PutObject` no bucket raw.

## Uso

```powershell
cd c:\welligton-aws\project-glue-2

# Obter nome do bucket
$bucket = terraform output -raw s3_bucket_raw_name

# Download + upload particionado
python scripts/download_ibovespa.py --bucket $bucket
```

## Estrutura no S3

```
s3://{bucket}/raw/ibovespa/
├── ticker=BBDC4/BBDC4.csv
├── ticker=ITUB4/ITUB4.csv
├── ticker=PETR4/PETR4.csv
└── ticker=VALE3/VALE3.csv
```

Cada arquivo contém as colunas: `ticker, date, open, high, low, close, volume`.

## Criterios de aceite — US-08

- [x] Particao Hive: `raw/ibovespa/ticker=<TICKER>/<TICKER>.csv`
- [x] Upload via `boto3` `put_object()` com `Content-Type: text/csv`
- [x] Corpo em UTF-8 via `io.StringIO` (sem arquivo temporario)
- [x] Log com bucket, key e linhas enviadas
- [x] Parametro CLI `--bucket`

---

## Por que particao Hive (`ticker=PETR4/`) e nao pasta simples?

| Abordagem | Exemplo | Glue / Athena |
|-----------|---------|---------------|
| Pasta simples | `raw/ibovespa/PETR4/PETR4.csv` | Crawler cria tabela, mas **nao** registra `ticker` como particao |
| Hive style | `raw/ibovespa/ticker=PETR4/PETR4.csv` | Crawler **infere** coluna de particao `ticker` e valores (`PETR4`, …) |

O padrao `chave=valor` no path e o contrato que Spark, Hive, Glue e Athena usam para **partition pruning**: consultas com `WHERE ticker = 'PETR4'` leem apenas o prefixo correspondente, reduzindo dados escaneados e custo no Athena.

Pastas “bonitas” (`PETR4/`) funcionam para organizacao humana, mas o catalogo trata tudo como um unico dataset sem particao logica — a menos que voce configure particoes manualmente depois.

---

## Verificar arquivos no S3 (AWS CLI)

```powershell
$bucket = terraform output -raw s3_bucket_raw_name

# Listar estrutura particionada
aws s3 ls "s3://$bucket/raw/ibovespa/" --recursive

# Conferir um ticker
aws s3 ls "s3://$bucket/raw/ibovespa/ticker=PETR4/"

# Baixar e inspecionar cabecalho
aws s3 cp "s3://$bucket/raw/ibovespa/ticker=PETR4/PETR4.csv" - | Select-Object -First 5

# Contar linhas (exclui header)
(aws s3 cp "s3://$bucket/raw/ibovespa/ticker=PETR4/PETR4.csv" -).Split("`n").Count - 1
```

---

## Como o Glue Crawler detecta particoes

1. **Target S3** — O crawler aponta para `s3://{bucket}/raw/ibovespa/`.
2. **Varredura de paths** — Percorre subpastas e reconhece segmentos `nome=valor` como particoes Hive.
3. **Tabela no Data Catalog** — Cria/atualiza tabela em `b3_raw` com colunas do CSV + coluna de particao `ticker` (tipo inferido).
4. **Metadados** — Cada particao (`ticker=PETR4`, etc.) fica registrada; Athena usa isso no planejamento da query.

Requisitos para deteccao automatica:

- Formato de path consistente: `ticker=<valor>/`
- Mesmo schema de CSV em todas as particoes
- Crawler configurado com suporte a particoes (default em tables com prefixo Hive)

---

## Proximo passo

- Validar dados: [US-09 — Validacao](us-09-validate-data.md)
- **Glue Crawler** — catalogar `raw/ibovespa/` → tabela em `b3_raw`
