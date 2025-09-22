#!/bin/sh
set -e

echo "Starting Medusa application..."

# Run database migrations if this is the server instance
if [ "$MEDUSA_WORKER_MODE" = "server" ]; then
    echo "Running database migrations..."
    npx medusa db:migrate

    echo "Seeding database..."
    npm run seed || echo "Seeding failed, continuing..."
fi

# Start the Medusa application based on mode
if [ "$MEDUSA_WORKER_MODE" = "worker" ]; then
    echo "Starting Medusa worker..."
    exec npm start
else
    echo "Starting Medusa server..."
    exec npm start
fi