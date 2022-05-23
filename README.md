# Traefik Reverse Proxy

[Traefik](https://doc.traefik.io/traefik/) setup inspired by [korridor/reverse-proxy-docker-traefik](https://github.com/korridor/reverse-proxy-docker-traefik).

This Traefik setup is an easy way to setup a local or production reverse proxy to handle incoming requests from outside your docker environment.

## Quick Start

First you will need to clone this repository.

```bash
git clone git@github.com:tjventurini/traefik-reverse-proxy.git
```

Navigate into the project directory in order to continue.

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

Update your projects `docker-compose.yml` file so that it includes the *network* and *labels* as shown below. Also make sure that you do not expose any ports on your services.

```yml
version: '3.8'

# setup the network
networks:
  frontend:
    external:
      name: reverse-proxy

services:
  someservice:
    # add the labels to the service configuration
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=reverse-proxy"
      # http
      - "traefik.http.routers.someservice.rule=Host(`someservice.com`)"
      - "traefik.http.routers.someservice.entrypoints=web"
    # add the network to the service configuration
    networks:
     - frontend
    # ...
```

### Production Environment

```yml
version: '3.8'

# setup the network
networks:
  frontend:
    external:
      name: reverse-proxy

services:
  someservice:
    # add the labels to the service configuration
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=reverse-proxy"
      # https
      - "traefik.http.routers.someservice.rule=Host(`someservice.com`)"
      - "traefik.http.routers.someservice.entrypoints=websecure"
      - "traefik.http.routers.someservice.tls=true"
      - "traefik.http.routers.someservice.tls.certresolver=letsencrypt"
    # add the network to the service configuration
    networks:
     - frontend
    # ...
```

## Links and Resources

* https://doc.traefik.io/traefik/
* https://github.com/korridor/reverse-proxy-docker-traefik
