# US-03 — Glue Database (Data Catalog)

**Status:** ✅ Database implementado · 🔜 Crawler (próxima entrega)

## O que é o Glue Data Catalog?

O **AWS Glue Data Catalog** é o repositório central de metadados da AWS — funciona como um **schema registry** para todo o pipeline de dados. Ele armazena:

- **Databases** — namespaces que agrupam tabelas relacionadas
- **Tables** — definição de colunas, tipos e localização dos dados no S3
- **Partitions** — metadados de particionamento (ex.: por data ou ticker)

No contexto deste projeto, o Data Catalog é a **ponte entre o S3 e o Athena**: os arquivos no bucket raw são apenas bytes; o catálogo descreve *o que* são esses arquivos e *como* consultá-los via SQL.

```
S3 (arquivos Parquet/CSV)
        ↓  Glue Crawler infere schema
Glue Data Catalog (database: b3_raw → tabelas)
        ↓  Athena lê metadados
SELECT * FROM b3_raw.stocks
```

## Por que é necessário neste pipeline?

| Sem Data Catalog | Com Data Catalog |
|------------------|------------------|
| Athena não sabe onde estão os dados | Tabelas apontam para paths S3 |
| Schema manual a cada consulta | Colunas e tipos inferidos/registrados |
| Sem descoberta automática | Crawler atualiza metadados periodicamente |
| Queries impossíveis ou frágeis | SQL padrão (`SELECT`, `JOIN`, `WHERE`) |

O database **`b3_raw`** é o namespace lógico para todas as tabelas de dados brutos da B3/Ibovespa. Quando o Crawler (US-04) varrer o bucket raw, ele registrará tabelas **dentro** deste database.

## Como o Athena usa o database

Ao executar uma query, o Athena:

1. **Resolve o namespace** — lê `b3_raw` no Glue Data Catalog
2. **Localiza a tabela** — ex.: `b3_raw.stocks` → obtém schema + path S3
3. **Planeja a query** — determina quais arquivos/partições ler
4. **Executa no S3** — lê dados diretamente do bucket raw (sem copiar)
5. **Grava resultados** — output no bucket athena-results

Exemplo de query futura:

```sql
SELECT ticker, close_price, trade_date
FROM b3_raw.stocks
WHERE trade_date >= DATE '2024-01-01'
LIMIT 100;
```

A IAM policy de analysts (`glue-b3-dev-iam-athena-query`) já referencia este database via ARN:

```
arn:aws:glue:us-east-1:303238378103:database/b3_raw
```

## Recurso Terraform

Arquivo: `glue.tf`

```hcl
resource "aws_glue_catalog_database" "this" {
  name        = var.glue_db_name   # default: b3_raw
  description = "Dados brutos da B3 — Ibovespa stocks"
}
```

Variável configurável em `terraform.tfvars`:

```hcl
glue_db_name = "b3_raw"
```

## Verificação

### Terraform

```powershell
terraform output glue_database_name
terraform output glue_database_arn
terraform plan -var-file="terraform.tfvars"
```

### AWS CLI

Listar databases e confirmar `b3_raw`:

```powershell
aws glue get-databases --query "DatabaseList[?Name=='b3_raw']"
```

Detalhes completos do database:

```powershell
aws glue get-database --name b3_raw
```

Saída esperada (campos principais):

```json
{
    "Database": {
        "Name": "b3_raw",
        "Description": "Dados brutos da B3 — Ibovespa stocks",
        "LocationUri": "..."
    }
}
```

Listar tabelas (vazio até o Crawler rodar):

```powershell
aws glue get-tables --database-name b3_raw
```

## Critérios de aceite — US-03 (Database)

- [x] Resource `aws_glue_catalog_database` criado
- [x] Nome configurável via `glue_db_name` (default: `b3_raw`)
- [x] Description definida
- [x] Outputs exportados (`glue_database_name`, `glue_database_arn`)

## Próximo passo

- **US-04** — Glue Crawler apontando para o bucket raw, registrando tabelas em `b3_raw`
