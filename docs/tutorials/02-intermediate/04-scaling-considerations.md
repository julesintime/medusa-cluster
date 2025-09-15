# Scaling Considerations - Design for Growth

**Design applications and infrastructure for horizontal and vertical scaling with intelligent autoscaling policies and cost optimization**

This tutorial guides you through implementing comprehensive scaling strategies that automatically adapt to demand while optimizing costs. You'll master the art of scaling applications efficiently using modern Kubernetes autoscaling technologies and proven patterns from high-scale production environments.

## What You'll Implement

- **Horizontal Pod Autoscaling (HPA)** with CPU, memory, and custom metrics
- **Vertical Pod Autoscaling (VPA)** for optimal resource allocation
- **KEDA event-driven autoscaling** for serverless-style scaling to zero
- **Cluster Autoscaling** for dynamic node management
- **Cost optimization strategies** with intelligent resource right-sizing
- **Performance testing frameworks** for validation
- **Multi-dimensional scaling policies** combining different triggers

**Time investment**: 60 minutes | **Result**: Production-ready autoscaling infrastructure

---

## Prerequisites Validation

Ensure you have completed previous intermediate tutorials and have monitoring infrastructure:

```bash
# Verify cluster and metrics
kubectl top nodes
kubectl top pods -A

# Check metrics server
kubectl get deployment metrics-server -n kube-system

# Verify monitoring stack
kubectl get pods -n monitoring | grep -E "(prometheus|grafana)"

# Check existing applications
kubectl get deployments -A
kubectl get hpa -A

# Expected: Metrics available and monitoring operational
```

**Required infrastructure:**
- Metrics Server deployed and operational
- Prometheus monitoring stack
- Applications with resource requests/limits configured
- Node pool with autoscaling capabilities

---

## Scaling Architecture Overview

### 2025 Kubernetes Autoscaling Landscape

```mermaid
graph TB
    subgraph "Application Layer"
        HPA[Horizontal Pod Autoscaler]
        VPA[Vertical Pod Autoscaler]
        KEDA[KEDA Event-Driven]
    end
    
    subgraph "Platform Layer"
        CA[Cluster Autoscaler]
        METRICS[Metrics Server]
        PROMETHEUS[Prometheus]
    end
    
    subgraph "Infrastructure Layer"
        NODES[Managed Node Groups]
        STORAGE[Persistent Volumes]
        NETWORK[Load Balancers]
    end
    
    HPA --> METRICS
    VPA --> METRICS
    KEDA --> PROMETHEUS
    CA --> NODES
    METRICS --> PROMETHEUS
    
    style HPA fill:#e1f5fe
    style VPA fill:#f3e5f5
    style KEDA fill:#fff3e0
    style CA fill:#f1f8e9
```

### Industry Statistics (2024-2025 Data)

**Cost Impact:**
- **32% of cloud costs are wasted** (Flexera 2024 State of Cloud Report)
- **75% of organizations** report increasing cloud waste
- **40-60% cost reduction** possible with proper autoscaling implementation
- **Average 3-5x overprovisioning** in manually scaled applications

**Performance Benefits:**
- **85% reduction in response time spikes** with proper HPA configuration
- **99.9% uptime achievement** through intelligent scaling policies
- **60% resource utilization improvement** with VPA optimization

---

## Pattern 1: Horizontal Pod Autoscaling (HPA)

### Basic HPA Configuration

**CPU and Memory-Based Autoscaling:**
```yaml
# Advanced HPA with CPU and memory targets
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  
  minReplicas: 2
  maxReplicas: 50
  
  # Multiple metrics for scaling decisions
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
  
  # Advanced scaling behavior (Kubernetes 1.18+)
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 5 minutes before scale down
      policies:
      - type: Percent
        value: 10                      # Scale down max 10% at a time
        periodSeconds: 60
      - type: Pods
        value: 2                       # Never scale down more than 2 pods at once
        periodSeconds: 60
      selectPolicy: Min                # Use most conservative policy
      
    scaleUp:
      stabilizationWindowSeconds: 60   # 1 minute before scale up
      policies:
      - type: Percent
        value: 50                      # Scale up max 50% at a time
        periodSeconds: 60
      - type: Pods
        value: 5                       # Never scale up more than 5 pods at once  
        periodSeconds: 60
      selectPolicy: Max                # Use most aggressive policy

---
# Deployment with proper resource configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2  # Initial replicas (will be managed by HPA)
  template:
    spec:
      containers:
      - name: webapp
        image: webapp:latest
        resources:
          requests:
            cpu: "250m"      # HPA uses these for percentage calculations
            memory: "512Mi"
          limits:
            cpu: "500m"      # Prevents resource contention
            memory: "1Gi"
        ports:
        - containerPort: 8080
        
        # Health checks for stable scaling
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Custom Metrics HPA

**External Metrics Integration:**
```yaml
# HPA with custom Prometheus metrics
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-custom-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 2
  maxReplicas: 100
  
  metrics:
  # Standard resource metrics
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
        
  # Custom application metric
  - type: Pods
    pods:
      metric:
        name: custom_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
        
  # External metric from load balancer
  - type: External
    external:
      metric:
        name: nginx_ingress_controller_requests_rate
        selector:
          matchLabels:
            ingress: webapp-ingress
      target:
        type: Value
        value: "1000"

---
# ServiceMonitor for custom metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: webapp-metrics
spec:
  selector:
    matchLabels:
      app: webapp
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

### Advanced HPA Implementation

**Queue-Based Scaling:**
```javascript
// Application code with custom metrics
const express = require('express');
const promClient = require('prom-client');
const app = express();

// Custom metrics for HPA
const register = new promClient.Registry();

const requestsPerSecond = new promClient.Gauge({
  name: 'custom_requests_per_second',
  help: 'Current requests per second',
  registers: [register]
});

const queueDepth = new promClient.Gauge({
  name: 'queue_depth',
  help: 'Current queue depth',
  registers: [register]
});

const activeConnections = new promClient.Gauge({
  name: 'active_connections',
  help: 'Current active connections',
  registers: [register]
});

// Track metrics with sliding window
let requestCount = 0;
let connectionCount = 0;
const metricsWindow = [];

setInterval(() => {
  // Calculate requests per second over last minute
  metricsWindow.push({ timestamp: Date.now(), requests: requestCount });
  metricsWindow.splice(0, metricsWindow.length - 60); // Keep last 60 seconds
  
  const rps = metricsWindow.length > 1 
    ? (requestCount - metricsWindow[0].requests) / 60
    : 0;
    
  requestsPerSecond.set(rps);
  activeConnections.set(connectionCount);
  
  // Reset counter
  requestCount = 0;
}, 1000);

// Middleware to track requests
app.use((req, res, next) => {
  requestCount++;
  connectionCount++;
  
  res.on('finish', () => {
    connectionCount--;
  });
  
  next();
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Queue processing simulation
class WorkQueue {
  constructor() {
    this.queue = [];
    this.processing = false;
  }
  
  addWork(workItem) {
    this.queue.push(workItem);
    queueDepth.set(this.queue.length);
    
    if (!this.processing) {
      this.processQueue();
    }
  }
  
  async processQueue() {
    this.processing = true;
    
    while (this.queue.length > 0) {
      const workItem = this.queue.shift();
      queueDepth.set(this.queue.length);
      
      try {
        await this.processItem(workItem);
      } catch (error) {
        console.error('Work processing failed:', error);
      }
    }
    
    this.processing = false;
  }
  
  async processItem(workItem) {
    // Simulate processing time based on queue depth
    const processingTime = Math.min(100 + (this.queue.length * 10), 1000);
    await new Promise(resolve => setTimeout(resolve, processingTime));
  }
}

const workQueue = new WorkQueue();
```

---

## Pattern 2: Vertical Pod Autoscaling (VPA)

### VPA Configuration and Implementation

**Recommendation and Update Modes:**
```yaml
# VPA for right-sizing recommendations
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  
  # VPA operation modes
  updatePolicy:
    updateMode: "Auto"  # Options: Off, Initial, Auto
    
  # Resource management policies
  resourcePolicy:
    containerPolicies:
    - containerName: webapp
      # Resource boundaries
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2000m
        memory: 4Gi
      # Control specific resources
      controlledResources:
      - cpu
      - memory
      # Scaling directions
      controlledValues: RequestsAndLimits

---
# Alternative: Recommendation-only mode for analysis
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa-recommendations
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  updatePolicy:
    updateMode: "Off"  # Only generate recommendations
```

### VPA Monitoring and Analysis

**Resource Usage Analysis Script:**
```bash
#!/bin/bash
# vpa-analysis.sh - Analyze VPA recommendations

set -e

NAMESPACE=${1:-default}
DEPLOYMENT=${2:-webapp}

echo "=== VPA Analysis for $DEPLOYMENT in $NAMESPACE ==="

# Get current resource requests/limits
echo "Current Resource Configuration:"
kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='
{range .spec.template.spec.containers[*]}
Container: {.name}
  Requests - CPU: {.resources.requests.cpu}, Memory: {.resources.requests.memory}
  Limits   - CPU: {.resources.limits.cpu}, Memory: {.resources.limits.memory}
{end}'

echo -e "\n=== VPA Recommendations ==="

# Get VPA recommendations
kubectl get vpa $DEPLOYMENT-vpa -n $NAMESPACE -o jsonpath='
{range .status.recommendation.containerRecommendations[*]}
Container: {.containerName}
  Target     - CPU: {.target.cpu}, Memory: {.target.memory}
  LowerBound - CPU: {.lowerBound.cpu}, Memory: {.lowerBound.memory}
  UpperBound - CPU: {.upperBound.cpu}, Memory: {.upperBound.memory}
{end}'

echo -e "\n=== Cost Impact Analysis ==="

# Calculate potential savings
CURRENT_CPU=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' | sed 's/m//')
CURRENT_MEM=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' | sed 's/Mi//')

RECOMMENDED_CPU=$(kubectl get vpa $DEPLOYMENT-vpa -n $NAMESPACE -o jsonpath='{.status.recommendation.containerRecommendations[0].target.cpu}' | sed 's/m//')
RECOMMENDED_MEM=$(kubectl get vpa $DEPLOYMENT-vpa -n $NAMESPACE -o jsonpath='{.status.recommendation.containerRecommendations[0].target.memory}' | sed 's/Mi//')

if [[ -n "$CURRENT_CPU" && -n "$RECOMMENDED_CPU" ]]; then
    CPU_DIFF=$((RECOMMENDED_CPU - CURRENT_CPU))
    MEM_DIFF=$((RECOMMENDED_MEM - CURRENT_MEM))
    
    echo "CPU Change: ${CPU_DIFF}m ($(( CPU_DIFF * 100 / CURRENT_CPU ))%)"
    echo "Memory Change: ${MEM_DIFF}Mi ($(( MEM_DIFF * 100 / CURRENT_MEM ))%)"
    
    # Rough cost calculation (adjust for your cloud provider)
    CPU_COST_MONTHLY=$(echo "scale=2; $CPU_DIFF * 0.031" | bc)  # ~$0.031 per CPU per month
    MEM_COST_MONTHLY=$(echo "scale=2; $MEM_DIFF * 0.004" | bc)  # ~$0.004 per MB per month
    
    echo "Estimated monthly cost impact: \$$(echo "$CPU_COST_MONTHLY + $MEM_COST_MONTHLY" | bc)"
fi
```

### VPA Integration with Deployment Automation

**GitOps-Friendly VPA Updates:**
```yaml
# VPA with webhook for GitOps integration
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa-gitops
  annotations:
    vpa.kubernetes.io/webhook-url: "https://gitops-webhook.company.com/vpa-recommendations"
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  updatePolicy:
    updateMode: "Off"  # Don't auto-update, send to GitOps
  resourcePolicy:
    containerPolicies:
    - containerName: webapp
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2000m
        memory: 4Gi
      # Only update requests to avoid changing limits automatically
      controlledValues: RequestsOnly
```

---

## Pattern 3: KEDA Event-Driven Autoscaling

### KEDA Installation and Configuration

**KEDA Deployment:**
```yaml
# KEDA installation via Helm
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: kedacore
  namespace: flux-system
spec:
  interval: 24h
  url: https://kedacore.github.io/charts

---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: keda
  namespace: flux-system
spec:
  releaseName: keda
  targetNamespace: keda
  interval: 30m
  chart:
    spec:
      chart: keda
      version: "2.12.x"
      sourceRef:
        kind: HelmRepository
        name: kedacore
  values:
    replicaCount: 2
    resources:
      operator:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 512Mi
      metricServer:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 256Mi
```

### Queue-Based Autoscaling with KEDA

**Redis Queue Scaling:**
```yaml
# KEDA ScaledObject for Redis queue
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: redis-queue-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: queue-processor
  
  # Scale to zero when no messages
  minReplicaCount: 0
  maxReplicaCount: 30
  
  # Cooldown periods
  cooldownPeriod: 300   # 5 minutes before scale to zero
  pollingInterval: 30   # Check every 30 seconds
  
  triggers:
  - type: redis
    metadata:
      address: redis.default.svc.cluster.local:6379
      listName: work_queue
      listLength: "10"  # Scale up when queue > 10 items
      # Authentication
      passwordFromEnv: REDIS_PASSWORD
    
  # Advanced scaling behavior
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 300
          policies:
          - type: Percent
            value: 25
            periodSeconds: 60
        scaleUp:
          stabilizationWindowSeconds: 60
          policies:
          - type: Percent
            value: 100
            periodSeconds: 30

---
# Queue processor deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: queue-processor
spec:
  replicas: 0  # KEDA will manage replicas
  template:
    spec:
      containers:
      - name: processor
        image: queue-processor:latest
        env:
        - name: REDIS_HOST
          value: redis.default.svc.cluster.local
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-auth
              key: password
        - name: QUEUE_NAME
          value: work_queue
        - name: BATCH_SIZE
          value: "5"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

### Multi-Trigger KEDA Configuration

**Complex Event-Driven Scaling:**
```yaml
# KEDA with multiple triggers
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: multi-trigger-scaler
spec:
  scaleTargetRef:
    name: event-processor
  minReplicaCount: 1
  maxReplicaCount: 50
  
  triggers:
  # Kafka message queue
  - type: kafka
    metadata:
      bootstrapServers: kafka.kafka.svc.cluster.local:9092
      consumerGroup: event-processor-group
      topic: user-events
      lagThreshold: "100"
    authenticationRef:
      name: kafka-auth
      
  # PostgreSQL connection count
  - type: postgresql
    metadata:
      connection: postgresql://username:password@postgres:5432/events?sslmode=disable
      query: "SELECT COUNT(*) FROM active_sessions WHERE created_at > NOW() - INTERVAL '5 minutes'"
      targetQueryValue: "20"
      
  # Custom Prometheus metric
  - type: prometheus
    metadata:
      serverAddress: http://prometheus.monitoring.svc.cluster.local:9090
      metricName: custom_processing_backlog
      query: sum(rate(events_received_total[2m])) - sum(rate(events_processed_total[2m]))
      threshold: "50"

---
# TriggerAuthentication for Kafka
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: kafka-auth
spec:
  secretTargetRef:
  - parameter: username
    name: kafka-credentials
    key: username
  - parameter: password
    name: kafka-credentials
    key: password
```

---

## Pattern 4: Cluster Autoscaling

### Node Pool Configuration

**Multi-Zone Cluster Autoscaler:**
```yaml
# Cluster Autoscaler deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: cluster-autoscaler
        image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.28.2
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws  # Adjust for your provider
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/k3s-cluster
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
        # Scaling parameters
        - --max-node-provision-time=15m
        - --max-empty-bulk-delete=10
        - --max-nodes-total=100
        - --cores-total=0:320
        - --memory-total=0:1280
        # Cost optimization
        - --scale-down-enabled=true
        - --scale-down-delay-after-add=10m
        - --scale-down-delay-after-delete=10s
        - --scale-down-delay-after-failure=3m
        - --scale-down-unneeded-time=10m
        - --scale-down-utilization-threshold=0.5
        resources:
          requests:
            cpu: 100m
            memory: 300Mi
          limits:
            cpu: 200m
            memory: 600Mi
```

### Node Affinity and Anti-Affinity

**Strategic Pod Placement:**
```yaml
# Deployment with node affinity for cost optimization
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cost-optimized-app
spec:
  template:
    spec:
      # Prefer spot instances for cost savings
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: node.kubernetes.io/instance-type
                operator: In
                values: ["spot", "preemptible"]
          - weight: 50
            preference:
              matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values: ["us-west-2a", "us-west-2b"]  # Cheaper zones
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: cost-optimized-app
              topologyKey: kubernetes.io/hostname
              
      # Tolerate spot instance interruptions
      tolerations:
      - key: node.kubernetes.io/unreliable
        operator: Exists
        effect: NoSchedule
      - key: spot-instance
        operator: Exists
        effect: NoSchedule
        
      containers:
      - name: app
        image: app:latest
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

---

## Cost Optimization Strategies

### Intelligent Resource Right-Sizing

**Automated Cost Analysis:**
```python
#!/usr/bin/env python3
"""
Kubernetes Cost Optimization Analysis Tool
Analyzes resource usage and provides right-sizing recommendations
"""

import json
import subprocess
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Tuple

class K8sCostOptimizer:
    def __init__(self):
        self.cost_per_cpu_hour = 0.031  # Approximate cost per CPU core per hour
        self.cost_per_gb_hour = 0.004   # Approximate cost per GB memory per hour
    
    def get_resource_usage(self, namespace: str = "default") -> Dict:
        """Get current resource usage from metrics server"""
        try:
            # Get pod metrics
            result = subprocess.run([
                "kubectl", "top", "pods", "-n", namespace, "--no-headers"
            ], capture_output=True, text=True, check=True)
            
            usage_data = {}
            for line in result.stdout.strip().split('\n'):
                if line:
                    parts = line.split()
                    pod_name = parts[0]
                    cpu_usage = parts[1].replace('m', '')
                    memory_usage = parts[2].replace('Mi', '').replace('Gi', '000')
                    
                    usage_data[pod_name] = {
                        'cpu_usage_millicores': int(cpu_usage),
                        'memory_usage_mb': int(memory_usage)
                    }
            
            return usage_data
            
        except subprocess.CalledProcessError as e:
            print(f"Error getting metrics: {e}")
            return {}
    
    def get_resource_requests(self, namespace: str = "default") -> Dict:
        """Get resource requests for deployments"""
        try:
            result = subprocess.run([
                "kubectl", "get", "deployments", "-n", namespace, "-o", "json"
            ], capture_output=True, text=True, check=True)
            
            deployments = json.loads(result.stdout)
            requests_data = {}
            
            for deployment in deployments['items']:
                name = deployment['metadata']['name']
                containers = deployment['spec']['template']['spec']['containers']
                
                total_cpu_request = 0
                total_memory_request = 0
                
                for container in containers:
                    resources = container.get('resources', {})
                    requests = resources.get('requests', {})
                    
                    cpu_request = requests.get('cpu', '0m')
                    if cpu_request.endswith('m'):
                        total_cpu_request += int(cpu_request[:-1])
                    else:
                        total_cpu_request += int(float(cpu_request) * 1000)
                    
                    memory_request = requests.get('memory', '0Mi')
                    if memory_request.endswith('Gi'):
                        total_memory_request += int(float(memory_request[:-2]) * 1024)
                    elif memory_request.endswith('Mi'):
                        total_memory_request += int(memory_request[:-2])
                
                requests_data[name] = {
                    'cpu_request_millicores': total_cpu_request,
                    'memory_request_mb': total_memory_request,
                    'replicas': deployment['spec']['replicas']
                }
            
            return requests_data
            
        except subprocess.CalledProcessError as e:
            print(f"Error getting deployments: {e}")
            return {}
    
    def calculate_right_sizing_recommendations(
        self, 
        usage_data: Dict, 
        requests_data: Dict
    ) -> List[Dict]:
        """Calculate right-sizing recommendations"""
        recommendations = []
        
        for deployment_name, deployment_info in requests_data.items():
            # Find matching pods
            matching_pods = [
                pod for pod in usage_data.keys() 
                if pod.startswith(deployment_name)
            ]
            
            if not matching_pods:
                continue
            
            # Calculate average usage across pods
            total_cpu_usage = sum(
                usage_data[pod]['cpu_usage_millicores'] 
                for pod in matching_pods
            )
            total_memory_usage = sum(
                usage_data[pod]['memory_usage_mb'] 
                for pod in matching_pods
            )
            
            avg_cpu_usage = total_cpu_usage / len(matching_pods)
            avg_memory_usage = total_memory_usage / len(matching_pods)
            
            # Add safety buffer (20% above average usage)
            recommended_cpu = int(avg_cpu_usage * 1.2)
            recommended_memory = int(avg_memory_usage * 1.2)
            
            # Ensure minimums
            recommended_cpu = max(recommended_cpu, 100)  # Minimum 100m
            recommended_memory = max(recommended_memory, 128)  # Minimum 128Mi
            
            # Calculate cost impact
            current_cpu = deployment_info['cpu_request_millicores']
            current_memory = deployment_info['memory_request_mb']
            replicas = deployment_info['replicas']
            
            cpu_savings_per_hour = (
                (current_cpu - recommended_cpu) / 1000 * 
                self.cost_per_cpu_hour * replicas
            )
            memory_savings_per_hour = (
                (current_memory - recommended_memory) / 1024 * 
                self.cost_per_gb_hour * replicas
            )
            
            total_savings_monthly = (
                (cpu_savings_per_hour + memory_savings_per_hour) * 24 * 30
            )
            
            recommendations.append({
                'deployment': deployment_name,
                'current_cpu_request': f"{current_cpu}m",
                'recommended_cpu_request': f"{recommended_cpu}m",
                'current_memory_request': f"{current_memory}Mi",
                'recommended_memory_request': f"{recommended_memory}Mi",
                'cpu_usage_avg': f"{int(avg_cpu_usage)}m",
                'memory_usage_avg': f"{int(avg_memory_usage)}Mi",
                'utilization_cpu': f"{avg_cpu_usage / current_cpu * 100:.1f}%",
                'utilization_memory': f"{avg_memory_usage / current_memory * 100:.1f}%",
                'monthly_savings_usd': round(total_savings_monthly, 2),
                'replicas': replicas
            })
        
        return sorted(recommendations, key=lambda x: x['monthly_savings_usd'], reverse=True)
    
    def generate_report(self, recommendations: List[Dict]) -> str:
        """Generate cost optimization report"""
        report = [
            "=== Kubernetes Cost Optimization Report ===",
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            ""
        ]
        
        total_savings = sum(r['monthly_savings_usd'] for r in recommendations)
        report.append(f"Total Potential Monthly Savings: ${total_savings:.2f}")
        report.append("")
        
        report.append("Top Optimization Opportunities:")
        report.append("-" * 80)
        
        for rec in recommendations[:10]:  # Top 10
            report.extend([
                f"Deployment: {rec['deployment']} (Replicas: {rec['replicas']})",
                f"  CPU: {rec['current_cpu_request']} → {rec['recommended_cpu_request']} "
                f"(Utilization: {rec['utilization_cpu']})",
                f"  Memory: {rec['current_memory_request']} → {rec['recommended_memory_request']} "
                f"(Utilization: {rec['utilization_memory']})",
                f"  Monthly Savings: ${rec['monthly_savings_usd']:.2f}",
                ""
            ])
        
        return "\n".join(report)

def main():
    if len(sys.argv) > 1:
        namespace = sys.argv[1]
    else:
        namespace = "default"
    
    optimizer = K8sCostOptimizer()
    
    print(f"Analyzing resource usage in namespace: {namespace}")
    
    usage_data = optimizer.get_resource_usage(namespace)
    requests_data = optimizer.get_resource_requests(namespace)
    
    if not usage_data or not requests_data:
        print("Unable to gather required metrics data")
        return
    
    recommendations = optimizer.calculate_right_sizing_recommendations(
        usage_data, requests_data
    )
    
    report = optimizer.generate_report(recommendations)
    print(report)

if __name__ == "__main__":
    main()
```

### Spot Instance Integration

**Spot-Aware Workload Configuration:**
```yaml
# Node pool for spot instances
apiVersion: v1
kind: ConfigMap
metadata:
  name: spot-instance-config
data:
  spot-config.yaml: |
    apiVersion: v1
    kind: Node
    metadata:
      labels:
        node.kubernetes.io/instance-type: "spot"
        cost-tier: "low"
        reliability: "preemptible"
      annotations:
        cluster-autoscaler/node-template/label/cost-tier: "low"
        cluster-autoscaler/node-template/taint/spot-instance: "true:NoSchedule"

---
# Workload optimized for spot instances
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spot-workload
spec:
  replicas: 10
  template:
    spec:
      # Tolerate spot instance taints
      tolerations:
      - key: spot-instance
        operator: Exists
        effect: NoSchedule
        
      # Prefer spot instances for cost optimization
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: cost-tier
                operator: In
                values: ["low"]
        
        # Distribute across zones for reliability
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: spot-workload
              topologyKey: topology.kubernetes.io/zone
      
      containers:
      - name: worker
        image: worker:latest
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
        
        # Graceful shutdown handling for spot interruptions
        lifecycle:
          preStop:
            exec:
              command:
              - /bin/sh
              - -c
              - |
                echo "Spot instance interruption detected, graceful shutdown..."
                # Drain work queue, save state, etc.
                sleep 30
```

---

## Performance Testing and Validation

### Load Testing Framework

**Artillery.js Performance Tests:**
```javascript
// performance/scaling-test.js
const Artillery = require('artillery/core');

const testConfig = {
  config: {
    target: process.env.TARGET_URL || 'https://webapp.yourdomain.com',
    phases: [
      { duration: 60, arrivalRate: 1, name: 'Warm up' },
      { duration: 300, arrivalRate: 5, rampTo: 50, name: 'Ramp up' },
      { duration: 600, arrivalRate: 50, name: 'Sustained load' },
      { duration: 300, arrivalRate: 50, rampTo: 100, name: 'Peak load' },
      { duration: 120, arrivalRate: 100, rampTo: 1, name: 'Cool down' }
    ],
    payload: {
      path: './test-data.csv',
      fields: ['userId', 'action']
    }
  },
  scenarios: [
    {
      name: 'API Load Test',
      weight: 70,
      flow: [
        {
          get: {
            url: '/',
            expect: [
              { statusCode: 200 },
              { contentType: 'application/json' }
            ]
          }
        },
        {
          post: {
            url: '/api/process',
            json: {
              userId: '{{ userId }}',
              action: '{{ action }}',
              timestamp: '{{ $timestamp }}'
            },
            expect: [
              { statusCode: [200, 201, 202] }
            ]
          }
        }
      ]
    },
    {
      name: 'Health Check',
      weight: 30,
      flow: [
        {
          get: {
            url: '/health',
            expect: [
              { statusCode: 200 },
              { hasProperty: 'status' }
            ]
          }
        }
      ]
    }
  ]
};

// Custom metrics collection
function collectMetrics() {
  return {
    'custom.response_time_p95': Artillery.util.metrics.percentile(95),
    'custom.response_time_p99': Artillery.util.metrics.percentile(99),
    'custom.error_rate': Artillery.util.metrics.rate('error')
  };
}

// Scaling validation
async function validateScaling() {
  const kubectl = require('child_process').execSync;
  
  // Get current pod count before test
  const initialPods = JSON.parse(
    kubectl('kubectl get pods -l app=webapp -o json').toString()
  ).items.length;
  
  console.log(`Initial pod count: ${initialPods}`);
  
  // Run load test
  const runner = Artillery.runner(testConfig);
  const report = await new Promise((resolve, reject) => {
    runner.run((err, report) => {
      if (err) reject(err);
      else resolve(report);
    });
  });
  
  // Check final pod count
  const finalPods = JSON.parse(
    kubectl('kubectl get pods -l app=webapp -o json').toString()
  ).items.length;
  
  console.log(`Final pod count: ${finalPods}`);
  console.log(`Scaling factor: ${finalPods / initialPods}x`);
  
  // Validate HPA metrics
  const hpaStatus = JSON.parse(
    kubectl('kubectl get hpa webapp-hpa -o json').toString()
  );
  
  console.log('HPA Status:', {
    currentReplicas: hpaStatus.status.currentReplicas,
    desiredReplicas: hpaStatus.status.desiredReplicas,
    currentCPU: hpaStatus.status.currentCPUUtilizationPercentage,
    targetCPU: hpaStatus.spec.targetCPUUtilizationPercentage
  });
  
  return {
    report,
    scaling: {
      initialPods,
      finalPods,
      scalingFactor: finalPods / initialPods
    }
  };
}

module.exports = { testConfig, validateScaling };
```

### Chaos Engineering for Scaling

**Scaling Resilience Testing:**
```yaml
# Chaos Monkey for scaling testing
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scaling-chaos-test
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: chaos-test
            image: alpine/curl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Generate load spike
              for i in $(seq 1 100); do
                curl -s -o /dev/null https://webapp.yourdomain.com/ &
              done
              wait
              
              # Wait for scaling
              sleep 300
              
              # Kill random pods to test scaling under failure
              kubectl delete pod -l app=webapp --field-selector=status.phase=Running --dry-run=client -o name | head -2 | xargs kubectl delete
              
              # Monitor recovery
              sleep 600
              
              # Validate scaling worked
              PODS=$(kubectl get pods -l app=webapp --field-selector=status.phase=Running --no-headers | wc -l)
              if [ $PODS -lt 2 ]; then
                echo "SCALING FAILURE: Only $PODS pods running"
                exit 1
              fi
              
              echo "Scaling test passed: $PODS pods healthy"
```

---

## Monitoring and Alerting

### Scaling-Specific Dashboards

**Grafana Dashboard Configuration:**
```json
{
  "dashboard": {
    "title": "Kubernetes Autoscaling Dashboard",
    "panels": [
      {
        "title": "HPA Scaling Events",
        "type": "graph",
        "targets": [
          {
            "expr": "kube_horizontalpodautoscaler_status_current_replicas",
            "legendFormat": "Current Replicas - {{ horizontalpodautoscaler }}"
          },
          {
            "expr": "kube_horizontalpodautoscaler_status_desired_replicas", 
            "legendFormat": "Desired Replicas - {{ horizontalpodautoscaler }}"
          },
          {
            "expr": "kube_horizontalpodautoscaler_spec_max_replicas",
            "legendFormat": "Max Replicas - {{ horizontalpodautoscaler }}"
          }
        ]
      },
      {
        "title": "Resource Utilization vs Targets",
        "type": "graph",
        "targets": [
          {
            "expr": "kube_horizontalpodautoscaler_status_current_cpu_utilization_percentage",
            "legendFormat": "Current CPU % - {{ horizontalpodautoscaler }}"
          },
          {
            "expr": "kube_horizontalpodautoscaler_spec_target_cpu_utilization_percentage",
            "legendFormat": "Target CPU % - {{ horizontalpodautoscaler }}"
          }
        ]
      },
      {
        "title": "KEDA Scaled Objects",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(keda_scaled_object_paused)",
            "legendFormat": "Paused"
          },
          {
            "expr": "sum(keda_scaled_object_errors)",
            "legendFormat": "Errors"
          }
        ]
      },
      {
        "title": "VPA Recommendations vs Current",
        "type": "table",
        "targets": [
          {
            "expr": "kube_verticalpodautoscaler_status_recommendation_containerrecommendations_target_cpu_millicores",
            "legendFormat": "VPA CPU Target"
          },
          {
            "expr": "kube_pod_container_resource_requests_cpu_cores * 1000",
            "legendFormat": "Current CPU Request"
          }
        ]
      }
    ]
  }
}
```

### Alert Rules for Scaling Issues

**Prometheus Alert Rules:**
```yaml
groups:
- name: autoscaling.rules
  rules:
  - alert: HPAMaxReplicasReached
    expr: |
      kube_horizontalpodautoscaler_status_current_replicas 
      >= kube_horizontalpodautoscaler_spec_max_replicas
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "HPA {{ $labels.horizontalpodautoscaler }} has reached max replicas"
      description: "{{ $labels.horizontalpodautoscaler }} in namespace {{ $labels.namespace }} has been at max replicas for 5 minutes"

  - alert: HPAScalingStuck
    expr: |
      (
        kube_horizontalpodautoscaler_status_desired_replicas 
        != kube_horizontalpodautoscaler_status_current_replicas
      ) and (
        changes(kube_horizontalpodautoscaler_status_current_replicas[10m]) == 0
      )
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: "HPA {{ $labels.horizontalpodautoscaler }} scaling is stuck"
      description: "Desired replicas ({{ $value }}) != current replicas for 10 minutes"

  - alert: KEDAScalerError
    expr: increase(keda_scaled_object_errors[5m]) > 0
    for: 0m
    labels:
      severity: critical
    annotations:
      summary: "KEDA scaler error for {{ $labels.scaledObject }}"
      description: "KEDA scaler {{ $labels.scaledObject }} has encountered errors"

  - alert: ClusterAutoscalerFailure
    expr: increase(cluster_autoscaler_errors_total[5m]) > 0
    for: 0m
    labels:
      severity: critical
    annotations:
      summary: "Cluster autoscaler errors detected"
      description: "Cluster autoscaler has encountered {{ $value }} errors in the last 5 minutes"

  - alert: HighResourceUtilization
    expr: |
      (
        sum(kube_pod_container_resource_requests_cpu_cores) by (node) 
        / sum(kube_node_status_capacity_cpu_cores) by (node)
      ) > 0.9
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High CPU utilization on node {{ $labels.node }}"
      description: "Node {{ $labels.node }} has {{ $value | humanizePercentage }} CPU utilization"

  - alert: PodResourceThrottling
    expr: rate(container_cpu_cfs_throttled_seconds_total[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ $labels.pod }} is being CPU throttled"
      description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is experiencing CPU throttling"
```

---

## Troubleshooting Scaling Issues

### Common Scaling Problems and Solutions

**HPA Not Scaling:**
```bash
#!/bin/bash
# hpa-troubleshoot.sh

HPA_NAME=${1:-webapp-hpa}
NAMESPACE=${2:-default}

echo "=== HPA Troubleshooting for $HPA_NAME ==="

# Check HPA status
echo "HPA Status:"
kubectl get hpa $HPA_NAME -n $NAMESPACE -o wide

echo -e "\nHPA Details:"
kubectl describe hpa $HPA_NAME -n $NAMESPACE

# Check metrics server
echo -e "\nMetrics Server Status:"
kubectl get deployment metrics-server -n kube-system

# Check target deployment
TARGET=$(kubectl get hpa $HPA_NAME -n $NAMESPACE -o jsonpath='{.spec.scaleTargetRef.name}')
echo -e "\nTarget Deployment: $TARGET"
kubectl get deployment $TARGET -n $NAMESPACE

# Check pod resource requests
echo -e "\nPod Resource Configuration:"
kubectl get deployment $TARGET -n $NAMESPACE -o jsonpath='
{range .spec.template.spec.containers[*]}
Container: {.name}
  CPU Request: {.resources.requests.cpu}
  Memory Request: {.resources.requests.memory}
{end}'

# Check current resource usage
echo -e "\nCurrent Resource Usage:"
kubectl top pods -l app=$TARGET -n $NAMESPACE

# Check HPA conditions
echo -e "\nHPA Conditions:"
kubectl get hpa $HPA_NAME -n $NAMESPACE -o jsonpath='
{range .status.conditions[*]}
Type: {.type}
Status: {.status}
Reason: {.reason}
Message: {.message}
{end}'

# Check events
echo -e "\nRecent Events:"
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$HPA_NAME --sort-by='.lastTimestamp'
```

**VPA Not Updating:**
```bash
#!/bin/bash
# vpa-troubleshoot.sh

VPA_NAME=${1:-webapp-vpa}
NAMESPACE=${2:-default}

echo "=== VPA Troubleshooting for $VPA_NAME ==="

# Check VPA status
echo "VPA Status:"
kubectl get vpa $VPA_NAME -n $NAMESPACE -o wide

# Check VPA recommendations
echo -e "\nVPA Recommendations:"
kubectl get vpa $VPA_NAME -n $NAMESPACE -o jsonpath='
{range .status.recommendation.containerRecommendations[*]}
Container: {.containerName}
  Target - CPU: {.target.cpu}, Memory: {.target.memory}
  Lower Bound - CPU: {.lowerBound.cpu}, Memory: {.lowerBound.memory}
  Upper Bound - CPU: {.upperBound.cpu}, Memory: {.upperBound.memory}
  Uncapped Target - CPU: {.uncappedTarget.cpu}, Memory: {.uncappedTarget.memory}
{end}'

# Check VPA controller logs
echo -e "\nVPA Controller Logs (last 20 lines):"
kubectl logs -n kube-system deployment/vpa-recommender --tail=20

# Check admission controller webhook
echo -e "\nVPA Admission Controller Status:"
kubectl get deployment vpa-admission-controller -n kube-system
kubectl get mutatingwebhookconfiguration vpa-webhook-config
```

---

## Next Steps

### Scaling Implementation Complete ✅

You now have:
- ✅ Comprehensive autoscaling strategies (HPA, VPA, KEDA, Cluster Autoscaler)
- ✅ Cost optimization frameworks and analysis tools
- ✅ Event-driven scaling with queue-based triggers
- ✅ Performance testing and validation procedures
- ✅ Production-ready monitoring and alerting
- ✅ Troubleshooting guides and automation tools

### What's Next

→ **[05-troubleshooting-guide.md](05-troubleshooting-guide.md)** - Master production troubleshooting techniques and operational procedures

### Advanced Topics

For enterprise scaling, explore:
- **Multi-cluster autoscaling**: Cross-region scaling strategies
- **Predictive scaling**: ML-based load prediction and preemptive scaling
- **FinOps integration**: Advanced cost allocation and optimization
- **Service mesh scaling**: Istio/Linkerd traffic-based autoscaling
- **GPU workload scaling**: Specialized scaling for ML/AI workloads

**Estimated time for next session**: 45 minutes to comprehensive troubleshooting mastery

---

*This scaling tutorial implements enterprise patterns used by high-growth technology companies. All configurations follow cloud-native best practices and provide a foundation for cost-effective, reliable scaling at any scale.*