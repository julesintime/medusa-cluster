# Getting Started - Hands-On Implementation Guide

**Transform from cloud-native concepts to production deployment in 4 practical sessions**

## Quick Start Path

This hands-on series takes you from zero to a production-ready cloud-native infrastructure in under 4 hours of focused work. Each guide builds on the previous one, creating a complete deployment pipeline.

### What You'll Build
- **Production K3s cluster** on bare metal or VPS
- **GitOps deployment pipeline** with FluxCD
- **Your first application** with HTTPS and custom domain
- **Monitoring and observability** basics

### Time Investment
- **Prerequisites**: 30 minutes (one-time setup)
- **Infrastructure**: 45 minutes (core deployment)
- **First Application**: 30 minutes (hello world to production)
- **Domain & SSL**: 15 minutes (external access)
- **Monitoring**: 30 minutes (basic observability)

**Total: ~2.5 hours** for complete production infrastructure

---

## Implementation Track

### Prerequisites & Account Setup
→ **[01-prerequisites-setup.md](./01-prerequisites-setup.md)**

**Goal**: Secure free accounts for complete infrastructure stack
**Time**: 30 minutes
**Outcome**: Ready-to-use accounts with API keys

**What You'll Get:**
- GitHub account with personal access token
- Cloudflare account with domain and API token  
- Optional: Cloud VPS provider account
- Local development environment setup

**Free Tier Coverage:**
- $0/month for core GitOps infrastructure
- $8-12/year for domain registration only
- No cloud hosting costs with existing hardware

### Infrastructure Bootstrap
→ **[02-infrastructure-bootstrap.md](./02-infrastructure-bootstrap.md)**

**Goal**: Deploy production K3s cluster with GitOps
**Time**: 45 minutes
**Outcome**: Running Kubernetes cluster with FluxCD

**What You'll Build:**
- K3s cluster with HA configuration
- FluxCD GitOps controller
- Ingress NGINX for external access
- MetalLB load balancer
- Basic monitoring stack

**Validation Points:**
- `kubectl get nodes` shows Ready cluster
- `flux get kustomizations` shows healthy GitOps
- External IP pool allocated and accessible

### First Application Deployment  
→ **[03-first-application.md](./03-first-application.md)**

**Goal**: Deploy containerized app via GitOps pipeline
**Time**: 30 minutes
**Outcome**: Running application accessible via LoadBalancer

**What You'll Deploy:**
- Sample Node.js application
- Kubernetes deployment with health checks
- LoadBalancer service with fixed IP
- Basic logging and monitoring

**Learning Focus:**
- GitOps workflow: git commit → Flux reconciliation → deployment
- Kubernetes resource patterns (deployment, service, configmap)
- Container health checks and lifecycle management

### Domain & SSL Configuration
→ **[04-domain-and-ssl.md](./04-domain-and-ssl.md)**

**Goal**: External HTTPS access with custom domain
**Time**: 15 minutes  
**Outcome**: https://yourapp.yourdomain.com accessible globally

**What You'll Configure:**
- DNS records via Cloudflare API
- ExternalDNS for automatic DNS management
- Ingress resource with SSL termination
- Cloudflare proxy for DDoS protection

**Business Value:**
- Professional external access for stakeholders
- SSL certificate automation
- CDN and security via Cloudflare proxy

### Monitoring & Observability
→ **[05-monitoring-basics.md](./05-monitoring-basics.md)**

**Goal**: Basic production monitoring setup
**Time**: 30 minutes
**Outcome**: Grafana dashboard with key metrics

**What You'll Monitor:**
- Cluster health (nodes, pods, deployments)
- Application metrics (requests, errors, latency)  
- Infrastructure metrics (CPU, memory, disk)
- Log aggregation basics

**Observability Stack:**
- Prometheus for metrics collection
- Grafana for visualization
- Loki for log aggregation (optional)
- Alert Manager for notifications

---

## Learning Philosophy

### Practitioner-to-Practitioner Transfer
Every guide reflects real production experience, not theoretical examples. Common gotchas, debugging steps, and "why it matters" context included throughout.

### Progressive Complexity
- **Session 1**: Core concepts and account setup
- **Session 2**: Infrastructure automation
- **Session 3**: Application deployment patterns  
- **Session 4**: Production features (DNS, SSL, monitoring)

### Immediate Value Recognition
Each session delivers a working system you can demonstrate to stakeholders. No "toy examples" - every deployment pattern scales to production workloads.

### Zero Vendor Lock-in
- **K3s**: Runs anywhere (bare metal, VPS, cloud)
- **FluxCD**: Works with any Git provider
- **Cloudflare**: DNS only, easily replaceable
- **Standard Kubernetes**: Portable across environments

---

## Prerequisites Knowledge

### Required (15-minute validation)
- **Linux command line**: `cd`, `ls`, `mkdir`, `cp` commands
- **Git basics**: `git add`, `git commit`, `git push` workflow
- **Text editing**: Comfortable editing YAML files

### Helpful (but not required)
- **Docker concepts**: Container vs image understanding
- **YAML syntax**: Basic key-value structure familiarity
- **HTTP/DNS**: Domain name and SSL certificate concepts

### Learning Resources
If you need to level up on prerequisites:
- **Git workflow**: [Git Handbook](https://guides.github.com/introduction/git-handbook/) (15 minutes)
- **YAML basics**: [YAML Tutorial](https://www.cloudbees.com/blog/yaml-tutorial-everything-you-need-get-started) (10 minutes)
- **Container concepts**: See [../00-foundations/06-container-fundamentals-beginners.md](../00-foundations/06-container-fundamentals-beginners.md)

---

## Success Metrics

### Technical Validation
- [ ] Kubernetes cluster responds to `kubectl get nodes`
- [ ] FluxCD successfully reconciles git changes
- [ ] Application accessible via external IP
- [ ] HTTPS domain resolves globally
- [ ] Monitoring dashboard shows live metrics

### Business Validation  
- [ ] Stakeholder can access demo application via HTTPS
- [ ] Deployment time under 5 minutes for changes
- [ ] Infrastructure cost under $20/month total
- [ ] Documentation sufficient for team member replication

### Knowledge Transfer Validation
- [ ] Can explain GitOps workflow to colleague
- [ ] Can troubleshoot common deployment issues
- [ ] Understand monitoring alerts and resolution steps
- [ ] Ready to customize for specific application needs

---

## What's Next

After completing this getting-started series, you'll have production infrastructure and hands-on experience with:

- **Cloud-native deployment patterns**
- **Infrastructure as Code (IaC) workflows**  
- **GitOps continuous deployment**
- **Kubernetes operational basics**
- **Production monitoring fundamentals**

### Progression Paths

**For Development Teams:**
→ [02-intermediate/](../02-intermediate/README.md) - Custom applications, databases, CI/CD pipelines

**For DevOps Engineers:**  
→ [technical-course/](../../technical-course/README.md) - Architecture deep-dives, scaling patterns

**For Business Leaders:**
→ [business/](../../business/README.md) - ROI analysis, team efficiency case studies

---

## Support & Troubleshooting

### Common Issues Database
Each guide includes "Common Issues" sections with:
- **Symptom description**
- **Root cause analysis** 
- **Step-by-step resolution**
- **Prevention strategies**

### Community Support
- **GitHub Issues**: Technical problems and enhancement requests
- **Discussion Forums**: Architecture questions and best practices
- **Office Hours**: Live troubleshooting sessions (monthly)

### Enterprise Support
For teams needing guidance on production deployments, architecture review, or custom implementation:
- **Architecture consulting**: Infrastructure design review
- **Implementation support**: Hands-on deployment assistance
- **Team training**: Custom workshops and knowledge transfer

Ready to build production-ready cloud-native infrastructure? Start with [Prerequisites Setup](./01-prerequisites-setup.md) →