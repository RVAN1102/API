#!/usr/bin/env bash
# fix-and-restart.sh
# 
# Helper script to clean up Docker state and restart the API Security Stack.
# This ensures that Keycloak imports the latest topic10-realm.json correctly
# and clears out any cached H2 database or zombie containers.

echo "====================================================="
echo "🧹 CLEANING UP DOCKER CONTAINERS AND VOLUMES..."
echo "====================================================="

# Stop all containers defined in docker-compose
docker compose -f infra/docker-compose.yml down -v

# Force remove any lingering containers explicitly just in case
docker compose -f infra/docker-compose.yml rm -f -s -v

echo ""
echo "====================================================="
echo "🚀 STARTING API SECURITY STACK..."
echo "====================================================="

docker compose -f infra/docker-compose.yml up -d --build

echo ""
echo "⏳ Waiting for services to initialize (approx 60 seconds)..."
echo "Keycloak and Kong may take a moment to be fully ready."
echo ""
echo "You can check status with: docker compose -f infra/docker-compose.yml ps"
echo "Check Keycloak logs:      docker compose -f infra/docker-compose.yml logs -f keycloak"
echo "Check Kong logs:          docker compose -f infra/docker-compose.yml logs -f kong"
echo ""
echo "✅ Done! Please wait ~60s then refresh the Frontend Dashboard."
