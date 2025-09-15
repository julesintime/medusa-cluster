# External Access with Domain and SSL - Production HTTPS Setup

**Secure external access to your applications with custom domains and automated SSL certificates**

After deploying your first application, the next critical step is enabling external access through custom domains with production-grade SSL certificates. This 30-minute tutorial walks through configuring ExternalDNS for automated DNS management and cert-manager for Let's Encrypt SSL certificates.

**Learning Objectives:**
- Configure ExternalDNS for automated DNS record management
- Set up cert-manager with Let's Encrypt for free SSL certificates
- Implement production-ready Ingress with HTTPS termination
- Understand DNS automation patterns and SSL certificate lifecycle
- Deploy applications accessible via custom domains with valid SSL

**Prerequisites:**
- Completed [infrastructure bootstrap](02-infrastructure-bootstrap.md) and [first application](03-first-application.md) tutorials
- K3s cluster with MetalLB and NGINX ingress controller running
- Domain name with DNS provider API access (Cloudflare recommended)
- Basic understanding of DNS records and SSL certificates

---

## The External Access Challenge

### Why Manual DNS Management Doesn't Scale

**Traditional approach problems:**
- Manual DNS record updates for each application deployment
- SSL certificate expiration tracking and renewal
- Inconsistent domain naming conventions
- No integration between application lifecycle and DNS management

**Production requirements:**
- Automatic DNS record creation/deletion based on Ingress resources
- Automated SSL certificate provisioning and renewal
- Secure HTTPS termination at the ingress layer
- Zero-downtime certificate updates

### Solution Architecture

Our external access solution provides:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │     Ingress     │    │   External DNS   │
│                 │    │   Controller    │    │    Provider     │
│  Service        │    │                 │    │                 │
│  ClusterIP      │──▶ │  HTTPS Term.    │──▶ │  Auto Records   │
│                 │    │  Load Balance   │    │  CNAME/A        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │  cert-manager   │
                       │                 │
                       │  Let's Encrypt  │
                       │  Auto Renewal   │
                       └─────────────────┘
```

**Key Components:**
- **ExternalDNS**: Automatically creates DNS records based on Ingress annotations
- **cert-manager**: Provisions and renews SSL certificates from Let's Encrypt
- **NGINX Ingress**: Terminates HTTPS and routes traffic to backend services
- **MetalLB**: Provides external IP addresses for LoadBalancer services

---

## Domain and DNS Provider Setup

### Cloudflare Configuration (Recommended)

**Why Cloudflare:**
- Excellent API support for ExternalDNS
- Free tier includes DNS management for unlimited domains
- Built-in DDoS protection and CDN capabilities
- Reliable DNS infrastructure with global anycast

#### 1. Domain Registration and DNS Setup

```bash
# If you don't have a domain, register one through Cloudflare or transfer existing domain
# For this tutorial, we'll use example domain: myapp.example.com

# Add your domain to Cloudflare:
# 1. Log into Cloudflare dashboard
# 2. Click "Add Site" and enter your domain
# 3. Select Free plan
# 4. Update nameservers at your domain registrar to Cloudflare's nameservers
```

#### 2. Create Cloudflare API Token

```bash
# Create API token with specific permissions:
# 1. Go to Cloudflare Dashboard → My Profile → API Tokens
# 2. Click "Create Token" → "Custom token"
# 3. Configure permissions:
#    - Zone:Zone:Read (for all zones)
#    - Zone:DNS:Edit (for specific zone or all zones)
# 4. Set zone resources to include your domain
# 5. Copy the generated token securely

# Example API token permissions:
# Zone:Zone:Read, Zone:DNS:Edit for zone myapp.example.com
```

#### 3. Store API Token in Infisical

```bash
# Add Cloudflare credentials to Infisical
infisical secrets set CLOUDFLARE_API_TOKEN=your_cloudflare_api_token_here --env=prod
infisical secrets set CLOUDFLARE_EMAIL=your_cloudflare_email@example.com --env=prod

# Verify secrets are stored
infisical secrets get CLOUDFLARE_API_TOKEN --env=prod
```

---

## ExternalDNS Installation and Configuration

### 1. Create ExternalDNS Namespace and RBAC

```bash
# Create dedicated namespace for ExternalDNS
kubectl create namespace external-dns

# Create service account and RBAC permissions
cat > external-dns-rbac.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: external-dns
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services","endpoints","pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["extensions","networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: external-dns
EOF

kubectl apply -f external-dns-rbac.yaml
```

### 2. Configure Cloudflare Credentials

```bash
# Create InfisicalSecret for Cloudflare API access
cat > external-dns-infisical-secrets.yaml << 'EOF'
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: external-dns-cloudflare
  namespace: external-dns
spec:
  hostAPI: https://app.infisical.com/api
  resyncInterval: 60
  
  authentication:
    serviceToken:
      secretsScope:
        envSlug: prod
        secretsPath: "/"
        recursive: false
      serviceTokenSecretReference:
        secretName: infisical-service-token
        secretNamespace: infisical-operator
  
  managedKubeSecretReferences:
    - secretName: cloudflare-credentials
      secretNamespace: external-dns
      creationPolicy: "Orphan"
      template:
        data:
          api-token: "{{ .CLOUDFLARE_API_TOKEN.Value }}"
          email: "{{ .CLOUDFLARE_EMAIL.Value }}"
EOF

kubectl apply -f external-dns-infisical-secrets.yaml

# Verify secret synchronization
kubectl get secrets -n external-dns
kubectl describe infisicalsecret external-dns-cloudflare -n external-dns
```

### 3. Deploy ExternalDNS with Cloudflare Provider

```bash
# Create ExternalDNS deployment
cat > external-dns-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: external-dns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.k8s.io/external-dns/external-dns:v0.14.0
        args:
        - --source=ingress
        - --domain-filter=example.com  # Replace with your domain
        - --provider=cloudflare
        - --cloudflare-proxied=false   # Set to true if you want Cloudflare proxy
        - --cloudflare-dns-records-per-page=100
        - --log-level=info
        - --log-format=text
        - --interval=1m
        - --registry=txt
        - --txt-owner-id=k3s-cluster-1
        env:
        - name: CF_API_TOKEN
          valueFrom:
            secretKeyRef:
              name: cloudflare-credentials
              key: api-token
        - name: CF_API_EMAIL
          valueFrom:
            secretKeyRef:
              name: cloudflare-credentials
              key: email
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /healthz
            port: 7979
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /healthz
            port: 7979
          initialDelaySeconds: 5
          periodSeconds: 10
EOF

kubectl apply -f external-dns-deployment.yaml

# Verify ExternalDNS is running
kubectl get pods -n external-dns
kubectl logs -l app=external-dns -n external-dns
```

---

## cert-manager Installation and Configuration

### 1. Install cert-manager

```bash
# Create cert-manager namespace
kubectl create namespace cert-manager

# Install cert-manager CRDs and components
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Verify cert-manager installation
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager

# Wait for all cert-manager components to be ready
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
```

### 2. Create Let's Encrypt Issuers

```bash
# Create staging issuer for testing (Let's Encrypt rate limits are more lenient)
cat > letsencrypt-staging-issuer.yaml << 'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com  # Replace with your email
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
EOF

# Create production issuer
cat > letsencrypt-production-issuer.yaml << 'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com  # Replace with your email
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
EOF

kubectl apply -f letsencrypt-staging-issuer.yaml
kubectl apply -f letsencrypt-production-issuer.yaml

# Verify issuers are ready
kubectl get clusterissuers
kubectl describe clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-production
```

---

## Deploying Applications with Custom Domains

### Example 1: Simple Web Application with HTTPS

```bash
# Create namespace for demo application
kubectl create namespace demo

# Deploy simple web application
cat > web-app-demo.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
        volumeMounts:
        - name: html-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html-content
        configMap:
          name: web-app-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-app-html
  namespace: demo
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Demo Web App</title>
        <style>
            body { 
                font-family: Arial, sans-serif; 
                text-align: center; 
                margin-top: 50px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
            }
            .container {
                background: rgba(255,255,255,0.1);
                padding: 40px;
                border-radius: 10px;
                display: inline-block;
                backdrop-filter: blur(10px);
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Demo Web Application</h1>
            <p>Successfully deployed with HTTPS via Let's Encrypt!</p>
            <p>Hostname: <code id="hostname"></code></p>
            <p>Timestamp: <span id="timestamp"></span></p>
        </div>
        <script>
            document.getElementById('hostname').textContent = window.location.hostname;
            document.getElementById('timestamp').textContent = new Date().toISOString();
        </script>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
  namespace: demo
spec:
  selector:
    app: web-app
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
EOF

kubectl apply -f web-app-demo.yaml
```

### 2. Create Ingress with Automatic DNS and SSL

```bash
# Create Ingress with ExternalDNS and cert-manager annotations
cat > web-app-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
  namespace: demo
  annotations:
    # ExternalDNS annotations
    external-dns.alpha.kubernetes.io/hostname: "demo.example.com"  # Replace with your domain
    external-dns.alpha.kubernetes.io/ttl: "300"
    
    # cert-manager annotations
    cert-manager.io/cluster-issuer: "letsencrypt-staging"  # Use staging for testing
    
    # NGINX ingress annotations
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - demo.example.com  # Replace with your domain
    secretName: web-app-tls-secret
  rules:
  - host: demo.example.com  # Replace with your domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app-service
            port:
              number: 80
EOF

kubectl apply -f web-app-ingress.yaml

# Monitor certificate issuance
kubectl get certificate -n demo -w
kubectl describe certificate web-app-tls-secret -n demo
kubectl get certificaterequests -n demo
```

### 3. Verification and Testing

```bash
# Check ExternalDNS created DNS record
kubectl logs -l app=external-dns -n external-dns | grep demo.example.com

# Check certificate status
kubectl get certificate web-app-tls-secret -n demo -o wide
kubectl describe certificate web-app-tls-secret -n demo

# Test HTTPS access
curl -k https://demo.example.com  # -k flag ignores certificate validation for staging

# Check SSL certificate details
openssl s_client -servername demo.example.com -connect demo.example.com:443 -showcerts < /dev/null

# Verify DNS resolution
nslookup demo.example.com
dig demo.example.com

# Test with browser - should show "Not Secure" for staging certificates
echo "Open https://demo.example.com in your browser"
```

---

## Production SSL Certificate Deployment

### Switching to Production Let's Encrypt

Once you've verified the staging setup works correctly:

```bash
# Update ingress to use production issuer
kubectl patch ingress web-app-ingress -n demo -p '{
  "metadata": {
    "annotations": {
      "cert-manager.io/cluster-issuer": "letsencrypt-production"
    }
  }
}'

# Delete the staging certificate to force renewal
kubectl delete certificate web-app-tls-secret -n demo

# Monitor production certificate issuance
kubectl get certificate -n demo -w
kubectl describe certificate web-app-tls-secret -n demo

# Verify production certificate
curl https://demo.example.com  # Should work without -k flag
```

### Certificate Monitoring and Renewal

```bash
# Check certificate expiration
kubectl get certificates -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,READY:.status.conditions[0].status,EXPIRY:.status.notAfter

# Monitor cert-manager logs
kubectl logs -l app.kubernetes.io/name=cert-manager -n cert-manager

# Force certificate renewal (if needed)
kubectl annotate certificate web-app-tls-secret -n demo cert-manager.io/issue-temporary-certificate="true"
```

---

## Advanced Configuration Patterns

### 1. Wildcard Certificates

```yaml
# Wildcard certificate for *.example.com
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-certificate
  namespace: default
spec:
  secretName: wildcard-tls-secret
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: "*.example.com"
  dnsNames:
  - "*.example.com"
  - "example.com"
```

### 2. Multiple Applications with Shared Certificate

```yaml
# Ingress using shared wildcard certificate
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-app-ingress
  namespace: production
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "app1.example.com,app2.example.com"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app1.example.com
    - app2.example.com
    secretName: wildcard-tls-secret
  rules:
  - host: app1.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  - host: app2.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

### 3. Custom Ingress with Advanced Routing

```yaml
# Advanced routing with path-based and header-based routing
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: advanced-routing
  namespace: production
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "api.example.com"
    cert-manager.io/cluster-issuer: "letsencrypt-production"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: SAMEORIGIN";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.example.com
    secretName: api-tls-secret
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /api/v1(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: api-v1-service
            port:
              number: 8080
      - path: /api/v2(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: api-v2-service
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

---

## Troubleshooting Common Issues

### ExternalDNS Issues

```bash
# Check ExternalDNS logs
kubectl logs -l app=external-dns -n external-dns --tail=50

# Common issues and solutions:

# 1. API rate limiting
# Solution: Increase --interval or reduce --cloudflare-dns-records-per-page

# 2. Insufficient permissions
# Check API token has Zone:Zone:Read and Zone:DNS:Edit permissions

# 3. Domain filter mismatch
# Ensure --domain-filter matches your domain

# Debug ExternalDNS configuration
kubectl describe deployment external-dns -n external-dns
kubectl get secrets cloudflare-credentials -n external-dns -o yaml
```

### cert-manager Certificate Issues

```bash
# Check certificate status
kubectl describe certificate web-app-tls-secret -n demo

# Check certificate request
kubectl get certificaterequests -n demo
kubectl describe certificaterequest <request-name> -n demo

# Check cert-manager logs
kubectl logs -l app.kubernetes.io/name=cert-manager -n cert-manager --tail=50

# Common certificate issues:

# 1. HTTP-01 challenge fails
# Ensure ingress is accessible and responding to /.well-known/acme-challenge/

# 2. Rate limiting from Let's Encrypt
# Use staging issuer for testing, production for final deployment

# 3. DNS propagation delays
# Wait 5-10 minutes for DNS changes to propagate globally

# Debug HTTP-01 challenge
kubectl get challenges -A
kubectl describe challenge <challenge-name> -n <namespace>
```

### SSL/TLS Issues

```bash
# Test SSL certificate
openssl s_client -servername demo.example.com -connect demo.example.com:443 -showcerts

# Check certificate chain
curl -vI https://demo.example.com

# Validate certificate details
echo | openssl s_client -servername demo.example.com -connect demo.example.com:443 2>/dev/null | openssl x509 -noout -dates -subject -issuer
```

---

## Security Best Practices

### 1. API Token Security

```bash
# Use minimal permissions for Cloudflare API token
# - Zone:Zone:Read for zone discovery
# - Zone:DNS:Edit for specific zones only
# - Set IP restrictions if possible
# - Use token expiration

# Rotate API tokens regularly
infisical secrets set CLOUDFLARE_API_TOKEN=new_token_here --env=prod
kubectl rollout restart deployment/external-dns -n external-dns
```

### 2. Certificate Security

```bash
# Monitor certificate expiration
kubectl get certificates -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,EXPIRY:.status.notAfter

# Use production certificates only after testing
# Always test with staging issuer first

# Implement certificate renewal monitoring
# Set up alerts for certificate expiration warnings
```

### 3. Ingress Security Headers

```yaml
# Add security headers to ingress
annotations:
  nginx.ingress.kubernetes.io/configuration-snippet: |
    more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload";
    more_set_headers "X-Frame-Options: SAMEORIGIN";
    more_set_headers "X-Content-Type-Options: nosniff";
    more_set_headers "X-XSS-Protection: 1; mode=block";
    more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
```

---

## Production Checklist

### Pre-Deployment Validation

- [ ] **Domain DNS configured**: Cloudflare nameservers active
- [ ] **API credentials tested**: ExternalDNS can create/delete test records  
- [ ] **Certificate issuer ready**: ClusterIssuer status shows Ready
- [ ] **Staging certificates work**: Test with letsencrypt-staging first
- [ ] **Ingress controller healthy**: NGINX pods running and ready

### Post-Deployment Verification

- [ ] **DNS records created**: nslookup returns correct IP addresses
- [ ] **SSL certificates valid**: Browser shows secure connection
- [ ] **HTTPS redirect working**: HTTP requests redirect to HTTPS
- [ ] **Certificate auto-renewal**: cert-manager logs show successful renewal setup
- [ ] **Health checks passing**: Application responds correctly via HTTPS

### Monitoring and Maintenance

- [ ] **Certificate expiration monitoring**: Set up alerts 30 days before expiry
- [ ] **DNS record monitoring**: Verify ExternalDNS continues to sync records
- [ ] **Performance monitoring**: Monitor SSL handshake times and errors
- [ ] **Security monitoring**: Review ingress access logs for anomalies

---

## Cost Optimization

### Free Tier Limits

**Cloudflare Free Tier:**
- DNS management for unlimited domains
- 100,000 DNS queries per month  
- DDoS protection and CDN included
- API rate limits: 1200 requests per 5 minutes

**Let's Encrypt:**
- Free SSL certificates with 90-day expiration
- Rate limits: 50 certificates per registered domain per week
- Automatic renewal 30 days before expiration

### Resource Usage

```yaml
# Optimized resource requests for small clusters
resources:
  requests:
    memory: "64Mi"    # ExternalDNS: ~40Mi actual usage
    cpu: "50m"        # ExternalDNS: ~20m actual usage
  limits:
    memory: "128Mi"
    cpu: "100m"
```

**Monthly costs for typical setup:**
- Cloudflare DNS: $0 (free tier)
- Let's Encrypt: $0 (free)
- Additional bandwidth: Minimal for DNS queries
- **Total external access cost: $0/month**

---

## Next Steps

With external access configured, your applications are now:
- ✅ Accessible via custom HTTPS domains
- ✅ Protected with valid SSL certificates  
- ✅ Automatically managed DNS records
- ✅ Production-ready external access

**Continue learning:**
- [Monitoring Basics](05-monitoring-basics.md): Implement comprehensive monitoring
- [Intermediate: Custom Applications](../02-intermediate/01-custom-applications.md): Deploy complex application patterns
- [Architecture: System Design](../../technical-course/01-architecture-fundamentals/01-system-design-principles.md): Understand production architecture patterns

**Production considerations:**
- Set up certificate expiration monitoring and alerting
- Implement DNS monitoring to detect configuration drift
- Consider wildcard certificates for multiple subdomains
- Review security headers and implement additional protections

Your infrastructure now provides enterprise-grade external access capabilities at zero cost, with automated management and production-ready security.