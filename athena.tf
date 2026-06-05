locals {
  athena_query_results_prefix = "query-results/"
  athena_output_location      = "s3://${aws_s3_bucket.this["athena_results"].id}/${local.athena_query_results_prefix}"
}

resource "aws_athena_workgroup" "this" {
  name = local.athena_workgroup_name

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = local.athena_output_location

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }

  tags = {
    Name = local.athena_workgroup_name
  }
}
