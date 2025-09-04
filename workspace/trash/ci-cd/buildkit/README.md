# BuildKit Service

High-performance container image builder service deployed as a Kubernetes application using BuildKit.

## Overview

BuildKit is a next-generation container image builder that provides:
- Parallel build execution
- Advanced caching mechanisms
- Security scanning integration
- Multi-platform builds
- Rootless operation

## Architecture

- **Deployment**: Rootless BuildKit daemon with TLS encryption
- **Service**: MetalLB LoadBalancer for internal cluster access
- **Security**: SOPS-encrypted TLS certificates
- **Storage**: Ephemeral cache with Longhorn persistence option

## Access

- **Internal LoadBalancer**: `192.168.80.110:1234`
- **Service DNS**: `buildkitd.buildkit.svc.cluster.local:1234`
- **TLS**: Required for secure communication

## Usage in CI/CD

### Docker Buildx Integration

```bash
# Create BuildKit builder context
docker buildx create \
  --name buildkit-builder \
  --driver remote \
  --driver-opt cacert=/path/to/ca.pem,cert=/path/to/client.pem,key=/path/to/client.key \
  tcp://192.168.80.110:1234

# Use for builds
docker buildx build \
  --builder buildkit-builder \
  --platform linux/amd64 \
  --push \
  -t myapp:latest \
  .
```

### Direct BuildKit Usage

```bash
# Using buildctl
buildctl --addr tcp://192.168.80.110:1234 \
  --tlscacert /path/to/ca.pem \
  --tlscert /path/to/client.pem \
  --tlskey /path/to/client.key \
  build --frontend dockerfile.v0 --local context=. --local dockerfile=.
```

## Certificate Management

TLS certificates are managed through SOPS-encrypted secrets:

```bash
# Edit certificates
SOPS_AGE_KEY_FILE=secrets/age/age-key.txt sops edit secrets/apps/buildkit.xuperson.org-secrets.yaml

# Required certificate fields:
# - ca.pem: Certificate Authority
# - cert.pem: Server certificate
# - key.pem: Server private key
```

## Scaling

For high-availability, scale the deployment:

```bash
kubectl scale deployment buildkitd -n buildkit --replicas=3
```

Consider using StatefulSet for persistent caching across replicas.

## Monitoring

```bash
# Check deployment status
kubectl get pods -n buildkit
kubectl get svc -n buildkit

# View logs
kubectl logs -n buildkit deployment/buildkitd

# Check resource usage
kubectl top pods -n buildkit
```

## Troubleshooting

### Common Issues

1. **TLS Connection Failed**
   - Verify certificates are properly base64 encoded in secrets
   - Check certificate validity and SAN (Subject Alternative Name)

2. **Build Performance**
   - Monitor resource usage and adjust limits
   - Consider persistent volume for build cache

3. **Service Unavailable**
   - Check MetalLB IP allocation
   - Verify BGP routing from EdgeRouter

### Debug Commands

```bash
# Test BuildKit connectivity
buildctl --addr tcp://192.168.80.110:1234 debug workers

# Check certificate validity
openssl x509 -in /path/to/cert.pem -text -noout

# View service endpoints
kubectl get endpoints -n buildkit
```
