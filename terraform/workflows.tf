
# -----------------------------------------------------------------------------
# Dataformトリガー用 Cloud Workflows
# -----------------------------------------------------------------------------

# --- Workflows用サービスアカウント ---
resource "google_service_account" "workflows_sa" {
  account_id   = "dataform-workflows-sa${local.env_suffix}"
  display_name = "Dataform Workflows Service Account${local.env_suffix}"
  project      = var.project_id
}

# Workflowsサービスアカウントへの権限付与
resource "google_project_iam_member" "workflows_dataform_editor" {
  project = var.project_id
  role    = "roles/dataform.editor"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"
}

resource "google_project_iam_member" "workflows_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workflows_sa.email}"
}

# --- Cloud Workflow ---
resource "google_workflows_workflow" "dataform_trigger_workflow" {
  depends_on = [google_project_service.workflows]
  name            = "dataform-trigger-workflow${local.env_suffix}"
  region          = var.region
  description     = "BigQueryテーブル更新時にDataform実行をトリガーするワークフロー"
  service_account = google_service_account.workflows_sa.id
  project         = var.project_id

  source_contents = <<EOF
main:
  params: [args]
  steps:
    - init:
        assign:
          - repository: "projects/${var.project_id}/locations/${var.region}/repositories/${terraform.workspace == "prd" ? google_dataform_repository.repository_prd.name : google_dataform_repository.repository_stg.name}"
          - workspace: "${var.dataform_workspace_id}"
    - createCompilationResult:
        call: http.post
        args:
          url: $${"https://dataform.googleapis.com/v1beta1/" + repository + "/compilationResults"}
          auth:
            type: OAuth2
          body:
            gitCommitish: "main"
            codeCompilationConfig:
              defaultDatabase: "${var.project_id}"
              defaultSchema: "${local.dataform_output_schema}"
              vars:
                source_schema: "${local.dataform_source_schema}"
        result: compilationResult
    - createWorkflowInvocation:
        call: http.post
        args:
          url: $${"https://dataform.googleapis.com/v1beta1/" + repository + "/workflowInvocations"}
          auth:
            type: OAuth2
          body:
            compilationResult: $${compilationResult.body.name}
            invocationConfig: {}
              # includedTargets:
              #   - database: "${var.project_id}"
              #     schema: "${local.dataform_output_schema}"
              #     name: "race" # 必要に応じて対象を変更または動的に設定してください
              # transitiveDependenciesIncluded: true
              # serviceAccount: "${google_service_account.dataform.email}"
        result: workflowInvocation
    - returnResult:
        return: $${workflowInvocation}
EOF
}
