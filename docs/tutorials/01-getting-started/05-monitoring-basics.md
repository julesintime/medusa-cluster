# Monitoring Basics - Comprehensive Observability Stack

**Deploy production-ready monitoring with Prometheus, Grafana, and AlertManager for complete system visibility**

Monitoring is essential for maintaining reliable infrastructure and applications. This 45-minute tutorial walks through deploying a complete observability stack using the industry-standard Prometheus ecosystem, providing metrics collection, visualization, and alerting capabilities.

**Learning Objectives:**
- Deploy Prometheus stack using kube-prometheus-stack Helm chart
- Configure application and infrastructure monitoring with ServiceMonitors
- Create custom Grafana dashboards for application and cluster metrics
- Set up intelligent alerting with AlertManager and notification channels
- Implement monitoring best practices and troubleshooting workflows

**Prerequisites:**
- Completed previous tutorials including [domain and SSL setup](04-domain-and-ssl.md)
- K3s cluster with NGINX ingress controller and cert-manager
- Applications deployed with external access configured
- Understanding of metrics concepts and Kubernetes resource management

---

## The Monitoring Challenge

### Why Comprehensive Monitoring Matters

**Without proper monitoring:**
- Application issues discovered by users, not operators
- No visibility into system resource utilization patterns
- Reactive incident response without predictive insights
- Difficult troubleshooting without historical data context

**Production monitoring requirements:**
- Real-time metrics collection from all cluster components
- Historical data storage for trend analysis and capacity planning
- Visual dashboards for quick system health assessment
- Proactive alerting for issues before they impact users
- Secure access controls and data retention policies

### Our Monitoring Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Applications  │    │   Kubernetes    │    │  Infrastructure │
│                 │    │   Components    │    │                 │
│  /metrics       │──▶ │  API Server     │──▶ │  Node Metrics   │
│  Custom Metrics │    │  kubelet        │    │  System Metrics │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Prometheus                               │
│  • Metrics Collection    • Service Discovery               │
│  • Time Series DB       • Query Engine (PromQL)           │
└─────────────────────────────────────────────────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Grafana     │    │  AlertManager   │    │   Exporters     │
│                 │    │                 │    │                 │
│  Visualization  │    │  Alert Routing  │    │  Node Exporter  │
│  Dashboards     │    │  Notifications  │    │  App Metrics    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

**Key Components:**
- **Prometheus**: Collects and stores metrics as time-series data
- **Grafana**: Provides rich visualization and dashboard capabilities
- **AlertManager**: Handles alert routing, grouping, and notifications
- **Node Exporter**: Exposes hardware and OS metrics from cluster nodes
- **ServiceMonitors**: Kubernetes CRDs that configure metric scraping

---

## kube-prometheus-stack Deployment

### 1. Prepare Monitoring Namespace

```bash
# Create dedicated namespace for monitoring
kubectl create namespace monitoring

# Label namespace for Prometheus Operator discovery
kubectl label namespace monitoring monitoring=prometheus
```

### 2. Add Prometheus Community Helm Repository

```bash
# Add the official Prometheus Community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Verify repository is added
helm search repo prometheus-community/kube-prometheus-stack
```

### 3. Configure kube-prometheus-stack Values

```bash
# Create comprehensive values file for production deployment
cat > monitoring-values.yaml << 'EOF'
# Global configuration for kube-prometheus-stack
global:
  # Resolve Kubernetes API endpoint for webhook URLs
  rbac:
    create: true
    pspEnabled: false  # Pod Security Policies deprecated in K8s 1.21+

# Prometheus configuration
prometheus:
  prometheusSpec:
    # Data retention settings
    retention: 30d
    retentionSize: 10GB
    
    # Storage configuration
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path  # K3s default storage class
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 15GB
    
    # Resource requests and limits
    resources:
      requests:
        memory: 2Gi
        cpu: 500m
      limits:
        memory: 4Gi
        cpu: 2000m
    
    # External URL for ingress access
    externalUrl: https://prometheus.example.com  # Replace with your domain
    
    # Security context
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      fsGroup: 2000
    
    # Additional scrape configs for custom applications
    additionalScrapeConfigs: []
    
    # Service monitor selector (monitor all namespaces)
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    
  # Ingress configuration for external access
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      external-dns.alpha.kubernetes.io/hostname: "prometheus.example.com"  # Replace
      cert-manager.io/cluster-issuer: "letsencrypt-production"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      # Basic auth for security (optional)
      nginx.ingress.kubernetes.io/auth-type: basic
      nginx.ingress.kubernetes.io/auth-secret: prometheus-basic-auth
    hosts:
      - prometheus.example.com  # Replace with your domain
    tls:
      - secretName: prometheus-tls
        hosts:
          - prometheus.example.com

# Grafana configuration
grafana:
  # Admin credentials configuration
  adminPassword: admin123  # Change in production - use secrets
  
  # Persistence for dashboards and configurations
  persistence:
    enabled: true
    type: pvc
    storageClassName: local-path
    accessModes:
      - ReadWriteOnce
    size: 5Gi
    
  # Resource configuration
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi
      cpu: 500m
  
  # Grafana configuration
  grafana.ini:
    server:
      domain: grafana.example.com  # Replace with your domain
      root_url: https://grafana.example.com
    auth.anonymous:
      enabled: false
    security:
      admin_user: admin
      disable_gravatar: true
    alerting:
      enabled: true
    unified_alerting:
      enabled: true
  
  # Ingress configuration
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      external-dns.alpha.kubernetes.io/hostname: "grafana.example.com"  # Replace
      cert-manager.io/cluster-issuer: "letsencrypt-production"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - grafana.example.com  # Replace with your domain
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.example.com
  
  # Default dashboards and plugins
  defaultDashboardsEnabled: true
  defaultDashboardsTimezone: UTC
  
  # Additional plugins to install
  plugins:
    - grafana-piechart-panel
    - grafana-worldmap-panel
    - grafana-clock-panel

# AlertManager configuration
alertmanager:
  alertmanagerSpec:
    # Storage configuration
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2GB
    
    # Resource configuration
    resources:
      requests:
        memory: 64Mi
        cpu: 50m
      limits:
        memory: 128Mi
        cpu: 200m
    
    # External URL for webhook notifications
    externalUrl: https://alertmanager.example.com  # Replace with your domain
    
    # Security context
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      fsGroup: 2000
  
  # Ingress configuration
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      external-dns.alpha.kubernetes.io/hostname: "alertmanager.example.com"  # Replace
      cert-manager.io/cluster-issuer: "letsencrypt-production"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - alertmanager.example.com  # Replace with your domain
    tls:
      - secretName: alertmanager-tls
        hosts:
          - alertmanager.example.com

# Node Exporter configuration
nodeExporter:
  enabled: true
  # Deploy as DaemonSet to collect metrics from all nodes
  
# Kube State Metrics configuration
kubeStateMetrics:
  enabled: true

# Additional configuration for K3s compatibility
kubeControllerManager:
  enabled: false  # K3s runs controller manager as part of main process
  
kubeEtcd:
  enabled: false  # K3s uses embedded etcd that's not exposed by default
  
kubeScheduler:
  enabled: false  # K3s runs scheduler as part of main process

kubeProxy:
  enabled: false  # K3s uses different proxy implementation

# Custom ServiceMonitor for applications
additionalServiceMonitors: []
EOF

# Update domain placeholders in the values file
sed -i 's/example\.com/your-domain.com/g' monitoring-values.yaml
```

### 4. Deploy the Monitoring Stack

```bash
# Install kube-prometheus-stack
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring-values.yaml \
  --wait

# Verify installation
kubectl get pods -n monitoring
kubectl get pvc -n monitoring
kubectl get ingress -n monitoring

# Check that all components are ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=alertmanager -n monitoring --timeout=300s
```

---

## Application Monitoring Configuration

### 1. Instrument Application with Metrics

Update your existing application to expose Prometheus metrics:

```bash
# Create enhanced Node.js application with Prometheus metrics
cat > app-with-metrics.js << 'EOF'
const express = require('express');
const promClient = require('prom-client');

const app = express();
const port = 3000;

// Create Prometheus metrics registry
const register = new promClient.Registry();

// Add default metrics (CPU, memory, etc.)
promClient.collectDefaultMetrics({
  register,
  prefix: 'nodejs_app_'
});

// Custom application metrics
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.001, 0.005, 0.015, 0.05, 0.1, 0.5, 1, 5],
  registers: [register]
});

const activeConnections = new promClient.Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
  registers: [register]
});

// Middleware to track metrics
app.use((req, res, next) => {
  const startTime = Date.now();
  
  // Increment active connections
  activeConnections.inc();
  
  res.on('finish', () => {
    // Record request duration
    const duration = (Date.now() - startTime) / 1000;
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path)
      .observe(duration);
    
    // Increment request counter
    httpRequestsTotal
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .inc();
    
    // Decrement active connections
    activeConnections.dec();
  });
  
  next();
});

// Application routes
app.get('/', (req, res) => {
  res.json({ 
    message: 'Hello from monitored application!',
    timestamp: new Date().toISOString(),
    version: '2.0.0'
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.get('/simulate-load', (req, res) => {
  // Simulate some CPU work
  const start = Date.now();
  while (Date.now() - start < Math.random() * 100) {
    // Busy wait to simulate work
  }
  
  res.json({
    message: 'Load simulation completed',
    duration: Date.now() - start
  });
});

// Prometheus metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(port, () => {
  console.log(`Monitored app listening on port ${port}`);
  console.log(`Metrics available at http://localhost:${port}/metrics`);
});
EOF

# Create package.json with Prometheus client
cat > package.json << 'EOF'
{
  "name": "monitored-app",
  "version": "2.0.0",
  "description": "Application with Prometheus metrics",
  "main": "app-with-metrics.js",
  "scripts": {
    "start": "node app-with-metrics.js",
    "dev": "nodemon app-with-metrics.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "prom-client": "^15.1.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF
```

### 2. Deploy Application with Metrics

```bash
# Update application deployment with metrics
cat > monitored-app-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitored-app
  namespace: demo
  labels:
    app: monitored-app
    version: v2.0.0
spec:
  replicas: 2
  selector:
    matchLabels:
      app: monitored-app
  template:
    metadata:
      labels:
        app: monitored-app
        version: v2.0.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: monitored-app
        image: node:18-alpine
        ports:
        - containerPort: 3000
          name: http
        - containerPort: 3000
          name: metrics
        command: ["sh", "-c"]
        args:
          - |
            npm install express prom-client &&
            node -e "
            const express = require('express');
            const promClient = require('prom-client');
            const app = express();
            const register = new promClient.Registry();
            
            promClient.collectDefaultMetrics({
              register,
              prefix: 'nodejs_app_'
            });
            
            const httpRequestsTotal = new promClient.Counter({
              name: 'http_requests_total',
              help: 'Total number of HTTP requests',
              labelNames: ['method', 'route', 'status_code'],
              registers: [register]
            });
            
            const httpRequestDuration = new promClient.Histogram({
              name: 'http_request_duration_seconds',
              help: 'Duration of HTTP requests in seconds',
              labelNames: ['method', 'route'],
              buckets: [0.001, 0.005, 0.015, 0.05, 0.1, 0.5, 1, 5],
              registers: [register]
            });
            
            app.use((req, res, next) => {
              const startTime = Date.now();
              res.on('finish', () => {
                const duration = (Date.now() - startTime) / 1000;
                httpRequestDuration.labels(req.method, req.path).observe(duration);
                httpRequestsTotal.labels(req.method, req.path, res.statusCode).inc();
              });
              next();
            });
            
            app.get('/', (req, res) => {
              res.json({ message: 'Hello from monitored app!', timestamp: new Date().toISOString() });
            });
            
            app.get('/health', (req, res) => {
              res.status(200).json({ status: 'healthy', uptime: process.uptime() });
            });
            
            app.get('/metrics', async (req, res) => {
              res.set('Content-Type', register.contentType);
              res.end(await register.metrics());
            });
            
            app.listen(3000, () => console.log('Monitored app listening on port 3000'));
            "
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: monitored-app-service
  namespace: demo
  labels:
    app: monitored-app
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "3000"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: monitored-app
  ports:
    - name: http
      port: 80
      targetPort: 3000
    - name: metrics
      port: 3000
      targetPort: 3000
  type: ClusterIP
EOF

kubectl apply -f monitored-app-deployment.yaml

# Verify metrics endpoint is working
kubectl port-forward svc/monitored-app-service 3000:3000 -n demo &
curl http://localhost:3000/metrics
kill %1  # Stop port-forward
```

### 3. Create ServiceMonitor for Application

```bash
# Create ServiceMonitor to tell Prometheus to scrape the application
cat > monitored-app-servicemonitor.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: monitored-app
  namespace: demo
  labels:
    app: monitored-app
    release: prometheus-stack  # Must match the Helm release name
spec:
  selector:
    matchLabels:
      app: monitored-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    honorLabels: true
    scrapeTimeout: 10s
  namespaceSelector:
    matchNames:
    - demo
EOF

kubectl apply -f monitored-app-servicemonitor.yaml

# Verify ServiceMonitor is created and discovered
kubectl get servicemonitor -n demo
kubectl describe servicemonitor monitored-app -n demo
```

---

## Grafana Dashboard Configuration

### 1. Access Grafana

```bash
# Get Grafana admin password (if using default configuration)
kubectl get secret prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d
echo

# Access Grafana via port-forward (for testing)
kubectl port-forward svc/prometheus-stack-grafana 3000:80 -n monitoring &

# Or access via ingress (if configured)
echo "Access Grafana at: https://grafana.your-domain.com"
echo "Username: admin"
echo "Password: (from secret above)"
```

### 2. Create Custom Application Dashboard

```json
# Create application dashboard JSON
cat > app-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Monitored Application Dashboard",
    "tags": ["application", "nodejs", "prometheus"],
    "timezone": "UTC",
    "panels": [
      {
        "id": 1,
        "title": "Request Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m]))",
            "legendFormat": "Requests/sec"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps"
          }
        },
        "gridPos": {
          "h": 8,
          "w": 6,
          "x": 0,
          "y": 0
        }
      },
      {
        "id": 2,
        "title": "Response Time",
        "type": "stat",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
            "legendFormat": "95th percentile"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s"
          }
        },
        "gridPos": {
          "h": 8,
          "w": 6,
          "x": 6,
          "y": 0
        }
      },
      {
        "id": 3,
        "title": "Active Connections",
        "type": "stat",
        "targets": [
          {
            "expr": "active_connections",
            "legendFormat": "Active"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "short"
          }
        },
        "gridPos": {
          "h": 8,
          "w": 6,
          "x": 12,
          "y": 0
        }
      },
      {
        "id": 4,
        "title": "Error Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status_code=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m])) * 100",
            "legendFormat": "Error %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {
                  "color": "green",
                  "value": null
                },
                {
                  "color": "yellow",
                  "value": 1
                },
                {
                  "color": "red",
                  "value": 5
                }
              ]
            }
          }
        },
        "gridPos": {
          "h": 8,
          "w": 6,
          "x": 18,
          "y": 0
        }
      },
      {
        "id": 5,
        "title": "Request Rate Over Time",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum by (method) (rate(http_requests_total[5m]))",
            "legendFormat": "{{method}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "reqps"
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 8
        }
      },
      {
        "id": 6,
        "title": "Response Time Distribution",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
            "legendFormat": "50th percentile"
          },
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
            "legendFormat": "95th percentile"
          },
          {
            "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))",
            "legendFormat": "99th percentile"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s"
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 8
        }
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
EOF
```

### 3. Import Dashboard via API

```bash
# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d)

# Import dashboard using Grafana API
curl -X POST \
  http://admin:${GRAFANA_PASSWORD}@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @app-dashboard.json

# Stop port-forward
kill %1
```

---

## AlertManager Configuration

### 1. Configure AlertManager with Notification Channels

```bash
# Create AlertManager configuration secret
cat > alertmanager-config.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-prometheus-stack-kube-prom-alertmanager
  namespace: monitoring
type: Opaque
stringData:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'smtp.gmail.com:587'
      smtp_from: 'alerts@your-domain.com'
      smtp_auth_username: 'alerts@your-domain.com'
      smtp_auth_password: 'your-app-password'  # Use app password, not regular password
      
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 1h
      receiver: 'default-receiver'
      routes:
      # Critical alerts route
      - match:
          severity: critical
        receiver: 'critical-alerts'
        group_wait: 10s
        repeat_interval: 30m
      
      # Warning alerts route
      - match:
          severity: warning
        receiver: 'warning-alerts'
        repeat_interval: 2h
        
    receivers:
    - name: 'default-receiver'
      email_configs:
      - to: 'admin@your-domain.com'
        subject: '[ALERT] {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Labels: {{ range .Labels.SortedPairs }}{{ .Name }}={{ .Value }} {{ end }}
          {{ end }}
          
    - name: 'critical-alerts'
      email_configs:
      - to: 'oncall@your-domain.com'
        subject: '[CRITICAL] {{ .GroupLabels.alertname }}'
        body: |
          🚨 CRITICAL ALERT 🚨
          
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          Instance: {{ .Labels.instance }}
          Started: {{ .StartsAt.Format "2006-01-02 15:04:05" }}
          Labels: {{ range .Labels.SortedPairs }}{{ .Name }}={{ .Value }} {{ end }}
          {{ end }}
          
          Dashboard: https://grafana.your-domain.com
          AlertManager: https://alertmanager.your-domain.com
          
    - name: 'warning-alerts'
      email_configs:
      - to: 'team@your-domain.com'
        subject: '[WARNING] {{ .GroupLabels.alertname }}'
        body: |
          ⚠️  Warning Alert
          
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Instance: {{ .Labels.instance }}
          {{ end }}
    
    inhibit_rules:
    - source_match:
        severity: 'critical'
      target_match:
        severity: 'warning'
      equal: ['alertname', 'instance']
EOF

kubectl apply -f alertmanager-config.yaml

# Restart AlertManager to pick up new configuration
kubectl rollout restart statefulset/alertmanager-prometheus-stack-kube-prom-alertmanager -n monitoring
```

### 2. Create Custom Alerting Rules

```bash
# Create application-specific alerting rules
cat > app-alert-rules.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: monitored-app-alerts
  namespace: demo
  labels:
    app: monitored-app
    release: prometheus-stack  # Must match Helm release name
spec:
  groups:
  - name: monitored-app.rules
    rules:
    # High error rate alert
    - alert: HighErrorRate
      expr: |
        (
          sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (instance) 
          / 
          sum(rate(http_requests_total[5m])) by (instance)
        ) * 100 > 5
      for: 2m
      labels:
        severity: critical
        service: monitored-app
      annotations:
        summary: "High error rate on {{ $labels.instance }}"
        description: "Error rate is {{ $value | humanizePercentage }} for {{ $labels.instance }}"
        runbook_url: "https://docs.your-domain.com/runbooks/high-error-rate"
    
    # High response time alert
    - alert: HighResponseTime
      expr: |
        histogram_quantile(0.95, 
          sum(rate(http_request_duration_seconds_bucket[5m])) by (le, instance)
        ) > 1.0
      for: 5m
      labels:
        severity: warning
        service: monitored-app
      annotations:
        summary: "High response time on {{ $labels.instance }}"
        description: "95th percentile response time is {{ $value }}s for {{ $labels.instance }}"
        runbook_url: "https://docs.your-domain.com/runbooks/high-response-time"
    
    # Application down alert
    - alert: ApplicationDown
      expr: up{job="monitored-app"} == 0
      for: 1m
      labels:
        severity: critical
        service: monitored-app
      annotations:
        summary: "Application instance down"
        description: "{{ $labels.instance }} has been down for more than 1 minute"
        runbook_url: "https://docs.your-domain.com/runbooks/app-down"
    
    # High CPU usage alert
    - alert: HighCPUUsage
      expr: |
        (
          sum(rate(nodejs_app_process_cpu_user_seconds_total[5m])) by (instance) + 
          sum(rate(nodejs_app_process_cpu_system_seconds_total[5m])) by (instance)
        ) * 100 > 80
      for: 10m
      labels:
        severity: warning
        service: monitored-app
      annotations:
        summary: "High CPU usage on {{ $labels.instance }}"
        description: "CPU usage is {{ $value | humanizePercentage }} for {{ $labels.instance }}"
    
    # High memory usage alert
    - alert: HighMemoryUsage
      expr: |
        (
          nodejs_app_process_resident_memory_bytes / 
          (1024 * 1024 * 1024)
        ) > 0.8
      for: 10m
      labels:
        severity: warning
        service: monitored-app
      annotations:
        summary: "High memory usage on {{ $labels.instance }}"
        description: "Memory usage is {{ $value }}GB for {{ $labels.instance }}"

  # Infrastructure alerts group
  - name: infrastructure.rules
    rules:
    # Node disk usage alert
    - alert: NodeDiskUsageHigh
      expr: |
        (
          node_filesystem_size_bytes{fstype!="tmpfs"} - 
          node_filesystem_free_bytes{fstype!="tmpfs"}
        ) / node_filesystem_size_bytes{fstype!="tmpfs"} * 100 > 85
      for: 5m
      labels:
        severity: warning
        service: infrastructure
      annotations:
        summary: "High disk usage on {{ $labels.instance }}"
        description: "Disk usage is {{ $value | humanizePercentage }} on {{ $labels.device }} ({{ $labels.instance }})"
    
    # Node memory usage alert
    - alert: NodeMemoryUsageHigh
      expr: |
        (
          node_memory_MemTotal_bytes - 
          node_memory_MemAvailable_bytes
        ) / node_memory_MemTotal_bytes * 100 > 90
      for: 5m
      labels:
        severity: critical
        service: infrastructure
      annotations:
        summary: "High memory usage on {{ $labels.instance }}"
        description: "Memory usage is {{ $value | humanizePercentage }} on {{ $labels.instance }}"
    
    # Node load average alert
    - alert: NodeLoadHigh
      expr: node_load1 / on(instance) count(node_cpu_seconds_total{mode="idle"}) by (instance) > 2
      for: 10m
      labels:
        severity: warning
        service: infrastructure
      annotations:
        summary: "High load average on {{ $labels.instance }}"
        description: "Load average is {{ $value }} on {{ $labels.instance }}"
EOF

kubectl apply -f app-alert-rules.yaml

# Verify rules are loaded
kubectl get prometheusrules -n demo
kubectl describe prometheusrule monitored-app-alerts -n demo
```

### 3. Test Alert Generation

```bash
# Generate load to trigger alerts
kubectl port-forward svc/monitored-app-service 3000:80 -n demo &

# Generate traffic that might trigger high response time alerts
for i in {1..100}; do
  curl http://localhost:3000/simulate-load &
done
wait

# Check if alerts are firing
kubectl port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090 -n monitoring &
# Visit http://localhost:9090/alerts in browser

kill %1 %2  # Stop port-forwards
```

---

## Advanced Monitoring Patterns

### 1. Custom Metrics and Recording Rules

```bash
# Create recording rules for common queries
cat > recording-rules.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: recording-rules
  namespace: monitoring
  labels:
    release: prometheus-stack
spec:
  groups:
  - name: application.recording
    interval: 30s
    rules:
    # Application request rate by service
    - record: app:request_rate5m
      expr: |
        sum(rate(http_requests_total[5m])) by (job, instance)
      
    # Application error rate by service
    - record: app:error_rate5m
      expr: |
        sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (job, instance) /
        sum(rate(http_requests_total[5m])) by (job, instance)
    
    # Application 95th percentile response time
    - record: app:response_time_95p5m
      expr: |
        histogram_quantile(0.95,
          sum(rate(http_request_duration_seconds_bucket[5m])) by (job, instance, le)
        )

  - name: infrastructure.recording
    interval: 30s
    rules:
    # Node CPU utilization
    - record: node:cpu_utilization
      expr: |
        100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
    
    # Node memory utilization
    - record: node:memory_utilization
      expr: |
        100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))
    
    # Node disk utilization
    - record: node:disk_utilization
      expr: |
        100 * (1 - (node_filesystem_free_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"}))
EOF

kubectl apply -f recording-rules.yaml
```

### 2. Monitoring Kubernetes Components

```bash
# Create ServiceMonitor for additional Kubernetes components
cat > k8s-components-monitor.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: k8s-components
  namespace: monitoring
  labels:
    release: prometheus-stack
spec:
  jobLabel: k8s-app
  selector:
    matchLabels:
      k8s-app: kubernetes
  namespaceSelector:
    matchNames:
      - kube-system
  endpoints:
  - port: https
    interval: 30s
    path: /metrics
    scheme: https
    tlsConfig:
      caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      serverName: kubernetes
    bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
EOF

kubectl apply -f k8s-components-monitor.yaml
```

---

## Troubleshooting and Maintenance

### Common Issues and Solutions

```bash
# 1. Check Prometheus targets
# Access Prometheus UI and go to Status -> Targets
kubectl port-forward svc/prometheus-stack-kube-prom-prometheus 9090:9090 -n monitoring &
# Visit http://localhost:9090/targets

# 2. Verify ServiceMonitor discovery
kubectl get servicemonitors -A
kubectl describe servicemonitor monitored-app -n demo

# 3. Check Prometheus configuration
kubectl get prometheus prometheus-stack-kube-prom-prometheus -n monitoring -o yaml

# 4. Verify alerting rules
kubectl get prometheusrules -A
kubectl describe prometheusrule monitored-app-alerts -n demo

# 5. Check AlertManager status
kubectl port-forward svc/prometheus-stack-kube-prom-alertmanager 9093:9093 -n monitoring &
# Visit http://localhost:9093

# 6. Debug metrics scraping
kubectl logs -l app.kubernetes.io/name=prometheus -n monitoring | grep -i error

# 7. Verify storage and retention
kubectl get pvc -n monitoring
kubectl describe pvc prometheus-prometheus-stack-kube-prom-prometheus-db-prometheus-prometheus-stack-kube-prom-prometheus-0 -n monitoring

kill %1 %2  # Stop port-forwards
```

### Maintenance Tasks

```bash
# Update Prometheus stack
helm repo update
helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring-values.yaml

# Backup Grafana dashboards
kubectl get configmaps -n monitoring | grep grafana-dashboard
# Export important dashboards via Grafana UI

# Clean up old metrics data (if needed)
kubectl exec -it prometheus-prometheus-stack-kube-prom-prometheus-0 -n monitoring -- \
  promtool tsdb create-blocks-from /prometheus/data

# Monitor resource usage
kubectl top pods -n monitoring
kubectl top nodes
```

---

## Security and Access Control

### 1. Enable Authentication for Prometheus

```bash
# Create basic auth for Prometheus
htpasswd -c auth prometheus
# Enter password when prompted

kubectl create secret generic prometheus-basic-auth \
  --from-file=auth \
  -n monitoring

# Update Prometheus ingress annotations
kubectl patch ingress prometheus-stack-kube-prom-prometheus -n monitoring -p '{
  "metadata": {
    "annotations": {
      "nginx.ingress.kubernetes.io/auth-type": "basic",
      "nginx.ingress.kubernetes.io/auth-secret": "prometheus-basic-auth"
    }
  }
}'
```

### 2. RBAC for Monitoring Stack

```bash
# Create monitoring team RBAC
cat > monitoring-rbac.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitoring-operator
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitoring-reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: monitoring-reader
subjects:
- kind: ServiceAccount
  name: monitoring-operator
  namespace: monitoring
EOF

kubectl apply -f monitoring-rbac.yaml
```

---

## Production Checklist

### Pre-Production Validation

- [ ] **Metrics collection working**: All applications exposing metrics properly
- [ ] **ServiceMonitors configured**: Prometheus discovering and scraping targets
- [ ] **Dashboards functional**: Grafana displaying accurate data
- [ ] **Alerts configured**: Critical alerts defined and tested
- [ ] **Notification channels**: AlertManager routing to correct recipients
- [ ] **Storage configured**: Persistent volumes for data retention
- [ ] **Access controls**: Authentication and authorization implemented

### Post-Production Monitoring

- [ ] **Data retention policies**: Configured appropriate retention periods
- [ ] **Performance monitoring**: Stack itself monitored for resource usage
- [ ] **Backup procedures**: Critical dashboards and configurations backed up
- [ ] **Alert fatigue prevention**: Alert thresholds tuned to avoid noise
- [ ] **Documentation maintained**: Runbooks and troubleshooting guides updated

### Operational Excellence

- [ ] **SLI/SLO definitions**: Service level indicators and objectives defined
- [ ] **Capacity planning**: Resource usage trends monitored
- [ ] **Cost optimization**: Storage and retention balanced with requirements
- [ ] **Security reviews**: Regular review of access controls and data exposure
- [ ] **Knowledge sharing**: Team trained on monitoring stack operation

---

## Cost Analysis

### Resource Usage Optimization

**Storage costs:**
```bash
# Monitor Prometheus storage usage
kubectl exec prometheus-prometheus-stack-kube-prom-prometheus-0 -n monitoring -- \
  du -sh /prometheus/data

# Check retention settings
kubectl get prometheus prometheus-stack-kube-prom-prometheus -n monitoring -o yaml | grep retention
```

**Typical resource usage for small cluster:**
- **Prometheus**: 2-4GB memory, 1-2 CPU cores, 15GB storage
- **Grafana**: 256-512MB memory, 0.1-0.5 CPU cores, 5GB storage
- **AlertManager**: 64-128MB memory, 0.05-0.2 CPU cores, 2GB storage
- **Node Exporter**: 32-64MB memory per node, 0.05-0.1 CPU cores

**Monthly cost estimate:**
- **Infrastructure overhead**: ~$10-30/month additional resource usage
- **Storage costs**: $0.10-0.30/GB/month depending on provider
- **Total monitoring cost**: $15-50/month for small-medium clusters

---

## Next Steps

Your monitoring stack is now providing comprehensive observability:
- ✅ Metrics collection from applications and infrastructure
- ✅ Visual dashboards for system health and performance
- ✅ Proactive alerting for issues before they impact users
- ✅ Historical data for trend analysis and capacity planning

**Continue your learning journey:**
- [Intermediate: Custom Applications](../02-intermediate/01-custom-applications.md): Deploy complex application patterns with monitoring
- [Architecture: System Design Principles](../../technical-course/01-architecture-fundamentals/01-system-design-principles.md): Learn production architecture patterns
- [Business: Infrastructure as Competitive Advantage](../../business/00-positioning/01-infrastructure-as-competitive-advantage.md): Understand business value of monitoring

**Advanced monitoring topics to explore:**
- Custom exporters for specialized metrics
- Log aggregation with Grafana Loki
- Distributed tracing with Jaeger or Zipkin
- Advanced PromQL queries and alerting rules
- Multi-cluster monitoring federation

Your infrastructure now provides enterprise-grade observability capabilities, enabling data-driven decision making and proactive issue resolution.