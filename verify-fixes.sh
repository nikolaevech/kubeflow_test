#!/bin/bash

# Verification Script - Check if all fixes have been applied correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((TOTAL_CHECKS++))
}

log_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║           Kubeflow Fixes Verification Script                ║
║        Validates all corrections have been applied          ║
╚══════════════════════════════════════════════════════════════╝
EOF

echo ""

# Check if in correct directory
if [ ! -f "README.md" ] || [ ! -d "02-kubeflow-pipelines" ]; then
    echo -e "${RED}[ERROR]${NC} Must run from project root directory!"
    exit 1
fi

# ============================================================================
# CHECK 1: Verify secretKeyRef namespace fields are removed
# ============================================================================
log_section "CHECK 1: Verify secretKeyRef namespace fields removed"

FILES_TO_CHECK=(
    "02-kubeflow-pipelines/kubeflow-all.yaml"
    "05-jupyterlab/jupyter-all.yaml"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
        # Check for problematic pattern
        if grep -A2 "secretKeyRef:" "$file" | grep -q "namespace: ml-infrastructure"; then
            check_fail "$file still contains 'namespace: ml-infrastructure' in secretKeyRef"
        else
            check_pass "$file - no namespace in secretKeyRef ✓"
        fi
        
        # Verify secrets are still referenced correctly
        if grep -q "secretKeyRef:" "$file" && grep -q "name: mysql-secret\|name: minio-secret" "$file"; then
            check_pass "$file - secret references intact ✓"
        else
            check_warn "$file - secret references may be missing"
        fi
    else
        check_fail "$file not found"
    fi
done

# ============================================================================
# CHECK 2: Verify MySQL deployment probe fixes
# ============================================================================
log_section "CHECK 2: Verify MySQL deployment probe fixes"

MYSQL_FILE="01-infrastructure/mysql/deployment.yaml"

if [ -f "$MYSQL_FILE" ]; then
    # Check readiness probe uses sh -c
    if grep -A5 "readinessProbe:" "$MYSQL_FILE" | grep -q "sh.*-c"; then
        check_pass "MySQL readiness probe uses 'sh -c' ✓"
    else
        check_fail "MySQL readiness probe doesn't use 'sh -c'"
    fi
    
    # Check liveness probe uses sh -c
    if grep -A5 "livenessProbe:" "$MYSQL_FILE" | grep -q "sh.*-c"; then
        check_pass "MySQL liveness probe uses 'sh -c' ✓"
    else
        check_fail "MySQL liveness probe doesn't use 'sh -c'"
    fi
    
    # Check failureThreshold is increased
    if grep -A10 "readinessProbe:" "$MYSQL_FILE" | grep -q "failureThreshold: [0-9]*" && \
       [ $(grep -A10 "readinessProbe:" "$MYSQL_FILE" | grep "failureThreshold:" | awk '{print $2}') -ge 15 ]; then
        check_pass "MySQL readiness probe has adequate failureThreshold ✓"
    else
        check_fail "MySQL readiness probe failureThreshold too low"
    fi
    
    # Check initialDelaySeconds
    if grep -A10 "readinessProbe:" "$MYSQL_FILE" | grep -q "initialDelaySeconds: [0-9]*" && \
       [ $(grep -A10 "readinessProbe:" "$MYSQL_FILE" | grep "initialDelaySeconds:" | awk '{print $2}') -ge 30 ]; then
        check_pass "MySQL readiness probe has adequate initialDelaySeconds ✓"
    else
        check_fail "MySQL readiness probe initialDelaySeconds too low"
    fi
else
    check_fail "MySQL deployment file not found"
fi

# ============================================================================
# CHECK 3: Verify MySQL wait script improvements
# ============================================================================
log_section "CHECK 3: Verify MySQL wait script improvements"

WAIT_SCRIPT="scripts/wait-mysql.sh"

if [ -f "$WAIT_SCRIPT" ]; then
    # Check if script is executable
    if [ -x "$WAIT_SCRIPT" ]; then
        check_pass "MySQL wait script is executable ✓"
    else
        check_fail "MySQL wait script is not executable"
    fi
    
    # Check for pod status checking
    if grep -q "POD_STATUS" "$WAIT_SCRIPT"; then
        check_pass "MySQL wait script checks pod status ✓"
    else
        check_fail "MySQL wait script doesn't check pod status"
    fi
    
    # Check for proper mysqladmin ping with sh -c
    if grep -q "sh -c.*mysqladmin ping" "$WAIT_SCRIPT"; then
        check_pass "MySQL wait script uses correct ping command ✓"
    else
        check_fail "MySQL wait script ping command may be incorrect"
    fi
    
    # Check for database creation verification
    if grep -q "SHOW DATABASES" "$WAIT_SCRIPT" || grep -q "CREATE DATABASE" "$WAIT_SCRIPT"; then
        check_pass "MySQL wait script creates and verifies databases ✓"
    else
        check_fail "MySQL wait script missing database creation"
    fi
    
    # Check for adequate retry attempts
    if grep -q "max_attempts.*12[0-9]" "$WAIT_SCRIPT" || grep -q "max_attempts.*[0-9][0-9][0-9]" "$WAIT_SCRIPT"; then
        check_pass "MySQL wait script has adequate retry attempts ✓"
    else
        check_warn "MySQL wait script may have insufficient retry attempts"
    fi
else
    check_fail "MySQL wait script not found"
fi

# ============================================================================
# CHECK 4: Verify deployment script integration
# ============================================================================
log_section "CHECK 4: Verify deployment script integration"

DEPLOY_SCRIPT="scripts/deploy-all.sh"

if [ -f "$DEPLOY_SCRIPT" ]; then
    # Check if script is executable
    if [ -x "$DEPLOY_SCRIPT" ]; then
        check_pass "Deployment script is executable ✓"
    else
        check_fail "Deployment script is not executable"
    fi
    
    # Check if wait-mysql.sh is called
    if grep -q "wait-mysql.sh" "$DEPLOY_SCRIPT" || grep -q "bash scripts/wait-mysql.sh" "$DEPLOY_SCRIPT"; then
        check_pass "Deployment script calls wait-mysql.sh ✓"
    else
        check_fail "Deployment script doesn't call wait-mysql.sh"
    fi
    
    # Check for proper error handling
    if grep -q "exit 1" "$DEPLOY_SCRIPT" && grep -q "log_error" "$DEPLOY_SCRIPT"; then
        check_pass "Deployment script has error handling ✓"
    else
        check_warn "Deployment script error handling could be improved"
    fi
else
    check_fail "Deployment script not found"
fi

# ============================================================================
# CHECK 5: YAML Syntax Validation
# ============================================================================
log_section "CHECK 5: YAML Syntax Validation"

if command -v kubectl >/dev/null 2>&1; then
    YAML_FILES=(
        "00-prerequisites/namespaces.yaml"
        "01-infrastructure/mysql/deployment.yaml"
        "01-infrastructure/mysql/service.yaml"
        "01-infrastructure/mysql/configmap.yaml"
        "01-infrastructure/mysql/secret.yaml"
        "01-infrastructure/mysql/pvc.yaml"
        "01-infrastructure/minio/deployment.yaml"
        "01-infrastructure/minio/service.yaml"
        "01-infrastructure/minio/secret.yaml"
        "01-infrastructure/minio/pvc.yaml"
        "02-kubeflow-pipelines/kubeflow-all.yaml"
        "05-jupyterlab/jupyter-all.yaml"
    )
    
    for file in "${YAML_FILES[@]}"; do
        if [ -f "$file" ]; then
            if kubectl apply --dry-run=client -f "$file" &>/dev/null; then
                check_pass "$file - valid YAML syntax ✓"
            else
                check_fail "$file - invalid YAML syntax"
                echo "  Error details:"
                kubectl apply --dry-run=client -f "$file" 2>&1 | head -3 | sed 's/^/    /'
            fi
        else
            check_warn "$file - not found (may be optional)"
        fi
    done
else
    check_warn "kubectl not found - skipping YAML validation"
fi

# ============================================================================
# CHECK 6: Secret references verification
# ============================================================================
log_section "CHECK 6: Secret references verification"

# Check that secrets exist in manifests
if [ -f "01-infrastructure/mysql/secret.yaml" ]; then
    if grep -q "MYSQL_ROOT_PASSWORD" "01-infrastructure/mysql/secret.yaml" && \
       grep -q "MYSQL_PASSWORD" "01-infrastructure/mysql/secret.yaml"; then
        check_pass "MySQL secret has required fields ✓"
    else
        check_fail "MySQL secret missing required fields"
    fi
else
    check_fail "MySQL secret file not found"
fi

if [ -f "01-infrastructure/minio/secret.yaml" ]; then
    if grep -q "MINIO_ROOT_USER" "01-infrastructure/minio/secret.yaml" && \
       grep -q "MINIO_ROOT_PASSWORD" "01-infrastructure/minio/secret.yaml"; then
        check_pass "MinIO secret has required fields ✓"
    else
        check_fail "MinIO secret missing required fields"
    fi
else
    check_fail "MinIO secret file not found"
fi

# ============================================================================
# CHECK 7: Script permissions
# ============================================================================
log_section "CHECK 7: Script permissions"

SCRIPTS=(
    "scripts/deploy-all.sh"
    "scripts/wait-mysql.sh"
    "scripts/uninstall.sh"
    "00-prerequisites/minikube-setup.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            check_pass "$script is executable ✓"
        else
            check_fail "$script is not executable (run: chmod +x $script)"
        fi
    else
        check_warn "$script not found"
    fi
done

# ============================================================================
# CHECK 8: Configuration consistency
# ============================================================================
log_section "CHECK 8: Configuration consistency"

# Check MySQL database names are consistent
if grep -r "mlpipeline" 01-infrastructure/mysql/ 02-kubeflow-pipelines/ scripts/ &>/dev/null && \
   grep -r "katib" 01-infrastructure/mysql/ 04-katib/ scripts/ &>/dev/null; then
    check_pass "Database names are consistent across manifests ✓"
else
    check_warn "Database names may not be consistent"
fi

# Check MinIO bucket names
if grep -r "mlpipeline" 01-infrastructure/minio/ 02-kubeflow-pipelines/ scripts/ &>/dev/null && \
   grep -r "models" 01-infrastructure/minio/ scripts/ &>/dev/null; then
    check_pass "MinIO bucket names are consistent ✓"
else
    check_warn "MinIO bucket names may not be consistent"
fi

# Check service names
if grep -q "mysql-service.ml-infrastructure" "02-kubeflow-pipelines/kubeflow-all.yaml" && \
   grep -q "minio-service.ml-infrastructure" "02-kubeflow-pipelines/kubeflow-all.yaml"; then
    check_pass "Service names are correctly referenced ✓"
else
    check_fail "Service names may be incorrectly referenced"
fi

# ============================================================================
# CHECK 9: Resource requests/limits
# ============================================================================
log_section "CHECK 9: Resource requests and limits"

if [ -f "01-infrastructure/mysql/deployment.yaml" ]; then
    if grep -A5 "resources:" "01-infrastructure/mysql/deployment.yaml" | grep -q "requests:" && \
       grep -A5 "resources:" "01-infrastructure/mysql/deployment.yaml" | grep -q "limits:"; then
        check_pass "MySQL has resource requests and limits ✓"
    else
        check_warn "MySQL missing resource requests or limits"
    fi
fi

if [ -f "01-infrastructure/minio/deployment.yaml" ]; then
    if grep -A5 "resources:" "01-infrastructure/minio/deployment.yaml" | grep -q "requests:" && \
       grep -A5 "resources:" "01-infrastructure/minio/deployment.yaml" | grep -q "limits:"; then
        check_pass "MinIO has resource requests and limits ✓"
    else
        check_warn "MinIO missing resource requests or limits"
    fi
fi

# ============================================================================
# CHECK 10: Verify fix-all-issues.sh exists and is executable
# ============================================================================
log_section "CHECK 10: Verify fix script"

if [ -f "fix-all-issues.sh" ]; then
    if [ -x "fix-all-issues.sh" ]; then
        check_pass "fix-all-issues.sh exists and is executable ✓"
    else
        check_fail "fix-all-issues.sh is not executable (run: chmod +x fix-all-issues.sh)"
    fi
    
    # Check if it has all necessary fixes
    if grep -q "FIX 1:" "fix-all-issues.sh" && \
       grep -q "FIX 2:" "fix-all-issues.sh" && \
       grep -q "FIX 3:" "fix-all-issues.sh" && \
       grep -q "FIX 4:" "fix-all-issues.sh"; then
        check_pass "fix-all-issues.sh contains all fix sections ✓"
    else
        check_fail "fix-all-issues.sh missing some fix sections"
    fi
else
    check_fail "fix-all-issues.sh not found"
fi

# ============================================================================
# SUMMARY
# ============================================================================
log_section "VERIFICATION SUMMARY"

echo ""
echo "Total checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo -e "${YELLOW}Warnings: $((TOTAL_CHECKS - PASSED_CHECKS - FAILED_CHECKS))${NC}"
echo ""

# Calculate pass rate
if [ $TOTAL_CHECKS -gt 0 ]; then
    PASS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo "Pass rate: ${PASS_RATE}%"
    echo ""
fi

# Final verdict
if [ $FAILED_CHECKS -eq 0 ]; then
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║              ✅ ALL CHECKS PASSED! ✅                        ║
║                                                              ║
║         All fixes have been applied correctly!              ║
║         You can now safely deploy Kubeflow.                 ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "  1. Deploy: make reset"
    echo "  2. Or:     ./scripts/deploy-all.sh"
    echo "  3. Monitor: kubectl get pods -A -w"
    echo ""
    exit 0
else
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║              ⚠️  ISSUES FOUND ⚠️                            ║
║                                                              ║
║     Some checks failed. Please review the errors above.     ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo ""
    echo -e "${YELLOW}Recommended actions:${NC}"
    echo "  1. Review failed checks above"
    echo "  2. Run fix script: ./fix-all-issues.sh"
    echo "  3. Re-run verification: ./verify-fixes.sh"
    echo ""
    
    if [ -f "fix-all-issues.sh" ]; then
        echo -e "${BLUE}Quick fix:${NC}"
        echo "  bash fix-all-issues.sh && bash verify-fixes.sh"
        echo ""
    fi
    
    exit 1
fi