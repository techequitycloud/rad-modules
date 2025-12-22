/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#########################################################################
# GCS bucket / Bucket Objects / Bucket Bindings
#########################################################################

# Create a public Google Cloud Storage (GCS) bucket.
resource "google_storage_bucket" "gcs_dev_cr_public_bucket" {
  name          = join("", [local.project.project_id, "-${var.customer_identifier}-${var.application_name}dev-cr-public"])     # Bucket name is derived from project ID with '-public' suffix.
  location      = local.region                                          # The location for the bucket.
  project       = local.project.project_id                            # The associated project ID.
  force_destroy = true                                                # Allows the bucket to be destroyed even if it contains objects.
  depends_on    = [                                                   # Ensures that certain resources are created before this bucket.
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

# Create a public Google Cloud Storage (GCS) bucket.
resource "google_storage_bucket" "gcs_qa_cr_public_bucket" {
  name          = join("", [local.project.project_id, "-${var.customer_identifier}-${var.application_name}qa-cr-public"])     # Bucket name is derived from project ID with '-public' suffix.
  location      = local.region                                          # The location for the bucket.
  project       = local.project.project_id                            # The associated project ID.
  force_destroy = true                                                # Allows the bucket to be destroyed even if it contains objects.
  depends_on    = [                                                   # Ensures that certain resources are created before this bucket.
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

# Create a public Google Cloud Storage (GCS) bucket.
resource "google_storage_bucket" "gcs_prod_cr_public_bucket" {
  name          = join("", [local.project.project_id, "-${var.customer_identifier}-${var.application_name}prod-cr-public"])     # Bucket name is derived from project ID with '-public' suffix.
  location      = local.region                                          # The location for the bucket.
  project       = local.project.project_id                            # The associated project ID.
  force_destroy = true                                                # Allows the bucket to be destroyed even if it contains objects.
  depends_on    = [                                                   # Ensures that certain resources are created before this bucket.
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

# Set public read access on all objects in the public bucket.
resource "google_storage_object_access_control" "app_dev_public_rule" {
  for_each = google_storage_bucket_object.app_dev_images                      # Apply to each image object in the bucket.
  object   = each.value.name                                          # The name of the object.
  bucket   = google_storage_bucket.gcs_dev_cr_public_bucket.name  # The name of the bucket.
  role     = "READER"                                                 # Sets the role to 'READER' for public access.
  entity   = "allUsers"                                               # Applies the rule to all users.
}

# Set public read access on all objects in the public bucket.
resource "google_storage_object_access_control" "app_qa_public_rule" {
  for_each = google_storage_bucket_object.app_qa_images                      # Apply to each image object in the bucket.
  object   = each.value.name                                          # The name of the object.
  bucket   = google_storage_bucket.gcs_qa_cr_public_bucket.name  # The name of the bucket.
  role     = "READER"                                                 # Sets the role to 'READER' for public access.
  entity   = "allUsers"                                               # Applies the rule to all users.
}

# Set public read access on all objects in the public bucket.
resource "google_storage_object_access_control" "app_prod_public_rule" {
  for_each = google_storage_bucket_object.app_prod_images                      # Apply to each image object in the bucket.
  object   = each.value.name                                          # The name of the object.
  bucket   = google_storage_bucket.gcs_prod_cr_public_bucket.name  # The name of the bucket.
  role     = "READER"                                                 # Sets the role to 'READER' for public access.
  entity   = "allUsers"                                               # Applies the rule to all users.
}

# Upload images to the public GCS bucket from a local path.
resource "google_storage_bucket_object" "app_dev_images" {
  for_each = fileset("${path.module}/scripts/img/dev/", "*")              # Iterate over each file in the local 'img' directory.
  name     = each.value                                               # Object name in GCS will match the filename.
  source   = "${path.module}/scripts/img/dev/${each.value}"               # The local file path for each image.
  bucket   = google_storage_bucket.gcs_dev_cr_public_bucket.name             # The bucket to which the images will be uploaded.
}

# Upload images to the public GCS bucket from a local path.
resource "google_storage_bucket_object" "app_qa_images" {
  for_each = fileset("${path.module}/scripts/img/qa/", "*")              # Iterate over each file in the local 'img' directory.
  name     = each.value                                               # Object name in GCS will match the filename.
  source   = "${path.module}/scripts/img/qa/${each.value}"               # The local file path for each image.
  bucket   = google_storage_bucket.gcs_qa_cr_public_bucket.name             # The bucket to which the images will be uploaded.
}

# Upload images to the public GCS bucket from a local path.
resource "google_storage_bucket_object" "app_prod_images" {
  for_each = fileset("${path.module}/scripts/img/prod/", "*")         # Iterate over each file in the local 'img' directory.
  name     = each.value                                               # Object name in GCS will match the filename.
  source   = "${path.module}/scripts/img/prod/${each.value}"          # The local file path for each image.
  bucket   = google_storage_bucket.gcs_prod_cr_public_bucket.name     # The bucket to which the images will be uploaded.
}

/**
# Bind storage admin role to trusted users for the public bucket.
resource "google_storage_bucket_iam_binding" "app_dev_binding" {
  bucket  = google_storage_bucket.gcs_dev_cr_public_bucket.name         # The name of the bucket.
  role    = "roles/storage.admin"                                       # Assigns 'storage.admin' role for admin access.
  members = toset(concat(                                               # Combines and converts user and group lists into a set.
    formatlist("user:%s", var.trusted_users),
    formatlist("group:%s", var.trusted_groups)
  ))
}

# Bind storage admin role to trusted users for the public bucket.
resource "google_storage_bucket_iam_binding" "app_qa_binding" {
  bucket  = google_storage_bucket.gcs_qa_cr_public_bucket.name          # The name of the bucket.
  role    = "roles/storage.admin"                                       # Assigns 'storage.admin' role for admin access.
  members = toset(concat(                                               # Combines and converts user and group lists into a set.
    formatlist("user:%s", var.trusted_users),
    formatlist("group:%s", var.trusted_groups)
  ))
}

# Bind storage admin role to trusted users for the public bucket.
resource "google_storage_bucket_iam_binding" "app_prod_binding" {
  bucket  = google_storage_bucket.gcs_prod_cr_public_bucket.name         # The name of the bucket.
  role    = "roles/storage.admin"                                        # Assigns 'storage.admin' role for admin access.
  members = toset(concat(                                               # Combines and converts user and group lists into a set.
    formatlist("user:%s", var.trusted_users),
    formatlist("group:%s", var.trusted_groups)
  ))
}
**/

#########################################################################
# Private GCS bucket / Bucket Objects / Bucket Bindings
#########################################################################

# Create a private Google Cloud Storage (GCS) bucket.
resource "google_storage_bucket" "gcs_dev_cr_private_bucket" {
  name          = join("", [local.project.project_id, "-${var.customer_identifier}-${var.application_name}dev-cr-private"])    # Bucket name is derived from project ID with '-private' suffix.
  location      = local.region                                          # The location for the bucket.
  project       = local.project.project_id                            # The associated project ID.
  force_destroy = true                                                # Allows the bucket to be destroyed even if it contains objects.
  public_access_prevention = "enforced"
  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 7
    }
  }

  depends_on    = [                                                   # Ensures that certain resources are created before this bucket.
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

# Create a private Google Cloud Storage (GCS) bucket.
resource "google_storage_bucket" "gcs_qa_cr_private_bucket" {
  name          = join("", [local.project.project_id, "-${var.customer_identifier}-${var.application_name}qa-cr-private"])    # Bucket name is derived from project ID with '-private' suffix.
  location      = local.region                                          # The location for the bucket.
  project       = local.project.project_id                            # The associated project ID.
  force_destroy = true                                                # Allows the bucket to be destroyed even if it contains objects.
  public_access_prevention = "enforced"
  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 7
    }
  }

  depends_on    = [                                                   # Ensures that certain resources are created before this bucket.
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

# Create a private Google Cloud Storage (GCS) bucket.
resource "google_storage_bucket" "gcs_prod_cr_private_bucket" {
  name          = join("", [local.project.project_id, "-${var.customer_identifier}-${var.application_name}prod-cr-private"])    # Bucket name is derived from project ID with '-private' suffix.
  location      = local.region                                          # The location for the bucket.
  project       = local.project.project_id                            # The associated project ID.
  force_destroy = true                                                # Allows the bucket to be destroyed even if it contains objects.
  public_access_prevention = "enforced"
  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 7
    }
  }

  depends_on    = [                                                   # Ensures that certain resources are created before this bucket.
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

/**
# Bind storage admin role to trusted users for the private bucket.
resource "google_storage_bucket_iam_binding" "gcs_dev_cr_private_bucket" {
  bucket  = google_storage_bucket.gcs_dev_cr_private_bucket.name             # The name of the bucket.
  role    = "roles/storage.admin"                                            # Assigns 'storage.admin' role for admin access.
  members = toset(concat(                                               # Combines and converts user and group lists into a set.
    formatlist("user:%s", var.trusted_users),
    formatlist("group:%s", var.trusted_groups)
  ))
}

# Bind storage admin role to trusted users for the private bucket.
resource "google_storage_bucket_iam_binding" "gcs_qa_cr_private_bucket" {
  bucket  = google_storage_bucket.gcs_qa_cr_private_bucket.name             # The name of the bucket.
  role    = "roles/storage.admin"                                           # Assigns 'storage.admin' role for admin access.
  members = toset(concat(                                               # Combines and converts user and group lists into a set.
    formatlist("user:%s", var.trusted_users),
    formatlist("group:%s", var.trusted_groups)
  ))
}

# Bind storage admin role to trusted users for the private bucket.
resource "google_storage_bucket_iam_binding" "gcs_prod_cr_private_bucket" {
  bucket  = google_storage_bucket.gcs_prod_cr_private_bucket.name             # The name of the bucket.
  role    = "roles/storage.admin"                                             # Assigns 'storage.admin' role for admin access.
  members = toset(concat(                                               # Combines and converts user and group lists into a set.
    formatlist("user:%s", var.trusted_users),
    formatlist("group:%s", var.trusted_groups)
  ))
}
**/

#########################################################################
# Upload backups
#########################################################################

resource "google_storage_bucket_object" "app_dev_db_dump" {
  count  = fileexists("${path.module}/scripts/app/local.dev_backup_files[var.application_demo].db_dump") ? 1 : 0
  name   = "local.dev_backup_files[var.application_demo].db_dump"
  bucket = google_storage_bucket.gcs_dev_cr_private_bucket.name
  source = "${path.module}/scripts/app/local.dev_backup_files[var.application_demo].db_dump"
}

resource "google_storage_bucket_object" "app_dev_data" {
  count  = fileexists("${path.module}/scripts/app/local.dev_backup_files[var.application_demo].data_file") ? 1 : 0
  name   = "local.dev_backup_files[var.application_demo].data_file"
  bucket = google_storage_bucket.gcs_dev_cr_private_bucket.name
  source = "${path.module}/scripts/app/local.dev_backup_files[var.application_demo].data_file"
}

resource "google_storage_bucket_object" "app_qa_db_dump" {
  count  = fileexists("${path.module}/scripts/app/local.qa_backup_files[var.application_demo].db_dump") ? 1 : 0
  name   = "local.qa_backup_files[var.application_demo].db_dump"
  bucket = google_storage_bucket.gcs_qa_cr_private_bucket.name
  source = "${path.module}/scripts/app/local.qa_backup_files[var.application_demo].db_dump"
}

resource "google_storage_bucket_object" "app_qa_data" {
  count  = fileexists("${path.module}/scripts/app/local.qa_backup_files[var.application_demo].data_file") ? 1 : 0
  name   = "local.qa_backup_files[var.application_demo].data_file"
  bucket = google_storage_bucket.gcs_qa_cr_private_bucket.name
  source = "${path.module}/scripts/app/local.qa_backup_files[var.application_demo].data_file"
}

resource "google_storage_bucket_object" "app_prod_db_dump" {
  count  = fileexists("${path.module}/scripts/app/local.prod_backup_files[var.application_demo].db_dump") ? 1 : 0
  name   = "local.prod_backup_files[var.application_demo].db_dump"
  bucket = google_storage_bucket.gcs_prod_cr_private_bucket.name
  source = "${path.module}/scripts/app/local.prod_backup_files[var.application_demo].db_dump"
}

resource "google_storage_bucket_object" "app_prod_data" {
  count  = fileexists("${path.module}/scripts/app/local.prod_backup_files[var.application_demo].data_file") ? 1 : 0
  name   = "local.prod_backup_files[var.application_demo].data_file"
  bucket = google_storage_bucket.gcs_prod_cr_private_bucket.name
  source = "${path.module}/scripts/app/local.prod_backup_files[var.application_demo].data_file"
}

#########################################################################
# GCS Backend Bucket for HTTP(S) Load Balancing
#########################################################################

/**
#
# Commented out due to Qwiklab quota limit to max of 3 backends globally
#
# Create a backend bucket on GCP to use with HTTP(S) load balancing, backed by a GCS bucket.
resource "google_compute_backend_bucket" "app_dev_be_http_cdn_gcs" {
  name        = "${var.application_name}dev-cr-be-http-cdn-gcs"             # The name of the backend bucket.
  description = "Public bucket resources"                     # A description of the backend bucket.
  project     = local.project.project_id                      # The associated project ID.
  bucket_name = google_storage_bucket.gcs_dev_cr_public_bucket.name  # The name of the GCS bucket to be used as a backend.
  enable_cdn  = true                                          # Enable CDN for the backend bucket.
}

# Create a backend bucket on GCP to use with HTTP(S) load balancing, backed by a GCS bucket.
resource "google_compute_backend_bucket" "app_qa_be_http_cdn_gcs" {
  name        = "${var.application_name}qa-cr-be-http-cdn-gcs"             # The name of the backend bucket.
  description = "Public bucket resources"                     # A description of the backend bucket.
  project     = local.project.project_id                      # The associated project ID.
  bucket_name = google_storage_bucket.gcs_qa_cr_public_bucket.name  # The name of the GCS bucket to be used as a backend.
  enable_cdn  = true                                          # Enable CDN for the backend bucket.
}

# Create a backend bucket on GCP to use with HTTP(S) load balancing, backed by a GCS bucket.
resource "google_compute_backend_bucket" "app_prod_be_http_cdn_gcs" {
  name        = "${var.application_name}prod-cr-be-http-cdn-gcs"             # The name of the backend bucket.
  description = "Public bucket resources"                     # A description of the backend bucket.
  project     = local.project.project_id                      # The associated project ID.
  bucket_name = google_storage_bucket.gcs_prod_cr_public_bucket.name  # The name of the GCS bucket to be used as a backend.
  enable_cdn  = true                                          # Enable CDN for the backend bucket.
}
**/
