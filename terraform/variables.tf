# -----------------------------------------------------------------------------
# Input Variables
#
# このファイルは、Terraform構成で使用されるすべての入力変数を定義します。
# デフォルト値を設定することで、実行時に毎回指定する必要がなくなります。
# 環境ごとに設定を変更したい場合は、`.tfvars`ファイルを使用するのが一般的です。
# -----------------------------------------------------------------------------

# リソースを作成するGCPプロジェクトのID。
variable "project_id" {
  description = "The GCP project ID."
  type        = string
  default     = "smartkeiba"
}

# リソースをデプロイするGCPリージョン。
variable "region" {
  description = "The GCP region to deploy resources in."
  type        = string
  default     = "asia-northeast1"
}

# Dataformリポジトリの名前。
variable "dataform_repository_id" {
  description = "The ID of the Dataform repository."
  type        = string
  default     = "kol-dataform-repo"
}

# Dataformワークスペースの名前。
variable "dataform_workspace_id" {
  description = "The ID of the Dataform workspace."
  type        = string
  default     = "kol-dataform-ws"
}

# Dataformがテーブルを作成するBigQueryデータセット（スキーマ）。
variable "dataform_output_schema" {
  description = "The BigQuery schema (dataset) for Dataform to create tables in."
  type        = string
  # ▼▼▼ ここの値を "kol_analysis" に変更 ▼▼▼
  default     = "kol_analysis"
}