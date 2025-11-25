# GCP_Project Module

## Problem Solved

The `GCP_Project` module provides a standardized and automated way to create new Google Cloud Platform projects. It ensures that new projects are set up with consistent configurations, including billing accounts, billing budgets, and essential APIs, from the moment of creation. This helps organizations maintain control over their cloud environments, prevent shadow IT, and streamline the project setup process.

## Major Features and Capabilities

*   **Project Creation:** The core feature of the module is to create a new GCP project. It can create a project within a specified folder or directly under the organization. The project ID is generated with a prefix and a random suffix to ensure uniqueness.
*   **Billing Account Association:** It associates the newly created project with a specified billing account.
*   **Billing Budget:** Configures a billing budget for the project to control costs.
*   **API Enablement:** The module automatically enables a predefined list of essential APIs (`cloudresourcemanager.googleapis.com` and `serviceusage.googleapis.com`) on the new project. This can be toggled on or off.
*   **IAM Permissions:** It can grant a list of specified users the "Viewer" role on the created project.
*   **Deletion Policy:** The project is configured with a `DELETE` deletion policy, meaning the project will be deleted when the Terraform resource is destroyed.
*   **Customizable Deployment ID:** Allows for a custom suffix for the project ID, or generates a random one if not provided.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| billing\_account\_id | Billing Account associated to the GCP Resources. | `string` | n/a | yes |
| billing\_budget\_alert\_spend\_basis | The type of basis used to determine if spend has passed the threshold. | `string` | `"CURRENT_SPEND"` | no |
| billing\_budget\_alert\_spent\_percents | A list of percentages of the budget to alert on when threshold is exceeded. | `list(number)` | `[0.5, 0.7, 1]` | no |
| billing\_budget\_amount | The amount to use as the budget. | `number` | `500` | no |
| billing\_budget\_amount\_currency\_code | The 3-letter currency code defined in ISO 4217. | `string` | `"USD"` | no |
| billing\_budget\_credit\_types\_treatment | Specifies how credits should be treated when determining spend for threshold calculations. | `string` | `"INCLUDE_ALL_CREDITS"` | no |
| billing\_budget\_notification\_email\_addresses | A list of email addresses which will be recieving billing budget notification alerts. | `list(string)` | `[]` | no |
| create\_budget | If the budget should be created. | `bool` | `true` | no |
| create\_project | Set to true if the module has to create a project. | `bool` | `true` | no |
| deployment\_id | Unique ID suffix for resources. Leave blank to generate random ID. | `string` | `null` | no |
| enable\_services | Enable the necessary APIs on the project. | `bool` | `true` | no |
| folder\_id | The ID of the folder where the project will be created. This is the recommended way to organize projects. | `string` | `""` | no |
| module\_folder\_id | The ID of the RAD UI folder. This is used for RAD UI integration and should not be set manually. | `string` | `""` | no |
| organization\_id | Organization ID where GCP Resources need to get spin up. Used if `folder_id` is not provided. | `string` | `""` | no |
| project\_id\_prefix | If create\_project is true, this will be the prefix of the Project ID & name created. | `string` | `"project-with-budget"` | no |
| trusted\_users | A list of user emails to be granted the "Viewer" role. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| project\_id | The ID of the project |
