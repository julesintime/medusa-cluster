# Production Dockerfile for Medusa
FROM node:20-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Create app user to avoid running as root
RUN addgroup -g 1001 -S nodejs && adduser -S medusa -u 1001 -G nodejs

# Set working directory
WORKDIR /server

# Copy package files
COPY package.json package-lock.json* ./

# Change ownership of the working directory
RUN chown -R medusa:nodejs /server

# Switch to non-root user
USER medusa

# Install all dependencies using npm
RUN npm ci --only=production

# Copy source code and change ownership
COPY --chown=medusa:nodejs . .

# Make start script executable
RUN chmod +x ./start.sh

# Expose the port Medusa runs on
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9000/health || exit 1

# Start with migrations and then the server
CMD ["./start.sh"]