#!/usr/bin/env bash

# Load config.
source ./scripts/colors.conf

# Start the containers.
docker compose up -d && echo -e "${SUCCESS}Traefik is alive! 🧟${NC}"