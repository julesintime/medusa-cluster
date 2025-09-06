# CloudNative-PG Setup and Operations Guide

## Overview

This guide provides comprehensive instructions for setting up, provisioning, and maintaining CloudNative-PG PostgreSQL clusters in your Kubernetes environment. CloudNative-PG is a modern PostgreSQL operator that provides advanced database capabilities including automated provisioning, high availability, and enterprise-grade backup/recovery features.

## Prerequisites

### Kubernetes Requirements
- Kubernetes 1.24+
- Storage class with `ReadWriteOnce` support (Longhorn recommended)
- MinIO or S3-compatible object storage for backups
- Flux CD for GitOps management

### Current Environment
- **Cluster**: Minikube with Longhorn storage
- **GitOps**: Flux-managed deployments
- **Applications**: Gitea and Coder with embedded PostgreSQL
- **Backup Storage**: MinIO for object storage

## Phase 1: Operator Installation

### 1.1 Add CloudNative-PG Helm Repository

```yaml
# clusters/minikube/core/cloudnative-pg/helmrepository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: cloudnative-pg
  namespace: flux-system
spec:
  interval: 1h
  url: https://cloudnative-pg.github.io/charts
```

### 1.2 Deploy CloudNative-PG Operator

```yaml
# clusters/minikube/core/cloudnative-pg/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cloudnative-pg
  namespace: cnpg-system
spec:
  interval: 30m
  chart:
    spec:
      chart: cloudnative-pg
      version: "0.21.0"
      sourceRef:
        kind: HelmRepository
        name: cloudnative-pg
        namespace: flux-system
  install:
    createNamespace: true
  values:
    crds:
      create: true
    monitoring:
      podMonitorEnabled: true
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

### 1.3 Verify Installation

```bash
# Check operator deployment
kubectl get pods -n cnpg-system

# Check CRDs are installed
kubectl get crd | grep postgresql.cnpg.io

# Check operator logs
kubectl logs -n cnpg-system deployment/cloudnative-pg
```

## Phase 2: PostgreSQL Cluster Provisioning

### 2.1 Create Namespace for Databases

```yaml
# clusters/minikube/core/cloudnative-pg/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: databases
  labels:
    name: databases
```

### 2.2 Provision PostgreSQL Cluster for Gitea

```yaml
# clusters/minikube/apps/gitea/postgres-cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: gitea-postgres
  namespace: databases
spec:
  instances: 2
  primaryUpdateStrategy: unsupervised
  postgresVersion: 15

  postgresql:
    parameters:
      max_connections: "200"
      shared_preload_libraries: "pg_stat_statements"
      log_statement: "ddl"
      log_line_prefix: "%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h "

  bootstrap:
    initdb:
      database: gitea
      owner: gitea
      secret:
        name: gitea-postgres-credentials
      postInitApplicationSQL:
      - CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
      - CREATE EXTENSION IF NOT EXISTS uuid_ossp;

  storage:
    size: 20Gi
    storageClass: longhorn-retain
    resizeInUseVolumes: true

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
        compression: gzip
      data:
        retention: "30d"
        compression: gzip
        jobs: 2

  monitoring:
    enablePodMonitor: true

  affinity:
    nodeSelector:
      kubernetes.io/os: linux
```

### 2.3 Provision PostgreSQL Cluster for Coder

```yaml
# clusters/minikube/apps/coder/postgres-cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: coder-postgres
  namespace: databases
spec:
  instances: 2
  primaryUpdateStrategy: unsupervised
  postgresVersion: 15

  postgresql:
    parameters:
      max_connections: "150"
      shared_preload_libraries: "pg_stat_statements"
      work_mem: "64MB"
      maintenance_work_mem: "256MB"

  bootstrap:
    initdb:
      database: coder
      owner: coder
      secret:
        name: coder-postgres-credentials
      postInitApplicationSQL:
      - CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
      - CREATE EXTENSION IF NOT EXISTS pgcrypto;

  storage:
    size: 20Gi
    storageClass: longhorn-retain
    resizeInUseVolumes: true

  backup:
    retentionPolicy: "30d"
    barmanObjectStore:
      destinationPath: "s3://postgres-backups/coder"
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
        compression: gzip
      data:
        retention: "30d"
        compression: gzip
        jobs: 2

  monitoring:
    enablePodMonitor: true
```

### 2.4 Create Application Credentials

```yaml
# clusters/minikube/core/cloudnative-pg/gitea-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitea-postgres-credentials
  namespace: databases
type: Opaque
data:
  username: Z2l0ZWE=  # base64 encoded 'gitea'
  password: <base64-encoded-password>
  database: Z2l0ZWE=  # base64 encoded 'gitea'

---
# clusters/minikube/core/cloudnative-pg/coder-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: coder-postgres-credentials
  namespace: databases
type: Opaque
data:
  username: Y29kZXI=  # base64 encoded 'coder'
  password: <base64-encoded-password>
  database: Y29kZXI=  # base64 encoded 'coder'
```

### 2.5 Create MinIO Credentials Secret

#### Option 1: Manual Secret Creation (Current Approach)
```yaml
# clusters/minikube/core/cloudnative-pg/minio-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: databases
type: Opaque
data:
  ACCESS_KEY_ID: <base64-encoded-access-key>
  SECRET_ACCESS_KEY: <base64-encoded-secret-key>
```

#### Option 2: Infisical-Managed Secret (Recommended for Production)
```yaml
# clusters/minikube/core/cloudnative-pg/minio-infisical-secret.yaml
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: minio-credentials
  namespace: databases
spec:
  hostAPI: https://app.infisical.com/api
  resyncInterval: 15m
  authentication:
    universalAuth:
      identityId: "your-minio-machine-identity-id"
      credentialsRef:
        secretName: infisical-credentials
        secretNamespace: databases

  secretsScope:
    projectSlug: "infrastructure"
    envSlug: "production"
    secretsPath: "/minio"
    recursive: true

  managedKubeSecretReferences:
    - secretName: minio-credentials
      secretNamespace: databases
      creationPolicy: "Orphan"
      template:
        includeAllSecrets: true
        data:
          # Standardize key names for CloudNative-PG
          ACCESS_KEY_ID: "{{ .MINIO_ACCESS_KEY.Value }}"
          SECRET_ACCESS_KEY: "{{ .MINIO_SECRET_KEY.Value }}"
          ENDPOINT_URL: "{{ .MINIO_ENDPOINT.Value }}"
```

#### Option 3: Dynamic MinIO Credentials (Advanced)
```yaml
# clusters/minikube/core/cloudnative-pg/minio-dynamic-secret.yaml
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalDynamicSecret
metadata:
  name: minio-dynamic-access
  namespace: databases
spec:
  hostAPI: https://app.infisical.com/api
  dynamicSecret:
    secretName: "minio-temp-access"
    projectId: "your-project-id"
    secretsPath: "/dynamic/minio"
    environmentSlug: "production"

  leaseRevocationPolicy: Revoke
  leaseTTL: 1h

  managedSecretReference:
    secretName: minio-temp-credentials
    secretNamespace: databases
    creationPolicy: Orphan

  authentication:
    universalAuth:
      credentialsRef:
        secretName: infisical-credentials
        secretNamespace: databases
```

## Phase 3: Declarative Database Management

### 3.1 Additional Databases with Database CRD

```yaml
# clusters/minikube/apps/gitea/gitea-additional-db.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: gitea-analytics
  namespace: databases
spec:
  name: gitea_analytics
  owner: gitea
  cluster:
    name: gitea-postgres
  extensions:
  - name: timescaledb
    ensure: present
  schemas:
  - name: analytics
    owner: gitea
    ensure: present
    searchPath: ["analytics", "public"]
```

### 3.2 Schema Management

```yaml
# clusters/minikube/apps/coder/coder-schemas.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: coder-schemas
  namespace: databases
spec:
  cluster:
    name: coder-postgres
  schemas:
  - name: workspaces
    owner: coder
    ensure: present
  - name: templates
    owner: coder
    ensure: present
  - name: audit
    owner: coder
    ensure: present
```

## Phase 4: Backup and Recovery

### 4.1 Scheduled Backups

```yaml
# clusters/minikube/core/cloudnative-pg/scheduled-backups.yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: gitea-daily-backup
  namespace: databases
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  cluster:
    name: gitea-postgres
  backupOwnerReference: self
  immediate: true

---
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: coder-daily-backup
  namespace: databases
spec:
  schedule: "0 3 * * *"  # Daily at 3 AM
  cluster:
    name: coder-postgres
  backupOwnerReference: self
  immediate: true
```

### 4.2 Point-in-Time Recovery (PITR)

#### With Manual Credentials:
```yaml
# Example PITR cluster creation
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: gitea-postgres-restored
  namespace: databases
spec:
  instances: 1

  bootstrap:
    recovery:
      source: gitea-postgres
      recoveryTarget:
        targetTime: "2025-09-03 14:30:00+00"

  storage:
    size: 20Gi
    storageClass: longhorn-retain

  externalClusters:
  - name: gitea-postgres
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
```

#### With Infisical-Managed Credentials:
```yaml
# Example PITR cluster creation with Infisical-managed S3 credentials
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: gitea-postgres-restored
  namespace: databases
spec:
  instances: 1

  bootstrap:
    recovery:
      source: gitea-postgres
      recoveryTarget:
        targetTime: "2025-09-03 14:30:00+00"

  storage:
    size: 20Gi
    storageClass: longhorn-retain

  externalClusters:
  - name: gitea-postgres
    barmanObjectStore:
      destinationPath: "s3://postgres-backups/gitea"
      s3Credentials:
        accessKeyId:
          name: minio-credentials  # Managed by Infisical operator
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: minio-credentials
          key: SECRET_ACCESS_KEY
      # Use templated endpoint from Infisical
      endpointURL: "{{ .ENDPOINT_URL }}"  # From Infisical template
```

### 4.3 Manual Backup Operations

```bash
# Create immediate backup
kubectl cnpg backup gitea-postgres -n databases

# List backups
kubectl get backups -n databases

# Show backup details
kubectl describe backup gitea-postgres-20250903-020000 -n databases
```

## Phase 5: Application Integration

### 5.1 Update Gitea Deployment

```yaml
# clusters/minikube/apps/gitea/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitea
  namespace: gitea
spec:
  template:
    spec:
      containers:
      - name: gitea
        env:
        - name: GITEA__database__DB_TYPE
          value: postgres
        - name: GITEA__database__HOST
          value: gitea-postgres-rw.databases.svc.cluster.local
        - name: GITEA__database__NAME
          value: gitea
        - name: GITEA__database__USER
          valueFrom:
            secretKeyRef:
              name: gitea-postgres-credentials
              key: username
        - name: GITEA__database__PASSWD
          valueFrom:
            secretKeyRef:
              name: gitea-postgres-credentials
              key: password
```

### 5.2 Update Coder Deployment

```yaml
# clusters/minikube/apps/coder/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coder
  namespace: coder
spec:
    spec:
      containers:
      - name: coder
        env:
        - name: CODER_PG_CONNECTION_URL
          valueFrom:
            secretKeyRef:
              name: coder-postgres-app
              key: uri
```

## Phase 6: Monitoring and Maintenance

### 6.1 Prometheus Metrics

CloudNative-PG automatically exposes metrics for:
- Cluster health status
- Replication lag
- Backup status
- WAL archiving status
- Connection counts

### 6.2 Health Checks

```bash
# Check cluster status
kubectl cnpg status gitea-postgres -n databases

# Check replication status
kubectl get pods -n databases -l postgresql.cnpg.io/cluster=gitea-postgres

# Monitor backup status
kubectl get backups -n databases
```

### 6.3 Maintenance Operations

#### Scale Cluster
```yaml
# Scale to 3 instances
kubectl patch cluster gitea-postgres -n databases --type merge -p '{"spec":{"instances":3}}'
```

#### Update PostgreSQL Version
```yaml
# Update to PostgreSQL 16
kubectl patch cluster gitea-postgres -n databases --type merge -p '{"spec":{"postgresVersion":16}}'
```

#### Resize Storage
```yaml
# Increase storage to 50Gi
kubectl patch cluster gitea-postgres -n databases --type merge -p '{"spec":{"storage":{"size":"50Gi"}}}'
```

### 6.4 Log Management

```yaml
# View PostgreSQL logs
kubectl logs -n databases -l postgresql.cnpg.io/cluster=gitea-postgres

# View operator logs
kubectl logs -n cnpg-system deployment/cloudnative-pg
```

## Phase 7: Migration from Embedded PostgreSQL

### 7.1 Data Migration Strategy

1. **Create parallel CloudNative-PG clusters**
2. **Dump existing databases**
3. **Import data into new clusters**
4. **Update application configurations**
5. **Verify functionality**
6. **Decommission old deployments**

### 7.2 Migration Commands

```bash
# Dump existing Gitea database
kubectl exec -n gitea gitea-postgres-0 -- pg_dump gitea > gitea-dump.sql

# Import into CloudNative-PG
kubectl exec -n databases gitea-postgres-1 -- psql -d gitea < gitea-dump.sql
```

### 7.3 Zero-Downtime Migration

```yaml
# Create migration job
apiVersion: batch/v1
kind: Job
metadata:
  name: gitea-migration
  namespace: databases
spec:
  template:
    spec:
      containers:
      - name: migration
        image: postgres:15
        command:
        - /bin/bash
        - -c
        - |
          pg_dump -h gitea-postgres.gitea.svc.cluster.local -U gitea gitea | \
          psql -h gitea-postgres-rw.databases.svc.cluster.local -U gitea gitea
      restartPolicy: Never
```

## Phase 8: Security and Compliance

### 8.1 Network Policies

```yaml
# clusters/minikube/core/cloudnative-pg/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-network-policy
  namespace: databases
spec:
  podSelector:
    matchLabels:
      postgresql.cnpg.io/cluster: gitea-postgres
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: gitea
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: minio
    ports:
    - protocol: TCP
      port: 9000
```

### 8.2 TLS Configuration

```yaml
# Enable TLS for PostgreSQL connections
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: gitea-postgres
  namespace: databases
spec:
  certificates:
    serverCASecret: postgres-ca
    serverTLSSecret: postgres-tls
    clientCASecret: postgres-client-ca
  postgresql:
    parameters:
      ssl: "on"
      ssl_min_protocol_version: "TLSv1.2"
```

### 8.3 RBAC Configuration

```yaml
# clusters/minikube/core/cloudnative-pg/rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: databases
  name: postgres-operator
rules:
- apiGroups: ["postgresql.cnpg.io"]
  resources: ["clusters", "backups", "scheduledbackups"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

## Phase 9: Troubleshooting

### 9.1 Common Issues

#### Cluster Not Starting
```bash
# Check events
kubectl get events -n databases

# Check pod logs
kubectl logs -n databases -l postgresql.cnpg.io/cluster=gitea-postgres

# Check PVC status
kubectl get pvc -n databases
```

#### Backup Failures
```bash
# Check backup status
kubectl describe backup <backup-name> -n databases

# Check MinIO connectivity
kubectl exec -n databases gitea-postgres-1 -- curl -v http://minio.minio.svc:9000
```

#### Replication Issues
```bash
# Check replication status
kubectl cnpg status gitea-postgres -n databases

# Check WAL sender/receiver processes
kubectl exec -n databases gitea-postgres-1 -- ps aux | grep wal
```

### 9.2 Performance Tuning

```yaml
# Optimize for high throughput
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: gitea-postgres
  namespace: databases
spec:
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      work_mem: "4MB"
      maintenance_work_mem: "64MB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
```

## Phase 10: Automation and CI/CD

### 10.1 Automated Testing

```yaml
# clusters/minikube/core/cloudnative-pg/postgres-tests.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-test-scripts
  namespace: databases
data:
  test-connection.sh: |
    #!/bin/bash
    PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT version();"
  test-backup.sh: |
    #!/bin/bash
    kubectl cnpg backup $CLUSTER_NAME -n databases
    sleep 30
    kubectl get backups -n databases -l postgresql.cnpg.io/cluster=$CLUSTER_NAME
```

### 10.2 GitOps Integration

```yaml
# clusters/minikube/core/cloudnative-pg/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- helmrepository.yaml
- helmrelease.yaml
- namespace.yaml
- gitea-credentials.yaml
- coder-credentials.yaml
- minio-credentials.yaml
- scheduled-backups.yaml
- network-policies.yaml
- rbac.yaml
```

## Summary

This guide provides a complete CloudNative-PG implementation covering:

1. **Operator Installation**: Helm-based deployment with Flux
2. **Cluster Provisioning**: Automated PostgreSQL cluster creation
3. **Database Management**: Declarative database and schema management
4. **Backup & Recovery**: Automated backups with PITR capability
5. **Application Integration**: Seamless connection to Gitea and Coder
6. **Monitoring & Maintenance**: Comprehensive operational procedures
7. **Migration Strategy**: Zero-downtime migration from embedded PostgreSQL
8. **Security**: TLS, network policies, and RBAC
9. **Secret Management**: Multiple options including manual, ESO, and Infisical
10. **Troubleshooting**: Common issues and performance tuning
11. **Automation**: GitOps integration and automated testing

**Secret Management Options**:
- **Manual Secrets**: Traditional Kubernetes secrets (current approach)
- **External Secrets Operator**: Centralized secret management with broad provider support
- **Infisical Operator**: Advanced secret management with dynamic secrets and templating
- **Hybrid Approach**: Combine ESO and Infisical for complex requirements

**Next Steps**:
1. Review and approve the implementation plan
2. Choose secret management strategy (Manual/ESO/Infisical/Hybrid)
3. Set up MinIO credentials and storage
4. Deploy CloudNative-PG operator
5. Create test clusters for validation
6. Plan migration timeline for production applications

**Key Benefits**:
- **Automated Provisioning**: Declarative database creation
- **Enterprise Backup**: WAL archiving and PITR with S3-compatible storage
- **High Availability**: Multi-instance clusters with automatic failover
- **GitOps Integration**: Complete infrastructure as code
- **Security**: TLS encryption, access controls, and centralized secret management
- **Monitoring**: Comprehensive metrics and alerting
- **Scalability**: Easy scaling and storage expansion
- **Flexibility**: Multiple secret management options for different requirements</content>
<parameter name="filePath">/Users/xoojulian/Downloads/minikube/docs/CLOUDNATIVE_PG_SETUP_GUIDE.md
