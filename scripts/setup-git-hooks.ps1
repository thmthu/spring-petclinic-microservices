# Git Hooks Setup Script for Windows
# This script installs pre-commit hooks and configures gitleaks
# Run this with: powershell -ExecutionPolicy Bypass -File scripts\setup-git-hooks.ps1

$ErrorActionPreference = "Stop"

Write-Host "================================" -ForegroundColor Blue
Write-Host "Git Hooks Setup Script" -ForegroundColor Blue
Write-Host "================================" -ForegroundColor Blue
Write-Host ""

# Check if we're in a git repository
if (-not (Test-Path ".git" -PathType Container)) {
    Write-Host "❌ ERROR: Not a git repository!" -ForegroundColor Red
    Write-Host "Please run this script from the root of your git repository."
    exit 1
}

Write-Host "✓ Git repository detected" -ForegroundColor Green

# Check if gitleaks is installed
Write-Host ""
Write-Host "Checking for gitleaks..."
try {
    $gitleaksVersion = & gitleaks version 2>&1
    Write-Host "✓ Gitleaks is installed: $gitleaksVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Gitleaks is not installed" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Gitleaks is required for secret detection. Please install it:"
    Write-Host ""
    Write-Host "Windows (Chocolatey):"
    Write-Host "  choco install gitleaks"
    Write-Host ""
    Write-Host "Windows (Scoop):"
    Write-Host "  scoop install gitleaks"
    Write-Host ""
    Write-Host "Manual installation:"
    Write-Host "  Visit: https://github.com/gitleaks/gitleaks/releases"
    Write-Host ""
    $continue = Read-Host "Continue without gitleaks? (y/N)"
    if ($continue -notmatch '^[Yy]$') {
        exit 1
    }
}

# Check if pre-commit is installed
Write-Host ""
Write-Host "Checking for pre-commit framework..."
try {
    $precommitVersion = & pre-commit --version 2>&1
    Write-Host "✓ Pre-commit framework is installed: $precommitVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Pre-commit framework is not installed" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pre-commit framework is recommended. Install it with:"
    Write-Host ""
    Write-Host "Python (pip):"
    Write-Host "  pip install pre-commit"
    Write-Host ""
    Write-Host "Or download from: https://pre-commit.com/#install"
    Write-Host ""
    $continue = Read-Host "Continue without pre-commit framework? (y/N)"
    if ($continue -notmatch '^[Yy]$') {
        exit 1
    }
}

# Install hooks
Write-Host ""
Write-Host "Installing Git hooks..." -ForegroundColor Blue

# Create .git/hooks directory if it doesn't exist
New-Item -ItemType Directory -Force -Path ".git\hooks" | Out-Null

# Copy pre-commit hook (convert to Windows format if needed)
if (Test-Path ".git-hooks\pre-commit") {
    # For Windows, we need to create a wrapper that calls bash or uses PowerShell
    $preCommitContent = @"
#!/bin/sh
# Pre-commit hook wrapper for Windows
# This calls the actual pre-commit script

if command -v bash >/dev/null 2>&1; then
    bash .git-hooks/pre-commit
else
    # Fallback to basic gitleaks check
    if command -v gitleaks >/dev/null 2>&1; then
        gitleaks protect --verbose --redact --staged --config .gitleaks.toml
    else
        echo "WARNING: Gitleaks not found. Skipping secret detection."
        exit 0
    fi
fi
"@
    $preCommitContent | Out-File -FilePath ".git\hooks\pre-commit" -Encoding ASCII -NoNewline
    Write-Host "✓ Installed pre-commit hook" -ForegroundColor Green
}

# Copy pre-push hook (convert to Windows format if needed)
if (Test-Path ".git-hooks\pre-push") {
    $prePushContent = @"
#!/bin/sh
# Pre-push hook wrapper for Windows
# This calls the actual pre-push script

if command -v bash >/dev/null 2>&1; then
    bash .git-hooks/pre-push "$@"
else
    # Fallback to basic gitleaks check
    if command -v gitleaks >/dev/null 2>&1; then
        gitleaks protect --verbose --redact --staged --config .gitleaks.toml
    else
        echo "WARNING: Gitleaks not found. Skipping secret detection."
        exit 0
    fi
fi
"@
    $prePushContent | Out-File -FilePath ".git\hooks\pre-push" -Encoding ASCII -NoNewline
    Write-Host "✓ Installed pre-push hook" -ForegroundColor Green
}

# Install pre-commit framework hooks if available
if ((Get-Command pre-commit -ErrorAction SilentlyContinue) -and (Test-Path ".pre-commit-config.yaml")) {
    Write-Host ""
    Write-Host "Installing pre-commit framework hooks..." -ForegroundColor Blue
    try {
        & pre-commit install
        & pre-commit install --hook-type pre-push
        Write-Host "✓ Pre-commit framework hooks installed" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Failed to install pre-commit framework hooks" -ForegroundColor Yellow
    }
}

# Test gitleaks configuration
Write-Host ""
Write-Host "Testing gitleaks configuration..." -ForegroundColor Blue
if ((Get-Command gitleaks -ErrorAction SilentlyContinue) -and (Test-Path ".gitleaks.toml")) {
    try {
        $null = & gitleaks detect --no-git --config .gitleaks.toml --verbose 2>&1 | Select-Object -First 5
        Write-Host "✓ Gitleaks configuration is valid" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Gitleaks configuration test failed (this may be normal)" -ForegroundColor Yellow
    }
}

# Success message
Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "✅ Setup completed successfully!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "Git hooks have been installed and configured."
Write-Host ""
Write-Host "What's next:"
Write-Host "  • Commits will be scanned for secrets automatically"
Write-Host "  • Pushes will be blocked if secrets are detected"
Write-Host "  • Configure .gitleaks.toml to customize secret detection rules"
Write-Host ""
Write-Host "To test the setup:"
Write-Host "  1. Create a test file with a dummy secret"
Write-Host "  2. Try to commit it: git add . && git commit -m 'test'"
Write-Host "  3. The commit should be blocked"
Write-Host ""
Write-Host "For server-side hooks:"
Write-Host "  Copy .git-hooks\update to your Git server's hooks directory"
Write-Host ""
Write-Host "Note: Make sure Git Bash or WSL is installed for hooks to work properly on Windows."
Write-Host ""
