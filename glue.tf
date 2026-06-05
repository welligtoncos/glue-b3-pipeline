# ---------------------------------------------------------------------------
# US-03 — Glue Data Catalog: Database
# ---------------------------------------------------------------------------

resource "aws_glue_catalog_database" "this" {
  name        = var.glue_db_name
  description = "Dados brutos da B3 — Ibovespa stocks"

  tags = {
    Name = var.glue_db_name
  }
}

# ---------------------------------------------------------------------------
# US-05 — CloudWatch Log Group: Glue Crawler
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "glue_crawler" {
  name              = local.glue_crawler_log_group_name
  retention_in_days = 14

  tags = {
    Name = local.glue_crawler_log_group_name
  }
}

# ---------------------------------------------------------------------------
# US-12 — Glue Crawler: catalogacao S3 raw/ibovespa → tabela ibovespa
# ---------------------------------------------------------------------------

resource "aws_glue_crawler" "ibovespa" {
  name          = local.glue_crawler_name
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.this.name
  description   = "Cataloga CSVs Ibovespa particionados por ticker em ${local.glue_crawler_s3_target}"

  s3_target {
    path = local.glue_crawler_s3_target
  }

  configuration = local.glue_crawler_configuration

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  schedule = var.crawler_schedule

  tags = {
    Name = local.glue_crawler_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.glue_crawler_service,
    aws_iam_role_policy.glue_crawler_s3,
    aws_iam_role_policy.glue_crawler_logs,
    aws_cloudwatch_log_group.glue_crawler,
  ]
}
