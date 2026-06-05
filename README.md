# Pipeline B3 — Análise de Ações (Ibovespa)

Pipeline de dados na AWS para ingestão, catalogação e consulta SQL de cotações da B3: dados no **S3**, metadados no **Glue Data Catalog** e análises no **Athena**. Infraestrutura 100% **Terraform**; ingestão via **Python** (yfinance + boto3).

---

## Visão geral

1. **Terraform** provisiona buckets S3, Glue Database, IAM, Athena Workgroup e logs.
2. **Scripts Python** baixam OHLCV (yfinance), validam qualidade e enviam CSVs particionados ao S3.
3. **Glue Crawler** infere schema e partições Hive; **Athena** consulta a tabela em `b3_raw`.

Ambiente de referência: `dev` · região `us-east-1` · projeto `glue-b3`.

---

## Arquitetura

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    INGESTÃO (local)                      │
                    │  yfinance ──► download_ibovespa.py ──► validate_data.py │
                    └────────────────────────────┬────────────────────────────┘
                                                 │ put_object (Hive)
                                                 ▼
┌──────────────┐    ┌──────────────────────────────────────┐    ┌─────────────────┐
│  Fonte B3    │    │  S3 Raw                               │    │  Glue Crawler   │
│  (yfinance   │───►│  raw/ibovespa/ticker=PETR4/PETR4.csv │───►│  (catalogação)  │
│   ou Kaggle) │    │  reports/validacao_*.csv              │    └────────┬────────┘
└──────────────┘    └──────────────────────────────────────┘             │
                                                 │                         ▼
                                                 │              ┌─────────────────┐
                                                 │              │ Glue Catalog    │
                                                 │              │ database: b3_raw│
                                                 │              └────────┬────────┘
                                                 │                       │
                                                 ▼                       ▼
                                    ┌────────────────────────────────────────┐
                                    │  Amazon Athena (glue-b3-workgroup)      │
                                    │  Engine v3 · resultados → S3 athena-*   │
                                    └────────────────────────────────────────┘
                                                 │
                                                 ▼
                                    ┌────────────────────────────────────────┐
                                    │  CloudWatch Logs                        │
                                    │  /aws-glue/crawlers/glue-b3-crawler     │
                                    └────────────────────────────────────────┘
```

| Etapa | Serviço | Status |
|-------|---------|--------|
| Infra base | S3, IAM, Glue DB, Athena, Logs | ✅ Terraform |
| Download + upload + validação | Python | ✅ US-07 a US-09 |
| Glue Crawler | Glue | ⚙️ Configuração manual (passo 8) |

Documentação detalhada por US: **[docs/README.md](docs/README.md)**

---

## Pré-requisitos

| Ferramenta | Versão | Verificação |
|------------|--------|-------------|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) | v2, perfil configurado | `aws sts get-caller-identity` |
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5 | `terraform version` |
| Python | 3.9+ | `python --version` |
| Git | qualquer recente | `git --version` |

**Permissões AWS:** o usuário precisa criar/gerenciar S3, IAM, Glue, Athena e CloudWatch Logs (deploy Terraform) e `s3:PutObject`/`s3:GetObject` no bucket raw (scripts Python).

**Fonte de dados:**

| Fonte | Uso no projeto |
|-------|----------------|
| **yfinance** (padrão) | `scripts/download_ibovespa.py` — sem conta externa |
| **Kaggle** (opcional) | Alternativa manual: baixe CSVs e adapte o upload para o mesmo layout Hive em `raw/ibovespa/` |

---

## Passo a passo — do zero ao Athena

### 1. Clonar o repositório

```powershell
git clone <url-do-repositorio> project-glue-2
cd project-glue-2
```

```bash
# Linux / macOS
git clone <url-do-repositorio> project-glue-2 && cd project-glue-2
```

### 2. Configurar credenciais AWS

```powershell
aws configure
aws sts get-caller-identity
```

Anote o `Account` (12 dígitos) e o nome do usuário IAM.

### 3. Criar `terraform.tfvars`

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars` ou gere automaticamente:

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

> `athena_analyst_users` adiciona seu usuário ao grupo IAM com permissão de query no Athena.

### 4. Provisionar infraestrutura (`terraform apply`)

```powershell
terraform init
terraform plan  -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

Validação opcional da infra (Sprint 1):

```powershell
.\scripts\validate-sprint1.ps1 -VerifyOnly
```

Outputs úteis:

```powershell
terraform output s3_bucket_raw_name
terraform output glue_database_name
terraform output athena_workgroup_name
terraform output glue_crawler_role_arn
```

### 5. Instalar dependências Python

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

### 6. Download dos dados (yfinance)

Baixa PETR4, VALE3, ITUB4 e BBDC4 desde 2018; remove linhas com `volume <= 0`; salva `data/local/ibovespa_stocks.csv`.

```powershell
python scripts/download_ibovespa.py
```

**Kaggle (opcional):** se usar datasets externos, normalize para as colunas `ticker,date,open,high,low,close,volume` e faça upload manual com a mesma estrutura Hive do passo 7.

### 7. Upload ao S3 (partição Hive)

```powershell
$bucket = terraform output -raw s3_bucket_raw_name
python scripts/download_ibovespa.py --bucket $bucket
```

Estrutura gerada:

```
s3://{bucket}/raw/ibovespa/
├── ticker=BBDC4/BBDC4.csv
├── ticker=ITUB4/ITUB4.csv
├── ticker=PETR4/PETR4.csv
└── ticker=VALE3/VALE3.csv
```

Conferir no S3:

```powershell
aws s3 ls "s3://$bucket/raw/ibovespa/" --recursive
```

### 8. Validar qualidade (antes do Crawler)

```powershell
python scripts/validate_data.py --bucket $bucket
```

Saída esperada: `geral=OK` e relatório em `s3://{bucket}/reports/validacao_{timestamp}.csv`.

Critérios: colunas corretas, `date` YYYY-MM-DD, `close > 0`, `volume > 0`, sem duplicatas `(ticker, date)`.

### 9. Executar o Glue Crawler

O Crawler **ainda não está no Terraform**; crie uma vez no console ou via CLI (role e database já existem).

**Console AWS:** Glue → Crawlers → Create crawler

| Campo | Valor |
|-------|-------|
| Name | `glue-b3-dev-glue-crawler-raw` |
| IAM Role | `glue-b3-dev-iam-glue-crawler` (output `glue_crawler_role_arn`) |
| Database | `b3_raw` |
| S3 path | `s3://<bucket-raw>/raw/ibovespa/` |
| Log group | `/aws-glue/crawlers/glue-b3-crawler` |

Execute o crawler e aguarde status **Succeeded**. A tabela costuma ser nomeada **`ibovespa`** (confira em Glue → Tables).

**CLI (alternativa):**

```powershell
$bucket = terraform output -raw s3_bucket_raw_name
$role   = terraform output -raw glue_crawler_role_arn

aws glue create-crawler `
  --name glue-b3-dev-glue-crawler-raw `
  --role $role `
  --database-name b3_raw `
  --targets "S3Targets=[{Path=s3://$bucket/raw/ibovespa/}]" `
  --schema-change-policy "UpdateBehavior=UPDATE_IN_DATABASE,DeleteBehavior=LOG"

aws glue start-crawler --name glue-b3-dev-glue-crawler-raw
aws glue get-crawler --name glue-b3-dev-glue-crawler-raw --query Crawler.LastCrawl.Status
```

Logs de erro:

```powershell
aws logs filter-log-events `
  --log-group-name "/aws-glue/crawlers/glue-b3-crawler" `
  --filter-pattern "ERROR"
```

### 10. Queries no Athena

1. Console **Athena** → Workgroup **`glue-b3-workgroup`**
2. Data source: **AwsDataCatalog** · Database **`b3_raw`**
3. Exemplos (ajuste o nome da tabela se o Crawler gerou outro):

```sql
-- Amostra por ticker (usa partição)
SELECT ticker, date, close, volume
FROM b3_raw.ibovespa
WHERE ticker = 'PETR4'
ORDER BY date DESC
LIMIT 10;

-- Contagem por ticker
SELECT ticker, COUNT(*) AS registros
FROM b3_raw.ibovespa
GROUP BY ticker
ORDER BY ticker;

-- Média móvel 7 dias (Engine v3)
SELECT
  ticker,
  date,
  close,
  AVG(close) OVER (
    PARTITION BY ticker
    ORDER BY date
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS mm7
FROM b3_raw.ibovespa
WHERE ticker = 'PETR4'
ORDER BY date;
```

**CLI:**

```powershell
aws athena start-query-execution `
  --query-string "SELECT ticker, COUNT(*) FROM b3_raw.ibovespa GROUP BY ticker" `
  --work-group glue-b3-workgroup `
  --query-execution-context Database=b3_raw
```

Resultados em: `s3://<bucket-athena-results>/query-results/` (output `terraform output athena_output_location`).

---

## Estrutura de pastas

```
project-glue-2/
├── main.tf                      # S3 buckets (raw + athena-results)
├── iam.tf                       # Role Crawler, policies, grupo Athena
├── glue.tf                      # Glue Database b3_raw + CloudWatch Logs
├── athena.tf                    # Workgroup glue-b3-workgroup
├── locals.tf                    # Nomenclatura centralizada
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example     # Modelo (copiar → terraform.tfvars)
├── requirements.txt             # yfinance, pandas, boto3
├── scripts/
│   ├── download_ibovespa.py     # Download yfinance + upload S3 (US-07/08)
│   ├── validate_data.py         # Validação CSVs no S3 (US-09)
│   ├── validate-sprint1.ps1       # Validação infra Windows
│   └── validate-sprint1.sh        # Validação infra Bash/CI
├── docs/                        # Guias por US e arquitetura
│   ├── README.md                # Índice da documentação
│   ├── architecture.md
│   ├── getting-started.md
│   └── us-*.md
└── data/local/                  # CSV local (gitignored)
```

---

## Troubleshooting

### 1. `AccessDenied` no Terraform ou no upload S3

**Sintoma:** `terraform apply` ou `download_ibovespa.py --bucket` falha com `AccessDenied`.

**Causas:** usuário sem permissão na conta; bucket em outra conta; política SCP restritiva.

**Solução:**

```powershell
aws sts get-caller-identity
# Confirme Account = aws_account_id em terraform.tfvars

aws s3 ls s3://$(terraform output -raw s3_bucket_raw_name)/
```

Garanta policies para S3, IAM, Glue, Athena e Logs. Para `logs:CreateLogGroup`, veja [US-05 — Glue Logs](docs/us-05-glue-logs.md).

---

### 2. Validação US-09 com `geral=FAIL`

**Sintoma:** `erros_close`, `erros_data` ou `erros_schema` > 0.

**Causas:** CSV desatualizado no S3; colunas erradas; `volume = 0` (yfinance); datas inválidas.

**Solução:**

```powershell
pip install -r requirements.txt
$bucket = terraform output -raw s3_bucket_raw_name
python scripts/download_ibovespa.py --bucket $bucket
python scripts/validate_data.py --bucket $bucket
```

O download remove automaticamente linhas com `volume <= 0`.

---

### 3. Glue Crawler `FAILED` ou tabela vazia no Athena

**Sintoma:** Crawler falha; `TABLE_NOT_FOUND`; query retorna 0 linhas.

**Causas:** path S3 errado; bucket sem dados; role IAM incorreta; validação pulada.

**Solução:**

```powershell
$bucket = terraform output -raw s3_bucket_raw_name

aws s3 ls "s3://$bucket/raw/ibovespa/" --recursive
aws glue get-database --name b3_raw
aws iam get-role --role-name glue-b3-dev-iam-glue-crawler

python scripts/validate_data.py --bucket $bucket

aws glue start-crawler --name glue-b3-dev-glue-crawler-raw
```

Consulte logs em `/aws-glue/crawlers/glue-b3-crawler`. Detalhes: [US-05 — Glue Logs](docs/us-05-glue-logs.md).

---

## Referência rápida

| Variável / output | Exemplo |
|-------------------|---------|
| Bucket raw | `glue-b3-dev-s3-raw-{account_id}` |
| Glue Database | `b3_raw` |
| Athena Workgroup | `glue-b3-workgroup` |
| Crawler (nome reservado) | `glue-b3-dev-glue-crawler-raw` |

## Destruir ambiente (dev)

```powershell
terraform destroy -var-file="terraform.tfvars"
```

> Buckets com `force_destroy = true` em dev são esvaziados na destruição.

---

## Documentação complementar

| Documento | Conteúdo |
|-----------|----------|
| [docs/README.md](docs/README.md) | Índice de todas as US |
| [Arquitetura](docs/architecture.md) | Componentes e fluxo |
| [US-07 Download](docs/us-07-download-ibovespa.md) | yfinance |
| [US-08 Upload S3](docs/us-08-upload-s3.md) | Partição Hive |
| [US-09 Validação](docs/us-09-validate-data.md) | Qualidade de dados |
| [Nomenclatura](docs/naming-convention.md) | Padrão de nomes AWS |
