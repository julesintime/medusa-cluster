FROM node:20-alpine

# Install required dependencies
RUN apk add --no-cache postgresql-client bash wget curl

WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./
RUN npm ci || npm install

# Copy all source code
COPY . .

# Create startup script with environment variable support
RUN cat > /app/start-production.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Medusa production server..."

# Wait for database to be ready
echo "⏳ Waiting for PostgreSQL..."
until PGPASSWORD=${POSTGRES_PASSWORD} psql -h ${POSTGRES_HOST:-postgres} -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-medusa-store} -c "\q" 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "✅ PostgreSQL is ready!"

# Run database migrations
echo "📄 Running database migrations..."
npm run medusa db:migrate

# Create admin user if specified
if [ -n "${ADMIN_EMAIL}" ] && [ -n "${ADMIN_PASSWORD}" ]; then
  echo "👤 Creating admin user if not exists..."
  npm run medusa user -e "${ADMIN_EMAIL}" -p "${ADMIN_PASSWORD}" || echo "Admin user might already exist"
fi

# Seed database if requested
if [ "${SEED_DATABASE}" = "true" ]; then
  echo "🌱 Seeding database..."
  npm run seed || echo "Seeding failed or already done, continuing..."
fi

# Start production server
echo "🎯 Starting Medusa production server..."
npm start
EOF

RUN chmod +x /app/start-production.sh

# Create health check script
RUN cat > /app/health-check.sh << 'EOF'
#!/bin/bash
curl -f http://localhost:9000/health || exit 1
EOF

RUN chmod +x /app/health-check.sh

EXPOSE 9000

# Use production startup script
CMD ["/app/start-production.sh"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD /app/health-check.sh