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

## Configuration

You can configure your traefik environment by editing the `.env` file. See the contents of that file for more information.

At the time of writing this the following options are available.

```
NETWORK_NAME=reverse-proxy
RESTART=no
DASHBOARD=true
HOST=localhost
```

## Add Docker-Compose Services to Traefik Network

### Development Environment

```yml
version: '3.8'
networks:
  frontend:
    external:
      name: reverse-proxy
services:
  someservice:
    # ...
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=reverse-proxy"
      # http
      - "traefik.http.routers.someservice.rule=Host(`someservice.com`)"
      - "traefik.http.routers.someservice-http.entrypoints=web"
    networks:
     - frontend
     - ...
```

### Production Environment

<!-- TODO: Add docker-compose setup for production -->

## Links and Resources

* https://doc.traefik.io/traefik/
