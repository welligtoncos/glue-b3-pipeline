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

output "glue_crawler_role_arn" {
  description = "ARN da IAM Role do Glue Crawler."
  value       = aws_iam_role.glue_crawler.arn
}

output "glue_crawler_role_name" {
  description = "Nome da IAM Role do Glue Crawler."
  value       = aws_iam_role.glue_crawler.name
}

output "athena_query_policy_arn" {
  description = "ARN da IAM Policy standalone para queries Athena."
  value       = aws_iam_policy.athena_query.arn
}

output "athena_query_policy_name" {
  description = "Nome da IAM Policy standalone para queries Athena."
  value       = aws_iam_policy.athena_query.name
}

output "athena_analysts_group_name" {
  description = "Nome do grupo IAM de analysts Athena."
  value       = aws_iam_group.athena_analysts.name
}

output "athena_analysts_group_arn" {
  description = "ARN do grupo IAM de analysts Athena."
  value       = aws_iam_group.athena_analysts.arn
}

output "athena_analyst_users" {
  description = "Usuarios membros do grupo de analysts Athena."
  value       = var.athena_analyst_users
}
