/**
 * Copyright 2026 Google LLC
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

# The Model Armor template the instructor attaches live in class
# (Configurations > Assistant > Enable Model Armor). Each filter maps to one
# group of the lab's test prompts:
#   - sdp_settings.basic_config          -> "Sensitive Data Protection" (card numbers, credentials)
#   - rai_settings HARASSMENT (+ others) -> "Harassment Content Filter"
#   - pi_and_jailbreak_filter_settings   -> "Prompt Injection"
# Attaching it to the assistant is deliberately left to the instructor — it is
# a demo step, and doing it here would pre-empt the "before/after" moment.
resource "google_model_armor_template" "demo" {
  count       = var.create_model_armor_template ? 1 : 0
  project     = local.project.project_id
  location    = local.model_armor_loc
  template_id = local.model_armor_id

  filter_config {
    rai_settings {
      rai_filters {
        filter_type      = "HARASSMENT"
        confidence_level = var.model_armor_confidence
      }
      rai_filters {
        filter_type      = "HATE_SPEECH"
        confidence_level = var.model_armor_confidence
      }
      rai_filters {
        filter_type      = "DANGEROUS"
        confidence_level = var.model_armor_confidence
      }
      rai_filters {
        filter_type      = "SEXUALLY_EXPLICIT"
        confidence_level = var.model_armor_confidence
      }
    }

    sdp_settings {
      basic_config {
        filter_enforcement = "ENABLED"
      }
    }

    pi_and_jailbreak_filter_settings {
      filter_enforcement = "ENABLED"
      confidence_level   = var.model_armor_confidence
    }

    malicious_uri_filter_settings {
      filter_enforcement = "ENABLED"
    }
  }

  template_metadata {
    enforcement_type        = "INSPECT_AND_BLOCK"
    log_sanitize_operations = true
  }

  labels = {
    module     = "gemini-enterprise"
    deployment = lower(local.random_id)
  }

  depends_on = [google_project_service.enabled_services]
}
