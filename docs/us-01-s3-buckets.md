# US-01 — Buckets S3

**Status:** ✅ Concluída  
**Ambiente:** dev · us-east-1  
**Conta:** 303238378103

## Objetivo

Provisionar a camada de armazenamento base do pipeline:

1. Bucket S3 para dados brutos (raw)
2. Bucket S3 para resultados de queries do Athena
3. Versionamento no bucket raw
4. Tags padronizadas em todos os recursos

## Recursos criados

| # | Recurso Terraform | ID / Nome |
|---|-------------------|-----------|
| 1 | `aws_s3_bucket.this["raw"]` | `glue-b3-dev-s3-raw-303238378103` |
| 2 | `aws_s3_bucket_versioning.this["raw"]` | versionamento Enabled |
| 3 | `aws_s3_bucket_public_access_block.this["raw"]` | bloqueio público total |
| 4 | `aws_s3_bucket.this["athena_results"]` | `glue-b3-dev-s3-athena-results-303238378103` |
| 5 | `aws_s3_bucket_public_access_block.this["athena_results"]` | bloqueio público total |

## Especificação

### Padrão de nomenclatura

```
{project_name}-{environment}-s3-{purpose}-{aws_account_id}
```

Ver [Convenção de Nomenclatura](naming-convention.md) para o catálogo completo.

### Bucket raw

| Propriedade | Valor |
|-------------|-------|
| Nome | `{project_name}-{environment}-s3-raw-{aws_account_id}` |
| Versionamento | Enabled |
| `force_destroy` | `true` |
| Acesso público | bloqueado |

### Bucket athena-results

| Propriedade | Valor |
|-------------|-------|
| Nome | `{project_name}-{environment}-s3-athena-results-{aws_account_id}` |
| Versionamento | não habilitado |
| `force_destroy` | `true` |
| Acesso público | bloqueado |

### Tags

Aplicadas via `default_tags` no provider + tag `Name` por bucket:

```hcl
Project     = "glue-b3"
Environment = "dev"
ManagedBy   = "terraform"
Name        = "<nome-do-bucket>"
```

## Código Terraform

Arquivos envolvidos:

- `locals.tf` — padrão centralizado de nomenclatura
- `main.tf` — recursos S3 e provider
- `variables.tf` — variáveis de entrada
- `outputs.tf` — nomes e ARNs exportados

Trecho principal (`locals.tf`):

```hcl
name_prefix   = "${var.project_name}-${var.environment}"
global_suffix = var.aws_account_id

s3_bucket_names = {
  raw            = "${local.name_prefix}-s3-raw-${local.global_suffix}"
  athena_results = "${local.name_prefix}-s3-athena-results-${local.global_suffix}"
}
```

## Critérios de aceite

| Critério | Status |
|----------|--------|
| Bucket raw criado | ✅ |
| Bucket athena-results criado | ✅ |
| Versionamento habilitado | ✅ |
| Tags aplicadas | ✅ |

## Plano de testes

Execute no PowerShell a partir da raiz do projeto.

### Setup

```powershell
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$PROJECT    = "glue-b3"
$ENV        = "dev"
$RAW_BUCKET = terraform output -raw s3_bucket_raw_name
$ATHENA_BUCKET = terraform output -raw s3_bucket_athena_results_name
```

### Teste 1 — State sincronizado

```powershell
terraform plan -var-file="terraform.tfvars"
```

**Esperado:** `No changes. Your infrastructure matches the configuration.`

### Teste 2 — Buckets existem

```powershell
aws s3 ls | Select-String "$PROJECT-$ENV"
```

**Esperado:**

```
glue-b3-dev-s3-raw-303238378103
glue-b3-dev-s3-athena-results-303238378103
```

### Teste 3 — Versionamento

```powershell
aws s3api get-bucket-versioning --bucket $RAW_BUCKET
```

**Esperado:** `"Status": "Enabled"`

### Teste 4 — Tags

```powershell
aws s3api get-bucket-tagging --bucket $RAW_BUCKET
aws s3api get-bucket-tagging --bucket $ATHENA_BUCKET
```

**Esperado:** tags `Project`, `Environment`, `ManagedBy` e `Name`.

### Teste 5 — Bloqueio de acesso público

```powershell
aws s3api get-public-access-block --bucket $RAW_BUCKET
```

**Esperado:** todos os campos `BlockPublic*` e `RestrictPublicBuckets` = `true`.

### Teste 6 — Upload no bucket raw

```powershell
"teste us-01" | Out-File -Encoding utf8 sample.txt
aws s3 cp sample.txt "s3://$RAW_BUCKET/test/sample.txt"
aws s3 ls "s3://$RAW_BUCKET/test/"
```

**Esperado:** arquivo listado em `test/`.

Limpeza:

```powershell
aws s3 rm "s3://$RAW_BUCKET/test/sample.txt"
Remove-Item sample.txt
```

### Teste 7 — Upload no bucket athena-results

```powershell
"query output" | Out-File -Encoding utf8 result.csv
aws s3 cp result.csv "s3://$ATHENA_BUCKET/athena-output/result.csv"
aws s3 ls "s3://$ATHENA_BUCKET/athena-output/"
```

**Esperado:** arquivo listado em `athena-output/`.

Limpeza:

```powershell
aws s3 rm "s3://$ATHENA_BUCKET/athena-output/result.csv"
Remove-Item result.csv
```

## Rollback

Para remover todos os recursos da US-01:

```powershell
terraform destroy -var-file="terraform.tfvars"
```

## Dependências para Sprint 2 (Glue Crawler)

- **Input:** `glue-b3-dev-s3-raw-303238378103`
- **Database:** `b3_raw`
- **Crawler:** `glue-b3-dev-glue-crawler-raw`
- **IAM Role:** `glue-b3-dev-iam-glue-crawler`
- **Log Group:** `/aws-glue/crawlers/glue-b3-crawler`
