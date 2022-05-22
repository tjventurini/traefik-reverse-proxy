#!/usr/bin/env bash

# Load config.
source ./config/colors.conf

# Clean up.
rm ./.env && echo -e "${SUCCESS}Removed .env ✅${NC}"
rm ./docker-compose.yml && echo -e "${SUCCESS}Removed docker-compose.yml ✅${NC}"
rm ./letsencrypt/acme.json && echo -e "${SUCCESS}Removed acme.json ✅${NC}"