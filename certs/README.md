# Local Traefik TLS material

This directory is for legion-local internal CA and wildcard certificate material used by Traefik for private `.legion` HTTPS routes.

Do not commit private keys, CSRs, serial files, or generated certificates from this directory.

Files currently expected locally:

- `legion-internal-ca.crt` — public CA certificate to install on trusted client devices.
- `legion-internal-ca.key` — private CA key; keep local and secret.
- `legion-wildcard.crt` — Traefik leaf certificate for `*.legion`.
- `legion-wildcard.key` — Traefik leaf private key; keep local and secret.

Client devices must trust `legion-internal-ca.crt` before browsers consider `https://*.legion` trusted.
