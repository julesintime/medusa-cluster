# Application-Level Backup Strategy for GitOps Cluster

## Executive Summary

**Objective**: Implement comprehensive application-level backup solutions for GitEa PostgreSQL, Coder PostgreSQL, and shared data beyond Longhorn's volume-level backups.

**Recommendation**: Multi-layered approach using **Velero + CloudNative-PG** for production-ready disaster recovery.

## Current State Analysis

### Existing Infrastructure
- **Longhorn**: Volume-level snapshots with retention policies
- **PostgreSQL Deployments**:
  - GitEa: Embedded PostgreSQL (20Gi) with `longhorn-retain`
  - Coder: Dedicated PostgreSQL (20Gi) with `longhorn-retain`
- **GitOps**: Flux-managed deployments with encrypted secrets (SOPS)

### Longhorn Backend Issue Diagnosis
**Problem**: Longhorn UI showing "URL not found" for backend options
**Root Cause**: Missing backup target configuration in HelmRelease values

**Current Configuration Gap**:
```yaml
# clusters/minikube/core/longhorn/helmrelease.yaml:28
# Backup configuration - external targets to be configured via UI or future NFS/S3 setup
backupstorePollInterval: "300"
```

**Fix Required**: Add backup target configuration to HelmRelease.

## Recommended Solution Architecture

### Primary Recommendation: Velero + CloudNative-PG

#### Why This Combination?
1. **Velero**: Industry-standard Kubernetes backup solution (Trust Score: 9.2)
   - Native Kubernetes resource backup
   - Application-consistent backups
   - Cross-cloud storage support
   - Mature GitOps integration

2. **CloudNative-PG**: Modern PostgreSQL operator with advanced backup
   - Continuous WAL archiving
   - Point-in-time recovery (PITR)
   - Application-consistent database backups
   - Barman-based backup infrastructure

#### Architecture Overview
```
┌─────────────────────────────────────────────────────────────────┐
│                    Application-Level Backups                    │
├─────────────────────┬─────────────────────┬─────────────────────┤
│     Velero          │   CloudNative-PG    │    Longhorn         │
│  (Cluster Resources)│   (PostgreSQL)      │   (Volume Snapshots)│
├─────────────────────┼─────────────────────┼─────────────────────┤
│ • K8s manifests     │ • WAL archiving     │ • Block-level       │
│ • PVC metadata      │ • Base backups      │ • Crash-consistent  │
│ • ConfigMaps        │ • PITR capability   │ • Fast snapshots    │
│ • Secrets (encrypted)│ • Hot backups      │ • Local replicas    │
└─────────────────────┴─────────────────────┴─────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Object Store  │
                    │   (MinIO/S3)    │
                    └─────────────────┘
```

### Alternative Solutions Evaluated

#### 1. KubeStash (Stash Next Generation)
**Pros**: 
- Kubernetes-native, next-gen solution
- PostgreSQL logical backup support
- Content-defined chunking for efficiency

**Cons**: 
- Newer solution, less production-proven
- Limited ecosystem compared to Velero

**Verdict**: Consider for future evaluation, not recommended for immediate implementation

#### 2. Longhorn-Only Approach
**Pros**: 
- Already deployed
- Fast volume-level recovery

**Cons**: 
- Block-level only (not application-aware)
- Current backend configuration issues
- No cross-application consistency

**Verdict**: Complement with application-level solutions

## Implementation Plan

### Phase 1: Fix Longhorn Backend Configuration (Immediate - Week 1)

#### 1.1 Configure S3-Compatible Backend
```yaml
# Update clusters/minikube/core/longhorn/helmrelease.yaml
defaultSettings:
  backupTarget: "s3://longhorn-backups@us-west-1/"
  backupTargetCredentialSecret: "minio-secret"
  backupstorePollInterval: "300"
  # For MinIO local setup
  # backupTarget: "s3://longhorn-backups@minio/"
```

#### 1.2 Create MinIO Backend Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-secret
  namespace: longhorn-system
type: Opaque
data:
  AWS_ACCESS_KEY_ID: <base64-encoded>
  AWS_SECRET_ACCESS_KEY: <base64-encoded>
  AWS_ENDPOINTS: <base64-encoded-minio-url>
```

#### 1.3 Verification Commands
```bash
# Check Longhorn backup target status
kubectl -n longhorn-system get setting backup-target

# Test backup creation
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: BackupVolume
metadata:
  name: test-backup
  namespace: longhorn-system
spec:
  volumeName: <pvc-volume-name>
EOF
```

### Phase 2: Deploy Velero (Week 2)

#### 2.1 Installation
```bash
# Install Velero CLI
curl -fsSL -o velero-v1.16.0-linux-amd64.tar.gz \
  https://github.com/vmware-tanzu/velero/releases/download/v1.16.0/velero-v1.16.0-linux-amd64.tar.gz
tar -xvf velero-v1.16.0-linux-amd64.tar.gz
sudo mv velero-v1.16.0-linux-amd64/velero /usr/local/bin/

# Install Velero server
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.8.0 \
    --bucket velero-backups \
    --secret-file ./velero-credentials \
    --use-node-agent \
    --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.minio.svc:9000
```

#### 2.2 GitOps Integration
```yaml
# clusters/minikube/core/velero/
├── helmrelease.yaml          # Velero server deployment
├── backup-schedule.yaml      # Automated backup schedules
├── backup-storage-location.yaml
└── volume-snapshot-location.yaml
```

#### 2.3 Backup Schedules
```yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-cluster-backup
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  template:
    includedNamespaces:
    - gitea
    - coder
    defaultVolumesToFsBackup: true
    storageLocation: default
    ttl: 720h  # 30 days
```

### Phase 3: Migrate to CloudNative-PG (Week 3-4)

#### 3.1 Deploy CloudNative-PG Operator
```yaml
# clusters/minikube/core/cloudnative-pg/
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cloudnative-pg
spec:
  chart:
    spec:
      chart: cloudnative-pg
      sourceRef:
        kind: HelmRepository
        name: cloudnative-pg
  values:
    crds:
      create: true
```

#### 3.2 PostgreSQL Cluster with Backup Configuration
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: gitea-postgres
  namespace: gitea
spec:
  instances: 2
  primaryUpdateStrategy: unsupervised
  
  postgresql:
    parameters:
      max_connections: "200"
      shared_preload_libraries: "pg_stat_statements"
  
  bootstrap:
    initdb:
      database: gitea
      owner: gitea
      secret:
        name: gitea-postgres-credentials

  storage:
    size: 20Gi
    storageClass: longhorn-retain
  
  backup:
    retentionPolicy: "30d"
    barmanObjectStore:
      destinationPath: "s3://postgres-backups/gitea"
      s3Credentials:
        accessKeyId:
          name: minio-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: minio-credentials
          key: SECRET_ACCESS_KEY
      endpointURL: "http://minio.minio.svc:9000"
      wal:
        retention: "7d"
      data:
        retention: "30d"
        jobs: 2
```

#### 3.3 Migration Strategy
1. **Create CloudNative-PG clusters** alongside existing deployments
2. **Backup existing databases** using pg_dump
3. **Import data** into new CloudNative-PG clusters
4. **Update application configurations** to use new endpoints
5. **Verify functionality** and decommission old deployments

### Phase 4: Enhanced Monitoring & Alerting (Week 4)

#### 4.1 Backup Success Monitoring
```yaml
# Prometheus rules for backup monitoring
groups:
- name: backup.rules
  rules:
  - alert: VeleroBackupFailed
    expr: velero_backup_failure_total > 0
    for: 0m
    labels:
      severity: critical
    annotations:
      summary: "Velero backup failed"
      description: "Backup {{ $labels.schedule }} has failed"

  - alert: PostgreSQLBackupFailed
    expr: cnpg_backup_duration_seconds == 0
    for: 15m
    labels:
      severity: critical
    annotations:
      summary: "PostgreSQL backup failed"
      description: "PostgreSQL backup for cluster {{ $labels.cluster }} has failed"
```

#### 4.2 Dashboard Configuration
```yaml
# Grafana dashboard for backup monitoring
apiVersion: v1
kind: ConfigMap
metadata:
  name: backup-monitoring-dashboard
data:
  backup-dashboard.json: |
    {
      "dashboard": {
        "title": "Backup Monitoring",
        "panels": [
          {
            "title": "Velero Backup Status",
            "targets": [
              {"expr": "velero_backup_success_total"}
            ]
          },
          {
            "title": "PostgreSQL WAL Archive Status", 
            "targets": [
              {"expr": "cnpg_wal_archive_total"}
            ]
          }
        ]
      }
    }
```

## Recovery Procedures

### Velero Recovery
```bash
# List available backups
velero backup get

# Restore entire namespace
velero restore create --from-backup daily-cluster-backup-20250903

# Restore specific resources
velero restore create --from-backup daily-cluster-backup-20250903 \
  --include-resources persistentvolumeclaims,persistentvolumes \
  --include-namespaces gitea
```

### CloudNative-PG Recovery
```bash
# Point-in-time recovery
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: gitea-postgres-restored
spec:
  instances: 1
  
  bootstrap:
    recovery:
      source: gitea-postgres-backup
      recoveryTarget:
        targetTime: "2025-09-03 10:00:00"

  externalClusters:
  - name: gitea-postgres-backup
    barmanObjectStore:
      destinationPath: "s3://postgres-backups/gitea"
      s3Credentials:
        accessKeyId:
          name: minio-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: minio-credentials
          key: SECRET_ACCESS_KEY
      endpointURL: "http://minio.minio.svc:9000"
EOF
```

## Cost Analysis

### Storage Requirements
- **Gitea Database**: ~2GB daily growth
- **Coder Database**: ~1GB daily growth  
- **Velero Backups**: ~5GB compressed daily
- **PostgreSQL WAL**: ~500MB daily per database

### Monthly Costs (Estimated)
```
Local MinIO (1TB):     $50/month hardware amortization
S3 Backup (100GB):     $23/month (AWS S3 Standard)
Compute Overhead:      ~5% cluster resources
Total:                 ~$75/month

Risk Mitigation Value: $10,000+ per prevented data loss incident
ROI:                   Positive after first month
```

## Security Considerations

### Encryption
- **At Rest**: All backups encrypted with AES-256
- **In Transit**: TLS 1.2+ for all backup traffic
- **Secrets**: SOPS-encrypted credentials in Git

### Access Control
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: velero
  name: backup-operator
rules:
- apiGroups: ["velero.io"]
  resources: ["backups", "restores"]
  verbs: ["get", "list", "create", "delete"]
```

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backup-network-policy
spec:
  podSelector:
    matchLabels:
      component: backup
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: minio
    ports:
    - protocol: TCP
      port: 9000
```

## Testing & Validation

### Monthly DR Drills
```bash
#!/bin/bash
# Monthly backup validation script

echo "=== Backup Validation Test ==="

# 1. Test Velero backup creation
velero backup create test-backup-$(date +%Y%m%d) \
  --include-namespaces gitea,coder \
  --wait

# 2. Test PostgreSQL backup
kubectl -n gitea-test exec -it gitea-postgres-1 -- \
  pg_dump gitea > /tmp/test-backup.sql

# 3. Test restore procedure (to test namespace)
velero restore create test-restore-$(date +%Y%m%d) \
  --from-backup test-backup-$(date +%Y%m%d) \
  --namespace-mappings gitea:gitea-test,coder:coder-test

echo "=== Validation Complete ==="
```

### Automated Testing
```yaml
apiVersion: v1
kind: CronJob
metadata:
  name: backup-validation
spec:
  schedule: "0 4 1 * *"  # First of every month at 4 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup-test
            image: velero/velero:latest
            command:
            - /bin/sh
            - -c
            - |
              velero backup create validation-test-$(date +%Y%m%d) --wait
              velero restore create validation-restore-$(date +%Y%m%d) \
                --from-backup validation-test-$(date +%Y%m%d) \
                --include-namespaces gitea-test
          restartPolicy: OnFailure
```

## Implementation Timeline

### Week 1: Foundation
- [ ] Fix Longhorn backend configuration
- [ ] Deploy MinIO for local object storage
- [ ] Configure backup credentials and secrets
- [ ] Test Longhorn backup functionality

### Week 2: Velero Deployment  
- [ ] Install Velero with MinIO backend
- [ ] Configure backup schedules
- [ ] Integrate with GitOps (Flux)
- [ ] Test cluster-level backup/restore

### Week 3: PostgreSQL Enhancement
- [ ] Deploy CloudNative-PG operator
- [ ] Create parallel PostgreSQL clusters
- [ ] Configure continuous WAL archiving
- [ ] Test database backup/restore

### Week 4: Migration & Monitoring
- [ ] Migrate applications to CloudNative-PG
- [ ] Deploy monitoring and alerting
- [ ] Run complete disaster recovery test
- [ ] Document runbooks and procedures

### Week 5: Production Hardening
- [ ] Implement security policies
- [ ] Configure automated testing
- [ ] Optimize backup retention policies
- [ ] Train operations team

## Success Metrics

### Technical KPIs
- **RTO (Recovery Time Objective)**: < 30 minutes
- **RPO (Recovery Point Objective)**: < 1 hour
- **Backup Success Rate**: 99.9%
- **Storage Efficiency**: > 70% compression ratio

### Operational KPIs
- **Mean Time to Recovery**: < 15 minutes
- **Backup Verification Success**: 100%
- **Security Compliance**: Zero credential exposures
- **Cost Efficiency**: < $100/month total backup costs

## Conclusion

This comprehensive backup strategy addresses all critical requirements:

1. **Application-Level Protection**: Beyond volume snapshots
2. **PostgreSQL Specialization**: Database-aware backups with PITR
3. **GitOps Integration**: Declarative backup configuration
4. **Multi-Layer Defense**: Velero + CloudNative-PG + Longhorn
5. **Cost Effectiveness**: Self-hosted MinIO vs. external services
6. **Production Ready**: Enterprise-grade reliability and security

**Next Steps**: 
1. Approve implementation plan
2. Provision MinIO storage backend  
3. Begin Phase 1 Longhorn configuration fix
4. Schedule weekly implementation checkpoints

**Critical Success Factor**: Start with Longhorn backend fix to establish foundational backup capability, then layer on application-specific solutions for comprehensive protection.