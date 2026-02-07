#!/bin/bash
set -e

# Script to ensure application modules have symbolic links to core CloudRunApp files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$(dirname "$SCRIPT_DIR")/modules"
CLOUDRUNAPP_DIR="$MODULES_DIR/CloudRunApp"

if [ ! -d "$CLOUDRUNAPP_DIR" ]; then
  echo "Error: CloudRunApp directory not found at $CLOUDRUNAPP_DIR"
  exit 1
fi

echo "Updating application modules with symlinks to CloudRunApp..."

# Get list of core .tf files from CloudRunApp
CORE_FILES=$(find "$CLOUDRUNAPP_DIR" -maxdepth 1 -name "*.tf" ! -name "cloudrunapp.tf" -exec basename {} \;)

# Iterate over all directories in modules/
for module_path in "$MODULES_DIR"/*; do
  if [ -d "$module_path" ]; then
    module_name=$(basename "$module_path")
    
    # Exclude specific modules
    if [[ "$module_name" == "CloudRunApp" || "$module_name" == "GCP_Project" || "$module_name" == "GCP_Services" ]]; then
      echo "Skipping excluded module: $module_name"
      continue
    fi
    
    echo "Processing module: $module_name"
    
    # Create symlinks for core .tf files
    for file in $CORE_FILES; do
      target="$module_path/$file"
      source="../CloudRunApp/$file"
      
      # Remove existing file/link
      rm -f "$target"
      
      # Create symlink
      ln -s "$source" "$target"
    done
    
    # Handle scripts/core directory
    scripts_dir="$module_path/scripts"
    mkdir -p "$scripts_dir"
    
    core_scripts_target="$scripts_dir/core"
    core_scripts_source="../../CloudRunApp/scripts/core"
    
    # Remove existing scripts/core (directory or link)
    rm -rf "$core_scripts_target"
    
    # Create symlink
    ln -s "$core_scripts_source" "$core_scripts_target"
    
    echo "  Updated symlinks for $module_name"
  fi
done

echo "Done."
