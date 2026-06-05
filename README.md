# Pipeline B3 — Análise de Ações (Ibovespa)

Pipeline de dados na AWS para ingestão, catalogação e consulta SQL de cotações da B3: dados no **S3**, metadados no **Glue Data Catalog** e análises no **Athena**. Infraestrutura 100% **Terraform**; ingestão via **Python** (yfinance + boto3).

---

## Visão geral

1. **Terraform** provisiona buckets S3, Glue Database, IAM, Athena Workgroup e logs.
2. **Scripts Python** baixam OHLCV (yfinance), validam qualidade e enviam CSVs particionados ao S3.
3. **Glue Crawler** infere schema e partições Hive; **Athena** consulta a tabela em `b3_raw`.

Ambiente de referência: `dev` · região `us-east-1` · projeto `glue-b3`.

---

## O que este projeto resolve?

Este pipeline resolve **três problemas práticos** de quem trabalha com dados de ações da B3:

### 1. Acesso organizado aos dados

Hoje, para analisar PETR4, VALE3 ou ITUB4, é comum baixar CSV do Kaggle, abrir no Excel e trabalhar localmente — dado preso na máquina de uma pessoa, sem histórico padronizado e sem escala.

**Este projeto** coloca tudo no **S3** com estrutura Hive (`raw/ibovespa/ticker=.../`), acessível por qualquer ferramenta AWS, com ingestão via **yfinance** (ou Kaggle adaptado ao mesmo layout).

### 2. Catálogo automático de metadados

Sem o Glue Data Catalog, cada analista precisa saber onde estão os arquivos, qual o schema e quais colunas existem.

Com o **Glue Crawler**, o catálogo **descobre e registra o schema sozinho**. Athena, QuickSight e SageMaker enxergam a tabela **`b3_raw.ibovespa`** sem configuração manual de colunas.

### 3. Análise e previsão sem infraestrutura de banco de dados

Rodar SQL em histórico de ações sem este pipeline costuma exigir **RDS ou Redshift** — custo fixo mensal, servidor e operação.

Com **Athena**, você paga **só pelo volume escaneado**. Queries de MM7, MM30 e regressão linear rodam **sob demanda**, sem servidor dedicado e sem DBA.

| Camada | O que entrega |
|--------|----------------|
| S3 + scripts | Dados padronizados e validados (`validate_data.py`) |
| Glue Crawler | Tabela `ibovespa` com partição `ticker` |
| Athena | SQL analítico no workgroup `glue-b3-workgroup` |
| Terraform | Ambiente reproduzível por qualquer dev |

### O que um analista consegue fazer (com o projeto no ar)

- Consultar preço de fechamento de qualquer ticker do pipeline **desde 2018** em segundos (SQL no Athena)
- Avaliar se PETR4 está em tendência de alta ou baixa (**cruzamento MM7/MM30**)
- Obter projeção estatística simples de preço para os **próximos 7 ou 30 dias** (regressão linear)
- Exportar resultados em **CSV** direto do Athena para compartilhar com o time

### O que este projeto **não** resolve (limites importantes)

| Limite | Detalhe |
|--------|---------|
| **Não é sistema de trading** | Regressão e sinais são **ilustrativos** — não são recomendação de investimento |
| **Não é tempo real** | Atualização via script sob demanda (agendamento opcional no Crawler); não há feed ao vivo |
| **Não inclui dashboards** | Para gráficos, conecte **QuickSight** ou **Grafana** por cima do Athena/Glue |
| **Não é Data Mesh multi-domínio** | Escopo: Ibovespa/B3 neste repositório; múltiplos domínios = evolução futura (Projeto 4/5) |

### Query de validação no Athena

A consulta abaixo **não é a análise final** — ela prova que a cadeia **S3 → Glue → Athena** funciona:

```sql
SELECT ticker, date, close, volume
FROM b3_raw.ibovespa
WHERE ticker = 'PETR4'
ORDER BY date DESC
LIMIT 10;
```

| O que valida | Por quê |
|--------------|---------|
| Database `b3_raw` e tabela `ibovespa` | Crawler catalogou o prefixo S3 |
| Partição `ticker = 'PETR4'` | Layout Hive `ticker=PETR4/` está correto |
| Colunas `date`, `close`, `volume` | Schema inferido bate com os CSVs |
| 10 linhas recentes | Leitura ponta a ponta sem erro de metadados |

Use **database `b3_raw`** (não outro, ex.: `rh_db`) e workgroup **`glue-b3-workgroup`**. Se retornar dados, o pipeline está pronto para análises SQL mais avançadas.

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
| Glue Crawler | Glue | ✅ Terraform (US-12) · execução passo 9 |

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

O crawler é provisionado pelo Terraform (`glue.tf`, US-12) no passo 4. Após dados validados no S3, **inicie a catalogação**:

```powershell
$crawler = terraform output -raw glue_crawler_name

aws glue start-crawler --name $crawler
```

Verificar estado (aguarde **SUCCEEDED**):

```powershell
aws glue get-crawler --name $crawler --query "Crawler.{State:State,LastCrawl:LastCrawl}"
```

Tabela esperada: **`b3_raw.ibovespa`** (partição `ticker`).

> Se o crawler foi criado manualmente antes da US-12: `terraform import aws_glue_crawler.ibovespa glue-b3-dev-glue-crawler-raw`

**Monitoramento — logs de erro:**

```powershell
aws logs filter-log-events `
  --log-group-name "/aws-glue/crawlers/glue-b3-crawler" `
  --filter-pattern "ERROR"
```

Guia completo: [US-12 — Glue Crawler](docs/us-12-glue-crawler.md)

### 10. Queries no Athena

1. Console **Athena** → Workgroup **`glue-b3-workgroup`**
2. Data source: **AwsDataCatalog** · Database **`b3_raw`**
3. **Primeiro:** rode a [query de validação](#query-de-validação-no-athena) (10 linhas da PETR4).
4. Depois, análises de exemplo (ajuste o nome da tabela se o Crawler gerou outro):

```sql
-- Validação: 10 pregões mais recentes da PETR4 (prova fim a fim)
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
├── glue.tf                      # Glue DB, Crawler (US-12), CloudWatch Logs
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
| [US-12 Glue Crawler](docs/us-12-glue-crawler.md) | Catalogação Terraform |
| [Nomenclatura](docs/naming-convention.md) | Padrão de nomes AWS |
