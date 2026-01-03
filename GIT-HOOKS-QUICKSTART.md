# 🚀 Git Hooks Quick Start

Pre-commit hooks với Gitleaks đã được cài đặt thành công!

## ✅ Đã hoàn thành

- ✅ Pre-commit framework đã cài đặt và hoạt động
- ✅ Gitleaks đã được tích hợp để phát hiện secrets
- ✅ Hooks tự động chặn commits và pushes có chứa secrets
- ✅ Auto-fix cho formatting issues (trailing whitespace, line endings, etc.)

## 📝 Những gì đã được test

### Test 1: Commit bình thường ✅
```powershell
git commit -m "feat: setup git hooks"
# ✅ PASSED - All hooks ran successfully
```

### Test 2: Commit với secrets ❌
```powershell
echo "spring.datasource.password=SuperSecret123!" > test.txt
git add test.txt
git commit -m "test"
# ❌ BLOCKED - Gitleaks detected secret!
```

## 🔍 Hooks đang hoạt động

1. **Gitleaks Secret Scanner** - Phát hiện:
   - AWS keys
   - Database passwords
   - API keys
   - JWT tokens
   - OAuth secrets
   - Private keys

2. **Code Quality Checks**:
   - Trim trailing whitespace
   - Fix end of files
   - Check YAML syntax
   - Detect private keys
   - Fix mixed line endings
   - Format Java code

## 📚 Cách sử dụng

### Commit bình thường
```bash
git add .
git commit -m "your message"
# Hooks sẽ tự động chạy
```

### Nếu phát hiện secrets
1. Hooks sẽ block và hiển thị file + dòng có secret
2. Sửa file, xóa secrets
3. Sử dụng environment variables thay thế
4. Commit lại

### Ví dụ sửa secrets

❌ Trước (sẽ bị block):
```yaml
spring.datasource.password=MyPassword123
```

✅ Sau (sẽ pass):
```yaml
spring.datasource.password=${DB_PASSWORD}
```

## ⚙️ Cấu hình

- **Gitleaks config**: [.gitleaks.toml](.gitleaks.toml)
- **Pre-commit config**: [.pre-commit-config.yaml](.pre-commit-config.yaml)
- **Documentation**: [docs/GIT-HOOKS-SETUP.md](docs/GIT-HOOKS-SETUP.md)

## 🔧 Nếu có vấn đề

Xem troubleshooting trong [docs/GIT-HOOKS-SETUP.md](docs/GIT-HOOKS-SETUP.md#-troubleshooting)

## 🎯 Next Steps

1. ✅ **Setup hoàn tất** - Hooks đã hoạt động!
2. Đảm bảo team members cũng chạy setup:
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\setup-git-hooks.ps1
   ```
3. Setup server-side hooks (xem docs)
4. Cấu hình CI/CD với gitleaks

---

**💡 Tip**: Nếu bạn muốn tạm thời skip hooks (KHÔNG khuyến nghị):
```bash
git commit --no-verify -m "message"
```

Nhưng đừng làm điều này trừ khi bạn biết chính xác mình đang làm gì!
