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
