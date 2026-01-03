#!/usr/bin/env bash
# Setup script for installing Git hooks
# This script installs pre-commit hooks and configures gitleaks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Git Hooks Setup Script${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}❌ ERROR: Not a git repository!${NC}"
    echo "Please run this script from the root of your git repository."
    exit 1
fi

echo -e "${GREEN}✓${NC} Git repository detected"

# Check if gitleaks is installed
echo ""
echo "Checking for gitleaks..."
if command -v gitleaks &> /dev/null; then
    version=$(gitleaks version)
    echo -e "${GREEN}✓${NC} Gitleaks is installed: $version"
else
    echo -e "${YELLOW}⚠️  Gitleaks is not installed${NC}"
    echo ""
    echo "Gitleaks is required for secret detection. Please install it:"
    echo ""
    echo "Windows (Chocolatey):"
    echo "  choco install gitleaks"
    echo ""
    echo "Windows (Scoop):"
    echo "  scoop install gitleaks"
    echo ""
    echo "macOS (Homebrew):"
    echo "  brew install gitleaks"
    echo ""
    echo "Linux:"
    echo "  Visit: https://github.com/gitleaks/gitleaks#installing"
    echo ""
    read -p "Continue without gitleaks? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if pre-commit is installed
echo ""
echo "Checking for pre-commit framework..."
if command -v pre-commit &> /dev/null; then
    version=$(pre-commit --version)
    echo -e "${GREEN}✓${NC} Pre-commit framework is installed: $version"
else
    echo -e "${YELLOW}⚠️  Pre-commit framework is not installed${NC}"
    echo ""
    echo "Pre-commit framework is recommended. Install it with:"
    echo ""
    echo "Python (pip):"
    echo "  pip install pre-commit"
    echo ""
    echo "macOS (Homebrew):"
    echo "  brew install pre-commit"
    echo ""
    read -p "Continue without pre-commit framework? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install hooks
echo ""
echo -e "${BLUE}Installing Git hooks...${NC}"

# Create .git/hooks directory if it doesn't exist
mkdir -p .git/hooks

# Copy pre-commit hook
if [ -f ".git-hooks/pre-commit" ]; then
    cp .git-hooks/pre-commit .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    echo -e "${GREEN}✓${NC} Installed pre-commit hook"
fi

# Copy pre-push hook
if [ -f ".git-hooks/pre-push" ]; then
    cp .git-hooks/pre-push .git/hooks/pre-push
    chmod +x .git/hooks/pre-push
    echo -e "${GREEN}✓${NC} Installed pre-push hook"
fi

# Install pre-commit framework hooks if available
if command -v pre-commit &> /dev/null && [ -f ".pre-commit-config.yaml" ]; then
    echo ""
    echo -e "${BLUE}Installing pre-commit framework hooks...${NC}"
    pre-commit install
    pre-commit install --hook-type pre-push
    echo -e "${GREEN}✓${NC} Pre-commit framework hooks installed"
fi

# Test gitleaks configuration
echo ""
echo -e "${BLUE}Testing gitleaks configuration...${NC}"
if command -v gitleaks &> /dev/null && [ -f ".gitleaks.toml" ]; then
    # Run a quick test
    if gitleaks detect --no-git --config .gitleaks.toml --verbose 2>&1 | head -n 5; then
        echo -e "${GREEN}✓${NC} Gitleaks configuration is valid"
    fi
fi

# Success message
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✅ Setup completed successfully!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Git hooks have been installed and configured."
echo ""
echo "What's next:"
echo "  • Commits will be scanned for secrets automatically"
echo "  • Pushes will be blocked if secrets are detected"
echo "  • Configure .gitleaks.toml to customize secret detection rules"
echo ""
echo "To test the setup:"
echo "  1. Create a test file with a dummy secret"
echo "  2. Try to commit it: git add . && git commit -m 'test'"
echo "  3. The commit should be blocked"
echo ""
echo "For server-side hooks:"
echo "  Copy .git-hooks/update to your Git server's hooks directory"
echo ""
