# Advanced CI/CD Pipelines - Production-Grade GitOps

**Build sophisticated continuous integration and deployment workflows with security scanning, multi-environment promotion, and automated testing**

This tutorial guides you through implementing enterprise-grade CI/CD pipelines that go far beyond basic deployment automation. You'll create secure, tested, and reliable deployment workflows that handle complex application lifecycles with automated quality gates, security scanning, and progressive delivery patterns.

## What You'll Build

- **Multi-stage CI/CD pipeline** with comprehensive testing and security scanning
- **Multi-environment promotion** with automated and manual gates
- **Progressive deployment strategies** (canary and blue-green deployments)
- **Security-first approach** with SAST, DAST, and container scanning
- **Performance testing automation** integrated into deployment pipeline
- **Automated rollback mechanisms** with health-based triggers
- **Comprehensive observability** and deployment analytics

**Time investment**: 90 minutes | **Result**: Enterprise-ready CI/CD pipeline

---

## Prerequisites Validation

Ensure you have completed the previous intermediate tutorials:

```bash
# Verify cluster and applications
kubectl get deployments -A
kubectl get ingress -A

# Verify GitOps setup
flux get kustomizations
flux get sources git

# Verify monitoring stack
kubectl get pods -n monitoring
kubectl get servicemonitors -A

# Expected: All services running and healthy
```

**Required infrastructure:**
- Custom applications deployed ([Tutorial 1](01-custom-applications.md))
- Database integration complete ([Tutorial 2](02-database-integration.md))
- Monitoring stack operational
- Multiple environments configured

---

## CI/CD Architecture Overview

### Pipeline Stages and Security Gates

```mermaid
graph TB
    A[Code Push] --> B[Security Scanning]
    B --> C[Unit Tests]
    C --> D[Build & Package]
    D --> E[Container Security Scan]
    E --> F[Deploy to Staging]
    F --> G[Integration Tests]
    G --> H[Performance Tests]
    H --> I{Manual Approval Gate}
    I -->|Approved| J[Canary Deployment]
    J --> K[Health Monitoring]
    K --> L{Health Check}
    L -->|Healthy| M[Full Production Deployment]
    L -->|Unhealthy| N[Automatic Rollback]
    M --> O[Post-Deployment Testing]
    
    style B fill:#ff9999
    style E fill:#ff9999
    style H fill:#99ccff
    style I fill:#ffcc99
    style L fill:#99ff99
    style N fill:#ff6666
```

### Security-First Pipeline Design

**2025 security requirements:**
- **SAST scanning** with SonarQube integration
- **Container vulnerability scanning** with Trivy/Grype
- **Secrets detection** with TruffleHog
- **Infrastructure as Code scanning** with Checkov
- **DAST testing** with OWASP ZAP
- **Supply chain security** with Sigstore/Cosign

---

## Advanced GitHub Actions Workflow

### Complete CI/CD Pipeline

Create `.github/workflows/advanced-cicd.yml`:

```yaml
name: Advanced Production CI/CD Pipeline

on:
  push:
    branches: [ main, develop, 'feature/**' ]
  pull_request:
    branches: [ main ]
  release:
    types: [created]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
  COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
  COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}

jobs:
  # Security and Code Quality Stage
  security-scan:
    name: Security & Code Quality
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for accurate analysis

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run ESLint with security rules
        run: npx eslint --ext .js,.ts --format sarif --output-file eslint-results.sarif .
        continue-on-error: true

      - name: Upload ESLint results to GitHub
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: eslint-results.sarif
        if: always()

      - name: Run Secrets Detection
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: main
          head: HEAD

      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

      - name: Dependency Check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: '${{ github.repository }}'
          path: '.'
          format: 'SARIF'

  # Unit and Integration Tests
  test:
    name: Comprehensive Testing
    runs-on: ubuntu-latest
    needs: security-scan
    
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

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

      - name: Run unit tests
        run: npm run test:unit
        env:
          NODE_ENV: test
          DATABASE_URL: postgres://postgres:testpass@localhost:5432/testdb
          REDIS_URL: redis://localhost:6379

      - name: Run integration tests
        run: npm run test:integration
        env:
          NODE_ENV: test
          DATABASE_URL: postgres://postgres:testpass@localhost:5432/testdb
          REDIS_URL: redis://localhost:6379

      - name: Generate test coverage
        run: npm run test:coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/coverage-final.json
          fail_ci_if_error: true

      - name: Upload test results
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Jest Tests
          path: junit.xml
          reporter: jest-junit

  # Build and Container Security
  build-secure:
    name: Build & Container Security
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push' || github.event_name == 'release'
    
    permissions:
      contents: read
      packages: write
      security-events: write
      id-token: write  # For Cosign

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

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-,format=short
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
          build-args: |
            NODE_ENV=production
            APP_VERSION=${{ github.sha }}

      - name: Sign container image
        run: |
          echo "${{ env.COSIGN_PRIVATE_KEY }}" > cosign.key
          cosign sign --key cosign.key ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
          rm cosign.key

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy scan results to GitHub
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Run Grype vulnerability scanner
        uses: anchore/scan-action@v3
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
          severity-cutoff: medium
          fail-build: true

      - name: Output image
        id: image
        run: |
          echo "image=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}" >> $GITHUB_OUTPUT

  # Staging Deployment
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build-secure
    if: github.ref == 'refs/heads/main'
    
    environment:
      name: staging
      url: https://staging.yourdomain.com

    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          repository: ${{ github.repository_owner }}/k3s-gitops
          token: ${{ secrets.GITOPS_TOKEN }}
          path: gitops

      - name: Setup Kustomize
        uses: imranismail/setup-kustomize@v2

      - name: Update staging image
        run: |
          cd gitops/clusters/staging/apps/${{ github.event.repository.name }}
          kustomize edit set image ${{ needs.build-secure.outputs.image }}
          
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "chore: update staging image to ${{ needs.build-secure.outputs.image }}"
          git push

      - name: Wait for deployment
        run: |
          echo "Waiting for staging deployment to complete..."
          sleep 60  # Allow time for Flux to reconcile

  # Staging Tests
  staging-tests:
    name: Staging Environment Tests
    runs-on: ubuntu-latest
    needs: deploy-staging
    
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

      - name: Run smoke tests
        run: npm run test:smoke
        env:
          BASE_URL: https://staging.yourdomain.com

      - name: Run API contract tests
        run: npm run test:contract
        env:
          BASE_URL: https://staging.yourdomain.com

      - name: Performance testing with Artillery
        run: |
          npx artillery run performance/load-test.yml
        env:
          TARGET_URL: https://staging.yourdomain.com

      - name: DAST Scan with OWASP ZAP
        uses: zaproxy/action-full-scan@v0.9.0
        with:
          target: 'https://staging.yourdomain.com'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'

  # Production Deployment Approval
  production-gate:
    name: Production Deployment Gate
    runs-on: ubuntu-latest
    needs: staging-tests
    
    environment:
      name: production-approval
    
    steps:
      - name: Manual approval checkpoint
        run: |
          echo "🚀 Ready for production deployment"
          echo "Image: ${{ needs.build-secure.outputs.image }}"
          echo "Staging tests: ✅ Passed"
          echo "Security scans: ✅ Passed"

  # Canary Deployment
  deploy-canary:
    name: Canary Production Deployment
    runs-on: ubuntu-latest
    needs: [build-secure, production-gate]
    
    environment:
      name: production
      url: https://yourdomain.com

    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          repository: ${{ github.repository_owner }}/k3s-gitops
          token: ${{ secrets.GITOPS_TOKEN }}
          path: gitops

      - name: Setup kubectl
        uses: azure/setup-kubectl@v3

      - name: Configure kubectl
        run: |
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
          export KUBECONFIG=kubeconfig

      - name: Deploy canary version
        run: |
          cd gitops/clusters/production/apps/${{ github.event.repository.name }}
          
          # Create canary deployment
          cp deployment.yaml deployment-canary.yaml
          sed -i 's/name: myapp/name: myapp-canary/g' deployment-canary.yaml
          sed -i 's/replicas: 3/replicas: 1/g' deployment-canary.yaml
          sed -i 's|image: .*|image: ${{ needs.build-secure.outputs.image }}|g' deployment-canary.yaml
          sed -i 's/app: myapp/app: myapp-canary/g' deployment-canary.yaml
          
          # Create canary service
          cp service.yaml service-canary.yaml
          sed -i 's/name: myapp/name: myapp-canary/g' service-canary.yaml
          sed -i 's/app: myapp/app: myapp-canary/g' service-canary.yaml
          
          # Update kustomization
          echo "  - deployment-canary.yaml" >> kustomization.yaml
          echo "  - service-canary.yaml" >> kustomization.yaml
          
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "feat: deploy canary version ${{ needs.build-secure.outputs.image }}"
          git push

      - name: Monitor canary health
        run: |
          echo "⏳ Monitoring canary deployment health..."
          
          # Wait for deployment
          kubectl wait --for=condition=available deployment/myapp-canary --timeout=300s
          
          # Check health metrics
          sleep 60  # Allow metrics to populate
          
          # Simple health check (implement more sophisticated monitoring)
          STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://yourdomain.com)
          if [ $STATUS_CODE -eq 200 ]; then
            echo "✅ Canary deployment healthy"
          else
            echo "❌ Canary deployment unhealthy"
            exit 1
          fi

      - name: Update ingress for canary traffic
        run: |
          cd gitops/clusters/production/apps/${{ github.event.repository.name }}
          
          # Update ingress to split traffic (90/10)
          cat > ingress-canary.yaml << EOF
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: myapp-canary
            annotations:
              nginx.ingress.kubernetes.io/canary: "true"
              nginx.ingress.kubernetes.io/canary-weight: "10"
          spec:
            ingressClassName: nginx
            rules:
            - host: yourdomain.com
              http:
                paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: myapp-canary
                      port:
                        number: 80
          EOF
          
          echo "  - ingress-canary.yaml" >> kustomization.yaml
          
          git add .
          git commit -m "feat: enable 10% canary traffic split"
          git push

  # Full Production Deployment
  deploy-production:
    name: Full Production Deployment
    runs-on: ubuntu-latest
    needs: [build-secure, deploy-canary]
    
    steps:
      - name: Monitor canary metrics
        run: |
          echo "📊 Monitoring canary metrics for 5 minutes..."
          
          # Monitor error rates, response times, etc.
          # Implement Prometheus queries or external monitoring
          sleep 300  # 5 minute canary analysis
          
          # Example health check
          ERROR_RATE=$(curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status=~'5..'}[5m])" | jq '.data.result[0].value[1]')
          
          if (( $(echo "$ERROR_RATE < 0.01" | bc -l) )); then
            echo "✅ Canary metrics healthy, proceeding with full deployment"
          else
            echo "❌ Canary metrics indicate issues, aborting deployment"
            exit 1
          fi

      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          repository: ${{ github.repository_owner }}/k3s-gitops
          token: ${{ secrets.GITOPS_TOKEN }}
          path: gitops

      - name: Full production deployment
        run: |
          cd gitops/clusters/production/apps/${{ github.event.repository.name }}
          
          # Update main deployment
          sed -i 's|image: .*|image: ${{ needs.build-secure.outputs.image }}|g' deployment.yaml
          
          # Remove canary resources
          git rm deployment-canary.yaml service-canary.yaml ingress-canary.yaml
          sed -i '/deployment-canary.yaml/d' kustomization.yaml
          sed -i '/service-canary.yaml/d' kustomization.yaml  
          sed -i '/ingress-canary.yaml/d' kustomization.yaml
          
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "feat: promote to full production ${{ needs.build-secure.outputs.image }}"
          git push

  # Post-deployment verification
  post-deployment:
    name: Post-Deployment Verification
    runs-on: ubuntu-latest
    needs: deploy-production
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Production health check
        run: |
          echo "🔍 Running production health verification..."
          
          # Wait for full deployment
          sleep 60
          
          # Comprehensive health checks
          curl -f https://yourdomain.com/health || exit 1
          curl -f https://yourdomain.com/metrics || exit 1
          
          # Performance verification
          RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' https://yourdomain.com)
          if (( $(echo "$RESPONSE_TIME < 1.0" | bc -l) )); then
            echo "✅ Performance check passed ($RESPONSE_TIME seconds)"
          else
            echo "⚠️ Performance degradation detected ($RESPONSE_TIME seconds)"
          fi

      - name: Update deployment status
        run: |
          echo "🎉 Deployment completed successfully!"
          echo "Image: ${{ needs.build-secure.outputs.image }}"
          echo "Environment: Production"
          echo "Status: ✅ Healthy"

  # Rollback job (triggered manually or by monitoring alerts)
  rollback:
    name: Emergency Rollback
    runs-on: ubuntu-latest
    if: github.event_name == 'workflow_dispatch'
    
    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          repository: ${{ github.repository_owner }}/k3s-gitops
          token: ${{ secrets.GITOPS_TOKEN }}
          path: gitops

      - name: Rollback to previous version
        run: |
          cd gitops/clusters/production/apps/${{ github.event.repository.name }}
          
          # Revert to previous commit
          git log --oneline -10
          
          echo "Enter the commit hash to rollback to:"
          read ROLLBACK_COMMIT
          
          git revert $ROLLBACK_COMMIT --no-edit
          git push
          
          echo "🔄 Rollback initiated to commit: $ROLLBACK_COMMIT"
```

---

## Security Configuration Files

### SonarQube Configuration

Create `sonar-project.properties`:

```properties
sonar.projectKey=myorg_myapp
sonar.organization=myorg
sonar.sources=src
sonar.tests=tests
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.testExecutionReportPaths=coverage/test-reporter.xml

# Security-focused rules
sonar.security.hotspots.trackingKey.enabled=true
sonar.security.rating=A
sonar.reliability.rating=A
sonar.maintainability.rating=A

# Code coverage requirements
sonar.coverage.exclusions=**/*.spec.js,**/*.test.js
sonar.qualitygate.wait=true
```

### ESLint Security Configuration

Create `.eslintrc.security.js`:

```javascript
module.exports = {
  extends: [
    'eslint:recommended',
    '@typescript-eslint/recommended',
    'plugin:security/recommended'
  ],
  plugins: ['security'],
  rules: {
    'security/detect-object-injection': 'error',
    'security/detect-non-literal-regexp': 'error',
    'security/detect-unsafe-regex': 'error',
    'security/detect-buffer-noassert': 'error',
    'security/detect-child-process': 'error',
    'security/detect-disable-mustache-escape': 'error',
    'security/detect-eval-with-expression': 'error',
    'security/detect-no-csrf-before-method-override': 'error',
    'security/detect-non-literal-fs-filename': 'error',
    'security/detect-non-literal-require': 'error',
    'security/detect-possible-timing-attacks': 'error',
    'security/detect-pseudoRandomBytes': 'error'
  }
};
```

### OWASP ZAP Security Rules

Create `.zap/rules.tsv`:

```tsv
10202	IGNORE	(False Positive - Session Management)
10021	IGNORE	(X-Content-Type-Options header - handled by ingress)
10017	IGNORE	(Cross-Domain JavaScript Source - CDN usage)
10015	IGNORE	(Incomplete or No Cache-control - API endpoints)
10011	IGNORE	(Cookie Without HttpOnly Flag - handled by session middleware)
```

---

## Multi-Environment Configuration

### Environment-Specific Overlays

Create staging environment configuration:

**`clusters/staging/apps/myapp/kustomization.yaml`**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../base/apps/myapp

patchesStrategicMerge:
  - deployment-patch.yaml
  - ingress-patch.yaml

configMapGenerator:
  - name: app-config
    behavior: merge
    literals:
      - NODE_ENV=staging
      - LOG_LEVEL=debug
      - FEATURE_FLAGS=staging-features-enabled

images:
  - name: myapp
    newTag: staging-latest
```

**`clusters/staging/apps/myapp/deployment-patch.yaml`**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: myapp
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        env:
        - name: NODE_ENV
          value: "staging"
        - name: LOG_LEVEL
          value: "debug"
```

### Production Configuration

**`clusters/production/apps/myapp/kustomization.yaml`**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../base/apps/myapp

patchesStrategicMerge:
  - deployment-patch.yaml
  - ingress-patch.yaml
  - hpa.yaml

configMapGenerator:
  - name: app-config
    behavior: merge
    literals:
      - NODE_ENV=production
      - LOG_LEVEL=info
      - FEATURE_FLAGS=production-features-only

secretGenerator:
  - name: app-secrets
    envs:
      - secrets.env

images:
  - name: myapp
    newTag: latest
```

**`clusters/production/apps/myapp/hpa.yaml`**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 3
  maxReplicas: 20
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
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
```

---

## Progressive Deployment Strategies

### Flagger Canary Configuration

Create `clusters/production/apps/myapp/canary.yaml`:

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp-canary
  namespace: default
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  
  progressDeadlineSeconds: 60
  
  service:
    port: 80
    targetPort: 8080
    gateways:
    - myapp-gateway
    hosts:
    - yourdomain.com
    
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 5
    
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
      
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
      
    - name: cpu-usage
      thresholdRange:
        max: 80
      interval: 30s
      
    webhooks:
    - name: acceptance-test
      type: pre-rollout
      url: http://loadtester.flagger/
      timeout: 30s
      metadata:
        type: bash
        cmd: "curl -sd 'test' http://myapp-canary.default/api/info | grep healthy"
        
    - name: load-test
      type: rollout
      url: http://loadtester.flagger/
      metadata:
        cmd: "hey -z 2m -q 10 -c 2 http://myapp-canary.default/"
        
  alerts:
  - name: slack
    severity: info
    providerRef:
      name: slack
      namespace: flagger-system
```

### Blue-Green Deployment with Argo Rollouts

Create `clusters/production/apps/myapp/rollout.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp-rollout
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: myapp-active
      previewService: myapp-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: myapp-preview.default.svc.cluster.local
      postPromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: myapp-active.default.svc.cluster.local
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: 256Mi
            cpu: 250m
          limits:
            memory: 512Mi
            cpu: 500m
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

---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 2m
    count: 3
    successCondition: result[0] >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(
            http_requests_total{service="{{args.service-name}}",status!~"5.*"}[2m]
          )) /
          sum(rate(
            http_requests_total{service="{{args.service-name}}"}[2m]
          ))
```

---

## Automated Testing Integration

### Performance Testing Configuration

Create `performance/load-test.yml`:

```yaml
config:
  target: 'https://staging.yourdomain.com'
  phases:
    - duration: 60
      arrivalRate: 1
      name: "Warm up"
    - duration: 120
      arrivalRate: 5
      rampTo: 50
      name: "Ramp up load"
    - duration: 300
      arrivalRate: 50
      name: "Sustained load"
  processor: "./load-test-processor.js"
  
scenarios:
  - name: "User Journey"
    weight: 70
    flow:
      - get:
          url: "/"
          expect:
            - statusCode: 200
            - hasProperty: 'message'
      - get:
          url: "/health"
          expect:
            - statusCode: 200
            - contentType: json
            - hasProperty: 'status'
      - post:
          url: "/api/data"
          json:
            userId: "{{ $randomInt(1, 1000) }}"
            action: "test"
          expect:
            - statusCode: [200, 201]
            
  - name: "Health Checks"
    weight: 30
    flow:
      - get:
          url: "/health"
          expect:
            - statusCode: 200
      - get:
          url: "/metrics"
          expect:
            - statusCode: 200
```

### Contract Testing with Pact

Create `tests/contract/user.contract.test.js`:

```javascript
const { Pact } = require('@pact-foundation/pact');
const { like, eachLike } = require('@pact-foundation/pact').Matchers;
const UserService = require('../../src/services/userService');

describe('User Service Contract', () => {
  const provider = new Pact({
    consumer: 'Frontend',
    provider: 'UserService',
    port: 1234,
    log: path.resolve(process.cwd(), 'logs', 'pact.log'),
    dir: path.resolve(process.cwd(), 'pacts'),
    logLevel: 'INFO'
  });

  beforeAll(() => provider.setup());
  afterAll(() => provider.finalize());
  afterEach(() => provider.verify());

  describe('Get User', () => {
    it('should return user data', async () => {
      // Arrange
      await provider.addInteraction({
        state: 'user exists',
        uponReceiving: 'a request for user data',
        withRequest: {
          method: 'GET',
          path: '/api/users/123',
          headers: {
            'Accept': 'application/json',
            'Authorization': like('Bearer token123')
          }
        },
        willRespondWith: {
          status: 200,
          headers: {
            'Content-Type': 'application/json'
          },
          body: {
            id: like(123),
            name: like('John Doe'),
            email: like('john@example.com'),
            active: like(true)
          }
        }
      });

      // Act
      const userService = new UserService('http://localhost:1234');
      const user = await userService.getUser(123, 'token123');

      // Assert
      expect(user.id).toBe(123);
      expect(user.name).toBe('John Doe');
      expect(user.email).toBe('john@example.com');
      expect(user.active).toBe(true);
    });
  });
});
```

---

## Monitoring and Observability

### Deployment Analytics Dashboard

Create custom Grafana dashboard configuration:

```json
{
  "dashboard": {
    "title": "CI/CD Pipeline Analytics",
    "panels": [
      {
        "title": "Deployment Frequency",
        "type": "stat",
        "targets": [
          {
            "expr": "increase(deployment_total[7d])",
            "legendFormat": "Deployments/Week"
          }
        ]
      },
      {
        "title": "Lead Time for Changes",
        "type": "stat",
        "targets": [
          {
            "expr": "avg(deployment_lead_time_seconds) / 3600",
            "legendFormat": "Hours"
          }
        ]
      },
      {
        "title": "Mean Time to Recovery",
        "type": "stat",
        "targets": [
          {
            "expr": "avg(incident_recovery_time_seconds) / 60",
            "legendFormat": "Minutes"
          }
        ]
      },
      {
        "title": "Change Failure Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "(sum(deployment_failed_total) / sum(deployment_total)) * 100",
            "legendFormat": "Percentage"
          }
        ]
      }
    ]
  }
}
```

### Alert Rules for Deployment Health

Create `monitoring/alerts/deployment-alerts.yml`:

```yaml
groups:
- name: deployment.rules
  rules:
  - alert: DeploymentFailed
    expr: increase(deployment_failed_total[5m]) > 0
    for: 0m
    labels:
      severity: critical
      team: platform
    annotations:
      summary: "Deployment failed for {{ $labels.application }}"
      description: "{{ $labels.application }} deployment has failed. Check CI/CD pipeline logs."

  - alert: CanaryDeploymentUnhealthy
    expr: |
      (
        sum(rate(http_requests_total{service=~".*-canary", status=~"5.."}[5m])) /
        sum(rate(http_requests_total{service=~".*-canary"}[5m]))
      ) > 0.05
    for: 2m
    labels:
      severity: warning
      team: platform
    annotations:
      summary: "Canary deployment showing high error rate"
      description: "Canary version of {{ $labels.service }} has error rate above 5% for 2 minutes."

  - alert: RollbackRequired
    expr: |
      (
        sum(rate(http_requests_total{status=~"5.."}[10m])) /
        sum(rate(http_requests_total[10m]))
      ) > 0.10
    for: 5m
    labels:
      severity: critical
      team: platform
    annotations:
      summary: "High error rate detected - rollback may be required"
      description: "Error rate above 10% for 5 minutes. Consider automated rollback."
```

---

## Troubleshooting Advanced Pipelines

### Common Pipeline Issues

**Security scan failures:**
```bash
# Check vulnerability scan results
kubectl logs -n ci-cd deployment/trivy-scanner

# Review security policy violations
kubectl get events --field-selector reason=PolicyViolation

# Bypass scan for hotfixes (use carefully)
git commit -m "hotfix: critical security patch [skip-security-scan]"
```

**Deployment conflicts:**
```bash
# Check GitOps synchronization status
flux get kustomizations --all-namespaces

# Resolve merge conflicts in GitOps repo
cd k3s-gitops
git status
git log --oneline --graph --all

# Force reconciliation
flux reconcile kustomization apps --with-source
```

**Performance test failures:**
```bash
# Analyze performance test results
kubectl logs -n ci-cd job/performance-test

# Check application metrics during test
kubectl port-forward svc/prometheus 9090:9090 &
# Query: rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])

# Scale resources if needed
kubectl patch deployment myapp -p '{"spec":{"template":{"spec":{"containers":[{"name":"myapp","resources":{"limits":{"cpu":"1000m","memory":"1Gi"}}}]}}}}'
```

### Emergency Procedures

**Automated rollback trigger:**
```bash
# Create webhook for emergency rollback
curl -X POST \
  https://api.github.com/repos/username/repo/actions/workflows/rollback.yml/dispatches \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -d '{"ref":"main","inputs":{"rollback_commit":"abc123"}}'

# Manual rollback via GitOps
cd k3s-gitops/clusters/production/apps/myapp
git log --oneline -5
git revert HEAD --no-edit
git push origin main
```

**Circuit breaker activation:**
```bash
# Temporarily disable new deployments
kubectl annotate deployment myapp deployment.kubernetes.io/revision-history-limit=0

# Enable maintenance mode
kubectl patch ingress myapp -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/server-snippet":"return 503;"}}}'
```

---

## Cost Optimization

### Resource-Aware Deployments

Configure dynamic resource allocation:

```yaml
# In deployment.yaml
spec:
  template:
    spec:
      containers:
      - name: myapp
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        env:
        - name: GOMAXPROCS
          valueFrom:
            resourceFieldRef:
              resource: limits.cpu
              divisor: "1"
        - name: GOMEMLIMIT
          valueFrom:
            resourceFieldRef:
              resource: limits.memory
              divisor: "1"
```

### Build Cache Optimization

**GitHub Actions cache strategy:**
```yaml
- name: Cache Docker layers
  uses: actions/cache@v3
  with:
    path: /tmp/.buildx-cache
    key: ${{ runner.os }}-buildx-${{ github.sha }}
    restore-keys: |
      ${{ runner.os }}-buildx-

- name: Build with cache
  uses: docker/build-push-action@v5
  with:
    cache-from: |
      type=local,src=/tmp/.buildx-cache
      type=gha
    cache-to: |
      type=local,dest=/tmp/.buildx-cache-new,mode=max
      type=gha,mode=max
```

---

## Next Steps

### Advanced CI/CD Pipeline Complete ✅

You now have:
- ✅ Enterprise-grade CI/CD pipeline with security scanning
- ✅ Multi-environment promotion workflow
- ✅ Progressive deployment strategies (canary/blue-green)
- ✅ Comprehensive testing and monitoring integration
- ✅ Automated rollback mechanisms
- ✅ Production-ready observability and alerting

### What's Next

→ **[04-scaling-considerations.md](04-scaling-considerations.md)** - Design applications for horizontal and vertical scaling

### Advanced Topics

For enterprise deployments, explore:
- **Service mesh integration**: Istio/Linkerd with advanced traffic management
- **Multi-cluster deployments**: Cross-region deployment strategies
- **Compliance automation**: SOC2, PCI-DSS, and GDPR compliance in CI/CD
- **Advanced observability**: Distributed tracing with Jaeger/Zipkin
- **Chaos engineering**: Automated resilience testing with Chaos Monkey

**Estimated time for next session**: 60 minutes to comprehensive scaling configuration

---

*This advanced CI/CD pipeline tutorial implements enterprise patterns used by leading technology companies. All configurations follow security best practices and provide a foundation for mission-critical application deployments.*