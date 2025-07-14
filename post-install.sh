#!/bin/bash

# User-space post-install script for Docker, Docker Compose, and PyTorch
# This script installs tools in user space where possible

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create local bin directory if it doesn't exist
mkdir -p ~/.local/bin

# Add ~/.local/bin to PATH if not already there
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    export PATH="$HOME/.local/bin:$PATH"
    log "Added ~/.local/bin to PATH"
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker (requires sudo for system-wide installation)
install_docker() {
    log "Installing Docker..."
    
    if command_exists docker; then
        success "Docker is already installed"
        return 0
    fi
    
    # Check if we're on a supported system
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Install Docker using the official script
        if command_exists curl; then
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            rm get-docker.sh
            
            # Add user to docker group to avoid needing sudo
            sudo usermod -aG docker $USER
            warning "You need to log out and back in for Docker group membership to take effect"
        else
            error "curl is required to install Docker"
            return 1
        fi
    else
        error "Docker installation script only supports Linux. Please install Docker manually."
        return 1
    fi
    
    success "Docker installation completed"
}

# Function to install Docker Compose
install_docker_compose() {
    log "Installing Docker Compose..."
    
    if command_exists docker-compose; then
        success "Docker Compose is already installed"
        return 0
    fi
    
    # Get latest release version
    if command_exists curl; then
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K[^"]*')
        
        # Download and install Docker Compose
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o ~/.local/bin/docker-compose
        chmod +x ~/.local/bin/docker-compose
        
        success "Docker Compose ${COMPOSE_VERSION} installed successfully"
    else
        error "curl is required to install Docker Compose"
        return 1
    fi
}

# Function to install Miniconda (for PyTorch)
install_miniconda() {
    log "Installing Miniconda..."
    
    if [ -d "$HOME/miniconda3" ]; then
        success "Miniconda is already installed"
        return 0
    fi
    
    # Download and install Miniconda
    if command_exists wget; then
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
    elif command_exists curl; then
        curl -o ~/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    else
        error "wget or curl is required to install Miniconda"
        return 1
    fi
    
    # Install Miniconda silently
    bash ~/miniconda.sh -b -p $HOME/miniconda3
    rm ~/miniconda.sh
    
    # Initialize conda
    $HOME/miniconda3/bin/conda init bash
    
    success "Miniconda installed successfully"
}

# Function to install PyTorch
install_pytorch() {
    log "Installing PyTorch..."
    
    # Source conda to make it available in this script
    source $HOME/miniconda3/etc/profile.d/conda.sh
    
    # Create a new conda environment for PyTorch
    conda create -n pytorch python=3.9 -y
    conda activate pytorch
    
    # Install PyTorch (CPU version - change if you need GPU support)
    conda install pytorch torchvision torchaudio cpuonly -c pytorch -y
    
    # Install additional useful packages
    conda install numpy pandas matplotlib jupyter -y
    pip install tensorboard
    
    success "PyTorch environment created and packages installed"
    log "To activate the PyTorch environment, run: conda activate pytorch"
}

# Function to install Python pip packages in user space
install_pip_packages() {
    log "Installing additional Python packages..."
    
    # Install useful packages for development
    pip install --user \
        requests \
        flask \
        fastapi \
        uvicorn \
        black \
        flake8 \
        pytest \
        python-dotenv
    
    success "Additional Python packages installed"
}

# Function to install Node.js using Node Version Manager (nvm)
install_nodejs() {
    log "Installing Node.js via nvm..."
    
    if [ -d "$HOME/.nvm" ]; then
        success "nvm is already installed"
        return 0
    fi
    
    # Install nvm
    if command_exists curl; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    elif command_exists wget; then
        wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    else
        error "curl or wget is required to install nvm"
        return 1
    fi
    
    # Source nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install latest LTS Node.js
    nvm install --lts
    nvm use --lts
    
    success "Node.js installed via nvm"
}

# Function to install useful development tools
install_dev_tools() {
    log "Installing development tools..."
    
    # Install GitHub CLI if not present
    if ! command_exists gh; then
        if command_exists curl; then
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt update
            sudo apt install gh -y
        else
            warning "Skipping GitHub CLI installation (curl not available)"
        fi
    fi
    
    # Install other useful tools that can be installed in user space
    pip install --user \
        httpie \
        tldr \
        cookiecutter
    
    success "Development tools installed"
}

# Main installation function
main() {
    log "Starting post-install setup..."
    
    # Update package lists (requires sudo)
    if command_exists apt; then
        sudo apt update
    elif command_exists yum; then
        sudo yum update
    elif command_exists dnf; then
        sudo dnf update
    fi
    
    # Install basic dependencies
    log "Installing basic dependencies..."
    if command_exists apt; then
        sudo apt install -y curl wget git build-essential
    elif command_exists yum; then
        sudo yum install -y curl wget git gcc gcc-c++ make
    elif command_exists dnf; then
        sudo dnf install -y curl wget git gcc gcc-c++ make
    fi
    
    # Install Docker
    install_docker
    
    # Install Docker Compose
    install_docker_compose
    
    # Install Miniconda
    install_miniconda
    
    # Install PyTorch
    install_pytorch
    
    # Install additional Python packages
    install_pip_packages
    
    # Install Node.js
    install_nodejs
    
    # Install development tools
    install_dev_tools
    
    success "Post-install setup completed!"
    
    echo
    log "Next steps:"
    echo "1. Log out and back in to activate Docker group membership"
    echo "2. Restart your terminal or run: source ~/.bashrc"
    echo "3. To use PyTorch, run: conda activate pytorch"
    echo "4. Test Docker with: docker --version"
    echo "5. Test Docker Compose with: docker-compose --version"
    echo "6. Test PyTorch with: python -c 'import torch; print(torch.__version__)'"
}

# Run main function
main "$@"
