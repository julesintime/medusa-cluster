# Kubernetes Essentials - From Containers to Production

**Understanding the fundamental building blocks that power modern cloud-native applications**

Kubernetes (K8s) orchestrates containerized applications across clusters of machines, but its power comes from understanding how its core components work together. This guide covers the essential concepts you need to deploy and manage applications effectively.

---

## Core Architecture - The Big Picture

### What Kubernetes Solves
**Traditional deployment challenges:**
- Manual server provisioning and configuration
- Application scaling requires infrastructure changes  
- Service discovery and load balancing complexity
- Rolling updates with zero-downtime difficulty
- Resource utilization inefficiency

**Kubernetes solutions:**
- **Declarative configuration**: Describe desired state, K8s maintains it
- **Automatic scheduling**: Optimal resource placement across cluster
- **Self-healing**: Automatic restart, replacement, and rescheduling
- **Service abstraction**: Built-in discovery and load balancing
- **Rolling deployments**: Zero-downtime updates and rollbacks

### Control Plane vs. Worker Nodes

#### Control Plane Components
- **API Server**: Central management hub, all communication goes through here
- **etcd**: Distributed key-value store for cluster state
- **Scheduler**: Assigns Pods to nodes based on resource requirements
- **Controller Manager**: Runs controllers that manage cluster state

#### Worker Node Components  
- **kubelet**: Node agent that manages Pods and containers
- **kube-proxy**: Network proxy maintaining network rules
- **Container Runtime**: Docker, containerd, or CRI-O for running containers

```bash
# View cluster architecture
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -n kube-system  # Control plane components
```

---

## Pods - The Fundamental Unit

### Understanding Pods
A **Pod** is the smallest deployable unit in Kubernetes - a wrapper around one or more containers that share:
- **Network namespace**: Same IP address and port space
- **Storage volumes**: Shared filesystem access
- **Lifecycle**: Created, scheduled, and terminated together

### Why Pods, Not Just Containers?
```yaml
# Real-world example: Web app with sidecar proxy
apiVersion: v1
kind: Pod
metadata:
  name: web-app-with-proxy
spec:
  containers:
  # Main application container
  - name: web-app
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  
  # Sidecar proxy container (shares network and storage)
  - name: log-proxy
    image: fluent/fluent-bit:latest
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
      readOnly: true
      
  volumes:
  - name: shared-logs
    emptyDir: {}
```

**Key insight**: Both containers share the same localhost (127.0.0.1) and can communicate via local ports.

### Pod Lifecycle Phases
- **Pending**: Pod accepted but containers not yet created
- **Running**: Pod bound to node, at least one container running
- **Succeeded**: All containers terminated successfully  
- **Failed**: All containers terminated, at least one failed
- **Unknown**: Pod state cannot be determined

### Practical Pod Management
```bash
# Create Pod from YAML
kubectl apply -f pod.yaml

# View Pod details
kubectl describe pod web-app-with-proxy
kubectl get pod web-app-with-proxy -o yaml

# Access Pod for debugging
kubectl exec -it web-app-with-proxy -c web-app -- /bin/bash

# Check Pod logs
kubectl logs web-app-with-proxy -c web-app -f

# Delete Pod
kubectl delete pod web-app-with-proxy
```

---

## Deployments - Production Pod Management

### Why Not Use Pods Directly?
**Problems with standalone Pods:**
- No automatic restart if Pod crashes
- No scaling capabilities  
- No rolling update mechanism
- Manual replacement when nodes fail

### Deployment Benefits
**Deployments provide:**
- **ReplicaSet management**: Maintains desired Pod count
- **Rolling updates**: Zero-downtime deployments
- **Rollback capability**: Return to previous versions
- **Declarative scaling**: Increase/decrease replicas easily

### Production Deployment Example
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3  # Desired number of Pods
  selector:
    matchLabels:
      app: nginx
  template:  # Pod template
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:  # Guaranteed resources
            memory: "64Mi"
            cpu: "250m"
          limits:    # Maximum resources
            memory: "128Mi" 
            cpu: "500m"
        livenessProbe:   # Health check
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:  # Ready to serve traffic
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Deployment Operations
```bash
# Deploy application
kubectl apply -f deployment.yaml

# Scale deployment
kubectl scale deployment nginx-deployment --replicas=5

# Rolling update (change image)
kubectl set image deployment/nginx-deployment nginx=nginx:1.22

# Check rollout status
kubectl rollout status deployment nginx-deployment

# View rollout history
kubectl rollout history deployment nginx-deployment

# Rollback to previous version
kubectl rollout undo deployment nginx-deployment

# Rollback to specific revision
kubectl rollout undo deployment nginx-deployment --to-revision=2
```

---

## Services - Network Abstraction

### The Service Discovery Problem
**Without Services:**
- Pod IPs change when Pods restart
- No load balancing across multiple Pod replicas
- Manual endpoint configuration required
- No service abstraction for external clients

### Service Types and Use Cases

#### ClusterIP (Default) - Internal Communication
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP  # Only accessible within cluster
  selector:
    app: nginx     # Matches Deployment label
  ports:
  - protocol: TCP
    port: 80       # Service port
    targetPort: 80 # Pod port
```

**Use case**: Database services, internal APIs, microservice communication

#### NodePort - External Access via Node IP
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080  # External access via <NodeIP>:30080
```

**Use case**: Development environments, simple external access

#### LoadBalancer - Cloud Provider Integration
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
# Cloud provider assigns external IP
```

**Use case**: Production external access with cloud load balancers

### Service Discovery and DNS
```bash
# Kubernetes automatically creates DNS entries:
# <service-name>.<namespace>.svc.cluster.local

# From within cluster, access service by name:
curl http://nginx-service/
curl http://nginx-service.default.svc.cluster.local/

# View service endpoints
kubectl get endpoints nginx-service
kubectl describe service nginx-service
```

---

## Ingress - HTTP/HTTPS Routing

### Why Ingress Over LoadBalancer Services?
**LoadBalancer limitations:**
- One LoadBalancer per service (expensive)
- No HTTP path-based routing
- No SSL termination features
- No virtual host support

**Ingress advantages:**
- Single entry point for multiple services
- HTTP(S) routing based on host/path  
- SSL termination and certificate management
- Cost-effective external access

### Production Ingress Configuration
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production-ingress
  annotations:
    # NGINX Ingress Controller specific
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # Cert-manager for automatic SSL
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    - api.example.com
    secretName: example-tls
  rules:
  # Frontend application
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
  # API service
  - host: api.example.com  
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

### Ingress Controller Setup
```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Verify installation
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx

# View ingress resources
kubectl get ingress
kubectl describe ingress production-ingress
```

---

## Namespaces - Multi-Tenancy and Organization

### Namespace Use Cases
- **Environment separation**: dev, staging, production
- **Team isolation**: frontend-team, backend-team, data-team
- **Resource quotas**: Limit CPU, memory, storage per team
- **Access control**: Role-based permissions per namespace

### Namespace Management
```yaml
# Create namespace
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: prod
    team: platform
---
# Resource quota for namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
    services: "10"
```

```bash
# Work with namespaces
kubectl create namespace development
kubectl get namespaces

# Deploy to specific namespace
kubectl apply -f deployment.yaml -n production

# Set default namespace for session
kubectl config set-context --current --namespace=production

# View resources across namespaces
kubectl get pods --all-namespaces
kubectl get services -A  # Short form
```

---

## ConfigMaps and Secrets - Configuration Management

### Separating Configuration from Code

#### ConfigMaps - Non-sensitive Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database_host: "postgres.example.com"
  database_port: "5432"
  log_level: "INFO"
  feature_flags: "new_ui:enabled,analytics:disabled"
  
  # File-based configuration
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
```

#### Secrets - Sensitive Data
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  # Base64 encoded values
  database_password: cGFzc3dvcmQxMjM=  # password123
  api_key: YWJjZGVmZ2hpams=  # abcdefghijk
  
# Or create from command line
# kubectl create secret generic app-secrets \
#   --from-literal=database_password=password123 \
#   --from-literal=api_key=abcdefghijk
```

### Using Configuration in Applications
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:latest
        
        # Environment variables from ConfigMap
        env:
        - name: DATABASE_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_host
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: log_level
              
        # Environment variables from Secret
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database_password
        
        # Mount entire ConfigMap as volume
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
          
        # Mount specific Secret files
        - name: secret-volume  
          mountPath: /etc/secrets
          readOnly: true
          
      volumes:
      - name: config-volume
        configMap:
          name: app-config
      - name: secret-volume
        secret:
          secretName: app-secrets
```

---

## Persistent Storage - Stateful Applications

### Storage Classes and Persistent Volumes

#### StorageClass - Dynamic Provisioning
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs  # Cloud provider specific
parameters:
  type: gp3
  fsType: ext4
allowVolumeExpansion: true
reclaimPolicy: Retain
```

#### PersistentVolumeClaim - Storage Request
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 20Gi
```

### Stateful Application Example
```yaml
apiVersion: apps/v1
kind: StatefulSet  # For stateful applications
metadata:
  name: postgres-db
spec:
  serviceName: postgres-service
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        ports:
        - containerPort: 5432
          
  # Volume claim template for StatefulSet
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 20Gi
```

---

## Resource Management and Health Checks

### Resource Requests and Limits
```yaml
containers:
- name: app
  image: myapp:latest
  resources:
    requests:  # Guaranteed resources (used for scheduling)
      memory: "256Mi"
      cpu: "200m"    # 0.2 CPU cores
    limits:    # Maximum allowed resources
      memory: "512Mi" 
      cpu: "500m"    # 0.5 CPU cores
```

**Understanding CPU units:**
- `100m` = 0.1 CPU cores  
- `1000m` = 1.0 CPU cores
- `2` = 2.0 CPU cores

### Health Check Probes
```yaml
containers:
- name: app
  image: myapp:latest
  
  # Is container ready to serve traffic?
  readinessProbe:
    httpGet:
      path: /health/ready
      port: 8080
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 1
    failureThreshold: 3
    
  # Is container still running properly?
  livenessProbe:
    httpGet:
      path: /health/live  
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
    
  # Has container fully started? (for slow-starting apps)
  startupProbe:
    httpGet:
      path: /health/startup
      port: 8080
    periodSeconds: 10
    failureThreshold: 30  # 5 minutes max startup time
```

---

## Production-Ready Application Pattern

Here's a complete example combining all concepts:

```yaml
# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: myapp-prod
---
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: myapp-prod
data:
  environment: "production"
  log_level: "warn"
  database_host: "postgres.myapp-prod.svc.cluster.local"
---
# Secret
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
  namespace: myapp-prod
type: Opaque
data:
  database_password: cGFzc3dvcmQxMjM=
  jwt_secret: c3VwZXJzZWNyZXQ=
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp-prod
  labels:
    app: myapp
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
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
        version: v1.0.0
    spec:
      containers:
      - name: app
        image: myregistry/myapp:v1.0.0
        ports:
        - containerPort: 8080
        env:
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: myapp-config
              key: environment
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: database_password
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: myapp-prod
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: myapp-prod
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

---

## Debugging and Troubleshooting

### Essential Debugging Commands
```bash
# Pod troubleshooting
kubectl describe pod <pod-name>
kubectl logs <pod-name> -f
kubectl exec -it <pod-name> -- /bin/bash

# Service discovery issues  
kubectl get endpoints <service-name>
kubectl describe service <service-name>

# Ingress troubleshooting
kubectl describe ingress <ingress-name>
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Resource usage
kubectl top nodes
kubectl top pods

# Events and cluster state
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl describe node <node-name>
```

### Common Issues and Solutions

#### Pod Stuck in Pending State
**Symptoms**: Pod never moves from Pending to Running
**Diagnosis**:
```bash
kubectl describe pod <pod-name>
# Check events section for scheduling issues
```
**Common causes**:
- Insufficient node resources
- No nodes matching nodeSelector/affinity rules  
- PersistentVolumeClaims not bound

#### Service Cannot Reach Pods
**Symptoms**: Service returns connection refused or timeouts
**Diagnosis**:
```bash
kubectl get endpoints <service-name>
# Should show Pod IPs if selector matches

kubectl describe service <service-name>  
# Verify selector and target ports
```
**Common causes**:
- Label selector doesn't match Pod labels
- Wrong targetPort in Service definition
- Pod not ready (readinessProbe failing)

#### Ingress Not Routing Traffic
**Symptoms**: External requests receive 404 or default backend
**Diagnosis**:
```bash
kubectl describe ingress <ingress-name>
# Check if addresses are assigned

kubectl get ingressclass
# Verify ingress controller is running
```
**Common causes**:
- No ingress controller installed
- Wrong ingressClassName specified
- DNS not pointing to ingress controller LoadBalancer IP

---

## Next Steps and Advanced Topics

### Immediate Applications
With these Kubernetes essentials, you can:
- **Deploy production applications** with proper resource management
- **Configure external access** via Services and Ingress
- **Manage application configuration** with ConfigMaps and Secrets
- **Implement basic monitoring** through health checks
- **Troubleshoot common issues** with debugging commands

### Advanced Kubernetes Topics
For deeper expertise, explore:
- **StatefulSets** for databases and persistent applications
- **DaemonSets** for node-level services (monitoring, logging)
- **Jobs and CronJobs** for batch processing
- **HorizontalPodAutoscaler** for automatic scaling
- **NetworkPolicies** for security and traffic isolation
- **Custom Resource Definitions (CRDs)** for extending Kubernetes
- **Operators** for complex application lifecycle management

### Production Considerations
- **Cluster monitoring** with Prometheus and Grafana
- **Log aggregation** with ELK stack or Loki
- **Backup strategies** for persistent data
- **Disaster recovery** and multi-cluster patterns
- **Security hardening** with Pod Security Standards
- **Cost optimization** through resource planning

Ready to apply these concepts in practice? Continue with [Getting Started Implementation Guide](../01-getting-started/README.md) to deploy your first production-ready application.

---

*This tutorial is based on official Kubernetes documentation and production deployment patterns. All examples are tested and validated for accuracy.*