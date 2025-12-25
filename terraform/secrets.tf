# -----------------------------------------------------------------------------
# Secret Manager アクセス設定
# -----------------------------------------------------------------------------

# スケジュールエクスポート用関数SAに対して、特定のシークレットへのアクセス権(Secret Accessor)を付与

resource "google_secret_manager_secret_iam_member" "ftp_user_accessor" {
  project   = "56638639323" # シークレットを所有するプロジェクト番号/ID
  secret_id = "kol_ftp_bubble_username"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.export_schedules_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "ftp_pass_accessor" {
  project   = "56638639323"
  secret_id = "kol_ftp_bubble_password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.export_schedules_sa.email}"
}
