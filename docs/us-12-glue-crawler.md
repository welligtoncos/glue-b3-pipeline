# US-12 — Glue Crawler (Terraform)

**Status:** ✅ Implementado

## Objetivo

Automatizar a descoberta de schema e criacao da tabela `ibovespa` no database `b3_raw` a partir dos CSVs em `s3://{bucket}/raw/ibovespa/`.

## Recurso

Arquivo: `glue.tf` — `aws_glue_crawler.ibovespa`

| Propriedade | Valor |
|-------------|-------|
| Nome | `glue-b3-dev-glue-crawler-raw` |
| Database | `b3_raw` |
| IAM Role | `glue-b3-dev-iam-glue-crawler` |
| S3 target | `s3://glue-b3-dev-s3-raw-{account}/raw/ibovespa/` |
| Tabela esperada | `ibovespa` |

## Configuracao JSON

| Chave | Valor | Efeito |
|-------|-------|--------|
| `Grouping.TableGroupingPolicy` | `CombineCompatibleSchemas` | Combina schemas compativeis |
| `CrawlerOutput.Partitions.AddOrUpdateBehavior` | `InheritFromTable` | Particoes herdadas da tabela |
| `CrawlerOutput.Tables.AddOrUpdateBehavior` | `MergeNewColumns` | Novas colunas mescladas sem recriar tabela |

## schema_change_policy

| Comportamento | Valor | Motivo |
|---------------|-------|--------|
| `delete_behavior` | `LOG` | Nunca remove tabela do Catalog automaticamente |
| `update_behavior` | `UPDATE_IN_DATABASE` | Atualiza metadados no Catalog |

## Schedule (opcional)

Variavel `crawler_schedule` em `terraform.tfvars`:

```hcl
crawler_schedule = "cron(0 6 * * ? *)"  # diario 06:00 UTC
```

`null` (default) = apenas execucao manual via CLI ou console.

## Deploy

```powershell
terraform plan  -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

Se o crawler ja existir (criado manualmente na US-10), importe antes do apply:

```powershell
terraform import aws_glue_crawler.ibovespa glue-b3-dev-glue-crawler-raw
```

## Executar o crawler

```powershell
$crawler = terraform output -raw glue_crawler_name

aws glue start-crawler --name $crawler
```

Aguarde alguns minutos e verifique o estado:

```powershell
aws glue get-crawler --name $crawler --query "Crawler.{State:State,LastCrawl:LastCrawl}"
```

Status esperado de `LastCrawl.Status`: **SUCCEEDED**.

## Monitoramento

### Estado do crawler

```powershell
aws glue get-crawler --name $crawler
```

### Tabela no Catalog

```powershell
aws glue get-table --database-name b3_raw --name ibovespa
```

### Logs (erros)

```powershell
aws logs filter-log-events `
  --log-group-name "/aws-glue/crawlers/glue-b3-crawler" `
  --filter-pattern "ERROR"
```

### Particoes detectadas

```powershell
aws glue get-partitions --database-name b3_raw --table-name ibovespa --max-results 10
```

## Query Athena (apos SUCCEEDED)

Use o database **`b3_raw`** (nao outro database como `rh_db`). Workgroup: **`glue-b3-workgroup`**.

### Por que consultar o Athena?

O Crawler so registra **metadados** no Glue Catalog. A query no Athena confirma que os dados no S3 sao **legiveis via SQL** — fechando o ciclo ingestao → catalogacao → consulta.

### Query de validacao (recomendada primeiro)

Nao e analise de negocio; e **teste de ponta a ponta**:

```sql
SELECT ticker, date, close, volume
FROM b3_raw.ibovespa
WHERE ticker = 'PETR4'
ORDER BY date DESC
LIMIT 10;
```

| Se funcionar | Significa |
|--------------|-----------|
| Retorna 10 linhas | Particao `ticker`, schema e permissoes OK |
| Erro `duplicate columns` | CSV no S3 ainda tem coluna `ticker` (ver secao abaixo) |
| Erro em `rh_db` ou outro DB | Database errado no console — use `b3_raw` |

### Query analitica (contagem por ticker)

```sql
SELECT ticker, COUNT(*) AS registros
FROM b3_raw.ibovespa
GROUP BY ticker;
```

### Erro `HIVE_INVALID_METADATA: duplicate columns`

Causa: coluna `ticker` no CSV **e** na particao `ticker=.../`. Correcao:

```powershell
aws glue delete-table --database-name b3_raw --name ibovespa
$bucket = terraform output -raw s3_bucket_raw_name
python scripts/download_ibovespa.py --bucket $bucket
aws glue start-crawler --name glue-b3-dev-glue-crawler-raw
```

## Criterios de aceite — US-12

- [x] `aws_glue_crawler` em `glue.tf`
- [x] S3 target `raw/ibovespa/`
- [x] `database_name` = `b3_raw`
- [x] Role IAM do Sprint 1
- [x] Configuration: CombineCompatibleSchemas, InheritFromTable, MergeNewColumns
- [x] `schema_change_policy`: LOG + UPDATE_IN_DATABASE
- [x] `crawler_schedule` opcional via variavel

## Proximo passo

- Queries analiticas no Athena (MM7, MM30)
- Agendar `crawler_schedule` em producao se necessario
