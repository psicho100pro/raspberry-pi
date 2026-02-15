sudo apt update
sudo apt install -y unbound unbound-anchor

sudo mkdir -p /var/lib/unbound
sudo wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache

sudo -u unbound unbound-anchor -a "/var/lib/unbound/root.key"
sudo chown -R unbound:unbound /var/lib/unbound
sudo chmod 644 /var/lib/unbound/root.key /var/lib/unbound/root.hints

sudo bash -c 'cat <<EOF > /lib/systemd/system/unbound.service
[Unit]
Description=Unbound DNS server
Documentation=man:unbound(8)
After=network.target
Before=nss-lookup.target
Wants=nss-lookup.target

[Service]
Type=notify
Restart=on-failure
LimitNOFILE=16384
EnvironmentFile=-/etc/default/unbound
ExecStartPre=-/usr/libexec/unbound-helper chroot_setup
ExecStartPre=-/usr/libexec/unbound-helper root_trust_anchor_update
ExecStart=/usr/sbin/unbound -d \$DAEMON_OPTS
ExecStopPost=-/usr/libexec/unbound-helper chroot_teardown
ExecReload=+/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF'

sudo bash -c 'cat <<EOF > /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes

    access-control: 127.0.0.0/8 allow

    root-hints: "/var/lib/unbound/root.hints"
    auto-trust-anchor-file: "/var/lib/unbound/root.key"

server:
    # Vlákna a paralelizace (slabs musí odpovídat počtu vláken)
    num-threads: 4
    msg-cache-slabs: 4
    rrset-cache-slabs: 4
    infra-cache-slabs: 4
    key-cache-slabs: 4

    # Velikost cache (celkem 384 MB)
    msg-cache-size: 128m
    rrset-cache-size: 256m

    # Kapacita fronty a síťový stack (řeší 'exceeded' chyby)
    num-queries-per-thread: 2048
    outgoing-range: 8192
    jostle-timeout: 200
    edns-buffer-size: 1232

    # Caching strategie
    cache-min-ttl: 0
    cache-max-ttl: 86400
    prefetch: yes
    prefetch-key: yes
    aggressive-nsec: yes
    
    # Odpovědi při nedostupnosti (serve-expired)
    serve-expired: yes
    serve-expired-ttl: 86400
    serve-expired-reply-ttl: 30

    # Zabezpečení a soukromí
    qname-minimisation: yes
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-below-nxdomain: yes
    use-caps-for-id: no

    # Monitoring
    statistics-interval: 0
    statistics-cumulative: no
    extended-statistics: yes

remote-control:
    control-enable: yes
    control-interface: 127.0.0.1
    control-port: 8953
    server-key-file: "/etc/unbound/unbound_server.key"
    server-cert-file: "/etc/unbound/unbound_server.pem"
    control-key-file: "/etc/unbound/unbound_control.key"
    control-cert-file: "/etc/unbound/unbound_control.pem"
EOF'


sudo unbound-checkconf
sudo systemctl restart unbound

(crontab -l 2>/dev/null; echo "0 0 1 * * wget https://www.internic.net/domain/named.root -qO /var/lib/unbound/root.hints && chown unbound:unbound /var/lib/unbound/root.hints && systemctl restart unbound") | crontab -

