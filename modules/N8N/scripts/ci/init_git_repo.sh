#!/bin/bash
# Copyright 2024 (c) Tech Equity Ltd
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

set -e

# Function to check if a branch exists
create_or_update_branch() {
    local branch_name=$1
    echo "Processing branch: ${branch_name}"

    if ! git rev-parse --verify ${branch_name} >/dev/null 2>&1; then
        echo "Creating branch ${branch_name}..."
        git checkout -b ${branch_name}
        git push -u origin ${branch_name}
    else
        echo "Branch ${branch_name} already exists."
        git checkout ${branch_name}
        git pull origin ${branch_name}
    fi
}

# Install GitHub CLI if not present
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI not found. Installing..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
fi

# Authenticate GitHub CLI
echo "${GITHUB_TOKEN}" | gh auth login --with-token

# Configure git
git config --global user.email "terraform@example.com"
git config --global user.name "Terraform"

# Clone or initialize the repository
if gh repo view ${GIT_ORG}/${GIT_REPO} >/dev/null 2>&1; then
    echo "Repository ${GIT_REPO} exists."
    git clone https://${GITHUB_TOKEN}@github.com/${GIT_ORG}/${GIT_REPO}.git .
else
    echo "Repository ${GIT_REPO} does not exist. Creating..."
    gh repo create ${GIT_ORG}/${GIT_REPO} --private
    git clone https://${GITHUB_TOKEN}@github.com/${GIT_ORG}/${GIT_REPO}.git .
    echo "# ${GIT_REPO}" > README.md
    git add README.md
    git commit -m "Initial commit"
    git branch -M main
    git push -u origin main
fi

# Add collaborators
IFS=',' read -ra ADDR <<< "${GIT_USERNAMES}"
for username in "${ADDR[@]}"; do
    echo "Adding collaborator: $username"
    gh api -X PUT repos/${GIT_ORG}/${GIT_REPO}/collaborators/${username} -f permission=push >/dev/null 2>&1 || echo "Failed to add $username"
done
