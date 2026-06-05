# Getting Started

Guia para configurar o ambiente, executar o Terraform e validar o **Sprint 1** do pipeline B3.

## Status Sprint 1

| US | Entrega | Status |
|----|---------|--------|
| US-01 | Buckets S3 | ✅ |
| US-02 | IAM (Role, Policies, Group) | ✅ |
| US-03 | Glue Database `b3_raw` | ✅ |
| US-04 | Athena Workgroup | ✅ |
| US-05 | CloudWatch Log Group | ✅ |
| US-06 | Validação plan/apply/verify | ✅ |

## Pré-requisitos

| Ferramenta | Versão mínima | Verificação |
|------------|---------------|-------------|
| Terraform | 1.5 | `terraform version` |
| AWS CLI | v2 | `aws --version` |
| Sessão AWS | ativa | `aws sts get-caller-identity` |
| PowerShell | 5+ | Windows (script de validação) |

### Permissões IAM necessárias

O operador Terraform precisa de permissões para criar recursos nos serviços abaixo. Em dev, o usuário `usuario-dados` utiliza policies amplas + inline policies pontuais.

| Serviço | Ações principais |
|---------|------------------|
| S3 | `CreateBucket`, `PutBucket*`, `GetBucket*` |
| IAM | `CreateRole`, `CreatePolicy`, `CreateGroup`, `Attach*` |
| Glue | `CreateDatabase`, `GetDatabase` |
| Athena | `CreateWorkGroup`, `GetWorkGroup` |
| CloudWatch Logs | `CreateLogGroup`, `PutRetentionPolicy` |

> **Nota:** se `logs:CreateLogGroup` falhar, use inline policy no usuário (não conta no limite de 10 managed policies). Ver [US-05 — Glue Logs](us-05-glue-logs.md).

## Autenticação AWS

Este projeto assume que você **já está logado** no terminal.

```powershell
aws sts get-caller-identity
```

Saída esperada:

```json
{
    "Account": "303238378103",
    "Arn": "arn:aws:iam::303238378103:user/usuario-dados"
}
```

## Configuração

### Criar `terraform.tfvars`

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Ou gere automaticamente:

```powershell
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$USER_NAME  = (aws sts get-caller-identity --query Arn --output text).Split("/")[-1]

@"
project_name   = "glue-b3"
aws_account_id = "$ACCOUNT_ID"
aws_region     = "us-east-1"
environment    = "dev"

glue_db_name   = "b3_raw"

athena_analyst_users = ["$USER_NAME"]
"@ | Set-Content terraform.tfvars
```

### Variáveis

| Variável | Obrigatória | Default | Descrição |
|----------|-------------|---------|-----------|
| `project_name` | sim | — | Nome do projeto (`[a-z0-9-]`) |
| `aws_account_id` | sim | — | ID da conta AWS (12 dígitos) |
| `aws_region` | não | `us-east-1` | Região de deploy |
| `environment` | não | `dev` | Ambiente (`dev`, `stg`, `prod`) |
| `glue_db_name` | não | `b3_raw` | Glue Database no Data Catalog |
| `athena_analyst_users` | não | `[]` | Usuários no grupo Athena |

## Deploy — ciclo completo

Ordem recomendada (Sprint 1):

```powershell
cd c:\welligton-aws\project-glue-2

terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

Resultado esperado (primeiro deploy completo):

```
Apply complete! Resources: N added, 0 changed, 0 destroyed.
```

Re-deploys subsequentes:

```
No changes. Your infrastructure matches the configuration.
```

## Validação automatizada (US-06)

```powershell
# Verificar recursos já provisionados (recomendado)
.\scripts\validate-sprint1.ps1 -VerifyOnly

# Plan + validação (sem apply)
.\scripts\validate-sprint1.ps1

# Ciclo completo com apply
.\scripts\validate-sprint1.ps1 -Apply
```

Guia detalhado: [US-06 — Validação Sprint 1](us-06-sprint1-validation.md)

## Verificação manual pós-deploy

```powershell
terraform output

# S3
aws s3 ls | Select-String "glue-b3-dev"

# IAM
aws iam get-role --role-name glue-b3-dev-iam-glue-crawler
aws iam list-groups-for-user --user-name usuario-dados

# Glue
aws glue get-database --name b3_raw

# Athena
aws athena get-work-group --work-group glue-b3-workgroup

# CloudWatch
aws logs describe-log-groups --log-group-name-prefix "/aws-glue/crawlers/glue-b3-crawler"

# Drift
terraform plan -var-file="terraform.tfvars"
```

## Destruir infraestrutura (dev)

```powershell
terraform destroy -var-file="terraform.tfvars"
```

Buckets usam `force_destroy = true` — objetos também são removidos.

## Troubleshooting

| Problema | Solução |
|----------|---------|
| `terraform.tfvars does not exist` | `Copy-Item terraform.tfvars.example terraform.tfvars` |
| `AccessDenied` | Verificar sessão AWS e permissões IAM (ver [US-06](us-06-sprint1-validation.md)) |
| `BucketAlreadyExists` | Corrigir `aws_account_id` ou `terraform import` |
| `InvalidClientTokenId` | Renovar credenciais / `aws sso login` |
| `logs:CreateLogGroup` negado | Inline policy CloudWatch (ver [US-05](us-05-glue-logs.md)) |
| `PoliciesPerUser: 10` | Usar grupos IAM ou inline policies |
| Drift no `plan` | `terraform apply` para reconciliar ou reverter alteração manual |

## Arquivos locais (não versionar)

| Arquivo | Descrição |
|---------|-----------|
| `terraform.tfvars` | Valores da sua conta |
| `terraform.tfstate` | State local |
| `tfplan` | Plano de execução salvo |
| `.terraform/` | Providers baixados |

## Próximo passo — Sprint 2

- **Glue Crawler** — catalogação automática do bucket raw → tabelas em `b3_raw`
