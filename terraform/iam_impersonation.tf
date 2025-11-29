# Grant Workflows SA permission to impersonate Dataform Runner SA
resource "google_service_account_iam_member" "workflows_sa_impersonate_dataform" {
  service_account_id = google_service_account.dataform.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.workflows_sa.email}"
}
