#!/bin/bash
# Copyright 2024 Tech Equity Ltd
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

# Check if gh is installed
if command -v gh &> /dev/null
then
    echo "GitHub CLI is already installed."
    gh --version
else
    echo "GitHub CLI not found. Installing..."

    # Import the GitHub CLI repository GPG key
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

    # Add the GitHub CLI repository to the system's software repository list
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

    # Update the system's package index
    sudo apt update

    # Install the GitHub CLI
    sudo apt install gh -y

    echo "GitHub CLI installation completed."
fi

# Authenticate gh CLI with your GitHub token
echo "Authenticating GitHub CLI..."
echo ${GITHUB_TOKEN} | gh auth login --with-token

# Delete the specified repository
# echo "Deleting repository ${GIT_ORG}/${PROJECT_ID}..."
# gh repo delete ${GIT_ORG}/${PROJECT_ID} --confirm

# echo "Repository ${GIT_ORG}/${PROJECT_ID} has been deleted."

