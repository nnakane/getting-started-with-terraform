variable "project_id" { type = string  default = "armagillo" }
variable "region"     { type = string  default = "asia-northeast1" }
variable "location"   { type = string  default = "asia-northeast1" } # BQ/DCのロケーション

variable "gcs_bucket_prefix" { type = string  default = "datalake" }

variable "cloud_run_image" {
  type        = string
  description = "Cloud Run のコンテナイメージ (Artifact Registry)"
  default     = "asia-northeast1-docker.pkg.dev/armagillo/ingestion/loader:latest" # ← 実イメージに合わせて
}

variable "raw_dataset" { type = string  default = "raw" }
variable "stg_dataset" { type = string  default = "stg" }
variable "cur_dataset" { type = string  default = "cur" }

variable "bq_location" { type = string  default = "asia-northeast1" }

# Looker 接続用サービスアカウント(任意)
#variable "looker_sa"   { type = string  default = null }