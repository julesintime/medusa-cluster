# Medusa Fresh - Complete E-commerce Platform

A production-ready, containerized e-commerce platform built with Medusa v2 and Next.js 15, featuring automated CI/CD pipelines and complete GitOps deployment.

## 🚀 Features

- **🛒 Complete E-commerce Backend**: Medusa v2 with PostgreSQL and Redis
- **🌐 Modern Storefront**: Next.js 15 with TypeScript and Tailwind CSS
- **🔧 Full Automation**: Docker containerization with multi-stage builds
- **⚡ CI/CD Pipeline**: Gitea Actions with BuildKit for fast builds
- **🔒 Security**: Infisical secret management, non-root containers
- **🌍 Multi-Region Support**: Built-in region detection and routing
- **📊 Health Monitoring**: Built-in health checks and monitoring
- **🎯 Production Ready**: Optimized for production deployment

## 📦 Components

### Backend (Medusa)
- **Framework**: Medusa v2 with Node.js 20
- **Database**: PostgreSQL 15 with connection pooling
- **Cache**: Redis 7 for session and cache management
- **Features**: Admin panel, API routes, user management, order processing

### Storefront (Next.js)
- **Framework**: Next.js 15.5.3 with App Router
- **Language**: TypeScript with strict mode
- **Styling**: Tailwind CSS with custom components
- **Features**: Product catalog, shopping cart, checkout, user accounts

### Infrastructure
- **Containerization**: Docker with multi-stage builds
- **Orchestration**: Docker Compose with health checks
- **CI/CD**: Gitea Actions with BuildKit
- **Secrets**: Infisical for secure secret management

## 🛠️ Quick Start

### Prerequisites
- Docker and Docker Compose
- Node.js 20+ (for local development)
- Git

### Local Development

1. **Clone the repository**:
   ```bash
   git clone https://git.xuperson.org/helloroot/medusa-fresh.git
   cd medusa-fresh
   ```

2. **Environment Setup**:
   ```bash
   cp .env.example .env.local
   # Edit .env.local with your configuration
   ```

3. **Start the platform**:
   ```bash
   docker-compose up -d
   ```

4. **Access the services**:
   - **Storefront**: http://localhost:3000
   - **Admin Panel**: http://localhost:9090/app
   - **API**: http://localhost:9090

### Production Deployment

The platform is designed for production deployment using GitOps with Kubernetes and Flux CD.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Storefront    │    │     Backend     │    │   Database      │
│   (Next.js)     │◄──►│    (Medusa)     │◄──►│  (PostgreSQL)   │
│   Port 3000     │    │   Port 9090     │    │   Port 5432     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │     Redis       │
                    │   (Cache)       │
                    │   Port 6379     │
                    └─────────────────┘
```

## 🔧 Configuration

### Environment Variables

Key environment variables (managed via Infisical in production):

#### Backend (Medusa)
- `JWT_SECRET`: JWT signing secret
- `COOKIE_SECRET`: Session cookie secret  
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `ADMIN_EMAIL`: Admin user email
- `ADMIN_PASSWORD`: Admin user password

#### Storefront (Next.js)
- `MEDUSA_BACKEND_URL`: Backend API URL
- `NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY`: Medusa API key
- `NEXT_PUBLIC_BASE_URL`: Storefront base URL
- `NEXT_PUBLIC_DEFAULT_REGION`: Default region code

### Security Features

- 🔐 **Secret Management**: All secrets managed via Infisical
- 👤 **Non-root Containers**: Security-hardened container images
- 🛡️ **CORS Protection**: Proper CORS configuration
- 🔒 **Environment Isolation**: Separate dev/staging/prod environments

## 🚀 CI/CD Pipeline

The project includes automated CI/CD pipelines using Gitea Actions and BuildKit:

### Workflows

1. **Backend CI**: Builds and pushes Medusa backend images
2. **Storefront CI**: Builds and pushes Next.js storefront images  
3. **Full Stack CI**: Comprehensive build for both components

### Build Process

- **Multi-stage Builds**: Optimized Docker images
- **BuildKit**: Fast, parallel builds with layer caching
- **Registry Push**: Automatic image versioning and push
- **GitOps Ready**: Images tagged for Flux CD deployment

## 📊 Monitoring & Health Checks

### Health Endpoints

- **Backend**: `/health` - Database and Redis connectivity
- **Storefront**: `/api/health` - Application health status

### Container Health Checks

All containers include built-in health checks for:
- Service availability
- Database connectivity  
- External API reachability

## 🌐 Production Deployment

The platform is designed for GitOps deployment using:

- **Kubernetes**: Container orchestration
- **Flux CD**: GitOps continuous deployment
- **Infisical**: Production secret management
- **External DNS**: Automatic DNS management
- **Ingress NGINX**: Load balancing and SSL termination

## 📚 Documentation

- **Backend API**: Available at `/docs` when running
- **Storefront Components**: Documented in component files
- **Deployment Guide**: See `clusters/labinfra/apps/` for Kubernetes manifests

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏷️ Version

- **Medusa**: v2.x
- **Next.js**: 15.5.3
- **Node.js**: 20 LTS
- **Docker**: Multi-stage production builds

---

Built with ❤️ for modern e-commerce platforms