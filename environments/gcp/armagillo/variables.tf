variable "project_id" {
  type    = string
  default = "armagillo"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "location" {
  type    = string
  default = "asia-northeast1" # BQ/DCのロケーション
}

variable "gcs_bucket_prefix" {
  type    = string
  default = "datalake"
}

variable "cloud_run_image" {
  type        = string
  description = "Cloud Run image"
  # 一時的に Cloud Run 公式サンプル
  default     = "us-docker.pkg.dev/cloudrun/container/hello:latest"
}

variable "raw_dataset" {
  type    = string
  default = "raw"
}

variable "stg_dataset" {
  type    = string
  default = "stg"
}

variable "cur_dataset" {
  type    = string
  default = "cur"
}

variable "bq_location" {
  type    = string
  default = "asia-northeast1"
}

variable "looker_sa" {
  type    = string
  default = null
}