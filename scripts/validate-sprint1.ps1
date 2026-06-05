# US-06 — Validação Sprint 1 (Terraform + AWS CLI)
# Uso:
#   .\scripts\validate-sprint1.ps1                 # plan + verify (sem apply)
#   .\scripts\validate-sprint1.ps1 -Apply          # init → plan → apply → verify
#   .\scripts\validate-sprint1.ps1 -VerifyOnly     # apenas verificação AWS/outputs

param(
    [switch]$Apply,
    [switch]$VerifyOnly,
    [string]$TfVars = "terraform.tfvars",
    [string]$PlanFile = "tfplan"
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir

function Write-Pass { param([string]$Message) Write-Host "[PASS] $Message" -ForegroundColor Green }
function Write-Fail { param([string]$Message) Write-Host "[FAIL] $Message" -ForegroundColor Red; exit 1 }
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }

function Assert-Equal {
    param([string]$Label, [string]$Expected, [string]$Actual)
    if ($Actual -eq $Expected) { Write-Pass $Label }
    else { Write-Fail "${Label} - esperado: '${Expected}', obtido: '${Actual}'" }
}

foreach ($cmd in @("terraform", "aws")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Fail "Comando obrigatorio nao encontrado: $cmd"
    }
}

if (-not (Test-Path $TfVars)) {
    Write-Fail "Arquivo ${TfVars} nao encontrado. Copie terraform.tfvars.example"
}

Write-Info "Conta AWS logada:"
aws sts get-caller-identity | Out-Host

if (-not $VerifyOnly) {
    Write-Info "=== 1. terraform init ==="
    terraform init -input=false

    Write-Info "=== 2. terraform fmt ==="
    terraform fmt -recursive
    terraform fmt -recursive -check -diff
    if ($LASTEXITCODE -ne 0) { Write-Fail "terraform fmt encontrou arquivos fora do padrao" }

    Write-Info "=== 3. terraform validate ==="
    terraform validate
    if ($LASTEXITCODE -ne 0) { Write-Fail "terraform validate falhou" }

    if (-not (Test-Path $TfVars)) {
        Write-Fail "Arquivo ${TfVars} nao encontrado. Copie terraform.tfvars.example"
    }

    Write-Info "=== 4. terraform plan ==="
    terraform plan "-var-file=$TfVars" -out=$PlanFile -input=false
    if ($LASTEXITCODE -ne 0) { Write-Fail "terraform plan falhou" }

    if ($Apply) {
        Write-Info "=== 5. terraform apply ==="
        terraform apply -input=false $PlanFile
        if ($LASTEXITCODE -ne 0) { Write-Fail "terraform apply falhou" }
    }
    else {
        Write-Info "Apply ignorado (use -Apply para executar). Plano salvo em $PlanFile"
    }
}

Write-Info "=== 6. terraform output ==="
terraform output

Write-Info "=== 7. Verificacao AWS CLI ==="

$RawBucket       = terraform output -raw s3_bucket_raw_name
$ResultsBucket   = terraform output -raw s3_bucket_athena_results_name
$GlueDb          = terraform output -raw glue_database_name
$Workgroup       = terraform output -raw athena_workgroup_name
$LogGroup        = terraform output -raw glue_crawler_log_group_name
$CrawlerRole     = terraform output -raw glue_crawler_role_name
$AnalystsGroup   = terraform output -raw athena_analysts_group_name

# S3 raw
aws s3api head-bucket --bucket $RawBucket 2>$null
if ($LASTEXITCODE -eq 0) { Write-Pass "S3 raw bucket existe: $RawBucket" }
else { Write-Fail "S3 raw bucket ausente: $RawBucket" }

$Versioning = aws s3api get-bucket-versioning --bucket $RawBucket --query Status --output text
if ($Versioning -eq "Enabled") { Write-Pass "S3 raw versionamento Enabled" }
else { Write-Fail "S3 raw versionamento nao habilitado" }

# S3 athena results
aws s3api head-bucket --bucket $ResultsBucket 2>$null
if ($LASTEXITCODE -eq 0) { Write-Pass "S3 athena-results existe: $ResultsBucket" }
else { Write-Fail "S3 athena-results ausente: $ResultsBucket" }

# Glue Database
$DbName = aws glue get-database --name $GlueDb --query Database.Name --output text
Assert-Equal "Glue Database" $GlueDb $DbName

# Athena Workgroup
$WgName = aws athena get-work-group --work-group $Workgroup --query WorkGroup.Name --output text
Assert-Equal "Athena Workgroup" $Workgroup $WgName
$WgEngine = aws athena get-work-group --work-group $Workgroup --query "WorkGroup.Configuration.EngineVersion.SelectedEngineVersion" --output text
Assert-Equal "Athena Engine" "Athena engine version 3" $WgEngine

# CloudWatch Log Group
$LogGroupsJson = aws logs describe-log-groups --log-group-name-prefix $LogGroup --output json | ConvertFrom-Json
$Retention = ($LogGroupsJson.logGroups | Where-Object { $_.logGroupName -eq $LogGroup }).retentionInDays
Assert-Equal "Log Group retention (dias)" "14" $Retention

# IAM
aws iam get-role --role-name $CrawlerRole 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { Write-Pass "IAM Role Crawler: $CrawlerRole" }
else { Write-Fail "IAM Role Crawler ausente: $CrawlerRole" }

aws iam get-group --group-name $AnalystsGroup 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { Write-Pass "IAM Group Analysts: $AnalystsGroup" }
else { Write-Fail "IAM Group Analysts ausente: $AnalystsGroup" }

# Drift
Write-Info "=== 8. Drift check (terraform plan) ==="
terraform plan "-var-file=$TfVars" -detailed-exitcode -input=false | Out-Null
$PlanExit = $LASTEXITCODE
if ($PlanExit -eq 0) { Write-Pass "Nenhum drift detectado" }
elseif ($PlanExit -eq 2) { Write-Fail "Drift detectado - execute terraform plan para detalhes" }
else { Write-Fail "terraform plan falhou (exit $PlanExit)" }

Write-Info "=== Validacao Sprint 1 concluida com sucesso ==="
