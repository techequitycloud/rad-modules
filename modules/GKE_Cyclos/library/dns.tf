# Copyright (c) Tech Equity Ltd

# Define a managed DNS zone resource within Google Cloud DNS.
resource "google_dns_managed_zone" "public_zone" {
  # Assign the project ID where the DNS zone will be managed.
  project  = local.project.project_id
  # Set a name for the managed DNS zone.
  name     = "public-zone"
  # Dynamically generate a unique DNS name using a random ID.
  dns_name    = "techequity.network."
  # Provide a description for the DNS zone.
  description   = "Public DNS zone"
  # Allow Terraform to delete the DNS zone even if it contains records.
  force_destroy = true

  # Ensure that required GCP services are enabled before creating this resource.
  depends_on = [
    google_project_service.enabled_services
  ]
}

# Generate a random ID to use in creating unique resource names.
resource "random_id" "rnd" {
  # The length of the random ID in bytes. A byte_length of 4 generates a sufficiently unique string.
  byte_length = 4
}

# Define a DNS record set for an application within the managed DNS zone.
resource "google_dns_record_set" "application" {
  # Specify the project ID where the DNS record set will be managed.
  project  = local.project.project_id
  # Construct the FQDN for the application using a variable and the DNS name of the managed zone.
  name = "${var.application_name}.${google_dns_managed_zone.public_zone.dns_name}"
  # Set the record type to 'A' (Address Record).
  type = "A"
  # Set the time-to-live for the DNS record, in seconds.
  ttl  = 300

  # Reference the name of the managed zone where the record set will be created.
  managed_zone = google_dns_managed_zone.public_zone.name

  # Specify the IP address for the 'A' record, using an address from a global compute address resource.
  rrdatas = [google_compute_global_address.default.address]

  # Ensure this resource is created after the specified dependencies are ready.
  depends_on = [
    google_compute_global_forwarding_rule.https_redirect,
  ]
}

# Define another DNS record set for a dev version of the application.
resource "google_dns_record_set" "application_dev" {
  # Specify the project ID where this DNS record set will be managed.
  project  = local.project.project_id
  # Construct the FQDN for the dev application, appending '-dev' to differentiate it.
  name     = "${var.application_name}dev.${google_dns_managed_zone.public_zone.dns_name}"
  # Set the record type to 'CNAME' (Canonical Name Record).
  type         = "CNAME"
  # Set the time-to-live for this DNS record, in seconds.
  ttl          = 300
  # Reference the name of the managed zone where this record set will be created.
  managed_zone = google_dns_managed_zone.public_zone.name
  # Specify the canonical name for the 'CNAME' record. Here it points to Google's
  rrdatas      = ["ghs.googlehosted.com."]
}

output "name_servers" {
  description = "The list of nameservers that will be authoritative for this domain."
  value       = google_dns_managed_zone.public_zone.name_servers
}

output "application_domain" {
  description = "The custom application domain."
  value       = google_dns_record_set.application.name
} 
