# Getting Started

Guia para configurar o ambiente e executar o Terraform neste projeto.

## Pré-requisitos

| Ferramenta | Versão mínima | Verificação |
|------------|---------------|-------------|
| Terraform | 1.5 | `terraform version` |
| AWS CLI | v2 | `aws --version` |
| Sessão AWS | ativa | `aws sts get-caller-identity` |

### Permissões IAM necessárias (US-01)

O usuário ou role precisa de permissões para:

- `s3:CreateBucket`, `s3:DeleteBucket`, `s3:PutBucket*`, `s3:GetBucket*`
- `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject` (testes manuais)
- Aplicar tags em recursos S3

## Autenticação AWS

Este projeto assume que você **já está logado** no terminal. Terraform e AWS CLI compartilham as mesmas credenciais da sessão ativa.

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

> Não é necessário executar `aws configure` se a sessão já estiver ativa.

## Configuração

### 1. Criar `terraform.tfvars`

Copie o template:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Ou gere automaticamente com a conta logada:

```powershell
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

@"
project_name   = "glue-b3"
aws_account_id = "$ACCOUNT_ID"
aws_region     = "us-east-1"
environment    = "dev"
"@ | Set-Content terraform.tfvars
```

### 2. Variáveis disponíveis

| Variável | Obrigatória | Default | Descrição |
|----------|-------------|---------|-----------|
| `project_name` | sim | — | Nome do projeto (lowercase, hífen) |
| `aws_account_id` | sim | — | ID da conta AWS (12 dígitos) |
| `aws_region` | não | `us-east-1` | Região de deploy |
| `environment` | não | `dev` | Tag de ambiente |

Validações em `variables.tf`:

- `project_name`: apenas `[a-z0-9-]`
- `aws_account_id`: exatamente 12 dígitos numéricos

## Deploy

```powershell
cd c:\welligton-aws\project-glue-2

terraform init
terraform plan  -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

Confirme com `yes` quando solicitado.

**Resultado esperado:**

```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

### Alternativa sem arquivo `.tfvars`

```powershell
terraform apply `
  -var="project_name=glue-b3" `
  -var="aws_account_id=$(aws sts get-caller-identity --query Account --output text)"
```

## Verificação pós-deploy

```powershell
terraform plan -var-file="terraform.tfvars"
```

Saída esperada: **No changes. Your infrastructure matches the configuration.**

Listar buckets:

```powershell
aws s3 ls | Select-String "glue-b3"
```

## Destruir infraestrutura (dev)

```powershell
terraform destroy -var-file="terraform.tfvars"
```

Como `force_destroy = true`, buckets com objetos também são removidos.

## Troubleshooting

### `terraform.tfvars does not exist`

O arquivo não é versionado. Crie a partir do example:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

### Bucket name already exists

Nomes S3 são globais. Se o bucket já existir em outra conta, altere `project_name` ou verifique se há conflito de nomenclatura.

### Access Denied

Verifique permissões IAM do usuário logado:

```powershell
aws sts get-caller-identity
aws s3 ls
```

### Drift detectado no `plan`

Se recursos foram alterados manualmente no console, o `plan` mostrará diferenças. Para reconciliar:

- Ajuste o código Terraform para refletir a mudança desejada, ou
- Reverta a alteração manual no console, ou
- Execute `terraform apply` para restaurar o estado declarado

## Arquivos gerados localmente (não versionar)

| Arquivo | Descrição |
|---------|-----------|
| `terraform.tfvars` | Valores específicos da sua conta |
| `terraform.tfstate` | State local do Terraform |
| `terraform.tfstate.backup` | Backup do state |
| `.terraform/` | Providers baixados |
