# Critical Data Protection Strategy

## Overview
This document outlines the data protection strategy for critical applications in the K3s cluster, specifically Gitea and Coder.

## Storage Classes with Retention

### New Storage Classes
- `longhorn-retain`: Standard performance with 3 replicas, Retain policy
- `longhorn-retain-fast`: High performance with 2 replicas, Retain policy

### Migration Strategy
1. **For new deployments**: Update Helm values to use `longhorn-retain` storage class
2. **For existing deployments**: Follow migration procedure below

## Critical Applications

### Gitea (git.xuperson.org)
- **Data**: Git repositories, database, logs
- **Storage**: Uses `longhorn-retain` for both app and PostgreSQL
- **Volatile Data**: act-runner (CI/CD cache), valkey cluster (Redis cache) use Delete policy
- **Backup Strategy**: Longhorn snapshots + git repository mirrors

### Coder (coder.xuperson.org)  
- **Data**: Workspace templates, user data, database
- **Storage**: PostgreSQL uses `longhorn-retain`
- **Backup Strategy**: Database backups + Longhorn snapshots

## PVC Policy Summary

### Critical Data (RETAIN Policy)
- `gitea-shared-storage`: Git repositories and application data
- `data-gitea-postgresql-0`: Gitea database
- `data-coder-coder-postgresql-0`: Coder database

### Ephemeral Data (DELETE Policy)  
- `act-runner-vol`: GitHub Actions runner cache
- `valkey-data-gitea-valkey-cluster-*`: Redis cache cluster (3 nodes)

## Emergency Recovery Procedures

### If Apps Are Accidentally Deleted

1. **Check PV Status**:
   ```bash
   kubectl get pv | grep -E "(Released|Available)"
   ```

2. **Recreate PVC to Bind to Existing PV**:
   ```bash
   # Edit PV to remove claimRef
   kubectl patch pv <pv-name> -p '{"spec":{"claimRef":null}}'
   
   # Create new PVC with same specifications
   kubectl apply -f pvc-recovery.yaml
   ```

3. **Redeploy Application**:
   ```bash
   flux reconcile kustomization apps
   ```

### Longhorn Backup Configuration

1. **Enable Recurring Backups**:
   - Daily snapshots at 2 AM
   - Weekly backups to external storage
   - Retention: 7 daily, 4 weekly

2. **Backup Targets**:
   - NFS: `nfs://192.168.80.100/longhorn-backups`
   - S3-compatible: Configure if available

## Monitoring and Alerts

### PVC Protection Checks
- Monitor PV reclaim policy
- Alert on PVC deletion events
- Verify backup completion

### Storage Health
- Longhorn volume health checks
- Replica status monitoring
- Storage capacity alerts

## Best Practices

1. **Always use retention storage classes** for critical data
2. **Test recovery procedures** regularly
3. **Monitor storage usage** and capacity
4. **Maintain backup verification** schedules
5. **Document all storage dependencies**

## Quick Commands

```bash
# Check storage classes
kubectl get storageclass

# Check PVC status
kubectl get pvc -A

# Check PV reclaim policy
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase

# Patch existing PV to Retain policy
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

# Create Longhorn backup
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Backup
metadata:
  name: gitea-backup-$(date +%Y%m%d)
  namespace: longhorn-system
spec:
  volumeName: <volume-name>
EOF
```
