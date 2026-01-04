# Git Hooks - Secret Detection Setup

Hệ thống Git hooks với gitleaks để phát hiện và ngăn chặn secrets trong code.

## 📋 Tổng quan

Dự án này sử dụng nhiều lớp bảo mật để ngăn chặn secrets bị commit và push lên repository:

1. **Pre-commit hooks**: Quét secrets trước khi commit
2. **Pre-push hooks**: Quét secrets trước khi push lên remote
3. **Server-side hooks**: Quét secrets trên Git server (reject push)
4. **Pre-commit framework**: Tích hợp các công cụ kiểm tra code tự động

## 🚀 Cài đặt

### Bước 1: Cài đặt Gitleaks

Gitleaks là công cụ chính để phát hiện secrets.

**Windows (Chocolatey):**
```powershell
choco install gitleaks
```

**Windows (Scoop):**
```powershell
scoop install gitleaks
```

**macOS (Homebrew):**
```bash
brew install gitleaks
```

**Linux:**
```bash
# Download binary từ GitHub releases
wget https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks-linux-amd64
chmod +x gitleaks-linux-amd64
sudo mv gitleaks-linux-amd64 /usr/local/bin/gitleaks
```

Kiểm tra cài đặt:
```bash
gitleaks version
```

### Bước 2: Cài đặt Pre-commit Framework (Tùy chọn nhưng khuyến nghị)

**Python pip:**
```bash
pip install pre-commit
```

**macOS (Homebrew):**
```bash
brew install pre-commit
```

**Windows:**
```powershell
pip install pre-commit
```

### Bước 3: Chạy script setup

**Trên Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup-git-hooks.ps1
```

**Trên Linux/macOS:**
```bash
chmod +x scripts/setup-git-hooks.sh
./scripts/setup-git-hooks.sh
```

## 📁 Cấu trúc Files

```
.
├── .pre-commit-config.yaml      # Cấu hình pre-commit framework
├── .gitleaks.toml               # Cấu hình gitleaks (custom rules)
├── .git-hooks/                  # Git hooks templates
│   ├── pre-commit              # Hook chạy trước commit
│   ├── pre-push                # Hook chạy trước push
│   └── update                  # Server-side hook (cho Git server)
└── scripts/
    ├── setup-git-hooks.sh      # Script setup cho Linux/macOS
    └── setup-git-hooks.ps1     # Script setup cho Windows
```

## 🔒 Các loại Secrets được phát hiện

Gitleaks có thể phát hiện nhiều loại secrets:

### Mặc định (Built-in rules):
- AWS Access Keys & Secret Keys
- GitHub tokens
- GitLab tokens
- Private SSH keys
- Generic API keys
- JWT tokens
- Database passwords
- OAuth tokens

### Custom rules (được định nghĩa trong .gitleaks.toml):
- Spring datasource passwords
- Spring datasource usernames (không phải test accounts)
- JWT secrets
- API key headers
- OAuth client secrets
- Docker registry passwords
- Generic API tokens

## 🎯 Cách hoạt động

### 1. Pre-commit Hook
- **Khi**: Trước khi commit được tạo
- **Scope**: Chỉ quét các files đã được staged (`git add`)
- **Hành động**: Block commit nếu phát hiện secrets
- **Bypass**: `git commit --no-verify` (KHÔNG khuyến nghị)

### 2. Pre-push Hook
- **Khi**: Trước khi push lên remote repository
- **Scope**: Quét tất cả commits sẽ được push
- **Hành động**: Block push nếu phát hiện secrets
- **Bypass**: `git push --no-verify` (KHÔNG khuyến nghị)

### 3. Server-side Hook (Update)
- **Khi**: Khi server nhận được push request
- **Scope**: Quét tất cả commits trong push
- **Hành động**: Reject push từ phía server
- **Bypass**: Không thể bypass (trừ khi có quyền admin server)

## 📝 Ví dụ sử dụng

### Test setup
Tạo file test với dummy secret:
```bash
echo "aws_access_key_id=AKIAIOSFODNN7EXAMPLE" > test-secret.txt
git add test-secret.txt
git commit -m "test commit"
```

Kết quả mong đợi:
```
🔍 Running pre-commit checks...
========================================
❌ SECRETS DETECTED! Commit rejected.
```

### Sửa lỗi khi phát hiện secrets

1. **Xem chi tiết phát hiện**: Gitleaks sẽ hiển thị file và dòng có secrets
2. **Remove secrets**: Xóa hoặc thay thế bằng environment variables
3. **Stage lại files**: `git add <fixed-files>`
4. **Commit lại**: `git commit -m "fix: remove hardcoded secrets"`

### Sử dụng Environment Variables

❌ **KHÔNG làm** (hardcoded):
```yaml
spring:
  datasource:
    username: admin
    password: MySecretPassword123!
```

✅ **NÊN làm** (environment variables):
```yaml
spring:
  datasource:
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
```

Hoặc trong Java code:
```java
// ❌ KHÔNG
String apiKey = "sk-1234567890abcdefghijklmnop";

// ✅ NÊN
String apiKey = System.getenv("API_KEY");
```

## ⚙️ Cấu hình

### Allowlist (Bỏ qua false positives)

Chỉnh sửa `.gitleaks.toml` để thêm exceptions:

```toml
[allowlist]
paths = [
    '''path/to/test/file\.java''',
]

regexes = [
    '''password\s*[:=]\s*['"]?test['"]?''',  # Allow "password=test"
]
```

### Thêm custom rules

Thêm rules mới vào `.gitleaks.toml`:

```toml
[[rules]]
id = "my-custom-secret"
description = "Detected my custom secret pattern"
regex = '''my-secret-pattern-here'''
tags = ["custom", "secret"]
```

### Tùy chỉnh pre-commit framework

Chỉnh sửa `.pre-commit-config.yaml` để thêm hoặc bỏ hooks:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-yaml
      - id: check-json
      # Thêm hooks khác ở đây
```

## 🔧 Troubleshooting

### ⚠️ Windows: ExecutableNotFoundError: `/bin/sh` not found

**Vấn đề**: Pre-commit framework cần Git Bash để chạy trên Windows.

**Giải pháp 1 - Cài đặt Git Bash (Khuyến nghị):**

Git Bash thường đã được cài cùng Git for Windows. Kiểm tra:
```powershell
# Kiểm tra Git Bash
where bash
where sh

# Nếu không có, tải Git for Windows từ:
# https://git-scm.com/download/win
# Chọn "Git Bash" trong quá trình cài đặt
```

**Giải pháp 2 - Sử dụng WSL (Windows Subsystem for Linux):**
```powershell
# Cài đặt WSL
wsl --install

# Sau khi cài, mở WSL và chạy setup script
wsl
cd /mnt/d/HCMUS/Advance\ DevOps/spring-petclinic-microservices/
./scripts/setup-git-hooks.sh
```

**Giải pháp 3 - Skip pre-commit framework, chỉ dùng Git hooks:**
```powershell
# Chạy script PowerShell để cài đặt hooks trực tiếp
powershell -ExecutionPolicy Bypass -File scripts\setup-git-hooks.ps1

# Sau đó uninstall pre-commit framework hooks
pre-commit uninstall

# Giờ chỉ Git hooks sẽ chạy (không cần /bin/sh)
```

**Giải pháp 4 - Thêm Git Bash vào PATH:**
```powershell
# Thêm Git Bash vào System PATH (chạy với quyền Admin)
# Thường Git Bash ở: C:\Program Files\Git\bin

# Hoặc tạo symbolic link
New-Item -ItemType SymbolicLink -Path "C:\bin" -Target "C:\Program Files\Git\bin" -Force
```

Sau khi áp dụng giải pháp, thử commit lại:
```bash
git commit -m "test"
```

### Gitleaks không được nhận diện
```bash
# Kiểm tra PATH
which gitleaks  # Linux/macOS
where gitleaks  # Windows

# Reinstall nếu cần
choco install gitleaks --force  # Windows
brew reinstall gitleaks         # macOS
```

### Hooks không chạy
```bash
# Kiểm tra hooks có được cài đặt
ls -la .git/hooks/

# Kiểm tra quyền executable (Linux/macOS)
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/pre-push

# Reinstall hooks
./scripts/setup-git-hooks.sh
```

### False positives quá nhiều
Cập nhật `.gitleaks.toml`:
```toml
[allowlist]
regexes = [
    '''pattern-to-ignore''',
]
```

### Muốn tạm thời skip hooks
```bash
# Skip pre-commit (không khuyến nghị)
git commit --no-verify -m "message"

# Skip pre-push (không khuyến nghị)
git push --no-verify
```

## 🏢 Setup Server-side Hooks

Để setup trên Git server (GitLab, GitHub Enterprise, Gitea, etc.):

### 1. Bare repository (Git server)
```bash
# Copy hook vào server
scp .git-hooks/update user@gitserver:/path/to/repo.git/hooks/

# Set permissions
ssh user@gitserver "chmod +x /path/to/repo.git/hooks/update"

# Cài gitleaks trên server
ssh user@gitserver "brew install gitleaks"  # hoặc method khác
```

### 2. GitLab CI/CD
Thêm vào `.gitlab-ci.yml`:
```yaml
secret-detection:
  stage: test
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks detect --verbose --config .gitleaks.toml
  allow_failure: false
```

### 3. GitHub Actions
Thêm vào `.github/workflows/secrets.yml`:
```yaml
name: Secret Detection
on: [push, pull_request]
jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 📚 Best Practices

1. **Never commit secrets**: Luôn sử dụng environment variables hoặc secret management tools
2. **Review hooks regularly**: Cập nhật rules trong `.gitleaks.toml` khi cần
3. **Train team**: Đảm bảo team hiểu cách làm việc với hooks
4. **Use secret managers**: AWS Secrets Manager, Azure Key Vault, HashiCorp Vault
5. **Rotate secrets**: Nếu secrets bị leak, rotate ngay lập tức
6. **Never use --no-verify**: Trừ khi có lý do chính đáng và đã được approve

## 🔗 Resources

- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [Pre-commit Framework](https://pre-commit.com/)
- [Git Hooks Documentation](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
- [OWASP Secret Management](https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password)

## 🆘 Support

Nếu gặp vấn đề:
1. Xem phần Troubleshooting ở trên
2. Check logs: `.git/hooks/pre-commit` và `.git/hooks/pre-push`
3. Contact DevOps team
4. Tạo issue với đầy đủ thông tin lỗi

## 📄 License

This configuration is part of the Spring PetClinic Microservices project.
