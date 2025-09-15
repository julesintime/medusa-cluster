# First Application - GitOps Deployment Pipeline

**Deploy a production-ready application in 30 minutes using GitOps patterns and automatic CI/CD**

This guide walks you through deploying your first application to the K3s cluster using GitOps workflows. You'll learn the complete development-to-production pipeline, from local development to automated deployments triggered by git commits.

## What You'll Deploy

- **Node.js web application** with health checks and logging
- **Automated CI/CD pipeline** triggered by git push
- **LoadBalancer service** with external IP access
- **Ingress with SSL** and custom domain
- **Monitoring integration** with Prometheus metrics
- **Production-ready configuration** with resource limits and security context

**Time investment**: 30 minutes | **Result**: Complete GitOps deployment pipeline

---

## Prerequisites Validation

Ensure you have completed [Infrastructure Bootstrap](./02-infrastructure-bootstrap.md):

```bash
# Verify cluster is running
kubectl cluster-info
kubectl get nodes

# Verify Flux is operational
flux check
flux get kustomizations

# Verify infrastructure components
kubectl get pods -A | grep -E "(metallb|ingress|cert-manager|external-dns)"

# Expected: All pods should be Running
```

**Required**: Infrastructure must be healthy before proceeding.

---

## Application Development

### Create Application Repository

```bash
# Create new repository for your application
export GITHUB_USER=your-github-username
export APP_REPO=hello-gitops

# Create repository via GitHub CLI or web interface
gh repo create $APP_REPO --public --description "Hello GitOps Application"

# Clone the repository
git clone https://github.com/$GITHUB_USER/$APP_REPO.git
cd $APP_REPO
```

### Build Sample Application

Create a production-ready Node.js application:

**`package.json`**:
```json
{
  "name": "hello-gitops",
  "version": "1.0.0",
  "description": "GitOps deployment example application",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "jest",
    "lint": "eslint server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "express-prometheus-middleware": "^1.2.0",
    "prom-client": "^14.2.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.5.0",
    "eslint": "^8.0.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

**`server.js`**:
```javascript
const express = require('express');
const promClient = require('prom-client');

const app = express();
const port = process.env.PORT || 8080;

// Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status']
});

register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);

// Middleware for metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route?.path || req.path || 'unknown';
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode)
      .observe(duration);
      
    httpRequestsTotal
      .labels(req.method, route, res.statusCode)
      .inc();
  });
  
  next();
});

// Health check endpoints
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.APP_VERSION || '1.0.0'
  });
});

app.get('/ready', (req, res) => {
  // Add readiness checks (database connectivity, etc.)
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Application routes
app.get('/', (req, res) => {
  const hostname = require('os').hostname();
  const response = {
    message: 'Hello from GitOps!',
    hostname: hostname,
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  };
  
  console.log(`Request handled by pod: ${hostname}`);
  res.json(response);
});

app.get('/info', (req, res) => {
  res.json({
    application: 'hello-gitops',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
    uptime: process.uptime(),
    memoryUsage: process.memoryUsage(),
    cpuUsage: process.cpuUsage()
  });
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: 'Something went wrong!'
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  process.exit(0);
});

const server = app.listen(port, '0.0.0.0', () => {
  console.log(`Hello GitOps app listening on port ${port}`);
  console.log(`Health check: http://localhost:${port}/health`);
  console.log(`Metrics: http://localhost:${port}/metrics`);
});

module.exports = app;
```

### Create Production Dockerfile

**`Dockerfile`**:
```dockerfile
# Multi-stage build for security and size optimization
FROM node:18-alpine AS builder

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM node:18-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001

# Set working directory
WORKDIR /app

# Copy dependencies from builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy application code
COPY --chown=appuser:nodejs server.js package*.json ./

# Security: run as non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start application
CMD ["npm", "start"]
```

### Add Development Files

**`.dockerignore`**:
```
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.nyc_output
coverage
.nyc_output
*.md
```

**`.gitignore`**:
```
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
coverage/
.nyc_output/
```

### Local Testing

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Test health endpoints
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/metrics
curl http://localhost:8080/

# Test Docker build
docker build -t hello-gitops:local .
docker run -p 8080:8080 hello-gitops:local

# Test health check in container
curl http://localhost:8080/health
```

**Expected responses**: All endpoints should return JSON with appropriate data.

---

## CI/CD Pipeline Setup

### GitHub Actions Workflow

Create `.github/workflows/ci-cd.yml`:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linting
        run: npm run lint --if-present

      - name: Run tests
        run: npm test --if-present

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    
    permissions:
      contents: read
      packages: write

    outputs:
      image: ${{ steps.image.outputs.image }}
      digest: ${{ steps.build.outputs.digest }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}

      - name: Build and push Docker image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Output image
        id: image
        run: |
          echo "image=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          repository: ${{ github.repository_owner }}/k3s-gitops
          token: ${{ secrets.GITOPS_TOKEN }}
          path: gitops

      - name: Update image in GitOps repo
        run: |
          cd gitops
          
          # Update image in application deployment
          sed -i "s|image: .*|image: ${{ needs.build.outputs.image }}|g" \
            clusters/production/apps/hello-gitops/deployment.yaml
            
          # Commit changes
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add clusters/production/apps/hello-gitops/deployment.yaml
          git commit -m "Update hello-gitops image to ${{ needs.build.outputs.image }}"
          git push
```

### Create GitOps Token

```bash
# Create personal access token for GitOps repository updates
# Go to GitHub → Settings → Developer settings → Personal access tokens
# Create token with 'repo' scope for GitOps repository access

# Add token as repository secret
# Go to your application repository → Settings → Secrets and variables → Actions
# Add new secret: GITOPS_TOKEN with your token value
```

---

## Kubernetes Deployment Configuration

### Switch to GitOps Repository

```bash
# Switch to your GitOps repository
cd ../k3s-gitops

# Create application directory
mkdir -p clusters/production/apps/hello-gitops

# Create application configuration files
cd clusters/production/apps/hello-gitops
```

### Application Deployment

Create `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-gitops
  namespace: default
  labels:
    app: hello-gitops
    version: v1.0.0
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: hello-gitops
  template:
    metadata:
      labels:
        app: hello-gitops
        version: v1.0.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        
      containers:
      - name: hello-gitops
        image: ghcr.io/your-username/hello-gitops:main-abc123  # Updated by CI/CD
        imagePullPolicy: Always
        
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
          
        env:
        - name: NODE_ENV
          value: "production"
        - name: APP_VERSION
          value: "v1.0.0"
        - name: PORT
          value: "8080"
          
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
            
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1001
          capabilities:
            drop:
            - ALL
            
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
          
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
          
        startupProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30  # 5 minutes max startup time
          
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/.npm
          
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
        
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
```

### Service Configuration

Create `service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-gitops
  namespace: default
  labels:
    app: hello-gitops
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
spec:
  type: LoadBalancer
  loadBalancerIP: "192.168.1.101"  # Next available IP from MetalLB pool
  selector:
    app: hello-gitops
  ports:
  - name: http
    port: 80
    targetPort: http
    protocol: TCP
  sessionAffinity: None
```

### Ingress with SSL

Create `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-gitops
  namespace: default
  annotations:
    # NGINX Ingress annotations
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
    
    # Security headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-Frame-Options "DENY" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header Content-Security-Policy "default-src 'self'" always;
    
    # External DNS annotation
    external-dns.alpha.kubernetes.io/hostname: "hello.yourdomain.com"
    
    # Cert-manager annotation
    cert-manager.io/cluster-issuer: "letsencrypt-production"
    
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - hello.yourdomain.com
    secretName: hello-gitops-tls
  rules:
  - host: hello.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-gitops
            port:
              number: 80
```

### ConfigMap for Application Configuration

Create `configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hello-gitops-config
  namespace: default
  labels:
    app: hello-gitops
data:
  # Application configuration
  log-level: "info"
  metrics-enabled: "true"
  
  # Feature flags
  feature-metrics: "true"
  feature-health-checks: "true"
  
  # Environment-specific settings
  environment: "production"
  cluster-name: "k3s-production"
```

### ServiceMonitor for Prometheus

Create `servicemonitor.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hello-gitops
  namespace: default
  labels:
    app: hello-gitops
    release: prometheus
spec:
  selector:
    matchLabels:
      app: hello-gitops
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
  namespaceSelector:
    matchNames:
    - default
```

### Kustomization File

Create `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

resources:
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - configmap.yaml
  - servicemonitor.yaml

commonLabels:
  app: hello-gitops
  
images:
  - name: ghcr.io/your-username/hello-gitops
    newTag: main-abc123  # Updated by CI/CD pipeline

configMapGenerator:
  - name: hello-gitops-env
    literals:
      - NODE_ENV=production
      - APP_VERSION=v1.0.0
      - PORT=8080

replacements:
  - source:
      kind: ConfigMap
      name: hello-gitops-config
      fieldPath: data.environment
    targets:
      - select:
          kind: Deployment
          name: hello-gitops
        fieldPaths:
          - spec.template.spec.containers.[name=hello-gitops].env.[name=NODE_ENV].value
```

---

## Application Registration

### Add to GitOps Apps Kustomization

Edit `clusters/production/apps/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - hello-gitops  # Add your application
```

### Commit GitOps Configuration

```bash
# Add all application files
git add clusters/production/apps/hello-gitops/
git add clusters/production/apps/kustomization.yaml

# Commit the configuration
git commit -m "feat: add hello-gitops application

- Production-ready Node.js application with health checks
- LoadBalancer service with external IP 192.168.1.101  
- Ingress with SSL termination via Let's Encrypt
- Prometheus monitoring integration with ServiceMonitor
- Security context with non-root user and read-only filesystem
- Resource limits and probes for production stability

Application accessible at https://hello.yourdomain.com"

# Push to trigger Flux reconciliation
git push origin main
```

---

## Deploy Application Code

### Commit Application Code

```bash
# Switch back to application repository
cd ../hello-gitops

# Add all application files
git add .

# Commit the application
git commit -m "feat: initial hello-gitops application

- Node.js Express server with health endpoints
- Prometheus metrics integration
- Production-ready Docker configuration
- GitHub Actions CI/CD pipeline
- Comprehensive health checks and graceful shutdown
- Security hardening with non-root user

Ready for GitOps deployment to K3s cluster"

# Push to trigger CI/CD pipeline
git push origin main
```

### Monitor CI/CD Pipeline

```bash
# Watch GitHub Actions (or check in web interface)
gh run list --repo $GITHUB_USER/$APP_REPO

# Check specific run details
gh run view --repo $GITHUB_USER/$APP_REPO

# Expected stages:
# 1. test: Run linting and tests
# 2. build: Build and push Docker image to GHCR
# 3. deploy: Update GitOps repository with new image
```

---

## Monitor Deployment

### Watch Flux Reconciliation

```bash
# Monitor GitOps reconciliation
flux get kustomizations --watch

# Check application resources
kubectl get pods -l app=hello-gitops
kubectl get svc hello-gitops
kubectl get ingress hello-gitops

# Expected output shows:
# - 3 pods in Running state
# - Service with EXTERNAL-IP 192.168.1.101
# - Ingress with hello.yourdomain.com
```

### Verify Application Health

```bash
# Test load balancer access
curl -H "Host: hello.yourdomain.com" http://192.168.1.101/health

# Test external DNS (may take 1-5 minutes to propagate)
nslookup hello.yourdomain.com

# Test HTTPS access
curl https://hello.yourdomain.com/health

# Expected responses: JSON with health status
```

### Check Application Logs

```bash
# View application logs
kubectl logs -l app=hello-gitops -f

# Check metrics endpoint
curl https://hello.yourdomain.com/metrics

# Test application scaling
kubectl scale deployment hello-gitops --replicas=5
kubectl get pods -l app=hello-gitops
```

---

## Production Validation

### Load Testing

```bash
# Simple load test
for i in {1..100}; do
  curl -s https://hello.yourdomain.com/ > /dev/null &
done
wait

# Check application performance
kubectl top pods -l app=hello-gitops
```

### Monitoring Verification

```bash
# Verify Prometheus is scraping metrics
kubectl port-forward svc/prometheus-server 9090:80 &

# Open http://localhost:9090 and query:
# http_requests_total{job="hello-gitops"}
# http_request_duration_seconds{job="hello-gitops"}
```

### SSL Certificate Validation

```bash
# Check certificate details
echo | openssl s_client -servername hello.yourdomain.com -connect hello.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Verify certificate issuer
kubectl get certificate hello-gitops-tls -o yaml
kubectl describe certificaterequest
```

---

## GitOps Workflow Testing

### Update Application

**Edit `server.js`**:
```javascript
// Update the root endpoint
app.get('/', (req, res) => {
  const hostname = require('os').hostname();
  const response = {
    message: 'Hello from GitOps v2!',  // Changed message
    hostname: hostname,
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    gitops: 'automated deployment working!'  // New field
  };
  
  console.log(`Request handled by pod: ${hostname}`);
  res.json(response);
});
```

### Deploy Update

```bash
# Commit and push changes
git add server.js
git commit -m "feat: update application message for GitOps demo

- Changed welcome message to v2
- Added gitops confirmation field
- Demonstrates automated deployment pipeline"

git push origin main
```

### Monitor Automated Deployment

```bash
# Watch CI/CD pipeline
gh run list --repo $GITHUB_USER/$APP_REPO --limit 1

# Watch GitOps deployment
flux get kustomizations --watch

# Monitor rolling update
kubectl get pods -l app=hello-gitops --watch

# Test updated application
curl https://hello.yourdomain.com/ | jq .message
# Expected: "Hello from GitOps v2!"
```

---

## Troubleshooting Guide

### Pod Not Starting

```bash
# Check pod status and events
kubectl get pods -l app=hello-gitops
kubectl describe pod <pod-name>

# Check application logs
kubectl logs <pod-name> -c hello-gitops

# Common issues:
# - Image pull errors: Check GHCR access and image exists
# - Health check failures: Verify application starts correctly
# - Resource constraints: Check cluster resources with 'kubectl top nodes'
```

### Service Not Accessible

```bash
# Check service and endpoints
kubectl get svc hello-gitops
kubectl get endpoints hello-gitops

# Verify MetalLB IP assignment
kubectl get svc -A | grep LoadBalancer

# Test pod connectivity directly
kubectl port-forward deployment/hello-gitops 8080:8080 &
curl http://localhost:8080/health
```

### Ingress/SSL Issues

```bash
# Check ingress status
kubectl get ingress hello-gitops
kubectl describe ingress hello-gitops

# Verify certificate creation
kubectl get certificates
kubectl describe certificate hello-gitops-tls

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Test ACME challenge
kubectl get challenges
kubectl describe challenge <challenge-name>
```

### CI/CD Pipeline Failures

```bash
# Check GitHub Actions logs
gh run view --repo $GITHUB_USER/$APP_REPO <run-id>

# Common issues:
# - Docker build failures: Check Dockerfile syntax
# - Registry push failures: Verify GITHUB_TOKEN permissions
# - GitOps update failures: Check GITOPS_TOKEN permissions
```

### Flux Reconciliation Issues

```bash
# Check Flux status
flux get all
flux check

# Check GitOps repository access
flux get sources git
kubectl describe gitrepository flux-system -n flux-system

# Force reconciliation
flux reconcile kustomization apps --with-source
```

---

## Advanced Configuration

### Blue-Green Deployments

Add labels for deployment strategies:

```yaml
# In deployment.yaml
metadata:
  labels:
    app: hello-gitops
    version: blue  # or green
    deployment-strategy: blue-green
```

### Canary Deployments with Flagger

Create `canary.yaml`:

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: hello-gitops
  namespace: default
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hello-gitops
  progressDeadlineSeconds: 60
  service:
    port: 80
    targetPort: 8080
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      threshold: 99
      interval: 1m
    - name: request-duration
      threshold: 500
      interval: 1m
```

### Environment-Specific Configuration

Create overlays for different environments:

```bash
mkdir -p clusters/production/apps/hello-gitops/overlays/{staging,production}
```

**`overlays/staging/kustomization.yaml`**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
patches:
  - target:
      kind: Deployment
      name: hello-gitops
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
      - op: replace
        path: /spec/template/spec/containers/0/env/0/value
        value: "staging"
```

---

## Security Best Practices

### Network Policies

Create `networkpolicy.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: hello-gitops-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: hello-gitops
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53  # DNS
```

### Pod Security Standards

```yaml
# Add to deployment.yaml
spec:
  template:
    metadata:
      annotations:
        seccomp.security.alpha.kubernetes.io/pod: runtime/default
    spec:
      securityContext:
        seccompProfile:
          type: RuntimeDefault
```

---

## Cost Optimization

### Resource Right-Sizing

Monitor and adjust resource requests/limits:

```bash
# Monitor resource usage
kubectl top pods -l app=hello-gitops --containers

# Adjust resources in deployment.yaml based on actual usage
# Recommendation: requests = 75% of typical usage, limits = 125% of peak usage
```

### Horizontal Pod Autoscaling

Create `hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hello-gitops-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hello-gitops
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## Next Steps

### Application Deployed Successfully ✅

You now have:
- ✅ Complete GitOps deployment pipeline
- ✅ Automated CI/CD with GitHub Actions
- ✅ Production-ready application with monitoring
- ✅ HTTPS access with automatic SSL certificates
- ✅ Load balancing and health checks

### What's Next

→ **[04-domain-and-ssl.md](./04-domain-and-ssl.md)** - Configure custom domains and SSL certificates

### Advanced Topics

For production workloads, explore:
- **Multi-environment deployments**: Staging, production, and development
- **Advanced deployment strategies**: Blue-green, canary deployments with Flagger
- **Application secrets management**: Integrate with Infisical or external secret operators
- **Advanced monitoring**: Application-specific dashboards and alerting rules
- **Performance optimization**: Resource tuning, caching strategies, and CDN integration

**Estimated time for next session**: 15 minutes to custom domain setup

---

*This GitOps deployment tutorial demonstrates production-ready patterns used by teams at scale. All configurations follow cloud-native best practices and provide a foundation for any application deployment.*