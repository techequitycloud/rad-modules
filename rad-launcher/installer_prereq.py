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

import os
import shutil
import sys

def main():

    # Install python dependencies.
    print("\nInstalling Libraries...")
    if os.system("pip3 install --no-cache-dir -r requirements.txt") != 0:
        print("Failed to install Python dependencies from requirements.txt")
        sys.exit(1)

    # Check if OpenTofu is already installed by looking up the binary.
    if shutil.which("tofu") is None:
        print("\nOpenTofu not installed. Starting installation...\n")
        if os.system("python3 opentofu_installer.py") != 0:
            print("OpenTofu installation failed.")
            sys.exit(1)
    else:
        print("\nOpenTofu already installed. Skipping installation...\n")

    # Print OpenTofu version
    os.system("tofu -version")

    # Set up Cloud SDK & kubectl
    if os.system("python3 cloudsdk_kubectl_installer.py") != 0:
        print("Cloud SDK / kubectl installation step reported an error.")

    print("\nPRE-REQ INSTALLATION COMPLETED\n")

if __name__ == "__main__":
    main()