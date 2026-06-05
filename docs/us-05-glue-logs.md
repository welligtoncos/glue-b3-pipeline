# US-05 — CloudWatch Log Group (Glue Crawler)

**Status:** ✅ Implementado

## Recurso Terraform

Arquivo: `glue.tf`

```hcl
resource "aws_cloudwatch_log_group" "glue_crawler" {
  name              = "/aws-glue/crawlers/${var.project_name}-crawler"
  retention_in_days = 14
}
```

| Propriedade | Valor |
|-------------|-------|
| Log group | `/aws-glue/crawlers/glue-b3-crawler` |
| Retenção | 14 dias |
| Tags | `Project`, `Environment`, `ManagedBy`, `Name` |

A IAM Role do Crawler (`iam.tf`) já possui permissões de escrita neste log group.

## Como ver os logs após uma execução do Crawler

### Console AWS

1. Acesse **CloudWatch** → **Log groups**
2. Abra `/aws-glue/crawlers/glue-b3-crawler`
3. Selecione o **log stream** mais recente (nome inclui timestamp da execução)
4. Filtre por `ERROR` ou `WARN` se necessário

Atalho via Glue:

1. **AWS Glue** → **Crawlers** → selecione o crawler
2. Aba **Runs** → clique na execução
3. Link **View logs in CloudWatch**

### AWS CLI

Listar log streams:

```powershell
aws logs describe-log-streams `
  --log-group-name "/aws-glue/crawlers/glue-b3-crawler" `
  --order-by LastEventTime `
  --descending `
  --limit 5
```

Ler eventos do stream mais recente:

```powershell
$STREAM = aws logs describe-log-streams `
  --log-group-name "/aws-glue/crawlers/glue-b3-crawler" `
  --order-by LastEventTime --descending --limit 1 `
  --query "logStreams[0].logStreamName" --output text

aws logs get-log-events `
  --log-group-name "/aws-glue/crawlers/glue-b3-crawler" `
  --log-stream-name $STREAM `
  --limit 50
```

### Terraform

```powershell
terraform output glue_crawler_log_group_name
```

---

## Troubleshooting — erros comuns

### 1. Access Denied no S3

**Sintoma no log:**

```
User: arn:aws:sts::...:assumed-role/glue-b3-dev-iam-glue-crawler/GlueJobRunnerSession
is not authorized to perform: s3:ListBucket on resource: arn:aws:s3:::...
```

**Causas:**

- IAM Role do Crawler sem `s3:ListBucket` / `s3:GetObject` no bucket raw
- Bucket policy bloqueando a role
- Path S3 do crawler apontando para bucket/prefixo errado

**Como resolver:**

1. Confirme a role: `terraform output glue_crawler_role_arn`
2. Verifique inline policy `glue-b3-dev-glue-crawler-s3` em `iam.tf`
3. Teste acesso manual:

```powershell
aws s3 ls s3://glue-b3-dev-s3-raw-303238378103/ --profile <role-assumida>
```

4. Reaplique Terraform se policies estiverem desatualizadas

---

### 2. Schema incompatível

**Sintoma no log:**

```
Schema change detected and schema updates are not allowed
```

ou colunas/tipos inconsistentes entre arquivos no mesmo prefixo.

**Causas:**

- Arquivos CSV/JSON com headers diferentes no mesmo path
- Mudança de schema entre execuções com `SchemaChangePolicy` restritivo
- Mix de formatos (Parquet + CSV) no mesmo target

**Como resolver:**

1. Padronize arquivos no prefixo S3 (mesmo formato e colunas)
2. Separe fontes em prefixos distintos (`/stocks/csv/`, `/stocks/parquet/`)
3. Configure o crawler com:

```hcl
schema_change_policy {
  update_behavior = "UPDATE_IN_DATABASE"
  delete_behavior = "LOG"
}
```

4. Se necessário, delete a tabela no Catalog e reexecute o crawler

---

### 3. Crawler em estado FAILED

**Sintoma:**

- Console Glue → Runs → status **FAILED**
- Log termina com stack trace ou `Exception`

**Causas frequentes:**

| Causa | Indicador no log |
|-------|------------------|
| S3 vazio ou path inexistente | `No files found` / `Path does not exist` |
| Permissão IAM | `Access Denied` |
| Database não existe | `EntityNotFoundException: Database b3_raw not found` |
| Timeout | `Crawler timed out` |
| Formato ilegível | `Unable to classify` |

**Como resolver (checklist):**

```powershell
# 1. Database existe?
aws glue get-database --name b3_raw

# 2. Bucket tem dados?
aws s3 ls s3://glue-b3-dev-s3-raw-303238378103/ --recursive

# 3. Role do crawler OK?
aws iam get-role --role-name glue-b3-dev-iam-glue-crawler

# 4. Logs detalhados
aws logs filter-log-events `
  --log-group-name "/aws-glue/crawlers/glue-b3-crawler" `
  --filter-pattern "ERROR"
```

5. Corrija a causa raiz e **reexecute** o crawler manualmente no console ou via:

```powershell
aws glue start-crawler --name glue-b3-dev-glue-crawler-raw
```

---

## Critérios de aceite — US-05

- [x] Resource `aws_cloudwatch_log_group` criado
- [x] Nome `/aws-glue/crawlers/{project_name}-crawler`
- [x] Retention 14 dias
- [x] Tags padrão aplicadas
- [x] IAM Role alinhada ao log group

## Verificação

```powershell
aws logs describe-log-groups `
  --log-group-name-prefix "/aws-glue/crawlers/glue-b3-crawler"

terraform output glue_crawler_log_group_name
```

Saída esperada: `retentionInDays: 14`
