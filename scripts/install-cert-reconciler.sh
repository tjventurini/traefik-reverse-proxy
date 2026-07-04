#!/usr/bin/env bash
#
# install-cert-reconciler.sh — install the legion-cert-reconcile systemd USER units.
#
# Writes legion-cert-reconcile.{service,timer} to ~/.config/systemd/user/,
# reloads the user daemon, and enables + starts the timer.
#
# Run once after cloning/updating traefik-reverse-proxy, or whenever the
# reconciler script path changes.
#
# USAGE
#   scripts/install-cert-reconciler.sh [--uninstall]
#     --uninstall   Stop + disable the timer and remove the unit files.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECONCILE_SH="$SCRIPT_DIR/reconcile-legion-cert.sh"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

if [ "${1:-}" = "--uninstall" ]; then
  echo "==> stopping and disabling legion-cert-reconcile.timer"
  systemctl --user stop  legion-cert-reconcile.timer  2>/dev/null || true
  systemctl --user disable legion-cert-reconcile.timer 2>/dev/null || true
  rm -f "$SYSTEMD_USER_DIR/legion-cert-reconcile.service" \
        "$SYSTEMD_USER_DIR/legion-cert-reconcile.timer"
  systemctl --user daemon-reload
  echo "==> uninstalled"
  exit 0
fi

[ -f "$RECONCILE_SH" ] || { echo "ERROR: $RECONCILE_SH not found" >&2; exit 1; }
chmod +x "$RECONCILE_SH" "$SCRIPT_DIR/gen-legion-cert.sh"

mkdir -p "$SYSTEMD_USER_DIR"

# ---------------------------------------------------------------------------
# Service unit — oneshot, logs to journal.
# ---------------------------------------------------------------------------
cat > "$SYSTEMD_USER_DIR/legion-cert-reconcile.service" <<EOF
[Unit]
Description=Legion TLS certificate drift reconciler
After=network.target

[Service]
Type=oneshot
ExecStart=$RECONCILE_SH
StandardOutput=journal
StandardError=journal
EOF

# ---------------------------------------------------------------------------
# Timer unit — fires ~60s after last activation; persistent across reboots.
# ---------------------------------------------------------------------------
cat > "$SYSTEMD_USER_DIR/legion-cert-reconcile.timer" <<'EOF'
[Unit]
Description=Legion TLS certificate drift reconciler timer

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now legion-cert-reconcile.timer

echo "==> legion-cert-reconcile.timer installed and active"
systemctl --user list-timers legion-cert-reconcile.timer --no-pager || true
