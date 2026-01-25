#!/bin/bash
# create_module.sh - Universal Module Creation Script (Complete)
# Location: rad-modules/scripts/create_module.sh
# Usage: ./create_module.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAD_MODULES_ROOT="$(dirname "$SCRIPT_DIR")"
MODULES_DIR="$RAD_MODULES_ROOT/modules"
WEBAPP_DIR="$MODULES_DIR/WebApp"

# Function to convert string to lowercase (Bash 3.2 compatible)
to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_highlight() {
    echo -e "${CYAN}🔍 $1${NC}"
}

print_section() {
    echo -e "${MAGENTA}📋 $1${NC}"
}

# Function to validate prerequisites
validate_prerequisites() {
    print_info "Validating prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "$RAD_MODULES_ROOT/README.md" ]]; then
        print_error "This script must be run from the rad-modules repository"
        print_info "Current directory: $(pwd)"
        print_info "Expected rad-modules root: $RAD_MODULES_ROOT"
        exit 1
    fi
    
    # Check if WebApp directory exists
    if [[ ! -d "$WEBAPP_DIR" ]]; then
        print_error "WebApp directory not found at: $WEBAPP_DIR"
        print_info "Please ensure the WebApp module exists in the modules directory"
        exit 1
    fi
    
    # Check if WebApp has required files
    if [[ ! -f "$WEBAPP_DIR/main.tf" ]]; then
        print_error "WebApp directory is missing required files (main.tf not found)"
        exit 1
    fi
    
    print_status "Prerequisites validated"
}

# Function to get existing modules
get_existing_modules() {
    local modules=()
    
    # Get all directories in modules/ except WebApp
    if [[ -d "$MODULES_DIR" ]]; then
        for module_dir in "$MODULES_DIR"/*; do
            if [[ -d "$module_dir" ]]; then
                local module_name=$(basename "$module_dir")
                # Skip WebApp as it's the base module
                if [[ "$module_name" != "WebApp" ]]; then
                    modules+=("$module_name")
                fi
            fi
        done
    fi
    
    # Sort modules
    printf '%s\n' "${modules[@]}" | sort -u
}

# Function to display existing modules
display_existing_modules() {
    local existing_modules=($(get_existing_modules))
    
    print_section "Existing Modules in rad-modules:"
    
    if [[ ${#existing_modules[@]} -eq 0 ]]; then
        print_info "  No custom modules found (only WebApp base module exists)"
        print_info "  This will be your first custom module! 🎉"
    else
        print_info "  Found ${#existing_modules[@]} existing module(s):"
        for i in "${!existing_modules[@]}"; do
            printf "    %2d) %s\n" $((i+1)) "${existing_modules[i]}"
        done
        print_warning "Choose a different name to avoid conflicts"
    fi
    echo
}

# Function to get available applications from WebApp
get_available_apps() {
    local apps=()
    
    # Get apps from WebApp/modules directory
    if [[ -d "$WEBAPP_DIR/modules" ]]; then
        for app_dir in "$WEBAPP_DIR/modules"/*; do
            if [[ -d "$app_dir" ]]; then
                apps+=($(basename "$app_dir"))
            fi
        done
    fi
    
    # Get apps from WebApp terraform files (*.tf files that aren't infrastructure)
    for tf_file in "$WEBAPP_DIR"/*.tf; do
        if [[ -f "$tf_file" ]]; then
            local filename=$(basename "$tf_file" .tf)
            # Skip infrastructure files
            case "$filename" in
                main|variables|versions|provider-auth|iam|network|storage|sql|nfs|secrets|service|registry|sa|outputs|modules|monitoring|jobs|buildappcontainer|trigger)
                    ;;
                *)
                    apps+=("$filename")
                    ;;
            esac
        fi
    done
    
    # Remove duplicates and sort
    printf '%s\n' "${apps[@]}" | sort -u
}

# Function to check if module name conflicts with existing modules
check_module_name_conflict() {
    local module_name="$1"
    local module_name_lower=$(to_lowercase "$module_name")
    local existing_modules=($(get_existing_modules))
    
    # Check for exact match (case-insensitive)
    for existing_module in "${existing_modules[@]}"; do
        local existing_lower=$(to_lowercase "$existing_module")
        if [[ "$module_name_lower" == "$existing_lower" ]]; then
            return 0  # Conflict found
        fi
    done
    
    # Check if it conflicts with WebApp
    if [[ "$module_name_lower" == "webapp" ]]; then
        return 0  # Conflict found
    fi
    
    return 1  # No conflict
}

# Function to suggest alternative module names
suggest_alternative_names() {
    local base_name="$1"
    local suggestions=()
    
    # Generate suggestions
    suggestions+=("My${base_name}")
    suggestions+=("${base_name}Custom")
    suggestions+=("${base_name}Pro")
    suggestions+=("${base_name}Enterprise")
    suggestions+=("Company${base_name}")
    suggestions+=("${base_name}2024")
    
    print_info "💡 Suggested alternative names:"
    for i in "${!suggestions[@]}"; do
        # Check if suggestion also conflicts
        if ! check_module_name_conflict "${suggestions[i]}"; then
            printf "    • %s\n" "${suggestions[i]}"
        fi
    done
}

# Function to prompt user for module name and app
prompt_user_input() {
    # Display existing modules first
    display_existing_modules
    
    # Get module name with conflict checking FIRST
    while true; do
        read -p "Enter the new module name (e.g., 'MyOdoo', 'CompanyERP'): " MODULE_NAME
        
        # Check if empty
        if [[ -z "$MODULE_NAME" ]]; then
            print_error "Module name cannot be empty"
            continue
        fi
        
        # Check for invalid characters
        if [[ ! "$MODULE_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
            print_error "Invalid module name. Use only letters, numbers, underscores, and hyphens. Must start with a letter."
            continue
        fi
        
        # Check for conflicts
        if check_module_name_conflict "$MODULE_NAME"; then
            print_error "Module name '$MODULE_NAME' conflicts with existing module or reserved name"
            suggest_alternative_names "$MODULE_NAME"
            echo
            continue
        fi
        
        # Check if directory would be created successfully
        if [[ -d "$MODULES_DIR/$MODULE_NAME" ]]; then
            print_error "Directory '$MODULES_DIR/$MODULE_NAME' already exists"
            continue
        fi
        
        # Name is valid
        print_status "Module name '$MODULE_NAME' is available! ✨"
        break
    done
    
    echo
    
    # NOW display available applications AFTER module name is entered
    local available_apps=($(get_available_apps))
    print_section "Available Applications in WebApp:"
    for i in "${!available_apps[@]}"; do
        printf "  %2d) %s\n" $((i+1)) "${available_apps[i]}"
    done
    echo
    
    # Get application to base the module on
    while true; do
        read -p "Enter the application name to base this module on (or number from list above): " APP_INPUT
        
        if [[ "$APP_INPUT" =~ ^[0-9]+$ ]]; then
            # User entered a number
            local app_index=$((APP_INPUT - 1))
            if [[ $app_index -ge 0 && $app_index -lt ${#available_apps[@]} ]]; then
                APP_NAME="${available_apps[app_index]}"
                break
            else
                print_error "Invalid selection. Please choose a number between 1 and ${#available_apps[@]}"
                continue
            fi
        else
            # User entered an app name directly
            APP_NAME="$APP_INPUT"
            # Validate app exists
            local app_found=false
            for app in "${available_apps[@]}"; do
                if [[ "$app" == "$APP_NAME" ]]; then
                    app_found=true
                    break
                fi
            done
            
            if [[ "$app_found" == true ]]; then
                break
            else
                print_error "Application '$APP_NAME' not found in WebApp"
                print_info "Available applications: ${available_apps[*]}"
                continue
            fi
        fi
    done
    
    # Confirm with user
    echo
    print_highlight "Final Configuration:"
    print_info "  Module Name: $MODULE_NAME"
    print_info "  Based on App: $APP_NAME"
    print_info "  Location: $MODULES_DIR/$MODULE_NAME"
    print_info "  Status: ✅ No conflicts detected"
    echo
    
    read -p "Proceed with module creation? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Module creation cancelled"
        exit 0
    fi
}

# Function to create module directory structure
create_module_structure() {
    print_info "Creating module directory structure..."
    
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    
    # Create main directories
    mkdir -p "$module_dir"/{modules/$APP_NAME,scripts/$APP_NAME,examples}
    
    print_status "Created directory structure for $MODULE_NAME"
}

# Function to copy app-specific files
copy_app_files() {
    print_info "Copying $APP_NAME-specific files..."
    
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    
    # Copy app-specific module files if they exist
    if [[ -d "$WEBAPP_DIR/modules/$APP_NAME" ]]; then
        cp -r "$WEBAPP_DIR/modules/$APP_NAME"/* "$module_dir/modules/$APP_NAME/"
        print_status "Copied $APP_NAME module files"
    else
        print_warning "No module files found for $APP_NAME in WebApp/modules/"
    fi
    
    # Copy app-specific scripts if they exist
    if [[ -d "$WEBAPP_DIR/scripts/$APP_NAME" ]]; then
        cp -r "$WEBAPP_DIR/scripts/$APP_NAME"/* "$module_dir/scripts/$APP_NAME/"
        print_status "Copied $APP_NAME script files"
    else
        print_warning "No script files found for $APP_NAME in WebApp/scripts/"
    fi
    
    # Copy main app terraform file if it exists
    if [[ -f "$WEBAPP_DIR/$APP_NAME.tf" ]]; then
        cp "$WEBAPP_DIR/$APP_NAME.tf" "$module_dir/"
        print_status "Copied $APP_NAME.tf"
    else
        print_warning "No terraform file found: $APP_NAME.tf"
    fi
    
    # Copy main variables file
    if [[ -f "$WEBAPP_DIR/variables.tf" ]]; then
        cp "$WEBAPP_DIR/variables.tf" "$module_dir/"
        print_status "Copied variables.tf"
    else
        print_warning "No variables.tf found in WebApp"
    fi
}

# Function to copy examples folder with enhanced handling
copy_examples() {
    print_info "Setting up examples folder..."
    
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    local examples_copied=0
    
    # Ensure examples directory exists
    mkdir -p "$module_dir/examples"
    
    # Copy all .tfvars files from WebApp/examples if the directory exists
    if [[ -d "$WEBAPP_DIR/examples" ]]; then
        print_info "Copying example files from WebApp/examples..."
        
        # Copy all .tfvars files
        for tfvars_file in "$WEBAPP_DIR/examples"/*.tfvars; do
            if [[ -f "$tfvars_file" ]]; then
                cp "$tfvars_file" "$module_dir/examples/"
                ((examples_copied++))
                print_info "  • Copied $(basename "$tfvars_file")"
            fi
        done
        
        # Copy any README or documentation files
        for doc_file in "$WEBAPP_DIR/examples"/{README.md,*.txt,*.md}; do
            if [[ -f "$doc_file" ]]; then
                cp "$doc_file" "$module_dir/examples/"
                print_info "  • Copied $(basename "$doc_file")"
            fi
        done
        
        if [[ $examples_copied -gt 0 ]]; then
            print_status "Copied $examples_copied example files"
        else
            print_warning "No .tfvars files found in WebApp/examples"
        fi
    else
        print_warning "WebApp/examples directory not found"
    fi
    
    # Create a basic example file if none were copied
    if [[ $examples_copied -eq 0 ]]; then
        print_info "Creating basic example file..."
        cat > "$module_dir/examples/basic-$APP_NAME.tfvars" << EOF
# Basic configuration for $MODULE_NAME module
# Copy and customize this file for your deployment

# Project configuration
project_id = "your-project-id"
region     = "us-central1"

# Application configuration
app_name = "$APP_NAME"
environment = "dev"

# Uncomment and configure as needed:
# domain_name = "your-domain.com"
# enable_ssl = true
# min_instances = 1
# max_instances = 10
EOF
        print_status "Created basic example file: basic-$APP_NAME.tfvars"
    fi
    
    # List all files in examples directory
    print_info "Examples directory contents:"
    for example_file in "$module_dir/examples"/*; do
        if [[ -f "$example_file" ]]; then
            print_info "  • $(basename "$example_file")"
        fi
    done
}

# Function to create symbolic links for shared infrastructure
create_infrastructure_symlinks() {
    print_info "Creating symbolic links for shared infrastructure..."
    
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    cd "$module_dir"
    
    # Infrastructure files to symlink
    local infrastructure_files=(
        "buildappcontainer.tf"
        "iam.tf"
        "jobs.tf"
        "main.tf"
        "modules.tf"
        "monitoring.tf"
        "network.tf"
        "nfs.tf"
        "outputs.tf"
        "provider-auth.tf"
        "registry.tf"
        "sa.tf"
        "secrets.tf"
        "service.tf"
        "sql.tf"
        "storage.tf"
        "trigger.tf"
        "versions.tf"
    )
    
    # Create symlinks for infrastructure files
    local symlinks_created=0
    for file in "${infrastructure_files[@]}"; do
        if [[ -f "../WebApp/$file" ]]; then
            ln -sf "../WebApp/$file" "$file"
            ((symlinks_created++))
        fi
    done
    
    print_status "Created $symlinks_created symbolic links for shared infrastructure"
}

# Function to create symbolic links for shared modules
create_module_symlinks() {
    print_info "Creating symbolic links for shared modules..."
    
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    cd "$module_dir/modules"
    
    # Create symlinks to other app modules (for potential dependencies)
    local module_symlinks=0
    for app_module in "$WEBAPP_DIR/modules"/*; do
        if [[ -d "$app_module" ]]; then
            local app_name=$(basename "$app_module")
            # Don't symlink the current app (we copied it)
            if [[ "$app_name" != "$APP_NAME" ]]; then
                ln -sf "../../WebApp/modules/$app_name" "$app_name"
                ((module_symlinks++))
            fi
        fi
    done
    
    print_status "Created $module_symlinks symbolic links for shared modules"
}

# Function to create symbolic links for shared scripts
create_script_symlinks() {
    print_info "Creating symbolic links for shared scripts..."
    
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    cd "$module_dir/scripts"
    
    local script_symlinks=0
    
    # Always link core scripts
    if [[ -d "$WEBAPP_DIR/scripts/core" ]]; then
        ln -sf "../../WebApp/scripts/core" "core"
        ((script_symlinks++))
    fi
    
    # Create symlinks to other app scripts (for potential dependencies)
    for app_script in "$WEBAPP_DIR/scripts"/*; do
        if [[ -d "$app_script" ]]; then
            local script_name=$(basename "$app_script")
            # Don't symlink the current app (we copied it) or core (already linked)
            if [[ "$script_name" != "$APP_NAME" && "$script_name" != "core" ]]; then
                ln -sf "../../WebApp/scripts/$script_name" "$script_name"
                ((script_symlinks++))
            fi
        fi
    done
    
    print_status "Created $script_symlinks symbolic links for shared scripts"
}

# Function to create README file
create_readme() {
    print_info "Creating README file..."
    
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    
    cat > "$module_dir/README.md" << EOF
# $MODULE_NAME Module

This module provides a standalone $APP_NAME deployment using shared infrastructure components from the WebApp module.

## Structure
- \`modules/$APP_NAME/\` - $APP_NAME-specific Terraform module
- \`scripts/$APP_NAME/\` - $APP_NAME-specific deployment scripts
- \`examples/\` - Configuration examples and templates
- \`$APP_NAME.tf\` - Main $APP_NAME Terraform configuration
- \`variables.tf\` - Module variables
- Other \`.tf\` files - Symbolic links to shared WebApp infrastructure

## Quick Start

### 1. Configure Variables
Copy and customize an example configuration:
\`\`\`bash
# Copy example configuration
cp examples/basic-$APP_NAME.tfvars my-config.tfvars

# Edit with your settings
nano my-config.tfvars
\`\`\`

### 2. Deploy
\`\`\`bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="my-config.tfvars"

# Deploy
terraform apply -var-file="my-config.tfvars"
\`\`\`

## Example Configurations

The \`examples/\` directory contains various configuration templates:
$(find "$module_dir/examples" -name "*.tfvars" -exec basename {} \; 2>/dev/null | sed 's/^/- /' || echo "- basic-$APP_NAME.tfvars")

## Dependencies
This module depends on shared infrastructure files from the WebApp module via symbolic links.
Ensure the WebApp module is present in the parent directory.

## Generated Information
- **Generated:** $(date)
- **Base Application:** $APP_NAME
- **Module Name:** $MODULE_NAME
- **Script Version:** create_module.sh v3.2 (macOS Bash 3.2 Compatible)

## Support
For issues or questions, refer to the main rad-modules documentation or create an issue in the repository.
EOF
    
    print_status "Created comprehensive README.md"
}

# Function to verify the setup
verify_setup() {
    print_info "Verifying module setup..."
    
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    cd "$module_dir"
    
    local verification_passed=true
    
    # Check if key files exist
    local key_files=("main.tf" "versions.tf" "variables.tf")
    for file in "${key_files[@]}"; do
        if [[ ! -f "$file" && ! -L "$file" ]]; then
            print_error "Missing key file: $file"
            verification_passed=false
        fi
    done
    
    # Check examples directory
    if [[ ! -d "examples" ]]; then
        print_error "Missing examples directory"
        verification_passed=false
    else
        local example_count=$(find examples -name "*.tfvars" 2>/dev/null | wc -l)
        if [[ $example_count -eq 0 ]]; then
            print_warning "No .tfvars files found in examples directory"
        else
            print_status "Found $example_count example configuration files"
        fi
    fi
    
    # Test symlinks
    local broken_links=0
    for link in *.tf; do
        if [[ -L "$link" && ! -e "$link" ]]; then
            print_warning "Broken symlink: $link"
            ((broken_links++))
            verification_passed=false
        fi
    done
    
    if [[ $broken_links -gt 0 ]]; then
        print_error "Found $broken_links broken symlinks"
        verification_passed=false
    fi
    
    # Test Terraform validation if terraform is available
    if command -v terraform >/dev/null 2>&1; then
        print_info "Testing Terraform configuration..."
        if terraform init -backend=false >/dev/null 2>&1; then
            if terraform validate >/dev/null 2>&1; then
                print_status "Terraform configuration is valid"
            else
                print_warning "Terraform validation failed (this may be expected without proper variables)"
            fi
        else
            print_warning "Terraform init failed (this may be expected without proper configuration)"
        fi
    fi
    
    if [[ "$verification_passed" == true ]]; then
        print_status "Module verification completed successfully"
    else
        print_error "Module verification found issues"
        return 1
    fi
}

# Function to display final summary
display_summary() {
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    local existing_modules=($(get_existing_modules))
    
    echo
    print_status "🎉 Module creation completed successfully!"
    echo
    print_highlight "Module Details:"
    print_info "  Name: $MODULE_NAME"
    print_info "  Based on: $APP_NAME"
    print_info "  Location: $module_dir"
    print_info "  Total modules now: $((${#existing_modules[@]} + 1))"
    echo
    print_highlight "Directory Structure:"
    print_info "  📁 $MODULE_NAME/"
    print_info "  ├── 📁 examples/          # Configuration templates"
    print_info "  ├── 📁 modules/$APP_NAME/ # App-specific Terraform modules"
    print_info "  ├── 📁 scripts/$APP_NAME/ # App-specific scripts"
    print_info "  ├── 📄 $APP_NAME.tf       # Main app configuration"
    print_info "  ├── 📄 variables.tf       # Module variables"
    print_info "  ├── 📄 README.md          # Documentation"
    print_info "  └── 🔗 *.tf              # Symlinks to shared infrastructure"
    echo
    print_highlight "Next Steps:"
    print_info "  1. cd $module_dir"
    print_info "  2. cp examples/basic-$APP_NAME.tfvars my-config.tfvars"
    print_info "  3. nano my-config.tfvars  # Edit configuration"
    print_info "  4. terraform init"
    print_info "  5. terraform plan -var-file=\"my-config.tfvars\""
    print_info "  6. terraform apply -var-file=\"my-config.tfvars\""
    echo
    print_status "The module is now ready for deployment! 🚀"
    
    # Show updated modules list
    echo
    print_section "Updated Modules List:"
    local updated_modules=($(get_existing_modules))
    for i in "${!updated_modules[@]}"; do
        if [[ "${updated_modules[i]}" == "$MODULE_NAME" ]]; then
            printf "  %2d) %s ✨ (newly created)\n" $((i+1)) "${updated_modules[i]}"
        else
            printf "  %2d) %s\n" $((i+1)) "${updated_modules[i]}"
        fi
    done
}

# Main execution
main() {
    echo
    print_section "🚀 RAD Modules - Universal Module Creator (Enhanced)"
    print_section "=================================================="
    echo
    
    validate_prerequisites
    prompt_user_input
    create_module_structure
    copy_app_files
    copy_examples
    create_infrastructure_symlinks
    create_module_symlinks
    create_script_symlinks
    create_readme
    verify_setup
    display_summary
}

# Run the script
main "$@"
