# Odoo Deployment Analysis

## 1. ODOO_MASTER_PASS Configuration

**Status: Confirmed**

The Odoo deployment is correctly configured to use the `ODOO_MASTER_PASS` value. The configuration flow is as follows:

1.  **Secret Generation**:
    A random password is generated and stored in Google Secret Manager. This is defined in `modules/WebApp/main.tf`:
    ```terraform
    resource "google_secret_manager_secret" "odoo_master_pass" { ... }
    ```

2.  **Environment Variable Injection**:
    The secret is injected into the application environment variables in `modules/WebApp/main.tf` via `preset_secret_env_vars`:
    ```terraform
    var.application_module == "odoo" ? {
      ODOO_MASTER_PASS = try(google_secret_manager_secret.odoo_master_pass[0].secret_id, "")
    } : {},
    ```

3.  **Configuration File Generation**:
    The `odoo-config` initialization job (defined in `modules/WebApp/modules/odoo/variables.tf`) reads this environment variable and writes it to the configuration file at `/mnt/odoo.conf`:
    ```bash
    # Generate configuration file with variable substitution
    cat > "$${CONFIG_FILE}" << EOF
    ...
    admin_passwd = $${ODOO_MASTER_PASS}
    ...
    EOF
    ```

4.  **Service Startup**:
    The Odoo container is started with the command `exec odoo -c /mnt/odoo.conf`, ensuring it uses the configuration file containing the secure master password.

## 2. Custom Docker Build Process

The `modules/WebApp` module supports building a custom Odoo container using the Dockerfile located in `modules/WebApp/scripts/odoo/Dockerfile`.

### Default Behavior
By default, the Odoo module (`modules/WebApp/modules/odoo`) is configured to use a **prebuilt** image (`image_source = "prebuilt"`). It does not automatically trigger a custom build.

### Enabling Custom Build
To perform a build using the custom Dockerfile, you must override the default configuration in your Terraform `module "webapp"` block:

1.  **Set Image Source**:
    Set `container_image_source` to `"custom"`.

2.  **Configure Build Settings**:
    Provide the `container_build_config` variable. Since the Odoo preset does not define a default build config, it must be fully specified:

    ```terraform
    module "webapp" {
      source = "./modules/WebApp"

      application_module = "odoo"

      # Enable custom build
      container_image_source = "custom"

      container_build_config = {
        enabled            = true
        dockerfile_path    = "Dockerfile"  # Relative to context_path
        context_path       = "odoo"        # Relative to modules/WebApp/scripts/
        dockerfile_content = null
        build_args         = {}
        artifact_repo_name = "webapp-repo"
      }

      # ... other variables
    }
    ```

### Build Workflow
When configured as above, the build process is orchestrated by `modules/WebApp/buildappcontainer.tf`:

1.  **Trigger**: Terraform detects `local.enable_custom_build` is `true`.
2.  **Cloud Build Config**: A `cloudbuild.yaml` file is generated from `modules/WebApp/scripts/core/cloudbuild.yaml.tpl`.
3.  **Execution**: The `local-exec` provisioner runs `modules/WebApp/scripts/core/build-container.sh`.
4.  **Build**: Google Cloud Build executes the build using the context `modules/WebApp/scripts/odoo`.
5.  **Push**: The resulting image is pushed to the project's Artifact Registry.
6.  **Deployment**: The Cloud Run service is deployed using the newly built image URI.
