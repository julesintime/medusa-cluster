#!/bin/bash
set -e

echo "Starting Medusa initialization..."

# Wait for database to be ready
echo "Waiting for PostgreSQL..."
until PGPASSWORD=$DB_PASSWORD psql -h postgres -U $DB_USERNAME -d $DB_DATABASE -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "PostgreSQL is ready!"

# Run database migrations
echo "Running database migrations..."
yarn medusa db:migrate

# Create admin user if it doesn't exist
echo "Creating admin user..."
ADMIN_EMAIL=${ADMIN_EMAIL:-"admin@medusa.local"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"supersecret123"}

# Check if admin user exists
USER_EXISTS=$(yarn medusa user -e $ADMIN_EMAIL --id 2>&1 | grep -c "User with email" || true)

if [ "$USER_EXISTS" -eq 0 ]; then
  echo "Creating new admin user: $ADMIN_EMAIL"
  yarn medusa user -e $ADMIN_EMAIL -p $ADMIN_PASSWORD
else
  echo "Admin user already exists: $ADMIN_EMAIL"
fi

# Generate API token for frontend
echo "Generating API tokens..."
node /app/scripts/generate-api-keys.js

echo "Initialization complete!"