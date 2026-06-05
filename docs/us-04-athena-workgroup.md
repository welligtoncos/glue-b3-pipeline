# US-04 — Athena Workgroup

**Status:** ✅ Implementado

## Recurso

Arquivo: `athena.tf`

| Propriedade | Valor |
|-------------|-------|
| Nome | `{project_name}-workgroup` → `glue-b3-workgroup` |
| Output | `s3://...-athena-results-.../query-results/` |
| Criptografia | `SSE_S3` |
| Engine | Athena engine version 3 |
| CloudWatch metrics | habilitado |

## Por que `enforce_workgroup_configuration = true`?

Quando habilitado, **as configurações do workgroup têm prioridade** sobre as preferências individuais de cada usuário no console Athena.

| Com `enforce = false` | Com `enforce = true` |
|---------------------|----------------------|
| Analista pode mudar bucket de saída | Saída sempre no bucket do projeto |
| Pode desativar criptografia | SSE_S3 obrigatório |
| Pode usar engine antiga | Engine v3 garantida para todos |
| Custos imprevisíveis | Controle centralizado de custo e compliance |

No pipeline Ibovespa, isso garante que **toda query** use o bucket correto, criptografia e engine v3 — essencial para MM7/MM30 com window functions.

## Athena Engine v2 vs v3

| Aspecto | Engine v2 | Engine v3 |
|---------|-----------|-----------|
| Base | Presto 0.217 | Trino (muito mais recente) |
| Window functions | Limitadas | Completas (`ROWS BETWEEN`, MM7/MM30) |
| Performance | Baseline | Até 2x mais rápido em muitos casos |
| Tipos JSON | Básico | Funções JSON avançadas |
| Suporte | Legado | Recomendado para novos projetos |

Para análise de ações com médias móveis (MM7, MM30), a **v3 é obrigatória** — window functions como abaixo só funcionam corretamente na v3:

```sql
SELECT ticker,
       close_price,
       AVG(close_price) OVER (
         PARTITION BY ticker
         ORDER BY trade_date
         ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ) AS mm7
FROM b3_raw.stocks;
```

## Como verificar o custo antes de executar

Athena cobra por **dados escaneados** (~USD 5/TB). Três formas de estimar:

### 1. `EXPLAIN` (sem custo)

Mostra o plano de execução sem ler dados:

```sql
EXPLAIN SELECT * FROM b3_raw.stocks WHERE trade_date >= DATE '2024-01-01';
```

### 2. Query com `LIMIT 0` ou agregação leve (custo mínimo)

Testa sintaxe e schema com scan mínimo:

```sql
SELECT COUNT(*) FROM b3_raw.stocks LIMIT 1;
```

### 3. Particionamento + colunas específicas (melhor prática)

Reduza scan selecionando só colunas necessárias e filtrando partições:

```sql
-- Ruim: SELECT * em tabela grande
-- Bom:
SELECT ticker, close_price
FROM b3_raw.stocks
WHERE year = '2024' AND month = '01';
```

### Após executar — custo real

Console Athena → aba **Recent queries** → coluna **Data scanned**.

Via CLI:

```powershell
aws athena get-query-execution --query-execution-id <ID> `
  --query "QueryExecution.Statistics.DataScannedInBytes"
```

CloudWatch (com `publish_cloudwatch_metrics_enabled = true`):

- Namespace: `AWS/Athena`
- Métricas: `ProcessedBytes`, `EngineExecutionTime`, `TotalExecutionTime`

## Verificação

```powershell
terraform output athena_workgroup_name
terraform output athena_output_location

aws athena get-work-group --work-group glue-b3-workgroup
```

Saída esperada em `Configuration`:

- `EnforceWorkGroupConfiguration`: `true`
- `ResultConfiguration.OutputLocation`: `s3://glue-b3-dev-s3-athena-results-.../query-results/`
- `EncryptionConfiguration.EncryptionOption`: `SSE_S3`
- `EngineVersion.SelectedEngineVersion`: `Athena engine version 3`

## Critérios de aceite — US-04

- [x] Resource `aws_athena_workgroup` criado
- [x] Nome `{project_name}-workgroup`
- [x] `enforce_workgroup_configuration = true`
- [x] Output location no bucket athena-results
- [x] Criptografia SSE_S3
- [x] Engine version 3
- [x] CloudWatch metrics habilitado
