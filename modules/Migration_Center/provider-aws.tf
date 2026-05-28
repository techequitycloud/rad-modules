/**
 * Copyright 2024 Google LLC
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

# The AWS provider is configured with the bootstrap credentials supplied by
# the user. When aws_access_key_id is empty, the skip_* flags prevent the
# provider from contacting AWS at plan/apply time; all AWS resources are
# gated with count = var.aws_access_key_id != "" ? 1 : 0 and are never
# created in that case.
provider "aws" {
  # When no real credentials are supplied, use placeholder values so the provider
  # does not fall through to the credential chain (env vars, IMDS, etc.).
  # The skip_* flags combined with count-gated resources ensure no AWS API calls
  # are made when aws_access_key_id is empty.
  access_key = var.aws_access_key_id != "" ? var.aws_access_key_id : "placeholder"
  secret_key = var.aws_secret_access_key != "" ? var.aws_secret_access_key : "placeholder"
  region     = var.aws_region

  skip_credentials_validation = var.aws_access_key_id == ""
  skip_requesting_account_id  = var.aws_access_key_id == ""
  skip_metadata_api_check     = true
}
