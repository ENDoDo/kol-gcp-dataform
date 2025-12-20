
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
resource "google_workflows_workflow" "dataform_trigger_workflow_stg" {
  depends_on = [google_project_service.workflows]
  name            = "dataform-trigger-workflow-stg"
  region          = var.region
  description     = "BigQueryテーブル更新時にDataform実行をトリガーするワークフロー (Staging)"
  service_account = google_service_account.workflows_sa.id
  project         = var.project_id

  source_contents = <<EOF
main:
  params: [args]
  steps:
    - init:
        assign:
          - is_paused: false  # 停止したい時はここを true に、再開時は false にする
          - repository: "projects/${var.project_id}/locations/${var.region}/repositories/${google_dataform_repository.repository_stg.name}"
          - workspace: "${var.dataform_workspace_id}"
    - check_paused:
        switch:
          - condition: ${is_paused}
            return: "Paused: Dataform execution skipped."
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
              defaultSchema: "${var.stg_schema}"
              vars:
                source_schema: "kolbi_keiba_stg"
        result: compilationResult
    - createWorkflowInvocation:
        call: http.post
        args:
          url: $${"https://dataform.googleapis.com/v1beta1/" + repository + "/workflowInvocations"}
          auth:
            type: OAuth2
          body:
            compilationResult: $${compilationResult.body.name}
            invocationConfig:
              serviceAccount: "dataform-runner-stg@${var.project_id}.iam.gserviceaccount.com"
        result: workflowInvocation
    - returnResult:
        return: $${workflowInvocation}
EOF
}

resource "google_workflows_workflow" "dataform_trigger_workflow_prd" {
  depends_on = [google_project_service.workflows]
  name            = "dataform-trigger-workflow"
  region          = var.region
  description     = "BigQueryテーブル更新時にDataform実行をトリガーするワークフロー (Production)"
  service_account = google_service_account.workflows_sa.id
  project         = var.project_id

  source_contents = <<EOF
main:
  params: [args]
  steps:
    - init:
        assign:
          - repository: "projects/${var.project_id}/locations/${var.region}/repositories/${google_dataform_repository.repository_prd.name}"
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
              defaultSchema: "${var.prd_schema}"
              vars:
                source_schema: "kolbi_keiba"
        result: compilationResult
    - createWorkflowInvocation:
        call: http.post
        args:
          url: $${"https://dataform.googleapis.com/v1beta1/" + repository + "/workflowInvocations"}
          auth:
            type: OAuth2
          body:
            compilationResult: $${compilationResult.body.name}
            invocationConfig:
              serviceAccount: "dataform-runner@${var.project_id}.iam.gserviceaccount.com"
        result: workflowInvocation
    - returnResult:
        return: $${workflowInvocation}
EOF
}
