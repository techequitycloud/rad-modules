# Gemini\_Enterprise Module

This module prepares a Google Cloud project for an **instructor-led demonstration of Gemini Enterprise**, built around the fictional **Cymbal Pools** company. It automates the parts of the "Cymbal Pools Gemini Enterprise Demo" setup that have an API: the Gemini Enterprise app, its identity provider, the demo content, the BigQuery data, the custom ADK agent and the Model Armor template. That leaves the instructor only the steps that need an interactive Google Workspace sign-in or are themselves the live demo.

On apply the module:

- **Creates the Gemini Enterprise app** ("Cymbal Pools GE", company name "Cymbal Pools") in the chosen `ge_location`. Google Identity is selected as the identity provider there, and the app gets a Cloud Storage-backed **Cymbal Pools Documents** data store, so *Search company data* returns grounded answers before Google Drive is even connected.
- **Stages the demo content** in a Cloud Storage bucket: the convention brochure (PDF) and pool installation analysis (DOCX) under `drive/` for upload to Google Drive, the `pool party.png` announcement image (optionally public-read), the `pH table.png` image for the image-to-table demo, the BigQuery seed CSV and the `adk_to_ge/` ADK agent source.
- **Creates a BigQuery dataset** (`cymbal_pools`) with an `installation_requests` table seeded with 60 sample pool installation requests.
- **Deploys the BigQuery ADK agent** to Vertex AI Agent Runtime (Agent Engine), running as `resource_creator_identity`, and grants the Reasoning Engine service agent Vertex AI User, BigQuery User and BigQuery Data Editor.
- **Creates a Model Armor template** with sensitive data (basic SDP), responsible-AI (harassment, hate speech, dangerous, sexually explicit), prompt-injection/jailbreak and malicious-URI filters, ready to attach to the assistant live in class.

What stays manual, and why: the Google Drive and Calendar connectors and the OAuth consent screen/client need the console's interactive OAuth flows. Registering the BigQuery agent in Gemini Enterprise needs that OAuth client, and "Grant All Users the Agent User role" has no API. Announcements, Feature Management toggles and enabling Model Armor on the assistant are demoed in class. A project that has never used Gemini Enterprise also needs a one-time **Start free trial** click in the console before the app can be created.

Cymbal Pools is a fictional company. Every document, image and dataset in `assets/` is original content written for this module (regenerate with `assets/generate_assets.py`), and the ADK agent in `adk_to_ge/` is this module's own implementation.

Resources carry the deployment ID as a suffix, e.g. bucket `<project>-ge-8b56`, app `cymbal-pools-ge-8b56`, data store `cymbal-pools-docs-8b56`, Model Armor template `cymbal-pools-ma-8b56`, and Agent Runtime engine "BigQuery Pool Data Agent (8b56)".

## Industry Value & Use Cases

Gemini Enterprise is Google Cloud's agentic workspace. It brings enterprise search across Google Workspace and third-party data, a conversational assistant, prebuilt agents such as Deep Research, a no-code Agent Designer, and custom agents built with the Agent Development Kit (ADK) together in one governed app. Partner trainers and field teams demonstrate it repeatedly, and the preparation (content, connectors, agent deployment, IAM and safety templates) usually takes longer than the demo itself. This module turns that preparation into a single deployment.

**Key use cases this module demonstrates:**
- **Enterprise search and grounded answers** across Google Drive, Calendar and a Cloud Storage data store, including targeting a single file with `@`
- **Connector actions** that create Calendar events and work with Drive files through OAuth-delegated actions
- **Built-in agents**: Deep Research plans and runs multi-source research; Agent Designer builds and schedules a daily-briefing agent from a prompt
- **Custom ADK agents on Agent Runtime** that query and write BigQuery data, registered into Gemini Enterprise with OAuth authorization
- **AI safety controls**: Model Armor blocking sensitive data, harassment and prompt-injection attempts at the assistant level

For the instructor walkthrough (pre-class setup and in-class demo script), see [Gemini_Enterprise.md](../../docs/labs/Gemini_Enterprise.md). For services, behaviour and configuration, see [docs/modules/Gemini_Enterprise.md](../../docs/modules/Gemini_Enterprise.md).

Last tested on Mon Sep 28, 2026

## Deployment Options

Deploy this module from the **[RAD Modules platform UI](https://radmodules.dev)**, the recommended path, with **no command line or local toolchain required**. Advanced/automation users can instead use the Launcher CLI or call the Terraform module directly (see **Advanced** below).

| | [RAD Modules UI](https://radmodules.dev) | RAD Modules Launcher (CLI) |
|---|---|---|
| **Setup required** | None — runs in your browser | Python 3.7+, OpenTofu, and `gcloud` CLI |
| **Best for** | Quick starts, demos, and guided deployments | Automation, scripting, and full variable control |
| **Configuration** | Point-and-click form with sensible defaults | `--varfile` with `key = "value"` overrides |
| **State management** | Managed by the platform | GCS bucket you own and manage |

### Option 1: RAD Modules UI (no setup required)

Visit **[https://radmodules.dev](https://radmodules.dev)**, sign in (with your Google account or an email and password), open **Solutions → Solution Catalog**, choose **RAD modules**, and click **Deploy** on this module. The module hides the **GCP Project on RAD** option (`enable_rad_gcpproject = false`), so it deploys into a Google Cloud project you bring.

### Advanced — RAD Modules Launcher (CLI, for automation/maintainers)

Use the [RAD Modules Launcher](../../rad-launcher/README.md) to deploy from your workstation or Google Cloud Shell.

## Advanced — Terraform module (maintainers)

> **Platform users don't need this.** Deploy from the [RAD Modules UI](https://radmodules.dev) above. The Terraform module call below is for maintainers/automation integrating the module directly.

```hcl
module "gemini_enterprise" {
  source = "./modules/Gemini_Enterprise"

  project_id  = "my-gcp-project"
  region      = "us-central1" # Agent Runtime region for the ADK agent
  ge_location = "global"      # or "us" / "eu"
}
```

The agent deploy runs `python3` locally (a virtualenv is created under `$HOME/.local/ge-adk-venv`), so the machine running Terraform needs Python 3.10+ and `gcloud`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.19, < 8.3 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 7.19, < 8.3 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0, < 4.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0, < 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 8.2.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | 8.2.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.2 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_bigquery_dataset.cymbal_pools](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset) | resource |
| [google_bigquery_job.seed_installation_requests](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_job) | resource |
| [google_bigquery_table.installation_requests](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_table) | resource |
| [google_discovery_engine_acl_config.google_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/discovery_engine_acl_config) | resource |
| [google_discovery_engine_data_store.cymbal_docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/discovery_engine_data_store) | resource |
| [google_discovery_engine_search_engine.app](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/discovery_engine_search_engine) | resource |
| [google_model_armor_template.demo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/model_armor_template) | resource |
| [google_project_iam_member.reasoning_engine_roles](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.enabled_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service_identity.discoveryengine](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service_identity) | resource |
| [google_storage_bucket.demo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.discoveryengine_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_object.adk_to_ge](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_storage_bucket_object.drive_documents](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_storage_bucket_object.images](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_storage_bucket_object.installation_requests_csv](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_storage_object_acl.pool_party_public](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_object_acl) | resource |
| [null_resource.deploy_adk_agent](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.import_cymbal_docs](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_auth_id"></a> [agent\_auth\_id](#input\_agent\_auth\_id) | Optional ID of the Gemini Enterprise Authorization (e.g. 'bq-auth') the agent is registered with. When set, BigQuery queries run as the signed-in Gemini Enterprise user via that OAuth token; when empty (default), they run as the Agent Runtime service agent, so the agent works whether or not it is registered with an authorization. {{UIMeta group=4 order=405 }} | `string` | `""` | no |
| <a name="input_agent_display_name"></a> [agent\_display\_name](#input\_agent\_display\_name) | Display name of the agent on Agent Runtime. The deployment ID is appended so destroy can find exactly this engine. Defaults to 'BigQuery Pool Data Agent'. {{UIMeta group=4 order=402 }} | `string` | `"BigQuery Pool Data Agent"` | no |
| <a name="input_agent_model"></a> [agent\_model](#input\_agent\_model) | Gemini model the BigQuery agent uses (e.g. 'gemini-3.5-flash'). Changing it redeploys the agent as a new engine, which must then be re-registered in Gemini Enterprise. Defaults to 'gemini-3.5-flash'. {{UIMeta group=4 order=403 }} | `string` | `"gemini-3.5-flash"` | no |
| <a name="input_agent_model_location"></a> [agent\_model\_location](#input\_agent\_model\_location) | Vertex AI location the agent calls the model in. Defaults to 'global', where the newest Gemini models are served; set a region only if the chosen model is regional. {{UIMeta group=4 order=404 }} | `string` | `"global"` | no |
| <a name="input_app_display_name"></a> [app\_display\_name](#input\_app\_display\_name) | Display name of the Gemini Enterprise app. Defaults to 'Cymbal Pools GE', matching the lab guide. {{UIMeta group=2 order=203 }} | `string` | `"Cymbal Pools GE"` | no |
| <a name="input_bq_dataset_id"></a> [bq\_dataset\_id](#input\_bq\_dataset\_id) | BigQuery dataset holding the installation_requests table queried by the BigQuery agent. Letters, numbers and underscores only. Defaults to 'cymbal_pools'. {{UIMeta group=3 order=303 }} | `string` | `"cymbal_pools"` | no |
| <a name="input_bq_location"></a> [bq\_location](#input\_bq\_location) | BigQuery dataset location (e.g. 'US', 'EU', 'us-central1'). Defaults to 'US'. {{UIMeta group=3 order=304 }} | `string` | `"US"` | no |
| <a name="input_bucket_location"></a> [bucket\_location](#input\_bucket\_location) | Location of the demo content bucket (e.g. 'US', 'us-central1'). Defaults to 'US'. {{UIMeta group=3 order=301 }} | `string` | `"US"` | no |
| <a name="input_company_name"></a> [company\_name](#input\_company\_name) | Company name set on the Gemini Enterprise app (Advanced Options > Company Name). It helps the assistant ground answers about 'our company'. Defaults to 'Cymbal Pools'. {{UIMeta group=2 order=204 }} | `string` | `"Cymbal Pools"` | no |
| <a name="input_configure_google_identity"></a> [configure\_google\_identity](#input\_configure\_google\_identity) | Set to true (default) to select Google Identity as the identity provider for the chosen ge_location. Required before Google Drive or Calendar connectors can be created. Set to false if the project already uses a third-party (workforce identity federation) provider. {{UIMeta group=2 order=205 }} | `bool` | `true` | no |
| <a name="input_create_gemini_enterprise_app"></a> [create\_gemini\_enterprise\_app](#input\_create\_gemini\_enterprise\_app) | Set to true (default) to create the Gemini Enterprise app and its Cymbal Pools document data store. Requires Gemini Enterprise to be activated in the project: on a project that has never used it, open Gemini Enterprise in the console once and click 'Start free trial' before deploying, or the app creation fails. Set to false to create the app by hand as the lab describes. {{UIMeta group=2 order=201 }} | `bool` | `true` | no |
| <a name="input_create_model_armor_template"></a> [create\_model\_armor\_template](#input\_create\_model\_armor\_template) | Set to true (default) to create the Model Armor template demonstrated in class (sensitive data, harassment/RAI and prompt-injection filters). The instructor attaches it to the app live under Configurations > Assistant. {{UIMeta group=5 order=501 }} | `bool` | `true` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Number of platform credits consumed when this module is deployed. {{UIMeta group=0 order=103 }} | `number` | `0` | no |
| <a name="input_deploy_adk_agent"></a> [deploy\_adk\_agent](#input\_deploy\_adk\_agent) | Set to true (default) to deploy the BigQuery ADK agent to Vertex AI Agent Runtime and grant the Reasoning Engine service agent Vertex AI User, BigQuery User and BigQuery Data Editor. Deployment takes 5-10 minutes and requires python3 on the machine running Terraform. Set to false to deploy it from Cloud Shell during class as the lab describes. {{UIMeta group=4 order=401 }} | `bool` | `true` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Short alphanumeric suffix appended to resource names to ensure uniqueness within the project. Set by the platform; leave blank to generate one. {{UIMeta group=0 order=108 }} | `string` | `null` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true (default) to allow platform administrators to permanently delete all resources created by this module. {{UIMeta group=0 order=105 }} | `bool` | `true` | no |
| <a name="input_enable_rad_gcpproject"></a> [enable\_rad\_gcpproject](#input\_enable\_rad\_gcpproject) | Set to false to hide the "GCP Project on RAD" option for this module -- it may only be deployed into a customer's own GCP project. This module enables modelarmor, which is absent from every RAD-managed tier allowlist, and aiplatform, which the sandbox and lab tiers do not permit; Gemini Enterprise itself also needs a per-project license or free trial. {{UIMeta group=0 order=110 }} | `bool` | `false` | no |
| <a name="input_enable_services"></a> [enable\_services](#input\_enable\_services) | Set to true (default) to automatically enable required GCP project APIs. Set to false when APIs are already enabled. {{UIMeta group=0 order=109 }} | `bool` | `true` | no |
| <a name="input_ge_location"></a> [ge\_location](#input\_ge\_location) | Gemini Enterprise location for the app, its data stores and the identity provider: 'global' (default), 'us' or 'eu'. The Drive/Calendar connectors and the BigQuery agent registration must later be created in this same location. Some sandbox projects have zero custom-agent quota at 'global'; use 'us' there. {{UIMeta group=2 order=202 }} | `string` | `"global"` | no |
| <a name="input_model_armor_confidence"></a> [model\_armor\_confidence](#input\_model\_armor\_confidence) | Minimum confidence at which Model Armor blocks content: 'LOW_AND_ABOVE' (strictest), 'MEDIUM_AND_ABOVE' (default) or 'HIGH'. {{UIMeta group=5 order=503 updatesafe }} | `string` | `"MEDIUM_AND_ABOVE"` | no |
| <a name="input_model_armor_location"></a> [model\_armor\_location](#input\_model\_armor\_location) | Location of the Model Armor template (e.g. 'us', 'eu', 'us-central1'). Leave empty (default) to follow ge_location, with 'global' mapped to 'us' because Model Armor has no global templates. {{UIMeta group=5 order=502 }} | `string` | `""` | no |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Ordered list of module names that must be fully deployed before this module can be deployed. {{UIMeta group=0 order=101 }} | `list(string)` | <pre>[<br>  "GCP Project"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | Human-readable description of this module displayed to users in the platform UI. {{UIMeta group=0 order=100 }} | `string` | `"This module prepares a Google Cloud project for an instructor-led demonstration of Gemini Enterprise using the fictional Cymbal Pools company. It creates the Gemini Enterprise app (\"Cymbal Pools GE\") with Google Identity configured, a searchable data store of Cymbal Pools documents, a Cloud Storage bucket holding the demo brochure, installation analysis, announcement image and pH-table image, a BigQuery dataset of pool installation requests, a custom ADK BigQuery agent deployed to Vertex AI Agent Runtime with the IAM it needs, and a Model Armor template covering sensitive data, harassment and prompt-injection filtering. What remains for the instructor is the part that needs an interactive Google Workspace sign-in or is itself demoed live: connecting Google Drive and Calendar, creating the OAuth client, registering the BigQuery agent, publishing the announcement, and enabling Feature Management and Model Armor on the app."` | no |
| <a name="input_module_documentation"></a> [module\_documentation](#input\_module\_documentation) | URL linking to the external documentation for this module. Displayed in the platform UI as a help reference. Metadata only. {{UIMeta group=0 order=1 }} | `string` | `"https://github.com/techequitycloud/rad-modules/blob/main/docs/labs/Gemini_Enterprise.md"` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | List of cloud service tags associated with this module. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "GCP",<br>  "Gemini Enterprise",<br>  "Vertex AI",<br>  "Agent Runtime",<br>  "Agent Development Kit",<br>  "BigQuery",<br>  "Model Armor",<br>  "Cloud Storage",<br>  "Cloud IAM"<br>]</pre> | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID to prepare for the Gemini Enterprise demo. Must already exist and the service account must hold roles/owner. Use a project whose users are in the same Google Workspace / Cloud Identity domain as the instructor's sign-in (for Qwiklabs, the lab project with the student account). {{UIMeta group=1 order=101 }} | `string` | `null` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to false to restrict this module to platform administrators only. Set to true (the default) to make it visible and deployable by all platform users. {{UIMeta group=0 order=106 }} | `bool` | `true` | no |
| <a name="input_public_announcement_image"></a> [public\_announcement\_image](#input\_public\_announcement\_image) | Set to true (default) to make only the 'pool party.png' announcement image publicly readable, so it renders on the Gemini Enterprise home page for every user. Set to false in projects that enforce constraints/storage.publicAccessPrevention, and use an image hosted elsewhere for the announcement. {{UIMeta group=3 order=302 }} | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region the custom ADK agent is deployed to on Vertex AI Agent Runtime (e.g. 'us-central1'). Must be a region where Agent Runtime is available and permitted by any constraints/gcp.resourceLocations org policy. Defaults to 'us-central1'. {{UIMeta group=1 order=103 }} | `string` | `"us-central1"` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | When `true`, the module fee can be paid only from purchased credits (subscription or top-up), not from free awarded or event credits. {{UIMeta group=0 order=104 }} | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | Email of the Terraform service account used to provision resources (format: name@project-id.iam.gserviceaccount.com). Must hold roles/owner in the destination project. Leave empty to use Application Default Credentials. {{UIMeta group=0 order=107 updatesafe }} | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_shared_users"></a> [shared\_users](#input\_shared\_users) | List of users who can view and deploy this module regardless of the public_access setting. Enter one or more user email addresses. Metadata only — not referenced within the Terraform module execution; consumed by the deployment platform only. {{UIMeta group=0 order=107 }} | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_source_copy_cmd"></a> [agent\_source\_copy\_cmd](#output\_agent\_source\_copy\_cmd) | Cloud Shell command that downloads the ADK agent source, if you want to redeploy or edit it during class |
| <a name="output_announcement_image_url"></a> [announcement\_image\_url](#output\_announcement\_image\_url) | Image URL for the 'Annual pool party' Gemini Enterprise announcement |
| <a name="output_bigquery_table"></a> [bigquery\_table](#output\_bigquery\_table) | Fully qualified installation_requests table queried by the BigQuery agent |
| <a name="output_cymbal_docs_data_store"></a> [cymbal\_docs\_data\_store](#output\_cymbal\_docs\_data\_store) | Resource name of the data store indexing the Cymbal Pools documents |
| <a name="output_demo_bucket"></a> [demo\_bucket](#output\_demo\_bucket) | Cloud Storage bucket holding the demo documents, images, BigQuery seed data and ADK agent source |
| <a name="output_deployment_id"></a> [deployment\_id](#output\_deployment\_id) | Module Deployment ID |
| <a name="output_drive_documents_console_url"></a> [drive\_documents\_console\_url](#output\_drive\_documents\_console\_url) | Console page listing the documents to download and upload to Google Drive (lab Task 1) |
| <a name="output_gemini_enterprise_app_id"></a> [gemini\_enterprise\_app\_id](#output\_gemini\_enterprise\_app\_id) | Engine ID of the Gemini Enterprise app, or 'not created' when create_gemini_enterprise_app is false |
| <a name="output_gemini_enterprise_console_url"></a> [gemini\_enterprise\_console\_url](#output\_gemini\_enterprise\_console\_url) | Gemini Enterprise console page for the project |
| <a name="output_gemini_enterprise_location"></a> [gemini\_enterprise\_location](#output\_gemini\_enterprise\_location) | Gemini Enterprise location of the app — create the Drive/Calendar connectors and register the agent here too |
| <a name="output_model_armor_template"></a> [model\_armor\_template](#output\_model\_armor\_template) | Model Armor template resource name to enter under Configurations > Assistant > Enable Model Armor |
| <a name="output_oauth_redirect_uris"></a> [oauth\_redirect\_uris](#output\_oauth\_redirect\_uris) | Authorized redirect URIs to add to the Web OAuth client used by the Drive/Calendar connectors and the BigQuery agent authorization |
| <a name="output_ph_table_image_url"></a> [ph\_table\_image\_url](#output\_ph\_table\_image\_url) | Authenticated console URL of the pH table image used in the 'Convert this image to tabular data' demo |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | GCP Project ID |
| <a name="output_reasoning_engine"></a> [reasoning\_engine](#output\_reasoning\_engine) | Agent Runtime reasoning engine resource name to paste into Gemini Enterprise > Agents > Add agent |
<!-- END_TF_DOCS -->
