
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
sudo systemctl start delinq_killer.service
```

### Logs

```bash
tail -f ~/solana/delinq_killer.log
```

### Log example
Here is an example of the script output. It shows the process from starting the validator, checking its status, detecting delinquency, switching to staked identity, and finally confirming that the validator is caught up and running with the new identity:
```shell
[2025-07-13 20:26:50] [WARN] Solana validator is not running.
[2025-07-13 20:27:00] [WARN] Solana validator is not running.
[2025-07-13 20:27:10] [WARN] Local RPC is not responding. Validator startup is not complete.
[2025-07-13 20:27:20] [WARN] Local RPC is not responding. Validator startup is not complete.
[2025-07-13 20:27:30] [WARN] Local RPC is not responding. Validator startup is not complete.
[2025-07-13 20:27:40] [WARN] Local RPC is not responding. Validator startup is not complete.
[2025-07-13 20:27:50] [INFO] Local RPC is running.
[2025-07-13 20:27:50] [INFO] Delinquent Slot Distance: 16
[2025-07-13 20:27:50] [INFO] Staked Identity: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ
[2025-07-13 20:27:50] [INFO] Active Identity: H56oxFq69KzYbUdoRSmMC2MwRP84b8DNeRJmD3FweR13
[2025-07-13 20:27:50] [INFO] Prev   Identity: H56oxFq69KzYbUdoRSmMC2MwRP84b8DNeRJmD3FweR13
[2025-07-13 20:27:50] [INFO] Internet connection is available.
[2025-07-13 20:27:51] [WARN] Attempt #1/5: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ is delinquent! Retry in 2 seconds...
[2025-07-13 20:27:53] [INFO] Local RPC is running.
[2025-07-13 20:27:53] [WARN] Attempt #2/5: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ is delinquent! Retry in 2 seconds...
[2025-07-13 20:27:55] [INFO] Local RPC is running.
[2025-07-13 20:27:55] [WARN] Attempt #3/5: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ is delinquent! Retry in 2 seconds...
[2025-07-13 20:27:57] [INFO] Local RPC is running.
[2025-07-13 20:27:57] [WARN] Attempt #4/5: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ is delinquent! Retry in 2 seconds...
[2025-07-13 20:27:59] [INFO] Local RPC is running.
[2025-07-13 20:27:59] [INFO] Using public RPC: https://api.testnet.solana.com for the final attempt.
[2025-07-13 20:28:00] [WARN] Attempt #5/5: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ is delinquent! Retry in 0 seconds...
[2025-07-13 20:28:01] [INFO] H56oxFq69KzYbUdoRSmMC2MwRP84b8DNeRJmD3FweR13 is caught up.
[2025-07-13 20:28:01] [OK..] Removed tower file: /root/solana/tower-1_9-8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ.bin
[2025-07-13 20:28:01] [OK..] Adding authorized voter: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ
[2025-07-13 20:28:02] [OK..] New validator identity: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ
[2025-07-13 20:28:02] [INFO] Waiting 10 seconds before next run...

[2025-07-13 20:28:12] [INFO] Local RPC is running.
[2025-07-13 20:28:12] [INFO] Delinquent Slot Distance: 8
[2025-07-13 20:28:12] [WARN] switched identity from UNSTAKED to STAKED.
[2025-07-13 20:28:12] [INFO] Waiting 120 seconds before next run...

[2025-07-13 20:30:12] [INFO] Local RPC is running.
[2025-07-13 20:30:12] [INFO] Delinquent Slot Distance: 8
[2025-07-13 20:30:12] [INFO] Staked Identity: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ
[2025-07-13 20:30:12] [INFO] Active Identity: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ
[2025-07-13 20:30:12] [INFO] Prev   Identity: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ
[2025-07-13 20:30:12] [INFO] Internet connection is available.
[2025-07-13 20:30:12] [INFO] 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ is not delinquent.
[2025-07-13 20:30:12] [INFO] Waiting 8 seconds before next run...

[2025-07-13 20:30:20] [INFO] Local RPC is running.
[2025-07-13 20:30:20] [INFO] Delinquent Slot Distance: 8
[2025-07-13 20:30:20] [INFO] Staked Identity: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ
[2025-07-13 20:30:20] [INFO] Active Identity: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ
[2025-07-13 20:30:20] [INFO] Prev   Identity: 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ
[2025-07-13 20:30:20] [INFO] Internet connection is available.
[2025-07-13 20:30:21] [INFO] 8E9KWWqX1JMNu1YC3NptLA6M8cGqWRTccrF6T1FDnYRJ is not delinquent.
[2025-07-13 20:30:21] [INFO] Waiting 10 seconds before next run...
```



### WARNING: This script is provided "as is" without any guarantees. You can use it at your own risk.
