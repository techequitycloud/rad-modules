#!/bin/bash
# create_module.sh - Universal Module Creation Script (Cloning based)
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
CLOUDRUNAPP_DIR="$MODULES_DIR/CloudRunApp"

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
    
    # Check if CloudRunApp directory exists (still needed as dependency)
    if [[ ! -d "$CLOUDRUNAPP_DIR" ]]; then
        print_error "CloudRunApp directory not found at: $CLOUDRUNAPP_DIR"
        print_info "Please ensure the CloudRunApp module exists in the modules directory"
        exit 1
    fi
    
    print_status "Prerequisites validated"
}

# Function to get existing modules (for conflict checking)
get_existing_modules() {
    local modules=()
    if [[ -d "$MODULES_DIR" ]]; then
        for module_dir in "$MODULES_DIR"/*; do
            if [[ -d "$module_dir" ]]; then
                local module_name=$(basename "$module_dir")
                modules+=("$module_name")
            fi
        done
    fi
    printf '%s\n' "${modules[@]}" | sort -u
}

# Function to get available applications (source for cloning)
get_available_apps() {
    local apps=()
    if [[ -d "$MODULES_DIR" ]]; then
        for module_dir in "$MODULES_DIR"/*; do
            if [[ -d "$module_dir" ]]; then
                local module_name=$(basename "$module_dir")
                # Exclude CloudRunApp (Foundation) and GCP_Services (Platform) and others if needed
                case "$module_name" in
                    CloudRunApp|GCP_Services|GCP_Project|Sample)
                        ;;
                    *)
                        apps+=("$module_name")
                        ;;
                esac
            fi
        done
    fi
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
    
    # Check if it conflicts with CloudRunApp
    if [[ "$module_name_lower" == "cloudrunapp" ]]; then
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
    local available_apps=($(get_available_apps))
    print_section "Available Applications to Clone:"

    if [[ ${#available_apps[@]} -eq 0 ]]; then
        print_error "No application modules found to clone."
        exit 1
    fi

    for i in "${!available_apps[@]}"; do
        printf "  %2d) %s\n" $((i+1)) "${available_apps[i]}"
    done
    echo

    # Get application to base the module on
    while true; do
        read -p "Enter the application name to clone (or number from list above): " APP_INPUT
        
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
                print_error "Application '$APP_NAME' not found"
                print_info "Available applications: ${available_apps[*]}"
                continue
            fi
        fi
    done

    echo
    # Get module name with conflict checking
    while true; do
        read -p "Enter the new module name (e.g., 'My${APP_NAME}'): " MODULE_NAME

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
    
    # Confirm with user
    echo
    print_highlight "Final Configuration:"
    print_info "  Module Name: $MODULE_NAME"
    print_info "  Based on App: $APP_NAME"
    print_info "  Source: $MODULES_DIR/$APP_NAME"
    print_info "  Destination: $MODULES_DIR/$MODULE_NAME"
    echo
    
    read -p "Proceed with module creation? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Module creation cancelled"
        exit 0
    fi
}

# Function to copy app files (Clone)
copy_app_files() {
    print_info "Cloning $APP_NAME to $MODULE_NAME..."
    
    local source_dir="$MODULES_DIR/$APP_NAME"
    local target_dir="$MODULES_DIR/$MODULE_NAME"
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Copy everything recursively, preserving attributes and symlinks
    if cp -a "$source_dir/." "$target_dir/"; then
        print_status "Cloned files successfully"
    else
        print_error "Failed to copy files"
        exit 1
    fi
    
    # Clean up build artifacts and state
    print_info "Cleaning up artifacts..."
    rm -rf "$target_dir"/.terraform \
           "$target_dir"/.terraform.lock.hcl \
           "$target_dir"/plan-output.tfplan \
           "$target_dir"/terraform.tfstate* \
           "$target_dir"/*.log \
           "$target_dir"/.DS_Store

    print_status "Cleaned up artifacts"
}

# Function to rename app-specific resources (files and directories)
rename_resources() {
    print_info "Renaming application resources..."
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    local app_name_lower=$(to_lowercase "$APP_NAME")
    local module_name_lower=$(to_lowercase "$MODULE_NAME")

    # Rename main TF file
    if [[ -f "$module_dir/$APP_NAME.tf" ]]; then
        mv "$module_dir/$APP_NAME.tf" "$module_dir/$MODULE_NAME.tf"
        print_status "Renamed main TF file to $MODULE_NAME.tf"
    elif [[ -f "$module_dir/$app_name_lower.tf" ]]; then
        mv "$module_dir/$app_name_lower.tf" "$module_dir/$module_name_lower.tf"
        print_status "Renamed main TF file to $module_name_lower.tf"
    fi

    # Rename uppercase documentation file (e.g., DJANGO.md → NEWMODULE.md)
    local app_name_upper=$(to_uppercase "$APP_NAME")
    local module_name_upper=$(to_uppercase "$MODULE_NAME")
    if [[ -f "$module_dir/$app_name_upper.md" ]]; then
        mv "$module_dir/$app_name_upper.md" "$module_dir/$module_name_upper.md"
        print_status "Renamed documentation file to $module_name_upper.md"
    fi

    # Rename scripts directory
    if [[ -d "$module_dir/scripts/$APP_NAME" ]]; then
        mv "$module_dir/scripts/$APP_NAME" "$module_dir/scripts/$MODULE_NAME"
        print_status "Renamed scripts directory"
    elif [[ -d "$module_dir/scripts/$app_name_lower" ]]; then
        mv "$module_dir/scripts/$app_name_lower" "$module_dir/scripts/$module_name_lower"
        print_status "Renamed scripts directory (lowercase)"
    fi

    # Rename modules directory (if exists)
    if [[ -d "$module_dir/modules/$APP_NAME" ]]; then
        mv "$module_dir/modules/$APP_NAME" "$module_dir/modules/$MODULE_NAME"
        print_status "Renamed modules directory"
    elif [[ -d "$module_dir/modules/$app_name_lower" ]]; then
        mv "$module_dir/modules/$app_name_lower" "$module_dir/modules/$module_name_lower"
        print_status "Renamed modules directory (lowercase)"
    fi
}

# Function to replace text content in files
replace_content() {
    print_info "Updating file content (replacing $APP_NAME with $MODULE_NAME)..."
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    local app_name_lower=$(to_lowercase "$APP_NAME")
    local module_name_lower=$(to_lowercase "$MODULE_NAME")

    # Use find to locate text files, excluding hidden files and binary files (basic filtering)
    # We want to replace in .tf, .tfvars, .sh, .md, .conf, .json, .yaml, .yml
    find "$module_dir" -type f \( \
        -name "*.tf" -o \
        -name "*.tfvars" -o \
        -name "*.sh" -o \
        -name "*.md" -o \
        -name "*.conf" -o \
        -name "*.json" -o \
        -name "*.yaml" -o \
        -name "*.yml" -o \
        -name "Dockerfile" \
    \) -print0 | while IFS= read -r -d '' file; do
        # Perform replacement for capitalized App Name
        if grep -q "$APP_NAME" "$file"; then
             sed -i "s/$APP_NAME/$MODULE_NAME/g" "$file" 2>/dev/null || sed -i "" "s/$APP_NAME/$MODULE_NAME/g" "$file"
        fi

        # Perform replacement for lowercase App Name (if different from capitalized)
        if [[ "$app_name_lower" != "$APP_NAME" ]]; then
            if grep -q "$app_name_lower" "$file"; then
                sed -i "s/$app_name_lower/$module_name_lower/g" "$file" 2>/dev/null || sed -i "" "s/$app_name_lower/$module_name_lower/g" "$file"
            fi
        fi
    done
    print_status "Content updated"
}

# Function to customize config files (renaming)
customize_config() {
    print_info "Customizing configuration files..."
    
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    local app_name_lower=$(to_lowercase "$APP_NAME")
    local module_name_lower=$(to_lowercase "$MODULE_NAME")
    
    # Enable nullglob to handle no matches gracefully
    shopt -s nullglob
    local config_files=("$module_dir/config"/*"$APP_NAME"* "$module_dir/config"/*"$app_name_lower"*)
    shopt -u nullglob
    
    if [[ ${#config_files[@]} -gt 0 ]]; then
        local processed_files=()
        for file in "${config_files[@]}"; do
            if [[ ! -f "$file" ]]; then continue; fi

            # Deduplicate
            local skip=0
            for p in "${processed_files[@]}"; do if [[ "$p" == "$file" ]]; then skip=1; break; fi; done
            if [[ $skip -eq 1 ]]; then continue; fi
            processed_files+=("$file")

            local filename=$(basename "$file")
            local new_filename="${filename//$app_name_lower/$module_name_lower}"

            if [[ "$filename" == "$new_filename" ]]; then
                 new_filename="${filename//$APP_NAME/$MODULE_NAME}"
            fi

            if [[ "$filename" != "$new_filename" ]]; then
                mv "$file" "$module_dir/config/$new_filename"
                print_info "Renamed config file: $filename -> $new_filename"
            fi
        done
    else
         print_warning "No config files found to rename in config/"
    fi
    
    # Append generation info to README (Content replacement handled by replace_content)
    if [[ -f "$module_dir/README.md" ]]; then
        cat >> "$module_dir/README.md" <<EOF

---
**Module Info:**
- **Generated:** $(date)
- **Base Application:** $APP_NAME
- **Module Name:** $MODULE_NAME
- **Created via:** create_module.sh
EOF
    fi
}

# Function to verify the setup
verify_setup() {
    print_info "Verifying module setup..."
    
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    
    # Check if key files exist
    local key_files=("main.tf" "versions.tf" "variables.tf")
    local missing=0
    for file in "${key_files[@]}"; do
        if [[ ! -e "$module_dir/$file" ]]; then
             print_error "Missing key file: $file"
             missing=1
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        print_status "Key files present"
    else
        print_error "Verification failed: Missing files"
        return 1
    fi
    
    # Check symlinks
    local broken_links=0
    local symlinks_count=0
    
    while IFS= read -r link; do
        symlinks_count=$((symlinks_count + 1))
        if [[ ! -e "$link" ]]; then
            print_warning "Broken symlink: $link -> $(readlink "$link")"
            broken_links=$((broken_links + 1))
        fi
    done < <(find "$module_dir" -maxdepth 1 -type l)

    if [[ $broken_links -eq 0 ]]; then
        print_status "Verified $symlinks_count symlinks (all valid)"
    else
        print_error "Found $broken_links broken symlinks"
    fi
}

# Function to display final summary
display_summary() {
    local module_dir="$MODULES_DIR/$MODULE_NAME"
    
    echo
    print_status "🎉 Module creation completed successfully!"
    echo
    print_highlight "Module Details:"
    print_info "  Name: $MODULE_NAME"
    print_info "  Based on: $APP_NAME"
    print_info "  Location: $module_dir"
    echo
    print_highlight "Next Steps:"
    print_info "  1. cd $module_dir"
    print_info "  2. Review the configuration in 'config/' directory"
    print_info "  3. terraform init"
    print_info "  4. terraform plan -var-file=\"config/basic-$(to_lowercase $MODULE_NAME).tfvars\""
    echo
    print_status "The module is now ready!"
}

# Main execution
main() {
    echo
    print_section "🚀 RAD Modules - Universal Module Creator (Cloning Edition)"
    print_section "========================================================="
    echo
    
    validate_prerequisites
    prompt_user_input
    copy_app_files
    rename_resources
    replace_content
    customize_config
    verify_setup
    display_summary
}

# Run the script
main "$@"
