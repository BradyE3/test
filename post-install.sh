#!/bin/bash

# Concise post-install script for Docker, Docker Compose, PyTorch, and VS Code
set -e

echo "🚀 Starting development environment setup..."

# Update system and install basics
sudo apt update
sudo apt install -y curl wget git build-essential software-properties-common

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh && rm get-docker.sh
    sudo usermod -aG docker $USER
    echo "⚠️  Log out and back in for Docker group membership"
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    mkdir -p ~/.local/bin
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K[^"]*')
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o ~/.local/bin/docker-compose
    chmod +x ~/.local/bin/docker-compose
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

# Install VS Code
if ! command -v code &> /dev/null; then
    echo "📦 Installing VS Code..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    sudo apt update && sudo apt install code -y
    rm -f packages.microsoft.gpg
    
    # Install key extensions
    code --install-extension ms-python.python --force
    code --install-extension ms-toolsai.jupyter --force
    code --install-extension ms-azuretools.vscode-docker --force
fi

# Install Miniconda and PyTorch
if [ ! -d "$HOME/miniconda3" ]; then
    echo "📦 Installing Miniconda and PyTorch..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
    bash ~/miniconda.sh -b -p $HOME/miniconda3 && rm ~/miniconda.sh
    $HOME/miniconda3/bin/conda init bash
    
    # Create PyTorch environment
    source $HOME/miniconda3/etc/profile.d/conda.sh
    conda create -n pytorch python=3.9 -y
    conda activate pytorch
    conda install pytorch torchvision torchaudio cpuonly -c pytorch -y
    conda install numpy pandas matplotlib jupyter -y
fi

# Install Node.js via nvm
if [ ! -d "$HOME/.nvm" ]; then
    echo "📦 Installing Node.js..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts && nvm use --lts
fi

# Install additional tools
pip install --user requests flask fastapi black pytest

echo "✅ Setup complete! Next steps:"
echo "1. Log out and back in (for Docker)"
echo "2. Restart terminal or: source ~/.bashrc"
echo "3. Activate PyTorch: conda activate pytorch"
echo "4. Test: docker --version && code --version"
