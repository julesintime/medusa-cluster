# RagFlow Application

RagFlow is a RAG (Retrieval-Augmented Generation) framework for building AI-powered applications with document processing, knowledge base management, and conversational AI capabilities.

## Architecture

This deployment includes the following components:

- **RagFlow Application**: Main web interface and API (port 9380)
- **MySQL**: Primary database for application data
- **Redis**: Caching and session storage
- **MinIO**: Object storage for documents and files
- **Elasticsearch**: Search and indexing engine

## Access

- **URL**: https://rag.xuperson.org
- **External DNS**: Automatically configured via ExternalDNS
- **SSL**: Cloudflare handles SSL termination

## Configuration

### Environment Variables

The application is configured with the following environment variables:

- `MYSQL_PASSWORD`: Database password (managed via Infisical)
- `REDIS_PASSWORD`: Redis password (managed via Infisical)
- `MINIO_ACCESS_KEY`: MinIO access key (managed via Infisical)
- `MINIO_SECRET_KEY`: MinIO secret key (managed via Infisical)
- `ELASTIC_PASSWORD`: Elasticsearch password (managed via Infisical)

### Secrets Management

All sensitive configuration is managed through Infisical:

- **Path**: `/ragflow`
- **Environment**: `prod`
- **Service Token**: Shared from `infisical-operator` namespace

## Deployment Details

### Resources

- **CPU Request**: 500m
- **Memory Request**: 1Gi
- **CPU Limit**: 1000m
- **Memory Limit**: 2Gi

### Health Checks

- **Liveness Probe**: HTTP GET on `/` every 30s after 60s initial delay
- **Readiness Probe**: HTTP GET on `/` every 10s after 30s initial delay

### Storage

- **MySQL**: 10Gi PVC
- **Redis**: 2Gi PVC (master and replica)
- **MinIO**: 10Gi PVC
- **Elasticsearch**: 10Gi PVC

## Monitoring

The deployment includes:

- **Metrics**: Enabled for MySQL, Redis via respective Helm charts
- **Health Checks**: Kubernetes probes for application health
- **Logs**: Application logs available via `kubectl logs`

## Scaling

Currently configured for single replica. For production workloads:

1. Increase replica count in deployment
2. Configure proper session affinity
3. Consider using external load balancer
4. Implement proper backup strategies

## Troubleshooting

### Common Issues

1. **Database Connection**: Check MySQL pod status and credentials
2. **Search Issues**: Verify Elasticsearch cluster health
3. **Storage Issues**: Check MinIO service and PVC status
4. **Cache Issues**: Verify Redis connectivity

### Logs

```bash
# Application logs
kubectl logs -n rag deployment/ragflow

# Database logs
kubectl logs -n rag statefulset/rag-mysql

# Search logs
kubectl logs -n rag statefulset/rag-elasticsearch
```

### Health Checks

```bash
# Check all pods
kubectl get pods -n rag

# Check services
kubectl get svc -n rag

# Check ingress
kubectl get ingress -n rag

# Check PVCs
kubectl get pvc -n rag
```

## Backup Strategy

Consider implementing backups for:

- MySQL database dumps
- MinIO object storage
- Elasticsearch indices
- Application configuration

## Security

- **RBAC**: Service account with minimal permissions
- **Network Policies**: Consider implementing network segmentation
- **Secrets**: All sensitive data managed via Infisical
- **SSL**: End-to-end encryption via Cloudflare

## Future Enhancements

- Add Infinity vector database for better embeddings
- Implement horizontal scaling
- Add monitoring and alerting
- Configure backup automation
- Add CI/CD pipeline integration
