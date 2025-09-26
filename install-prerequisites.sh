#!/bin/bash

# Kubeflow Platform - Prerequisites Installation Script
# Supports: macOS, Linux (Ubuntu/Debian, CentOS/RHEL/Fedora, Arch)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                OS="debian"
                ;;
            centos|rhel|fedora)
                OS="redhat"
                ;;
            arch|manjaro)
                OS="arch"
                ;;
            *)
                OS="unknown"
                ;;
        esac
    else
        OS="unknown"
    fi
    
    log_info "Detected OS: $OS"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    if command_exists docker; then
        log_success "Docker already installed: $(docker --version)"
        return 0
    fi
    
    case "$OS" in
        macos)
            log_info "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
            log_warning "After installation, restart this script."
            exit 0
            ;;
        debian)
            # Remove old versions
            sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            
            # Install dependencies
            sudo apt-get update
            sudo apt-get install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
            
            # Add Docker GPG key
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Add repository
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
            # Add user to docker group
            sudo usermod -aG docker $USER
            log_warning "You need to log out and back in for docker group changes to take effect"
            ;;
        redhat)
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            ;;
        arch)
            sudo pacman -S --noconfirm docker docker-compose
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            ;;
        *)
            log_error "Unsupported OS for automatic Docker installation"
            log_info "Please install Docker manually: https://docs.docker.com/engine/install/"
            exit 1
            ;;
    esac
    
    log_success "Docker installed successfully!"
}

# Install kubectl
install_kubectl() {
    log_info "Installing kubectl..."
    
    if command_exists kubectl; then
        log_success "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return 0
    fi
    
    case "$OS" in
        macos)
            if command_exists brew; then
                brew install kubectl
            else
                # Install via curl
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/
            fi
            ;;
        debian)
            sudo apt-get update
            sudo apt-get install -y apt-transport-https ca-certificates curl
            curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
            echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
            sudo apt-get update
            sudo apt-get install -y kubectl
            ;;
        redhat)
            cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
EOF
            sudo yum install -y kubectl
            ;;
        arch)
            sudo pacman -S --noconfirm kubectl
            ;;
        *)
            # Generic installation
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
            ;;
    esac
    
    log_success "kubectl installed successfully!"
}

# Install Minikube
install_minikube() {
    log_info "Installing Minikube..."
    
    if command_exists minikube; then
        log_success "Minikube already installed: $(minikube version --short)"
        return 0
    fi
    
    case "$OS" in
        macos)
            if command_exists brew; then
                brew install minikube
            else
                curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
                sudo install minikube-darwin-amd64 /usr/local/bin/minikube
                rm minikube-darwin-amd64
            fi
            ;;
        debian|redhat|arch)
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
            sudo install minikube-linux-amd64 /usr/local/bin/minikube
            rm minikube-linux-amd64
            ;;
        *)
            log_error "Unsupported OS for Minikube installation"
            exit 1
            ;;
    esac
    
    log_success "Minikube installed successfully!"
}

# Install Homebrew (macOS)
install_homebrew() {
    if [[ "$OS" != "macos" ]]; then
        return 0
    fi
    
    if command_exists brew; then
        log_success "Homebrew already installed"
        return 0
    fi
    
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log_success "Homebrew installed successfully!"
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check CPU
    if [[ "$OS" == "macos" ]]; then
        CPU_CORES=$(sysctl -n hw.ncpu)
    else
        CPU_CORES=$(nproc)
    fi
    
    if [ "$CPU_CORES" -lt 4 ]; then
        log_warning "Recommended: 6+ CPU cores, found: $CPU_CORES"
    else
        log_success "CPU cores: $CPU_CORES ✓"
    fi
    
    # Check RAM
    if [[ "$OS" == "macos" ]]; then
        TOTAL_RAM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
    else
        TOTAL_RAM_GB=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
    fi
    
    if [ "$TOTAL_RAM_GB" -lt 12 ]; then
        log_warning "Recommended: 12GB+ RAM, found: ${TOTAL_RAM_GB}GB"
    else
        log_success "RAM: ${TOTAL_RAM_GB}GB ✓"
    fi
    
    # Check disk space
    if [[ "$OS" == "macos" ]]; then
        AVAILABLE_DISK_GB=$(df -g / | awk 'NR==2 {print $4}')
    else
        AVAILABLE_DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    fi
    
    if [ "$AVAILABLE_DISK_GB" -lt 50 ]; then
        log_warning "Recommended: 50GB+ free disk space, found: ${AVAILABLE_DISK_GB}GB"
    else
        log_success "Disk space: ${AVAILABLE_DISK_GB}GB available ✓"
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    echo ""
    
    local all_good=true
    
    if command_exists docker; then
        echo -e "${GREEN}✓${NC} Docker: $(docker --version)"
    else
        echo -e "${RED}✗${NC} Docker: Not found"
        all_good=false
    fi
    
    if command_exists kubectl; then
        echo -e "${GREEN}✓${NC} kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1)"
    else
        echo -e "${RED}✗${NC} kubectl: Not found"
        all_good=false
    fi
    
    if command_exists minikube; then
        echo -e "${GREEN}✓${NC} Minikube: $(minikube version --short)"
    else
        echo -e "${RED}✗${NC} Minikube: Not found"
        all_good=false
    fi
    
    echo ""
    
    if [ "$all_good" = true ]; then
        log_success "All prerequisites installed successfully! 🎉"
        echo ""
        log_info "Next steps:"
        echo "  1. If you installed Docker, you may need to log out and back in"
        echo "  2. Run: ./quickstart.sh"
        echo "  or"
        echo "  2. Run: ./scripts/deploy-all.sh"
    else
        log_error "Some prerequisites are missing. Please check the errors above."
        exit 1
    fi
}

# Main installation flow
main() {
    cat << "EOF"
╔══════════════════════════════════════════════════╗
║   Kubeflow Prerequisites Installation Script    ║
╚══════════════════════════════════════════════════╝
EOF
    echo ""
    
    # Detect OS
    detect_os
    
    if [[ "$OS" == "unknown" ]]; then
        log_error "Unsupported operating system"
        exit 1
    fi
    
    # Check requirements
    check_requirements
    echo ""
    
    # Ask for confirmation
    read -p "Do you want to proceed with installation? (yes/no): " confirmation
    if [ "$confirmation" != "yes" ]; then
        log_info "Installation cancelled."
        exit 0
    fi
    
    echo ""
    
    # Install Homebrew (macOS only)
    if [[ "$OS" == "macos" ]]; then
        install_homebrew
        echo ""
    fi
    
    # Install components
    install_docker
    echo ""
    
    install_kubectl
    echo ""
    
    install_minikube
    echo ""
    
    # Verify
    verify_installation
}

# Run main function
main