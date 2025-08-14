locals {
  landing_bucket    = "${var.gcs_bucket_prefix}-landing-${var.project_id}"
  archive_bucket    = "${var.gcs_bucket_prefix}-archive-${var.project_id}"
  quarantine_bucket = "${var.gcs_bucket_prefix}-quarantine-${var.project_id}"

  raw_table_name = "sales-data"
}