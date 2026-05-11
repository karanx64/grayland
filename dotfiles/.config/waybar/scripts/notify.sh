#!/usr/bin/env bash
# notify_demo.sh — demonstrates notify-send with urgency levels, actions, and progress
# Requires: libnotify (notify-send), bash 4+
# Works on: GNOME, KDE Plasma, XFCE, and most freedesktop-compliant DEs

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

die() { echo "error: $*" >&2; exit 1; }

# Check notify-send is available
command -v notify-send &>/dev/null || die "notify-send not found. Install libnotify: sudo apt install libnotify-bin"

# Ensure we have a session bus (needed when called from cron/root/SSH)
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  _pid=$(pgrep -u "$USER" -x "gnome-session\|plasmashell\|xfce4-session" | head -1 || true)
  if [[ -n "$_pid" ]]; then
    export DBUS_SESSION_BUS_ADDRESS
    DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS "/proc/$_pid/environ" \
      | tr -d '\0' | cut -d= -f2-)
  fi
fi

# ── 1. NORMAL urgency — with two actions + --wait ─────────────────────────────
echo
echo "▶ Sending NORMAL notification with actions…"
echo "  (will block until you click one)"

ACTION=$(notify-send \
  --urgency=normal \
  --expire-time=0 \
  --app-name="notify_demo" \
  --icon=dialog-question \
  --category=transfer.complete \
  --hint=string:desktop-entry:nautilus \
  --action="open=Open folder" \
  --action="dismiss=Dismiss" \
  --wait \
  "Download finished" \
  "ubuntu-24.04.iso (1.2 GB) is ready in ~/Downloads")

case "$ACTION" in
  open)    echo "  → you clicked: Open folder" ;;
  dismiss) echo "  → you clicked: Dismiss" ;;
  *)       echo "  → notification closed without action" ;;
esac

sleep 1

# ── 2. LOW urgency — with a single action + --wait ────────────────────────────
echo
echo "▶ Sending LOW notification with action…"

ACTION=$(notify-send \
  --urgency=low \
  --expire-time=0 \
  --app-name="notify_demo" \
  --icon=dialog-information \
  --category=x-gnome.music \
  --hint=int:transient:0 \
  --hint=int:suppress-sound:1 \
  --action="ack=Got it" \
  --wait \
  "Now playing" \
  "Pink Floyd — Comfortably Numb")

echo "  → action result: ${ACTION:-<closed without action>}"

sleep 1

# ── 3. CRITICAL urgency — with two actions + --wait ───────────────────────────
echo
echo "▶ Sending CRITICAL notification with actions…"

ACTION=$(notify-send \
  --urgency=critical \
  --app-name="notify_demo" \
  --icon=dialog-warning \
  --category=device.error \
  --hint=int:resident:1 \
  --hint=string:sound-name:dialog-warning \
  --hint=int:suppress-sound:0 \
  --action="reboot=Reboot now" \
  --action="later=Remind me later" \
  --wait \
  "Kernel panic — action required" \
  "System detected an unrecoverable error.\nSave your work and reboot.")

case "$ACTION" in
  reboot) echo "  → you clicked: Reboot now  (not actually rebooting)" ;;
  later)  echo "  → you clicked: Remind me later" ;;
  *)      echo "  → notification closed without action" ;;
esac

sleep 1

# ── 4. PROGRESS BAR — replace-id pattern ─────────────────────────────────────
echo
echo "▶ Sending progress notification (10 steps)…"

# Fire the first notification and capture its ID
NOTIF_ID=$(notify-send \
  --urgency=normal \
  --expire-time=0 \
  --app-name="notify_demo" \
  --icon=system-software-update \
  --category=transfer \
  --hint=int:transient:0 \
  --print-id \
  "Deploying…" "Step 0 / 10  ░░░░░░░░░░")

STEPS=10
for i in $(seq 1 "$STEPS"); do
  sleep 0.8   # simulate work

  # Build a simple ASCII bar: ██ for done, ░░ for remaining
  FILLED=$(printf '█%.0s' $(seq 1 "$i"))
  EMPTY=$(printf  '░%.0s' $(seq 1 $(( STEPS - i ))))
  BAR="${FILLED}${EMPTY}"

  if (( i < STEPS )); then
    notify-send \
      --urgency=normal \
      --expire-time=0 \
      --app-name="notify_demo" \
      --icon=system-software-update \
      --category=transfer \
      --hint=int:transient:0 \
      --replace-id="$NOTIF_ID" \
      "Deploying…" "Step $i / $STEPS  $BAR"
  else
    # Final state — swap icon and mark done; add a dismiss action
    ACTION=$(notify-send \
      --urgency=normal \
      --expire-time=0 \
      --app-name="notify_demo" \
      --icon=emblem-ok-symbolic \
      --category=transfer.complete \
      --hint=int:transient:0 \
      --replace-id="$NOTIF_ID" \
      --action="ok=Dismiss" \
      --wait \
      "Deploy complete ✓" "Step $STEPS / $STEPS  $BAR")
    echo "  → progress done; action: ${ACTION:-<closed>}"
  fi
done

echo
echo "All done."
