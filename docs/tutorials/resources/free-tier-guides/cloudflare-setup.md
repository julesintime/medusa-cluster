# Cloudflare Free Tier Setup Guide

**Complete step-by-step guide to setting up Cloudflare's free tier for domain management, DNS, and tunnel services**

*Estimated time: 30 minutes | Cost: $0 (using free tier) | Skill level: Beginner*

---

## Overview

Cloudflare's free tier provides enterprise-grade DNS, CDN, and security services at no cost. This guide covers everything you need to get started, including domain setup, DNS configuration, and Cloudflare Tunnels for secure access to your applications.

### What You'll Get for Free

✅ **Global DNS** with 100% uptime SLA  
✅ **DDoS Protection** (unmetered and unlimited)  
✅ **SSL/TLS Certificates** (automatic generation and renewal)  
✅ **CDN and Caching** (global edge network)  
✅ **Analytics and Insights** (traffic, performance, security)  
✅ **Cloudflare Tunnels** (secure remote access without VPN)  
✅ **Page Rules** (3 rules for custom caching/redirects)  

### What You'll Need

- A domain name (can be from any registrar)
- Access to your domain's DNS settings
- Terminal/command line access (for tunnels)

---

## Part 1: Domain and DNS Setup

### Step 1: Create Cloudflare Account

1. **Visit [cloudflare.com](https://www.cloudflare.com/)**
2. **Click "Sign Up"** and create your account
3. **Verify your email address**

### Step 2: Add Your Domain

1. **In Cloudflare dashboard, click "Add a Site"**
2. **Enter your domain name** (e.g., `example.com`)
3. **Select "Free" plan**
4. **Click "Continue"**

### Step 3: DNS Record Discovery

Cloudflare will automatically scan and import your existing DNS records.

1. **Review the detected records**
2. **Add any missing records manually:**
   - `A` record: `@` → Your server IP
   - `CNAME` record: `www` → `@`
   - `MX` records: For email (if applicable)
3. **Ensure the proxy status is correct:**
   - 🟠 **Proxied**: Traffic routed through Cloudflare (recommended for web traffic)
   - ⚫ **DNS Only**: Direct to your server (use for SSH, non-HTTP services)

### Step 4: Update Nameservers

**Critical:** This step makes Cloudflare your DNS provider.

1. **Copy the nameservers** provided by Cloudflare (looks like `ns1.cloudflare.com`, `ns2.cloudflare.com`)
2. **Log into your domain registrar** (GoDaddy, Namecheap, etc.)
3. **Find DNS/Nameserver settings**
4. **Replace existing nameservers** with Cloudflare's nameservers
5. **Save changes**

**⏱️ Propagation time:** 2-24 hours (usually within 2 hours)

### Step 5: Verify Setup

Wait for nameserver changes to propagate, then:

1. **Check Cloudflare dashboard** - should show "Active"
2. **Test DNS resolution:**
   ```bash
   nslookup your-domain.com
   # Should return Cloudflare IP addresses
   ```
3. **Visit your website** - should load normally with Cloudflare protection

---

## Part 2: SSL/TLS Configuration

### Step 1: Enable SSL/TLS

1. **Go to SSL/TLS tab** in Cloudflare dashboard
2. **Select encryption mode:**
   - **Flexible**: Cloudflare to visitors (HTTPS), Cloudflare to server (HTTP) - *Use only if your server doesn't support HTTPS*
   - **Full**: HTTPS end-to-end, accepts self-signed certificates
   - **Full (strict)**: HTTPS end-to-end, requires valid certificates - *Recommended for production*
   - **Off**: No encryption - *Not recommended*

### Step 2: Enable Security Features

**Always Use HTTPS:**
1. **Go to SSL/TLS → Edge Certificates**
2. **Enable "Always Use HTTPS"**
3. **Enable "HTTP Strict Transport Security (HSTS)"** after testing

**Automatic HTTPS Rewrites:**
1. **Enable "Automatic HTTPS Rewrites"**
2. **This fixes mixed content issues automatically**

---

## Part 3: Cloudflare Tunnels Setup

Cloudflare Tunnels provide secure access to your applications without exposing servers to the internet.

### Step 1: Install Cloudflared

**On macOS (Homebrew):**
```bash
brew install cloudflare/cloudflare/cloudflared
```

**On Ubuntu/Debian:**
```bash
# Download the latest release
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

# Install
sudo dpkg -i cloudflared-linux-amd64.deb
```

**On CentOS/RHEL:**
```bash
# Download and install
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.rpm
sudo rpm -i cloudflared-linux-amd64.rpm
```

**Verify installation:**
```bash
cloudflared --version
```

### Step 2: Authenticate Cloudflared

```bash
cloudflared tunnel login
```

This opens a browser window where you:
1. **Log into your Cloudflare account**
2. **Select the domain** you want to use for tunnels
3. **Authorize the connection**

**Authentication file location:**
- macOS/Linux: `~/.cloudflared/cert.pem`

### Step 3: Create a Named Tunnel

```bash
# Create tunnel
cloudflared tunnel create my-tunnel

# Note the tunnel ID - you'll need this later
```

**Example output:**
```
Created tunnel my-tunnel with id: 6ff42ae2-765d-4adf-8112-31c55c1551ef
```

### Step 4: Configure the Tunnel

Create configuration file at `~/.cloudflared/config.yml`:

```yaml
tunnel: 6ff42ae2-765d-4adf-8112-31c55c1551ef  # Your tunnel ID
credentials-file: /home/user/.cloudflared/6ff42ae2-765d-4adf-8112-31c55c1551ef.json

ingress:
  # Route subdomain to local service
  - hostname: app.your-domain.com
    service: http://localhost:3000
  
  # Route another subdomain
  - hostname: api.your-domain.com  
    service: http://localhost:8080
    
  # Catch-all rule (required)
  - service: http_status:404
```

### Step 5: Create DNS Records

**Option A: Manual (Cloudflare Dashboard)**
1. **Go to DNS tab** in Cloudflare
2. **Add CNAME record:**
   - Name: `app` (for app.your-domain.com)
   - Target: `6ff42ae2-765d-4adf-8112-31c55c1551ef.cfargotunnel.com`
   - Proxy status: Proxied (🟠)

**Option B: Automatic (Command Line)**
```bash
cloudflared tunnel route dns my-tunnel app.your-domain.com
```

### Step 6: Run the Tunnel

**Test run:**
```bash
cloudflared tunnel run my-tunnel
```

**Install as system service (recommended for production):**
```bash
# Install service
sudo cloudflared service install

# Start service
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# Check status
sudo systemctl status cloudflared
```

### Step 7: Verify Tunnel Operation

1. **Start your local application:**
   ```bash
   # Example: Start a simple web server
   python3 -m http.server 3000
   ```

2. **Test external access:**
   ```bash
   curl https://app.your-domain.com
   ```

3. **Check tunnel status:**
   ```bash
   cloudflared tunnel info my-tunnel
   ```

---

## Part 4: Security and Optimization

### Step 1: Enable Security Features

**Firewall Rules (Free tier: 5 rules):**
1. **Go to Security → WAF**
2. **Create rules to block threats:**
   - Block countries (if applicable)
   - Block known bad IP ranges
   - Rate limiting for API endpoints

**Bot Fight Mode:**
1. **Go to Security → Bots**
2. **Enable "Bot Fight Mode"** (free protection)

### Step 2: Performance Optimization

**Caching Configuration:**
1. **Go to Caching → Configuration**
2. **Set appropriate caching level:**
   - Standard: Caches static content only
   - Aggressive: Caches more content types

**Page Rules (3 free rules):**
1. **Go to Rules → Page Rules**
2. **Create rules for:**
   - Cache everything for static assets: `*.css`, `*.js`, `*.images`
   - Always online for critical pages
   - Redirect rules for SEO

### Step 3: Analytics Setup

**Enable Analytics:**
1. **Go to Analytics & Logs → Analytics**
2. **Review available metrics:**
   - Requests and bandwidth
   - Threats blocked
   - Performance metrics

---

## Part 5: Free Tier Limits and Monitoring

### Understanding Free Tier Limits

| Feature | Free Tier Limit |
|---------|----------------|
| **Bandwidth** | Unlimited |
| **Requests** | Unlimited |
| **DNS Queries** | Unlimited |
| **Page Rules** | 3 rules |
| **Firewall Rules** | 5 rules |
| **Tunnel Concurrent Requests** | 200 (quick tunnels) |
| **Custom SSL Certificates** | 0 (Universal SSL included) |

### Monitoring Usage

**Check usage:**
1. **Dashboard overview** shows request counts
2. **Analytics tab** provides detailed metrics
3. **Set up alerts** (available in paid plans)

**Signs you might need paid tier:**
- Need more than 3 page rules
- Require advanced firewall features
- Need guaranteed uptime SLA
- Advanced analytics and reporting required

---

## Troubleshooting Common Issues

### DNS Not Resolving

**Check nameserver propagation:**
```bash
dig NS your-domain.com
# Should show Cloudflare nameservers
```

**Common fixes:**
- Wait longer for propagation (up to 24 hours)
- Clear local DNS cache: `sudo dscacheutil -flushcache` (macOS)
- Use different DNS resolver: `8.8.8.8` or `1.1.1.1`

### SSL/TLS Errors

**"Too many redirects" error:**
- Check encryption mode (Full or Full Strict recommended)
- Ensure your server doesn't force HTTPS when Cloudflare uses HTTP to origin

**"Certificate error":**
- Wait for SSL provisioning (up to 24 hours)
- Check if Universal SSL is enabled

### Tunnel Connection Issues

**Tunnel won't start:**
```bash
# Check authentication
cloudflared tunnel login

# Verify tunnel exists
cloudflared tunnel list

# Check configuration
cloudflared tunnel ingress validate
```

**Service not accessible:**
- Verify DNS records are correctly set
- Check local service is running on correct port
- Review ingress rules in config.yml

### Performance Issues

**Slow loading:**
- Check if appropriate content is being cached
- Use page rules to cache static assets
- Enable Brotli compression (automatic with proxied traffic)

---

## Security Best Practices

### 1. DNS Configuration
- Use proxy (🟠) for web traffic
- Use DNS-only (⚫) for non-HTTP services (SSH, FTP, etc.)
- Don't proxy mail servers (MX records)

### 2. SSL/TLS Settings
- Use "Full (strict)" encryption when possible
- Enable HSTS for production sites
- Monitor certificate expiration (handled automatically by Cloudflare)

### 3. Tunnel Security
- Keep credentials file secure (`~/.cloudflared/cert.pem`)
- Use specific ingress rules instead of catch-all
- Monitor tunnel access logs

### 4. Firewall Configuration
- Enable bot protection
- Use rate limiting for API endpoints
- Block unnecessary countries/regions if applicable

---

## Cost Optimization Tips

### Maximizing Free Tier Value

1. **Use Cloudflare for multiple subdomains** - no additional cost
2. **Leverage caching** to reduce origin server load
3. **Use tunnels instead of VPN services** - saves $5-20/month
4. **Utilize free DDoS protection** - saves $100+/month compared to other services
5. **Use free SSL certificates** - saves $10-100/year per certificate

### When to Consider Paid Plans

**Pro Plan ($20/month) if you need:**
- More page rules (20 vs 3)
- Advanced analytics
- Image optimization
- Mobile optimization

**Business Plan ($200/month) if you need:**
- Advanced firewall (100 rules)
- Load balancing
- Custom SSL certificates
- Priority support

---

## Next Steps

### Integration with Labinfra

This Cloudflare setup integrates perfectly with the labinfra platform:

1. **Domain management** through Cloudflare DNS
2. **External access** to your Kubernetes cluster via tunnels  
3. **SSL termination** at Cloudflare edge
4. **DDoS protection** for your applications

### Advanced Configurations

Once comfortable with basics:
- **Load balancing** across multiple servers
- **Custom workers** for edge computing
- **Stream live video** using Cloudflare Stream
- **R2 object storage** for static assets

### Monitoring and Maintenance

- **Review analytics monthly** to understand traffic patterns
- **Update tunnel configurations** as you add services
- **Monitor security threats** in the dashboard
- **Plan for scaling** when approaching free tier limits

---

## Resources and Documentation

### Official Documentation
- [Cloudflare Docs](https://developers.cloudflare.com/)
- [Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [DNS Documentation](https://developers.cloudflare.com/dns/)

### Community Resources
- [Cloudflare Community](https://community.cloudflare.com/)
- [GitHub - Cloudflared](https://github.com/cloudflare/cloudflared)
- [Status Page](https://www.cloudflarestatus.com/)

### Related Labinfra Guides
- [Infisical Setup Guide](./infisical-setup.md) - Secrets management
- [Git Platform Setup](./git-platform-setup.md) - Repository hosting
- [Getting Started Tutorial](../../01-getting-started/README.md) - Full platform deployment

---

**🎉 Congratulations!** You now have a production-ready Cloudflare setup providing global DNS, CDN, security, and tunneling capabilities at no cost.

**Next recommended step:** Set up [Infisical for secrets management](./infisical-setup.md) to complete your secure infrastructure foundation.