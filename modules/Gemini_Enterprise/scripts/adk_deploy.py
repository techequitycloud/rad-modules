#!/usr/bin/env python3
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Runs the stock `adk` CLI as the module's resource_creator_identity.

`adk deploy agent_engine` authenticates with google.auth.default() and has no
impersonation flag. Every other resource in this module is created as
var.resource_creator_identity via provider impersonation, so the Agent Engine
must be too — otherwise it is created as whatever ADC the runner happens to
hold (the Cloud Build SA, or an operator's personal login), which may lack
access to the project entirely.

When IMPERSONATE_SERVICE_ACCOUNT is set, google.auth.default() is replaced
BEFORE the ADK is imported, so every client the CLI builds picks up
short-lived impersonated credentials. Unset, this is exactly `adk`.

Usage: python3 adk_deploy.py deploy agent_engine [adk args...]
"""

import os
import sys

import google.auth
from google.auth import impersonated_credentials

CLOUD_PLATFORM = "https://www.googleapis.com/auth/cloud-platform"
target = os.environ.get("IMPERSONATE_SERVICE_ACCOUNT", "").strip()

if target:
    _original_default = google.auth.default

    def _impersonated_default(scopes=None, **kwargs):
        source, project = _original_default(scopes=[CLOUD_PLATFORM])
        creds = impersonated_credentials.Credentials(
            source_credentials=source,
            target_principal=target,
            target_scopes=list(scopes) if scopes else [CLOUD_PLATFORM],
            lifetime=3600,
        )
        return creds, project or os.environ.get("GOOGLE_CLOUD_PROJECT")

    google.auth.default = _impersonated_default
    print(f"adk_deploy: impersonating {target}", flush=True)

from google.adk.cli.cli_tools_click import main  # noqa: E402  (must follow the patch)

sys.argv[0] = "adk"
sys.exit(main())
