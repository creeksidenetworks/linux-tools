#!/bin/bash
# Check home usages for Synology DSM 
# (c) 2025 Creekside Networks LLC, Jackson Tong
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
DEFAULT_HOME=/volume1/homes
DU_OPTIONS="-sh"
BASE_PATH=$(dirname $(dirname "$(readlink -f "$0")"))
NAS_NAME=$(hostname -s)

LOG_PATH=$BASE_PATH/log
LOG_FILE="$LOG_PATH/${NAS_NAME}.log"
RPT_FILE="$LOG_PATH/${NAS_NAME}.rpt"

# Function to log messages
log_message() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    printf "%-10s : %s\n" "$timestamp" "$message" | sudo tee -a "$LOG_FILE" &> /dev/null

    # Ensure the log file does not exceed 1000 lines
    line_count=$(sudo wc -l < "$LOG_FILE")
    if [ "$line_count" -gt 1000 ]; then
        sudo tail -n 500 "$LOG_FILE" | sudo tee "$LOG_FILE.tmp" &> /dev/null
        sudo mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

main() {

    if [ $# -eq 0 ]; then
        HOME_PATH="${DEFAULT_HOME}"
    else
        HOME_PATH="$1"
    fi

    today_date=$(date +"%y-%m-%d")
    REPORT="0"
    rm -f $RPT_FILE

    if [ ! -d $HOME_PATH ]; then
        log_message "Home path $HOME_PATH does not exist. Exiting."
        exit 1
    fi

    if [ ! -d $LOG_PATH ]; then
        mkdir -p $LOG_PATH
    fi

    while read target; do
        if [[ $target == "" ]]; then 
            continue
        fi 
        
        size=$(du $DU_OPTIONS ${HOME_PATH}/$target  | awk '{print $1}' )
        log_message "$(printf "%-30s : %-5s\n" "$target" "$size")"
        if [[ $size == *"T" ]]; then
            printf "%-30s : %-5s\n" "$target" "$size"  >>  $RPT_FILE
            REPORT="1"
        fi
    done < <(find ${HOME_PATH} -maxdepth 1 -type d -printf '%P\n' | sort -f )


    if [ $REPORT -eq 1 ]; then
        printf "=========================================\n"
        printf "Home usage report for $NAS_NAME\n"
        printf "Report date: $today_date\n\n"
        printf "=========================================\n"
        cat "$RPT_FILE"
        printf "=========================================\n"
    fi  

    exit $REPORT
}

main "$@"
