# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#########################################################################
# Build and Push Initial Placeholder Container Image
#########################################################################

# This resource creates a Cloud Build job to build and push an initial
# placeholder container image to the Artifact Registry repository.
# This ensures there's always an image available for deployments.

resource "null_resource" "build_initial_image" {
  count = var.enable_cicd && local.use_custom_image ? 1 : 0

  triggers = {
    registry_id = google_artifact_registry_repository.container_repo[0].id
    image_url   = local.container_image_url
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Create a temporary directory for the build
      BUILD_DIR=$(mktemp -d)
      cd $BUILD_DIR

      # Create a simple placeholder Dockerfile
      cat > Dockerfile <<'EOF'
FROM nginx:alpine
RUN echo '<html><body><h1>Placeholder Application</h1><p>This is a temporary container. Deploy your application to replace this.</p></body></html>' > /usr/share/nginx/html/index.html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
EOF

      # Create a simple nginx config to listen on port 8080
      cat > nginx.conf <<'EOF'
events {
    worker_connections 1024;
}
http {
    server {
        listen 8080;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
}
EOF

      # Update Dockerfile to use custom nginx config
      cat > Dockerfile <<'EOF'
FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
RUN echo '<html><body><h1>Placeholder Application</h1><p>This is a temporary container. Deploy your application to replace this.</p><p>Ready to receive your code!</p></body></html>' > /usr/share/nginx/html/index.html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
EOF

      # Build and push using Cloud Build
      gcloud builds submit \
        --project=${local.project.project_id} \
        --region=${local.region} \
        --tag=${local.container_image_url}:latest \
        --timeout=${var.build_timeout}s \
        --machine-type=${var.cloudbuild_machine_type} \
        --disk-size=${var.cloudbuild_disk_size_gb} \
        --suppress-logs \
        .

      # Tag as initial version
      gcloud builds submit \
        --project=${local.project.project_id} \
        --region=${local.region} \
        --tag=${local.container_image_url}:initial \
        --timeout=120s \
        --machine-type=${var.cloudbuild_machine_type} \
        --suppress-logs \
        .

      # Clean up
      cd /
      rm -rf $BUILD_DIR
    EOT

    environment = {
      CLOUDSDK_CORE_PROJECT = local.project.project_id
    }
  }

  depends_on = [
    google_artifact_registry_repository.container_repo,
    google_artifact_registry_repository_iam_member.default_cloudbuild_writer,
    google_service_account.cloud_build_sa_admin,
    resource.time_sleep.wait_for_apis,
  ]
}
