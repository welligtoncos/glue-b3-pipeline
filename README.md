# Pipeline B3 — Analise de Acoes (Ibovespa)

Infraestrutura como codigo (Terraform) para um pipeline de dados na AWS, focado em ingestao, catalogacao e consulta de dados de acoes da B3.

## Stack

```
S3 (raw) → Glue Crawler → Glue Catalog (b3_raw) → Athena
                ↓                                      ↓
         CloudWatch Logs                    S3 (athena-results)
```

| Camada | Servico | Status |
|--------|---------|--------|
| Armazenamento raw | Amazon S3 | ✅ US-01 |
| Armazenamento de queries | Amazon S3 | ✅ US-01 |
| Seguranca (IAM) | Roles, Policies, Groups | ✅ US-02 |
| Glue Database | Glue Data Catalog (`b3_raw`) | ✅ US-03 |
| Consulta SQL | Amazon Athena Workgroup | ✅ US-04 |
| Observabilidade | CloudWatch Log Group | ✅ US-05 |
| Validacao Sprint 1 | Terraform plan/apply/verify | ✅ US-06 |
| Ingestao local | Download Ibovespa (yfinance) | ✅ US-07 |
| Glue Crawler | Catalogacao automatica S3 | 🔜 Sprint 2 |

## Ambiente

| Item | Valor |
|------|-------|
| Regiao | `us-east-1` |
| Ambiente | `dev` |
| IaC | Terraform >= 1.5 |
| Provider | AWS ~> 5.0 |
| Conta AWS | `303238378103` |
| Projeto | `glue-b3` |

## Inicio rapido

```powershell
cd c:\welligton-aws\project-glue-2

# 1. Configurar
Copy-Item terraform.tfvars.example terraform.tfvars

# 2. Deploy
terraform init
terraform plan  -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan

# 3. Validar Sprint 1
.\scripts\validate-sprint1.ps1 -VerifyOnly
```

## Estrutura do repositorio

```
.
├── main.tf                  # US-01: S3
├── iam.tf                   # US-02: IAM
├── glue.tf                  # US-03 + US-05: Glue DB + CloudWatch
├── athena.tf                # US-04: Athena Workgroup
├── locals.tf                # Nomenclatura centralizada
├── variables.tf             # Variaveis
├── outputs.tf               # Outputs
├── scripts/
│   ├── validate-sprint1.ps1 # Validacao Windows
│   ├── validate-sprint1.sh  # Validacao Bash/CI
│   └── download_ibovespa.py # US-07: download yfinance
├── requirements.txt         # Dependencias Python
```

## Recursos provisionados

| US | Recurso Terraform | Nome |
|----|-------------------|------|
| US-01 | `aws_s3_bucket.this["raw"]` | `glue-b3-dev-s3-raw-303238378103` |
| US-01 | `aws_s3_bucket.this["athena_results"]` | `glue-b3-dev-s3-athena-results-303238378103` |
| US-02 | `aws_iam_role.glue_crawler` | `glue-b3-dev-iam-glue-crawler` |
| US-02 | `aws_iam_group.athena_analysts` | `glue-b3-dev-iam-grp-athena-analysts` |
| US-03 | `aws_glue_catalog_database.this` | `b3_raw` |
| US-04 | `aws_athena_workgroup.this` | `glue-b3-workgroup` |
| US-05 | `aws_cloudwatch_log_group.glue_crawler` | `/aws-glue/crawlers/glue-b3-crawler` |

## Variaveis

| Variavel | Default | Descricao |
|----------|---------|-----------|
| `project_name` | — | Nome do projeto |
| `aws_account_id` | — | ID da conta AWS |
| `aws_region` | `us-east-1` | Regiao |
| `environment` | `dev` | Ambiente |
| `glue_db_name` | `b3_raw` | Glue Database |
| `athena_analyst_users` | `[]` | Usuarios no grupo Athena |

## Outputs principais

```powershell
terraform output s3_bucket_raw_name
terraform output glue_database_name
terraform output athena_workgroup_name
terraform output glue_crawler_log_group_name
terraform output glue_crawler_role_arn
```

## Criterios de aceite — Sprint 1

- [x] **US-01** — Buckets S3 + versionamento + tags
- [x] **US-02** — IAM Role + Policy + Group (least privilege)
- [x] **US-03** — Glue Database `b3_raw`
- [x] **US-04** — Athena Workgroup engine v3 + SSE_S3
- [x] **US-05** — CloudWatch Log Group (14 dias)
- [x] **US-06** — Validacao plan/apply/verify OK

## Criterios de aceite — Sprint 2

- [x] **US-07** — Script `download_ibovespa.py` funcional
- [x] Tickers: PETR4, VALE3, ITUB4, BBDC4
- [x] Colunas: ticker, date, open, high, low, close, volume
- [x] Periodo >= 2018

## Validacao

```powershell
.\scripts\validate-sprint1.ps1 -VerifyOnly
```

## Documentacao

Indice completo: **[docs/README.md](docs/README.md)**

| Documento | Descricao |
|-----------|-----------|
| [Arquitetura](docs/architecture.md) | Componentes e fluxo de dados |
| [Getting Started](docs/getting-started.md) | Deploy e troubleshooting |
| [US-06 — Validacao](docs/us-06-sprint1-validation.md) | Checklist completo Sprint 1 |
| [US-07 — Download Ibovespa](docs/us-07-download-ibovespa.md) | yfinance → CSV local |
| [Convencao de Nomenclatura](docs/naming-convention.md) | Padrao de nomes |

## Destruir (dev)

```powershell
terraform destroy -var-file="terraform.tfvars"
```

## Proximo passo — Sprint 2

- Upload CSV para S3 raw (`stocks/`)
- **Glue Crawler** — catalogacao automatica → tabelas em `b3_raw`

### Download dados Ibovespa (US-07)

```powershell
pip install -r requirements.txt
python scripts/download_ibovespa.py
```

Guia: [US-07 — Download Ibovespa](docs/us-07-download-ibovespa.md)
