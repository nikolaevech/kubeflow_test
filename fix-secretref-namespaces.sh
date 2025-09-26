#!/bin/bash

# Script to fix secretKeyRef namespace issues in Kubernetes manifests
# This removes the unsupported 'namespace' field from secretKeyRef declarations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Kubernetes SecretRef Namespace Fixer                    ║"
echo "║  Removes unsupported 'namespace' field from secretKeyRef ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "02-kubeflow-pipelines" ]; then
    log_error "Must run from project root directory!"
    exit 1
fi

# Create backup directory
BACKUP_DIR="backups/fix-$(date +%Y%m%d-%H%M%S)"
log_info "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# List of files to fix
FILES_TO_FIX=(
    "02-kubeflow-pipelines/kubeflow-all.yaml"
    "05-jupyterlab/jupyter-all.yaml"
)

# Function to backup and fix a file
fix_file() {
    local file=$1
    
    if [ ! -f "$file" ]; then
        log_warning "File not found: $file (skipping)"
        return
    fi
    
    log_info "Processing: $file"
    
    # Create backup
    cp "$file" "$BACKUP_DIR/$(basename $file).backup"
    log_success "  ✓ Backup created"
    
    # Check if file contains the problematic pattern
    if grep -q "namespace: ml-infrastructure" "$file" && grep -B2 "namespace: ml-infrastructure" "$file" | grep -q "secretKeyRef:"; then
        
        # Count occurrences before fix
        COUNT_BEFORE=$(grep -c "namespace: ml-infrastructure" "$file" || echo "0")
        
        # Fix the file using sed
        # This removes lines containing "namespace: ml-infrastructure" that come after "secretKeyRef:"
        sed -i.tmp '/secretKeyRef:/,/key:/ {
            /namespace: ml-infrastructure/d
        }' "$file"
        
        # Alternative approach: more precise regex-based fix
        # Remove the namespace line if it appears within secretKeyRef block
        perl -i -pe '
            BEGIN { $in_secret = 0; }
            if (/secretKeyRef:/) { $in_secret = 1; }
            if ($in_secret && /^\s+namespace:\s+ml-infrastructure\s*$/) { 
                $_ = ""; 
                $in_secret = 0; 
            }
            if ($in_secret && /^\s+key:/) { $in_secret = 0; }
        ' "$file"
        
        # Clean up temp file
        rm -f "${file}.tmp"
        
        # Count occurrences after fix
        COUNT_AFTER=$(grep -c "namespace: ml-infrastructure" "$file" || echo "0")
        
        log_success "  ✓ Fixed! Removed $(($COUNT_BEFORE - $COUNT_AFTER)) namespace references"
        
        # Show changes
        if command -v diff >/dev/null 2>&1; then
            log_info "  Changes made:"
            diff -u "$BACKUP_DIR/$(basename $file).backup" "$file" | head -20 || true
        fi
    else
        log_info "  ℹ No problematic namespace references found"
    fi
    
    echo ""
}

# Process all files
log_info "Starting fixes..."
echo ""

for file in "${FILES_TO_FIX[@]}"; do
    fix_file "$file"
done

# Summary
log_success "All files processed!"
echo ""
log_info "Backup location: $BACKUP_DIR"
echo ""

# Offer to validate
read -p "Do you want to validate the YAML files? (yes/no): " validate

if [ "$validate" = "yes" ]; then
    log_info "Validating YAML syntax..."
    echo ""
    
    for file in "${FILES_TO_FIX[@]}"; do
        if [ -f "$file" ]; then
            log_info "Validating: $file"
            if command -v kubectl >/dev/null 2>&1; then
                kubectl apply --dry-run=client -f "$file" >/dev/null 2>&1 && \
                    log_success "  ✓ Valid" || \
                    log_error "  ✗ Invalid YAML"
            else
                log_warning "  kubectl not found, skipping validation"
            fi
        fi
    done
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    Fix Complete! ✓                       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
log_info "Next steps:"
echo "  1. Review the changes if needed"
echo "  2. Run: make deploy"
echo "  3. Or run: ./scripts/deploy-all.sh"
echo ""
log_info "To restore from backup:"
echo "  cp $BACKUP_DIR/*.backup <original-location>"
echo ""