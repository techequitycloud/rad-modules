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
"""Prints the Authorization URI to paste into Gemini Enterprise's "Add Authorization" form.

Usage: replace OAUTH_CLIENT_ID below (or export OAUTH_CLIENT_ID), then
    python3 ./construct_auth_uri.py
"""

import os
from urllib.parse import urlencode

OAUTH_CLIENT_ID = os.environ.get("OAUTH_CLIENT_ID", "YOUR_OAUTH_CLIENT_ID")

# Gemini Enterprise completes the OAuth handshake on this redirect URI; it must
# also be listed under "Authorized redirect URIs" on the OAuth client.
REDIRECT_URI = "https://vertexaisearch.cloud.google.com/oauth-redirect"

SCOPES = [
    "https://www.googleapis.com/auth/bigquery",
    "https://www.googleapis.com/auth/cloud-platform",
]

params = {
    "client_id": OAUTH_CLIENT_ID,
    "redirect_uri": REDIRECT_URI,
    "scope": " ".join(SCOPES),
    "include_granted_scopes": "true",
    "response_type": "code",
    "access_type": "offline",
    "prompt": "consent",
}

if OAUTH_CLIENT_ID == "YOUR_OAUTH_CLIENT_ID":
    raise SystemExit("Set OAUTH_CLIENT_ID in this file (or export it) first.")

print()
print("https://accounts.google.com/o/oauth2/v2/auth?" + urlencode(params))
print()
