sudo apt update && sudo apt install curl

curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

sudo apt update && sudo apt install whois -y
mkpasswd -m bcrypt *______*

sudo useradd -r -s /usr/sbin/nologin adguard

sudo chown -R adguard:adguard /opt/AdGuardHome

sudo find /opt/AdGuardHome -type d -exec chmod 755 {} +
sudo find /opt/AdGuardHome -type f -exec chmod 644 {} +
sudo chmod +x /opt/AdGuardHome/AdGuardHome

sudo setcap 'CAP_NET_BIND_SERVICE=+eip CAP_NET_RAW=+eip' /opt/AdGuardHome/AdGuardHome

sudo mkdir -p /etc/systemd/system/AdGuardHome.service.d/

sudo bash -c 'cat <<EOF > /etc/systemd/system/AdGuardHome.service.d/user_isolation.conf
[Service]
User=adguard
Group=adguard
WorkingDirectory=/opt/AdGuardHome
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
ProtectHome=yes
ProtectSystem=full
EOF'

sudo bash -c 'cat <<EOF > /etc/systemd/system/AdGuardHome.service
[Unit]
Description=AdGuard Home: Network-level blocker
After=network-online.target unbound.service
Requires=unbound.service

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/opt/AdGuardHome/AdGuardHome -s run
WorkingDirectory=/opt/AdGuardHome
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reexec
sudo systemctl restart AdGuardHome
