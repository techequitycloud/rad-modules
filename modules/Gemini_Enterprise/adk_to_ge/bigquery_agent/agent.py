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
"""BigQuery Pool Data Agent for the Cymbal Pools Gemini Enterprise demo."""

import os

import google.auth
from google.adk.agents import Agent
from google.adk.tools.bigquery import BigQueryCredentialsConfig, BigQueryToolset
from google.adk.tools.bigquery.config import BigQueryToolConfig, WriteMode

# `adk deploy agent_engine --region X` forces GOOGLE_CLOUD_LOCATION=X in the
# container, overriding any value in .env. Newer Gemini models are served only
# from the "global" endpoint, so the model location is carried separately and
# applied here, before the model client is created.
if os.environ.get("MODEL_LOCATION"):
    os.environ["GOOGLE_CLOUD_LOCATION"] = os.environ["MODEL_LOCATION"]

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "")
DATASET_ID = os.environ.get("BQ_DATASET", "cymbal_pools")
TABLE_ID = os.environ.get("BQ_TABLE", "installation_requests")

# AUTH_ID names the Gemini Enterprise Authorization resource (e.g. "bq-auth").
# When set, Gemini Enterprise puts the end user's OAuth access token into
# session state under that key and queries run as the signed-in user. When
# empty, queries run as the Agent Runtime service agent, which the module
# grants BigQuery User + Data Editor -- so the demo works even before any
# OAuth client has been registered.
AUTH_ID = os.environ.get("AUTH_ID", "")

if AUTH_ID:
    credentials_config = BigQueryCredentialsConfig(external_access_token_key=AUTH_ID)
else:
    adc, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/bigquery"])
    credentials_config = BigQueryCredentialsConfig(credentials=adc)

bigquery_toolset = BigQueryToolset(
    credentials_config=credentials_config,
    bigquery_tool_config=BigQueryToolConfig(
        write_mode=WriteMode.ALLOWED,
        default_project_id=PROJECT_ID or None,
        default_dataset_id=DATASET_ID,
        application_name="cymbal-pools-ge-demo",
    ),
)

root_agent = Agent(
    name="bigquery_agent",
    model=os.environ.get("MODEL", "gemini-3.5-flash"),
    description="Queries and records Cymbal Pools pool installation requests in BigQuery.",
    instruction=f"""
You are the Cymbal Pools installation data assistant. You answer questions about
pool installation requests stored in BigQuery and record new requests.

Data location:
- Project: {PROJECT_ID}
- Dataset: {DATASET_ID}
- Table:   {TABLE_ID}  (fully qualified: `{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}`)

Rules:
- Always use fully qualified table names in SQL.
- Before answering a data question, inspect the table schema if you have not yet.
- Dimensions are in metres; pool volume is length_m * width_m * depth_m (cubic metres).
- To record a new request, first list the fields you need. Once the user supplies
  them, generate the next request_id (REQ- followed by one more than the current
  highest number), use CURRENT_DATE() when the user says "today", and INSERT one row.
- Only ever INSERT into or SELECT from {TABLE_ID}. Never UPDATE, DELETE, DROP or
  create tables.
- After running a query, briefly state what you ran and summarise the result as a
  table when there are multiple rows.
""",
    tools=[bigquery_toolset],
)
