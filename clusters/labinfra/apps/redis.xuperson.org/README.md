# Redis with REST API

Production Redis deployment with native TCP access and HTTP REST API via Cloudflare tunneling.

## Access Methods

### 1. Native Redis Protocol (TCP)
- **External**: `192.168.80.110:6379`
- **Internal**: `redis-server.redis.svc.cluster.local:6379`
- **Same namespace**: `redis-server:6379`

### 2. HTTP REST API (HTTPS via Cloudflare)
- **URL**: `https://redis-api.xuperson.org`
- **Format**: Upstash-compatible REST API

## Authentication

All access requires password authentication stored in Infisical.

**Secrets in Infisical (`prod` environment):**
- `REDIS_PASSWORD`: Generated random password
- `REDIS_URL`: Complete connection string

**Kubernetes Secrets (auto-synced):**
- `redis-secrets.redis-password`: Password for direct connections
- `redis-secrets.redis-url`: Full Redis URL format

## Usage Examples

### Native Redis (TCP)
```bash
# Direct connection
redis-cli -h 192.168.80.110 -p 6379 -a "PASSWORD" ping

# Application connection
REDIS_URL="redis://default:PASSWORD@192.168.80.110:6379"
```

### REST API (HTTP)
```bash
# PING
curl -X POST https://redis-api.xuperson.org/ \
  -H "Authorization: Bearer PASSWORD" \
  -H "Content-Type: application/json" \
  -d '["PING"]'

# SET
curl -X POST https://redis-api.xuperson.org/ \
  -H "Authorization: Bearer PASSWORD" \
  -H "Content-Type: application/json" \
  -d '["SET", "key", "value"]'

# GET  
curl -X POST https://redis-api.xuperson.org/ \
  -H "Authorization: Bearer PASSWORD" \
  -H "Content-Type: application/json" \
  -d '["GET", "key"]'
```

### Kubernetes Applications
```yaml
env:
- name: REDIS_URL
  valueFrom:
    secretKeyRef:
      name: redis-secrets
      key: redis-url
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: redis-secrets
      key: redis-password
```

## Components

- **Redis Server**: Official `redis:7.2-alpine` with persistence
- **REST API Proxy**: `hiett/serverless-redis-http` (Upstash-compatible)
- **LoadBalancer**: MetalLB IP `192.168.80.110`
- **Ingress**: NGINX + Cloudflare tunnel for HTTPS REST API
- **Secrets**: Infisical integration with auto-sync

## Features

- ✅ **Dual Access**: Both TCP and HTTP protocols
- ✅ **External Access**: LoadBalancer + Cloudflare tunneling  
- ✅ **Authentication**: Password protection on all endpoints
- ✅ **Persistence**: AOF enabled for data durability
- ✅ **Cloud Compatible**: Upstash REST API format