# Custom Applications - Advanced Multi-Service Deployment Patterns

**Deploy complex applications with sidecar patterns, inter-service communication, and production-ready configurations**

Moving beyond simple single-container applications, this tutorial explores sophisticated deployment patterns used in production environments. You'll learn to orchestrate multiple containers, implement secure communication between services, and apply advanced Kubernetes features for resilient applications.

**Learning Objectives:**
- Deploy multi-container applications with sidecar patterns
- Implement secure inter-service communication and service discovery
- Configure advanced health checks and lifecycle management
- Apply resource optimization and Quality of Service (QoS) classes
- Implement security contexts and Pod Security Standards
- Design applications for high availability and fault tolerance

**Prerequisites:**
- Completed all getting-started tutorials including monitoring setup
- Understanding of microservices architecture concepts
- Familiarity with container networking and storage patterns
- Basic knowledge of security principles for containerized applications

**Time Estimate:** 60 minutes

---

## Understanding Multi-Service Application Patterns

### Common Multi-Container Patterns

**1. Sidecar Pattern**
- **Purpose**: Auxiliary functionality alongside main application
- **Examples**: Log shipping, metrics collection, proxy/mesh, backup agents
- **Benefits**: Separation of concerns, independent scaling, shared resources

**2. Ambassador Pattern**  
- **Purpose**: Proxy communication to external services
- **Examples**: Database connection pooling, API gateway, load balancing
- **Benefits**: Network abstraction, connection management, protocol translation

**3. Adapter Pattern**
- **Purpose**: Standardize interfaces between containers
- **Examples**: Metrics formatting, log normalization, API translation
- **Benefits**: Interface consistency, legacy integration, data transformation

### Architecture Overview

```mermaid
graph TB
    subgraph "Pod: E-commerce Application"
        A[Main App<br/>Node.js API] 
        B[Log Shipper<br/>Fluent Bit]
        C[Metrics Proxy<br/>Envoy]
        D[Cache Warmer<br/>Redis Client]
    end
    
    subgraph "Shared Resources"
        E[Config Volume]
        F[Log Volume] 
        G[TLS Certs]
    end
    
    subgraph "External Services"
        H[PostgreSQL]
        I[Redis Cache]
        J[Prometheus]
        K[Elasticsearch]
    end
    
    A -.->|reads| E
    A -.->|writes| F
    A -->|queries| H
    A -->|caches| I
    
    B -.->|reads| F
    B -->|ships| K
    
    C -->|scrapes| A
    C -->|exports| J
    
    D -->|warms| I
    D -.->|reads| E
```

---

## Real-World Application: E-commerce API with Sidecars

### 1. Main Application Container

First, let's create a comprehensive e-commerce API with multiple endpoints:

```bash
# Create namespace for our custom application
kubectl create namespace ecommerce

# Create the main application code
cat > ecommerce-app.js << 'EOF'
const express = require('express');
const promClient = require('prom-client');
const winston = require('winston');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const app = express();
const port = 3000;

// Prometheus metrics setup
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code', 'user_type'],
  registers: [register]
});

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route'],
  buckets: [0.001, 0.005, 0.015, 0.05, 0.1, 0.5, 1, 5],
  registers: [register]
});

const activeUsers = new promClient.Gauge({
  name: 'active_users_total',
  help: 'Number of active users',
  registers: [register]
});

const orderValue = new promClient.Histogram({
  name: 'order_value_dollars',
  help: 'Order value in dollars',
  labelNames: ['product_category'],
  buckets: [10, 25, 50, 100, 250, 500, 1000],
  registers: [register]
});

// Structured logging setup
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'ecommerce-api', version: '1.0.0' },
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ 
      filename: '/shared/logs/app.log',
      maxsize: 100 * 1024 * 1024, // 100MB
      maxFiles: 5
    })
  ]
});

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(limiter);
app.use(express.json({ limit: '10mb' }));

// Request tracking middleware
app.use((req, res, next) => {
  req.startTime = Date.now();
  req.requestId = Math.random().toString(36).substr(2, 9);
  
  // Add request context to logs
  req.logger = logger.child({ 
    requestId: req.requestId,
    method: req.method,
    path: req.path,
    userAgent: req.get('User-Agent')
  });
  
  res.on('finish', () => {
    const duration = (Date.now() - req.startTime) / 1000;
    const userType = req.headers['x-user-type'] || 'anonymous';
    
    httpRequestsTotal
      .labels(req.method, req.route?.path || req.path, res.statusCode, userType)
      .inc();
    
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path)
      .observe(duration);
      
    req.logger.info('Request completed', {
      statusCode: res.statusCode,
      duration,
      userType
    });
  });
  
  next();
});

// In-memory data store (replace with database in production)
let products = [
  { id: 1, name: 'Laptop', price: 999.99, category: 'electronics', stock: 50 },
  { id: 2, name: 'Book', price: 19.99, category: 'books', stock: 200 },
  { id: 3, name: 'Shirt', price: 29.99, category: 'clothing', stock: 100 }
];

let orders = [];
let users = new Map(); // Track active users for metrics

// API Routes
app.get('/', (req, res) => {
  res.json({
    service: 'E-commerce API',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    requestId: req.requestId
  });
});

app.get('/health', (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    requestId: req.requestId
  };
  
  res.status(200).json(health);
});

app.get('/ready', (req, res) => {
  // Simulate readiness checks (database connectivity, etc.)
  const ready = {
    status: 'ready',
    checks: {
      database: 'ok',
      cache: 'ok', 
      external_api: 'ok'
    },
    timestamp: new Date().toISOString(),
    requestId: req.requestId
  };
  
  res.status(200).json(ready);
});

// Products API
app.get('/api/products', (req, res) => {
  const { category, minPrice, maxPrice } = req.query;
  let filteredProducts = products;
  
  if (category) {
    filteredProducts = filteredProducts.filter(p => p.category === category);
  }
  
  if (minPrice) {
    filteredProducts = filteredProducts.filter(p => p.price >= parseFloat(minPrice));
  }
  
  if (maxPrice) {
    filteredProducts = filteredProducts.filter(p => p.price <= parseFloat(maxPrice));
  }
  
  req.logger.info('Products fetched', { 
    filters: { category, minPrice, maxPrice },
    resultCount: filteredProducts.length
  });
  
  res.json({
    products: filteredProducts,
    total: filteredProducts.length,
    requestId: req.requestId
  });
});

app.get('/api/products/:id', (req, res) => {
  const product = products.find(p => p.id === parseInt(req.params.id));
  
  if (!product) {
    req.logger.warn('Product not found', { productId: req.params.id });
    return res.status(404).json({ 
      error: 'Product not found',
      requestId: req.requestId
    });
  }
  
  res.json({
    product,
    requestId: req.requestId
  });
});

// Orders API
app.post('/api/orders', (req, res) => {
  const { userId, items } = req.body;
  
  if (!userId || !items || !Array.isArray(items)) {
    return res.status(400).json({ 
      error: 'Invalid order data',
      requestId: req.requestId
    });
  }
  
  // Calculate total and validate items
  let total = 0;
  const orderItems = [];
  
  for (const item of items) {
    const product = products.find(p => p.id === item.productId);
    if (!product) {
      return res.status(400).json({ 
        error: `Product ${item.productId} not found`,
        requestId: req.requestId
      });
    }
    
    if (product.stock < item.quantity) {
      return res.status(400).json({ 
        error: `Insufficient stock for product ${product.name}`,
        requestId: req.requestId
      });
    }
    
    const itemTotal = product.price * item.quantity;
    total += itemTotal;
    
    orderItems.push({
      productId: product.id,
      name: product.name,
      price: product.price,
      quantity: item.quantity,
      total: itemTotal
    });
    
    // Update stock
    product.stock -= item.quantity;
  }
  
  const order = {
    id: orders.length + 1,
    userId,
    items: orderItems,
    total,
    status: 'confirmed',
    createdAt: new Date().toISOString(),
    requestId: req.requestId
  };
  
  orders.push(order);
  
  // Record metrics
  orderItems.forEach(item => {
    const product = products.find(p => p.id === item.productId);
    orderValue.labels(product.category).observe(item.total);
  });
  
  req.logger.info('Order created', { 
    orderId: order.id,
    userId,
    total,
    itemCount: orderItems.length
  });
  
  res.status(201).json(order);
});

app.get('/api/orders/:id', (req, res) => {
  const order = orders.find(o => o.id === parseInt(req.params.id));
  
  if (!order) {
    return res.status(404).json({ 
      error: 'Order not found',
      requestId: req.requestId
    });
  }
  
  res.json(order);
});

// User session tracking
app.post('/api/users/:id/session', (req, res) => {
  const userId = req.params.id;
  users.set(userId, Date.now());
  activeUsers.set(users.size);
  
  req.logger.info('User session started', { userId });
  
  res.json({ 
    message: 'Session started',
    userId,
    requestId: req.requestId
  });
});

app.delete('/api/users/:id/session', (req, res) => {
  const userId = req.params.id;
  users.delete(userId);
  activeUsers.set(users.size);
  
  req.logger.info('User session ended', { userId });
  
  res.json({ 
    message: 'Session ended',
    userId,
    requestId: req.requestId
  });
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
  
  // Force exit after 30 seconds
  setTimeout(() => {
    logger.error('Forced exit after timeout');
    process.exit(1);
  }, 30000);
});

const server = app.listen(port, '0.0.0.0', () => {
  logger.info('E-commerce API started', { port });
});
EOF

# Create package.json for the application
cat > package.json << 'EOF'
{
  "name": "ecommerce-api",
  "version": "1.0.0",
  "description": "E-commerce API with sidecar patterns",
  "main": "ecommerce-app.js",
  "scripts": {
    "start": "node ecommerce-app.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "prom-client": "^15.1.0",
    "winston": "^3.8.0",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF
```

### 2. Log Shipping Sidecar with Fluent Bit

```bash
# Create Fluent Bit configuration for log parsing and shipping
cat > fluent-bit.conf << 'EOF'
[SERVICE]
    Flush         1
    Log_Level     info
    Daemon        off
    Parsers_File  parsers.conf

[INPUT]
    Name              tail
    Path              /shared/logs/*.log
    Parser            json
    Tag               app.*
    Refresh_Interval  5
    Mem_Buf_Limit     50MB

[FILTER]
    Name                kubernetes
    Match               app.*
    Kube_URL            https://kubernetes.default.svc:443
    Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
    Merge_Log           On
    Keep_Log            Off
    K8S-Logging.Parser  On
    K8S-Logging.Exclude On

[FILTER]
    Name    modify
    Match   app.*
    Add     cluster_name k3s-cluster
    Add     environment production

[OUTPUT]
    Name  stdout
    Match app.*
    Format json_lines

# For production, replace stdout with your log destination:
# [OUTPUT]
#     Name  es
#     Match app.*
#     Host  elasticsearch.logging.svc.cluster.local
#     Port  9200
#     Index ecommerce-logs
#     Type  _doc
EOF

# Create Fluent Bit parsers configuration
cat > parsers.conf << 'EOF'
[PARSER]
    Name        json
    Format      json
    Time_Key    timestamp
    Time_Format %Y-%m-%dT%H:%M:%S.%LZ
    Time_Keep   On
EOF
```

### 3. Metrics Collection Sidecar with Envoy Proxy

```bash
# Create Envoy configuration for metrics collection and proxying
cat > envoy.yaml << 'EOF'
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        protocol: TCP
        address: 0.0.0.0
        port_value: 8080
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          access_log:
          - name: envoy.access_loggers.stdout
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
              log_format:
                json_format:
                  timestamp: "%START_TIME%"
                  method: "%REQ(:METHOD)%"
                  path: "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%"
                  status: "%RESPONSE_CODE%"
                  duration: "%DURATION%"
                  bytes_sent: "%BYTES_SENT%"
                  bytes_received: "%BYTES_RECEIVED%"
                  user_agent: "%REQ(USER-AGENT)%"
                  x_forwarded_for: "%REQ(X-FORWARDED-FOR)%"
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  cluster: local_app
                  timeout: 30s
              - match:
                  prefix: "/stats/prometheus"
                route:
                  cluster: admin
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

  clusters:
  - name: local_app
    connect_timeout: 0.25s
    type: STATIC
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: local_app
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1
                port_value: 3000

  - name: admin
    connect_timeout: 0.25s
    type: STATIC
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: admin
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 127.0.0.1
                port_value: 9901

admin:
  address:
    socket_address:
      protocol: TCP
      address: 0.0.0.0
      port_value: 9901

stats_config:
  stats_tags:
  - tag_name: cluster_name
    regex: "^cluster\\.((.+?)\\.).*"
  - tag_name: virtual_host_name
    regex: "^vhost\\.((.+?)\\.).*"
EOF
```

### 4. Multi-Container Deployment Configuration

```bash
# Create comprehensive multi-container deployment
cat > ecommerce-deployment.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: ecommerce-app-config
  namespace: ecommerce
data:
  DATABASE_URL: "postgresql://user:password@postgres.ecommerce.svc.cluster.local:5432/ecommerce"
  REDIS_URL: "redis://redis.ecommerce.svc.cluster.local:6379"
  LOG_LEVEL: "info"
  NODE_ENV: "production"
  API_VERSION: "v1.0.0"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: ecommerce
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf

    [INPUT]
        Name              tail
        Path              /shared/logs/*.log
        Parser            json
        Tag               app.*
        Refresh_Interval  5
        Mem_Buf_Limit     50MB

    [FILTER]
        Name                kubernetes
        Match               app.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        Keep_Log            Off

    [FILTER]
        Name    modify
        Match   app.*
        Add     cluster_name k3s-cluster
        Add     environment production

    [OUTPUT]
        Name  stdout
        Match app.*
        Format json_lines

  parsers.conf: |
    [PARSER]
        Name        json
        Format      json
        Time_Key    timestamp
        Time_Format %Y-%m-%dT%H:%M:%S.%LZ
        Time_Keep   On
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: envoy-config
  namespace: ecommerce
data:
  envoy.yaml: |
    static_resources:
      listeners:
      - name: listener_0
        address:
          socket_address:
            protocol: TCP
            address: 0.0.0.0
            port_value: 8080
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: ingress_http
              access_log:
              - name: envoy.access_loggers.stdout
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/"
                    route:
                      cluster: local_app
                      timeout: 30s
              http_filters:
              - name: envoy.filters.http.router

      clusters:
      - name: local_app
        connect_timeout: 0.25s
        type: STATIC
        lb_policy: ROUND_ROBIN
        load_assignment:
          cluster_name: local_app
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: 127.0.0.1
                    port_value: 3000

    admin:
      address:
        socket_address:
          protocol: TCP
          address: 0.0.0.0
          port_value: 9901
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecommerce-app
  namespace: ecommerce
  labels:
    app: ecommerce-app
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
      app: ecommerce-app
  template:
    metadata:
      labels:
        app: ecommerce-app
        version: v1.0.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
        # Annotations for log parsing
        fluentbit.io/parser: "json"
        fluentbit.io/exclude: "false"
    spec:
      # Security Context for the entire pod
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      
      # Service account for Kubernetes API access (if needed)
      serviceAccountName: ecommerce-app
      
      # Pod anti-affinity for high availability
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - ecommerce-app
              topologyKey: kubernetes.io/hostname
      
      # Init container for setup tasks
      initContainers:
      - name: setup-logs
        image: alpine:3.18
        command: ['sh', '-c']
        args:
          - |
            mkdir -p /shared/logs
            touch /shared/logs/app.log
            chown -R 1000:3000 /shared/logs
            chmod -R 755 /shared/logs
        volumeMounts:
        - name: shared-logs
          mountPath: /shared/logs
        securityContext:
          runAsUser: 0  # Needed for initial setup
          runAsNonRoot: false
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
      
      containers:
      # Main application container
      - name: ecommerce-api
        image: node:18-alpine
        ports:
        - containerPort: 3000
          name: http
          protocol: TCP
        command: ["/bin/sh"]
        args:
          - -c
          - |
            set -e
            echo "Installing dependencies..."
            npm install express prom-client winston helmet express-rate-limit
            echo "Starting application..."
            exec node /app/ecommerce-app.js
        
        env:
        - name: NODE_ENV
          value: "production"
        - name: PORT
          value: "3000"
        - name: LOG_LEVEL
          value: "info"
        
        envFrom:
        - configMapRef:
            name: ecommerce-app-config
        
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
            ephemeral-storage: "1Gi"
          limits:
            memory: "512Mi"
            cpu: "500m"
            ephemeral-storage: "2Gi"
        
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        
        volumeMounts:
        - name: app-code
          mountPath: /app
        - name: shared-logs
          mountPath: /shared/logs
        - name: tmp-volume
          mountPath: /tmp
        - name: npm-cache
          mountPath: /.npm
        
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
          successThreshold: 1
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
          successThreshold: 1
        
        startupProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 12
          successThreshold: 1
      
      # Log shipping sidecar
      - name: log-shipper
        image: fluent/fluent-bit:2.2.0
        ports:
        - containerPort: 2020
          name: fluent-bit
          protocol: TCP
        
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        
        volumeMounts:
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc
        - name: shared-logs
          mountPath: /shared/logs
          readOnly: true
        - name: fluent-bit-tmp
          mountPath: /tmp
        
        livenessProbe:
          httpGet:
            path: /
            port: 2020
          initialDelaySeconds: 30
          periodSeconds: 30
        
        readinessProbe:
          httpGet:
            path: /api/v1/health
            port: 2020
          initialDelaySeconds: 5
          periodSeconds: 10
      
      # Envoy proxy sidecar for metrics and routing
      - name: envoy-proxy
        image: envoyproxy/envoy:v1.28.0
        ports:
        - containerPort: 8080
          name: proxy
          protocol: TCP
        - containerPort: 9901
          name: admin
          protocol: TCP
        
        command: ["envoy"]
        args:
          - "-c"
          - "/etc/envoy/envoy.yaml"
          - "--log-level"
          - "info"
          - "--log-format"
          - "[%Y-%m-%d %T.%e][%t][%l][%n] %v"
        
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        
        volumeMounts:
        - name: envoy-config
          mountPath: /etc/envoy
        - name: envoy-tmp
          mountPath: /tmp
        
        livenessProbe:
          httpGet:
            path: /server_info
            port: 9901
          initialDelaySeconds: 30
          periodSeconds: 30
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 9901
          initialDelaySeconds: 5
          periodSeconds: 10
      
      # Cache warming sidecar
      - name: cache-warmer
        image: redis:7-alpine
        command: ['sh', '-c']
        args:
          - |
            echo "Cache warmer starting..."
            while true; do
              echo "Warming cache..."
              # Simulate cache warming operations
              redis-cli -h redis.ecommerce.svc.cluster.local PING > /dev/null 2>&1 || echo "Redis not available"
              sleep 300  # Warm cache every 5 minutes
            done
        
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
        
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
      
      volumes:
      - name: app-code
        configMap:
          name: ecommerce-app-code
          defaultMode: 0755
      - name: shared-logs
        emptyDir:
          sizeLimit: 1Gi
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
      - name: envoy-config
        configMap:
          name: envoy-config
      - name: tmp-volume
        emptyDir:
          sizeLimit: 100Mi
      - name: npm-cache
        emptyDir:
          sizeLimit: 200Mi
      - name: fluent-bit-tmp
        emptyDir:
          sizeLimit: 50Mi
      - name: envoy-tmp
        emptyDir:
          sizeLimit: 50Mi
      
      # Graceful termination settings
      terminationGracePeriodSeconds: 60
      
      # DNS policy for service discovery
      dnsPolicy: ClusterFirst
      
      # Restart policy
      restartPolicy: Always
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ecommerce-app-code
  namespace: ecommerce
data:
  ecommerce-app.js: |
    const express = require('express');
    const promClient = require('prom-client');
    const winston = require('winston');
    const helmet = require('helmet');
    const rateLimit = require('express-rate-limit');

    const app = express();
    const port = 3000;

    // Prometheus metrics setup
    const register = new promClient.Registry();
    promClient.collectDefaultMetrics({ register });

    const httpRequestsTotal = new promClient.Counter({
      name: 'http_requests_total',
      help: 'Total HTTP requests',
      labelNames: ['method', 'route', 'status_code', 'user_type'],
      registers: [register]
    });

    const httpRequestDuration = new promClient.Histogram({
      name: 'http_request_duration_seconds',
      help: 'HTTP request duration',
      labelNames: ['method', 'route'],
      buckets: [0.001, 0.005, 0.015, 0.05, 0.1, 0.5, 1, 5],
      registers: [register]
    });

    const activeUsers = new promClient.Gauge({
      name: 'active_users_total',
      help: 'Number of active users',
      registers: [register]
    });

    // Structured logging setup
    const logger = winston.createLogger({
      level: 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
      ),
      defaultMeta: { service: 'ecommerce-api', version: '1.0.0' },
      transports: [
        new winston.transports.Console(),
        new winston.transports.File({ filename: '/shared/logs/app.log' })
      ]
    });

    // Security middleware
    app.use(helmet());
    app.use(express.json({ limit: '10mb' }));

    // Request tracking
    app.use((req, res, next) => {
      req.startTime = Date.now();
      req.requestId = Math.random().toString(36).substr(2, 9);
      
      req.logger = logger.child({ 
        requestId: req.requestId,
        method: req.method,
        path: req.path
      });
      
      res.on('finish', () => {
        const duration = (Date.now() - req.startTime) / 1000;
        const userType = req.headers['x-user-type'] || 'anonymous';
        
        httpRequestsTotal
          .labels(req.method, req.route?.path || req.path, res.statusCode, userType)
          .inc();
        
        httpRequestDuration
          .labels(req.method, req.route?.path || req.path)
          .observe(duration);
          
        req.logger.info('Request completed', {
          statusCode: res.statusCode,
          duration,
          userType
        });
      });
      
      next();
    });

    // In-memory data store
    let products = [
      { id: 1, name: 'Laptop', price: 999.99, category: 'electronics', stock: 50 },
      { id: 2, name: 'Book', price: 19.99, category: 'books', stock: 200 },
      { id: 3, name: 'Shirt', price: 29.99, category: 'clothing', stock: 100 }
    ];

    let orders = [];
    let users = new Map();

    // API Routes
    app.get('/', (req, res) => {
      res.json({
        service: 'E-commerce API',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        requestId: req.requestId
      });
    });

    app.get('/health', (req, res) => {
      res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        requestId: req.requestId
      });
    });

    app.get('/ready', (req, res) => {
      res.status(200).json({
        status: 'ready',
        checks: {
          database: 'ok',
          cache: 'ok', 
          external_api: 'ok'
        },
        timestamp: new Date().toISOString(),
        requestId: req.requestId
      });
    });

    app.get('/api/products', (req, res) => {
      const { category } = req.query;
      let filteredProducts = products;
      
      if (category) {
        filteredProducts = filteredProducts.filter(p => p.category === category);
      }
      
      req.logger.info('Products fetched', { 
        filters: { category },
        resultCount: filteredProducts.length
      });
      
      res.json({
        products: filteredProducts,
        total: filteredProducts.length,
        requestId: req.requestId
      });
    });

    app.post('/api/orders', (req, res) => {
      const { userId, items } = req.body;
      
      if (!userId || !items || !Array.isArray(items)) {
        return res.status(400).json({ 
          error: 'Invalid order data',
          requestId: req.requestId
        });
      }
      
      const order = {
        id: orders.length + 1,
        userId,
        items,
        total: items.reduce((sum, item) => {
          const product = products.find(p => p.id === item.productId);
          return sum + (product ? product.price * item.quantity : 0);
        }, 0),
        status: 'confirmed',
        createdAt: new Date().toISOString(),
        requestId: req.requestId
      };
      
      orders.push(order);
      
      req.logger.info('Order created', { 
        orderId: order.id,
        userId,
        total: order.total
      });
      
      res.status(201).json(order);
    });

    app.get('/metrics', async (req, res) => {
      res.set('Content-Type', register.contentType);
      res.end(await register.metrics());
    });

    const server = app.listen(port, '0.0.0.0', () => {
      logger.info('E-commerce API started', { port });
    });

    process.on('SIGTERM', () => {
      logger.info('SIGTERM received, shutting down gracefully');
      server.close(() => {
        logger.info('Process terminated');
        process.exit(0);
      });
    });
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ecommerce-app
  namespace: ecommerce
automountServiceAccountToken: true
---
apiVersion: v1
kind: Service
metadata:
  name: ecommerce-app-service
  namespace: ecommerce
  labels:
    app: ecommerce-app
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "3000"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: ecommerce-app
  ports:
    - name: http
      port: 80
      targetPort: 3000
      protocol: TCP
    - name: proxy
      port: 8080
      targetPort: 8080
      protocol: TCP
    - name: envoy-admin
      port: 9901
      targetPort: 9901
      protocol: TCP
  type: ClusterIP
EOF

# Apply the deployment
kubectl apply -f ecommerce-deployment.yaml

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=300s deployment/ecommerce-app -n ecommerce

# Verify pods are running
kubectl get pods -n ecommerce
kubectl describe pod -l app=ecommerce-app -n ecommerce
```

### 5. External Access Configuration

```bash
# Create Ingress for external access
cat > ecommerce-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-app-ingress
  namespace: ecommerce
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "ecommerce-api.example.com"  # Replace with your domain
    cert-manager.io/cluster-issuer: "letsencrypt-production"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    
    # Security headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: DENY";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload";
    
    # Rate limiting
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/limit-connections: "50"
    
    # Request size
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/client-max-body-size: "10m"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ecommerce-api.example.com  # Replace with your domain
    secretName: ecommerce-api-tls
  rules:
  - host: ecommerce-api.example.com  # Replace with your domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ecommerce-app-service
            port:
              number: 80
      - path: /proxy
        pathType: Prefix
        backend:
          service:
            name: ecommerce-app-service
            port:
              number: 8080
EOF

kubectl apply -f ecommerce-ingress.yaml
```

---

## Monitoring and ServiceMonitor Configuration

### Create ServiceMonitor for Prometheus

```bash
# Create ServiceMonitor for application metrics
cat > ecommerce-servicemonitor.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ecommerce-app
  namespace: ecommerce
  labels:
    app: ecommerce-app
    release: prometheus-stack
spec:
  selector:
    matchLabels:
      app: ecommerce-app
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
    honorLabels: true
    scrapeTimeout: 10s
  - port: envoy-admin
    interval: 30s
    path: /stats/prometheus
    honorLabels: true
    scrapeTimeout: 10s
    metricRelabelings:
    - sourceLabels: [__name__]
      regex: 'envoy_.*'
      targetLabel: container
      replacement: 'envoy-proxy'
  namespaceSelector:
    matchNames:
    - ecommerce
EOF

kubectl apply -f ecommerce-servicemonitor.yaml
```

---

## Testing and Validation

### 1. Basic Functionality Tests

```bash
# Test application endpoints
kubectl port-forward svc/ecommerce-app-service 8080:80 -n ecommerce &

# Health checks
curl -s http://localhost:8080/health | jq
curl -s http://localhost:8080/ready | jq

# Products API
curl -s http://localhost:8080/api/products | jq
curl -s http://localhost:8080/api/products?category=electronics | jq

# Create an order
curl -s -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -H "X-User-Type: premium" \
  -d '{
    "userId": "user123",
    "items": [
      {"productId": 1, "quantity": 1},
      {"productId": 2, "quantity": 2}
    ]
  }' | jq

# Check metrics endpoint
curl -s http://localhost:8080/metrics | grep http_requests_total

kill %1  # Stop port-forward
```

### 2. Multi-Container Communication Tests

```bash
# Test Envoy proxy
kubectl port-forward svc/ecommerce-app-service 8081:8080 -n ecommerce &

# Access app through Envoy proxy
curl -s http://localhost:8081/api/products | jq

# Check Envoy admin interface
kubectl port-forward svc/ecommerce-app-service 9901:9901 -n ecommerce &
curl -s http://localhost:9901/stats/prometheus | grep envoy

kill %1 %2  # Stop port-forwards
```

### 3. Log Verification

```bash
# Check application logs
kubectl logs -l app=ecommerce-app -c ecommerce-api -n ecommerce --tail=20

# Check Fluent Bit logs
kubectl logs -l app=ecommerce-app -c log-shipper -n ecommerce --tail=20

# Check Envoy logs  
kubectl logs -l app=ecommerce-app -c envoy-proxy -n ecommerce --tail=20

# Check shared log volume
kubectl exec -it deployment/ecommerce-app -c ecommerce-api -n ecommerce -- \
  tail -f /shared/logs/app.log
```

---

## Production Optimizations

### 1. Resource Management and QoS

```bash
# Update deployment with optimal resource configuration
kubectl patch deployment ecommerce-app -n ecommerce -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "ecommerce-api",
            "resources": {
              "requests": {
                "memory": "256Mi",
                "cpu": "250m"
              },
              "limits": {
                "memory": "512Mi",
                "cpu": "500m"
              }
            }
          }
        ]
      }
    }
  }
}'

# Verify QoS class assignment
kubectl describe pod -l app=ecommerce-app -n ecommerce | grep "QoS Class"
```

### 2. Security Hardening

```bash
# Create Pod Security Policy (if using older Kubernetes)
# Or use Pod Security Standards for newer versions

# Create Network Policy for traffic segmentation
cat > ecommerce-network-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ecommerce-app-network-policy
  namespace: ecommerce
spec:
  podSelector:
    matchLabels:
      app: ecommerce-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 3000
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 9901
  egress:
  # Allow DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  # Allow HTTPS for external APIs
  - to: []
    ports:
    - protocol: TCP
      port: 443
  # Allow internal service communication
  - to:
    - namespaceSelector:
        matchLabels:
          name: ecommerce
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 6379  # Redis
EOF

kubectl apply -f ecommerce-network-policy.yaml
```

### 3. High Availability Configuration

```bash
# Create PodDisruptionBudget
cat > ecommerce-pdb.yaml << 'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ecommerce-app-pdb
  namespace: ecommerce
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: ecommerce-app
EOF

kubectl apply -f ecommerce-pdb.yaml

# Verify PDB status
kubectl get pdb -n ecommerce
```

---

## Troubleshooting Common Issues

### Container Communication Problems

```bash
# Check container networking within pods
kubectl exec -it deployment/ecommerce-app -c ecommerce-api -n ecommerce -- \
  netstat -tlnp

# Test inter-container communication
kubectl exec -it deployment/ecommerce-app -c ecommerce-api -n ecommerce -- \
  curl -s http://localhost:9901/stats

# Check shared volumes
kubectl exec -it deployment/ecommerce-app -c ecommerce-api -n ecommerce -- \
  ls -la /shared/logs/
```

### Resource and Performance Issues

```bash
# Check resource usage
kubectl top pods -n ecommerce
kubectl describe pod -l app=ecommerce-app -n ecommerce | grep -A 10 "Requests\|Limits"

# Check events for resource-related issues
kubectl get events -n ecommerce --sort-by='.lastTimestamp' | grep -i "resource\|oom\|evict"

# Performance testing
kubectl port-forward svc/ecommerce-app-service 8080:80 -n ecommerce &

# Load test (install Apache Bench if needed)
ab -n 1000 -c 10 http://localhost:8080/api/products

kill %1
```

### Security Context Issues

```bash
# Check security context enforcement
kubectl describe pod -l app=ecommerce-app -n ecommerce | grep -A 20 "Security Context"

# Verify non-root execution
kubectl exec -it deployment/ecommerce-app -c ecommerce-api -n ecommerce -- \
  id

# Check file system permissions
kubectl exec -it deployment/ecommerce-app -c ecommerce-api -n ecommerce -- \
  ls -la /shared/
```

---

## Advanced Patterns and Next Steps

### Service Mesh Integration

For more advanced traffic management, consider integrating with a service mesh:

```bash
# Example Istio sidecar injection (if Istio is installed)
kubectl label namespace ecommerce istio-injection=enabled

# Redeploy to get Istio sidecars
kubectl rollout restart deployment/ecommerce-app -n ecommerce
```

### Database Integration Preview

The next tutorial will integrate this application with PostgreSQL:

- **Connection pooling** with PgBouncer sidecar
- **Database migrations** with init containers
- **Backup and recovery** automation
- **High availability** with PostgreSQL clusters

### CI/CD Integration

Future tutorials will cover:

- **GitOps deployment** with Flux CD
- **Multi-environment** promotion strategies
- **Automated testing** in deployment pipelines
- **Canary deployments** and rollback strategies

---

## Production Checklist

### Pre-Deployment

- [ ] **Security contexts** configured for all containers
- [ ] **Resource requests and limits** set appropriately
- [ ] **Health checks** configured and tested
- [ ] **Network policies** implemented for traffic segmentation
- [ ] **Pod disruption budgets** created for high availability
- [ ] **Anti-affinity rules** configured for distribution

### Post-Deployment

- [ ] **Monitoring** shows healthy metrics collection
- [ ] **Logging** aggregation working correctly
- [ ] **External access** properly secured with TLS
- [ ] **Performance testing** completed successfully
- [ ] **Load balancing** distributing traffic correctly
- [ ] **Failure scenarios** tested (pod restarts, node failures)

### Operational

- [ ] **Runbooks** created for common operations
- [ ] **Alerting rules** configured and tested
- [ ] **Backup procedures** documented and automated
- [ ] **Scaling policies** defined and implemented
- [ ] **Security scanning** integrated into CI/CD
- [ ] **Regular updates** scheduled for base images and dependencies

---

## Key Takeaways

**Multi-container patterns enable:**
- **Separation of concerns** without service fragmentation
- **Independent scaling** of auxiliary functions
- **Shared resources** for efficient resource utilization
- **Specialized containers** for specific functions

**Production readiness requires:**
- **Comprehensive health checks** at multiple levels
- **Resource management** with appropriate QoS classes
- **Security hardening** with contexts and policies
- **High availability** through redundancy and affinity rules

**Monitoring and observability need:**
- **Multiple metric endpoints** for different container functions
- **Structured logging** with correlation IDs
- **Service discovery** integration with monitoring systems
- **Performance testing** to validate under load

Your application now demonstrates enterprise-grade deployment patterns that can handle production workloads while maintaining operational simplicity and security best practices.

**Next:** [Database Integration](02-database-integration.md) - Learn to deploy and manage stateful services with persistent data storage.