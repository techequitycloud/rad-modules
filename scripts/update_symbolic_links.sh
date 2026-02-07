#!/bin/bash
set -e

# Script to ensure application modules have symbolic links to core CloudRunApp files.
# Version: 2.0
# Features: Dry-run mode, verification, logging, rollback capability, configurable exclusions

# ============================================================================
# Configuration
# ============================================================================

# Files to exclude from linking
EXCLUDED_FILES=("cloudrunapp.tf" "variables.tf" "terraform.tfvars")

# Modules to exclude from processing
EXCLUDED_MODULES=("CloudRunApp" "GCP_Project" "GCP_Services")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Path Setup
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$(dirname "$SCRIPT_DIR")/modules"
CLOUDRUNAPP_DIR="$MODULES_DIR/CloudRunApp"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/tmp/symlink_update_${TIMESTAMP}.log"
BACKUP_DIR="/tmp/terraform_symlinks_backup_${TIMESTAMP}"

# ============================================================================
# Command Line Arguments
# ============================================================================

DRY_RUN=false
VERBOSE=false
CREATE_BACKUP=true
VERIFY=true

show_usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Manages symbolic links from CloudRunApp to application modules.

OPTIONS:
  --dry-run         Show what would be done without making changes
  --no-backup       Skip creating backup of existing symlinks
  --no-verify       Skip verification of created symlinks
  -v, --verbose     Enable verbose output
  -h, --help        Show this help message

EXAMPLES:
  $(basename "$0")                    # Normal run with backup and verification
  $(basename "$0") --dry-run          # Preview changes without applying
  $(basename "$0") --no-backup -v     # Run without backup, verbose output

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-backup)
      CREATE_BACKUP=false
      shift
      ;;
    --no-verify)
      VERIFY=false
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option: $1${NC}"
      show_usage
      exit 1
      ;;
  esac
done

# ============================================================================
# Logging Setup
# ============================================================================

# Initialize log file
if [ "$DRY_RUN" = false ]; then
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "Log file: $LOG_FILE"
fi

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[VERBOSE]${NC} $1"
  fi
}

# Check if value is in array
array_contains() {
  local seeking=$1
  shift
  local array=("$@")
  for element in "${array[@]}"; do
    if [[ "$element" == "$seeking" ]]; then
      return 0
    fi
  done
  return 1
}

# Create backup of existing symlinks
create_backup() {
  local module_path=$1
  local module_name=$2
  
  if [ "$CREATE_BACKUP" = false ]; then
    return 0
  fi
  
  local module_backup_dir="$BACKUP_DIR/$module_name"
  mkdir -p "$module_backup_dir"
  
  # Backup existing symlinks
  local backed_up=0
  for file in "$module_path"/*.tf; do
    if [ -L "$file" ]; then
      cp -P "$file" "$module_backup_dir/" 2>/dev/null || true
      ((backed_up++))
    fi
  done
  
  # Backup scripts/core if it exists
  if [ -L "$module_path/scripts/core" ] || [ -d "$module_path/scripts/core" ]; then
    mkdir -p "$module_backup_dir/scripts"
    cp -rP "$module_path/scripts/core" "$module_backup_dir/scripts/" 2>/dev/null || true
    ((backed_up++))
  fi
  
  if [ $backed_up -gt 0 ]; then
    log_verbose "Backed up $backed_up item(s) from $module_name to $module_backup_dir"
  fi
}

# Verify symlink was created correctly
verify_symlink() {
  local target=$1
  local expected_source=$2
  local file_name=$3
  
  if [ "$VERIFY" = false ]; then
    return 0
  fi
  
  if [ -L "$target" ] && [ -e "$target" ]; then
    local actual_source=$(readlink "$target")
    if [ "$actual_source" = "$expected_source" ]; then
      log_success "  ✓ $file_name"
      return 0
    else
      log_error "  ✗ $file_name (points to wrong location: $actual_source)"
      return 1
    fi
  else
    log_error "  ✗ $file_name (symlink creation failed)"
    return 1
  fi
}

# Remove broken symlinks
remove_broken_symlinks() {
  local module_path=$1
  local removed=0
  
  for file in "$module_path"/*.tf; do
    if [ -L "$file" ] && [ ! -e "$file" ]; then
      log_warning "  Removing broken symlink: $(basename "$file")"
      if [ "$DRY_RUN" = false ]; then
        rm -f "$file"
      fi
      ((removed++))
    fi
  done
  
  if [ -L "$module_path/scripts/core" ] && [ ! -e "$module_path/scripts/core" ]; then
    log_warning "  Removing broken symlink: scripts/core"
    if [ "$DRY_RUN" = false ]; then
      rm -rf "$module_path/scripts/core"
    fi
    ((removed++))
  fi
  
  if [ $removed -gt 0 ]; then
    log_verbose "Removed $removed broken symlink(s)"
  fi
}

# ============================================================================
# Main Script
# ============================================================================

log_info "Starting symlink update process..."
if [ "$DRY_RUN" = true ]; then
  log_warning "DRY RUN MODE - No changes will be made"
fi

# Validate CloudRunApp directory exists
if [ ! -d "$CLOUDRUNAPP_DIR" ]; then
  log_error "CloudRunApp directory not found at $CLOUDRUNAPP_DIR"
  exit 1
fi

log_success "Found CloudRunApp directory: $CLOUDRUNAPP_DIR"

# Build find command with exclusions
log_info "Building list of core files to link..."
FIND_CMD="find \"$CLOUDRUNAPP_DIR\" -maxdepth 1 -name \"*.tf\""
for excluded in "${EXCLUDED_FILES[@]}"; do
  FIND_CMD="$FIND_CMD ! -name \"$excluded\""
done
FIND_CMD="$FIND_CMD -exec basename {} \;"

CORE_FILES=$(eval $FIND_CMD)
CORE_FILES_ARRAY=($CORE_FILES)

log_info "Found ${#CORE_FILES_ARRAY[@]} core files to link:"
for file in "${CORE_FILES_ARRAY[@]}"; do
  log_verbose "  - $file"
done

log_info "Excluded files: ${EXCLUDED_FILES[*]}"
log_info "Excluded modules: ${EXCLUDED_MODULES[*]}"

# Create backup directory if needed
if [ "$CREATE_BACKUP" = true ] && [ "$DRY_RUN" = false ]; then
  mkdir -p "$BACKUP_DIR"
  log_info "Backup directory: $BACKUP_DIR"
fi

# Statistics
total_modules=0
processed_modules=0
skipped_modules=0
total_links_created=0
total_links_failed=0

# Iterate over all directories in modules/
log_info "Processing modules..."
echo ""

for module_path in "$MODULES_DIR"/*; do
  if [ -d "$module_path" ]; then
    module_name=$(basename "$module_path")
    ((total_modules++))
    
    # Check if module should be excluded
    if array_contains "$module_name" "${EXCLUDED_MODULES[@]}"; then
      log_warning "Skipping excluded module: $module_name"
      ((skipped_modules++))
      continue
    fi
    
    log_info "Processing module: $module_name"
    ((processed_modules++))
    
    # Create backup before making changes
    if [ "$DRY_RUN" = false ]; then
      create_backup "$module_path" "$module_name"
    fi
    
    # Remove broken symlinks
    remove_broken_symlinks "$module_path"
    
    # Create symlinks for core .tf files
    log_info "  Creating symlinks for .tf files..."
    for file in "${CORE_FILES_ARRAY[@]}"; do
      target="$module_path/$file"
      source="../CloudRunApp/$file"
      
      if [ "$DRY_RUN" = true ]; then
        log_verbose "  Would create: ln -s $source $target"
      else
        # Remove existing file/link
        rm -f "$target"
        
        # Create symlink
        ln -s "$source" "$target"
        
        # Verify symlink
        if verify_symlink "$target" "$source" "$file"; then
          ((total_links_created++))
        else
          ((total_links_failed++))
        fi
      fi
    done
    
    # Handle scripts/core directory
    log_info "  Creating symlink for scripts/core directory..."
    scripts_dir="$module_path/scripts"
    
    if [ "$DRY_RUN" = true ]; then
      log_verbose "  Would create directory: $scripts_dir"
      log_verbose "  Would create: ln -s ../../CloudRunApp/scripts/core $scripts_dir/core"
    else
      mkdir -p "$scripts_dir"
      
      core_scripts_target="$scripts_dir/core"
      core_scripts_source="../../CloudRunApp/scripts/core"
      
      # Remove existing scripts/core (directory or link)
      rm -rf "$core_scripts_target"
      
      # Create symlink
      ln -s "$core_scripts_source" "$core_scripts_target"
      
      # Verify symlink
      if verify_symlink "$core_scripts_target" "$core_scripts_source" "scripts/core"; then
        ((total_links_created++))
      else
        ((total_links_failed++))
      fi
    fi
    
    log_success "  Completed: $module_name"
    echo ""
  fi
done

# ============================================================================
# Summary
# ============================================================================

echo ""
log_info "=========================================="
log_info "Summary"
log_info "=========================================="
log_info "Total modules found: $total_modules"
log_info "Modules processed: $processed_modules"
log_info "Modules skipped: $skipped_modules"

if [ "$DRY_RUN" = false ]; then
  log_info "Symlinks created: $total_links_created"
  if [ $total_links_failed -gt 0 ]; then
    log_error "Symlinks failed: $total_links_failed"
  fi
  
  if [ "$CREATE_BACKUP" = true ]; then
    log_info "Backup location: $BACKUP_DIR"
  fi
  
  log_info "Log file: $LOG_FILE"
fi

echo ""
if [ "$DRY_RUN" = true ]; then
  log_warning "DRY RUN completed - No changes were made"
  log_info "Run without --dry-run to apply changes"
else
  if [ $total_links_failed -eq 0 ]; then
    log_success "All operations completed successfully!"
  else
    log_error "Some operations failed. Check the log file for details."
    exit 1
  fi
fi

# ============================================================================
# Rollback Instructions
# ============================================================================

if [ "$DRY_RUN" = false ] && [ "$CREATE_BACKUP" = true ]; then
  cat << EOF

To rollback these changes, run:
  cp -rP $BACKUP_DIR/* $MODULES_DIR/

EOF
fi

exit 0
