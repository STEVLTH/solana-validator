
```
██████╗ ███████╗██╗     ██╗███╗   ██╗╔██████╗    ██╗  ██╗██╗██╗     ██╗     ███████╗██████╗
██╔══██╗██╔════╝██║     ██║████╗  ██║██╔═══██╗   ██║ ██╔╝██║██║     ██║     ██╔════╝██╔══██╗
██║  ██║█████╗  ██║     ██║██╔██╗ ██║██║   ██║   █████╔╝ ██║██║     ██║     █████╗  ██████╔╝
██║  ██║██╔══╝  ██║     ██║██║╚██╗██║██║██╗██║   ██╔═██╗ ██║██║     ██║     ██╔══╝  ██╔══██╗
██████╔╝███████╗███████╗██║██║ ╚████║╚██████╔╝   ██║  ██╗██║███████╗███████╗███████╗██║  ██║
╚═════╝ ╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝ ╚═██╔═╝    ╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝
                                        ╚═╝        No coordination. No downtime. No crashes.
```

Delinq Killer
================
is a simple Solana validator failover script. Handles identity switching between primary and backup nodes with no coordination or manual control.


### What it does
- Checks validator status every 10 seconds.
- If the Primary validator is **delinquent** or **offline**:
  - Switches to **unstaked** identity.
  - The Backup validator detects this and switches to **staked** identity.
  - Sends a Telegram alert (optional).
- If the Primary validator comes back online:
  - It will stay with the **unstaked** identity until backup validator fail or manual switch.
- Prevents crashes due to duplicate instances of the same validator node when the Primary/Backup comes back online.
- Respects manual identity switching, allowing for safe upgrades or maintenance without fighting the automation.


### Requirements

- Solana CLI + agave-validator
- staked_identity.json + unstaked_identity.json
  - both validators must start with **unstaked** identity
- jq, curl, ping, bc, timeout, awk
- Telegram Bot Token + Chat ID (optional)


### Run Script

Use one of the following:

### 1. screen (quick)

Start
```bash
screen -dmS delinq_killer ~/solana/delinq_killer.sh
```
Stop
```
screen -S delinq_killer -X quit
```

### 2. systemd (recommended)

```bash
# Create unit file:
echo "[Unit]
Description=Delinq Killer
After=network.target

[Service]
User=solana
ExecStart=/home/solana/scripts/delinq_killer.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/delinq_killer.service

# Enable and start:
sudo systemctl daemon-reload
sudo systemctl enable --now delinq_killer
```

### Logs

```bash
tail -f ~/solana/delinq_killer.log
```


### WARNING: This script is provided "as is" without any guarantees. You can use it at your own risk.
