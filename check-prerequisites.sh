#!/bin/bash

# Quick prerequisites checker for Kubeflow Platform

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Kubeflow Prerequisites Checker              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""

all_good=true

# Check Docker
echo -n "Checking Docker... "
if command -v docker >/dev/null 2>&1; then
    if docker ps >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $(docker --version)"
    else
        echo -e "${YELLOW}⚠${NC} Docker installed but not running"
        echo "   Run: sudo systemctl start docker (Linux) or start Docker Desktop (macOS)"
        all_good=false
    fi
else
    echo -e "${RED}✗${NC} Not installed"
    all_good=false
fi

# Check kubectl
echo -n "Checking kubectl... "
if command -v kubectl >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $(kubectl version --client --short 2>/dev/null | head -1 || kubectl version --client | head -1)"
else
    echo -e "${RED}✗${NC} Not installed"
    all_good=false
fi

# Check Minikube
echo -n "Checking Minikube... "
if command -v minikube >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $(minikube version --short)"
else
    echo -e "${RED}✗${NC} Not installed"
    all_good=false
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check system resources
echo -e "${BLUE}System Resources:${NC}"

# CPU
if [[ "$OSTYPE" == "darwin"* ]]; then
    CPU_CORES=$(sysctl -n hw.ncpu)
    TOTAL_RAM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
    AVAILABLE_DISK_GB=$(df -g / | awk 'NR==2 {print $4}')
else
    CPU_CORES=$(nproc)
    TOTAL_RAM_GB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
    AVAILABLE_DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
fi

# CPU Check
if [ "$CPU_CORES" -ge 6 ]; then
    echo -e "  CPU Cores: ${GREEN}✓${NC} $CPU_CORES cores (recommended: 6+)"
elif [ "$CPU_CORES" -ge 4 ]; then
    echo -e "  CPU Cores: ${YELLOW}⚠${NC} $CPU_CORES cores (minimum: 4, recommended: 6+)"
else
    echo -e "  CPU Cores: ${RED}✗${NC} $CPU_CORES cores (minimum: 4)"
    all_good=false
fi

# RAM Check
if [ "$TOTAL_RAM_GB" -ge 16 ]; then
    echo -e "  RAM: ${GREEN}✓${NC} ${TOTAL_RAM_GB}GB (recommended: 16GB+)"
elif [ "$TOTAL_RAM_GB" -ge 12 ]; then
    echo -e "  RAM: ${YELLOW}⚠${NC} ${TOTAL_RAM_GB}GB (minimum: 12GB, recommended: 16GB)"
else
    echo -e "  RAM: ${RED}✗${NC} ${TOTAL_RAM_GB}GB (minimum: 12GB)"
    all_good=false
fi

# Disk Check
if [ "$AVAILABLE_DISK_GB" -ge 50 ]; then
    echo -e "  Free Disk: ${GREEN}✓${NC} ${AVAILABLE_DISK_GB}GB available (recommended: 50GB+)"
else
    echo -e "  Free Disk: ${YELLOW}⚠${NC} ${AVAILABLE_DISK_GB}GB available (recommended: 50GB+)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if Minikube is running
if command -v minikube >/dev/null 2>&1; then
    echo -e "${BLUE}Minikube Status:${NC}"
    if minikube status >/dev/null 2>&1; then
        echo -e "  Status: ${GREEN}✓${NC} Running"
        echo ""
        minikube status | sed 's/^/  /'
    else
        echo -e "  Status: ${YELLOW}⚠${NC} Not running"
        echo "  Run: minikube start"
    fi
    echo ""
fi

# Final verdict
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$all_good" = true ]; then
    echo -e "${GREEN}✓ All prerequisites are met!${NC}"
    echo ""
    echo "You're ready to deploy Kubeflow:"
    echo "  ./quickstart.sh"
    echo "or"
    echo "  ./scripts/deploy-all.sh"
else
    echo -e "${RED}✗ Some prerequisites are missing or insufficient${NC}"
    echo ""
    echo "To install missing components, run:"
    echo "  ./install-prerequisites.sh"
fi

echo ""