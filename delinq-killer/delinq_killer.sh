#!/bin/bash

################################################################################
###          Solana DELINQ KILLER - Automatic Identity Switch Script         ###
###                 No downtime. No crashes. No coordination.                ###
################################################################################

# File: delinq_killer.sh
# Version: 1.1
# Date: 2025-20-07
# Author: STEALTH (93Q99nhdKjuSe6WNXgMBbC3s8QVQEAoHKt91PNRkUkMn)
# GitHub: https://github.com/STEVLTH/solana-validator/tree/main/delinq-killer
# Tweeter/X: @stevlth_sol
# Discord: .stevlth
# Telegram: @STEVLTH

# Description: This script automatically switches between staked and unstaked identities
#              based on validator delinquency status and internet connection.
#              It runs on both primary and secondary servers, no coordination required.
#              It respects manual identity switching — this means you can safely
#              perform upgrades or maintenance without fighting the automation.

# Usage: Run this script on both primary and secondary servers.
#        Setup as a systemd service or run it in a screen session.

# Requirements: jq, bc, curl, solana-cli, agave-validator, screen (optional)

# WARNING: This script is provided "as is" without any guarantees. Use it at your own risk.


# Settings
VALIDATOR_NAME="STEALTH_testnet_1"
SOLANA_PATH="$HOME/.local/share/solana/install/active_release/bin"
STAKED_IDENTITY_PATH="/path/to/staked_identity.json"
UNSTAKED_IDENTITY_PATH="/path/to/unstaked_identity.json"
RPC_URL="$($SOLANA_PATH/solana config get | grep RPC | awk '{print $3}')"
CHECK_INTERVAL=10
SWITCH_TIMEOUT=120
DEFAULT_DELINQUENT_SLOT_DISTANCE=16
LOG_PATH="$HOME/solana/delinq_killer.log"
# Telegram bot alerts (optional)
BOT_TOKEN=""
CHAT_ID=""


STAKED_IDENTITY_KEYPAIR=$(cat "$STAKED_IDENTITY_PATH")
STAKED_IDENTITY_PUBKEY="$($SOLANA_PATH/solana-keygen pubkey /dev/stdin <<< $STAKED_IDENTITY_KEYPAIR)"
# STAKED_IDENTITY_SHORT="${STAKED_IDENTITY_PUBKEY:0:5}...${STAKED_IDENTITY_PUBKEY: -5}"
UNSTAKED_IDENTITY_KEYPAIR=$(cat "$UNSTAKED_IDENTITY_PATH")
UNSTAKED_IDENTITY_PUBKEY="$($SOLANA_PATH/solana-keygen pubkey /dev/stdin <<< $UNSTAKED_IDENTITY_KEYPAIR)"
PREV_ACTIVE_IDENTITY_PUBKEY=""




# Colors and logging functions
BLUE="\033[1;34m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"; RESET="\033[0m"

log()   { echo -e "[$(date -u +"%F %T")] ${BLUE}[INFO]${RESET} $1" >> "$LOG_PATH"; }
warn()  { echo -e "[$(date -u +"%F %T")] ${YELLOW}[WARN]${RESET} $1" >> "$LOG_PATH"; }
error() { echo -e "[$(date -u +"%F %T")] ${RED}[ERROR]${RESET} $1" >> "$LOG_PATH"; exit 1; }
ok()    { echo -e "[$(date -u +"%F %T")] ${GREEN}[OK..]${RESET} $1" >> "$LOG_PATH"; }




for cmd in jq curl bc awk timeout systemctl; do
    if ! command -v $cmd &> /dev/null; then
        error "Required command '$cmd' is not installed or not in PATH."
    fi
done

if [[ ! -f "$SOLANA_PATH/solana" || ! -f "$SOLANA_PATH/agave-validator" ]]; then
    error "Solana binaries not found in $SOLANA_PATH"
fi

if [[ ! -f $STAKED_IDENTITY_PATH || -z $STAKED_IDENTITY_KEYPAIR ]]; then
    error "STAKED identity keypair is empty or file not found."
fi

if [[ ! -f $UNSTAKED_IDENTITY_PATH || -z $UNSTAKED_IDENTITY_KEYPAIR ]]; then
    error "UNSTAKED identity keypair is empty or file not found."
    # log 'Use "solana-keygen new --no-bip39-passphrase -s -o unstaked_identity.json" to generate new unstaked identity.'
fi

if [[ -z $LOG_PATH ]]; then
    error "LOG_PATH is not set."
fi




telegram_message() {
    if [[ -n $BOT_TOKEN && -n $CHAT_ID ]]; then
        curl --header 'Content-Type: application/json' --request 'POST' --data '{"chat_id":"'"$CHAT_ID"'","text":"'"$1"'"}' "https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
    fi
}


calculate_sleep_interval() {
    # Emulates cron-like scheduling using epoch time

    if [[ -z $1 ]]; then
        error "CHECK_INTERVAL not specified."
    fi

    local interval=$1
    local now=$(date +%s)
    local next=$(( (now / interval + 1) * interval ))
    local sleep_time=$(( next - now ))
    echo "$sleep_time"
}


check_internet_connection() {
    local servers=("google.com" "cloudflare.com" "github.com")
    local attempts=6
    local interval=2

    for ((i=0; i<attempts; i++)); do
        for server in "${servers[@]}"; do
            if ping -W 1 -c 1 $server &> /dev/null; then
                return 0
            fi
        done

        warn "Attempt #$((i+1))/$attempts: Internet connection unavailable. Retry in $interval seconds..."
        sleep $interval
    done

    return 1
}


check_local_rpc() {
    if $SOLANA_PATH/agave-validator --ledger $LEDGER_PATH contact-info > /dev/null; then
        RPC_PORT="$(systemctl status solana | grep -o -- "--rpc-port [^ ]*" | awk '{print $2}')"
        RPC_URL="http://localhost:$RPC_PORT"
        log "Local RPC is running."
        
        return 0
    else
        warn "Local RPC is not responding. Validator startup is not complete."

        return 1
    fi
}


check_delinquency() {
    local attempts=5
    local interval=2
    local delinquent_status
        
    for ((i=1; i<=attempts; i++)); do
        if [[ $i -gt 1 ]]; then
            # Check local RPC before each delinquency check
            if ! check_local_rpc; then
                warn "Skipping delinquency check."

                return 1
            fi
        fi

        if [[ $i == $attempts ]]; then
            # Usign public RPC for the final attempt
            RPC_URL="$($SOLANA_PATH/solana config get | grep RPC | awk '{print $3}')"
            log "Using public RPC: $RPC_URL for the final attempt."
            interval=0
        fi

        delinquent_status="$($SOLANA_PATH/solana --url $RPC_URL validators --delinquent-slot-distance $DELINQUENT_SLOT_DISTANCE --output json-compact | jq --arg IDENTITY "$STAKED_IDENTITY_PUBKEY" '.validators[] | select(.identityPubkey==$IDENTITY) ' | jq .delinquent)"

        if ! $delinquent_status; then
            log "$STAKED_IDENTITY_PUBKEY is not delinquent."

            return 1
        fi

        warn "Attempt #$i/$attempts: $STAKED_IDENTITY_PUBKEY is delinquent! Retry in $interval seconds..."
        sleep $interval
    done

    return 0
}


check_catchup() {
    if [ "$(timeout --foreground 5 $SOLANA_PATH/solana catchup --our-localhost > /dev/null && echo $?)" == "0" ]; then
        log "$ACTIVE_IDENTITY_PUBKEY is caught up."

        return 0
    else
        warn "$ACTIVE_IDENTITY_PUBKEY is NOT caught up."

        return 1
    fi
}


monitor_identity() {
    local message=""
    
    if [[ "$ACTIVE_IDENTITY_PUBKEY" == "$STAKED_IDENTITY_PUBKEY" && "$PREV_ACTIVE_IDENTITY_PUBKEY" != "" ]]; then
        DELINQUENT_SLOT_DISTANCE=$DEFAULT_DELINQUENT_SLOT_DISTANCE
        log "Delinquent Slot Distance: $DELINQUENT_SLOT_DISTANCE"

        if [[ "$PREV_ACTIVE_IDENTITY_PUBKEY" != "$STAKED_IDENTITY_PUBKEY" ]]; then
            
            SLEEP_SECONDS=$SWITCH_TIMEOUT
            message="Switched identity from UNSTAKED to STAKED."
            warn "$message"
            telegram_message "\u26A0 #$VALIDATOR_NAME ($(hostname -I | awk '{print $1}'))\n\n$message"

            return 1
        fi
    else
        DELINQUENT_SLOT_DISTANCE=$(echo "$DEFAULT_DELINQUENT_SLOT_DISTANCE*2" | bc)
        log "Delinquent Slot Distance: $DELINQUENT_SLOT_DISTANCE"

        if [[ "$PREV_ACTIVE_IDENTITY_PUBKEY" == "$STAKED_IDENTITY_PUBKEY" ]]; then        
            SLEEP_SECONDS=$(echo "$SWITCH_TIMEOUT*2" | bc)
            message="Switched identity from STAKED to UNSTAKED."
            warn "$message"
            telegram_message "\u26A0 #$VALIDATOR_NAME ($(hostname -I | awk '{print $1}'))\n\n$message"

            return 1
        fi
    fi

    return 0
}


switch_identity() {
    local identity
    
    if [[ "$ACTIVE_IDENTITY_PUBKEY" == "$STAKED_IDENTITY_PUBKEY" ]]; then
        identity="$UNSTAKED_IDENTITY_KEYPAIR"
        ok "$($SOLANA_PATH/agave-validator --ledger $LEDGER_PATH authorized-voter remove-all)"
    else
        identity="$STAKED_IDENTITY_KEYPAIR"

        if -f $TOWER_PATH ]; then
            rm -f $TOWER_PATH
            ok "Removed tower file: $TOWER_PATH"
        else
            warn "Tower file not found: $TOWER_PATH"
        fi
        
        ok "$($SOLANA_PATH/agave-validator --ledger $LEDGER_PATH authorized-voter add <<< $identity | grep Add)"
    fi

    ok "$($SOLANA_PATH/agave-validator --ledger $LEDGER_PATH set-identity <<< $identity)"
}




echo ""; echo "" >> "$LOG_PATH"
log "################################################################################"
log "###       Solana DELINQ KILLER v1.1 - Automatic Identity Switch Script       ###"
log "################################################################################"
echo ""; echo "" >> "$LOG_PATH"
log "Starting Solana DELINQ KILLER v1.1"
log "Validator Name: $VALIDATOR_NAME"
log "Staked Identity: $STAKED_IDENTITY_PUBKEY"
log "RPC URL: $RPC_URL"
log "Check Interval: $CHECK_INTERVAL seconds"
log "Switch Timeout: $SWITCH_TIMEOUT seconds"
log "Default Delinquent Slot Distance: $DEFAULT_DELINQUENT_SLOT_DISTANCE"
log "Log Path: $LOG_PATH"

if [[ -n $BOT_TOKEN && -n $CHAT_ID ]]; then
    log "Telegram Bot Alerts: Enabled"
else
    warn "Telegram Bot Alerts: Disabled"
fi
echo ""; echo "" >> "$LOG_PATH"


while true; do
    SLEEP_SECONDS=$CHECK_INTERVAL
    
    if ! systemctl is-active --quiet solana; then
        warn "Solana validator is not running."
    else
        LEDGER_PATH="$(systemctl status solana | grep -o -- "--ledger [^ ]*" | awk '{print $2}')"
        TOWER_PATH="$(systemctl status solana | grep -o -- "--tower [^ ]*" | awk '{print $2}')"
        DELINQUENT_SLOT_DISTANCE=$DEFAULT_DELINQUENT_SLOT_DISTANCE

        if [ -z "$TOWER_PATH" ]; then
            TOWER_PATH="$LEDGER_PATH/tower-1_9-$STAKED_IDENTITY_PUBKEY.bin"
        else
            TOWER_PATH="$TOWER_PATH/tower-1_9-$STAKED_IDENTITY_PUBKEY.bin"
        fi


        if check_local_rpc; then
            ACTIVE_IDENTITY_PUBKEY="$($SOLANA_PATH/agave-validator --ledger $LEDGER_PATH contact-info | grep Identity | awk '{print $2}')"
            log "Staked Identity: $STAKED_IDENTITY_PUBKEY"
            log "Active Identity: $ACTIVE_IDENTITY_PUBKEY"
            log "Prev   Identity: $PREV_ACTIVE_IDENTITY_PUBKEY"
            
            if monitor_identity; then
                if check_internet_connection; then 
                    log "Internet connection is available."

                    if check_delinquency; then

                        if [[ $ACTIVE_IDENTITY_PUBKEY == $STAKED_IDENTITY_PUBKEY ]]; then
                            switch_identity
                        else

                            if check_catchup; then
                                switch_identity
                            else
                                warn "Cannot switch to STAKED identity."
                                telegram_message "\u26A0 #$VALIDATOR_NAME ($(hostname -I | awk '{print $1}'))\n\nis NOT caught up.\nCannot switch to STAKED identity."
                            fi
                        fi
                    fi
                else 
                    warn "No internet connection."

                    if [[ $ACTIVE_IDENTITY_PUBKEY == $STAKED_IDENTITY_PUBKEY ]]; then 
                        switch_identity
                    else
                        log "Unstaked identity is active, do nothing."
                    fi
                fi
            fi

            PREV_ACTIVE_IDENTITY_PUBKEY=$ACTIVE_IDENTITY_PUBKEY
            log "Waiting $(calculate_sleep_interval "$SLEEP_SECONDS") seconds before next run..."
            echo ""; echo "" >> "$LOG_PATH"
        fi
    fi

    sleep "$(calculate_sleep_interval "$SLEEP_SECONDS")"
done
