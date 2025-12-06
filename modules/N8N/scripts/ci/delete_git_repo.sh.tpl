#!/bin/bash

# set -x

# Copyright 2024 Tech Equity Ltd

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
