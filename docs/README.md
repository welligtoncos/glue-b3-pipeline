# Documentacao — Pipeline B3 (Ibovespa)

Indice da documentacao do projeto.

## Sprint 1 — Concluido

| US | Documento | Descricao |
|----|-----------|-----------|
| — | [Arquitetura](architecture.md) | Visao geral, componentes e fluxo |
| — | [Getting Started](getting-started.md) | Deploy, config e troubleshooting |
| — | [Convencao de Nomenclatura](naming-convention.md) | Padrao de nomes AWS |
| US-01 | [Buckets S3](us-01-s3-buckets.md) | Spec e testes S3 |
| US-03 | [Glue Database](us-03-glue-database.md) | Data Catalog `b3_raw` |
| US-04 | [Athena Workgroup](us-04-athena-workgroup.md) | Engine v3, custos, SSE_S3 |
| US-05 | [Glue Logs](us-05-glue-logs.md) | CloudWatch + troubleshooting |
| US-06 | [Validacao Sprint 1](us-06-sprint1-validation.md) | Checklist plan/apply/verify |

## Sprint 2 — Em progresso

| US | Documento | Status |
|----|-----------|--------|
| US-07 | [Download Ibovespa](us-07-download-ibovespa.md) | ✅ Concluida |
| US-08 | [Upload S3 particionado](us-08-upload-s3.md) | ✅ Concluida |
| US-09 | [Validacao dados S3](us-09-validate-data.md) | ✅ Concluida |

## Scripts

| Script | Plataforma | Uso |
|--------|------------|-----|
| `scripts/validate-sprint1.ps1` | Windows | `.\scripts\validate-sprint1.ps1 -VerifyOnly` |
| `scripts/validate-sprint1.sh` | Bash / CI | `./scripts/validate-sprint1.sh --verify-only` |
| `scripts/download_ibovespa.py` | Python | `python scripts/download_ibovespa.py --bucket <raw>` |
| `scripts/validate_data.py` | Python | `python scripts/validate_data.py --bucket <raw>` |

## Arquivos Terraform

| Arquivo | US | Recursos |
|---------|-----|----------|
| `main.tf` | US-01 | S3 buckets |
| `iam.tf` | US-02 | IAM Role, Policies, Group |
| `glue.tf` | US-03, US-05 | Glue Database, CloudWatch Log Group |
| `athena.tf` | US-04 | Athena Workgroup |
| `locals.tf` | — | Nomenclatura centralizada |
| `variables.tf` | — | Variaveis de entrada |
| `outputs.tf` | — | ARNs e nomes exportados |

## Sprint 2 — Pendente

- Glue Crawler (`glue-b3-dev-glue-crawler-raw`)
- Catalogacao automatica S3 → tabelas em `b3_raw`

## Links rapidos

- [README principal](../README.md)
- [terraform.tfvars.example](../terraform.tfvars.example)
