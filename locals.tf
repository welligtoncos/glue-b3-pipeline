locals {
  # Padrão: {project_name}-{environment}-{aws_service}-{purpose}[-{account_id}]
  # account_id apenas em recursos com nome global (S3)
  name_prefix   = "${var.project_name}-${var.environment}"
  global_suffix = var.aws_account_id

  # S3 — nomes físicos na AWS
  s3_bucket_names = {
    raw            = "${local.name_prefix}-s3-raw-${local.global_suffix}"
    athena_results = "${local.name_prefix}-s3-athena-results-${local.global_suffix}"
  }

  s3_buckets = {
    raw = {
      name       = local.s3_bucket_names.raw
      versioning = true
    }
    athena_results = {
      name       = local.s3_bucket_names.athena_results
      versioning = false
    }
  }

  # Reservado para US-02 e US-03
  # Glue Data Catalog — nome logico configuravel (ex.: b3_raw)
  glue_database_name      = var.glue_db_name
  glue_crawler_name       = "${local.name_prefix}-glue-crawler-raw"
  glue_crawler_s3_target  = "s3://${local.s3_bucket_names.raw}/raw/ibovespa/"
  glue_crawler_table_name = "ibovespa"
  glue_crawler_configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })
  glue_crawler_log_group_name       = "/aws-glue/crawlers/${var.project_name}-crawler"
  glue_crawler_log_group_arn        = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:${local.glue_crawler_log_group_name}"
  glue_crawler_log_group_stream_arn = "${local.glue_crawler_log_group_arn}:*"
  athena_workgroup_name             = "${var.project_name}-workgroup"
  iam_role_glue_crawler             = "${local.name_prefix}-iam-glue-crawler"
  iam_group_athena_analysts         = "${local.name_prefix}-iam-grp-athena-analysts"
}
