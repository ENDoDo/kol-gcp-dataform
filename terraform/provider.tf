# -----------------------------------------------------------------------------
# Terraform Provider Configuration
#
# このファイルは、TerraformがGoogle Cloud Platform (GCP) と通信するための
# プロバイダを定義・設定します。
#
# - `google`: GCPの安定版リソースを管理するためのメインプロバイダ。
# - `google-beta`: ベータ版の機能やリソース（例: Eventarc関連）を
#   利用するために必要なプロバイダ。
# -----------------------------------------------------------------------------

# Terraform自体の設定ブロック。
terraform {
  # この構成で使用するプロバイダとそのバージョン制約を定義します。
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.7" # 最新の安定バージョンに固定 (2024年6月時点)
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.7" # googleプロバイダとバージョンを合わせる
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2" # null_resourceを使用するために必要
    }
  }
}

# GCPの安定版リソースを管理するためのメインプロバイダ設定。
provider "google" {
  project = var.project_id
  region  = var.region
}

# GCPのベータ版リソースを管理するためのプロバイダ設定。
provider "google-beta" {
  alias   = "beta"
  project = var.project_id
  region  = var.region
}
