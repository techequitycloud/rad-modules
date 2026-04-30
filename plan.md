1. *Update `UIMeta group` for variables in `variables.tf` files.*
   - Change `group=0` to the correct logical grouping for variables like `pod_ip_range`, `service_ip_range`, `enable_services`, and `deploy_application` based on their section headers.
   - For `modules/Istio_GKE/variables.tf`:
     - `pod_ip_range`: change to `group=3`
     - `service_ip_range`: change to `group=3`
     - `enable_services`: change to `group=4`
     - `deploy_application`: change to `group=6`
   - For `modules/Bank_GKE/variables.tf`:
     - `pod_ip_range`: change to `group=5`
     - `service_ip_range`: change to `group=5`
     - `enable_services`: change to `group=6`
   - For `modules/MC_Bank_GKE/variables.tf`:
     - `enable_services`: change to `group=4`

2. *Run Terraform format and validation.*
   - Execute `terraform fmt -check -recursive` and `terraform validate` in the module directories.

3. *Pre-commit steps.*
   - Run pre-commit instructions to ensure verification and proper checking is done.

4. *Submit.*
   - Submit the branch.
