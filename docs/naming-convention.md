# Convencao de Nomenclatura

Padrao adotado para consistencia entre S3, Glue, Athena, IAM e CloudWatch.

## Padrao geral

```
{project_name}-{environment}-{aws_service}-{purpose}[-{account_id}]
```

| Segmento | Exemplo | Obrigatorio | Descricao |
|----------|---------|-------------|-----------|
| `project_name` | `glue-b3` | sim | Identificador do projeto |
| `environment` | `dev` | sim | Ambiente (`dev`, `stg`, `prod`) |
| `aws_service` | `s3`, `iam`, `glue-crawler` | sim | Servico AWS abreviado |
| `purpose` | `raw`, `athena-query` | sim | Funcao do recurso |
| `account_id` | `303238378103` | S3 only | Unicidade global |

### Excecoes (nomes logicos)

| Recurso | Nome | Padrao |
|---------|------|--------|
| Glue Database | `b3_raw` | Variavel `glue_db_name` |
| Athena Workgroup | `glue-b3-workgroup` | `{project_name}-workgroup` |
| Log Group | `/aws-glue/crawlers/glue-b3-crawler` | Padrao AWS Glue |

### Regras

- Lowercase, numeros e hifens (`[a-z0-9-]`) — underscore apenas em `b3_raw`
- Separador: hifen (`-`)
- `account_id` somente em buckets S3
- Tags: `Project`, `Environment`, `ManagedBy`

## Implementacao Terraform

Centralizado em `locals.tf`:

```hcl
name_prefix   = "${var.project_name}-${var.environment}"
global_suffix = var.aws_account_id
glue_database_name          = var.glue_db_name
athena_workgroup_name       = "${var.project_name}-workgroup"
glue_crawler_log_group_name = "/aws-glue/crawlers/${var.project_name}-crawler"
```

## Catalogo de nomes — Sprint 1 (implementado)

### US-01 — S3

| Recurso | Nome (dev) |
|---------|------------|
| Bucket raw | `glue-b3-dev-s3-raw-303238378103` |
| Bucket Athena results | `glue-b3-dev-s3-athena-results-303238378103` |

### US-02 — IAM

| Recurso | Nome (dev) |
|---------|------------|
| Role Crawler | `glue-b3-dev-iam-glue-crawler` |
| Policy Athena | `glue-b3-dev-iam-athena-query` |
| Group Analysts | `glue-b3-dev-iam-grp-athena-analysts` |

### US-03 — Glue Database

| Recurso | Nome |
|---------|------|
| Database | `b3_raw` |

### US-04 — Athena

| Recurso | Nome |
|---------|------|
| Workgroup | `glue-b3-workgroup` |

### US-05 — CloudWatch

| Recurso | Nome |
|---------|------|
| Log Group | `/aws-glue/crawlers/glue-b3-crawler` |

## Sprint 2 (reservado)

| Recurso | Padrao | Exemplo (dev) |
|---------|--------|---------------|
| Glue Crawler | `{prefix}-glue-crawler-raw` | `glue-b3-dev-glue-crawler-raw` |

## Abreviacoes

| Abreviacao | Servico |
|------------|---------|
| `s3` | Amazon S3 |
| `iam` | IAM Role / Policy / Group |
| `glue-db` | Glue Database |
| `glue-crawler` | Glue Crawler |
| `athena-wg` | Athena Workgroup |

## Terraform vs AWS

| Contexto | Convencao | Exemplo |
|----------|-----------|---------|
| Nome AWS | padrao acima | `glue-b3-dev-s3-raw-303238378103` |
| Recurso TF | snake_case / for_each | `aws_s3_bucket.this["raw"]` |
| Arquivo TF | por dominio | `main.tf`, `iam.tf`, `glue.tf`, `athena.tf` |
| Output TF | snake_case | `s3_bucket_raw_name` |

## Consultar nomes

```powershell
terraform output
terraform output naming_convention
terraform output glue_database_name
terraform output athena_workgroup_name
terraform output glue_crawler_log_group_name
```
