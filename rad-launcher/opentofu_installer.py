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

# Installs OpenTofu
# https://opentofu.org/docs/cli/install/

import os
import platform
import requests
import json
import sys

def get_latest_tofu_version():
    """Fetches the latest OpenTofu version from GitHub API."""
    url = "https://api.github.com/repos/opentofu/opentofu/releases/latest"
    try:
        print("Fetching latest OpenTofu version...")
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        version = data['tag_name'].lstrip('v')
        print(f"Latest OpenTofu version is {version}")
        return version
    except requests.exceptions.RequestException as e:
        print(f"Error fetching latest version: {e}", file=sys.stderr)
        return None
    except (KeyError, json.JSONDecodeError):
        print("Error parsing response from GitHub API.", file=sys.stderr)
        return None

def main():
    system = platform.system().lower()
    machine = platform.machine().lower()

    if 'darwin' in system or 'linux' in system:
        if 'x86_64' in machine:
            arch = 'amd64'
        elif 'aarch64' in machine or 'arm64' in machine:
            arch = 'arm64'
        else:
            arch = '386'

        version = get_latest_tofu_version()
        if not version:
            sys.exit(1)

        download_url = f"https://github.com/opentofu/opentofu/releases/download/v{version}/tofu_{version}_{system}_{arch}.zip"

        print(f"Downloading OpenTofu v{version} for {system}/{arch} from {download_url}")
        os.system(f"curl -L {download_url} --output opentofu_download.zip")
        os.system("unzip -o opentofu_download.zip")
        print("\nPlease enter your machine's password to complete installation (if requested)...\n")

        # Move to /usr/local/bin, a common directory for user-installed executables.
        if os.system(f"sudo mv {os.getcwd()}/tofu /usr/local/bin/") != 0:
            print("Failed to move tofu to /usr/local/bin/", file=sys.stderr)
            sys.exit(1)

        os.remove("opentofu_download.zip")
        print("OpenTofu installation complete. You can now use the 'tofu' command.")

    elif 'windows' in system:
        print("Detected Windows OS. Using Chocolatey for installation.")
        # Check if Chocolatey is installed
        if os.system("choco --version") != 0:
            print("Chocolatey is not installed. Attempting to install it now.")
            # Create installChocolatey.cmd
            with open('installChocolatey.cmd', 'w+') as f:
                f.write('@echo off\n\nSET DIR=%~dp0%\n\n::download install.ps1\n%systemroot%\System32\WindowsPowerShell\\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "((new-object net.webclient).DownloadFile('"'https://community.chocolatey.org/install.ps1'"','"'%DIR%install.ps1'"'))"\n::run installer\n%systemroot%\System32\WindowsPowerShell\\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '"'%DIR%install.ps1'"' %*"')

            # Install Chocolatey
            os.system('installChocolatey.cmd')

            # Delete installChocolatey.cmd & install.ps1
            os.remove('install.ps1')
            os.remove('installChocolatey.cmd')

        print("Installing OpenTofu using Chocolatey...")
        os.system('choco install opentofu -y')
        print("OpenTofu installation complete.")

    else:
        print(f"Unsupported operating system: {system}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()