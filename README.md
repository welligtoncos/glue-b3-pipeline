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
| Catalogação | AWS Glue Crawler + Catalog | 🔜 US-02 |
| Consulta SQL | Amazon Athena | 🔜 US-03 |

## Ambiente

| Item | Valor |
|------|-------|
| Região | `us-east-1` |
| Ambiente | `dev` |
| IaC | Terraform >= 1.5 |
| Provider | AWS ~> 5.0 |
| Conta AWS | `303238378103` |
| Projeto | `glue-b3` |

## Início rápido

```powershell
cd c:\welligton-aws\project-glue-2

# Confirme a sessão AWS
aws sts get-caller-identity

# Deploy
terraform init
terraform apply -var-file="terraform.tfvars"
```

Copie `terraform.tfvars.example` para `terraform.tfvars` e ajuste se necessário.

## Documentação

| Documento | Descrição |
|-----------|-----------|
| [Arquitetura](docs/architecture.md) | Visão geral do pipeline, recursos e fluxo de dados |
| [Getting Started](docs/getting-started.md) | Pré-requisitos, configuração e deploy |
| [US-01 — Buckets S3](docs/us-01-s3-buckets.md) | Especificação, recursos e testes da primeira entrega |
| [Convenção de Nomenclatura](docs/naming-convention.md) | Padrão de nomes para todos os serviços AWS |

## Estrutura do repositório

```
.
├── main.tf                  # Recursos Terraform (US-01: S3)
├── locals.tf                # Padrao centralizado de nomenclatura
├── variables.tf             # Variaveis de entrada
├── outputs.tf               # Nomes e ARNs dos recursos
├── terraform.tfvars.example # Template de configuracao
├── docs/
│   ├── architecture.md
│   ├── getting-started.md
│   ├── naming-convention.md
│   └── us-01-s3-buckets.md
└── README.md
```

## Recursos provisionados (US-01)

Padrão: `{project}-{env}-s3-{purpose}-{account}`

| Recurso Terraform | Bucket |
|-------------------|--------|
| `aws_s3_bucket.this["raw"]` | `glue-b3-dev-s3-raw-303238378103` |
| `aws_s3_bucket.this["athena_results"]` | `glue-b3-dev-s3-athena-results-303238378103` |

## Critérios de aceite — US-01

- [x] Bucket raw criado
- [x] Bucket athena-results criado
- [x] Versionamento habilitado no bucket raw
- [x] Tags aplicadas (`Project`, `Environment`, `ManagedBy`)

## Próximas entregas

- **US-02** — Glue Database + Crawler apontando para o bucket raw
- **US-03** — Athena Workgroup com saída no bucket athena-results
