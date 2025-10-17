# -----------------------------------------------------------------------------
# Dataform Resources
#
# このファイルは、Dataformのリポジトリ、ワークスペース、および関連する
# IAM設定を定義します。
# -----------------------------------------------------------------------------

# DataformがBigQueryなどのGCPリソースにアクセスするためのサービスアカウント。
resource "google_service_account" "dataform" {
  account_id   = "dataform-runner"
  display_name = "Dataform Runner Service Account"
  project      = var.project_id
}

# サービスアカウントにDataformがBigQueryを操作するためのロールを付与します。
# - BigQuery データ編集者: テーブルやデータの読み書きを許可
# - BigQuery ジョブユーザー: クエリの実行を許可
resource "google_project_iam_member" "dataform_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.dataform.email}"
}

resource "google_project_iam_member" "dataform_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.dataform.email}"
}

# Dataformのコードを管理するリポジトリ。
# Gitリポジトリと連携してコードを管理するのが一般的ですが、
# ここではTerraformでリポジトリのみを作成します。
resource "google_dataform_repository" "repository" {
  provider = google-beta
  project  = var.project_id
  region   = var.region
  name     = var.dataform_repository_id
  # Dataformがオペレーションを実行する際に使用するサービスアカウントを指定
  service_account = google_service_account.dataform.email

  # 初回適用時にIAMの伝播を待つための依存関係
  depends_on = [
    google_project_iam_member.dataform_bigquery_data_editor,
    google_project_iam_member.dataform_bigquery_job_user,
  ]
}

# 開発用のワークスペース。
# 開発者はこのワークスペースを通じて、リポジトリ内のコードを編集・実行します。
resource "google_dataform_workspace" "workspace" {
  provider   = google-beta
  project    = var.project_id
  region     = var.region
  name       = var.dataform_workspace_id
  repository = google_dataform_repository.repository.name
}

# `terraform apply`後に、作成されたリポジトリとワークスペースのURLを出力します。
output "dataform_repository_url" {
  description = "URL of the created Dataform repository."
  value       = "https://console.cloud.google.com/dataform/locations/${var.region}/repositories/${google_dataform_repository.repository.name}?project=${var.project_id}"
}

output "dataform_workspace_url" {
  description = "URL of the created Dataform workspace."
  value       = "https://console.cloud.google.com/dataform/locations/${var.region}/repositories/${google_dataform_repository.repository.name}/workspaces/${google_dataform_workspace.workspace.name}?project=${var.project_id}"
}
