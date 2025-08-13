terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# =====================
# GCS: landing / archive / quarantine
# =====================
resource "google_storage_bucket" "landing" {
  name                        = local.landing_bucket
  location                    = var.region
  uniform_bucket_level_access = true
  versioning { enabled = true }
  lifecycle_rule {
    action { type = "SetStorageClass" storage_class = "NEARLINE" }
    condition { age = 30 }
  }
}

resource "google_storage_bucket" "archive" {
  name                        = local.archive_bucket
  location                    = var.region
  uniform_bucket_level_access = true
  lifecycle_rule {
    action { type = "SetStorageClass" storage_class = "COLDLINE" }
    condition { age = 90 }
  }
}

resource "google_storage_bucket" "quarantine" {
  name                        = local.quarantine_bucket
  location                    = var.region
  uniform_bucket_level_access = true
}

# =====================
# BigQuery: datasets
# =====================
resource "google_bigquery_dataset" "raw" {
  dataset_id                 = var.raw_dataset
  location                   = var.bq_location
  delete_contents_on_destroy = false
}

resource "google_bigquery_dataset" "stg" {
  dataset_id                 = var.stg_dataset
  location                   = var.bq_location
  delete_contents_on_destroy = false
}

resource "google_bigquery_dataset" "cur" {
  dataset_id                 = var.cur_dataset
  location                   = var.bq_location
  delete_contents_on_destroy = false
}

# =====================
# BigQuery: RAW テーブル（全カラム STRING + メタ列）
# =====================
resource "google_bigquery_table" "raw_sales" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = local.raw_table_name
  deletion_protection = false
  schema              = file("${path.module}/bigquery_schemas/raw_sales.json")

  time_partitioning {
    type  = "DAY"
    field = "_ingested_at" # 取り込み時刻でパーティション
  }

  clustering = ["_batch_id", "_source_file"]
}

# =====================
# Cloud Run (Gen2) サービス：GCS→BQ 取込
# =====================
resource "google_service_account" "ingestor" {
  account_id   = "ingestor-sa"
  display_name = "CSV ingestor for BigQuery RAW"
}

# 必要権限：BigQuery Job User / Data Editor、Storage Object Viewer
resource "google_project_iam_member" "ingestor_bqjob" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.ingestor.email}"
}
resource "google_project_iam_member" "ingestor_bqdata" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.ingestor.email}"
}
resource "google_project_iam_member" "ingestor_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.ingestor.email}"
}

resource "google_cloud_run_v2_service" "ingest" {
  name     = "csv-ingest"
  location = var.region

  template {
    service_account = google_service_account.ingestor.email
    containers {
      image = var.cloud_run_image
      env { name = "BQ_DATASET" value = google_bigquery_dataset.raw.dataset_id }
      env { name = "BQ_TABLE"   value = google_bigquery_table.raw_sales.table_id }
      env { name = "ARCHIVE_BUCKET" value = google_storage_bucket.archive.name }
    }
    scaling { max_instance_count = 3 }
  }
}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  name     = google_cloud_run_v2_service.ingest.name
  location = google_cloud_run_v2_service.ingest.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.ingestor.email}"
}

# =====================
# Eventarc: GCSオブジェクト作成で Cloud Run 起動（簡易）
# =====================
resource "google_eventarc_trigger" "gcs_to_run" {
  name     = "gcs-finalize-to-run"
  location = var.region

  transport { pubsub { topic = "gcs-finalize-topic" } }

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.landing.name
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.ingest.name
      region  = var.region
      path    = "/ingest" # コンテナ側のエンドポイント
    }
  }
}

# =====================
# Data Catalog: タグテンプレート & Policy Tags（列レベル権限）
# =====================
resource "google_data_catalog_tag_template" "tt_dataset_asset" {
  tag_template_id = "tt_dataset_asset"
  region          = var.location
  display_name    = "Dataset Asset"

  fields {
    field_id     = "owner_email"
    display_name = "Owner Email"
    type { primitive_type = "STRING" }
    is_required  = true
  }
  fields {
    field_id     = "sensitivity"
    display_name = "Sensitivity"
    type { enum_type { allowed_values { display_name = "Public" }
                       allowed_values { display_name = "Internal" }
                       allowed_values { display_name = "Confidential" }
                       allowed_values { display_name = "Restricted" } } }
    is_required  = true
  }
  fields {
    field_id     = "retention_days"
    display_name = "Retention (days)"
    type { primitive_type = "DOUBLE" }
  }
}

resource "google_data_catalog_taxonomy" "taxonomy_pii" {
  region       = var.location
  display_name = "PII Taxonomy"
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "pii_basic" {
  taxonomy     = google_data_catalog_taxonomy.taxonomy_pii.name
  display_name = "pii_basic"
}
resource "google_data_catalog_policy_tag" "pii_sensitive" {
  taxonomy     = google_data_catalog_taxonomy.taxonomy_pii.name
  display_name = "pii_sensitive"
}