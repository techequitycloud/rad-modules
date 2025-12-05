#!/bin/bash
# Copyright 2024 Tech Equity Ltd

set -e

export GIT_REPO=$GIT_REPO
export GIT_ORG=$GIT_ORG
export GITHUB_TOKEN=$GITHUB_TOKEN
export TRUSTED_USERS=$GIT_USERNAMES

# Get the absolute path to the scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================================"
echo "Initializing Git Repository"
echo "Repository: ${GIT_ORG}/${GIT_REPO}"
echo "Script directory: $SCRIPT_DIR"
echo "Module directory: $MODULE_DIR"
echo "================================================"

check_and_install_gh() {
    if command -v gh &> /dev/null; then
        echo "✓ GitHub CLI is already installed."
        gh --version
    else
        echo "Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh -y
        echo "✓ GitHub CLI installation completed."
    fi
}

authenticate_gh() {
    echo "Authenticating GitHub CLI..."
    
    if gh auth status &>/dev/null; then
        echo "✓ Already authenticated with GitHub CLI"
        return 0
    fi
    
    set +e
    echo "${GITHUB_TOKEN}" | gh auth login --with-token 2>&1 | tee /tmp/gh_auth.log
    set -e
    
    if gh auth status &>/dev/null; then
        echo "✓ Authentication successful"
        rm -f /tmp/gh_auth.log
        return 0
    else
        echo "✗ Authentication failed"
        cat /tmp/gh_auth.log
        rm -f /tmp/gh_auth.log
        exit 1
    fi
}

initialize_git_repo() {
    echo "Initializing local git repository..."
    
    # Configure git to use 'dev' as default branch
    git config --global init.defaultBranch dev
    
    if [ ! -d ".git" ]; then
        git init
        echo "✓ Git repository initialized with dev branch"
    else
        echo "✓ Git repository already exists"
    fi

    if git remote | grep -q 'origin'; then
        git remote set-url origin https://${GITHUB_TOKEN}@github.com/${GIT_ORG}/${GIT_REPO}.git
        echo "✓ Updated remote origin"
    else
        git remote add origin https://${GITHUB_TOKEN}@github.com/${GIT_ORG}/${GIT_REPO}.git
        echo "✓ Added remote origin"
    fi

    git config user.email "shiyghan.navti@techequity.cloud"
    git config user.name "Shiyghan Navti"
    git config pull.rebase false
    echo "✓ Git configuration complete"
}

check_remote_branch_exists() {
    local branch_name=$1
    git ls-remote --heads origin ${branch_name} 2>/dev/null | grep -q ${branch_name}
}

check_repo_exists() {
    gh api repos/${GIT_ORG}/${GIT_REPO} >/dev/null 2>&1
}

find_html_directory() {
    # Define the expected location based on directory structure
    local html_path="$MODULE_DIR/scripts/app/html"
    
    echo "Searching for html directory at: $html_path" >&2
    
    if [ -d "$html_path" ]; then
        echo "$html_path"
        return 0
    fi
    
    # Fallback locations
    local possible_paths=(
        "$SCRIPT_DIR/../app/html"
        "$SCRIPT_DIR/../../app/html"
        "./scripts/app/html"
        "scripts/app/html"
    )
    
    for path in "${possible_paths[@]}"; do
        echo "Checking: $path" >&2
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    echo "" >&2
    return 1
}

create_or_update_branch() {
    local branch_name=$1
    echo "================================================"
    echo "Processing branch: ${branch_name}"
    echo "================================================"

    # Fetch latest from remote
    git fetch origin 2>/dev/null || true

    # Check if branch exists remotely
    if check_remote_branch_exists ${branch_name}; then
        echo "Branch ${branch_name} exists remotely, checking out..."
        
        # Abort any ongoing rebase/merge
        git rebase --abort 2>/dev/null || true
        git merge --abort 2>/dev/null || true
        
        # Check if local branch exists
        if git rev-parse --verify ${branch_name} >/dev/null 2>&1; then
            git checkout ${branch_name}
            
            # Reset to remote state to avoid conflicts
            echo "Resetting to remote state..."
            git reset --hard origin/${branch_name}
            echo "✓ Reset local branch to match remote: ${branch_name}"
        else
            git checkout -b ${branch_name} origin/${branch_name}
            echo "✓ Created local branch from remote: ${branch_name}"
        fi
    else
        echo "Branch ${branch_name} does not exist remotely, creating..."
        
        if git rev-parse --verify ${branch_name} >/dev/null 2>&1; then
            git checkout ${branch_name}
            echo "✓ Switched to existing local branch: ${branch_name}"
        else
            git checkout -b ${branch_name}
            echo "✓ Created new local branch: ${branch_name}"
        fi
    fi

    # Find html directory BEFORE any operations
    echo "Looking for html directory..."
    HTML_SOURCE=$(find_html_directory)
    
    if [ -z "$HTML_SOURCE" ]; then
        echo "✗ html folder not found in any expected location"
        echo "Module directory: $MODULE_DIR"
        echo "Script directory: $SCRIPT_DIR"
        echo "Current directory: $(pwd)"
        echo ""
        echo "Directory structure:"
        ls -la "$MODULE_DIR/scripts/" 2>/dev/null || echo "scripts/ not found"
        ls -la "$MODULE_DIR/scripts/app/" 2>/dev/null || echo "scripts/app/ not found"
        exit 1
    fi
    
    echo "✓ Found html directory at: $HTML_SOURCE"

    # Create README
    cat > README.md << EOF
# ${GIT_REPO}

Banking Portal Application - ${branch_name} environment

This repository contains the web application files.
Additional configuration files will be added by the CI/CD pipeline.

## Branch: ${branch_name}

This branch is automatically managed by Terraform.
EOF
    echo "✓ Created README.md"

    # Remove existing html directory if it exists
    if [ -d "html" ]; then
        rm -rf html
        echo "✓ Removed old html directory"
    fi
    
    # Copy html directory
    cp -r "$HTML_SOURCE" html
    echo "✓ Copied html directory to branch"
    
    # Verify copy
    if [ ! -d "html" ]; then
        echo "✗ Failed to copy html directory"
        exit 1
    fi
    
    # List contents to verify
    echo "HTML directory contents:"
    ls -la html/ | head -10
    
    # Add files
    git add -A
    
    # Check if there are changes to commit
    if ! git diff --staged --quiet; then
        git commit -m "Update html folder and README for ${branch_name} branch"
        echo "✓ Committed changes to ${branch_name}"
    else
        echo "✓ No changes to commit in ${branch_name}"
    fi

    # Push to remote
    if check_remote_branch_exists ${branch_name}; then
        echo "Pushing to existing remote branch..."
        git push -f origin ${branch_name}
        echo "✓ Successfully force pushed ${branch_name}"
    else
        echo "Pushing new branch to remote..."
        git push -u origin ${branch_name}
        echo "✓ Successfully pushed new branch ${branch_name}"
    fi
}

grant_write_access() {
    echo "================================================"
    echo "Granting write access to trusted users..."
    echo "================================================"
    
    if [[ -z "$TRUSTED_USERS" ]]; then
        echo "⚠ No trusted users specified"
        return 0
    fi
    
    IFS=',' read -ra USERS <<< "$TRUSTED_USERS"
    
    for username in "${USERS[@]}"; do
        username=$(echo "$username" | xargs)
        if [[ -z "$username" ]]; then
            continue
        fi
        
        echo "Adding collaborator: $username"
        
        if gh api repos/${GIT_ORG}/${GIT_REPO}/collaborators/${username} \
            --method PUT \
            --field permission=write 2>/dev/null; then
            echo "✅ Success: $username"
        else
            echo "❌ Failed: $username (may already have access)"
        fi
    done
}

# Main execution
check_and_install_gh
authenticate_gh

# Check if repository exists
if ! check_repo_exists; then
    echo "✗ Repository ${GIT_ORG}/${GIT_REPO} does not exist"
    echo "Please create the repository first"
    exit 1
fi

initialize_git_repo

# Fetch all remote branches first
git fetch origin 2>/dev/null || true

# Create/update branches in order: dev, qa, prod
create_or_update_branch dev
create_or_update_branch qa
create_or_update_branch prod

grant_write_access

echo "================================================"
echo "✓ Repository initialization complete!"
echo "Repository: https://github.com/${GIT_ORG}/${GIT_REPO}"
echo "Branches: dev, qa, prod"
echo "================================================"

if [ "${CLEANUP_GIT}" = "true" ]; then
    echo "Cleaning up .git directory (CLEANUP_GIT=true)..."
    rm -rf .git
else
    echo "Keeping .git directory for Terraform state management"
fi
