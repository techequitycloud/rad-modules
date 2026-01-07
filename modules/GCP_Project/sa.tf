resource "google_service_account" "rad_agent" {
  account_id   = "rad-agent"
  display_name = "RAD Agent Service Account"
  project      = google_project.project.project_id
}
