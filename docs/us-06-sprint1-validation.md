# US-06 — Validação Sprint 1 (Terraform CLI)

Checklist completo para garantir que toda a infraestrutura do Sprint 1 está corretamente provisionada.

## Recursos esperados (Sprint 1)

| US | Recurso | Nome esperado (dev) |
|----|---------|---------------------|
| US-01 | S3 raw | `glue-b3-dev-s3-raw-{account}` |
| US-01 | S3 athena-results | `glue-b3-dev-s3-athena-results-{account}` |
| US-02 | IAM Role Crawler | `glue-b3-dev-iam-glue-crawler` |
| US-02 | IAM Policy Athena | `glue-b3-dev-iam-athena-query` |
| US-02 | IAM Group Analysts | `glue-b3-dev-iam-grp-athena-analysts` |
| US-03 | Glue Database | `b3_raw` |
| US-04 | Athena Workgroup | `glue-b3-workgroup` |
| US-05 | CloudWatch Log Group | `/aws-glue/crawlers/glue-b3-crawler` |

---

## 1. Comandos de execução (ordem correta)

### Pré-requisitos

```powershell
aws sts get-caller-identity
# Confirme Account = aws_account_id no terraform.tfvars
```

### Ciclo completo (manual)

```powershell
cd c:\welligton-aws\project-glue-2

# 1. Inicializar providers
terraform init

# 2. Formatar código
terraform fmt -recursive

# 3. Validar sintaxe e referências
terraform validate

# 4. Gerar plano (recomendado: tfvars)
terraform plan -var-file="terraform.tfvars" -out=tfplan

# Alternativa com variável inline:
terraform plan `
  -var="project_name=glue-b3" `
  -var="aws_account_id=303238378103" `
  -out=tfplan

# 5. Aplicar plano salvo
terraform apply tfplan
```

### Script automatizado (recomendado)

**PowerShell (Windows):**

```powershell
# Apenas validar (plan + verify, sem apply)
.\scripts\validate-sprint1.ps1

# Ciclo completo com apply
.\scripts\validate-sprint1.ps1 -Apply

# Apenas verificar recursos já provisionados
.\scripts\validate-sprint1.ps1 -VerifyOnly
```

**Bash (Git Bash / Linux / CI):**

```bash
chmod +x scripts/validate-sprint1.sh
./scripts/validate-sprint1.sh
./scripts/validate-sprint1.sh --apply
./scripts/validate-sprint1.sh --verify-only
```

---

## 2. O que verificar após o apply

### 2.1 Terraform outputs (todos)

```powershell
terraform output
```

| Output | Valor esperado |
|--------|----------------|
| `name_prefix` | `glue-b3-dev` |
| `s3_bucket_raw_name` | `glue-b3-dev-s3-raw-303238378103` |
| `s3_bucket_athena_results_name` | `glue-b3-dev-s3-athena-results-303238378103` |
| `glue_database_name` | `b3_raw` |
| `athena_workgroup_name` | `glue-b3-workgroup` |
| `athena_output_location` | `s3://.../query-results/` |
| `glue_crawler_log_group_name` | `/aws-glue/crawlers/glue-b3-crawler` |
| `glue_crawler_role_name` | `glue-b3-dev-iam-glue-crawler` |
| `athena_analysts_group_name` | `glue-b3-dev-iam-grp-athena-analysts` |

### 2.2 Drift (state sincronizado)

```powershell
terraform plan -var-file="terraform.tfvars"
```

Esperado: **No changes. Your infrastructure matches the configuration.**

### 2.3 Console AWS

| Serviço | O que verificar |
|---------|-----------------|
| **S3** | 2 buckets com tags `Project`, `Environment`, `ManagedBy` |
| **IAM** | Role, policy, group e membro `usuario-dados` |
| **Glue** | Database `b3_raw` no Data Catalog |
| **Athena** | Workgroup `glue-b3-workgroup`, engine v3 |
| **CloudWatch** | Log group com retention 14 dias |

### 2.4 AWS CLI — confirmar cada recurso

```powershell
# Identidade
aws sts get-caller-identity

# US-01 — S3
aws s3 ls | Select-String "glue-b3-dev"
aws s3api get-bucket-versioning --bucket (terraform output -raw s3_bucket_raw_name)

# US-02 — IAM
aws iam get-role --role-name glue-b3-dev-iam-glue-crawler
aws iam get-group --group-name glue-b3-dev-iam-grp-athena-analysts
aws iam list-groups-for-user --user-name usuario-dados

# US-03 — Glue Database
aws glue get-database --name b3_raw

# US-04 — Athena Workgroup
aws athena get-work-group --work-group glue-b3-workgroup

# US-05 — CloudWatch
aws logs describe-log-groups --log-group-name-prefix "/aws-glue/crawlers/glue-b3-crawler"
```

### 2.5 Critérios de aceite Sprint 1

- [ ] `terraform validate` sem erros
- [ ] `terraform plan` sem changes (pós-apply)
- [ ] 2 buckets S3 existem
- [ ] Versionamento habilitado no raw
- [ ] IAM Role + Group + Policy existem
- [ ] Glue Database `b3_raw` existe
- [ ] Athena Workgroup engine v3 + SSE_S3
- [ ] Log group com retention 14 dias
- [ ] Todos os outputs preenchidos

---

## 3. Erros comuns e soluções

### Error: AccessDenied

**Mensagem típica:**

```
User: arn:aws:iam::303238378103:user/usuario-dados is not authorized
to perform: <acao> on resource: <arn>
```

**Causas:**

- Credenciais AWS expiradas ou perfil errado
- Usuário/role sem permissão para o serviço (ex.: `logs:CreateLogGroup`, `s3:CreateBucket`)
- Limite de 10 managed policies por usuário IAM

**Fix:**

```powershell
# 1. Confirmar sessão
aws sts get-caller-identity

# 2. Identificar ação negada na mensagem de erro

# 3. Opções:
#    a) Inline policy (nao conta no limite de 10 managed)
aws iam put-user-policy --user-name usuario-dados `
  --policy-name glue-b3-extra-perms `
  --policy-document file://policy.json

#    b) Adicionar ao grupo IAM existente via Terraform (athena_analyst_users)

#    c) Pedir ao admin a policy necessaria
```

---

### Error: BucketAlreadyExists

**Mensagem típica:**

```
Error creating S3 bucket: BucketAlreadyExists
```

**Causas:**

- Nome S3 já usado globalmente (outra conta ou projeto)
- `aws_account_id` incorreto no `terraform.tfvars`
- Bucket criado manualmente fora do Terraform

**Fix:**

```powershell
# 1. Confirmar conta
aws sts get-caller-identity --query Account --output text

# 2. Corrigir terraform.tfvars com Account correto

# 3. Se bucket existe na SUA conta mas fora do state:
terraform import 'aws_s3_bucket.this["raw"]' glue-b3-dev-s3-raw-303238378103

# 4. Se nome conflita globalmente, altere project_name no tfvars
```

---

### Error: InvalidClientTokenId

**Mensagem típica:**

```
The security token included in the request is invalid
```

**Causas:**

- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` inválidos ou expirados
- Sessão SSO expirada
- Credenciais de outra conta/região

**Fix:**

```powershell
# SSO
aws sso login --profile seu-perfil
$env:AWS_PROFILE = "seu-perfil"

# Access keys
aws configure
# ou renove as keys no console IAM

# Confirmar
aws sts get-caller-identity
```

---

### Outros erros frequentes

| Erro | Causa | Fix |
|------|-------|-----|
| `terraform.tfvars does not exist` | Arquivo local ausente | `Copy-Item terraform.tfvars.example terraform.tfvars` |
| `Error: creating CloudWatch Logs Log Group` AccessDenied | Sem `logs:CreateLogGroup` | Inline policy CloudWatch (ver US-05) |
| `PoliciesPerUser: 10` | Limite IAM | Use grupos ou inline policies |
| `EntityAlreadyExists` (IAM) | Recurso criado fora do TF | `terraform import` ou renomeie |

---

## 4. Rollback seguro

### Cenário A — Apply falhou no meio

Terraform faz rollback parcial automático: recursos criados antes do erro permanecem; o state reflete o que foi criado.

```powershell
# Ver o que está no state
terraform state list

# Reexecutar apply após corrigir a causa
terraform apply -var-file="terraform.tfvars"
```

### Cenário B — Reverter último apply bem-sucedido

```powershell
# Ver historico (state local — se usar backend remoto, habilite versioning no bucket)
# Restaurar backup se existir
Copy-Item terraform.tfstate.backup terraform.tfstate

terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Cenário C — Destruir tudo (ambiente dev)

```powershell
# ATENCAO: remove TODOS os recursos do Sprint 1
terraform destroy -var-file="terraform.tfvars"
```

Como `force_destroy = true` nos buckets S3, objetos também são removidos.

### Cenário D — Remover recurso específico do state (sem destruir na AWS)

```powershell
# Apenas desvincula do Terraform — recurso permanece na AWS
terraform state rm aws_cloudwatch_log_group.glue_crawler
```

Use apenas quando souber exatamente o que está fazendo.

### Boas práticas de rollback

1. Sempre use `terraform plan -out=tfplan` antes do apply
2. Guarde o output do plan em PRs/CI
3. Em dev, commit o `.terraform.lock.hcl` para reproducibilidade
4. Nunca edite `terraform.tfstate` manualmente
5. Para produção futura: backend S3 + DynamoDB lock + versioning

---

## 5. Resumo — fluxo recomendado

```
aws sts get-caller-identity
        ↓
terraform init → fmt → validate
        ↓
terraform plan -var-file=terraform.tfvars -out=tfplan
        ↓
terraform apply tfplan
        ↓
.\scripts\validate-sprint1.ps1 -VerifyOnly
        ↓
✅ Sprint 1 validado
```
