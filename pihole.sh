curl -sSL https://install.pi-hole.net -o pihole_install.sh
less pihole_install.sh
sudo bash pihole_install.sh

sudo bash -c 'cat <<EOF > /etc/systemd/system/pihole-FTL.service
[Unit]
Description=Pi-hole FTL (Strictly after AdGuard Home)
After=network-online.target AdGuardHome.service
Requires=AdGuardHome.service
BindsTo=AdGuardHome.service
StartLimitBurst=5
StartLimitIntervalSec=60s

[Service]
User=pihole
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_NET_ADMIN CAP_SYS_NICE CAP_CHOWN
ExecStartPre=/bin/bash -c "until : < /dev/tcp/127.0.0.1/5353; do sleep 1; done"
ExecStartPre=/bin/sleep 2
ExecStartPre=+/opt/pihole/pihole-FTL-prestart.sh
ExecStart=/usr/bin/pihole-FTL -f
ExecReload=/bin/kill -HUP \$MAINPID
ExecStopPost=+/opt/pihole/pihole-FTL-poststop.sh
Restart=always
RestartSec=5s
TimeoutStopSec=15s
ProtectSystem=full
ReadWriteDirectories=/etc/pihole

[Install]
WantedBy=multi-user.target
EOF'

sudo bash -c 'cat <<EOF > /etc/pihole/pihole.toml
#port = "80o,[::]:80o,443so,[::]:443so"
port = "80,[::]:80"
EOF'

sudo usermod -aG pihole ******
