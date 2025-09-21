# Multi-stage build for optimized production image
FROM node:20-alpine AS base

# Install dependencies for build
RUN apk add --no-cache libc6-compat curl bash

# Enable corepack for yarn management
RUN corepack enable

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
FROM base AS deps
# Use npm for Docker builds to avoid yarn lockfile issues
RUN npm install

# Development stage  
FROM base AS development
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Copy and set up entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Set proper permissions
RUN chown -R nextjs:nodejs /app
USER nextjs

# Expose port
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

# Use entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Build stage for production
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set build environment
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create a temporary environment file for build
RUN echo "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_build_placeholder" > .env.local
RUN echo "MEDUSA_BACKEND_URL=http://medusa-backend:9000" >> .env.local
RUN echo "SKIP_BUILD_STATIC_GENERATION=true" >> .env.local

# Build the application
RUN npm run build

# Production stage
FROM base AS production
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Create non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy built application
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# Copy entrypoint script
COPY --chown=nextjs:nodejs entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy package.json for npm start command
COPY --chown=nextjs:nodejs package.json ./

USER nextjs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]