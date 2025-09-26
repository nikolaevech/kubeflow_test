#!/bin/bash

# Final fix for secretKeyRef namespace issues
# This script removes ALL namespace fields from secretKeyRef blocks

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Final Fix: Remove ALL namespace from secretKeyRef      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Files to fix
FILES=(
    "02-kubeflow-pipelines/kubeflow-all.yaml"
    "05-jupyterlab/jupyter-all.yaml"
)

# Backup
BACKUP_DIR="backups/final-fix-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
log_info "Backup directory: $BACKUP_DIR"

for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        continue
    fi
    
    log_info "Processing: $file"
    
    # Backup
    cp "$file" "$BACKUP_DIR/$(basename $file).backup"
    
    # Count before
    BEFORE=$(grep -c "namespace: ml-infrastructure" "$file" 2>/dev/null || echo "0")
    log_info "  Found $BEFORE 'namespace: ml-infrastructure' lines"
    
    # Remove ALL lines with "namespace: ml-infrastructure" 
    # that appear within secretKeyRef context
    sed -i '/secretKeyRef:/,/key:/ {
        /namespace: ml-infrastructure/d
    }' "$file"
    
    # Count after
    AFTER=$(grep -c "namespace: ml-infrastructure" "$file" 2>/dev/null || echo "0")
    REMOVED=$((BEFORE - AFTER))
    
    if [ $REMOVED -gt 0 ]; then
        log_success "  ✓ Removed $REMOVED namespace lines"
    else
        log_info "  ℹ No changes needed"
    fi
    
    # Verify no namespace in secretKeyRef remains
    if grep -A3 "secretKeyRef:" "$file" | grep -q "namespace:"; then
        log_error "  ✗ WARNING: Still has namespace in secretKeyRef!"
        grep -B1 -A3 "secretKeyRef:" "$file" | grep -A3 "namespace:"
    else
        log_success "  ✓ Clean! No namespace in secretKeyRef"
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
log_success "Fix completed!"
echo ""
log_info "Validation:"

# Validate YAML
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -n "  $file: "
        if kubectl apply --dry-run=client -f "$file" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Valid${NC}"
        else
            echo -e "${RED}✗ Invalid${NC}"
            kubectl apply --dry-run=client -f "$file" 2>&1 | head -3
        fi
    fi
done

echo ""
log_info "Next step: make reset"
echo ""