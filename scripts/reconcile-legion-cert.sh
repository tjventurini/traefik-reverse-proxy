#!/usr/bin/env bash
#
# reconcile-legion-cert.sh — idempotent Legion TLS cert drift reconciler.
#
# Runs gen-legion-cert.sh --check to compare the live DB's desired SAN set
# against the current leaf cert. Regenerates + reloads Traefik ONLY when drift
# is detected. A no-drift run exits silently with no side effects.
#
# Intended to be run from a systemd user timer every 60–90 s. Safe to invoke
# manually at any time.
#
# Environment overrides passed through to gen-legion-cert.sh:
#   RCMS_DB_CONTAINER, TRAEFIK_CONTAINER, CERT_DAYS, NO_RELOAD
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$SCRIPT_DIR/gen-legion-cert.sh"

if "$GEN" --check >/dev/null 2>&1; then
  # SANs are already in sync — nothing to do.
  exit 0
fi

# Drift detected — regenerate the cert and reload Traefik.
echo "==> legion-cert-reconcile: SAN drift detected — regenerating cert" >&2
"$GEN"
