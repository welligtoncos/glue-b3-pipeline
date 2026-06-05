# Pipeline B3 — Análise de Ações (Ibovespa)

Infraestrutura como código (Terraform) para um pipeline de dados na AWS, focado em ingestão, catalogação e consulta de dados de ações da B3.

## Stack

```
S3 (raw) → Glue Crawler → Glue Catalog → Athena
                ↓
         S3 (athena-results)
```

| Camada | Serviço | Status |
|--------|---------|--------|
| Armazenamento raw | Amazon S3 | ✅ US-01 |
| Armazenamento de queries | Amazon S3 | ✅ US-01 |
| Segurança (IAM) | Roles, Policies, Groups | ✅ US-02 |
| Glue Database | Glue Data Catalog (`b3_raw`) | ✅ US-03 |
| Consulta SQL | Amazon Athena Workgroup | ✅ US-04 |
| Observabilidade | CloudWatch Log Group (Glue) | ✅ US-05 |
| Glue Crawler | Catalogação automática S3 | 🔜 US-06 |

## Ambiente

| Item | Valor |
|------|-------|
| Região | `us-east-1` |
| Ambiente | `dev` |
| IaC | Terraform >= 1.5 |
| Provider | AWS ~> 5.0 |
| Conta AWS | `303238378103` |
| Projeto | `glue-b3` |
| Usuário IAM | `usuario-dados` |

## Início rápido

Pré-requisito: sessão AWS ativa no terminal (`aws sts get-caller-identity`).

```powershell
cd c:\welligton-aws\project-glue-2

# 1. Configurar variáveis
Copy-Item terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com sua conta e usuário IAM

# 2. Deploy
terraform init
terraform plan  -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# 3. Consultar recursos criados
terraform output
```

Gerar `terraform.tfvars` automaticamente:

```powershell
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$USER_NAME  = (aws sts get-caller-identity --query Arn --output text).Split("/")[-1]

@"
project_name   = "glue-b3"
aws_account_id = "$ACCOUNT_ID"
aws_region     = "us-east-1"
environment    = "dev"

athena_analyst_users = ["$USER_NAME"]
"@ | Set-Content terraform.tfvars
```

## Estrutura do repositório

```
.
├── main.tf                  # US-01: buckets S3
├── iam.tf                   # US-02: IAM Role, Policies e Group
├── glue.tf                  # US-03: Glue Database (Data Catalog)
├── athena.tf                # US-04: Athena Workgroup
├── locals.tf                # Padrão centralizado de nomenclatura
├── variables.tf             # Variáveis de entrada
├── outputs.tf               # Nomes, ARNs e referências
├── terraform.tfvars.example # Template de configuração
├── docs/
│   ├── architecture.md
│   ├── getting-started.md
│   ├── naming-convention.md
│   └── us-01-s3-buckets.md
└── README.md
```

## Variáveis

| Variável | Obrigatória | Default | Descrição |
|----------|-------------|---------|-----------|
| `project_name` | sim | — | Nome do projeto (`[a-z0-9-]`) |
| `aws_account_id` | sim | — | ID da conta AWS (12 dígitos) |
| `aws_region` | não | `us-east-1` | Região de deploy |
| `environment` | não | `dev` | Ambiente (`dev`, `stg`, `prod`) |
| `glue_db_name` | não | `b3_raw` | Nome do Glue Database no Data Catalog |
| `athena_analyst_users` | não | `[]` | Usuários no grupo Athena (least privilege) |

## Recursos provisionados

### US-01 — S3

Padrão: `{project}-{env}-s3-{purpose}-{account}`

| Recurso Terraform | Nome |
|-------------------|------|
| `aws_s3_bucket.this["raw"]` | `glue-b3-dev-s3-raw-303238378103` |
| `aws_s3_bucket.this["athena_results"]` | `glue-b3-dev-s3-athena-results-303238378103` |

### US-02 — IAM

Padrão: `{project}-{env}-iam-{purpose}`

| Recurso Terraform | Nome / Função |
|-------------------|---------------|
| `aws_iam_role.glue_crawler` | `glue-b3-dev-iam-glue-crawler` — role do Glue Crawler |
| `aws_iam_role_policy.glue_crawler_s3` | S3 List/Get/Put nos dois buckets |
| `aws_iam_role_policy.glue_crawler_logs` | CloudWatch Logs para crawlers |
| `aws_iam_policy.athena_query` | `glue-b3-dev-iam-athena-query` — policy standalone |
| `aws_iam_group.athena_analysts` | `glue-b3-dev-iam-grp-athena-analysts` — grupo de analysts |

### US-03 — Glue Database

| Recurso Terraform | Nome |
|-------------------|------|
| `aws_glue_catalog_database.this` | `b3_raw` |

### US-04 — Athena Workgroup

| Recurso Terraform | Nome / Config |
|-------------------|---------------|
| `aws_athena_workgroup.this` | `glue-b3-workgroup` |
| Output location | `s3://...-athena-results-.../query-results/` |
| Engine | Athena engine version 3 |
| Criptografia | SSE_S3 |

### US-05 — CloudWatch Log Group

| Recurso Terraform | Nome |
|-------------------|------|
| `aws_cloudwatch_log_group.glue_crawler` | `/aws-glue/crawlers/glue-b3-crawler` |

Retenção: **14 dias**. Guia: [US-05 — Glue Logs](docs/us-05-glue-logs.md)

Permissões do grupo Athena (least privilege):

- Athena: `StartQueryExecution`, `GetQueryExecution`, `GetQueryResults`, `StopQueryExecution`
- S3: `ListBucket`, `GetObject`, `PutObject` nos dois buckets
- Glue: `GetDatabase`, `GetTables`, `GetPartitions` no catálogo do projeto

## Outputs principais

```powershell
terraform output s3_bucket_raw_name           # bucket raw
terraform output glue_crawler_role_arn          # ARN da role do crawler
terraform output athena_query_policy_arn        # ARN da policy Athena
terraform output athena_analysts_group_name     # grupo de analysts
terraform output glue_database_name              # database b3_raw
terraform output athena_workgroup_name           # glue-b3-workgroup
terraform output athena_output_location        # path de saída das queries
terraform output naming_convention              # nomes reservados US-05
```

## Critérios de aceite

### US-01 — Buckets S3

- [x] Bucket raw criado
- [x] Bucket athena-results criado
- [x] Versionamento habilitado no bucket raw
- [x] Tags aplicadas (`Project`, `Environment`, `ManagedBy`)

### US-02 — IAM

- [x] Role Glue com `AWSGlueServiceRole`
- [x] Policy S3 read/write nos dois buckets
- [x] Policy Athena query (standalone + grupo)
- [x] Least privilege aplicado via grupo IAM

### US-03 — Glue Database

- [x] Database criado no Catalog
- [x] Nome: `b3_raw`
- [x] Description preenchida

### US-04 — Athena Workgroup

- [x] Workgroup criado
- [x] Output location configurado
- [x] Engine v3 selecionado
- [x] Encrypt SSE_S3

### US-05 — CloudWatch Log Group

- [x] Log group `/aws-glue/crawlers/glue-b3-crawler` criado
- [x] Retention 14 dias
- [x] Tags aplicadas

## Verificação rápida

```powershell
# Buckets
aws s3 ls | Select-String "glue-b3-dev"

# IAM Role do Crawler
aws iam get-role --role-name glue-b3-dev-iam-glue-crawler

# Grupo de analysts e membro
aws iam list-attached-group-policies --group-name glue-b3-dev-iam-grp-athena-analysts
aws iam list-groups-for-user --user-name usuario-dados

# Glue Database
aws glue get-database --name b3_raw
terraform output glue_database_name

# Athena Workgroup
aws athena get-work-group --work-group glue-b3-workgroup
terraform output athena_workgroup_name

# CloudWatch Log Group (Glue)
aws logs describe-log-groups --log-group-name-prefix "/aws-glue/crawlers/glue-b3-crawler"
terraform output glue_crawler_log_group_name

# Drift
terraform plan -var-file="terraform.tfvars"
```

## Nomenclatura

Padrão centralizado em `locals.tf`:

```
{project_name}-{environment}-{aws_service}-{purpose}[-{account_id}]
```

| US | Recurso | Nome |
|----|---------|------|
| US-03 | Glue Database | `b3_raw` |
| US-04 | Athena Workgroup | `glue-b3-workgroup` |
| US-05 | CloudWatch Log Group | `/aws-glue/crawlers/glue-b3-crawler` |
| US-06 | Glue Crawler | `glue-b3-dev-glue-crawler-raw` |

Detalhes: [Convenção de Nomenclatura](docs/naming-convention.md)

## Documentação

| Documento | Descrição |
|-----------|-----------|
| [Arquitetura](docs/architecture.md) | Visão geral do pipeline e fluxo de dados |
| [Getting Started](docs/getting-started.md) | Pré-requisitos, deploy e troubleshooting |
| [US-01 — Buckets S3](docs/us-01-s3-buckets.md) | Spec e testes dos buckets |
| [US-03 — Glue Database](docs/us-03-glue-database.md) | Data Catalog e database `b3_raw` |
| [US-04 — Athena Workgroup](docs/us-04-athena-workgroup.md) | Workgroup, engine v3 e custos |
| [Convenção de Nomenclatura](docs/naming-convention.md) | Padrão de nomes AWS |

## Destruir recursos (dev)

```powershell
terraform destroy -var-file="terraform.tfvars"
```

Buckets usam `force_destroy = true` — objetos são removidos junto.

## Próximas entregas

- **US-06** — Glue Crawler apontando para o bucket raw
