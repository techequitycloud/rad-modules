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

#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if git is installed
if ! command_exists git; then
    echo "git is not installed. Please install it to proceed."
    exit 1
fi

# Check if jq is installed
if ! command_exists jq; then
    echo "jq is not installed. Please install it to proceed."
    exit 1
fi

# Set variables
REPO_NAME=$GIT_REPO
GITHUB_TOKEN=$GITHUB_TOKEN
GITHUB_USERNAMES=$GIT_USERNAMES

# Clone the repository
git clone https://${GITHUB_TOKEN}@github.com/${GIT_ORG}/${REPO_NAME}.git
cd ${REPO_NAME} || exit

# Configure git
git config user.email "ci-bot@example.com"
git config user.name "CI Bot"

# Function to create or update a branch
create_or_update_branch() {
    local branch_name=$1
    if git show-ref --verify --quiet refs/heads/${branch_name}; then
        echo "Branch ${branch_name} already exists. Switching to it."
        git checkout ${branch_name}
    else
        echo "Creating branch ${branch_name}."
        git checkout -b ${branch_name}
    fi
}

# Function to commit and push changes
commit_and_push() {
    local branch_name=$1
    local commit_message=$2

    # Add all files in the current directory (including dotfiles)
    git add -A

    # Commit changes
    git commit -m "${commit_message}"

    # Push changes
    git push -u origin ${branch_name}
}

# Function to check if a user is already a collaborator
is_collaborator() {
    local username=$1
    local repo_owner=$GIT_ORG
    local repo_name=$REPO_NAME
    local token=$GITHUB_TOKEN

    local status_code=$(curl -s -o /dev/null -w "%%{http_code}" \
        -H "Authorization: token ${token}" \
        "https://api.github.com/repos/${repo_owner}/${repo_name}/collaborators/${username}")

    if [ "$status_code" -eq 204 ]; then
        return 0 # User is a collaborator
    else
        return 1 # User is not a collaborator
    fi
}

# Function to add collaborators
add_collaborators() {
    local usernames=$1
    local repo_owner=$GIT_ORG
    local repo_name=$REPO_NAME
    local token=$GITHUB_TOKEN

    # Split the comma-separated string into an array
    IFS=',' read -r -a username_array <<< "$usernames"

    for username in "${username_array[@]}"; do
        if is_collaborator "$username"; then
            echo "User $username is already a collaborator."
        else
            echo "Adding user $username as a collaborator..."
            curl -s -X PUT \
                -H "Authorization: token ${token}" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/repos/${repo_owner}/${repo_name}/collaborators/${username}" \
                -d '{"permission":"push"}'
        fi
    done
}

# Main script logic
if [[ "${branch_name}" == "main" ]]; then
    create_or_update_branch ${branch_name}

    # Copy files for the branch (this part assumes files are copied to the repo directory before running this script)
    # In a real scenario, you might copy files from a source directory or generate them here.
    # For this example, we assume files are present in the current directory.

    commit_and_push ${branch_name} "Initial commit for ${branch_name} branch"
else
    # If branch_name is not specified or empty, default to creating all branches

    # Create main branch
    create_or_update_branch main
    # Add main branch specific files/configurations here if needed
    commit_and_push main "Initial commit for main branch"

fi

# Add collaborators
if [ -n "$GITHUB_USERNAMES" ]; then
    add_collaborators "$GITHUB_USERNAMES"
fi

# Clean up
cd ..
rm -rf ${REPO_NAME}
