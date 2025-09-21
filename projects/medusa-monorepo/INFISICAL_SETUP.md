# Medusa Fresh - Infisical Secrets Setup Guide

This guide provides step-by-step instructions for setting up Infisical secrets for the Medusa Fresh e-commerce platform in a fresh session.

## 📁 Folder Structure

All secrets are organized in Infisical under the path: `/medusa-fresh` in the `prod` environment.

## 🔧 Setup Commands

### 1. Create Folder Structure
```bash
infisical secrets folders create --name medusa-fresh --env=prod
```

### 2. Set Backend Secrets

#### Core Medusa Secrets
```bash
# JWT signing secret (64 character base64)
infisical secrets set JWT_SECRET="$(openssl rand -base64 48)" --env=prod --path=/medusa-fresh

# Session cookie secret (64 character base64)
infisical secrets set COOKIE_SECRET="$(openssl rand -base64 48)" --env=prod --path=/medusa-fresh

# Admin user configuration
infisical secrets set ADMIN_EMAIL="admin@medusa.xuperson.org" --env=prod --path=/medusa-fresh
infisical secrets set ADMIN_PASSWORD="$(openssl rand -base64 32)" --env=prod --path=/medusa-fresh
```

#### Database Configuration
```bash
# Secure PostgreSQL password
infisical secrets set POSTGRES_PASSWORD="$(openssl rand -base64 32)" --env=prod --path=/medusa-fresh

# Complete database connection URL
POSTGRES_PASS=$(infisical secrets get POSTGRES_PASSWORD --env=prod --path=/medusa-fresh --plain)
infisical secrets set DATABASE_URL="postgres://postgres:${POSTGRES_PASS}@postgres:5432/medusa-store" --env=prod --path=/medusa-fresh
```

#### CORS Configuration
```bash
# Store frontend CORS
infisical secrets set STORE_CORS="https://medusa.xuperson.org,http://localhost:3000" --env=prod --path=/medusa-fresh

# Admin panel CORS
infisical secrets set ADMIN_CORS="https://medusa-admin.xuperson.org,http://localhost:9090" --env=prod --path=/medusa-fresh
```

### 3. Set Storefront Secrets

```bash
# Medusa publishable API key (get from existing database or generate new)
infisical secrets set NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY="pk_41e9965603f2febbab5e713391673b6e56c9d747c19d8b5cc77cef81360e6894" --env=prod --path=/medusa-fresh

# Default region for the storefront
infisical secrets set NEXT_PUBLIC_DEFAULT_REGION="dk" --env=prod --path=/medusa-fresh

# Production storefront base URL
infisical secrets set NEXT_PUBLIC_BASE_URL="https://medusa.xuperson.org" --env=prod --path=/medusa-fresh
```

### 4. Set CI/CD Secrets

```bash
# Gitea admin credentials for CI/CD pipeline
infisical secrets set ADMIN_USER="helloroot" --env=prod --path=/medusa-fresh
infisical secrets set ADMIN_PASS="$(openssl rand -base64 32)" --env=prod --path=/medusa-fresh
```

## 📋 Complete Secrets Reference

All production secrets in Infisical (`prod` environment, `/medusa-fresh` path):

| Secret Name                        | Purpose                    | Type      | Example/Format                    |
|------------------------------------|----------------------------|-----------|-----------------------------------|
| `JWT_SECRET`                       | Medusa JWT signing         | Generated | 64-char base64 string            |
| `COOKIE_SECRET`                    | Session cookies            | Generated | 64-char base64 string            |
| `POSTGRES_PASSWORD`                | Database password          | Generated | 44-char base64 string            |
| `DATABASE_URL`                     | Complete DB connection     | Composed  | postgres://user:pass@host:5432/db |
| `ADMIN_EMAIL`                      | Admin user email           | Set       | admin@medusa.xuperson.org        |
| `ADMIN_PASSWORD`                   | Admin user password        | Generated | 44-char base64 string            |
| `ADMIN_USER`                       | Gitea CI/CD username       | Set       | helloroot                        |
| `ADMIN_PASS`                       | Gitea CI/CD password       | Generated | 44-char base64 string            |
| `NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY` | Storefront API key        | Set       | pk_xxxx...                       |
| `NEXT_PUBLIC_DEFAULT_REGION`       | Default region (dk)        | Set       | dk                               |
| `STORE_CORS`                       | Frontend CORS              | Set       | https://domain.com,http://localhost |
| `ADMIN_CORS`                       | Admin CORS                 | Set       | https://admin.domain.com,http://localhost |
| `NEXT_PUBLIC_BASE_URL`             | Production URL             | Set       | https://medusa.xuperson.org      |

## 🔍 Verification Commands

### List All Secrets in Folder
```bash
# View all secrets in the medusa-fresh folder
infisical secrets get --env=prod --path=/medusa-fresh
```

### Get Individual Secret (for verification)
```bash
# Example: Get JWT secret (masked)
infisical secrets get JWT_SECRET --env=prod --path=/medusa-fresh

# Example: Get JWT secret (plain text - use carefully!)
infisical secrets get JWT_SECRET --env=prod --path=/medusa-fresh --plain
```

### Verify Folder Structure
```bash
# List all folders in prod environment
infisical secrets folders --env=prod
```

## 🔐 Security Notes

1. **Generated Secrets**: Use `openssl rand -base64 32` or `openssl rand -base64 48` for high-entropy secrets
2. **Database URL**: Automatically composed from individual components for security
3. **CORS Origins**: Include both production domains and localhost for development
4. **Path Organization**: All secrets under `/medusa-fresh` for clear separation
5. **Environment**: Use `prod` environment for production secrets

## 🚀 Usage in CI/CD

The CI/CD workflows in `.gitea/workflows/` automatically reference these secrets:

```yaml
# In Gitea Actions workflows
secrets.ADMIN_USER
secrets.ADMIN_PASS
```

## 📝 Notes

- **Publishable Key**: The example key `pk_41e9965603f2febbab5e713391673b6e56c9d747c19d8b5cc77cef81360e6894` is from the working database
- **Region**: Default region set to `dk` (Denmark) to match existing data
- **URLs**: Production URLs use `xuperson.org` domain pattern
- **Passwords**: All automatically generated passwords use 32-byte base64 encoding for security

## 🔄 Updating Secrets

To update a secret:
```bash
infisical secrets set SECRET_NAME="new_value" --env=prod --path=/medusa-fresh
```

To rotate all passwords:
```bash
# Example: Rotate admin password
infisical secrets set ADMIN_PASSWORD="$(openssl rand -base64 32)" --env=prod --path=/medusa-fresh

# Update database URL with new password
POSTGRES_PASS=$(infisical secrets get POSTGRES_PASSWORD --env=prod --path=/medusa-fresh --plain)
infisical secrets set DATABASE_URL="postgres://postgres:${POSTGRES_PASS}@postgres:5432/medusa-store" --env=prod --path=/medusa-fresh
```

---

**Last Updated**: 2025-09-20  
**Platform**: Medusa Fresh v2 + Next.js 15  
**Environment**: Production (`prod`)  
**Path**: `/medusa-fresh`