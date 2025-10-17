# -----------------------------------------------------------------------------
# Dataform Resources
#
# このファイルは、Dataformのリポジトリ、ワークスペース、および関連する
# IAM設定を定義します。
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# API Services
#
# Dataform関連リソースを作成する前に、必要なGCP APIを有効化します。
# -----------------------------------------------------------------------------
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

# 2. DataformがGitリポジトリにアクセスするための認証トークンを保管するSecret
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

# Secretにダミーの値を設定 (実際には手動でPersonal Access Tokenを設定する必要がある)
resource "google_secret_manager_secret_version" "dataform_git_token_version" {
  provider = google-beta.beta
  secret   = google_secret_manager_secret.dataform_git_token.id

  # NOTE: apply後、このSecretの値をGCPコンソールから手動で
  #       GitリポジトリのPersonal Access Tokenに更新してください。
  secret_data = "placeholder-replace-this-with-a-real-git-token"
}

# 3. Dataformリポジトリ (Gitリポジトリと連携)
resource "google_dataform_repository" "repository" {
  provider = google-beta.beta
  project  = var.project_id
  region   = var.region
  name     = var.dataform_repository_id

  # Gitリポジトリとの連携設定
  git_remote_settings {
    # ▼▼▼ ここをGitHubリポジトリのURLに書き換える ▼▼▼
    url                               = "https://github.com/ENDoDo/kol-gcp-dataform.git" # あなたのGitHubリポジトリのURL
    default_branch                    = "main"
    authentication_token_secret_version = "projects/56638639323/secrets/github-token/versions/latest"
  }

  depends_on = [
    google_project_iam_member.dataform_bigquery_data_editor,
    google_project_iam_member.dataform_bigquery_job_user,
    google_project_service.dataform,
  ]
}

# 4. リリース設定 (どのブランチを本番とするか)
resource "google_dataform_repository_release_config" "release_config" {
  provider = google-beta.beta

  project    = google_dataform_repository.repository.project
  region     = google_dataform_repository.repository.region
  repository = google_dataform_repository.repository.name

  name          = "production-release"
  git_commitish = "main" # mainブランチを対象とする

  # コンパイル時の設定 (dataform.jsonの内容をここで上書き・設定)
  code_compilation_config {
    default_database = var.project_id
    default_schema   = var.dataform_output_schema
    vars = {
      source_schema = "kol_keiba" # dataform.jsonのvarsと同じ値を設定
    }
  }
}

# 5. ワークフロー設定 (いつ、何を、どのように実行するか)
resource "google_dataform_repository_workflow_config" "workflow" {
  provider = google-beta.beta

  project    = google_dataform_repository.repository.project
  region     = google_dataform_repository.repository.region
  repository = google_dataform_repository.repository.name

  name           = "daily-race-table-update"
  release_config = google_dataform_repository_release_config.release_config.id

  # 実行設定
  invocation_config {
    # `race`テーブルのみを実行対象とする
    included_targets {
      database = var.project_id
      schema   = var.dataform_output_schema
      name     = "race"
    }
    # 実行時に使用するサービスアカウント
    service_account = google_service_account.dataform.email
  }

  # 実行スケジュール (毎日午前7時 JST)
  cron_schedule = "0 7 * * *"
  time_zone     = "Asia/Tokyo"
}

# `terraform apply`後に、作成されたリポジトリとワークスペースのURLを出力します。
output "dataform_repository_url" {
  description = "URL of the created Dataform repository."
  value       = "https://console.cloud.google.com/dataform/locations/${var.region}/repositories/${google_dataform_repository.repository.name}?project=${var.project_id}"
}
