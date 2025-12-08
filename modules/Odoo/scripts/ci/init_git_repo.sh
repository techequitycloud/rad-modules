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

export GIT_REPO=$GIT_REPO
export GIT_ORG=$GIT_ORG
if [ -z "$GITHUB_TOKEN" ]; then
  read -r GITHUB_TOKEN
  export GITHUB_TOKEN
fi
export TRUSTED_USERS=$GIT_USERNAMES

check_and_install_gh() {
    if command -v gh &> /dev/null; then
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
}

authenticate_gh() {
    echo "Authenticating GitHub CLI..."
    echo ${GITHUB_TOKEN} | gh auth login --with-token
}

initialize_git_repo() {
    if [ ! -d ".git" ]; then
        git init
    fi

    if git remote | grep -q 'origin'; then
        git remote set-url origin https://${GITHUB_TOKEN}@github.com/${GIT_ORG}/${GIT_REPO}.git
    else
        git remote add origin https://${GITHUB_TOKEN}@github.com/${GIT_ORG}/${GIT_REPO}.git
    fi

    git config --global user.email "shiyghan.navti@techequity.cloud"
    git config --global user.name "Shiyghan Navti"
    git config pull.rebase true
}

create_branch_via_api() {
    local branch_name=$1
    local sha=$2

    echo "Creating branch ${branch_name} via GitHub API..."
    gh api repos/${GIT_ORG}/${GIT_REPO}/git/refs \
        -f ref=refs/heads/${branch_name} \
        -f sha=${sha}
}

create_or_update_branch() {
    local branch_name=$1

    if ! git rev-parse --verify ${branch_name} >/dev/null 2>&1; then
        git checkout -b ${branch_name}
    else
        git checkout ${branch_name}
        git stash push -u -m "Temporarily stashing untracked files before pulling"
        git pull
        git stash pop || true  # Ignore error if there's nothing to pop
    fi

    if [[ "${branch_name}" == "dev" || "${branch_name}" == "qa" || "${branch_name}" == "prod" ]]; then
        cp -r ../app/addons .
        git add addons
        git commit -m "Add addons folder to ${branch_name} branch"
    fi

    git push -u origin ${branch_name}
}

check_branch_exists_via_api() {
    local branch_name=$1

    gh api repos/${GIT_ORG}/${GIT_REPO}/branches/${branch_name} >/dev/null 2>&1
}

grant_write_access() {
    echo "Granting write access to trusted users..."
    
    if [[ -z "$TRUSTED_USERS" ]]; then
        echo "No trusted users specified"
        return 0
    fi
    
    IFS=',' read -ra USERS <<< "$TRUSTED_USERS"
    
    for username in "${USERS[@]}"; do
        username=$(echo "$username" | xargs)
        echo "Adding collaborator: $username"
        
        if gh api repos/${GIT_ORG}/${GIT_REPO}/collaborators/${username} \
            --method PUT \
            --field permission=write; then
            echo "✅ Success: $username"
        else
            echo "❌ Failed: $username"
        fi
    done
}

check_and_install_gh
authenticate_gh
initialize_git_repo

if ! check_branch_exists_via_api main; then
    echo "Banking Portal on GKE" > README.md
    git add README.md
    git commit -m "Initialize main branch with README"
    git push -u origin main

    MAIN_SHA=$(git rev-parse HEAD)
    create_branch_via_api main ${MAIN_SHA}
else
    git checkout main
    git pull
fi

create_or_update_branch dev
create_or_update_branch qa
create_or_update_branch prod

grant_write_access

rm -rf .git
