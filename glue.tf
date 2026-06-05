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
