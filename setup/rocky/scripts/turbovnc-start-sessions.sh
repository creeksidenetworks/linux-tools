#!/bin/bash
# TurboVNC User-Based Session Manager
# Reads /opt/TurboVNC/config/vncuser.conf and manages sessions accordingly
# Tracks session ownership and restarts sessions when ownership changes

CONFIG_FILE="/opt/TurboVNC/config/vncuser.conf"
STATE_FILE="/opt/TurboVNC/config/.session_state"
SETTINGS_FILE="/opt/TurboVNC/config/turbovnc.conf"
LOG_FILE="/var/log/turbovnc-sessions.log"

# Load settings from config file
if [[ -f "$SETTINGS_FILE" ]]; then
    source "$SETTINGS_FILE"
else
    echo "ERROR: Settings file not found: $SETTINGS_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

# Per-user clipboard settings (populated from config file)
declare -A user_clipboard

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_msg "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

log_msg "Starting TurboVNC session manager..."

# Load previous session state (display -> username mapping)
declare -A previous_state
if [[ -f "$STATE_FILE" ]]; then
    while IFS=: read -r display username; do
        # Skip empty lines
        [[ -z "$display" || -z "$username" ]] && continue
        previous_state["$display"]="$username"
    done < "$STATE_FILE"
fi

# Parse config file and build desired state
declare -A desired_sessions
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
    
    # Parse line: username : display_id [: copy] [: paste]
    IFS=':' read -ra parts <<< "$line"
    
    # Get username and display_id (required)
    username=$(echo "${parts[0]}" | xargs)
    display_id=$(echo "${parts[1]}" | xargs)
    
    # Validate display_id is a number
    if [[ ! "$display_id" =~ ^[0-9]+$ ]]; then
        log_msg "WARNING: Invalid display ID for user $username: $display_id (skipping)"
        continue
    fi
    
    # Validate user exists
    if ! id "$username" &>/dev/null; then
        log_msg "WARNING: User $username does not exist (skipping)"
        continue
    fi
    
    # Parse optional clipboard settings (parts 2+)
    user_copy="$GLOBAL_COPY"
    user_paste="$GLOBAL_PASTE"
    has_override=false
    
    for ((i=2; i<${#parts[@]}; i++)); do
        opt=$(echo "${parts[i]}" | xargs | tr '[:upper:]' '[:lower:]')
        case "$opt" in
            copy)  has_override=true ;;
            paste) has_override=true ;;
        esac
    done
    
    # If user has explicit overrides, check what was specified
    if [[ "$has_override" == "true" ]]; then
        copy_specified=false
        paste_specified=false
        for ((i=2; i<${#parts[@]}; i++)); do
            opt=$(echo "${parts[i]}" | xargs | tr '[:upper:]' '[:lower:]')
            [[ "$opt" == "copy" ]] && copy_specified=true
            [[ "$opt" == "paste" ]] && paste_specified=true
        done
        # Enable only what was explicitly specified
        [[ "$copy_specified" == "true" ]] && user_copy="Y" || user_copy="N"
        [[ "$paste_specified" == "true" ]] && user_paste="Y" || user_paste="N"
    fi
    
    # Build clipboard options string for this user
    clip_opts=""
    [[ "$user_copy" == "N" ]] && clip_opts+="-noclipboardsend "
    [[ "$user_paste" == "N" ]] && clip_opts+="-noclipboardrecv "
    user_clipboard[":$display_id"]="$clip_opts"
    
    desired_sessions[":$display_id"]="$username"
    if [[ -n "$clip_opts" ]]; then
        log_msg "Config: :$display_id -> $username (clipboard: $clip_opts)"
    else
        log_msg "Config: :$display_id -> $username (clipboard: full access)"
    fi
done < "$CONFIG_FILE"

# Get current running sessions by checking Xvnc processes
# This works regardless of which user started the session
declare -A current_sessions
while read -r display_num; do
    if [[ -n "$display_num" ]]; then
        current_sessions[":$display_num"]="running"
    fi
done < <(pgrep -a Xvnc 2>/dev/null | grep -oP ':\K[0-9]+(?= )' | sort -u)

# Stop sessions that are no longer in config or have ownership changes
for display in "${!current_sessions[@]}"; do
    desired_user="${desired_sessions[$display]}"
    previous_user="${previous_state[$display]}"
    
    if [[ -z "$desired_user" ]]; then
        # Session no longer in config - stop it
        log_msg "Stopping orphaned session $display"
        /opt/TurboVNC/bin/vncserver -kill "$display" 2>/dev/null
        unset current_sessions["$display"]
    elif [[ -n "$previous_user" && "$desired_user" != "$previous_user" ]]; then
        # Ownership changed - stop session so it can be restarted
        log_msg "Stopping session $display (ownership changed: $previous_user -> $desired_user)"
        /opt/TurboVNC/bin/vncserver -kill "$display" 2>/dev/null
        unset current_sessions["$display"]
    fi
done

# Start sessions that should be running
for display in "${!desired_sessions[@]}"; do
    username="${desired_sessions[$display]}"
    
    if [[ -n "${current_sessions[$display]}" ]]; then
        log_msg "Session $display already running for $username"
    else
        log_msg "Starting session $display for user $username"
        
        # Start VNC session AS THE USER (not root)
        # This ensures the session runs with proper user context
        
        # Get clipboard options for this user/display
        clip_opts="${user_clipboard[$display]}"
        
        # Build the vncserver command
        vnc_cmd="/opt/TurboVNC/bin/vncserver $display -wm $WM -securitytypes UnixLogin,TLSPlain $clip_opts -geometry 1920x1080 -depth 24"
        
        if [[ "$username" == "root" ]]; then
            # Set HOME explicitly for systemd environment where it may not be set
            export HOME=/root
            eval "$vnc_cmd" 2>/dev/null
        else
            # Use su with bash to run vncserver as the user
            su - "$username" -s /bin/bash -c "$vnc_cmd" 2>/dev/null
        fi
        
        # Check if session started by looking for Xvnc process
        # Extract display number (e.g., ":1" -> "1")
        display_num="${display#:}"
        #sleep 2
        if pgrep -a Xvnc 2>/dev/null | grep -q "Xvnc $display "; then
            log_msg "  Started session $display successfully"
        else
            log_msg "  ERROR: Failed to start session $display"
        fi
    fi
done

# Save current state for next run
> "$STATE_FILE"
for display in "${!desired_sessions[@]}"; do
    echo "$display:${desired_sessions[$display]}" >> "$STATE_FILE"
done
chmod 600 "$STATE_FILE"

log_msg "TurboVNC session manager completed."
