locals {
  iam_athena_query_policy_name = "${local.name_prefix}-iam-athena-query"

  s3_bucket_arns = [
    aws_s3_bucket.this["raw"].arn,
    aws_s3_bucket.this["athena_results"].arn,
  ]

  s3_object_arns = [
    "${aws_s3_bucket.this["raw"].arn}/*",
    "${aws_s3_bucket.this["athena_results"].arn}/*",
  ]

  glue_catalog_arn  = "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:catalog"
  glue_database_arn = "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:database/${local.glue_database_name}"
  glue_table_arns = [
    "arn:aws:glue:${var.aws_region}:${var.aws_account_id}:table/${local.glue_database_name}/*",
  ]

  athena_workgroup_arn = "arn:aws:athena:${var.aws_region}:${var.aws_account_id}:workgroup/${local.athena_workgroup_name}"
}

# ---------------------------------------------------------------------------
# US-02 — IAM Role: Glue Crawler
# ---------------------------------------------------------------------------

resource "aws_iam_role" "glue_crawler" {
  name = local.iam_role_glue_crawler

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = local.iam_role_glue_crawler
  }
}

resource "aws_iam_role_policy_attachment" "glue_crawler_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_crawler_s3" {
  name = "${local.name_prefix}-glue-crawler-s3"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListProjectBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
        ]
        Resource = local.s3_bucket_arns
      },
      {
        Sid    = "ReadWriteProjectObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = local.s3_object_arns
      },
    ]
  })
}

resource "aws_iam_role_policy" "glue_crawler_logs" {
  name = "${local.name_prefix}-glue-crawler-logs"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CreateCrawlerLogGroup"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
        ]
        Resource = local.glue_crawler_log_group_arn
      },
      {
        Sid    = "WriteCrawlerLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = local.glue_crawler_log_group_stream_arn
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# US-02 — IAM Policy standalone: Athena query users
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "athena_query" {
  name        = local.iam_athena_query_policy_name
  description = "Least privilege para execucao de queries Athena no pipeline ${local.name_prefix}."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StartQueriesOnWorkgroup"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
        ]
        Resource = local.athena_workgroup_arn
      },
      {
        Sid    = "ManageQueryExecutions"
        Effect = "Allow"
        Action = [
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
        ]
        Resource = ["*"]
      },
      {
        Sid    = "ListProjectBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
        ]
        Resource = local.s3_bucket_arns
      },
      {
        Sid    = "ReadWriteQueryData"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = local.s3_object_arns
      },
      {
        Sid    = "ReadGlueCatalog"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartitions",
        ]
        Resource = concat(
          [local.glue_catalog_arn, local.glue_database_arn],
          local.glue_table_arns,
        )
      },
    ]
  })

  tags = {
    Name = local.iam_athena_query_policy_name
  }
}

# ---------------------------------------------------------------------------
# US-02 — IAM Group: Athena analysts (least privilege via grupo)
# ---------------------------------------------------------------------------

resource "aws_iam_group" "athena_analysts" {
  name = local.iam_group_athena_analysts

  path = "/${var.project_name}/"
}

resource "aws_iam_group_policy_attachment" "athena_analysts_query" {
  group      = aws_iam_group.athena_analysts.name
  policy_arn = aws_iam_policy.athena_query.arn
}

resource "aws_iam_user_group_membership" "athena_analysts" {
  for_each = toset(var.athena_analyst_users)

  user   = each.value
  groups = [aws_iam_group.athena_analysts.name]
}
