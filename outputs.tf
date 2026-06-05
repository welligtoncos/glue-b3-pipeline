output "name_prefix" {
  description = "Prefixo padrao de nomenclatura: {project}-{environment}."
  value       = local.name_prefix
}

output "s3_bucket_raw_name" {
  description = "Nome do bucket S3 de dados brutos."
  value       = aws_s3_bucket.this["raw"].id
}

output "s3_bucket_athena_results_name" {
  description = "Nome do bucket S3 de resultados do Athena."
  value       = aws_s3_bucket.this["athena_results"].id
}

output "s3_bucket_raw_arn" {
  description = "ARN do bucket S3 de dados brutos."
  value       = aws_s3_bucket.this["raw"].arn
}

output "s3_bucket_athena_results_arn" {
  description = "ARN do bucket S3 de resultados do Athena."
  value       = aws_s3_bucket.this["athena_results"].arn
}

# Referencia para proximas US
output "naming_convention" {
  description = "Nomes reservados para recursos futuros."
  value = {
    glue_database    = local.glue_database_name
    glue_crawler     = local.glue_crawler_name
    athena_workgroup = local.athena_workgroup_name
    iam_glue_crawler = local.iam_role_glue_crawler
  }
}
