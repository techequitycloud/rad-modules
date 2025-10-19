# GCP Project

This Terraform module creates a new Google Cloud project and configures a billing budget for it.

## Purpose

The main purpose of this module is to provide a standardized way to create new projects with budget controls in place from the start. This helps to prevent unexpected costs and ensures that all new projects adhere to the organization's spending policies.

## Usage

To use this module, you need to provide the following information:

- `project_id_prefix`: A prefix for the new project's ID.
- `folder_id`: The ID of the folder where the project will be created.
- `billing_account_id`: The ID of the billing account to associate with the project.

You can also customize the budget by providing the following variables:

- `billing_budget_amount`: The amount of the budget.
- `billing_budget_alert_spent_percents`: A list of percentages of the budget at which to send alerts.
- `billing_budget_notification_email_addresses`: A list of email addresses to receive budget alerts.

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
| folder\_id | Folder ID where the project should be created. | `string` | `""` | no |
| organization\_id | Organization ID where GCP Resources need to get spin up. | `string` | `""` | no |
| project\_id | The ID of the project. | `string` | `""` | no |
| project\_id\_prefix | If create\_project is true, this will be the prefix of the Project ID & name created. | `string` | `"project-with-budget"` | no |

## Outputs

| Name | Description |
|------|-------------|
| project\_id | The ID of the project |
| billing\_budget\_budget\_id | Resource name of the budget. |
