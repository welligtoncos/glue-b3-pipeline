# Convenção de Nomenclatura

Padrão adotado para garantir consistência entre S3, Glue, Athena e IAM ao longo do pipeline.

## Padrão geral

```
{project_name}-{environment}-{aws_service}-{purpose}[-{account_id}]
```

| Segmento | Exemplo | Obrigatório | Descrição |
|----------|---------|-------------|-----------|
| `project_name` | `glue-b3` | sim | Identificador do projeto |
| `environment` | `dev` | sim | Ambiente (`dev`, `stg`, `prod`) |
| `aws_service` | `s3`, `glue-db`, `athena-wg` | sim | Serviço AWS abreviado |
| `purpose` | `raw`, `catalog`, `primary` | sim | Função do recurso |
| `account_id` | `303238378103` | S3 only | Sufixo de unicidade global |

### Regras

- Apenas **lowercase**, números e hífens (`[a-z0-9-]`)
- Separador único: hífen (`-`)
- Ordem fixa dos segmentos — não inverter
- `account_id` somente em buckets S3 (nome globalmente único)
- Tags complementam a nomenclatura (`Project`, `Environment`, `ManagedBy`)

## Implementação Terraform

Toda nomenclatura é centralizada em `locals.tf`:

```hcl
name_prefix   = "${var.project_name}-${var.environment}"
global_suffix = var.aws_account_id
```

Recursos futuros devem **sempre** usar `local.name_prefix` — nunca montar strings inline.

## Catálogo de nomes

### US-01 — S3 (implementado)

| Recurso | Padrão | Exemplo (dev) |
|---------|--------|---------------|
| Bucket raw | `{prefix}-s3-raw-{account}` | `glue-b3-dev-s3-raw-303238378103` |
| Bucket Athena results | `{prefix}-s3-athena-results-{account}` | `glue-b3-dev-s3-athena-results-303238378103` |

### US-02 — Glue (reservado)

| Recurso | Padrão | Exemplo (dev) |
|---------|--------|---------------|
| Glue Database | `{prefix}-glue-db-catalog` | `glue-b3-dev-glue-db-catalog` |
| Glue Crawler | `{prefix}-glue-crawler-raw` | `glue-b3-dev-glue-crawler-raw` |
| IAM Role (Crawler) | `{prefix}-iam-glue-crawler` | `glue-b3-dev-iam-glue-crawler` |

### US-03 — Athena (reservado)

| Recurso | Padrão | Exemplo (dev) |
|---------|--------|---------------|
| Workgroup | `{prefix}-athena-wg-primary` | `glue-b3-dev-athena-wg-primary` |

## Abreviações de serviços AWS

| Abreviação | Serviço |
|------------|---------|
| `s3` | Amazon S3 |
| `glue-db` | AWS Glue Database |
| `glue-crawler` | AWS Glue Crawler |
| `athena-wg` | Amazon Athena Workgroup |
| `iam` | IAM Role / Policy |

## Nomes no Terraform vs. AWS

| Contexto | Convenção | Exemplo |
|----------|-----------|---------|
| Nome físico na AWS | padrão acima | `glue-b3-dev-s3-raw-303238378103` |
| Recurso Terraform | snake_case descritivo | `aws_s3_bucket.this["raw"]` |
| Arquivo Terraform | por domínio | `locals.tf`, `main.tf`, `outputs.tf` |
| Output Terraform | snake_case | `s3_bucket_raw_name` |

## Prefixos por ambiente

| Ambiente | Prefixo | Exemplo bucket raw |
|----------|---------|-------------------|
| dev | `glue-b3-dev-...` | `glue-b3-dev-s3-raw-303238378103` |
| staging | `glue-b3-stg-...` | `glue-b3-stg-s3-raw-303238378103` |
| prod | `glue-b3-prod-...` | `glue-b3-prod-s3-raw-303238378103` |

## Migração da nomenclatura anterior

| Antigo | Novo |
|--------|------|
| `glue-b3-raw-{account}` | `glue-b3-dev-s3-raw-{account}` |
| `glue-b3-athena-results-{account}` | `glue-b3-dev-s3-athena-results-{account}` |

> Aplicar a nova convenção **recria** os buckets S3. Em dev, com `force_destroy = true`, execute `terraform apply` e confirme a substituição.

## Consultar nomes provisionados

```powershell
terraform output
terraform output s3_bucket_raw_name
terraform output naming_convention
```
