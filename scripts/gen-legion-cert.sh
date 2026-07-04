#!/usr/bin/env bash
#
# gen-legion-cert.sh — (re)generate or drift-check the legion internal TLS leaf cert.
#
# WHY THIS EXISTS (RES-307)
# -------------------------
# Traefik serves every private `*.legion` HTTPS route from ONE leaf certificate
# (traefik.d/legion-tls.yml → certs/legion-wildcard.crt), signed by the local
# "Thomas Legion Internal CA". A TLS wildcard label matches EXACTLY ONE dns
# label, so `*.restaurant-cms.legion` covers `foo-bar.restaurant-cms.legion`
# (the tenant PUBLIC host) but does NOT cover `admin.foo-bar.restaurant-cms.legion`
# or `api.foo-bar.restaurant-cms.legion` (two labels left of the base). Those
# per-tenant admin/api hosts need a dedicated `*.<slug>.restaurant-cms.legion`
# SAN — exactly the entries that already exist for buchenbeisl/dresdnerhof.
#
# When a new restaurant (e.g. Foo Bar) is provisioned, its admin/api hosts have
# no matching SAN → the browser Supabase/auth fetch to `api.<slug>...` fails the
# TLS check and the admin app shows "Verbindung zum Anmeldedienst fehlgeschlagen"
# even though routing and DNS/hosts are fine.
#
# This script makes cert coverage REUSABLE instead of a hand-edited one-off:
# it enumerates the live tenants from the running legion DB and regenerates the
# leaf cert with a `*.<slug>.restaurant-cms.legion` SAN per tenant, plus a
# `*.<custom>` SAN per custom `.legion` tenant domain. Run it whenever a
# restaurant is added (or wire it into the onboarding/`up-legion` flow).
#
# USAGE
#   scripts/gen-legion-cert.sh [--check] [extra-san ...]
#     --check     Drift-check mode: exit 0 if the current cert covers all desired
#                 SANs, non-zero if any SAN is missing. NO side effects — no CSR,
#                 no cert write, no Traefik restart. Used by reconcile-legion-cert.sh.
#     extra-san   Optional additional SAN hostnames (e.g. a slug not yet in the DB).
#                 Bare hostnames only. Ignored in --check mode (DB is the source).
#
# Environment overrides:
#   RCMS_DB_CONTAINER   legion supabase-db container (default: restaurant-cms-supabase-db-1)
#   TRAEFIK_CONTAINER   traefik container to restart (default: traefik-reverse-proxy-traefik-1)
#   CERT_DAYS           leaf validity in days (default: 800)
#   NO_RELOAD=1         generate the cert but do not restart Traefik
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$(cd "$SCRIPT_DIR/../certs" && pwd)"

CA_CRT="$CERTS_DIR/legion-internal-ca.crt"
CA_KEY="$CERTS_DIR/legion-internal-ca.key"
LEAF_KEY="$CERTS_DIR/legion-wildcard.key"
LEAF_CSR="$CERTS_DIR/legion-wildcard.csr"
LEAF_CRT="$CERTS_DIR/legion-wildcard.crt"
LEAF_CNF="$CERTS_DIR/legion-wildcard.openssl.cnf"

RCMS_DB_CONTAINER="${RCMS_DB_CONTAINER:-restaurant-cms-supabase-db-1}"
TRAEFIK_CONTAINER="${TRAEFIK_CONTAINER:-traefik-reverse-proxy-traefik-1}"
CERT_DAYS="${CERT_DAYS:-800}"
LEGION_IP="${LEGION_IP:-100.76.8.125}"

# ---------------------------------------------------------------------------
# Argument parsing — separate --check from extra SANs.
# ---------------------------------------------------------------------------
CHECK_MODE=0
EXTRA_SANS=()
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_MODE=1 ;;
    *) EXTRA_SANS+=("$arg") ;;
  esac
done

# ---------------------------------------------------------------------------
# 1. Static infrastructure SANs (non-tenant hosts on the legion box).
# ---------------------------------------------------------------------------
declare -a SANS=(
  "*.legion"
  "legion"
  "hermes.legion"
  "paperclip.legion"
  "restaurant-cms.legion"
  "*.restaurant-cms.legion"
  "admin.restaurant-cms.legion"
  "api.restaurant-cms.legion"
  "auth.restaurant-cms.legion"
  "supabase.restaurant-cms.legion"
  "mail.restaurant-cms.legion"
  "grafana.restaurant-cms.legion"
)

# ---------------------------------------------------------------------------
# 2. Shared helpers: add_san + db_query.
# ---------------------------------------------------------------------------
add_san() {
  local s="$1"
  [ -z "$s" ] && return 0
  local existing
  for existing in "${SANS[@]}"; do
    [ "$existing" = "$s" ] && return 0
  done
  SANS+=("$s")
}

db_query() {
  docker exec -e PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" "$RCMS_DB_CONTAINER" \
    psql -U postgres -d postgres -tAc "$1" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 3. Per-tenant SANs — enumerated live from the running legion DB.
#    Shared between --check and generation modes.
# ---------------------------------------------------------------------------
enumerate_tenant_sans() {
  local slugs
  slugs="$(db_query "SELECT slug FROM public.tenants ORDER BY slug;")"
  if [ -n "$slugs" ]; then
    while IFS= read -r slug; do
      [ -z "$slug" ] && continue
      add_san "${slug}.restaurant-cms.legion"
      add_san "*.${slug}.restaurant-cms.legion"
    done <<< "$slugs"
  else
    echo "WARN: legion DB ($RCMS_DB_CONTAINER) not reachable — seed-tenant fallback" >&2
    for slug in buchenbeisl dresdnerhof; do
      add_san "*.${slug}.restaurant-cms.legion"
    done
  fi

  # Custom bare `.legion` domains.
  local custom_hosts
  custom_hosts="$(db_query "SELECT hostname FROM public.tenant_domains WHERE hostname LIKE '%.legion' AND hostname NOT LIKE '%.restaurant-cms.legion' AND hostname NOT LIKE '%.restaurants.legion' ORDER BY hostname;")"
  if [ -n "$custom_hosts" ]; then
    while IFS= read -r host; do
      [ -z "$host" ] && continue
      local parent="${host#admin.}"; parent="${parent#api.}"; parent="${parent#www.}"
      add_san "$parent"
      add_san "*.${parent}"
    done <<< "$custom_hosts"
  fi
}

enumerate_tenant_sans

# ---------------------------------------------------------------------------
# 4. Any extra SANs passed on the command line (not used in --check mode).
# ---------------------------------------------------------------------------
if [ "$CHECK_MODE" = "0" ]; then
  for extra in "${EXTRA_SANS[@]}"; do
    add_san "$extra"
  done
fi

# ---------------------------------------------------------------------------
# --check: drift detection only — no cert/CSR/Traefik side effects.
# ---------------------------------------------------------------------------
if [ "$CHECK_MODE" = "1" ]; then
  if [ ! -f "$LEAF_CRT" ]; then
    echo "CHECK: no cert at $LEAF_CRT — drift (cert missing)" >&2
    exit 1
  fi

  # Parse DNS SANs from the current leaf cert.
  cert_dns="$(openssl x509 -in "$LEAF_CRT" -noout -ext subjectAltName 2>/dev/null \
    | tr ',' '\n' | sed -n 's/[[:space:]]*DNS://p' | tr -d ' ')"

  drift=0
  for san in "${SANS[@]}"; do
    if ! printf '%s\n' "$cert_dns" | grep -qxF "$san"; then
      echo "CHECK: missing SAN: $san" >&2
      drift=1
    fi
  done

  if [ "$drift" = "0" ]; then
    echo "CHECK: cert covers all ${#SANS[@]} desired SANs — in sync" >&2
    exit 0
  else
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Generation path (original logic below).
# ---------------------------------------------------------------------------

for f in "$CA_CRT" "$CA_KEY"; do
  [ -f "$f" ] || { echo "ERROR: missing CA material: $f" >&2; exit 1; }
done

# Reuse the existing leaf key if present (keeps the same public key; only the
# SAN set changes, so already-trusted clients need no re-trust). Generate one on
# first run.
if [ ! -f "$LEAF_KEY" ]; then
  echo "==> generating new leaf private key"
  openssl genrsa -out "$LEAF_KEY" 2048
fi

# ---------------------------------------------------------------------------
# 5. Render the OpenSSL config with the assembled SAN list.
# ---------------------------------------------------------------------------
{
  cat <<'EOF'
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = AT
ST = Vienna
L = Vienna
O = Venturini Homelab
OU = Legion
CN = *.legion

[req_ext]
subjectAltName = @alt_names

[alt_names]
EOF
  i=0
  for s in "${SANS[@]}"; do
    i=$((i + 1))
    echo "DNS.${i} = ${s}"
  done
  echo "IP.1 = ${LEGION_IP}"
} > "$LEAF_CNF"

echo "==> SAN set (${#SANS[@]} DNS entries):"
printf '    %s\n' "${SANS[@]}"

# ---------------------------------------------------------------------------
# 6. Back up the current cert, issue a new CSR + sign with the internal CA.
# ---------------------------------------------------------------------------
if [ -f "$LEAF_CRT" ]; then
  ts="$(date +%Y%m%d%H%M%S)"
  cp "$LEAF_CRT" "${LEAF_CRT}.bak.${ts}"
  echo "==> backed up previous cert to ${LEAF_CRT}.bak.${ts}"
fi

openssl req -new -key "$LEAF_KEY" -out "$LEAF_CSR" -config "$LEAF_CNF"
openssl x509 -req -in "$LEAF_CSR" \
  -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial \
  -out "$LEAF_CRT" -days "$CERT_DAYS" -sha256 \
  -extfile "$LEAF_CNF" -extensions req_ext

echo "==> issued $LEAF_CRT"
openssl x509 -in "$LEAF_CRT" -noout -issuer -subject -dates

# ---------------------------------------------------------------------------
# 7. Reload Traefik so it picks up the new cert (file provider does not always
#    watch cert file contents; a restart is deterministic and blips ~2s).
# ---------------------------------------------------------------------------
if [ "${NO_RELOAD:-0}" = "1" ]; then
  echo "==> NO_RELOAD=1 — skipping Traefik restart (reload manually to apply)"
else
  if docker ps --format '{{.Names}}' | grep -qx "$TRAEFIK_CONTAINER"; then
    echo "==> restarting Traefik ($TRAEFIK_CONTAINER)"
    docker restart "$TRAEFIK_CONTAINER" >/dev/null
    echo "==> Traefik restarted"
  else
    echo "WARN: Traefik container $TRAEFIK_CONTAINER not running — restart it to apply" >&2
  fi
fi

echo "==> done"
