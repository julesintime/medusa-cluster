# API Token Management Design

## Overview

This document outlines the API token management strategy for automated Coder template deployment in GitOps environments, addressing the bootstrap challenge for fresh deployments.

## The Bootstrap Challenge

**Problem**: Fresh Coder deployments need API tokens for template automation, but API tokens can only be created by authenticated users.

**Solution**: Multi-stage approach with manual bootstrapping and automatic maintenance.

## API Token Management Strategy

### Stage 1: Manual Bootstrap (First Deployment)

```bash
# 1. Deploy Coder via GitOps (without template automation)
git add clusters/labinfra/apps/coder.xuperson.org/
git commit -m "Deploy Coder with GitHub external auth"
git push

# 2. Create initial admin user (web UI)
# Navigate to https://coder.xuperson.org
# Create first admin account: email + password

# 3. Create API token for automation
# Account → Tokens → Create new token
# Name: "template-automation"
# Scope: Full access (for template management)

# 4. Store token in Kubernetes secret
export ADMIN_TOKEN="coder_token_here"
kubectl create secret generic coder-admin-api-token \
  --from-literal=token="$ADMIN_TOKEN" \
  -n coder

# 5. Deploy template automation
# Uncomment template-init job in kustomization.yaml
git add clusters/labinfra/apps/coder.xuperson.org/kustomization.yaml
git commit -m "Enable template automation with API token"
git push
```

### Stage 2: Automated Template Management

Once bootstrap is complete, the system operates automatically:

```bash
# Template updates via GitOps
# 1. Update template files in ConfigMap
# 2. Restart job to deploy new version
# 3. Template automatically becomes active
```

## Implementation Details

### Token Storage Strategy

**Kubernetes Secret**: `coder-admin-api-token` in `coder` namespace

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: coder-admin-api-token
  namespace: coder
data:
  token: <base64-encoded-coder-token>
```

**Why not Infisical?**: API tokens are deployment-specific and should remain in cluster for security.

### Token Rotation Strategy

#### Manual Rotation (Recommended)
```bash
# 1. Create new token in Coder web UI
# 2. Update Kubernetes secret
kubectl patch secret coder-admin-api-token -n coder \
  -p '{"data":{"token":"BASE64_NEW_TOKEN"}}'
# 3. Restart template automation job
kubectl delete job coder-template-init -n coder
# Job will be recreated by GitOps with new token
```

#### Automated Rotation (Future Enhancement)
```yaml
# Future: CronJob for token rotation
# Requires programmatic token creation via existing valid token
# Implementation: 30-day rotation cycle
```

### Security Considerations

#### Token Scope
- **Required Permissions**: Template read/write, organization access
- **Minimal Scope**: Avoid user management permissions
- **Template-Only Access**: Consider dedicated service account

#### Access Control
```yaml
# RBAC for automation service account
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "create", "patch", "update", "list", "delete"]
  resourceNames: ["coder-admin-api-token"]
```

#### Network Security
- **Internal Only**: Token used only within cluster
- **TLS Required**: All API calls use HTTPS
- **Token Masking**: Never log token values

## Disaster Recovery Procedures

### Complete Infrastructure Recovery

```bash
# 1. Deploy infrastructure (K3s, Flux, Infisical)
# 2. Deploy Coder (without template automation)
git clone git@github.com:user/labinfra.git
cd labinfra
git add clusters/labinfra/apps/coder.xuperson.org/
# Comment out template-init job in kustomization.yaml
git commit -m "Deploy Coder infrastructure"
git push

# 3. Manual bootstrap (see Stage 1 above)
# 4. Enable automation
# Uncomment template-init job in kustomization.yaml
git commit -m "Enable template automation post-bootstrap"
git push
```

### Partial Recovery (Token Lost)

```bash
# 1. Create new API token in web UI
# 2. Update secret
kubectl patch secret coder-admin-api-token -n coder \
  -p '{"data":{"token":"BASE64_NEW_TOKEN"}}'
# 3. Restart automation
kubectl delete job coder-template-init -n coder
```

## Automation Job Behavior

### Token Validation
```bash
# Job checks token validity before proceeding
AUTH_TEST=$(curl -s -H "Coder-Session-Token: $ADMIN_TOKEN" "$CODER_URL/api/v2/users/me")
if echo "$AUTH_TEST" | grep -q '"id"'; then
  echo "Authentication successful!"
else
  echo "ERROR: API authentication failed"
  exit 1
fi
```

### Graceful Degradation
- **No Token**: Job creates placeholder, exits with instructions
- **Invalid Token**: Job fails with clear error message  
- **API Unavailable**: Job retries with exponential backoff

### Success Criteria
- ✅ Template uploaded successfully
- ✅ Version created and set active
- ✅ Build statistics generated
- ✅ Template accessible via web UI

## Monitoring and Alerting

### Job Success Monitoring
```bash
# Check job completion
kubectl get jobs -n coder
kubectl logs job/coder-template-init -n coder

# Verify template exists
curl -H "Coder-Session-Token: $TOKEN" "https://coder.xuperson.org/api/v2/templates"
```

### Token Expiration Monitoring
```yaml
# Future: Monitor token expiration
# Alert 7 days before expiration
# Automate renewal process
```

## Best Practices

### Development Workflow
1. **Test Locally**: Verify template changes before commit
2. **Staging Environment**: Test automation in non-production
3. **Incremental Updates**: Small, focused template changes
4. **Version Control**: Clear commit messages for template updates

### Operational Workflow
1. **Token Hygiene**: Regular rotation (30-90 days)
2. **Access Review**: Quarterly review of token permissions  
3. **Backup Strategy**: Document token recovery procedures
4. **Change Management**: Coordinate template updates with users

### Security Workflow
1. **Principle of Least Privilege**: Minimal required permissions
2. **Audit Logging**: Track all API token usage
3. **Incident Response**: Clear procedures for token compromise
4. **Documentation**: Keep runbooks up to date

## Troubleshooting

### Common Issues

#### "Authentication failed"
```bash
# Check token format
kubectl get secret coder-admin-api-token -n coder -o yaml
echo "TOKEN_BASE64" | base64 -d

# Verify token in Coder UI
# Account → Tokens → Check token status
```

#### "Template upload failed"
```bash
# Check file permissions
kubectl exec -n coder job/coder-template-init -- ls -la /template-files/

# Verify ConfigMap content
kubectl get configmap coder-template-files -n coder -o yaml
```

#### "Job keeps failing"
```bash
# Check job logs
kubectl logs job/coder-template-init -n coder -f

# Check service account permissions
kubectl auth can-i create secrets --as=system:serviceaccount:coder:coder-template-automation -n coder
```

### Recovery Commands

```bash
# Reset job
kubectl delete job coder-template-init -n coder

# Force job recreation (GitOps will recreate)
kubectl get kustomization coder.xuperson.org -n flux-system -o yaml

# Manual template upload
curl -X POST https://coder.xuperson.org/api/v2/files \
  -H "Content-Type: application/x-tar" \
  -H "Coder-Session-Token: $TOKEN" \
  --data-binary @template.tar.gz
```

## Future Enhancements

### Planned Improvements
1. **Service Account Authentication**: Eliminate user token dependency
2. **Automated Token Rotation**: 30-day rotation cycle
3. **Multiple Environment Support**: Dev/staging/prod templates
4. **Template Versioning**: Semantic versioning for templates
5. **Rollback Capability**: Revert to previous template versions

### Integration Opportunities
1. **GitOps Webhooks**: Trigger template updates on Git push
2. **Slack Notifications**: Alert on template deployment success/failure
3. **Prometheus Metrics**: Monitor template deployment health
4. **External Secrets Operator**: Enhanced secret management
5. **ArgoCD Integration**: Alternative GitOps operator support

---

**Next Steps**: Complete bootstrap process and test end-to-end automation workflow.