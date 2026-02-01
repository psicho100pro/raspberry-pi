sudo apt update && sudo apt upgrade -y
sudo apt install -y redis-server

sudo systemctl enable redis-server
sudo systemctl start redis-server

sudo bash -c 'cat <<EOF > /etc/systemd/system/redis-server.service
[Unit]
Description=Advanced key-value store (Backend for Rspamd)
After=network-online.target
Before=rspamd.service
Documentation=http://redis.io/documentation, man:redis-server(1)

[Service]
Type=notify
ExecStart=/usr/bin/redis-server /etc/redis/redis.conf --supervised systemd
PIDFile=/run/redis/redis-server.pid
TimeoutStopSec=0
Restart=always
RestartSec=5s
User=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=2755

UMask=007
PrivateTmp=true
LimitNOFILE=65535
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=-/var/lib/redis
ReadWritePaths=-/var/log/redis
ReadWritePaths=-/var/run/redis
CapabilityBoundingSet=
LockPersonality=true
MemoryDenyWriteExecute=true
NoNewPrivileges=true
PrivateUsers=true
ProtectClock=true
ProtectControlGroups=true
ProtectHostname=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectProc=invisible
RemoveIPC=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~ @privileged @resources
NoExecPaths=/
ExecPaths=/usr/bin/redis-server /usr/lib /lib

[Install]
WantedBy=multi-user.target
Alias=redis.service
EOF'

wget -O- rspamd.com | gpg --dearmor | sudo tee /usr/share/keyrings/rspamd.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/rspamd.gpg] rspamd.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/rspamd.list

sudo apt update
sudo apt install -y rspamd

sudo bash -c 'cat <<EOF > /etc/systemd/system/rspamd.service
[Unit]
Description=rapid spam filtering system
After=network-online.target redis.service pihole-FTL.service
Requires=redis.service pihole-FTL.service
Documentation=https://rspamd.com

[Service]
LimitNOFILE=1048576
NonBlocking=true
ExecStart=/usr/bin/rspamd -c /etc/rspamd/rspamd.conf -f
ExecReload=/bin/kill -HUP \$MAINPID
User=_rspamd
RuntimeDirectory=rspamd
RuntimeDirectoryMode=0755
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF'


sudo mkdir -p /etc/rspamd/local.d
echo 'bind_socket = "0.0.0.0:11334";' | sudo tee /etc/rspamd/local.d/worker-controller.inc
echo 'password = "****";' | sudo tee -a /etc/rspamd/local.d/worker-controller.inc
echo 'servers = "127.0.0.1:6379";' | sudo tee /etc/rspamd/local.d/redis.conf

sudo bash -c 'cat <<EOF > /etc/rspamd/local.d/multimap.conf
GITHUB_SENDER_BLACKLIST {
    type = "from";
    filter = "email";
    map = "https://raw.githubusercontent.com/marco-acorte/antispam-it/main/antispam-emails.txt";
    score = 15.0;
    description = "Externí blacklist z GitHubu";
}
EOF'

sudo bash -c 'cat <<EOF > /etc/rspamd/local.d/classifier-bayes.conf
backend = "redis";
autolearn = true;
new_schema = true;
min_learns = 50;
EOF'

sudo bash -c 'cat <<EOF > /etc/rspamd/local.d/options.inc
map_watch_interval = 1209600;
rules_update_interval = "336h";

max_urls = 50;
max_images = 10;
max_message = 20M;
dns {
    nameserver = ["127.0.0.1:53"];
    retransmits = 3;
    timeout = 3s;
    error_time = 30s;
    max_errors = 5;
    remote_signals = false;
    skip_local = true;
}
EOF'

sudo rspamadm configtest


wget https://go.dev/dl/go1.25.5.linux-armv6l.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.25.5.linux-armv6l.tar.gz
export PATH=$PATH:/usr/local/go/bin

go install github.com/fho/rspamd-iscan@latest

sudo cp /home/psicho/go/bin/rspamd-iscan /usr/local/bin/

sudo bash -c 'cat <<EOF > /etc/rspamd-iscan/config.toml
RspamdURL           = "http://127.0.0.1:11334"
RspamdPassword      = ""
ImapAddr            = "imap.:993"
ImapUser            = ""
ImapPassword        = ""
ScanMailbox         = "INBOX"
InboxMailbox        = "Doruceny"
SpamMailbox         = "Rspamd/Spam"
HamMailbox          = "Rspamd/Ham"
UndetectedMailbox   = "Rspamd/Undetected"
BackupMailbox       = "Rspamd/Backup"
TempDir             = "/tmp"
KeepTempFiles       = false
SpamThreshold       = 6.0
EOF'

sudo bash -c 'cat <<EOF > /etc/systemd/system/rspamd-iscan.service
[Unit]
Description=Rspamd IMAP Scanner Daemon
After=network-online.target redis-server.service rspamd.service
Requires=redis-server.service rspamd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/rspamd-iscan --cfg-file /etc/rspamd-iscan/config.toml
Restart=always
RestartSec=10
User=*****

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl enable rspamd-iscan
sudo systemctl start rspamd-iscan


sudo systemctl stop rspamd
sudo rm /var/lib/rspamd/stats.ucl
sudo rm /var/lib/rspamd/rspamd.history
sudo rm /var/lib/rspamd/symbols.cache
sudo systemctl start rspamd
