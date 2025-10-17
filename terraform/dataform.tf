# -----------------------------------------------------------------------------
# Dataform Resources
# -----------------------------------------------------------------------------

# --- API Services ---
resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "dataform" {
  project            = var.project_id
  service            = "dataform.googleapis.com"
  disable_on_destroy = false
}

# --- Service Account for Dataform Runner ---
# DataformがBigQueryなどのGCPリソースにアクセスするためのサービスアカウント。
resource "google_service_account" "dataform" {
  account_id   = "dataform-runner"
  display_name = "Dataform Runner Service Account"
  project      = var.project_id
}

# サービスアカウントにBigQueryを操作するためのロールを付与
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

# --- Git Authentication Secret ---
resource "google_secret_manager_secret" "dataform_git_token" {
  provider  = google-beta.beta
  secret_id = "${var.dataform_repository_id}-git-token"
  replication {
    auto {}
  }
  depends_on = [
    google_project_service.secretmanager
  ]
}

resource "google_secret_manager_secret_version" "dataform_git_token_version" {
  provider    = google-beta.beta
  secret      = google_secret_manager_secret.dataform_git_token.id
  secret_data = "placeholder-replace-this-with-a-real-git-token"
}

# --- Dataform Repository and Configurations ---
# 1. Dataformリポジトリ (Gitリポジトリと連携)
resource "google_dataform_repository" "repository" {
  provider = google-beta.beta
  project  = var.project_id
  region   = var.region
  name     = var.dataform_repository_id

  git_remote_settings {
    url                               = "https://github.com/ENDoDo/kol-gcp-dataform.git"
    default_branch                    = "main"
    authentication_token_secret_version = "projects/56638639323/secrets/github-token/versions/latest"
  }
  depends_on = [
    google_project_iam_member.dataform_bigquery_data_editor,
    google_project_iam_member.dataform_bigquery_job_user,
    google_project_service.dataform,
  ]
}

# 2. リリース設定
resource "google_dataform_repository_release_config" "release_config" {
  provider = google-beta.beta
  project    = google_dataform_repository.repository.project
  region     = google_dataform_repository.repository.region
  repository = google_dataform_repository.repository.name
  name          = "production-release"
  git_commitish = "main"

  code_compilation_config {
    default_database = var.project_id
    default_schema   = var.dataform_output_schema # 変数を参照
    vars = {
      source_schema = "kol_keiba"
    }
  }
}

# 3. ワークフロー設定
resource "google_dataform_repository_workflow_config" "workflow" {
  provider = google-beta.beta
  project    = google_dataform_repository.repository.project
  region     = google_dataform_repository.repository.region
  repository = google_dataform_repository.repository.name
  name           = "daily-race-table-update"
  release_config = google_dataform_repository_release_config.release_config.id

  invocation_config {
    included_targets {
      database = var.project_id
      schema   = var.dataform_output_schema # 変数を参照
      name     = "race"
    }
    service_account = google_service_account.dataform.email
  }

  cron_schedule = "0 7 * * *"
  time_zone     = "Asia/Tokyo"
}

# Dataformサービスエージェントの権限設定に必要なプロジェクト情報を取得
data "google_project" "project" {}

# Dataformサービスエージェントに、カスタムSA(dataform-runner)として振る舞う権限を付与
resource "google_service_account_iam_member" "dataform_agent_impersonator" {
  provider           = google-beta.beta
  service_account_id = google_service_account.dataform.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

# --- Outputs ---
output "dataform_repository_url" {
  description = "URL of the created Dataform repository."
  value       = "https://console.cloud.google.com/bigquery/dataform/locations/${var.region}/repositories/${google_dataform_repository.repository.name}?project=${var.project_id}"
}