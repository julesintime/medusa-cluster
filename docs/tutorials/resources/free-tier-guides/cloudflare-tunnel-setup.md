# Cloudflare Tunnel Setup: Secure Zero-Cost External Access

**Complete guide to setting up Cloudflare Tunnels for secure, reliable external access to your applications**

*Setup time: 25 minutes | Cost: $0/month forever | Perfect for: Self-hosted applications, development servers, homelab setups*

---

## What Cloudflare Tunnels Solve

### The Problem: Exposing Applications Securely

Traditional approaches to external access have significant drawbacks:

**Port forwarding**: Exposes your entire network, requires router configuration
**VPN**: Complex setup, limits accessibility to VPN users only  
**Dynamic DNS**: Still requires open ports, no built-in security
**Cloud hosting**: Expensive, requires migration and vendor lock-in

### The Cloudflare Tunnel Solution

Cloudflare Tunnels create **secure outbound connections** from your infrastructure to Cloudflare's global network:

- **No open ports**: Outbound-only connections through Cloudflare
- **Automatic HTTPS**: SSL certificates managed automatically
- **Global CDN**: Your app available worldwide with low latency
- **DDoS protection**: Enterprise-grade security included
- **Zero Trust access**: Control who can access your applications

## What You Get With Free Tier

### Included Free Forever

✅ **Unlimited bandwidth and requests**  
✅ **Up to 50 tunnels per account**  
✅ **Custom domains (bring your own domain)**  
✅ **SSL certificates with automatic renewal**  
✅ **DDoS protection and Web Application Firewall**  
✅ **Global CDN with 320+ locations worldwide**  
✅ **DNS management for your domains**  
✅ **Zero Trust network security**  
✅ **Basic analytics and logs**  

### Perfect For

- **Self-hosted applications**: Expose services running on your infrastructure
- **Development environments**: Share work-in-progress with team/clients  
- **Homelab projects**: Access personal services from anywhere
- **IoT devices**: Secure access to embedded systems
- **Staging environments**: Test deployments before production

## Prerequisites and Account Setup

### Required Accounts and Tools

**Cloudflare Account** (free):
- Sign up at [cloudflare.com](https://www.cloudflare.com)
- Email verification required
- No credit card needed for free tier

**Domain Name**:
- Purchase from any registrar ($8-15/year typical cost)
- Can use subdomains of existing domains
- Free options: [Freenom](https://freenom.com) for testing (limited TLDs)

**Technical Requirements**:
- Command-line access to your server/infrastructure
- Basic networking knowledge (IP addresses, ports)
- Text editor for configuration files

### Account Setup

1. **Create Cloudflare Account**
   ```bash
   # Visit https://www.cloudflare.com
   # Click "Sign Up" 
   # Use email and strong password
   # Verify email address
   ```

2. **Add Your Domain**
   ```bash
   # In Cloudflare dashboard:
   # 1. Click "Add a Site"
   # 2. Enter your domain name
   # 3. Select "Free" plan
   # 4. Update nameservers at your registrar
   ```

3. **Verify Domain Control**
   ```bash
   # Wait for DNS propagation (5-30 minutes)
   # Cloudflare will show "Active" status when ready
   # Test with: dig yourdomain.com
   ```

## Installing Cloudflared

### Linux Installation

```bash
# Download and install cloudflared
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# Verify installation
cloudflared --version
```

### macOS Installation

```bash
# Using Homebrew (recommended)
brew install cloudflared

# Or download directly
curl -L --output cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

### Windows Installation

```powershell
# Download from GitHub releases
# https://github.com/cloudflare/cloudflared/releases/latest
# Download cloudflared-windows-amd64.exe
# Rename to cloudflared.exe
# Add to PATH or run from Downloads folder
```

### Docker Installation

```bash
# Run cloudflared in Docker container
docker pull cloudflare/cloudflared:latest

# Verify installation
docker run --rm cloudflare/cloudflared:latest --version
```

## Basic Tunnel Setup

### Step 1: Authenticate with Cloudflare

```bash
# Login to Cloudflare account
cloudflared tunnel login

# This opens browser for authentication
# Select the domain you want to use
# Returns to terminal when complete
```

### Step 2: Create Your First Tunnel

```bash
# Create a new tunnel
cloudflared tunnel create my-app-tunnel

# This generates a unique tunnel ID and credentials file
# Example output:
# Created tunnel my-app-tunnel with id: 12345678-1234-1234-1234-123456789012
# Credentials written to: /home/user/.cloudflared/12345678-1234-1234-1234-123456789012.json
```

### Step 3: Configure DNS Records

```bash
# Create DNS record for your tunnel
cloudflared tunnel route dns my-app-tunnel app.yourdomain.com

# This creates a CNAME record pointing to your tunnel
# Verify in Cloudflare dashboard under DNS tab
```

### Step 4: Create Configuration File

```bash
# Create tunnel configuration file
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml << 'EOF'
tunnel: my-app-tunnel
credentials-file: ~/.cloudflared/12345678-1234-1234-1234-123456789012.json

ingress:
  # Route traffic to local application
  - hostname: app.yourdomain.com
    service: http://localhost:3000
  
  # Default rule (required)
  - service: http_status:404
EOF
```

### Step 5: Test the Tunnel

```bash
# Start your local application first
# Example: Node.js app running on port 3000
node server.js &

# Run tunnel in foreground for testing
cloudflared tunnel run my-app-tunnel

# Test access from browser:
# https://app.yourdomain.com
```

## Production Configuration

### Multiple Applications Setup

```yaml
# ~/.cloudflared/config.yml
tunnel: my-app-tunnel
credentials-file: ~/.cloudflared/12345678-1234-1234-1234-123456789012.json

ingress:
  # Web application
  - hostname: app.yourdomain.com
    service: http://localhost:3000
    originRequest:
      httpHostHeader: app.yourdomain.com
  
  # API service  
  - hostname: api.yourdomain.com
    service: http://localhost:8080
    originRequest:
      httpHostHeader: api.yourdomain.com
  
  # Admin dashboard
  - hostname: admin.yourdomain.com
    service: http://localhost:9000
    originRequest:
      httpHostHeader: admin.yourdomain.com
  
  # Grafana monitoring
  - hostname: grafana.yourdomain.com
    service: http://localhost:3001
  
  # Default catch-all
  - service: http_status:404
```

### Advanced Security Configuration

```yaml
# ~/.cloudflared/config.yml with security features
tunnel: my-app-tunnel
credentials-file: ~/.cloudflared/12345678-1234-1234-1234-123456789012.json

# Global tunnel settings
originRequest:
  connectTimeout: 30s
  tlsTimeout: 10s
  tcpKeepAlive: 30s
  noHappyEyeballs: false
  keepAliveTimeout: 90s
  httpHostHeader: ""

ingress:
  # Production app with security headers
  - hostname: app.yourdomain.com
    service: http://localhost:3000
    originRequest:
      httpHostHeader: app.yourdomain.com
      # Add security headers
      originServerName: app.yourdomain.com
      caPool: /path/to/ca-certificates.crt
      
  # Admin with IP restrictions (configured in Cloudflare dashboard)
  - hostname: admin.yourdomain.com
    service: http://localhost:9000
    
  # Default
  - service: http_status:404
```

### System Service Setup

Create systemd service for automatic startup:

```bash
# Create service file
sudo tee /etc/systemd/system/cloudflared.service > /dev/null << 'EOF'
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
TimeoutStartSec=0
Type=notify
ExecStart=/usr/local/bin/cloudflared tunnel run
Restart=on-failure
RestartSec=5s
User=cloudflared
Group=cloudflared

[Install]
WantedBy=multi-user.target
EOF

# Create cloudflared user
sudo useradd -r -s /bin/false cloudflared

# Copy configuration to system location
sudo mkdir -p /etc/cloudflared
sudo cp ~/.cloudflared/config.yml /etc/cloudflared/config.yml
sudo cp ~/.cloudflared/*.json /etc/cloudflared/
sudo chown -R cloudflared:cloudflared /etc/cloudflared/

# Start and enable service
sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

# Check status
sudo systemctl status cloudflared
```

## Integration with Kubernetes

### Kubernetes Deployment

```yaml
# cloudflared-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflare-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
          - tunnel
          - --config
          - /etc/cloudflared/config.yml
          - run
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared
          readOnly: true
        - name: creds
          mountPath: /etc/cloudflared/creds
          readOnly: true
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
      volumes:
      - name: config
        configMap:
          name: cloudflared-config
      - name: creds
        secret:
          secretName: cloudflared-credentials
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: cloudflare-system
data:
  config.yml: |
    tunnel: my-k8s-tunnel
    credentials-file: /etc/cloudflared/creds/credentials.json
    
    ingress:
      - hostname: app.yourdomain.com
        service: http://app-service.default.svc.cluster.local:80
      - hostname: api.yourdomain.com  
        service: http://api-service.default.svc.cluster.local:8080
      - service: http_status:404
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflared-credentials
  namespace: cloudflare-system
type: Opaque
data:
  credentials.json: <base64-encoded-credentials-file>
```

### DNS Records for Kubernetes Services

```bash
# Create DNS records for each service
cloudflared tunnel route dns my-k8s-tunnel app.yourdomain.com
cloudflared tunnel route dns my-k8s-tunnel api.yourdomain.com
cloudflared tunnel route dns my-k8s-tunnel grafana.yourdomain.com

# Verify DNS records
dig +short app.yourdomain.com
dig +short api.yourdomain.com
```

## Monitoring and Troubleshooting

### Basic Monitoring

```bash
# Check tunnel status
cloudflared tunnel list

# View tunnel details
cloudflared tunnel info my-app-tunnel

# Test connectivity
cloudflared tunnel route ip show

# View logs (when running as service)
sudo journalctl -u cloudflared -f
```

### Advanced Monitoring with Prometheus

```yaml
# Add metrics endpoint to config.yml
tunnel: my-app-tunnel
credentials-file: ~/.cloudflared/credentials.json
metrics: 127.0.0.1:8099  # Prometheus metrics endpoint

ingress:
  - hostname: app.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
```

```bash
# Test metrics endpoint
curl http://127.0.0.1:8099/metrics

# Example metrics available:
# cloudflared_tunnel_connections_total
# cloudflared_tunnel_request_duration_seconds  
# cloudflared_tunnel_response_by_code_total
```

### Common Issues and Solutions

**Issue: Tunnel connects but applications not accessible**
```bash
# Check local application is running
netstat -tlnp | grep :3000

# Verify tunnel configuration
cloudflared tunnel validate ~/.cloudflared/config.yml

# Test local connectivity
curl http://localhost:3000
```

**Issue: SSL/TLS certificate errors**
```bash
# Force SSL certificate regeneration
cloudflared tunnel route dns my-app-tunnel app.yourdomain.com --overwrite

# Check certificate status in Cloudflare dashboard
# Navigate to SSL/TLS → Edge Certificates
```

**Issue: High latency or slow connections**
```bash
# Check connection quality
cloudflared tunnel trace app.yourdomain.com

# Monitor connection metrics
curl -s http://127.0.0.1:8099/metrics | grep cloudflared_tunnel
```

## Security Best Practices

### Access Control Configuration

Set up Cloudflare Access for additional security:

```bash
# In Cloudflare dashboard:
# 1. Go to Zero Trust → Access → Applications
# 2. Click "Add an Application"
# 3. Choose "Self-hosted"
# 4. Configure domain: admin.yourdomain.com
# 5. Set access policies (email domain, IP ranges, etc.)
```

### Network Security

```yaml
# Restrict access by geography
ingress:
  - hostname: app.yourdomain.com
    service: http://localhost:3000
    # Additional security configured in Cloudflare dashboard:
    # - Bot Fight Mode: enabled
    # - Security Level: High  
    # - Country restrictions: as needed
```

### Secrets Management

```bash
# Protect credentials file
chmod 600 ~/.cloudflared/*.json
sudo chown cloudflared:cloudflared /etc/cloudflared/*.json

# Use Infisical for credential management (advanced)
infisical secrets set CLOUDFLARE_TUNNEL_CREDENTIALS="$(cat ~/.cloudflared/credentials.json)"
```

## Cost Analysis and Scaling

### Free Tier Limits

**What's included forever:**
- ✅ Unlimited bandwidth and requests
- ✅ Up to 50 tunnels per account
- ✅ All security features (DDoS protection, WAF)
- ✅ Global CDN and anycast network
- ✅ SSL certificates and automatic renewal

**What you pay for separately:**
- Domain registration: $8-15/year (required)
- Server/hosting costs: varies by provider
- Advanced Zero Trust features: $3/user/month (optional)

### When to Consider Paid Features

**Cloudflare Teams** ($3/user/month):
- Advanced Access policies
- Browser isolation
- Data loss prevention
- Advanced analytics
- Gateway filtering

**Cloudflare Pro** ($20/domain/month):
- Advanced analytics
- Image optimization  
- Mobile acceleration
- Faster SSL certificate issuance

**Most teams never need paid features** for basic tunnel functionality.

## Integration Examples

### Docker Compose Integration

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      
  cloudflared:
    image: cloudflare/cloudflared:latest
    command: tunnel --config /etc/cloudflared/config.yml run
    volumes:
      - ./cloudflared-config:/etc/cloudflared
    depends_on:
      - app
    restart: unless-stopped

volumes:
  cloudflared-config:
```

### Nginx Proxy Integration

```nginx
# /etc/nginx/sites-available/app
upstream app {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name app.yourdomain.com;
    
    # Cloudflare connection info headers
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    # ... (other Cloudflare IP ranges)
    real_ip_header CF-Connecting-IP;
    
    location / {
        proxy_pass http://app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Next Steps

### Immediate Actions
1. **Test your tunnel**: Verify external access works correctly
2. **Set up monitoring**: Configure metrics endpoint and basic alerting  
3. **Document configuration**: Save all settings and credentials securely
4. **Plan additional services**: Identify other applications to expose

### Advanced Configurations
- **Multiple tunnels**: Separate tunnels for different environments
- **Load balancing**: Multiple origin servers for high availability
- **Zero Trust integration**: Advanced access policies and user authentication
- **Automation**: Infrastructure-as-code for tunnel configuration

### Integration with Other Services
- **Monitoring**: Connect to [Grafana Cloud setup](./grafana-cloud-setup.md)
- **Secrets**: Integrate with [Infisical secrets management](./infisical-secrets-setup.md)  
- **CI/CD**: Automate deployments with [GitHub Actions](./github-actions-setup.md)
- **Alerting**: Send notifications via [Discord setup](./discord-community-setup.md)

---

**Congratulations!** You now have secure, reliable external access to your applications at zero monthly cost. Your tunnel provides enterprise-grade security and global performance that scales automatically with your needs.

*Next: [Infisical Secrets Management](./infisical-secrets-setup.md) to secure API keys and sensitive configuration*