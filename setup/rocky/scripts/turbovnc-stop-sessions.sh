#!/bin/bash
# TurboVNC Multi-Session Shutdown Script

LOG_FILE="/var/log/turbovnc-sessions.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_msg "Stopping all TurboVNC sessions..."

for session in $(/opt/TurboVNC/bin/vncserver -list 2>/dev/null | grep "^:" | awk '{print $1}'); do
    /opt/TurboVNC/bin/vncserver -kill "$session" 2>/dev/null
    log_msg "  Stopped session $session"
done

log_msg "All TurboVNC sessions stopped."
