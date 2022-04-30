# Traefik Reverse Proxy

[Traefik](https://doc.traefik.io/traefik/) setup inspired by [korridor/reverse-proxy-docker-traefik](https://github.com/korridor/reverse-proxy-docker-traefik).

This Traefik setup is an easy way to setup a local or production reverse proxy to handle incoming requests from outside your docker environment.

## Quick Start

First you will need to clone this repository.

```bash
git clone git@github.com:tjventurini/traefik-reverse-proxy.git
```

Then navigate into that directory in order to continue.

```bash
cd traefik-reverse-proxy
```

Now simply run `make init` or `make` from within the project root directory. The wizard will guide you through 🧙‍♂️

```bash
make init
```

## Usage

### Commands

```bash
# Run setup wizard
make init
# Start Traefik
make start
# Stop Traefik
make down
make stop # alias for 'make down'
# Uninstall Traefik
make clear
```

<!-- TODO: Add sample code on how to add an environment to the Traefik network -->

## Configuration

<!-- TODO: Show .env.example variables and how to overwrite with docker-compose.overwrite.yml -->

## Links and Resources

* https://doc.traefik.io/traefik/
