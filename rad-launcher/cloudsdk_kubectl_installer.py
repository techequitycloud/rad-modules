#!/usr/bin/python3

# Copyright 2023 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#https://cloud.google.com/sdk/docs/downloads-interactive

import os
import platform
import shutil
import tempfile


def main():
    # curl & bash must already be installed on the local OS.
    # Not required for Cloud Shell.

    system = platform.system().lower()
    node = platform.node().lower()

    if 'linux' in system and 'cs-' in node:
        print("Detected Cloud Shell, skipping Cloud SDK & kubectl installation...")
        return

    # Skip re-installation if gcloud is already on PATH.
    if shutil.which("gcloud") is not None:
        print("gcloud already installed, skipping Cloud SDK installation...")
    else:
        # Download and run the Cloud SDK installer into a temp file so we don't
        # clobber the committed install.sh shipped alongside this script.
        with tempfile.NamedTemporaryFile(suffix=".sh", delete=False) as tmp:
            tmp_path = tmp.name
        try:
            if os.system(f"curl -fsSL https://sdk.cloud.google.com > {tmp_path}") != 0:
                print("Failed to download Cloud SDK install script.")
                return
            if os.system(f"bash {tmp_path} --disable-prompts") != 0:
                print("Cloud SDK install script reported an error.")
                return
        finally:
            try:
                os.remove(tmp_path)
            except OSError:
                pass

    # Install kubectl component (gcloud may require sudo depending on install location).
    os.system("gcloud components install kubectl --quiet || sudo gcloud components install kubectl --quiet")


if __name__ == "__main__":
    main()