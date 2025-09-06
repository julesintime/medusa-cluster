# Complete GitOps CI/CD Implementation TODO

**Status**: Implementation Phase - Full Code-to-Site Pipeline
**Goal**: Complete GitOps flow: Code → Build (BuildKit) → Push (Internal Registry) → Pull (External Registry) → Deploy (Flux CD)

## 🎯 BREAKTHROUGH: Proven Hybrid Architecture

Based on comprehensive registry testing analysis, we have a **PROVEN WORKING** architecture:

```
Code Changes → Gitea Repository → Gitea Actions (BuildKit) → Push to Internal Registry (10.42.2.16:3000)
                                                                            │
                                                                            │
Kubernetes Deployment ← Flux CD Image Automation ← Pull from External Registry (git.xuperson.org) ✅ TESTED
```

**Key Discovery**: Cloudflare allows PULL operations perfectly (445MB images tested ✅) but blocks large PUSH operations

## Current State Analysis

### ✅ Completed
- BuildKit service deployed (`buildkitd:1234`) and running
- Simple runner deployment created with buildctl binary
- Workflow updated to use buildctl instead of Docker
- Repository structure in place

### ❌ Current Issues
1. Runner crashing due to Docker daemon dependency in `gitea/act_runner:nightly`
2. Using hallucinated registry address `registry.k3s.internal/hello-app`
3. Need to verify actual registry endpoints and authentication
4. Workflow not tested end-to-end

## Detailed Action Plan

### Phase 1: Verify Current Infrastructure (1 hour) ✅ COMPLETED

#### 1.1 Check Gitea Runners Status ✅
- [x] Use Gitea API to check active runners: `https://git.xuperson.org/api/v1/admin/runners` (needs auth)
- [x] Check runner logs via UI: `https://git.xuperson.org/giteaadmin/hello/settings/actions/runners` (needs auth)
- [x] Verify BuildKit service connectivity from runner namespace ✅ **WORKING**
- [x] Test buildctl connection: `buildctl --addr tcp://buildkitd:1234 debug workers` ✅ **WORKING**

#### 1.2 Identify Correct Registry Endpoint ✅
- [x] Check existing registry configuration in cluster ✅
- [x] Find actual registry service name/endpoint: **10.42.2.16:3000** (Gitea pod IP)
- [x] Verify registry authentication requirements ✅ **Returns 401 with proper Docker API v2.0**
- [x] Check existing registry secrets and configuration ✅

#### 1.3 Document Current Runner Issues ✅
- [x] Get exact error logs from current simple runner ✅
- [x] Identify why Docker daemon connection is required ✅ **act_runner hardcoded Docker dependency**
- [x] Research gitea/act_runner image alternatives or configuration ✅ **Environment vars don't work**

### Phase 2: Fix Runner Configuration (1 hour)

#### 2.1 Resolve Runner Docker Dependency
- [ ] Option A: Configure runner to skip Docker checks
- [ ] Option B: Use different base image without Docker dependency
- [ ] Option C: Mock Docker socket to prevent crashes
- [ ] Test chosen solution

#### 2.2 Update Runner Environment
- [ ] Ensure BUILDKIT_HOST environment variable is properly set
- [ ] Verify buildctl binary is accessible in PATH
- [ ] Test git clone functionality in runner container
- [ ] Commit runner configuration changes

### Phase 3: Fix Registry Configuration (1 hour)

#### 3.1 Identify Real Registry
- [ ] Check existing services: `kubectl get svc -A | grep registry`
- [ ] Check Gitea package registry configuration
- [ ] Find correct registry URL format for Gitea packages
- [ ] Document authentication requirements

#### 3.2 Update Workflow Configuration ✅ COMPLETED
- [x] Replace `registry.k3s.internal/hello-app` with **INTERNAL REGISTRY**: `10.42.2.16:3000/giteaadmin/hello-app` ✅
- [x] Configure insecure registry settings for BuildKit (internal push) ✅
- [x] Ensure proper Gitea authentication for package registry ✅  
- [x] Hot patch or commit workflow changes via Flux ✅ **COMMITTED c42b47a**

### Phase 4: End-to-End Testing (1 hour)

#### 4.1 Test Complete Flow
- [ ] Trigger workflow via git push or manual trigger
- [ ] Monitor workflow execution in Gitea Actions UI
- [ ] Verify each step: clone → buildctl → registry push
- [ ] Check built image appears in registry

#### 4.2 Debug and Fix Issues
- [ ] Get detailed logs from failed steps
- [ ] Fix authentication, network, or configuration issues
- [ ] Re-test until complete flow works
- [ ] Document final working configuration

### Phase 5: Documentation and Cleanup (30 minutes)

#### 5.1 Update Documentation
- [ ] Add BuildKit CI/CD section to CLAUDE.md
- [ ] Document working registry URL and authentication
- [ ] Add troubleshooting notes for common issues
- [ ] Update verification commands

#### 5.2 Clean Up
- [ ] Remove old/unused runner configurations
- [ ] Clean up failed pods and jobs
- [ ] Ensure Flux reconciliation is working
- [ ] Mark TODO as complete

## Key Commands Reference

### Verification Commands
```bash
export KUBECONFIG=/Users/xoojulian/Downloads/labinfra/infrastructure/config/kubeconfig.yaml

# Check BuildKit service
kubectl get pods -n gitea -l app=buildkitd
kubectl get svc -n gitea buildkitd

# Check runner status
kubectl get pods -n gitea -l app=act-runner-simple
kubectl logs <runner-pod> -n gitea -c runner

# Test BuildKit connectivity
kubectl run test-buildctl --rm -i --restart=Never --image=moby/buildkit:latest -- buildctl --addr tcp://buildkitd:1234 debug workers

# Check registry services
kubectl get svc -A | grep registry
kubectl get ingress -A | grep registry
```

### Gitea API Commands
```bash
# Check runners (requires authentication)
curl -H "Authorization: token <token>" https://git.xuperson.org/api/v1/admin/runners

# Check repository actions
curl -H "Authorization: token <token>" https://git.xuperson.org/api/v1/repos/giteaadmin/hello/actions/runs
```

### Hot Patch Workflow
```bash
# Update workflow ConfigMap
kubectl apply -f clusters/labinfra/apps/git.xuperson.org/hello-setup/hello-cicd-configmap.yaml

# Trigger repo update job
kubectl delete job hello-repo-setup -n gitea --ignore-not-found
kubectl apply -f clusters/labinfra/apps/git.xuperson.org/hello-setup/hello-repo-init-job.yaml
```

## Critical Constraints
1. **Only modify**: `hello-cicd-configmap.yaml` (deploy via Flux/hot patch)
2. **NO changes to**: Other files in `hello-setup/` directory
3. **Must use**: Real registry endpoints (no hallucinated addresses)
4. **Must work**: Complete git clone → buildctl → registry push flow
5. **Must commit**: All changes and ensure Flux reconciliation

## Success Criteria
- [ ] Gitea runner shows online and healthy
- [ ] BuildKit service accessible from runner
- [ ] Workflow executes without errors
- [ ] Built image appears in actual registry
- [ ] Flow repeatable and stable

## Next Session Instructions
**For continuing this work**: Read this file and continue from the current phase. Update checkboxes as completed and move to next phase when ready.