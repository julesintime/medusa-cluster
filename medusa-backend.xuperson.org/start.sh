#!/bin/sh
set -e

echo "Starting Medusa application..."

# Run database migrations if this is the server instance
if [ "$MEDUSA_WORKER_MODE" = "server" ]; then
    echo "Running database migrations..."
    npx medusa db:migrate
fi

# Start the Medusa application
echo "Starting Medusa in $MEDUSA_WORKER_MODE mode..."
exec npm start