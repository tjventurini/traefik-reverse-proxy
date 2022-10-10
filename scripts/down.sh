#!/usr/bin/env bash

# Load config.
source ./scripts/colors.conf

# Bring the containers down.
docker compose down --remove-orphans && echo -e "${SUCCESS}Traefik is dead! 💀${NC}"