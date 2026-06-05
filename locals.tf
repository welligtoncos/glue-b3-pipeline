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
  glue_database_name    = "${local.name_prefix}-glue-db-catalog"
  glue_crawler_name     = "${local.name_prefix}-glue-crawler-raw"
  athena_workgroup_name = "${local.name_prefix}-athena-wg-primary"
  iam_role_glue_crawler = "${local.name_prefix}-iam-glue-crawler"
}
