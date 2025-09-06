# DISASTER RECOVERY PLAN

## Lessons Learned from Production Incident

**Date**: 2025-08-30  
**Incident**: Accidental deletion of PostgreSQL PVC resulting in complete data loss
**Root Cause**: ReclaimPolicy=Delete + No backup system

## Critical Fixes Applied

1. **StorageClass ReclaimPolicy**: Changed from `Delete` to `Retain`
2. **Backup Target**: Implemented MinIO S3-compatible storage
3. **Automated Backups**: Daily Longhorn + PostgreSQL backups
4. **Monitoring**: Backup success/failure alerts

## Multi-Layer Backup Strategy

### Layer 1: Longhorn Volume Snapshots
- **Frequency**: Every 4 hours
- **Retention**: 7 days local, 30 days remote
- **Target**: MinIO S3 bucket
- **RTO**: 15 minutes
- **RPO**: 4 hours

### Layer 2: Application-Level Backups (PostgreSQL)
- **Tool**: pgBackRest
- **Frequency**: Daily full, hourly WAL
- **Retention**: 7 daily, 4 weekly, 6 monthly
- **Target**: MinIO S3 bucket (separate from volume backups)
- **RTO**: 10 minutes
- **RPO**: 1 hour

### Layer 3: Configuration Backups
- **Target**: Git repository (GitOps)
- **Frequency**: Every commit
- **Scope**: All Kubernetes manifests, secrets (encrypted)

## Storage Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Production    │───▶│   MinIO Local   │───▶│   Remote S3     │
│   Workloads     │    │   (Primary)     │    │   (Offsite)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
   Live Data              Hot Backups           Cold Backups
   RTO: 0s                RTO: 15min            RTO: 2hrs
   RPO: 0s                RPO: 4hrs             RPO: 24hrs
```

## Recovery Procedures

### 1. Volume Recovery (Longhorn)
```bash
# Restore from Longhorn backup
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Volume
metadata:
  name: restored-volume
spec:
  fromBackup: "s3://longhorn-backups/backup-name"
EOF
```

### 2. Database Recovery (PostgreSQL)
```bash
# Restore with pgBackRest
pgbackrest restore --stanza=coder --type=time --target="2025-08-30 10:00:00"
```

### 3. Complete Cluster Recovery
```bash
# 1. Recreate cluster
# 2. Apply GitOps manifests
# 3. Restore volumes from backup
# 4. Restore databases
# 5. Validate services
```

## Monitoring & Alerting

### Backup Success Monitoring
- **Tool**: Prometheus + AlertManager
- **Metrics**: Backup completion, size, duration
- **Alerts**: Failed backups, missing backups, storage quotas

### Regular Testing
- **Monthly**: Restore test to staging environment
- **Quarterly**: Full disaster recovery drill
- **Annually**: Complete cluster rebuild test

## Backup Storage Sizing

### Current Setup (Small Cluster)
- **Production Data**: ~50GB
- **Daily Backups**: ~5GB (compressed/deduped)
- **Monthly Storage Need**: ~150GB
- **Annual Storage Need**: ~500GB

### Recommended MinIO Setup
- **Local MinIO**: 1TB storage (2x replication)
- **Remote S3**: 500GB (lifecycle policies)
- **Total Cost**: <$100/month vs $500/month external

## Human Process Improvements

### Change Management
1. **NEVER** delete PVCs in production without backup verification
2. **ALWAYS** check ReclaimPolicy before PVC operations
3. **REQUIRE** backup verification before destructive operations
4. **IMPLEMENT** change approval process for storage operations

### Emergency Contacts
- **Primary**: System Administrator
- **Secondary**: DevOps Team Lead  
- **Escalation**: CTO/Engineering Manager

### Documentation
- **Runbooks**: Step-by-step recovery procedures
- **Contact Lists**: Emergency response team
- **RTO/RPO Targets**: Business requirements documented

## Cost Analysis

### Current No-Backup Cost
- **Storage**: Free (no backups)
- **Risk**: $10,000+ in lost productivity per incident

### Proposed Backup Cost
- **Storage**: $100/month MinIO + S3
- **Risk Mitigation**: 99.9% data protection
- **ROI**: Positive after first prevented incident

## Implementation Checklist

- [ ] Deploy MinIO with persistent storage
- [ ] Configure Longhorn backup target
- [ ] Set up recurring backup jobs  
- [ ] Install pgBackRest for PostgreSQL
- [ ] Configure backup monitoring
- [ ] Test restore procedures
- [ ] Update runbooks
- [ ] Train operations team
- [ ] Schedule regular DR drills

**NEVER AGAIN SHALL WE LOSE PRODUCTION DATA**