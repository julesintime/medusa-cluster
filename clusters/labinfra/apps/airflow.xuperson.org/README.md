# Apache Airflow Orchestration Platform

Complete Apache Airflow deployment with CeleryExecutor for scalable workflow orchestration and data pipeline management.

## Components

### Core Airflow
- **Webserver**: Web UI and API server
- **Scheduler**: Workflow scheduling and task management
- **Workers**: Distributed task execution (2 replicas)
- **Flower**: Celery monitoring dashboard

### Infrastructure
- **PostgreSQL**: Metadata database (bundled)
- **Redis**: Celery message broker and result backend (bundled)
- **StatsD**: Metrics collection for monitoring

## Access

- **URL**: https://airflow.xuperson.org
- **LoadBalancer IPs**:
  - Airflow: 192.168.80.107
  - PostgreSQL: 192.168.80.108
  - Redis: 192.168.80.109
- **Admin Credentials**: Stored in Infisical as `AIRFLOW_ADMIN_USERNAME` / `AIRFLOW_ADMIN_PASSWORD`

## Configuration

- **Executor**: CeleryExecutor for distributed task execution
- **Authentication**: Password-based authentication enabled
- **Example DAGs**: Disabled for production
- **Config Exposure**: Enabled for debugging and development

## Security

- All components run as non-root with dropped capabilities
- Read-only root filesystems where possible
- TLS termination handled by Cloudflare through ingress
- Fernet key and secrets managed via Infisical
- Dedicated service account with minimal permissions

## Storage

- **DAGs**: 10Gi persistent storage
- **Logs**: 20Gi persistent storage
- **Workers**: 10Gi per worker for temporary files
- **PostgreSQL**: 20Gi database storage
- **Redis**: 8Gi cache storage

## Resources

- **CPU Requests**: ~1200m total
- **Memory Requests**: ~3Gi total
- **CPU Limits**: ~5200m total
- **Memory Limits**: ~10Gi total

## Dependencies

- Requires Infisical secrets: `AIRFLOW_ADMIN_USERNAME`, `AIRFLOW_ADMIN_PASSWORD`, `AIRFLOW_ADMIN_EMAIL`, `AIRFLOW_POSTGRESQL_PASSWORD`, `AIRFLOW_POSTGRESQL_POSTGRES_PASSWORD`, `AIRFLOW_REDIS_PASSWORD`, `AIRFLOW_FERNET_KEY`, `AIRFLOW_SECRET_KEY`
- Uses shared service token from `infisical-operator` namespace
- Requires nginx ingress controller and ExternalDNS