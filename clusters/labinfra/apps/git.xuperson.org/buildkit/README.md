# BuildKit Service

High-performance container image builder service integrated with Gitea for CI/CD workflows.

## Overview

BuildKit is a next-generation container image builder that provides:
- Parallel build execution
- Advanced caching mechanisms
- Security scanning integration
- Multi-platform builds
- Rootless operation
- Integrated with Gitea Actions for seamless CI/CD

## Architecture

- **Deployment**: Rootless BuildKit daemon with TLS encryption in `gitea` namespace
- **Service**: ClusterIP for internal access only (no external exposure)
- **Security**: Infisical-managed TLS certificates with automatic setup
- **Storage**: Ephemeral cache for optimal Docker-in-Docker compatibility
- **Integration**: Direct access from Gitea Actions runners

## Access

- **Internal Service**: `buildkitd.gitea.svc.cluster.local:1235`
- **TLS**: Required for secure communication
- **Access**: Internal cluster only - no external LoadBalancer

## Usage in Gitea Actions

### Direct BuildKit Usage in Actions

```yaml
name: Build and Push
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Build with BuildKit
      run: |
        # BuildKit is available internally
        buildctl --addr tcp://buildkitd.gitea.svc.cluster.local:1235 \
          --tlscacert /certs/ca.pem \
          --tlscert /certs/client-cert.pem \
          --tlskey /certs/client-key.pem \
          build --frontend dockerfile.v0 \
          --local context=. \
          --local dockerfile=. \
          --output type=image,name=registry.gitea.svc.cluster.local:5000/myapp:latest,push=true
```

### Docker Buildx Integration

```bash
# For runners with docker buildx
docker buildx create \
  --name buildkit-gitea \
  --driver remote \
  --driver-opt cacert=/certs/ca.pem,cert=/certs/client-cert.pem,key=/certs/client-key.pem \
  tcp://buildkitd.gitea.svc.cluster.local:1235

# Use for builds
docker buildx build \
  --builder buildkit-gitea \
  --platform linux/amd64 \
  --push \
  -t registry.gitea.svc.cluster.local:5000/myapp:latest \
  .
```

## Certificate Management

TLS certificates are managed through Infisical and automatically configured:

- **CA Certificate**: `BUILDKIT_CA_PEM_B64` (base64 encoded)
- **Server Certificate**: `BUILDKIT_CERT_PEM_B64` (base64 encoded)
- **Server Key**: `BUILDKIT_KEY_PEM_B64` (base64 encoded)
- **Client Certificate**: `BUILDKIT_CLIENT_CERT_PEM_B64` (base64 encoded)
- **Client Key**: `BUILDKIT_CLIENT_KEY_PEM_B64` (base64 encoded)

Certificates are automatically decoded and set up by the init container on pod startup.

## Integration with Registry

BuildKit works seamlessly with the co-located container registry:

```bash
# Build and push to internal registry
buildctl build \
  --frontend dockerfile.v0 \
  --local context=. \
  --output type=image,name=registry.gitea.svc.cluster.local:5000/myproject:latest,push=true
```

## Scaling

For high-availability, scale the deployment:

```bash
kubectl scale deployment buildkitd -n gitea --replicas=3
```

Note: Uses ephemeral storage, so scaling creates independent build environments.

## Monitoring

```bash
# Check deployment status
kubectl get pods -n gitea -l app.kubernetes.io/name=buildkit
kubectl get svc -n gitea buildkitd

# View logs
kubectl logs -n gitea deployment/buildkitd -c buildkitd

# Check certificate setup
kubectl logs -n gitea deployment/buildkitd -c setup-certs

# Check resource usage
kubectl top pods -n gitea -l app.kubernetes.io/name=buildkit
```

## Troubleshooting

### Common Issues

1. **TLS Connection Failed**
   - Check Infisical secret availability: `kubectl get infisicalsecret buildkit-daemon-certs -n gitea`
   - Verify certificate decoding in init container logs
   - Ensure certificates include correct SAN: `buildkitd.gitea.svc.cluster.local`

2. **Build Performance**
   - Monitor resource usage and adjust limits in deployment
   - BuildKit uses ephemeral storage for optimal DinD compatibility

3. **Service Unavailable**
   - Check service endpoints: `kubectl get endpoints buildkitd -n gitea`
   - Verify pod readiness: `kubectl get pods -n gitea -l app.kubernetes.io/name=buildkit`

4. **Infisical Secret Issues**
   - Check operator status: `kubectl get pods -n infisical-operator-system`
   - Verify InfisicalSecret status: `kubectl describe infisicalsecret buildkit-daemon-certs -n gitea`

### Debug Commands

```bash
# Test BuildKit connectivity from within cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
# Inside pod:
# apk add --no-cache curl
# curl -k https://buildkitd.gitea.svc.cluster.local:1235

# Check certificate validity (from a pod with access to secrets)
kubectl exec -it deployment/buildkitd -n gitea -c buildkitd -- \
  openssl x509 -in /certs/cert.pem -text -noout

# Test BuildKit daemon
kubectl exec -it deployment/buildkitd -n gitea -c buildkitd -- \
  buildctl debug workers
```

## Security Notes

- BuildKit runs in rootless mode (UID 1000) with unconfined security contexts
- TLS certificates are automatically rotated via Infisical integration
- No external exposure - internal cluster access only
- RBAC configured for minimal required permissions
